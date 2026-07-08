package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"strings"

	"codertalk-backend/internal/config"
	"codertalk-backend/internal/middleware"
	"codertalk-backend/internal/models"
	"codertalk-backend/internal/services"

	"github.com/gin-gonic/gin"
)

// AuthHandler handles authentication endpoints.
type AuthHandler struct {
	authService  *services.AuthService
	emailService *services.EmailService
	cfg          *config.Config
}

// NewAuthHandler creates a new AuthHandler.
func NewAuthHandler(authService *services.AuthService, emailService *services.EmailService, cfg *config.Config) *AuthHandler {
	return &AuthHandler{
		authService:  authService,
		emailService: emailService,
		cfg:          cfg,
	}
}

// isWebClient returns true if the request originates from a web browser client.
// Mobile clients should send "X-Client-Type: mobile" header.
func isWebClient(c *gin.Context) bool {
	clientType := c.GetHeader("X-Client-Type")
	if strings.EqualFold(clientType, "mobile") {
		return false
	}
	// If no explicit header, check if it looks like a browser request
	// (has Origin header or Cookie header, or Accept includes text/html)
	if c.GetHeader("Origin") != "" || c.GetHeader("Cookie") != "" {
		return true
	}
	// Default to web if no explicit header is set — safe default
	return true
}

// setAuthCookies sets the access_token (HttpOnly) and csrf_token cookies.
func (h *AuthHandler) setAuthCookies(c *gin.Context, token string, csrfToken string, maxAge int) {
	// HttpOnly cookie for the JWT — JavaScript cannot access this
	c.SetSameSite(http.SameSiteStrictMode)
	c.SetCookie(
		"access_token",        // name
		token,                 // value
		maxAge,                // maxAge in seconds
		"/",                   // path
		h.cfg.CookieDomain,   // domain
		h.cfg.CookieSecure,   // secure (HTTPS only)
		true,                  // httpOnly — NOT accessible via JavaScript
	)

	// CSRF token cookie — readable by JavaScript so the frontend can send it as a header
	c.SetSameSite(http.SameSiteStrictMode)
	c.SetCookie(
		"csrf_token",          // name
		csrfToken,             // value
		maxAge,                // maxAge in seconds
		"/",                   // path
		h.cfg.CookieDomain,   // domain
		h.cfg.CookieSecure,   // secure
		false,                 // httpOnly=false — JavaScript CAN read this
	)
}

// clearAuthCookies removes the auth cookies by setting MaxAge=-1.
func (h *AuthHandler) clearAuthCookies(c *gin.Context) {
	c.SetSameSite(http.SameSiteStrictMode)
	c.SetCookie("access_token", "", -1, "/", h.cfg.CookieDomain, h.cfg.CookieSecure, true)
	c.SetSameSite(http.SameSiteStrictMode)
	c.SetCookie("csrf_token", "", -1, "/", h.cfg.CookieDomain, h.cfg.CookieSecure, false)
}

// generateCSRFToken creates a cryptographically secure random token.
func generateCSRFToken() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
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
// For web clients: JWT is set as an HttpOnly cookie (invisible to JavaScript).
// For mobile clients: JWT is returned in the JSON response body.
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

	if isWebClient(c) {
		// Web client: set JWT as HttpOnly cookie, don't return token in body
		csrfToken, err := generateCSRFToken()
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Success: false,
				Error:   "Failed to generate security token",
			})
			return
		}

		maxAge := h.cfg.JWTExpiryHours * 3600
		h.setAuthCookies(c, authResp.Token, csrfToken, maxAge)

		// Return response WITHOUT the token in the body
		c.JSON(http.StatusOK, models.APIResponse{
			Success: true,
			Data: models.AuthResponse{
				// Token is omitted (empty + omitempty) — the HttpOnly cookie carries it
				User: authResp.User,
			},
		})
	} else {
		// Mobile client: return token in body (existing behavior)
		c.JSON(http.StatusOK, models.APIResponse{
			Success: true,
			Data:    authResp,
		})
	}
}

// Logout clears the authentication cookies.
// POST /api/auth/logout
func (h *AuthHandler) Logout(c *gin.Context) {
	h.clearAuthCookies(c)
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Logged out successfully.",
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

// ForgotPassword initiates password reset.
// POST /api/auth/forgot-password
func (h *AuthHandler) ForgotPassword(c *gin.Context) {
	var req models.ForgotPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	username, code, err := h.authService.ForgotPassword(c.Request.Context(), req.Email)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	go func() {
		_ = h.emailService.SendPasswordResetEmail(req.Email, username, code)
	}()

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "If an account exists with this email, a password reset code has been sent.",
	})
}

// ResetPassword resets user password with verification code.
// POST /api/auth/reset-password
func (h *AuthHandler) ResetPassword(c *gin.Context) {
	var req models.ResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	if err := h.authService.ResetPassword(c.Request.Context(), req.Email, req.Code, req.NewPassword); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Password reset successfully! You can now sign in with your new password.",
	})
}

// ChangePassword changes authenticated user's password.
// PUT /api/auth/change-password
func (h *AuthHandler) ChangePassword(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	var req models.ChangePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: "Invalid request: " + err.Error()})
		return
	}

	if err := h.authService.ChangePassword(c.Request.Context(), userID, req.CurrentPassword, req.NewPassword); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Password updated successfully."})
}

// UpdateProfile updates authenticated user's profile.
// PUT /api/auth/profile
func (h *AuthHandler) UpdateProfile(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	var req models.UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: "Invalid request: " + err.Error()})
		return
	}

	updatedUser, err := h.authService.UpdateProfile(c.Request.Context(), userID, req.Username, req.AvatarURL, req.HideLastSeen)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Profile updated successfully.", Data: updatedUser})
}

// DeleteAccount deletes authenticated user's account after confirming password.
// DELETE /api/auth/account
func (h *AuthHandler) DeleteAccount(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Success: false, Error: "Unauthorized"})
		return
	}

	var req models.DeleteAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: "Invalid request: " + err.Error()})
		return
	}

	if err := h.authService.DeleteAccount(c.Request.Context(), userID, req.Password); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: err.Error()})
		return
	}

	// Clear auth cookies (for web clients)
	h.clearAuthCookies(c)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Account deleted successfully."})
}

