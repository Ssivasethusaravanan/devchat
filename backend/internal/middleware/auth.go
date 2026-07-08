package middleware

import (
	"net/http"
	"strings"

	"codertalk-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// JWTClaims holds the custom JWT claims.
type JWTClaims struct {
	UserID   uuid.UUID `json:"user_id"`
	Username string    `json:"username"`
	jwt.RegisteredClaims
}

// AuthMiddleware validates the JWT token from either:
// 1. The "access_token" HttpOnly cookie (web clients)
// 2. The "Authorization: Bearer <token>" header (mobile clients)
//
// When the token comes from a cookie, CSRF validation is enforced on
// mutating methods (POST, PUT, PATCH, DELETE) by requiring the
// X-CSRF-Token header to match the csrf_token cookie value.
func AuthMiddleware(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		var tokenString string
		fromCookie := false

		// Strategy 1: Try to read JWT from the HttpOnly access_token cookie
		if cookie, err := c.Cookie("access_token"); err == nil && cookie != "" {
			tokenString = cookie
			fromCookie = true
		}

		// Strategy 2: Fall back to Authorization: Bearer <token> header (mobile clients)
		if tokenString == "" {
			authHeader := c.GetHeader("Authorization")
			if authHeader == "" {
				c.JSON(http.StatusUnauthorized, models.APIResponse{
					Success: false,
					Error:   "Authentication required",
				})
				c.Abort()
				return
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
				c.JSON(http.StatusUnauthorized, models.APIResponse{
					Success: false,
					Error:   "Invalid authorization header format. Use: Bearer <token>",
				})
				c.Abort()
				return
			}
			tokenString = parts[1]
		}

		// CSRF validation: If the JWT came from a cookie, enforce CSRF check
		// on state-changing methods to prevent cross-site request forgery.
		if fromCookie && isMutatingMethod(c.Request.Method) {
			csrfHeader := c.GetHeader("X-CSRF-Token")
			csrfCookie, err := c.Cookie("csrf_token")
			if err != nil || csrfHeader == "" || csrfHeader != csrfCookie {
				c.JSON(http.StatusForbidden, models.APIResponse{
					Success: false,
					Error:   "CSRF validation failed",
				})
				c.Abort()
				return
			}
		}

		// Parse and validate token
		claims := &JWTClaims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			// Validate signing method
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(jwtSecret), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, models.APIResponse{
				Success: false,
				Error:   "Invalid or expired token",
			})
			c.Abort()
			return
		}

		// Inject user info into Gin context for downstream handlers
		c.Set("user_id", claims.UserID)
		c.Set("username", claims.Username)
		c.Next()
	}
}

// isMutatingMethod returns true for HTTP methods that change state.
// GET, HEAD, and OPTIONS are considered safe (no CSRF check needed).
func isMutatingMethod(method string) bool {
	switch method {
	case http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete:
		return true
	default:
		return false
	}
}

// GetUserID extracts the authenticated user's ID from the Gin context.
func GetUserID(c *gin.Context) (uuid.UUID, bool) {
	userID, exists := c.Get("user_id")
	if !exists {
		return uuid.Nil, false
	}
	id, ok := userID.(uuid.UUID)
	return id, ok
}

// GetUsername extracts the authenticated user's username from the Gin context.
func GetUsername(c *gin.Context) (string, bool) {
	username, exists := c.Get("username")
	if !exists {
		return "", false
	}
	name, ok := username.(string)
	return name, ok
}

