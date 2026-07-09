package websocket

import (
	"context"
	"log"
	"sync"
	"time"

	"codertalk-backend/internal/models"

	"github.com/google/uuid"
)

// Hub maintains the set of active clients and broadcasts messages to rooms.
type Hub struct {
	// Registered clients mapped by user ID (one user can have multiple connections)
	clients map[uuid.UUID]map[*Client]bool

	// Room subscriptions: conversation_id -> set of user_ids
	rooms map[uuid.UUID]map[uuid.UUID]bool

	// Inbound messages from clients to be broadcast
	broadcast chan *BroadcastMessage

	// Register requests from clients
	register chan *Client

	// Unregister requests from clients
	unregister chan *Client

	TypingManager *TypingManager

	mu sync.RWMutex
}

// BroadcastMessage contains a message and its target conversation.
type BroadcastMessage struct {
	ConversationID uuid.UUID
	Message        []byte
	SenderID       uuid.UUID // Exclude sender from receiving their own message
}

// NewHub creates a new Hub instance.
func NewHub() *Hub {
	return &Hub{
		clients:       make(map[uuid.UUID]map[*Client]bool),
		rooms:         make(map[uuid.UUID]map[uuid.UUID]bool),
		broadcast:     make(chan *BroadcastMessage, 256),
		register:      make(chan *Client),
		unregister:    make(chan *Client),
		TypingManager: NewTypingManager(),
	}
}

// Run starts the hub's main event loop. Must be run as a goroutine.
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			if _, ok := h.clients[client.UserID]; !ok {
				h.clients[client.UserID] = make(map[*Client]bool)
			}
			connections := h.clients[client.UserID]
			wentOnline := len(connections) == 0
			h.clients[client.UserID][client] = true

			for _, convID := range client.Rooms {
				if _, ok := h.rooms[convID]; !ok {
					h.rooms[convID] = make(map[uuid.UUID]bool)
				}
				h.rooms[convID][client.UserID] = true
			}
			h.mu.Unlock()
			log.Printf("👤 Client registered: %s (%s)", client.Username, client.UserID)

			if wentOnline && client.chatService != nil {
				go func(userID uuid.UUID, hide bool) {
					ctx := context.Background()
					_ = client.chatService.SetUserOnline(ctx, userID)
					rooms, err := client.chatService.GetUserConversationIDs(ctx, userID)
					if err == nil {
						for _, convID := range rooms {
							h.BroadcastPresenceToRoom(convID, userID, "online", nil, hide)
						}
					}
				}(client.UserID, client.HideLastSeen)
			}

		case client := <-h.unregister:
			h.TypingManager.StopAllTyping(client.UserID, h)
			h.mu.Lock()
			var wentOffline bool
			var userRooms []uuid.UUID
			if connections, ok := h.clients[client.UserID]; ok {
				delete(connections, client)
				if len(connections) == 0 {
					wentOffline = true
					delete(h.clients, client.UserID)
					// Collect rooms before removing
					for roomID, members := range h.rooms {
						if members[client.UserID] {
							userRooms = append(userRooms, roomID)
							delete(members, client.UserID)
							if len(members) == 0 {
								delete(h.rooms, roomID)
							}
						}
					}
				}
			}
			close(client.send)
			h.mu.Unlock()

			if wentOffline && client.chatService != nil {
				go func(userID uuid.UUID, hide bool) {
					ctx := context.Background()
					lastSeen, _ := client.chatService.SetUserOffline(ctx, userID)
					rooms, err := client.chatService.GetUserConversationIDs(ctx, userID)
					if err == nil {
						for _, convID := range rooms {
							h.BroadcastPresenceToRoom(convID, userID, "offline", lastSeen, hide)
						}
					}
				}(client.UserID, client.HideLastSeen)
			}
			log.Printf("👤 Client unregistered: %s (%s)", client.Username, client.UserID)

		case bm := <-h.broadcast:
			h.mu.RLock()
			// Get all users in the conversation room
			if members, ok := h.rooms[bm.ConversationID]; ok {
				for userID := range members {
					// Send to all connections of each user in the room
					if connections, ok := h.clients[userID]; ok {
						for client := range connections {
							select {
							case client.send <- bm.Message:
							default:
								// Client's send buffer is full, close the connection
								close(client.send)
								delete(connections, client)
							}
						}
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

// JoinRoom adds a user to a conversation room for real-time message delivery.
func (h *Hub) JoinRoom(conversationID, userID uuid.UUID) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if _, ok := h.rooms[conversationID]; !ok {
		h.rooms[conversationID] = make(map[uuid.UUID]bool)
	}
	h.rooms[conversationID][userID] = true
	log.Printf("🚪 User %s joined room %s", userID, conversationID)
}

// LeaveRoom removes a user from a conversation room.
func (h *Hub) LeaveRoom(conversationID, userID uuid.UUID) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if members, ok := h.rooms[conversationID]; ok {
		delete(members, userID)
		if len(members) == 0 {
			delete(h.rooms, conversationID)
		}
	}
}

// JoinUserRooms adds a user to all their conversation rooms (called on connect).
// Returns wentOnline=true if this is the user's first active connection.
func (h *Hub) JoinUserRooms(userID uuid.UUID, conversationIDs []uuid.UUID) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	for _, convID := range conversationIDs {
		if _, ok := h.rooms[convID]; !ok {
			h.rooms[convID] = make(map[uuid.UUID]bool)
		}
		h.rooms[convID][userID] = true
	}
	log.Printf("🚪 User %s joined %d rooms", userID, len(conversationIDs))

	connections := h.clients[userID]
	return len(connections) == 1
}

