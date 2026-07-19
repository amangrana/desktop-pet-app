@echo off
setlocal

set "PROJECT_DIR=%~dp0"
set "GODOT_EXE=%PROJECT_DIR%.tools\godot-4.7.1\Godot_v4.7.1-stable_win64.exe"

if not exist "%GODOT_EXE%" (
    echo Godot was not found inside the DesktopPet folder.
    echo Expected: %GODOT_EXE%
    pause
    exit /b 1
)

start "" "%GODOT_EXE%" --path "%PROJECT_DIR%"
