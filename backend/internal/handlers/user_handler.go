package handlers

import (
	"net/http"

	"codertalk-backend/internal/middleware"
	"codertalk-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// UserHandler handles user-related endpoints.
type UserHandler struct {
	db *pgxpool.Pool
}

// NewUserHandler creates a new UserHandler.
func NewUserHandler(db *pgxpool.Pool) *UserHandler {
	return &UserHandler{db: db}
}

// SearchUsers searches users by username prefix.
// GET /api/users/search?q=<query>
func (h *UserHandler) SearchUsers(c *gin.Context) {
	query := c.Query("q")
	if len(query) < 1 {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Search query must be at least 1 character",
		})
		return
	}

	currentUserID, _ := middleware.GetUserID(c)

	rows, err := h.db.Query(c.Request.Context(), `
		SELECT id, username, email, COALESCE(avatar_url, ''), status, created_at
		FROM users
		WHERE username ILIKE $1 AND id != $2 AND is_verified = TRUE
		ORDER BY username ASC
		LIMIT 20
	`, query+"%", currentUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Error:   "Failed to search users",
		})
		return
	}
	defer rows.Close()

	var users []models.UserPublic
	for rows.Next() {
		var u models.UserPublic
		if err := rows.Scan(&u.ID, &u.Username, &u.Email, &u.AvatarURL, &u.Status, &u.CreatedAt); err != nil {
			continue
		}
		users = append(users, u)
	}

	if users == nil {
		users = []models.UserPublic{}
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    users,
	})
}

// GetUser returns a user's public profile.
// GET /api/users/:id
func (h *UserHandler) GetUser(c *gin.Context) {
	userIDStr := c.Param("id")

	var user models.UserPublic
	err := h.db.QueryRow(c.Request.Context(), `
		SELECT id, username, email, COALESCE(avatar_url, ''), status, created_at
		FROM users WHERE id = $1
	`, userIDStr).Scan(&user.ID, &user.Username, &user.Email, &user.AvatarURL, &user.Status, &user.CreatedAt)
	if err != nil {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Success: false,
			Error:   "User not found",
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    user,
	})
}

// GetOnlineUsers returns all currently online users.
// GET /api/users/online
func (h *UserHandler) GetOnlineUsers(c *gin.Context) {
	rows, err := h.db.Query(c.Request.Context(), `
		SELECT id, username, email, COALESCE(avatar_url, ''), status, created_at
		FROM users WHERE status = 'online' AND is_verified = TRUE
		ORDER BY username ASC
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Error:   "Failed to get online users",
		})
		return
	}
	defer rows.Close()

	var users []models.UserPublic
	for rows.Next() {
		var u models.UserPublic
		if err := rows.Scan(&u.ID, &u.Username, &u.Email, &u.AvatarURL, &u.Status, &u.CreatedAt); err != nil {
			continue
		}
		users = append(users, u)
	}

	if users == nil {
		users = []models.UserPublic{}
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    users,
	})
}
