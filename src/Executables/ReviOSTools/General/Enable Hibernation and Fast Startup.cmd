@echo off
setlocal

net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "REVITOOL=%ProgramFiles%\Revision Tool\revitool.exe"
if not exist "%REVITOOL%" (
    echo Revision Tool was not found at:
    echo "%REVITOOL%"
    pause
    exit /b 2
)

"%REVITOOL%" tweaks utilities hibernation enable
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" goto done

"%REVITOOL%" tweaks utilities fast-startup enable
set "CODE=%ERRORLEVEL%"

:done
echo.
if "%CODE%"=="0" (
    echo Hibernation and Fast Startup enabled.
) else (
    echo Command failed with exit code %CODE%.
)
pause
exit /b %CODE%
