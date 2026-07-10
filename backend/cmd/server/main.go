package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"

	"codertalk-backend/internal/config"
	"codertalk-backend/internal/database"
	"codertalk-backend/internal/handlers"
	"codertalk-backend/internal/middleware"
	"codertalk-backend/internal/services"
	ws "codertalk-backend/internal/websocket"

	"github.com/gin-gonic/gin"
)

func main() {
	log.Println("🚀 Starting CoderTalk Server...")

	// Load configuration
	cfg := config.Load()
	cfg.Validate()

	log.Printf("🔌 Database URL loaded: %s", cfg.DatabaseURL)

	// Connect to database
	pool, err := database.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("❌ Database connection failed: %v", err)
	}
	defer database.Close()

	// Run migrations
	if err := database.RunMigrations(pool); err != nil {
		log.Fatalf("❌ Database migrations failed: %v", err)
	}

	// Initialize services
	authService := services.NewAuthService(pool, cfg.JWTSecret, cfg.JWTExpiryHours)
	emailService := services.NewEmailService(cfg)
	chatService := services.NewChatService(pool)
	groupService := services.NewGroupService(pool)
	storageService, err := services.NewStorageService(cfg)
	if err != nil {
		log.Printf("⚠️ Storage service init failed (R2 features disabled): %v", err)
	}

	// Initialize WebSocket hub
	hub := ws.NewHub()
	go hub.Run()

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(authService, emailService, cfg)
	userHandler := handlers.NewUserHandler(pool)
	chatHandler := handlers.NewChatHandler(chatService, hub)
	groupHandler := handlers.NewGroupHandler(groupService)
	uploadHandler := handlers.NewUploadHandler(storageService)

	// Setup Gin router
	router := gin.Default()

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "codertalk"})
	})

	// ===== Public routes (no auth) =====
	auth := router.Group("/api/auth")
	auth.Use(middleware.CORSMiddleware(cfg.AllowedOrigins))
	{
		auth.POST("/register", authHandler.Register)
		auth.POST("/login", authHandler.Login)
		auth.POST("/verify-email", authHandler.VerifyEmail)
		auth.POST("/resend-verification", authHandler.ResendVerification)
		auth.POST("/forgot-password", authHandler.ForgotPassword)
		auth.POST("/reset-password", authHandler.ResetPassword)
		auth.POST("/logout", authHandler.Logout)
	}

	// Public file streaming route (allows browser image tags and downloads without Bearer token)
	router.GET("/api/files/*key", uploadHandler.ServeFile)
	router.OPTIONS("/api/files/*key", func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "*")
		c.Status(204)
	})

	// ===== Protected routes (auth required) =====
	api := router.Group("/api")
	api.Use(middleware.CORSMiddleware(cfg.AllowedOrigins))
	api.Use(middleware.AuthMiddleware(cfg.JWTSecret))
	{
		// Auth
		api.GET("/auth/me", authHandler.GetMe)
		api.PUT("/auth/change-password", authHandler.ChangePassword)
		api.PUT("/auth/profile", authHandler.UpdateProfile)
		api.DELETE("/auth/account", authHandler.DeleteAccount)

		// Users
		api.GET("/users/search", userHandler.SearchUsers)
		api.GET("/users/online", userHandler.GetOnlineUsers)
		api.GET("/users/:id", userHandler.GetUser)

		// Conversations & Messages
		api.GET("/conversations", chatHandler.GetConversations)
		api.POST("/conversations/dm/:user_id", chatHandler.GetOrCreateDM)
		api.GET("/conversations/:id/messages", chatHandler.GetMessages)
		api.PUT("/messages/:id", chatHandler.EditMessage)
		api.DELETE("/messages/:id", chatHandler.DeleteMessage)
		api.POST("/messages/:id/reactions", chatHandler.ToggleReaction)

		// Groups
		api.POST("/groups", groupHandler.CreateGroup)
		api.GET("/groups/:id", groupHandler.GetGroup)
		api.PUT("/groups/:id", groupHandler.UpdateGroup)
		api.POST("/groups/:id/members", groupHandler.AddMember)
		api.DELETE("/groups/:id/members/:user_id", groupHandler.RemoveMember)

		// File uploads
		api.POST("/upload/presign", uploadHandler.GetPresignedUploadURL)
		api.POST("/upload/direct", uploadHandler.UploadDirect)
		api.GET("/upload/download/*key", uploadHandler.GetPresignedDownloadURL)
	}

	// ===== WebSocket endpoint =====
	router.GET("/ws", func(c *gin.Context) {
		ws.ServeWS(hub, chatService, cfg.JWTSecret, cfg.AllowedOrigins, c)
	})

	// ===== Static Web Serving (Optional Monolithic SPA Hosting) =====
	if _, err := os.Stat("web"); err == nil {
		log.Println("🎨 Serving Flutter Web SPA from ./web directory...")
		fs := http.FileServer(http.Dir("web"))
		router.NoRoute(func(c *gin.Context) {
			path := c.Request.URL.Path
			if strings.HasPrefix(path, "/api") || strings.HasPrefix(path, "/ws") {
				c.JSON(http.StatusNotFound, gin.H{"error": "API route not found"})
				return
			}
			filePath := filepath.Join("web", path)
			if stat, err := os.Stat(filePath); err == nil && !stat.IsDir() {
				fs.ServeHTTP(c.Writer, c.Request)
			} else {
				c.File("web/index.html")
			}
		})
	}

	// Graceful shutdown
	go func() {
		quit := make(chan os.Signal, 1)
		signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
		<-quit
		log.Println("⏹️  Shutting down server...")
		database.Close()
		os.Exit(0)
	}()

	// Start server
	addr := fmt.Sprintf(":%s", cfg.ServerPort)
	log.Printf("🌐 CoderTalk server running on http://localhost%s", addr)
	log.Printf("📡 WebSocket endpoint: ws://localhost%s/ws", addr)

	if err := router.Run(addr); err != nil {
		log.Fatalf("❌ Server failed to start: %v", err)
	}
}
