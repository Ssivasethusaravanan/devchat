package websocket

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"codertalk-backend/internal/middleware"
	"codertalk-backend/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

const (
	// Time allowed to write a message to the peer.
	writeWait = 10 * time.Second

	// Time allowed to read the next pong message from the peer.
	pongWait = 60 * time.Second

	// Send pings to peer with this period. Must be less than pongWait.
	pingPeriod = (pongWait * 9) / 10

	// Maximum message size allowed from peer.
	maxMessageSize = 65536 // 64KB
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins in development
	},
}

// Client represents a single WebSocket connection.
type Client struct {
	hub         *Hub
	conn        *websocket.Conn
	send        chan []byte
	UserID      uuid.UUID
	Username    string
	chatService *services.ChatService
}

// ServeWS handles WebSocket upgrade requests.
// Authenticates via ?token=<jwt> query parameter.
func ServeWS(hub *Hub, chatService *services.ChatService, jwtSecret string, c *gin.Context) {
	// Authenticate via query parameter
	tokenString := c.Query("token")
	if tokenString == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Token required"})
		return
	}

	// Parse JWT
	claims := &middleware.JWTClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(jwtSecret), nil
	})
	if err != nil || !token.Valid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
		return
	}

	// Upgrade to WebSocket
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("❌ WebSocket upgrade failed: %v", err)
		return
	}

	client := &Client{
		hub:         hub,
		conn:        conn,
		send:        make(chan []byte, 256),
		UserID:      claims.UserID,
		Username:    claims.Username,
		chatService: chatService,
	}

	// Register client
	hub.register <- client

	// Auto-join all user's conversation rooms
	go func() {
		ctx := context.Background()
		conversations, err := chatService.GetConversations(ctx, client.UserID)
		if err != nil {
			log.Printf("⚠️ Failed to get conversations for auto-join: %v", err)
			return
		}
		convIDs := make([]uuid.UUID, len(conversations))
		for i, conv := range conversations {
			convIDs[i] = conv.ID
		}
		hub.JoinUserRooms(client.UserID, convIDs)
	}()

	// Start read and write pumps
	go client.writePump()
	go client.readPump()
}

// readPump pumps messages from the WebSocket connection to the hub.
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()

		// Set user status to offline
		if !c.hub.IsUserOnline(c.UserID) {
			// User has disconnected all connections
		}
	}()

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, rawMessage, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("⚠️ WebSocket error for %s: %v", c.Username, err)
			}
			break
		}

		// Parse the incoming message
		var wsMsg WSMessage
		if err := json.Unmarshal(rawMessage, &wsMsg); err != nil {
			log.Printf("⚠️ Invalid message from %s: %v", c.Username, err)
			c.sendError("Invalid message format")
			continue
		}

		// Handle based on message type
		c.handleMessage(&wsMsg)
	}
}

// writePump pumps messages from the hub to the WebSocket connection.
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// The hub closed the channel
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Flush queued messages
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte("\n"))
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// handleMessage routes incoming WebSocket messages to appropriate handlers.
func (c *Client) handleMessage(wsMsg *WSMessage) {
	switch wsMsg.Type {
	case TypeMessage:
		c.handleNewMessage(wsMsg)
	case TypeTyping:
		c.handleTyping(wsMsg, true)
	case TypeStopTyping:
		c.handleTyping(wsMsg, false)
	case TypeJoinRoom:
		c.handleJoinRoom(wsMsg)
	case TypeReadReceipt:
		c.handleReadReceipt(wsMsg)
	default:
		c.sendError("Unknown message type: " + wsMsg.Type)
	}
}

// handleNewMessage processes a new chat message.
func (c *Client) handleNewMessage(wsMsg *WSMessage) {
	var payload MessagePayload
	if err := json.Unmarshal(wsMsg.Payload, &payload); err != nil {
		c.sendError("Invalid message payload")
		return
	}

	convID, err := uuid.Parse(wsMsg.ConversationID)
	if err != nil {
		c.sendError("Invalid conversation ID")
		return
	}

	ctx := context.Background()

	// Save message to database
	msg, err := c.chatService.SaveMessage(ctx, convID, c.UserID, payload.Content, payload.ContentType, payload.Language)
	if err != nil {
		log.Printf("❌ Failed to save message: %v", err)
		c.sendError("Failed to send message")
		return
	}

	// If there's an attachment, save it too
	if payload.R2Key != "" {
		att, err := c.chatService.SaveAttachment(ctx, msg.ID, payload.FileName, payload.FileSize, payload.MimeType, payload.R2Key)
		if err != nil {
			log.Printf("⚠️ Failed to save attachment: %v", err)
		} else {
			msg.Attachments = append(msg.Attachments, *att)
		}
	}

	// Create broadcast message
	broadcast := MessageBroadcast{Message: *msg}
	outMsg, err := NewWSMessage(TypeMessage, wsMsg.ConversationID, broadcast)
	if err != nil {
		log.Printf("❌ Failed to create broadcast: %v", err)
		return
	}

	outBytes, err := outMsg.Encode()
	if err != nil {
		return
	}

	// Broadcast to all users in the conversation
	c.hub.BroadcastToRoom(convID, outBytes, c.UserID)
}

// handleTyping broadcasts typing indicators (ephemeral, not persisted).
func (c *Client) handleTyping(wsMsg *WSMessage, isTyping bool) {
	convID, err := uuid.Parse(wsMsg.ConversationID)
	if err != nil {
		return
	}

	msgType := TypeTyping
	if !isTyping {
		msgType = TypeStopTyping
	}

	payload := TypingPayload{
		UserID:   c.UserID,
		Username: c.Username,
	}

	outMsg, err := NewWSMessage(msgType, wsMsg.ConversationID, payload)
	if err != nil {
		return
	}

	outBytes, err := outMsg.Encode()
	if err != nil {
		return
	}

	c.hub.BroadcastToRoom(convID, outBytes, c.UserID)
}

// handleJoinRoom processes room join requests.
func (c *Client) handleJoinRoom(wsMsg *WSMessage) {
	convID, err := uuid.Parse(wsMsg.ConversationID)
	if err != nil {
		c.sendError("Invalid conversation ID")
		return
	}

	c.hub.JoinRoom(convID, c.UserID)
}

// handleReadReceipt updates the read status for a conversation.
func (c *Client) handleReadReceipt(wsMsg *WSMessage) {
	convID, err := uuid.Parse(wsMsg.ConversationID)
	if err != nil {
		return
	}

	ctx := context.Background()
	// Update read receipt by loading messages (which updates the read_receipt)
	_, _ = c.chatService.GetMessages(ctx, convID, c.UserID, 1, 1)
}

// sendError sends an error message to the client.
func (c *Client) sendError(message string) {
	errPayload := ErrorPayload{Message: message}
	outMsg, err := NewWSMessage(TypeError, "", errPayload)
	if err != nil {
		return
	}
	outBytes, _ := outMsg.Encode()
	select {
	case c.send <- outBytes:
	default:
	}
}
