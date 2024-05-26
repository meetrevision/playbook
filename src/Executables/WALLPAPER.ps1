param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Desktop", "LockScreen")]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$ImagePath
)

function Set-DesktopWallpaper {
    param(
        [string]$imagePath
    )

    if (-not (Test-Path $imagePath)) {
        Write-Error "Image path does not exist: $imagePath"
        return
    }

    Get-ChildItem -Path "Registry::HKU" | ForEach-Object {
        $userKey = $_.Name
        [microsoft.win32.registry]::SetValue("$userKey\Control Panel\Desktop", "WallPaper", $imagePath, [Microsoft.Win32.RegistryValueKind]::String)
    }
    
    # https://gist.github.com/s7ephen/714023?permalink_comment_id=3611772#gistcomment-3611772
    $setwallpapersrc = @"
    using System.Runtime.InteropServices;

    public class DesktopWallpaper
    {
      public const int SetDesktopWallpaper = 20;
      public const int UpdateIniFile = 0x01;
      public const int SendWinIniChange = 0x02;
      [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
      private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
      public static void SetWallpaper(string path)
      {
        SystemParametersInfo(SetDesktopWallpaper, 0, path, UpdateIniFile |  SendWinIniChange);
      }
    }
"@
    if (-not ([System.Management.Automation.PSTypeName]'DesktopWallpaper').Type) {
        Add-Type -TypeDefinition $setwallpapersrc
    }

    [DesktopWallpaper]::SetWallpaper($imagePath)

}


function Set-LockScreenWallpaper {
    param(
        [string]$imagePath
    )

    if (!(Test-Path $imagePath)) {
        Write-Error "Image path does not exist: $imagePath"
        return
    }

    # https://superuser.com/a/1343640
# License: https://creativecommons.org/licenses/by-sa/4.0/
    $newImagePath = [System.IO.Path]::GetDirectoryName($imagePath) + '\' + (New-Guid).Guid + [System.IO.Path]::GetExtension($imagePath)
    Copy-Item $imagePath $newImagePath
    [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime] | Out-Null
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    Function Await($WinRtTask, $ResultType) {
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
        $netTask = $asTask.Invoke($null, @($WinRtTask))
        $netTask.Wait(-1) | Out-Null
        $netTask.Result
    }
    Function AwaitAction($WinRtAction) {
        $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and !$_.IsGenericMethod })[0]
        $netTask = $asTask.Invoke($null, @($WinRtAction))
        $netTask.Wait(-1) | Out-Null
    }
    [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
    $image = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($newImagePath)) ([Windows.Storage.StorageFile])
    AwaitAction ([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($image))
    Remove-Item $newImagePath -Force
}

$path = Get-ChildItem $ImagePath -Force | Select-Object -ExpandProperty FullName
switch ($Mode) {
    "Desktop" {
        Set-DesktopWallpaper -ImagePath $path
    }
    "LockScreen" {
        Set-LockScreenWallpaper -ImagePath $path
    }
}