// BroadcastToRoom sends a message to all users in a conversation.
func (h *Hub) BroadcastToRoom(conversationID uuid.UUID, message []byte, senderID uuid.UUID) {
	h.broadcast <- &BroadcastMessage{
		ConversationID: conversationID,
		Message:        message,
		SenderID:       senderID,
	}
}

func statusToMsgType(status string) string {
	if status == "online" {
		return TypeUserOnline
	}
	return TypeUserOffline
}

// BroadcastPresenceToRoom broadcasts online/offline presence enforcing LastSeen reciprocity.
func (h *Hub) BroadcastPresenceToRoom(conversationID uuid.UUID, targetID uuid.UUID, status string, targetLastSeen *time.Time, targetHideLastSeen bool) {
	h.mu.RLock()
	members, ok := h.rooms[conversationID]
	if !ok {
		h.mu.RUnlock()
		return
	}
	memberIDs := make([]uuid.UUID, 0, len(members))
	for memberID := range members {
		if memberID != targetID {
			memberIDs = append(memberIDs, memberID)
		}
	}
	h.mu.RUnlock()

	for _, memberID := range memberIDs {
		h.mu.RLock()
		conns, ok := h.clients[memberID]
		if !ok {
			h.mu.RUnlock()
			continue
		}
		var showConns []*Client
		var hideConns []*Client
		for c := range conns {
			if c.HideLastSeen {
				hideConns = append(hideConns, c)
			} else {
				showConns = append(showConns, c)
			}
		}
		h.mu.RUnlock()

		if len(showConns) > 0 {
			resolved := models.ResolveLastSeen(false, targetHideLastSeen, targetLastSeen)
			payload := UserPresencePayload{
				UserID:   targetID,
				Status:   status,
				LastSeen: resolved,
			}
			if outMsg, err := NewWSMessage(statusToMsgType(status), conversationID.String(), payload); err == nil {
				if outBytes, err := outMsg.Encode(); err == nil {
					for _, c := range showConns {
						select {
						case c.send <- outBytes:
						default:
						}
					}
				}
			}
		}

		if len(hideConns) > 0 {
			resolved := models.ResolveLastSeen(true, targetHideLastSeen, targetLastSeen)
			payload := UserPresencePayload{
				UserID:   targetID,
				Status:   status,
				LastSeen: resolved,
			}
			if outMsg, err := NewWSMessage(statusToMsgType(status), conversationID.String(), payload); err == nil {
				if outBytes, err := outMsg.Encode(); err == nil {
					for _, c := range hideConns {
						select {
						case c.send <- outBytes:
						default:
						}
					}
				}
			}
		}
	}
}

// SendToUser sends a message directly to a specific user (all their connections).
func (h *Hub) SendToUser(userID uuid.UUID, message []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	if connections, ok := h.clients[userID]; ok {
		for client := range connections {
			select {
			case client.send <- message:
			default:
				close(client.send)
				delete(connections, client)
			}
		}
	}
}

