# CoderTalk Monolithic Build & Preparation Script
# This script builds the Flutter Web frontend and copies the assets to the Go backend directory.

$ErrorActionPreference = "Stop"

Write-Host "Starting CoderTalk Monolithic Build..." -ForegroundColor Cyan

# 1. Verify Flutter is installed
try {
    $null = Get-Command flutter -ErrorAction Stop
} catch {
    Write-Error "flutter command not found. Please make sure Flutter SDK is installed and added to your system PATH."
}

# 2. Build the Flutter Web SPA
Write-Host ""
Write-Host "Building Flutter Web frontend..." -ForegroundColor Yellow
Push-Location frontend
try {
    # Run flutter pub get first
    Write-Host "Fetching packages..." -ForegroundColor Gray
    flutter pub get
    
    # Run release build
    Write-Host "Compiling web package..." -ForegroundColor Gray
    flutter build web --release
} catch {
    Pop-Location
    Write-Error "Flutter build failed!"
}
Pop-Location

# 3. Copy files to the Go backend folder
Write-Host ""
Write-Host "Copying static assets to Go backend..." -ForegroundColor Yellow

$SrcPath = Join-Path (Get-Item .).FullName "frontend/build/web"
$DestPath = Join-Path (Get-Item .).FullName "backend/web"

if (-not (Test-Path $SrcPath)) {
    Write-Error "Build output directory not found at $SrcPath"
}

# Clean existing files (except .gitkeep)
if (Test-Path $DestPath) {
    Write-Host "Cleaning existing web folder: $DestPath" -ForegroundColor Gray
    Get-ChildItem -Path $DestPath -Exclude ".gitkeep" | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
}

# Copy files
Copy-Item -Path "$SrcPath\*" -Destination $DestPath -Recurse -Force

Write-Host ""
Write-Host "Success: Prepared monolithic deployment assets." -ForegroundColor Green
Write-Host "Frontend files are now located in: chat_app/backend/web"
Write-Host ""
Write-Host "NEXT STEPS FOR CLOUD DEPLOYMENT:"
Write-Host "1. Commit your changes and push them to your Git repository."
Write-Host "2. Deploy the backend directory to Render, Railway, or Fly.io."
Write-Host "   The hosting service will build the Go server and serve the frontend."
Write-Host ""
Write-Host "NEXT STEPS FOR LOCAL RUNNING:"
Write-Host "1. Go to backend directory"
Write-Host "2. Run: docker compose up --build"
Write-Host "3. Open http://localhost:8080 in your browser"
