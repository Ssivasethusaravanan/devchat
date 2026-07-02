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

// ChatService handles chat and conversation business logic.
type ChatService struct {
	db *pgxpool.Pool
}

// NewChatService creates a new ChatService.
func NewChatService(db *pgxpool.Pool) *ChatService {
	return &ChatService{db: db}
}

// GetConversations returns all conversations for a user, with last message and unread count.
func (s *ChatService) GetConversations(ctx context.Context, userID uuid.UUID) ([]models.Conversation, error) {
	rows, err := s.db.Query(ctx, `
		SELECT c.id, c.type, COALESCE(c.name, ''), COALESCE(c.description, ''),
		       COALESCE(c.avatar_url, ''), c.created_by, c.created_at, c.updated_at
		FROM conversations c
		JOIN conversation_members cm ON cm.conversation_id = c.id
		WHERE cm.user_id = $1
		ORDER BY c.updated_at DESC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to query conversations: %w", err)
	}
	defer rows.Close()

	var conversations []models.Conversation
	for rows.Next() {
		var conv models.Conversation
		if err := rows.Scan(&conv.ID, &conv.Type, &conv.Name, &conv.Description,
			&conv.AvatarURL, &conv.CreatedBy, &conv.CreatedAt, &conv.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan conversation: %w", err)
		}

		// Get members
		conv.Members, _ = s.getConversationMembers(ctx, conv.ID)

		// For DMs, set the name to the other user's username
		if conv.Type == "direct" && len(conv.Members) > 0 {
			for _, member := range conv.Members {
				if member.ID != userID {
					conv.Name = member.Username
					conv.AvatarURL = member.AvatarURL
					break
				}
			}
		}

		// Get last message
		conv.LastMessage, _ = s.getLastMessage(ctx, conv.ID)

		// Get unread count
		conv.UnreadCount, _ = s.getUnreadCount(ctx, conv.ID, userID)

		conversations = append(conversations, conv)
	}

	return conversations, nil
}

// GetOrCreateDM gets an existing DM conversation or creates a new one between two users.
func (s *ChatService) GetOrCreateDM(ctx context.Context, userID, otherUserID uuid.UUID) (*models.Conversation, error) {
	if userID == otherUserID {
		return nil, errors.New("cannot create a conversation with yourself")
	}

	// Check if a DM already exists between these two users
	var convID uuid.UUID
	err := s.db.QueryRow(ctx, `
		SELECT cm1.conversation_id
		FROM conversation_members cm1
		JOIN conversation_members cm2 ON cm1.conversation_id = cm2.conversation_id
		JOIN conversations c ON c.id = cm1.conversation_id
		WHERE cm1.user_id = $1 AND cm2.user_id = $2 AND c.type = 'direct'
	`, userID, otherUserID).Scan(&convID)

	if err == nil {
		// DM exists, return it
		return s.GetConversation(ctx, convID, userID)
	}

	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("failed to check existing DM: %w", err)
	}

	// Create new DM conversation
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	err = tx.QueryRow(ctx,
		`INSERT INTO conversations (type, created_by) VALUES ('direct', $1) RETURNING id`,
		userID,
	).Scan(&convID)
	if err != nil {
		return nil, fmt.Errorf("failed to create conversation: %w", err)
	}

	// Add both users as members
	_, err = tx.Exec(ctx,
		`INSERT INTO conversation_members (conversation_id, user_id, role) VALUES ($1, $2, 'member'), ($1, $3, 'member')`,
		convID, userID, otherUserID,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to add members: %w", err)
	}

	// Initialize read receipts
	_, err = tx.Exec(ctx,
		`INSERT INTO read_receipts (conversation_id, user_id) VALUES ($1, $2), ($1, $3)`,
		convID, userID, otherUserID,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create read receipts: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return s.GetConversation(ctx, convID, userID)
}

// GetConversation returns a single conversation by ID.
func (s *ChatService) GetConversation(ctx context.Context, convID, userID uuid.UUID) (*models.Conversation, error) {
	conv := &models.Conversation{}
	err := s.db.QueryRow(ctx, `
		SELECT c.id, c.type, COALESCE(c.name, ''), COALESCE(c.description, ''),
		       COALESCE(c.avatar_url, ''), c.created_by, c.created_at, c.updated_at
		FROM conversations c
		JOIN conversation_members cm ON cm.conversation_id = c.id AND cm.user_id = $2
		WHERE c.id = $1
	`, convID, userID).Scan(&conv.ID, &conv.Type, &conv.Name, &conv.Description,
		&conv.AvatarURL, &conv.CreatedBy, &conv.CreatedAt, &conv.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("conversation not found or access denied")
		}
		return nil, fmt.Errorf("failed to query conversation: %w", err)
	}

	conv.Members, _ = s.getConversationMembers(ctx, conv.ID)
	conv.LastMessage, _ = s.getLastMessage(ctx, conv.ID)
	conv.UnreadCount, _ = s.getUnreadCount(ctx, conv.ID, userID)

	// For DMs, set the name to the other user's username
	if conv.Type == "direct" {
		for _, member := range conv.Members {
			if member.ID != userID {
				conv.Name = member.Username
				conv.AvatarURL = member.AvatarURL
				break
			}
		}
	}

	return conv, nil
}

// GetMessages returns paginated messages for a conversation.
func (s *ChatService) GetMessages(ctx context.Context, convID, userID uuid.UUID, page, pageSize int) (*models.MessageListResponse, error) {
	// Verify user is a member
	var isMember bool
	err := s.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM conversation_members WHERE conversation_id = $1 AND user_id = $2)`,
		convID, userID,
	).Scan(&isMember)
	if err != nil || !isMember {
		return nil, errors.New("access denied")
	}

	// Get total count
	var totalCount int
	err = s.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM messages WHERE conversation_id = $1`, convID,
	).Scan(&totalCount)
	if err != nil {
		return nil, fmt.Errorf("failed to count messages: %w", err)
	}

	offset := (page - 1) * pageSize
	rows, err := s.db.Query(ctx, `
		SELECT m.id, m.conversation_id, m.sender_id, m.content, m.content_type,
		       COALESCE(m.language, ''), m.is_edited, m.reply_to_id, m.created_at, m.updated_at,
		       u.id, u.username, u.email, COALESCE(u.avatar_url, ''), u.status, u.created_at
		FROM messages m
		JOIN users u ON u.id = m.sender_id
		WHERE m.conversation_id = $1
		ORDER BY m.created_at DESC
		LIMIT $2 OFFSET $3
	`, convID, pageSize, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to query messages: %w", err)
	}
	defer rows.Close()

	var messages []models.Message
	for rows.Next() {
		var msg models.Message
		sender := &models.UserPublic{}
		if err := rows.Scan(&msg.ID, &msg.ConversationID, &msg.SenderID, &msg.Content,
			&msg.ContentType, &msg.Language, &msg.IsEdited, &msg.ReplyToID, &msg.CreatedAt, &msg.UpdatedAt,
			&sender.ID, &sender.Username, &sender.Email, &sender.AvatarURL, &sender.Status, &sender.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan message: %w", err)
		}
		msg.Sender = sender

		// Get attachments if file type
		if msg.ContentType == "file" || msg.ContentType == "image" {
			msg.Attachments, _ = s.getAttachments(ctx, msg.ID)
		}
		msg.ReplyTo = s.getReplyToSnippet(ctx, msg.ReplyToID)
		msg.Reactions, _ = s.getReactions(ctx, msg.ID)

		messages = append(messages, msg)
	}

	// Reverse to get chronological order (we queried DESC for pagination)
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	// Update read receipt
	_, _ = s.db.Exec(ctx,
		`INSERT INTO read_receipts (conversation_id, user_id, last_read_at)
		 VALUES ($1, $2, NOW())
		 ON CONFLICT (conversation_id, user_id) DO UPDATE SET last_read_at = NOW()`,
		convID, userID,
	)

	return &models.MessageListResponse{
		Messages:   messages,
		TotalCount: totalCount,
		Page:       page,
		PageSize:   pageSize,
		HasMore:    offset+pageSize < totalCount,
	}, nil
}

// SaveMessage persists a new message to the database.
func (s *ChatService) SaveMessage(ctx context.Context, convID, senderID uuid.UUID, content, contentType, language string, replyToID *uuid.UUID) (*models.Message, error) {
	msg := &models.Message{}
	sender := &models.UserPublic{}

	err := s.db.QueryRow(ctx, `
		INSERT INTO messages (conversation_id, sender_id, content, content_type, language, reply_to_id)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, conversation_id, sender_id, content, content_type, language, is_edited, reply_to_id, created_at, updated_at
	`, convID, senderID, content, contentType, language, replyToID,
	).Scan(&msg.ID, &msg.ConversationID, &msg.SenderID, &msg.Content,
		&msg.ContentType, &msg.Language, &msg.IsEdited, &msg.ReplyToID, &msg.CreatedAt, &msg.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to save message: %w", err)
	}

	// Get sender info
	_ = s.db.QueryRow(ctx,
		`SELECT id, username, email, COALESCE(avatar_url, ''), status, created_at FROM users WHERE id = $1`,
		senderID,
	).Scan(&sender.ID, &sender.Username, &sender.Email, &sender.AvatarURL, &sender.Status, &sender.CreatedAt)
	msg.Sender = sender
	msg.ReplyTo = s.getReplyToSnippet(ctx, msg.ReplyToID)
	msg.Reactions = []models.MessageReaction{}

	// Update conversation's updated_at timestamp
	_, _ = s.db.Exec(ctx,
		`UPDATE conversations SET updated_at = NOW() WHERE id = $1`, convID,
	)

	return msg, nil
}

// SaveAttachment persists file attachment metadata.
func (s *ChatService) SaveAttachment(ctx context.Context, messageID uuid.UUID, fileName string, fileSize int64, mimeType, r2Key string) (*models.Attachment, error) {
	att := &models.Attachment{}
	err := s.db.QueryRow(ctx, `
		INSERT INTO attachments (message_id, file_name, file_size, mime_type, r2_key)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, message_id, file_name, file_size, mime_type, r2_key, created_at
	`, messageID, fileName, fileSize, mimeType, r2Key,
	).Scan(&att.ID, &att.MessageID, &att.FileName, &att.FileSize, &att.MimeType, &att.R2Key, &att.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to save attachment: %w", err)
	}
	return att, nil
}

// GetConversationMemberIDs returns all user IDs in a conversation.
func (s *ChatService) GetConversationMemberIDs(ctx context.Context, convID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := s.db.Query(ctx,
		`SELECT user_id FROM conversation_members WHERE conversation_id = $1`, convID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, nil
}

// --- Helper methods ---

func (s *ChatService) getConversationMembers(ctx context.Context, convID uuid.UUID) ([]models.UserPublic, error) {
	rows, err := s.db.Query(ctx, `
		SELECT u.id, u.username, u.email, COALESCE(u.avatar_url, ''), u.status, u.created_at
		FROM users u
		JOIN conversation_members cm ON cm.user_id = u.id
		WHERE cm.conversation_id = $1
	`, convID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []models.UserPublic
	for rows.Next() {
		var m models.UserPublic
		if err := rows.Scan(&m.ID, &m.Username, &m.Email, &m.AvatarURL, &m.Status, &m.CreatedAt); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, nil
}

func (s *ChatService) getLastMessage(ctx context.Context, convID uuid.UUID) (*models.Message, error) {
	msg := &models.Message{}
	sender := &models.UserPublic{}
	err := s.db.QueryRow(ctx, `
		SELECT m.id, m.conversation_id, m.sender_id, m.content, m.content_type,
		       COALESCE(m.language, ''), m.is_edited, m.reply_to_id, m.created_at, m.updated_at,
		       u.id, u.username, u.email, COALESCE(u.avatar_url, ''), u.status, u.created_at
		FROM messages m
		JOIN users u ON u.id = m.sender_id
		WHERE m.conversation_id = $1
		ORDER BY m.created_at DESC
		LIMIT 1
	`, convID).Scan(&msg.ID, &msg.ConversationID, &msg.SenderID, &msg.Content,
		&msg.ContentType, &msg.Language, &msg.IsEdited, &msg.ReplyToID, &msg.CreatedAt, &msg.UpdatedAt,
		&sender.ID, &sender.Username, &sender.Email, &sender.AvatarURL, &sender.Status, &sender.CreatedAt)
	if err != nil {
		return nil, err
	}
	msg.Sender = sender
	msg.ReplyTo = s.getReplyToSnippet(ctx, msg.ReplyToID)
	msg.Reactions = []models.MessageReaction{}
	return msg, nil
}

func (s *ChatService) getUnreadCount(ctx context.Context, convID, userID uuid.UUID) (int, error) {
	var count int
	err := s.db.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM messages m
		WHERE m.conversation_id = $1
		  AND m.sender_id != $2
		  AND m.created_at > COALESCE(
			(SELECT last_read_at FROM read_receipts WHERE conversation_id = $1 AND user_id = $2),
			'1970-01-01'::timestamptz
		  )
	`, convID, userID).Scan(&count)
	return count, err
}

