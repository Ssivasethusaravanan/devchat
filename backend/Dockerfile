# ==========================================
# Stage 1: Build the Go application
# ==========================================
FROM golang:1.23-alpine AS builder

# Install SSL ca-certificates for external API/DB requests
RUN apk update && apk add --no-cache git ca-certificates tzdata

WORKDIR /app

# Cache dependency downloads
COPY go.mod go.sum ./
RUN go mod download

# Copy source code and build production binary
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o server ./cmd/server/main.go

# ==========================================
# Stage 2: Minimal runner container
# ==========================================
FROM alpine:latest

# Import SSL certs and timezone data from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

WORKDIR /root/

# Copy binary from builder stage
COPY --from=builder /app/server .

# Copy web static files if they were built
COPY --from=builder /app/web ./web

# Ensure storage data directory exists
RUN mkdir -p data

EXPOSE 8080

CMD ["./server"]
