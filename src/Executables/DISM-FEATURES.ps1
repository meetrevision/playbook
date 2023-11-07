function Toggle-Feature {
    param(
        [string]$featureName,
        [bool]$bool
    )
    
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Notifications\OptionalFeatures"
    $regKey = Get-ItemProperty -Path "$regPath\$featureName" -ErrorAction SilentlyContinue
	
	$dismCmd = if ($bool) { "Enable" } else { "Disable" }
	
    if ($regKey -eq $null) {
        Write-Host "$dismCmd $featureName"
    } else {
		if (($regKey.Selection -eq 0 -and $bool) -or ($regKey.Selection -eq 1 -and !$bool)) {
            Write-Host "$dismCmd $featureName"
			if ($bool) {
				Enable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart
			} else {
				Disable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart
			}
		}
    }
}


$featuresToToggle = @(
    @{ Name = "DirectPlay"; Bool = $true },
    @{ Name = "LegacyComponents"; Bool = $true },
    @{ Name = "MicrosoftWindowsPowerShellV2"; Bool = $false },
    @{ Name = "MicrosoftWindowsPowerShellV2Root"; Bool = $false },
    @{ Name = "MSRDC-Infrastructure"; Bool = $false },
    @{ Name = "Printing-Foundation-Features"; Bool = $false },
    @{ Name = "Printing-Foundation-InternetPrinting-Client"; Bool = $false },
    @{ Name = "WorkFolders-Client"; Bool = $false },
	@{ Name = "SmbDirect"; Bool = $false }
)
foreach ($feature in $featuresToToggle) {
    Toggle-Feature -featureName $feature.Name -bool $feature.Bool
}