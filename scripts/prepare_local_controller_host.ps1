param(
    [switch] $CheckOnly,
    [switch] $Install,
    [string] $OutputPath,
    [switch] $DownloadAme,
    [string] $AmeDownloadUri,
    [string] $AmeOutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$PlaybookRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$WorkspaceRoot = (Resolve-Path (Join-Path $PlaybookRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $WorkspaceRoot 'artifacts\local-controller\host-prereqs.json'
}
if ([string]::IsNullOrWhiteSpace($AmeOutputDir)) {
    $AmeOutputDir = Join-Path $WorkspaceRoot 'artifacts\downloads\ame'
}

function Resolve-CommandPath {
    param(
        [string] $Command,
        [string[]] $Candidates = @()
    )

    $found = Get-Command $Command -ErrorAction SilentlyContinue
    if ($found -ne $null) {
        return $found.Source
    }

    foreach ($candidate in $Candidates) {
        if (![string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }

    return $null
}

function Test-VisualStudioWindowsToolchain {
    $flutter = Resolve-CommandPath 'flutter'
    if ($flutter -eq $null) {
        return [pscustomobject]@{ Passed = $false; Detail = 'flutter was not found on PATH.' }
    }

    $output = & flutter doctor -v 2>&1 | Out-String
    $visualStudioLine = (($output -split "`r?`n") | Where-Object { $_ -match 'Visual Studio - develop Windows apps' } | Select-Object -First 1)
    if ($visualStudioLine -match '^\s*\[\s*X\s*\]') {
        return [pscustomobject]@{ Passed = $false; Detail = 'Flutter reports Visual Studio as unavailable for Windows apps.' }
    }
    if ($output -match 'Visual Studio at .+Microsoft Visual Studio' -and $output -match 'Windows 10 SDK version') {
        return [pscustomobject]@{ Passed = $true; Detail = 'Flutter reports a Windows Visual Studio toolchain.' }
    }
    if ($output -match 'Visual Studio not installed|Desktop development with C\+\+') {
        return [pscustomobject]@{ Passed = $false; Detail = 'Flutter does not see Visual Studio C++ desktop workload.' }
    }

    return [pscustomobject]@{ Passed = $false; Detail = 'Flutter doctor did not report a usable Visual Studio Windows toolchain.' }
}

function Resolve-AmeInstall {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\AME Wizard'),
        (Join-Path $env:ProgramFiles 'AME Wizard'),
        (Join-Path ${env:ProgramFiles(x86)} 'AME Wizard'),
        (Join-Path $env:LOCALAPPDATA 'AME Wizard'),
        (Join-Path $WorkspaceRoot 'artifacts\downloads\ame\extracted')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            $exe = Get-ChildItem -LiteralPath $candidate -Recurse -File -Filter '*.exe' -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($exe -ne $null) {
                return $exe.FullName
            }
        }
    }

    return $null
}

function New-Check {
    param(
        [string] $Name,
        [bool] $Passed,
        [string] $Detail,
        [bool] $Required = $true,
        [string] $InstallId = ''
    )

    return [pscustomobject]@{
        name = $Name
        passed = $Passed
        required = $Required
        detail = $Detail
        installId = $InstallId
    }
}

function Get-Checks {
    $checks = New-Object System.Collections.Generic.List[object]

    $winget = Resolve-CommandPath 'winget'
    $checks.Add((New-Check 'winget' ($winget -ne $null) ($(if ($winget) { $winget } else { 'winget was not found.' })) $true '')) | Out-Null

    $flutter = Resolve-CommandPath 'flutter'
    $checks.Add((New-Check 'flutter' ($flutter -ne $null) ($(if ($flutter) { $flutter } else { 'flutter was not found.' })) $true '')) | Out-Null

    $vs = Test-VisualStudioWindowsToolchain
    $checks.Add((New-Check 'visual-studio-cpp-workload' ([bool]$vs.Passed) $vs.Detail $true 'Microsoft.VisualStudio.2022.BuildTools')) | Out-Null

    $iscc = Resolve-CommandPath 'iscc.exe' @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
    )
    $checks.Add((New-Check 'inno-setup' ($iscc -ne $null) ($(if ($iscc) { $iscc } else { 'ISCC.exe was not found.' })) $true 'JRSoftware.InnoSetup')) | Out-Null

    $vbox = Resolve-CommandPath 'VBoxManage.exe' @(
        (Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Oracle\VirtualBox\VBoxManage.exe')
    )
    $checks.Add((New-Check 'virtualbox' ($vbox -ne $null) ($(if ($vbox) { $vbox } else { 'VBoxManage.exe was not found.' })) $true 'Oracle.VirtualBox')) | Out-Null

    $sevenZip = Resolve-CommandPath '7z.exe' @(
        (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
        (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe')
    )
    $checks.Add((New-Check '7zip' ($sevenZip -ne $null) ($(if ($sevenZip) { $sevenZip } else { '7z.exe was not found.' })) $true '')) | Out-Null

    $dism = Resolve-CommandPath 'Dism.exe' @((Join-Path $env:WINDIR 'System32\Dism.exe'))
    $checks.Add((New-Check 'dism' ($dism -ne $null) ($(if ($dism) { $dism } else { 'Dism.exe was not found.' })) $true '')) | Out-Null

    $mountDiskImage = Get-Command 'Mount-DiskImage' -ErrorAction SilentlyContinue
    $checks.Add((New-Check 'mount-diskimage' ($mountDiskImage -ne $null) ($(if ($mountDiskImage) { $mountDiskImage.Source } else { 'Mount-DiskImage was not found.' })) $true '')) | Out-Null

    $ame = Resolve-AmeInstall
    $checks.Add((New-Check 'ame' ($ame -ne $null) ($(if ($ame) { $ame } else { 'AME Wizard/AME Beta was not found in common install paths.' })) $false '')) | Out-Null

    return $checks
}

function Invoke-WingetInstall {
    param(
        [string] $Id,
        [string[]] $ExtraArguments = @()
    )

    $arguments = @(
        'install',
        '--id', $Id,
        '--exact',
        '--source', 'winget',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity'
    ) + $ExtraArguments

    Write-Host "Installing $Id"
    & winget @arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "winget install failed for $Id with exit code $exitCode."
    }
}

function Resolve-AmeDownloadUri {
    if (![string]::IsNullOrWhiteSpace($AmeDownloadUri)) {
        return $AmeDownloadUri
    }

    $html = Invoke-WebRequest -UseBasicParsing -Uri 'https://amelabs.net/'
    $matches = [regex]::Matches($html.Content, 'https?://[^"''\s>]+\.zip')
    foreach ($match in $matches) {
        if ($match.Value -match 'AME|Wizard|Beta|ameliorated') {
            return $match.Value
        }
    }

    throw 'Could not find an AME download zip on https://amelabs.net/. Pass -AmeDownloadUri explicitly.'
}

function Save-Ame {
    New-Item -ItemType Directory -Path $AmeOutputDir -Force | Out-Null
    $uri = Resolve-AmeDownloadUri
    $zipPath = Join-Path $AmeOutputDir 'AME.zip'
    Write-Host "Downloading AME from $uri"
    Invoke-WebRequest -Uri $uri -OutFile $zipPath

    $extractDir = Join-Path $AmeOutputDir 'extracted'
    if (Test-Path -LiteralPath $extractDir) {
        Remove-Item -LiteralPath $extractDir -Recurse -Force
    }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
    return $extractDir
}

function Write-Status {
    param([object[]] $Checks)

    $status = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        installRequested = [bool]$Install
        checkOnly = [bool]$CheckOnly
        checks = $Checks
    }

    $outputDir = Split-Path -Parent $OutputPath
    if (![string]::IsNullOrWhiteSpace($outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    $status | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    return $status
}

if (!$CheckOnly -and !$Install -and !$DownloadAme) {
    $CheckOnly = $true
}

$checks = @(Get-Checks)

if ($Install) {
    foreach ($check in $checks | Where-Object { $_.required -and !$_.passed -and $_.installId }) {
        switch ($check.installId) {
            'Microsoft.VisualStudio.2022.BuildTools' {
                Invoke-WingetInstall $check.installId @('--override', '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
            }
            default {
                Invoke-WingetInstall $check.installId
            }
        }
    }
    $checks = @(Get-Checks)
}

if ($DownloadAme -and !(Resolve-AmeInstall)) {
    $ameDir = Save-Ame
    Write-Host "AME extracted to $ameDir"
    $checks = @(Get-Checks)
}

$status = Write-Status $checks

Write-Host 'Local controller host prerequisites:'
foreach ($check in $status.checks) {
    $mark = if ($check.passed) { 'OK' } elseif ($check.required) { 'MISSING' } else { 'OPTIONAL' }
    Write-Host ("  [{0}] {1}: {2}" -f $mark, $check.name, $check.detail)
}
Write-Host "Status JSON: $OutputPath"

if ($Install) {
    $missingRequired = @($status.checks | Where-Object { $_.required -and !$_.passed })
    if ($missingRequired.Count -gt 0) {
        Write-Error 'Required prerequisites are still missing. Reboot if installers requested it, then rerun this script.'
        exit 1
    }
}

exit 0
