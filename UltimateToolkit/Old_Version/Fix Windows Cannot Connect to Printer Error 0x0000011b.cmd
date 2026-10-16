@echo off
title Fix Printer Error 0x0000011b By Ultimate Toolkit
color 0A

echo =====================================================
echo     FIX WINDOWS PRINTER ERROR 0x0000011b
echo =====================================================
echo.

:: Check Admin Rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Please Run This BAT File As Administrator!
    pause
    exit
)

echo.
echo [1/5] Creating Registry Fix...

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print" ^
/v RpcAuthnLevelPrivacyEnabled ^
/t REG_DWORD ^
/d 0 /f

echo.
echo [2/5] Restarting Print Spooler Service...

net stop spooler /y
timeout /t 3 >nul
net start spooler

echo.
echo [3/5] Clearing Printer Spool Cache...

del /q /f "%systemroot%\System32\spool\PRINTERS\*.*" >nul 2>&1

echo.
echo [4/5] Re-Enabling Print Spooler...

sc config spooler start= auto
net start spooler

echo.
echo [5/5] Operation Completed Successfully!

echo.
echo =====================================================
echo Printer Error 0x0000011b Fixed Successfully
echo.
echo If issue still exists:
echo 1. Restart Host PC
echo 2. Restart Client PC
echo 3. Reconnect Shared Printer
echo =====================================================

pause
exit