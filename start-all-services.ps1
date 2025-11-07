# PowerShell script to start both services
# Usage: .\start-all-services.ps1

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Starting Both Backend Services                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Check if both .env files exist
$apiEnvExists = Test-Path "backend-api\.env"
$chatEnvExists = Test-Path "backend-chat\.env"

if (-not $apiEnvExists) {
    Write-Host "✗ ERROR: backend-api/.env not found" -ForegroundColor Red
    Write-Host "   Copy ENV_EXAMPLE.txt to .env and configure MONGODB_URI`n" -ForegroundColor Yellow
}

if (-not $chatEnvExists) {
    Write-Host "✗ ERROR: backend-chat/.env not found" -ForegroundColor Red
    Write-Host "   Copy ENV_EXAMPLE.txt to .env and configure Supabase credentials`n" -ForegroundColor Yellow
}

if (-not $apiEnvExists -or -not $chatEnvExists) {
    Write-Host "Please configure both services before starting.`n" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Both .env files found`n" -ForegroundColor Green

# Start Main API in a new window
Write-Host "🚀 Starting Main API Service (MongoDB)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\backend-api'; npm start" -WindowStyle Normal

# Wait a bit
Start-Sleep -Seconds 2

# Start Chat Service in a new window
Write-Host "🚀 Starting Chat Service (Supabase)..." -ForegroundColor Magenta
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\backend-chat'; npm start" -WindowStyle Normal

Write-Host "`n✓ Both services starting in separate windows`n" -ForegroundColor Green
Write-Host "Main API: http://localhost:3000" -ForegroundColor Cyan
Write-Host "Chat Service: http://localhost:3001`n" -ForegroundColor Magenta

