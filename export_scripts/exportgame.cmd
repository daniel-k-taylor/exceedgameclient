@echo off
setlocal

set "ScriptDirectory=%~dp0"
for %%I in ("%ScriptDirectory%..") do set "ProjectDirectory=%%~fI"

if not "%~1"=="" set "GodotExecutable=%~f1"
if not defined GodotExecutable if defined GODOT_EXE set "GodotExecutable=%GODOT_EXE%"
if not defined GodotExecutable if exist "%ProjectDirectory%\godotexe\Godot_v4.7.2-stable_win64.exe" set "GodotExecutable=%ProjectDirectory%\godotexe\Godot_v4.7.2-stable_win64.exe"
if not defined GodotExecutable where godot.exe >nul 2>&1 && set "GodotExecutable=godot.exe"
if not defined GodotExecutable where godot4.exe >nul 2>&1 && set "GodotExecutable=godot4.exe"

if not defined GodotExecutable (
    echo Godot was not found.
    echo Pass its path as the first argument or set the GODOT_EXE environment variable.
    exit /b 1
)

echo Exporting HTML5...
if not exist "%ProjectDirectory%\export" mkdir "%ProjectDirectory%\export"
"%GodotExecutable%" --headless --path "%ProjectDirectory%" --export-release "HTML5Export"
if errorlevel 1 goto :export_failed

echo Exporting Windows...
if not exist "%ProjectDirectory%\export_native\windows" mkdir "%ProjectDirectory%\export_native\windows"
"%GodotExecutable%" --headless --path "%ProjectDirectory%" --export-release "Windows Desktop"
if errorlevel 1 goto :export_failed

echo Exporting Android...
if not exist "%ProjectDirectory%\export_native\android" mkdir "%ProjectDirectory%\export_native\android"

rem The game is distributed for free on itch.io, so a self-signed keystore is used.
rem Keep exceedgg-release.keystore backed up: Android requires the same key to update an installed app.
if not defined ANDROID_KEYSTORE set "ANDROID_KEYSTORE=%ScriptDirectory%exceedgg-release.keystore"
if not defined ANDROID_KEYSTORE_USER set "ANDROID_KEYSTORE_USER=exceedgg"
if not defined ANDROID_KEYSTORE_PASSWORD set "ANDROID_KEYSTORE_PASSWORD=exceedgg"

if exist "%ANDROID_KEYSTORE%" goto :keystore_ready
echo Keystore not found, generating a self-signed one at "%ANDROID_KEYSTORE%"...
call :find_keytool
if not defined KeytoolExecutable (
    echo keytool was not found. Install a JDK or set the KEYTOOL_EXE environment variable.
    goto :export_failed
)
"%KeytoolExecutable%" -genkeypair -noprompt -keystore "%ANDROID_KEYSTORE%" -alias "%ANDROID_KEYSTORE_USER%" -keyalg RSA -keysize 2048 -validity 10950 -storepass "%ANDROID_KEYSTORE_PASSWORD%" -keypass "%ANDROID_KEYSTORE_PASSWORD%" -dname "CN=Exceed Game Client, OU=Itch, O=Exceed, L=NA, ST=NA, C=US"
if errorlevel 1 goto :export_failed

:keystore_ready

set "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=%ANDROID_KEYSTORE%"
set "GODOT_ANDROID_KEYSTORE_DEBUG_USER=%ANDROID_KEYSTORE_USER%"
set "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=%ANDROID_KEYSTORE_PASSWORD%"
set "GODOT_ANDROID_KEYSTORE_RELEASE_PATH=%ANDROID_KEYSTORE%"
set "GODOT_ANDROID_KEYSTORE_RELEASE_USER=%ANDROID_KEYSTORE_USER%"
set "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=%ANDROID_KEYSTORE_PASSWORD%"

"%GodotExecutable%" --headless --path "%ProjectDirectory%" --export-release "Android"
if errorlevel 1 goto :export_failed

echo.
echo All exports completed successfully.
echo Run "%ScriptDirectory%updategame.cmd" to package and upload them.
exit /b 0

:find_keytool
if defined KEYTOOL_EXE set "KeytoolExecutable=%KEYTOOL_EXE%" & goto :eof
where keytool.exe >nul 2>&1 && set "KeytoolExecutable=keytool.exe" & goto :eof
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\keytool.exe" set "KeytoolExecutable=%JAVA_HOME%\bin\keytool.exe" & goto :eof
if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\keytool.exe" set "KeytoolExecutable=%ProgramFiles%\Android\Android Studio\jbr\bin\keytool.exe" & goto :eof
for /d %%J in ("%ProgramFiles%\Eclipse Adoptium\jdk-*") do if exist "%%~fJ\bin\keytool.exe" set "KeytoolExecutable=%%~fJ\bin\keytool.exe"
for /d %%J in ("%ProgramFiles%\Java\jdk-*") do if exist "%%~fJ\bin\keytool.exe" set "KeytoolExecutable=%%~fJ\bin\keytool.exe"
goto :eof

:export_failed
echo.
echo Export failed. updategame.cmd was not run.
exit /b 1
