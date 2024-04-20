# Unpin Edge from the taskbar
# credits to
# https://github.com/Disassembler0/Win10-Initial-Setup-Script/issues/8#issue-227159084
# https://www.ntlite.com/community/index.php?threads/get-rid-of-edge-microsoft-store-in-the-taskbar.3972/post-39159

param (
    [Parameter(Mandatory=$true)]
    [string[]]$List,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("startMenu", "taskbar")]
    [string]$Mode
)

function Get-String { 
    param (
        [Parameter(Mandatory=$true)]
        [int]$strId
    )

    $getstring = @'
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    internal static extern int LoadString(IntPtr hInstance, uint uID, StringBuilder lpBuffer, int nBufferMax);

    public static string GetString(uint strId) {
        IntPtr intPtr = GetModuleHandle("shell32.dll");
        StringBuilder sb = new StringBuilder(255);
        LoadString(intPtr, strId, sb, sb.Capacity);
        return sb.ToString();
    }
'@
    $getstring = Add-Type $getstring -PassThru -Name GetStr -Using System.Text

    $unpinFromStart = $getstring[0]::GetString($strId)
    return $unpinFromStart
}


function Unpin-FromTaskbar {
    $UnpinFromTaskbar = Get-String -strId 5387
    
    foreach ($App in $List) {
    ((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{ $_.Name -match $App }).Verbs() | `
        ?{ $_.Name -eq $UnpinFromTaskbar } | %{ $_.DoIt(); $exec = $true }
}  
}

switch ($Mode) {
    # "startMenu" { Unpin-FromStartMenu }
    "taskbar" { Unpin-FromTaskbar }
}
