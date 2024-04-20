@echo off
set version=1.0
for /f "tokens=2 delims==" %%i in ('wmic os get BuildNumber /value ^| find "="') do set "build=%%i"
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

if not defined w11 (
	bcdedit /set description "ReviOS 10 %version%" >NUL 2>nul
  reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v "Model"  /t REG_SZ /d "ReviOS 10 %version%" /f >NUL 2>nul
  reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "RegisteredOrganization" /t REG_SZ /d "ReviOS 10 %version%" /f >NUL 2>nul
) else (
	bcdedit /set description "ReviOS 11 %version%" >NUL 2>nul
  reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v "Model"  /t REG_SZ /d "ReviOS 11 %version%" /f >NUL 2>nul
  reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "RegisteredOrganization" /t REG_SZ /d "ReviOS 11 %version%" /f >NUL 2>nul
)

@REM PowerShell -NonInteractive -NoLogo -NoP -C "Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod" >NUL 2>nul

echo Configuring power settings
powercfg /hibernate off
powercfg -restoredefaultschemes
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 3ff9831b-6f80-4830-8178-736cd4229e7b
powercfg -changename 3ff9831b-6f80-4830-8178-736cd4229e7b "Revision - Ultra Performance" "Windows's Ultimate Performance with additional changes."
powercfg -s 3ff9831b-6f80-4830-8178-736cd4229e7b
powercfg -setacvalueindex scheme_current sub_processor PERFINCPOL 2
powercfg -setacvalueindex scheme_current sub_processor PERFDECPOL 1
powercfg -setacvalueindex scheme_current sub_processor PERFINCTHRESHOLD 10
powercfg -setacvalueindex scheme_current sub_processor PERFDECTHRESHOLD 8
powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100
powercfg -setacvalueindex scheme_current sub_processor CPMINCORES1 100
powercfg /setactive scheme_current

@REM PowerShell -NonInteractive -NoLogo -NoP -C "& {$cpu = Get-CimInstance Win32_Processor; $cpuName = $cpu.Name; if ($cpu.Manufacturer -eq 'GenuineIntel') { if ($cpuName.Substring(0, 2) -eq 'In') { Write-Host 'Detected Intel CPU older than 10th generation.' } else { $cpuGen = [int]($cpuName.Substring(0, 2)); if ($cpuGen -gt 11) { Write-Host 'Optimizing Revision''s Ultra powerplan for 12th generation or later Intel CPUs'; powercfg -changename 3ff9831b-6f80-4830-8178-736cd4229e7b 'Revision - Ultra Performance' 'Windows''s Ultimate Performance with optimized settings for newer Intel CPUs.'; powercfg -s 3ff9831b-6f80-4830-8178-736cd4229e7b; powercfg -setacvalueindex scheme_current sub_processor HETEROPOLICY 0; powercfg -setacvalueindex scheme_current sub_processor SCHEDPOLICY 2; powercfg /setactive scheme_current }}};}"

echo Configuring tasks
schtasks /change /tn "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\WindowsUpdate\Scheduled Start" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Windows Error Reporting\QueueReporting" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Application Experience\AitAgent" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" /disable >NUL 2>nul
wevtutil sl Microsoft-Windows-SleepStudy/Diagnostic /q:false >NUL 2>nul
wevtutil sl Microsoft-Windows-Kernel-Processor-Power/Diagnostic /q:false >NUL 2>nul
wevtutil sl Microsoft-Windows-UserModePowerService/Diagnostic /q:false >NUL 2>nul

echo Configuring boot settings
bcdedit /deletevalue useplatformclock >NUL 2>nul
::bcdedit /set useplatformtick yes >NUL 2>nul
bcdedit /set disabledynamictick yes >NUL 2>nul
bcdedit /set bootmenupolicy Legacy >NUL 2>nul
bcdedit /set lastknowngood yes >NUL 2>nul

