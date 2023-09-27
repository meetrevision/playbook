@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

taskkill /f /im "OneDrive.exe"
taskkill /f /im "OneDriveStandaloneUpdater.exe"
taskkill /f /im "OneDriveSetup.exe"

"!systemroot!\System32\OneDriveSetup.exe" /uninstall
"!systemroot!\SysWOW64\OneDriveSetup.exe" /uninstall

for /f "tokens=2*" %%A in ('reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe" /v "UninstallString"') do (
    set "uninstallString=%%B"
)

if defined uninstallString (
    call !uninstallString!
)

del /F /Q "!systemroot!\System32\OneDriveSetup.exe"
del /F /Q "!systemroot!\SysWOW64\OneDriveSetup.exe"
del /F /Q "!systemroot!\SysWOW64\OneDriveSettingSyncProvider.dll"
del /F /Q "!SystemDrive!\OneDriveTemp"
del /F /Q "!ProgramData!\Microsoft OneDrive"

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f

reg delete "HKCU\Software\Microsoft\OneDrive" /f

REM remove OneDrive from explorer navigation pane
reg delete "HKCR\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f
reg delete "HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f

for /f "usebackq tokens=2 delims=\" %%e in (`reg query "HKEY_USERS" ^| findstr /r /x /c:"HKEY_USERS\\S-.*" /c:"HKEY_USERS\\AME_UserHive_[^_]*"`) do (
	REM If the "Volatile Environment" key exists, that means it is a proper user. Built in accounts/SIDs do not have this key.
	reg query "HKU\%%e" | findstr /c:"Volatile Environment" /c:"AME_UserHive_" > nul 2>&1
	if not !errorlevel! == 1 (
		call :USERREG "%%e"
	)
)

for /f "usebackq delims=" %%a in (`dir /b /a:d "!SystemDrive!\Users"`) do (
	echo rmdir /q /s "!SystemDrive!\Users\%%a\AppData\Local\Microsoft\OneDrive"
	rmdir /q /s "!SystemDrive!\Users\%%a\AppData\Local\Microsoft\OneDrive"
	echo rmdir /q /s "!SystemDrive!\Users\%%a\OneDrive"
	rmdir /q /s "!SystemDrive!\Users\%%a\OneDrive"

	echo del /q /f "!SystemDrive!\Users\%%a\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"
	del /q /f "!SystemDrive!\Users\%%a\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"
)

for /f "usebackq delims=" %%e in (`reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SyncRootManager" ^| findstr /i /c:"OneDrive"`) do echo reg delete "%%e" /f & reg delete "%%e" /f

for /f "usebackq tokens=1* delims=\" %%A in (`schtasks /query /fo list ^| findstr /c:"\OneDrive Reporting Task" /c:"\OneDrive Standalone Update Task"`) do (
	schtasks /delete /tn "%%B" /f
)

exit /b 0

:USERREG
for /f "usebackq delims=" %%e in (`reg query "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\BannerStore" ^| findstr /i /c:"OneDrive"`) do (
	echo reg delete "%%e" /f
	reg delete "%%e" /f
)
for /f "usebackq delims=" %%e in (`reg query "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\Handlers" ^| findstr /i /c:"OneDrive"`) do (
	echo reg delete "%%e" /f
	reg delete "%%e" /f
)
for /f "usebackq delims=" %%e in (`reg query "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths" ^| findstr /i /c:"OneDrive"`) do (
	echo reg delete "%%e" /f
	reg delete "%%e" /f
)
for /f "usebackq delims=" %%e in (`reg query "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" ^| findstr /i /c:"OneDrive"`) do (
	echo reg delete "%%e" /f
	reg delete "%%e" /f
)
