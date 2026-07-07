param(
    [string] $ReviToolPath = "$env:ProgramFiles\Revision Tool\revitool.exe",
    [string] $GuiPath = "$env:ProgramFiles\Revision Tool\revitoolw.exe",
    [string] $OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $baseDir = Join-Path $env:ProgramData 'Revision\Revision Tool\controller-validation'
    if ([string]::IsNullOrWhiteSpace($env:ProgramData)) {
        $baseDir = Join-Path ([IO.Path]::GetTempPath()) 'Revision-Tool\controller-validation'
    }
    $OutputPath = Join-Path $baseDir ("probe-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

function Convert-FirstJsonObject {
    param([string] $Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $start = $Text.IndexOf('{')
    $end = $Text.LastIndexOf('}')
    if ($start -lt 0 -or $end -le $start) {
        return $null
    }

    $candidate = $Text.Substring($start, $end - $start + 1)
    try {
        return $candidate | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Invoke-ControllerCommand {
    param(
        [string] $Name,
        [string[]] $Arguments
    )

    $started = Get-Date
    $output = & $ReviToolPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $ended = Get-Date
    $text = ($output | Out-String).Trim()

    return [pscustomobject]@{
        name = $Name
        arguments = $Arguments
        exitCode = $exitCode
        durationMs = [int](New-TimeSpan -Start $started -End $ended).TotalMilliseconds
        stdout = $text
        json = Convert-FirstJsonObject $text
    }
}

function Get-RegistryValue {
    param(
        [string] $Path,
        [string] $Name
    )

    try {
        return (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name
    } catch {
        return $null
    }
}

function Get-AppxPresence {
    param([string] $Name)

    try {
        $package = Get-AppxPackage -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1
        return $package -ne $null
    } catch {
        return $false
    }
}

function Find-FailedResults {
    param([object[]] $Commands)

    $failed = @()
    foreach ($command in $Commands) {
        if ($command.json -eq $null -or !($command.json.PSObject.Properties.Name -contains 'results')) {
            continue
        }
        foreach ($result in @($command.json.results)) {
            $state = ''
            if ($result.PSObject.Properties.Name -contains 'state') {
                $state = [string]$result.state
            } elseif ($result.PSObject.Properties.Name -contains 'status') {
                $state = [string]$result.status
            }

            if ($state.Equals('failed', [StringComparison]::OrdinalIgnoreCase)) {
                $failed += [pscustomobject]@{
                    command = $command.name
                    result = $result
                }
            }
        }
    }
    return $failed
}

if (!(Test-Path -LiteralPath $ReviToolPath -PathType Leaf)) {
    throw "revitool.exe was not found: $ReviToolPath"
}

$commands = @(
    (Invoke-ControllerCommand 'profile list' @('profile', 'list')),
    (Invoke-ControllerCommand 'profile apply gaming dry-run' @('profile', 'apply', 'gaming', '--dry-run', '--json')),
    (Invoke-ControllerCommand 'report last' @('report', '--last', '--json')),
    (Invoke-ControllerCommand 'profile apply gaming' @('profile', 'apply', 'gaming', '--yes')),
    (Invoke-ControllerCommand 'profile status' @('profile', 'status', '--json'))
)

$failedResults = @(Find-FailedResults $commands)
$failedCommands = @($commands | Where-Object { $_.exitCode -ne 0 })

$metadata = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    computerName = $env:COMPUTERNAME
    currentUser = "$env:USERDOMAIN\$env:USERNAME"
    revitoolPath = $ReviToolPath
    revitoolExists = (Test-Path -LiteralPath $ReviToolPath -PathType Leaf)
    guiPath = $GuiPath
    guiExists = (Test-Path -LiteralPath $GuiPath -PathType Leaf)
    windowsBuild = Get-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'CurrentBuildNumber'
    windowsDisplayVersion = Get-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'
    windowsEdition = Get-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'EditionID'
}

$networkOk = $false
try {
    $networkOk = [bool](Test-NetConnection 'www.microsoft.com' -Port 443 -InformationLevel Quiet)
} catch {
    $networkOk = $false
}

$wuService = $null
try {
    $service = Get-Service -Name 'wuauserv' -ErrorAction Stop
    $wuService = [pscustomobject]@{ status = [string]$service.Status; startType = [string]$service.StartType }
} catch {
    $wuService = [pscustomobject]@{ status = 'missing'; startType = '' }
}

$audioDevices = @()
try {
    $audioDevices = @(Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue | Select-Object Name,Status)
} catch {
    $audioDevices = @()
}

$probe = [pscustomobject]@{
    metadata = $metadata
    checks = [pscustomobject]@{
        networkHttps = $networkOk
        windowsUpdateService = $wuService
        audioDevices = $audioDevices
        appx = [pscustomobject]@{
            store = Get-AppxPresence 'Microsoft.WindowsStore'
            xbox = Get-AppxPresence 'Microsoft.XboxApp'
            gamingServices = Get-AppxPresence 'Microsoft.GamingServices'
        }
    }
    commands = $commands
    failedCommands = $failedCommands
    failedResults = $failedResults
}

$outputDir = Split-Path -Parent $OutputPath
if (![string]::IsNullOrWhiteSpace($outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
$probe | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "Probe JSON: $OutputPath"

if ($failedCommands.Count -gt 0 -or $failedResults.Count -gt 0) {
    exit 1
}

exit 0
