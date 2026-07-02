package models

import (
	"time"

	"github.com/google/uuid"
)

// Conversation represents either a direct message or group conversation.
type Conversation struct {
	ID          uuid.UUID    `json:"id"`
	Type        string       `json:"type"` // "direct" or "group"
	Name        string       `json:"name,omitempty"`
	Description string       `json:"description,omitempty"`
	AvatarURL   string       `json:"avatar_url,omitempty"`
	CreatedBy   uuid.UUID    `json:"created_by"`
	CreatedAt   time.Time    `json:"created_at"`
	UpdatedAt   time.Time    `json:"updated_at"`
	Members     []UserPublic `json:"members,omitempty"`
	LastMessage *Message     `json:"last_message,omitempty"`
	UnreadCount int          `json:"unread_count"`
}

// ConversationMember represents a user's membership in a conversation.
type ConversationMember struct {
	ID             uuid.UUID `json:"id"`
	ConversationID uuid.UUID `json:"conversation_id"`
	UserID         uuid.UUID `json:"user_id"`
	Role           string    `json:"role"` // "admin" or "member"
	JoinedAt       time.Time `json:"joined_at"`
}

// CreateGroupRequest represents the payload for creating a group.
type CreateGroupRequest struct {
	Name        string   `json:"name" binding:"required,min=1,max=100"`
	Description string   `json:"description,omitempty"`
	Members     []string `json:"members"` // Usernames to add
}

// UpdateGroupRequest represents the payload for updating a group.
type UpdateGroupRequest struct {
	Name        string `json:"name,omitempty"`
	Description string `json:"description,omitempty"`
}

// AddMemberRequest represents the payload for adding a member.
type AddMemberRequest struct {
	Username string `json:"username" binding:"required"`
}
