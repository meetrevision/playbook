@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

for /f "usebackq tokens=7 delims=\" %%e in (`reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /d /f "Update Health Tools" /s ^| findstr /i /c:"CurrentVersion\Uninstall\\"`) do set "GUID=%%e"
for /f "usebackq tokens=4 delims=\" %%e in (`reg query "HKCR\Installer\Products" /d /f "Update Health Tools" /s ^| findstr /i /c:"Installer\Products\\"`) do set "ProdID=%%e"

if "!GUID!"=="" goto :Prod
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\!GUID!" /f

:Prod
if "!ProdID!"=="" exit /b 0

for /f "usebackq delims=" %%e in (`reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes" /d /f "!ProdID!" /s ^| findstr /i /c:"Installer\UpgradeCodes\\"`) do reg delete "%%e" /f
reg delete "HKCR\Installer\Products\!ProdID!" /f
reg delete "HKCR\Installer\Features\!ProdID!" /f
for /f "usebackq delims=" %%e in (`reg query "HKCR\Installer\UpgradeCodes" /d /f "!ProdID!" /s ^| findstr /i /c:"Installer\UpgradeCodes\\"`) do reg delete "%%e" /f
for /f "usebackq delims=" %%e in (`reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components" /d /f "!ProdID!" /s ^| findstr /i /c:"S-1-5-18\Components\\"`) do reg delete "%%e" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\!ProdID!" /f

for /f "usebackq delims=" %%e in (`PowerShell -NoP -C "(Get-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Folders').Property" ^| findstr /i /c:"Update Health Tools"`) do (
	set "var=%%e"
	if "!var:~-1!"=="\" set "var=%%e\"
	reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Folders" /v "!var!" /f
)