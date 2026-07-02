package handlers

import (
	"net/http"

	"codertalk-backend/internal/middleware"
	"codertalk-backend/internal/models"
	"codertalk-backend/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// GroupHandler handles group conversation endpoints.
type GroupHandler struct {
	groupService *services.GroupService
}

// NewGroupHandler creates a new GroupHandler.
func NewGroupHandler(groupService *services.GroupService) *GroupHandler {
	return &GroupHandler{groupService: groupService}
}

// CreateGroup creates a new group conversation.
// POST /api/groups
func (h *GroupHandler) CreateGroup(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	var req models.CreateGroupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	group, err := h.groupService.CreateGroup(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, models.APIResponse{
		Success: true,
		Data:    group,
	})
}

// GetGroup returns group details.
// GET /api/groups/:id
func (h *GroupHandler) GetGroup(c *gin.Context) {
	groupIDStr := c.Param("id")
	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid group ID",
		})
		return
	}

	group, err := h.groupService.GetGroup(c.Request.Context(), groupID)
	if err != nil {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    group,
	})
}

// UpdateGroup updates group details.
// PUT /api/groups/:id
func (h *GroupHandler) UpdateGroup(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	groupIDStr := c.Param("id")
	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid group ID",
		})
		return
	}

	var req models.UpdateGroupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	group, err := h.groupService.UpdateGroup(c.Request.Context(), groupID, userID, req)
	if err != nil {
		c.JSON(http.StatusForbidden, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    group,
	})
}

// AddMember adds a user to a group by username.
// POST /api/groups/:id/members
func (h *GroupHandler) AddMember(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	groupIDStr := c.Param("id")
	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid group ID",
		})
		return
	}

	var req models.AddMemberRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	if err := h.groupService.AddMember(c.Request.Context(), groupID, userID, req.Username); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Member added successfully",
	})
}

// RemoveMember removes a user from a group.
// DELETE /api/groups/:id/members/:user_id
func (h *GroupHandler) RemoveMember(c *gin.Context) {
	requesterID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	groupIDStr := c.Param("id")
	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid group ID",
		})
		return
	}

	memberIDStr := c.Param("user_id")
	memberID, err := uuid.Parse(memberIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid member ID",
		})
		return
	}

	if err := h.groupService.RemoveMember(c.Request.Context(), groupID, requesterID, memberID); err != nil {
		c.JSON(http.StatusForbidden, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Member removed successfully",
	})
}
