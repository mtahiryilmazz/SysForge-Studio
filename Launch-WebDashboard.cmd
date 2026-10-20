@echo off
cd /d "%~dp0"

:: --- Step 1: Admin check ---
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ================================================
    echo  Admin required - requesting elevation...
    echo ================================================
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title UltimateToolkit - Web Bridge Server [ADMIN]

echo.
echo  =========================================================
echo    UltimateToolkit Web GUI - Ultimate Toolkit Pro
echo    Bridge Server v5  *  Port 9999  *  Admin Mode [OK]
echo  =========================================================
echo.

:: --- Step 2: Kill any old server instance ---
echo [1/4] Stopping any previous server...
taskkill /F /FI "WINDOWTITLE eq UltimateToolkit*Bridge*" >nul 2>&1
powershell -Command "Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowTitle -like '*UltimateBridge*'} | Stop-Process -Force" >nul 2>&1
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -like '*powershell*' -and $_.CommandLine -like '*WebBridgeServer.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1

:: Kill anything already using port 9999
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":9999 "') do (
    if "%%a" NEQ "4" (
        taskkill /F /PID %%a >nul 2>&1
    )
)

timeout /t 1 /nobreak >nul

:: --- Step 3: Start bridge server in background ---
echo [2/4] Starting Bridge Server on http://localhost:9999 ...
netsh advfirewall firewall delete rule name="UltimateToolkit Web Bridge" >nul 2>&1
netsh advfirewall firewall add rule name="UltimateToolkit Web Bridge" dir=in action=allow protocol=TCP localport=9999 >nul 2>&1
start "UltimateToolkit-Bridge" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Modules\WebBridgeServer.ps1" -Port 9999

:: Wait for server to come up
echo [3/4] Server is starting up...
timeout /t 3 /nobreak >nul

:: Verify server is running
powershell -NoProfile -Command "try{$r=(New-Object Net.WebClient).DownloadString('http://localhost:9999/api/status');Write-Host ' [OK] Server ONLINE!'}catch{Write-Host ' [!!] Server still starting...'}"

echo.

:: --- Step 4: Open Dashboard ---
echo [4/4] Opening Dashboard in browser...
start "" "http://localhost:9999/dashboard.html"

echo.
echo  ========================================================
echo    READY! You can now use the dashboard.
echo    All clicks will execute actions on this system.
echo.
echo    Dashboard:  http://localhost:9999/dashboard.html
echo    API Server: http://localhost:9999
echo.
echo    Please keep this window open while using the toolkit.
echo    To stop: Press Ctrl+C or close this window.
echo  ========================================================
echo.

:loop
timeout /t 30 /nobreak >nul
powershell -NoProfile -Command "try{(New-Object Net.WebClient).DownloadString('http://localhost:9999/api/status')|Out-Null;Write-Host 'Server running OK'}catch{Write-Host 'Server stopped!'}"
goto loop
