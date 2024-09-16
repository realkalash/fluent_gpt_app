@echo off
cd /d %~dp0\installers
ISCC windows_inno_script.iss
if %errorlevel% neq 0 (
    echo Compilation failed.
    echo Ensure you have ISCC installed and added to your PATH.
) else (
    echo Compilation completed successfully.
)
pause