@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1

if not defined TOOLKIT_ROOT set "TOOLKIT_ROOT=%~dp0..\"
for %%I in ("%TOOLKIT_ROOT%.") do set "TOOLKIT_ROOT=%%~fI\"

set "MODULES_DIR=%TOOLKIT_ROOT%Modules"
set "LOGROOT=%TOOLKIT_ROOT%Logs"
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1

set "REQUESTED_SAFE=0"
set "OPEN_REPORT=1"
set "PAUSE_AT_END=1"

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--safe" set "REQUESTED_SAFE=1"
if /i "%~1"=="--no-open" set "OPEN_REPORT=0"
if /i "%~1"=="--no-pause" set "PAUSE_AT_END=0"
shift
goto parse_args

:args_done

set "SECRET_ARG=-IncludeSecrets"
set "OPEN_ARG="
if "%OPEN_REPORT%"=="1" set "OPEN_ARG=-Open"

cls
echo Creating system inventory HTML report...
if "%REQUESTED_SAFE%"=="1" echo Note: --safe is deprecated; full report mode includes keys/passwords when available.
echo.

if not exist "%MODULES_DIR%\SystemInventoryReport.ps1" (
    echo Missing module:
    echo %MODULES_DIR%\SystemInventoryReport.ps1
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%MODULES_DIR%\SystemInventoryReport.ps1" -OutputRoot "%SystemDrive%\System Inventory" %SECRET_ARG% %OPEN_ARG%
set "RC=%errorlevel%"

echo.
if "%RC%"=="0" (
    echo Done.
) else (
    echo System inventory report failed. Error code: %RC%
)
if "%PAUSE_AT_END%"=="1" pause
exit /b %RC%
