[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $IsoPath,
    [string] $InjectedIsoPath,
    [string] $OutputPath,
    [switch] $OpenDownloadPage,
    [switch] $OpenAmePage,
    [string] $MicrosoftDownloadPage = 'https://www.microsoft.com/software-download/windows11',
    [string] $AmePage = 'https://amelabs.net/'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$PlaybookRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$WorkspaceRoot = (Resolve-Path (Join-Path $PlaybookRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $WorkspaceRoot 'artifacts\local-controller\iso-manifest.json'
}

function Get-HashInfo {
    param([string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    $item = Get-Item -LiteralPath $Path
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    return [pscustomobject]@{
        path = $item.FullName
        length = $item.Length
        lastWriteTime = $item.LastWriteTime.ToString('o')
        sha256 = $hash.Hash
    }
}

function Convert-DismInfo {
    param([string] $Text)

    $version = $null
    $name = $null
    $architecture = $null

    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^\s*Version\s*:\s*(.+?)\s*$') {
            $version = $matches[1]
        } elseif ($line -match '^\s*Name\s*:\s*(.+?)\s*$') {
            $name = $matches[1]
        } elseif ($line -match '^\s*Architecture\s*:\s*(.+?)\s*$') {
            $architecture = $matches[1]
        }
    }

    $build = $null
    if ($version -match '^10\.0\.(\d+)') {
        $build = $matches[1]
    }

    return [pscustomobject]@{
        name = $name
        architecture = $architecture
        version = $version
        build = $build
        supportedByPlaybook = @('26100', '26200') -contains $build
    }
}

function Get-IsoImageInfo {
    param([string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $resolved = (Resolve-Path $Path).Path
    if (!(Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "ISO not found: $resolved"
    }

    $mounted = $false
    try {
        if ($PSCmdlet.ShouldProcess($resolved, 'Mount ISO for build inspection')) {
            Mount-DiskImage -ImagePath $resolved -ErrorAction Stop | Out-Null
            $mounted = $true
        } else {
            return [pscustomobject]@{
                image = Get-HashInfo $resolved
                mounted = $false
                installImage = $null
                dism = $null
            }
        }

        $volume = Get-DiskImage -ImagePath $resolved | Get-Volume | Select-Object -First 1
        if ($volume -eq $null -or [string]::IsNullOrWhiteSpace($volume.DriveLetter)) {
            throw "Mounted ISO has no drive letter: $resolved"
        }

        $root = "$($volume.DriveLetter):\"
        $installWim = Join-Path $root 'sources\install.wim'
        $installEsd = Join-Path $root 'sources\install.esd'
        $installImage = if (Test-Path -LiteralPath $installWim -PathType Leaf) {
            $installWim
        } elseif (Test-Path -LiteralPath $installEsd -PathType Leaf) {
            $installEsd
        } else {
            $null
        }

        if ($installImage -eq $null) {
            throw "ISO does not contain sources\\install.wim or sources\\install.esd."
        }

        $dismOutput = & Dism.exe /English /Get-WimInfo /WimFile:$installImage /Index:1 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            throw "DISM failed while reading ${installImage}: $dismOutput"
        }

        return [pscustomobject]@{
            image = Get-HashInfo $resolved
            mounted = $true
            installImage = $installImage
            dism = Convert-DismInfo $dismOutput
        }
    } finally {
        if ($mounted) {
            Dismount-DiskImage -ImagePath $resolved -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

if ($OpenDownloadPage -and $PSCmdlet.ShouldProcess($MicrosoftDownloadPage, 'Open Microsoft Windows 11 download page')) {
    Start-Process $MicrosoftDownloadPage
}

if ($OpenAmePage -and $PSCmdlet.ShouldProcess($AmePage, 'Open AME Labs download page')) {
    Start-Process $AmePage
}

$isoInfo = Get-IsoImageInfo $IsoPath
$injectedInfo = Get-HashInfo $InjectedIsoPath

$manifest = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    microsoftDownloadPage = $MicrosoftDownloadPage
    amePage = $AmePage
    iso = $isoInfo
    injectedIso = $injectedInfo
    acceptedBuilds = @('26100', '26200')
}

$outputDir = Split-Path -Parent $OutputPath
if (![string]::IsNullOrWhiteSpace($outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force -WhatIf:$false | Out-Null
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8 -WhatIf:$false

Write-Host "ISO manifest: $OutputPath"

if ($isoInfo -ne $null -and $isoInfo.dism -ne $null -and !$isoInfo.dism.supportedByPlaybook) {
    Write-Error "ISO build $($isoInfo.dism.build) is not in the accepted build list: 26100, 26200."
    exit 1
}

exit 0
