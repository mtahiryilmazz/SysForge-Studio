@echo off
title SysForge Studio - Guest Printer Share Access Fix
color 0A

echo =====================================================
echo         FIX GUEST SHARE ACCESS ERROR
echo =====================================================
echo.

:: Admin Check
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Please Run This BAT File As Administrator!
    pause
    exit
)

echo.
echo [1/7] Enabling SMB Guest Logons...

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" ^
/v AllowInsecureGuestAuth ^
/t REG_DWORD ^
/d 1 /f

echo.
echo [2/7] Enabling Network Discovery...

netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes

echo.
echo [3/7] Enabling File And Printer Sharing...

netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes

echo.
echo [4/7] Starting Required Services...

sc config lanmanworkstation start= auto
sc config lanmanserver start= auto

net start lanmanworkstation
net start lanmanserver

echo.
echo [5/7] Enabling SMB1 Client...

dism /online /Enable-Feature /FeatureName:SMB1Protocol /All /NoRestart

echo.
echo [6/7] Restarting Explorer...

taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe

echo.
echo [7/7] Completed Successfully!

echo.
echo =====================================================
echo Guest Share Error Fixed Successfully
echo.
echo Now Try Accessing:
echo \\COMPUTERNAME\SHARENAME
echo.
echo Restart PC If Needed
echo =====================================================

pause
exit
