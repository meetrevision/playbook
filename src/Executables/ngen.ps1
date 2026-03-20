Get-ScheduledTask -TaskPath "\Microsoft\Windows\.NET Framework\" | Start-ScheduledTask -ErrorAction SilentlyContinue

# Credits to https://stackoverflow.com/users/9898643/theo
$env:PATH = [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()

$priorityAssemblies = @(
    "mscorlib.dll",
    "System.dll",
    "System.Core.dll",
    "System.Runtime.dll",
    "PresentationCore.dll",
    "PresentationFramework.dll",
    "WindowsBase.dll"
)

foreach ($name in $priorityAssemblies) {
    $path = Join-Path $env:PATH $name
    if (Test-Path $path) {
        Write-Host -ForegroundColor Cyan "Priority ngen: '$name'"
        ngen.exe install $path /nologo /queue:1
    }
}

[AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
    $path = $_.Location
    if ($path) {
        $name = Split-Path $path -Leaf
        if ($priorityAssemblies -notcontains $name) {
            Write-Host -ForegroundColor Yellow "`r`nRunning ngen on '$name'"
            ngen.exe install $path /nologo /queue:3
        }
    }
}

ngen.exe executeQueuedItems