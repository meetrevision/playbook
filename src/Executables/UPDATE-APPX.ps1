Write-Host 'Updating Microsoft Store apps...'
# Write-Host 'Installing Winget Source'
# Add-AppPackage 'https://cdn.winget.microsoft.com/cache/source.msix' -ForceApplicationShutdown -Verbose
$productName = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ProductName
Write-Host "Product Name: $productName"
$path = Join-Path ${env:ProgramFiles(x86)} 'Revision Tool'
$file = Join-Path $path 'revitool.exe'

if (!(Test-Path $path) -or !(Test-Path $file)) {
    Write-Host 'Revision Tool not found. Skipping update.'
    exit 1
}

$argumentsList = if ($productName -like '*LTSC*') {'msstore-apps --id 9NBLGGH4NNS1 --ring RP'} else {'msstore-apps --id 9WZDNCRFJBMP --id 9NBLGGH4NNS1 --ring RP'}
Start-Process -FilePath $file -ArgumentList $argumentsList -Wait -NoNewWindow -PassThru -Verbose