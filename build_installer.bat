@echo off
echo Compiling a build for Windows...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo Build failed.
    exit /b %errorlevel%
)
echo Building installer...

cd /d %~dp0\installers
ISCC windows_inno_script.iss
if %errorlevel% neq 0 (
    echo Compilation failed.
    echo Ensure you have ISCC installed and added to your PATH.
) else (
    echo Compilation completed successfully.
)
pause