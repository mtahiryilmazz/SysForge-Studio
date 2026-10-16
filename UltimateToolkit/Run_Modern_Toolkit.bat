@echo off
cd /d "%~dp0"
if exist "%~dp0UltimateToolkit_Modern.exe" (
    start "" "%~dp0UltimateToolkit_Modern.exe"
    exit /b
)
if exist "%~dp0Portable\UltimateToolkit.exe" (
    start "" "%~dp0Portable\UltimateToolkit.exe"
    exit /b
)
echo Uygulama bulunamadi!
pause