func (s *ChatService) getAttachments(ctx context.Context, messageID uuid.UUID) ([]models.Attachment, error) {
	rows, err := s.db.Query(ctx, `
		SELECT id, message_id, file_name, file_size, mime_type, r2_key, created_at
		FROM attachments WHERE message_id = $1
	`, messageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var attachments []models.Attachment
	for rows.Next() {
		var a models.Attachment
		if err := rows.Scan(&a.ID, &a.MessageID, &a.FileName, &a.FileSize, &a.MimeType, &a.R2Key, &a.CreatedAt); err != nil {
			return nil, err
		}
		attachments = append(attachments, a)
	}
	return attachments, nil
}

func (s *ChatService) getReplyToSnippet(ctx context.Context, replyToID *uuid.UUID) *models.MessageReplySnippet {
	if replyToID == nil {
		return nil
	}
	var snippet models.MessageReplySnippet
	err := s.db.QueryRow(ctx, `
		SELECT m.id, m.sender_id, u.username, m.content, m.content_type
		FROM messages m
		JOIN users u ON u.id = m.sender_id
		WHERE m.id = $1
	`, *replyToID).Scan(&snippet.ID, &snippet.SenderID, &snippet.Username, &snippet.Content, &snippet.ContentType)
	if err != nil {
		return nil
	}
	return &snippet
}

func (s *ChatService) getReactions(ctx context.Context, messageID uuid.UUID) ([]models.MessageReaction, error) {
	rows, err := s.db.Query(ctx, `
		SELECT mr.id, mr.message_id, mr.user_id, u.username, mr.emoji, mr.created_at
		FROM message_reactions mr
		JOIN users u ON u.id = mr.user_id
		WHERE mr.message_id = $1
		ORDER BY mr.created_at ASC
	`, messageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reactions []models.MessageReaction
	for rows.Next() {
		var r models.MessageReaction
		if err := rows.Scan(&r.ID, &r.MessageID, &r.UserID, &r.Username, &r.Emoji, &r.CreatedAt); err != nil {
			continue
		}
		reactions = append(reactions, r)
	}
	return reactions, nil
}

// EditMessage edits a message's content if the user is the sender.
func (s *ChatService) EditMessage(ctx context.Context, userID, messageID uuid.UUID, newContent string) (*models.Message, error) {
	var senderID, convID uuid.UUID
	err := s.db.QueryRow(ctx, `SELECT sender_id, conversation_id FROM messages WHERE id = $1`, messageID).Scan(&senderID, &convID)
	if err != nil {
		return nil, errors.New("message not found")
	}
	if senderID != userID {
		return nil, errors.New("only the sender can edit this message")
	}

	_, err = s.db.Exec(ctx, `UPDATE messages SET content = $1, is_edited = TRUE, updated_at = NOW() WHERE id = $2`, newContent, messageID)
	if err != nil {
		return nil, fmt.Errorf("failed to update message: %w", err)
	}

	return s.GetMessageByID(ctx, messageID)
}

// DeleteMessage deletes a message if the user is the sender.
func (s *ChatService) DeleteMessage(ctx context.Context, userID, messageID uuid.UUID) (uuid.UUID, error) {
	var senderID, convID uuid.UUID
	err := s.db.QueryRow(ctx, `SELECT sender_id, conversation_id FROM messages WHERE id = $1`, messageID).Scan(&senderID, &convID)
	if err != nil {
		return uuid.Nil, errors.New("message not found")
	}
	if senderID != userID {
		return uuid.Nil, errors.New("only the sender can delete this message")
	}

	_, err = s.db.Exec(ctx, `DELETE FROM messages WHERE id = $1`, messageID)
	if err != nil {
		return uuid.Nil, fmt.Errorf("failed to delete message: %w", err)
	}
	return convID, nil
}

// ToggleReaction adds or removes an emoji reaction from a user on a message.
func (s *ChatService) ToggleReaction(ctx context.Context, userID, messageID uuid.UUID, emoji string) ([]models.MessageReaction, error) {
	// Verify user has access to message's conversation
	var convID uuid.UUID
	err := s.db.QueryRow(ctx, `SELECT conversation_id FROM messages WHERE id = $1`, messageID).Scan(&convID)
	if err != nil {
		return nil, errors.New("message not found")
	}

	var exists bool
	err = s.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM message_reactions WHERE message_id = $1 AND user_id = $2 AND emoji = $3)`, messageID, userID, emoji).Scan(&exists)
	if err == nil && exists {
		_, _ = s.db.Exec(ctx, `DELETE FROM message_reactions WHERE message_id = $1 AND user_id = $2 AND emoji = $3`, messageID, userID, emoji)
	} else {
		_, _ = s.db.Exec(ctx, `INSERT INTO message_reactions (message_id, user_id, emoji) VALUES ($1, $2, $3)`, messageID, userID, emoji)
	}

	return s.getReactions(ctx, messageID)
}

// GetMessageByID retrieves a single message complete with sender, attachments, reply snippet, and reactions.
func (s *ChatService) GetMessageByID(ctx context.Context, messageID uuid.UUID) (*models.Message, error) {
	var msg models.Message
	sender := &models.UserPublic{}
	err := s.db.QueryRow(ctx, `
		SELECT m.id, m.conversation_id, m.sender_id, m.content, m.content_type,
		       COALESCE(m.language, ''), m.is_edited, m.reply_to_id, m.created_at, m.updated_at,
		       u.id, u.username, u.email, COALESCE(u.avatar_url, ''), u.status, u.created_at
		FROM messages m
		JOIN users u ON u.id = m.sender_id
		WHERE m.id = $1
	`, messageID).Scan(&msg.ID, &msg.ConversationID, &msg.SenderID, &msg.Content,
		&msg.ContentType, &msg.Language, &msg.IsEdited, &msg.ReplyToID, &msg.CreatedAt, &msg.UpdatedAt,
		&sender.ID, &sender.Username, &sender.Email, &sender.AvatarURL, &sender.Status, &sender.CreatedAt)
	if err != nil {
		return nil, err
	}
	msg.Sender = sender
	if msg.ContentType == "file" || msg.ContentType == "image" {
		msg.Attachments, _ = s.getAttachments(ctx, msg.ID)
	}
	msg.ReplyTo = s.getReplyToSnippet(ctx, msg.ReplyToID)
	msg.Reactions, _ = s.getReactions(ctx, msg.ID)
	return &msg, nil
}
