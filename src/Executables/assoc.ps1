param(
    [Parameter(Position = 0)]
    [string]$Placeholder,

    [Parameter(Position = 1, Mandatory = $true)]
    [string]$Hive,

    [Parameter(Position = 2, ValueFromRemainingArguments = $true)]
    [string[]]$Associations
)

function Remove-UserChoiceKey {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [String]$Key
    )
    $code = @'
    using System;
    using System.Runtime.InteropServices;
    using Microsoft.Win32;

    namespace Registry {
        public class Utils {
            [DllImport("advapi32.dll", SetLastError = true)]
            private static extern int RegOpenKeyEx(UIntPtr hKey, string subKey, int ulOptions, int samDesired, out UIntPtr hkResult);

            [DllImport("advapi32.dll", SetLastError=true, CharSet = CharSet.Unicode)]
            private static extern uint RegDeleteKey(UIntPtr hKey, string subKey);

            public static void DeleteKey(string key) {
                UIntPtr hKey = UIntPtr.Zero;
                RegOpenKeyEx((UIntPtr)0x80000003u, key, 0, 0x20019, out hKey);
                RegDeleteKey((UIntPtr)0x80000003u, key);
            }
        }
    }
'@
    Add-Type -TypeDefinition $code
    [Registry.Utils]::DeleteKey($Key)
}

Write-Host "Setting file associations for HKEY_USERS\$Hive..."

New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null

if (-not (Test-Path "HKU:\$Hive\SOFTWARE\Clients")) {
    New-Item -Path "HKU:\$Hive\SOFTWARE\Clients" -Force | Out-Null
}
if (-not (Test-Path "HKU:\$Hive\SOFTWARE\Clients\StartMenuInternet")) {
    New-Item -Path "HKU:\$Hive\SOFTWARE\Clients\StartMenuInternet" -Force | Out-Null
}

Get-Item -Path "HKLM:\SOFTWARE\Clients\StartMenuInternet\*" -ErrorAction SilentlyContinue |
    ForEach-Object {
        Copy-Item -Path "$($_.PSPath)" -Destination "HKU:\$Hive\SOFTWARE\Clients\StartMenuInternet" -Force -Recurse | Out-Null
    }

foreach ($entry in $Associations) {
    $splitArg = $entry -split ":"
    if ($splitArg[0] -eq "Proto") {
        $urlAssocPath = "HKU:\$Hive\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\$($splitArg[1])"
        if (-not (Test-Path $urlAssocPath)) {
            New-Item -Path $urlAssocPath -Force | Out-Null
        }
        if (Test-Path "$urlAssocPath\UserChoice") {
            Remove-UserChoiceKey "$Hive\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\$($splitArg[1])\UserChoice"
        }
        $toastPath = "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts"
        if (-not (Test-Path $toastPath)) {
            New-Item -Path $toastPath -Force | Out-Null
        }
        New-ItemProperty -Path $toastPath -Name "$($splitArg[2])_$($splitArg[1])" -PropertyType DWORD -Value 0 -Force | Out-Null
    }
    else {
        $fileExtPath = "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($splitArg[0])"
        if (-not (Test-Path $fileExtPath)) {
            New-Item -Path $fileExtPath -Force | Out-Null
        }
        if (Test-Path "$fileExtPath\UserChoice") {
            Remove-UserChoiceKey "$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($splitArg[0])\UserChoice"
        }
        $toastPath = "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts"
        if (-not (Test-Path $toastPath)) {
            New-Item -Path $toastPath -Force | Out-Null
        }
        New-ItemProperty -Path $toastPath -Name "$($splitArg[1])_$($splitArg[0])" -PropertyType DWORD -Value 0 -Force | Out-Null

        [Microsoft.Win32.Registry]::SetValue("HKEY_CLASSES_ROOT\$($splitArg[0])", "", "$($splitArg[1])")
        [Microsoft.Win32.Registry]::SetValue("HKEY_USERS\$Hive\SOFTWARE\Classes\$($splitArg[0])", "", "$($splitArg[1])")
    }
}