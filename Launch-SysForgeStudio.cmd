@echo off
cd /d "%~dp0"

:: --- Step 1: Admin check ---
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ================================================
    echo  Admin yetkisi gerekiyor - Yonetici olarak baslatiliyor...
    echo ================================================
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title SysForge Studio v6.1.0 - Enterprise IT Suite [ADMIN]

echo.
echo  =============================================================
echo    SysForge Studio v6.1.0 - Kurumsal IT & Donanim Yonetimi
echo    WPF Fluent UI  *  Node.js Virtual Server  *  Yonetici [OK]
echo  =============================================================
echo.

set EXE_RELEASE=SysForgeStudio\bin\Release\net48\SysForgeStudio.exe
set EXE_DEBUG=SysForgeStudio\bin\Debug\net48\SysForgeStudio.exe

if exist "%EXE_RELEASE%" (
    echo [*] Release surumu baslatiliyor: %EXE_RELEASE%
    start "" "%EXE_RELEASE%"
    exit /b
)

if exist "%EXE_DEBUG%" (
    echo [*] Debug surumu baslatiliyor: %EXE_DEBUG%
    start "" "%EXE_DEBUG%"
    exit /b
)

echo [HATA] Derlenmis SysForgeStudio.exe bulunamadi!
echo Lutfen 'dotnet build SysForgeStudio\SysForgeStudio.csproj -c Release' komutunu calistirin.
pause
