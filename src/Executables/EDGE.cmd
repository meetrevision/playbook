@echo off

reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" /v "NoRemove" /f >NUL 2>nul
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" /v "experiment_control_labels" /f >NUL 2>nul
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev" /v "AllowUninstall" /t REG_DWORD /d 1 /f >NUL 2>nul

for /D %%I in ("%ProgramFiles(x86)%\Microsoft\Edge\Application\*") do (
    if exist "%%I\Installer\setup.exe" (
        echo Uninstalling Edge Chromium
        pushd "%%I\Installer"
        setup.exe --uninstall --msedge  --force-uninstall --system-level --delete-profile
        popd
    )
)

msiexec /X{2BFF39DC-EFF0-355C-80CD-41D847013784} /qn /norestart

set "value=MicrosoftEdgeAutoLaunch_.*"
set "path=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"

for /f "tokens=1,*" %%A in ('reg query "%path%" /f "Microsoft" ^| findstr /R "%value%"') do (
    reg delete "%path%" /v "%%A" /f
)

del /q /f "%userprofile%\Desktop\Microsoft Edge.lnk" >NUL 2>nul