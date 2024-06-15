function Log {
    param (
        [string]$message
    )
    Write-Host $message
    Add-Content -Path $logFile -Value $message
}

function Check-Installed-Version {
    param (
        [string]$PackageName,
        [string]$PackageVersion
    )
    $existingPackages = Get-AppxPackage -Name $PackageName
    $highestVersionInstalled = $existingPackages | Sort-Object -Property Version -Descending | Select-Object -First 1

    if ($highestVersionInstalled) {
        $installedVersion = [Version]$highestVersionInstalled.Version
        $packageVersion = [Version]$PackageVersion

        if ($installedVersion -ge $packageVersion) {
            Log "Package $PackageName v$PackageVersion is already installed with version v$installedVersion."
            return $true
        }
    }
    return $false
}

function Add-AppxPackageSafe {
    param (
        [string]$PackagePath,
        [string]$PackageName
    )
    try {
        Add-AppxPackage -Path $PackagePath
        Log "Package installed: $PackageName"
    } catch {
        Log "Failed to install package: $($_.Exception.Message)"
        throw
    }
}

function Set-UBR {
    param (
        [string]$newUBR,
        [Microsoft.Win32.RegistryValueKind]$type
    )
    $path = "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion"
    $name = "UBR"

    $originalUBR = (Get-ItemProperty -Path $path).UBR
    $originalType = (Get-ItemProperty -Path $path).UBR.GetType().Name
    $originalUBRHex = "{0:x}" -f $originalUBR
    Log "Setting UBR to new value. Original UBR: $originalUBR (Decimal), $originalUBRHex (Hex), Type: $originalType"

    $decimalValue = [convert]::ToInt32($newUBR, 16)
    Set-ItemProperty -Path $path -Name $name -Value $decimalValue -Type $type
    return $originalUBRHex, $originalType
}

function Install-Fonts {
    $fontName = "Segoe Fluent Icons.ttf"
    $regPath = "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Fonts"
    
    $fontRegistryName = "$($fontName -replace '\.ttf$', ' (TrueType)')"
    $installedFont = Get-ItemProperty -Path $regPath -Name $fontRegistryName -ErrorAction SilentlyContinue

    if ($installedFont) {
        Log "$fontName is already installed. Skipping installation."
        return
    } else {
        Log "$fontName is not installed. Proceeding with download and installation."
    }

    $fontUrl = "https://aka.ms/SegoeFluentIcons"
    $fontZipFileName = "Segoe-Fluent-Icons.zip"
    $fontZipPath = Join-Path -Path $arctempDirectory -ChildPath $fontZipFileName
    $webClient.DownloadFile($fontUrl, $fontZipPath)
    Log "Segoe Fluent Icons zip downloaded."

    $fontExtractPath = Join-Path -Path $arctempDirectory -ChildPath "SegoeFluentIcons"
    if (Test-Path $fontExtractPath) {
        Remove-Item -Recurse -Force $fontExtractPath
    }
    Expand-Archive -Path $fontZipPath -DestinationPath $fontExtractPath -Force
    Log "Segoe Fluent Icons zip extracted."

    $fontFilePath = Join-Path -Path $fontExtractPath -ChildPath $fontName
    Add-Font -fontPath $fontFilePath
}

function Add-Font {
    param (
        [string]$fontPath
    )
    $fontsFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
    $fontName = [System.IO.Path]::GetFileName($fontPath)
    $fontsFolder.CopyHere($fontPath)
    $regPath = "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Fonts"
    $fontNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($fontPath)
    New-ItemProperty -Path $regPath -Name "$fontNameWithoutExtension (TrueType)" -Value $fontName -PropertyType String -Force | Out-Null
    Log "$fontName installed."
}

function Get-LatestInstalledVersion($packageName, $architecture) {
    $packages = Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue | 
                Where-Object { $_.Architecture -eq $architecture }
    if ($packages) {
        $latestVersion = $packages | Sort-Object {[System.Version] $_.Version} -Descending | 
                         Select-Object -First 1 -ExpandProperty Version
        return $latestVersion
    } else {
        return $null
    }
}

