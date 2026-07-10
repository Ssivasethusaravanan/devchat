package handlers

import (
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"

	"codertalk-backend/internal/models"
	"codertalk-backend/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// UploadHandler handles file upload/download via R2 presigned URLs or direct proxy.
type UploadHandler struct {
	storageService *services.StorageService
}

// NewUploadHandler creates a new UploadHandler.
func NewUploadHandler(storageService *services.StorageService) *UploadHandler {
	return &UploadHandler{storageService: storageService}
}

// GetPresignedUploadURL generates a presigned PUT URL for direct upload to R2.
// POST /api/upload/presign
func (h *UploadHandler) GetPresignedUploadURL(c *gin.Context) {
	var req models.PresignUploadRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	uploadURL, r2Key, err := h.storageService.GenerateUploadURL(req.FileName, req.ContentType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Error:   "Failed to generate upload URL: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: models.PresignUploadResponse{
			UploadURL: uploadURL,
			R2Key:     r2Key,
		},
	})
}

func getBaseURL(c *gin.Context) string {
	if appURL := os.Getenv("APP_URL"); appURL != "" && appURL != "http://localhost:8080" {
		return appURL
	}
	scheme := "http"
	if c.Request.TLS != nil || c.GetHeader("X-Forwarded-Proto") == "https" {
		scheme = "https"
	}
	return fmt.Sprintf("%s://%s", scheme, c.Request.Host)
}

// UploadDirect handles direct multipart file upload through the Go server.
// POST /api/upload/direct
func (h *UploadHandler) UploadDirect(c *gin.Context) {
	fileHeader, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Success: false, Error: "No file uploaded: " + err.Error()})
		return
	}

	file, err := fileHeader.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Success: false, Error: "Failed to read file: " + err.Error()})
		return
	}
	defer file.Close()

	content, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Success: false, Error: "Failed to read content: " + err.Error()})
		return
	}

	contentType := fileHeader.Header.Get("Content-Type")
	if contentType == "" {
		contentType = http.DetectContentType(content)
	}

	r2Key := fmt.Sprintf("uploads/%s/%s", uuid.New().String(), fileHeader.Filename)
	err = h.storageService.SaveFileDirect(r2Key, content, contentType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Success: false, Error: "Failed to save file: " + err.Error()})
		return
	}

	fileURL := fmt.Sprintf("%s/api/files/%s", getBaseURL(c), r2Key)
	if u, err := url.Parse(getBaseURL(c)); err == nil {
		u.Path = "/api/files/" + r2Key
		fileURL = u.String()
	}
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"r2_key":   r2Key,
			"file_url": fileURL,
		},
	})
}

// GetPresignedDownloadURL returns a backend proxy URL to prevent CORS or expiration issues.
// GET /api/upload/download/:key
func (h *UploadHandler) GetPresignedDownloadURL(c *gin.Context) {
	key := c.Param("key")
	if len(key) > 0 && key[0] == '/' {
		key = key[1:]
	}
	if key == "" {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "File key is required",
		})
		return
	}

	fileURL := fmt.Sprintf("%s/api/files/%s", getBaseURL(c), key)
	if u, err := url.Parse(getBaseURL(c)); err == nil {
		u.Path = "/api/files/" + key
		fileURL = u.String()
	}
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"download_url": fileURL,
		},
	})
}

// ServeFile streams a file directly from storage (local cache or R2) with full Range and Content-Length support.
// GET /api/files/*key
func (h *UploadHandler) ServeFile(c *gin.Context) {
	key := c.Param("key")
	if len(key) > 0 && key[0] == '/' {
		key = key[1:]
	}
	if key == "" {
		c.Status(http.StatusBadRequest)
		return
	}

	localPath := filepath.Join("data", key)
	if _, err := os.Stat(localPath); os.IsNotExist(err) {
		err := h.storageService.CacheFromR2(key)
		if err != nil {
			c.Status(http.StatusNotFound)
			return
		}
	}

	c.Header("Access-Control-Allow-Origin", "*")
	c.Header("Access-Control-Allow-Methods", "GET, OPTIONS")
	c.Header("Access-Control-Allow-Headers", "*")
	http.ServeFile(c.Writer, c.Request, localPath)
}
