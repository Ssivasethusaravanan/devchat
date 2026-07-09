package websocket

import (
	"encoding/json"
	"time"

	"codertalk-backend/internal/models"

	"github.com/google/uuid"
)

// WebSocket message types
const (
	TypeMessage         = "message"
	TypeMessageEdited   = "message_edited"
	TypeMessageDeleted  = "message_deleted"
	TypeMessageReaction = "message_reaction"
	TypeMessageStatus   = "message_status"
	TypeTyping          = "typing"
	TypeStopTyping      = "stop_typing"
	TypeReadReceipt     = "read_receipt"
	TypeJoinRoom        = "join_room"
	TypeLeaveRoom       = "leave_room"
	TypeUserOnline      = "user_online"
	TypeUserOffline     = "user_offline"
	TypeError           = "error"
	TypeAck             = "ack"
	TypePing            = "ping"
	TypePong            = "pong"
)

// WSMessage is the envelope for all WebSocket communication.
type WSMessage struct {
	Type           string          `json:"type"`
	ConversationID string          `json:"conversation_id,omitempty"`
	Payload        json.RawMessage `json:"payload,omitempty"`
	Timestamp      time.Time       `json:"timestamp"`
}

// UnmarshalJSON implements custom JSON unmarshaling with resilient timestamp parsing.
func (m *WSMessage) UnmarshalJSON(data []byte) error {
	type Alias WSMessage
	aux := &struct {
		Timestamp string `json:"timestamp"`
		*Alias
	}{
		Alias: (*Alias)(m),
	}
	if err := json.Unmarshal(data, &aux); err != nil {
		return err
	}
	if aux.Timestamp != "" {
		t, err := time.Parse(time.RFC3339Nano, aux.Timestamp)
		if err != nil {
			t, err = time.Parse("2006-01-02T15:04:05.999999999", aux.Timestamp)
		}
		if err == nil {
			m.Timestamp = t
		} else {
			m.Timestamp = time.Now()
		}
	} else {
		m.Timestamp = time.Now()
	}
	return nil
}

// MessagePayload is the payload for a new chat message.
type MessagePayload struct {
	Content      string     `json:"content"`
	ContentType  string     `json:"content_type"`
	Language     string     `json:"language,omitempty"`
	ReplyToID    *uuid.UUID `json:"reply_to_id,omitempty"`
	AttachmentID string     `json:"attachment_id,omitempty"`
	FileName     string     `json:"file_name,omitempty"`
	FileSize     int64      `json:"file_size,omitempty"`
	MimeType     string     `json:"mime_type,omitempty"`
	R2Key        string     `json:"r2_key,omitempty"`
}

// MessageBroadcast is sent to all clients in a conversation when a new message arrives.
type MessageBroadcast struct {
	Message models.Message `json:"message"`
}

// MessageEditedBroadcast is sent when a message is edited.
type MessageEditedBroadcast struct {
	Message models.Message `json:"message"`
}

// MessageDeletedBroadcast is sent when a message is deleted.
type MessageDeletedBroadcast struct {
	MessageID      uuid.UUID `json:"message_id"`
	ConversationID uuid.UUID `json:"conversation_id"`
}

// MessageReactionBroadcast is sent when a reaction is toggled on a message.
type MessageReactionBroadcast struct {
	MessageID      uuid.UUID                `json:"message_id"`
	ConversationID uuid.UUID                `json:"conversation_id"`
	Reactions      []models.MessageReaction `json:"reactions"`
}

// TypingPayload is the payload for typing indicators.
type TypingPayload struct {
	UserID   uuid.UUID `json:"user_id"`
	Username string    `json:"username"`
}

// UserPresencePayload is broadcast when a user comes online or goes offline.
type UserPresencePayload struct {
	UserID   uuid.UUID  `json:"user_id"`
	Status   string     `json:"status"` // online or offline
	LastSeen *time.Time `json:"last_seen,omitempty"`
}

// ReadReceiptPayload is broadcast when a user reads messages in a conversation.
type ReadReceiptPayload struct {
	ConversationID uuid.UUID  `json:"conversation_id"`
	UserID         uuid.UUID  `json:"user_id"`
	ReadAt         time.Time  `json:"read_at"`
	UpToMessageID  *uuid.UUID `json:"up_to_message_id,omitempty"`
}

// MessageStatusPayload is broadcast when a message changes status (sent -> delivered -> read).
type MessageStatusPayload struct {
	MessageID      uuid.UUID `json:"message_id"`
	ConversationID uuid.UUID `json:"conversation_id"`
	Status         string    `json:"status"`
}

// ErrorPayload is sent when an error occurs during WebSocket processing.
type ErrorPayload struct {
	Message string `json:"message"`
}

// NewWSMessage creates a new WSMessage with the current timestamp.
func NewWSMessage(msgType string, conversationID string, payload interface{}) (*WSMessage, error) {
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	return &WSMessage{
		Type:           msgType,
		ConversationID: conversationID,
		Payload:        payloadBytes,
		Timestamp:      time.Now(),
	}, nil
}

// Encode serializes a WSMessage to JSON bytes.
func (m *WSMessage) Encode() ([]byte, error) {
	return json.Marshal(m)
}
