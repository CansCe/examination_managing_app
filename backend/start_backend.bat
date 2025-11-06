@echo off
REM Backend Server Startup Script for Windows (Batch)
echo Exam Management Backend Server Setup
echo =====================================
echo.

REM Check if .env file exists
if not exist ".env" (
    echo Warning: .env file not found!
    echo.
    echo Creating .env file from ENV_EXAMPLE.txt...
    
    if exist "ENV_EXAMPLE.txt" (
        copy "ENV_EXAMPLE.txt" ".env" >nul
        echo Created .env file. Please update it with your MongoDB credentials.
        echo.
        echo Edit .env and set your MONGODB_URI with your actual credentials.
        echo Press any key to continue after editing...
        pause >nul
    ) else (
        echo ENV_EXAMPLE.txt not found. Please create .env manually.
        echo Required variables:
        echo   MONGODB_URI=mongodb+srv://^<username^>:^<password^>@clustertest.7nkaqoh.mongodb.net/exam_management?retryWrites=true^&w=majority^&appName=ClusterTest
        echo   MONGODB_DB=exam_management
        echo   PORT=3000
        pause
        exit /b 1
    )
)

REM Check if node_modules exists
if not exist "node_modules" (
    echo Installing dependencies...
    call npm install
    if errorlevel 1 (
        echo Failed to install dependencies
        pause
        exit /b 1
    )
    echo Dependencies installed
    echo.
)

REM Start the server
echo Starting backend server...
echo Server will be available at http://localhost:3000
echo Press Ctrl+C to stop the server
echo.

call npm run dev

