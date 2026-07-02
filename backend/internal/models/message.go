package models

import (
	"time"

	"github.com/google/uuid"
)

// Message represents a chat message in a conversation.
type Message struct {
	ID             uuid.UUID    `json:"id"`
	ConversationID uuid.UUID    `json:"conversation_id"`
	SenderID       uuid.UUID    `json:"sender_id"`
	Content        string       `json:"content"`
	ContentType    string       `json:"content_type"` // text, code, json, file, image
	Language       string       `json:"language,omitempty"`
	IsEdited       bool         `json:"is_edited"`
	CreatedAt      time.Time    `json:"created_at"`
	UpdatedAt      time.Time    `json:"updated_at"`
	Sender         *UserPublic  `json:"sender,omitempty"`
	Attachments    []Attachment `json:"attachments,omitempty"`
}

// SendMessageRequest represents the payload for sending a message via REST.
type SendMessageRequest struct {
	Content     string `json:"content" binding:"required"`
	ContentType string `json:"content_type" binding:"required,oneof=text code json file image"`
	Language    string `json:"language,omitempty"`
}

// MessageResponse wraps a message with pagination metadata.
type MessageListResponse struct {
	Messages   []Message `json:"messages"`
	TotalCount int       `json:"total_count"`
	Page       int       `json:"page"`
	PageSize   int       `json:"page_size"`
	HasMore    bool      `json:"has_more"`
}
