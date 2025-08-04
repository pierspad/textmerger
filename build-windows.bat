@echo off
echo Building TextMerger for Windows...

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Python is not installed or not in PATH
    exit /b 1
)

REM Install build dependencies
echo Installing dependencies...
pip install -r requirements-windows.txt

REM Build the executable
echo Building executable...
python build_windows.py

echo.
echo Build completed! The executable is in the dist folder.
pause
