@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

"!systemroot!\System32\OneDriveSetup.exe" /uninstall >NUL 2>nul
"!systemroot!\SysWOW64\OneDriveSetup.exe" /uninstall >NUL 2>nul

for /f "usebackq tokens=2 delims=\" %%e in (`reg query "HKEY_USERS" ^| findstr /r /x /c:"HKEY_USERS\\S-.*" /c:"HKEY_USERS\\AME_UserHive_[^_]*"`) do (
	REM If the "Volatile Environment" key exists, that means it is a proper user. Built in accounts/SIDs do not have this key.
	reg query "HKU\%%e" | findstr /c:"Volatile Environment" /c:"AME_UserHive_" > nul 2>&1
	if not errorlevel 1 (
		call :USERREG "%%e"
	)
)

taskkill /f /im "OneDrive.exe" >NUL 2>nul

for /f "usebackq delims=" %%a in (`dir /b /a:d "%SystemDrive%\Users"`) do (
	rmdir /q /s "%SystemDrive%\Users\%%a\AppData\Local\Microsoft\OneDrive" >NUL 2>nul
	@REM rmdir /q /s "%SystemDrive%\Users\%%a\OneDrive" >NUL 2>nul
	del /q /f "%SystemDrive%\Users\%%a\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk" >NUL 2>nul
)

for /f "usebackq delims=" %%e in (`reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SyncRootManager" ^| findstr /i /c:"OneDrive"`) do reg delete "%%e" /f >NUL 2>nul

for /f "usebackq tokens=1* delims=\" %%A in (`schtasks /query /fo list ^| findstr /c:"\OneDrive Reporting Task" /c:"\OneDrive Standalone Update Task"`) do (
	schtasks /delete /tn "%%B" /f >NUL 2>nul
)

exit /b 0

:USERREG
for /f "usebackq delims=" %%e in (`reg query "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\BannerStore" ^| findstr /i /c:"OneDrive"`) do reg delete "%%e" /f >NUL 2>nul

for /f "usebackq delims=" %%e in (`reg query "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\Handlers" ^| findstr /i /c:"OneDrive"`) do reg delete "%%e" /f >NUL 2>nul

for /f "usebackq delims=" %%e in (`reg query "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths" ^| findstr /i /c:"OneDrive"`) do reg delete "%%e" /f >NUL 2>nul

for /f "usebackq delims=" %%e in (`reg query "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" ^| findstr /i /c:"OneDrive"`) do reg delete "%%e" /f >NUL 2>nul

REM User installed variant
for /f "tokens=2*" %%A in ('reg query "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe" /v "UninstallString"') do (
    set "uninstallString=%%B"
)
if defined uninstallString (
    call !uninstallString! >NUL 2>nul
)
