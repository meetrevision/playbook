<# :
REM credits to echnobas

@echo off &pushd "%~dp0"
@set batch_args=%*
@powershell "iex (cat -Raw '%~f0')"
@exit /b %ERRORLEVEL%
: #>

$cabPath = ".\$(Get-ChildItem -File -Filter *.cab)"
$certRegPath = "HKLM:\Software\Microsoft\SystemCertificates\ROOT\Certificates"

$cert = (Get-AuthenticodeSignature $cabPath).SignerCertificate
$certPath = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllBytes($certPath, $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
Import-Certificate $certPath -CertStoreLocation "Cert:\LocalMachine\Root" | Out-Null
Copy-Item -Path "$certRegPath\$($cert.Thumbprint)" "$certRegPath\8A334AA8052DD244A647306A76B8178FA215F344" -Force  | Out-Null
Add-WindowsPackage -Online -NoRestart -PackagePath $cabPath | Out-Null
Get-ChildItem "Cert:\LocalMachine\Root\$($cert.Thumbprint)" | Remove-Item
# Remove-Item "$certRegPath\8A334AA8052DD244A647306A76B8178FA215F344" -Force -Recurse | Out-Null
# Move-Item -Path "$env:systemdrive\MeetRevision\Windows\System32" -Destination "$env:systemroot\" -Force