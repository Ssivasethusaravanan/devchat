package services

import (
	"fmt"
	"log"

	"codertalk-backend/internal/config"

	"gopkg.in/gomail.v2"
)

// EmailService handles sending emails for verification, etc.
type EmailService struct {
	cfg *config.Config
}

// NewEmailService creates a new EmailService.
func NewEmailService(cfg *config.Config) *EmailService {
	return &EmailService{cfg: cfg}
}

// SendVerificationEmail sends a 6-digit verification code to the user's email.
func (s *EmailService) SendVerificationEmail(toEmail, username, code string) error {
	// Always print code to terminal so developers can skip SMTP configuration during local development
	log.Printf("🔑 [DEVELOPMENT PIN] Verification code for %s (%s): %s", username, toEmail, code)

	if s.cfg.SMTPHost == "" || s.cfg.SMTPUsername == "" || s.cfg.SMTPUsername == "your-email@gmail.com" {
		log.Println("⚠️ SMTP is not configured or uses placeholders. Email sending skipped.")
		return nil
	}

	subject := "CoderTalk — Verify Your Email"
	body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background-color: #f4f7fa; margin: 0; padding: 0; }
        .container { max-width: 480px; margin: 40px auto; background: #ffffff; border-radius: 16px; box-shadow: 0 4px 24px rgba(0,0,0,0.08); overflow: hidden; }
        .header { background: linear-gradient(135deg, #1a237e, #283593); padding: 32px; text-align: center; }
        .header h1 { color: #ffffff; margin: 0; font-size: 28px; letter-spacing: 1px; }
        .header p { color: #b3c6ff; margin: 8px 0 0; font-size: 14px; }
        .content { padding: 32px; text-align: center; }
        .greeting { color: #333; font-size: 18px; margin-bottom: 16px; }
        .code-box { background: linear-gradient(135deg, #e8eaf6, #f3f4fb); border: 2px dashed #3f51b5; border-radius: 12px; padding: 24px; margin: 24px 0; }
        .code { font-size: 36px; font-weight: bold; color: #1a237e; letter-spacing: 8px; font-family: 'Courier New', monospace; }
        .note { color: #666; font-size: 13px; margin-top: 20px; }
        .footer { background: #f9fafb; padding: 16px; text-align: center; border-top: 1px solid #eee; }
        .footer p { color: #999; font-size: 12px; margin: 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 CoderTalk</h1>
            <p>Developer Team Communication</p>
        </div>
        <div class="content">
            <p class="greeting">Hey <strong>%s</strong>,</p>
            <p style="color: #555;">Use this verification code to complete your registration:</p>
            <div class="code-box">
                <span class="code">%s</span>
            </div>
            <p class="note">This code expires in <strong>15 minutes</strong>.<br>If you didn't create a CoderTalk account, you can safely ignore this email.</p>
        </div>
        <div class="footer">
            <p>© 2025 CoderTalk — Built for developers, by developers.</p>
        </div>
    </div>
</body>
</html>
`, username, code)

	m := gomail.NewMessage()
	m.SetHeader("From", s.cfg.SMTPFrom)
	m.SetHeader("To", toEmail)
	m.SetHeader("Subject", subject)
	m.SetBody("text/html", body)

	d := gomail.NewDialer(s.cfg.SMTPHost, s.cfg.SMTPPort, s.cfg.SMTPUsername, s.cfg.SMTPPassword)

	if err := d.DialAndSend(m); err != nil {
		log.Printf("❌ Failed to send verification email to %s: %v", toEmail, err)
		return fmt.Errorf("failed to send email: %w", err)
	}

	log.Printf("📧 Verification email sent to %s", toEmail)
	return nil
}
