param(
    [string] $RevisionToolRoot,
    [string] $InstallerPath,
    [string] $Version = 'local-controller',
    [string] $OutputDir,
    [string] $SevenZipPath,
    [switch] $SkipValidation,
    [switch] $NoPackage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PlaybookRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$WorkspaceRoot = (Resolve-Path (Join-Path $PlaybookRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($RevisionToolRoot)) {
    $RevisionToolRoot = Join-Path $WorkspaceRoot 'revision-tool'
}
$RevisionToolRoot = (Resolve-Path $RevisionToolRoot).Path

if ([string]::IsNullOrWhiteSpace($InstallerPath)) {
    $InstallerPath = Join-Path $RevisionToolRoot 'RevisionTool-Setup.exe'
}
$InstallerPath = (Resolve-Path $InstallerPath).Path

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $WorkspaceRoot 'artifacts\local-controller'
}

function Assert-File {
    param([string] $Path)

    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file does not exist: $Path"
    }
}

function Assert-PathInside {
    param(
        [string] $Child,
        [string] $Parent
    )

    $trimChars = [char[]]@('\', '/')
    $childFull = [IO.Path]::GetFullPath($Child).TrimEnd($trimChars)
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd($trimChars) + [IO.Path]::DirectorySeparatorChar
    if (!$childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify path outside output directory. Child=$childFull Parent=$parentFull"
    }
}

function Write-TextNoBom {
    param(
        [string] $Path,
        [string] $Text
    )

    $encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Invoke-External {
    param(
        [string] $Name,
        [string] $Command,
        [string[]] $Arguments,
        [string] $WorkingDirectory
    )

    Write-Host ''
    Write-Host "==> $Name"
    Push-Location $WorkingDirectory
    try {
        & $Command @Arguments
        $exitCode = $LASTEXITCODE
        if ($null -ne $exitCode -and $exitCode -ne 0) {
            throw "$Name failed with exit code $exitCode."
        }
    } finally {
        Pop-Location
    }
}

function Resolve-SevenZip {
    if (![string]::IsNullOrWhiteSpace($SevenZipPath)) {
        $resolved = (Resolve-Path $SevenZipPath).Path
        Assert-File $resolved
        return $resolved
    }

    $command = Get-Command '7z.exe' -ErrorAction SilentlyContinue
    if ($command -ne $null) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
        (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw "7-Zip was not found. Install 7-Zip, or pass -SevenZipPath with the full path to 7z.exe."
}

Assert-File $InstallerPath

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$OutputDir = (Resolve-Path $OutputDir).Path
$StagingRoot = Join-Path $OutputDir 'playbook-staging'

Assert-PathInside $StagingRoot $OutputDir
if (Test-Path -LiteralPath $StagingRoot) {
    Remove-Item -LiteralPath $StagingRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $StagingRoot -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $PlaybookRoot 'src') -Destination $StagingRoot -Recurse -Force
Copy-Item -LiteralPath $InstallerPath -Destination (Join-Path $StagingRoot 'src\Executables\RevisionTool-Setup.exe') -Force

$startTask = Join-Path $StagingRoot 'src\Configuration\Tasks\start.yml'
$startText = [IO.File]::ReadAllText($startTask)
$pattern = @'
(?ms)^  - !writeStatus: \{status: 'Installing Revision Tool'\}\r?\n  - !download:\s*\r?\n    url: 'https://github\.com/meetrevision/revision-tool/releases/latest/download/RevisionTool-Setup\.exe'\r?\n    destination: "RevisionTool-Setup\.exe"\r?\n    overwrite: true\r?\n  - !run:\r?\n    exeDir: true\r?\n    exe: "RevisionTool-Setup\.exe"\r?\n    args: '/VERYSILENT /TASKS="desktopicon"'\r?\n    weight: 150
'@
$pattern = $pattern.Replace(
    'https://github\.com/meetrevision/revision-tool/releases/latest/download/RevisionTool-Setup\.exe',
    'https://github\.com/(?:meetrevision/revision-tool/releases/latest/download|Drizzy07x/revision-tool/releases/download/[^/]+)/RevisionTool-Setup\.exe'
)
$pattern = $pattern.Trim()
$replacement = @'
  - !writeStatus: {status: 'Installing local Revision Tool'}
  - !run:
    exeDir: true
    exe: "RevisionTool-Setup.exe"
    args: '/VERYSILENT /TASKS="desktopicon"'
    weight: 150
'@
$replacement = $replacement.TrimEnd()
$regex = New-Object System.Text.RegularExpressions.Regex $pattern
$matches = $regex.Matches($startText)
if ($matches.Count -ne 1) {
    throw "Expected exactly one public Revision Tool download/install block in staged start.yml, found $($matches.Count)."
}

$patchedStart = $regex.Replace($startText, $replacement, 1)
if ($patchedStart -match 'releases/(?:latest/download|download/[^/]+)/RevisionTool-Setup\.exe') {
    throw 'Staged playbook still references the public Revision Tool installer.'
}
if ($patchedStart -notmatch 'profile apply gaming --yes') {
    throw 'Staged playbook no longer applies the gaming profile.'
}
Write-TextNoBom $startTask $patchedStart

if (!$SkipValidation) {
    Invoke-External -Name 'Validate staged playbook with Python' -Command 'python' -Arguments @((Join-Path $PlaybookRoot 'scripts\validate_playbook.py'), '--root', $StagingRoot) -WorkingDirectory $PlaybookRoot
    Invoke-External -Name 'Validate staged playbook with PowerShell' -Command 'powershell.exe' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PlaybookRoot 'scripts\validate_playbook.ps1'), '-Root', $StagingRoot) -WorkingDirectory $PlaybookRoot
}

if ($NoPackage) {
    Write-Host ''
    Write-Host "Staged local playbook is ready:"
    Write-Host "  $StagingRoot"
    exit 0
}

$sevenZip = Resolve-SevenZip
$packagePath = Join-Path $OutputDir "Revi-PB-$Version.apbx"
Assert-PathInside $packagePath $OutputDir
if (Test-Path -LiteralPath $packagePath -PathType Leaf) {
    Remove-Item -LiteralPath $packagePath -Force
}

Invoke-External -Name 'Package local controller APBX' -Command $sevenZip -Arguments @('a', '-pmalte', '-mhe=on', $packagePath, '.\src\*') -WorkingDirectory $StagingRoot
Assert-File $packagePath
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $packagePath

Write-Host ''
Write-Host 'Local controller playbook payload ready:'
Write-Host "  Staging: $StagingRoot"
Write-Host "  APBX:    $packagePath"
Write-Host "  SHA256:  $($hash.Hash)"
