@echo off
setlocal EnableDelayedExpansion

for /f "usebackq tokens=2 delims=\" %%e in (`reg query "HKEY_USERS" ^| findstr /r /x /c:"HKEY_USERS\\S-.*" /c:"HKEY_USERS\\AME_UserHive_[^_]*"`) do (
	REM If the "Volatile Environment" key exists, that means it is a proper user. Built in accounts/SIDs do not have this key.
	reg query "HKU\%%e" | findstr /c:"Volatile Environment" /c:"AME_UserHive_" > nul 2>&1
	if not errorlevel 1 (
		call :USERREG "%%e"
	)
)

:USERREG
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "DisableTelemetry" /t REG_DWORD /d 1 /f >NUL 2>nul
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "DisablePocket" /t REG_DWORD /d 1 /f >NUL 2>nul
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "CaptivePortal" /t REG_DWORD /d 0 /f >NUL 2>nul
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "DisableFirefoxStudies" /t REG_DWORD /d 1 /f >NUL 2>nul
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "ExtensionSettings" /t REG_MULTI_SZ /d "{\0    \"uBlock0@raymondhill.net\": {\0        \"installation_mode\": \"force_installed\",\0        \"install_url\": \"https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi\"\0    }\0}" /f >NUL 2>nul
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "DisableDefaultBrowserAgent" /t REG_DWORD /d 1 /f >NUL 2>nul
reg add "HKU\%~1\Software\Policies\Mozilla\Firefox" /v "Preferences" /t REG_MULTI_SZ /d "{\"network.cookie.sameSite.laxByDefault\":{\"Value\":true,\"Status\":\"user\"},\"network.cookie.sameSite.noneRequiresSecure\":{\"Value\":true,\"Status\":\"user\"},\"network.cookie.sameSite.schemeful\":{\"Value\":true,\"Status\":\"user\"},\"browser.contentblocking.category\":{\"Value\":\"strict\",\"Status\":\"user\"},\"browser.newtabpage.activity-stream.showSponsored\":{\"Value\":false,\"Status\":\"user\"},\"browser.newtabpage.activity-stream.showSponsoredTopSites\":{\"Value\":false,\"Status\":\"user\"}}" /f >NUL 2>nul
@REM reg add "HKU\%~1\Software\Policies\Mozilla\Firefox\Bookmarks\1" /v "Title" /t REG_SZ /d "Revision" /f >NUL 2>nul
@REM reg add "HKU\%~1\Software\Policies\Mozilla\Firefox\Bookmarks\1" /v "URL" /t REG_SZ /d "https://revi.cc/" /f >NUL 2>nul
@REM reg add "HKU\%~1\Software\Policies\Mozilla\Firefox\Bookmarks\1" /v "Favicon" /t REG_SZ /d "https://revi.cc/img/favicon.png" /f >NUL 2>nul
@REM reg add "HKU\%~1\Software\Policies\Mozilla\Firefox\Bookmarks\1" /v "Placement" /t REG_SZ /d "toolbar" /f >NUL 2>nul
@REM reg add "HKU\%~1\Software\Policies\Mozilla\Firefox\Bookmarks\1" /v "Folder" /t REG_SZ /d "" /f >NUL 2>nul

@REM reg add "HKU\%~1\Software\Policies\Mozilla\Firefox\Bookmarks\10" /v "Title" /t REG_SZ /d "FAQ" /f >NUL 2>nul
@REM reg add "HKU\%~1\Software\Policies\Mozilla\Firefox\Bookmarks\10" /v "URL" /t REG_SZ /d "https://revi.cc/docs/faq/" /f >NUL 2>nul
@REM reg add "HKU\%~1\Software\Policies\Mozilla\Firefox\Bookmarks\10" /v "Favicon" /t REG_SZ /d "https://revi.cc/img/favicon.png" /f >NUL 2>nul
@REM reg add "HKU\%~1\Software\Policies\Mozilla\Firefox\Bookmarks\10" /v "Placement" /t REG_SZ /d "toolbar" /f >NUL 2>nul
@REM reg add "HKU\%~1\Software\Policies\Mozilla\Firefox\Bookmarks\10" /v "Folder" /t REG_SZ /d "" /f >NUL 2>nul

"%ProgramFiles(x86)%\Mozilla Maintenance Service\uninstall.exe" /S >NUL 2>nul