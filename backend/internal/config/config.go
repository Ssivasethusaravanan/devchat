package config

import (
	"log"
	"os"
	"strconv"

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
}

// Load reads configuration from .env file and environment variables.
func Load() *Config {
	// Overwrite environment variables with .env file values to avoid session contamination
	if err := godotenv.Overload(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	jwtExpiry, _ := strconv.Atoi(getEnv("JWT_EXPIRY_HOURS", "72"))
	smtpPort, _ := strconv.Atoi(getEnv("SMTP_PORT", "587"))

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
	}
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
