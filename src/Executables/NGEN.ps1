(Get-ScheduledTask -TaskPath "\Microsoft\Windows\.NET Framework\")[0,1] | Start-ScheduledTask

$env:PATH = [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
[AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
    if ($_.Location) {
        NGEN.EXE install $_.Location | Out-Null
    }
}