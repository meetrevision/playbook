param(
    [string]$FirefoxDir = "$env:ProgramFiles\Mozilla Firefox"
)

$distDir = Join-Path $FirefoxDir "distribution"

if (-not (Test-Path $FirefoxDir)) {
    Write-Host "Firefox not installed at $FirefoxDir, skipping policy."
    exit 0
}

if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

$policy = @{
    policies = @{
        DisableTelemetry              = $true
        DisablePocket                 = $true
        CaptivePortal                 = $false
        DisableFirefoxStudies         = $true
        DisableDefaultBrowserAgent    = $true
        ExtensionSettings             = @{
            'uBlock0@raymondhill.net' = @{
                installation_mode = 'force_installed'
                install_url       = 'https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi'
            }
        }
        Preferences                   = @{
            'network.cookie.sameSite.laxByDefault'                           = @{ Value = $true;      Status = 'user' }
            'network.cookie.sameSite.noneRequiresSecure'                     = @{ Value = $true;      Status = 'user' }
            'network.cookie.sameSite.schemeful'                              = @{ Value = $true;      Status = 'user' }
            'browser.contentblocking.category'                               = @{ Value = 'strict';   Status = 'user' }
            'browser.newtabpage.activity-stream.showSponsored'               = @{ Value = $false;     Status = 'user' }
            'browser.newtabpage.activity-stream.showSponsoredTopSites'       = @{ Value = $false;     Status = 'user' }
        }
    }
} | ConvertTo-Json -Depth 10

$policyPath = Join-Path $distDir "policies.json"
[System.IO.File]::WriteAllText($policyPath, $policy, [System.Text.Encoding]::UTF8)
Write-Host "Firefox policy written to $policyPath"
