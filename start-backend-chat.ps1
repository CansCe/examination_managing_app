# PowerShell script to start Chat Service (Supabase)
# Usage: .\start-backend-chat.ps1

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║     Starting CHAT SERVICE (Supabase)                    ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Magenta

Set-Location backend-chat

# Check if .env exists
if (-not (Test-Path .env)) {
    Write-Host "✗ ERROR: .env file not found in backend-chat/" -ForegroundColor Red
    Write-Host "`n📝 Solution:" -ForegroundColor Yellow
    Write-Host "   1. Copy ENV_EXAMPLE.txt to .env" -ForegroundColor Yellow
    Write-Host "   2. Fill in your SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY" -ForegroundColor Yellow
    Write-Host "   3. Run this script again`n" -ForegroundColor Yellow
    exit 1
}

# Check if node_modules exists
if (-not (Test-Path node_modules)) {
    Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
    npm install
}

Write-Host "🚀 Starting Chat Service...`n" -ForegroundColor Green
npm start

