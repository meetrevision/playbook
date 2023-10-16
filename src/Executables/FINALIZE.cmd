@echo off
set version=23.10
for /f "tokens=2 delims==" %%i in ('wmic os get BuildNumber /value ^| find "="') do set "build=%%i"
if %build% gtr 19045 ( set "w11=true" )

if not defined w11 (
	bcdedit /set description "ReviOS 10 %version%" >NUL 2>nul
  reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v "Model"  /t REG_SZ /d "ReviOS 10 %version%" /f >NUL 2>nul
  reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "RegisteredOrganization" /t REG_SZ /d "ReviOS 10 %version%" /f >NUL 2>nul
) else (
	bcdedit /set description "ReviOS 11 %version%" >NUL 2>nul
  reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v "Model"  /t REG_SZ /d "ReviOS 11 %version%" /f >NUL 2>nul
  reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "RegisteredOrganization" /t REG_SZ /d "ReviOS 11 %version%" /f >NUL 2>nul

  :: Credits to Garlin for the idea
  PowerShell -NonInteractive -NoLogo -NoP -C "& { $Cbs = \"$env:SystemRoot\\SystemApps\\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\"; $Manifest = Join-Path $Cbs 'appxmanifest.xml'; takeown /a /f $Manifest; icacls $Manifest /grant Administrators:F; $ReviManifest = Join-Path $Cbs \"appxmanifest.xml.revi\"; if (!(Test-Path $ReviManifest)) { Copy-Item -Path $Manifest -Destination $ReviManifest -Force; Remove-Item $Manifest -Force }; [xml]$xml = Get-Content -Path \"$Cbs\\appxmanifest.xml.revi\" -Raw; $applicationNode = $xml.Package.Applications.Application | Where-Object { $_.Id -eq 'WebExperienceHost' }; if ($applicationNode -ne $null) { $xml.Package.Applications.RemoveChild($applicationNode) } $xml.Save($Manifest) }"
)

PowerShell -NonInteractive -NoLogo -NoP -C "& {$cpu = Get-CimInstance Win32_Processor; $cpuName = $cpu.Name; if ($cpu.Manufacturer -eq 'GenuineIntel') { if ($cpuName.Substring(0, 2) -eq 'In') { Write-Host 'Detected Intel CPU older than 10th generation.' } else { $cpuGen = [int]($cpuName.Substring(0, 2)); if ($cpuGen -gt 11) { Write-Host 'Optimizing Revision''s Ultra powerplan for 12th generation or later Intel CPUs'; powercfg -changename 3ff9831b-6f80-4830-8178-736cd4229e7b 'Revision - Ultra Performance' 'Windows''s Ultimate Performance with optimized settings for newer Intel CPUs.'; powercfg -s 3ff9831b-6f80-4830-8178-736cd4229e7b; powercfg -setacvalueindex scheme_current sub_processor HETEROPOLICY 0; powercfg -setacvalueindex scheme_current sub_processor SCHEDPOLICY 2; powercfg /setactive scheme_current }}};}"

echo Disabling Superfetch for SSD...

for /f %%i in ('PowerShell -NonInteractive -NoLogo -NoP -C "(Get-PhysicalDisk -SerialNumber (Get-Disk -Number (Get-Partition -DriveLetter $env:SystemDrive.Substring(0, 1)).DiskNumber).SerialNumber.TrimStart()).MediaType"') do set "hardDrive=%%i"

if "%hardDrive%"=="SSD" (
  @start /b "" "%programfiles(x86)%\Revision Tool\data\flutter_assets\additionals\MinSudo.exe" --NoLogo --TrustedInstaller "%programfiles(x86)%\Revision Tool\data\flutter_assets\additionals\DisableSF.bat"
)

echo Configuring memory...

reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v "SvcHostSplitThresholdInKB" /t REG_DWORD /d "4294967295" /f >NUL
reg add "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" /v "AllowInputPersonalization" /t REG_DWORD /d "0" /f >NUL

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

PowerShell -NonInteractive -NoLogo -NoP -C "& {$tmp = (New-TemporaryFile).FullName; CertUtil -generateSSTFromWU -f $tmp; if ( (Get-Item $tmp | Measure-Object -Property Length -Sum).sum -gt 0 ) { $SST_File = Get-ChildItem -Path $tmp; $SST_File | Import-Certificate -CertStoreLocation "Cert:\LocalMachine\Root"; $SST_File | Import-Certificate -CertStoreLocation "Cert:\LocalMachine\AuthRoot" } Remove-Item -Path $tmp}" >NUL 2>nul

