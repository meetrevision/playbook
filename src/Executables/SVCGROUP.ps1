# Alternative way to group services without breaking services like XboxGipSvc
# By default Windows groups following services even SVC Split is enabled: BFE, mpssvc, OneSyncSvc, PimIndexMaintenanceSvc, PlugPlay, RasMan, RemoteAccess, UnistoreSvc, UserDataSvc
# (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\*" | Where-Object -Property SvcHostSplitDisable).PSChildName
#

$registryPath = "HKLM:\SYSTEM\ControlSet001\Services\"

# These services are grouped when SVC Split is not available, but the list is not complete, it could be different on other Windows editions
$services = @(
    "DisplayEnhancementService",
    "PcaSvc",
    "WdiSystemHost",
    "AudioEndpointBuilder",
    "DeviceAssociationService",
    "NcbService",
    "StorSvc",
    "SysMain",
    "TextInputManagementService",
    "TrkWks",
    "hidserv",

    "Appinfo",
    "BITS",
    "LanmanServer",
    "SENS",
    "Schedule",
    "ShellHWDetection",
    "Themes",
    "TokenBroker",
    "UserManager",
    "ProfSvc",
    "UsoSvc",
    "Winmgmt",
    "WpnService",
    "gpsvc",
    "iphlpsvc",
	"wuauserv",

    "WinHttpAutoProxySvc",
    "EventLog",
    "TimeBrokerSvc",
    "lmhosts",
    "Dhcp",

    "FontCache",
    "nsi",
    "netprofm",
	"SstpSvc",
    "DispBrokerDesktopSvc",
    "CDPSvc",
    "EventSystem",
	"LicenseManager",

    "SystemEventsBroker",
    "Power",
    "LSM",
    "DcomLaunch",
    "BrokerInfrastructure",
	
    "CoreMessagingRegistrar",
    "DPS",
    "NcdAutoSetup",
	
	"AppXSvc",
	"ClipSVC",

    "camsvc",
    "StateRepository",

    "FDResPub",
    "SSDPSRV",

    "CryptSvc",
    "Dnscache",
    "NlaSvc",
    "LanmanWorkstation",

    "KeyIso",
    "VaultSvc",
    "SamSs"
)

foreach ($service in $services) {
    New-ItemProperty -Path "$registryPath\$service" -Name "SvcHostSplitDisable" -Value 1 -PropertyType DWord -Force
}


$userServices = @(
    "CDPUserSvc_*",
    "OneSyncSvc_*",
    "WpnUserService_*"
)

foreach ($service in $userServices) {
    $matchingServices = Get-Service | Where-Object { $_.Name -like $service }

    foreach ($matchingService in $matchingServices) {
		New-ItemProperty -Path "$registryPath\$($matchingService.Name)" -Name "SvcHostSplitDisable" -Value 1 -PropertyType  DWord -Force
    
    }
}