package config

import (
	"log"
	"os"
	"strconv"
	"strings"

	"github.com/joho/godotenv"
)

// Config holds all application configuration.
type Config struct {
	ServerPort string

	// Database
	DatabaseURL string

	// JWT
	JWTSecret      string
	JWTExpiryHours int

	// Cloudflare R2
	R2AccountID       string
	R2AccessKeyID     string
	R2SecretAccessKey string
	R2BucketName      string

	// SMTP
	SMTPHost     string
	SMTPPort     int
	SMTPUsername string
	SMTPPassword string
	SMTPFrom     string

	// App
	AppURL string

	// Cookie Security
	CookieDomain string // Domain for cookies (empty = current host, e.g. ".yourdomain.com")
	CookieSecure bool   // Set Secure flag on cookies (true in production with HTTPS)

	// CORS
	AllowedOrigins []string // Explicit allowed origins for CORS (e.g. "https://yourdomain.com")
}

// Load reads configuration from .env file and environment variables.
func Load() *Config {
	// Overwrite environment variables with .env file values to avoid session contamination
	if err := godotenv.Overload(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	jwtExpiry, _ := strconv.Atoi(getEnv("JWT_EXPIRY_HOURS", "72"))
	smtpPort, _ := strconv.Atoi(getEnv("SMTP_PORT", "587"))
	cookieSecure, _ := strconv.ParseBool(getEnv("COOKIE_SECURE", "false"))

	// Parse allowed origins from comma-separated string
	allowedOrigins := parseAllowedOrigins(getEnv("ALLOWED_ORIGINS", ""))

	return &Config{
		ServerPort:  getEnv("SERVER_PORT", "8080"),
		DatabaseURL: getEnv("DATABASE_URL", ""),

		JWTSecret:      getEnv("JWT_SECRET", ""),
		JWTExpiryHours: jwtExpiry,

		R2AccountID:       getEnv("R2_ACCOUNT_ID", ""),
		R2AccessKeyID:     getEnv("R2_ACCESS_KEY_ID", ""),
		R2SecretAccessKey: getEnv("R2_SECRET_ACCESS_KEY", ""),
		R2BucketName:      getEnv("R2_BUCKET_NAME", "codertalk-files"),

		SMTPHost:     getEnv("SMTP_HOST", "smtp.gmail.com"),
		SMTPPort:     smtpPort,
		SMTPUsername: getEnv("SMTP_USERNAME", ""),
		SMTPPassword: getEnv("SMTP_PASSWORD", ""),
		SMTPFrom:     getEnv("SMTP_FROM", "CoderTalk <noreply@codertalk.dev>"),

		AppURL: getEnv("APP_URL", "http://localhost:8080"),

		CookieDomain:  getEnv("COOKIE_DOMAIN", ""),
		CookieSecure:  cookieSecure,
		AllowedOrigins: allowedOrigins,
	}
}

// parseAllowedOrigins splits a comma-separated origins string into a slice.
// If empty, defaults to localhost origins for development.
func parseAllowedOrigins(raw string) []string {
	if raw == "" {
		return []string{
			"http://localhost:8080",
			"http://localhost:3000",
			"http://127.0.0.1:8080",
		}
	}
	parts := strings.Split(raw, ",")
	origins := make([]string, 0, len(parts))
	for _, p := range parts {
		trimmed := strings.TrimSpace(p)
		if trimmed != "" {
			origins = append(origins, trimmed)
		}
	}
	return origins
}

// Validate checks that required config values are set.
func (c *Config) Validate() {
	required := map[string]string{
		"DATABASE_URL": c.DatabaseURL,
		"JWT_SECRET":   c.JWTSecret,
	}

	for key, val := range required {
		if val == "" {
			log.Fatalf("FATAL: Required environment variable %s is not set", key)
		}
	}
}

func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
