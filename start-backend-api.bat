@echo off
REM Batch script to start Main API Service (MongoDB)
REM Usage: start-backend-api.bat

echo.
echo ╔══════════════════════════════════════════════════════════╗
echo ║     Starting MAIN API SERVICE (MongoDB)                ║
echo ╚══════════════════════════════════════════════════════════╝
echo.

cd backend-api

REM Check if .env exists
if not exist .env (
    echo ✗ ERROR: .env file not found in backend-api/
    echo.
    echo 📝 Solution:
    echo    1. Copy ENV_EXAMPLE.txt to .env
    echo    2. Fill in your MONGODB_URI
    echo    3. Run this script again
    echo.
    pause
    exit /b 1
)

REM Check if node_modules exists
if not exist node_modules (
    echo 📦 Installing dependencies...
    call npm install
)

echo 🚀 Starting Main API Service...
echo.
call npm start

