package handlers

import (
	"net/http"
	"strconv"

	"codertalk-backend/internal/middleware"
	"codertalk-backend/internal/models"
	"codertalk-backend/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ChatHandler handles conversation and message endpoints.
type ChatHandler struct {
	chatService *services.ChatService
}

// NewChatHandler creates a new ChatHandler.
func NewChatHandler(chatService *services.ChatService) *ChatHandler {
	return &ChatHandler{chatService: chatService}
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
