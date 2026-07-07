@echo off
setlocal

reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /t REG_SZ /d "" /f
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe
echo Classic context menu enabled.
pause
