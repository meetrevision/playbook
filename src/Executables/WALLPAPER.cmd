@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

robocopy "Web" "%windir%\Web" /E /IM /IT /NP > nul

@REM :: Set wallpaper path for new users, as well as dark/light theme
@REM type "!windir!\Resources\Themes\aero.theme" | findstr /c:"AppMode=" > nul
@REM if !errorlevel! == 0 (
@REM 	PowerShell -NoP -C "$Content = (Get-Content '!windir!\Resources\Themes\aero.theme'); $Content = $Content -replace 'Wallpaper=%%SystemRoot%%.*', 'Wallpaper=%%SystemRoot%%\web\wallpaper\Windows\revision.jpg'; $Content = $Content -replace 'SystemMode=.*', 'SystemMode=Dark'; $Content -replace 'AppMode=.*', 'AppMode=Dark' | Set-Content '!windir!\Resources\Themes\aero.theme'"
@REM ) else (
@REM 	PowerShell -NoP -C "$Content = (Get-Content '!windir!\Resources\Themes\aero.theme'); $Content = $Content -replace 'Wallpaper=%%SystemRoot%%.*', 'Wallpaper=%%SystemRoot%%\web\wallpaper\Windows\revision.jpg'; $Content = $Content -replace 'SystemMode=.*', """"SystemMode=Dark`nAppMode=Dark"""" | Set-Content '!windir!\Resources\Themes\aero.theme'"
@REM )

@REM for /f "usebackq tokens=2 delims=\" %%a in (`reg query "HKEY_USERS" ^| findstr /r /x /c:"HKEY_USERS\\S-.*" /c:"HKEY_USERS\\AME_UserHive_[^_]*"`) do (
@REM 	if "%%a"=="AME_UserHive_Default" (
@REM 		call :WALLRUN "%%a" "!SystemDrive!\Users\Default\AppData\Roaming"
@REM 	) else (
@REM 		for /f "usebackq tokens=2* delims= " %%b in (`reg query "HKU\%%a\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "AppData" 2^>^&1 ^| findstr /r /x /c:".*AppData[ ]*REG_SZ[ ].*"`) do (
@REM 			call :WALLRUN "%%a" "%%c"
@REM 		)
@REM 	)
@REM )

:: Clear lockscreen cache
for /d %%x in ("!ProgramData!\Microsoft\Windows\SystemData\*") do (
	for /d %%y in ("%%x\ReadOnly\LockScreen_*") do (
		rd /s /q "%%y" 
	)
)

:WALLRUN
@REM :: Check if the wallpaper was changed from the default wallpaper by the user
@REM if exist "!appdata!\Microsoft\Windows\Themes\Transcoded_000" exit /b 0
@REM if exist "%~2\Microsoft\Windows\Themes\TranscodedWallpaper" (
@REM 	PowerShell -NoP -C "Add-Type -AssemblyName System.Drawing; $img = New-Object System.Drawing.Bitmap '%~2\Microsoft\Windows\Themes\TranscodedWallpaper'; if ($img.Flags -ne 77840) {exit 1}; if ($img.HorizontalResolution -ne 96) {exit 1}; if ($img.VerticalResolution -ne 96) {exit 1}; if ($img.PropertyIdList -notcontains 40961) {exit 1}; if ($img.PropertyIdList -notcontains 20624) {exit 1}; if ($img.PropertyIdList -notcontains 20625) {exit 1}" > nul
@REM 	if !errorlevel! == 1 (
@REM 		exit /b 0
@REM 	)
@REM ) 

@REM if not exist "!windir!\Web\Wallpaper\Windows\revision.jpg" exit /b 1

:: Some OEM systems, the wallpaper is set to a different path
reg add "HKEY_USERS\%~1\Control Panel\Desktop" /v "Wallpaper" /t REG_SZ /d "!windir!\Web\Wallpaper\Windows\img0.jpg" /f
rmdir /q /s "!appdata!\Microsoft\Windows\Themes"
rundll32.exe user32.dll, UpdatePerUserSystemParameters

@REM if not "%~1"=="AME_UserHive_Default" (
@REM 	reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\Creative\%~1" /v "RotatingLockScreenEnabled" /t REG_DWORD /d "0" /f > nul
@REM )
@REM reg add "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "RotatingLockScreenEnabled" /t REG_DWORD /d "0" /f > nul