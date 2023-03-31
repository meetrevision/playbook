@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

if exist "!SystemDrive!\Windows\StartMenuLayout.xml" echo del /q /f "!SystemDrive!\Windows\StartMenuLayout.xml" & del /q /f "!SystemDrive!\Windows\StartMenuLayout.xml"
@REM copy /y "Layout.xml" "!SystemDrive!\Windows\StartMenuLayout.xml"
@REM taskkill /f /im "SearchApp.exe"

mkdir "%SYSTEMDRIVE%\Users\Default\AppData\Local\Microsoft\Windows\Shell" 2>nul
copy /y "LayoutModification.xml" "%SYSTEMDRIVE%\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml"
copy /y "LayoutModification.json" "%SYSTEMDRIVE%\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.json"
copy /y "DefaultLayouts.xml" "%SYSTEMDRIVE%\Users\Default\AppData\Local\Microsoft\Windows\Shell\DefaultLayouts.xml"

mkdir "%SYSTEMDRIVE%\Users\Default\AppData\Local\Packages\%%d\LocalState" 2>nul
copy /y "settings.json" "%SYSTEMDRIVE%\Users\Default\AppData\Local\Packages\%%d\LocalState\settings.json"

for /f "usebackq tokens=2 delims=\" %%a in (`reg query "HKEY_USERS" ^| findstr /r /x /c:"HKEY_USERS\\S-.*" /c:"HKEY_USERS\\AME_UserHive_[^_]*"`) do (
	@REM If the "Volatile Environment" key exists, that means it is a proper user. Built in accounts/SIDs do not have this key.
	reg query "HKEY_USERS\%%a" | findstr /c:"Volatile Environment" /c:"AME_UserHive_" > nul 2>&1
	if not !errorlevel! == 1 (
		for /f "usebackq tokens=3* delims= " %%b in (`reg query "HKU\%%a\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Local AppData" 2^>nul ^| findstr /r /x /c:".*Local AppData[ ]*REG_SZ[ ].*"`) do (
			echo copy /y "LayoutModification.xml" "%%c\Microsoft\Windows\Shell\LayoutModification.xml"
			copy /y "LayoutModification.xml" "%%c\Microsoft\Windows\Shell\LayoutModification.xml"
			echo copy /y "LayoutModification.json" "%%c\Microsoft\Windows\Shell\LayoutModification.json"
			copy /y "LayoutModification.json" "%%c\Microsoft\Windows\Shell\LayoutModification.json"
			echo copy /y "DefaultLayouts.xml" "%%c\Microsoft\Windows\Shell\DefaultLayouts.xml"
			copy /y "DefaultLayouts.xml" "%%c\Microsoft\Windows\Shell\DefaultLayouts.xml"

			@REM Clear start menu pinned items
			for /f "usebackq delims=" %%d in (`dir /b "%%c\Packages" /a:d ^| findstr /c:"Microsoft.Windows.StartMenuExperienceHost"`) do (
				for /f "usebackq delims=" %%e in (`dir /b "%%c\Packages\%%d\LocalState" /a:-d ^| findstr /R /c:"start.\.bin" /c:"start\.bin"`) do (
					echo del /q /f "%%c\Packages\%%d\LocalState\%%e"
					del /q /f "%%c\Packages\%%d\LocalState\%%e"
				)
			)



			@REM This is not an ideal place to put this, but it works
			for /f "usebackq delims=" %%d in (`dir /b "%%c\Packages" /a:d ^| findstr /c:"Microsoft.DesktopAppInstaller"`) do (
				mkdir "%%c\Packages\%%d\LocalState" 2>nul
				echo copy /y "settings.json" "%%c\Packages\%%d\LocalState\settings.json"
				copy /y "settings.json" "%%c\Packages\%%d\LocalState\settings.json"
			)

			@REM echo del /q /f "%%c\Packages\Microsoft.Windows.Search_cw5n1h2txyewy\LocalState\DeviceSearchCache\SettingsCache.txt"
			@REM del /q /f "%%c\Packages\Microsoft.Windows.Search_cw5n1h2txyewy\LocalState\DeviceSearchCache\SettingsCache.txt"
			@REM echo copy /y "SettingsCache.txt" "%%c\Packages\Microsoft.Windows.Search_cw5n1h2txyewy\LocalState\DeviceSearchCache\SettingsCache.txt"
			@REM copy /y "SettingsCache.txt" "%%c\Packages\Microsoft.Windows.Search_cw5n1h2txyewy\LocalState\DeviceSearchCache\SettingsCache.txt"
		)
		@REM echo reg add "HKU\%%a\SOFTWARE\Policies\Microsoft\Windows\Explorer" /f
		@REM reg add "HKU\%%a\SOFTWARE\Policies\Microsoft\Windows\Explorer" /f
		@REM echo reg add "HKU\%%a\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "LockedStartLayout" /t REG_DWORD /d "0" /f
		@REM reg add "HKU\%%a\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "LockedStartLayout" /t REG_DWORD /d "0" /f
		@REM echo reg add "HKU\%%a\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "StartLayoutFile" /t REG_SZ /d "C:\Windows\StartMenuLayout.xml" /f
		@REM reg add "HKU\%%a\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "StartLayoutFile" /t REG_SZ /d "C:\Windows\StartMenuLayout.xml" /f
		for /f "usebackq delims=" %%c in (`reg query "HKU\%%a\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount" ^| findstr /c:"start.tilegrid"`) do (
			echo reg delete "%%c" /f
			reg delete "%%c" /f
		)
	)
)

::PowerShell -NoP -C "Import-StartLayout -LayoutPath '!SystemDrive!\Windows\StartMenuLayout.xml' -MountPath $env:SystemDrive\\"
::reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /f
::reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "StartLayoutFile" /t REG_SZ /d "!SystemDrive!\Windows\StartMenuLayout.xml" /f