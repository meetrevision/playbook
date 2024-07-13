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
        $uninstallString = (Get-ItemProperty -Path $regPath -EA SilentlyContinue).UninstallString

        if (!([string]::IsNullOrEmpty($uninstallString))) {
            $uninstallFilePath = [System.IO.Path]::GetDirectoryName($uninstallString)
            $uninstallRegPaths.Add($uninstallFilePath)
        }
        
        Remove-ItemProperty -Path "HKU:\$($user.PSChildName)\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -EA SilentlyContinue

        Remove-Item -Path "HKU:\$($user.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe" -Force -EA SilentlyContinue
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

# Remove OneDrive from the Explorer sidebar
[microsoft.win32.registry]::SetValue("HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}", "System.IsPinnedToNameSpaceTree", 0, [Microsoft.Win32.RegistryValueKind]::DWord)
