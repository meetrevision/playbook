@echo off
setlocal

net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo Running DISM health restore...
dism /online /cleanup-image /restorehealth
echo.
echo Running System File Checker...
sfc /scannow
echo.
echo Repair commands finished. Restart Windows if repairs were applied.
pause
