# Production Build Script for Exam Management App (PowerShell)
# 
# Usage:
#   .\build-production.ps1 [platform] [api_url] [chat_url]
#
# Examples:
#   .\build-production.ps1 android https://api.yourdomain.com https://chat.yourdomain.com
#   .\build-production.ps1 ios https://api.yourdomain.com https://chat.yourdomain.com
#   .\build-production.ps1 apk http://192.168.1.100:3000 http://192.168.1.100:3001

param(
    [string]$Platform = "android",
    [string]$ApiUrl = "http://exam-app-api.duckdns.org",
    [string]$ChatUrl = "http://backend-chat.duckdns.org"
)

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Production Build Script                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Platform: $Platform" -ForegroundColor Green
Write-Host "API URL: $ApiUrl" -ForegroundColor Green
Write-Host "Chat URL: $ChatUrl" -ForegroundColor Green
Write-Host ""

# Validate URLs
if (-not $ApiUrl -match '^https?://') {
    Write-Host "Error: API URL must start with http:// or https://" -ForegroundColor Red
    exit 1
}

if (-not $ChatUrl -match '^https?://') {
    Write-Host "Error: Chat URL must start with http:// or https://" -ForegroundColor Red
    exit 1
}

# Build based on platform
switch ($Platform.ToLower()) {
    { $_ -in "android", "apk" } {
        Write-Host "Building Android APK..." -ForegroundColor Yellow
        flutter build apk --release `
            --dart-define=API_BASE_URL="$ApiUrl" `
            --dart-define=CHAT_BASE_URL="$ChatUrl"
        Write-Host "`n✓ APK built successfully!" -ForegroundColor Green
        Write-Host "Output: build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor Green
    }
    { $_ -in "appbundle", "bundle" } {
        Write-Host "Building Android App Bundle..." -ForegroundColor Yellow
        flutter build appbundle --release `
            --dart-define=API_BASE_URL="$ApiUrl" `
            --dart-define=CHAT_BASE_URL="$ChatUrl"
        Write-Host "`n✓ App Bundle built successfully!" -ForegroundColor Green
        Write-Host "Output: build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Green
    }
    "ios" {
        Write-Host "Building iOS..." -ForegroundColor Yellow
        flutter build ios --release `
            --dart-define=API_BASE_URL="$ApiUrl" `
            --dart-define=CHAT_BASE_URL="$ChatUrl"
        Write-Host "`n✓ iOS build completed!" -ForegroundColor Green
        Write-Host "Note: Open Xcode to archive and distribute" -ForegroundColor Yellow
    }
    default {
        Write-Host "Error: Unknown platform '$Platform'" -ForegroundColor Red
        Write-Host "Supported platforms: android, apk, appbundle, bundle, ios" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "`n✓ Build completed successfully!`n" -ForegroundColor Green
Write-Host "Configuration used:" -ForegroundColor Cyan
Write-Host "  API URL: $ApiUrl"
Write-Host "  Chat URL: $ChatUrl"
Write-Host ""

