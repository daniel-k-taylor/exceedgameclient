@echo off
setlocal

REM NOTES:
REM Requires Butler, logging into itch io for butler, 7zip, and setting up the right directory paths.
REM TODO: Make this more easily runnable straight from the project.

set "DirectoryPath=..\export"
set "WindowsNativePath=..\export_native\windows"
set "AndroidNativePath=..\export_native\android"

REM Delete the existing game.zip if it exists
if exist "%DirectoryPath%\game.zip" (
    del "%DirectoryPath%\game.zip"
)
if exist "%WindowsNativePath%\exceedgg.exe" (
    del "%WindowsNativePath%\exceedgg.exe"
)
if exist "%WindowsNativePath%\exceedgg_windows.zip" (
    del "%WindowsNativePath%\exceedgg_windows.zip"
)

REM Zip all the contents of the directory into game.zip
move %WindowsNativePath%\index.exe %WindowsNativePath%\exceedgg.exe
powershell -command "Compress-Archive -Path '%DirectoryPath%\*' -DestinationPath '%DirectoryPath%\game.zip'"

if errorlevel 1 (
    echo Error occurred while creating game.zip.
    exit /b 1
)

REM Call butler.exe with the path to game.zip
set "butlerCommand=.\butler.exe"
if not exist "%butlerCommand%" (
    echo butler.exe not found. Please make sure it is in the current directory or provide the full path.
    exit /b 1
)

"%butlerCommand%" push "%DirectoryPath%\game.zip" daktagames/exceedgg:html5

REM Now for the Native versions
powershell -command "Compress-Archive -Path '%WindowsNativePath%\exceedgg.exe' -DestinationPath '%WindowsNativePath%\exceedgg_windows.zip'"
if errorlevel 1 (
    echo Error occurred while creating exceedgg_windows.zip.
    exit /b 1
)

"%butlerCommand%" push "%WindowsNativePath%\exceedgg_windows.zip" daktagames/exceedgg:windows

REM Now for the Android version
if exist "%AndroidNativePath%\exceedgg.apk" (
    "%butlerCommand%" push "%AndroidNativePath%\exceedgg.apk" daktagames/exceedgg:android
) else (
    echo Warning: Android APK not found at %AndroidNativePath%\exceedgg.apk
)

endlocal
