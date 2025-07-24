@echo off
setlocal

REM Get version from parameter or use default
set "VERSION=%~1"
if "%VERSION%"=="" set "VERSION=1.0.73"

REM Remove 'v' prefix if present
set "VERSION=%VERSION:v=%"

echo Compiling a build for Windows version %VERSION%...

REM Update the version in the Inno Setup script
powershell -Command "(Get-Content 'installers\windows_inno_script.iss') -replace '#define MyAppVersion \".*\"', '#define MyAppVersion \"%VERSION%\"' | Set-Content 'installers\windows_inno_script.iss'"

call flutter build windows --release
if %errorlevel% neq 0 (
    echo Build failed.
    exit /b %errorlevel%
)
echo Building installer...

@REM Copy everything in the external_files directory to the build directory
xcopy external_files build\windows\x64\runner\Release /E /Y

cd /d %~dp0\installers
ISCC windows_inno_script.iss
if %errorlevel% neq 0 (
    echo Compilation failed.
    echo Ensure you have ISCC installed and added to your PATH.
) else (
    echo Compilation completed successfully.
    echo Output: FluentGPT-%VERSION%.exe
)
pause