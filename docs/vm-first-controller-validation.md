# Local controller validation on a VM

Build the local Revision Tool, put it into a local playbook payload, install it on a clean VM, then promote the same installer to the host after the VM passes.

Keep the first host pass limited to `gaming`. Do not run `performance`, `extreme`, or `--include-dangerous` on the host until a snapshot-backed VM pass has covered that path.

## Prerequisites

- Flutter, Dart, Python, PowerShell, 7-Zip, and Inno Setup 6.
- Visual Studio Build Tools with the Desktop C++ workload.
- VirtualBox.
- AME Wizard.
- A clean Windows 11 ISO. Build `26100` and `26200` are accepted.

Check the host:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\playbook\scripts\prepare_local_controller_host.ps1 -CheckOnly
```

Install missing host tools:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\playbook\scripts\prepare_local_controller_host.ps1 -Install -DownloadAme
```

Reboot if the installer output asks for it, then run the check again.

## Build the local installer

Run from the workspace root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\revision-tool\scripts\build-local-controller.ps1 -Version local-controller
```

Check these files:

```text
revision-tool\src\build\windows\x64\runner\Release\revitoolw.exe
revision-tool\revitool.exe
revision-tool\RevisionTool-Setup.exe
```

If `ISCC.exe` is not on PATH, pass it directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\revision-tool\scripts\build-local-controller.ps1 -Version local-controller -InnoSetupCompiler "C:\Path\To\ISCC.exe"
```

CLI-only smoke, for hosts that do not have the Windows GUI toolchain yet:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\revision-tool\scripts\build-local-controller.ps1 -Version local-controller -SkipGuiBuild -SkipInstaller
```

That smoke can return exit code `55` when the host is not ReviOS or AME. The full command check belongs inside the VM.

## Create the local playbook

Run from the workspace root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\playbook\scripts\build_local_controller_payload.ps1 -Version local-controller
```

Check the payload:

```text
artifacts\local-controller\Revi-PB-local-controller.apbx
```

The staging copy is under `artifacts\local-controller\playbook-staging`. Only that copy replaces the public GitHub installer download with `RevisionTool-Setup.exe` from the local build.

## Inject the ISO

Open the official download pages if needed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\playbook\scripts\prepare_controller_iso.ps1 -OpenDownloadPage -OpenAmePage
```

After downloading the Windows ISO, inspect it:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\playbook\scripts\prepare_controller_iso.ps1 -IsoPath ".\artifacts\downloads\Win11.iso"
```

Open AME and use:

- ISO: clean Windows 11 ISO.
- Playbook: `artifacts\local-controller\Revi-PB-local-controller.apbx`.

Save the injected ISO outside the repos:

```text
artifacts\local-controller\ReviOS-local-controller.iso
```

## Create the VM

Check the command first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\playbook\scripts\new_virtualbox_controller_vm.ps1 -IsoPath ".\artifacts\local-controller\ReviOS-local-controller.iso" -WhatIf
```

Create and start the VM:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\playbook\scripts\new_virtualbox_controller_vm.ps1 -IsoPath ".\artifacts\local-controller\ReviOS-local-controller.iso" -Start
```

Defaults:

- 4 vCPU.
- 8 GB RAM.
- 80 GB VDI.
- EFI firmware.
- NAT network.
- TPM 2.0 when VirtualBox supports it.

## Validate in the VM

Run inside the VM:

```powershell
& "$env:ProgramFiles\Revision Tool\revitool.exe" profile list
& "$env:ProgramFiles\Revision Tool\revitool.exe" profile apply gaming --dry-run --json
& "$env:ProgramFiles\Revision Tool\revitool.exe" report --last --json
& "$env:ProgramFiles\Revision Tool\revitool.exe" profile apply gaming --yes
& "$env:ProgramFiles\Revision Tool\revitool.exe" profile status --json
```

Or run the probe:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\probe_controller_vm.ps1
```

Check the machine:

- `revitool.exe` and `revitoolw.exe` are in `C:\Program Files\Revision Tool`.
- The GUI opens.
- `/tweaks/controller` opens.
- Reboot works.
- Login works.
- Internet works.
- Audio works.
- Windows Update opens and can check status.
- Store, Xbox, Game Pass, and Gaming Services work if the selected playbook options kept them.
- At least one safe tweak rolls back.

No promotion to the host until this checklist passes.

## Install on the host

Host pass:

1. Create a restore point or full backup.
2. Install `revision-tool\RevisionTool-Setup.exe`.
3. Run:

```powershell
& "$env:ProgramFiles\Revision Tool\revitool.exe" profile apply gaming --dry-run --json
& "$env:ProgramFiles\Revision Tool\revitool.exe" profile apply gaming --yes
& "$env:ProgramFiles\Revision Tool\revitool.exe" profile status --json
```

Stop there on the first host pass. Keep `performance`, `extreme`, and `--include-dangerous` for a separate VM run with a snapshot.
