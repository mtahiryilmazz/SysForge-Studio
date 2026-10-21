@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:: =========================================================================
::  SysForge Studio — Node.js Virtual LAN Server Launcher [ADMIN]
:: =========================================================================

:: --- Step 1: Administrator Privilege Check ---
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo =========================================================
    echo  Yoneticilik yetkisi gerekiyor - Yukseltilmis izin isteniyor...
    echo =========================================================
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title SysForge Studio - Node.js Virtual Server & LAN Gateway [ADMIN]

echo.
echo  ====================================================================
echo    SysForge Studio  --  Node.js Virtual Server & LAN Host
echo    Ag Erisimi: Tum Ag Arayuzleri (0.0.0.0)  *  Port: 9999
echo  ====================================================================
echo.

:: --- Step 2: Check Node.js runtime ---
where node >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [HATA] Node.js sisteminizde kurulu bulunamadi!
    echo Lutfen https://nodejs.org adresinden Node.js kurunuz.
    echo Veya geleneksel PowerShell sunucusu icin Launch-WebDashboard.cmd dosyasini calistiriniz.
    echo.
    pause
    exit /b 1
)

:: --- Step 3: Stop any conflicting process on port 9999 ---
echo [1/3] Onceki sunucu ornekleri kontrol ediliyor...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":9999 "') do (
    if "%%a" NEQ "4" (
        taskkill /F /PID %%a >nul 2>&1
    )
)
timeout /t 1 /nobreak >nul

:: --- Step 4: Configure Windows Firewall Rule for LAN access ---
echo [2/3] Windows Guvenlik Duvari kurali yapilandiriliyor (Port 9999 TCP)...
netsh advfirewall firewall delete rule name="SysForge Studio Web Server" >nul 2>&1
netsh advfirewall firewall add rule name="SysForge Studio Web Server" dir=in action=allow protocol=TCP localport=9999 >nul 2>&1

:: --- Step 5: Start Browser after 2 seconds ---
echo [3/3] Sanal sunucu baslatiliyor ve tarayici aciliyor...
start "" "http://localhost:9999/dashboard.html"

:: Run Node Server in this foreground window so technician sees live LAN connections
node server.js

pause
