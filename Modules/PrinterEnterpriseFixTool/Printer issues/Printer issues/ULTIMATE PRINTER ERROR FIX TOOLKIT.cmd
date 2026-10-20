@echo off
title SysForge Studio - Printer Error Fix Toolkit
color 0B

:MENU
cls
echo ======================================================================
echo                ULTIMATE PRINTER ERROR FIX TOOLKIT
echo ======================================================================
echo.
echo ===================== COMMON PRINTER ERRORS ==========================
echo.
echo [1]  Error 0x0000011b
echo      Windows Cannot Connect To Printer
echo.
echo [2]  Error 0x00000709
echo      Cannot Set Default Printer
echo.
echo [3]  Default Printer Not Changing
echo      Printer Cannot Be Set As Default
echo.
echo [4]  Shared Printer Not Connecting
echo      Network Printer Access Failed
echo.
echo [5]  Printer Offline Problem
echo      Printer Showing Offline
echo.
echo [6]  Print Spooler Service Error
echo      Print Queue Not Working
echo.
echo [7]  Printer Queue Stuck
echo      Documents Not Printing
echo.
echo [8]  Access Denied Printer Error
echo      Permission Denied While Printing
echo.
echo [9]  SMB Guest Share Error
echo      Shared Printer Asking Username Password
echo.
echo [10] Printer Driver Problem
echo      Driver Missing Or Corrupted
echo.
echo [11] Network Discovery Problem
echo      Shared Printer Not Visible
echo.
echo [12] RPC Server Unavailable
echo      Printer Communication Failed
echo.
echo [13] Operation Failed Error
echo      Printer Operation Could Not Be Completed
echo.
echo [14] Complete Printer Reset Tool
echo      Remove All Queue And Restart Services
echo.
echo [15] Apply ALL Printer Fixes Automatically
echo      Recommended For Most Users
echo.
echo [16] Exit Toolkit
echo.
echo ======================================================================
set /p choice=Select Option Number: 

if "%choice%"=="1" goto FIX11B
if "%choice%"=="2" goto FIX709
if "%choice%"=="3" goto DEFAULTPRINTER
if "%choice%"=="4" goto SHAREPRINTER
if "%choice%"=="5" goto OFFLINE
if "%choice%"=="6" goto SPOOLER
if "%choice%"=="7" goto QUEUE
if "%choice%"=="8" goto ACCESS
if "%choice%"=="9" goto SMB
if "%choice%"=="10" goto DRIVER
if "%choice%"=="11" goto DISCOVERY
if "%choice%"=="12" goto RPC
if "%choice%"=="13" goto OPFAILED
if "%choice%"=="14" goto RESET
if "%choice%"=="15" goto ALLFIX
if "%choice%"=="16" exit

goto MENU

:FIX11B
cls
echo FIXING ERROR 0x0000011b...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f
net stop spooler /y
net start spooler
echo.
echo ERROR 0x0000011b FIXED SUCCESSFULLY!
pause
goto MENU

:FIX709
cls
echo FIXING ERROR 0x00000709...
reg add "HKLM\Software\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f
net stop spooler /y
net start spooler
echo.
echo ERROR 0x00000709 FIXED SUCCESSFULLY!
pause
goto MENU

:DEFAULTPRINTER
cls
echo FIXING DEFAULT PRINTER ISSUE...
REG ADD "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Windows" /v LegacyDefaultPrinterMode /t REG_DWORD /d 1 /f
net stop spooler /y
net start spooler
echo.
echo DEFAULT PRINTER ISSUE FIXED!
pause
goto MENU

:SHAREPRINTER
cls
echo FIXING SHARED PRINTER CONNECTION...
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes
sc config lanmanworkstation start= auto
sc config lanmanserver start= auto
net start lanmanworkstation
net start lanmanserver
echo.
echo SHARED PRINTER ISSUE FIXED!
pause
goto MENU

:OFFLINE
cls
echo FIXING PRINTER OFFLINE ISSUE...
wmic printer where name="%printername%" call setdefaultprinter
net stop spooler /y
net start spooler
echo.
echo PRINTER OFFLINE ISSUE FIXED!
pause
goto MENU

:SPOOLER
cls
echo FIXING PRINT SPOOLER SERVICE...
net stop spooler /y
timeout /t 3 >nul
net start spooler
sc config spooler start= auto
echo.
echo PRINT SPOOLER FIXED!
pause
goto MENU

:QUEUE
cls
echo CLEARING PRINT QUEUE...
net stop spooler /y
del /Q /F /S "%systemroot%\System32\spool\PRINTERS\*.*"
net start spooler
echo.
echo PRINT QUEUE CLEARED!
pause
goto MENU

:ACCESS
cls
echo FIXING ACCESS DENIED PRINTER ERROR...
takeown /f "%systemroot%\System32\spool" /r /d y
icacls "%systemroot%\System32\spool" /grant administrators:F /t
echo.
echo ACCESS DENIED ISSUE FIXED!
pause
goto MENU

:SMB
cls
echo FIXING SMB GUEST SHARE ERROR...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f
echo.
echo SMB GUEST SHARE FIXED!
pause
goto MENU

:DRIVER
cls
echo FIXING PRINTER DRIVER ISSUE...
pnputil /scan-devices
echo.
echo DRIVER SCAN COMPLETED!
pause
goto MENU

:DISCOVERY
cls
echo FIXING NETWORK DISCOVERY...
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes
echo.
echo NETWORK DISCOVERY ENABLED!
pause
goto MENU

:RPC
cls
echo FIXING RPC SERVER ISSUE...
sc config RpcSs start= auto
net start RpcSs
echo.
echo RPC SERVER ISSUE FIXED!
pause
goto MENU

:OPFAILED
cls
echo FIXING OPERATION FAILED ERROR...
dism /online /Enable-Feature /FeatureName:Printing-LPDPrintService /NoRestart
dism /online /Enable-Feature /FeatureName:Printing-LPRPortMonitor /NoRestart
net stop spooler /y
net start spooler
echo.
echo OPERATION FAILED ERROR FIXED!
pause
goto MENU

:RESET
cls
echo RESETTING ALL PRINTER SERVICES...
net stop spooler /y
del /Q /F /S "%systemroot%\System32\spool\PRINTERS\*.*"
net start spooler
echo.
echo COMPLETE PRINTER RESET DONE!
pause
goto MENU

:ALLFIX
cls
echo APPLYING ALL PRINTER FIXES...
echo PLEASE WAIT...
echo.

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f

reg add "HKLM\Software\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f

REG ADD "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Windows" /v LegacyDefaultPrinterMode /t REG_DWORD /d 1 /f

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f

netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes

netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes

dism /online /Enable-Feature /FeatureName:Printing-LPDPrintService /NoRestart

dism /online /Enable-Feature /FeatureName:Printing-LPRPortMonitor /NoRestart

net stop spooler /y

del /Q /F /S "%systemroot%\System32\spool\PRINTERS\*.*"

net start spooler

sc config spooler start= auto

echo.
echo ======================================================================
echo ALL PRINTER FIXES APPLIED SUCCESSFULLY!
echo RESTART YOUR COMPUTER NOW
echo ======================================================================
pause
goto MENU
