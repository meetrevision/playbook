param (
    [Parameter(Mandatory = $true)]
    [string]$WallpaperPath,

    [string]$ThemeExportPath = "$env:SystemRoot\Resources\Themes\revi.theme",

    [ValidateSet("Dark", "Light")]
    [string]$SystemMode = "Dark",

    [ValidateSet("Dark", "Light")]
    [string]$AppMode = "Dark"
)

if (-not ([Security.Principal.WindowsPrincipal] `
            [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
            [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator. Exiting."
    exit 1
}

if (-not (Test-Path $WallpaperPath)) {
    Write-Error "Wallpaper file not found at: $WallpaperPath"
    exit 1
}

$themesDir = "$env:SystemRoot\Resources\Themes"
$baseTheme = Join-Path $themesDir "aero.theme"
if (-not (Test-Path $baseTheme)) {
    Write-Error "Base theme not found at: $baseTheme"
    exit 1
}

Copy-Item -Path $baseTheme -Destination $ThemeExportPath -Force

(Get-Content $ThemeExportPath) | ForEach-Object {
    switch -Regex ($_) {
        '^Wallpaper=' { "Wallpaper=$WallpaperPath" }
        '^SystemMode=' { "SystemMode=$SystemMode" }
        '^AppMode=' { "AppMode=$AppMode" }
        default { $_ }
    }
} | Set-Content $ThemeExportPath
Write-Host "Custom theme created at $ThemeExportPath"

$regPathTemplate = "Registry::HKEY_USERS\{0}\Software\Microsoft\Windows\CurrentVersion\Themes"

Get-ChildItem Registry::HKEY_USERS | ForEach-Object {
    $sid = $_.PSChildName
    if ($sid -notmatch '(_Classes|^\.DEFAULT$)') {
        $themeKey = $regPathTemplate -f $sid
        if (-not (Test-Path $themeKey)) {
            New-Item -Path $themeKey -Force | Out-Null
        }
        Set-ItemProperty -Path $themeKey -Name "CurrentTheme" -Value $ThemeExportPath
        Write-Host "Theme assigned for user SID: $sid"
    }
}

Start-Process -FilePath $ThemeExportPath