echo Optimizing NTFS settings
fsutil behavior set disableLastAccess 1 >NUL 2>nul
fsutil behavior set disable8dot3 1 >NUL 2>nul

echo Configuring teredo
netsh interface Teredo set state type=default >NUL 2>nul
netsh interface Teredo set state servername=default >NUL 2>nul

::https://github.com/meetrevision/playbook/issues/27
::netsh int tcp set supplemental internet congestionprovider=bbr2 >NUL 2>nul

echo Configuring Windows settings
net accounts /maxpwage:unlimited
  
PowerShell -NonInteractive -NoLogo -NoProfile -Command "Disable-MMAgent -mc"
PowerShell -NonInteractive -NoLogo -NoProfile -Command "Disable-WindowsErrorReporting"
powershell -NonInteractive -NoLogo -NoProfile Set-ProcessMitigation -Name vgc.exe -Enable CFG
:: - !cmd: {exeDir: true, command: '@echo Disable-MMAgent -MC; ForEach($v in (Get-Command -Name "Set-ProcessMitigation").Parameters["Disable"].Attributes.ValidValues){Set-ProcessMitigation -System -Disable $v.ToString().Replace(" ", "").Replace("`n", "")}; rm $PSCommandPath> MC_PM.ps1'}
:: - !run: {exeDir: true, exe: 'powershell -windowstyle hidden -ExecutionPolicy Bypass -C "& ''./MC_PM.ps1''"'}
setx DOTNET_CLI_TELEMETRY_OPTOUT 1
setx POWERSHELL_TELEMETRY_OPTOUT 1

echo Disabling Superfetch for SSD...

for /f %%i in ('PowerShell -NonInteractive -NoLogo -NoP -C "(Get-PhysicalDisk -SerialNumber (Get-Disk -Number (Get-Partition -DriveLetter $env:SystemDrive.Substring(0, 1)).DiskNumber).SerialNumber.TrimStart()).MediaType"') do set "hardDrive=%%i"

if "%hardDrive%"=="SSD" (
  @start /b "" "%programfiles(x86)%\Revision Tool\data\flutter_assets\additionals\DisableSF.bat"
)

echo Configuring animations

:: Breaks XboxGipSvc
::reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v "SvcHostSplitThresholdInKB" /t REG_DWORD /d "4294967295" /f >NUL

for /f "tokens=2 delims==" %%a in ('wmic os get TotalVisibleMemorySize /format:value') do set "mem=%%a"

for /f "usebackq tokens=2 delims=\" %%a in (`reg query "HKEY_USERS" ^| findstr /r /x /c:"HKEY_USERS\\S-.*" /c:"HKEY_USERS\\AME_UserHive_[^_]*"`) do (
  REM If the "Volatile Environment" key exists, that means it is a proper user. Built in accounts/SIDs do not have this key.
  reg query "HKEY_USERS\%%a" | findstr /c:"Volatile Environment" /c:"AME_UserHive_" > nul 2>&1
    if not errorlevel 1 (
      if %mem% lss 9000000 ( 
        reg add "HKU\%%a\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t REG_DWORD /d "0" /f >NUL
        reg add "HKU\%%a\Control Panel\Desktop\WindowMetrics" /v "MinAnimate" /t REG_SZ /d "0" /f >NUL 2>nul
      )
    )
  )

:: https://github.com/meetrevision/playbook/issues/15
:: Updates root certificates

::echo Updating root certificates

::PowerShell -NonInteractive -NoLogo -NoP -C "& {$tmp = (New-TemporaryFile).FullName; CertUtil -generateSSTFromWU -f $tmp; if ( (Get-Item $tmp | Measure-Object -Property Length -Sum).sum -gt 0 ) { $SST_File = Get-ChildItem -Path $tmp; $SST_File | Import-Certificate -CertStoreLocation "Cert:\LocalMachine\Root"; $SST_File | Import-Certificate -CertStoreLocation "Cert:\LocalMachine\AuthRoot" } Remove-Item -Path $tmp}" >NUL 2>nul

