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

	// Maximum message size allowed from peer (10MB to support large code snippets).
	maxMessageSize = 10485760 // 10MB
)

// newUpgrader creates a WebSocket upgrader with origin checking based on allowed origins.
func newUpgrader(allowedOrigins []string) websocket.Upgrader {
	originSet := make(map[string]bool, len(allowedOrigins))
	for _, o := range allowedOrigins {
		originSet[o] = true
	}

	return websocket.Upgrader{
		ReadBufferSize:  4096,
		WriteBufferSize: 4096,
		CheckOrigin: func(r *http.Request) bool {
			origin := r.Header.Get("Origin")
			if origin == "" {
				// No origin header = non-browser client (mobile), allow
				return true
			}
			return originSet[origin]
		},
	}
}

// Client represents a single WebSocket connection.
type Client struct {
	hub          *Hub
	conn         *websocket.Conn
	send         chan []byte
	UserID       uuid.UUID
	Username     string
	HideLastSeen bool
	Rooms        []uuid.UUID
	chatService  *services.ChatService
}

// ServeWS handles WebSocket upgrade requests.
// Authenticates via:
// 1. "access_token" cookie (web clients — browser sends cookies automatically)
// 2. ?token=<jwt> query parameter (mobile clients)
func ServeWS(hub *Hub, chatService *services.ChatService, jwtSecret string, allowedOrigins []string, c *gin.Context) {
	var tokenString string

	// Strategy 1: Try to read JWT from the access_token HttpOnly cookie
	if cookie, err := c.Cookie("access_token"); err == nil && cookie != "" {
		tokenString = cookie
	}

	// Strategy 2: Fall back to query parameter (mobile clients)
	if tokenString == "" {
		tokenString = c.Query("token")
	}

	if tokenString == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Authentication required"})
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

	// Upgrade to WebSocket with origin checking
	upgrader := newUpgrader(allowedOrigins)
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("❌ WebSocket upgrade failed: %v", err)
		return
	}

	ctx := context.Background()
	var rooms []uuid.UUID
	var hideLastSeen bool
	if chatService != nil {
		conversations, err := chatService.GetConversations(ctx, claims.UserID)
		if err == nil {
			rooms = make([]uuid.UUID, len(conversations))
			for i, conv := range conversations {
				rooms[i] = conv.ID
			}
		}
		hideLastSeen = chatService.GetHideLastSeen(ctx, claims.UserID)
	}

	client := &Client{
		hub:          hub,
		conn:         conn,
		send:         make(chan []byte, 256),
		UserID:       claims.UserID,
		Username:     claims.Username,
		HideLastSeen: hideLastSeen,
		Rooms:        rooms,
		chatService:  chatService,
	}

	// Register client
	hub.register <- client

	// Start read and write pumps
	go client.writePump()
	go client.readPump()
}

// readPump pumps messages from the WebSocket connection to the hub.
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
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

		// Extend the read deadline whenever ANY message is received to prevent unexpected disconnects.
		c.conn.SetReadDeadline(time.Now().Add(pongWait))

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
	case TypePing:
		c.send <- []byte(`{"type":"pong"}`)
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
	msg, err := c.chatService.SaveMessage(ctx, convID, c.UserID, payload.Content, payload.ContentType, payload.Language, payload.ReplyToID)
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

	// If any peer in the room is online, mark message delivered
	if c.hub.HasOtherOnlineMembers(convID, c.UserID) {
		_ = c.chatService.UpdateMessageStatus(ctx, msg.ID, "delivered")
		msg.Status = "delivered"
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

	// Ensure all conversation members are joined to this room in the hub before broadcasting
	if memberIDs, err := c.chatService.GetConversationMemberIDs(ctx, convID); err == nil {
		for _, memberID := range memberIDs {
			c.hub.JoinRoom(convID, memberID)
		}
	} else {
		c.hub.JoinRoom(convID, c.UserID)
	}

	// Broadcast to all users in the conversation
	c.hub.BroadcastToRoom(convID, outBytes, c.UserID)
}

// handleTyping routes typing indicators through server-owned TypingManager.
func (c *Client) handleTyping(wsMsg *WSMessage, isTyping bool) {
	convID, err := uuid.Parse(wsMsg.ConversationID)
	if err != nil {
		return
	}

	if isTyping {
		c.hub.TypingManager.StartTyping(convID, c.UserID, c.Username, c.hub)
	} else {
		c.hub.TypingManager.StopTyping(convID, c.UserID, c.hub)
	}
}

// handleJoinRoom processes room join requests.
func (c *Client) handleJoinRoom(wsMsg *WSMessage) {
	convID, err := uuid.Parse(wsMsg.ConversationID)
	if err != nil {
		c.sendError("Invalid conversation ID")
		return
	}

	c.Rooms = append(c.Rooms, convID)
	c.hub.JoinRoom(convID, c.UserID)
}

// handleReadReceipt updates the read status for a conversation up to optional cursor.
func (c *Client) handleReadReceipt(wsMsg *WSMessage) {
	convID, err := uuid.Parse(wsMsg.ConversationID)
	if err != nil {
		return
	}

	var req struct {
		UpToMessageID *uuid.UUID `json:"up_to_message_id"`
	}
	_ = json.Unmarshal(wsMsg.Payload, &req)

	ctx := context.Background()
	_ = c.chatService.MarkConversationRead(ctx, convID, c.UserID, req.UpToMessageID)

	payload := ReadReceiptPayload{
		ConversationID: convID,
		UserID:         c.UserID,
		ReadAt:         time.Now().UTC(),
		UpToMessageID:  req.UpToMessageID,
	}
	if outMsg, err := NewWSMessage(TypeReadReceipt, wsMsg.ConversationID, payload); err == nil {
		if outBytes, err := outMsg.Encode(); err == nil {
			c.hub.BroadcastToRoom(convID, outBytes, c.UserID)
		}
	}
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
