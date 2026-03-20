Write-Host "Using Disk Cleanup with custom configuration"
$volumeCache = @{
    "Active Setup Temp Folders"      = 2
    "BranchCache"                    = 2
    "Delivery Optimization Files"    = 2
    "Device Driver Packages"         = 2
    "Downloaded Program Files"       = 2
    "Internet Cache Files"           = 2
    "Language Pack"                  = 2
    "Offline Pages Files"            = 2
    "Old ChkDsk Files"               = 2
    "Setup Log Files"                = 2
    "System error memory dump files" = 2
    "System error minidump files"    = 2
    "Temporary Setup Files"          = 2
    "Temporary Sync Files"           = 2
    "Update Cleanup"                 = 2
    "Upgrade Discarded Files"        = 2
    "User file versions"             = 2
    "Windows Defender"               = 2
    "Windows Error Reporting Files"  = 2
    "Windows Reset Log Files"        = 2
    "Windows Upgrade Log Files"      = 2
}

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"

foreach ($item in $volumeCache.GetEnumerator()) {
    $keyPath = Join-Path $registryPath $item.Key
    if (Test-Path $keyPath) {
        New-ItemProperty -Path $keyPath -Name StateFlags1337 -Value $item.Value -PropertyType DWord -ErrorAction SilentlyContinue | Out-Null
    }
}

Start-Process -FilePath "$env:SystemRoot\system32\cleanmgr.exe" -ArgumentList "/sagerun:1337" -Wait

Write-Host "Cleaning up Event Logs"
Get-EventLog -LogName * -ErrorAction SilentlyContinue | ForEach-Object { Clear-EventLog $_.Log -ErrorAction SilentlyContinue }

Write-Host "Disabling Reserved Storage"
Set-WindowsReservedStorageState -State Disabled -ErrorAction SilentlyContinue

Stop-Service -Name "bits"      -Force -ErrorAction SilentlyContinue
Stop-Service -Name "appidsvc"  -Force -ErrorAction SilentlyContinue
Stop-Service -Name "dps"       -Force -ErrorAction SilentlyContinue
Stop-Service -Name "wuauserv"  -Force -ErrorAction SilentlyContinue

Write-Host "Cleaning up leftovers"
$foldersToRemove = @(
    "CbsTemp",
    "Logs",
    "SoftwareDistribution",
    "System32\LogFiles",
    "System32\LogFiles\WMI",
    "System32\SleepStudy",
    "System32\sru",
    "System32\WDI\LogFiles",
    "System32\winevt\Logs",
    "SystemTemp",
    "Temp"
)

foreach ($folderName in $foldersToRemove) {
    $folderPath = Join-Path $env:SystemRoot $folderName
    if (Test-Path $folderPath) {
        Remove-Item -Path "$folderPath\*" -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
    }
}

Write-Host "Cleaning up %TEMP% for all user profiles"
Get-ChildItem -Path "$env:SystemDrive\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $userTemp = Join-Path $_.FullName "AppData\Local\Temp"
    if (Test-Path $userTemp) {
        Get-ChildItem -Path $userTemp -Exclude "AME", "Revision-Tool" -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Start-ScheduledTask -TaskPath "\Microsoft\Windows\DiskCleanup\" -TaskName "SilentCleanup" -ErrorAction SilentlyContinue

if ($env:REVI_CLEANUP_WINSXS -eq "1") {
    DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
}

$edgeUpdatePath = ${env:ProgramFiles(x86)} + "\Microsoft\EdgeUpdate\Download"
if (Test-Path -Path $edgeUpdatePath) {
    Remove-Item -Path $edgeUpdatePath -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
}