[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string] $IsoPath,
    [string] $VmName = 'ReviOS-Controller-VM',
    [string] $VmRoot,
    [UInt64] $MemoryStartupBytes = 8GB,
    [UInt64] $VhdSizeBytes = 80GB,
    [int] $ProcessorCount = 4,
    [string] $SwitchName = 'Default Switch',
    [switch] $Start
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($VmRoot)) {
    $VmRoot = Join-Path $env:PUBLIC 'Documents\Hyper-V\ReviOS-Controller-VM'
}

$IsoPath = (Resolve-Path $IsoPath).Path

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (!(Test-Admin)) {
    throw 'Run this script from an elevated PowerShell session.'
}

if (!(Get-Command 'New-VM' -ErrorAction SilentlyContinue)) {
    throw 'Hyper-V PowerShell cmdlets were not found. Enable Hyper-V first, then reboot: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All'
}

if (!(Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
    throw "ISO not found: $IsoPath"
}

if (Get-VM -Name $VmName -ErrorAction SilentlyContinue) {
    throw "A Hyper-V VM named '$VmName' already exists."
}

if (!(Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    throw "Hyper-V switch '$SwitchName' was not found. Create it or pass -SwitchName."
}

New-Item -ItemType Directory -Path $VmRoot -Force | Out-Null
$VmRoot = (Resolve-Path $VmRoot).Path
$VhdPath = Join-Path $VmRoot "$VmName.vhdx"
if (Test-Path -LiteralPath $VhdPath) {
    throw "VHDX already exists: $VhdPath"
}

if (!$PSCmdlet.ShouldProcess($VmName, 'Create Hyper-V controller validation VM')) {
    return
}

Write-Host "Creating Hyper-V VM '$VmName'"
New-VM `
    -Name $VmName `
    -Generation 2 `
    -MemoryStartupBytes $MemoryStartupBytes `
    -NewVHDPath $VhdPath `
    -NewVHDSizeBytes $VhdSizeBytes `
    -Path $VmRoot `
    -SwitchName $SwitchName | Out-Null

Set-VMProcessor -VMName $VmName -Count $ProcessorCount
Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $false
Set-VMFirmware -VMName $VmName -EnableSecureBoot On -SecureBootTemplate 'MicrosoftWindows'

$dvd = Get-VMDvdDrive -VMName $VmName -ErrorAction SilentlyContinue
if ($dvd -eq $null) {
    Add-VMDvdDrive -VMName $VmName -Path $IsoPath
} else {
    Set-VMDvdDrive -VMName $VmName -Path $IsoPath
}
$dvd = Get-VMDvdDrive -VMName $VmName
Set-VMFirmware -VMName $VmName -FirstBootDevice $dvd

if ($Start -and $PSCmdlet.ShouldProcess($VmName, 'Start Hyper-V VM')) {
    Start-VM -Name $VmName
}

Write-Host ''
Write-Host 'Hyper-V VM prepared:'
Write-Host "  Name:       $VmName"
Write-Host "  ISO:        $IsoPath"
Write-Host "  VHDX:       $VhdPath"
Write-Host "  CPUs:       $ProcessorCount"
Write-Host "  Memory:     $MemoryStartupBytes bytes"
Write-Host "  SecureBoot: MicrosoftWindows"
Write-Host ''
Write-Host 'After Windows setup finishes, run the VM acceptance checklist from docs\vm-first-controller-validation.md.'
