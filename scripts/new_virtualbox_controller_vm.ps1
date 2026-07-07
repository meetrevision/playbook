[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string] $IsoPath,
    [string] $VmName = 'ReviOS-Controller-VM',
    [string] $VmRoot,
    [UInt32] $MemoryMB = 8192,
    [UInt32] $DiskSizeMB = 81920,
    [int] $ProcessorCount = 4,
    [string] $VBoxManagePath,
    [switch] $Start,
    [switch] $DisableTpm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$PlaybookRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$WorkspaceRoot = (Resolve-Path (Join-Path $PlaybookRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($VmRoot)) {
    $VmRoot = Join-Path $WorkspaceRoot 'artifacts\local-controller\vms'
}

$IsoPath = (Resolve-Path $IsoPath).Path
$VmRoot = [IO.Path]::GetFullPath($VmRoot)
$VmFolder = Join-Path $VmRoot $VmName
$DiskPath = Join-Path $VmFolder "$VmName.vdi"

function Resolve-VBoxManage {
    if (![string]::IsNullOrWhiteSpace($VBoxManagePath)) {
        return (Resolve-Path $VBoxManagePath).Path
    }

    $command = Get-Command 'VBoxManage.exe' -ErrorAction SilentlyContinue
    if ($command -ne $null) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Oracle\VirtualBox\VBoxManage.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    if ($WhatIfPreference) {
        return 'VBoxManage.exe'
    }

    throw 'VBoxManage.exe was not found. Install Oracle VirtualBox or pass -VBoxManagePath.'
}

function Invoke-VBox {
    param(
        [string] $Action,
        [string[]] $Arguments,
        [switch] $AllowFailure
    )

    Write-Host ('  VBoxManage {0}' -f ($Arguments -join ' '))
    if ($PSCmdlet.ShouldProcess($VmName, $Action)) {
        & $VBoxManage @Arguments
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0 -and !$AllowFailure) {
            throw "VBoxManage failed during '$Action' with exit code $exitCode."
        }
        if ($exitCode -ne 0 -and $AllowFailure) {
            Write-Warning "VBoxManage step '$Action' failed with exit code $exitCode and was skipped."
        }
    }
}

if (!(Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
    throw "ISO not found: $IsoPath"
}

$VBoxManage = Resolve-VBoxManage

Write-Host 'VirtualBox VM plan'
Write-Host "  Name:       $VmName"
Write-Host "  Root:       $VmRoot"
Write-Host "  ISO:        $IsoPath"
Write-Host "  Disk:       $DiskPath"
Write-Host "  CPUs:       $ProcessorCount"
Write-Host "  Memory MB:  $MemoryMB"
Write-Host "  Disk MB:    $DiskSizeMB"
Write-Host "  Firmware:   EFI"
Write-Host "  Network:    NAT"

if (!$WhatIfPreference) {
    if (Test-Path -LiteralPath $VmFolder) {
        throw "VM folder already exists: $VmFolder"
    }
    $existing = & $VBoxManage list vms 2>$null
    if (($existing | Out-String) -match [regex]::Escape("`"$VmName`"")) {
        throw "A VirtualBox VM named '$VmName' already exists."
    }
}

New-Item -ItemType Directory -Path $VmRoot -Force | Out-Null

Invoke-VBox 'Create VM' @('createvm', '--name', $VmName, '--ostype', 'Windows11_64', '--basefolder', $VmRoot, '--register')
Invoke-VBox 'Configure VM' @(
    'modifyvm', $VmName,
    '--memory', "$MemoryMB",
    '--cpus', "$ProcessorCount",
    '--firmware', 'efi',
    '--ioapic', 'on',
    '--rtcuseutc', 'on',
    '--vram', '128',
    '--graphicscontroller', 'vboxsvga',
    '--nic1', 'nat',
    '--boot1', 'dvd',
    '--boot2', 'disk'
)

if (!$DisableTpm) {
    Invoke-VBox 'Enable TPM 2.0 when supported' @('modifyvm', $VmName, '--tpm-type', '2.0') -AllowFailure
}

Invoke-VBox 'Create disk' @('createmedium', 'disk', '--filename', $DiskPath, '--size', "$DiskSizeMB", '--format', 'VDI')
Invoke-VBox 'Create storage controller' @('storagectl', $VmName, '--name', 'SATA', '--add', 'sata', '--controller', 'IntelAhci', '--portcount', '2')
Invoke-VBox 'Attach disk' @('storageattach', $VmName, '--storagectl', 'SATA', '--port', '0', '--device', '0', '--type', 'hdd', '--medium', $DiskPath)
Invoke-VBox 'Attach ISO' @('storageattach', $VmName, '--storagectl', 'SATA', '--port', '1', '--device', '0', '--type', 'dvddrive', '--medium', $IsoPath)

if ($Start) {
    Invoke-VBox 'Start VM' @('startvm', $VmName, '--type', 'gui')
}

Write-Host ''
Write-Host 'VirtualBox VM prepared.'
Write-Host 'Run the VM acceptance checklist after Windows setup finishes.'
