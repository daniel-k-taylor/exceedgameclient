@echo off
setlocal

set "ScriptDirectory=%~dp0"
for %%I in ("%ScriptDirectory%..") do set "ProjectDirectory=%%~fI"

if not "%~1"=="" set "GodotExecutable=%~f1"
if not defined GodotExecutable if defined GODOT_EXE set "GodotExecutable=%GODOT_EXE%"
if not defined GodotExecutable if exist "%ProjectDirectory%\godotexe\Godot_v4.4.1-stable_win64.exe" set "GodotExecutable=%ProjectDirectory%\godotexe\Godot_v4.4.1-stable_win64.exe"
if not defined GodotExecutable where godot.exe >nul 2>&1 && set "GodotExecutable=godot.exe"
if not defined GodotExecutable where godot4.exe >nul 2>&1 && set "GodotExecutable=godot4.exe"

if not defined GodotExecutable (
    echo Godot was not found.
    echo Pass its path as the first argument or set the GODOT_EXE environment variable.
    exit /b 1
)

echo Exporting HTML5...
"%GodotExecutable%" --headless --path "%ProjectDirectory%" --export-release "HTML5Export"
if errorlevel 1 goto :export_failed

echo Exporting Windows...
"%GodotExecutable%" --headless --path "%ProjectDirectory%" --export-release "Windows Desktop"
if errorlevel 1 goto :export_failed

echo Exporting Android...
"%GodotExecutable%" --headless --path "%ProjectDirectory%" --export-release "Android"
if errorlevel 1 goto :export_failed

echo.
echo All exports completed successfully.
echo Run "%ScriptDirectory%updategame.cmd" to package and upload them.
exit /b 0

:export_failed
echo.
echo Export failed. updategame.cmd was not run.
exit /b 1