// IsUserOnline checks if a user has any active connections.
func (h *Hub) IsUserOnline(userID uuid.UUID) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()

	connections, ok := h.clients[userID]
	return ok && len(connections) > 0
}

// GetOnlineUserIDs returns the IDs of all currently connected users.
func (h *Hub) GetOnlineUserIDs() []uuid.UUID {
	h.mu.RLock()
	defer h.mu.RUnlock()

	userIDs := make([]uuid.UUID, 0, len(h.clients))
	for userID := range h.clients {
		userIDs = append(userIDs, userID)
	}
	return userIDs
}

// GetUserRooms returns all conversation room IDs that a user has joined.
func (h *Hub) GetUserRooms(userID uuid.UUID) []uuid.UUID {
	h.mu.RLock()
	defer h.mu.RUnlock()

	var rooms []uuid.UUID
	for roomID, members := range h.rooms {
		if members[userID] {
			rooms = append(rooms, roomID)
		}
	}
	return rooms
}

// HasOtherOnlineMembers checks if any member in the room other than excludeUserID is currently online.
func (h *Hub) HasOtherOnlineMembers(roomID uuid.UUID, excludeUserID uuid.UUID) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()

	members, ok := h.rooms[roomID]
	if !ok {
		return false
	}
	for memberID := range members {
		if memberID != excludeUserID {
			if conns, active := h.clients[memberID]; active && len(conns) > 0 {
				return true
			}
		}
	}
	return false
}

// TypingManager tracks active typing timers per conversation per user.
type TypingManager struct {
	mu     sync.Mutex
	timers map[uuid.UUID]map[uuid.UUID]*time.Timer // convID -> userID -> timer
}

const typingTimeout = 5 * time.Second

func NewTypingManager() *TypingManager {
	return &TypingManager{
		timers: make(map[uuid.UUID]map[uuid.UUID]*time.Timer),
	}
}

func (tm *TypingManager) StartTyping(convID, userID uuid.UUID, username string, hub *Hub) {
	tm.mu.Lock()
	defer tm.mu.Unlock()

	if tm.timers[convID] == nil {
		tm.timers[convID] = make(map[uuid.UUID]*time.Timer)
	}

	if existing, ok := tm.timers[convID][userID]; ok {
		existing.Stop()
	} else {
		// First time -> broadcast typing start
		payload := TypingPayload{UserID: userID, Username: username}
		if outMsg, err := NewWSMessage(TypeTyping, convID.String(), payload); err == nil {
			if outBytes, err := outMsg.Encode(); err == nil {
				go hub.BroadcastToRoom(convID, outBytes, userID)
			}
		}
	}

	tm.timers[convID][userID] = time.AfterFunc(typingTimeout, func() {
		tm.StopTyping(convID, userID, hub)
	})
}

func (tm *TypingManager) StopTyping(convID, userID uuid.UUID, hub *Hub) {
	tm.mu.Lock()
	timer, ok := tm.timers[convID][userID]
	if ok {
		timer.Stop()
		delete(tm.timers[convID], userID)
	}
	tm.mu.Unlock()

	if ok {
		payload := TypingPayload{UserID: userID}
		if outMsg, err := NewWSMessage(TypeStopTyping, convID.String(), payload); err == nil {
			if outBytes, err := outMsg.Encode(); err == nil {
				hub.BroadcastToRoom(convID, outBytes, userID)
			}
		}
	}
}

func (tm *TypingManager) StopAllTyping(userID uuid.UUID, hub *Hub) {
	tm.mu.Lock()
	var toStop []uuid.UUID
	for convID, users := range tm.timers {
		if timer, ok := users[userID]; ok {
			timer.Stop()
			delete(users, userID)
			toStop = append(toStop, convID)
		}
	}
	tm.mu.Unlock()

	payload := TypingPayload{UserID: userID}
	for _, convID := range toStop {
		if outMsg, err := NewWSMessage(TypeStopTyping, convID.String(), payload); err == nil {
			if outBytes, err := outMsg.Encode(); err == nil {
				hub.BroadcastToRoom(convID, outBytes, userID)
			}
		}
	}
}
