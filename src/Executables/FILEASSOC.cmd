
@REM copy /y "Associations.dll" "%WINDIR%\System32\OEMDefaultAssociations.dll"
copy /y "OEMDefaultAssociations.xml" "%WINDIR%\System32\OEMDefaultAssociations.xml"

@echo OFF
for /f "usebackq tokens=2 delims=\" %%A in (`reg query "HKEY_USERS" ^| findstr /r /x /c:"HKEY_USERS\\S-.*" /c:"HKEY_USERS\\AME_UserHive_[^_]*"`) do (
	REM If the "Volatile Environment" key exists, that means it is a proper user. Built in accounts/SIDs don't have this key.
	reg query "HKU\%%A" | findstr /c:"Volatile Environment" /c:"AME_UserHive_" > NUL 2>&1
		if not errorlevel 1 (
			PowerShell -NoP -ExecutionPolicy Bypass -File assoc.ps1 "Placeholder" "%%A" "Proto:https:BraveHTML" "Proto:http:BraveHTML" ".bmp:PhotoViewer.FileAssoc.Bitmap" ".dib:PhotoViewer.FileAssoc.Bitmap" ".jfif:PhotoViewer.FileAssoc.JFIF" ".jpe:PhotoViewer.FileAssoc.Jpeg" ".jpeg:PhotoViewer.FileAssoc.Jpeg" ".jpg:PhotoViewer.FileAssoc.Jpeg" ".jxr:PhotoViewer.FileAssoc.Wdp" ".png:PhotoViewer.FileAssoc.Png" ".tif:PhotoViewer.FileAssoc.Tiff" ".tiff:PhotoViewer.FileAssoc.Tiff" ".wdp:PhotoViewer.FileAssoc.Wdp" ".htm:BraveHTML" ".html:BraveHTML" ".pdf:BraveHTML" ".shtml:BraveHTML"
	)
)