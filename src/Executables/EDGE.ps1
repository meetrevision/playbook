param (   
    [Parameter(Mandatory = $true)]
    [ValidateSet("EdgeBrowser", "WebView", "EdgeUpdate")]
    [string]$Mode
)

function Uninstall-Process {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $originalNation = [microsoft.win32.registry]::GetValue('HKEY_USERS\.DEFAULT\Control Panel\International\Geo', 'Nation', [Microsoft.Win32.RegistryValueKind]::String)

    # Set Nation to 84 (France) temporarily
    [microsoft.win32.registry]::SetValue('HKEY_USERS\.DEFAULT\Control Panel\International\Geo', 'Nation', 84, [Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    
    $baseKey = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate'
    $registryPath = $baseKey + '\ClientState\' + $Key

    if (!(Test-Path -Path $registryPath)) {
        Write-Host "[$Mode] Registry key not found: $registryPath"
        return
    }

    Remove-ItemProperty -Path $registryPath -Name "experiment_control_labels" -ErrorAction SilentlyContinue | Out-Null

    # Needed to activate BrowserReplacement
    # Not needed if windir is set to an empty string, but keeping it in case Windows Updates reinstalls Edge
    $folderPath = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"

    if (!(Test-Path -Path $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
    }
    New-Item -ItemType File -Path $folderPath -Name "MicrosoftEdge.exe" -Force | Out-Null
    #

    # Setting windir to an empty string allows the Edge uninstallation to work
    [microsoft.win32.registry]::SetValue('HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Session Manager\Environment', 'windir', "", [Microsoft.Win32.RegistryValueKind]::ExpandString) | Out-Null
    $env:windir = [System.Environment]::GetEnvironmentVariable("windir","Machine")

    $uninstallString = (Get-ItemProperty -Path $registryPath).UninstallString
    $uninstallArguments = (Get-ItemProperty -Path $registryPath).UninstallArguments

    if ([string]::IsNullOrEmpty($uninstallString) -or [string]::IsNullOrEmpty($uninstallArguments)) {
        Write-Host "[$Mode] Cannot find uninstall methods for $Mode"
        return
    }

    $uninstallArguments += " --force-uninstall --delete-profile"

    # $uninstallCommand = "`"$uninstallString`"" + $uninstallArguments
    if (!(Test-Path -Path $uninstallString)) {
        Write-Host "[$Mode] setup.exe not found at: $uninstallString"
        return
    }
    Start-Process -FilePath $uninstallString -ArgumentList $uninstallArguments -Wait -NoNewWindow -Verbose

    # Restore Nation
    [microsoft.win32.registry]::SetValue('HKEY_USERS\.DEFAULT\Control Panel\International\Geo', 'Nation', $originalNation, [Microsoft.Win32.RegistryValueKind]::String) | Out-Null

    # Restore windir
    [microsoft.win32.registry]::SetValue('HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Session Manager\Environment', 'windir', '%SystemRoot%', [Microsoft.Win32.RegistryValueKind]::ExpandString) | Out-Null

    if ((Get-ItemProperty -Path $baseKey).IsEdgeStableUninstalled -eq 1) {
        Write-Host "[$Mode] Edge Stable has been successfully uninstalled"
    }
}

function Uninstall-Edge {
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" -Name "NoRemove" -ErrorAction SilentlyContinue | Out-Null
   
    [microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev", "AllowUninstall", 1, [Microsoft.Win32.RegistryValueKind]::DWord) | Out-Null

    Uninstall-Process -Key '{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'
    
    @( "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
       "$env:PUBLIC\Desktop",
       "$env:USERPROFILE\Desktop" ) | ForEach-Object {
        $shortcutPath = Join-Path -Path $_ -ChildPath "Microsoft Edge.lnk"
        if (Test-Path -Path $shortcutPath) {
            Remove-Item -Path $shortcutPath -Force
        }
    }

}

function Uninstall-WebView {
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView" -Name "NoRemove" -ErrorAction SilentlyContinue | Out-Null

    # Force to use system-wide WebView2 
    # [microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge\WebView2\BrowserExecutableFolder", "*", "%%SystemRoot%%\System32\Microsoft-Edge-WebView")

    Uninstall-Process -Key '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
}

function Uninstall-EdgeUpdate {
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge Update" -Name "NoRemove" -ErrorAction SilentlyContinue | Out-Null

    $registryPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate'
    if (!(Test-Path -Path $registryPath)) {
        Write-Host "Registry key not found: $registryPath"
        return
    }
    $uninstallCmdLine = (Get-ItemProperty -Path $registryPath).UninstallCmdLine

    if ([string]::IsNullOrEmpty($uninstallCmdLine)) {
        Write-Host "Cannot find uninstall methods for $Mode"
        return
    }

    Write-Output "Uninstalling: $uninstallCmdLine"
    Start-Process cmd.exe "/c $uninstallCmdLine" -WindowStyle Hidden -Wait
}

switch ($Mode) {
    "EdgeBrowser" { Uninstall-Edge }
    # "WebView" { Uninstall-WebView }
    # "EdgeUpdate" { Uninstall-EdgeUpdate }
    default { Write-Host "Invalid mode: $Mode" }
}