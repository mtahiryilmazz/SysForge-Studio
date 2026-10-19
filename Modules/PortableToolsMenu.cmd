@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1

if not defined TOOLKIT_ROOT set "TOOLKIT_ROOT=%~dp0..\"
for %%I in ("%TOOLKIT_ROOT%.") do set "TOOLKIT_ROOT=%%~fI\"

set "MODULES_DIR=%TOOLKIT_ROOT%Modules"
set "TOOLS_DIR=%TOOLKIT_ROOT%Tools"
set "LOGROOT=%TOOLKIT_ROOT%Logs"
set "TOOLS_CATALOG=%TOOLKIT_ROOT%Config\tools.catalog"

if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
if not exist "%TOOLS_DIR%" mkdir "%TOOLS_DIR%" >nul 2>&1

:tools_menu
cls
title UltimateToolkit - Portable Tools Launcher
echo.
echo ================================================================================
echo                         ULTIMATE TOOLKIT - PORTABLE TOOLS
echo ================================================================================
echo.
echo Root    : %TOOLKIT_ROOT%
echo Tools   : %TOOLS_DIR%
echo Catalog : %TOOLS_CATALOG%
echo.

if not exist "%TOOLS_CATALOG%" (
    echo Tools catalog missing.
    echo Expected: %TOOLS_CATALOG%
    echo.
    pause
    exit /b 1
)

echo Available tools:
echo.
for /f "usebackq eol=# tokens=1-5* delims=|" %%A in ("%TOOLS_CATALOG%") do (
    if not "%%~A"=="" (
        set "CAT_ID=%%~A"
        set "CAT_NAME=%%~B"
        set "CAT_TYPE=%%~C"
        set "CAT_NOTE=%%~E"
        if /i "!CAT_TYPE!"=="separator" (
            echo.
        ) else (
            echo   [!CAT_ID!] !CAT_NAME!  -  !CAT_NOTE!
        )
    )
)

echo.
echo   [O] Open Tools folder
echo   [C] Edit tools catalog
echo   [R] Refresh
echo   [99] Back to main toolkit
echo.
set "TOOL_CHOICE="
set /p TOOL_CHOICE=Select tool: 

if /i "%TOOL_CHOICE%"=="99" exit /b 0
if /i "%TOOL_CHOICE%"=="00" exit /b 0
if /i "%TOOL_CHOICE%"=="O" start "" "%TOOLS_DIR%" & goto tools_menu
if /i "%TOOL_CHOICE%"=="C" start "" notepad "%TOOLS_CATALOG%" & goto tools_menu
if /i "%TOOL_CHOICE%"=="R" goto tools_menu
if "%TOOL_CHOICE%"=="" goto tools_menu

set "TOOL_FOUND=0"
set "TOOL_NAME="
set "TOOL_TYPE="
set "TOOL_PATH="
set "TOOL_NOTE="

for /f "usebackq eol=# tokens=1-5* delims=|" %%A in ("%TOOLS_CATALOG%") do (
    if /i "%TOOL_CHOICE%"=="%%~A" (
        set "TOOL_FOUND=1"
        set "TOOL_NAME=%%~B"
        set "TOOL_TYPE=%%~C"
        set "TOOL_PATH=%%~D"
        set "TOOL_NOTE=%%~E"
    )
)

if "%TOOL_FOUND%"=="0" (
    echo.
    echo Invalid selection: %TOOL_CHOICE%
    pause
    goto tools_menu
)

call :dispatch_tool
goto tools_menu

:dispatch_tool
set "TARGET=%TOOL_PATH%"
call :resolve_target TARGET

echo.
echo Selected : %TOOL_NAME%
echo Type     : %TOOL_TYPE%
echo Target   : %TARGET%
echo.

if /i "%TOOL_TYPE%"=="exe" (
    if exist "%TARGET%" (
        start "" "%TARGET%"
        echo Launched: %TOOL_NAME%
    ) else (
        echo Missing EXE.
        echo Put the file here:
        echo %TARGET%
    )
    pause
    exit /b 0
)

if /i "%TOOL_TYPE%"=="script" (
    if exist "%TARGET%" (
        call "%TARGET%"
    ) else (
        echo Missing script:
        echo %TARGET%
        pause
    )
    exit /b 0
)

if /i "%TOOL_TYPE%"=="folder" (
    if exist "%TARGET%" (
        start "" "%TARGET%"
    ) else (
        echo Missing folder:
        echo %TARGET%
    )
    pause
    exit /b 0
)

if /i "%TOOL_TYPE%"=="url" (
    start "" "%TARGET%"
    exit /b 0
)

echo Unknown tool type: %TOOL_TYPE%
pause
exit /b 1

:resolve_target
set "RESOLVE_VALUE=!%~1!"
if "%RESOLVE_VALUE%"=="" exit /b 0
if "%RESOLVE_VALUE:~1,1%"==":" exit /b 0
if "%RESOLVE_VALUE:~0,2%"=="\\" exit /b 0
set "%~1=%TOOLKIT_ROOT%%RESOLVE_VALUE%"
exit /b 0
