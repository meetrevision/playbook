<# :
@echo off &pushd "%~dp0"
@set batch_args=%*
@set script_path=%~f0
@powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (cat -Raw '%~f0')"
@exit /b %ERRORLEVEL%
: #>

$scriptPath = "$env:SystemRoot\Web\Wallpaper\MeetRevision\WALLPAPER.ps1"
& $scriptPath -Mode Desktop -ImagePath "$env:SystemRoot\Web\Wallpaper\MeetRevision\v2\desktop.jpg"
& $scriptPath -Mode LockScreen -ImagePath "$env:SystemRoot\Web\Wallpaper\MeetRevision\v2\lockscreen.jpg"