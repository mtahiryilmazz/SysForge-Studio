@echo off
chcp 65001 > nul
cd /d "%~dp0"
title SysForge Studio Launcher

if exist "%~dp0SysForgeStudio\bin\Release\net48\SysForgeStudio.exe" (
    start "" "%~dp0SysForgeStudio\bin\Release\net48\SysForgeStudio.exe"
    exit /b
)
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

echo [HATA] SysForgeStudio.exe bulunamadı! Lütfen önce Publish_All_Architectures.bat dosyasını çalıştırın.
pause
