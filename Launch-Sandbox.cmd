@echo off
setlocal
cd /d "%~dp0"
title SysForge Studio - Windows Sandbox Launcher

echo =======================================================
echo    SysForge Studio - Portable Windows Sandbox Launcher
echo =======================================================
echo.
echo Initializing dynamic Windows Sandbox configuration...

set "WSB_TEMP=%TEMP%\SysForgeStudio_Auto.wsb"
set "HOST_DIR=%~dp0"
:: Strip trailing backslash if present
if "%HOST_DIR:~-1%"=="\" set "HOST_DIR=%HOST_DIR:~0,-1%"

(
echo ^<Configuration^>
echo   ^<VGpu^>Default^</VGpu^>
echo   ^<Networking^>Default^</Networking^>
echo   ^<MappedFolders^>
echo     ^<MappedFolder^>
echo       ^<HostFolder^>%HOST_DIR%^</HostFolder^>
echo       ^<SandboxFolder^>C:\Users\WDAGUtilityAccount\Desktop\SysForgeStudio^</SandboxFolder^>
echo       ^<ReadOnly^>false^</ReadOnly^>
echo     ^</MappedFolder^>
echo   ^</MappedFolders^>
echo   ^<LogonCommand^>
echo     ^<Command^>C:\Users\WDAGUtilityAccount\Desktop\SysForgeStudio\Run_SysForgeStudio.bat^</Command^>
echo   ^</LogonCommand^>
echo ^</Configuration^>
) > "%WSB_TEMP%"

echo [OK] Dynamic WSB generated: %WSB_TEMP%
echo [INFO] Launching Windows Sandbox...
start "" "%WSB_TEMP%"
exit /b 0
