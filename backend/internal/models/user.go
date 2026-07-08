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
	LastSeen              *time.Time `json:"last_seen,omitempty"`
	HideLastSeen          bool       `json:"hide_last_seen"`
	IsVerified            bool       `json:"is_verified"`
	VerificationCode      string     `json:"-"`
	VerificationExpiresAt *time.Time `json:"-"`
	ResetCode             string     `json:"-"`
	ResetCodeExpiresAt    *time.Time `json:"-"`
	CreatedAt             time.Time  `json:"created_at"`
	UpdatedAt             time.Time  `json:"updated_at"`
}

// UserPublic is a safe version of User for API responses (no sensitive fields).
type UserPublic struct {
	ID           uuid.UUID  `json:"id"`
	Username     string     `json:"username"`
	Email        string     `json:"email"`
	AvatarURL    string     `json:"avatar_url,omitempty"`
	Status       string     `json:"status"`
	LastSeen     *time.Time `json:"last_seen,omitempty"`
	HideLastSeen bool       `json:"hide_last_seen"`
	CreatedAt    time.Time  `json:"created_at"`
}

// ToPublic converts a User to its public representation.
func (u *User) ToPublic() UserPublic {
	var lastSeen *time.Time
	if !u.HideLastSeen {
		lastSeen = u.LastSeen
	}
	return UserPublic{
		ID:           u.ID,
		Username:     u.Username,
		Email:        u.Email,
		AvatarURL:    u.AvatarURL,
		Status:       u.Status,
		LastSeen:     lastSeen,
		HideLastSeen: u.HideLastSeen,
		CreatedAt:    u.CreatedAt,
	}
}

// ResolveLastSeen enforces symmetric privacy: if either the viewer or the target hides their last seen, it returns nil.
func ResolveLastSeen(viewerHideLastSeen bool, targetHideLastSeen bool, targetLastSeen *time.Time) *time.Time {
	if viewerHideLastSeen || targetHideLastSeen {
		return nil
	}
	return targetLastSeen
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

// ForgotPasswordRequest represents the forgot password payload.
type ForgotPasswordRequest struct {
	Email string `json:"email" binding:"required,email"`
}

// ResetPasswordRequest represents the reset password payload.
type ResetPasswordRequest struct {
	Email       string `json:"email" binding:"required,email"`
	Code        string `json:"code" binding:"required,len=6"`
	NewPassword string `json:"new_password" binding:"required,min=6"`
}

// ChangePasswordRequest represents the change password payload.
type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" binding:"required"`
	NewPassword     string `json:"new_password" binding:"required,min=6"`
}

// UpdateProfileRequest represents updating user profile.
type UpdateProfileRequest struct {
	Username     string `json:"username" binding:"omitempty,min=3,max=50"`
	AvatarURL    string `json:"avatar_url" binding:"omitempty"`
	HideLastSeen *bool  `json:"hide_last_seen" binding:"omitempty"`
}

// DeleteAccountRequest represents account deletion confirmation payload.
type DeleteAccountRequest struct {
	Password string `json:"password" binding:"required"`
}

// AuthResponse is returned after successful login.
type AuthResponse struct {
	Token string     `json:"token,omitempty"`
	User  UserPublic `json:"user"`
}
