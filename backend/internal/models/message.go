package models

import (
	"time"

	"github.com/google/uuid"
)

// MessageReplySnippet represents a lightweight preview of a replied message.
type MessageReplySnippet struct {
	ID          uuid.UUID `json:"id"`
	SenderID    uuid.UUID `json:"sender_id"`
	Username    string    `json:"username"`
	Content     string    `json:"content"`
	ContentType string    `json:"content_type"`
}

// MessageReaction represents an emoji reaction on a message.
type MessageReaction struct {
	ID        uuid.UUID `json:"id"`
	MessageID uuid.UUID `json:"message_id"`
	UserID    uuid.UUID `json:"user_id"`
	Username  string    `json:"username"`
	Emoji     string    `json:"emoji"`
	CreatedAt time.Time `json:"created_at"`
}

// Message represents a chat message in a conversation.
type Message struct {
	ID             uuid.UUID            `json:"id"`
	ConversationID uuid.UUID            `json:"conversation_id"`
	SenderID       uuid.UUID            `json:"sender_id"`
	Content        string               `json:"content"`
	ContentType    string               `json:"content_type"` // text, code, json, file, image
	Language       string               `json:"language,omitempty"`
	IsEdited       bool                 `json:"is_edited"`
	ReplyToID      *uuid.UUID           `json:"reply_to_id,omitempty"`
	ReplyTo        *MessageReplySnippet `json:"reply_to,omitempty"`
	Reactions      []MessageReaction    `json:"reactions,omitempty"`
	CreatedAt      time.Time            `json:"created_at"`
	UpdatedAt      time.Time            `json:"updated_at"`
	Sender         *UserPublic          `json:"sender,omitempty"`
	Attachments    []Attachment         `json:"attachments,omitempty"`
}

// SendMessageRequest represents the payload for sending a message via REST.
type SendMessageRequest struct {
	Content     string     `json:"content" binding:"required"`
	ContentType string     `json:"content_type" binding:"required,oneof=text code json file image"`
	Language    string     `json:"language,omitempty"`
	ReplyToID   *uuid.UUID `json:"reply_to_id,omitempty"`
}

// EditMessageRequest represents editing message text content.
type EditMessageRequest struct {
	Content string `json:"content" binding:"required"`
}

// ToggleReactionRequest represents toggling a reaction emoji.
type ToggleReactionRequest struct {
	Emoji string `json:"emoji" binding:"required"`
}

// MessageListResponse wraps a message with pagination metadata.
type MessageListResponse struct {
	Messages   []Message `json:"messages"`
	TotalCount int       `json:"total_count"`
	Page       int       `json:"page"`
	PageSize   int       `json:"page_size"`
	HasMore    bool      `json:"has_more"`
}
