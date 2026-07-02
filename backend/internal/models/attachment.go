package models

import (
	"time"

	"github.com/google/uuid"
)

// Attachment represents a file attached to a message, stored in R2.
type Attachment struct {
	ID        uuid.UUID `json:"id"`
	MessageID uuid.UUID `json:"message_id"`
	FileName  string    `json:"file_name"`
	FileSize  int64     `json:"file_size"`
	MimeType  string    `json:"mime_type"`
	R2Key     string    `json:"r2_key"`
	CreatedAt time.Time `json:"created_at"`
}

// PresignUploadRequest is the payload for requesting a presigned upload URL.
type PresignUploadRequest struct {
	FileName    string `json:"file_name" binding:"required"`
	ContentType string `json:"content_type" binding:"required"`
	FileSize    int64  `json:"file_size" binding:"required"`
}

// PresignUploadResponse contains the presigned URL and the R2 key.
type PresignUploadResponse struct {
	UploadURL string `json:"upload_url"`
	R2Key     string `json:"r2_key"`
}

// APIResponse is the standard API response wrapper.
type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
	Message string      `json:"message,omitempty"`
}
