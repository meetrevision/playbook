@echo off
set "source_dir=src"
set "output_file=custom_windows.apbx"
set "password=malte"

cd /d "%source_dir%"

REM Compress all files in the directory using 7zip
7z a -t7z "%output_file%" * -p"%password%" -aoa
