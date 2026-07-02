package handlers

import (
	"net/http"
	"strconv"

	"codertalk-backend/internal/middleware"
	"codertalk-backend/internal/models"
	"codertalk-backend/internal/services"
	ws "codertalk-backend/internal/websocket"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ChatHandler handles conversation and message endpoints.
type ChatHandler struct {
	chatService *services.ChatService
	hub         *ws.Hub
}

// NewChatHandler creates a new ChatHandler.
func NewChatHandler(chatService *services.ChatService, hub *ws.Hub) *ChatHandler {
	return &ChatHandler{chatService: chatService, hub: hub}
}

// GetConversations returns all conversations for the authenticated user.
// GET /api/conversations
func (h *ChatHandler) GetConversations(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	conversations, err := h.chatService.GetConversations(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Error:   "Failed to get conversations",
		})
		return
	}

	if conversations == nil {
		conversations = []models.Conversation{}
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    conversations,
	})
}

// GetOrCreateDM starts or retrieves an existing DM with another user.
// POST /api/conversations/dm/:user_id
func (h *ChatHandler) GetOrCreateDM(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	otherUserIDStr := c.Param("user_id")
	otherUserID, err := uuid.Parse(otherUserIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid user ID",
		})
		return
	}

	conv, err := h.chatService.GetOrCreateDM(c.Request.Context(), userID, otherUserID)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    conv,
	})
}

// GetMessages returns paginated messages for a conversation.
// GET /api/conversations/:id/messages?page=1&limit=50
func (h *ChatHandler) GetMessages(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	convIDStr := c.Param("id")
	convID, err := uuid.Parse(convIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid conversation ID",
		})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 50
	}

	messages, err := h.chatService.GetMessages(c.Request.Context(), convID, userID, page, limit)
	if err != nil {
		c.JSON(http.StatusForbidden, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    messages,
	})
}

// EditMessage edits a message text content.
// PUT /api/messages/:id
func (h *ChatHandler) EditMessage(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	msgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: "Invalid message ID"})
		return
	}

	var req models.EditMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: "Content is required"})
		return
	}

	msg, err := h.chatService.EditMessage(c.Request.Context(), userID, msgID, req.Content)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: err.Error()})
		return
	}

	// Broadcast via WebSocket
	if h.hub != nil {
		broadcast := ws.MessageEditedBroadcast{Message: *msg}
		if outMsg, err := ws.NewWSMessage(ws.TypeMessageEdited, msg.ConversationID.String(), broadcast); err == nil {
			if outBytes, err := outMsg.Encode(); err == nil {
				h.hub.BroadcastToRoom(msg.ConversationID, outBytes, uuid.Nil)
			}
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: msg})
}

// DeleteMessage deletes a message.
// DELETE /api/messages/:id
func (h *ChatHandler) DeleteMessage(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	msgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: "Invalid message ID"})
		return
	}

	convID, err := h.chatService.DeleteMessage(c.Request.Context(), userID, msgID)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: err.Error()})
		return
	}

	// Broadcast via WebSocket
	if h.hub != nil {
		broadcast := ws.MessageDeletedBroadcast{MessageID: msgID, ConversationID: convID}
		if outMsg, err := ws.NewWSMessage(ws.TypeMessageDeleted, convID.String(), broadcast); err == nil {
			if outBytes, err := outMsg.Encode(); err == nil {
				h.hub.BroadcastToRoom(convID, outBytes, uuid.Nil)
			}
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Message deleted successfully"})
}

// ToggleReaction toggles an emoji reaction on a message.
// POST /api/messages/:id/reactions
func (h *ChatHandler) ToggleReaction(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	msgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: "Invalid message ID"})
		return
	}

	var req models.ToggleReactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: "Emoji is required"})
		return
	}

	reactions, err := h.chatService.ToggleReaction(c.Request.Context(), userID, msgID, req.Emoji)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: err.Error()})
		return
	}

	// Get message to know convID for broadcasting
	if msg, err := h.chatService.GetMessageByID(c.Request.Context(), msgID); err == nil && h.hub != nil {
		broadcast := ws.MessageReactionBroadcast{MessageID: msgID, ConversationID: msg.ConversationID, Reactions: reactions}
		if outMsg, err := ws.NewWSMessage(ws.TypeMessageReaction, msg.ConversationID.String(), broadcast); err == nil {
			if outBytes, err := outMsg.Encode(); err == nil {
				h.hub.BroadcastToRoom(msg.ConversationID, outBytes, uuid.Nil)
			}
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: reactions})
}
