@echo off
chcp 65001 > nul
cd /d "%~dp0"

if exist "%~dp0publish_output\win-x64\SysForgeStudio.exe" (
    start "" "%~dp0publish_output\win-x64\SysForgeStudio.exe"
    exit /b
)
if exist "%~dp0publish_output\SysForgeStudio.exe" (
    start "" "%~dp0publish_output\SysForgeStudio.exe"
    exit /b
)
if exist "%~dp0publish_output\win-x86\SysForgeStudio.exe" (
    start "" "%~dp0publish_output\win-x86\SysForgeStudio.exe"
    exit /b
)
if exist "%~dp0publish_output\UltimateToolkit.exe" (
    start "" "%~dp0publish_output\UltimateToolkit.exe"
    exit /b
)
if exist "%~dp0UltimateToolkit_Modern.exe" (
    start "" "%~dp0UltimateToolkit_Modern.exe"
    exit /b
)

echo [HATA] SysForgeStudio.exe bulunamadi! Lutfen once Publish_All_Architectures.bat calistirin.
pause