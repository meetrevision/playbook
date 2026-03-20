param (
    [Parameter(Mandatory = $true)]
    [string[]]$Packages,
    [Parameter(Mandatory = $false)]
    [switch]$Unregister = $false
)

$baseRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore"

$allPackages = Get-AppxPackage -AllUsers | Select-Object PackageFullName, PackageFamilyName, PackageUserInformation, NonRemovable

foreach ($package in $Packages) {
    $filteredPackages = $allPackages | Where-Object { $_.PackageFullName -like "*$package*" }

    foreach ($pkg in $filteredPackages) {

        $fullPackageName = $pkg.PackageFullName
        $packageFamilyName = $pkg.PackageFamilyName

        Write-Host "Removing package: $($fullPackageName)"

        # Adding to Deprovisioned may prevent some UWP packages from installing after updating Windows
        $deprovisionedPath = "$baseRegistryPath\Deprovisioned\$packageFamilyName"
        if (-not (Test-Path -Path $deprovisionedPath)) {
            New-Item -Path $deprovisionedPath -Force
        }

        $inboxAppsPath = "$baseRegistryPath\InboxApplications\$fullPackageName"
        if (Test-Path $inboxAppsPath) {
            Remove-Item -Path $inboxAppsPath -Force
        }
        
        if ($pkg.NonRemovable -eq 1) {
            Set-NonRemovableAppsPolicy -Online -PackageFamilyName $packageFamilyName -NonRemovable 0
        }

        # Add to EndOfLife
        foreach ($userInfo in $pkg.PackageUserInformation) {
            $userSid = $userInfo.UserSecurityID.SID
            $endOfLifePath = "$baseRegistryPath\EndOfLife\$userSid\$fullPackageName"
            New-Item -Path $endOfLifePath -Force -ErrorAction SilentlyContinue | Out-Null

            try {
                if ($Unregister) {
                    Remove-AppxPackage -Package $fullPackageName -User $userSid -PreserveRoamableApplicationData -ErrorAction Stop
                }
                else {
                    Remove-AppxPackage -Package $fullPackageName -User $userSid -ErrorAction Stop
                }
            }
            catch {
                Write-Warning "Failed to remove $fullPackageName for user $userSid`: $_"
            }
        }

        # Second attempt
        # An APPX package can be installed for multiple users, and when uninstallation is performed for each or all users, its status may appear as "Staged" or "Installed(pending removal)" for certain users. Therefore, a second attempt is needed to remove the package completely
        if ($Unregister) {
            Remove-AppxPackage -Package $fullPackageName -AllUsers -PreserveRoamableApplicationData
        }
        else {
            Remove-AppxPackage -Package $fullPackageName -AllUsers
        }

    }
}