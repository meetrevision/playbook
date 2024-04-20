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
del "%appdata%\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk" /q /f >NUL 2>nul
del "%appdata%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk" /q /f >NUL 2>nul
del "%programdata%\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk" >NUL 2>nul

 for /f "usebackq delims=" %%e in (`reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" ^| findstr /i /r /c:"Microsoft[ ]*Edge" /c:"msedge"`) do reg delete "%%e" /f

 for /f "usebackq delims=" %%a in (`dir /b /a:d "%SystemDrive%\Users" ^| findstr /v /i /x /c:"Public" /c:"Default User" /c:"All Users"`) do (
	del /q /f "%homeDrive%\Users\%%a\Desktop\Microsoft Edge.lnk" >NUL 2>nul
	rmdir /q /s "%homeDrive%\Users\%%a\AppData\Local\Microsoft\Edge" >NUL 2>nul
	rmdir /q /s "%homeDrive%\Users\%%a\AppData\Local\Microsoft\EdgeUpdate" >NUL 2>nul
	del /q /f "%homeDrive%\Users\%%a\Desktop\Microsoft Edge.lnk" >NUL 2>nul
	del /q /f "%homeDrive%\Users\%%a\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Accessories\Internet Explorer.lnk" >NUL 2>nul
)

for /f "usebackq tokens=1* delims=\" %%A in (`schtasks /query /fo list ^| findstr /c:"\MicrosoftEdge"`) do (
	schtasks /delete /tn "%%B" /f >NUL 2>nul
)
exit /b 0