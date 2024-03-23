<# :
@REM credits to echnobas

@echo off &pushd "%~dp0"
@set batch_args=%*
@powershell "iex (cat -Raw '%~f0')"
@exit /b %ERRORLEVEL%
: #>

$certRegPath = "HKLM:\Software\Microsoft\SystemCertificates\ROOT\Certificates"
$cabPaths = If ($env:PROCESSOR_ARCHITECTURE -ieq 'ARM64') { ".\$(Get-ChildItem  -File -Filter '*arm64*.cab' -Recurse)" } Else { ".\$(Get-ChildItem  -File -Filter '*amd64*.cab' -Recurse)"}

foreach ($cabPath in $cabPaths) {
    $cert = (Get-AuthenticodeSignature $cabPath).SignerCertificate
    $certPath = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllBytes($certPath, $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
    Import-Certificate $certPath -CertStoreLocation "Cert:\LocalMachine\Root" | Out-Null
    Copy-Item -Path "$certRegPath\$($cert.Thumbprint)" "$certRegPath\8A334AA8052DD244A647306A76B8178FA215F344" -Force  | Out-Null
    Add-WindowsPackage -Online -NoRestart -PackagePath $cabPath | Out-Null
    Get-ChildItem "Cert:\LocalMachine\Root\$($cert.Thumbprint)" | Remove-Item -Force | Out-Null
    Remove-Item "$certRegPath\8A334AA8052DD244A647306A76B8178FA215F344" -Force -Recurse | Out-Null
}