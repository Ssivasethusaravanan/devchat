package models

import (
	"time"

	"github.com/google/uuid"
)

// User represents a registered user in the system.
type User struct {
	ID                    uuid.UUID  `json:"id"`
	Username              string     `json:"username"`
	Email                 string     `json:"email"`
	PasswordHash          string     `json:"-"`
	AvatarURL             string     `json:"avatar_url,omitempty"`
	Status                string     `json:"status"`
	IsVerified            bool       `json:"is_verified"`
	VerificationCode      string     `json:"-"`
	VerificationExpiresAt *time.Time `json:"-"`
	CreatedAt             time.Time  `json:"created_at"`
	UpdatedAt             time.Time  `json:"updated_at"`
}

// UserPublic is a safe version of User for API responses (no sensitive fields).
type UserPublic struct {
	ID        uuid.UUID `json:"id"`
	Username  string    `json:"username"`
	Email     string    `json:"email"`
	AvatarURL string    `json:"avatar_url,omitempty"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

// ToPublic converts a User to its public representation.
func (u *User) ToPublic() UserPublic {
	return UserPublic{
		ID:        u.ID,
		Username:  u.Username,
		Email:     u.Email,
		AvatarURL: u.AvatarURL,
		Status:    u.Status,
		CreatedAt: u.CreatedAt,
	}
}

// RegisterRequest represents the registration payload.
type RegisterRequest struct {
	Username string `json:"username" binding:"required,min=3,max=50"`
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

// LoginRequest represents the login payload.
type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// VerifyEmailRequest represents the email verification payload.
type VerifyEmailRequest struct {
	Email string `json:"email" binding:"required,email"`
	Code  string `json:"code" binding:"required,len=6"`
}

// ResendVerificationRequest represents the resend verification payload.
type ResendVerificationRequest struct {
	Email string `json:"email" binding:"required,email"`
}

// AuthResponse is returned after successful login.
type AuthResponse struct {
	Token string     `json:"token"`
	User  UserPublic `json:"user"`
}
