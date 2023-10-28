Get-ScheduledTask -TaskPath "\Microsoft\Windows\.NET Framework\" | Start-ScheduledTask

# Credits to https://stackoverflow.com/users/9898643/theo
$env:PATH = [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
[AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
    $path = $_.Location
    if ($path) { 
        $name = Split-Path $path -Leaf
        Write-Host -ForegroundColor Yellow "`r`nRunning ngen on '$name'"
        ngen.exe install $path /nologo
    }
}