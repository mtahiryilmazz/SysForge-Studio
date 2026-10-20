@echo off
title SysForge Studio - Fix Printer Error 0x00000709
color 0A

echo =====================================================
echo      FIXING PRINTER ERROR 0x00000709
echo =====================================================
echo.

:: Run as Admin Check
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Please Run This BAT File As Administrator!
    pause
    exit
)

echo.
echo [1/8] Enabling LPD Printer Service...
dism /online /Enable-Feature /FeatureName:Printing-LPDPrintService /NoRestart
dism /online /Enable-Feature /FeatureName:Printing-LPRPortMonitor /NoRestart

echo.
echo [2/8] Configuring RPC Printer Policies...

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcProtocols /t REG_DWORD /d 7 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC" /v ForceKerberosForRpc /t REG_DWORD /d 0 /f

echo.
echo [3/8] Fixing RpcAuthnLevelPrivacyEnabled...

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f

echo.
echo [4/8] Granting Printer Registry Permissions...

takeown /f "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Windows" >nul 2>&1

echo.
echo [5/8] Restarting Print Spooler...

net stop spooler /y
timeout /t 3 >nul
net start spooler

echo.
echo [6/8] Clearing Printer Cache...

del /q /f "%systemroot%\System32\spool\PRINTERS\*.*" >nul 2>&1

echo.
echo [7/8] Restarting Services...

sc config spooler start= auto
net start spooler

echo.
echo [8/8] Completed Successfully!
echo.

echo =====================================================
echo Printer Error 0x00000709 Fixed Successfully
echo Restart Your Computer Now
echo =====================================================

pause
exit
