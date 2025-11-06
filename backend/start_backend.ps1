# Backend Server Startup Script for Windows
# This script helps you start the backend API server

Write-Host "Exam Management Backend Server Setup" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if .env file exists
if (-Not (Test-Path ".env")) {
    Write-Host "⚠ Warning: .env file not found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Creating .env file from ENV_EXAMPLE.txt..." -ForegroundColor Yellow
    
    if (Test-Path "ENV_EXAMPLE.txt") {
        Copy-Item "ENV_EXAMPLE.txt" ".env"
        Write-Host "✓ Created .env file. Please update it with your MongoDB credentials." -ForegroundColor Green
        Write-Host ""
        Write-Host "Edit .env and set your MONGODB_URI with your actual credentials." -ForegroundColor Yellow
        Write-Host "Press Enter to continue after editing..."
        Read-Host
    } else {
        Write-Host "✗ ENV_EXAMPLE.txt not found. Please create .env manually." -ForegroundColor Red
        Write-Host "Required variables:" -ForegroundColor Yellow
        Write-Host "  MONGODB_URI=mongodb+srv://<username>:<password>@clustertest.7nkaqoh.mongodb.net/exam_management?retryWrites=true&w=majority&appName=ClusterTest"
        Write-Host "  MONGODB_DB=exam_management"
        Write-Host "  PORT=3000"
        exit 1
    }
}

# Check if node_modules exists
if (-Not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to install dependencies" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Dependencies installed" -ForegroundColor Green
    Write-Host ""
}

# Start the server
Write-Host "Starting backend server..." -ForegroundColor Green
Write-Host "Server will be available at http://localhost:3000" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

npm run dev

