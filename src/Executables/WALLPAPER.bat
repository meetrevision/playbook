@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

:: Set wallpaper path for new users, as well as dark/light theme
type "!windir!\Resources\Themes\aero.theme" | findstr /c:"AppMode=" > nul
if !errorlevel! == 0 (
	PowerShell -NoP -C "$Content = (Get-Content '!windir!\Resources\Themes\aero.theme'); $Content = $Content -replace 'Wallpaper=%%SystemRoot%%.*', 'Wallpaper=%%SystemRoot%%\web\wallpaper\Windows\revision.jpg'; $Content = $Content -replace 'SystemMode=.*', 'SystemMode=Dark'; $Content -replace 'AppMode=.*', 'AppMode=Dark' | Set-Content '!windir!\Resources\Themes\aero.theme'"
) else (
	PowerShell -NoP -C "$Content = (Get-Content '!windir!\Resources\Themes\aero.theme'); $Content = $Content -replace 'Wallpaper=%%SystemRoot%%.*', 'Wallpaper=%%SystemRoot%%\web\wallpaper\Windows\revision.jpg'; $Content = $Content -replace 'SystemMode=.*', """"SystemMode=Dark`nAppMode=Dark"""" | Set-Content '!windir!\Resources\Themes\aero.theme'"
)

for /f "usebackq tokens=2 delims=\" %%a in (`reg query "HKEY_USERS" ^| findstr /r /x /c:"HKEY_USERS\\S-.*" /c:"HKEY_USERS\\AME_UserHive_[^_]*"`) do (
	if "%%a"=="AME_UserHive_Default" (
		call :WALLRUN "%%a" "!SystemDrive!\Users\Default\AppData\Roaming"
	) else (
		for /f "usebackq tokens=2* delims= " %%b in (`reg query "HKU\%%a\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "AppData" 2^>^&1 ^| findstr /r /x /c:".*AppData[ ]*REG_SZ[ ].*"`) do (
			call :WALLRUN "%%a" "%%c"
		)
	)
)

:: Clear lockscreen cache
for /d %%x in ("!ProgramData!\Microsoft\Windows\SystemData\*") do (
	for /d %%y in ("%%x\ReadOnly\LockScreen_*") do (
		rd /s /q "%%y" 
	)
)

exit /b 0

:WALLRUN
:: Check if the wallpaper was changed from the default wallpaper by the user
if exist "%~2\Microsoft\Windows\Themes\Transcoded_000" exit /b 0
if exist "%~2\Microsoft\Windows\Themes\TranscodedWallpaper" (
	PowerShell -NoP -C "Add-Type -AssemblyName System.Drawing; $img = New-Object System.Drawing.Bitmap '%~2\Microsoft\Windows\Themes\TranscodedWallpaper'; if ($img.Flags -ne 77840) {exit 1}; if ($img.HorizontalResolution -ne 96) {exit 1}; if ($img.VerticalResolution -ne 96) {exit 1}; if ($img.PropertyIdList -notcontains 40961) {exit 1}; if ($img.PropertyIdList -notcontains 20624) {exit 1}; if ($img.PropertyIdList -notcontains 20625) {exit 1}" > nul
	if !errorlevel! == 1 (
		exit /b 0
	)
) 

if not exist "!windir!\Web\Wallpaper\Windows\revision.jpg" exit /b 1

reg add "HKEY_USERS\%~1\Control Panel\Desktop" /v "WallPaper" /t REG_SZ /d "!windir!\Web\Wallpaper\Windows\revision.jpg" /f

:: Set the wallpaper for the current user and local machine
reg add "HKCU\Control Panel\Desktop" /v "WallPaper" /t REG_SZ /d "!windir!\Web\Wallpaper\Windows\revision.jpg" /f
reg add "HKLM\Control Panel\Desktop" /v "WallPaper" /t REG_SZ /d "!windir!\Web\Wallpaper\Windows\revision.jpg" /f

del /q /f "%~2\Microsoft\Windows\Themes\TranscodedWallpaper"
rd /q /s "%~2\Microsoft\Windows\Themes\CachedFiles"
rundll32.exe user32.dll, UpdatePerUserSystemParameters

if not "%~1"=="AME_UserHive_Default" (
	reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\Creative\%~1" /v "RotatingLockScreenEnabled" /t REG_DWORD /d "0" /f > nul
)
reg add "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "RotatingLockScreenEnabled" /t REG_DWORD /d "0" /f > nul