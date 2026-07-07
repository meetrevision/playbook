param()

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$Validator = Join-Path $ScriptDir 'validate_playbook.ps1'

function New-FixtureRoot {
    param(
        [string] $TaskBody
    )

    $root = Join-Path ([IO.Path]::GetTempPath()) ("revi-playbook-validator-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $root 'src\Configuration\Tasks') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'src\Images') -Force | Out-Null

    @'
<?xml version="1.0" encoding="utf-8"?>
<Playbook>
  <Name>Fixture</Name>
  <Software>
    <Package Option="known-option">
      <Name>known-package</Name>
      <Title>Known Package</Title>
    </Package>
  </Software>
  <FeaturePages>
    <CheckboxPage>
      <Options>
        <CheckboxOption>
          <Text>Known option</Text>
          <Name>known-option</Name>
        </CheckboxOption>
      </Options>
    </CheckboxPage>
  </FeaturePages>
</Playbook>
'@ | Set-Content -LiteralPath (Join-Path $root 'src\playbook.conf') -Encoding UTF8

    @'
---
title: Root
actions:
  - !task: {path: 'Tasks\known.yml'}
'@ | Set-Content -LiteralPath (Join-Path $root 'src\Configuration\main.yml') -Encoding UTF8

    $TaskBody | Set-Content -LiteralPath (Join-Path $root 'src\Configuration\Tasks\known.yml') -Encoding UTF8
    return $root
}

function Invoke-Validator {
    param([string] $Root)

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Validator -Root $Root 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldPreference
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = ($output | Out-String)
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string] $Message)
    if ($Expected -ne $Actual) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

function Assert-Match {
    param([string] $Pattern, [string] $Text, [string] $Message)
    if ($Text -notmatch $Pattern) {
        throw "$Message Pattern '$Pattern' was not found in:`n$Text"
    }
}

$validRoot = New-FixtureRoot @'
---
title: Known
actions:
  - !registryValue: {path: 'HKCU\Software\Fixture', value: 'Enabled', type: REG_DWORD, data: '1', option: 'known-option'}
'@

$valid = Invoke-Validator $validRoot
Assert-Equal 0 $valid.ExitCode 'Valid fixture should pass.'
Assert-Match 'Validated' $valid.Output 'Valid fixture should report validation summary.'

$invalidRoot = New-FixtureRoot @'
---
title: Unknown option
actions:
  - !registryValue: {path: 'HKCU\Software\Fixture', value: 'Enabled', type: REG_DWORD, data: '1', option: 'unknown-option'}
'@

$invalid = Invoke-Validator $invalidRoot
Assert-Equal 1 $invalid.ExitCode 'Unknown option fixture should fail.'
Assert-Match 'unknown option reference.*unknown-option' $invalid.Output 'Unknown option should be reported.'

Write-Output 'PowerShell validator tests passed.'
