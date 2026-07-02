# 🚀 CoderTalk Full-Stack Production Deployment Guide

CoderTalk consists of two main components:
1. **Go Backend Server** (`/backend`) — High-performance API, real-time WebSocket messaging, and file streaming server.
2. **Flutter Client** (`/frontend`) — Cross-platform application (Web, Android APK, Windows Desktop).

---

## 🛠️ Part 1: Deploying the Go Backend

We have prepared a multi-stage, optimized `Dockerfile` inside `chat_app/backend/Dockerfile`. You can deploy this easily to any cloud provider that supports Docker container hosting.

### Option A: Render.com (Recommended Free/Low-Cost Cloud)
1. Push your repository to **GitHub** or **GitLab**.
2. Go to [Render Dashboard](https://dashboard.render.com/) and click **New > Web Service**.
3. Connect your Git repository.
4. Set the following build options:
   - **Root Directory**: `chat_app/backend`
   - **Environment**: `Docker`
5. Under **Environment Variables**, add:
   ```env
   SERVER_PORT=8080
   GIN_MODE=release
   DATABASE_URL=postgresql://postgres.user:password@your-supabase-db.pooler.supabase.com:6543/postgres?pgbouncer=true
   JWT_SECRET=your-secure-production-jwt-secret-key
   APP_URL=https://your-app-name.onrender.com
   ```
6. Click **Create Web Service**. Your Go server will build and launch in under 2 minutes!

### Option B: Railway.app / Fly.io / Google Cloud Run
Simply point Railway or Fly.io to the `chat_app/backend` folder. They will automatically detect the `Dockerfile` and build the lightweight Alpine Go container.

### Option C: Self-Hosted VPS via Docker Compose
If you have your own VPS or Linux server (e.g., Ubuntu, Debian, AWS EC2):
1. Copy the `chat_app` folder to your server.
2. Run:
   ```bash
   docker compose up -d --build
   ```
Your server will run continuously on port `8080`.

---

## 📱 Part 2: Building & Deploying the Flutter Frontend

We have configured `AppConstants` in Flutter to read production API and WebSocket URLs dynamically at compile time via `--dart-define`.

### 🌐 1. Deploying Flutter Web
To build your web application for production:
```bash
cd chat_app/frontend
flutter build web --release --dart-define=API_URL=https://your-backend.onrender.com --dart-define=WS_URL=wss://your-backend.onrender.com/ws
```

#### Hosting Options for Flutter Web:
- **Free Static Hosting (Vercel / Netlify / Cloudflare Pages)**:
  Upload the generated contents of `chat_app/frontend/build/web` directly to Vercel or Cloudflare Pages.
- **Monolithic Hosting inside Go Server**:
  Copy the generated `build/web` folder directly into `chat_app/backend/web`. The Go server is pre-programmed to automatically serve your full web SPA on `https://your-backend.onrender.com/` alongside the API!

### 🤖 2. Building Android APK for Users
To generate a production Android app APK:
```bash
cd chat_app/frontend
flutter build apk --release --dart-define=API_URL=https://your-backend.onrender.com --dart-define=WS_URL=wss://your-backend.onrender.com/ws
```
Your APK will be ready at:
`chat_app/frontend/build/app/outputs/flutter-apk/app-release.apk`

### 💻 3. Building Windows Desktop Application
To generate a standalone Windows desktop executable:
```bash
cd chat_app/frontend
flutter build windows --release --dart-define=API_URL=https://your-backend.onrender.com --dart-define=WS_URL=wss://your-backend.onrender.com/ws
```
Your executable files will be located in:
`chat_app/frontend/build/windows/x64/runner/Release/`
