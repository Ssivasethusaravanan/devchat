package services

import (
	"context"
	"errors"
	"fmt"

	"codertalk-backend/internal/models"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// GroupService handles group conversation business logic.
type GroupService struct {
	db *pgxpool.Pool
}

// NewGroupService creates a new GroupService.
func NewGroupService(db *pgxpool.Pool) *GroupService {
	return &GroupService{db: db}
}

// CreateGroup creates a new group conversation and adds initial members.
func (s *GroupService) CreateGroup(ctx context.Context, creatorID uuid.UUID, req models.CreateGroupRequest) (*models.Conversation, error) {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Create the group conversation
	var convID uuid.UUID
	err = tx.QueryRow(ctx,
		`INSERT INTO conversations (type, name, description, created_by)
		 VALUES ('group', $1, $2, $3) RETURNING id`,
		req.Name, req.Description, creatorID,
	).Scan(&convID)
	if err != nil {
		return nil, fmt.Errorf("failed to create group: %w", err)
	}

	// Add creator as admin
	_, err = tx.Exec(ctx,
		`INSERT INTO conversation_members (conversation_id, user_id, role) VALUES ($1, $2, 'admin')`,
		convID, creatorID,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to add creator as member: %w", err)
	}

	// Create read receipt for creator
	_, err = tx.Exec(ctx,
		`INSERT INTO read_receipts (conversation_id, user_id) VALUES ($1, $2)`,
		convID, creatorID,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create read receipt: %w", err)
	}

	// Add initial members by username
	for _, username := range req.Members {
		var memberID uuid.UUID
		err = tx.QueryRow(ctx,
			`SELECT id FROM users WHERE username = $1`, username,
		).Scan(&memberID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				continue // Skip non-existent users
			}
			return nil, fmt.Errorf("failed to find user %s: %w", username, err)
		}

		if memberID == creatorID {
			continue // Skip if already added as creator
		}

		_, err = tx.Exec(ctx,
			`INSERT INTO conversation_members (conversation_id, user_id, role) VALUES ($1, $2, 'member')
			 ON CONFLICT (conversation_id, user_id) DO NOTHING`,
			convID, memberID,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to add member %s: %w", username, err)
		}

		_, _ = tx.Exec(ctx,
			`INSERT INTO read_receipts (conversation_id, user_id) VALUES ($1, $2)
			 ON CONFLICT (conversation_id, user_id) DO NOTHING`,
			convID, memberID,
		)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Return the created group with members
	return s.GetGroup(ctx, convID)
}

// GetGroup returns group details including members.
func (s *GroupService) GetGroup(ctx context.Context, groupID uuid.UUID) (*models.Conversation, error) {
	conv := &models.Conversation{}
	err := s.db.QueryRow(ctx, `
		SELECT id, type, COALESCE(name, ''), COALESCE(description, ''),
		       COALESCE(avatar_url, ''), created_by, created_at, updated_at
		FROM conversations WHERE id = $1 AND type = 'group'
	`, groupID).Scan(&conv.ID, &conv.Type, &conv.Name, &conv.Description,
		&conv.AvatarURL, &conv.CreatedBy, &conv.CreatedAt, &conv.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("group not found")
		}
		return nil, fmt.Errorf("failed to query group: %w", err)
	}

	// Get members
	rows, err := s.db.Query(ctx, `
		SELECT u.id, u.username, u.email, COALESCE(u.avatar_url, ''), u.status, u.created_at
		FROM users u
		JOIN conversation_members cm ON cm.user_id = u.id
		WHERE cm.conversation_id = $1
	`, groupID)
	if err != nil {
		return nil, fmt.Errorf("failed to query members: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var m models.UserPublic
		if err := rows.Scan(&m.ID, &m.Username, &m.Email, &m.AvatarURL, &m.Status, &m.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan member: %w", err)
		}
		conv.Members = append(conv.Members, m)
	}

	return conv, nil
}

// UpdateGroup updates a group's name and/or description.
func (s *GroupService) UpdateGroup(ctx context.Context, groupID, userID uuid.UUID, req models.UpdateGroupRequest) (*models.Conversation, error) {
	// Verify user is admin
	if err := s.verifyAdmin(ctx, groupID, userID); err != nil {
		return nil, err
	}

	_, err := s.db.Exec(ctx, `
		UPDATE conversations
		SET name = COALESCE(NULLIF($1, ''), name),
		    description = COALESCE(NULLIF($2, ''), description),
		    updated_at = NOW()
		WHERE id = $3
	`, req.Name, req.Description, groupID)
	if err != nil {
		return nil, fmt.Errorf("failed to update group: %w", err)
	}

	return s.GetGroup(ctx, groupID)
}

// AddMember adds a user to a group by username.
func (s *GroupService) AddMember(ctx context.Context, groupID, requesterID uuid.UUID, username string) error {
	// Verify requester is admin
	if err := s.verifyAdmin(ctx, groupID, requesterID); err != nil {
		return err
	}

	// Find user by username
	var memberID uuid.UUID
	err := s.db.QueryRow(ctx,
		`SELECT id FROM users WHERE username = $1`, username,
	).Scan(&memberID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("user '%s' not found", username)
		}
		return fmt.Errorf("failed to find user: %w", err)
	}

	// Check if already a member
	var exists bool
	err = s.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM conversation_members WHERE conversation_id = $1 AND user_id = $2)`,
		groupID, memberID,
	).Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check membership: %w", err)
	}
	if exists {
		return fmt.Errorf("user '%s' is already a member", username)
	}

	// Add member
	_, err = s.db.Exec(ctx,
		`INSERT INTO conversation_members (conversation_id, user_id, role) VALUES ($1, $2, 'member')`,
		groupID, memberID,
	)
	if err != nil {
		return fmt.Errorf("failed to add member: %w", err)
	}

	// Create read receipt
	_, _ = s.db.Exec(ctx,
		`INSERT INTO read_receipts (conversation_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		groupID, memberID,
	)

	return nil
}

// RemoveMember removes a user from a group.
func (s *GroupService) RemoveMember(ctx context.Context, groupID, requesterID, memberID uuid.UUID) error {
	// Verify requester is admin (or removing themselves)
	if requesterID != memberID {
		if err := s.verifyAdmin(ctx, groupID, requesterID); err != nil {
			return err
		}
	}

	result, err := s.db.Exec(ctx,
		`DELETE FROM conversation_members WHERE conversation_id = $1 AND user_id = $2`,
		groupID, memberID,
	)
	if err != nil {
		return fmt.Errorf("failed to remove member: %w", err)
	}
	if result.RowsAffected() == 0 {
		return errors.New("member not found in group")
	}

	// Also delete read receipt
	_, _ = s.db.Exec(ctx,
		`DELETE FROM read_receipts WHERE conversation_id = $1 AND user_id = $2`,
		groupID, memberID,
	)

	return nil
}

// verifyAdmin checks if a user is an admin of the given group.
func (s *GroupService) verifyAdmin(ctx context.Context, groupID, userID uuid.UUID) error {
	var role string
	err := s.db.QueryRow(ctx,
		`SELECT role FROM conversation_members WHERE conversation_id = $1 AND user_id = $2`,
		groupID, userID,
	).Scan(&role)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("you are not a member of this group")
		}
		return fmt.Errorf("failed to check admin status: %w", err)
	}
	if role != "admin" {
		return errors.New("only group admins can perform this action")
	}
	return nil
}
