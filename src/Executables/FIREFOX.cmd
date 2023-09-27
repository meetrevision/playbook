@echo off

reg add "HKCU\Software\Policies\Mozilla\Firefox" /v "DisableTelemetry" /t REG_DWORD /d 1 /f
reg add "HKCU\Software\Policies\Mozilla\Firefox" /v "DisablePocket" /t REG_DWORD /d 1 /f
reg add "HKCU\Software\Policies\Mozilla\Firefox" /v "CaptivePortal" /t REG_DWORD /d 0 /f
reg add "HKCU\Software\Policies\Mozilla\Firefox" /v "DisableFirefoxStudies" /t REG_DWORD /d 1 /f
reg add "HKCU\Software\Policies\Mozilla\Firefox" /v "ExtensionSettings" /t REG_MULTI_SZ /d "{\0    \"uBlock0@raymondhill.net\": {\0        \"installation_mode\": \"force_installed\",\0        \"install_url\": \"https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi\"\0    }\0}" /f
reg add "HKCU\Software\Policies\Mozilla\Firefox" /v "DisableDefaultBrowserAgent" /t REG_DWORD /d 1 /f
reg add "HKCU\Software\Policies\Mozilla\Firefox" /v "Preferences" /t REG_MULTI_SZ /d "{\"network.cookie.sameSite.laxByDefault\":{\"Value\":true,\"Status\":\"user\"},\"network.cookie.sameSite.noneRequiresSecure\":{\"Value\":true,\"Status\":\"user\"},\"network.cookie.sameSite.schemeful\":{\"Value\":true,\"Status\":\"user\"},\"browser.contentblocking.category\":{\"Value\":\"strict\",\"Status\":\"user\"},\"browser.newtabpage.activity-stream.showSponsored\":{\"Value\":false,\"Status\":\"user\"},\"browser.newtabpage.activity-stream.showSponsoredTopSites\":{\"Value\":false,\"Status\":\"user\"}}" /f
reg add "HKCU\Software\Policies\Mozilla\Firefox\Bookmarks\1" /v "Title" /t REG_SZ /d "Revision" /f
reg add "HKCU\Software\Policies\Mozilla\Firefox\Bookmarks\1" /v "URL" /t REG_SZ /d "https://revi.cc/" /f
reg add "HKCU\Software\Policies\Mozilla\Firefox\Bookmarks\1" /v "Favicon" /t REG_SZ /d "https://revi.cc/img/favicon.png" /f
reg add "HKCU\Software\Policies\Mozilla\Firefox\Bookmarks\1" /v "Placement" /t REG_SZ /d "toolbar" /f
reg add "HKCU\Software\Policies\Mozilla\Firefox\Bookmarks\1" /v "Folder" /t REG_SZ /d "" /f

reg add "HKCU\Software\Policies\Mozilla\Firefox\Bookmarks\10" /v "Title" /t REG_SZ /d "FAQ" /f
reg add "HKCU\Software\Policies\Mozilla\Firefox\Bookmarks\10" /v "URL" /t REG_SZ /d "https://revi.cc/docs/faq/" /f
reg add "HKCU\Software\Policies\Mozilla\Firefox\Bookmarks\10" /v "Favicon" /t REG_SZ /d "https://revi.cc/img/favicon.png" /f
reg add "HKCU\Software\Policies\Mozilla\Firefox\Bookmarks\10" /v "Placement" /t REG_SZ /d "toolbar" /f
reg add "HKCU\Software\Policies\Mozilla\Firefox\Bookmarks\10" /v "Folder" /t REG_SZ /d "" /f

"%ProgramFiles(x86)%\Mozilla Maintenance Service\uninstall.exe" /S