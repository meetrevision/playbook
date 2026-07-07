param()

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath

function Invoke-Tool {
    param(
        [string] $File,
        [string[]] $Arguments
    )

    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $File @Arguments 2>&1
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = ($output | Out-String)
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string] $Message)
    if ($Expected -ne $Actual) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (!$Condition) {
        throw $Message
    }
}

function Assert-Match {
    param([string] $Pattern, [string] $Text, [string] $Message)
    if ($Text -notmatch $Pattern) {
        throw "$Message Pattern '$Pattern' was not found in:`n$Text"
    }
}

$scripts = @(
    'prepare_local_controller_host.ps1',
    'prepare_controller_iso.ps1',
    'new_virtualbox_controller_vm.ps1',
    'probe_controller_vm.ps1'
)

foreach ($script in $scripts) {
    $path = Join-Path $ScriptDir $script
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "$script should exist."
    [void][scriptblock]::Create((Get-Content -LiteralPath $path -Raw))
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("revi-controller-tooling-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $prereqOutput = Join-Path $tempRoot 'prereqs.json'
    $prereq = Invoke-Tool `
        -File (Join-Path $ScriptDir 'prepare_local_controller_host.ps1') `
        -Arguments @('-CheckOnly', '-OutputPath', $prereqOutput)
    Assert-Equal 0 $prereq.ExitCode 'Prereq check-only run should pass.'
    Assert-True (Test-Path -LiteralPath $prereqOutput -PathType Leaf) 'Prereq status JSON should be written.'
    $prereqJson = Get-Content -LiteralPath $prereqOutput -Raw | ConvertFrom-Json
    Assert-True ($prereqJson.checks.Count -gt 0) 'Prereq status should contain checks.'

    $isoManifest = Join-Path $tempRoot 'iso-manifest.json'
    $isoPrep = Invoke-Tool `
        -File (Join-Path $ScriptDir 'prepare_controller_iso.ps1') `
        -Arguments @('-OpenDownloadPage', '-OpenAmePage', '-OutputPath', $isoManifest, '-WhatIf')
    Assert-Equal 0 $isoPrep.ExitCode 'ISO prep WhatIf run should pass.'
    Assert-True (Test-Path -LiteralPath $isoManifest -PathType Leaf) 'ISO prep manifest should be written.'
    $isoJson = Get-Content -LiteralPath $isoManifest -Raw | ConvertFrom-Json
    Assert-Equal 'https://www.microsoft.com/software-download/windows11' $isoJson.microsoftDownloadPage 'ISO prep should record the Microsoft download page.'

    $isoPath = Join-Path $tempRoot 'install.iso'
    Set-Content -LiteralPath $isoPath -Value 'fake iso' -Encoding ASCII
    $vm = Invoke-Tool `
        -File (Join-Path $ScriptDir 'new_virtualbox_controller_vm.ps1') `
        -Arguments @('-IsoPath', $isoPath, '-VmName', 'ReviOS-Controller-Test', '-VmRoot', $tempRoot, '-WhatIf')
    Assert-Equal 0 $vm.ExitCode 'VirtualBox WhatIf run should pass.'
    Assert-Match 'VirtualBox VM plan|What if' $vm.Output 'VirtualBox WhatIf should print a plan.'

    $fakeReviTool = Join-Path $tempRoot 'fake-revitool.ps1'
    @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]] $Args)
$joined = $Args -join ' '
if ($joined -match 'profile list') {
  '{"profiles":["compatibility","gaming","performance","extreme"]}'
  exit 0
}
if ($joined -match 'profile apply gaming --dry-run --json') {
  '{"profile":"gaming","dryRun":true,"results":[]}'
  exit 0
}
if ($joined -match 'report --last --json') {
  '{"profile":"gaming","results":[]}'
  exit 0
}
if ($joined -match 'profile apply gaming --yes') {
  '{"profile":"gaming","dryRun":false,"results":[]}'
  exit 0
}
if ($joined -match 'profile status --json') {
  '{"states":[]}'
  exit 0
}
'unexpected command'
exit 2
'@ | Set-Content -LiteralPath $fakeReviTool -Encoding UTF8

    $probeOutput = Join-Path $tempRoot 'probe.json'
    $probe = Invoke-Tool `
        -File (Join-Path $ScriptDir 'probe_controller_vm.ps1') `
        -Arguments @('-ReviToolPath', $fakeReviTool, '-OutputPath', $probeOutput)
    Assert-Equal 0 $probe.ExitCode 'Probe should pass with fake revitool.'
    Assert-True (Test-Path -LiteralPath $probeOutput -PathType Leaf) 'Probe JSON should be written.'
    $probeJson = Get-Content -LiteralPath $probeOutput -Raw | ConvertFrom-Json
    Assert-Equal 5 $probeJson.commands.Count 'Probe should run the controller acceptance commands.'
    Assert-Equal 0 $probeJson.failedResults.Count 'Fake probe should have no failed tweak results.'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Output 'Local controller tooling tests passed.'