function Get-DependencyXmlPackageInfo($packageName) {
    $package = $xml.AppInstaller.Dependencies.Package | Where-Object { $_.Name -eq $packageName }
    if ($package) {
        return @{Version = $package.Version; Uri = $package.Uri}
    } else {
        return $null
    }
}

function DownloadAndInstallDependency {
    param (
        [string]$uri,
        [string]$packageName,
        [System.Net.WebClient]$webClient
    )
    $localPath = "$arctempDirectory\$packageName.appx"
    Write-Output "Downloading $packageName from $uri..."
    $webClient.DownloadFile($uri, $localPath)
    Write-Output "Installing $packageName..."
    Add-AppxPackage -Path $localPath
}

$dependenciesToCheck = @(
    @{Name="Microsoft.WindowsAppRuntime.1.5"; Architecture="x64"},
    @{Name="Microsoft.VCLibs.140.00.UWPDesktop"; Architecture="x64"}
)

$logFile = Join-Path -Path $PSScriptRoot -ChildPath ("Arc.appinstaller(" + (Get-Date -Format "MM-dd-yyyy-hhmmtt") + ").log")
$arctempDirectory = Join-Path -Path $PSScriptRoot -ChildPath "arctemp"
if (-not (Test-Path -Path $arctempDirectory)) {
    New-Item -ItemType Directory -Path $arctempDirectory | Out-Null
}

$webClient = New-Object System.Net.WebClient

$installerUrl = "https://releases.arc.net/windows/prod/Arc.appinstaller"
$localAppInstaller = "$arctempDirectory\Arc.appinstaller"
$webClient.DownloadFile($installerUrl, $localAppInstaller)
Log "Arc.appinstaller downloaded."

[xml]$xml = Get-Content -Path $localAppInstaller
$mainPackage = $xml.AppInstaller.MainPackage
$mainPackageUri = $mainPackage.Uri
$mainPackageFileName = [System.IO.Path]::GetFileName($mainPackageUri)
$localMainPackagePath = "$arctempDirectory\$mainPackageFileName"

if (Check-Installed-Version -PackageName $mainPackage.Name -PackageVersion $mainPackage.Version) {
    Log "Skipping further installations."
} else {
    foreach ($packageInfo in $dependenciesToCheck) {
        $packageName = $packageInfo.Name
        $architecture = $packageInfo.Architecture
        $installedVersion = Get-LatestInstalledVersion -packageName $packageName -architecture $architecture
        $packageDetails = Get-DependencyXmlPackageInfo -packageName $packageName

        if ($packageDetails) {
            $xmlVersion = $packageDetails.Version
            $uri = $packageDetails.Uri
            if ($installedVersion) {
                if ([System.Version]$installedVersion -eq [System.Version]$xmlVersion) {
                    Log "$packageName is up to date. Installed version: $installedVersion. Required version from XML: $xmlVersion"
                } elseif ([System.Version]$installedVersion -lt [System.Version]$xmlVersion) {
                    Log "$packageName is outdated. Installed version: $installedVersion. Required version from XML: $xmlVersion"
                    DownloadAndInstallDependency -uri $uri -packageName $packageName -webClient $webClient
                } else {
                    Log "$packageName has a higher version installed than required. Installed version: $installedVersion. Required version from XML: $xmlVersion"
                }
            } else {
                Log "$packageName is not installed or not found. Required version from XML: $xmlVersion"
                DownloadAndInstallDependency -uri $uri -packageName $packageName -webClient $webClient
            }
        } else {
            Log "No XML version found for $packageName"
        }
    }
    Install-Fonts
    $originalUBRHex, $originalType = Set-UBR -newUBR "ffffffff" -type 'DWord'
    $webClient.DownloadFile($mainPackage.Uri, $localMainPackagePath)
    Add-AppxPackageSafe -PackagePath $localMainPackagePath -PackageName $mainPackage.Name
    Set-UBR -newUBR $originalUBRHex -type 'DWord'
    Log "UBR restored to original value: $originalUBRHex, Type: $originalType"
}

$webClient.Dispose()

Remove-Item -Path $arctempDirectory -Recurse -Force
Log "Cleanup completed. All temporary files removed."
