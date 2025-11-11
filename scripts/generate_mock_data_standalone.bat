@echo off
setlocal enabledelayedexpansion
REM ============================================
REM Standalone Mock Data Generator Script
REM ============================================
REM 
REM This batch file runs a pure Dart script (no Flutter dependencies)
REM to generate and upload mock data to MongoDB Atlas.
REM
REM Usage: Double-click this file or run from command prompt
REM ============================================

echo.
echo ============================================================
echo STANDALONE MOCK DATA GENERATOR
echo ============================================================
echo.
echo This script will:
echo   1. Connect directly to MongoDB Atlas
echo   2. Drop the entire database (WARNING: Deletes ALL data!)
echo   3. Generate fresh mock data
echo   4. Upload all data to MongoDB
echo.
echo NOTE: This uses pure Dart (no Flutter dependencies)
echo ============================================================
echo.

REM Change to the project root directory
cd /d "%~dp0.."

REM Check if Dart is installed
where dart >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Dart is not installed or not in PATH
    echo Please install Dart SDK and add it to your PATH
    echo.
    pause
    exit /b 1
)

REM Check if the script file exists
if not exist "lib\scripts\generate_mock_data_standalone.dart" (
    echo ERROR: Script file not found at lib\scripts\generate_mock_data_standalone.dart
    echo.
    pause
    exit /b 1
)

echo Running standalone mock data generator...
echo.

REM Get dependencies first
echo Getting Dart dependencies...
dart pub get >nul 2>&1

REM Run the standalone script using Dart (no Flutter needed)
echo.
echo Executing script...
echo.

dart run lib/scripts/generate_mock_data_standalone.dart

REM Check if the command was successful
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================================
    echo SUCCESS: Mock data generation completed!
    echo ============================================================
    echo.
) else (
    echo.
    echo ============================================================
    echo ERROR: Mock data generation failed!
    echo ============================================================
    echo.
    echo Please check the error messages above.
    echo.
)

pause

