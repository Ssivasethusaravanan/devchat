package services

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"time"

	"codertalk-backend/internal/config"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/google/uuid"
)

// StorageService handles Cloudflare R2 file operations.
type StorageService struct {
	client     *s3.Client
	presigner  *s3.PresignClient
	bucketName string
}

// NewStorageService creates a new R2-backed storage service.
func NewStorageService(cfg *config.Config) (*StorageService, error) {
	if cfg.R2AccountID == "" || cfg.R2AccessKeyID == "" || cfg.R2SecretAccessKey == "" {
		return &StorageService{bucketName: cfg.R2BucketName}, nil
	}

	r2Endpoint := fmt.Sprintf("https://%s.r2.cloudflarestorage.com", cfg.R2AccountID)

	awsCfg, err := awsconfig.LoadDefaultConfig(context.TODO(),
		awsconfig.WithCredentialsProvider(
			credentials.NewStaticCredentialsProvider(cfg.R2AccessKeyID, cfg.R2SecretAccessKey, ""),
		),
		awsconfig.WithRegion("auto"),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config for R2: %w", err)
	}

	client := s3.NewFromConfig(awsCfg, func(o *s3.Options) {
		o.BaseEndpoint = aws.String(r2Endpoint)
	})

	return &StorageService{
		client:     client,
		presigner:  s3.NewPresignClient(client),
		bucketName: cfg.R2BucketName,
	}, nil
}

// GenerateUploadURL creates a presigned PUT URL for direct client upload to R2.
func (s *StorageService) GenerateUploadURL(fileName, contentType string) (string, string, error) {
	if s.client == nil {
		return "", "", fmt.Errorf("R2 storage not configured")
	}

	// Generate a unique key to avoid collisions
	key := fmt.Sprintf("uploads/%s/%s", uuid.New().String(), fileName)

	request, err := s.presigner.PresignPutObject(context.TODO(), &s3.PutObjectInput{
		Bucket:      aws.String(s.bucketName),
		Key:         aws.String(key),
		ContentType: aws.String(contentType),
	}, func(opts *s3.PresignOptions) {
		opts.Expires = 15 * time.Minute
	})
	if err != nil {
		return "", "", fmt.Errorf("failed to generate presigned upload URL: %w", err)
	}

	return request.URL, key, nil
}

// GenerateDownloadURL creates a presigned GET URL for downloading from R2.
func (s *StorageService) GenerateDownloadURL(key string) (string, error) {
	if s.client == nil {
		return "", fmt.Errorf("R2 storage not configured")
	}

	request, err := s.presigner.PresignGetObject(context.TODO(), &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	}, func(opts *s3.PresignOptions) {
		opts.Expires = 1 * time.Hour
	})
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned download URL: %w", err)
	}

	return request.URL, nil
}

// DeleteObject removes a file from R2.
func (s *StorageService) DeleteObject(key string) error {
	if s.client == nil {
		return nil
	}

	_, err := s.client.DeleteObject(context.TODO(), &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	})
	return err
}

// SaveFileDirect saves file content to local disk (fallback/cache) and R2 storage directly.
func (s *StorageService) SaveFileDirect(key string, content []byte, contentType string) error {
	// 1. Always save locally to data/<key> for reliable serving without CORS or expiration
	localPath := filepath.Join("data", key)
	var localErr error
	if err := os.MkdirAll(filepath.Dir(localPath), 0755); err != nil {
		localErr = fmt.Errorf("failed to create directory: %w", err)
	} else if err := os.WriteFile(localPath, content, 0644); err != nil {
		localErr = fmt.Errorf("failed to write file: %w", err)
	}

	// 2. Also upload to R2 if configured
	if s.client != nil {
		_, err := s.client.PutObject(context.TODO(), &s3.PutObjectInput{
			Bucket:      aws.String(s.bucketName),
			Key:         aws.String(key),
			Body:        bytes.NewReader(content),
			ContentType: aws.String(contentType),
		})
		if err != nil {
			log.Printf("⚠️ Failed to upload to R2: %v", err)
			if localErr != nil {
				return fmt.Errorf("both local and R2 upload failed (local: %v, r2: %v)", localErr, err)
			}
			return nil
		}
	} else if localErr != nil {
		// R2 not configured and local save failed
		return fmt.Errorf("local file save failed and R2 is not configured: %w", localErr)
	}

	return nil
}

// GetFileStream retrieves a file reader directly from local disk cache or R2.
func (s *StorageService) GetFileStream(key string) (io.ReadCloser, string, error) {
	// 1. Check local disk first
	localPath := filepath.Join("data", key)
	if f, err := os.Open(localPath); err == nil {
		return f, "application/octet-stream", nil
	}

	// 2. Fetch from R2 if configured
	if s.client != nil {
		out, err := s.client.GetObject(context.TODO(), &s3.GetObjectInput{
			Bucket: aws.String(s.bucketName),
			Key:    aws.String(key),
		})
		if err == nil {
			contentType := "application/octet-stream"
			if out.ContentType != nil {
				contentType = *out.ContentType
			}
			return out.Body, contentType, nil
		}
	}

	return nil, "", fmt.Errorf("file not found")
}

// CacheFromR2 downloads a file from R2 to local disk cache if it exists in R2.
func (s *StorageService) CacheFromR2(key string) error {
	if s.client == nil {
		return fmt.Errorf("file not found locally or in R2")
	}

	out, err := s.client.GetObject(context.TODO(), &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	})
	if err != nil {
		return err
	}
	defer out.Body.Close()

	localPath := filepath.Join("data", key)
	if err := os.MkdirAll(filepath.Dir(localPath), 0755); err != nil {
		return err
	}

	f, err := os.Create(localPath)
	if err != nil {
		return err
	}
	defer f.Close()

	_, err = io.Copy(f, out.Body)
	return err
}
