@echo off
setlocal EnableDelayedExpansion

for /f "usebackq tokens=2 delims=\" %%e in (`reg query "HKEY_USERS" ^| findstr /r /x /c:"HKEY_USERS\\S-.*" /c:"HKEY_USERS\\AME_UserHive_[^_]*"`) do (
	REM If the "Volatile Environment" key exists, that means it is a proper user. Built in accounts/SIDs do not have this key.
	reg query "HKU\%%e" | findstr /c:"Volatile Environment" /c:"AME_UserHive_" > nul 2>&1
	if not errorlevel 1 (
		call :USERREG "%%e"
	)
)

PowerShell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "FIREFOX-POLICY.ps1"

"%ProgramFiles(x86)%\Mozilla Maintenance Service\uninstall.exe" /S >NUL 2>nul

goto :eof

:USERREG
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "DisableTelemetry" /t REG_DWORD /d 1 /f >NUL 2>nul
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "DisablePocket" /t REG_DWORD /d 1 /f >NUL 2>nul
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "CaptivePortal" /t REG_DWORD /d 0 /f >NUL 2>nul
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "DisableFirefoxStudies" /t REG_DWORD /d 1 /f >NUL 2>nul
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "DisableDefaultBrowserAgent" /t REG_DWORD /d 1 /f >NUL 2>nul