package database

import (
	"context"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

// RunMigrations creates all required tables if they don't exist.
func RunMigrations(pool *pgxpool.Pool) error {
	ctx := context.Background()

	migrations := []string{
		// Enable UUID extension
		`CREATE EXTENSION IF NOT EXISTS "pgcrypto"`,

		// Users table
		`CREATE TABLE IF NOT EXISTS users (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			username VARCHAR(50) UNIQUE NOT NULL,
			email VARCHAR(255) UNIQUE NOT NULL,
			password_hash VARCHAR(255) NOT NULL,
			avatar_url TEXT DEFAULT '',
			status VARCHAR(20) DEFAULT 'offline',
			is_verified BOOLEAN DEFAULT FALSE,
			verification_code VARCHAR(6),
			verification_expires_at TIMESTAMPTZ,
			reset_code VARCHAR(6),
			reset_code_expires_at TIMESTAMPTZ,
			created_at TIMESTAMPTZ DEFAULT NOW(),
			updated_at TIMESTAMPTZ DEFAULT NOW()
		)`,

		// Add columns for existing databases
		`ALTER TABLE users 
			ADD COLUMN IF NOT EXISTS reset_code VARCHAR(6),
			ADD COLUMN IF NOT EXISTS reset_code_expires_at TIMESTAMPTZ`,

		// Conversations table (supports both DMs and groups)
		`CREATE TABLE IF NOT EXISTS conversations (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			type VARCHAR(10) NOT NULL CHECK (type IN ('direct', 'group')),
			name VARCHAR(100),
			description TEXT DEFAULT '',
			avatar_url TEXT DEFAULT '',
			created_by UUID REFERENCES users(id),
			created_at TIMESTAMPTZ DEFAULT NOW(),
			updated_at TIMESTAMPTZ DEFAULT NOW()
		)`,

		// Conversation members (many-to-many)
		`CREATE TABLE IF NOT EXISTS conversation_members (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
			user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'member')),
			joined_at TIMESTAMPTZ DEFAULT NOW(),
			UNIQUE(conversation_id, user_id)
		)`,

		// Messages table
		`CREATE TABLE IF NOT EXISTS messages (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
			sender_id UUID NOT NULL REFERENCES users(id),
			content TEXT NOT NULL,
			content_type VARCHAR(20) DEFAULT 'text' CHECK (content_type IN ('text', 'code', 'json', 'file', 'image')),
			language VARCHAR(50) DEFAULT '',
			is_edited BOOLEAN DEFAULT FALSE,
			reply_to_id UUID REFERENCES messages(id) ON DELETE SET NULL,
			created_at TIMESTAMPTZ DEFAULT NOW(),
			updated_at TIMESTAMPTZ DEFAULT NOW()
		)`,

		`ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES messages(id) ON DELETE SET NULL`,

		// Message reactions table
		`CREATE TABLE IF NOT EXISTS message_reactions (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
			user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			emoji VARCHAR(20) NOT NULL,
			created_at TIMESTAMPTZ DEFAULT NOW(),
			UNIQUE(message_id, user_id, emoji)
		)`,

		// Attachments table (linked to messages, stored in R2)
		`CREATE TABLE IF NOT EXISTS attachments (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
			file_name VARCHAR(255) NOT NULL,
			file_size BIGINT NOT NULL,
			mime_type VARCHAR(100) NOT NULL,
			r2_key VARCHAR(500) NOT NULL,
			created_at TIMESTAMPTZ DEFAULT NOW()
		)`,

		// Read receipts for tracking unread messages
		`CREATE TABLE IF NOT EXISTS read_receipts (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
			user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			last_read_at TIMESTAMPTZ DEFAULT NOW(),
			UNIQUE(conversation_id, user_id)
		)`,

		// ===== Indexes =====
		`CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id)`,
		`CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id)`,
		`CREATE INDEX IF NOT EXISTS idx_message_reactions_message_id ON message_reactions(message_id)`,
		`CREATE INDEX IF NOT EXISTS idx_conversation_members_user_id ON conversation_members(user_id)`,
		`CREATE INDEX IF NOT EXISTS idx_conversation_members_conversation_id ON conversation_members(conversation_id)`,
		`CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)`,
		`CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)`,
		`CREATE INDEX IF NOT EXISTS idx_attachments_message_id ON attachments(message_id)`,
		`CREATE INDEX IF NOT EXISTS idx_read_receipts_conversation_user ON read_receipts(conversation_id, user_id)`,
	}

	for i, migration := range migrations {
		if _, err := pool.Exec(ctx, migration); err != nil {
			log.Printf("❌ Migration %d failed: %v", i+1, err)
			return err
		}
	}

	log.Println("✅ Database migrations completed successfully")
	return nil
}
