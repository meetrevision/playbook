param (
    [Parameter(Mandatory = $true, ParameterSetName = 'SetExistingTheme')]
    [string]$Path,

    [Parameter(Mandatory = $true, ParameterSetName = 'NewCustomTheme')]
    [hashtable]$New
)

if (-not ([Security.Principal.WindowsPrincipal] `
            [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
            [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator. Exiting."
    exit 1
}

function Set-ExistingTheme {
    param ([string]$ThemePath)
    
    if (-not (Test-Path $ThemePath)) {
        Write-Error "Theme file not found at: $ThemePath"
        exit 1
    }
    
    Write-Host "Applying existing theme from: $ThemePath"
    
    $regPathTemplate = "Registry::HKEY_USERS\{0}\Software\Microsoft\Windows\CurrentVersion\Themes"
    
    Get-ChildItem Registry::HKEY_USERS | ForEach-Object {
        $sid = $_.PSChildName
        if ($sid -notmatch '(_Classes|^\.DEFAULT$)') {
            $themeKey = $regPathTemplate -f $sid
            if (-not (Test-Path $themeKey)) {
                New-Item -Path $themeKey -Force | Out-Null
            }
            Set-ItemProperty -Path $themeKey -Name "CurrentTheme" -Value $ThemePath
            Write-Host "Theme assigned for user SID: $sid"
        }
    }
    
    Start-Process -FilePath $ThemePath
}

function New-CustomTheme {
    param ([hashtable]$Config)
    
    if (-not $Config.ContainsKey('WallpaperPath')) {
        Write-Error "WallpaperPath is required in the hashtable"
        exit 1
    }
    
    $wallpaperPath = $Config['WallpaperPath']
    $themeExportPath = if ($Config.ContainsKey('ThemeExportPath')) { $Config['ThemeExportPath'] } else { "$env:SystemRoot\Resources\Themes\revi.theme" }
    $systemMode = if ($Config.ContainsKey('SystemMode')) { $Config['SystemMode'] } else { 'Dark' }
    $appMode = if ($Config.ContainsKey('AppMode')) { $Config['AppMode'] } else { 'Dark' }
    
    if ($systemMode -notin @('Dark', 'Light')) {
        Write-Error "SystemMode must be 'Dark' or 'Light'"
        exit 1
    }
    if ($appMode -notin @('Dark', 'Light')) {
        Write-Error "AppMode must be 'Dark' or 'Light'"
        exit 1
    }
    
    if (-not (Test-Path $wallpaperPath)) {
        Write-Error "Wallpaper file not found at: $wallpaperPath"
        exit 1
    }
    
    $themesDir = "$env:SystemRoot\Resources\Themes"
    $baseTheme = if ($systemMode -eq 'Dark') { "$themesDir\dark.theme" } else { "$themesDir\aero.theme" }
    if (-not (Test-Path $baseTheme)) {
        Write-Error "Base theme not found at: $baseTheme"
        exit 1
    }
    
    Copy-Item -Path $baseTheme -Destination $themeExportPath -Force
    
    (Get-Content $themeExportPath -Encoding Unicode) | ForEach-Object {
        switch -Regex ($_) {
            '^Wallpaper=' { "Wallpaper=$wallpaperPath" }
            '^SystemMode=' { "SystemMode=$systemMode" }
            '^AppMode=' { "AppMode=$appMode" }
            default { $_ }
        }
    } | Set-Content $themeExportPath -Encoding Unicode
    
    Write-Host "Custom theme created at $themeExportPath"
    
    Set-ExistingTheme -ThemePath $themeExportPath
}

switch ($PSCmdlet.ParameterSetName) {
    'SetExistingTheme' {
        Set-ExistingTheme -ThemePath $Path
    }
    'NewCustomTheme' {
        New-CustomTheme -Config $New
    }
}