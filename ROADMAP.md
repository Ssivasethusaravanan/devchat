# 💬 Chat App — Complete Feature Roadmap (Phase 3+)

**Legend:** 🔴 Critical (users expect this) · 🟡 Important (competitive parity) · 🟢 Nice-to-have (differentiator)

---

## ✅ Where You Are Now
- Auth: login, signup, forgot/reset password, change password, delete account
- Profile: avatar/username edit
- Chat: text messages, edit, delete, reply w/ quote, emoji reactions, real-time WS sync, date separators
- Single Docker deployment (Flutter Web + backend on Render)

This is a strong foundation — you have the *interaction* layer. What's mostly missing is **presence, media, groups, calling, security depth, and infra hardening**.

---

## 🔴 Phase 3 — Presence & Delivery Status
- [ ] Typing indicator ("Alice is typing…") via WS event, auto-clears after timeout
- [ ] Online / offline presence dot on avatars
- [ ] "Last seen at …" with privacy toggle to hide it
- [ ] Message delivery ticks: sent (1 grey) → delivered (2 grey) → read (2 blue)
- [ ] Read receipts per-user in group chats (who has seen it)
- [ ] Connection status banner ("Reconnecting…") when WS drops

## 🔴 Phase 4 — Rich Media Messaging
- [ ] Image messages: pick from gallery/camera, compress before upload, thumbnail + full-screen viewer with pinch-zoom
- [ ] Video messages: thumbnail preview, inline playback, download
- [ ] Voice notes: hold-to-record button, waveform animation, slide-to-cancel gesture, playback with scrubber + speed toggle
- [ ] Document/file sharing (PDF, docs) with file-type icon + size
- [ ] Location sharing (map pin, optionally live location)
- [ ] Contact card sharing
- [ ] Link previews (auto-unfurl title/image/description for URLs)
- [ ] GIF picker (Giphy/Tenor) + sticker packs
- [ ] Attachment menu (bottom sheet: camera, gallery, doc, location, contact)
- [ ] Upload/download progress indicators on bubbles

## 🟡 Phase 5 — Groups & Channels
- [ ] Create group: name, avatar, description, add members
- [ ] Group info screen: member list, roles (admin/member), add/remove members
- [ ] Leave group / admin can remove members / transfer ownership
- [ ] @mentions with autocomplete + push notification on mention
- [ ] Group-specific permissions (who can send messages, edit info, add members)
- [ ] Broadcast/channel mode (one-to-many, read-only for members)

## 🟡 Phase 6 — Search & Organization
- [ ] In-chat message search (jump to result, highlight)
- [ ] Global search across all chats + contacts
- [ ] Pin conversations to top of chat list
- [ ] Archive chats (hide without deleting)
- [ ] Mute conversation (with duration: 1h / 8h / always)
- [ ] Star/bookmark important messages, dedicated "Starred Messages" screen
- [ ] Pinned messages inside a chat (banner at top)
- [ ] Swipe actions on chat list (archive, mute, delete)

## 🟡 Phase 7 — Voice & Video Calling
- [ ] WebRTC integration (via `flutter_webrtc`) with your WS server as signaling channel
- [ ] 1:1 voice call + video call
- [ ] Incoming call full-screen UI (accept/decline), ringtone
- [ ] In-call controls: mute, speaker, camera flip, end call
- [ ] Group calls
- [ ] Call history screen (missed/incoming/outgoing log)

## 🟢 Phase 8 — Stories / Status
- [ ] 24-hour disappearing photo/video/text posts
- [ ] Story ring indicator around avatars in chat list
- [ ] Story viewer with progress bars, tap-to-advance
- [ ] "Seen by" list for your own stories

## 🔴 Phase 9 — Notifications & Multi-Device Sync
- [ ] Push notifications (FCM for Android/Web, APNs for iOS) for new messages, mentions, calls
- [ ] Notification tap → deep-link to correct chat
- [ ] Per-chat notification settings (mute, custom sound)
- [ ] Offline message queue — messages sent while offline deliver on reconnect
- [ ] Message sync across devices (mark-as-read syncs everywhere)
- [ ] "Linked devices" screen (like WhatsApp Web sessions) with remote logout

