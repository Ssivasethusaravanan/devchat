package websocket

import (
	"log"
	"sync"

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
		clients:    make(map[uuid.UUID]map[*Client]bool),
		rooms:      make(map[uuid.UUID]map[uuid.UUID]bool),
		broadcast:  make(chan *BroadcastMessage, 256),
		register:   make(chan *Client),
		unregister: make(chan *Client),
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
			h.clients[client.UserID][client] = true
			h.mu.Unlock()
			log.Printf("👤 Client registered: %s (%s)", client.Username, client.UserID)

		case client := <-h.unregister:
			h.mu.Lock()
			if connections, ok := h.clients[client.UserID]; ok {
				delete(connections, client)
				if len(connections) == 0 {
					delete(h.clients, client.UserID)
					// Remove from all rooms
					for roomID, members := range h.rooms {
						delete(members, client.UserID)
						if len(members) == 0 {
							delete(h.rooms, roomID)
						}
					}
				}
			}
			close(client.send)
			h.mu.Unlock()
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
func (h *Hub) JoinUserRooms(userID uuid.UUID, conversationIDs []uuid.UUID) {
	h.mu.Lock()
	defer h.mu.Unlock()

	for _, convID := range conversationIDs {
		if _, ok := h.rooms[convID]; !ok {
			h.rooms[convID] = make(map[uuid.UUID]bool)
		}
		h.rooms[convID][userID] = true
	}
	log.Printf("🚪 User %s joined %d rooms", userID, len(conversationIDs))
}

// BroadcastToRoom sends a message to all users in a conversation.
func (h *Hub) BroadcastToRoom(conversationID uuid.UUID, message []byte, senderID uuid.UUID) {
	h.broadcast <- &BroadcastMessage{
		ConversationID: conversationID,
		Message:        message,
		SenderID:       senderID,
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
