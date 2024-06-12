<# :
@echo off &pushd "%~dp0"
@set batch_args=%*
@powershell "iex (cat -Raw '%~f0')"
@exit /b %ERRORLEVEL%
: #>

$setupPaths = @(
    "$env:systemroot\System32\OneDriveSetup.exe",
    "$env:systemroot\SysWOW64\OneDriveSetup.exe"
)
$uninstallArguments = "/uninstall"

# $sid = (([System.Security.Principal.WindowsIdentity]::GetCurrent()).User).Value

$uninstallRegPaths = New-Object System.Collections.ArrayList
New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
$users = Get-ChildItem 'HKU:\'
foreach ($user in $users) {
    if (Test-Path "HKU:\$($user.PSChildName)\Volatile Environment") {
        $regPath = "HKU:\$($user.PSChildName)\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe"
        $uninstallString = (Get-ItemProperty -Path $regPath).UninstallString

        if (!([string]::IsNullOrEmpty($uninstallString))) {
            $uninstallFilePath = [System.IO.Path]::GetDirectoryName($uninstallString)
            $uninstallRegPaths.Add($uninstallFilePath)
        }
        
        Remove-ItemProperty -Path "HKU:\$($user.PSChildName)\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue
    }
}

if ($uninstallRegPaths.Count -ne 0) {
    $setupPaths = @($uninstallRegPaths) + $setupPaths
}

$setupPaths | ForEach-Object {
    if (Test-Path $_) {
        Write-Host "Uninstalling OneDrive from $_"
        Start-Process -FilePath $_ -ArgumentList $uninstallArguments -Verbose -Wait -NoNewWindow -PassThru
    }
}

Get-ChildItem -Path "$env:SystemDrive\Users" -Directory | ForEach-Object {
    $oneDrivePath = Join-Path $_.FullName "AppData\Local\Microsoft\OneDrive"
    if (Test-Path $oneDrivePath) {
        Remove-Item -Path $oneDrivePath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $oneDriveLinkPath = Join-Path $_.FullName "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"
    if (Test-Path $oneDriveLinkPath) {
        Remove-Item -Path $oneDriveLinkPath -Force -ErrorAction SilentlyContinue | Out-Null
    }
}