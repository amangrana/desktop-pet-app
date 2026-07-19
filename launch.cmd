@echo off
setlocal

set "LAUNCH_SCRIPT=%~dp0launch.ps1"
if not exist "%LAUNCH_SCRIPT%" (
    echo Desktop Pet launcher was not found.
    echo Expected: %LAUNCH_SCRIPT%
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%LAUNCH_SCRIPT%"
if errorlevel 1 (
    echo.
    echo Desktop Pet could not be started.
    pause
    exit /b 1
)
