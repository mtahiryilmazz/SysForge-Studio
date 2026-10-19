@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1

if not defined TOOLKIT_ROOT set "TOOLKIT_ROOT=%~dp0..\"
for %%I in ("%TOOLKIT_ROOT%.") do set "TOOLKIT_ROOT=%%~fI\"

set "OUTPUT_ROOT=%SystemDrive%\System Inventory"
set "OPEN_REPORT=1"
set "PAUSE_AT_END=1"

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--no-open" set "OPEN_REPORT=0"
if /i "%~1"=="--no-pause" set "PAUSE_AT_END=0"
if /i "%~1"=="--output-root" (
    if not "%~2"=="" (
        set "OUTPUT_ROOT=%~2"
        shift
    )
)
shift
goto parse_args

:args_done

if not exist "%OUTPUT_ROOT%" mkdir "%OUTPUT_ROOT%" >nul 2>&1
set "REPORT_PATH=%OUTPUT_ROOT%\%COMPUTERNAME%_BatteryReport.html"

cls
echo Creating Windows battery report...
echo Output:
echo %REPORT_PATH%
echo.

powercfg /batteryreport /output "%REPORT_PATH%"
set "RC=%errorlevel%"

echo.
if "%RC%"=="0" (
    echo Done.
    if "%OPEN_REPORT%"=="1" start "" "%REPORT_PATH%"
) else (
    echo Battery report failed. Error code: %RC%
)

if "%PAUSE_AT_END%"=="1" pause
exit /b %RC%
