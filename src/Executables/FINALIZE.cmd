@echo off
set version=1.0
for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "CurrentBuild"') do set "build=%%i"
if %build% gtr 19045 ( set "w11=true" )


:: Update Health Tools
msiexec /X{43D501A5-E5E3-46EC-8F33-9E15D2A2CBD5} /qn /norestart >NUL 2>nul
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\UpdateHealthTools" /f >NUL 2>nul
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\rempl" /f >NUL 2>nul
reg delete "HKLM\SOFTWARE\Microsoft\CloudManagedUpdate" /f >NUL 2>nul
rmdir /s /q "%ProgramW6432%\\Microsoft Update Health Tools" >NUL 2>nul

:: PC Health Check
msiexec /X{804A0628-543B-4984-896C-F58BF6A54832} /qn /norestart >NUL 2>nul
rmdir /s /q "%ProgramW6432%\\PCHealthCheck" >NUL 2>nul

:: Windows Installation Assistant
"%ProgramFiles(x86)%\WindowsInstallationAssistant\Windows10UpgraderApp.exe" /SunValley /ForceUninstall >NUL 2>nul
rmdir /s /q "%ProgramFiles(x86)%\WindowsInstallationAssistant" >NUL 2>nul

echo Configuring tasks
schtasks /change /tn "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\WindowsUpdate\Scheduled Start" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Windows Error Reporting\QueueReporting" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Application Experience\AitAgent" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\WindowsUpdate\Scheduled Start" /disable >NUL 2>nul

schtasks /change /tn "\Microsoft\Windows\UpdateOrchestrator\StartOobeAppsScanAfterUpdate" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\UpdateOrchestrator\Start Oobe Expedite Work" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan" /disable >NUL 2>nul

wevtutil sl Microsoft-Windows-SleepStudy/Diagnostic /q:false >NUL 2>nul
wevtutil sl Microsoft-Windows-Kernel-Processor-Power/Diagnostic /q:false >NUL 2>nul
wevtutil sl Microsoft-Windows-UserModePowerService/Diagnostic /q:false >NUL 2>nul

echo Configuring boot settings
bcdedit /deletevalue useplatformclock >NUL 2>nul
::bcdedit /set useplatformtick yes >NUL 2>nul
::bcdedit /set disabledynamictick yes >NUL 2>nul    breaks ROG Ally sleep, see #167
bcdedit /deletevalue disabledynamictick >NUL 2>nul
bcdedit /set bootmenupolicy Legacy >NUL 2>nul
bcdedit /set lastknowngood yes >NUL 2>nul

echo Configuring teredo
netsh interface Teredo set state type=default >NUL 2>nul
netsh interface Teredo set state servername=default >NUL 2>nul

echo Configuring Windows settings
net accounts /maxpwage:unlimited
  
PowerShell -NonInteractive -NoLogo -NoProfile -Command "Disable-WindowsErrorReporting"
setx DOTNET_CLI_TELEMETRY_OPTOUT 1
setx POWERSHELL_TELEMETRY_OPTOUT 1
