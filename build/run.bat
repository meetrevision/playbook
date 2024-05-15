@echo off
set "script_dir=%~dp0"
for %%I in ("%script_dir%..") do set "parent_dir=%%~fI"

set "source_dir=%parent_dir%\src\"
set "output_file=%script_dir%\custom_windows.apbx"
set "password=malte"

cd /d "%source_dir%"

REM Compress all files in the directory using 7zip
7z a -t7z "%output_file%" * -p"%password%"
