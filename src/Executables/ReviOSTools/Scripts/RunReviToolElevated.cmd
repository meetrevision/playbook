@echo off
setlocal

if /i "%~1"==":elevated" shift

net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList ':elevated %*' -Verb RunAs"
    exit /b
)

set "REVITOOL=%ProgramFiles%\Revision Tool\revitool.exe"
if not exist "%REVITOOL%" (
    echo Revision Tool was not found at:
    echo "%REVITOOL%"
    echo.
    echo Install or repair Revision Tool, then run this script again.
    pause
    exit /b 2
)

"%REVITOOL%" %*
set "CODE=%ERRORLEVEL%"
echo.
if "%CODE%"=="0" (
    echo Completed.
) else (
    echo Command failed with exit code %CODE%.
)
echo Restart Windows if the setting does not apply immediately.
pause
exit /b %CODE%
