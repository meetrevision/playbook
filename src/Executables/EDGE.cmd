@echo off

reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" /v "NoRemove" /f >NUL 2>nul
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" /v "experiment_control_labels" /f >NUL 2>nul
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev" /v "AllowUninstall" /t REG_DWORD /d 1 /f >NUL 2>nul

for /D %%I in ("%ProgramFiles(x86)%\Microsoft\Edge\Application\*") do (
    if exist "%%I\Installer\setup.exe" (
        echo Uninstalling Edge Chromium
        pushd "%%I\Installer"
        setup.exe --uninstall --msedge  --force-uninstall --system-level --delete-profile >NUL 2>nul
        popd
    )
)

msiexec /X{2BFF39DC-EFF0-355C-80CD-41D847013784} /qn /norestart >NUL 2>nul

::leftovers

for /f "usebackq tokens=2 delims=\" %%a in (`reg query "HKEY_USERS" ^| findstr /r /x /c:"HKEY_USERS\\S-.*" /c:"HKEY_USERS\\AME_UserHive_[^_]*"`) do (
	reg query "HKU\%%a" | findstr /c:"Volatile Environment" /c:"AME_UserHive_" > nul 2>&1
	if not errorlevel 1 (
		for /f "usebackq tokens=2* delims= " %%b in (`reg query "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "AppData" 2^>^&1 ^| findstr /r /x /c:".*AppData[ ]*REG_SZ[ ].*"`) do (
			echo del "%%c\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk" /q /f >NUL 2>nul
			del "%%c\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk" /q /f >NUL 2>nul
			echo del "%%c\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk" /q /f >NUL 2>nul
			del "%%c\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk" /q /f >NUL 2>nul
		)
	)
)

for /f "usebackq tokens=2 delims=\" %%a in (`reg query "HKEY_USERS" ^| findstr /r /x /c:"HKEY_USERS\\S-.*" /c:"HKEY_USERS\\AME_UserHive_[^_]*"`) do (
	reg query "HKU\%%a" | findstr /c:"Volatile Environment" /c:"AME_UserHive_" > nul 2>&1
	if not errorlevel 1 (
		CALL :USERREG "%%a"
	)
)

 for /f "usebackq delims=" %%e in (`reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" ^| findstr /i /r /c:"Microsoft[ ]*Edge" /c:"msedge"`) do reg delete "%%e" /f

 for /f "usebackq delims=" %%a in (`dir /b /a:d "%SystemDrive%\Users" ^| findstr /v /i /x /c:"Public" /c:"Default User" /c:"All Users"`) do (
	echo del /q /f "%homeDrive%\Users\%%a\Desktop\Microsoft Edge.lnk" >NUL 2>nul
	del /q /f "%homeDrive%\Users\%%a\Desktop\Microsoft Edge.lnk" >NUL 2>nul

	echo rmdir /q /s "%homeDrive%\Users\%%a\AppData\Local\Microsoft\Edge" >NUL 2>nul
	rmdir /q /s "%homeDrive%\Users\%%a\AppData\Local\Microsoft\Edge" >NUL 2>nul

	echo rmdir /q /s "%homeDrive%\Users\%%a\AppData\Local\Microsoft\EdgeUpdate" >NUL 2>nul
	rmdir /q /s "%homeDrive%\Users\%%a\AppData\Local\Microsoft\EdgeUpdate" >NUL 2>nul
	
	echo del /q /f "%homeDrive%\Users\%%a\Desktop\Microsoft Edge.lnk" >NUL 2>nul
	del /q /f "%homeDrive%\Users\%%a\Desktop\Microsoft Edge.lnk" >NUL 2>nul
	echo del /q /f "%homeDrive%\Users\%%a\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Accessories\Internet Explorer.lnk" >NUL 2>nul
	del /q /f "%homeDrive%\Users\%%a\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Accessories\Internet Explorer.lnk" >NUL 2>nul
)

for /f "usebackq tokens=1* delims=\" %%A in (`schtasks /query /fo list ^| findstr /c:"\MicrosoftEdge"`) do (
	schtasks /delete /tn "%%B" /f >NUL 2>nul
)

exit /b 0

:USERREG
for /f "usebackq tokens=1 delims= " %%e in (`reg query "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" ^| findstr /i /c:"MicrosoftEdge" /c:"msedge"`) do (
	echo reg delete "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%%e" /f >NUL 2>nul
	reg delete "HKU\%~1\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%%e" /f >NUL 2>nul
)