package services

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"time"

	"codertalk-backend/internal/middleware"
	"codertalk-backend/internal/models"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

// AuthService handles authentication business logic.
type AuthService struct {
	db           *pgxpool.Pool
	jwtSecret    string
	jwtExpiryHrs int
}

// NewAuthService creates a new AuthService.
func NewAuthService(db *pgxpool.Pool, jwtSecret string, jwtExpiryHrs int) *AuthService {
	return &AuthService{
		db:           db,
		jwtSecret:    jwtSecret,
		jwtExpiryHrs: jwtExpiryHrs,
	}
}

// Register creates a new user account with an email verification code.
func (s *AuthService) Register(ctx context.Context, req models.RegisterRequest) (*models.User, string, error) {
	// Check if username already exists
	var exists bool
	err := s.db.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM users WHERE username = $1)", req.Username,
	).Scan(&exists)
	if err != nil {
		return nil, "", fmt.Errorf("failed to check username: %w", err)
	}
	if exists {
		return nil, "", errors.New("username already taken")
	}

	// Check if email already exists
	err = s.db.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)", req.Email,
	).Scan(&exists)
	if err != nil {
		return nil, "", fmt.Errorf("failed to check email: %w", err)
	}
	if exists {
		return nil, "", errors.New("email already registered")
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, "", fmt.Errorf("failed to hash password: %w", err)
	}

	// Generate 6-digit verification code
	code, err := generateVerificationCode()
	if err != nil {
		return nil, "", fmt.Errorf("failed to generate verification code: %w", err)
	}

	// Verification code expires in 15 minutes
	expiresAt := time.Now().Add(15 * time.Minute)

	// Insert user
	user := &models.User{}
	err = s.db.QueryRow(ctx,
		`INSERT INTO users (username, email, password_hash, verification_code, verification_expires_at)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, username, email, avatar_url, status, is_verified, created_at, updated_at`,
		req.Username, req.Email, string(hashedPassword), code, expiresAt,
	).Scan(&user.ID, &user.Username, &user.Email, &user.AvatarURL, &user.Status,
		&user.IsVerified, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, "", fmt.Errorf("failed to create user: %w", err)
	}

	return user, code, nil
}

// VerifyEmail verifies a user's email with the provided code.
func (s *AuthService) VerifyEmail(ctx context.Context, email, code string) error {
	var storedCode string
	var expiresAt time.Time
	var isVerified bool

	err := s.db.QueryRow(ctx,
		`SELECT verification_code, verification_expires_at, is_verified FROM users WHERE email = $1`,
		email,
	).Scan(&storedCode, &expiresAt, &isVerified)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("user not found")
		}
		return fmt.Errorf("failed to query user: %w", err)
	}

	if isVerified {
		return errors.New("email already verified")
	}

	if time.Now().After(expiresAt) {
		return errors.New("verification code has expired")
	}

	if storedCode != code {
		return errors.New("invalid verification code")
	}

	// Mark user as verified
	_, err = s.db.Exec(ctx,
		`UPDATE users SET is_verified = TRUE, verification_code = NULL, verification_expires_at = NULL, updated_at = NOW() WHERE email = $1`,
		email,
	)
	if err != nil {
		return fmt.Errorf("failed to verify user: %w", err)
	}

	return nil
}

// ResendVerification generates a new verification code for an unverified user.
func (s *AuthService) ResendVerification(ctx context.Context, email string) (string, error) {
	var isVerified bool
	err := s.db.QueryRow(ctx,
		`SELECT is_verified FROM users WHERE email = $1`, email,
	).Scan(&isVerified)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", errors.New("user not found")
		}
		return "", fmt.Errorf("failed to query user: %w", err)
	}

	if isVerified {
		return "", errors.New("email already verified")
	}

	code, err := generateVerificationCode()
	if err != nil {
		return "", fmt.Errorf("failed to generate code: %w", err)
	}

	expiresAt := time.Now().Add(15 * time.Minute)
	_, err = s.db.Exec(ctx,
		`UPDATE users SET verification_code = $1, verification_expires_at = $2, updated_at = NOW() WHERE email = $3`,
		code, expiresAt, email,
	)
	if err != nil {
		return "", fmt.Errorf("failed to update verification code: %w", err)
	}

	return code, nil
}

// Login authenticates a user and returns a JWT token.
func (s *AuthService) Login(ctx context.Context, req models.LoginRequest) (*models.AuthResponse, error) {
	user := &models.User{}
	err := s.db.QueryRow(ctx,
		`SELECT id, username, email, password_hash, avatar_url, status, is_verified, created_at, updated_at
		 FROM users WHERE username = $1`,
		req.Username,
	).Scan(&user.ID, &user.Username, &user.Email, &user.PasswordHash, &user.AvatarURL,
		&user.Status, &user.IsVerified, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("invalid username or password")
		}
		return nil, fmt.Errorf("failed to query user: %w", err)
	}

	// Check password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("invalid username or password")
	}

	// Check if verified
	if !user.IsVerified {
		return nil, errors.New("email not verified. Please check your email for the verification code")
	}

	// Generate JWT
	token, err := s.generateToken(user.ID, user.Username)
	if err != nil {
		return nil, fmt.Errorf("failed to generate token: %w", err)
	}

	// Update user status to online
	_, _ = s.db.Exec(ctx,
		`UPDATE users SET status = 'online', updated_at = NOW() WHERE id = $1`, user.ID,
	)

	return &models.AuthResponse{
		Token: token,
		User:  user.ToPublic(),
	}, nil
}

// GetCurrentUser returns the user profile for the given user ID.
func (s *AuthService) GetCurrentUser(ctx context.Context, userID uuid.UUID) (*models.UserPublic, error) {
	user := &models.User{}
	err := s.db.QueryRow(ctx,
		`SELECT id, username, email, avatar_url, status, is_verified, created_at, updated_at
		 FROM users WHERE id = $1`,
		userID,
	).Scan(&user.ID, &user.Username, &user.Email, &user.AvatarURL, &user.Status,
		&user.IsVerified, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("user not found")
		}
		return nil, fmt.Errorf("failed to query user: %w", err)
	}

	pub := user.ToPublic()
	return &pub, nil
}

// generateToken creates a signed JWT for the given user.
func (s *AuthService) generateToken(userID uuid.UUID, username string) (string, error) {
	claims := &middleware.JWTClaims{
		UserID:   userID,
		Username: username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(s.jwtExpiryHrs) * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "codertalk",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.jwtSecret))
}

// generateVerificationCode creates a cryptographically secure 6-digit code.
func generateVerificationCode() (string, error) {
	code := ""
	for i := 0; i < 6; i++ {
		n, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			return "", err
		}
		code += fmt.Sprintf("%d", n.Int64())
	}
	return code, nil
}
