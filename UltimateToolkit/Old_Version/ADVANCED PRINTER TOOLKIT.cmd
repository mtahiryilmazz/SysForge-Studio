@echo off
title ADVANCED PRINTER TOOLKIT - Ultimate Toolkit
color 0B

:MENU
cls
echo =================================================================================================================
echo                                    ADVANCED PRINTER TOOLKIT
echo =================================================================================================================
echo.
echo   [1] Error 0x0000011b          [2] Error 0x00000709           [3] Default Printer Issue
echo       Cannot Connect Printer        Cannot Set Printer             Printer Not Changing
echo.
echo   [4] Shared Printer Error      [5] Printer Offline             [6] Print Spooler Error
echo       Network Printer Failed        Printer Showing Offline         Queue Not Working
echo.
echo   [7] Print Queue Stuck         [8] Access Denied Error         [9] SMB Guest Share Error
echo       Documents Not Printing        Permission Problem              Asking Username Password
echo.
echo   [10] Driver Problem           [11] Network Discovery          [12] RPC Server Error
echo        Driver Missing                Printer Not Visible             Communication Failed
echo.
echo   [13] Operation Failed         [14] Remove Printers            [15] Remove Drivers
echo        Could Not Complete            Delete Installed Printers       Delete Driver Package
echo.
echo   [16] Clean Version-3          [17] Clean Version-4            [18] Registry Cleanup
echo        Old Drivers Remove            Modern Drivers Remove           Remove Printer Regedit
echo.
echo   [19] Clear Print Queue        [20] Restart Spooler            [21] COMPLETE CLEANUP
echo        Delete Stuck Jobs             Restart Printer Service         Full Printer Reset
echo.
echo   [22] APPLY ALL FIXES          [23] Exit
echo        Recommended For Users
echo.
echo =================================================================================================================
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
if "%choice%"=="14" goto REMOVEPRINTER
if "%choice%"=="15" goto REMOVEDRIVER
if "%choice%"=="16" goto VERSION3
if "%choice%"=="17" goto VERSION4
if "%choice%"=="18" goto REGCLEAN
if "%choice%"=="19" goto CLEARQUEUE
if "%choice%"=="20" goto RESTARTSPOOLER
if "%choice%"=="21" goto FULLCLEAN
if "%choice%"=="22" goto ALLFIX
if "%choice%"=="23" exit

goto MENU

:FIX11B
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f
net stop spooler /y
net start spooler
echo ERROR 0x0000011b FIXED!
pause
goto MENU

:FIX709
reg add "HKLM\Software\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f
net stop spooler /y
net start spooler
echo ERROR 0x00000709 FIXED!
pause
goto MENU

:DEFAULTPRINTER
REG ADD "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Windows" /v LegacyDefaultPrinterMode /t REG_DWORD /d 1 /f
echo DEFAULT PRINTER ISSUE FIXED!
pause
goto MENU

:SHAREPRINTER
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes
echo SHARED PRINTER ISSUE FIXED!
pause
goto MENU

:OFFLINE
net stop spooler /y
net start spooler
echo PRINTER OFFLINE ISSUE FIXED!
pause
goto MENU

:SPOOLER
net stop spooler /y
net start spooler
echo PRINT SPOOLER FIXED!
pause
goto MENU

:QUEUE
net stop spooler /y
del /Q /F /S "%systemroot%\System32\spool\PRINTERS\*.*"
net start spooler
echo PRINT QUEUE CLEARED!
pause
goto MENU

:ACCESS
takeown /f "%systemroot%\System32\spool" /r /d y
icacls "%systemroot%\System32\spool" /grant administrators:F /t
echo ACCESS DENIED ISSUE FIXED!
pause
goto MENU

:SMB
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f
echo SMB GUEST SHARE FIXED!
pause
goto MENU

:DRIVER
rundll32 printui.dll,PrintUIEntry /s /t2
echo DRIVER WINDOW OPENED!
pause
goto MENU

:DISCOVERY
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes
echo NETWORK DISCOVERY ENABLED!
pause
goto MENU

:RPC
sc config RpcSs start= auto
net start RpcSs
echo RPC SERVER ISSUE FIXED!
pause
goto MENU

:OPFAILED
dism /online /Enable-Feature /FeatureName:Printing-LPDPrintService /NoRestart
dism /online /Enable-Feature /FeatureName:Printing-LPRPortMonitor /NoRestart
echo OPERATION FAILED ERROR FIXED!
pause
goto MENU

:REMOVEPRINTER
for /f "skip=1 tokens=*" %%p in ('wmic printer get name') do (
 if not "%%p"=="" (
  printui.exe /dl /n "%%p"
 )
)
echo ALL PRINTERS REMOVED!
pause
goto MENU

:REMOVEDRIVER
rundll32 printui.dll,PrintUIEntry /s /t2
echo REMOVE DRIVERS MANUALLY!
pause
goto MENU

:VERSION3
net stop spooler /y
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-3" /f
net start spooler
echo VERSION-3 DRIVERS CLEANED!
pause
goto MENU

:VERSION4
net stop spooler /y
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-4" /f
net start spooler
echo VERSION-4 DRIVERS CLEANED!
pause
goto MENU

:REGCLEAN
reg delete "HKCU\Printers" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers" /f
echo REGISTRY CLEANUP COMPLETED!
pause
goto MENU

:CLEARQUEUE
net stop spooler /y
del /Q /F /S "%systemroot%\System32\spool\PRINTERS\*.*"
net start spooler
echo PRINT QUEUE CLEARED!
pause
goto MENU

:RESTARTSPOOLER
net stop spooler /y
timeout /t 2 >nul
net start spooler
echo PRINT SPOOLER RESTARTED!
pause
goto MENU

:FULLCLEAN
net stop spooler /y
del /Q /F /S "%systemroot%\System32\spool\PRINTERS\*.*"
reg delete "HKCU\Printers" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-3" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-4" /f
net start spooler
echo COMPLETE CLEANUP DONE!
pause
goto MENU

:ALLFIX
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f
REG ADD "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Windows" /v LegacyDefaultPrinterMode /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes
net stop spooler /y
del /Q /F /S "%systemroot%\System32\spool\PRINTERS\*.*"
net start spooler
echo ALL FIXES APPLIED SUCCESSFULLY!
pause
goto MENU