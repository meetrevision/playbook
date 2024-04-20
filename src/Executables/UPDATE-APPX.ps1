Add-AppPackage 'https://cdn.winget.microsoft.com/cache/source.msix' -ForceApplicationShutdown
$productName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name ProductName
$path = Join-Path ${env:ProgramFiles(x86)} 'Revision Tool'
if (Test-Path $path) {
    $file = Join-Path $path 'revitool.exe'
    $args = if ($productName -like '*LTSC*') {'msstore-apps --id 9NBLGGH4NNS1 --ring RP'} else {'msstore-apps --id 9WZDNCRFJBMP --id 9NBLGGH4NNS1 --ring RP'}
    Start-Process -FilePath $file -ArgumentList $args -Wait -WindowStyle Hidden
}