## 🔴 Phase 10 — Security & Privacy
- [ ] End-to-end encryption for message content (at minimum, encrypt-at-rest; ideally Signal-protocol style E2E)
- [ ] App lock: PIN/biometric (fingerprint/Face ID) before opening app
- [ ] Block user / report user + report message flow
- [ ] Privacy settings: who sees last seen, profile photo, read receipts (per-contact granularity if possible)
- [ ] Session management: view active sessions, "log out of all devices"
- [ ] Rate limiting on login/message endpoints, CAPTCHA on repeated auth failures
- [ ] Disappearing messages (self-destruct timer per chat)

## 🟡 Phase 11 — Settings & Personalization
- [ ] Theme: light / dark / system, plus accent color picker
- [ ] Per-chat wallpaper/background
- [ ] Font size scaling
- [ ] Language/localization (i18n)
- [ ] Data & storage usage screen (clear cache, media auto-download settings)
- [ ] Custom notification sounds
- [ ] Export/backup chat history

---

## 📱 Full UI Screen Inventory

| Screen | Status |
|---|---|
| Splash screen | ❌ Missing |
| Onboarding/intro carousel | ❌ Missing |
| Login | ✅ Done |
| Signup | ✅ Done |
| Forgot / Reset password | ✅ Done |
| Chat list (home) | ✅ Done (basic) — needs search bar, swipe actions, pinned/archived sections |
| Chat screen | ✅ Done — needs media, calls, pinned banner |
| New chat / contacts picker | ❌ Missing |
| Group creation flow | ❌ Missing |
| Group info / members | ❌ Missing |
| User profile (viewing someone else) | ❌ Missing |
| My profile / settings hub | ✅ Done (basic) — needs privacy, theme, notifications sections |
| Global search | ❌ Missing |
| Media/full-screen viewer | ❌ Missing |
| Call screen (incoming/in-call) | ❌ Missing |
| Call history | ❌ Missing |
| Story viewer/creator | ❌ Missing |
| Archived chats | ❌ Missing |
| Blocked users list | ❌ Missing |
| Starred messages | ❌ Missing |
| App lock (PIN/biometric) | ❌ Missing |

---

## 🛠️ Backend & Infra Checklist
- [ ] **WebSocket scaling**: Redis pub/sub (or socket.io Redis adapter) so multiple server instances share real-time state — right now a single container works, but this breaks the moment you scale horizontally
- [ ] **Media storage + CDN**: S3/Cloudinary/R2 for uploads, with image compression pipeline (don't store raw uploads in your DB or container)
- [ ] **Database pagination**: cursor-based pagination + indexing on `chat_id`/`created_at` for infinite scroll — flat `findAll()` won't scale past a few thousand messages
- [ ] **Push notification service**: FCM/APNs server integration, device token management
- [ ] **Rate limiting & abuse protection**: per-IP and per-user limits on auth + message endpoints
- [ ] **Monitoring & error tracking**: Sentry (or similar) for both Flutter and backend crash/error reporting
- [ ] **Structured logging**: request logs, WS connection logs for debugging production issues
- [ ] **Automated DB backups**
- [ ] **Admin/moderation tooling**: ability to view reports, ban users, delete abusive content
- [ ] **GDPR-style data export/delete** for account deletion flow

## 🧪 Testing & DevOps
- [ ] Unit tests for BLoCs (auth_bloc, chat_bloc) — test event → state transitions
- [ ] Widget tests for key screens (chat_screen, profile_screen)
- [ ] Integration/e2e test for the core send → receive → react flow
- [ ] CI pipeline (GitHub Actions) running tests + `flutter analyze` on PRs
- [ ] Separate staging environment before deploying to Render prod

## ♿ Accessibility & Polish
- [ ] Screen reader labels (Semantics widgets) on interactive elements
- [ ] Dynamic text scaling support (don't hardcode font sizes that break with system scaling)
- [ ] Empty states (no chats yet, no search results, no messages)
- [ ] Skeleton/shimmer loaders instead of blank screens while fetching
- [ ] Retry UI on failed message send / failed network calls
- [ ] Offline banner when device has no connectivity

## 🟢 Differentiators (later)
- [ ] Custom emoji/sticker packs
- [ ] Message scheduling (send later)
- [ ] In-line translation
- [ ] Bots/integrations via webhook
- [ ] Home-screen widget (recent chats)
- [ ] Chat export to PDF/txt
