$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$telemetryHosts = @(
    "0.0.0.0 vortex.data.microsoft.com",
    "0.0.0.0 settings-win.data.microsoft.com",
    "0.0.0.0 watson.telemetry.microsoft.com",
    "0.0.0.0 umwatsonc.events.data.microsoft.com",
    "0.0.0.0 ceuswatcab01.blob.core.windows.net",
    "0.0.0.0 v10.events.data.microsoft.com",
    "0.0.0.0 v20.events.data.microsoft.com",
    "0.0.0.0 telecommand.telemetry.microsoft.com",
    "0.0.0.0 oca.telemetry.microsoft.com",
    "0.0.0.0 oca.microsoft.com",
    "0.0.0.0 sqm.telemetry.microsoft.com",
    "0.0.0.0 watson.ppe.telemetry.microsoft.com",
    "0.0.0.0 redir.metaservices.microsoft.com",
    "0.0.0.0 compatexchange.cloudapp.net"
)

$current = Get-Content $hostsPath -Raw -ErrorAction SilentlyContinue
foreach ($entry in $telemetryHosts) {
    $hostname = ($entry -split ' ')[1]
    if ($current -notmatch [regex]::Escape($hostname)) {
        Add-Content -Path $hostsPath -Value $entry -Encoding ASCII
        Write-Host "Blocked: $hostname"
    }
}
