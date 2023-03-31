function Delete-UserChoiceKey {
  param (
    [Parameter( Position = 0, Mandatory = $True )]
    [String]
    $Key
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

$Hive = $args[1]

Write-Host "Setting file associations for HKEY_USERS\$Hive..."

New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null

If (-NOT (Test-Path "HKU:\$Hive\SOFTWARE\Clients")) {
New-Item -Path "HKU:\$Hive\SOFTWARE\Clients" -Force | Out-Null
}
If (-NOT (Test-Path "HKU:\$Hive\SOFTWARE\Clients\StartMenuInternet")) {
New-Item -Path "HKU:\$Hive\SOFTWARE\Clients\StartMenuInternet" -Force | Out-Null
}

Get-Item -Path "HKLM:\SOFTWARE\Clients\StartMenuInternet\*" |
ForEach-Object {
Copy-Item -Path "$($_.PSPath)" -Destination "HKU:\$Hive\SOFTWARE\Clients\StartMenuInternet" -Force -Recurse | Out-Null
}

for ($i = 2; $i -lt $args.Length; $i++) {
  $splitArg = $args[$i] -split ":"
  if ($splitArg[0] -eq "Proto") {
    If (-NOT (Test-Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\$($splitArg[1])")) {
    New-Item -Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\$($splitArg[1])" -Force | Out-Null
    }
    If (Test-Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\$($splitArg[1])\UserChoice") {
    Delete-UserChoiceKey "$Hive\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\$($splitArg[1])\UserChoice"
    }
    If (-NOT (Test-Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts")) {
    New-Item -Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" -Force | Out-Null
    }
    New-ItemProperty -Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" -Name "$($splitArg[2])_$($splitArg[1])" -PropertyType DWORD -Value 0 -Force | Out-Null
  } else {
    If (-NOT (Test-Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($splitArg[0])")) {
    New-Item -Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($splitArg[0])" -Force | Out-Null
    } 
    If (Test-Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($splitArg[0])\UserChoice") {
    Delete-UserChoiceKey "$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($splitArg[0])\UserChoice"
    }
    If (-NOT (Test-Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts")) {
    New-Item -Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" -Force | Out-Null
    }
    New-ItemProperty -Path "HKU:\$Hive\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" -Name "$($splitArg[1])_$($splitArg[0])" -PropertyType DWORD -Value 0 -Force | Out-Null

    [Microsoft.Win32.Registry]::SetValue("HKEY_CLASSES_ROOT\$($splitArg[0])", "", "$($splitArg[1])")
    [Microsoft.Win32.Registry]::SetValue("HKEY_USERS\$Hive\SOFTWARE\Classes\$($splitArg[0])", "", "$($splitArg[1])")
  }
}