@echo off
setlocal

net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

ipconfig /flushdns
netsh winsock reset
netsh int ip reset
echo.
echo Network reset commands finished. Restart Windows to complete the reset.
pause
