# PowerShell script to start Main API Service (MongoDB)
# Usage: .\start-backend-api.ps1

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Starting MAIN API SERVICE (MongoDB)                ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Set-Location backend-api

# Check if .env exists
if (-not (Test-Path .env)) {
    Write-Host "✗ ERROR: .env file not found in backend-api/" -ForegroundColor Red
    Write-Host "`n📝 Solution:" -ForegroundColor Yellow
    Write-Host "   1. Copy ENV_EXAMPLE.txt to .env" -ForegroundColor Yellow
    Write-Host "   2. Fill in your MONGODB_URI" -ForegroundColor Yellow
    Write-Host "   3. Run this script again`n" -ForegroundColor Yellow
    exit 1
}

# Check if node_modules exists
if (-not (Test-Path node_modules)) {
    Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
    npm install
}

Write-Host "🚀 Starting Main API Service...`n" -ForegroundColor Green
npm start

