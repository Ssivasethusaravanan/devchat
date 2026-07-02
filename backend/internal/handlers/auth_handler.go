package handlers

import (
	"net/http"

	"codertalk-backend/internal/middleware"
	"codertalk-backend/internal/models"
	"codertalk-backend/internal/services"

	"github.com/gin-gonic/gin"
)

// AuthHandler handles authentication endpoints.
type AuthHandler struct {
	authService  *services.AuthService
	emailService *services.EmailService
}

// NewAuthHandler creates a new AuthHandler.
func NewAuthHandler(authService *services.AuthService, emailService *services.EmailService) *AuthHandler {
	return &AuthHandler{
		authService:  authService,
		emailService: emailService,
	}
}

// Register handles user registration.
// POST /api/auth/register
func (h *AuthHandler) Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	user, code, err := h.authService.Register(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusConflict, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	// Send verification email (async — don't block the response)
	go func() {
		_ = h.emailService.SendVerificationEmail(user.Email, user.Username, code)
	}()

	c.JSON(http.StatusCreated, models.APIResponse{
		Success: true,
		Message: "Registration successful. Please check your email for the verification code.",
		Data:    user.ToPublic(),
	})
}

// Login handles user login and returns a JWT.
// POST /api/auth/login
func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	authResp, err := h.authService.Login(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    authResp,
	})
}

// VerifyEmail handles email verification.
// POST /api/auth/verify-email
func (h *AuthHandler) VerifyEmail(c *gin.Context) {
	var req models.VerifyEmailRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	if err := h.authService.VerifyEmail(c.Request.Context(), req.Email, req.Code); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Email verified successfully. You can now log in.",
	})
}

// ResendVerification resends the verification email.
// POST /api/auth/resend-verification
func (h *AuthHandler) ResendVerification(c *gin.Context) {
	var req models.ResendVerificationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	code, err := h.authService.ResendVerification(c.Request.Context(), req.Email)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	go func() {
		_ = h.emailService.SendVerificationEmail(req.Email, "", code)
	}()

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Verification code resent. Please check your email.",
	})
}

// GetMe returns the current authenticated user's profile.
// GET /api/auth/me
func (h *AuthHandler) GetMe(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Success: false,
			Error:   "User not found in context",
		})
		return
	}

	user, err := h.authService.GetCurrentUser(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    user,
	})
}
