@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
:: ==========================================================================================
::         ULTIMATE TOOLKIT VERSION 5 - By Ultimate Toolkit
::         Windows IT Admin Enterprise Master Toolkit - FULL ORGANIZED WOW BUILD
::         Categories: 37 Modules ^| Smart Search ^| Driver Auto Center ^| 10000+ Command Vault
:: ==========================================================================================

set "TOOLKIT_ORIGINAL_ARGS=%*"
set "TOOLKIT_NO_ELEVATE="
set "TOOLKIT_START_LABEL="
set "TOOLKIT_BACK_LABEL="

:parse_cli_args
if "%~1"=="" goto cli_args_done
if /i "%~1"=="--no-elevate" (
    set "TOOLKIT_NO_ELEVATE=1"
    shift
    goto parse_cli_args
)
if /i "%~1"=="--label" (
    if not "%~2"=="" (
        set "TOOLKIT_START_LABEL=%~2"
        shift
        shift
        goto parse_cli_args
    )
)
if /i "%~1"=="--back" (
    if not "%~2"=="" (
        set "TOOLKIT_BACK_LABEL=%~2"
        shift
        shift
        goto parse_cli_args
    )
)
shift
goto parse_cli_args

:cli_args_done

if not defined TOOLKIT_NO_ELEVATE (
    net session >nul 2>&1
)
if not defined TOOLKIT_NO_ELEVATE if errorlevel 1 (
    color 4F
    cls
    echo ============================================================
    echo       ADMINISTRATOR PERMISSION REQUIRED
    echo       Requesting elevated window now...
    echo ============================================================
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%TOOLKIT_ORIGINAL_ARGS%' -Verb RunAs" >nul 2>&1
    if errorlevel 1 (
        echo Could not open elevated window. Right-click this file and select "Run as administrator".
        pause
    )
    exit /b
)

title ULTIMATE TOOLKIT VERSION 5 - By Ultimate Toolkit
mode con cols=160 lines=55

set "TOOLKIT_VERSION=Version 5"
set "TOOLKIT_AUTHOR=Ultimate Toolkit"
set "TOOLKIT_ROOT=%~dp0"
for %%I in ("%TOOLKIT_ROOT%.") do set "TOOLKIT_ROOT=%%~fI\"
set "TOOLKIT_HOME=%TOOLKIT_ROOT%"
set "MODULES_DIR=%TOOLKIT_ROOT%Modules"
if defined UT_ORIGINAL_DIR (
    set "TOOLS_DIR=%UT_ORIGINAL_DIR%Tools"
) else (
    set "TOOLS_DIR=%TOOLKIT_ROOT%Tools"
)
set "ASSETS_DIR=%TOOLKIT_ROOT%Assets"
set "CONFIG_DIR=%TOOLKIT_ROOT%Config"
set "LOGROOT=%TOOLKIT_ROOT%Logs"
for %%D in ("%MODULES_DIR%" "%TOOLS_DIR%" "%ASSETS_DIR%" "%CONFIG_DIR%" "%LOGROOT%") do if not exist "%%~D" mkdir "%%~D" >nul 2>&1

call :init_ui_colors
call :setup_console_scroll
if defined TOOLKIT_START_LABEL (
    set "BACK_MENU=main"
    if defined TOOLKIT_BACK_LABEL set "BACK_MENU=%TOOLKIT_BACK_LABEL%"
    set "SAFE_TARGET=%TOOLKIT_START_LABEL%"
    goto safe_goto
)
goto main

:init_ui_colors
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "C_RESET=%ESC%[0m"
set "C_CYAN=%ESC%[96m"
set "C_GREEN=%ESC%[92m"
set "C_YELLOW=%ESC%[93m"
set "C_MAGENTA=%ESC%[95m"
set "C_RED=%ESC%[91m"
set "C_WHITE=%ESC%[97m"
set "C_BLUE=%ESC%[94m"
exit /b

:setup_console_scroll
mode con: cols=170 lines=45 >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $raw=$Host.UI.RawUI; $max=$raw.MaxWindowSize; $cur=$raw.WindowSize; $bufWidth=[Math]::Max(170,$cur.Width); $raw.BufferSize=New-Object System.Management.Automation.Host.Size -ArgumentList $bufWidth,3000; $winWidth=[Math]::Min(170,$max.Width); $winHeight=[Math]::Min(45,$max.Height); $raw.WindowSize=New-Object System.Management.Automation.Host.Size -ArgumentList $winWidth,$winHeight } catch {}" >nul 2>&1
exit /b


:main
set "BACK_MENU=main"
cls
chcp 65001 >nul
call :setup_console_scroll

:: ANSI COLORS
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

echo.
echo  %ESC%[96m╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗%ESC%[0m
echo  %ESC%[95m║                                               ULTIMATE X PRO MAX %TOOLKIT_VERSION% - By %TOOLKIT_AUTHOR%                                              ║%ESC%[0m
echo  %ESC%[93m║                            Windows IT Admin Enterprise Toolkit - 3 Column Command Center / Problem Solver / Backup Pro                               ║%ESC%[0m
echo  %ESC%[96m╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝%ESC%[0m


:: ==========================================================================================
:: MAIN MODULES
:: ==========================================================================================

echo  %ESC%[96m════════════════════════════════════════════════════════ MAIN MODULES ════════════════════════════════════════════════════════%ESC%[0m
echo.

:: ======================= ROW 1 =======================

echo  %ESC%[94m┌────────────────────────────────────────────┐%ESC%[0m   %ESC%[92m┌────────────────────────────────────────────┐%ESC%[0m   %ESC%[95m┌────────────────────────────────────────────┐%ESC%[0m
echo  %ESC%[94m│         SYSTEM ^& ADMINISTRATION          │%ESC%[0m   %ESC%[92m│          NETWORK ^& INTERNET              │%ESC%[0m   %ESC%[95m│          REPAIR ^& MANAGEMENT             │%ESC%[0m
echo  %ESC%[94m├────────────────────────────────────────────┤%ESC%[0m   %ESC%[92m├────────────────────────────────────────────┤%ESC%[0m   %ESC%[95m├────────────────────────────────────────────┤%ESC%[0m

echo  %ESC%[96m│ [01] SYSTEM ^& ADMINISTRATION             │%ESC%[0m   %ESC%[92m│ [02] NETWORK ^& INTERNET                  │%ESC%[0m   %ESC%[95m│ [03] WINDOWS REPAIR ^& RECOVERY           │%ESC%[0m
echo  %ESC%[96m│ [04] SECURITY ^& DEFENDER                 │%ESC%[0m   %ESC%[92m│ [05] PERFORMANCE ^& OPTIMIZATION          │%ESC%[0m   %ESC%[95m│ [06] STORAGE ^& DISK MANAGEMENT           │%ESC%[0m
echo  %ESC%[96m│ [07] USER / ACCOUNT MANAGEMENT            │%ESC%[0m   %ESC%[92m│ [08] BACKUP ^& RESTORE CENTER             │%ESC%[0m   %ESC%[95m│ [09] DRIVER ^& HARDWARE MANAGEMENT        │%ESC%[0m
echo  %ESC%[96m│ [10] WINDOWS UPDATE ^& ACTIVATION         │%ESC%[0m   %ESC%[92m│ [11] OFFICE / OUTLOOK TOOLKIT             │%ESC%[0m   %ESC%[95m│ [12] PRINTER / SPOOLER CENTER             │%ESC%[0m
echo  %ESC%[96m│ [13] REMOTE ACCESS / RDP TOOLS            │%ESC%[0m   %ESC%[92m│ [14] BIOS / UEFI / BOOT TOOLS             │%ESC%[0m   %ESC%[95m│ [15] REGISTRY / GROUP POLICY              │%ESC%[0m
echo  %ESC%[96m│ [16] WINDOWS SERVICES ^& FEATURES         │%ESC%[0m   %ESC%[92m│ [17] LIVE SYSTEM MONITOR                  │%ESC%[0m   %ESC%[95m│ [18] EVENT VIEWER ^& LOG ANALYZER         │%ESC%[0m
echo  %ESC%[96m│ [19] QUICK ACCESS UTILITIES               │%ESC%[0m   %ESC%[92m│ [20] POWER USER / DEV TOOLS               │%ESC%[0m   %ESC%[95m│ [21] AI SMART AUTO FIX ENGINE             │%ESC%[0m
echo  %ESC%[96m│ [22] AUTO PERFORMANCE BOOSTER             │%ESC%[0m   %ESC%[92m│ [23] AUTO NETWORK REPAIR ENGINE           │%ESC%[0m   %ESC%[95m│ [24] CLOUD ^& REMOTE MANAGEMENT           │%ESC%[0m
echo  %ESC%[96m│ [25] DOWNLOAD ^& DEPLOYMENT CENTER        │%ESC%[0m   %ESC%[92m│ [26] CYBER SECURITY TOOLKIT               │%ESC%[0m   %ESC%[95m│ [27] MASS SOFTWARE INSTALLER              │%ESC%[0m
echo  %ESC%[96m│ [28] HACKER STYLE LIVE DASHBOARD          │%ESC%[0m   %ESC%[92m│ [29] TOOLKIT SETTINGS ^& THEMES           │%ESC%[0m   %ESC%[95m│ [30] ABOUT TOOLKIT                        │%ESC%[0m

echo  %ESC%[94m└────────────────────────────────────────────┘%ESC%[0m   %ESC%[92m└────────────────────────────────────────────┘%ESC%[0m   %ESC%[95m└────────────────────────────────────────────┘%ESC%[0m

echo.
echo  %ESC%[96m════════════════════════════════════════════════════════ SMART CENTERS ═══════════════════════════════════════════════════════%ESC%[0m
echo.

echo  %ESC%[93m┌────────────────────────────────────────────┐%ESC%[0m   %ESC%[95m┌────────────────────────────────────────────┐%ESC%[0m   %ESC%[91m┌────────────────────────────────────────────┐%ESC%[0m
echo  %ESC%[93m│ [S] SMART SEARCH MENU                    │%ESC%[0m   %ESC%[95m│ [31] SMART SEARCH CENTER                  │%ESC%[0m   %ESC%[91m│ [32] ALL-IN-ONE PROBLEM SOLVER            │%ESC%[0m
echo  %ESC%[93m│ [33] SMART DRIVER AUTO CENTER            │%ESC%[0m   %ESC%[95m│ [34] 10000+ CMD VAULT / GLOBAL SEARCH     │%ESC%[0m   %ESC%[91m│ [P] PROBLEM HUB / GUIDED FIXES            │%ESC%[0m
echo  %ESC%[96m│ [35] MISSING 20000+ COMMAND MEGA VAULT   │%ESC%[0m   %ESC%[92m│ [36] PORTABLE TOOLS MENU                  │%ESC%[0m   %ESC%[91m│ [37] 100 APPS 1-CLICK INSTALL             │%ESC%[0m
echo  %ESC%[96m [M] QUICK OPEN MISSING VAULT               [T] PORTABLE TOOLS MENU                        DUPLICATES REMOVED%ESC%[0m
echo  %ESC%[93m└────────────────────────────────────────────┘%ESC%[0m   %ESC%[95m└────────────────────────────────────────────┘%ESC%[0m   %ESC%[91m└────────────────────────────────────────────┘%ESC%[0m

echo.
echo  %ESC%[96m════════════════════════════════════════════════════════ STATUS CENTER ════════════════════════════════════════════════════════%ESC%[0m
echo.

echo  %ESC%[96mTOOLKIT : READY%ESC%[0m       %ESC%[92mMODE : ADMINISTRATOR%ESC%[0m       %ESC%[95mPC : %COMPUTERNAME%%ESC%[0m       %ESC%[93mUSER : %USERNAME%%ESC%[0m
echo  %ESC%[97mLOGS    : %LOGROOT%%ESC%[0m

echo.
echo  %ESC%[96m[R] REFRESH%ESC%[0m     %ESC%[93m[C] COLOR THEME%ESC%[0m     %ESC%[92m[L] LOG CENTER%ESC%[0m     %ESC%[95m[G] PREMIUM GUI%ESC%[0m     %ESC%[95m[W] WEB DASHBOARD%ESC%[0m     %ESC%[91m[X] EXIT%ESC%[0m     %ESC%[95mVERSION %TOOLKIT_VERSION%%ESC%[0m
echo.


echo  SELECT MODULE [01-37 / S / P / M / T / G / W] :
echo %C_CYAN%SELECT MODULE / 99 MAIN:%C_RESET%
set "choice=" & set /p choice=  ^> 


if /i "%choice%"=="R" goto main
if /i "%choice%"=="C" goto change_color_theme
if /i "%choice%"=="L" goto open_log_center
if /i "%choice%"=="G" goto launch_gui
if /i "%choice%"=="W" goto launch_web_dashboard
if /i "%choice%"=="S" goto menu_search
if /i "%choice%"=="P" goto problem_master_hub
if /i "%choice%"=="M" goto missing_mega_vault_launcher
if /i "%choice%"=="T" goto portable_tools_menu
if /i "%choice%"=="X" goto exitprog_inline
if "%choice%"=="01" goto menu_system_admin
if "%choice%"=="1" goto menu_system_admin
if "%choice%"=="02" goto menu_network_internet
if "%choice%"=="2" goto menu_network_internet
if "%choice%"=="03" goto menu_windows_repair
if "%choice%"=="3" goto menu_windows_repair
if "%choice%"=="04" goto menu_security_defender
if "%choice%"=="4" goto menu_security_defender
if "%choice%"=="05" goto menu_performance_optimization
if "%choice%"=="5" goto menu_performance_optimization
if "%choice%"=="06" goto menu_storage_disk
if "%choice%"=="6" goto menu_storage_disk
if "%choice%"=="07" goto menu_user_account
if "%choice%"=="7" goto menu_user_account
if "%choice%"=="08" goto menu_backup_restore
if "%choice%"=="8" goto menu_backup_restore
if "%choice%"=="09" goto menu_driver_hardware
if "%choice%"=="9" goto menu_driver_hardware
if "%choice%"=="10" goto menu_update_activation
if "%choice%"=="11" goto menu_office_outlook
if "%choice%"=="12" goto menu_printer_spooler
if "%choice%"=="13" goto menu_remote_rdp
if "%choice%"=="14" goto menu_bios_boot
if "%choice%"=="15" goto menu_registry_policy
if "%choice%"=="16" goto menu_services_features
if "%choice%"=="17" goto menu_live_monitor
if "%choice%"=="18" goto menu_event_logs
if "%choice%"=="19" goto menu_quick_access
if "%choice%"=="20" goto menu_power_user_dev
if "%choice%"=="21" goto menu_ai_auto_fix
if "%choice%"=="22" goto menu_auto_performance
if "%choice%"=="23" goto menu_auto_network
if "%choice%"=="24" goto menu_cloud_remote
if "%choice%"=="25" goto menu_download_deploy
if "%choice%"=="26" goto menu_cyber_security
if "%choice%"=="27" goto menu_mass_installer
if "%choice%"=="28" goto menu_hacker_dashboard
if "%choice%"=="29" goto menu_settings_themes
if "%choice%"=="30" goto menu_about_toolkit
if "%choice%"=="31" goto menu_search
if "%choice%"=="32" goto problem_master_hub
if "%choice%"=="33" goto driver_auto_center
if "%choice%"=="34" goto cmd_vault
if "%choice%"=="35" goto missing_mega_vault_launcher
if "%choice%"=="36" goto portable_tools_menu
if "%choice%"=="37" goto menu_1click_100_apps
if "%choice%"=="99" goto main
goto main

:launch_gui
cls
echo.
echo  =============================================================
echo  Launching Ultimate Toolkit Premium GUI Command Center v5...
echo  =============================================================
echo.
start "" wscript.exe "%~dp0Toolkit-GUI.vbs"
exit

:launch_web_dashboard
cls
echo.
echo  =============================================================
echo  Launching Ultimate Toolkit Web Command Center Dashboard...
echo  =============================================================
echo.
start "" "%~dp0Launch-WebDashboard.cmd"
goto main

:portable_tools_menu
set "BACK_MENU=main"
if exist "%MODULES_DIR%\PortableToolsMenu.cmd" (
    call "%MODULES_DIR%\PortableToolsMenu.cmd"
) else (
    echo Portable tools module missing: %MODULES_DIR%\PortableToolsMenu.cmd
    pause
)
goto main

:exitprog_inline
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo                         Thank you for using ULTIMATE X PRO MAX %TOOLKIT_VERSION%
echo                                  By Ultimate Toolkit
echo.
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
timeout /t 3 /nobreak >nul 2>&1
exit /b 0

:: ============================================================
:: ULTRA MAIN MODULE SUBMENUS (01-30)
:: ============================================================
:ultra_menu_note
echo.
echo %C_GREEN%  [00] MAIN MENU     [99] BACK / EXIT CURRENT MODULE%C_RESET%
goto :eof

:: ============================================================
:: SMART SEARCH MENU + SAFE BACK HELPER
:: ============================================================
:go_back
if not defined BACK_MENU goto main
call :safe_label_exists "!BACK_MENU!"
if errorlevel 1 (
    echo Invalid back target detected: !BACK_MENU!
    echo Returning to main menu safely.
    timeout /t 2 /nobreak >nul 2>&1
    set "BACK_MENU=main"
    goto main
)
goto !BACK_MENU!

:safe_goto
if not defined SAFE_TARGET goto main
set "SAFE_DEST=!SAFE_TARGET!"
call :safe_label_exists "!SAFE_DEST!"
if errorlevel 1 (
    echo Invalid menu target detected: !SAFE_DEST!
    echo Returning to main menu safely.
    timeout /t 2 /nobreak >nul 2>&1
    set "SAFE_TARGET="
    set "SAFE_DEST="
    goto main
)
set "SAFE_TARGET="
goto !SAFE_DEST!

:safe_label_exists
set "SAFE_LABEL=%~1"
if not defined SAFE_LABEL exit /b 1
echo(!SAFE_LABEL!| findstr /r /c:"^[A-Za-z0-9_][A-Za-z0-9_]*$" >nul 2>&1
if errorlevel 1 exit /b 1
findstr /i /c:":!SAFE_LABEL!" "%~f0" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0
goto main

:: ============================================================
:: SMART BACKUP / RESTORE HELPERS - DRIVE PICKER + AUTO FOLDERS
:: ============================================================
:make_timestamp
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
exit /b

:pick_target_drive
set "PICKED_DRIVE="
echo.
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  AVAILABLE DRIVES
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_LogicalDisk | Where-Object {$_.DriveType -in 2,3} | Sort-Object DeviceID | ForEach-Object { $size=if($_.Size){[math]::Round($_.Size/1GB,1)}else{0}; $free=if($_.FreeSpace){[math]::Round($_.FreeSpace/1GB,1)}else{0}; Write-Host ('  ' + $_.DeviceID + '  Free ' + $free + ' GB / Size ' + $size + ' GB  ' + $_.VolumeName) }"
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
set /p PICKED_DRIVE=Type drive letter for backup/restore, or 99 to cancel: 
if /i "%PICKED_DRIVE%"=="99" exit /b 1
if "%PICKED_DRIVE%"=="" exit /b 1
set "PICKED_DRIVE=%PICKED_DRIVE::=%"
set "PICKED_DRIVE=%PICKED_DRIVE:~0,1%:"
if not exist "%PICKED_DRIVE%\" (
    echo Invalid drive selected: %PICKED_DRIVE%
    pause
    exit /b 1
)
exit /b 0

:open_backup_root
call :pick_target_drive
if errorlevel 1 goto go_back
set "BACKUP_ROOT=%PICKED_DRIVE%\IT_Toolkit_Backups"
if not exist "%BACKUP_ROOT%" mkdir "%BACKUP_ROOT%" >nul 2>&1
explorer "%BACKUP_ROOT%"
goto go_back

:file_backup_to_drive
if not defined FILE_BACKUP_RETURN set "FILE_BACKUP_RETURN=file_backup"
if not defined FILE_BACKUP_SOURCE (set "SAFE_TARGET=!FILE_BACKUP_RETURN!" & goto safe_goto)
if not exist "!FILE_BACKUP_SOURCE!" (
    echo Source folder not found: !FILE_BACKUP_SOURCE!
    pause
    set "SAFE_TARGET=!FILE_BACKUP_RETURN!"
    goto safe_goto
)
call :pick_target_drive
if errorlevel 1 (set "SAFE_TARGET=!FILE_BACKUP_RETURN!" & goto safe_goto)
call :make_timestamp
set "FILE_BACKUP_ROOT=!PICKED_DRIVE!\IT_Toolkit_Backups\Files"
if not exist "!FILE_BACKUP_ROOT!" mkdir "!FILE_BACKUP_ROOT!" >nul 2>&1
set "FILE_BACKUP_DEST=!FILE_BACKUP_ROOT!\!FILE_BACKUP_NAME!_%COMPUTERNAME%_%stamp%"
mkdir "!FILE_BACKUP_DEST!" >nul 2>&1
echo Backing up:
echo   From: !FILE_BACKUP_SOURCE!
echo   To  : !FILE_BACKUP_DEST!
robocopy "!FILE_BACKUP_SOURCE!" "!FILE_BACKUP_DEST!" /E /XJ /R:1 /W:1 /COPY:DAT /DCOPY:DAT /LOG:"!FILE_BACKUP_DEST!\backup_log.txt"
set "ROBO_RC=!errorlevel!"
if !ROBO_RC! LEQ 7 (echo Backup completed. Robocopy code !ROBO_RC!.) else (echo Backup completed with warning/error code !ROBO_RC!.)
echo Log: !FILE_BACKUP_DEST!\backup_log.txt
pause
set "SAFE_TARGET=!FILE_BACKUP_RETURN!"
goto safe_goto

:file_restore_from_drive
if not defined FILE_RESTORE_RETURN set "FILE_RESTORE_RETURN=file_backup"
call :pick_target_drive
if errorlevel 1 (set "SAFE_TARGET=!FILE_RESTORE_RETURN!" & goto safe_goto)
set "FILE_BACKUP_ROOT=!PICKED_DRIVE!\IT_Toolkit_Backups\Files"
if not exist "!FILE_BACKUP_ROOT!" mkdir "!FILE_BACKUP_ROOT!" >nul 2>&1
set "BACKUP_LIST=%TEMP%\it_toolkit_file_backups_%RANDOM%.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root=$env:FILE_BACKUP_ROOT; if(Test-Path -LiteralPath $root){Get-ChildItem -LiteralPath $root -Directory | Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName | Set-Content -LiteralPath $env:BACKUP_LIST -Encoding ASCII} else {New-Item -ItemType File -Path $env:BACKUP_LIST -Force | Out-Null}"
echo.
echo Available file backup folders on !PICKED_DRIVE!:
powershell -NoProfile -ExecutionPolicy Bypass -Command "$list=Get-Content -LiteralPath $env:BACKUP_LIST -ErrorAction SilentlyContinue; if(!$list){Write-Host '  No backup folders found. Root was created:' $env:FILE_BACKUP_ROOT}else{$i=0; $list | ForEach-Object {$i++; Write-Host ('  ['+$i+'] '+(Split-Path $_ -Leaf))}}"
echo.
set "FILE_RESTORE_SEL=" & set /p FILE_RESTORE_SEL=Select number, folder name, full path, or 99 to cancel: 
if /i "!FILE_RESTORE_SEL!"=="99" (set "SAFE_TARGET=!FILE_RESTORE_RETURN!" & goto safe_goto)
if "!FILE_RESTORE_SEL!"=="" (set "SAFE_TARGET=!FILE_RESTORE_RETURN!" & goto safe_goto)
set "restore_src="
for /f "usebackq delims=" %%D in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$list=Get-Content -LiteralPath $env:BACKUP_LIST -ErrorAction SilentlyContinue; $sel=$env:FILE_RESTORE_SEL; if($sel -match '^[0-9]+$'){ $n=[int]$sel-1; if($n -ge 0 -and $n -lt $list.Count){$list[$n]}} elseif([IO.Path]::IsPathRooted($sel)){ $sel } else { Join-Path $env:FILE_BACKUP_ROOT $sel }"`) do set "restore_src=%%D"
if not exist "!restore_src!" (
    echo Backup folder not found: !restore_src!
    pause
    set "SAFE_TARGET=!FILE_RESTORE_RETURN!"
    goto safe_goto
)
set "restore_dest=" & set /p restore_dest=Destination folder blank = Desktop\Restored_From_Toolkit: 
if "!restore_dest!"=="" set "restore_dest=%USERPROFILE%\Desktop\Restored_From_Toolkit"
if not exist "!restore_dest!" mkdir "!restore_dest!" >nul 2>&1
echo Restoring:
echo   From: !restore_src!
echo   To  : !restore_dest!
robocopy "!restore_src!" "!restore_dest!" /E /XJ /R:1 /W:1 /COPY:DAT /DCOPY:DAT
pause
set "SAFE_TARGET=!FILE_RESTORE_RETURN!"
goto safe_goto

:driver_backup_to_drive
if not defined DRIVER_BACKUP_RETURN set "DRIVER_BACKUP_RETURN=driver_backup"
call :pick_target_drive
if errorlevel 1 (set "SAFE_TARGET=!DRIVER_BACKUP_RETURN!" & goto safe_goto)
call :make_timestamp
set "DRIVER_BACKUP_ROOT=!PICKED_DRIVE!\IT_Toolkit_Backups\Drivers"
if not exist "!DRIVER_BACKUP_ROOT!" mkdir "!DRIVER_BACKUP_ROOT!" >nul 2>&1
set "driver_dest=!DRIVER_BACKUP_ROOT!\Driver_Backup_%COMPUTERNAME%_%stamp%"
mkdir "!driver_dest!" >nul 2>&1
echo Exporting all third-party drivers to:
echo !driver_dest!
pnputil /export-driver * "!driver_dest!"
echo Driver backup finished.
pause
set "SAFE_TARGET=!DRIVER_BACKUP_RETURN!"
goto safe_goto

:driver_restore_from_drive
if not defined DRIVER_RESTORE_RETURN set "DRIVER_RESTORE_RETURN=driver_backup"
call :pick_target_drive
if errorlevel 1 (set "SAFE_TARGET=!DRIVER_RESTORE_RETURN!" & goto safe_goto)
set "DRIVER_BACKUP_ROOT=!PICKED_DRIVE!\IT_Toolkit_Backups\Drivers"
if not exist "!DRIVER_BACKUP_ROOT!" mkdir "!DRIVER_BACKUP_ROOT!" >nul 2>&1
set "BACKUP_LIST=%TEMP%\it_toolkit_driver_backups_%RANDOM%.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root=$env:DRIVER_BACKUP_ROOT; if(Test-Path -LiteralPath $root){Get-ChildItem -LiteralPath $root -Directory | Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName | Set-Content -LiteralPath $env:BACKUP_LIST -Encoding ASCII} else {New-Item -ItemType File -Path $env:BACKUP_LIST -Force | Out-Null}"
echo.
echo Available driver backup folders on !PICKED_DRIVE!:
powershell -NoProfile -ExecutionPolicy Bypass -Command "$list=Get-Content -LiteralPath $env:BACKUP_LIST -ErrorAction SilentlyContinue; if(!$list){Write-Host '  No driver backups found. Root was created:' $env:DRIVER_BACKUP_ROOT}else{$i=0; $list | ForEach-Object {$i++; Write-Host ('  ['+$i+'] '+(Split-Path $_ -Leaf))}}"
echo.
set "DRIVER_RESTORE_SEL=" & set /p DRIVER_RESTORE_SEL=Select number, folder name, full path, or 99 to cancel: 
if /i "!DRIVER_RESTORE_SEL!"=="99" (set "SAFE_TARGET=!DRIVER_RESTORE_RETURN!" & goto safe_goto)
if "!DRIVER_RESTORE_SEL!"=="" (set "SAFE_TARGET=!DRIVER_RESTORE_RETURN!" & goto safe_goto)
set "driver_backup_path="
for /f "usebackq delims=" %%D in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$list=Get-Content -LiteralPath $env:BACKUP_LIST -ErrorAction SilentlyContinue; $sel=$env:DRIVER_RESTORE_SEL; if($sel -match '^[0-9]+$'){ $n=[int]$sel-1; if($n -ge 0 -and $n -lt $list.Count){$list[$n]}} elseif([IO.Path]::IsPathRooted($sel)){ $sel } else { Join-Path $env:DRIVER_BACKUP_ROOT $sel }"`) do set "driver_backup_path=%%D"
if not exist "!driver_backup_path!" (
    echo Driver backup folder not found: !driver_backup_path!
    pause
    set "SAFE_TARGET=!DRIVER_RESTORE_RETURN!"
    goto safe_goto
)
echo Installing matching drivers from:
echo !driver_backup_path!
pnputil /add-driver "!driver_backup_path!\*.inf" /subdirs /install
pause
set "SAFE_TARGET=!DRIVER_RESTORE_RETURN!"
goto safe_goto

:driver_open_backup_root
call :pick_target_drive
if errorlevel 1 goto driver_backup_restore_pro
set "DRIVER_BACKUP_ROOT=!PICKED_DRIVE!\IT_Toolkit_Backups\Drivers"
if not exist "!DRIVER_BACKUP_ROOT!" mkdir "!DRIVER_BACKUP_ROOT!" >nul 2>&1
explorer "!DRIVER_BACKUP_ROOT!"
goto driver_backup_restore_pro

:registry_backup_to_drive
if not defined REG_BACKUP_MODE set "REG_BACKUP_MODE=FULL"
if not defined REG_BACKUP_RETURN set "REG_BACKUP_RETURN=reg_backup"
call :pick_target_drive
if errorlevel 1 (set "SAFE_TARGET=!REG_BACKUP_RETURN!" & goto safe_goto)
call :make_timestamp
set "REG_BACKUP_ROOT=!PICKED_DRIVE!\IT_Toolkit_Backups\Registry\Registry_Backup_%COMPUTERNAME%_%stamp%"
if not exist "!REG_BACKUP_ROOT!" mkdir "!REG_BACKUP_ROOT!" >nul 2>&1
if /i "!REG_BACKUP_MODE!"=="HKCU" reg export HKCU "!REG_BACKUP_ROOT!\HKCU.reg" /y
if /i "!REG_BACKUP_MODE!"=="HKLM" reg export HKLM "!REG_BACKUP_ROOT!\HKLM.reg" /y
if /i "!REG_BACKUP_MODE!"=="HKCR" reg export HKCR "!REG_BACKUP_ROOT!\HKCR.reg" /y
if /i "!REG_BACKUP_MODE!"=="FULL" (
    reg export HKCU "!REG_BACKUP_ROOT!\HKCU.reg" /y
    reg export HKLM "!REG_BACKUP_ROOT!\HKLM.reg" /y
    reg export HKCR "!REG_BACKUP_ROOT!\HKCR.reg" /y
)
echo Registry backup saved to:
echo !REG_BACKUP_ROOT!
pause
set "SAFE_TARGET=!REG_BACKUP_RETURN!"
goto safe_goto

:registry_restore_from_drive
if not defined REG_RESTORE_RETURN set "REG_RESTORE_RETURN=reg_backup"
call :pick_target_drive
if errorlevel 1 (set "SAFE_TARGET=!REG_RESTORE_RETURN!" & goto safe_goto)
set "REG_BACKUP_ROOT=!PICKED_DRIVE!\IT_Toolkit_Backups\Registry"
if not exist "!REG_BACKUP_ROOT!" mkdir "!REG_BACKUP_ROOT!" >nul 2>&1
set "BACKUP_LIST=%TEMP%\it_toolkit_reg_backups_%RANDOM%.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root=$env:REG_BACKUP_ROOT; if(Test-Path -LiteralPath $root){Get-ChildItem -LiteralPath $root -Filter *.reg -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName | Set-Content -LiteralPath $env:BACKUP_LIST -Encoding ASCII} else {New-Item -ItemType File -Path $env:BACKUP_LIST -Force | Out-Null}"
echo.
echo Available registry .reg files on !PICKED_DRIVE!:
powershell -NoProfile -ExecutionPolicy Bypass -Command "$list=Get-Content -LiteralPath $env:BACKUP_LIST -ErrorAction SilentlyContinue; if(!$list){Write-Host '  No .reg backups found. Root was created:' $env:REG_BACKUP_ROOT}else{$i=0; $list | ForEach-Object {$i++; Write-Host ('  ['+$i+'] '+$_)}}"
echo.
set "REG_RESTORE_SEL=" & set /p REG_RESTORE_SEL=Select number, .reg path, or 99 to cancel: 
if /i "!REG_RESTORE_SEL!"=="99" (set "SAFE_TARGET=!REG_RESTORE_RETURN!" & goto safe_goto)
if "!REG_RESTORE_SEL!"=="" (set "SAFE_TARGET=!REG_RESTORE_RETURN!" & goto safe_goto)
set "reg_restore_file="
for /f "usebackq delims=" %%D in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$list=Get-Content -LiteralPath $env:BACKUP_LIST -ErrorAction SilentlyContinue; $sel=$env:REG_RESTORE_SEL; if($sel -match '^[0-9]+$'){ $n=[int]$sel-1; if($n -ge 0 -and $n -lt $list.Count){$list[$n]}} else { $sel }"`) do set "reg_restore_file=%%D"
if not exist "!reg_restore_file!" (
    echo Registry file not found: !reg_restore_file!
    pause
    set "SAFE_TARGET=!REG_RESTORE_RETURN!"
    goto safe_goto
)
echo Importing registry file:
echo !reg_restore_file!
regedit /s "!reg_restore_file!"
echo Registry import command finished.
pause
set "SAFE_TARGET=!REG_RESTORE_RETURN!"
goto safe_goto

:system_image_backup_to_drive
if not defined SYS_BACKUP_RETURN set "SYS_BACKUP_RETURN=system_backup"
call :pick_target_drive
if errorlevel 1 (set "SAFE_TARGET=!SYS_BACKUP_RETURN!" & goto safe_goto)
echo Starting Windows image backup to !PICKED_DRIVE! . This can take a long time.
echo Command: wbadmin start backup -backupTarget:!PICKED_DRIVE! -include:C: -allCritical -quiet
wbadmin start backup -backupTarget:!PICKED_DRIVE! -include:C: -allCritical -quiet
pause
set "SAFE_TARGET=!SYS_BACKUP_RETURN!"
goto safe_goto

:: ============================================================
:: SHARED SAFE HELPERS - MODERN CIM + WINGET
:: ============================================================
:ps_disk_drives
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_DiskDrive | Select-Object Model,Status,@{Name='SizeGB';Expression={[math]::Round($_.Size/1GB,2)}},MediaType | Format-Table -AutoSize"
exit /b

:ps_logical_disks
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,VolumeName,Description,@{Name='FreeGB';Expression={[math]::Round($_.FreeSpace/1GB,2)}},@{Name='SizeGB';Expression={[math]::Round($_.Size/1GB,2)}} | Format-Table -AutoSize"
exit /b

:ps_cpu_info
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Processor | Select-Object Name,MaxClockSpeed,NumberOfCores,NumberOfLogicalProcessors | Format-Table -AutoSize"
exit /b

:ps_gpu_info
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_VideoController | Select-Object Caption,DriverVersion,@{Name='AdapterRAMGB';Expression={[math]::Round($_.AdapterRAM/1GB,2)}} | Format-Table -AutoSize"
exit /b

:ps_gpu_refresh
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_VideoController | Select-Object Caption,CurrentRefreshRate,MaxRefreshRate | Format-Table -AutoSize"
exit /b

:ps_bios_info
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_BIOS | Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate | Format-List"
exit /b

:ps_qfe_list
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_QuickFixEngineering | Select-Object HotFixID,Description,InstalledOn | Sort-Object InstalledOn -Descending | Format-Table -AutoSize"
exit /b

:ps_vcredist_list
powershell -NoProfile -ExecutionPolicy Bypass -Command "$paths='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'; Get-ItemProperty $paths -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -like '*Visual C++*'} | Select-Object DisplayName,DisplayVersion,Publisher | Sort-Object DisplayName | Format-Table -AutoSize"
exit /b

:ps_installed_apps
powershell -NoProfile -ExecutionPolicy Bypass -Command "$paths='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'; Get-ItemProperty $paths -ErrorAction SilentlyContinue | Where-Object DisplayName | Select-Object DisplayName,DisplayVersion,Publisher | Sort-Object DisplayName | Format-Table -AutoSize"
exit /b

:ps_oem_key
powershell -NoProfile -ExecutionPolicy Bypass -Command "$key=(Get-CimInstance -Query 'SELECT OA3xOriginalProductKey FROM SoftwareLicensingService').OA3xOriginalProductKey; if([string]::IsNullOrWhiteSpace($key)){Write-Host 'No embedded OEM product key found.'} else {Write-Host $key}"
exit /b

:ps_printers
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Printer | Select-Object Name,Default,WorkOffline,PortName | Format-Table -AutoSize"
exit /b

:ps_auto_pagefile
powershell -NoProfile -ExecutionPolicy Bypass -Command "$cs=Get-CimInstance Win32_ComputerSystem; Set-CimInstance -InputObject $cs -Property @{AutomaticManagedPagefile=$true}; Write-Host 'Page File Reset to Auto.'"
exit /b

:open_outlook_safe
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath 'outlook.exe' -ArgumentList '/safe' -ErrorAction Stop; Write-Host 'Outlook safe mode launched.' } catch { Write-Host 'Outlook.exe was not found. Install or repair Microsoft Outlook/Office, then try again.'; Start-Process 'ms-settings:appsfeatures' }"
exit /b

:open_outlook_profiles
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath 'outlook.exe' -ArgumentList '/manageprofiles' -ErrorAction Stop; Write-Host 'Outlook profile manager launched.' } catch { Write-Host 'Outlook.exe was not found. Opening Mail profile control panel if available.'; try { Start-Process 'control.exe' -ArgumentList 'mlcfg32.cpl' -ErrorAction Stop } catch { Start-Process 'ms-settings:appsfeatures' } }"
exit /b

:open_outlook_reset_navpane
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath 'outlook.exe' -ArgumentList '/resetnavpane' -ErrorAction Stop; Write-Host 'Outlook reset navigation pane command launched.' } catch { Write-Host 'Outlook.exe was not found. Install or repair Microsoft Outlook/Office, then try again.'; Start-Process 'ms-settings:appsfeatures' }"
exit /b

:open_scanpst
powershell -NoProfile -ExecutionPolicy Bypass -Command "$roots=@($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }; $candidates=@(); foreach($r in $roots){ $candidates += Get-ChildItem -LiteralPath $r -Filter SCANPST.EXE -Recurse -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName }; $scanpst=$candidates | Select-Object -First 1; if($scanpst){ Write-Host ('Opening Outlook Inbox Repair Tool: ' + $scanpst); Start-Process -FilePath $scanpst } else { Write-Host 'SCANPST.EXE was not found. Opening Office repair page.'; Start-Process 'appwiz.cpl' }"
exit /b

:office_activation_status
powershell -NoProfile -ExecutionPolicy Bypass -Command "$roots=@($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }; $scripts=@(); foreach($r in $roots){ $scripts += Get-ChildItem -LiteralPath $r -Filter OSPP.VBS -Recurse -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName }; $ospp=$scripts | Select-Object -First 1; if($ospp){ cscript.exe //nologo $ospp /dstatus } else { Write-Host 'OSPP.VBS was not found. Microsoft Office may not be installed or uses a different activation channel.' }"
exit /b

:open_hyperv_manager
if exist "%SystemRoot%\System32\virtmgmt.msc" (
    start "" virtmgmt.msc
) else (
    echo Hyper-V Manager is not installed on this Windows installation.
    echo Opening Windows Optional Features so Hyper-V tools can be enabled.
    start "" optionalfeatures.exe
)
exit /b

:run_bootrec
set "BOOTREC_EXE="
where bootrec.exe >nul 2>&1
if not errorlevel 1 set "BOOTREC_EXE=bootrec.exe"
if not defined BOOTREC_EXE if exist "%SystemRoot%\System32\bootrec.exe" set "BOOTREC_EXE=%SystemRoot%\System32\bootrec.exe"
if not defined BOOTREC_EXE (
    echo bootrec.exe is not available in this running Windows session.
    echo Bootrec commands are normally available from Windows Recovery Environment / WinPE.
    echo Opening Recovery settings. Use Advanced startup, then run this from recovery CMD.
    start "" ms-settings:recovery
    exit /b 1
)
"%BOOTREC_EXE%" %*
exit /b %errorlevel%

:winget_require
where winget >nul 2>&1
if errorlevel 1 (
    echo Winget/App Installer not found. Opening Microsoft Store App Installer page...
    start "" "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
    exit /b 1
)
exit /b 0

:winget_install_id
set "WINGET_ID=%~1"
if "%WINGET_ID%"=="" exit /b 1
call :winget_require
if errorlevel 1 exit /b 1
echo.
echo Installing %WINGET_ID% ...
winget install --id "%WINGET_ID%" --source winget -e --accept-package-agreements --accept-source-agreements
set "WINGET_RC=%errorlevel%"
if not "%WINGET_RC%"=="0" (
    echo Install failed or package unavailable: %WINGET_ID%
)
exit /b %WINGET_RC%

:winget_install_store
set "WINGET_ID=%~1"
if "%WINGET_ID%"=="" exit /b 1
call :winget_require
if errorlevel 1 exit /b 1
echo.
echo Installing Microsoft Store package %WINGET_ID% ...
winget install --id "%WINGET_ID%" --source msstore --accept-package-agreements --accept-source-agreements
set "WINGET_RC=%errorlevel%"
if not "%WINGET_RC%"=="0" (
    echo Store install failed or package unavailable: %WINGET_ID%
)
exit /b %WINGET_RC%

:winget_install_pack
call :winget_require
if errorlevel 1 exit /b 1
:winget_install_pack_loop
if "%~1"=="" exit /b 0
call :winget_install_id "%~1"
shift
goto winget_install_pack_loop

:winget_upgrade_all
call :winget_require
if errorlevel 1 exit /b 1
winget upgrade --all --source winget --accept-package-agreements --accept-source-agreements
exit /b %errorlevel%

:winget_list_installed
call :winget_require
if errorlevel 1 exit /b 1
winget list --accept-source-agreements
exit /b %errorlevel%

:winget_health
call :winget_require
if errorlevel 1 exit /b 1
winget --info
echo.
winget source list
echo.
winget source update
exit /b %errorlevel%

:wifi_show_all_passwords
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% SAVED WIFI PROFILES WITH PASSWORDS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$profiles=(netsh wlan show profiles) | Select-String 'All User Profile' | ForEach-Object {($_.ToString() -split ':',2)[1].Trim()}; if(-not $profiles){Write-Host 'No saved WiFi profiles found.'; exit}; foreach($p in $profiles){$detail=netsh wlan show profile name=$p key=clear; $key=($detail | Select-String 'Key Content' | Select-Object -First 1); $auth=($detail | Select-String 'Authentication' | Select-Object -First 1); $cipher=($detail | Select-String 'Cipher' | Select-Object -First 1); $pass=if($key){($key.ToString() -split ':',2)[1].Trim()}else{'<No password saved / open network>'}; $a=if($auth){($auth.ToString() -split ':',2)[1].Trim()}else{''}; $c=if($cipher){($cipher.ToString() -split ':',2)[1].Trim()}else{''}; Write-Host ('WiFi Name : ' + $p) -ForegroundColor Cyan; Write-Host ('Password  : ' + $pass) -ForegroundColor Yellow; if($a){Write-Host ('Security  : ' + $a + ' / ' + $c)}; Write-Host '------------------------------------------------------------------'}"
echo.
exit /b

:wifi_export_password_csv
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "WIFI_CSV=%LOGROOT%\WiFi_Saved_Passwords_%stamp%.csv"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$out='%WIFI_CSV%'; $profiles=(netsh wlan show profiles) | Select-String 'All User Profile' | ForEach-Object {($_.ToString() -split ':',2)[1].Trim()}; $rows=foreach($p in $profiles){$detail=netsh wlan show profile name=$p key=clear; $key=($detail | Select-String 'Key Content' | Select-Object -First 1); $auth=($detail | Select-String 'Authentication' | Select-Object -First 1); [pscustomobject]@{WiFiName=$p;Password=if($key){($key.ToString() -split ':',2)[1].Trim()}else{''};Security=if($auth){($auth.ToString() -split ':',2)[1].Trim()}else{''}}}; $rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $out; Write-Host ('Saved CSV: ' + $out)"
exit /b

:repair_app_installer
powershell -NoProfile -ExecutionPolicy Bypass -Command "$pkg=Get-AppxPackage Microsoft.DesktopAppInstaller -AllUsers; if($pkg){$pkg | ForEach-Object {try {Reset-AppxPackage -Package $_.PackageFullName -ErrorAction Stop} catch {Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $_.InstallLocation 'AppxManifest.xml') -ErrorAction SilentlyContinue}}; Write-Host 'App Installer repair command finished.'} else {Write-Host 'Desktop App Installer package not found. Opening Store page.'; Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'}"
exit /b

:return_from_pack
if defined PACK_RETURN (
    set "PACK_BACK=%PACK_RETURN%"
    set "PACK_RETURN="
    set "SAFE_TARGET=!PACK_BACK!"
    goto safe_goto
)
goto menu_mass_installer

:return_from_category
if defined CATEGORY_RETURN (
    set "CATEGORY_BACK=%CATEGORY_RETURN%"
    set "CATEGORY_RETURN="
    set "SAFE_TARGET=!CATEGORY_BACK!"
    goto safe_goto
)
goto winget_installer

:menu_search
set "BACK_MENU=menu_search"
cls
color 0F
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  [31/S] SMART SEARCH CENTER
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Smart keyword jump to toolkit module      [02] Full toolkit text search                  [03] Search files by name                      %C_RESET%
echo %C_GREEN%  [04] Search running processes                  [05] Search Windows services                   [06] Search installed apps/packages            %C_RESET%
echo %C_GREEN%  [07] Search recent System events               [08] Search active network ports               [09] Windows Search / Indexing tools           %C_RESET%
echo %C_GREEN%  [10] Open Windows Search settings              [11] Global Search Everything                  [12] Search Driver / Hardware IDs              %C_RESET%
echo %C_GREEN%  [13] 10000+ CMD Vault                          [14] Microsoft Problem Library                 [15] Core Windows Tool Check                   %C_RESET%
echo %C_GREEN%  [16] Quick Health Report                       [17] Deep Diagnostics Pack                     [18] Open Log Center                           %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto search_smart_jump
if "%c%"=="1" goto search_smart_jump
if "%c%"=="02" goto search_toolkit_text
if "%c%"=="2" goto search_toolkit_text
if "%c%"=="03" goto search_files
if "%c%"=="3" goto search_files
if "%c%"=="04" goto search_processes
if "%c%"=="4" goto search_processes
if "%c%"=="05" goto search_services
if "%c%"=="5" goto search_services
if "%c%"=="06" goto search_installed_apps
if "%c%"=="6" goto search_installed_apps
if "%c%"=="07" goto search_events
if "%c%"=="7" goto search_events
if "%c%"=="08" goto search_ports
if "%c%"=="8" goto search_ports
if "%c%"=="09" goto win_indexing
if "%c%"=="9" goto win_indexing
if "%c%"=="10" (start "" ms-settings:search & pause & goto menu_search)
if "%c%"=="11" goto search_global
if "%c%"=="12" goto search_driver_hwids
if "%c%"=="13" goto cmd_vault
if "%c%"=="14" goto microsoft_problem_library
if "%c%"=="15" goto check_core_tools
if "%c%"=="16" goto quick_health_report
if "%c%"=="17" goto issue_deep_diagnostics
if "%c%"=="18" goto open_log_center
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_search

:search_smart_jump
cls
color 0F
echo %C_CYAN%============================================================%C_RESET%
echo  SMART KEYWORD JUMP
echo %C_CYAN%============================================================%C_RESET%
echo  Examples: wifi, dns, printer, defender, update, sfc, driver,
echo            outlook, backup, rdp, registry, services, search, problem,
echo            hack, hacking, brute, failed login, ports, bootable, pendrive, iso
echo %C_CYAN%============================================================%C_RESET%
set "q=" & set /p q=Type keyword:
if not defined q goto menu_search
set "SMART_DEST="
for /f "delims=" %%L in ('powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABxAD0AJABlAG4AdgA6AHEACgAkAHIAdQBsAGUAcwAgAD0AIABAACgACgAgACAAQAAoACcAcAByAG8AYgBsAGUAbQBfAG0AYQBzAHQAZQByAF8AaAB1AGIAJwAsACcAKAA/AGkAKQBwAHIAbwBiAGwAZQBtAHwAcAByAG8AYgBsAGUAbQBzAHwAaQBzAHMAdQBlAHwAaQBzAHMAdQBlAHMAfABhAGwAbABpAG4AbwBuAGUAfABhAGwAbAAtAGkAbgAtAG8AbgBlAHwAbQBhAHMAdABlAHIAfABmAGkAeAB8AHIAZQBwAGEAaQByAHwAdAByAG8AdQBiAGwAZQBzAGgAbwBvAHQAfAB0AHIAbwB1AGIAbABlAHMAaABvAG8AdABpAG4AZwAnACkALAAKACAAIABAACgAJwB3AGkAbgBfAGkAbgBkAGUAeABpAG4AZwAnACwAJwAoAD8AaQApAHMAZQBhAHIAYwBoAHwAaQBuAGQAZQB4AHwAaQBuAGQAZQB4AGkAbgBnAHwAYwBvAHIAdABhAG4AYQAnACkALAAKACAAIABAACgAJwBtAGUAbgB1AF8AbgBlAHQAdwBvAHIAawBfAGkAbgB0AGUAcgBuAGUAdAAnACwAJwAoAD8AaQApAG4AZQB0AHcAbwByAGsAfABpAG4AdABlAHIAbgBlAHQAfAB3AGkAZgBpAHwAZABuAHMAfABwAHIAbwB4AHkAfAB2AHAAbgB8AHAAaQBuAGcAfABpAHAAfABhAGQAYQBwAHQAZQByAHwAdABjAHAAfABzAG0AYgB8AHMAaABhAHIAZQB8AG4AYQBzACcAKQAsAAoAIAAgAEAAKAAnAG0AZQBuAHUAXwBwAHIAaQBuAHQAZQByAF8AcwBwAG8AbwBsAGUAcgAnACwAJwAoAD8AaQApAHAAcgBpAG4AdABlAHIAfABzAHAAbwBvAGwAZQByAHwAcAByAGkAbgB0AHwAcwBjAGEAbgBuAGUAcgB8AHEAdQBlAHUAZQAnACkALAAKACAAIABAACgAJwBjAHkAYgBlAHIAXwBwAGMAXwBnAHUAYQByAGQAJwAsACcAKAA/AGkAKQBoAGEAYwBrAHwAaABhAGMAawBpAG4AZwB8AGgAYQBjAGsAZQBkAHwAYgByAHUAdABlAHwAYgByAHUAdABlAGYAbwByAGMAZQB8AGIAcgB1AHQAZQAtAGYAbwByAGMAZQB8AGYAbABvAG8AZAB8AGEAdAB0AGEAYwBrAHwAYgByAGUAYQBjAGgAfABjAG8AbQBwAHIAbwBtAGkAcwBlAHwAcwB1AHMAcABpAGMAaQBvAHUAcwB8AHAAbwByAHQAfABwAG8AcgB0AHMAfABmAGEAaQBsAGUAZAB8AGYAYQBpAGwAZQBkAGwAbwBnAGkAbgB8AGYAYQBpAGwAZQBkAC0AbABvAGcAaQBuAHwAbABvAGcAbwBuAHwANAA2ADIANQB8ADQANgAyADQAJwApACwACgAgACAAQAAoACcAbQBlAG4AdQBfAHMAZQBjAHUAcgBpAHQAeQBfAGQAZQBmAGUAbgBkAGUAcgAnACwAJwAoAD8AaQApAHMAZQBjAHUAcgBpAHQAeQB8AGQAZQBmAGUAbgBkAGUAcgB8AGEAbgB0AGkAdgBpAHIAdQBzAHwAZgBpAHIAZQB3AGEAbABsAHwAYgBpAHQAbABvAGMAawBlAHIAfABtAGEAbAB3AGEAcgBlAHwAcAByAGkAdgBhAGMAeQB8AHUAcwBiAHwAYwB5AGIAZQByACcAKQAsAAoAIAAgAEAAKAAnAG0AZQBuAHUAXwB3AGkAbgBkAG8AdwBzAF8AcgBlAHAAYQBpAHIAJwAsACcAKAA/AGkAKQByAGUAcABhAGkAcgB8AHMAZgBjAHwAZABpAHMAbQB8AGIAbwBvAHQAfABiAGMAZAB8AHIAZQBnAGkAcwB0AHIAeQB8AGQAbABsAHwAZQB4AHAAbABvAHIAZQByAHwAcwB0AG8AcgBlAHwAdAByAG8AdQBiAGwAZQBzAGgAbwBvAHQAfABpAHMAcwB1AGUAfABmAGkAeAAnACkALAAKACAAIABAACgAJwBtAGUAbgB1AF8AcABlAHIAZgBvAHIAbQBhAG4AYwBlAF8AbwBwAHQAaQBtAGkAegBhAHQAaQBvAG4AJwAsACcAKAA/AGkAKQBwAGUAcgBmAG8AcgBtAGEAbgBjAGUAfABzAGwAbwB3AHwAcgBhAG0AfABjAHAAdQB8AGMAbABlAGEAbgB1AHAAfABzAHAAZQBlAGQAfABiAHMAbwBkAHwAbwBwAHQAaQBtAGkAegBlAHwAZABlAGYAcgBhAGcAfABjAGEAYwBoAGUAfABiAG8AbwBzAHQAfABtAGkAbgBpAG0AdQBtAHwAbABvAHcAZQBuAGQAfABsAG8AdwAtAGUAbgBkACcAKQAsAAoAIAAgAEAAKAAnAG0AZQBuAHUAXwBzAHQAbwByAGEAZwBlAF8AZABpAHMAawAnACwAJwAoAD8AaQApAGQAaQBzAGsAfABzAHQAbwByAGEAZwBlAHwAYwBoAGsAZABzAGsAfABwAGEAcgB0AGkAdABpAG8AbgB8AHYAaABkAHwAdgBvAGwAdQBtAGUAfABkAHIAaQB2AGUAJwApACwACgAgACAAQAAoACcAbQBlAG4AdQBfAHUAcwBlAHIAXwBhAGMAYwBvAHUAbgB0ACcALAAnACgAPwBpACkAdQBzAGUAcgB8AGEAYwBjAG8AdQBuAHQAfABwAGEAcwBzAHcAbwByAGQAfABwAHIAbwBmAGkAbABlAHwAYwByAGUAZABlAG4AdABpAGEAbAB8AGwAbwBnAGkAbgB8AGEAZABtAGkAbgAnACkALAAKACAAIABAACgAJwBtAGUAbgB1AF8AYgBhAGMAawB1AHAAXwByAGUAcwB0AG8AcgBlACcALAAnACgAPwBpACkAYgBhAGMAawB1AHAAfAByAGUAcwB0AG8AcgBlAHwAcgBlAGMAbwB2AGUAcgB5AHwAcgBlAHMAdABvAHIAZQBwAG8AaQBuAHQAfABpAG0AYQBnAGUAJwApACwACgAgACAAQAAoACcAYgBvAG8AdABhAGIAbABlAF8AdQBzAGIAXwBjAHIAZQBhAHQAbwByACcALAAnACgAPwBpACkAYgBvAG8AdABhAGIAbABlAHwAcABlAG4AZAByAGkAdgBlAHwAaQBzAG8AfAByAHUAZgB1AHMAfAB2AGUAbgB0AG8AeQB8AHcAaQBuAHAAZQB8AG0AZQBkAGkAYQAgAGMAcgBlAGEAdABpAG8AbgB8AHUAcwBiAGIAbwBvAHQAfABiAG8AbwB0AHUAcwBiAHwAYgBvAG8AdAAtAHUAcwBiACcAKQAsAAoAIAAgAEAAKAAnAGQAcgBpAHYAZQByAF8AYQB1AHQAbwBfAGMAZQBuAHQAZQByACcALAAnACgAPwBpACkAZAByAGkAdgBlAHIAfABkAHIAaQB2AGUAcgBzAHwAaABhAHIAZAB3AGEAcgBlAHwAZABlAHYAaQBjAGUAfABhAHUAZABpAG8AfABkAGkAcwBwAGwAYQB5AHwAYgBsAHUAZQB0AG8AbwB0AGgAfABjAGEAbQBlAHIAYQB8AGcAcAB1AHwAdQBzAGIAfABoAHAAfABkAGUAbABsAHwAbABlAG4AbwB2AG8AfABpAG4AdABlAGwAfABuAHYAaQBkAGkAYQB8AGEAbQBkAHwAcgBlAGEAbAB0AGUAawB8AHEAdQBhAGwAYwBvAG0AbQB8AG0AZQBkAGkAYQB0AGUAawB8AG8AZQBtAHwAcABuAHAAfABwAG4AcAB1AHQAaQBsAHwAaQBuAGYAJwApACwACgAgACAAQAAoACcAbQBlAG4AdQBfAHUAcABkAGEAdABlAF8AYQBjAHQAaQB2AGEAdABpAG8AbgAnACwAJwAoAD8AaQApAHUAcABkAGEAdABlAHwAYQBjAHQAaQB2AGEAdABpAG8AbgB8AGwAaQBjAGUAbgBzAGUAfABrAGUAeQB8AHcAaQBuAGQAbwB3AHMAdQBwAGQAYQB0AGUAfAB3AHMAdQBzACcAKQAsAAoAIAAgAEAAKAAnAG0AZQBuAHUAXwBvAGYAZgBpAGMAZQBfAG8AdQB0AGwAbwBvAGsAJwAsACcAKAA/AGkAKQBvAGYAZgBpAGMAZQB8AG8AdQB0AGwAbwBvAGsAfAB0AGUAYQBtAHMAfAB6AG8AbwBtAHwAbwBuAGUAZAByAGkAdgBlAHwAYwBsAG8AdQBkACcAKQAsAAoAIAAgAEAAKAAnAG0AZQBuAHUAXwByAGUAbQBvAHQAZQBfAHIAZABwACcALAAnACgAPwBpACkAcgBlAG0AbwB0AGUAfAByAGQAcAB8AG0AcwB0AHMAYwB8AHYAcABuAHwAYQBzAHMAaQBzAHQAYQBuAGMAZQAnACkALAAKACAAIABAACgAJwBtAGUAbgB1AF8AYgBpAG8AcwBfAGIAbwBvAHQAJwAsACcAKAA/AGkAKQBiAGkAbwBzAHwAdQBlAGYAaQB8AGIAbwBvAHQAfAB0AHAAbQB8AHMAYQBmAGUAbQBvAGQAZQB8AHMAYQBmAGUAJwApACwACgAgACAAQAAoACcAbQBlAG4AdQBfAHIAZQBnAGkAcwB0AHIAeQBfAHAAbwBsAGkAYwB5ACcALAAnACgAPwBpACkAZwBwAG8AfABwAG8AbABpAGMAeQB8AGcAcABlAGQAaQB0AHwAcgBlAGcAaQBzAHQAcgB5AHwAcgBlAGcAZQBkAGkAdAAnACkALAAKACAAIABAACgAJwBtAGUAbgB1AF8AcwBlAHIAdgBpAGMAZQBzAF8AZgBlAGEAdAB1AHIAZQBzACcALAAnACgAPwBpACkAcwBlAHIAdgBpAGMAZQB8AHMAZQByAHYAaQBjAGUAcwB8AGYAZQBhAHQAdQByAGUAfABvAHAAdABpAG8AbgBhAGwAZgBlAGEAdAB1AHIAZQBzAHwAdwBpAG4AZABvAHcAcwBmAGUAYQB0AHUAcgBlAHMAJwApACwACgAgACAAQAAoACcAbQBlAG4AdQBfAGUAdgBlAG4AdABfAGwAbwBnAHMAJwAsACcAKAA/AGkAKQBlAHYAZQBuAHQAfABsAG8AZwB8AGwAbwBnAHMAfAB2AGkAZQB3AGUAcgB8AGUAdgB0AHgAJwApACwACgAgACAAQAAoACcAbQBlAG4AdQBfAGwAaQB2AGUAXwBtAG8AbgBpAHQAbwByACcALAAnACgAPwBpACkAbQBvAG4AaQB0AG8AcgB8AGgAZQBhAGwAdABoAHwAcgBlAHAAbwByAHQAfABkAGEAcwBoAGIAbwBhAHIAZAB8AGwAaQB2AGUAJwApACwACgAgACAAQAAoACcAbQBlAG4AdQBfAGQAbwB3AG4AbABvAGEAZABfAGQAZQBwAGwAbwB5ACcALAAnACgAPwBpACkAZABvAHcAbgBsAG8AYQBkAHwAZABlAHAAbABvAHkAfABpAG4AcwB0AGEAbABsAHwAaQBuAHMAdABhAGwAbABlAHIAfABtAGEAcwBzAHwAcwBvAGYAdAB3AGEAcgBlAHwAYQBwAHAAfABhAHAAcABzAHwAdwBpAG4AZwBlAHQAfAA1ADAAMAAwAHwAYwBhAHQAYQBsAG8AZwAnACkALAAKACAAIABAACgAJwBtAGUAbgB1AF8AcQB1AGkAYwBrAF8AYQBjAGMAZQBzAHMAJwAsACcAKAA/AGkAKQBxAHUAaQBjAGsAfAB0AG8AbwBsAHwAdABvAG8AbABzAHwAcwBoAG8AcgB0AGMAdQB0AHwAYwBvAG4AdAByAG8AbAAgAHAAYQBuAGUAbAB8AHMAZQB0AHQAaQBuAGcAcwAnACkALAAKACAAIABAACgAJwBtAGUAbgB1AF8AcABvAHcAZQByAF8AdQBzAGUAcgBfAGQAZQB2ACcALAAnACgAPwBpACkAZABlAHYAfABkAGUAdgBlAGwAbwBwAGUAcgB8AHYAcwBjAG8AZABlAHwAZwBpAHQAfABuAG8AZABlAHwAcAB5AHQAaABvAG4AfABoAHkAcABlAHIAfAB3AHMAbAAnACkALAAKACAAIABAACgAJwBtAGUAbgB1AF8AcwBlAHQAdABpAG4AZwBzAF8AdABoAGUAbQBlAHMAJwAsACcAKAA/AGkAKQB0AGgAZQBtAGUAfABjAG8AbABvAHIAfABhAGIAbwB1AHQAfABzAGUAdAB0AGkAbgBnAHwAcwBlAHQAdABpAG4AZwBzACcAKQAsAAoAIAAgAEAAKAAnAGMAbQBkAF8AdgBhAHUAbAB0ACcALAAnACgAPwBpACkAYwBtAGQAfABjAG8AbQBtAGEAbgBkAHwAYwBvAG0AbQBhAG4AZABzAHwAcABvAHcAZQByAHMAaABlAGwAbAB8AHQAZQByAG0AaQBuAGEAbAB8AHYAYQB1AGwAdAB8AHIAdQBuAHwAbABhAHUAbgBjAGgAfABlAHgAZQB8AHMAYwByAGkAcAB0AHwAcwB5AG4AdABhAHgAfAAxADAAMAAwADAAJwApACwACgAgACAAQAAoACcAdwBpAG4AZABvAHcAcwBfAGEAaQBfAGMAbwBuAHQAcgBvAGwAcwAnACwAJwAoAD8AaQApAGEAaQB8AGMAbwBwAGkAbABvAHQAfAByAGUAYwBhAGwAbAB8AHcAaQBuAGQAbwB3AHMAYQBpAHwAdwBpAG4AZABvAHcAcwAtAGEAaQB8AGIAaQBuAGcAfAB3AGUAYgBzAGUAYQByAGMAaAB8AHcAZQBiAC0AcwBlAGEAcgBjAGgAfAB3AGkAZABnAGUAdABzAHwAcwB1AGcAZwBlAHMAdABpAG8AbgBzACcAKQAKACkACgBmAG8AcgBlAGEAYwBoACAAKAAkAHIAIABpAG4AIAAkAHIAdQBsAGUAcwApACAAewAKACAAIABpAGYAIAAoACQAcQAgAC0AbQBhAHQAYwBoACAAJAByAFsAMQBdACkAIAB7ACAAWwBDAG8AbgBzAG8AbABlAF0AOgA6AFcAcgBpAHQAZQBMAGkAbgBlACgAJAByAFsAMABdACkAOwAgAGUAeABpAHQAIAB9AAoAfQA=') do set "SMART_DEST=%%L"
if defined SMART_DEST (
    set "SAFE_TARGET=!SMART_DEST!"
    goto safe_goto
)
echo.
echo No direct module matched. Opening full toolkit text search...
pause
goto search_toolkit_text

:search_toolkit_text
cls
color 0F
echo %C_CYAN%============================================================%C_RESET%
echo  FULL TOOLKIT TEXT SEARCH
echo %C_CYAN%============================================================%C_RESET%
set "kw=" & set /p kw=Keyword:
if not defined kw goto menu_search
set "SEARCH_FILE=%~f0"
echo.
echo Matching lines inside this toolkit:
echo ------------------------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $file=$env:SEARCH_FILE; $rows=Select-String -LiteralPath $file -SimpleMatch $kw -ErrorAction SilentlyContinue | Select-Object -First 220; if($rows){$rows | ForEach-Object { '{0}: {1}' -f $_.LineNumber,$_.Line }} else { Write-Host 'No match found.' }"
echo ------------------------------------------------------------
pause
goto menu_search

:search_files
cls
color 0F
echo %C_CYAN%============================================================%C_RESET%
echo  SEARCH FILES BY NAME
echo %C_CYAN%============================================================%C_RESET%
set "root=" & set /p root=Start folder (blank = C:\):
if not defined root set "root=C:\"
set "name=" & set /p name=File name contains:
if not defined name goto menu_search
echo.
echo Searching. Large folders can take time...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root=$env:root; $name=$env:name; if(-not (Test-Path -LiteralPath $root)){ Write-Host ('Folder not found: ' + $root); exit }; $rx=[regex]::Escape($name); Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $rx } | Select-Object -First 300 -ExpandProperty FullName"
pause
goto menu_search

:search_processes
cls
color 0F
echo %C_CYAN%============================================================%C_RESET%
echo  SEARCH RUNNING PROCESSES
echo %C_CYAN%============================================================%C_RESET%
set "kw=" & set /p kw=Process name or PID:
if not defined kw goto menu_search
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match $rx -or ([string]$_.Id -eq $kw) } | Select-Object -First 100 Id,ProcessName,CPU,WorkingSet | Format-Table -AutoSize"
pause
goto menu_search

:search_services
cls
color 0F
echo %C_CYAN%============================================================%C_RESET%
echo  SEARCH WINDOWS SERVICES
echo %C_CYAN%============================================================%C_RESET%
set "kw=" & set /p kw=Service keyword:
if not defined kw goto menu_search
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Get-CimInstance Win32_Service | Where-Object { ([string]$_.Name) -match $rx -or ([string]$_.DisplayName) -match $rx -or ([string]$_.State) -match $rx } | Select-Object -First 120 Name,DisplayName,State,StartMode | Format-Table -AutoSize"
pause
goto menu_search

:search_installed_apps
cls
color 0F
echo %C_CYAN%============================================================%C_RESET%
echo  SEARCH INSTALLED APPS / PACKAGES
echo %C_CYAN%============================================================%C_RESET%
set "kw=" & set /p kw=App keyword:
if not defined kw goto menu_search
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Write-Host '=== Installed app registry matches ==='; $paths='HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'; Get-ItemProperty $paths -ErrorAction SilentlyContinue | Where-Object { ([string]$_.DisplayName) -match $rx } | Sort-Object DisplayName | Select-Object -First 120 DisplayName,DisplayVersion,Publisher | Format-Table -AutoSize; if(Get-Command winget -ErrorAction SilentlyContinue){ Write-Host ''; Write-Host '=== Winget list matches ==='; & winget list --accept-source-agreements 2>$null | Select-String -SimpleMatch $kw | Select-Object -First 80 }"
pause
goto menu_search

:search_events
cls
color 0F
echo %C_CYAN%============================================================%C_RESET%
echo  SEARCH RECENT SYSTEM EVENTS
echo %C_CYAN%============================================================%C_RESET%
set "kw=" & set /p kw=Event keyword:
if not defined kw goto menu_search
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Get-WinEvent -LogName System -MaxEvents 120 -ErrorAction SilentlyContinue | Where-Object { ([string]$_.ProviderName) -match $rx -or ([string]$_.Message) -match $rx -or ([string]$_.Id) -match $rx } | Select-Object -First 40 TimeCreated,Id,ProviderName,LevelDisplayName,Message | Format-List"
pause
goto menu_search

:search_ports
cls
color 0F
echo %C_CYAN%============================================================%C_RESET%
echo  SEARCH ACTIVE NETWORK PORTS
echo %C_CYAN%============================================================%C_RESET%
set "kw=" & set /p kw=Port, PID, LISTENING, or IP:
if not defined kw goto menu_search
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; netstat -ano | Select-String -SimpleMatch $kw | Select-Object -First 160"
pause
goto menu_search

:search_driver_hwids
cls
color 0F
echo %C_CYAN%============================================================%C_RESET%
echo  SEARCH DRIVER / HARDWARE IDS
echo %C_CYAN%============================================================%C_RESET%
set "kw=" & set /p kw=Device, vendor, VEN_, DEV_, USB, PCI, audio, wifi:
if not defined kw goto menu_search
echo.
echo Matching Plug and Play devices:
echo ------------------------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Get-CimInstance Win32_PnPEntity | Where-Object { ([string]$_.Name) -match $rx -or ([string]$_.DeviceID) -match $rx -or (($_.HardwareID -join ' ') -match $rx) } | Select-Object -First 80 Name,PNPClass,Status,DeviceID,@{Name='HardwareID';Expression={$_.HardwareID -join '; '}} | Format-List"
pause
goto menu_search

:search_global
cls
color 0F
echo %C_CYAN%============================================================%C_RESET%
echo  GLOBAL SEARCH - TOOLKIT / COMMANDS / APPS / SERVICES / DEVICES
echo %C_CYAN%============================================================%C_RESET%
set "kw=" & set /p kw=Search keyword:
if not defined kw goto menu_search
set "SEARCH_FILE=%~f0"
echo.
echo === TOOLKIT MATCHES ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $file=$env:SEARCH_FILE; Select-String -LiteralPath $file -SimpleMatch $kw -ErrorAction SilentlyContinue | Select-Object -First 120 | ForEach-Object { '{0}: {1}' -f $_.LineNumber,$_.Line }"
echo.
echo === POWERSHELL COMMANDS ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Get-Command -ErrorAction SilentlyContinue | Where-Object { ([string]$_.Name) -match $rx } | Select-Object -First 80 CommandType,Name,Source | Format-Table -AutoSize"
echo.
echo === SYSTEM32 EXE/CPL/MSC MATCHES ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Get-ChildItem -LiteralPath (Join-Path $env:windir 'System32') -Force -ErrorAction SilentlyContinue | Where-Object { ([string]$_.Name) -match $rx -and $_.Extension -in '.exe','.cpl','.msc' } | Select-Object -First 120 -ExpandProperty FullName"
echo.
echo === SERVICES ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Get-CimInstance Win32_Service | Where-Object { ([string]$_.Name) -match $rx -or ([string]$_.DisplayName) -match $rx } | Select-Object -First 80 Name,DisplayName,State | Format-Table -AutoSize"
echo.
echo === DEVICES ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; pnputil /enum-devices | Select-String -SimpleMatch $kw | Select-Object -First 100"
echo.
echo === WINGET CATALOG ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; if(Get-Command winget -ErrorAction SilentlyContinue){ & winget search $kw --accept-source-agreements } else { Write-Host 'Winget not installed.' }"
pause
goto menu_search

:menu_system_admin
set "BACK_MENU=menu_system_admin"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [01] SYSTEM ^& ADMINISTRATION ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] System Tools Console                      [02] Task ^& Process Manager                   [03] Startup Manager                           %C_RESET%
echo %C_GREEN%  [04] User / PC Info                            [05] Advanced Admin Tools                      [06] Environment Variables                     %C_RESET%
echo %C_GREEN%  [07] Scheduled Tasks                           [08] Live Health Dashboard                     [09] Complete Issue Library                    %C_RESET%
echo %C_GREEN%  [10] Windows Core Issues                       [11] Open Computer Management                  [12] Open Control Panel                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto system_tools
if "%c%"=="1" goto system_tools
if "%c%"=="02" goto task_process
if "%c%"=="2" goto task_process
if "%c%"=="03" goto startup_mgr
if "%c%"=="3" goto startup_mgr
if "%c%"=="04" goto user_pc_info
if "%c%"=="4" goto user_pc_info
if "%c%"=="05" goto adv_admin
if "%c%"=="5" goto adv_admin
if "%c%"=="06" goto env_vars
if "%c%"=="6" goto env_vars
if "%c%"=="07" goto sched_tasks
if "%c%"=="7" goto sched_tasks
if "%c%"=="08" goto health_dashboard
if "%c%"=="8" goto health_dashboard
if "%c%"=="09" goto issue_library
if "%c%"=="9" goto issue_library
if "%c%"=="10" goto issue_windows_core
if "%c%"=="11" (start "" compmgmt.msc & pause & goto menu_system_admin)
if "%c%"=="12" (start "" control & pause & goto menu_system_admin)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_system_admin

:menu_network_internet
set "BACK_MENU=menu_network_internet"
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [02] NETWORK ^& INTERNET ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Network Diagnostics                       [02] WiFi Tools                                [03] DNS Manager                               %C_RESET%
echo %C_GREEN%  [04] Firewall Manager                          [05] IP / Adapter Config                       [06] VPN ^& Proxy                              %C_RESET%
echo %C_GREEN%  [07] RDP Network Tools                         [08] Network Shares                            [09] Advanced Network Tools                    %C_RESET%
echo %C_GREEN%  [10] Network Pro Issue Library                 [11] Auto Network Repair Engine                [12] Deep Network Report                       %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto net_diag
if "%c%"=="1" goto net_diag
if "%c%"=="02" goto wifi_tools
if "%c%"=="2" goto wifi_tools
if "%c%"=="03" goto dns_mgr
if "%c%"=="3" goto dns_mgr
if "%c%"=="04" goto firewall_mgr
if "%c%"=="4" goto firewall_mgr
if "%c%"=="05" goto ip_config
if "%c%"=="5" goto ip_config
if "%c%"=="06" goto vpn_proxy
if "%c%"=="6" goto vpn_proxy
if "%c%"=="07" goto rdp_tools
if "%c%"=="7" goto rdp_tools
if "%c%"=="08" goto net_shares
if "%c%"=="8" goto net_shares
if "%c%"=="09" goto net_advanced
if "%c%"=="9" goto net_advanced
if "%c%"=="10" goto issue_network_pro
if "%c%"=="11" goto menu_auto_network
if "%c%"=="12" goto issue_network_report
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_network_internet

:menu_windows_repair
set "BACK_MENU=menu_windows_repair"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [03] WINDOWS REPAIR ^& RECOVERY ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] SFC / DISM Repair                         [02] Boot Repair                               [03] Registry Repair                           %C_RESET%
echo %C_GREEN%  [04] Windows Update Fix                        [05] Store / Apps Repair                       [06] DLL / Runtime Fix                         %C_RESET%
echo %C_GREEN%  [07] Explorer / Start Fix                      [08] Service Repair                            [09] One Click Repair                          %C_RESET%
echo %C_GREEN%  [10] Recovery Options                          [11] Reset PC Tools                            [12] Complete Issue Library                    %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto sfc_dism
if "%c%"=="1" goto sfc_dism
if "%c%"=="02" goto boot_repair
if "%c%"=="2" goto boot_repair
if "%c%"=="03" goto reg_repair
if "%c%"=="3" goto reg_repair
if "%c%"=="04" goto update_fix
if "%c%"=="4" goto update_fix
if "%c%"=="05" goto store_repair
if "%c%"=="5" goto store_repair
if "%c%"=="06" goto dll_fix
if "%c%"=="6" goto dll_fix
if "%c%"=="07" goto explorer_fix
if "%c%"=="7" goto explorer_fix
if "%c%"=="08" goto service_repair
if "%c%"=="8" goto service_repair
if "%c%"=="09" goto one_click_repair
if "%c%"=="9" goto one_click_repair
if "%c%"=="10" goto recovery_opts
if "%c%"=="11" goto reset_pc
if "%c%"=="12" goto issue_windows_core
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_windows_repair

:menu_security_defender
set "BACK_MENU=menu_security_defender"
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [04] SECURITY ^& DEFENDER ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Defender Tools                            [02] User Password Security                    [03] USB Security                              %C_RESET%
echo %C_GREEN%  [04] BitLocker Tools                           [05] Malware Cleanup                           [06] Network Security                          %C_RESET%
echo %C_GREEN%  [07] Privacy Settings                          [08] Security Audit                            [09] Cyber Security Toolkit                    %C_RESET%
echo %C_GREEN%  [10] Windows Security App                      [11] Defender Offline Scan                     [12] Firewall Reset                            %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto defender_tools
if "%c%"=="1" goto defender_tools
if "%c%"=="02" goto user_security
if "%c%"=="2" goto user_security
if "%c%"=="03" goto usb_security
if "%c%"=="3" goto usb_security
if "%c%"=="04" goto bitlocker_tools
if "%c%"=="4" goto bitlocker_tools
if "%c%"=="05" goto malware_cleanup
if "%c%"=="5" goto malware_cleanup
if "%c%"=="06" goto net_security
if "%c%"=="6" goto net_security
if "%c%"=="07" goto privacy_settings
if "%c%"=="7" goto privacy_settings
if "%c%"=="08" goto security_audit
if "%c%"=="8" goto security_audit
if "%c%"=="09" goto menu_cyber_security
if "%c%"=="9" goto menu_cyber_security
if "%c%"=="10" (start "" windowsdefender: & pause & goto menu_security_defender)
if "%c%"=="11" goto issue_defender_offline
if "%c%"=="12" goto issue_firewall_reset
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_security_defender

:menu_performance_optimization
set "BACK_MENU=menu_performance_optimization"
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [05] PERFORMANCE ^& OPTIMIZATION ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] System Cleanup                            [02] RAM Optimizer                             [03] Speed Booster                             %C_RESET%
echo %C_GREEN%  [04] BSOD / Crash Fix                          [05] Disk Defrag                               [06] Visual Effects                            %C_RESET%
echo %C_GREEN%  [07] Prefetch / Cache                          [08] Windows Indexing                          [09] Advanced Cleanup                          %C_RESET%
echo %C_GREEN%  [10] Auto Performance Booster                  [11] Live Monitor                              [12] Energy Report                             %C_RESET%
echo %C_GREEN%  [13] 1 Click Minimum PC Boost                  [14] Disable Boost / Restore Normal            [15] ONE CLEAN                                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto sys_cleanup
if "%c%"=="1" goto sys_cleanup
if "%c%"=="02" goto ram_optimizer
if "%c%"=="2" goto ram_optimizer
if "%c%"=="03" goto speed_booster
if "%c%"=="3" goto speed_booster
if "%c%"=="04" goto bsod_fix
if "%c%"=="4" goto bsod_fix
if "%c%"=="05" goto disk_defrag
if "%c%"=="5" goto disk_defrag
if "%c%"=="06" goto visual_effects
if "%c%"=="6" goto visual_effects
if "%c%"=="07" goto prefetch_cache
if "%c%"=="7" goto prefetch_cache
if "%c%"=="08" goto win_indexing
if "%c%"=="8" goto win_indexing
if "%c%"=="09" goto adv_cleanup
if "%c%"=="9" goto adv_cleanup
if "%c%"=="10" goto menu_auto_performance
if "%c%"=="11" goto menu_live_monitor
if "%c%"=="12" goto issue_energy_report
if "%c%"=="13" goto performance_minimum_boost
if "%c%"=="14" goto performance_boost_restore
if "%c%"=="15" goto one_clean
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_performance_optimization

:menu_storage_disk
set "BACK_MENU=menu_storage_disk"
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [06] STORAGE ^& DISK MANAGEMENT ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Storage Tools                             [02] Disk Defrag / Optimize                    [03] Disk Image Tools                          %C_RESET%
echo %C_GREEN%  [04] VHD / VHDX Create                         [05] Disk Health Summary                       [06] CHKDSK Tools                              %C_RESET%
echo %C_GREEN%  [07] Disk Cleanup                              [08] Large File Scanner                        [09] BitLocker Status                          %C_RESET%
echo %C_GREEN%  [10] Complete Issue Report                     [11] Open Disk Management                      [12] Storage Settings                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto storage
if "%c%"=="1" goto storage
if "%c%"=="02" goto disk_defrag
if "%c%"=="2" goto disk_defrag
if "%c%"=="03" goto disk_image
if "%c%"=="3" goto disk_image
if "%c%"=="04" goto create_vhd
if "%c%"=="4" goto create_vhd
if "%c%"=="05" goto issue_disk_health
if "%c%"=="5" goto issue_disk_health
if "%c%"=="06" (chkdsk & pause & goto menu_storage_disk)
if "%c%"=="6" (chkdsk & pause & goto menu_storage_disk)
if "%c%"=="07" (cleanmgr & pause & goto menu_storage_disk)
if "%c%"=="7" (cleanmgr & goto menu_storage_disk)
if "%c%"=="08" (powershell -NoProfile -Command "Get-ChildItem C:\ -Recurse -ErrorAction SilentlyContinue | Where-Object {$_.Length -gt 500MB} | Sort-Object Length -Descending | Select-Object -First 20 FullName,@{Name='SizeGB';Expression={[math]::Round($_.Length/1GB,2)}} | Format-Table -AutoSize" & pause & goto menu_storage_disk)
if "%c%"=="8" (powershell -NoProfile -Command "Get-ChildItem C:\ -Recurse -ErrorAction SilentlyContinue | Where-Object {$_.Length -gt 500MB} | Sort-Object Length -Descending | Select-Object -First 20 FullName,@{Name='SizeGB';Expression={[math]::Round($_.Length/1GB,2)}} | Format-Table -AutoSize" & pause & goto menu_storage_disk)
if "%c%"=="09" (manage-bde -status & pause & goto menu_storage_disk)
if "%c%"=="9" (manage-bde -status & pause & goto menu_storage_disk)
if "%c%"=="10" goto issue_complete_report
if "%c%"=="11" (start "" diskmgmt.msc & pause & goto menu_storage_disk)
if "%c%"=="12" (start "" ms-settings:storagesense & pause & goto menu_storage_disk)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_storage_disk

:menu_user_account
set "BACK_MENU=menu_user_account"
cls
color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [07] USER / ACCOUNT MANAGEMENT ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] User / PC Info                            [02] User Password Security                    [03] Profile Diagnostics                       %C_RESET%
echo %C_GREEN%  [04] Create Local Admin User                   [05] Credential Manager                        [06] Sign-in Options                           %C_RESET%
echo %C_GREEN%  [07] Local Users and Groups                    [08] Region / Language                         [09] Startup Apps Review                       %C_RESET%
echo %C_GREEN%  [10] App Permissions Hub                       [11] User / App Issue Library                  [12] Installed Apps Inventory                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto user_pc_info
if "%c%"=="1" goto user_pc_info
if "%c%"=="02" goto user_security
if "%c%"=="2" goto user_security
if "%c%"=="03" goto issue_profile_diag
if "%c%"=="3" goto issue_profile_diag
if "%c%"=="04" goto issue_create_admin
if "%c%"=="4" goto issue_create_admin
if "%c%"=="05" (control /name Microsoft.CredentialManager & pause & goto menu_user_account)
if "%c%"=="5" (control /name Microsoft.CredentialManager & goto menu_user_account)
if "%c%"=="06" (start "" ms-settings:signinoptions & pause & goto menu_user_account)
if "%c%"=="6" (start "" ms-settings:signinoptions & goto menu_user_account)
if "%c%"=="07" (start "" lusrmgr.msc & pause & goto menu_user_account)
if "%c%"=="7" (start "" lusrmgr.msc & goto menu_user_account)
if "%c%"=="08" (start "" ms-settings:regionlanguage & pause & goto menu_user_account)
if "%c%"=="8" (start "" ms-settings:regionlanguage & goto menu_user_account)
if "%c%"=="09" (start "" ms-settings:startupapps & pause & goto menu_user_account)
if "%c%"=="9" (start "" ms-settings:startupapps & goto menu_user_account)
if "%c%"=="10" (start "" ms-settings:privacy & pause & goto menu_user_account)
if "%c%"=="11" goto issue_user_apps
if "%c%"=="12" goto issue_apps_inventory
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_user_account

:menu_backup_restore
set "BACK_MENU=menu_backup_restore"
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [08] BACKUP ^& RESTORE CENTER - DRIVE PICKER READY%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] System Backup / Image                  [02] File Backup / Restore Pro            [03] System Restore%C_RESET%
echo %C_GREEN%  [04] Registry Backup / Restore Pro          [05] Driver Backup / Restore Pro          [06] Emergency Tools%C_RESET%
echo %C_GREEN%  [07] Recovery Options                       [08] Disk Image Tools                     [09] Create Restore Point%C_RESET%
echo %C_GREEN%  [10] Backup Toolkit File                    [11] Export Event Logs                    [12] Complete Issue Report%C_RESET%
echo %C_GREEN%  [13] Open Smart Backup Root                  [14] DISM / WIM Auto Center%C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto system_backup
if "%c%"=="1" goto system_backup
if "%c%"=="02" goto file_backup
if "%c%"=="2" goto file_backup
if "%c%"=="03" goto sys_restore
if "%c%"=="3" goto sys_restore
if "%c%"=="04" goto reg_backup
if "%c%"=="4" goto reg_backup
if "%c%"=="05" goto driver_backup
if "%c%"=="5" goto driver_backup
if "%c%"=="06" goto emergency_tools
if "%c%"=="6" goto emergency_tools
if "%c%"=="07" goto recovery_opts
if "%c%"=="7" goto recovery_opts
if "%c%"=="08" goto disk_image
if "%c%"=="8" goto disk_image
if "%c%"=="09" goto create_restore_point
if "%c%"=="9" goto create_restore_point
if "%c%"=="10" goto backup_toolkit_file
if "%c%"=="11" goto issue_event_export
if "%c%"=="12" goto issue_complete_report
if "%c%"=="13" goto open_backup_root
if "%c%"=="14" (set "WIM_CENTER_BACK=menu_backup_restore" & goto dism_wim_center)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_backup_restore

:menu_driver_hardware
set "BACK_MENU=menu_driver_hardware"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [09] DRIVER ^& HARDWARE MANAGEMENT ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Driver Tools                              [02] Hardware Health                           [03] Device Manager                            %C_RESET%
echo %C_GREEN%  [04] Problem Devices                           [05] USB Fix                                   [06] Bluetooth Fix                             %C_RESET%
echo %C_GREEN%  [07] Audio Fix                                 [08] Display / GPU Fix                         [09] Camera / Mic Fix                          %C_RESET%
echo %C_GREEN%  [10] Driver Store Report                       [11] RAM Diagnostic                            [12] Disk Health                               %C_RESET%
echo %C_GREEN%  [13] Smart Driver Auto Center                  [14] OEM Driver Assistants                     [15] Driver Backup / Restore                   %C_RESET%
echo %C_GREEN%  [16] Driver Command Reference                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto driver_tools
if "%c%"=="1" goto driver_tools
if "%c%"=="02" goto hardware_health
if "%c%"=="2" goto hardware_health
if "%c%"=="03" (start "" devmgmt.msc & pause & goto menu_driver_hardware)
if "%c%"=="3" (start "" devmgmt.msc & goto menu_driver_hardware)
if "%c%"=="04" goto issue_problem_devices
if "%c%"=="4" goto issue_problem_devices
if "%c%"=="05" goto issue_usb_fix
if "%c%"=="5" goto issue_usb_fix
if "%c%"=="06" goto issue_bluetooth_fix
if "%c%"=="6" goto issue_bluetooth_fix
if "%c%"=="07" goto issue_audio_modern_fix
if "%c%"=="7" goto issue_audio_modern_fix
if "%c%"=="08" goto issue_display_gpu
if "%c%"=="8" goto issue_display_gpu
if "%c%"=="09" goto issue_camera_mic
if "%c%"=="9" goto issue_camera_mic
if "%c%"=="10" goto issue_driver_report
if "%c%"=="11" (start "" mdsched.exe & pause & goto menu_driver_hardware)
if "%c%"=="12" goto issue_disk_health
if "%c%"=="13" goto driver_auto_center
if "%c%"=="14" goto driver_oem_assistant
if "%c%"=="15" goto driver_backup_restore_pro
if "%c%"=="16" goto driver_command_reference
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_driver_hardware

:menu_update_activation
set "BACK_MENU=menu_update_activation"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [10] WINDOWS UPDATE ^& ACTIVATION ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Windows Update Fix                        [02] Windows Update Settings                   [03] Deep Update Reset                         %C_RESET%
echo %C_GREEN%  [04] Update Policy / WSUS View                 [05] Windows Activation                        [06] Activation Settings                       %C_RESET%
echo %C_GREEN%  [07] Edition Tools                             [08] License Info                              [09] Component Repair                          %C_RESET%
echo %C_GREEN%  [10] Recovery Options                          [11] Windows Core Issues                       [12] Update Logs Folder                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto update_fix
if "%c%"=="1" goto update_fix
if "%c%"=="02" (start "" ms-settings:windowsupdate & pause & goto menu_update_activation)
if "%c%"=="2" (start "" ms-settings:windowsupdate & goto menu_update_activation)
if "%c%"=="03" goto issue_win_update_deep
if "%c%"=="3" goto issue_win_update_deep
if "%c%"=="04" goto issue_wsus_policy
if "%c%"=="4" goto issue_wsus_policy
if "%c%"=="05" goto win_activation
if "%c%"=="5" goto win_activation
if "%c%"=="06" (start "" ms-settings:activation & pause & goto menu_update_activation)
if "%c%"=="6" (start "" ms-settings:activation & goto menu_update_activation)
if "%c%"=="07" goto edition_tools
if "%c%"=="7" goto edition_tools
if "%c%"=="08" (slmgr /dlv & pause & goto menu_update_activation)
if "%c%"=="8" (slmgr /dlv & pause & goto menu_update_activation)
if "%c%"=="09" goto issue_component_repair
if "%c%"=="9" goto issue_component_repair
if "%c%"=="10" goto recovery_opts
if "%c%"=="11" goto issue_windows_core
if "%c%"=="12" (explorer "C:\Windows\Logs" & goto menu_update_activation)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_update_activation

:menu_office_outlook
set "BACK_MENU=menu_office_outlook"
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [11] OFFICE / OUTLOOK TOOLKIT ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Outlook Fix                               [02] Office Download Center                    [03] Office Repair Page                        %C_RESET%
echo %C_GREEN%  [04] Outlook Safe Mode                         [05] Mail Profile Panel                        [06] Teams / Zoom Cache Fix                    %C_RESET%
echo %C_GREEN%  [07] OneDrive Reset                            [08] Office Activation Info                    [09] Browser / Cloud Issues                    %C_RESET%
echo %C_GREEN%  [10] Mass Software Installer                   [11] Installed Apps Inventory                  [12] Credential Manager                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto outlook_fix
if "%c%"=="1" goto outlook_fix
if "%c%"=="02" goto office_download
if "%c%"=="2" goto office_download
if "%c%"=="03" (start "" appwiz.cpl & pause & goto menu_office_outlook)
if "%c%"=="3" (start "" appwiz.cpl & goto menu_office_outlook)
if "%c%"=="04" (call :open_outlook_safe & pause & goto menu_office_outlook)
if "%c%"=="4" (call :open_outlook_safe & pause & goto menu_office_outlook)
if "%c%"=="05" (control mlcfg32.cpl & pause & goto menu_office_outlook)
if "%c%"=="5" (control mlcfg32.cpl & goto menu_office_outlook)
if "%c%"=="06" goto issue_teams_zoom_cache
if "%c%"=="6" goto issue_teams_zoom_cache
if "%c%"=="07" goto issue_onedrive_reset
if "%c%"=="7" goto issue_onedrive_reset
if "%c%"=="08" (call :office_activation_status & pause & goto menu_office_outlook)
if "%c%"=="8" (call :office_activation_status & pause & goto menu_office_outlook)
if "%c%"=="09" goto issue_browser_cloud
if "%c%"=="9" goto issue_browser_cloud
if "%c%"=="10" goto menu_mass_installer
if "%c%"=="11" goto issue_apps_inventory
if "%c%"=="12" (control /name Microsoft.CredentialManager & pause & goto menu_office_outlook)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_office_outlook

:menu_printer_spooler
set "BACK_MENU=menu_printer_spooler"
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [12] ADVANCED PRINTER TOOLKIT - Ultimate Toolkit%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Error 0x0000011b                         [02] Error 0x00000709                         [03] Default Printer Issue                     %C_RESET%
echo %C_GREEN%       Cannot Connect Printer                         Cannot Set Printer                           Printer Not Changing                          %C_RESET%
echo.
echo %C_GREEN%  [04] Shared Printer Error                    [05] Printer Offline                           [06] Print Spooler Error                       %C_RESET%
echo %C_GREEN%       Network Printer Failed                        Printer Showing Offline                       Queue Not Working                             %C_RESET%
echo.
echo %C_GREEN%  [07] Print Queue Stuck                       [08] Access Denied Error                       [09] SMB Guest Share Error                     %C_RESET%
echo %C_GREEN%       Documents Not Printing                        Permission Problem                            Asking Username Password                      %C_RESET%
echo.
echo %C_GREEN%  [10] Driver Problem                          [11] Network Discovery                         [12] RPC Server Error                          %C_RESET%
echo %C_GREEN%       Driver Missing                               Printer Not Visible                           Communication Failed                          %C_RESET%
echo.
echo %C_GREEN%  [13] Operation Failed                        [14] Remove Printers                           [15] Remove Drivers                            %C_RESET%
echo %C_GREEN%       Could Not Complete                            Delete Installed Printers                     Delete Driver Package                         %C_RESET%
echo.
echo %C_GREEN%  [16] Clean Version-3                         [17] Clean Version-4                           [18] Registry Cleanup                          %C_RESET%
echo %C_GREEN%       Old Drivers Remove                            Modern Drivers Remove                         Remove Printer Regedit                        %C_RESET%
echo.
echo %C_GREEN%  [19] Clear Print Queue                       [20] Restart Spooler                           [21] COMPLETE CLEANUP                          %C_RESET%
echo %C_GREEN%       Delete Stuck Jobs                             Restart Printer Service                       Full Printer Reset                            %C_RESET%
echo.
echo %C_GREEN%  [22] APPLY ALL FIXES                         [23] Main Menu / Exit Printer Center                                                        %C_RESET%
echo %C_GREEN%       Recommended For Users                                                                                                                   %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu              [00] Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT PRINTER OPTION:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto printer_fix_11b
if "%c%"=="1" goto printer_fix_11b
if "%c%"=="02" goto printer_fix_709
if "%c%"=="2" goto printer_fix_709
if "%c%"=="03" goto printer_fix_default
if "%c%"=="3" goto printer_fix_default
if "%c%"=="04" goto printer_fix_share
if "%c%"=="4" goto printer_fix_share
if "%c%"=="05" goto printer_fix_offline
if "%c%"=="5" goto printer_fix_offline
if "%c%"=="06" goto printer_fix_spooler
if "%c%"=="6" goto printer_fix_spooler
if "%c%"=="07" goto printer_fix_queue
if "%c%"=="7" goto printer_fix_queue
if "%c%"=="08" goto printer_fix_access
if "%c%"=="8" goto printer_fix_access
if "%c%"=="09" goto printer_fix_smb
if "%c%"=="9" goto printer_fix_smb
if "%c%"=="10" goto printer_fix_driver
if "%c%"=="11" goto printer_fix_discovery
if "%c%"=="12" goto printer_fix_rpc
if "%c%"=="13" goto printer_fix_operation_failed
if "%c%"=="14" goto printer_remove_printers
if "%c%"=="15" goto printer_remove_drivers
if "%c%"=="16" goto printer_clean_v3
if "%c%"=="17" goto printer_clean_v4
if "%c%"=="18" goto printer_reg_cleanup
if "%c%"=="19" goto printer_clear_queue
if "%c%"=="20" goto printer_restart_spooler_menu
if "%c%"=="21" goto printer_full_cleanup
if "%c%"=="22" goto printer_all_fix
if "%c%"=="23" goto main
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_printer_spooler

:printer_restart_spooler_core
net stop spooler /y >nul 2>&1
timeout /t 2 /nobreak >nul 2>&1
net start spooler
exit /b

:printer_clear_queue_core
net stop spooler /y >nul 2>&1
del /Q /F /S "%SystemRoot%\System32\spool\PRINTERS\*.*" >nul 2>&1
net start spooler
exit /b

:printer_confirm_danger
echo.
echo This option can remove printers, drivers, or registry entries.
set "confirm="
set /p confirm=Type YES to continue, or press Enter to cancel: 
if /i "%confirm%"=="YES" exit /b 0
echo Cancelled.
pause
exit /b 1

:printer_fix_11b
cls
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f
call :printer_restart_spooler_core
echo ERROR 0x0000011b FIXED!
pause
goto menu_printer_spooler

:printer_fix_709
cls
reg add "HKLM\Software\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f
call :printer_restart_spooler_core
echo ERROR 0x00000709 FIXED!
pause
goto menu_printer_spooler

:printer_fix_default
cls
REG ADD "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Windows" /v LegacyDefaultPrinterMode /t REG_DWORD /d 1 /f
echo DEFAULT PRINTER ISSUE FIXED!
pause
goto menu_printer_spooler

:printer_fix_share
cls
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes
echo SHARED PRINTER ISSUE FIXED!
pause
goto menu_printer_spooler

:printer_fix_offline
cls
call :printer_restart_spooler_core
start "" ms-settings:printers
echo PRINTER OFFLINE ISSUE FIXED!
pause
goto menu_printer_spooler

:printer_fix_spooler
cls
call :printer_restart_spooler_core
echo PRINT SPOOLER FIXED!
pause
goto menu_printer_spooler

:printer_fix_queue
cls
call :printer_clear_queue_core
echo PRINT QUEUE CLEARED!
pause
goto menu_printer_spooler

:printer_fix_access
cls
takeown /f "%SystemRoot%\System32\spool" /r /d Y
icacls "%SystemRoot%\System32\spool" /grant *S-1-5-32-544:F /t
echo ACCESS DENIED ISSUE FIXED!
pause
goto menu_printer_spooler

:printer_fix_smb
cls
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f
echo SMB GUEST SHARE FIXED!
pause
goto menu_printer_spooler

:printer_fix_driver
cls
rundll32 printui.dll,PrintUIEntry /s /t2
echo DRIVER WINDOW OPENED!
pause
goto menu_printer_spooler

:printer_fix_discovery
cls
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes
echo NETWORK DISCOVERY ENABLED!
pause
goto menu_printer_spooler

:printer_fix_rpc
cls
sc config RpcSs start= auto
net start RpcSs
echo RPC SERVER ISSUE FIXED!
pause
goto menu_printer_spooler

:printer_fix_operation_failed
cls
dism /online /Enable-Feature /FeatureName:Printing-LPDPrintService /NoRestart
dism /online /Enable-Feature /FeatureName:Printing-LPRPortMonitor /NoRestart
echo OPERATION FAILED ERROR FIXED!
pause
goto menu_printer_spooler

:printer_remove_printers
cls
call :printer_confirm_danger
if errorlevel 1 goto menu_printer_spooler
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $printers=Get-Printer -ErrorAction Stop; if(-not $printers){ Write-Host 'No installed printers found.' } else { foreach($p in $printers){ try { Remove-Printer -Name $p.Name -ErrorAction Stop; Write-Host ('Removed: ' + $p.Name) } catch { Write-Host ('Failed: ' + $p.Name + ' - ' + $_.Exception.Message) } } } } catch { Write-Host ('Printer removal failed: ' + $_.Exception.Message) }"
echo ALL PRINTERS REMOVE COMMAND COMPLETED!
pause
goto menu_printer_spooler

:printer_remove_drivers
cls
rundll32 printui.dll,PrintUIEntry /s /t2
echo REMOVE DRIVERS MANUALLY FROM THE DRIVERS TAB.
pause
goto menu_printer_spooler

:printer_clean_v3
cls
call :printer_confirm_danger
if errorlevel 1 goto menu_printer_spooler
net stop spooler /y >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-3" /f
net start spooler
echo VERSION-3 DRIVERS CLEANED!
pause
goto menu_printer_spooler

:printer_clean_v4
cls
call :printer_confirm_danger
if errorlevel 1 goto menu_printer_spooler
net stop spooler /y >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-4" /f
net start spooler
echo VERSION-4 DRIVERS CLEANED!
pause
goto menu_printer_spooler

:printer_reg_cleanup
cls
call :printer_confirm_danger
if errorlevel 1 goto menu_printer_spooler
net stop spooler /y >nul 2>&1
reg delete "HKCU\Printers" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers" /f
net start spooler
echo REGISTRY CLEANUP COMPLETED!
pause
goto menu_printer_spooler

:printer_clear_queue
cls
call :printer_clear_queue_core
echo PRINT QUEUE CLEARED!
pause
goto menu_printer_spooler

:printer_restart_spooler_menu
cls
call :printer_restart_spooler_core
echo PRINT SPOOLER RESTARTED!
pause
goto menu_printer_spooler

:printer_full_cleanup
cls
call :printer_confirm_danger
if errorlevel 1 goto menu_printer_spooler
net stop spooler /y >nul 2>&1
del /Q /F /S "%SystemRoot%\System32\spool\PRINTERS\*.*" >nul 2>&1
reg delete "HKCU\Printers" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-3" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Drivers\Version-4" /f
net start spooler
echo COMPLETE CLEANUP DONE!
pause
goto menu_printer_spooler

:printer_all_fix
cls
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Policies\Microsoft\Windows NT\Printers\RPC" /v RpcUseNamedPipeProtocol /t REG_DWORD /d 1 /f
REG ADD "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Windows" /v LegacyDefaultPrinterMode /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes
call :printer_clear_queue_core
echo ALL FIXES APPLIED SUCCESSFULLY!
pause
goto menu_printer_spooler

:menu_remote_rdp
set "BACK_MENU=menu_remote_rdp"
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [13] REMOTE ACCESS / RDP TOOLS ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] RDP Tools                                 [02] RDP / NLA Firewall Fix                    [03] Remote Desktop Settings                   %C_RESET%
echo %C_GREEN%  [04] VPN ^& Proxy Tools                        [05] Network Shares                            [06] Credential Manager                        %C_RESET%
echo %C_GREEN%  [07] SMB / NAS Diagnostics                     [08] Cloud ^& Remote Management                [09] Active Sessions                           %C_RESET%
echo %C_GREEN%  [10] RDP Port Check                            [11] Firewall Remote Rules                     [12] Remote Assistance Settings                %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto rdp_tools
if "%c%"=="1" goto rdp_tools
if "%c%"=="02" goto issue_rdp_nla
if "%c%"=="2" goto issue_rdp_nla
if "%c%"=="03" (start "" ms-settings:remotedesktop & pause & goto menu_remote_rdp)
if "%c%"=="3" (start "" ms-settings:remotedesktop & goto menu_remote_rdp)
if "%c%"=="04" goto vpn_proxy
if "%c%"=="4" goto vpn_proxy
if "%c%"=="05" goto net_shares
if "%c%"=="5" goto net_shares
if "%c%"=="06" (control /name Microsoft.CredentialManager & pause & goto menu_remote_rdp)
if "%c%"=="6" (control /name Microsoft.CredentialManager & goto menu_remote_rdp)
if "%c%"=="07" goto issue_smb_nas
if "%c%"=="7" goto issue_smb_nas
if "%c%"=="08" goto menu_cloud_remote
if "%c%"=="8" goto menu_cloud_remote
if "%c%"=="09" (net session & pause & goto menu_remote_rdp)
if "%c%"=="9" (net session & pause & goto menu_remote_rdp)
if "%c%"=="10" (netstat -ano ^| findstr :3389 & pause & goto menu_remote_rdp)
if "%c%"=="11" (netsh advfirewall firewall set rule group="remote desktop" new enable=Yes & pause & goto menu_remote_rdp)
if "%c%"=="12" (start "" msra.exe & pause & goto menu_remote_rdp)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_remote_rdp

:menu_bios_boot
set "BACK_MENU=menu_bios_boot"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [14] BIOS / UEFI / BOOT TOOLS ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] BIOS / Boot Tools                         [02] Restart to UEFI                           [03] Advanced Startup                          %C_RESET%
echo %C_GREEN%  [04] Safe Mode Enable                          [05] Safe Mode Disable                         [06] Boot Repair Menu                          %C_RESET%
echo %C_GREEN%  [07] BCD View                                  [08] Secure Boot Status                        [09] TPM Check                                 %C_RESET%
echo %C_GREEN%  [10] Fast Startup Disable                      [11] Recovery Options                          [12] System Restore                            %C_RESET%
echo %C_GREEN%  [13] Fast Startup Enable                       [14] Create Bootable Pendrive                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto bios_boot
if "%c%"=="1" goto bios_boot
if "%c%"=="02" (shutdown /r /fw /t 5 & pause & goto menu_bios_boot)
if "%c%"=="2" (shutdown /r /fw /t 5 & pause & goto menu_bios_boot)
if "%c%"=="03" (shutdown /r /o /f /t 0)
if "%c%"=="3" (shutdown /r /o /f /t 0)
if "%c%"=="04" (bcdedit /set {current} safeboot minimal & pause & goto menu_bios_boot)
if "%c%"=="4" (bcdedit /set {current} safeboot minimal & pause & goto menu_bios_boot)
if "%c%"=="05" (bcdedit /deletevalue {current} safeboot & pause & goto menu_bios_boot)
if "%c%"=="5" (bcdedit /deletevalue {current} safeboot & pause & goto menu_bios_boot)
if "%c%"=="06" goto boot_repair
if "%c%"=="6" goto boot_repair
if "%c%"=="07" (bcdedit & pause & goto menu_bios_boot)
if "%c%"=="7" (bcdedit & pause & goto menu_bios_boot)
if "%c%"=="08" (powershell Confirm-SecureBootUEFI & pause & goto menu_bios_boot)
if "%c%"=="8" (powershell Confirm-SecureBootUEFI & pause & goto menu_bios_boot)
if "%c%"=="09" (tpm.msc & pause & goto menu_bios_boot)
if "%c%"=="9" (tpm.msc & goto menu_bios_boot)
if "%c%"=="10" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f & pause & goto menu_bios_boot)
if "%c%"=="13" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 1 /f & echo Fast Startup Enabled. & pause & goto menu_bios_boot)
if "%c%"=="11" goto recovery_opts
if "%c%"=="12" goto sys_restore
if "%c%"=="14" goto bootable_usb_creator
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_bios_boot

:bootable_usb_creator
set "BACK_MENU=bootable_usb_creator"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% BOOTABLE PENDRIVE CREATOR - ISO TO USB%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Create Bootable Pendrive from ISO           [02] List USB / Removable Drives              [03] Open OS Download Center                    %C_RESET%
echo %C_GREEN%  [04] Boot From USB Help                          [05] Open Logs Folder                         %C_RESET%
echo.
echo %C_YELLOW%  WARNING: Option 01 formats the selected USB drive. Backup pendrive data first.%C_RESET%
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back to BIOS / Boot Menu             [00] Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto bootable_usb_make
if "%c%"=="1" goto bootable_usb_make
if "%c%"=="02" goto bootable_usb_list
if "%c%"=="2" goto bootable_usb_list
if "%c%"=="03" goto os_download
if "%c%"=="3" goto os_download
if "%c%"=="04" goto bootable_usb_help
if "%c%"=="4" goto bootable_usb_help
if "%c%"=="05" (if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1 & explorer "%LOGROOT%" & goto bootable_usb_creator)
if "%c%"=="5" (if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1 & explorer "%LOGROOT%" & goto bootable_usb_creator)
if "%c%"=="99" goto menu_bios_boot
if "%c%"=="00" goto main
goto bootable_usb_creator

:bootable_usb_list
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% USB / REMOVABLE DRIVE LIST%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $usb=Get-Disk | Where-Object BusType -eq USB | Sort-Object Number; if($usb){$usb | ForEach-Object { $d=$_; Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | Where-Object DriveLetter | ForEach-Object { $v=Get-Volume -DriveLetter $_.DriveLetter -ErrorAction SilentlyContinue; [pscustomobject]@{Drive=($_.DriveLetter+':');Disk=$d.Number;Label=$v.FileSystemLabel;FileSystem=$v.FileSystem;SizeGB=[math]::Round($d.Size/1GB,2);Health=$d.HealthStatus;Model=$d.FriendlyName} } } | Format-Table -AutoSize } else { Get-CimInstance Win32_LogicalDisk | Where-Object DriveType -eq 2 | Select-Object @{n='Drive';e={$_.DeviceID}},VolumeName,FileSystem,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},@{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,2)}} | Format-Table -AutoSize } } catch { Write-Host ('USB list failed: ' + $_.Exception.Message) }"
echo.
pause
goto bootable_usb_creator

:bootable_usb_make
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% CREATE BOOTABLE PENDRIVE FROM ISO%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo.
echo This will format the selected pendrive, mount the ISO, copy boot files,
echo and split install.wim automatically when FAT32 needs it.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; function Show-Usb { $rows=@(); try { $usb=Get-Disk | Where-Object BusType -eq USB | Sort-Object Number; foreach($d in $usb){ foreach($p in Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | Where-Object DriveLetter){ $v=Get-Volume -DriveLetter $p.DriveLetter -ErrorAction SilentlyContinue; $rows += [pscustomobject]@{Drive=($p.DriveLetter+':');Disk=$d.Number;Label=$v.FileSystemLabel;FileSystem=$v.FileSystem;SizeGB=[math]::Round($d.Size/1GB,2);Model=$d.FriendlyName} } } } catch {}; if(-not $rows){ $rows=Get-CimInstance Win32_LogicalDisk | Where-Object DriveType -eq 2 | Select-Object @{n='Drive';e={$_.DeviceID}},@{n='Disk';e={'?'}},@{n='Label';e={$_.VolumeName}},FileSystem,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},@{n='Model';e={'Removable'}} }; $rows | Format-Table -AutoSize; return $rows }; Write-Host 'Detected USB / removable drives:' -ForegroundColor Cyan; $rows=Show-Usb; if(-not $rows){ throw 'No USB/removable drive with drive letter found.' }; $letter=(Read-Host 'Enter pendrive drive letter only, example E').Trim().TrimEnd(':').ToUpperInvariant(); if($letter -notmatch '^[A-Z]$'){ throw 'Invalid drive letter.' }; $vol=Get-Volume -DriveLetter $letter -ErrorAction Stop; $part=Get-Partition -DriveLetter $letter -ErrorAction Stop; $disk=Get-Disk -Number $part.DiskNumber -ErrorAction Stop; Write-Host ('Selected: ' + $letter + ':  Disk ' + $disk.Number + '  ' + $disk.FriendlyName + '  ' + [math]::Round($disk.Size/1GB,2) + ' GB') -ForegroundColor Yellow; if($disk.BusType -ne 'USB'){ $sure=(Read-Host 'This disk is not reported as USB. Type USBOK to continue'); if($sure -ne 'USBOK'){ throw 'Cancelled.' } }; $iso=(Read-Host 'Enter full ISO path, example C:\ISO\Windows.iso').Trim([char]34); if(-not (Test-Path -LiteralPath $iso)){ throw 'ISO path not found.' }; if([IO.Path]::GetExtension($iso) -ne '.iso'){ throw 'Please select a .iso file.' }; $confirm=(Read-Host ('Type ERASE ' + $letter + ' to format ' + $letter + ': and create bootable USB')); if($confirm -ne ('ERASE ' + $letter)){ throw 'Cancelled by user.' }; $sizeLine=if($disk.Size -gt 32GB){ 'create partition primary size=32000' } else { 'create partition primary' }; $dp=@('select disk ' + $disk.Number,'clean','convert mbr',$sizeLine,'format fs=fat32 quick label=BOOTUSB','active','assign letter=' + $letter,'exit'); $dpFile=Join-Path $env:TEMP ('bootusb_' + [guid]::NewGuid() + '.txt'); $dp | Set-Content -LiteralPath $dpFile -Encoding ASCII; Write-Host 'Formatting USB with DiskPart...' -ForegroundColor Cyan; diskpart /s $dpFile; if($LASTEXITCODE -ne 0){ throw 'DiskPart failed while formatting USB.' }; Remove-Item -LiteralPath $dpFile -Force -ErrorAction SilentlyContinue; $mounted=$null; try { Write-Host 'Mounting ISO...' -ForegroundColor Cyan; $mounted=Mount-DiskImage -ImagePath $iso -PassThru; Start-Sleep -Seconds 2; $srcLetter=($mounted | Get-Volume).DriveLetter; if(-not $srcLetter){ throw 'Mounted ISO drive letter not found.' }; $src=$srcLetter + ':\'; $dst=$letter + ':\'; $bigWim=Join-Path $src 'sources\install.wim'; if((Test-Path -LiteralPath $bigWim) -and ((Get-Item -LiteralPath $bigWim).Length -gt 4000000000)){ Write-Host 'Large install.wim detected. Copying ISO except install.wim, then splitting WIM...' -ForegroundColor Yellow; robocopy $src $dst /E /XF install.wim; if($LASTEXITCODE -ge 8){ throw 'Robocopy failed while copying ISO files.' }; $swm=Join-Path $dst 'sources\install.swm'; New-Item -ItemType Directory -Path (Join-Path $dst 'sources') -Force | Out-Null; dism /Split-Image /ImageFile:$bigWim /SWMFile:$swm /FileSize:3800; if($LASTEXITCODE -ne 0){ throw 'DISM split install.wim failed.' } } else { Write-Host 'Copying ISO files to USB...' -ForegroundColor Cyan; robocopy $src $dst /E; if($LASTEXITCODE -ge 8){ throw 'Robocopy failed while copying ISO files.' } }; Write-Host ''; Write-Host ('BOOTABLE USB READY: ' + $letter + ':') -ForegroundColor Green; Write-Host 'Use BIOS/UEFI boot menu and select the USB drive.' } finally { if($mounted){ Dismount-DiskImage -ImagePath $iso -ErrorAction SilentlyContinue } }"
echo.
pause
goto bootable_usb_creator

:bootable_usb_help
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% BOOT FROM USB HELP%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo.
echo  1. Create the bootable pendrive from a valid Windows/WinPE/Linux ISO.
echo  2. Restart PC and press boot menu key: F12, F9, F8, ESC, or DEL depending on brand.
echo  3. Choose USB / UEFI USB from boot menu.
echo  4. If USB is not visible, disable Fast Startup, check Secure Boot compatibility, or try another USB port.
echo  5. For Windows ISO with large install.wim, this toolkit splits it for FAT32 UEFI boot.
echo.
pause
goto bootable_usb_creator

:menu_registry_policy
set "BACK_MENU=menu_registry_policy"
cls
color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [15] REGISTRY / GROUP POLICY ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Registry / GPO Tools                      [02] Group Policy Editor                       [03] GPUpdate Force                            %C_RESET%
echo %C_GREEN%  [04] GPResult HTML Report                      [05] RSOP Policy Result                        [06] Registry Editor                           %C_RESET%
echo %C_GREEN%  [07] Registry Backup                           [08] Registry Repair                           [09] Local Security Policy                     %C_RESET%
echo %C_GREEN%  [10] WSUS Policy View                          [11] Environment Variables                     [12] Scheduled Tasks                           %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto gpo_reg
if "%c%"=="1" goto gpo_reg
if "%c%"=="02" (start "" gpedit.msc & pause & goto menu_registry_policy)
if "%c%"=="2" (start "" gpedit.msc & goto menu_registry_policy)
if "%c%"=="03" (gpupdate /force & pause & goto menu_registry_policy)
if "%c%"=="3" (gpupdate /force & pause & goto menu_registry_policy)
if "%c%"=="04" goto issue_gp_report
if "%c%"=="4" goto issue_gp_report
if "%c%"=="05" (rsop.msc & pause & goto menu_registry_policy)
if "%c%"=="5" (rsop.msc & goto menu_registry_policy)
if "%c%"=="06" (start "" regedit & pause & goto menu_registry_policy)
if "%c%"=="6" (start "" regedit & goto menu_registry_policy)
if "%c%"=="07" goto reg_backup
if "%c%"=="7" goto reg_backup
if "%c%"=="08" goto reg_repair
if "%c%"=="8" goto reg_repair
if "%c%"=="09" (start "" secpol.msc & pause & goto menu_registry_policy)
if "%c%"=="9" (start "" secpol.msc & goto menu_registry_policy)
if "%c%"=="10" goto issue_wsus_policy
if "%c%"=="11" goto env_vars
if "%c%"=="12" goto sched_tasks
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_registry_policy

:menu_services_features
set "BACK_MENU=menu_services_features"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [16] WINDOWS SERVICES ^& FEATURES ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Service Repair                            [02] Services Manager                          [03] Windows Features                          %C_RESET%
echo %C_GREEN%  [04] Component Services                        [05] Service Failure Logs                      [06] Windows Installer Fix                     %C_RESET%
echo %C_GREEN%  [07] Windows Search Fix                        [08] Spooler Service Fix                       [09] Windows Time Fix                          %C_RESET%
echo %C_GREEN%  [10] Bluetooth Service Fix                     [11] Audio Service Fix                         [12] Hyper-V / WSL Tools                       %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto service_repair
if "%c%"=="1" goto service_repair
if "%c%"=="02" (start "" services.msc & pause & goto menu_services_features)
if "%c%"=="2" (start "" services.msc & goto menu_services_features)
if "%c%"=="03" (start "" optionalfeatures & pause & goto menu_services_features)
if "%c%"=="3" (start "" optionalfeatures & goto menu_services_features)
if "%c%"=="04" (start "" dcomcnfg & pause & goto menu_services_features)
if "%c%"=="4" (start "" dcomcnfg & goto menu_services_features)
if "%c%"=="05" goto issue_services_diag
if "%c%"=="5" goto issue_services_diag
if "%c%"=="06" goto issue_installer_fix
if "%c%"=="6" goto issue_installer_fix
if "%c%"=="07" goto issue_search_rebuild
if "%c%"=="7" goto issue_search_rebuild
if "%c%"=="08" goto issue_spooler_repair
if "%c%"=="8" goto issue_spooler_repair
if "%c%"=="09" goto issue_time_sync
if "%c%"=="9" goto issue_time_sync
if "%c%"=="10" goto issue_bluetooth_fix
if "%c%"=="11" goto issue_audio_modern_fix
if "%c%"=="12" goto hyperv_wsl
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_services_features

:menu_live_monitor
set "BACK_MENU=menu_live_monitor"
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [17] LIVE SYSTEM MONITOR ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] WOW Health Dashboard                      [02] Task Manager                              [03] Resource Monitor                          %C_RESET%
echo %C_GREEN%  [04] Performance Monitor                       [05] Reliability Monitor                       [06] Live Network Connections                  %C_RESET%
echo %C_GREEN%  [07] Live RAM Usage                            [08] Boot Performance Events                   [09] Hacker Style Dashboard                    %C_RESET%
echo %C_GREEN%  [10] Full System Report                        [11] Quick Health Report                       [12] Complete Issue Report                     %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto health_dashboard
if "%c%"=="1" goto health_dashboard
if "%c%"=="02" (start "" taskmgr & pause & goto menu_live_monitor)
if "%c%"=="2" (start "" taskmgr & goto menu_live_monitor)
if "%c%"=="03" (start "" resmon & pause & goto menu_live_monitor)
if "%c%"=="3" (start "" resmon & goto menu_live_monitor)
if "%c%"=="04" (start "" perfmon & pause & goto menu_live_monitor)
if "%c%"=="4" (start "" perfmon & goto menu_live_monitor)
if "%c%"=="05" (start "" perfmon /rel & pause & goto menu_live_monitor)
if "%c%"=="5" (start "" perfmon /rel & goto menu_live_monitor)
if "%c%"=="06" (netstat -ano & pause & goto menu_live_monitor)
if "%c%"=="6" (netstat -ano & pause & goto menu_live_monitor)
if "%c%"=="07" (powershell -NoProfile -Command "Get-CimInstance Win32_OperatingSystem | Select @{n='FreeRAMGB';e={[math]::Round($_.FreePhysicalMemory/1MB,2)}},@{n='TotalRAMGB';e={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}}" & pause & goto menu_live_monitor)
if "%c%"=="7" (powershell -NoProfile -Command "Get-CimInstance Win32_OperatingSystem | Select @{n='FreeRAMGB';e={[math]::Round($_.FreePhysicalMemory/1MB,2)}},@{n='TotalRAMGB';e={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}}" & pause & goto menu_live_monitor)
if "%c%"=="08" goto issue_boot_perf
if "%c%"=="8" goto issue_boot_perf
if "%c%"=="09" goto menu_hacker_dashboard
if "%c%"=="9" goto menu_hacker_dashboard
if "%c%"=="10" goto sysreport
if "%c%"=="11" goto quick_health_report
if "%c%"=="12" goto issue_complete_report
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_live_monitor

:menu_event_logs
set "BACK_MENU=menu_event_logs"
cls
color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [18] EVENT VIEWER ^& LOG ANALYZER ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Event Log Analyzer                        [02] Event Viewer GUI                          [03] Critical System Events                    %C_RESET%
echo %C_GREEN%  [04] BSOD Events                               [05] Security Events                           [06] Service Failure Events                    %C_RESET%
echo %C_GREEN%  [07] Task Scheduler Events                     [08] Export Event Logs                         [09] Reliability Monitor                       %C_RESET%
echo %C_GREEN%  [10] Boot Performance                          [11] Complete Issue Report                     [12] Open Logs Folder                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto event_log
if "%c%"=="1" goto event_log
if "%c%"=="02" (start "" eventvwr.msc & pause & goto menu_event_logs)
if "%c%"=="2" (start "" eventvwr.msc & goto menu_event_logs)
if "%c%"=="03" (powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName='System'; Level=1; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue | Select -First 20 TimeCreated,Id,ProviderName,Message | Format-List" & pause & goto menu_event_logs)
if "%c%"=="3" (powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName='System'; Level=1; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue | Select -First 20 TimeCreated,Id,ProviderName,Message | Format-List" & pause & goto menu_event_logs)
if "%c%"=="04" (powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,1001,6008} -ErrorAction SilentlyContinue | Select -First 20 TimeCreated,Id,ProviderName,Message | Format-List" & pause & goto menu_event_logs)
if "%c%"=="4" (powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,1001,6008} -ErrorAction SilentlyContinue | Select -First 20 TimeCreated,Id,ProviderName,Message | Format-List" & pause & goto menu_event_logs)
if "%c%"=="05" goto issue_security_events
if "%c%"=="5" goto issue_security_events
if "%c%"=="06" goto issue_services_diag
if "%c%"=="6" goto issue_services_diag
if "%c%"=="07" goto issue_tasks_diag
if "%c%"=="7" goto issue_tasks_diag
if "%c%"=="08" goto issue_event_export
if "%c%"=="8" goto issue_event_export
if "%c%"=="09" (start "" perfmon /rel & pause & goto menu_event_logs)
if "%c%"=="9" (start "" perfmon /rel & goto menu_event_logs)
if "%c%"=="10" goto issue_boot_perf
if "%c%"=="11" goto issue_complete_report
if "%c%"=="12" (explorer "%LOGROOT%" & goto menu_event_logs)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_event_logs

:menu_quick_access
set "BACK_MENU=menu_quick_access"
cls
color 0F
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [19] QUICK ACCESS UTILITIES ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Quick Tools                               [02] Smart Fix Wizard                          [03] Complete Issue Library                    %C_RESET%
echo %C_GREEN%  [04] System Report                             [05] Health Dashboard                          [06] Toolkit Utilities                         %C_RESET%
echo %C_GREEN%  [07] Create Restore Point                      [08] Open Log Center                           [09] Control Panel                             %C_RESET%
echo %C_GREEN%  [10] Settings Home                             [11] Device Manager                            [12] Task Manager                              %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto quicktools
if "%c%"=="1" goto quicktools
if "%c%"=="02" goto smartfix
if "%c%"=="2" goto smartfix
if "%c%"=="03" goto issue_library
if "%c%"=="3" goto issue_library
if "%c%"=="04" goto sysreport
if "%c%"=="4" goto sysreport
if "%c%"=="05" goto health_dashboard
if "%c%"=="5" goto health_dashboard
if "%c%"=="06" goto toolkit_utilities
if "%c%"=="6" goto toolkit_utilities
if "%c%"=="07" goto create_restore_point
if "%c%"=="7" goto create_restore_point
if "%c%"=="08" goto open_log_center
if "%c%"=="8" goto open_log_center
if "%c%"=="09" (start "" control & pause & goto menu_quick_access)
if "%c%"=="9" (start "" control & goto menu_quick_access)
if "%c%"=="10" (start "" ms-settings: & pause & goto menu_quick_access)
if "%c%"=="11" (start "" devmgmt.msc & pause & goto menu_quick_access)
if "%c%"=="12" (start "" taskmgr & pause & goto menu_quick_access)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_quick_access

:menu_power_user_dev
set "BACK_MENU=menu_power_user_dev"
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [20] POWER USER / DEV TOOLS ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Hyper-V / WSL Tools                       [02] Windows Terminal / CMD                    [03] PowerShell Console                        %C_RESET%
echo %C_GREEN%  [04] Environment Variables                     [05] Scheduled Tasks                           [06] Services Manager                          %C_RESET%
echo %C_GREEN%  [07] Event Viewer                              [08] Registry Editor                           [09] 5000+ Software Search                     %C_RESET%
echo %C_GREEN%  [10] Windows Features                          [11] Developer Settings                        [12] System Information                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto hyperv_wsl
if "%c%"=="1" goto hyperv_wsl
if "%c%"=="02" (start "" cmd.exe & pause & goto menu_power_user_dev)
if "%c%"=="2" (start "" cmd.exe & goto menu_power_user_dev)
if "%c%"=="03" (start "" powershell.exe & pause & goto menu_power_user_dev)
if "%c%"=="3" (start "" powershell.exe & goto menu_power_user_dev)
if "%c%"=="04" goto env_vars
if "%c%"=="4" goto env_vars
if "%c%"=="05" goto sched_tasks
if "%c%"=="5" goto sched_tasks
if "%c%"=="06" (start "" services.msc & pause & goto menu_power_user_dev)
if "%c%"=="6" (start "" services.msc & goto menu_power_user_dev)
if "%c%"=="07" (start "" eventvwr.msc & pause & goto menu_power_user_dev)
if "%c%"=="7" (start "" eventvwr.msc & goto menu_power_user_dev)
if "%c%"=="08" (start "" regedit & pause & goto menu_power_user_dev)
if "%c%"=="8" (start "" regedit & goto menu_power_user_dev)
if "%c%"=="09" goto winget_installer
if "%c%"=="9" goto winget_installer
if "%c%"=="10" (start "" optionalfeatures & pause & goto menu_power_user_dev)
if "%c%"=="11" (start "" ms-settings:developers & pause & goto menu_power_user_dev)
if "%c%"=="12" (start "" msinfo32 & pause & goto menu_power_user_dev)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_power_user_dev

:menu_ai_auto_fix
set "BACK_MENU=menu_ai_auto_fix"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [21] AI SMART AUTO FIX ENGINE ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Smart Fix Wizard                          [02] Complete Issue Library                    [03] Create Restore Point First                %C_RESET%
echo %C_GREEN%  [04] Auto Network Engine                       [05] Auto Performance Engine                   [06] Windows Repair Engine                     %C_RESET%
echo %C_GREEN%  [07] Printer Fix Engine                        [08] Browser / Cloud Engine                    [09] Security Engine                           %C_RESET%
echo %C_GREEN%  [10] Deep Diagnostics                          [11] Quick Health Report                       [12] Full System Report                        %C_RESET%
echo %C_GREEN%  [13] Windows AI Enable / Disable Controls      %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto smartfix
if "%c%"=="1" goto smartfix
if "%c%"=="02" goto issue_library
if "%c%"=="2" goto issue_library
if "%c%"=="03" goto create_restore_point
if "%c%"=="3" goto create_restore_point
if "%c%"=="04" goto menu_auto_network
if "%c%"=="4" goto menu_auto_network
if "%c%"=="05" goto menu_auto_performance
if "%c%"=="5" goto menu_auto_performance
if "%c%"=="06" goto one_click_repair
if "%c%"=="6" goto one_click_repair
if "%c%"=="07" goto issue_printer_pro
if "%c%"=="7" goto issue_printer_pro
if "%c%"=="08" goto issue_browser_cloud
if "%c%"=="8" goto issue_browser_cloud
if "%c%"=="09" goto issue_security_privacy
if "%c%"=="9" goto issue_security_privacy
if "%c%"=="10" goto issue_deep_diagnostics
if "%c%"=="11" goto quick_health_report
if "%c%"=="12" goto sysreport
if "%c%"=="13" goto windows_ai_controls
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_ai_auto_fix

:menu_auto_performance
set "BACK_MENU=menu_auto_performance"
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [22] AUTO PERFORMANCE BOOSTER ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Safe Speed Booster                        [02] Full Cleanup                              [03] RAM Optimizer                             %C_RESET%
echo %C_GREEN%  [04] Visual Performance Mode                   [05] Startup Review                            [06] Indexing Settings                         %C_RESET%
echo %C_GREEN%  [07] Disk Optimize                             [08] Power Plan Booster                        [09] Energy Report                             %C_RESET%
echo %C_GREEN%  [10] Boot Performance Events                   [11] Live Monitor                              [12] Quick Health Report                       %C_RESET%
echo %C_GREEN%  [13] 1 Click Minimum PC Boost                  [14] Disable Boost / Restore Normal            %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto speed_booster
if "%c%"=="1" goto speed_booster
if "%c%"=="02" goto sys_cleanup
if "%c%"=="2" goto sys_cleanup
if "%c%"=="03" goto ram_optimizer
if "%c%"=="3" goto ram_optimizer
if "%c%"=="04" goto visual_effects
if "%c%"=="4" goto visual_effects
if "%c%"=="05" goto startup_mgr
if "%c%"=="5" goto startup_mgr
if "%c%"=="06" goto win_indexing
if "%c%"=="6" goto win_indexing
if "%c%"=="07" goto disk_defrag
if "%c%"=="7" goto disk_defrag
if "%c%"=="08" goto power_mgmt
if "%c%"=="8" goto power_mgmt
if "%c%"=="09" goto issue_energy_report
if "%c%"=="9" goto issue_energy_report
if "%c%"=="10" goto issue_boot_perf
if "%c%"=="11" goto menu_live_monitor
if "%c%"=="12" goto quick_health_report
if "%c%"=="13" goto performance_minimum_boost
if "%c%"=="14" goto performance_boost_restore
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_auto_performance

:windows_ai_controls
set "BACK_MENU=windows_ai_controls"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% WINDOWS AI / COPILOT / RECALL ENABLE-DISABLE CENTER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Windows AI Status                         [02] Disable All Windows AI Extras            [03] Enable / Restore Windows AI Choice       %C_RESET%
echo %C_GREEN%  [04] Disable Copilot                            [05] Enable Copilot                           [06] Disable Recall Snapshots                 %C_RESET%
echo %C_GREEN%  [07] Enable Recall User Choice                  [08] Disable Bing / Web Search in Start       [09] Enable Bing / Web Search in Start        %C_RESET%
echo %C_GREEN%  [10] Disable Widgets / News                     [11] Enable Widgets / News                    [12] Disable AI Suggestions / Consumer Tips   %C_RESET%
echo %C_GREEN%  [13] Enable Suggestions / Consumer Tips         [14] Open AI / Privacy Settings               %C_RESET%
echo.
echo %C_YELLOW%  NOTE: Recall enable only restores user choice; Windows still needs supported hardware and user opt-in.%C_RESET%
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back to AI Menu                    [00] Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto windows_ai_status
if "%c%"=="1" goto windows_ai_status
if "%c%"=="02" goto windows_ai_disable_all
if "%c%"=="2" goto windows_ai_disable_all
if "%c%"=="03" goto windows_ai_enable_all
if "%c%"=="3" goto windows_ai_enable_all
if "%c%"=="04" goto windows_ai_disable_copilot
if "%c%"=="4" goto windows_ai_disable_copilot
if "%c%"=="05" goto windows_ai_enable_copilot
if "%c%"=="5" goto windows_ai_enable_copilot
if "%c%"=="06" goto windows_ai_disable_recall
if "%c%"=="6" goto windows_ai_disable_recall
if "%c%"=="07" goto windows_ai_enable_recall
if "%c%"=="7" goto windows_ai_enable_recall
if "%c%"=="08" goto windows_ai_disable_websearch
if "%c%"=="8" goto windows_ai_disable_websearch
if "%c%"=="09" goto windows_ai_enable_websearch
if "%c%"=="9" goto windows_ai_enable_websearch
if "%c%"=="10" goto windows_ai_disable_widgets
if "%c%"=="11" goto windows_ai_enable_widgets
if "%c%"=="12" goto windows_ai_disable_suggestions
if "%c%"=="13" goto windows_ai_enable_suggestions
if "%c%"=="14" (start "" ms-settings:privacy & start "" ms-settings:privacy-diagnosticsfeedback & goto windows_ai_controls)
if "%c%"=="99" goto menu_ai_auto_fix
if "%c%"=="00" goto main
goto windows_ai_controls

:windows_ai_status
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% WINDOWS AI STATUS%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo.
echo === COPILOT POLICY ===
reg query "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot
echo.
echo === RECALL / WINDOWS AI POLICY ===
reg query "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis
echo.
echo === WEB SEARCH / BING ===
reg query "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled
echo.
echo === WIDGETS / NEWS ===
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa
reg query "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests
echo.
echo === CONSUMER / SUGGESTIONS ===
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DisableTailoredExperiencesWithDiagnosticData
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage -AllUsers *Copilot* -ErrorAction SilentlyContinue | Select Name,PackageFullName | Format-Table -AutoSize"
pause
goto windows_ai_controls

:windows_ai_disable_all
cls
echo This will disable Copilot policy, Recall snapshots, Bing web search suggestions,
echo Widgets news entry, consumer suggestions, and tailored experiences.
set "ok=" & set /p ok=Type YES to disable Windows AI extras:
if /i not "!ok!"=="YES" goto windows_ai_controls
call :windows_ai_apply_disable
pause
goto windows_ai_controls

:windows_ai_enable_all
cls
echo This will enable / restore Windows AI choices. Recall still requires supported hardware and user opt-in.
set "ok=" & set /p ok=Type YES to enable / restore Windows AI choices:
if /i not "!ok!"=="YES" goto windows_ai_controls
call :windows_ai_apply_enable
pause
goto windows_ai_controls

:windows_ai_disable_copilot
call :windows_ai_policy_copilot_disable
pause
goto windows_ai_controls

:windows_ai_enable_copilot
call :windows_ai_policy_copilot_enable
pause
goto windows_ai_controls

:windows_ai_disable_recall
call :windows_ai_policy_recall_disable
pause
goto windows_ai_controls

:windows_ai_enable_recall
call :windows_ai_policy_recall_enable
pause
goto windows_ai_controls

:windows_ai_disable_websearch
call :windows_ai_policy_websearch_disable
pause
goto windows_ai_controls

:windows_ai_enable_websearch
call :windows_ai_policy_websearch_enable
pause
goto windows_ai_controls

:windows_ai_disable_widgets
call :windows_ai_policy_widgets_disable
pause
goto windows_ai_controls

:windows_ai_enable_widgets
call :windows_ai_policy_widgets_enable
pause
goto windows_ai_controls

:windows_ai_disable_suggestions
call :windows_ai_policy_suggestions_disable
pause
goto windows_ai_controls

:windows_ai_enable_suggestions
call :windows_ai_policy_suggestions_enable
pause
goto windows_ai_controls

:windows_ai_apply_disable
call :windows_ai_policy_copilot_disable
call :windows_ai_policy_recall_disable
call :windows_ai_policy_websearch_disable
call :windows_ai_policy_widgets_disable
call :windows_ai_policy_suggestions_disable
echo.
echo Windows AI extras disabled. Sign out or restart Explorer/PC for full effect.
exit /b

:windows_ai_apply_enable
call :windows_ai_policy_copilot_enable
call :windows_ai_policy_recall_enable
call :windows_ai_policy_websearch_enable
call :windows_ai_policy_widgets_enable
call :windows_ai_policy_suggestions_enable
echo.
echo Windows AI choices restored. Some features require supported Windows build, region, hardware, and user opt-in.
exit /b

:windows_ai_policy_copilot_disable
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f
echo Copilot policy disabled.
exit /b

:windows_ai_policy_copilot_enable
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 0 /f
echo Copilot policy enabled/restored.
exit /b

:windows_ai_policy_recall_disable
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f
echo Recall snapshots disabled by WindowsAI policy.
exit /b

:windows_ai_policy_recall_enable
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 0 /f
echo Recall user choice enabled/restored by WindowsAI policy.
exit /b

:windows_ai_policy_websearch_disable
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /t REG_DWORD /d 0 /f
echo Bing / web search suggestions disabled.
exit /b

:windows_ai_policy_websearch_enable
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 0 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /t REG_DWORD /d 1 /f
echo Bing / web search suggestions enabled/restored.
exit /b

:windows_ai_policy_widgets_disable
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f
echo Widgets / news disabled.
exit /b

:windows_ai_policy_widgets_enable
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 1 /f
echo Widgets / news enabled/restored.
exit /b

:windows_ai_policy_suggestions_disable
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 1 /f
echo AI suggestions / consumer tips disabled.
exit /b

:windows_ai_policy_suggestions_enable
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 0 /f
echo AI suggestions / consumer tips enabled/restored.
exit /b

:performance_minimum_boost
set "BACK_MENU=performance_minimum_boost"
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% 1 CLICK MINIMUM PC BOOST - ENABLE / DISABLE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Enable Minimum Requirement Boost            [02] Disable Boost / Restore Normal            [03] Boost Status Report                       %C_RESET%
echo.
echo %C_YELLOW%  Enable mode keeps Windows usable with minimum visuals/services. Security services are not disabled.%C_RESET%
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back to Performance Menu             [00] Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto performance_minimum_boost_enable
if "%c%"=="1" goto performance_minimum_boost_enable
if "%c%"=="02" goto performance_boost_restore
if "%c%"=="2" goto performance_boost_restore
if "%c%"=="03" goto performance_boost_status
if "%c%"=="3" goto performance_boost_status
if "%c%"=="99" goto menu_performance_optimization
if "%c%"=="00" goto main
goto performance_minimum_boost

:performance_minimum_boost_enable
cls
echo This will apply low-resource performance settings:
echo - High performance power plan
echo - Best performance visual effects
echo - Transparency and taskbar animations off
echo - Background apps reduced
echo - SysMain, Windows Search, and Diagnostics Tracking stopped/disabled
echo - Temp cleanup and DNS flush
echo.
set "ok=" & set /p ok=Type YES to enable 1 Click Minimum PC Boost:
if /i not "!ok!"=="YES" goto performance_minimum_boost
echo.
powercfg /setactive SCHEME_MIN
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f
sc stop SysMain >nul 2>&1
sc config SysMain start= disabled
sc stop WSearch >nul 2>&1
sc config WSearch start= disabled
sc stop DiagTrack >nul 2>&1
sc config DiagTrack start= disabled
call :clean_folder_contents "%TEMP%" "User Temp"
call :clean_folder_contents "C:\Windows\Temp" "Windows Temp"
ipconfig /flushdns >nul 2>&1
echo.
echo Minimum PC Boost enabled. Restart PC for full effect.
pause
goto performance_minimum_boost

:performance_boost_restore
cls
echo This will restore normal Windows performance settings and services.
set "ok=" & set /p ok=Type YES to disable boost / restore normal:
if /i not "!ok!"=="YES" goto performance_minimum_boost
echo.
powercfg /setactive SCHEME_BALANCED
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 1 /f
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 400 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 0 /f
sc config SysMain start= auto
net start SysMain >nul 2>&1
sc config WSearch start= delayed-auto
net start WSearch >nul 2>&1
sc config DiagTrack start= auto
net start DiagTrack >nul 2>&1
echo.
echo Boost disabled / normal settings restored. Restart PC for full effect.
pause
goto performance_minimum_boost

:performance_boost_status
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% PERFORMANCE BOOST STATUS%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo.
echo === ACTIVE POWER PLAN ===
powercfg /getactivescheme
echo.
echo === VISUAL / BACKGROUND SETTINGS ===
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled
echo.
echo === SERVICE STATES ===
sc query SysMain
sc qc SysMain
sc query WSearch
sc qc WSearch
sc query DiagTrack
sc qc DiagTrack
pause
goto performance_minimum_boost

:menu_auto_network
set "BACK_MENU=menu_auto_network"
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [23] AUTO NETWORK REPAIR ENGINE ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Smart Internet Fix                        [02] DNS Full Repair                           [03] DHCP / APIPA Fix                          %C_RESET%
echo %C_GREEN%  [04] Proxy / VPN Reset                         [05] TCP/IP Advanced Reset                     [06] WiFi Missing Fix                          %C_RESET%
echo %C_GREEN%  [07] Network Adapter Rebuild                   [08] SMB / NAS Diagnostics                     [09] Firewall Net Check                        %C_RESET%
echo %C_GREEN%  [10] Network Report                            [11] Network Diagnostics                       [12] Advanced Network Tools                    %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto smart_internet
if "%c%"=="1" goto smart_internet
if "%c%"=="02" goto issue_dns_full
if "%c%"=="2" goto issue_dns_full
if "%c%"=="03" goto issue_apipa_fix
if "%c%"=="3" goto issue_apipa_fix
if "%c%"=="04" goto issue_proxy_vpn
if "%c%"=="4" goto issue_proxy_vpn
if "%c%"=="05" goto issue_tcp_advanced
if "%c%"=="5" goto issue_tcp_advanced
if "%c%"=="06" goto issue_wifi_missing
if "%c%"=="6" goto issue_wifi_missing
if "%c%"=="07" goto issue_adapter_rebuild
if "%c%"=="7" goto issue_adapter_rebuild
if "%c%"=="08" goto issue_smb_nas
if "%c%"=="8" goto issue_smb_nas
if "%c%"=="09" goto issue_firewall_net_check
if "%c%"=="9" goto issue_firewall_net_check
if "%c%"=="10" goto issue_network_report
if "%c%"=="11" goto net_diag
if "%c%"=="12" goto net_advanced
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_auto_network

:menu_cloud_remote
set "BACK_MENU=menu_cloud_remote"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [24] CLOUD ^& REMOTE MANAGEMENT ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] OneDrive Reset                            [02] OneDrive Settings                         [03] RDP Tools                                 %C_RESET%
echo %C_GREEN%  [04] Remote Desktop Settings                   [05] VPN Tools                                 [06] Network Shares                            %C_RESET%
echo %C_GREEN%  [07] Credential Manager                        [08] SMB / NAS Diagnostics                     [09] Microsoft Account                         %C_RESET%
echo %C_GREEN%  [10] Work / School Account                     [11] Sync Settings                             [12] Browser / Cloud Issues                    %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto issue_onedrive_reset
if "%c%"=="1" goto issue_onedrive_reset
if "%c%"=="02" (start "" ms-settings:sync & pause & goto menu_cloud_remote)
if "%c%"=="2" (start "" ms-settings:sync & goto menu_cloud_remote)
if "%c%"=="03" goto rdp_tools
if "%c%"=="3" goto rdp_tools
if "%c%"=="04" (start "" ms-settings:remotedesktop & pause & goto menu_cloud_remote)
if "%c%"=="4" (start "" ms-settings:remotedesktop & goto menu_cloud_remote)
if "%c%"=="05" goto vpn_proxy
if "%c%"=="5" goto vpn_proxy
if "%c%"=="06" goto net_shares
if "%c%"=="6" goto net_shares
if "%c%"=="07" (control /name Microsoft.CredentialManager & pause & goto menu_cloud_remote)
if "%c%"=="7" (control /name Microsoft.CredentialManager & goto menu_cloud_remote)
if "%c%"=="08" goto issue_smb_nas
if "%c%"=="8" goto issue_smb_nas
if "%c%"=="09" (start "" ms-settings:emailandaccounts & pause & goto menu_cloud_remote)
if "%c%"=="9" (start "" ms-settings:emailandaccounts & goto menu_cloud_remote)
if "%c%"=="10" (start "" ms-settings:workplace & pause & goto menu_cloud_remote)
if "%c%"=="11" (start "" ms-settings:sync & pause & goto menu_cloud_remote)
if "%c%"=="12" goto issue_browser_cloud
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_cloud_remote

:menu_download_deploy
set "BACK_MENU=menu_download_deploy"
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [25] DOWNLOAD ^& DEPLOYMENT CENTER ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] OS Download Center                        [02] Office Download Center                    [03] 5000+ Software Library                    %C_RESET%
echo %C_GREEN%  [04] Mass / Pack Installer                     [05] Driver Tools                              [06] Windows Features                          %C_RESET%
echo %C_GREEN%  [07] App Installer Health                      [08] Installed Apps Inventory                  [09] Windows Update Settings                   %C_RESET%
echo %C_GREEN%  [10] Microsoft Store Repair                    [11] Deployment / Dev Tools                    [12] Download Folder                           %C_RESET%
echo %C_GREEN%  [13] .NET Download + Install                   %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto os_download
if "%c%"=="1" goto os_download
if "%c%"=="02" goto office_download
if "%c%"=="2" goto office_download
if "%c%"=="03" goto winget_installer
if "%c%"=="3" goto winget_installer
if "%c%"=="04" goto menu_mass_installer
if "%c%"=="4" goto menu_mass_installer
if "%c%"=="05" goto driver_tools
if "%c%"=="5" goto driver_tools
if "%c%"=="06" (start "" optionalfeatures & pause & goto menu_download_deploy)
if "%c%"=="6" (start "" optionalfeatures & goto menu_download_deploy)
if "%c%"=="07" (set "WINGET_HEALTH_RETURN=menu_download_deploy" & goto issue_winget_health)
if "%c%"=="7" (set "WINGET_HEALTH_RETURN=menu_download_deploy" & goto issue_winget_health)
if "%c%"=="08" goto issue_apps_inventory
if "%c%"=="8" goto issue_apps_inventory
if "%c%"=="09" (start "" ms-settings:windowsupdate & pause & goto menu_download_deploy)
if "%c%"=="9" (start "" ms-settings:windowsupdate & goto menu_download_deploy)
if "%c%"=="10" goto issue_store_repair
if "%c%"=="11" goto menu_power_user_dev
if "%c%"=="12" (explorer "%USERPROFILE%\Downloads" & pause & goto menu_download_deploy)
if "%c%"=="13" goto dotnet_download_install
if "%c%"=="99" goto menu_download_back
if "%c%"=="00" goto main
goto menu_download_deploy

:menu_download_back
if defined DOWNLOAD_RETURN (
    set "DOWNLOAD_BACK=!DOWNLOAD_RETURN!"
    set "DOWNLOAD_RETURN="
    set "SAFE_TARGET=!DOWNLOAD_BACK!"
    goto safe_goto
)
goto main

:dotnet_download_install
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% .NET DOWNLOAD + INSTALL CENTER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_YELLOW% Installed .NET versions on this PC:%C_RESET%
where dotnet >nul 2>&1
if errorlevel 1 (
    echo dotnet command not found.
) else (
    dotnet --list-runtimes
    dotnet --list-sdks
)
echo.
echo %C_YELLOW% Available .NET packages from winget:%C_RESET%
where winget >nul 2>&1
if errorlevel 1 (
    echo Winget not found. Use option [8] to open official .NET download page.
) else (
    winget search Microsoft.DotNet --accept-source-agreements
)
echo.
echo %C_GREEN%  [1] Install .NET Desktop Runtime 8 LTS         [2] Install .NET SDK 8 LTS                     [3] Install ASP.NET Core Runtime 8             %C_RESET%
echo %C_GREEN%  [4] Install .NET Desktop Runtime 10 LTS        [5] Install .NET SDK 10 LTS                    [6] Install ASP.NET Core Runtime 10            %C_RESET%
echo %C_GREEN%  [7] Install custom winget .NET package ID      [8] Open official .NET download page           %C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Download Center                 [00] Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="1" (call :winget_install_id Microsoft.DotNet.DesktopRuntime.8 & pause & goto dotnet_download_install)
if "%c%"=="2" (call :winget_install_id Microsoft.DotNet.SDK.8 & pause & goto dotnet_download_install)
if "%c%"=="3" (call :winget_install_id Microsoft.DotNet.AspNetCore.8 & pause & goto dotnet_download_install)
if "%c%"=="4" (call :winget_install_id Microsoft.DotNet.DesktopRuntime.10 & pause & goto dotnet_download_install)
if "%c%"=="5" (call :winget_install_id Microsoft.DotNet.SDK.10 & pause & goto dotnet_download_install)
if "%c%"=="6" (call :winget_install_id Microsoft.DotNet.AspNetCore.10 & pause & goto dotnet_download_install)
if "%c%"=="7" goto dotnet_custom_install
if "%c%"=="8" (start "" "https://dotnet.microsoft.com/download/dotnet" & pause & goto dotnet_download_install)
if "%c%"=="99" goto menu_download_deploy
if "%c%"=="00" goto main
goto dotnet_download_install

:dotnet_custom_install
cls
echo Enter exact winget package ID from the .NET list, example:
echo Microsoft.DotNet.DesktopRuntime.8
echo Microsoft.DotNet.SDK.8
echo Microsoft.DotNet.DesktopRuntime.10
echo.
set "DOTNET_ID=" & set /p DOTNET_ID=Package ID: 
if not defined DOTNET_ID goto dotnet_download_install
call :winget_install_id "%DOTNET_ID%"
pause
goto dotnet_download_install

:menu_cyber_security
set "BACK_MENU=menu_cyber_security"
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [26] CYBER SECURITY TOOLKIT ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Security ^& Privacy Issues                [02] Defender Dashboard                        [03] Quick Scan                                %C_RESET%
echo %C_GREEN%  [04] Full Scan                                 [05] Offline Scan                              [06] Firewall Reset                            %C_RESET%
echo %C_GREEN%  [07] Network Security                          [08] USB Security                              [09] BitLocker Status                          %C_RESET%
echo %C_GREEN%  [10] Security Events                           [11] Credential Manager                        [12] Privacy Hub                               %C_RESET%
echo %C_GREEN%  [13] Save Your PC From Hacking                 %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto issue_security_privacy
if "%c%"=="1" goto issue_security_privacy
if "%c%"=="02" (start "" windowsdefender: & pause & goto menu_cyber_security)
if "%c%"=="2" (start "" windowsdefender: & goto menu_cyber_security)
if "%c%"=="03" (powershell -NoProfile -Command "Start-MpScan -ScanType QuickScan" & pause & goto menu_cyber_security)
if "%c%"=="3" (powershell -NoProfile -Command "Start-MpScan -ScanType QuickScan" & pause & goto menu_cyber_security)
if "%c%"=="04" (powershell -NoProfile -Command "Start-MpScan -ScanType FullScan" & pause & goto menu_cyber_security)
if "%c%"=="4" (powershell -NoProfile -Command "Start-MpScan -ScanType FullScan" & pause & goto menu_cyber_security)
if "%c%"=="05" goto issue_defender_offline
if "%c%"=="5" goto issue_defender_offline
if "%c%"=="06" goto issue_firewall_reset
if "%c%"=="6" goto issue_firewall_reset
if "%c%"=="07" goto net_security
if "%c%"=="7" goto net_security
if "%c%"=="08" goto usb_security
if "%c%"=="8" goto usb_security
if "%c%"=="09" (manage-bde -status & pause & goto menu_cyber_security)
if "%c%"=="9" (manage-bde -status & pause & goto menu_cyber_security)
if "%c%"=="10" goto issue_security_events
if "%c%"=="11" (control /name Microsoft.CredentialManager & pause & goto menu_cyber_security)
if "%c%"=="12" (start "" ms-settings:privacy & pause & goto menu_cyber_security)
if "%c%"=="13" goto cyber_pc_guard
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_cyber_security

:cyber_pc_guard
set "BACK_MENU=cyber_pc_guard"
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [26.13] SAVE YOUR PC FROM HACKING - DEFENSIVE CHECKUP%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Quick PC Security Health                    [02] Defender Status ^& Threats                 [03] Firewall Profiles ^& Rules                 %C_RESET%
echo %C_GREEN%  [04] Open Ports + Process Names                  [05] Suspicious Connections Review              [06] Failed Login / Brute Force Detector        %C_RESET%
echo %C_GREEN%  [07] Recent Successful Logins                    [08] Admin Users + Password Policy              [09] RDP / Remote Exposure Check                %C_RESET%
echo %C_GREEN%  [10] Startup + Scheduled Task Audit              [11] Hosts / DNS / Proxy Tamper Check           [12] Safe Target Ping Test (No Flood)           %C_RESET%
echo %C_GREEN%  [13] SMB Shares + Guest + SMBv1 Check            [14] Browser / Download Risk Check              [15] BitLocker + Encryption Check               %C_RESET%
echo %C_GREEN%  [16] One Click Basic Hardening                   [17] Export Full Cyber Security Report          [18] Open Security Logs Folder                  %C_RESET%
echo.
echo %C_YELLOW%  NOTE: Flood ping and brute-force attack tools are not included. This menu detects exposure and hardens your own PC safely.%C_RESET%
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back to Cyber Toolkit              [00] Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto cyber_pc_guard_health
if "%c%"=="1" goto cyber_pc_guard_health
if "%c%"=="02" goto cyber_pc_guard_defender
if "%c%"=="2" goto cyber_pc_guard_defender
if "%c%"=="03" goto cyber_pc_guard_firewall
if "%c%"=="3" goto cyber_pc_guard_firewall
if "%c%"=="04" goto cyber_pc_guard_ports
if "%c%"=="4" goto cyber_pc_guard_ports
if "%c%"=="05" goto cyber_pc_guard_connections
if "%c%"=="5" goto cyber_pc_guard_connections
if "%c%"=="06" goto cyber_pc_guard_failed_logins
if "%c%"=="6" goto cyber_pc_guard_failed_logins
if "%c%"=="07" goto cyber_pc_guard_success_logins
if "%c%"=="7" goto cyber_pc_guard_success_logins
if "%c%"=="08" goto cyber_pc_guard_accounts
if "%c%"=="8" goto cyber_pc_guard_accounts
if "%c%"=="09" goto cyber_pc_guard_rdp
if "%c%"=="9" goto cyber_pc_guard_rdp
if "%c%"=="10" goto cyber_pc_guard_startup
if "%c%"=="11" goto cyber_pc_guard_tamper
if "%c%"=="12" goto cyber_pc_guard_safe_ping
if "%c%"=="13" goto cyber_pc_guard_smb
if "%c%"=="14" goto cyber_pc_guard_browser
if "%c%"=="15" goto cyber_pc_guard_bitlocker
if "%c%"=="16" goto cyber_pc_guard_harden
if "%c%"=="17" goto cyber_pc_guard_export
if "%c%"=="18" (if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1 & explorer "%LOGROOT%" & goto cyber_pc_guard)
if "%c%"=="99" goto menu_cyber_security
if "%c%"=="00" goto main
goto cyber_pc_guard

:cyber_pc_guard_health
cls
color 0C
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% QUICK PC SECURITY HEALTH%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo.
echo === ADMIN USERS ===
net localgroup Administrators
echo.
echo === PASSWORD / LOCKOUT POLICY ===
net accounts
echo.
echo === FIREWALL STATE ===
netsh advfirewall show allprofiles state
echo.
echo === DEFENDER CORE STATUS ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-MpComputerStatus | Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,IoavProtectionEnabled,NISEnabled,AntispywareSignatureLastUpdated | Format-List } catch { Write-Host ('Defender status unavailable: ' + $_.Exception.Message) }"
echo.
echo === LISTENING PORTS ===
netstat -an | findstr LISTENING
echo.
echo === RECENT FAILED LOGINS (LAST 7 DAYS) ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-WinEvent -FilterHashtable @{LogName='Security';Id=4625;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 20 -ErrorAction Stop | Select-Object TimeCreated,Id,@{n='Account';e={if($_.Properties.Count -gt 5){$_.Properties[5].Value}else{''}}},@{n='SourceIP';e={if($_.Properties.Count -gt 19){$_.Properties[19].Value}else{''}}} | Format-Table -AutoSize } catch { Write-Host 'No failed login events found or Security log access unavailable.' }"
echo.
echo === STARTUP PROGRAMS ===
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
echo.
echo Review anything unknown above. Use option 17 to save a full report.
pause
goto cyber_pc_guard

:cyber_pc_guard_defender
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% DEFENDER STATUS ^& THREAT HISTORY%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Write-Host '=== Defender Status ==='; Get-MpComputerStatus | Format-List; Write-Host ''; Write-Host '=== Defender Preferences ==='; Get-MpPreference | Select-Object DisableRealtimeMonitoring,PUAProtection,MAPSReporting,SubmitSamplesConsent,EnableNetworkProtection,ExclusionPath,ExclusionProcess | Format-List; Write-Host ''; Write-Host '=== Recent Threat Detections ==='; Get-MpThreatDetection | Select-Object -First 30 | Format-List } catch { Write-Host ('Defender query failed: ' + $_.Exception.Message) }"
pause
goto cyber_pc_guard

:cyber_pc_guard_firewall
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% FIREWALL PROFILES ^& RULES%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
netsh advfirewall show allprofiles
echo.
echo === PowerShell Firewall Profile Summary ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction,NotifyOnListen,LogFileName | Format-Table -AutoSize; Write-Host ''; Write-Host '=== Enabled inbound allow rules (first 60) ==='; Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow | Select-Object -First 60 DisplayName,Profile,Direction,Action | Format-Table -AutoSize } catch { Write-Host ('Firewall query failed: ' + $_.Exception.Message) }"
pause
goto cyber_pc_guard

:cyber_pc_guard_ports
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% OPEN PORTS WITH PROCESS NAMES%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $proc=Get-Process | Group-Object Id -AsHashTable -AsString; Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,State,OwningProcess,@{n='Process';e={$id=[string]$_.OwningProcess; if($proc.ContainsKey($id)){$proc[$id].ProcessName}else{'Unknown'}}} | Sort-Object LocalPort | Format-Table -AutoSize } catch { netstat -ano | Select-String LISTENING }"
echo.
echo Tip: Unknown public-facing listening ports should be checked in Task Manager and Firewall rules.
pause
goto cyber_pc_guard

:cyber_pc_guard_connections
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% SUSPICIOUS CONNECTIONS REVIEW%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo Public remote connections are not always bad; review unknown IPs and processes.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $proc=Get-Process | Group-Object Id -AsHashTable -AsString; Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | Where-Object { $_.RemoteAddress -notmatch '^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|::1|0\.0\.0\.0)$' } | Select-Object -First 80 LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess,@{n='Process';e={$id=[string]$_.OwningProcess; if($proc.ContainsKey($id)){$proc[$id].ProcessName}else{'Unknown'}}} | Format-Table -AutoSize } catch { netstat -ano | findstr ESTABLISHED }"
pause
goto cyber_pc_guard

:cyber_pc_guard_failed_logins
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% FAILED LOGIN / BRUTE FORCE DETECTOR%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo This detects failed login attempts on your PC. It does not perform brute force.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $events=Get-WinEvent -FilterHashtable @{LogName='Security';Id=4625;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 300 -ErrorAction Stop; if($events.Count -eq 0){Write-Host 'No failed login events found in the last 7 days.'} else { $rows=$events | Select-Object TimeCreated,@{n='Account';e={if($_.Properties.Count -gt 5){$_.Properties[5].Value}else{''}}},@{n='SourceIP';e={if($_.Properties.Count -gt 19){$_.Properties[19].Value}else{''}}},@{n='Workstation';e={if($_.Properties.Count -gt 13){$_.Properties[13].Value}else{''}}}; Write-Host '=== Top Sources ==='; $rows | Group-Object SourceIP | Sort-Object Count -Descending | Select-Object -First 15 Count,Name | Format-Table -AutoSize; Write-Host ''; Write-Host '=== Recent Failed Logins ==='; $rows | Select-Object -First 60 | Format-Table -AutoSize } } catch { Write-Host ('Security log query failed: ' + $_.Exception.Message) }"
pause
goto cyber_pc_guard

:cyber_pc_guard_success_logins
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% RECENT SUCCESSFUL LOGINS%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-WinEvent -FilterHashtable @{LogName='Security';Id=4624;StartTime=(Get-Date).AddDays(-3)} -MaxEvents 80 -ErrorAction Stop | Select-Object TimeCreated,@{n='Account';e={if($_.Properties.Count -gt 5){$_.Properties[5].Value}else{''}}},@{n='LogonType';e={if($_.Properties.Count -gt 8){$_.Properties[8].Value}else{''}}},@{n='SourceIP';e={if($_.Properties.Count -gt 18){$_.Properties[18].Value}else{''}}} | Format-Table -AutoSize } catch { Write-Host ('Successful login query failed: ' + $_.Exception.Message) }"
pause
goto cyber_pc_guard

:cyber_pc_guard_accounts
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% ADMIN USERS + PASSWORD POLICY%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo === ADMINISTRATORS GROUP ===
net localgroup Administrators
echo.
echo === ALL LOCAL USERS ===
net user
echo.
echo === PASSWORD POLICY ===
net accounts
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Write-Host '=== Local User Details ==='; Get-LocalUser | Select-Object Name,Enabled,LastLogon,PasswordRequired,PasswordLastSet,UserMayChangePassword | Format-Table -AutoSize } catch { Write-Host 'Get-LocalUser unavailable on this Windows edition.' }"
pause
goto cyber_pc_guard

:cyber_pc_guard_rdp
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% RDP / REMOTE EXPOSURE CHECK%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo === RDP Registry State ===
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication
echo.
echo === Port 3389 Listener Check ===
netstat -ano | findstr ":3389"
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Write-Host '=== RDP Firewall Rules ==='; Get-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue | Select-Object DisplayName,Enabled,Profile,Direction,Action | Format-Table -AutoSize; Write-Host ''; Write-Host '=== Remote Desktop Users ==='; Get-LocalGroupMember 'Remote Desktop Users' -ErrorAction SilentlyContinue | Format-Table -AutoSize } catch { Write-Host ('RDP query failed: ' + $_.Exception.Message) }"
pause
goto cyber_pc_guard

:cyber_pc_guard_startup
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% STARTUP + SCHEDULED TASK AUDIT%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo === RUN KEYS HKLM ===
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
echo.
echo === RUN KEYS HKCU ===
reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Write-Host '=== Startup Commands ==='; Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User | Format-Table -AutoSize; Write-Host ''; Write-Host '=== Enabled Scheduled Tasks (first 80) ==='; Get-ScheduledTask | Where-Object State -ne 'Disabled' | Select-Object -First 80 TaskName,TaskPath,State | Format-Table -AutoSize } catch { Write-Host ('Startup audit failed: ' + $_.Exception.Message) }"
pause
goto cyber_pc_guard

:cyber_pc_guard_tamper
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% HOSTS / DNS / PROXY TAMPER CHECK%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo === HOSTS FILE ===
type C:\Windows\System32\drivers\etc\hosts
echo.
echo === WINHTTP PROXY ===
netsh winhttp show proxy
echo.
echo === USER PROXY SETTINGS ===
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer
echo.
echo === DNS SERVER SETTINGS ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-DnsClientServerAddress | Select-Object InterfaceAlias,AddressFamily,ServerAddresses | Format-Table -AutoSize } catch { ipconfig /all }"
pause
goto cyber_pc_guard

:cyber_pc_guard_safe_ping
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% SAFE TARGET CONNECTIVITY TEST - NO FLOOD%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo Use only your own router, server, or an approved target. This runs only 4 pings.
echo.
set "target=" & set /p target=Target IP/Domain:
if "!target!"=="" goto cyber_pc_guard
set "CYBER_TARGET=!target!"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=$env:CYBER_TARGET; if($t -match '[;&|<>]'){Write-Host 'Invalid target characters blocked.'; exit 1}; Write-Host ('Testing target: ' + $t); Write-Host ''; Write-Host '=== Limited Ping ==='; Test-Connection -ComputerName $t -Count 4 -ErrorAction Continue; Write-Host ''; Write-Host '=== Network Summary ==='; try { Test-NetConnection -ComputerName $t -InformationLevel Detailed } catch { Write-Host ('Test-NetConnection failed: ' + $_.Exception.Message) }"
set "CYBER_TARGET="
pause
goto cyber_pc_guard

:cyber_pc_guard_smb
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% SMB SHARES + GUEST + SMBv1 CHECK%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo === LOCAL SHARES ===
net share
echo.
echo === GUEST ACCOUNT ===
net user Guest
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Write-Host '=== SMB Server Configuration ==='; Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol,EnableSMB2Protocol,RejectUnencryptedAccess,EnableSecuritySignature,RequireSecuritySignature | Format-List; Write-Host ''; Write-Host '=== SMB Shares ==='; Get-SmbShare | Select-Object Name,Path,Description,CurrentUsers | Format-Table -AutoSize } catch { Write-Host ('SMB query failed: ' + $_.Exception.Message) }"
pause
goto cyber_pc_guard

:cyber_pc_guard_browser
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% BROWSER / DOWNLOAD RISK CHECK%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo === SMARTSCREEN SETTINGS ===
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v SmartScreenEnabled
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\AppHost" /v EnableWebContentEvaluation
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $dl=Join-Path $env:USERPROFILE 'Downloads'; Write-Host '=== Recent Downloads ==='; Get-ChildItem -LiteralPath $dl -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 30 Name,@{n='MB';e={[math]::Round($_.Length/1MB,2)}},LastWriteTime | Format-Table -AutoSize; Write-Host ''; Write-Host '=== Internet-marked files in Downloads (first 30) ==='; Get-ChildItem -LiteralPath $dl -File -ErrorAction SilentlyContinue | Where-Object { Get-Item -LiteralPath $_.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue } | Select-Object -First 30 FullName,LastWriteTime | Format-Table -AutoSize } catch { Write-Host ('Download risk check failed: ' + $_.Exception.Message) }"
pause
goto cyber_pc_guard

:cyber_pc_guard_bitlocker
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% BITLOCKER + ENCRYPTION CHECK%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
manage-bde -status
echo.
cipher /status
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-Tpm | Format-List } catch { Write-Host 'TPM query unavailable.' }"
pause
goto cyber_pc_guard

:cyber_pc_guard_harden
cls
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% ONE CLICK BASIC HARDENING%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo This will enable Windows Firewall, Defender real-time protection, PUA protection,
echo Defender Network Protection, disable SMBv1, disable Guest, and set lockout threshold to 5.
echo.
set "ok=" & set /p ok=Type YES to apply these defensive settings:
if /i not "!ok!"=="YES" goto cyber_pc_guard
echo.
echo === Enabling Firewall ===
netsh advfirewall set allprofiles state on
echo.
echo === Disabling Guest Account ===
net user Guest /active:no
echo.
echo === Setting Account Lockout Threshold ===
net accounts /lockoutthreshold:5
echo.
echo === Applying Defender / SMB hardening ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Set-MpPreference -DisableRealtimeMonitoring $false; Write-Host 'Real-time protection requested ON.' } catch { Write-Host ('Realtime setting failed: ' + $_.Exception.Message) }; try { Set-MpPreference -PUAProtection Enabled; Write-Host 'PUA protection requested ON.' } catch { Write-Host ('PUA setting failed: ' + $_.Exception.Message) }; try { Set-MpPreference -EnableNetworkProtection Enabled; Write-Host 'Network protection requested ON.' } catch { Write-Host ('Network protection setting failed: ' + $_.Exception.Message) }; try { Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force; Write-Host 'SMBv1 requested OFF.' } catch { Write-Host ('SMBv1 setting failed: ' + $_.Exception.Message) }"
echo.
echo Hardening commands finished. Reboot is recommended.
pause
goto cyber_pc_guard

:cyber_pc_guard_export
cls
call :make_timestamp
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
set "report=%LOGROOT%\Cyber_PC_Guard_%stamp%.txt"
echo Creating cyber security report...
(
echo ULTIMATE X PRO MAX - CYBER PC GUARD REPORT
echo Computer: %COMPUTERNAME%
echo User: %USERNAME%
echo Time: %date% %time%
echo.
echo === WHOAMI ===
whoami /all
echo.
echo === LOCAL USERS ===
net user
echo.
echo === ADMINISTRATORS ===
net localgroup Administrators
echo.
echo === PASSWORD POLICY ===
net accounts
echo.
echo === FIREWALL ===
netsh advfirewall show allprofiles
echo.
echo === LISTENING PORTS ===
netstat -ano
echo.
echo === HOSTS FILE ===
type C:\Windows\System32\drivers\etc\hosts
echo.
echo === SHARES ===
net share
) > "%report%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$out='%report%'; Add-Content -LiteralPath $out -Value ''; Add-Content -LiteralPath $out -Value '=== DEFENDER STATUS ==='; try { Get-MpComputerStatus | Out-String | Add-Content -LiteralPath $out } catch { Add-Content -LiteralPath $out -Value ('Defender query failed: ' + $_.Exception.Message) }; Add-Content -LiteralPath $out -Value '=== DEFENDER PREFERENCES ==='; try { Get-MpPreference | Select-Object DisableRealtimeMonitoring,PUAProtection,MAPSReporting,SubmitSamplesConsent,EnableNetworkProtection,ExclusionPath,ExclusionProcess | Out-String | Add-Content -LiteralPath $out } catch {}; Add-Content -LiteralPath $out -Value '=== FAILED LOGINS LAST 7 DAYS ==='; try { Get-WinEvent -FilterHashtable @{LogName='Security';Id=4625;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 100 -ErrorAction Stop | Select-Object TimeCreated,@{n='Account';e={if($_.Properties.Count -gt 5){$_.Properties[5].Value}else{''}}},@{n='SourceIP';e={if($_.Properties.Count -gt 19){$_.Properties[19].Value}else{''}}} | Out-String | Add-Content -LiteralPath $out } catch { Add-Content -LiteralPath $out -Value ('Failed login query failed: ' + $_.Exception.Message) }; Add-Content -LiteralPath $out -Value '=== STARTUP COMMANDS ==='; try { Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User | Out-String | Add-Content -LiteralPath $out } catch {}; Add-Content -LiteralPath $out -Value '=== ENABLED SCHEDULED TASKS FIRST 100 ==='; try { Get-ScheduledTask | Where-Object State -ne 'Disabled' | Select-Object -First 100 TaskName,TaskPath,State | Out-String | Add-Content -LiteralPath $out } catch {}"
echo.
echo Report saved:
echo %report%
start "" "%report%"
pause
goto cyber_pc_guard

:menu_mass_installer
set "BACK_MENU=menu_mass_installer"
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [27] MASS SOFTWARE INSTALLER ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] 5000+ Winget Library                      [02] Search + Install App                      [03] Upgrade All Apps                          %C_RESET%
echo %C_GREEN%  [04] List Installed Apps                       [05] Install Browsers Pack                     [06] Install Runtime Pack                      %C_RESET%
echo %C_GREEN%  [07] Install Utility Pack                      [08] Install Dev Pack                          [09] Microsoft Store Repair                    %C_RESET%
echo %C_GREEN%  [10] App Installer Repair                      [11] Apps Inventory Report                     [12] Download Center                           %C_RESET%
echo %C_GREEN%  [13] Winget Health / Sources                   [14] Communication Pack                        [15] Remote Support Pack                       %C_RESET%
echo %C_GREEN%  [16] Media / Creator Pack                      [17] Security Tools Pack                       [18] Office / Student Pack                     %C_RESET%
echo %C_GREEN%  [19] Custom Batch ID Install                   [20] Category Pack Menu                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto winget_installer
if "%c%"=="1" goto winget_installer
if "%c%"=="02" goto winget_search_install
if "%c%"=="2" goto winget_search_install
if "%c%"=="03" (call :winget_upgrade_all & pause & goto menu_mass_installer)
if "%c%"=="3" (call :winget_upgrade_all & pause & goto menu_mass_installer)
if "%c%"=="04" (call :winget_list_installed & pause & goto menu_mass_installer)
if "%c%"=="4" (call :winget_list_installed & pause & goto menu_mass_installer)
if "%c%"=="05" (set "PACK_RETURN=menu_mass_installer" & goto install_browsers_pack)
if "%c%"=="5" (set "PACK_RETURN=menu_mass_installer" & goto install_browsers_pack)
if "%c%"=="06" (set "PACK_RETURN=menu_mass_installer" & goto install_runtime_pack)
if "%c%"=="6" (set "PACK_RETURN=menu_mass_installer" & goto install_runtime_pack)
if "%c%"=="07" (set "PACK_RETURN=menu_mass_installer" & goto install_utility_pack)
if "%c%"=="7" (set "PACK_RETURN=menu_mass_installer" & goto install_utility_pack)
if "%c%"=="08" (set "PACK_RETURN=menu_mass_installer" & goto install_dev_pack)
if "%c%"=="8" (set "PACK_RETURN=menu_mass_installer" & goto install_dev_pack)
if "%c%"=="09" goto issue_store_repair
if "%c%"=="9" goto issue_store_repair
if "%c%"=="10" (call :repair_app_installer & pause & goto menu_mass_installer)
if "%c%"=="11" goto issue_apps_inventory
if "%c%"=="12" (set "DOWNLOAD_RETURN=menu_mass_installer" & goto menu_download_deploy)
if "%c%"=="13" (call :winget_health & pause & goto menu_mass_installer)
if "%c%"=="14" (set "PACK_RETURN=menu_mass_installer" & goto install_communication_pack)
if "%c%"=="15" (set "PACK_RETURN=menu_mass_installer" & goto install_remote_pack)
if "%c%"=="16" (set "PACK_RETURN=menu_mass_installer" & goto install_media_pack)
if "%c%"=="17" (set "PACK_RETURN=menu_mass_installer" & goto install_security_pack)
if "%c%"=="18" (set "PACK_RETURN=menu_mass_installer" & goto install_office_pack)
if "%c%"=="19" (set "PACK_RETURN=menu_mass_installer" & goto winget_custom_batch)
if "%c%"=="20" (set "CATEGORY_RETURN=menu_mass_installer" & goto winget_category_packs)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_mass_installer

:install_browsers_pack
cls
echo This will use winget to install common browsers. Internet required.
set "ok=" & set /p ok=Install browsers pack? (Y/N):
if /i not "%ok%"=="Y" goto return_from_pack
call :winget_install_pack Google.Chrome Mozilla.Firefox Brave.Brave Opera.Opera
pause
goto return_from_pack

:install_runtime_pack
cls
echo This will use winget to install common runtimes. Internet required.
set "ok=" & set /p ok=Install runtime pack? (Y/N):
if /i not "%ok%"=="Y" goto return_from_pack
call :winget_install_pack Microsoft.VCRedist.2015+.x64 Microsoft.DotNet.DesktopRuntime.8 Microsoft.EdgeWebView2Runtime Microsoft.OpenJDK.21
pause
goto return_from_pack

:install_utility_pack
cls
echo This will use winget to install common utilities. Internet required.
set "ok=" & set /p ok=Install utility pack? (Y/N):
if /i not "%ok%"=="Y" goto return_from_pack
call :winget_install_pack 7zip.7zip Notepad++.Notepad++ VideoLAN.VLC voidtools.Everything Microsoft.PowerToys
pause
goto return_from_pack

:install_dev_pack
cls
echo This will use winget to install developer utilities. Internet required.
set "ok=" & set /p ok=Install dev pack? (Y/N):
if /i not "%ok%"=="Y" goto return_from_pack
call :winget_install_pack Microsoft.VisualStudioCode Git.Git OpenJS.NodeJS.LTS Python.Python.3.12 Microsoft.WindowsTerminal
pause
goto return_from_pack

:install_communication_pack
cls
echo This will use winget to install communication apps. Internet required.
set "ok=" & set /p ok=Install communication pack? (Y/N):
if /i not "%ok%"=="Y" goto return_from_pack
call :winget_install_pack Zoom.Zoom Microsoft.Teams Telegram.TelegramDesktop Discord.Discord SlackTechnologies.Slack
pause
goto return_from_pack

:install_remote_pack
cls
echo This will use winget to install remote support tools. Internet required.
set "ok=" & set /p ok=Install remote support pack? (Y/N):
if /i not "%ok%"=="Y" goto return_from_pack
call :winget_install_pack AnyDesk.AnyDesk TeamViewer.TeamViewer Google.ChromeRemoteDesktopHost PuTTY.PuTTY WinSCP.WinSCP
pause
goto return_from_pack

:install_media_pack
cls
echo This will use winget to install media and creator tools. Internet required.
set "ok=" & set /p ok=Install media / creator pack? (Y/N):
if /i not "%ok%"=="Y" goto return_from_pack
call :winget_install_pack VideoLAN.VLC OBSProject.OBSStudio GIMP.GIMP Audacity.Audacity HandBrake.HandBrake
pause
goto return_from_pack

:install_security_pack
cls
echo This will use winget to install security tools. Internet required.
set "ok=" & set /p ok=Install security tools pack? (Y/N):
if /i not "%ok%"=="Y" goto return_from_pack
call :winget_install_pack Malwarebytes.Malwarebytes Microsoft.Sysinternals.Suite Bitwarden.Bitwarden WiresharkFoundation.Wireshark
pause
goto return_from_pack

:install_office_pack
cls
echo This will use winget to install office / student tools. Internet required.
set "ok=" & set /p ok=Install office / student pack? (Y/N):
if /i not "%ok%"=="Y" goto return_from_pack
call :winget_install_pack TheDocumentFoundation.LibreOffice Adobe.Acrobat.Reader.64-bit SumatraPDF.SumatraPDF Notion.Notion Microsoft.OneDrive
pause
goto return_from_pack

:winget_custom_batch
cls
echo Enter Winget IDs separated by spaces or commas.
echo Example: Google.Chrome 7zip.7zip VideoLAN.VLC
set "ids=" & set /p ids=Winget IDs:
if "%ids%"=="" goto return_from_pack
set "ids=%ids:,= %"
call :winget_require
if errorlevel 1 (pause & goto return_from_pack)
for %%A in (%ids%) do call :winget_install_id "%%~A"
pause
goto return_from_pack

:menu_hacker_dashboard
set "BACK_MENU=menu_hacker_dashboard"
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [28] HACKER STYLE LIVE DASHBOARD ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Matrix System Snapshot                    [02] Live Netstat                              [03] Live Process List                         %C_RESET%
echo %C_GREEN%  [04] Live Ping Monitor                         [05] Security Snapshot                         [06] Disk / RAM Snapshot                       %C_RESET%
echo %C_GREEN%  [07] Event Error Snapshot                      [08] Network Interface Snapshot                [09] Open Task Manager                         %C_RESET%
echo %C_GREEN%  [10] Open Resource Monitor                     [11] Health Dashboard                          [12] Back Main Menu                            %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto hacker_snapshot
if "%c%"=="1" goto hacker_snapshot
if "%c%"=="02" (netstat -ano & pause & goto menu_hacker_dashboard)
if "%c%"=="2" (netstat -ano & pause & goto menu_hacker_dashboard)
if "%c%"=="03" (tasklist & pause & goto menu_hacker_dashboard)
if "%c%"=="3" (tasklist & pause & goto menu_hacker_dashboard)
if "%c%"=="04" (ping 8.8.8.8 -t)
if "%c%"=="4" (ping 8.8.8.8 -t)
if "%c%"=="05" (netsh advfirewall show allprofiles state & powershell -NoProfile -Command "Get-MpComputerStatus | Select AntivirusEnabled,RealTimeProtectionEnabled" & pause & goto menu_hacker_dashboard)
if "%c%"=="5" (netsh advfirewall show allprofiles state & powershell -NoProfile -Command "Get-MpComputerStatus | Select AntivirusEnabled,RealTimeProtectionEnabled" & pause & goto menu_hacker_dashboard)
if "%c%"=="06" (call :ps_logical_disks & powershell -NoProfile -Command "Get-CimInstance Win32_OperatingSystem | Select @{n='FreeRAMGB';e={[math]::Round($_.FreePhysicalMemory/1MB,2)}} " & pause & goto menu_hacker_dashboard)
if "%c%"=="6" (call :ps_logical_disks & powershell -NoProfile -Command "Get-CimInstance Win32_OperatingSystem | Select @{n='FreeRAMGB';e={[math]::Round($_.FreePhysicalMemory/1MB,2)}} " & pause & goto menu_hacker_dashboard)
if "%c%"=="07" (powershell -NoProfile -Command "Get-WinEvent -LogName System -MaxEvents 20 | Where-Object {$_.Level -le 2} | Select TimeCreated,Id,ProviderName | Format-Table -AutoSize" & pause & goto menu_hacker_dashboard)
if "%c%"=="7" (powershell -NoProfile -Command "Get-WinEvent -LogName System -MaxEvents 20 | Where-Object {$_.Level -le 2} | Select TimeCreated,Id,ProviderName | Format-Table -AutoSize" & pause & goto menu_hacker_dashboard)
if "%c%"=="08" (netsh interface show interface & ipconfig ^| findstr /i "IPv4 Gateway" & pause & goto menu_hacker_dashboard)
if "%c%"=="8" (netsh interface show interface & ipconfig ^| findstr /i "IPv4 Gateway" & pause & goto menu_hacker_dashboard)
if "%c%"=="09" (start "" taskmgr & pause & goto menu_hacker_dashboard)
if "%c%"=="9" (start "" taskmgr & goto menu_hacker_dashboard)
if "%c%"=="10" (start "" resmon & pause & goto menu_hacker_dashboard)
if "%c%"=="11" goto health_dashboard
if "%c%"=="12" goto main
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_hacker_dashboard

:hacker_snapshot
cls
color 0A
echo +============================================================================================================================================================+
echo ^| LIVE MATRIX SNAPSHOT                                                                                                                ULTIMATE X PRO MAX ^|
echo +============================================================================================================================================================+
echo.
echo [SYSTEM]
hostname
whoami
ver
echo.
echo [NETWORK]
ipconfig ^| findstr /i "IPv4 Gateway DNS"
echo.
echo [PROCESSES]
tasklist ^| more
pause
goto menu_hacker_dashboard

:menu_settings_themes
set "BACK_MENU=menu_settings_themes"
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [29] TOOLKIT SETTINGS ^& THEMES ULTIMATE X PRO MAX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Change Color Theme                        [02] Open Log Center                           [03] Toolkit Utilities                         %C_RESET%
echo %C_GREEN%  [04] Toolkit Checksum                          [05] Backup Toolkit File                       [06] Open Legacy Backup                        %C_RESET%
echo %C_GREEN%  [07] About WOW Build                           [08] Core Tool Check                           [09] Theme: Cyan                               %C_RESET%
echo %C_GREEN%  [10] Theme: Green                              [11] Theme: Matrix                             [12] Theme: White                              %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto change_color_theme
if "%c%"=="1" goto change_color_theme
if "%c%"=="02" goto open_log_center
if "%c%"=="2" goto open_log_center
if "%c%"=="03" goto toolkit_utilities
if "%c%"=="3" goto toolkit_utilities
if "%c%"=="04" goto toolkit_checksum
if "%c%"=="4" goto toolkit_checksum
if "%c%"=="05" goto backup_toolkit_file
if "%c%"=="5" goto backup_toolkit_file
if "%c%"=="06" goto open_legacy_backup
if "%c%"=="6" goto open_legacy_backup
if "%c%"=="07" goto about_wow
if "%c%"=="7" goto about_wow
if "%c%"=="08" goto check_core_tools
if "%c%"=="8" goto check_core_tools
if "%c%"=="09" (color 0B & goto menu_settings_themes)
if "%c%"=="9" (color 0B & goto menu_settings_themes)
if "%c%"=="10" (color 0A & goto menu_settings_themes)
if "%c%"=="11" (color 0A & goto menu_hacker_dashboard)
if "%c%"=="12" (color 0F & goto menu_settings_themes)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_settings_themes

:menu_about_toolkit
set "BACK_MENU=main"
goto about_wow

:open_log_center
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
explorer "%LOGROOT%"
goto go_back

:change_color_theme
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  COLOR THEME CENTER ULTIMATE X PRO MAX
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Cyan Pro                                  [02] Green Matrix                              [03] Yellow Repair                             %C_RESET%
echo %C_GREEN%  [04] Red Security                              [05] White Classic                             %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" (color 0B & goto go_back)
if "%c%"=="1" (color 0B & goto go_back)
if "%c%"=="02" (color 0A & goto go_back)
if "%c%"=="2" (color 0A & goto go_back)
if "%c%"=="03" (color 0E & goto go_back)
if "%c%"=="3" (color 0E & goto go_back)
if "%c%"=="04" (color 0C & goto go_back)
if "%c%"=="4" (color 0C & goto go_back)
if "%c%"=="05" (color 0F & goto go_back)
if "%c%"=="5" (color 0F & goto go_back)
if "%c%"=="99" goto go_back
goto change_color_theme

:: ============================================================
:: CATEGORY 1: SYSTEM & HARDWARE
:: ============================================================
:cat_system
set "BACK_MENU=cat_system"
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  [CATEGORY 1] SYSTEM ^& HARDWARE
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] System Tools                               [2] Hardware Health                            [3] BIOS ^& Boot Tools                         %C_RESET%
echo %C_GREEN%  [4] Storage ^& Partition                       [5] Device ^& Driver Manager                   [6] Display ^& Audio Tools                     %C_RESET%
echo %C_GREEN%  [7] Power Management                           [8] Task ^& Process Manager                    [9] Startup Manager                            %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" goto system_tools
if "%c%"=="2" goto hardware_health
if "%c%"=="3" goto bios_boot
if "%c%"=="4" goto storage
if "%c%"=="5" goto device_driver
if "%c%"=="6" goto display_audio
if "%c%"=="7" goto power_mgmt
if "%c%"=="8" goto task_process
if "%c%"=="9" goto startup_mgr
if "%c%"=="99" goto main
goto cat_system

:: ---- 1.1 System Tools ----
:system_tools
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [1.1] SYSTEM TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] MSConfig                                   [2] Services Manager                           [3] Event Viewer                               %C_RESET%
echo %C_GREEN%  [4] Device Manager                             [5] Driver Query                               [6] System Information (msinfo32)              %C_RESET%
echo %C_GREEN%  [7] Task Manager                               [8] Computer Management                        [9] System Properties                          %C_RESET%
echo %C_GREEN%  [10] DirectX Diagnostic                        [11] Control Panel                             [12] Programs ^& Features                      %C_RESET%
echo %C_GREEN%  [13] Resource Monitor                          [14] Performance Monitor                       [15] Reliability Monitor                       %C_RESET%
echo %C_GREEN%  [16] Registry Editor                           [17] Group Policy Editor                       [18] Local Security Policy                     %C_RESET%
echo %C_GREEN%  [19] UAC Settings                              [20] Local Users ^& Groups                     [21] Environment Variables                     %C_RESET%
echo %C_GREEN%  [22] Windows Features On/Off                   [23] Scheduled Tasks                           [24] Component Services                        %C_RESET%
echo %C_GREEN%  [25] Disk Management                           %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" msconfig & goto system_tools)
if "%c%"=="2" (start "" services.msc & goto system_tools)
if "%c%"=="3" (start "" eventvwr.msc & goto system_tools)
if "%c%"=="4" (start "" devmgmt.msc & goto system_tools)
if "%c%"=="5" (driverquery & pause & goto system_tools)
if "%c%"=="6" (start "" msinfo32 & goto system_tools)
if "%c%"=="7" (start "" taskmgr & goto system_tools)
if "%c%"=="8" (start "" compmgmt.msc & goto system_tools)
if "%c%"=="9" (start "" sysdm.cpl & goto system_tools)
if "%c%"=="10" (start "" dxdiag & pause & goto system_tools)
if "%c%"=="11" (start "" control & pause & goto system_tools)
if "%c%"=="12" (start "" appwiz.cpl & pause & goto system_tools)
if "%c%"=="13" (start "" resmon & pause & goto system_tools)
if "%c%"=="14" (start "" perfmon & pause & goto system_tools)
if "%c%"=="15" (start "" perfmon /rel & pause & goto system_tools)
if "%c%"=="16" (start "" regedit & pause & goto system_tools)
if "%c%"=="17" (start "" gpedit.msc & pause & goto system_tools)
if "%c%"=="18" (start "" secpol.msc & pause & goto system_tools)
if "%c%"=="19" (start "" UserAccountControlSettings & pause & goto system_tools)
if "%c%"=="20" (start "" lusrmgr.msc & pause & goto system_tools)
if "%c%"=="21" (start "" sysdm.cpl & pause & goto system_tools)
if "%c%"=="22" (start "" optionalfeatures & pause & goto system_tools)
if "%c%"=="23" (start "" taskschd.msc & pause & goto system_tools)
if "%c%"=="24" (start "" dcomcnfg & pause & goto system_tools)
if "%c%"=="25" (start "" diskmgmt.msc & pause & goto system_tools)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto system_tools

:: ---- 1.2 Hardware Health ----
:hardware_health
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [1.2] HARDWARE HEALTH - RAM / HDD / CPU / GPU%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] RAM Diagnostic (Windows)                   [2] HDD SMART Status                           [3] CPU Info                                   %C_RESET%
echo %C_GREEN%  [4] GPU Info                                   [5] Battery Report (Laptop)                    [6] CHKDSK Basic                               %C_RESET%
echo %C_GREEN%  [7] CHKDSK Full Repair                         [8] Disk Speed Test (WinSAT)                   [9] System Temperatures                        %C_RESET%
echo %C_GREEN%  [10] Hardware Info Full Report                 [11] DirectX Check                             [12] RAM Usage Live                            %C_RESET%
echo %C_GREEN%  [13] CPU Stress Test Info                      [14] Disk Health Summary                       %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" mdsched.exe & goto hardware_health)
if "%c%"=="2" (call :ps_disk_drives & pause & goto hardware_health)
if "%c%"=="3" (call :ps_cpu_info & pause & goto hardware_health)
if "%c%"=="4" (call :ps_gpu_info & pause & goto hardware_health)
if "%c%"=="5" (powercfg /batteryreport /output "%USERPROFILE%\Desktop\BatteryReport.html" & start "" "%USERPROFILE%\Desktop\BatteryReport.html" & goto hardware_health)
if "%c%"=="6" (chkdsk & pause & goto hardware_health)
if "%c%"=="7" (echo Will run on next reboot... & chkdsk C: /f /r & pause & goto hardware_health)
if "%c%"=="8" (winsat disk & pause & goto hardware_health)
if "%c%"=="9" (powershell -command "Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace root/wmi | Select-Object -ExpandProperty CurrentTemperature | ForEach-Object {$_/10-273.15}" & pause & goto hardware_health)
if "%c%"=="10" (msinfo32 & goto hardware_health)
if "%c%"=="11" (dxdiag & goto hardware_health)
if "%c%"=="12" (powershell -command "while($true){$ram=[math]::Round((Get-WmiObject Win32_OS).FreePhysicalMemory/1MB,2); Write-Host 'Free RAM:' $ram 'GB' -ForegroundColor Green; Start-Sleep 2; Clear-Host}" & goto hardware_health)
if "%c%"=="13" (echo Use HWMonitor or OCCT for stress testing. & echo Download: https://www.cpuid.com/softwares/hwmonitor.html & pause & goto hardware_health)
if "%c%"=="14" (call :ps_disk_drives & pause & goto hardware_health)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto hardware_health

:: ---- 1.3 BIOS & Boot Tools ----
:bios_boot
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [1.3] BIOS ^& BOOT TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Restart to UEFI/BIOS                       [2] Boot to Advanced Startup                   [3] Safe Mode Enable                           %C_RESET%
echo %C_GREEN%  [4] Safe Mode Disable                          [5] Bootrec FixMBR                             [6] Bootrec FixBoot                            %C_RESET%
echo %C_GREEN%  [7] Rebuild BCD                                [8] BCD Edit View                              [9] Startup Repair                             %C_RESET%
echo %C_GREEN%  [10] Recovery Console                          [11] System Info (BIOS Version)                [12] Secure Boot Status                        %C_RESET%
echo %C_GREEN%  [13] TPM Check                                 [14] Fast Boot Disable                         [15] Fast Boot Enable                          %C_RESET%
echo %C_GREEN%  [16] Create Bootable Pendrive                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (shutdown /r /fw /t 5 & echo Restarting to BIOS in 5 seconds... & pause & goto bios_boot)
if "%c%"=="2" (shutdown /r /o /f /t 0)
if "%c%"=="3" (bcdedit /set {current} safeboot minimal & echo Safe Mode enabled. Restart now. & pause & goto bios_boot)
if "%c%"=="4" (bcdedit /deletevalue {current} safeboot & echo Safe Mode disabled. & pause & goto bios_boot)
if "%c%"=="5" (echo WARNING: Only run from Recovery/WinPE! & pause & call :run_bootrec /fixmbr & pause & goto bios_boot)
if "%c%"=="6" (echo WARNING: Only run from Recovery/WinPE! & pause & call :run_bootrec /fixboot & pause & goto bios_boot)
if "%c%"=="7" (call :run_bootrec /rebuildbcd & pause & goto bios_boot)
if "%c%"=="8" (bcdedit & pause & goto bios_boot)
if "%c%"=="9" (shutdown /r /o /t 0)
if "%c%"=="10" (cmd.exe)
if "%c%"=="11" (call :ps_bios_info & pause & goto bios_boot)
if "%c%"=="12" (powershell Confirm-SecureBootUEFI & pause & goto bios_boot)
if "%c%"=="13" (tpm.msc & pause & goto bios_boot)
if "%c%"=="14" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f & echo Fast Boot Disabled. & pause & goto bios_boot)
if "%c%"=="15" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 1 /f & echo Fast Boot Enabled. & pause & goto bios_boot)
if "%c%"=="16" goto bootable_usb_creator
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto bios_boot

:: ---- 1.4 Storage & Partition ----
:storage
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [1.4] STORAGE ^& PARTITION TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Disk Management GUI                        [2] DiskPart (Advanced)                        [3] Storage Spaces                             %C_RESET%
echo %C_GREEN%  [4] Drive Letter Change                        [5] Volume Shrink                              [6] CHKDSK All Drives                          %C_RESET%
echo %C_GREEN%  [7] Disk Cleanup                               [8] Large File Scanner                         [9] Duplicate File Info                        %C_RESET%
echo %C_GREEN%  [10] Drive Info (All)                          [11] BitLocker Status                          [12] BitLocker Enable                          %C_RESET%
echo %C_GREEN%  [13] BitLocker Disable                         [14] Format Drive (Careful!)                   [15] VHD/VHDX Create                           %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" diskmgmt.msc & goto storage)
if "%c%"=="2" (diskpart & goto storage)
if "%c%"=="3" (start "" storagespacescontrol & goto storage)
if "%c%"=="4" (start "" diskmgmt.msc & goto storage)
if "%c%"=="5" (start "" diskmgmt.msc & goto storage)
if "%c%"=="6" (for %%d in (C D E F G H) do (if exist %%d:\ echo Checking %%d:\ && chkdsk %%d:) & pause & goto storage)
if "%c%"=="7" (cleanmgr & goto storage)
if "%c%"=="8" (
    echo Scanning for Large Files (Top 20 over 500MB^)...
    powershell -command "Get-ChildItem C:\ -Recurse -ErrorAction SilentlyContinue | Where-Object {$_.Length -gt 500MB} | Sort-Object Length -Descending | Select-Object -First 20 FullName, @{Name='Size(GB)';Expression={[math]::Round($_.Length/1GB,2)}} | Format-Table -AutoSize"
    pause & goto storage
)
if "%c%"=="9" (echo Use WinDirStat or TreeSize for duplicate scanning. & pause & goto storage)
if "%c%"=="10" (call :ps_logical_disks & pause & goto storage)
if "%c%"=="11" (manage-bde -status & pause & goto storage)
if "%c%"=="12" (set "drv=" & set /p drv=Enter Drive Letter e.g. C: & manage-bde -on !drv!: & pause & goto storage)
if "%c%"=="13" (set "drv=" & set /p drv=Enter Drive Letter e.g. C: & manage-bde -off !drv!: & pause & goto storage)
if "%c%"=="14" (echo WARNING! This will erase data! & set "drv=" & set /p drv=Enter Drive Letter: & set "fs=" & set /p fs=File System NTFS/FAT32: & format !drv!: /fs:!fs! & pause & goto storage)
if "%c%"=="15" goto create_vhd
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto storage

:create_vhd
cls
color 0A
echo %C_CYAN%============================================================%C_RESET%
echo  VHD/VHDX CREATE - GUIDED MODE
echo %C_CYAN%============================================================%C_RESET%
echo  Example path: C:\Toolkit\TestDisk.vhdx
echo  Size is in MB. Example: 20480 for 20 GB
echo %C_CYAN%============================================================%C_RESET%
set "vhd=" & set /p vhd=Enter VHD/VHDX full path:
if "%vhd%"=="" goto storage
set "sz=" & set /p sz=Enter size in MB:
if "%sz%"=="" goto storage
set "dpfile=%TEMP%\toolkit_create_vhd_%RANDOM%.txt"
(
echo create vdisk file="%vhd%" maximum=%sz% type=expandable
echo select vdisk file="%vhd%"
echo attach vdisk
echo create partition primary
echo format fs=ntfs quick label="ToolkitVHD"
echo assign
) > "%dpfile%"
diskpart /s "%dpfile%"
del "%dpfile%" >nul 2>&1
echo.
echo VHD/VHDX task finished.
pause
goto storage

:: ---- 1.5 Device & Driver Manager ----
:device_driver
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [1.5] DEVICE ^& DRIVER MANAGER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Device Manager                             [2] Driver Query (All)                         [3] Driver Query (Network)                     %C_RESET%
echo %C_GREEN%  [4] Driver Backup (DISM)                       [5] Driver Restore                             [6] Driver Verifier                            %C_RESET%
echo %C_GREEN%  [7] Unsigned Driver Check                      [8] PnP Device Scan                            [9] Remove Old Drivers                         %C_RESET%
echo %C_GREEN%  [10] Update All Drivers Info                   [11] Printer Drivers                           [12] Audio Driver Restart                      %C_RESET%
echo %C_GREEN%  [13] GPU Driver Info                           [14] USB Driver Reset                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" devmgmt.msc & goto device_driver)
if "%c%"=="2" (driverquery & pause & goto device_driver)
if "%c%"=="3" (driverquery ^| findstr /i network & pause & goto device_driver)
if "%c%"=="4" (set "DRIVER_BACKUP_RETURN=device_driver" & goto driver_backup_to_drive)
if "%c%"=="5" (set "DRIVER_RESTORE_RETURN=device_driver" & goto driver_restore_from_drive)
if "%c%"=="6" (verifier & goto device_driver)
if "%c%"=="7" (sigverif & goto device_driver)
if "%c%"=="8" (pnputil /scan-devices & pause & goto device_driver)
if "%c%"=="9" (set DEVMGR_SHOW_NONPRESENT_DEVICES=1 & start "" devmgmt.msc & goto device_driver)
if "%c%"=="10" (echo Open Device Manager and right-click to update. & start "" devmgmt.msc & pause & goto device_driver)
if "%c%"=="11" (printui /s /t2 & goto device_driver)
if "%c%"=="12" (net stop audiosrv & net start audiosrv & echo Audio restarted. & pause & goto device_driver)
if "%c%"=="13" (call :ps_gpu_info & pause & goto device_driver)
if "%c%"=="14" (pnputil /scan-devices & pause & goto device_driver)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto device_driver

:: ---- 1.6 Display & Audio Tools ----
:display_audio
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [1.6] DISPLAY ^& AUDIO TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Display Settings                           [2] Screen Resolution                          [3] Color Calibration                          %C_RESET%
echo %C_GREEN%  [4] Night Light Settings                       [5] Multiple Display Setup                     [6] Audio Devices                              %C_RESET%
echo %C_GREEN%  [7] Volume Mixer                               [8] Audio Troubleshooter                       [9] Sound Settings                             %C_RESET%
echo %C_GREEN%  [10] Restart Audio Service                     [11] DirectX Diagnostic                        [12] GPU Info                                  %C_RESET%
echo %C_GREEN%  [13] Refresh Rate Check                        [14] Display Driver Restart                    %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" ms-settings:display & goto display_audio)
if "%c%"=="2" (start "" desk.cpl & goto display_audio)
if "%c%"=="3" (start "" dccw & goto display_audio)
if "%c%"=="4" (start "" ms-settings:nightlight & goto display_audio)
if "%c%"=="5" (start "" ms-settings:display & goto display_audio)
if "%c%"=="6" (start "" mmsys.cpl & goto display_audio)
if "%c%"=="7" (start "" sndvol & goto display_audio)
if "%c%"=="8" (msdt.exe /id AudioPlaybackDiagnostic & goto display_audio)
if "%c%"=="9" (start "" ms-settings:sound & goto display_audio)
if "%c%"=="10" (net stop audiosrv & net stop AudioEndpointBuilder & net start AudioEndpointBuilder & net start audiosrv & echo Audio Service Restarted. & pause & goto display_audio)
if "%c%"=="11" (dxdiag & goto display_audio)
if "%c%"=="12" (call :ps_gpu_info & pause & goto display_audio)
if "%c%"=="13" (call :ps_gpu_refresh & pause & goto display_audio)
if "%c%"=="14" (
    echo Restarting Display Driver (Ctrl+Shift+Win+B equivalent via cmd^)...
    powershell -command "Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class DD{[DllImport(\"user32.dll\")]public static extern bool SendMessage(IntPtr hWnd,int Msg,int wParam,int lParam);}'; [DD]::SendMessage([IntPtr]-1,0x0112,0xF170,2)"
    pause & goto display_audio
)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto display_audio

:: ---- 1.7 Power Management ----
:power_mgmt
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [1.7] POWER MANAGEMENT%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Power Options                              [2] Battery Report                             [3] Balanced Plan                              %C_RESET%
echo %C_GREEN%  [4] High Performance Plan                      [5] Power Saver Plan                           [6] Ultimate Performance                       %C_RESET%
echo %C_GREEN%  [7] Sleep Settings                             [8] Hibernate Enable                           [9] Hibernate Disable                          %C_RESET%
echo %C_GREEN%  [10] Shutdown Timer                            [11] Restart Timer                             [12] Cancel Shutdown Timer                     %C_RESET%
echo %C_GREEN%  [13] Fast Startup Enable                       [14] Fast Startup Disable                      %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" powercfg.cpl & goto power_mgmt)
if "%c%"=="2" (powercfg /batteryreport /output "%USERPROFILE%\Desktop\BatteryReport.html" & start "" "%USERPROFILE%\Desktop\BatteryReport.html" & goto power_mgmt)
if "%c%"=="3" (powercfg /setactive SCHEME_BALANCED & echo Balanced Plan Active. & pause & goto power_mgmt)
if "%c%"=="4" (powercfg /setactive SCHEME_MIN & echo High Performance Active. & pause & goto power_mgmt)
if "%c%"=="5" (powercfg /setactive SCHEME_MAX & echo Power Saver Active. & pause & goto power_mgmt)
if "%c%"=="6" (powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 & echo Ultimate Performance added. Check Power Options. & pause & goto power_mgmt)
if "%c%"=="7" (start "" ms-settings:powersleep & goto power_mgmt)
if "%c%"=="8" (powercfg /hibernate on & echo Hibernate Enabled. & pause & goto power_mgmt)
if "%c%"=="9" (powercfg /hibernate off & echo Hibernate Disabled. & pause & goto power_mgmt)
if "%c%"=="10" (set "mins=" & set /p mins=Shutdown after how many minutes?: & if not "!mins!"=="" (set /a seconds=!mins!*60 & shutdown /s /t !seconds!) & goto power_mgmt)
if "%c%"=="11" (set "mins=" & set /p mins=Restart after how many minutes?: & if not "!mins!"=="" (set /a seconds=!mins!*60 & shutdown /r /t !seconds!) & goto power_mgmt)
if "%c%"=="12" (shutdown /a & echo Timer cancelled. & pause & goto power_mgmt)
if "%c%"=="13" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 1 /f & echo Fast Startup Enabled. & pause & goto power_mgmt)
if "%c%"=="14" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f & echo Fast Startup Disabled. & pause & goto power_mgmt)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto power_mgmt

:: ---- 1.8 Task & Process Manager ----
:task_process
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [1.8] TASK ^& PROCESS MANAGER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Task Manager                               [2] Running Processes List                     [3] Kill Process by Name                       %C_RESET%
echo %C_GREEN%  [4] Kill Process by PID                        [5] Suspicious Process Check                   [6] Kill All Chrome                            %C_RESET%
echo %C_GREEN%  [7] Kill All Edge                              [8] Kill All Office Apps                       [9] High CPU Process                           %C_RESET%
echo %C_GREEN%  [10] High RAM Process                          [11] Services Running                          [12] Services Stopped                          %C_RESET%
echo %C_GREEN%  [13] Start a Service                           [14] Stop a Service                            [15] Restart Explorer                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" taskmgr & goto task_process)
if "%c%"=="2" (tasklist & pause & goto task_process)
if "%c%"=="3" (set "proc=" & set /p proc=Process name e.g. notepad.exe: & taskkill /f /im !proc! & pause & goto task_process)
if "%c%"=="4" (set "pid=" & set /p pid=Enter PID: & taskkill /f /pid !pid! & pause & goto task_process)
if "%c%"=="5" (
    echo Checking suspicious processes...
    tasklist ^| findstr /i "rat keylog malware trojan virus worm backdoor"
    echo Check complete. If nothing listed, common malware names not found.
    pause & goto task_process
)
if "%c%"=="6" (taskkill /f /im chrome.exe & echo Chrome killed. & pause & goto task_process)
if "%c%"=="7" (taskkill /f /im msedge.exe & echo Edge killed. & pause & goto task_process)
if "%c%"=="8" (taskkill /f /im winword.exe & taskkill /f /im excel.exe & taskkill /f /im powerpnt.exe & taskkill /f /im outlook.exe & echo Office apps closed. & pause & goto task_process)
if "%c%"=="9" (powershell -command "Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name,CPU,Id | Format-Table -AutoSize" & pause & goto task_process)
if "%c%"=="10" (powershell -command "Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name,@{Name='RAM(MB)';Expression={[math]::Round($_.WorkingSet64/1MB,1)}},Id | Format-Table -AutoSize" & pause & goto task_process)
if "%c%"=="11" (sc query type= service state= running & pause & goto task_process)
if "%c%"=="12" (sc query type= service state= stopped & pause & goto task_process)
if "%c%"=="13" (set "svc=" & set /p svc=Service name: & net start !svc! & pause & goto task_process)
if "%c%"=="14" (set "svc=" & set /p svc=Service name: & net stop !svc! & pause & goto task_process)
if "%c%"=="15" (taskkill /f /im explorer.exe & start explorer.exe & echo Explorer restarted. & pause & goto task_process)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto task_process

:: ---- 1.9 Startup Manager ----
:startup_mgr
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [1.9] STARTUP MANAGER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] View Startup Programs (Task Manager)       [2] View Startup Registry Keys (HKCU)          [3] View Startup Registry Keys (HKLM)          %C_RESET%
echo %C_GREEN%  [4] View Startup Folder (User)                 [5] View Startup Folder (All Users)            [6] Disable Startup App (via Registry)         %C_RESET%
echo %C_GREEN%  [7] Open Startup Folder                        [8] Boot Time Check                            [9] MSConfig (Startup Tab)                     %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" taskmgr & goto startup_mgr)
if "%c%"=="2" (reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run & pause & goto startup_mgr)
if "%c%"=="3" (reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run & pause & goto startup_mgr)
if "%c%"=="4" (explorer "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup" & goto startup_mgr)
if "%c%"=="5" (explorer "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp" & goto startup_mgr)
if "%c%"=="6" (set "app=" & set /p app=App Registry Name to delete: & reg delete HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v !app! /f & pause & goto startup_mgr)
if "%c%"=="7" (explorer shell:startup & goto startup_mgr)
if "%c%"=="8" (powershell -command "Get-WinEvent -ProviderName Microsoft-Windows-Diagnostics-Performance | Where-Object {$_.Id -eq 100} | Select-Object -First 1 Message | Format-List" & pause & goto startup_mgr)
if "%c%"=="9" (start "" msconfig & goto startup_mgr)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto startup_mgr

:: ============================================================
:: CATEGORY 2: NETWORK & INTERNET
:: ============================================================
:cat_network
set "BACK_MENU=cat_network"
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  [CATEGORY 2] NETWORK ^& INTERNET
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Network Diagnostics                        [2] WiFi Tools                                 [3] DNS Manager                                %C_RESET%
echo %C_GREEN%  [4] Firewall Manager                           [5] IP / Adapter Config                        [6] VPN ^& Proxy                               %C_RESET%
echo %C_GREEN%  [7] Remote Desktop (RDP)                       [8] Network Shares                             [9] Advanced Network Tools                     %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" goto net_diag
if "%c%"=="2" goto wifi_tools
if "%c%"=="3" goto dns_mgr
if "%c%"=="4" goto firewall_mgr
if "%c%"=="5" goto ip_config
if "%c%"=="6" goto vpn_proxy
if "%c%"=="7" goto rdp_tools
if "%c%"=="8" goto net_shares
if "%c%"=="9" goto net_advanced
if "%c%"=="99" goto main
goto cat_network

:: ---- 2.1 Network Diagnostics ----
:net_diag
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [2.1] NETWORK DIAGNOSTICS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] IPConfig /All                              [2] Ping Google                                [3] Ping Custom Target                         %C_RESET%
echo %C_GREEN%  [4] Tracert                                    [5] NSLookup                                   [6] Netstat (All)                              %C_RESET%
echo %C_GREEN%  [7] Netstat (Listening Ports)                  [8] Full Network Diagnostics                   [9] Internet Connectivity Check                %C_RESET%
echo %C_GREEN%  [10] Packet Loss Test                          [11] MTR/PathPing                              [12] Network Adapter Status                    %C_RESET%
echo %C_GREEN%  [13] ARP Table                                 [14] Route Table                               [15] Network Troubleshooter                    %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (ipconfig /all & pause & goto net_diag)
if "%c%"=="2" (ping google.com & pause & goto net_diag)
if "%c%"=="3" (set "target=" & set /p target=Target IP/Domain: & ping !target! & pause & goto net_diag)
if "%c%"=="4" (set "target=" & set /p target=Target: & tracert !target! & pause & goto net_diag)
if "%c%"=="5" (set "domain=" & set /p domain=Domain: & nslookup !domain! & pause & goto net_diag)
if "%c%"=="6" (netstat -ano & pause & goto net_diag)
if "%c%"=="7" (netstat -an ^| findstr LISTENING & pause & goto net_diag)
if "%c%"=="8" (
    echo === FULL NETWORK DIAGNOSTICS ===
    ipconfig /all
    echo. & echo === PING TEST ===
    ping 8.8.8.8 -n 4
    echo. & echo === DNS TEST ===
    nslookup google.com
    echo. & echo === ROUTE TABLE ===
    route print
    echo. & echo === ARP TABLE ===
    arp -a
    pause & goto net_diag
)
if "%c%"=="9" (
    ping 8.8.8.8 -n 1 >nul 2>&1
    if !errorlevel!==0 (echo [OK] Internet is Connected!) else (echo [FAIL] No Internet!)
    pause & goto net_diag
)
if "%c%"=="10" (ping google.com -n 50 & pause & goto net_diag)
if "%c%"=="11" (pathping google.com & pause & goto net_diag)
if "%c%"=="12" (netsh interface show interface & pause & goto net_diag)
if "%c%"=="13" (arp -a & pause & goto net_diag)
if "%c%"=="14" (route print & pause & goto net_diag)
if "%c%"=="15" (msdt.exe /id NetworkDiagnosticsNetworkAdapter & pause & goto net_diag)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto net_diag

:: ---- 2.2 WiFi Tools ----
:wifi_tools
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [2.2] WIFI TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Show WiFi Profiles                         [2] WiFi Password View                         [3] Connect to WiFi                            %C_RESET%
echo %C_GREEN%  [4] Disconnect WiFi                            [5] WiFi Adapter Reset                         [6] WiFi Backup (Export)                       %C_RESET%
echo %C_GREEN%  [7] WiFi Restore (Import)                      [8] Delete WiFi Profile                        [9] WiFi Signal Check                          %C_RESET%
echo %C_GREEN%  [10] WiFi Driver Info                          [11] WiFi Slow Fix                             [12] WiFi No Internet Fix                      %C_RESET%
echo %C_GREEN%  [13] Enable WiFi Adapter                       [14] Disable WiFi Adapter                      [15] WiFi Analyzer (Settings)                  %C_RESET%
echo %C_GREEN%  [16] Show Saved WiFi + Passwords               [17] Visible Networks (BSSID)                  [18] WLAN Report Generate                      %C_RESET%
echo %C_GREEN%  [19] WiFi Driver Capabilities                  [20] Restart WLAN Service                      [21] Known Networks Settings                   %C_RESET%
echo %C_GREEN%  [22] Airplane Mode Settings                    [23] Network Reset Settings                    [24] WiFi Power Saving Settings                %C_RESET%
echo %C_GREEN%  [25] Export Password CSV                       [26] Export Profiles to Desktop                [27] Import Profiles from Folder               %C_RESET%
echo %C_GREEN%  [28] Ping Default Gateway                      [29] Delete All WiFi Profiles                  [30] Open WiFi Data Usage                      %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (netsh wlan show profiles & pause & goto wifi_tools)
if "%c%"=="2" (call :wifi_show_all_passwords & pause & goto wifi_tools)
if "%c%"=="3" (set "wifi=" & set /p wifi=WiFi Name: & netsh wlan connect name="!wifi!" & pause & goto wifi_tools)
if "%c%"=="4" (netsh wlan disconnect & echo Disconnected. & pause & goto wifi_tools)
if "%c%"=="5" (netsh interface set interface "Wi-Fi" disable & timeout /t 3 /nobreak >nul 2>&1 & netsh interface set interface "Wi-Fi" enable & echo WiFi Reset Done. & pause & goto wifi_tools)
if "%c%"=="6" (if not exist "%USERPROFILE%\Desktop\WiFi_Backup" mkdir "%USERPROFILE%\Desktop\WiFi_Backup" & netsh wlan export profile key=clear folder="%USERPROFILE%\Desktop\WiFi_Backup" & echo Saved to Desktop\WiFi_Backup & pause & goto wifi_tools)
if "%c%"=="7" (set "wifi_backup_path=" & set /p wifi_backup_path=Backup Folder Path: & netsh wlan add profile filename="!wifi_backup_path!\*.xml" & pause & goto wifi_tools)
if "%c%"=="8" (set "wifi=" & set /p wifi=WiFi Profile Name: & netsh wlan delete profile name="!wifi!" & pause & goto wifi_tools)
if "%c%"=="9" (netsh wlan show interfaces & pause & goto wifi_tools)
if "%c%"=="10" (driverquery ^| findstr /i wireless & pause & goto wifi_tools)
if "%c%"=="11" (netsh wlan disconnect & timeout /t 2 /nobreak >nul 2>&1 & netsh interface set interface "Wi-Fi" disable & timeout /t 3 /nobreak >nul 2>&1 & netsh interface set interface "Wi-Fi" enable & netsh winsock reset & ipconfig /flushdns & echo WiFi Slow Fix Done. & pause & goto wifi_tools)
if "%c%"=="12" (ipconfig /release & ipconfig /renew & ipconfig /flushdns & netsh winsock reset & echo WiFi No Internet Fix Done. & pause & goto wifi_tools)
if "%c%"=="13" (netsh interface set interface "Wi-Fi" enable & echo WiFi Enabled. & pause & goto wifi_tools)
if "%c%"=="14" (netsh interface set interface "Wi-Fi" disable & echo WiFi Disabled. & pause & goto wifi_tools)
if "%c%"=="15" (start "" ms-settings:network-wifi & pause & goto wifi_tools)
if "%c%"=="16" (call :wifi_show_all_passwords & pause & goto wifi_tools)
if "%c%"=="17" (netsh wlan show networks mode=bssid & pause & goto wifi_tools)
if "%c%"=="18" (netsh wlan show wlanreport & start "" "%ProgramData%\Microsoft\Windows\WlanReport\wlan-report-latest.html" & pause & goto wifi_tools)
if "%c%"=="19" (netsh wlan show drivers & pause & goto wifi_tools)
if "%c%"=="20" (sc config WlanSvc start= auto & net stop WlanSvc >nul 2>&1 & net start WlanSvc & echo WLAN AutoConfig restarted. & pause & goto wifi_tools)
if "%c%"=="21" (start "" ms-settings:network-wifi & pause & goto wifi_tools)
if "%c%"=="22" (start "" ms-settings:network-airplanemode & pause & goto wifi_tools)
if "%c%"=="23" (start "" ms-settings:network-status & echo Use Advanced network settings - Network reset. & pause & goto wifi_tools)
if "%c%"=="24" (start "" powercfg.cpl & echo Open adapter power settings and disable power saving for WiFi adapter if needed. & pause & goto wifi_tools)
if "%c%"=="25" (call :wifi_export_password_csv & pause & goto wifi_tools)
if "%c%"=="26" (if not exist "%USERPROFILE%\Desktop\WiFi_Backup" mkdir "%USERPROFILE%\Desktop\WiFi_Backup" & netsh wlan export profile key=clear folder="%USERPROFILE%\Desktop\WiFi_Backup" & echo Exported to Desktop\WiFi_Backup & pause & goto wifi_tools)
if "%c%"=="27" (set "wifi_backup_path=" & set /p wifi_backup_path=Folder with XML profiles: & for %%F in ("!wifi_backup_path!\*.xml") do netsh wlan add profile filename="%%~fF" & pause & goto wifi_tools)
if "%c%"=="28" (powershell -NoProfile -ExecutionPolicy Bypass -Command "$gw=(Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Sort-Object RouteMetric | Select-Object -First 1).NextHop; if($gw){Write-Host ('Gateway: '+$gw); Test-Connection $gw -Count 8}else{Write-Host 'Gateway not found.'}" & pause & goto wifi_tools)
if "%c%"=="29" (echo WARNING: This deletes all saved WiFi profiles. & set "ok=" & set /p ok=Type YES to continue: & if /i "!ok!"=="YES" netsh wlan delete profile name=* & pause & goto wifi_tools)
if "%c%"=="30" (start "" ms-settings:datausage & pause & goto wifi_tools)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto wifi_tools

:: ---- 2.3 DNS Manager ----
:dns_mgr
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [2.3] DNS MANAGER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Flush DNS Cache                            [2] View DNS Cache                             [3] Register DNS                               %C_RESET%
echo %C_GREEN%  [4] Set Google DNS (WiFi)                      [5] Set Google DNS (LAN)                       [6] Set Cloudflare DNS (WiFi)                  %C_RESET%
echo %C_GREEN%  [7] Set Cloudflare DNS (LAN)                   [8] Set Auto DNS (WiFi)                        [9] Set Auto DNS (LAN)                         %C_RESET%
echo %C_GREEN%  [10] Custom DNS Set                            [11] DNS Leak Check                            [12] NSLookup Test                             %C_RESET%
echo %C_GREEN%  [13] Hosts File View                           [14] Hosts File Edit                           [15] DNS Troubleshooter                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (ipconfig /flushdns & echo DNS Flushed. & pause & goto dns_mgr)
if "%c%"=="2" (ipconfig /displaydns & pause & goto dns_mgr)
if "%c%"=="3" (ipconfig /registerdns & echo DNS Registered. & pause & goto dns_mgr)
if "%c%"=="4" (netsh interface ip set dns "Wi-Fi" static 8.8.8.8 & netsh interface ip add dns "Wi-Fi" 8.8.4.4 index=2 & echo Google DNS set for WiFi. & pause & goto dns_mgr)
if "%c%"=="5" (netsh interface ip set dns "Ethernet" static 8.8.8.8 & netsh interface ip add dns "Ethernet" 8.8.4.4 index=2 & echo Google DNS set for LAN. & pause & goto dns_mgr)
if "%c%"=="6" (netsh interface ip set dns "Wi-Fi" static 1.1.1.1 & netsh interface ip add dns "Wi-Fi" 1.0.0.1 index=2 & echo Cloudflare DNS set for WiFi. & pause & goto dns_mgr)
if "%c%"=="7" (netsh interface ip set dns "Ethernet" static 1.1.1.1 & netsh interface ip add dns "Ethernet" 1.0.0.1 index=2 & echo Cloudflare DNS set for LAN. & pause & goto dns_mgr)
if "%c%"=="8" (netsh interface ip set dns "Wi-Fi" dhcp & echo Auto DNS for WiFi. & pause & goto dns_mgr)
if "%c%"=="9" (netsh interface ip set dns "Ethernet" dhcp & echo Auto DNS for LAN. & pause & goto dns_mgr)
if "%c%"=="10" (set "dns1=" & set /p dns1=Primary DNS: & set "dns2=" & set /p dns2=Secondary DNS: & set "iface=" & set /p iface=Interface Wi-Fi or Ethernet: & netsh interface ip set dns "!iface!" static !dns1! & netsh interface ip add dns "!iface!" !dns2! index=2 & pause & goto dns_mgr)
if "%c%"=="11" (nslookup google.com & nslookup google.com 8.8.8.8 & pause & goto dns_mgr)
if "%c%"=="12" (set "domain=" & set /p domain=Domain to lookup: & nslookup !domain! & pause & goto dns_mgr)
if "%c%"=="13" (type C:\Windows\System32\drivers\etc\hosts & pause & goto dns_mgr)
if "%c%"=="14" (notepad C:\Windows\System32\drivers\etc\hosts & goto dns_mgr)
if "%c%"=="15" (msdt.exe /id NetworkDiagnosticsWeb & pause & goto dns_mgr)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto dns_mgr

:: ---- 2.4 Firewall Manager ----
:firewall_mgr
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [2.4] FIREWALL MANAGER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Firewall Status                            [2] Firewall Advanced (GUI)                    [3] Firewall On (All Profiles)                 %C_RESET%
echo %C_GREEN%  [4] Firewall Off (All)                         [5] Reset Firewall                             [6] Block App via Firewall                     %C_RESET%
echo %C_GREEN%  [7] Unblock App via Firewall                   [8] Show All Rules                             [9] Block Port                                 %C_RESET%
echo %C_GREEN%  [10] Unblock Port                              [11] Firewall Log Enable                       [12] Firewall Log View                         %C_RESET%
echo %C_GREEN%  [13] Export Firewall Rules                     [14] Import Firewall Rules                     %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (netsh advfirewall show allprofiles & pause & goto firewall_mgr)
if "%c%"=="2" (start "" wf.msc & goto firewall_mgr)
if "%c%"=="3" (netsh advfirewall set allprofiles state on & echo Firewall ON. & pause & goto firewall_mgr)
if "%c%"=="4" (netsh advfirewall set allprofiles state off & echo Firewall OFF. & pause & goto firewall_mgr)
if "%c%"=="5" (netsh advfirewall reset & echo Firewall Reset. & pause & goto firewall_mgr)
if "%c%"=="6" (set "app=" & set /p app=Full path of app to block: & netsh advfirewall firewall add rule name="Blocked_App" dir=out action=block program="!app!" & pause & goto firewall_mgr)
if "%c%"=="7" (set "rule=" & set /p rule=Rule name to delete: & netsh advfirewall firewall delete rule name="!rule!" & pause & goto firewall_mgr)
if "%c%"=="8" (netsh advfirewall firewall show rule name=all & pause & goto firewall_mgr)
if "%c%"=="9" (set "port=" & set /p port=Port to block: & set "proto=" & set /p proto=Protocol TCP/UDP: & netsh advfirewall firewall add rule name="Block_Port_!port!" dir=in action=block protocol=!proto! localport=!port! & echo Port !port! Blocked. & pause & goto firewall_mgr)
if "%c%"=="10" (set "port=" & set /p port=Port to unblock: & netsh advfirewall firewall delete rule name="Block_Port_!port!" & echo Port !port! Unblocked. & pause & goto firewall_mgr)
if "%c%"=="11" (netsh advfirewall set allprofiles logging droppedconnections enable & echo Logging enabled. & pause & goto firewall_mgr)
if "%c%"=="12" (notepad C:\Windows\System32\LogFiles\Firewall\pfirewall.log & goto firewall_mgr)
if "%c%"=="13" (netsh advfirewall export "%USERPROFILE%\Desktop\FirewallRules.wfw" & echo Exported to Desktop. & pause & goto firewall_mgr)
if "%c%"=="14" (set "file=" & set /p file=Import file path: & netsh advfirewall import "!file!" & pause & goto firewall_mgr)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto firewall_mgr

:: ---- 2.5 IP / Adapter Config ----
:ip_config
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [2.5] IP ^& ADAPTER CONFIG%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Show All IPs                               [2] Release IP                                 [3] Renew IP                                   %C_RESET%
echo %C_GREEN%  [4] Set Static IP                              [5] Set DHCP (Auto IP)                         [6] Winsock Reset                              %C_RESET%
echo %C_GREEN%  [7] TCP/IP Reset                               [8] Network Connections GUI                    [9] MAC Address View                           %C_RESET%
echo %C_GREEN%  [10] Change MAC (Spoof)                        [11] Public IP Check                           [12] Adapter Enable                            %C_RESET%
echo %C_GREEN%  [13] Adapter Disable                           [14] APIPA Fix (169 IP)                        [15] Duplicate IP Fix                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (ipconfig /all & pause & goto ip_config)
if "%c%"=="2" (ipconfig /release & echo IP Released. & pause & goto ip_config)
if "%c%"=="3" (ipconfig /renew & echo IP Renewed. & pause & goto ip_config)
if "%c%"=="4" goto ip_config_static
if "%c%"=="5" (set "iface=" & set /p iface=Interface name: & netsh interface ipv4 set address "!iface!" dhcp & echo DHCP enabled. & pause & goto ip_config)
if "%c%"=="6" (netsh winsock reset & echo Winsock Reset. Restart required. & pause & goto ip_config)
if "%c%"=="7" (netsh int ip reset & echo TCP/IP Reset. Restart required. & pause & goto ip_config)
if "%c%"=="8" (start "" ncpa.cpl & goto ip_config)
if "%c%"=="9" (getmac /v & pause & goto ip_config)
if "%c%"=="10" (echo Open Device Manager - Network Adapters - Properties - Advanced - MAC Address & start "" devmgmt.msc & pause & goto ip_config)
if "%c%"=="11" (powershell -command "(Invoke-WebRequest -uri 'https://api.ipify.org').Content" & pause & goto ip_config)
if "%c%"=="12" (set "iface=" & set /p iface=Interface name: & netsh interface set interface "!iface!" enable & pause & goto ip_config)
if "%c%"=="13" (set "iface=" & set /p iface=Interface name: & netsh interface set interface "!iface!" disable & pause & goto ip_config)
if "%c%"=="14" (ipconfig /release & ipconfig /renew & ipconfig /flushdns & netsh winsock reset & echo APIPA Fix Done. & pause & goto ip_config)
if "%c%"=="15" (arp -d * & echo ARP cleared. & pause & goto ip_config)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto ip_config

:ip_config_static
set "iface=" & set /p iface=Interface name (e.g. Wi-Fi or Ethernet):
if "!iface!"=="" goto ip_config
set "ip=" & set /p ip=Static IP (e.g. 192.168.1.100):
if "!ip!"=="" goto ip_config
set "mask=" & set /p mask=Subnet Mask (e.g. 255.255.255.0):
if "!mask!"=="" goto ip_config
set "gw=" & set /p gw=Gateway (e.g. 192.168.1.1):
if "!gw!"=="" goto ip_config
netsh interface ipv4 set address "!iface!" static !ip! !mask! !gw!
echo Static IP Set.
pause
goto ip_config

:: ---- 2.6 VPN & Proxy ----
:vpn_proxy
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [2.6] VPN ^& PROXY TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Proxy Status Check                         [2] Proxy Reset                                [3] WinHTTP Proxy Show                         %C_RESET%
echo %C_GREEN%  [4] WinHTTP Proxy Reset                        [5] VPN Connections                            [6] VPN Connect                                %C_RESET%
echo %C_GREEN%  [7] VPN Disconnect                             [8] VPN Adapter Reset                          [9] Proxy Settings (GUI)                       %C_RESET%
echo %C_GREEN%  [10] IE Proxy Reset                            [11] Captive Portal Open                       [12] Proxy Malware Check                       %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (netsh winhttp show proxy & pause & goto vpn_proxy)
if "%c%"=="2" (netsh winhttp reset proxy & echo Proxy Reset. & pause & goto vpn_proxy)
if "%c%"=="3" (netsh winhttp show proxy & pause & goto vpn_proxy)
if "%c%"=="4" (netsh winhttp reset proxy & pause & goto vpn_proxy)
if "%c%"=="5" (rasdial & pause & goto vpn_proxy)
if "%c%"=="6" (set "vpn=" & set /p vpn=VPN Name: & rasdial "!vpn!" & pause & goto vpn_proxy)
if "%c%"=="7" (rasdial /disconnect & echo VPN Disconnected. & pause & goto vpn_proxy)
if "%c%"=="8" (netcfg -d & echo Network config reset - restart required. & pause & goto vpn_proxy)
if "%c%"=="9" (start "" ms-settings:network-proxy & goto vpn_proxy)
if "%c%"=="10" (reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /f & reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /f & echo IE Proxy Reset. & pause & goto vpn_proxy)
if "%c%"=="11" (start "" http://neverssl.com & pause & goto vpn_proxy)
if "%c%"=="12" (reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" & pause & goto vpn_proxy)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto vpn_proxy

:: ---- 2.7 RDP Tools ----
:rdp_tools
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [2.7] REMOTE DESKTOP (RDP) TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Enable RDP                                 [2] Disable RDP                                [3] RDP Port Check                             %C_RESET%
echo %C_GREEN%  [4] Change RDP Port                            [5] RDP Firewall Rule Add                      [6] Remote Desktop GUI                         %C_RESET%
echo %C_GREEN%  [7] RDP Sessions View                          [8] Kill RDP Session                           [9] RDP Log Check                              %C_RESET%
echo %C_GREEN%  [10] NLA Enable                                [11] NLA Disable                               [12] Remote Assistance Enable                  %C_RESET%
echo %C_GREEN%  [13] Remote Assistance Disable                 [14] Credential Clear (RDP)                    %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f & netsh advfirewall firewall set rule group="remote desktop" new enable=Yes & echo RDP Enabled. & pause & goto rdp_tools)
if "%c%"=="2" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f & echo RDP Disabled. & pause & goto rdp_tools)
if "%c%"=="3" (netstat -ano ^| findstr :3389 & pause & goto rdp_tools)
if "%c%"=="4" (set "port=" & set /p port=New RDP Port: & reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber /t REG_DWORD /d !port! /f & echo RDP Port changed to !port!. Restart service. & pause & goto rdp_tools)
if "%c%"=="5" (netsh advfirewall firewall set rule group="remote desktop" new enable=Yes & echo Firewall rule added. & pause & goto rdp_tools)
if "%c%"=="6" (start "" mstsc & goto rdp_tools)
if "%c%"=="7" (query session & pause & goto rdp_tools)
if "%c%"=="8" (set "sid=" & set /p sid=Session ID to kill: & logoff !sid! & pause & goto rdp_tools)
if "%c%"=="9" (eventvwr.msc & goto rdp_tools)
if "%c%"=="10" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 1 /f & echo NLA Enabled. & pause & goto rdp_tools)
if "%c%"=="11" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f & echo NLA Disabled. & pause & goto rdp_tools)
if "%c%"=="12" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fAllowToGetHelp /t REG_DWORD /d 1 /f & echo Remote Assistance Enabled. & pause & goto rdp_tools)
if "%c%"=="13" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fAllowToGetHelp /t REG_DWORD /d 0 /f & echo Remote Assistance Disabled. & pause & goto rdp_tools)
if "%c%"=="14" (cmdkey /delete:TERMSRV/* & echo RDP Credentials Cleared. & pause & goto rdp_tools)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto rdp_tools

:: ---- 2.8 Network Shares ----
:net_shares
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [2.8] NETWORK SHARES%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] View All Shares                            [2] Create Share                               [3] Delete Share                               %C_RESET%
echo %C_GREEN%  [4] Active Sessions                            [5] Disconnect All Sessions                    [6] SMB Status                                 %C_RESET%
echo %C_GREEN%  [7] SMBv1 Disable                              [8] SMBv1 Enable                               [9] SMBv2 Enable                               %C_RESET%
echo %C_GREEN%  [10] Net Use (Mapped Drives)                   [11] Map Network Drive                         [12] Disconnect Network Drive                  %C_RESET%
echo %C_GREEN%  [13] NAS Access Fix                            [14] Access Denied Fix (SMB)                   %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (net share & pause & goto net_shares)
if "%c%"=="2" (set "name=" & set /p name=Share Name: & set "share_path=" & set /p share_path=Folder Path: & net share !name!=!share_path! & pause & goto net_shares)
if "%c%"=="3" (set "name=" & set /p name=Share Name: & net share !name! /delete & pause & goto net_shares)
if "%c%"=="4" (net session & pause & goto net_shares)
if "%c%"=="5" (net session /delete /y & echo All sessions disconnected. & pause & goto net_shares)
if "%c%"=="6" (powershell Get-SmbServerConfiguration ^| Select-Object EnableSMB1Protocol,EnableSMB2Protocol & pause & goto net_shares)
if "%c%"=="7" (powershell Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force & echo SMBv1 Disabled. & pause & goto net_shares)
if "%c%"=="8" (powershell Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force & echo SMBv1 Enabled. & pause & goto net_shares)
if "%c%"=="9" (powershell Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force & echo SMBv2 Enabled. & pause & goto net_shares)
if "%c%"=="10" (net use & pause & goto net_shares)
if "%c%"=="11" (set "drive=" & set /p drive=Drive Letter e.g. Z: & set "share_path=" & set /p share_path=\\Server\Share path: & net use !drive!: !share_path! /persistent:yes & pause & goto net_shares)
if "%c%"=="12" (set "drive=" & set /p drive=Drive Letter: & net use !drive!: /delete & pause & goto net_shares)
if "%c%"=="13" (net use * /delete /y & ipconfig /flushdns & net start workstation & echo NAS Fix Done. & pause & goto net_shares)
if "%c%"=="14" (net use * /delete /y & cmdkey /delete:* & echo SMB Access Fix Done. & pause & goto net_shares)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto net_shares

:: ---- 2.9 Advanced Network Tools ----
:net_advanced
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [2.9] ADVANCED NETWORK TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Port Check (Custom)                        [2] Full Port Scan (Netstat)                   [3] ARP Cache Clear                            %C_RESET%
echo %C_GREEN%  [4] Route Add                                  [5] Route Delete                               [6] Route Print                                %C_RESET%
echo %C_GREEN%  [7] MTU Reset (WiFi)                           [8] MTU Reset (LAN)                            [9] NetBIOS Status                             %C_RESET%
echo %C_GREEN%  [10] Register DNS                              [11] Full Network Repair                       [12] Speed Test (Browser)                      %C_RESET%
echo %C_GREEN%  [13] Network Reset (netcfg)                    [14] TCP Reset                                 [15] Internet Full Repair                      %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (set "port=" & set /p port=Port Number: & netstat -ano ^| findstr :!port! & pause & goto net_advanced)
if "%c%"=="2" (netstat -ano & pause & goto net_advanced)
if "%c%"=="3" (arp -d * & echo ARP Cache Cleared. & pause & goto net_advanced)
if "%c%"=="4" (set "dest=" & set /p dest=Destination: & set "mask=" & set /p mask=Mask: & set "gw=" & set /p gw=Gateway: & route add !dest! mask !mask! !gw! & pause & goto net_advanced)
if "%c%"=="5" (set "dest=" & set /p dest=Destination: & route delete !dest! & pause & goto net_advanced)
if "%c%"=="6" (route print & pause & goto net_advanced)
if "%c%"=="7" (netsh interface ipv4 set subinterface "Wi-Fi" mtu=1500 store=persistent & echo MTU set for WiFi. & pause & goto net_advanced)
if "%c%"=="8" (netsh interface ipv4 set subinterface "Ethernet" mtu=1500 store=persistent & echo MTU set for LAN. & pause & goto net_advanced)
if "%c%"=="9" (nbtstat -n & pause & goto net_advanced)
if "%c%"=="10" (ipconfig /registerdns & pause & goto net_advanced)
if "%c%"=="11" (ipconfig /flushdns & netsh winsock reset & netsh int ip reset & netsh advfirewall reset & echo Full Network Repair Done. Restart recommended. & pause & goto net_advanced)
if "%c%"=="12" (start "" "https://fast.com" & pause & goto net_advanced)
if "%c%"=="13" (echo WARNING: This removes all network drivers! & set "confirm=" & set /p confirm=Type YES to continue: & if "!confirm!"=="YES" netcfg -d & pause & goto net_advanced)
if "%c%"=="14" (netsh int tcp reset & pause & goto net_advanced)
if "%c%"=="15" (ipconfig /release & ipconfig /flushdns & netsh winsock reset & netsh int ip reset & ipconfig /renew & echo Internet Full Repair Done. & pause & goto net_advanced)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto net_advanced

:: ============================================================
:: CATEGORY 3: WINDOWS REPAIR
:: ============================================================
:cat_repair
set "BACK_MENU=cat_repair"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  [CATEGORY 3] WINDOWS REPAIR
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] SFC ^& DISM Repair                         [2] Boot ^& MBR Repair                         [3] Registry Repair                            %C_RESET%
echo %C_GREEN%  [4] Windows Update Fix                         [5] Store ^& App Repair                        [6] DLL ^& Runtime Fix                         %C_RESET%
echo %C_GREEN%  [7] Explorer ^& UI Fix                         [8] Service Repair                             [9] One Click Full Repair                      %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" goto sfc_dism
if "%c%"=="2" goto boot_repair
if "%c%"=="3" goto reg_repair
if "%c%"=="4" goto update_fix
if "%c%"=="5" goto store_repair
if "%c%"=="6" goto dll_fix
if "%c%"=="7" goto explorer_fix
if "%c%"=="8" goto service_repair
if "%c%"=="9" goto one_click_repair
if "%c%"=="99" goto main
goto cat_repair

:: ---- 3.1 SFC & DISM ----
:sfc_dism
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [3.1] SFC ^& DISM REPAIR%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] SFC /ScanNow                               [2] SFC /VerifyOnly                            [3] SFC /ScanFile (Custom)                     %C_RESET%
echo %C_GREEN%  [4] DISM CheckHealth                           [5] DISM ScanHealth                            [6] DISM RestoreHealth                         %C_RESET%
echo %C_GREEN%  [7] DISM from ISO/USB                          [8] Component Store Cleanup                    [9] Reset Base (StartComponent)                %C_RESET%
echo %C_GREEN%  [10] Full SFC + DISM                           [11] CBS Log View                              [12] Catroot2 Reset                            %C_RESET%
echo %C_GREEN%  [13] SoftwareDistribution Reset                [14] Pending.xml Delete                        [15] DISM / WIM Auto Center                    %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (sfc /scannow & pause & goto sfc_dism)
if "%c%"=="2" (sfc /verifyonly & pause & goto sfc_dism)
if "%c%"=="3" (set "file=" & set /p file=File path: & sfc /scanfile=!file! & pause & goto sfc_dism)
if "%c%"=="4" (DISM /Online /Cleanup-Image /CheckHealth & pause & goto sfc_dism)
if "%c%"=="5" (DISM /Online /Cleanup-Image /ScanHealth & pause & goto sfc_dism)
if "%c%"=="6" (DISM /Online /Cleanup-Image /RestoreHealth & pause & goto sfc_dism)
if "%c%"=="7" (set "src=" & set /p src=Source path e.g. D:\Sources\install.wim: & DISM /Online /Cleanup-Image /RestoreHealth /Source:!src! /LimitAccess & pause & goto sfc_dism)
if "%c%"=="8" (DISM /Online /Cleanup-Image /StartComponentCleanup & pause & goto sfc_dism)
if "%c%"=="9" (DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase & pause & goto sfc_dism)
if "%c%"=="10" (sfc /scannow & DISM /Online /Cleanup-Image /RestoreHealth & echo Full Repair Done. & pause & goto sfc_dism)
if "%c%"=="11" (notepad C:\Windows\Logs\CBS\CBS.log & goto sfc_dism)
if "%c%"=="12" (net stop cryptsvc & ren C:\Windows\System32\catroot2 catroot2.old & net start cryptsvc & echo Catroot2 Reset. & pause & goto sfc_dism)
if "%c%"=="13" (net stop wuauserv & ren C:\Windows\SoftwareDistribution SoftwareDistribution.old & net start wuauserv & echo SoftwareDistribution Reset. & pause & goto sfc_dism)
if "%c%"=="14" (del /f /q C:\Windows\WinSxS\pending.xml & echo Pending.xml deleted. & pause & goto sfc_dism)
if "%c%"=="15" (set "WIM_CENTER_BACK=sfc_dism" & goto dism_wim_center)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto sfc_dism

:: ---- 3.2 Boot & MBR Repair ----
:boot_repair
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [3.2] BOOT ^& MBR REPAIR%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Bootrec /FixMBR                            [2] Bootrec /FixBoot                           [3] Bootrec /RebuildBCD                        %C_RESET%
echo %C_GREEN%  [4] Bootrec /ScanOS                            [5] BCDEdit View                               [6] Startup Repair (Reboot)                    %C_RESET%
echo %C_GREEN%  [7] Safe Mode Enable                           [8] Safe Mode Disable                          [9] Boot to Recovery                           %C_RESET%
echo %C_GREEN%  [10] Boot Repair Full                          [11] BCD Backup                                [12] BCD Restore                               %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (call :run_bootrec /fixmbr & pause & goto boot_repair)
if "%c%"=="2" (call :run_bootrec /fixboot & pause & goto boot_repair)
if "%c%"=="3" (call :run_bootrec /rebuildbcd & pause & goto boot_repair)
if "%c%"=="4" (call :run_bootrec /scanos & pause & goto boot_repair)
if "%c%"=="5" (bcdedit & pause & goto boot_repair)
if "%c%"=="6" (shutdown /r /o /f /t 0)
if "%c%"=="7" (bcdedit /set {current} safeboot minimal & echo Safe Mode set. Restart now. & pause & goto boot_repair)
if "%c%"=="8" (bcdedit /deletevalue {current} safeboot & echo Normal boot restored. & pause & goto boot_repair)
if "%c%"=="9" (shutdown /r /o /t 0)
if "%c%"=="10" (call :run_bootrec /fixmbr & call :run_bootrec /fixboot & call :run_bootrec /rebuildbcd & echo Boot Repair Done. & pause & goto boot_repair)
if "%c%"=="11" (bcdedit /export "%USERPROFILE%\Desktop\BCD_Backup" & echo BCD Backed up to Desktop. & pause & goto boot_repair)
if "%c%"=="12" (set "bcd=" & set /p bcd=BCD Backup path: & bcdedit /import "!bcd!" & pause & goto boot_repair)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto boot_repair

:: ---- 3.3 Registry Repair ----
:reg_repair
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [3.3] REGISTRY REPAIR%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Open Registry Editor                       [2] Registry Backup (HKCU)                     [3] Registry Backup (HKLM)                     %C_RESET%
echo %C_GREEN%  [4] Registry Backup (Full)                     [5] Group Policy Reset                         [6] EXE Association Fix                        %C_RESET%
echo %C_GREEN%  [7] File Association Fix                       [8] Registry Scan (SFC)                        [9] Trust Installer Fix                        %C_RESET%
echo %C_GREEN%  [10] WMI Repair                                [11] COM+ Repair                               [12] Font Registry Fix                         %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" regedit & goto reg_repair)
if "%c%"=="2" (reg export HKCU "%USERPROFILE%\Desktop\HKCU_Backup.reg" & echo HKCU backed up to Desktop. & pause & goto reg_repair)
if "%c%"=="3" (reg export HKLM "%USERPROFILE%\Desktop\HKLM_Backup.reg" & echo HKLM backed up to Desktop. & pause & goto reg_repair)
if "%c%"=="4" (
    if not exist "%USERPROFILE%\Desktop\RegBackup" mkdir "%USERPROFILE%\Desktop\RegBackup"
    reg export HKCU "%USERPROFILE%\Desktop\RegBackup\HKCU.reg" /y
    reg export HKLM "%USERPROFILE%\Desktop\RegBackup\HKLM.reg" /y
    reg export HKCR "%USERPROFILE%\Desktop\RegBackup\HKCR.reg" /y
    echo Full Registry Backup Done to Desktop\RegBackup
    pause & goto reg_repair
)
if "%c%"=="5" (rd /s /q "%ALLUSERSPROFILE%\Microsoft\Group Policy" & gpupdate /force & echo GPO Reset. & pause & goto reg_repair)
if "%c%"=="6" (assoc .exe=exefile & ftype exefile="%1" %* & echo EXE Fix Done. & pause & goto reg_repair)
if "%c%"=="7" (assoc .exe=exefile & echo File Association Fixed. & pause & goto reg_repair)
if "%c%"=="8" (sfc /scannow & pause & goto reg_repair)
if "%c%"=="9" (sc config trustedinstaller start= auto & net start trustedinstaller & pause & goto reg_repair)
if "%c%"=="10" (winmgmt /resetrepository & echo WMI Reset. & pause & goto reg_repair)
if "%c%"=="11" (net stop msdtc & net start msdtc & echo COM+ Reset. & pause & goto reg_repair)
if "%c%"=="12" (reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" /va /f & echo Font Registry cleared. Reinstall fonts. & pause & goto reg_repair)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto reg_repair

:: ---- 3.4 Windows Update Fix ----
:update_fix
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [3.4] WINDOWS UPDATE FIX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Windows Update Settings                    [2] Reset Update Services                      [3] Clear Update Cache                         %C_RESET%
echo %C_GREEN%  [4] Force Update Check                         [5] BITS Reset                                 [6] Windows Modules Reset                      %C_RESET%
echo %C_GREEN%  [7] Update Error Log                           [8] Rearm Activation                           [9] Windows Update Troubleshoot                %C_RESET%
echo %C_GREEN%  [10] Disable Auto Updates                      [11] Enable Auto Updates                       [12] Pending Updates Check                     %C_RESET%
echo %C_GREEN%  [13] WSUS Reset (Enterprise)                   %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" ms-settings:windowsupdate & goto update_fix)
if "%c%"=="2" (net stop wuauserv & net stop cryptSvc & net stop bits & net stop msiserver & net start bits & net start cryptSvc & net start wuauserv & net start msiserver & echo Services Reset. & pause & goto update_fix)
if "%c%"=="3" (net stop wuauserv & ren C:\Windows\SoftwareDistribution SoftwareDistribution.old & ren C:\Windows\System32\catroot2 catroot2.old & net start wuauserv & echo Cache Cleared. & pause & goto update_fix)
if "%c%"=="4" (usoclient StartScan & echo Update scan started. & pause & goto update_fix)
if "%c%"=="5" (net stop bits & net start bits & echo BITS Reset. & pause & goto update_fix)
if "%c%"=="6" (net stop trustedinstaller & net start trustedinstaller & echo Windows Modules Reset. & pause & goto update_fix)
if "%c%"=="7" (notepad C:\Windows\WindowsUpdate.log & goto update_fix)
if "%c%"=="8" (slmgr /rearm & echo Activation Rearm Done. & pause & goto update_fix)
if "%c%"=="9" (msdt.exe /id WindowsUpdateDiagnostic & goto update_fix)
if "%c%"=="10" (sc config wuauserv start= disabled & net stop wuauserv & echo Auto Updates Disabled. & pause & goto update_fix)
if "%c%"=="11" (sc config wuauserv start= auto & net start wuauserv & echo Auto Updates Enabled. & pause & goto update_fix)
if "%c%"=="12" (powershell -command "Get-WUList" >nul 2>&1 || echo Install PSWindowsUpdate module first. & call :ps_qfe_list & pause & goto update_fix)
if "%c%"=="13" (reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f & gpupdate /force & echo WSUS Reset. & pause & goto update_fix)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto update_fix

:: ---- 3.5 Store & App Repair ----
:store_repair
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [3.5] STORE ^& APP REPAIR%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] WSReset (Store Reset)                      [2] Store Troubleshooter                       [3] Reinstall Store                            %C_RESET%
echo %C_GREEN%  [4] Reinstall All UWP Apps                     [5] Reset Specific App                         [6] Repair Specific App                        %C_RESET%
echo %C_GREEN%  [7] Remove Specific App                        [8] List All Installed Apps                    [9] Calculator Reset                           %C_RESET%
echo %C_GREEN%  [10] Photos App Reset                          [11] Mail App Reset                            [12] Start Menu Reset                          %C_RESET%
echo %C_GREEN%  [13] Cortana Reset                             [14] Microsoft Teams Reset                     %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (wsreset.exe & goto store_repair)
if "%c%"=="2" (msdt.exe /id WindowsStoreDiagnostic & goto store_repair)
if "%c%"=="3" goto store_reinstall_store
if "%c%"=="4" goto store_reinstall_all_uwp
if "%c%"=="5" (set "app=" & set /p app=App Name partial: & powershell -command "Get-AppxPackage *!app!* | Reset-AppxPackage" & pause & goto store_repair)
if "%c%"=="6" goto store_repair_specific_app
if "%c%"=="7" (set "app=" & set /p app=App Name partial: & powershell -command "Get-AppxPackage *!app!* | Remove-AppxPackage" & pause & goto store_repair)
if "%c%"=="8" (powershell -command "Get-AppxPackage | Select-Object Name,Version | Format-Table -AutoSize" & pause & goto store_repair)
if "%c%"=="9" (powershell -command "Get-AppxPackage *calculator* | Reset-AppxPackage" & pause & goto store_repair)
if "%c%"=="10" (powershell -command "Get-AppxPackage *photos* | Reset-AppxPackage" & pause & goto store_repair)
if "%c%"=="11" (powershell -command "Get-AppxPackage *windowscommunicationsapps* | Reset-AppxPackage" & pause & goto store_repair)
if "%c%"=="12" (powershell -command "Get-AppxPackage Microsoft.Windows.StartMenuExperienceHost | Reset-AppxPackage" & pause & goto store_repair)
if "%c%"=="13" (powershell -command "Get-AppxPackage *cortana* | Reset-AppxPackage" & pause & goto store_repair)
if "%c%"=="14" (powershell -command "Get-AppxPackage *teams* | Reset-AppxPackage" & pause & goto store_repair)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto store_repair

:store_reinstall_store
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage -AllUsers Microsoft.WindowsStore | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $_.InstallLocation 'AppXManifest.xml') }"
pause
goto store_repair

:store_reinstall_all_uwp
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage -AllUsers | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $_.InstallLocation 'AppXManifest.xml') }"
pause
goto store_repair

:store_repair_specific_app
set "app=" & set /p app=App Name partial:
if "!app!"=="" goto store_repair
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage *!app!* | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $_.InstallLocation 'AppXManifest.xml') }"
pause
goto store_repair

:: ---- 3.6 DLL & Runtime Fix ----
:dll_fix
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [3.6] DLL ^& RUNTIME FIX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Register All DLLs                          [2] Register Specific DLL                      [3] Unregister DLL                             %C_RESET%
echo %C_GREEN%  [4] VC++ Runtime Info                          [5] .NET Repair Command                        [6] DirectX Repair                             %C_RESET%
echo %C_GREEN%  [7] Missing DLL Scan (SFC)                     [8] System32 DLL Check                         [9] Common DLL Re-register                     %C_RESET%
echo %C_GREEN%  [10] MSI Repair                                %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (for %%i in (%windir%\system32\*.dll) do regsvr32 /s %%i & echo All DLLs re-registered. & pause & goto dll_fix)
if "%c%"=="2" (set "dll=" & set /p dll=DLL name e.g. msxml4.dll: & regsvr32 "C:\Windows\System32\!dll!" & pause & goto dll_fix)
if "%c%"=="3" (set "dll=" & set /p dll=DLL name: & regsvr32 /u "C:\Windows\System32\!dll!" & pause & goto dll_fix)
if "%c%"=="4" (call :ps_vcredist_list & pause & goto dll_fix)
if "%c%"=="5" (sfc /scannow & DISM /Online /Cleanup-Image /RestoreHealth & pause & goto dll_fix)
if "%c%"=="6" (dxdiag & goto dll_fix)
if "%c%"=="7" (sfc /scannow & pause & goto dll_fix)
if "%c%"=="8" (dir C:\Windows\System32\*.dll ^| find /c ".dll" & pause & goto dll_fix)
if "%c%"=="9" (regsvr32 vbscript.dll & regsvr32 jscript.dll & regsvr32 mshtml.dll & regsvr32 browseui.dll & echo Common DLLs re-registered. & pause & goto dll_fix)
if "%c%"=="10" (msiexec /unregister & msiexec /regserver & echo MSI Repaired. & pause & goto dll_fix)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto dll_fix

:: ---- 3.7 Explorer & UI Fix ----
:explorer_fix
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [3.7] EXPLORER ^& UI FIX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Restart Explorer                           [2] Start Menu Fix                             [3] Taskbar Fix                                %C_RESET%
echo %C_GREEN%  [4] Search Fix                                 [5] Black Screen Fix                           [6] Desktop Icons Reset                        %C_RESET%
echo %C_GREEN%  [7] Thumbnail Cache Clear                      [8] Icon Cache Clear                           [9] Context Menu Fix                           %C_RESET%
echo %C_GREEN%  [10] Font Cache Reset                          [11] Windows Shell Repair                      [12] Explorer Crash Fix                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (taskkill /f /im explorer.exe & start explorer.exe & echo Explorer restarted. & pause & goto explorer_fix)
if "%c%"=="2" (powershell -command "Get-AppxPackage Microsoft.Windows.StartMenuExperienceHost | Reset-AppxPackage" & pause & goto explorer_fix)
if "%c%"=="3" (taskkill /f /im explorer.exe & start explorer.exe & pause & goto explorer_fix)
if "%c%"=="4" (taskkill /f /im SearchUI.exe & taskkill /f /im SearchApp.exe & pause & goto explorer_fix)
if "%c%"=="5" (taskkill /f /im explorer.exe & start explorer.exe & pause & goto explorer_fix)
if "%c%"=="6" (ie4uinit.exe -show & pause & goto explorer_fix)
if "%c%"=="7" (del /f /s /q "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" & echo Thumbnail Cache Cleared. & pause & goto explorer_fix)
if "%c%"=="8" (taskkill /f /im explorer.exe & del /f /s /q "%LocalAppData%\IconCache.db" & start explorer.exe & echo Icon Cache Cleared. & pause & goto explorer_fix)
if "%c%"=="9" (reg delete "HKCU\Software\Classes\*\shellex\ContextMenuHandlers" /f & echo Context Menu Reset. Restart Explorer. & pause & goto explorer_fix)
if "%c%"=="10" (net stop fontcache & del /f /q "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache*" & net start fontcache & echo Font Cache Reset. & pause & goto explorer_fix)
if "%c%"=="11" (sfc /scannow & pause & goto explorer_fix)
if "%c%"=="12" (sfc /scannow & DISM /Online /Cleanup-Image /RestoreHealth & taskkill /f /im explorer.exe & start explorer.exe & pause & goto explorer_fix)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto explorer_fix

:: ---- 3.8 Service Repair ----
:service_repair
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [3.8] SERVICE REPAIR%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Services Manager (GUI)                     [2] List Running Services                      [3] List Stopped Services                      %C_RESET%
echo %C_GREEN%  [4] Start Service                              [5] Stop Service                               [6] Restart Service                            %C_RESET%
echo %C_GREEN%  [7] Set Service Auto Start                     [8] Set Service Disabled                       [9] Audio Service Fix                          %C_RESET%
echo %C_GREEN%  [10] Print Spooler Fix                         [11] Windows Update Service Fix                [12] WMI Service Fix                           %C_RESET%
echo %C_GREEN%  [13] Security Center Fix                       [14] Windows Search Fix                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" services.msc & goto service_repair)
if "%c%"=="2" (sc query type= service state= running & pause & goto service_repair)
if "%c%"=="3" (sc query type= service state= stopped & pause & goto service_repair)
if "%c%"=="4" (set "svc=" & set /p svc=Service name: & net start !svc! & pause & goto service_repair)
if "%c%"=="5" (set "svc=" & set /p svc=Service name: & net stop !svc! & pause & goto service_repair)
if "%c%"=="6" (set "svc=" & set /p svc=Service name: & net stop !svc! & net start !svc! & pause & goto service_repair)
if "%c%"=="7" (set "svc=" & set /p svc=Service name: & sc config !svc! start= auto & pause & goto service_repair)
if "%c%"=="8" (set "svc=" & set /p svc=Service name: & sc config !svc! start= disabled & pause & goto service_repair)
if "%c%"=="9" (net stop audiosrv & net stop AudioEndpointBuilder & net start AudioEndpointBuilder & net start audiosrv & echo Audio Fixed. & pause & goto service_repair)
if "%c%"=="10" (net stop spooler & del /f /s /q "C:\Windows\System32\spool\PRINTERS\*" & net start spooler & echo Print Spooler Fixed. & pause & goto service_repair)
if "%c%"=="11" (net stop wuauserv & net start wuauserv & echo Windows Update Fixed. & pause & goto service_repair)
if "%c%"=="12" (winmgmt /resetrepository & echo WMI Fixed. & pause & goto service_repair)
if "%c%"=="13" (sc config wscsvc start= auto & net start wscsvc & echo Security Center Fixed. & pause & goto service_repair)
if "%c%"=="14" (net stop wsearch & net start wsearch & echo Windows Search Fixed. & pause & goto service_repair)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto service_repair

:: ---- 3.9 One Click Full Repair ----
:one_click_repair
cls
color 0E
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% [3.9] ONE CLICK FULL REPAIR%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo  Starting Full Windows Repair... This will take time.
echo %C_CYAN%============================================================%C_RESET%
echo.
echo [STEP 1] Running SFC...
sfc /scannow
echo.
echo [STEP 2] Running DISM RestoreHealth...
DISM /Online /Cleanup-Image /RestoreHealth
echo.
echo [STEP 3] Resetting Windows Update Services...
net stop wuauserv & net stop bits & net stop cryptSvc
ren C:\Windows\SoftwareDistribution SoftwareDistribution.old 2>nul
net start wuauserv & net start bits & net start cryptSvc
echo.
echo [STEP 4] Flushing DNS ^& Winsock Reset...
ipconfig /flushdns
netsh winsock reset
echo.
echo [STEP 5] Fixing Explorer...
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe
echo.
echo [STEP 6] Resetting Store...
wsreset.exe
echo.
echo %C_CYAN%============================================================%C_RESET%
echo  FULL REPAIR COMPLETE! Restart your PC for best results.
echo %C_CYAN%============================================================%C_RESET%
pause
goto go_back

:: ============================================================
:: CATEGORY 4: SECURITY CENTER
:: ============================================================
:cat_security
set "BACK_MENU=cat_security"
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  [CATEGORY 4] SECURITY CENTER
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Defender ^& Antivirus                      [2] Firewall (see Category 2^>4)               [3] User ^& Password Security                  %C_RESET%
echo %C_GREEN%  [4] USB ^& Device Security                     [5] BitLocker ^& Encryption                    [6] Malware Cleanup                            %C_RESET%
echo %C_GREEN%  [7] Network Security                           [8] Privacy Settings                           [9] Full Security Audit                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" goto defender_tools
if "%c%"=="2" goto firewall_mgr
if "%c%"=="3" goto user_security
if "%c%"=="4" goto usb_security
if "%c%"=="5" goto bitlocker_tools
if "%c%"=="6" goto malware_cleanup
if "%c%"=="7" goto net_security
if "%c%"=="8" goto privacy_settings
if "%c%"=="9" goto security_audit
if "%c%"=="99" goto main
goto cat_security

:: ---- 4.1 Defender Tools ----
:defender_tools
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [4.1] DEFENDER ^& ANTIVIRUS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Open Defender                              [2] Quick Scan                                 [3] Full Scan                                  %C_RESET%
echo %C_GREEN%  [4] Offline Scan                               [5] Update Definitions                         [6] Defender Status                            %C_RESET%
echo %C_GREEN%  [7] Defender Enable                            [8] Defender Disable (Careful!)                [9] Exclusion Add                              %C_RESET%
echo %C_GREEN%  [10] Exclusion View                            [11] Threat History                            [12] Quarantine View                           %C_RESET%
echo %C_GREEN%  [13] Cloud Protection Enable                   [14] PUA Protection Enable                     [15] Real-Time Protection ON                   %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" windowsdefender: & goto defender_tools)
if "%c%"=="2" (powershell -command "Start-MpScan -ScanType QuickScan" & pause & goto defender_tools)
if "%c%"=="3" (powershell -command "Start-MpScan -ScanType FullScan" & pause & goto defender_tools)
if "%c%"=="4" (powershell -command "Start-MpWDOScan" & pause & goto defender_tools)
if "%c%"=="5" (powershell -command "Update-MpSignature" & echo Definitions Updated. & pause & goto defender_tools)
if "%c%"=="6" (powershell -command "Get-MpComputerStatus" & pause & goto defender_tools)
if "%c%"=="7" (powershell -command "Set-MpPreference -DisableRealtimeMonitoring $false" & echo Defender Enabled. & pause & goto defender_tools)
if "%c%"=="8" (echo WARNING: Disabling Defender is dangerous! & set "confirm=" & set /p confirm=Type YES to continue: & if "!confirm!"=="YES" powershell -command "Set-MpPreference -DisableRealtimeMonitoring $true" & pause & goto defender_tools)
if "%c%"=="9" (set "exclude_path=" & set /p exclude_path=Path to exclude: & powershell -command "Add-MpPreference -ExclusionPath '!exclude_path!'" & echo Exclusion added. & pause & goto defender_tools)
if "%c%"=="10" (powershell -command "Get-MpPreference | Select-Object ExclusionPath,ExclusionProcess" & pause & goto defender_tools)
if "%c%"=="11" (powershell -command "Get-MpThreatDetection" & pause & goto defender_tools)
if "%c%"=="12" (powershell -command "Get-MpThreat" & pause & goto defender_tools)
if "%c%"=="13" (powershell -command "Set-MpPreference -MAPSReporting Advanced" & echo Cloud Protection ON. & pause & goto defender_tools)
if "%c%"=="14" (powershell -command "Set-MpPreference -PUAProtection Enabled" & echo PUA Protection ON. & pause & goto defender_tools)
if "%c%"=="15" (powershell -command "Set-MpPreference -DisableRealtimeMonitoring $false" & echo Real-Time Protection ON. & pause & goto defender_tools)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto defender_tools

:: ---- 4.3 User & Password Security ----
:user_security
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [4.3] USER ^& PASSWORD SECURITY%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] List All Users                             [2] Create User                                [3] Delete User                                %C_RESET%
echo %C_GREEN%  [4] Change Password                            [5] Add to Admin Group                         [6] Remove from Admin                          %C_RESET%
echo %C_GREEN%  [7] Enable User Account                        [8] Disable User Account                       [9] Guest Account Disable                      %C_RESET%
echo %C_GREEN%  [10] Guest Account Enable                      [11] Password Policy View                      [12] Password Policy Set                       %C_RESET%
echo %C_GREEN%  [13] Account Lockout Policy                    [14] Local Security Policy GUI                 [15] Credential Manager                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (net user & pause & goto user_security)
if "%c%"=="2" (set "user=" & set /p user=Username: & set "pass=" & set /p pass=Password: & net user !user! !pass! /add & echo User created. & pause & goto user_security)
if "%c%"=="3" (set "user=" & set /p user=Username to delete: & net user !user! /delete & pause & goto user_security)
if "%c%"=="4" (set "user=" & set /p user=Username: & set "pass=" & set /p pass=New Password: & net user !user! !pass! & pause & goto user_security)
if "%c%"=="5" (set "user=" & set /p user=Username: & net localgroup Administrators !user! /add & pause & goto user_security)
if "%c%"=="6" (set "user=" & set /p user=Username: & net localgroup Administrators !user! /delete & pause & goto user_security)
if "%c%"=="7" (set "user=" & set /p user=Username: & net user !user! /active:yes & pause & goto user_security)
if "%c%"=="8" (set "user=" & set /p user=Username: & net user !user! /active:no & pause & goto user_security)
if "%c%"=="9" (net user Guest /active:no & echo Guest Account Disabled. & pause & goto user_security)
if "%c%"=="10" (net user Guest /active:yes & echo Guest Account Enabled. & pause & goto user_security)
if "%c%"=="11" (net accounts & pause & goto user_security)
if "%c%"=="12" (set "minlen=" & set /p minlen=Min Password Length: & net accounts /minpwlen:!minlen! & pause & goto user_security)
if "%c%"=="13" (set "max=" & set /p max=Max bad logon attempts: & net accounts /lockoutthreshold:!max! & pause & goto user_security)
if "%c%"=="14" (start "" secpol.msc & pause & goto user_security)
if "%c%"=="15" (start "" control /name Microsoft.CredentialManager & pause & goto user_security)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto user_security

:: ---- 4.4 USB & Device Security ----
:usb_security
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [4.4] USB ^& DEVICE SECURITY%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Block USB Storage                          [2] Allow USB Storage                          [3] USB Status Check                           %C_RESET%
echo %C_GREEN%  [4] Autorun Disable                            [5] Autorun Enable                             [6] Device Install Block                       %C_RESET%
echo %C_GREEN%  [7] Device Install Allow                       [8] USB Devices List                           [9] CD/DVD Disable                             %C_RESET%
echo %C_GREEN%  [10] CD/DVD Enable                             %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (reg add "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" /v Start /t REG_DWORD /d 4 /f & echo USB Storage BLOCKED. & pause & goto usb_security)
if "%c%"=="2" (reg add "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" /v Start /t REG_DWORD /d 3 /f & echo USB Storage ALLOWED. & pause & goto usb_security)
if "%c%"=="3" (reg query "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" /v Start & pause & goto usb_security)
if "%c%"=="4" (reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\IniFileMapping\Autorun.inf" /ve /t REG_SZ /d "@SYS:DoesNotExist" /f & echo Autorun Disabled. & pause & goto usb_security)
if "%c%"=="5" (reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\IniFileMapping\Autorun.inf" /f & echo Autorun Enabled. & pause & goto usb_security)
if "%c%"=="6" (start "" gpedit.msc & echo Go to: Computer Config - Admin Templates - System - Device Installation & pause & goto usb_security)
if "%c%"=="7" (start "" gpedit.msc & goto usb_security)
if "%c%"=="8" (pnputil /enum-devices /class USB & pause & goto usb_security)
if "%c%"=="9" (reg add "HKLM\SYSTEM\CurrentControlSet\Services\cdrom" /v Start /t REG_DWORD /d 4 /f & echo CD/DVD Disabled. & pause & goto usb_security)
if "%c%"=="10" (reg add "HKLM\SYSTEM\CurrentControlSet\Services\cdrom" /v Start /t REG_DWORD /d 1 /f & echo CD/DVD Enabled. & pause & goto usb_security)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto usb_security

:: ---- 4.5 BitLocker Tools ----
:bitlocker_tools
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [4.5] BITLOCKER ^& ENCRYPTION%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] BitLocker Status (All)                     [2] Enable BitLocker (C:)                      [3] Disable BitLocker (C:)                     %C_RESET%
echo %C_GREEN%  [4] BitLocker GUI                              [5] Backup Recovery Key                        [6] Unlock BitLocker Drive                     %C_RESET%
echo %C_GREEN%  [7] BitLocker on USB                           [8] EFS Encryption Info                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (manage-bde -status & pause & goto bitlocker_tools)
if "%c%"=="2" (manage-bde -on C: & echo BitLocker enabling on C:. & pause & goto bitlocker_tools)
if "%c%"=="3" (manage-bde -off C: & echo BitLocker disabling on C:. & pause & goto bitlocker_tools)
if "%c%"=="4" (start "" control /name Microsoft.BitLockerDriveEncryption & goto bitlocker_tools)
if "%c%"=="5" (manage-bde -protectors -get C: & pause & goto bitlocker_tools)
if "%c%"=="6" (set "drv=" & set /p drv=Drive Letter: & set "key=" & set /p key=Recovery Key: & manage-bde -unlock !drv!: -RecoveryKey "!key!" & pause & goto bitlocker_tools)
if "%c%"=="7" (set "drv=" & set /p drv=USB Drive Letter: & manage-bde -on !drv!: & pause & goto bitlocker_tools)
if "%c%"=="8" (cipher /status & pause & goto bitlocker_tools)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto bitlocker_tools

:: ---- 4.6 Malware Cleanup ----
:malware_cleanup
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [4.6] MALWARE CLEANUP%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Malware Removal Tool (MRT)                 [2] Defender Full Scan                         [3] Temp Files Cleanup                         %C_RESET%
echo %C_GREEN%  [4] Startup Malware Check                      [5] Suspicious Process Check                   [6] Hosts File Check                           %C_RESET%
echo %C_GREEN%  [7] Run from Safe Mode                         [8] Safe Mode Malware Boot                     [9] Kill Suspicious Processes                  %C_RESET%
echo %C_GREEN%  [10] Clear Run History                         [11] Clear Temp Folders                        [12] Emergency Process Kill                    %C_RESET%
echo %C_GREEN%  [13] One Click Malware Removal                 %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" mrt & goto malware_cleanup)
if "%c%"=="2" (powershell -command "Start-MpScan -ScanType FullScan" & pause & goto malware_cleanup)
if "%c%"=="3" (call :clean_folder_contents "%TEMP%" "User Temp" & call :clean_folder_contents "C:\Windows\Temp" "Windows Temp" & echo Temp Cleaned. & pause & goto malware_cleanup)
if "%c%"=="4" (reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run & reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run & pause & goto malware_cleanup)
if "%c%"=="5" (tasklist & pause & goto malware_cleanup)
if "%c%"=="6" (type C:\Windows\System32\drivers\etc\hosts & pause & goto malware_cleanup)
if "%c%"=="7" (echo Restart in Safe Mode then run this toolkit again. & pause & goto malware_cleanup)
if "%c%"=="8" (bcdedit /set {current} safeboot minimal & echo Restart to boot in Safe Mode. & pause & goto malware_cleanup)
if "%c%"=="9" (
    echo Killing known malware process names...
    for %%p in (rat.exe keylogger.exe malware.exe trojan.exe virus.exe worm.exe backdoor.exe) do (
        taskkill /f /im %%p >nul 2>&1
    )
    echo Done.
    pause & goto malware_cleanup
)
if "%c%"=="10" (reg delete HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /va /f & echo Run History Cleared. & pause & goto malware_cleanup)
if "%c%"=="11" (call :one_clean_core & echo All Temp Cleaned. & pause & goto malware_cleanup)
if "%c%"=="12" (start "" taskmgr & pause & goto malware_cleanup)
if "%c%"=="13" (
    echo ONE CLICK MALWARE REMOVAL RUNNING...
    call :clean_folder_contents "%TEMP%" "User Temp"
    call :clean_folder_contents "C:\Windows\Temp" "Windows Temp"
    powershell -command "Start-MpScan -ScanType QuickScan"
    reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
    echo DONE. Check scan results above.
    pause & goto malware_cleanup
)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto malware_cleanup

:: ---- 4.7 Network Security ----
:net_security
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [4.7] NETWORK SECURITY%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Open Ports Check                           [2] Listening Ports                            [3] Suspicious Connections                     %C_RESET%
echo %C_GREEN%  [4] RDP Security Harden                        [5] SMBv1 Disable (Security)                   [6] Firewall Reset                             %C_RESET%
echo %C_GREEN%  [7] Network Protection Enable                  [8] ASR Rules Enable                           [9] DNS Over HTTPS (DoH)                       %C_RESET%
echo %C_GREEN%  [10] MAC Spoofing Check                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (netstat -ano & pause & goto net_security)
if "%c%"=="2" (netstat -an ^| findstr LISTENING & pause & goto net_security)
if "%c%"=="3" (netstat -ano ^| findstr ESTABLISHED & pause & goto net_security)
if "%c%"=="4" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 1 /f & echo NLA Enabled for RDP. & pause & goto net_security)
if "%c%"=="5" (powershell -command "Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force" & echo SMBv1 Disabled. & pause & goto net_security)
if "%c%"=="6" (netsh advfirewall reset & echo Firewall Reset. & pause & goto net_security)
if "%c%"=="7" (powershell -command "Set-MpPreference -EnableNetworkProtection Enabled" & echo Network Protection ON. & pause & goto net_security)
if "%c%"=="8" (powershell -command "Set-MpPreference -AttackSurfaceReductionRules_Ids * -AttackSurfaceReductionRules_Actions Enabled" & pause & goto net_security)
if "%c%"=="9" (start "" ms-settings:network-proxy & echo Enable DNS over HTTPS in Network settings. & pause & goto net_security)
if "%c%"=="10" (getmac /v & pause & goto net_security)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto net_security

:: ---- 4.8 Privacy Settings ----
:privacy_settings
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [4.8] PRIVACY SETTINGS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Privacy Settings (GUI)                     [2] Disable Telemetry                          [3] Disable Activity History                   %C_RESET%
echo %C_GREEN%  [4] Disable Location                           [5] Disable Advertising ID                     [6] Disable Camera Access                      %C_RESET%
echo %C_GREEN%  [7] Disable Mic Access                         [8] Clear Clipboard                            [9] Clear Search History                       %C_RESET%
echo %C_GREEN%  [10] Disable Cortana                           [11] Disable Timeline                          [12] Clear Activity History                    %C_RESET%
echo %C_GREEN%  [13] Enable Telemetry                         [14] Enable Activity History                  [15] Enable Location                         %C_RESET%
echo %C_GREEN%  [16] Enable Advertising ID                    [17] Enable Camera Access                     [18] Enable Mic Access                       %C_RESET%
echo %C_GREEN%  [19] Enable Cortana                           [20] Enable Timeline                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" ms-settings:privacy & goto privacy_settings)
if "%c%"=="2" (reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f & echo Telemetry Disabled. & pause & goto privacy_settings)
if "%c%"=="3" (reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f & echo Activity History Disabled. & pause & goto privacy_settings)
if "%c%"=="4" (reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Deny /f & echo Location Disabled. & pause & goto privacy_settings)
if "%c%"=="5" (reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f & echo Advertising ID Disabled. & pause & goto privacy_settings)
if "%c%"=="6" (reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" /v Value /t REG_SZ /d Deny /f & echo Camera Access Disabled. & pause & goto privacy_settings)
if "%c%"=="7" (reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" /v Value /t REG_SZ /d Deny /f & echo Microphone Disabled. & pause & goto privacy_settings)
if "%c%"=="8" (echo off ^| clip & echo Clipboard Cleared. & pause & goto privacy_settings)
if "%c%"=="9" (reg delete HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery /va /f & echo Search History Cleared. & pause & goto privacy_settings)
if "%c%"=="10" (reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f & echo Cortana Disabled. & pause & goto privacy_settings)
if "%c%"=="11" (reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f & echo Timeline Disabled. & pause & goto privacy_settings)
if "%c%"=="12" (powershell -command "Clear-ActivityHistory" >nul 2>&1 & echo Activity History Cleared. & pause & goto privacy_settings)
if "%c%"=="13" (reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 1 /f & echo Telemetry Enabled. & pause & goto privacy_settings)
if "%c%"=="14" (reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 1 /f & echo Activity History Enabled. & pause & goto privacy_settings)
if "%c%"=="15" (reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f & echo Location Enabled. & pause & goto privacy_settings)
if "%c%"=="16" (reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 1 /f & echo Advertising ID Enabled. & pause & goto privacy_settings)
if "%c%"=="17" (reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" /v Value /t REG_SZ /d Allow /f & echo Camera Access Enabled. & pause & goto privacy_settings)
if "%c%"=="18" (reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" /v Value /t REG_SZ /d Allow /f & echo Microphone Enabled. & pause & goto privacy_settings)
if "%c%"=="19" (reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 1 /f & echo Cortana Enabled. & pause & goto privacy_settings)
if "%c%"=="20" (reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 1 /f & echo Timeline Enabled. & pause & goto privacy_settings)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto privacy_settings

:: ---- 4.9 Security Audit ----
:security_audit
cls
color 0C
echo %C_CYAN%============================================================%C_RESET%
echo %C_MAGENTA% [4.9] FULL SECURITY AUDIT%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
echo Running Full Security Audit... Please wait...
echo.
echo === USER ACCOUNTS ===
net user
echo.
echo === ADMIN GROUP MEMBERS ===
net localgroup Administrators
echo.
echo === RUNNING SERVICES ===
sc query type= service state= running
echo.
echo === OPEN PORTS ===
netstat -an ^| findstr LISTENING
echo.
echo === STARTUP PROGRAMS ===
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
echo.
echo === FIREWALL STATUS ===
netsh advfirewall show allprofiles state
echo.
echo === DEFENDER STATUS ===
powershell -command "Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled,AntispywareEnabled,AntispywareSignatureLastUpdated"
echo.
echo === HOSTS FILE ===
type C:\Windows\System32\drivers\etc\hosts
echo.
echo %C_CYAN%============================================================%C_RESET%
echo  AUDIT COMPLETE. Review above for any issues.
echo %C_CYAN%============================================================%C_RESET%
pause
goto go_back

:: ============================================================
:: CATEGORY 5: PERFORMANCE & CLEANUP
:: ============================================================
:cat_performance
set "BACK_MENU=cat_performance"
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  [CATEGORY 5] PERFORMANCE ^& CLEANUP
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] System Cleanup                             [2] RAM ^& CPU Optimizer                       [3] Speed Booster                              %C_RESET%
echo %C_GREEN%  [4] Disk Defrag ^& Optimize                    [5] Visual Effects Tuning                      [6] BSOD ^& Crash Fix                          %C_RESET%
echo %C_GREEN%  [7] Prefetch ^& Cache                          [8] Windows Indexing                           [9] Advanced Cleanup                           %C_RESET%
echo %C_GREEN%  [10] 1 Click Minimum PC Boost                  [11] Disable Boost / Restore Normal            %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" goto sys_cleanup
if "%c%"=="2" goto ram_optimizer
if "%c%"=="3" goto speed_booster
if "%c%"=="4" goto disk_defrag
if "%c%"=="5" goto visual_effects
if "%c%"=="6" goto bsod_fix
if "%c%"=="7" goto prefetch_cache
if "%c%"=="8" goto win_indexing
if "%c%"=="9" goto adv_cleanup
if "%c%"=="10" goto performance_minimum_boost
if "%c%"=="11" goto performance_boost_restore
if "%c%"=="99" goto main
goto cat_performance

:: ---- 5.1 System Cleanup ----
:sys_cleanup
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [5.1] SYSTEM CLEANUP%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Disk Cleanup (GUI)                         [2] Clean Temp Folder                          [3] Clean Windows Temp                         %C_RESET%
echo %C_GREEN%  [4] Clean Prefetch                             [5] Clean Recycle Bin                          [6] Clean DNS Cache                            %C_RESET%
echo %C_GREEN%  [7] Clean Event Logs                           [8] Clean Browser Caches                       [9] WinSxS Cleanup (DISM)                      %C_RESET%
echo %C_GREEN%  [10] Delivery Optimization Clean               [11] Old Windows Update Clean                  [12] ONE CLICK ALL CLEAN                       %C_RESET%
echo %C_GREEN%  [13] ONE CLEAN (Temp + Windows Temp + Prefetch + Caches)                                                                               %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (cleanmgr & goto sys_cleanup)
if "%c%"=="2" (call :clean_folder_contents "%TEMP%" "User Temp" & pause & goto sys_cleanup)
if "%c%"=="3" (call :clean_folder_contents "C:\Windows\Temp" "Windows Temp" & pause & goto sys_cleanup)
if "%c%"=="4" (call :clean_folder_contents "C:\Windows\Prefetch" "Prefetch" & pause & goto sys_cleanup)
if "%c%"=="5" (rd /s /q C:\$Recycle.Bin >nul 2>&1 & echo Recycle Bin Cleared. & pause & goto sys_cleanup)
if "%c%"=="6" (ipconfig /flushdns & echo DNS Cache Cleared. & pause & goto sys_cleanup)
if "%c%"=="7" (for /F "tokens=*" %%G in ('wevtutil.exe el') DO wevtutil.exe cl "%%G" 2>nul & echo Event Logs Cleared. & pause & goto sys_cleanup)
if "%c%"=="8" (call :clean_browser_caches & pause & goto sys_cleanup)
if "%c%"=="9" (DISM /Online /Cleanup-Image /StartComponentCleanup & pause & goto sys_cleanup)
if "%c%"=="10" (call :clean_folder_contents "C:\Windows\SoftwareDistribution\DeliveryOptimization" "Delivery Optimization" & pause & goto sys_cleanup)
if "%c%"=="11" (DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase & pause & goto sys_cleanup)
if "%c%"=="12" (
    echo ONE CLICK ALL CLEAN RUNNING...
    call :one_clean_core
    ipconfig /flushdns >nul 2>&1
    for /F "tokens=*" %%G in ('wevtutil.exe el') DO wevtutil.exe cl "%%G" 2>nul
    echo ALL CLEAN DONE!
    pause & goto sys_cleanup
)
if "%c%"=="13" (call :one_clean_core & echo ONE CLEAN DONE! & pause & goto sys_cleanup)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto sys_cleanup

:: ---- 5.2 RAM & CPU Optimizer ----
:ram_optimizer
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [5.2] RAM ^& CPU OPTIMIZER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] RAM Usage Live View                        [2] Free RAM Now                               [3] CPU Usage Live View                        %C_RESET%
echo %C_GREEN%  [4] Top CPU Processes                          [5] Top RAM Processes                          [6] Virtual Memory Settings                    %C_RESET%
echo %C_GREEN%  [8] Enable SysMain                             [9] Disable Windows Search                     [10] Enable Windows Search                     %C_RESET%
echo %C_GREEN%  [11] RAM Info                                  [12] CPU Info                                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (powershell -command "while($true){$f=[math]::Round((Get-WmiObject Win32_OS).FreePhysicalMemory/1MB,2);$t=[math]::Round((Get-WmiObject Win32_CS).TotalPhysicalMemory/1GB,2);Write-Host 'Free:' $f 'GB / Total:' $t 'GB' -ForegroundColor Cyan;Start-Sleep 2;cls}" & goto ram_optimizer)
if "%c%"=="2" (powershell -command "[System.GC]::Collect()" & echo RAM Freed - GC collected. & pause & goto ram_optimizer)
if "%c%"=="3" (powershell -command "while($true){$cpu=(Get-WmiObject Win32_Processor).LoadPercentage;Write-Host 'CPU Usage:' $cpu'%%' -ForegroundColor Yellow;Start-Sleep 2;cls}" & goto ram_optimizer)
if "%c%"=="4" (powershell -command "Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name,CPU,Id | Format-Table -AutoSize" & pause & goto ram_optimizer)
if "%c%"=="5" (powershell -command "Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name,@{Name='RAM(MB)';Expression={[math]::Round($_.WorkingSet64/1MB,1)}},Id | Format-Table -AutoSize" & pause & goto ram_optimizer)
if "%c%"=="6" (start "" sysdm.cpl & goto ram_optimizer)
if "%c%"=="7" (sc stop SysMain & sc config SysMain start= disabled & echo SysMain Disabled. & pause & goto ram_optimizer)
if "%c%"=="8" (sc config SysMain start= auto & sc start SysMain & echo SysMain Enabled. & pause & goto ram_optimizer)
if "%c%"=="9" (net stop wsearch & sc config wsearch start= disabled & echo Windows Search Disabled. & pause & goto ram_optimizer)
if "%c%"=="10" (sc config wsearch start= auto & net start wsearch & echo Windows Search Enabled. & pause & goto ram_optimizer)
if "%c%"=="11" (powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_PhysicalMemory | Select-Object @{Name='CapacityGB';Expression={[math]::Round($_.Capacity/1GB,2)}},Speed,Manufacturer | Format-Table -AutoSize" & pause & goto ram_optimizer)
if "%c%"=="12" (call :ps_cpu_info & pause & goto ram_optimizer)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto ram_optimizer

:: ---- 5.3 Speed Booster ----
:speed_booster
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [5.3] SPEED BOOSTER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] High Performance Mode                      [2] Ultimate Performance Mode                  [3] Disable Animations                         %C_RESET%
echo %C_GREEN%  [4] Disable Transparency                       [5] Disable Startup Apps                       [6] Optimize for Performance                   %C_RESET%
echo %C_GREEN%  [7] SSD TRIM Run                               [8] Disk Defrag (HDD)                          [9] Fast Boot Enable                           %C_RESET%
echo %C_GREEN%  [10] 1 Click Minimum PC Boost                  [11] Enable Animations                         [12] Enable Transparency                       %C_RESET%
echo %C_GREEN%  [13] Disable Boost / Restore Normal            %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (powercfg /setactive SCHEME_MIN & echo High Performance Mode ON. & pause & goto speed_booster)
if "%c%"=="2" (powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 & echo Ultimate Performance added. Check Power Options. & pause & goto speed_booster)
if "%c%"=="3" (reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f & echo Animations Disabled. & pause & goto speed_booster)
if "%c%"=="4" (reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f & echo Transparency Disabled. & pause & goto speed_booster)
if "%c%"=="5" (start "" taskmgr & echo Go to Startup tab and disable unnecessary apps. & pause & goto speed_booster)
if "%c%"=="6" (powershell -command "Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2" & echo Visual Effects set for Performance. & pause & goto speed_booster)
if "%c%"=="7" (defrag C: /U /V /X & echo SSD TRIM Done. & pause & goto speed_booster)
if "%c%"=="8" (defrag C: /U /V & echo Defrag Done. & pause & goto speed_booster)
if "%c%"=="9" (reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 1 /f & echo Fast Boot Enabled. & pause & goto speed_booster)
if "%c%"=="10" goto performance_minimum_boost
if "%c%"=="11" (reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 1 /f & echo Animations Enabled. & pause & goto speed_booster)
if "%c%"=="12" (reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 1 /f & echo Transparency Enabled. & pause & goto speed_booster)
if "%c%"=="13" goto performance_boost_restore
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto speed_booster

:: ---- 5.6 BSOD Fix ----
:bsod_fix
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [5.6] BSOD ^& CRASH FIX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] SFC Scan (Corrupt Files)                   [2] DISM Repair                                [3] Driver Verifier                            %C_RESET%
echo %C_GREEN%  [4] Memory Diagnostic                          [5] Check Minidump Logs                        [6] Event Viewer Errors                        %C_RESET%
echo %C_GREEN%  [7] Page File Reset                            [8] Disable Driver Verifier                    [9] BSOD Log Export                            %C_RESET%
echo %C_GREEN%  [10] Crash Dump Folder                         [11] Startup Repair                            [12] Roll Back Driver                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (sfc /scannow & pause & goto bsod_fix)
if "%c%"=="2" (DISM /Online /Cleanup-Image /RestoreHealth & pause & goto bsod_fix)
if "%c%"=="3" (verifier & goto bsod_fix)
if "%c%"=="4" (start "" mdsched.exe & goto bsod_fix)
if "%c%"=="5" (dir C:\Windows\Minidump & pause & goto bsod_fix)
if "%c%"=="6" (eventvwr.msc & goto bsod_fix)
if "%c%"=="7" (call :ps_auto_pagefile & pause & goto bsod_fix)
if "%c%"=="8" (verifier /reset & echo Driver Verifier Disabled. Restart PC. & pause & goto bsod_fix)
if "%c%"=="9" (powershell -command "Get-WinEvent -LogName System | Where-Object {$_.LevelDisplayName -eq 'Critical'} | Select-Object -First 20 TimeCreated,Message | Out-File '%USERPROFILE%\Desktop\BSOD_Log.txt'" & echo Log saved to Desktop. & pause & goto bsod_fix)
if "%c%"=="10" (explorer C:\Windows\Minidump & goto bsod_fix)
if "%c%"=="11" (shutdown /r /o /f /t 0)
if "%c%"=="12" (start "" devmgmt.msc & echo Right-click device - Properties - Driver - Roll Back Driver & pause & goto bsod_fix)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto bsod_fix

:: ---- Other Performance subs (short) ----
:disk_defrag
cls & color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [5.4] DISK DEFRAG ^& OPTIMIZE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Defrag C: (HDD)                            [2] Optimize C: (SSD - TRIM)                   [3] Analyze C:                                 %C_RESET%
echo %C_GREEN%  [4] Defrag All Drives                          [5] Optimize GUI                               %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (defrag C: /U /V & pause & goto disk_defrag)
if "%c%"=="2" (defrag C: /U /V /X & pause & goto disk_defrag)
if "%c%"=="3" (defrag C: /A & pause & goto disk_defrag)
if "%c%"=="4" (defrag * /U /V & pause & goto disk_defrag)
if "%c%"=="5" (dfrgui & goto disk_defrag)
if "%c%"=="99" goto go_back
goto disk_defrag

:visual_effects
cls & color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [5.5] VISUAL EFFECTS TUNING%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Best Performance (All Off)                 [2] Best Appearance (All On)                   [3] Disable Animations                         %C_RESET%
echo %C_GREEN%  [4] Disable Transparency                       [5] Custom Visual Effects GUI                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f & echo Best Performance set. & pause & goto visual_effects)
if "%c%"=="2" (reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 1 /f & echo Best Appearance set. & pause & goto visual_effects)
if "%c%"=="3" (reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012078010000000 /f & echo Animations Disabled. & pause & goto visual_effects)
if "%c%"=="4" (reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f & echo Transparency Off. & pause & goto visual_effects)
if "%c%"=="5" (start "" sysdm.cpl & goto visual_effects)
if "%c%"=="99" goto go_back
goto visual_effects

:prefetch_cache
cls & color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [5.7] PREFETCH ^& CACHE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Clear Prefetch                             [2] Clear DNS Cache                            [3] Clear Font Cache                           %C_RESET%
echo %C_GREEN%  [4] Clear Thumbnail                            [5] Clear Icon Cache                           [6] Clear Browser Cache                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (call :clean_folder_contents "C:\Windows\Prefetch" "Prefetch" & pause & goto prefetch_cache)
if "%c%"=="2" (ipconfig /flushdns & echo DNS Cleared. & pause & goto prefetch_cache)
if "%c%"=="3" (net stop fontcache & del /f /q "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache*" >nul 2>&1 & net start fontcache & echo Font Cache Cleared. & pause & goto prefetch_cache)
if "%c%"=="4" (call :clean_thumbnail_cache & pause & goto prefetch_cache)
if "%c%"=="5" (call :clean_icon_cache & pause & goto prefetch_cache)
if "%c%"=="6" (call :clean_browser_caches & pause & goto prefetch_cache)
if "%c%"=="99" goto go_back
goto prefetch_cache

:win_indexing
cls & color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [5.8] WINDOWS INDEXING%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Indexing Options (GUI)                     [2] Disable Indexing Service                   [3] Enable Indexing Service                    %C_RESET%
echo %C_GREEN%  [4] Rebuild Index                              [5] Search Settings                            %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" control /name Microsoft.IndexingOptions & goto win_indexing)
if "%c%"=="2" (sc stop wsearch & sc config wsearch start= disabled & echo Search Indexing Disabled. & pause & goto win_indexing)
if "%c%"=="3" (sc config wsearch start= auto & net start wsearch & echo Search Indexing Enabled. & pause & goto win_indexing)
if "%c%"=="4" (sc stop wsearch & del /f /s /q "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\*" >nul 2>&1 & sc start wsearch & echo Index Rebuilt. & pause & goto win_indexing)
if "%c%"=="5" (start "" ms-settings:search & goto win_indexing)
if "%c%"=="99" goto go_back
goto win_indexing

:adv_cleanup
cls & color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [5.9] ADVANCED CLEANUP%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] WinSxS Cleanup                             [2] Old Update Files                           [3] Delivery Optimization                      %C_RESET%
echo %C_GREEN%  [4] Windows Error Reports                      [5] Crash Dumps Delete                         [6] System Log Files                           %C_RESET%
echo %C_GREEN%  [7] All Advanced Clean                         %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase & pause & goto adv_cleanup)
if "%c%"=="2" (DISM /Online /Cleanup-Image /StartComponentCleanup & pause & goto adv_cleanup)
if "%c%"=="3" (call :clean_folder_contents "C:\Windows\SoftwareDistribution\DeliveryOptimization" "Delivery Optimization" & pause & goto adv_cleanup)
if "%c%"=="4" (call :clean_folder_contents "C:\ProgramData\Microsoft\Windows\WER" "Windows Error Reports" & pause & goto adv_cleanup)
if "%c%"=="5" (call :clean_crash_dumps & pause & goto adv_cleanup)
if "%c%"=="6" (for /F "tokens=*" %%G in ('wevtutil.exe el') DO wevtutil.exe cl "%%G" 2>nul & echo Logs Cleared. & pause & goto adv_cleanup)
if "%c%"=="7" (
    DISM /Online /Cleanup-Image /StartComponentCleanup >nul 2>&1
    call :clean_folder_contents "C:\Windows\SoftwareDistribution\DeliveryOptimization" "Delivery Optimization"
    call :clean_folder_contents "C:\ProgramData\Microsoft\Windows\WER" "Windows Error Reports"
    call :clean_crash_dumps
    echo All Advanced Cleanup Done.
    pause & goto adv_cleanup
)
if "%c%"=="99" goto go_back
goto adv_cleanup

:: ============================================================
:: CATEGORY 6: OFFICE & SOFTWARE
:: ============================================================
:cat_office
set "BACK_MENU=cat_office"
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  [CATEGORY 6] OFFICE ^& SOFTWARE
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Outlook ^& Office Fix                      [2] Office Download Center                     [3] Driver Tools                               %C_RESET%
echo %C_GREEN%  [4] 5000+ Winget Software                      [5] Print ^& Spooler                           [6] Windows Edition Tools                      %C_RESET%
echo %C_GREEN%  [7] OS Download Center                         [8] Location Fix Toolkit                       [9] Browser Tools                              %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" goto outlook_fix
if "%c%"=="2" goto office_download
if "%c%"=="3" goto driver_tools
if "%c%"=="4" goto winget_installer
if "%c%"=="5" goto printer_tools
if "%c%"=="6" goto edition_tools
if "%c%"=="7" goto os_download
if "%c%"=="8" goto location_fix
if "%c%"=="9" goto browser_tools
if "%c%"=="99" goto main
goto cat_office

:: ---- 6.1 Outlook & Office Fix ----
:outlook_fix
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [6.1] OUTLOOK ^& OFFICE FIX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Outlook Safe Mode                          [2] Outlook Profile Repair                     [3] Outlook Data File Repair                   %C_RESET%
echo %C_GREEN%  [4] Office Online Repair                       [5] Office Quick Repair                        [6] Clear Outlook Cache                        %C_RESET%
echo %C_GREEN%  [7] Outlook Reset Nav Pane                     [8] OST to PST Fix                             [9] Office Activation Check                    %C_RESET%
echo %C_GREEN%  [10] Disable Office Add-ins                    [11] Repair Office Registry                    [12] Office Crash Fix                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (call :open_outlook_safe & pause & goto outlook_fix)
if "%c%"=="2" (call :open_outlook_profiles & pause & goto outlook_fix)
if "%c%"=="3" (call :open_scanpst & pause & goto outlook_fix)
if "%c%"=="4" (start "" control appwiz.cpl & echo Find Microsoft Office - Change - Online Repair & pause & goto outlook_fix)
if "%c%"=="5" (start "" control appwiz.cpl & echo Find Microsoft Office - Change - Quick Repair & pause & goto outlook_fix)
if "%c%"=="6" (del /f /s /q "%LocalAppData%\Microsoft\Outlook\RoamCache\*" >nul 2>&1 & echo Outlook Cache Cleared. & pause & goto outlook_fix)
if "%c%"=="7" (call :open_outlook_reset_navpane & pause & goto outlook_fix)
if "%c%"=="8" (call :open_scanpst & echo Select your OST/PST file in Inbox Repair Tool. & pause & goto outlook_fix)
if "%c%"=="9" (call :office_activation_status & pause & goto outlook_fix)
if "%c%"=="10" (call :open_outlook_safe & echo Disable add-ins from File - Options - Add-ins & pause & goto outlook_fix)
if "%c%"=="11" (sfc /scannow & pause & goto outlook_fix)
if "%c%"=="12" (del /f /s /q "%AppData%\Microsoft\Outlook\*.srs" >nul 2>&1 & echo Crash Fix Applied. Restart Outlook. & pause & goto outlook_fix)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto outlook_fix

:: ---- 6.4 Winget Software Installer ----
:winget_installer
if not defined BACK_MENU set "BACK_MENU=main"
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [6.4] 5000+ SOFTWARE LIBRARY - WINGET SEARCH INSTALLER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Search 5000+ Software Catalog + Install   [02] Install by Exact Winget ID                [03] Popular Software Quick IDs                %C_RESET%
echo %C_GREEN%  [04] Category / Pack Installer                 [05] List Installed Apps                       [06] Upgrade All Apps                          %C_RESET%
echo %C_GREEN%  [07] Refresh Winget 5000+ Source               [08] Export Installed Apps List                [09] Import Apps from JSON List                %C_RESET%
echo %C_GREEN%  [10] Winget Health / Sources                   [11] Repair App Installer                      [12] Mass Software Installer                   %C_RESET%
echo %C_GREEN%  [13] Show Winget Info                          [14] Custom Batch ID Install                   [15] More Category Packs                       %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto winget_search_install
if "%c%"=="1" goto winget_search_install
if "%c%"=="02" goto winget_install_by_id
if "%c%"=="2" goto winget_install_by_id
if "%c%"=="03" goto winget_popular_apps
if "%c%"=="3" goto winget_popular_apps
if "%c%"=="04" goto winget_category_packs
if "%c%"=="4" goto winget_category_packs
if "%c%"=="05" (call :winget_list_installed & pause & goto winget_installer)
if "%c%"=="5" (call :winget_list_installed & pause & goto winget_installer)
if "%c%"=="06" (call :winget_upgrade_all & pause & goto winget_installer)
if "%c%"=="6" (call :winget_upgrade_all & pause & goto winget_installer)
if "%c%"=="07" (call :winget_health & pause & goto winget_installer)
if "%c%"=="7" (call :winget_health & pause & goto winget_installer)
if "%c%"=="08" goto winget_export_installed
if "%c%"=="8" goto winget_export_installed
if "%c%"=="09" goto winget_import_json
if "%c%"=="9" goto winget_import_json
if "%c%"=="10" (call :winget_health & pause & goto winget_installer)
if "%c%"=="11" (call :repair_app_installer & pause & goto winget_installer)
if "%c%"=="12" goto menu_mass_installer
if "%c%"=="13" (call :winget_health & pause & goto winget_installer)
if "%c%"=="14" (set "PACK_RETURN=winget_installer" & goto winget_custom_batch)
if "%c%"=="15" (set "CATEGORY_RETURN=winget_installer" & goto winget_category_packs)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto winget_installer

:winget_missing
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo                                  WINGET / APP INSTALLER NOT FOUND
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  Winget is required for the 5000+ software catalog.
echo  Install or repair "App Installer" from Microsoft Store, then run this menu again.
echo.
echo  Store link: ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_GREEN%  [1] Open App Installer in Microsoft Store      [99] Back%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" & pause & goto winget_installer)
if "%c%"=="99" goto go_back
goto winget_missing

:winget_search_install
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo                                  SEARCH 5000+ WINGET SOFTWARE CATALOG
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  Type app/software name. Examples: chrome, vlc, office, python, java, zoom, anydesk, winrar
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
where winget >nul 2>&1
if errorlevel 1 goto winget_installer
set "q=" & set /p q=Software search:
if "%q%"=="" goto winget_installer
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
set "WINGET_SEARCH_FILE=%LOGROOT%\Winget_Search_%RANDOM%.txt"
echo.
echo Searching official Winget 5000+ catalog for "%q%"...
echo Please wait...
winget search --source winget "%q%" --accept-source-agreements > "%WINGET_SEARCH_FILE%" 2>&1
echo.
type "%WINGET_SEARCH_FILE%" | more
echo.
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  Result saved: %WINGET_SEARCH_FILE%
echo  Next: Press I, then paste exact ID from the ID column. Example: Google.Chrome
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
:winget_search_action
echo.
echo %C_GREEN%  [I] Install from this result     [S] Search again     [O] Open result in Notepad     [99] Back%C_RESET%
set "act=" & set /p act=SELECT ACTION:
if /i "%act%"=="I" goto winget_install_from_search
if /i "%act%"=="S" goto winget_search_install
if /i "%act%"=="O" (start "" notepad "%WINGET_SEARCH_FILE%" & goto winget_search_action)
if "%act%"=="99" goto winget_installer
goto winget_search_action

:winget_install_from_search
set "app=" & set /p app=Paste exact Winget ID:
if "%app%"=="" goto winget_search_action
echo.
echo Installing "%app%" from Winget...
echo.
call :winget_install_id "%app%"
echo.
echo Install command finished for "%app%".
pause
goto winget_installer

:winget_install_by_id
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo                                  INSTALL BY EXACT WINGET ID
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  Example IDs: Google.Chrome, VideoLAN.VLC, 7zip.7zip, Microsoft.VisualStudioCode
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
set "app=" & set /p app=Exact Winget ID:
if "%app%"=="" goto winget_installer
echo.
echo Installing "%app%"...
call :winget_install_id "%app%"
echo.
pause
goto winget_installer

:winget_popular_apps
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo                                  POPULAR SOFTWARE QUICK IDS
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_GREEN%  [01] Google Chrome             [02] Mozilla Firefox             [03] Brave Browser              [04] Opera Browser%C_RESET%
echo %C_GREEN%  [05] VLC Media Player          [06] 7-Zip                       [07] WinRAR                     [08] Notepad++%C_RESET%
echo %C_GREEN%  [09] VS Code                   [10] Git                         [11] Node.js LTS                [12] Python 3%C_RESET%
echo %C_GREEN%  [13] Java Runtime              [14] .NET Desktop Runtime        [15] Zoom                       [16] Microsoft Teams%C_RESET%
echo %C_GREEN%  [17] Telegram Desktop          [18] Discord                     [19] AnyDesk                    [20] TeamViewer%C_RESET%
echo %C_GREEN%  [21] Adobe Reader              [22] SumatraPDF                  [23] OBS Studio                 [24] ShareX%C_RESET%
echo %C_GREEN%  [25] PowerToys                 [26] Everything Search           [27] Rufus                      [28] PuTTY%C_RESET%
echo %C_GREEN%  [29] WinSCP                    [30] Google Drive                [31] OneDrive                   [32] Steam%C_RESET%
echo %C_GREEN%  [99] Back%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
set "pick=" & set /p pick=SELECT SOFTWARE:
set "app="
if "%pick%"=="01" set "app=Google.Chrome"
if "%pick%"=="1"  set "app=Google.Chrome"
if "%pick%"=="02" set "app=Mozilla.Firefox"
if "%pick%"=="2"  set "app=Mozilla.Firefox"
if "%pick%"=="03" set "app=Brave.Brave"
if "%pick%"=="3"  set "app=Brave.Brave"
if "%pick%"=="04" set "app=Opera.Opera"
if "%pick%"=="4"  set "app=Opera.Opera"
if "%pick%"=="05" set "app=VideoLAN.VLC"
if "%pick%"=="5"  set "app=VideoLAN.VLC"
if "%pick%"=="06" set "app=7zip.7zip"
if "%pick%"=="6"  set "app=7zip.7zip"
if "%pick%"=="07" set "app=RARLab.WinRAR"
if "%pick%"=="7"  set "app=RARLab.WinRAR"
if "%pick%"=="08" set "app=Notepad++.Notepad++"
if "%pick%"=="8"  set "app=Notepad++.Notepad++"
if "%pick%"=="09" set "app=Microsoft.VisualStudioCode"
if "%pick%"=="9"  set "app=Microsoft.VisualStudioCode"
if "%pick%"=="10" set "app=Git.Git"
if "%pick%"=="11" set "app=OpenJS.NodeJS.LTS"
if "%pick%"=="12" set "app=Python.Python.3.12"
if "%pick%"=="13" set "app=Oracle.JavaRuntimeEnvironment"
if "%pick%"=="14" set "app=Microsoft.DotNet.DesktopRuntime.8"
if "%pick%"=="15" set "app=Zoom.Zoom"
if "%pick%"=="16" set "app=Microsoft.Teams"
if "%pick%"=="17" set "app=Telegram.TelegramDesktop"
if "%pick%"=="18" set "app=Discord.Discord"
if "%pick%"=="19" set "app=AnyDesk.AnyDesk"
if "%pick%"=="20" set "app=TeamViewer.TeamViewer"
if "%pick%"=="21" set "app=Adobe.Acrobat.Reader.64-bit"
if "%pick%"=="22" set "app=SumatraPDF.SumatraPDF"
if "%pick%"=="23" set "app=OBSProject.OBSStudio"
if "%pick%"=="24" set "app=ShareX.ShareX"
if "%pick%"=="25" set "app=Microsoft.PowerToys"
if "%pick%"=="26" set "app=voidtools.Everything"
if "%pick%"=="27" set "app=Rufus.Rufus"
if "%pick%"=="28" set "app=PuTTY.PuTTY"
if "%pick%"=="29" set "app=WinSCP.WinSCP"
if "%pick%"=="30" set "app=Google.GoogleDrive"
if "%pick%"=="31" set "app=Microsoft.OneDrive"
if "%pick%"=="32" set "app=Valve.Steam"
if "%pick%"=="99" goto winget_installer
if "%app%"=="" goto winget_popular_apps
echo.
echo Selected ID: %app%
set "ok=" & set /p ok=Install now? (Y/N):
if /i not "%ok%"=="Y" goto winget_popular_apps
call :winget_install_id "%app%"
pause
goto winget_popular_apps

:winget_category_packs
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  CATEGORY / PACK INSTALLER
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Browser Pack                              [02] Runtime Pack                              [03] Utility Pack                              %C_RESET%
echo %C_GREEN%  [04] Developer Pack                            [05] Communication                             [06] Remote Support                            %C_RESET%
echo %C_GREEN%  [07] Media / Creator                           [08] Security Tools                            [09] Office / Student                          %C_RESET%
echo %C_GREEN%  [10] Custom Batch IDs                          [11] Popular IDs                               [12] Search 5000+ Apps                         %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" (set "PACK_RETURN=winget_category_packs" & goto install_browsers_pack)
if "%c%"=="1" (set "PACK_RETURN=winget_category_packs" & goto install_browsers_pack)
if "%c%"=="02" (set "PACK_RETURN=winget_category_packs" & goto install_runtime_pack)
if "%c%"=="2" (set "PACK_RETURN=winget_category_packs" & goto install_runtime_pack)
if "%c%"=="03" (set "PACK_RETURN=winget_category_packs" & goto install_utility_pack)
if "%c%"=="3" (set "PACK_RETURN=winget_category_packs" & goto install_utility_pack)
if "%c%"=="04" (set "PACK_RETURN=winget_category_packs" & goto install_dev_pack)
if "%c%"=="4" (set "PACK_RETURN=winget_category_packs" & goto install_dev_pack)
if "%c%"=="05" (set "PACK_RETURN=winget_category_packs" & goto install_communication_pack)
if "%c%"=="5" (set "PACK_RETURN=winget_category_packs" & goto install_communication_pack)
if "%c%"=="06" (set "PACK_RETURN=winget_category_packs" & goto install_remote_pack)
if "%c%"=="6" (set "PACK_RETURN=winget_category_packs" & goto install_remote_pack)
if "%c%"=="07" (set "PACK_RETURN=winget_category_packs" & goto install_media_pack)
if "%c%"=="7" (set "PACK_RETURN=winget_category_packs" & goto install_media_pack)
if "%c%"=="08" (set "PACK_RETURN=winget_category_packs" & goto install_security_pack)
if "%c%"=="8" (set "PACK_RETURN=winget_category_packs" & goto install_security_pack)
if "%c%"=="09" (set "PACK_RETURN=winget_category_packs" & goto install_office_pack)
if "%c%"=="9" (set "PACK_RETURN=winget_category_packs" & goto install_office_pack)
if "%c%"=="10" (set "PACK_RETURN=winget_category_packs" & goto winget_custom_batch)
if "%c%"=="11" goto winget_popular_apps
if "%c%"=="12" goto winget_search_install
if "%c%"=="99" goto return_from_category
goto winget_category_packs

:winget_export_installed
cls
color 06
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "exportfile=%LOGROOT%\Winget_Installed_Apps_%stamp%.json"
echo Exporting installed Winget apps to:
echo %exportfile%
call :winget_require
if errorlevel 1 (pause & goto winget_installer)
winget export -o "%exportfile%" --accept-source-agreements
echo.
echo Export command finished.
pause
goto winget_installer

:winget_import_json
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo                                  IMPORT / INSTALL APPS FROM WINGET JSON
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  Use a JSON created by Winget export. Example: %LOGROOT%\Winget_Installed_Apps_20260510_150000.json
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
set "jsonfile=" & set /p jsonfile=JSON full path:
if "%jsonfile%"=="" goto winget_installer
if not exist "%jsonfile%" (
    echo File not found:
    echo %jsonfile%
    pause
    goto winget_import_json
)
call :winget_require
if errorlevel 1 (pause & goto winget_installer)
winget import -i "%jsonfile%" --accept-package-agreements --accept-source-agreements --ignore-unavailable
pause
goto winget_installer
:: ---- 6.5 Print & Spooler ----
:printer_tools
goto menu_printer_spooler

:: ---- 6.6 Windows Edition Tools ----
:edition_tools
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [6.6] WINDOWS EDITION TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Check Windows Edition                      [2] Activate Windows (slmgr)                   [3] View License Info                          %C_RESET%
echo %C_GREEN%  [4] Change Product Key                         [5] Rearm Activation                           [6] KMS Server Set                             %C_RESET%
echo %C_GREEN%  [7] Activation Status                          [8] Upgrade to Pro                             [9] Windows Version Info                       %C_RESET%
echo %C_GREEN%  [10] OEM Key Check                             %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (winver & goto edition_tools)
if "%c%"=="2" (slmgr /ato & pause & goto edition_tools)
if "%c%"=="3" (slmgr /dlv & pause & goto edition_tools)
if "%c%"=="4" (set "key=" & set /p key=Product Key XXXXX-XXXXX-XXXXX-XXXXX-XXXXX: & slmgr /ipk !key! & pause & goto edition_tools)
if "%c%"=="5" (slmgr /rearm & echo Rearm Done. Restart. & pause & goto edition_tools)
if "%c%"=="6" (set "kms=" & set /p kms=KMS Server: & slmgr /skms !kms! & slmgr /ato & pause & goto edition_tools)
if "%c%"=="7" (slmgr /xpr & pause & goto edition_tools)
if "%c%"=="8" (start "" ms-settings:activation & goto edition_tools)
if "%c%"=="9" (systeminfo ^| findstr /c:"OS Name" /c:"OS Version" & pause & goto edition_tools)
if "%c%"=="10" (call :ps_oem_key & pause & goto edition_tools)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto edition_tools

:: ---- 6.7 OS Download Center ----
:os_download
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [6.7] OS DOWNLOAD CENTER - 120+ DIRECT LINKS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_YELLOW%  3-COLUMN DIRECT LINK CATALOG - Official/vendor pages. Scroll up/down if list is long.%C_RESET%
echo.
echo %C_GREEN%  [01] Windows 11 Official ISO                     [02] Windows 10 Official ISO                     [03] Windows 11 ARM64 ISO                        %C_RESET%
echo %C_GREEN%  [04] Windows Server 2025 Eval                    [05] Windows Server 2022 Eval                    [06] Windows Server 2019 Eval                    %C_RESET%
echo %C_GREEN%  [07] Windows Admin Center                        [08] Windows ADK                                 [09] Windows PE Add-on                           %C_RESET%
echo %C_GREEN%  [10] Windows Insider Preview                     [11] Microsoft Evaluation Center                 [12] Visual Studio Windows Dev VM                %C_RESET%
echo %C_GREEN%  [13] Ubuntu Desktop                              [14] Ubuntu Server                               [15] Ubuntu Core                                 %C_RESET%
echo %C_GREEN%  [16] Kubuntu                                     [17] Xubuntu                                     [18] Lubuntu                                     %C_RESET%
echo %C_GREEN%  [19] Ubuntu MATE                                 [20] Ubuntu Studio                               [21] Linux Mint Cinnamon                         %C_RESET%
echo %C_GREEN%  [22] Linux Mint Edge ISO                         [23] Debian                                      [24] Fedora Workstation                          %C_RESET%
echo %C_GREEN%  [25] Fedora Server                               [26] Fedora Spins                                [27] Kali Linux                                  %C_RESET%
echo %C_GREEN%  [28] Kali NetHunter                              [29] Parrot Security                             [30] BlackArch Linux                             %C_RESET%
echo %C_GREEN%  [31] Arch Linux                                  [32] Manjaro                                     [33] EndeavourOS                                 %C_RESET%
echo %C_GREEN%  [34] Garuda Linux                                [35] openSUSE Leap                               [36] openSUSE Tumbleweed                         %C_RESET%
echo %C_GREEN%  [37] Rocky Linux                                 [38] AlmaLinux                                   [39] CentOS Stream                               %C_RESET%
echo %C_GREEN%  [40] Red Hat Enterprise Linux                    [41] Oracle Linux                                [42] SUSE Linux Enterprise                       %C_RESET%
echo %C_GREEN%  [43] Pop OS                                      [44] Zorin OS                                    [45] elementary OS                               %C_RESET%
echo %C_GREEN%  [46] MX Linux                                    [47] antiX Linux                                 [48] Peppermint OS                               %C_RESET%
echo %C_GREEN%  [49] Nitrux                                      [50] Solus                                       [51] Deepin                                      %C_RESET%
echo %C_GREEN%  [52] PCLinuxOS                                   [53] Mageia                                      [54] Clear Linux                                 %C_RESET%
echo %C_GREEN%  [55] Tiny Core Linux                             [56] Puppy Linux                                 [57] Bodhi Linux                                 %C_RESET%
echo %C_GREEN%  [58] Tails                                       [59] Qubes OS                                    [60] Whonix                                      %C_RESET%
echo %C_GREEN%  [61] Kodachi                                     [62] Nobara Project                              [63] SteamOS Recovery                            %C_RESET%
echo %C_GREEN%  [64] HoloISO                                     [65] Batocera                                    [66] Lakka                                       %C_RESET%
echo %C_GREEN%  [67] Recalbox                                    [68] LibreELEC                                   [69] FreeBSD                                     %C_RESET%
echo %C_GREEN%  [70] OpenBSD                                     [71] NetBSD                                      [72] DragonFly BSD                               %C_RESET%
echo %C_GREEN%  [73] GhostBSD                                    [74] TrueNAS CORE                                [75] TrueNAS SCALE                               %C_RESET%
echo %C_GREEN%  [76] pfSense CE                                  [77] OPNsense                                    [78] Proxmox VE                                  %C_RESET%
echo %C_GREEN%  [79] Proxmox Backup Server                       [80] VMware ESXi Evaluation                      [81] XCP-ng                                      %C_RESET%
echo %C_GREEN%  [82] Citrix Hypervisor                           [83] Oracle VM VirtualBox                        [84] Clonezilla Live                             %C_RESET%
echo %C_GREEN%  [85] GParted Live                                [86] Rescuezilla                                 [87] SystemRescue                                %C_RESET%
echo %C_GREEN%  [88] Hiren BootCD PE                             [89] MediCat USB                                 [90] Ventoy                                      %C_RESET%
echo %C_GREEN%  [91] Rufus                                       [92] Balena Etcher                               [93] Universal USB Installer                     %C_RESET%
echo %C_GREEN%  [94] YUMI Multiboot USB                          [95] UNetbootin                                  [96] Raspberry Pi Imager                         %C_RESET%
echo %C_GREEN%  [97] Raspberry Pi OS                             [98] DietPi                                      [100] Armbian                                    %C_RESET%
echo %C_GREEN%  [101] OpenWrt                                    [102] VyOS                                       [103] MikroTik CHR                               %C_RESET%
echo %C_GREEN%  [104] IPFire                                     [105] NethServer                                 [106] OpenMediaVault                             %C_RESET%
echo %C_GREEN%  [107] Kasm Workspaces                            [108] Android Studio Emulator Images             [109] Android x86                                %C_RESET%
echo %C_GREEN%  [110] Bliss OS                                   [111] PrimeOS                                    [112] ChromeOS Flex                              %C_RESET%
echo %C_GREEN%  [113] FydeOS                                     [114] ReactOS                                    [115] Haiku OS                                   %C_RESET%
echo %C_GREEN%  [116] FreeDOS                                    [117] KolibriOS                                  [118] TempleOS Archive                           %C_RESET%
echo %C_GREEN%  [119] SerenityOS                                 [120] Plan 9 9front                              [121] illumos OpenIndiana                        %C_RESET%
echo %C_GREEN%  [122] SmartOS                                    [123] OmniOS                                                                                      %C_RESET%
echo.
echo %C_YELLOW%  [S] Search Any OS Download                         [99] Back / Previous Menu                         [00] Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / S SEARCH / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if /i "%c%"=="S" goto os_search_download
if "%c%"=="01" (start "" "https://www.microsoft.com/software-download/windows11" & pause & goto os_download)
if "%c%"=="1" (start "" "https://www.microsoft.com/software-download/windows11" & pause & goto os_download)
if "%c%"=="02" (start "" "https://www.microsoft.com/software-download/windows10" & pause & goto os_download)
if "%c%"=="2" (start "" "https://www.microsoft.com/software-download/windows10" & pause & goto os_download)
if "%c%"=="03" (start "" "https://www.microsoft.com/software-download/windows11arm64" & pause & goto os_download)
if "%c%"=="3" (start "" "https://www.microsoft.com/software-download/windows11arm64" & pause & goto os_download)
if "%c%"=="04" (start "" "https://www.microsoft.com/evalcenter/evaluate-windows-server-2025" & pause & goto os_download)
if "%c%"=="4" (start "" "https://www.microsoft.com/evalcenter/evaluate-windows-server-2025" & pause & goto os_download)
if "%c%"=="05" (start "" "https://www.microsoft.com/evalcenter/evaluate-windows-server-2022" & pause & goto os_download)
if "%c%"=="5" (start "" "https://www.microsoft.com/evalcenter/evaluate-windows-server-2022" & pause & goto os_download)
if "%c%"=="06" (start "" "https://www.microsoft.com/evalcenter/evaluate-windows-server-2019" & pause & goto os_download)
if "%c%"=="6" (start "" "https://www.microsoft.com/evalcenter/evaluate-windows-server-2019" & pause & goto os_download)
if "%c%"=="07" (start "" "https://www.microsoft.com/evalcenter/evaluate-windows-admin-center" & pause & goto os_download)
if "%c%"=="7" (start "" "https://www.microsoft.com/evalcenter/evaluate-windows-admin-center" & pause & goto os_download)
if "%c%"=="08" (start "" "https://learn.microsoft.com/windows-hardware/get-started/adk-install" & pause & goto os_download)
if "%c%"=="8" (start "" "https://learn.microsoft.com/windows-hardware/get-started/adk-install" & pause & goto os_download)
if "%c%"=="09" (start "" "https://learn.microsoft.com/windows-hardware/manufacture/desktop/winpe-intro" & pause & goto os_download)
if "%c%"=="9" (start "" "https://learn.microsoft.com/windows-hardware/manufacture/desktop/winpe-intro" & pause & goto os_download)
if "%c%"=="10" (start "" "https://www.microsoft.com/software-download/windowsinsiderpreviewiso" & pause & goto os_download)
if "%c%"=="11" (start "" "https://www.microsoft.com/evalcenter" & pause & goto os_download)
if "%c%"=="12" (start "" "https://developer.microsoft.com/windows/downloads/virtual-machines/" & pause & goto os_download)
if "%c%"=="13" (start "" "https://ubuntu.com/download/desktop" & pause & goto os_download)
if "%c%"=="14" (start "" "https://ubuntu.com/download/server" & pause & goto os_download)
if "%c%"=="15" (start "" "https://ubuntu.com/download/iot" & pause & goto os_download)
if "%c%"=="16" (start "" "https://kubuntu.org/getkubuntu/" & pause & goto os_download)
if "%c%"=="17" (start "" "https://xubuntu.org/download/" & pause & goto os_download)
if "%c%"=="18" (start "" "https://lubuntu.me/downloads/" & pause & goto os_download)
if "%c%"=="19" (start "" "https://ubuntu-mate.org/download/" & pause & goto os_download)
if "%c%"=="20" (start "" "https://ubuntustudio.org/download/" & pause & goto os_download)
if "%c%"=="21" (start "" "https://linuxmint.com/download.php" & pause & goto os_download)
if "%c%"=="22" (start "" "https://linuxmint.com/download.php" & pause & goto os_download)
if "%c%"=="23" (start "" "https://www.debian.org/distrib/" & pause & goto os_download)
if "%c%"=="24" (start "" "https://fedoraproject.org/workstation/download" & pause & goto os_download)
if "%c%"=="25" (start "" "https://fedoraproject.org/server/download" & pause & goto os_download)
if "%c%"=="26" (start "" "https://fedoraproject.org/spins/" & pause & goto os_download)
if "%c%"=="27" (start "" "https://www.kali.org/get-kali/" & pause & goto os_download)
if "%c%"=="28" (start "" "https://www.kali.org/get-kali/#kali-mobile" & pause & goto os_download)
if "%c%"=="29" (start "" "https://www.parrotsec.org/download/" & pause & goto os_download)
if "%c%"=="30" (start "" "https://blackarch.org/downloads.html" & pause & goto os_download)
if "%c%"=="31" (start "" "https://archlinux.org/download/" & pause & goto os_download)
if "%c%"=="32" (start "" "https://manjaro.org/download/" & pause & goto os_download)
if "%c%"=="33" (start "" "https://endeavouros.com/latest-release/" & pause & goto os_download)
if "%c%"=="34" (start "" "https://garudalinux.org/downloads.html" & pause & goto os_download)
if "%c%"=="35" (start "" "https://get.opensuse.org/leap/" & pause & goto os_download)
if "%c%"=="36" (start "" "https://get.opensuse.org/tumbleweed/" & pause & goto os_download)
if "%c%"=="37" (start "" "https://rockylinux.org/download" & pause & goto os_download)
if "%c%"=="38" (start "" "https://almalinux.org/get-almalinux/" & pause & goto os_download)
if "%c%"=="39" (start "" "https://www.centos.org/centos-stream/" & pause & goto os_download)
if "%c%"=="40" (start "" "https://developers.redhat.com/products/rhel/download" & pause & goto os_download)
if "%c%"=="41" (start "" "https://www.oracle.com/linux/technologies/oracle-linux-downloads.html" & pause & goto os_download)
if "%c%"=="42" (start "" "https://www.suse.com/download/sles/" & pause & goto os_download)
if "%c%"=="43" (start "" "https://pop.system76.com/" & pause & goto os_download)
if "%c%"=="44" (start "" "https://zorin.com/os/download/" & pause & goto os_download)
if "%c%"=="45" (start "" "https://elementary.io/" & pause & goto os_download)
if "%c%"=="46" (start "" "https://mxlinux.org/download-links/" & pause & goto os_download)
if "%c%"=="47" (start "" "https://antixlinux.com/download/" & pause & goto os_download)
if "%c%"=="48" (start "" "https://peppermintos.com/guide/downloading/" & pause & goto os_download)
if "%c%"=="49" (start "" "https://nxos.org/get/" & pause & goto os_download)
if "%c%"=="50" (start "" "https://getsol.us/download/" & pause & goto os_download)
if "%c%"=="51" (start "" "https://www.deepin.org/en/download/" & pause & goto os_download)
if "%c%"=="52" (start "" "https://www.pclinuxos.com/?page_id=10" & pause & goto os_download)
if "%c%"=="53" (start "" "https://www.mageia.org/downloads/" & pause & goto os_download)
if "%c%"=="54" (start "" "https://clearlinux.org/downloads" & pause & goto os_download)
if "%c%"=="55" (start "" "http://tinycorelinux.net/downloads.html" & pause & goto os_download)
if "%c%"=="56" (start "" "https://puppylinux-woof-ce.github.io/" & pause & goto os_download)
if "%c%"=="57" (start "" "https://www.bodhilinux.com/download/" & pause & goto os_download)
if "%c%"=="58" (start "" "https://tails.net/install/download/" & pause & goto os_download)
if "%c%"=="59" (start "" "https://www.qubes-os.org/downloads/" & pause & goto os_download)
if "%c%"=="60" (start "" "https://www.whonix.org/wiki/Download" & pause & goto os_download)
if "%c%"=="61" (start "" "https://www.digi77.com/linux-kodachi/" & pause & goto os_download)
if "%c%"=="62" (start "" "https://nobaraproject.org/download-nobara/" & pause & goto os_download)
if "%c%"=="63" (start "" "https://help.steampowered.com/en/faqs/view/1b71-edf2-eb6d-2bb3" & pause & goto os_download)
if "%c%"=="64" (start "" "https://github.com/HoloISO/holoiso" & pause & goto os_download)
if "%c%"=="65" (start "" "https://batocera.org/download" & pause & goto os_download)
if "%c%"=="66" (start "" "https://www.lakka.tv/get/" & pause & goto os_download)
if "%c%"=="67" (start "" "https://www.recalbox.com/download/stable/" & pause & goto os_download)
if "%c%"=="68" (start "" "https://libreelec.tv/downloads/" & pause & goto os_download)
if "%c%"=="69" (start "" "https://www.freebsd.org/where/" & pause & goto os_download)
if "%c%"=="70" (start "" "https://www.openbsd.org/ftp.html" & pause & goto os_download)
if "%c%"=="71" (start "" "https://www.netbsd.org/releases/" & pause & goto os_download)
if "%c%"=="72" (start "" "https://www.dragonflybsd.org/download/" & pause & goto os_download)
if "%c%"=="73" (start "" "https://www.ghostbsd.org/download" & pause & goto os_download)
if "%c%"=="74" (start "" "https://www.truenas.com/download-truenas-core/" & pause & goto os_download)
if "%c%"=="75" (start "" "https://www.truenas.com/download-truenas-scale/" & pause & goto os_download)
if "%c%"=="76" (start "" "https://www.pfsense.org/download/" & pause & goto os_download)
if "%c%"=="77" (start "" "https://opnsense.org/download/" & pause & goto os_download)
if "%c%"=="78" (start "" "https://www.proxmox.com/en/downloads/proxmox-virtual-environment" & pause & goto os_download)
if "%c%"=="79" (start "" "https://www.proxmox.com/en/downloads/proxmox-backup-server" & pause & goto os_download)
if "%c%"=="80" (start "" "https://www.vmware.com/products/cloud-infrastructure/vsphere" & pause & goto os_download)
if "%c%"=="81" (start "" "https://xcp-ng.org/#easy-to-install" & pause & goto os_download)
if "%c%"=="82" (start "" "https://www.citrix.com/downloads/citrix-hypervisor/" & pause & goto os_download)
if "%c%"=="83" (start "" "https://www.virtualbox.org/wiki/Downloads" & pause & goto os_download)
if "%c%"=="84" (start "" "https://clonezilla.org/downloads.php" & pause & goto os_download)
if "%c%"=="85" (start "" "https://gparted.org/download.php" & pause & goto os_download)
if "%c%"=="86" (start "" "https://rescuezilla.com/download" & pause & goto os_download)
if "%c%"=="87" (start "" "https://www.system-rescue.org/Download/" & pause & goto os_download)
if "%c%"=="88" (start "" "https://www.hirensbootcd.org/download/" & pause & goto os_download)
if "%c%"=="89" (start "" "https://medicatusb.com/" & pause & goto os_download)
if "%c%"=="90" (start "" "https://www.ventoy.net/en/download.html" & pause & goto os_download)
if "%c%"=="91" (start "" "https://rufus.ie/en/" & pause & goto os_download)
if "%c%"=="92" (start "" "https://etcher.balena.io/" & pause & goto os_download)
if "%c%"=="93" (start "" "https://pendrivelinux.com/universal-usb-installer-easy-as-1-2-3/" & pause & goto os_download)
if "%c%"=="94" (start "" "https://pendrivelinux.com/yumi-multiboot-usb-creator/" & pause & goto os_download)
if "%c%"=="95" (start "" "https://unetbootin.github.io/" & pause & goto os_download)
if "%c%"=="96" (start "" "https://www.raspberrypi.com/software/" & pause & goto os_download)
if "%c%"=="97" (start "" "https://www.raspberrypi.com/software/operating-systems/" & pause & goto os_download)
if "%c%"=="98" (start "" "https://dietpi.com/#download" & pause & goto os_download)
if "%c%"=="100" (start "" "https://www.armbian.com/download/" & pause & goto os_download)
if "%c%"=="101" (start "" "https://openwrt.org/downloads" & pause & goto os_download)
if "%c%"=="102" (start "" "https://vyos.io/download/" & pause & goto os_download)
if "%c%"=="103" (start "" "https://mikrotik.com/download" & pause & goto os_download)
if "%c%"=="104" (start "" "https://www.ipfire.org/download" & pause & goto os_download)
if "%c%"=="105" (start "" "https://www.nethserver.org/getting-started-with-nethserver/" & pause & goto os_download)
if "%c%"=="106" (start "" "https://www.openmediavault.org/download.html" & pause & goto os_download)
if "%c%"=="107" (start "" "https://www.kasmweb.com/downloads" & pause & goto os_download)
if "%c%"=="108" (start "" "https://developer.android.com/studio" & pause & goto os_download)
if "%c%"=="109" (start "" "https://www.android-x86.org/download" & pause & goto os_download)
if "%c%"=="110" (start "" "https://blissos.org/index.php#download" & pause & goto os_download)
if "%c%"=="111" (start "" "https://www.primeos.in/download/" & pause & goto os_download)
if "%c%"=="112" (start "" "https://support.google.com/chromeosflex/answer/11552529" & pause & goto os_download)
if "%c%"=="113" (start "" "https://fydeos.io/download/" & pause & goto os_download)
if "%c%"=="114" (start "" "https://reactos.org/download/" & pause & goto os_download)
if "%c%"=="115" (start "" "https://www.haiku-os.org/get-haiku/" & pause & goto os_download)
if "%c%"=="116" (start "" "https://www.freedos.org/download/" & pause & goto os_download)
if "%c%"=="117" (start "" "https://kolibrios.org/en/download" & pause & goto os_download)
if "%c%"=="118" (start "" "https://templeos.org/" & pause & goto os_download)
if "%c%"=="119" (start "" "https://serenityos.org/" & pause & goto os_download)
if "%c%"=="120" (start "" "http://9front.org/releases/" & pause & goto os_download)
if "%c%"=="121" (start "" "https://www.openindiana.org/download/" & pause & goto os_download)
if "%c%"=="122" (start "" "https://www.tritondatacenter.com/smartos/download" & pause & goto os_download)
if "%c%"=="123" (start "" "https://omnios.org/download" & pause & goto os_download)
if "%c%"=="99" goto go_back
if "%c%"=="00" goto main
goto os_download

:os_search_download
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% OS SEARCH ^& DOWNLOAD FINDER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo Type any OS name/version. Example: Windows 11 25H2, Ubuntu Server, Kali, Proxmox, pfSense, TinyCore.
echo The toolkit opens an official-download search so even uncommon OS names can be found quickly.
echo.
set "OS_SEARCH_QUERY="
set /p OS_SEARCH_QUERY=Search OS: 
if "%OS_SEARCH_QUERY%"=="" goto os_download
powershell -NoProfile -ExecutionPolicy Bypass -Command "$q=[Environment]::GetEnvironmentVariable('OS_SEARCH_QUERY'); $url='https://www.google.com/search?q='+[uri]::EscapeDataString($q+' official download ISO image'); Start-Process $url"
pause
goto os_download

:: ---- 6.3 Driver Tools ----
:driver_tools
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [6.3] DRIVER TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Device Manager                             [2] Driver Query All                           [3] Driver Query Network                       %C_RESET%
echo %C_GREEN%  [4] Driver Backup                              [5] Driver Restore                             [6] Driver Verifier                            %C_RESET%
echo %C_GREEN%  [7] Unsigned Driver Check                      [8] PnP Scan                                   [9] Driver Update (Web)                        %C_RESET%
echo %C_GREEN%  [10] GPU Driver Update                         [11] Audio Driver Restart                      [12] Old Driver Cleanup                        %C_RESET%
echo %C_GREEN%  [13] Smart Driver Auto Center                  [14] Hardware ID Report                        [15] Install INF Folder                        %C_RESET%
echo %C_GREEN%  [16] Driver Command Reference                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (start "" devmgmt.msc & goto driver_tools)
if "%c%"=="2" (driverquery & pause & goto driver_tools)
if "%c%"=="3" (driverquery ^| findstr /i network & pause & goto driver_tools)
if "%c%"=="4" (set "DRIVER_BACKUP_RETURN=driver_tools" & goto driver_backup_to_drive)
if "%c%"=="5" (set "DRIVER_RESTORE_RETURN=driver_tools" & goto driver_restore_from_drive)
if "%c%"=="6" (verifier & goto driver_tools)
if "%c%"=="7" (sigverif & goto driver_tools)
if "%c%"=="8" (pnputil /scan-devices & pause & goto driver_tools)
if "%c%"=="9" (start "" "https://www.driversupport.com" & goto driver_tools)
if "%c%"=="10" (start "" "https://www.nvidia.com/drivers" & start "" "https://www.amd.com/support" & pause & goto driver_tools)
if "%c%"=="11" (net stop audiosrv & net start audiosrv & echo Audio Restarted. & pause & goto driver_tools)
if "%c%"=="12" (set DEVMGR_SHOW_NONPRESENT_DEVICES=1 & start "" devmgmt.msc & echo Show hidden devices, remove unused. & pause & goto driver_tools)
if "%c%"=="13" goto driver_auto_center
if "%c%"=="14" goto driver_hwid_report
if "%c%"=="15" goto driver_install_inf_folder
if "%c%"=="16" goto driver_command_reference
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto driver_tools

:: ---- SMART DRIVER AUTO CENTER ----
:driver_auto_center
set "BACK_MENU=driver_auto_center"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [33] SMART DRIVER AUTO CENTER - SAFE MATCH / BACKUP / INSTALL%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Smart Driver Scan + HW Report          [02] Windows Optional Driver Page        [03] Auto OEM Driver Assistant%C_RESET%
echo %C_GREEN%  [04] Install Drivers from INF Folder        [05] Backup All Drivers to Drive         [06] Driver Backup / Restore Pro%C_RESET%
echo %C_GREEN%  [07] Problem Device Repair Scan             [08] Hardware IDs CSV Report             [09] GPU Driver Helper%C_RESET%
echo %C_GREEN%  [10] Network / Bluetooth Driver Helper      [11] Printer / Scanner Driver Helper     [12] Vendor Driver App Pack%C_RESET%
echo %C_GREEN%  [13] Driver Command Reference               [14] Microsoft Driver Help Links          [15] Full Safe Driver Workflow%C_RESET%
echo %C_GREEN%  [16] Open Device Manager%C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  Note: uses OEM / Windows Update / INF matching. Random driver websites are avoided.
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto driver_smart_report
if "%c%"=="1" goto driver_smart_report
if "%c%"=="02" goto driver_windows_update_page
if "%c%"=="2" goto driver_windows_update_page
if "%c%"=="03" goto driver_oem_assistant
if "%c%"=="3" goto driver_oem_assistant
if "%c%"=="04" goto driver_install_inf_folder
if "%c%"=="4" goto driver_install_inf_folder
if "%c%"=="05" goto driver_export_backup
if "%c%"=="5" goto driver_export_backup
if "%c%"=="06" goto driver_backup_restore_pro
if "%c%"=="6" goto driver_backup_restore_pro
if "%c%"=="07" goto driver_problem_repair_scan
if "%c%"=="7" goto driver_problem_repair_scan
if "%c%"=="08" goto driver_hwid_report
if "%c%"=="8" goto driver_hwid_report
if "%c%"=="09" goto driver_gpu_helper
if "%c%"=="9" goto driver_gpu_helper
if "%c%"=="10" goto driver_network_bluetooth_helper
if "%c%"=="11" goto driver_printer_helper
if "%c%"=="12" goto driver_vendor_pack
if "%c%"=="13" goto driver_command_reference
if "%c%"=="14" goto driver_help_links
if "%c%"=="15" goto driver_full_safe_workflow
if "%c%"=="16" (start "" devmgmt.msc & pause & goto driver_auto_center)
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto driver_auto_center

:driver_smart_report
cls
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "dreport=%LOGROOT%\Driver_Smart_Report_%stamp%.txt"
(
echo ================================================================
echo SMART DRIVER SCAN REPORT - %date% %time%
echo ================================================================
echo.
echo === COMPUTER ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_ComputerSystem | Select Manufacturer,Model,SystemType | Format-List"
echo.
echo === BIOS ===
call :ps_bios_info
echo.
echo === CPU ===
call :ps_cpu_info
echo.
echo === GPU ===
call :ps_gpu_info
echo.
echo === DISKS ===
call :ps_disk_drives
echo.
echo === PROBLEM DEVICES WITH DEVICE IDS ===
pnputil /enum-devices /problem /deviceids
echo.
echo === CONNECTED DEVICES ===
pnputil /enum-devices /connected
echo.
echo === THIRD PARTY DRIVER STORE ===
pnputil /enum-drivers
) > "%dreport%" 2>&1
echo Driver report saved:
echo %dreport%
start "" notepad "%dreport%"
pause
if defined DRIVER_REPORT_RETURN (
    set "DRIVER_REPORT_BACK=%DRIVER_REPORT_RETURN%"
    set "DRIVER_REPORT_RETURN="
    set "SAFE_TARGET=!DRIVER_REPORT_BACK!"
    goto safe_goto
)
goto driver_auto_center

:driver_windows_update_page
cls
echo Opening Windows Update driver area.
echo Check Advanced options ^> Optional updates ^> Driver updates.
pnputil /scan-devices
start "" ms-settings:windowsupdate
start "" ms-settings:windowsupdate-optionalupdates
pause
goto driver_auto_center

:driver_oem_assistant
cls
for /f "delims=" %%m in ('powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystem).Manufacturer"') do set "OEM_MANUFACTURER=%%m"
for /f "delims=" %%m in ('powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystem).Model"') do set "OEM_MODEL=%%m"
echo Detected PC:
echo Manufacturer: !OEM_MANUFACTURER!
echo Model       : !OEM_MODEL!
echo.
echo This installs the official OEM helper when detected. It can scan matching drivers for this PC.
set "ok=" & set /p ok=Install detected OEM driver assistant now? (Y/N):
if /i not "%ok%"=="Y" goto driver_auto_center
echo(!OEM_MANUFACTURER!| findstr /i "Dell Alienware" >nul
if not errorlevel 1 (call :winget_install_store XPDCCXDN26VNBT & pause & goto driver_auto_center)
echo(!OEM_MANUFACTURER!| findstr /i "Lenovo" >nul
if not errorlevel 1 (call :winget_install_store 9WZDNCRFJ4MV & pause & goto driver_auto_center)
echo(!OEM_MANUFACTURER!| findstr /i "HP Hewlett" >nul
if not errorlevel 1 (call :winget_install_id HPInc.HPSupportAssistant & pause & goto driver_auto_center)
echo(!OEM_MANUFACTURER!| findstr /i "Microsoft Surface" >nul
if not errorlevel 1 (start "" "https://support.microsoft.com/surface" & pause & goto driver_auto_center)
echo OEM not matched. Installing Intel Driver ^& Support Assistant as generic chipset/display/network helper.
call :winget_install_id Intel.IntelDriverAndSupportAssistant
pause
goto driver_auto_center

:driver_install_inf_folder
cls
echo Install matching drivers from a folder containing .INF files.
echo Only matching, ranked drivers are installed by PnPUtil.
set "driver_folder=" & set /p driver_folder=Driver folder full path:
if "!driver_folder!"=="" goto driver_auto_center
if not exist "!driver_folder!" (
    echo Folder not found.
    pause
    goto driver_install_inf_folder
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Before Toolkit Driver INF Install' -RestorePointType MODIFY_SETTINGS" >nul 2>&1
pnputil /add-driver "!driver_folder!\*.inf" /subdirs /install
pause
goto driver_auto_center

:driver_export_backup
cls
set "DRIVER_BACKUP_RETURN=driver_auto_center"
goto driver_backup_to_drive

:driver_backup_restore_pro
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  DRIVER BACKUP / RESTORE PRO - DRIVE PICKER
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Backup all drivers to selected drive    [2] Restore drivers from selected drive     [3] List third-party drivers%C_RESET%
echo %C_GREEN%  [4] Open Driver Backup Root                 [5] Create restore point                    [6] Problem Devices Scan%C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (set "DRIVER_BACKUP_RETURN=driver_backup_restore_pro" & goto driver_backup_to_drive)
if "%c%"=="2" (set "DRIVER_RESTORE_RETURN=driver_backup_restore_pro" & goto driver_restore_from_drive)
if "%c%"=="3" (pnputil /enum-drivers & pause & goto driver_backup_restore_pro)
if "%c%"=="4" goto driver_open_backup_root
if "%c%"=="5" (powershell -NoProfile -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Toolkit Driver Restore Point' -RestorePointType MODIFY_SETTINGS" & pause & goto driver_backup_restore_pro)
if "%c%"=="6" goto driver_problem_repair_scan
if "%c%"=="99" goto driver_auto_center
goto driver_backup_restore_pro

:driver_problem_repair_scan
cls
echo Scanning hardware changes and listing problem devices.
pnputil /scan-devices
echo.
pnputil /enum-devices /problem /deviceids
echo.
start "" devmgmt.msc
pause
goto driver_auto_center

:driver_hwid_report
cls
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "hwcsv=%LOGROOT%\Hardware_IDs_%stamp%.csv"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_PnPEntity | Select-Object Name,PNPClass,Status,DeviceID,@{Name='HardwareID';Expression={$_.HardwareID -join '; '}},@{Name='CompatibleID';Expression={$_.CompatibleID -join '; '}} | Export-Csv -NoTypeInformation -Encoding UTF8 '%hwcsv%'"
echo Hardware IDs CSV saved:
echo %hwcsv%
start "" notepad "%hwcsv%"
pause
goto driver_auto_center

:driver_gpu_helper
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  GPU / Display Driver Helper
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Open NVIDIA driver page                    [2] Open AMD driver page                       [3] Install Intel Driver Assistant             %C_RESET%
echo %C_GREEN%  [4] Install Display Driver Uninstaller         [5] Open Display settings                      %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" "https://www.nvidia.com/Download/index.aspx" & pause & goto driver_gpu_helper)
if "%c%"=="2" (start "" "https://www.amd.com/en/support/download/drivers.html" & pause & goto driver_gpu_helper)
if "%c%"=="3" (call :winget_install_id Intel.IntelDriverAndSupportAssistant & pause & goto driver_gpu_helper)
if "%c%"=="4" (call :winget_install_id Wagnardsoft.DisplayDriverUninstaller & pause & goto driver_gpu_helper)
if "%c%"=="5" (start "" ms-settings:display & pause & goto driver_gpu_helper)
if "%c%"=="99" goto driver_auto_center
goto driver_gpu_helper

:driver_network_bluetooth_helper
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  Network / WiFi / Bluetooth Driver Helper
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Scan PnP devices                           [2] Restart WLAN/Bluetooth services            [3] Open WiFi settings                         %C_RESET%
echo %C_GREEN%  [4] Open Bluetooth settings                    [5] Install Intel Driver Assistant             %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (pnputil /scan-devices & pause & goto driver_network_bluetooth_helper)
if "%c%"=="2" (net stop WlanSvc >nul 2>&1 & net start WlanSvc & net stop bthserv >nul 2>&1 & net start bthserv & pause & goto driver_network_bluetooth_helper)
if "%c%"=="3" (start "" ms-settings:network-wifi & pause & goto driver_network_bluetooth_helper)
if "%c%"=="4" (start "" ms-settings:bluetooth & pause & goto driver_network_bluetooth_helper)
if "%c%"=="5" (call :winget_install_id Intel.IntelDriverAndSupportAssistant & pause & goto driver_network_bluetooth_helper)
if "%c%"=="99" goto driver_auto_center
goto driver_network_bluetooth_helper

:driver_printer_helper
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  Printer / Scanner Driver Helper
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Restart spooler                            [2] Clear print queue                          [3] Open printer settings                      %C_RESET%
echo %C_GREEN%  [4] Add printer wizard                         [5] List printer drivers                       %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (net stop spooler & net start spooler & pause & goto driver_printer_helper)
if "%c%"=="2" (net stop spooler & del /f /s /q "%SystemRoot%\System32\spool\PRINTERS\*" >nul 2>&1 & net start spooler & pause & goto driver_printer_helper)
if "%c%"=="3" (start "" ms-settings:printers & pause & goto driver_printer_helper)
if "%c%"=="4" (start "" printui.exe /il & pause & goto driver_printer_helper)
if "%c%"=="5" (powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-PrinterDriver | Select Name,Manufacturer,DriverVersion | Format-Table -AutoSize" & pause & goto driver_printer_helper)
if "%c%"=="99" goto driver_auto_center
goto driver_printer_helper

:driver_vendor_pack
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  Vendor Driver App Pack
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Intel Driver ^& Support Assistant          [2] HP Support Assistant                       [3] Dell SupportAssist (Store)                 %C_RESET%
echo %C_GREEN%  [4] Lenovo Vantage (Store)                     [5] Display Driver Uninstaller                 [6] Auto-detect OEM Assistant                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (call :winget_install_id Intel.IntelDriverAndSupportAssistant & pause & goto driver_vendor_pack)
if "%c%"=="2" (call :winget_install_id HPInc.HPSupportAssistant & pause & goto driver_vendor_pack)
if "%c%"=="3" (call :winget_install_store XPDCCXDN26VNBT & pause & goto driver_vendor_pack)
if "%c%"=="4" (call :winget_install_store 9WZDNCRFJ4MV & pause & goto driver_vendor_pack)
if "%c%"=="5" (call :winget_install_id Wagnardsoft.DisplayDriverUninstaller & pause & goto driver_vendor_pack)
if "%c%"=="6" goto driver_oem_assistant
if "%c%"=="99" goto driver_auto_center
goto driver_vendor_pack

:driver_command_reference
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  DRIVER COMMAND REFERENCE - PNPUTIL / DISM / POWERSHELL
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  pnputil /scan-devices
echo  pnputil /enum-devices /problem /deviceids
echo  pnputil /enum-devices /connected
echo  pnputil /enum-drivers
echo  pnputil /export-driver * C:\DriverBackup
echo  pnputil /add-driver C:\Drivers\*.inf /subdirs /install
echo  pnputil /enum-devices /instanceid "DEVICE_INSTANCE_ID" /drivers
echo  DISM /Online /Get-Drivers /Format:Table
echo  DISM /Online /Export-Driver /Destination:C:\DriverBackup
echo  PowerShell: Get-PnpDevice -PresentOnly
echo  PowerShell: Get-CimInstance Win32_PnPEntity
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
pause
goto driver_auto_center

:driver_help_links
cls
echo Opening Microsoft and OEM driver help links.
start "" "https://learn.microsoft.com/windows-hardware/drivers/devtest/pnputil-command-syntax"
start "" "https://learn.microsoft.com/windows-hardware/drivers/devtest/pnputil-examples"
start "" "https://support.microsoft.com/windows"
pause
goto driver_auto_center

:driver_full_safe_workflow
cls
echo Full safe driver workflow:
echo  1. Create restore point
echo  2. Generate driver/hardware report
echo  3. Scan devices
echo  4. Open Windows Optional Driver Updates
echo  5. Offer OEM driver assistant
echo.
set "ok=" & set /p ok=Start full safe workflow? (Y/N):
if /i not "%ok%"=="Y" goto driver_auto_center
powershell -NoProfile -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'Before Toolkit Driver Workflow' -RestorePointType MODIFY_SETTINGS" >nul 2>&1
set "DRIVER_REPORT_RETURN=driver_full_safe_workflow_continue"
goto driver_smart_report

:driver_full_safe_workflow_continue
pnputil /scan-devices
start "" ms-settings:windowsupdate-optionalupdates
echo.
set "ok=" & set /p ok=Install detected OEM assistant too? (Y/N):
if /i "%ok%"=="Y" goto driver_oem_assistant
goto driver_auto_center

:: ---- 10000+ CMD VAULT / GLOBAL COMMAND SEARCH ----
:cmd_vault
set "BACK_MENU=cmd_vault"
cls
color 0F
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [34] 10000+ CMD VAULT / GLOBAL SEARCH%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Search Everything by Keyword           [02] Search PowerShell Commands           [03] Search System32 EXE/CPL/MSC%C_RESET%
echo %C_GREEN%  [04] Search Winget 5000+ Catalog            [05] CMD Internal Help Index              [06] Windows Settings URI Launcher%C_RESET%
echo %C_GREEN%  [07] Network Command Kit                    [08] Repair Command Kit                   [09] Device / Driver Command Kit%C_RESET%
echo %C_GREEN%  [10] Admin / Policy Command Kit             [11] Services / Tasks / Events Kit        [12] Run Custom Command%C_RESET%
echo %C_GREEN%  [13] Microsoft Problem Library              [14] Smart Search Center                    [15] Missing 20000+ Command Vault              %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto cmd_vault_search_all
if "%c%"=="1" goto cmd_vault_search_all
if "%c%"=="02" goto cmd_vault_ps_search
if "%c%"=="2" goto cmd_vault_ps_search
if "%c%"=="03" goto cmd_vault_system32_search
if "%c%"=="3" goto cmd_vault_system32_search
if "%c%"=="04" goto cmd_vault_winget_search
if "%c%"=="4" goto cmd_vault_winget_search
if "%c%"=="05" (help | more & pause & goto cmd_vault)
if "%c%"=="5" (help | more & pause & goto cmd_vault)
if "%c%"=="06" goto cmd_vault_settings_uri
if "%c%"=="6" goto cmd_vault_settings_uri
if "%c%"=="07" goto cmd_vault_network_kit
if "%c%"=="7" goto cmd_vault_network_kit
if "%c%"=="08" goto cmd_vault_repair_kit
if "%c%"=="8" goto cmd_vault_repair_kit
if "%c%"=="09" goto cmd_vault_device_kit
if "%c%"=="9" goto cmd_vault_device_kit
if "%c%"=="10" goto cmd_vault_admin_kit
if "%c%"=="11" goto cmd_vault_service_event_kit
if "%c%"=="12" goto cmd_vault_run_custom
if "%c%"=="13" goto microsoft_problem_library
if "%c%"=="14" goto menu_search
if "%c%"=="15" goto missing_mega_vault_launcher
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto cmd_vault

:cmd_vault_search_all
cls
set "kw=" & set /p kw=Search command/tool/problem keyword:
if not defined kw goto cmd_vault
set "SEARCH_FILE=%~f0"
echo === POWERSHELL COMMANDS ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Get-Command -ErrorAction SilentlyContinue | Where-Object { ([string]$_.Name) -match $rx } | Select-Object -First 100 CommandType,Name,Source | Format-Table -AutoSize"
echo.
echo === SYSTEM32 TOOLS ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Get-ChildItem -LiteralPath (Join-Path $env:windir 'System32') -Force -ErrorAction SilentlyContinue | Where-Object { ([string]$_.Name) -match $rx -and $_.Extension -in '.exe','.cpl','.msc' } | Select-Object -First 150 -ExpandProperty FullName"
echo.
echo === CMD HELP MATCH ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; cmd /c help | Select-String -SimpleMatch $kw | Select-Object -First 80"
echo.
echo === TOOLKIT MATCH ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $file=$env:SEARCH_FILE; Select-String -LiteralPath $file -SimpleMatch $kw -ErrorAction SilentlyContinue | Select-Object -First 120 | ForEach-Object { '{0}: {1}' -f $_.LineNumber,$_.Line }"
echo.
echo === WINGET CATALOG ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; if(Get-Command winget -ErrorAction SilentlyContinue){ & winget search $kw --accept-source-agreements } else { Write-Host 'Winget not installed.' }"
pause
goto cmd_vault

:cmd_vault_ps_search
cls
set "kw=" & set /p kw=PowerShell command keyword:
if not defined kw goto cmd_vault
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Get-Command -ErrorAction SilentlyContinue | Where-Object { ([string]$_.Name) -match $rx } | Sort-Object Name | Select-Object -First 150 CommandType,Name,Source,Version | Format-Table -AutoSize"
pause
goto cmd_vault

:cmd_vault_system32_search
cls
set "kw=" & set /p kw=System tool keyword:
if not defined kw goto cmd_vault
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; $rx=[regex]::Escape($kw); Get-ChildItem -LiteralPath (Join-Path $env:windir 'System32') -Force -ErrorAction SilentlyContinue | Where-Object { ([string]$_.Name) -match $rx -and $_.Extension -in '.exe','.cpl','.msc','.dll' } | Select-Object -First 200 -ExpandProperty FullName"
pause
goto cmd_vault

:cmd_vault_winget_search
cls
set "kw=" & set /p kw=Winget app keyword:
if not defined kw goto cmd_vault
where winget >nul 2>&1
if errorlevel 1 goto winget_missing
powershell -NoProfile -ExecutionPolicy Bypass -Command "$kw=$env:kw; & winget search $kw --accept-source-agreements"
pause
goto cmd_vault

:cmd_vault_settings_uri
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  Windows Settings URI Launcher
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Windows Update                             [2] Optional Updates                           [3] Network                                    %C_RESET%
echo %C_GREEN%  [4] Bluetooth                                  [5] Printers                                   [6] Sound                                      %C_RESET%
echo %C_GREEN%  [7] Camera Privacy                             [8] Apps Features                              [9] Troubleshoot                               %C_RESET%
echo %C_GREEN%  [10] Activation                                [11] Recovery                                  [12] Default Apps                              %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" start "" ms-settings:windowsupdate
if "%c%"=="2" start "" ms-settings:windowsupdate-optionalupdates
if "%c%"=="3" start "" ms-settings:network
if "%c%"=="4" start "" ms-settings:bluetooth
if "%c%"=="5" start "" ms-settings:printers
if "%c%"=="6" start "" ms-settings:sound
if "%c%"=="7" start "" ms-settings:privacy-webcam
if "%c%"=="8" start "" ms-settings:appsfeatures
if "%c%"=="9" start "" ms-settings:troubleshoot
if "%c%"=="10" start "" ms-settings:activation
if "%c%"=="11" start "" ms-settings:recovery
if "%c%"=="12" start "" ms-settings:defaultapps
if "%c%"=="99" goto cmd_vault
goto cmd_vault_settings_uri

:cmd_vault_network_kit
cls
echo NETWORK COMMAND KIT
echo ------------------------------------------------------------
echo ipconfig /all
echo ipconfig /release  ^& ipconfig /renew
echo ipconfig /flushdns
echo netsh winsock reset
echo netsh int ip reset
echo netsh wlan show interfaces
echo netsh wlan show drivers
echo netsh wlan show wlanreport
echo netstat -ano
echo route print
echo pathping 8.8.8.8
echo nslookup microsoft.com
echo Get-NetAdapter
echo Get-NetIPConfiguration
pause
goto cmd_vault

:cmd_vault_repair_kit
cls
echo REPAIR COMMAND KIT
echo ------------------------------------------------------------
echo sfc /scannow
echo DISM /Online /Cleanup-Image /CheckHealth
echo DISM /Online /Cleanup-Image /ScanHealth
echo DISM /Online /Cleanup-Image /RestoreHealth
echo chkdsk C: /scan
echo chkdsk C: /f /r
echo wsreset.exe
echo powershell Reset-AppxPackage
echo bootrec /fixmbr
echo bootrec /fixboot
echo bootrec /rebuildbcd
echo bcdedit /enum
pause
goto cmd_vault

:cmd_vault_device_kit
cls
echo DEVICE / DRIVER COMMAND KIT
echo ------------------------------------------------------------
echo pnputil /scan-devices
echo pnputil /enum-devices /problem /deviceids
echo pnputil /enum-devices /connected
echo pnputil /enum-drivers
echo pnputil /export-driver * C:\DriverBackup
echo pnputil /add-driver C:\Drivers\*.inf /subdirs /install
echo DISM /Online /Get-Drivers /Format:Table
echo DISM /Online /Export-Driver /Destination:C:\DriverBackup
echo driverquery /v
echo verifier
echo sigverif
pause
goto cmd_vault

:cmd_vault_admin_kit
cls
echo ADMIN / POLICY COMMAND KIT
echo ------------------------------------------------------------
echo gpupdate /force
echo gpresult /h C:\gpresult.html
echo secedit /configure /cfg %%windir%%\inf\defltbase.inf /db defltbase.sdb /verbose
echo net user
echo net localgroup administrators
echo whoami /groups
echo auditpol /get /category:*
echo manage-bde -status
echo reagentc /info
echo powercfg /a
echo powercfg /energy
pause
goto cmd_vault

:cmd_vault_service_event_kit
cls
echo SERVICES / TASKS / EVENTS KIT
echo ------------------------------------------------------------
echo sc query state= all
echo sc queryex SERVICE_NAME
echo net start
echo tasklist /svc
echo taskkill /pid PID /f
echo schtasks /query /fo LIST /v
echo wevtutil el
echo wevtutil qe System /c:50 /f:text
echo Get-WinEvent -LogName System -MaxEvents 50
echo eventvwr.msc
pause
goto cmd_vault

:cmd_vault_run_custom
cls
echo Custom command runner.
echo Use only commands you trust. Destructive commands are your responsibility.
set "customcmd=" & set /p customcmd=Command:
if "!customcmd!"=="" goto cmd_vault
echo.
cmd /d /c "!customcmd!"
pause
goto cmd_vault

:: ---- MICROSOFT PROBLEM LIBRARY / WEB TROUBLESHOOTERS ----
:microsoft_problem_library
set "BACK_MENU=microsoft_problem_library"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  MICROSOFT PROBLEM LIBRARY - GUIDED FIX LINKS + TOOLKIT JUMPS
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Windows Update Troubleshooter             [02] WiFi / Network Fix Guide                  [03] Printer / Spooler Problems                %C_RESET%
echo %C_GREEN%  [04] Bluetooth Problems                        [05] Sound / Audio Problems                    [06] Camera / Microphone Problems              %C_RESET%
echo %C_GREEN%  [07] Driver / PnPUtil Docs                     [08] Device Manager Problem Devices            [09] Search / Indexing Fix                     %C_RESET%
echo %C_GREEN%  [10] Store / App Installer Fix                 [11] Open Windows Troubleshoot Settings        [12] All-In-One Problem Solver                 %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" (start "" "https://support.microsoft.com/en-us/windows/windows-update-troubleshooter-19bc41ca-ad72-ae67-af3c-89ce169755dd" & pause & goto microsoft_problem_library)
if "%c%"=="1" (start "" "https://support.microsoft.com/en-us/windows/windows-update-troubleshooter-19bc41ca-ad72-ae67-af3c-89ce169755dd" & goto microsoft_problem_library)
if "%c%"=="02" (start "" "https://support.microsoft.com/en-us/windows/fix-wi-fi-connection-issues-in-windows-9424a1f7-6a3b-65a6-4d78-7f07eee84d2c" & pause & goto microsoft_problem_library)
if "%c%"=="2" (start "" "https://support.microsoft.com/en-us/windows/fix-wi-fi-connection-issues-in-windows-9424a1f7-6a3b-65a6-4d78-7f07eee84d2c" & goto microsoft_problem_library)
if "%c%"=="03" (start "" "https://support.microsoft.com/en-us/windows/fix-printer-connection-and-printing-problems-in-windows-fb830bff-7702-6349-33cd-9443fe987f73" & pause & goto microsoft_problem_library)
if "%c%"=="3" (start "" "https://support.microsoft.com/en-us/windows/fix-printer-connection-and-printing-problems-in-windows-fb830bff-7702-6349-33cd-9443fe987f73" & goto microsoft_problem_library)
if "%c%"=="04" (start "" "https://support.microsoft.com/en-us/windows/fix-bluetooth-problems-in-windows-723e092f-03fa-858b-5c80-131ec3fba75c" & pause & goto microsoft_problem_library)
if "%c%"=="4" (start "" "https://support.microsoft.com/en-us/windows/fix-bluetooth-problems-in-windows-723e092f-03fa-858b-5c80-131ec3fba75c" & goto microsoft_problem_library)
if "%c%"=="05" (start "" "https://support.microsoft.com/en-gb/windows/fix-sound-or-audio-problems-in-windows-73025246-b61c-40fb-671a-2535c7cd56c8" & pause & goto microsoft_problem_library)
if "%c%"=="5" (start "" "https://support.microsoft.com/en-gb/windows/fix-sound-or-audio-problems-in-windows-73025246-b61c-40fb-671a-2535c7cd56c8" & goto microsoft_problem_library)
if "%c%"=="06" (start "" "https://support.microsoft.com/en-us/windows/camera-app-shows-error-0xa00f4244-nocamerasareattached-05d738b3-b1fd-06f2-f5fc-c0437ff8db32" & start "" "https://support.microsoft.com/en-us/windows/fix-microphone-problems-5f230348-106d-bfa4-1db5-336f35576011" & pause & goto microsoft_problem_library)
if "%c%"=="6" (start "" "https://support.microsoft.com/en-us/windows/camera-app-shows-error-0xa00f4244-nocamerasareattached-05d738b3-b1fd-06f2-f5fc-c0437ff8db32" & start "" "https://support.microsoft.com/en-us/windows/fix-microphone-problems-5f230348-106d-bfa4-1db5-336f35576011" & goto microsoft_problem_library)
if "%c%"=="07" (start "" "https://learn.microsoft.com/windows-hardware/drivers/devtest/pnputil-command-syntax" & start "" "https://learn.microsoft.com/windows-hardware/drivers/devtest/pnputil-examples" & pause & goto microsoft_problem_library)
if "%c%"=="7" (start "" "https://learn.microsoft.com/windows-hardware/drivers/devtest/pnputil-command-syntax" & start "" "https://learn.microsoft.com/windows-hardware/drivers/devtest/pnputil-examples" & goto microsoft_problem_library)
if "%c%"=="08" goto issue_problem_devices
if "%c%"=="8" goto issue_problem_devices
if "%c%"=="09" goto win_indexing
if "%c%"=="9" goto win_indexing
if "%c%"=="10" goto issue_store_repair
if "%c%"=="11" (start "" ms-settings:troubleshoot & pause & goto microsoft_problem_library)
if "%c%"=="12" goto problem_master_hub
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto microsoft_problem_library

:: ---- 6.8 Location Fix ----
:location_fix
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [6.8] LOCATION ^& GPS FIX TOOLKIT%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] ONE CLICK FIX                              [2] Restart Location Service                   [3] Restart Sensor Service                     %C_RESET%
echo %C_GREEN%  [4] Clear Location Cache                       [5] Reset Maps App                             [6] Fix Permissions                            %C_RESET%
echo %C_GREEN%  [7] Repair System                              [8] Quick Fix                                  [9] Open Location Settings                     %C_RESET%
echo %C_GREEN%  [10] Check Services                            [11] Chrome Location Fix                       %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (
    echo [STEP 1] Stopping Services...
    net stop lfsvc >nul 2>&1 & net stop SensorService >nul 2>&1
    echo [STEP 2] Clearing Location Cache...
    del /f /s /q "%ProgramData%\Microsoft\Windows\Location\*" >nul 2>&1
    echo [STEP 3] Starting Services...
    net start SensorService >nul 2>&1 & net start lfsvc >nul 2>&1
    echo [STEP 4] Fixing Permissions...
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f >nul
    echo [STEP 5] Reset Maps App...
    powershell "Get-AppxPackage *maps* | Reset-AppxPackage" >nul 2>&1
    echo [STEP 6] Flushing DNS...
    ipconfig /flushdns >nul 2>&1
    echo LOCATION FIX COMPLETED!
    pause & goto location_fix
)
if "%c%"=="2" (net stop lfsvc & net start lfsvc & echo Location Service Restarted. & pause & goto location_fix)
if "%c%"=="3" (net stop SensorService & net start SensorService & echo Sensor Restarted. & pause & goto location_fix)
if "%c%"=="4" (del /f /s /q "%ProgramData%\Microsoft\Windows\Location\*" & echo Cache Cleared. & pause & goto location_fix)
if "%c%"=="5" (powershell "Get-AppxPackage *maps* | Reset-AppxPackage" & echo Maps Reset. & pause & goto location_fix)
if "%c%"=="6" (reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f & echo Permissions Fixed. & pause & goto location_fix)
if "%c%"=="7" (DISM /Online /Cleanup-Image /RestoreHealth & sfc /scannow & pause & goto location_fix)
if "%c%"=="8" (ipconfig /flushdns & net start lfsvc & echo Quick Fix Done. & pause & goto location_fix)
if "%c%"=="9" (start "" ms-settings:privacy-location & goto location_fix)
if "%c%"=="10" (sc query lfsvc & sc query SensorService & pause & goto location_fix)
if "%c%"=="11" (taskkill /f /im chrome.exe >nul 2>&1 & rd /s /q "%LocalAppData%\Google\Chrome\User Data\Default\Geolocation" >nul 2>&1 & echo Chrome Location Fixed. & pause & goto location_fix)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto location_fix

:: ---- 6.9 Browser Tools ----
:browser_tools
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [6.9] BROWSER TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Reset Chrome                               [2] Reset Edge                                 [3] Reset Firefox                              %C_RESET%
echo %C_GREEN%  [4] Clear All Browser Caches                   [5] Chrome Security Reset                      [6] Edge Security Reset                        %C_RESET%
echo %C_GREEN%  [7] Fix Browser No Internet                    [8] Browser DNS Error Fix                      [9] Open Chrome Settings                       %C_RESET%
echo %C_GREEN%  [10] Open Edge Settings                        [11] Uninstall Chrome Data                     [12] Default Browser Set                       %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (taskkill /f /im chrome.exe >nul 2>&1 & rd /s /q "%LocalAppData%\Google\Chrome\User Data\Default\Cache" >nul 2>&1 & echo Chrome Reset. & pause & goto browser_tools)
if "%c%"=="2" (taskkill /f /im msedge.exe >nul 2>&1 & rd /s /q "%LocalAppData%\Microsoft\Edge\User Data\Default\Cache" >nul 2>&1 & echo Edge Reset. & pause & goto browser_tools)
if "%c%"=="3" (taskkill /f /im firefox.exe >nul 2>&1 & rd /s /q "%AppData%\Mozilla\Firefox\Profiles" >nul 2>&1 & echo Firefox Cache Cleared. & pause & goto browser_tools)
if "%c%"=="4" (call :clean_browser_caches & echo All Browser Caches Cleared. & pause & goto browser_tools)
if "%c%"=="5" (start "" "chrome://settings/security" & goto browser_tools)
if "%c%"=="6" (start "" "edge://settings/security" & goto browser_tools)
if "%c%"=="7" (ipconfig /flushdns & netsh winsock reset & echo Browser Internet Fix Done. & pause & goto browser_tools)
if "%c%"=="8" (ipconfig /flushdns & nslookup google.com & pause & goto browser_tools)
if "%c%"=="9" (start "" "chrome://settings" & goto browser_tools)
if "%c%"=="10" (start "" "edge://settings" & pause & goto browser_tools)
if "%c%"=="11" (rd /s /q "%LocalAppData%\Google\Chrome\User Data" & echo Chrome Data Removed. Reinstall Chrome. & pause & goto browser_tools)
if "%c%"=="12" (start "" ms-settings:defaultapps & pause & goto browser_tools)
if "%c%"=="99" goto go_back
echo Invalid choice. & pause
goto browser_tools

:: ---- 6.2 Office Download Center ----
:office_download
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [6.2] OFFICE DOWNLOAD CENTER - 100+ DIRECT LINKS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_YELLOW%  3-COLUMN DIRECT LINK CATALOG - Official/vendor pages. Scroll up/down if list is long.%C_RESET%
echo.
echo %C_GREEN%  [01] Microsoft 365 Home                          [02] Microsoft 365 Apps Admin                    [03] Office Deployment Tool                      %C_RESET%
echo %C_GREEN%  [04] Office Customization Tool                   [05] Office Deployment Docs                      [06] Office Install Help                         %C_RESET%
echo %C_GREEN%  [07] Office Account Portal                       [08] Office Web Apps                             [09] Microsoft Word Online                       %C_RESET%
echo %C_GREEN%  [10] Microsoft Excel Online                      [11] Microsoft PowerPoint Online                 [12] Microsoft OneNote                           %C_RESET%
echo %C_GREEN%  [13] Microsoft Outlook                           [14] Microsoft Teams                             [15] Microsoft OneDrive                          %C_RESET%
echo %C_GREEN%  [16] Microsoft SharePoint                        [17] Microsoft Visio Trial                       [18] Microsoft Project Trial                     %C_RESET%
echo %C_GREEN%  [19] Microsoft Access Info                       [20] Microsoft Publisher Info                    [21] Microsoft Forms                             %C_RESET%
echo %C_GREEN%  [22] Microsoft Planner                           [23] Microsoft To Do                             [24] Microsoft Loop                              %C_RESET%
echo %C_GREEN%  [25] Microsoft Clipchamp                         [26] Microsoft Whiteboard                        [27] Microsoft Power BI Desktop                  %C_RESET%
echo %C_GREEN%  [28] Power Automate Desktop                      [29] Power Apps                                  [30] SharePoint Designer 2013                    %C_RESET%
echo %C_GREEN%  [31] Skype Download                              [32] Yammer Viva Engage                          [33] Microsoft Viva                              %C_RESET%
echo %C_GREEN%  [34] Office Activation Help                      [35] Office Repair Help                          [36] Office Uninstall Tool                       %C_RESET%
echo %C_GREEN%  [37] Microsoft Support Recovery Assistant        [38] Outlook Support Center                      [39] Teams Support Center                        %C_RESET%
echo %C_GREEN%  [40] OneDrive Support Center                     [41] LibreOffice Fresh                           [42] LibreOffice Still                           %C_RESET%
echo %C_GREEN%  [43] LibreOffice Portable                        [44] Apache OpenOffice                           [45] ONLYOFFICE Desktop                          %C_RESET%
echo %C_GREEN%  [46] ONLYOFFICE Workspace                        [47] WPS Office                                  [48] FreeOffice                                  %C_RESET%
echo %C_GREEN%  [49] Collabora Office                            [50] Google Docs                                 [51] Google Sheets                               %C_RESET%
echo %C_GREEN%  [52] Google Slides                               [53] Google Drive Desktop                        [54] Zoho Writer                                 %C_RESET%
echo %C_GREEN%  [55] Zoho Sheet                                  [56] Zoho Show                                   [57] Dropbox Paper                               %C_RESET%
echo %C_GREEN%  [58] Notion Desktop                              [59] Obsidian                                    [60] Evernote                                    %C_RESET%
echo %C_GREEN%  [61] Joplin                                      [62] Adobe Acrobat Reader                        [63] Adobe Acrobat Pro Trial                     %C_RESET%
echo %C_GREEN%  [64] Foxit PDF Reader                            [65] SumatraPDF                                  [66] PDF24 Creator                               %C_RESET%
echo %C_GREEN%  [67] PDFCreator                                  [68] PDFsam Basic                                [69] Okular                                      %C_RESET%
echo %C_GREEN%  [70] Scribus                                     [71] LaTeX MiKTeX                                [72] TeX Live                                    %C_RESET%
echo %C_GREEN%  [73] Zotero                                      [74] Mendeley Reference Manager                  [75] Grammarly Desktop                           %C_RESET%
echo %C_GREEN%  [76] LanguageTool                                [77] Pandoc                                      [78] Calibre                                     %C_RESET%
echo %C_GREEN%  [79] Sigil EPUB Editor                           [80] XMind                                       [81] FreeMind                                    %C_RESET%
echo %C_GREEN%  [82] Draw.io Desktop                             [83] Diagrams.net Online                         [84] Lucidchart                                  %C_RESET%
echo %C_GREEN%  [85] Miro Desktop                                [86] Slack Desktop                               [87] Zoom Desktop                                %C_RESET%
echo %C_GREEN%  [88] Cisco Webex                                 [89] Google Meet                                 [90] Thunderbird                                 %C_RESET%
echo %C_GREEN%  [91] eM Client                                   [92] Mailbird                                    [93] Proton Mail Bridge                          %C_RESET%
echo %C_GREEN%  [94] Nextcloud Desktop                           [95] Syncthing                                   [96] Docusign                                    %C_RESET%
echo %C_GREEN%  [97] Adobe Scan Mobile                           [98] Microsoft Lens Mobile                       [100] Canon IJ Scan Utility                      %C_RESET%
echo %C_GREEN%  [101] HP Smart                                   [102] Epson ScanSmart                            [103] Brother iPrint Scan                        %C_RESET%
echo %C_GREEN%  [104] Microsoft Keyboard Layout Creator          [105] PowerPoint Viewer Info                     [106] Office Language Pack                       %C_RESET%
echo %C_GREEN%  [107] Office Update History                      [108] Microsoft 365 Release Notes                [109] Office Product IDs                         %C_RESET%
echo %C_GREEN%  [110] Office Offline Installer Help              [111] Microsoft Store Office                     [112] Office CDN Setup EXE                       %C_RESET%
echo.
echo %C_YELLOW%  [S] Search Office/App Download                         [99] Back / Previous Menu                         [00] Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / S SEARCH / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if /i "%c%"=="S" goto office_search_download
if "%c%"=="01" (start "" "https://www.microsoft.com/microsoft-365" & pause & goto office_download)
if "%c%"=="1" (start "" "https://www.microsoft.com/microsoft-365" & pause & goto office_download)
if "%c%"=="02" (start "" "https://admin.microsoft.com/" & pause & goto office_download)
if "%c%"=="2" (start "" "https://admin.microsoft.com/" & pause & goto office_download)
if "%c%"=="03" (start "" "https://www.microsoft.com/en-us/download/details.aspx?id=49117" & pause & goto office_download)
if "%c%"=="3" (start "" "https://www.microsoft.com/en-us/download/details.aspx?id=49117" & pause & goto office_download)
if "%c%"=="04" (start "" "https://config.office.com/" & pause & goto office_download)
if "%c%"=="4" (start "" "https://config.office.com/" & pause & goto office_download)
if "%c%"=="05" (start "" "https://learn.microsoft.com/microsoft-365-apps/deploy/overview-office-deployment-tool" & pause & goto office_download)
if "%c%"=="5" (start "" "https://learn.microsoft.com/microsoft-365-apps/deploy/overview-office-deployment-tool" & pause & goto office_download)
if "%c%"=="06" (start "" "https://support.microsoft.com/office/download-and-install-or-reinstall-microsoft-365-or-office-4414eaaf-0478-48be-9c42-23adc4716658" & pause & goto office_download)
if "%c%"=="6" (start "" "https://support.microsoft.com/office/download-and-install-or-reinstall-microsoft-365-or-office-4414eaaf-0478-48be-9c42-23adc4716658" & pause & goto office_download)
if "%c%"=="07" (start "" "https://account.microsoft.com/services" & pause & goto office_download)
if "%c%"=="7" (start "" "https://account.microsoft.com/services" & pause & goto office_download)
if "%c%"=="08" (start "" "https://www.office.com/" & pause & goto office_download)
if "%c%"=="8" (start "" "https://www.office.com/" & pause & goto office_download)
if "%c%"=="09" (start "" "https://www.microsoft365.com/launch/word" & pause & goto office_download)
if "%c%"=="9" (start "" "https://www.microsoft365.com/launch/word" & pause & goto office_download)
if "%c%"=="10" (start "" "https://www.microsoft365.com/launch/excel" & pause & goto office_download)
if "%c%"=="11" (start "" "https://www.microsoft365.com/launch/powerpoint" & pause & goto office_download)
if "%c%"=="12" (start "" "https://www.onenote.com/download" & pause & goto office_download)
if "%c%"=="13" (start "" "https://www.microsoft.com/microsoft-365/outlook/email-and-calendar-software-microsoft-outlook" & pause & goto office_download)
if "%c%"=="14" (start "" "https://www.microsoft.com/microsoft-teams/download-app" & pause & goto office_download)
if "%c%"=="15" (start "" "https://www.microsoft.com/microsoft-365/onedrive/download" & pause & goto office_download)
if "%c%"=="16" (start "" "https://www.microsoft.com/microsoft-365/sharepoint/collaboration" & pause & goto office_download)
if "%c%"=="17" (start "" "https://www.microsoft.com/microsoft-365/visio/flowchart-software" & pause & goto office_download)
if "%c%"=="18" (start "" "https://www.microsoft.com/microsoft-365/project/project-management-software" & pause & goto office_download)
if "%c%"=="19" (start "" "https://www.microsoft.com/microsoft-365/access" & pause & goto office_download)
if "%c%"=="20" (start "" "https://support.microsoft.com/office/publisher-help-56591eee-353e-47a6-baa6-1dddf6d23f0b" & pause & goto office_download)
if "%c%"=="21" (start "" "https://forms.office.com/" & pause & goto office_download)
if "%c%"=="22" (start "" "https://tasks.office.com/" & pause & goto office_download)
if "%c%"=="23" (start "" "https://to-do.office.com/tasks/" & pause & goto office_download)
if "%c%"=="24" (start "" "https://loop.microsoft.com/" & pause & goto office_download)
if "%c%"=="25" (start "" "https://clipchamp.com/" & pause & goto office_download)
if "%c%"=="26" (start "" "https://www.microsoft.com/microsoft-365/microsoft-whiteboard/digital-whiteboard-app" & pause & goto office_download)
if "%c%"=="27" (start "" "https://powerbi.microsoft.com/desktop/" & pause & goto office_download)
if "%c%"=="28" (start "" "https://powerautomate.microsoft.com/desktop/" & pause & goto office_download)
if "%c%"=="29" (start "" "https://powerapps.microsoft.com/" & pause & goto office_download)
if "%c%"=="30" (start "" "https://www.microsoft.com/en-us/download/details.aspx?id=35491" & pause & goto office_download)
if "%c%"=="31" (start "" "https://www.skype.com/get-skype/" & pause & goto office_download)
if "%c%"=="32" (start "" "https://www.microsoft.com/microsoft-viva/engage" & pause & goto office_download)
if "%c%"=="33" (start "" "https://www.microsoft.com/microsoft-viva" & pause & goto office_download)
if "%c%"=="34" (start "" "https://support.microsoft.com/office-activation" & pause & goto office_download)
if "%c%"=="35" (start "" "https://support.microsoft.com/office/repair-an-office-application-7821d4b6-7c1d-4205-aa0e-a6b40c5bb88b" & pause & goto office_download)
if "%c%"=="36" (start "" "https://support.microsoft.com/office/uninstall-office-from-a-pc-9dd49b83-264a-477a-8fcc-2fdf5dbf61d8" & pause & goto office_download)
if "%c%"=="37" (start "" "https://aka.ms/SaRA-officeUninstallFromPC" & pause & goto office_download)
if "%c%"=="38" (start "" "https://support.microsoft.com/outlook" & pause & goto office_download)
if "%c%"=="39" (start "" "https://support.microsoft.com/teams" & pause & goto office_download)
if "%c%"=="40" (start "" "https://support.microsoft.com/onedrive" & pause & goto office_download)
if "%c%"=="41" (start "" "https://www.libreoffice.org/download/download-libreoffice/" & pause & goto office_download)
if "%c%"=="42" (start "" "https://www.libreoffice.org/download/download-libreoffice/" & pause & goto office_download)
if "%c%"=="43" (start "" "https://www.libreoffice.org/download/portable-versions/" & pause & goto office_download)
if "%c%"=="44" (start "" "https://www.openoffice.org/download/" & pause & goto office_download)
if "%c%"=="45" (start "" "https://www.onlyoffice.com/download-desktop.aspx" & pause & goto office_download)
if "%c%"=="46" (start "" "https://www.onlyoffice.com/download-workspace.aspx" & pause & goto office_download)
if "%c%"=="47" (start "" "https://www.wps.com/office/windows/" & pause & goto office_download)
if "%c%"=="48" (start "" "https://www.freeoffice.com/en/download" & pause & goto office_download)
if "%c%"=="49" (start "" "https://www.collaboraoffice.com/collabora-office/" & pause & goto office_download)
if "%c%"=="50" (start "" "https://docs.google.com/" & pause & goto office_download)
if "%c%"=="51" (start "" "https://sheets.google.com/" & pause & goto office_download)
if "%c%"=="52" (start "" "https://slides.google.com/" & pause & goto office_download)
if "%c%"=="53" (start "" "https://www.google.com/drive/download/" & pause & goto office_download)
if "%c%"=="54" (start "" "https://www.zoho.com/writer/" & pause & goto office_download)
if "%c%"=="55" (start "" "https://www.zoho.com/sheet/" & pause & goto office_download)
if "%c%"=="56" (start "" "https://www.zoho.com/show/" & pause & goto office_download)
if "%c%"=="57" (start "" "https://www.dropbox.com/paper" & pause & goto office_download)
if "%c%"=="58" (start "" "https://www.notion.com/desktop" & pause & goto office_download)
if "%c%"=="59" (start "" "https://obsidian.md/download" & pause & goto office_download)
if "%c%"=="60" (start "" "https://evernote.com/download" & pause & goto office_download)
if "%c%"=="61" (start "" "https://joplinapp.org/help/install/" & pause & goto office_download)
if "%c%"=="62" (start "" "https://get.adobe.com/reader/" & pause & goto office_download)
if "%c%"=="63" (start "" "https://www.adobe.com/acrobat/free-trial-download.html" & pause & goto office_download)
if "%c%"=="64" (start "" "https://www.foxit.com/pdf-reader/" & pause & goto office_download)
if "%c%"=="65" (start "" "https://www.sumatrapdfreader.org/download-free-pdf-viewer" & pause & goto office_download)
if "%c%"=="66" (start "" "https://tools.pdf24.org/en/creator" & pause & goto office_download)
if "%c%"=="67" (start "" "https://www.pdfforge.org/pdfcreator/download" & pause & goto office_download)
if "%c%"=="68" (start "" "https://pdfsam.org/download-pdfsam-basic/" & pause & goto office_download)
if "%c%"=="69" (start "" "https://okular.kde.org/download/" & pause & goto office_download)
if "%c%"=="70" (start "" "https://www.scribus.net/downloads/" & pause & goto office_download)
if "%c%"=="71" (start "" "https://miktex.org/download" & pause & goto office_download)
if "%c%"=="72" (start "" "https://www.tug.org/texlive/acquire-netinstall.html" & pause & goto office_download)
if "%c%"=="73" (start "" "https://www.zotero.org/download/" & pause & goto office_download)
if "%c%"=="74" (start "" "https://www.mendeley.com/download-reference-manager/" & pause & goto office_download)
if "%c%"=="75" (start "" "https://www.grammarly.com/desktop" & pause & goto office_download)
if "%c%"=="76" (start "" "https://languagetool.org/windows-desktop" & pause & goto office_download)
if "%c%"=="77" (start "" "https://pandoc.org/installing.html" & pause & goto office_download)
if "%c%"=="78" (start "" "https://calibre-ebook.com/download" & pause & goto office_download)
if "%c%"=="79" (start "" "https://sigil-ebook.com/sigil/download/" & pause & goto office_download)
if "%c%"=="80" (start "" "https://xmind.app/download/" & pause & goto office_download)
if "%c%"=="81" (start "" "https://freemind.sourceforge.io/wiki/index.php/Download" & pause & goto office_download)
if "%c%"=="82" (start "" "https://github.com/jgraph/drawio-desktop/releases" & pause & goto office_download)
if "%c%"=="83" (start "" "https://app.diagrams.net/" & pause & goto office_download)
if "%c%"=="84" (start "" "https://www.lucidchart.com/pages/" & pause & goto office_download)
if "%c%"=="85" (start "" "https://miro.com/apps/" & pause & goto office_download)
if "%c%"=="86" (start "" "https://slack.com/downloads/windows" & pause & goto office_download)
if "%c%"=="87" (start "" "https://zoom.us/download" & pause & goto office_download)
if "%c%"=="88" (start "" "https://www.webex.com/downloads.html" & pause & goto office_download)
if "%c%"=="89" (start "" "https://meet.google.com/" & pause & goto office_download)
if "%c%"=="90" (start "" "https://www.thunderbird.net/download/" & pause & goto office_download)
if "%c%"=="91" (start "" "https://www.emclient.com/download" & pause & goto office_download)
if "%c%"=="92" (start "" "https://www.getmailbird.com/download/" & pause & goto office_download)
if "%c%"=="93" (start "" "https://proton.me/mail/bridge" & pause & goto office_download)
if "%c%"=="94" (start "" "https://nextcloud.com/install/#install-clients" & pause & goto office_download)
if "%c%"=="95" (start "" "https://syncthing.net/downloads/" & pause & goto office_download)
if "%c%"=="96" (start "" "https://www.docusign.com/products/electronic-signature" & pause & goto office_download)
if "%c%"=="97" (start "" "https://www.adobe.com/acrobat/mobile/scanner-app.html" & pause & goto office_download)
if "%c%"=="98" (start "" "https://www.microsoft.com/microsoft-365/microsoft-lens" & pause & goto office_download)
if "%c%"=="100" (start "" "https://www.usa.canon.com/support" & pause & goto office_download)
if "%c%"=="101" (start "" "https://www.hpsmart.com/" & pause & goto office_download)
if "%c%"=="102" (start "" "https://epson.com/Support/wa00870" & pause & goto office_download)
if "%c%"=="103" (start "" "https://support.brother.com/" & pause & goto office_download)
if "%c%"=="104" (start "" "https://www.microsoft.com/en-us/download/details.aspx?id=102134" & pause & goto office_download)
if "%c%"=="105" (start "" "https://support.microsoft.com/office/view-a-presentation-without-powerpoint-1a1f4a4a-04d6-4f21-9c9c-879cdbb8a3d2" & pause & goto office_download)
if "%c%"=="106" (start "" "https://support.microsoft.com/office/language-accessory-pack-for-microsoft-365-82ee1236-0f9a-45ee-9c72-05b026ee809f" & pause & goto office_download)
if "%c%"=="107" (start "" "https://learn.microsoft.com/officeupdates/update-history-microsoft365-apps-by-date" & pause & goto office_download)
if "%c%"=="108" (start "" "https://learn.microsoft.com/officeupdates/current-channel" & pause & goto office_download)
if "%c%"=="109" (start "" "https://learn.microsoft.com/microsoft-365-apps/deploy/office-deployment-tool-configuration-options" & pause & goto office_download)
if "%c%"=="110" (start "" "https://support.microsoft.com/office/use-the-office-offline-installer-f0a85fe7-118f-41cb-a791-d59cef96ad1c" & pause & goto office_download)
if "%c%"=="111" (start "" "https://apps.microsoft.com/search?query=Microsoft%20365" & pause & goto office_download)
if "%c%"=="112" (start "" "https://officecdn.microsoft.com/pr/wsus/setup.exe" & pause & goto office_download)
if "%c%"=="99" goto go_back
if "%c%"=="00" goto main
goto office_download

:office_search_download
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% OFFICE / PRODUCTIVITY SEARCH ^& DOWNLOAD FINDER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo Type any office/productivity app name. Example: Office 2021, LibreOffice, PDF reader, OneDrive, Teams.
echo.
set "OFFICE_SEARCH_QUERY="
set /p OFFICE_SEARCH_QUERY=Search Office/App: 
if "%OFFICE_SEARCH_QUERY%"=="" goto office_download
powershell -NoProfile -ExecutionPolicy Bypass -Command "$q=[Environment]::GetEnvironmentVariable('OFFICE_SEARCH_QUERY'); $url='https://www.google.com/search?q='+[uri]::EscapeDataString($q+' official download'); Start-Process $url"
pause
goto office_download

:: ============================================================
:: CATEGORY 7: BACKUP & RECOVERY
:: ============================================================
:cat_backup
set "BACK_MENU=cat_backup"
cls
color 03
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  [CATEGORY 7] BACKUP ^& RECOVERY
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] System Backup                              [2] File Backup                                [3] System Restore                             %C_RESET%
echo %C_GREEN%  [4] Registry Backup                            [5] Driver Backup                              [6] Emergency Tools                            %C_RESET%
echo %C_GREEN%  [7] Recovery Options                           [8] Reset This PC                              [9] Disk Image                                 %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" goto system_backup
if "%c%"=="2" goto file_backup
if "%c%"=="3" goto sys_restore
if "%c%"=="4" goto reg_backup
if "%c%"=="5" goto driver_backup
if "%c%"=="6" goto emergency_tools
if "%c%"=="7" goto recovery_opts
if "%c%"=="8" goto reset_pc
if "%c%"=="9" goto disk_image
if "%c%"=="99" goto main
goto cat_backup

:system_backup
cls & color 03
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [7.1] SYSTEM BACKUP%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Create System Image                        [2] Backup Settings (GUI)                      [3] Create Restore Point                       %C_RESET%
echo %C_GREEN%  [4] View Restore Points                        [5] File History Setup                         [6] OneDrive Backup                            %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" sdclt & goto system_backup)
if "%c%"=="2" (start "" ms-settings:backup & goto system_backup)
if "%c%"=="3" (powershell -command "Checkpoint-Computer -Description 'Manual Restore Point' -RestorePointType 'MODIFY_SETTINGS'" & echo Restore Point Created. & pause & goto system_backup)
if "%c%"=="4" (rstrui.exe & goto system_backup)
if "%c%"=="5" (start "" ms-settings:backup & goto system_backup)
if "%c%"=="6" (start "" ms-settings:onedrive & goto system_backup)
if "%c%"=="99" goto go_back
goto system_backup

:file_backup
cls & color 03
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [7.2] FILE BACKUP / RESTORE - DRIVE PICKER PRO%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Backup Desktop to selected drive        [2] Backup Documents to selected drive      [3] Backup Pictures to selected drive%C_RESET%
echo %C_GREEN%  [4] Backup Custom Folder                    [5] Restore Folder Backup from drive        [6] Advanced Robocopy Backup%C_RESET%
echo %C_GREEN%  [7] Open File Backup Root                   [8] File History GUI                        [9] Verify / List Backup Folders%C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (set "FILE_BACKUP_SOURCE=%USERPROFILE%\Desktop" & set "FILE_BACKUP_NAME=Desktop" & set "FILE_BACKUP_RETURN=file_backup" & goto file_backup_to_drive)
if "%c%"=="2" (set "FILE_BACKUP_SOURCE=%USERPROFILE%\Documents" & set "FILE_BACKUP_NAME=Documents" & set "FILE_BACKUP_RETURN=file_backup" & goto file_backup_to_drive)
if "%c%"=="3" (set "FILE_BACKUP_SOURCE=%USERPROFILE%\Pictures" & set "FILE_BACKUP_NAME=Pictures" & set "FILE_BACKUP_RETURN=file_backup" & goto file_backup_to_drive)
if "%c%"=="4" goto file_backup_custom_to_drive
if "%c%"=="5" (set "FILE_RESTORE_RETURN=file_backup" & goto file_restore_from_drive)
if "%c%"=="6" goto file_backup_advanced_to_drive
if "%c%"=="7" goto file_open_backup_root
if "%c%"=="8" (start "" control /name Microsoft.FileHistory & goto file_backup)
if "%c%"=="9" goto file_verify_backup_root
if "%c%"=="99" goto go_back
goto file_backup

:file_backup_custom_to_drive
cls
set "FILE_BACKUP_SOURCE=" & set /p FILE_BACKUP_SOURCE=Source folder to backup: 
if "!FILE_BACKUP_SOURCE!"=="" goto file_backup
set "FILE_BACKUP_NAME=Custom"
set "FILE_BACKUP_RETURN=file_backup"
goto file_backup_to_drive

:file_backup_advanced_to_drive
cls
set "FILE_BACKUP_SOURCE=" & set /p FILE_BACKUP_SOURCE=Source folder to backup with Robocopy: 
if "!FILE_BACKUP_SOURCE!"=="" goto file_backup
set "FILE_BACKUP_NAME=Advanced"
set "FILE_BACKUP_RETURN=file_backup"
goto file_backup_to_drive

:file_open_backup_root
call :pick_target_drive
if errorlevel 1 goto file_backup
set "FILE_BACKUP_ROOT=!PICKED_DRIVE!\IT_Toolkit_Backups\Files"
if not exist "!FILE_BACKUP_ROOT!" mkdir "!FILE_BACKUP_ROOT!" >nul 2>&1
explorer "!FILE_BACKUP_ROOT!"
goto file_backup

:file_verify_backup_root
call :pick_target_drive
if errorlevel 1 goto file_backup
set "FILE_BACKUP_ROOT=!PICKED_DRIVE!\IT_Toolkit_Backups\Files"
if not exist "!FILE_BACKUP_ROOT!" mkdir "!FILE_BACKUP_ROOT!" >nul 2>&1
echo.
echo File backup folders in !FILE_BACKUP_ROOT!:
dir /ad /o-d "!FILE_BACKUP_ROOT!"
pause
goto file_backup

:sys_restore
cls & color 03
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [7.3] SYSTEM RESTORE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Open System Restore                        [2] Create Restore Point                       [3] Enable System Restore                      %C_RESET%
echo %C_GREEN%  [4] Disable System Restore                     [5] List Restore Points                        %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (rstrui.exe & goto sys_restore)
if "%c%"=="2" (powershell -command "Checkpoint-Computer -Description 'Restore Point' -RestorePointType 'MODIFY_SETTINGS'" & echo Created. & pause & goto sys_restore)
if "%c%"=="3" (powershell -command "Enable-ComputerRestore -Drive 'C:\'" & echo System Restore Enabled. & pause & goto sys_restore)
if "%c%"=="4" (powershell -command "Disable-ComputerRestore -Drive 'C:\'" & echo System Restore Disabled. & pause & goto sys_restore)
if "%c%"=="5" (powershell -command "Get-ComputerRestorePoint" & pause & goto sys_restore)
if "%c%"=="99" goto go_back
goto sys_restore

:reg_backup
cls & color 03
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [7.4] REGISTRY BACKUP / RESTORE - DRIVE PICKER PRO%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Backup HKCU to selected drive           [2] Backup HKLM to selected drive           [3] Backup HKCR to selected drive%C_RESET%
echo %C_GREEN%  [4] Backup Full Registry to drive           [5] Restore .reg from selected drive        [6] Open Registry Backup Root%C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (set "REG_BACKUP_MODE=HKCU" & set "REG_BACKUP_RETURN=reg_backup" & goto registry_backup_to_drive)
if "%c%"=="2" (set "REG_BACKUP_MODE=HKLM" & set "REG_BACKUP_RETURN=reg_backup" & goto registry_backup_to_drive)
if "%c%"=="3" (set "REG_BACKUP_MODE=HKCR" & set "REG_BACKUP_RETURN=reg_backup" & goto registry_backup_to_drive)
if "%c%"=="4" (set "REG_BACKUP_MODE=FULL" & set "REG_BACKUP_RETURN=reg_backup" & goto registry_backup_to_drive)
if "%c%"=="5" (set "REG_RESTORE_RETURN=reg_backup" & goto registry_restore_from_drive)
if "%c%"=="6" goto reg_open_backup_root
if "%c%"=="99" goto go_back
goto reg_backup

:reg_open_backup_root
call :pick_target_drive
if errorlevel 1 goto reg_backup
set "REG_BACKUP_ROOT=!PICKED_DRIVE!\IT_Toolkit_Backups\Registry"
if not exist "!REG_BACKUP_ROOT!" mkdir "!REG_BACKUP_ROOT!" >nul 2>&1
explorer "!REG_BACKUP_ROOT!"
goto reg_backup

:driver_backup
cls & color 03
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [7.5] DRIVER BACKUP / RESTORE - DRIVE PICKER PRO%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Backup all drivers to selected drive    [2] Restore drivers from selected drive     [3] List third-party drivers%C_RESET%
echo %C_GREEN%  [4] Open Driver Backup Root                 [5] Device Manager                          [6] Problem Devices Scan%C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (set "DRIVER_BACKUP_RETURN=driver_backup" & goto driver_backup_to_drive)
if "%c%"=="2" (set "DRIVER_RESTORE_RETURN=driver_backup" & goto driver_restore_from_drive)
if "%c%"=="3" (pnputil /enum-drivers & pause & goto driver_backup)
if "%c%"=="4" goto driver_open_backup_root
if "%c%"=="5" (start "" devmgmt.msc & goto driver_backup)
if "%c%"=="6" (pnputil /enum-devices /problem /deviceids & pause & goto driver_backup)
if "%c%"=="99" goto go_back
goto driver_backup

:emergency_tools
cls & color 03
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [7.6] EMERGENCY TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Kill All Non-Essential                     [2] Kill Explorer                              [3] Force Kill Process                         %C_RESET%
echo %C_GREEN%  [4] Emergency Restart                          [5] Emergency Shutdown                         [6] Task Manager                               %C_RESET%
echo %C_GREEN%  [7] Emergency CMD                              [8] Undo Last Action (Restore)                 %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (taskkill /f /im chrome.exe >nul 2>&1 & taskkill /f /im msedge.exe >nul 2>&1 & taskkill /f /im firefox.exe >nul 2>&1 & taskkill /f /im winword.exe >nul 2>&1 & echo Non-essential killed. & pause & goto emergency_tools)
if "%c%"=="2" (taskkill /f /im explorer.exe & goto emergency_tools)
if "%c%"=="3" (set "proc=" & set /p proc=Process name: & taskkill /f /im !proc! & pause & goto emergency_tools)
if "%c%"=="4" (shutdown /r /f /t 0)
if "%c%"=="5" (shutdown /s /f /t 0)
if "%c%"=="6" (start "" taskmgr & goto emergency_tools)
if "%c%"=="7" (cmd.exe)
if "%c%"=="8" (rstrui.exe & goto emergency_tools)
if "%c%"=="99" goto go_back
goto emergency_tools

:recovery_opts
cls & color 03
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [7.7] RECOVERY OPTIONS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Advanced Startup                           [2] Safe Mode Enable                           [3] Safe Mode Exit                             %C_RESET%
echo %C_GREEN%  [4] Recovery Console                           [5] System Restore                             [6] Startup Repair                             %C_RESET%
echo %C_GREEN%  [7] Recovery Settings                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (shutdown /r /o /f /t 0)
if "%c%"=="2" (bcdedit /set {current} safeboot minimal & echo Restart to Safe Mode. & pause & goto recovery_opts)
if "%c%"=="3" (bcdedit /deletevalue {current} safeboot & echo Normal boot restored. & pause & goto recovery_opts)
if "%c%"=="4" (cmd.exe)
if "%c%"=="5" (rstrui.exe & goto recovery_opts)
if "%c%"=="6" (shutdown /r /o /f /t 0)
if "%c%"=="7" (start "" ms-settings:recovery & goto recovery_opts)
if "%c%"=="99" goto go_back
goto recovery_opts

:reset_pc
cls & color 03
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [7.8] RESET THIS PC%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Reset (Keep Files)                         [2] Reset (Remove Everything)                  [3] Reset Settings GUI                         %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" ms-settings:recovery & echo Click Reset this PC - Keep my files & pause & goto reset_pc)
if "%c%"=="2" (echo WARNING: All data will be deleted! & set "confirm=" & set /p confirm=Type YES to continue: & if "!confirm!"=="YES" systemreset -factoryreset & goto reset_pc)
if "%c%"=="3" (start "" ms-settings:recovery & goto reset_pc)
if "%c%"=="99" goto go_back
goto reset_pc

:disk_image
cls & color 03
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [7.9] DISK IMAGE TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Create System Image                        [2] Restore System Image                       [3] Windows Backup GUI                         %C_RESET%
echo %C_GREEN%  [4] Disk Image Info                            [5] DISM / WIM Auto Center                    [6] WIM / ESD Info                            %C_RESET%
echo %C_GREEN%  [7] Apply / Restore WIM to Drive               [8] Capture New WIM                           [9] Copy Install WIM / ESD                    %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" sdclt & goto disk_image)
if "%c%"=="2" (start "" sdclt & goto disk_image)
if "%c%"=="3" (start "" ms-settings:backup & goto disk_image)
if "%c%"=="4" (call :ps_disk_drives & pause & goto disk_image)
if "%c%"=="5" (set "WIM_CENTER_BACK=disk_image" & goto dism_wim_center)
if "%c%"=="6" goto dism_wim_info
if "%c%"=="7" goto dism_wim_apply
if "%c%"=="8" goto dism_wim_capture
if "%c%"=="9" goto dism_wim_copy_install
if "%c%"=="99" goto go_back
goto disk_image

:: ---- DISM / WIM Auto Center ----
:dism_wim_center
if not defined BACK_MENU set "BACK_MENU=main"
cls & color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% DISM / WIM AUTO CENTER - INSTALL / COPY / RESTORE / CAPTURE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Auto RestoreHealth from ISO / USB / WIM / ESD     [2] List WIM / ESD indexes               [3] Copy install.wim / esd / swm%C_RESET%
echo %C_GREEN%  [4] Export ESD/WIM to new install.wim                 [5] Apply / Install WIM to target drive  [6] Capture drive/folder to new WIM%C_RESET%
echo %C_GREEN%  [7] Mount WIM                                         [8] Unmount WIM Commit/Discard           [9] Cleanup stale WIM mounts%C_RESET%
echo %C_GREEN%  [10] Add drivers to offline WIM                       [11] DISM command reference%C_RESET%
echo.
echo %C_YELLOW%  [99] Back     [00] Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="1" goto dism_wim_restore_auto
if "%c%"=="2" goto dism_wim_info
if "%c%"=="3" goto dism_wim_copy_install
if "%c%"=="4" goto dism_wim_export_install
if "%c%"=="5" goto dism_wim_apply
if "%c%"=="6" goto dism_wim_capture
if "%c%"=="7" goto dism_wim_mount
if "%c%"=="8" goto dism_wim_unmount
if "%c%"=="9" (DISM /Cleanup-Wim & pause & goto dism_wim_center)
if "%c%"=="10" goto dism_wim_add_drivers
if "%c%"=="11" goto dism_wim_reference
if "%c%"=="99" goto dism_wim_back
if "%c%"=="00" goto main
goto dism_wim_center

:dism_wim_back
if defined WIM_CENTER_BACK (
    set "WIM_BACK=!WIM_CENTER_BACK!"
    set "WIM_CENTER_BACK="
    set "SAFE_TARGET=!WIM_BACK!"
    goto safe_goto
)
goto go_back

:dism_wim_pick_image
set "WIM_PATH="
set "WIM_KIND="
set "WIM_EXT="
set "WIM_SPLIT_PATTERN="
set "WIM_ISO_PATH="
set "WIM_ISO_DRIVE="
set "WIM_ISO_MOUNTED="
echo.
echo Enter WIM/ESD/SWM/ISO/folder path.
echo Blank = auto scan all drives for \sources\install.wim / install.esd / install.swm.
set "WIM_INPUT=" & set /p WIM_INPUT=Path:
if "!WIM_INPUT!"=="" goto dism_wim_auto_find
set "WIM_INPUT=!WIM_INPUT:"=!"
if exist "!WIM_INPUT!\sources\install.wim" (set "WIM_PATH=!WIM_INPUT!\sources\install.wim" & call :dism_wim_set_kind & exit /b 0)
if exist "!WIM_INPUT!\sources\install.esd" (set "WIM_PATH=!WIM_INPUT!\sources\install.esd" & call :dism_wim_set_kind & exit /b 0)
if exist "!WIM_INPUT!\sources\install.swm" (set "WIM_PATH=!WIM_INPUT!\sources\install.swm" & call :dism_wim_set_kind & exit /b 0)
for %%F in ("!WIM_INPUT!") do set "WIM_EXT=%%~xF"
if /i "!WIM_EXT!"==".iso" goto dism_wim_pick_iso
if exist "!WIM_INPUT!" (
    set "WIM_PATH=!WIM_INPUT!"
    call :dism_wim_set_kind
    exit /b !errorlevel!
)
echo Source not found.
exit /b 1

:dism_wim_auto_find
for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z C) do (
    if not defined WIM_PATH if exist "%%D:\sources\install.wim" set "WIM_PATH=%%D:\sources\install.wim"
    if not defined WIM_PATH if exist "%%D:\sources\install.esd" set "WIM_PATH=%%D:\sources\install.esd"
    if not defined WIM_PATH if exist "%%D:\sources\install.swm" set "WIM_PATH=%%D:\sources\install.swm"
)
if not defined WIM_PATH (
    echo No install.wim / install.esd / install.swm found on available drives.
    exit /b 1
)
call :dism_wim_set_kind
exit /b %errorlevel%

:dism_wim_pick_iso
set "WIM_ISO_PATH=!WIM_INPUT!"
set "ISO_DRIVE_FILE=%TEMP%\it_toolkit_iso_%RANDOM%.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $iso=$env:WIM_ISO_PATH; $img=Mount-DiskImage -ImagePath $iso -PassThru; Start-Sleep -Seconds 2; $letter=($img | Get-Volume).DriveLetter; if(-not $letter){throw 'Mounted ISO drive letter not found.'}; Set-Content -LiteralPath $env:ISO_DRIVE_FILE -Value ($letter+':') -Encoding ASCII"
if errorlevel 1 (
    echo ISO mount failed.
    exit /b 1
)
for /f "usebackq delims=" %%D in ("!ISO_DRIVE_FILE!") do set "WIM_ISO_DRIVE=%%D"
del /f /q "!ISO_DRIVE_FILE!" >nul 2>&1
set "WIM_ISO_MOUNTED=1"
if exist "!WIM_ISO_DRIVE!\sources\install.wim" (set "WIM_PATH=!WIM_ISO_DRIVE!\sources\install.wim" & call :dism_wim_set_kind & exit /b 0)
if exist "!WIM_ISO_DRIVE!\sources\install.esd" (set "WIM_PATH=!WIM_ISO_DRIVE!\sources\install.esd" & call :dism_wim_set_kind & exit /b 0)
if exist "!WIM_ISO_DRIVE!\sources\install.swm" (set "WIM_PATH=!WIM_ISO_DRIVE!\sources\install.swm" & call :dism_wim_set_kind & exit /b 0)
echo ISO mounted but install image was not found in \sources.
call :dism_wim_cleanup_iso
exit /b 1

:dism_wim_set_kind
for %%F in ("!WIM_PATH!") do set "WIM_EXT=%%~xF"
if /i "!WIM_EXT!"==".wim" (set "WIM_KIND=wim" & exit /b 0)
if /i "!WIM_EXT!"==".esd" (set "WIM_KIND=esd" & exit /b 0)
if /i "!WIM_EXT!"==".swm" (
    set "WIM_KIND=wim"
    for %%F in ("!WIM_PATH!") do set "WIM_SPLIT_PATTERN=%%~dpFinstall*.swm"
    exit /b 0
)
echo Unsupported image type. Use .wim, .esd, .swm, .iso, or a Windows setup folder.
exit /b 1

:dism_wim_cleanup_iso
if defined WIM_ISO_MOUNTED if defined WIM_ISO_PATH powershell -NoProfile -ExecutionPolicy Bypass -Command "Dismount-DiskImage -ImagePath $env:WIM_ISO_PATH -ErrorAction SilentlyContinue" >nul 2>&1
set "WIM_ISO_MOUNTED="
set "WIM_ISO_PATH="
set "WIM_ISO_DRIVE="
exit /b

:dism_wim_info
cls & color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% WIM / ESD IMAGE INFO%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
call :dism_wim_pick_image
if errorlevel 1 (pause & goto dism_wim_center)
echo.
echo Selected image: !WIM_PATH!
if defined WIM_SPLIT_PATTERN (
    DISM /Get-WimInfo /WimFile:"!WIM_PATH!" /SWMFile:"!WIM_SPLIT_PATTERN!"
) else (
    DISM /Get-WimInfo /WimFile:"!WIM_PATH!"
)
call :dism_wim_cleanup_iso
pause
goto dism_wim_center

:dism_wim_restore_auto
cls & color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% AUTO DISM RESTOREHEALTH FROM LOCAL WIM / ESD / ISO / USB%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
call :dism_wim_pick_image
if errorlevel 1 (
    echo No local image selected. Running normal online DISM RestoreHealth.
    DISM /Online /Cleanup-Image /RestoreHealth
    pause
    goto dism_wim_center
)
echo.
echo Image indexes:
if defined WIM_SPLIT_PATTERN (
    DISM /Get-WimInfo /WimFile:"!WIM_PATH!" /SWMFile:"!WIM_SPLIT_PATTERN!"
) else (
    DISM /Get-WimInfo /WimFile:"!WIM_PATH!"
)
echo.
set "WIM_INDEX=" & set /p WIM_INDEX=Index to use blank=1:
if "!WIM_INDEX!"=="" set "WIM_INDEX=1"
set "WIM_SOURCE=!WIM_KIND!:!WIM_PATH!:!WIM_INDEX!"
echo.
echo Running:
echo DISM /Online /Cleanup-Image /RestoreHealth /Source:"!WIM_SOURCE!" /LimitAccess
DISM /Online /Cleanup-Image /RestoreHealth /Source:"!WIM_SOURCE!" /LimitAccess
call :dism_wim_cleanup_iso
pause
goto dism_wim_center

:dism_wim_copy_install
cls & color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% COPY INSTALL WIM / ESD / SWM TO SELECTED DRIVE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
call :dism_wim_pick_image
if errorlevel 1 (pause & goto dism_wim_center)
call :pick_target_drive
if errorlevel 1 (call :dism_wim_cleanup_iso & goto dism_wim_center)
call :make_timestamp
set "WIM_COPY_DEST=!PICKED_DRIVE!\IT_Toolkit_Backups\WIM\Install_Image_%COMPUTERNAME%_%stamp%"
if not exist "!WIM_COPY_DEST!" mkdir "!WIM_COPY_DEST!" >nul 2>&1
if defined WIM_SPLIT_PATTERN (
    for %%F in ("!WIM_SPLIT_PATTERN!") do copy /y "%%~fF" "!WIM_COPY_DEST!\" >nul
) else (
    copy /y "!WIM_PATH!" "!WIM_COPY_DEST!\" >nul
)
echo Install image copied to:
echo !WIM_COPY_DEST!
call :dism_wim_cleanup_iso
pause
goto dism_wim_center

:dism_wim_export_install
cls & color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% EXPORT / CONVERT TO NEW INSTALL.WIM%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
call :dism_wim_pick_image
if errorlevel 1 (pause & goto dism_wim_center)
echo.
if defined WIM_SPLIT_PATTERN (
    DISM /Get-WimInfo /WimFile:"!WIM_PATH!" /SWMFile:"!WIM_SPLIT_PATTERN!"
) else (
    DISM /Get-WimInfo /WimFile:"!WIM_PATH!"
)
echo.
set "WIM_INDEX=" & set /p WIM_INDEX=Source index blank=1:
if "!WIM_INDEX!"=="" set "WIM_INDEX=1"
call :make_timestamp
set "EXPORT_DEST=" & set /p EXPORT_DEST=Destination install.wim path blank=Desktop\install_%stamp%.wim:
if "!EXPORT_DEST!"=="" set "EXPORT_DEST=%USERPROFILE%\Desktop\install_%stamp%.wim"
set "EXPORT_DEST=!EXPORT_DEST:"=!"
for %%F in ("!EXPORT_DEST!") do if not exist "%%~dpF" mkdir "%%~dpF" >nul 2>&1
if defined WIM_SPLIT_PATTERN (
    DISM /Export-Image /SourceImageFile:"!WIM_PATH!" /SWMFile:"!WIM_SPLIT_PATTERN!" /SourceIndex:!WIM_INDEX! /DestinationImageFile:"!EXPORT_DEST!" /DestinationName:"Windows Install" /Compress:max /CheckIntegrity
) else (
    DISM /Export-Image /SourceImageFile:"!WIM_PATH!" /SourceIndex:!WIM_INDEX! /DestinationImageFile:"!EXPORT_DEST!" /DestinationName:"Windows Install" /Compress:max /CheckIntegrity
)
echo New install WIM path:
echo !EXPORT_DEST!
call :dism_wim_cleanup_iso
pause
goto dism_wim_center

:dism_wim_apply
cls & color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% APPLY / INSTALL WIM TO TARGET DRIVE - ADVANCED%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo WARNING: This applies Windows files to the target drive. Use only on the correct prepared partition.
echo It does not format the drive automatically.
echo.
call :dism_wim_pick_image
if errorlevel 1 (pause & goto dism_wim_center)
if defined WIM_SPLIT_PATTERN (
    DISM /Get-WimInfo /WimFile:"!WIM_PATH!" /SWMFile:"!WIM_SPLIT_PATTERN!"
) else (
    DISM /Get-WimInfo /WimFile:"!WIM_PATH!"
)
echo.
set "WIM_INDEX=" & set /p WIM_INDEX=Index to apply blank=1:
if "!WIM_INDEX!"=="" set "WIM_INDEX=1"
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_LogicalDisk | Where-Object {$_.DriveType -in 2,3} | Sort-Object DeviceID | Select DeviceID,VolumeName,FileSystem,@{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,1)}} | Format-Table -AutoSize"
set "APPLY_DRIVE=" & set /p APPLY_DRIVE=Target drive letter, example W:
if "!APPLY_DRIVE!"=="" (call :dism_wim_cleanup_iso & goto dism_wim_center)
set "APPLY_DRIVE=!APPLY_DRIVE::=!"
set "APPLY_DRIVE=!APPLY_DRIVE:~0,1!:"
if not exist "!APPLY_DRIVE!\" (
    echo Target drive not found: !APPLY_DRIVE!
    call :dism_wim_cleanup_iso
    pause
    goto dism_wim_center
)
echo.
echo Type APPLY !APPLY_DRIVE! to start applying image index !WIM_INDEX! to !APPLY_DRIVE!\ .
set "APPLY_OK=" & set /p APPLY_OK=Confirm:
if /i not "!APPLY_OK!"=="APPLY !APPLY_DRIVE!" (
    echo Cancelled.
    call :dism_wim_cleanup_iso
    pause
    goto dism_wim_center
)
if defined WIM_SPLIT_PATTERN (
    DISM /Apply-Image /ImageFile:"!WIM_PATH!" /SWMFile:"!WIM_SPLIT_PATTERN!" /Index:!WIM_INDEX! /ApplyDir:"!APPLY_DRIVE!\"
) else (
    DISM /Apply-Image /ImageFile:"!WIM_PATH!" /Index:!WIM_INDEX! /ApplyDir:"!APPLY_DRIVE!\"
)
echo.
set "BOOT_OK=" & set /p BOOT_OK=Create boot files with BCDBoot on same drive? (Y/N):
if /i "!BOOT_OK!"=="Y" bcdboot "!APPLY_DRIVE!\Windows" /s !APPLY_DRIVE! /f ALL
call :dism_wim_cleanup_iso
pause
goto dism_wim_center

:dism_wim_capture
cls & color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% CAPTURE DRIVE / FOLDER TO NEW WIM%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
set "CAPTURE_DIR=" & set /p CAPTURE_DIR=Capture source folder/drive, example D:\ :
if "!CAPTURE_DIR!"=="" goto dism_wim_center
set "CAPTURE_DIR=!CAPTURE_DIR:"=!"
if not exist "!CAPTURE_DIR!" (
    echo Capture source not found.
    pause
    goto dism_wim_center
)
call :make_timestamp
set "NEW_WIM_PATH=" & set /p NEW_WIM_PATH=Destination .wim path blank=selected drive backup:
if "!NEW_WIM_PATH!"=="" (
    call :pick_target_drive
    if errorlevel 1 goto dism_wim_center
    set "NEW_WIM_PATH=!PICKED_DRIVE!\IT_Toolkit_Backups\WIM\Captured_%COMPUTERNAME%_%stamp%.wim"
)
set "NEW_WIM_PATH=!NEW_WIM_PATH:"=!"
for %%F in ("!NEW_WIM_PATH!") do if not exist "%%~dpF" mkdir "%%~dpF" >nul 2>&1
set "WIM_NAME=" & set /p WIM_NAME=Image name blank=Captured_Windows:
if "!WIM_NAME!"=="" set "WIM_NAME=Captured_Windows"
echo.
echo Type CAPTURE to create:
echo !NEW_WIM_PATH!
set "CAPTURE_OK=" & set /p CAPTURE_OK=Confirm:
if /i not "!CAPTURE_OK!"=="CAPTURE" goto dism_wim_center
DISM /Capture-Image /ImageFile:"!NEW_WIM_PATH!" /CaptureDir:"!CAPTURE_DIR!" /Name:"!WIM_NAME!" /Description:"Captured by IT Toolkit" /Compress:max /CheckIntegrity
echo WIM capture finished:
echo !NEW_WIM_PATH!
pause
goto dism_wim_center

:dism_wim_mount
cls & color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% MOUNT WIM%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
call :dism_wim_pick_image
if errorlevel 1 (pause & goto dism_wim_center)
if defined WIM_ISO_MOUNTED (
    echo Mounting directly from ISO is not recommended. Copy/export the WIM first, then mount it.
    call :dism_wim_cleanup_iso
    pause
    goto dism_wim_center
)
DISM /Get-WimInfo /WimFile:"!WIM_PATH!"
set "WIM_INDEX=" & set /p WIM_INDEX=Index to mount blank=1:
if "!WIM_INDEX!"=="" set "WIM_INDEX=1"
set "MOUNT_DIR=" & set /p MOUNT_DIR=Mount folder blank=C:\IT_Toolkit_WIM_Mount:
if "!MOUNT_DIR!"=="" set "MOUNT_DIR=C:\IT_Toolkit_WIM_Mount"
set "MOUNT_DIR=!MOUNT_DIR:"=!"
if not exist "!MOUNT_DIR!" mkdir "!MOUNT_DIR!" >nul 2>&1
DISM /Mount-Image /ImageFile:"!WIM_PATH!" /Index:!WIM_INDEX! /MountDir:"!MOUNT_DIR!"
echo Mounted folder:
echo !MOUNT_DIR!
pause
goto dism_wim_center

:dism_wim_unmount
cls & color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% UNMOUNT WIM - COMMIT OR DISCARD%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
set "MOUNT_DIR=" & set /p MOUNT_DIR=Mounted WIM folder blank=C:\IT_Toolkit_WIM_Mount:
if "!MOUNT_DIR!"=="" set "MOUNT_DIR=C:\IT_Toolkit_WIM_Mount"
set "MOUNT_DIR=!MOUNT_DIR:"=!"
set "COMMIT_OK=" & set /p COMMIT_OK=Commit changes? Y=Commit / N=Discard:
if /i "!COMMIT_OK!"=="Y" (
    DISM /Unmount-Image /MountDir:"!MOUNT_DIR!" /Commit
) else (
    DISM /Unmount-Image /MountDir:"!MOUNT_DIR!" /Discard
)
pause
goto dism_wim_center

:dism_wim_add_drivers
cls & color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% ADD DRIVERS TO OFFLINE WIM%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
set "MOUNT_DIR=" & set /p MOUNT_DIR=Mounted Windows image folder:
if "!MOUNT_DIR!"=="" goto dism_wim_center
set "MOUNT_DIR=!MOUNT_DIR:"=!"
if not exist "!MOUNT_DIR!\Windows" (
    echo Mounted image Windows folder not found.
    pause
    goto dism_wim_center
)
set "DRIVER_DIR=" & set /p DRIVER_DIR=Driver INF folder:
if "!DRIVER_DIR!"=="" goto dism_wim_center
set "DRIVER_DIR=!DRIVER_DIR:"=!"
if not exist "!DRIVER_DIR!" (
    echo Driver folder not found.
    pause
    goto dism_wim_center
)
DISM /Image:"!MOUNT_DIR!" /Add-Driver /Driver:"!DRIVER_DIR!" /Recurse
pause
goto dism_wim_center

:dism_wim_reference
cls & color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% DISM / WIM COMMAND REFERENCE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo  DISM /Online /Cleanup-Image /CheckHealth
echo  DISM /Online /Cleanup-Image /ScanHealth
echo  DISM /Online /Cleanup-Image /RestoreHealth
echo  DISM /Online /Cleanup-Image /RestoreHealth /Source:"wim:D:\sources\install.wim:1" /LimitAccess
echo  DISM /Get-WimInfo /WimFile:"D:\sources\install.wim"
echo  DISM /Export-Image /SourceImageFile:"D:\sources\install.esd" /SourceIndex:1 /DestinationImageFile:"C:\install.wim" /Compress:max /CheckIntegrity
echo  DISM /Apply-Image /ImageFile:"D:\sources\install.wim" /Index:1 /ApplyDir:"W:\"
echo  DISM /Capture-Image /ImageFile:"E:\backup.wim" /CaptureDir:"C:\" /Name:"Windows Backup" /Compress:max /CheckIntegrity
echo  DISM /Mount-Image /ImageFile:"C:\install.wim" /Index:1 /MountDir:"C:\Mount"
echo  DISM /Unmount-Image /MountDir:"C:\Mount" /Commit
echo  DISM /Cleanup-Wim
echo.
pause
goto dism_wim_center

:: ============================================================
:: CATEGORY 8: ADVANCED & EXTRAS
:: ============================================================
:cat_extras
set "BACK_MENU=cat_extras"
cls
color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  [CATEGORY 8] ADVANCED ^& EXTRAS
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] User ^& PC Info                            [2] Group Policy ^& Registry                   [3] Hyper-V ^& WSL                             %C_RESET%
echo %C_GREEN%  [4] Network Advanced Diag                      [5] Event Log Analyzer                         [6] Windows Activation                         %C_RESET%
echo %C_GREEN%  [7] Environment Variables                      [8] Scheduled Tasks                            [9] Advanced Admin Tools                       %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" goto user_pc_info
if "%c%"=="2" goto gpo_reg
if "%c%"=="3" goto hyperv_wsl
if "%c%"=="4" goto net_adv_diag
if "%c%"=="5" goto event_log
if "%c%"=="6" goto win_activation
if "%c%"=="7" goto env_vars
if "%c%"=="8" goto sched_tasks
if "%c%"=="9" goto adv_admin
if "%c%"=="99" goto main
goto cat_extras

:user_pc_info
cls & color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [8.1] USER ^& PC INFO%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Full System Info                           [2] PC Name ^& Domain                          [3] Current User                               %C_RESET%
echo %C_GREEN%  [4] All Users                                  [5] IP ^& Network Info                         [6] Disk Info                                  %C_RESET%
echo %C_GREEN%  [7] Uptime                                     [8] Boot Time                                  [9] Installed Software                         %C_RESET%
echo %C_GREEN%  [10] Windows License                           [11] Generate Full Report                      %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (msinfo32 & goto user_pc_info)
if "%c%"=="2" (systeminfo ^| findstr /c:"Host Name" /c:"Domain" & pause & goto user_pc_info)
if "%c%"=="3" (whoami & echo. & net user %username% & pause & goto user_pc_info)
if "%c%"=="4" (net user & pause & goto user_pc_info)
if "%c%"=="5" (ipconfig /all & pause & goto user_pc_info)
if "%c%"=="6" (call :ps_logical_disks & pause & goto user_pc_info)
if "%c%"=="7" (powershell -command "(Get-Date) - (gcim Win32_OperatingSystem).LastBootUpTime" & pause & goto user_pc_info)
if "%c%"=="8" (powershell -command "(gcim Win32_OperatingSystem).LastBootUpTime" & pause & goto user_pc_info)
if "%c%"=="9" (call :ps_installed_apps & pause & goto user_pc_info)
if "%c%"=="10" (slmgr /dlv & goto user_pc_info)
if "%c%"=="11" goto sysreport
if "%c%"=="99" goto go_back
goto user_pc_info

:gpo_reg
cls & color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [8.2] GROUP POLICY ^& REGISTRY%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Group Policy Editor                        [2] GPO Update Force                           [3] GPO Reset                                  %C_RESET%
echo %C_GREEN%  [4] Local Security Policy                      [5] Registry Editor                            [6] Registry Backup                            %C_RESET%
echo %C_GREEN%  [7] Reg Query (Custom)                         [8] Reg Add (Custom)                           [9] Reg Delete (Custom)                        %C_RESET%
echo %C_GREEN%  [10] Policy Result (RSOP)                      %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" gpedit.msc & goto gpo_reg)
if "%c%"=="2" (gpupdate /force & pause & goto gpo_reg)
if "%c%"=="3" (rd /s /q "%ALLUSERSPROFILE%\Microsoft\Group Policy" >nul 2>&1 & gpupdate /force & echo GPO Reset. & pause & goto gpo_reg)
if "%c%"=="4" (start "" secpol.msc & goto gpo_reg)
if "%c%"=="5" (start "" regedit & goto gpo_reg)
if "%c%"=="6" (reg export HKCU "%USERPROFILE%\Desktop\RegBackup.reg" & echo Backed up. & pause & goto gpo_reg)
if "%c%"=="7" (set "key=" & set /p key=Registry Key: & reg query "!key!" & pause & goto gpo_reg)
if "%c%"=="8" (set "key=" & set /p key=Key: & set "val=" & set /p val=Value Name: & set "dat=" & set /p dat=Data: & reg add "!key!" /v !val! /d !dat! /f & pause & goto gpo_reg)
if "%c%"=="9" (set "key=" & set /p key=Key: & set "val=" & set /p val=Value Name: & reg delete "!key!" /v !val! /f & pause & goto gpo_reg)
if "%c%"=="10" (rsop.msc & pause & goto gpo_reg)
if "%c%"=="99" goto go_back
goto gpo_reg

:hyperv_wsl
cls & color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [8.3] HYPER-V ^& WSL TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Enable Hyper-V                             [2] Disable Hyper-V                            [3] Hyper-V Manager                            %C_RESET%
echo %C_GREEN%  [4] WSL Install                                [5] WSL List Distros                           [6] WSL Update                                 %C_RESET%
echo %C_GREEN%  [7] WSL Enable                                 [8] WSL Disable                                [9] Virtual Machine Info                       %C_RESET%
echo %C_GREEN%  [10] Windows Sandbox Enable                    %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (dism /online /enable-feature /featurename:Microsoft-Hyper-V-All /all & echo Hyper-V Enabled. Restart needed. & pause & goto hyperv_wsl)
if "%c%"=="2" (dism /online /disable-feature /featurename:Microsoft-Hyper-V-All & echo Hyper-V Disabled. & pause & goto hyperv_wsl)
if "%c%"=="3" (call :open_hyperv_manager & pause & goto hyperv_wsl)
if "%c%"=="4" (wsl --install & pause & goto hyperv_wsl)
if "%c%"=="5" (wsl --list --verbose & pause & goto hyperv_wsl)
if "%c%"=="6" (wsl --update & pause & goto hyperv_wsl)
if "%c%"=="7" (dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux & echo WSL Enabled. Restart. & pause & goto hyperv_wsl)
if "%c%"=="8" (dism /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux & echo WSL Disabled. & pause & goto hyperv_wsl)
if "%c%"=="9" (powershell -command "Get-VM" & pause & goto hyperv_wsl)
if "%c%"=="10" (dism /online /enable-feature /featurename:Containers-DisposableClientVM /all & echo Sandbox Enabled. Restart. & pause & goto hyperv_wsl)
if "%c%"=="99" goto go_back
goto hyperv_wsl

:event_log
cls & color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [8.5] EVENT LOG ANALYZER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Event Viewer GUI                           [2] Critical Errors (Last 7 Days)              [3] System Errors                              %C_RESET%
echo %C_GREEN%  [4] Application Errors                         [5] Security Logs                              [6] BSOD Events                                %C_RESET%
echo %C_GREEN%  [7] Login Events                               [8] Clear All Logs                             [9] Export Logs to Desktop                     %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (eventvwr.msc & goto event_log)
if "%c%"=="2" (powershell -command "Get-WinEvent -LogName System | Where-Object {$_.LevelDisplayName -eq 'Critical' -and $_.TimeCreated -gt (Get-Date).AddDays(-7)} | Select-Object TimeCreated,Message | Format-List" & pause & goto event_log)
if "%c%"=="3" (powershell -command "Get-WinEvent -LogName System | Where-Object {$_.Level -eq 2} | Select-Object -First 20 TimeCreated,Message | Format-List" & pause & goto event_log)
if "%c%"=="4" (powershell -command "Get-WinEvent -LogName Application | Where-Object {$_.Level -eq 2} | Select-Object -First 20 TimeCreated,Message | Format-List" & pause & goto event_log)
if "%c%"=="5" (powershell -command "Get-WinEvent -LogName Security | Select-Object -First 20 TimeCreated,Message | Format-List" & pause & goto event_log)
if "%c%"=="6" (powershell -command "Get-WinEvent -LogName System | Where-Object {$_.Id -eq 41 -or $_.Id -eq 6008} | Select-Object -First 10 TimeCreated,Message | Format-List" & pause & goto event_log)
if "%c%"=="7" (powershell -command "Get-WinEvent -LogName Security | Where-Object {$_.Id -eq 4624} | Select-Object -First 20 TimeCreated,Message | Format-List" & pause & goto event_log)
if "%c%"=="8" (for /F "tokens=*" %%G in ('wevtutil.exe el') DO wevtutil.exe cl "%%G" 2>nul & echo All Logs Cleared. & pause & goto event_log)
if "%c%"=="9" (wevtutil epl System "%USERPROFILE%\Desktop\System_Log.evtx" & wevtutil epl Application "%USERPROFILE%\Desktop\App_Log.evtx" & echo Logs saved to Desktop. & pause & goto event_log)
if "%c%"=="99" goto go_back
goto event_log

:win_activation
cls & color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [8.6] WINDOWS ACTIVATION%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Activation Status                          [2] Activate Windows                           [3] View License Info                          %C_RESET%
echo %C_GREEN%  [4] Change Product Key                         [5] Rearm                                      [6] Activation Settings                        %C_RESET%
echo %C_GREEN%  [7] Online Activation                          [8] OEM Key Check                              %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (slmgr /xpr & goto win_activation)
if "%c%"=="2" (slmgr /ato & pause & goto win_activation)
if "%c%"=="3" (slmgr /dlv & pause & goto win_activation)
if "%c%"=="4" (set "key=" & set /p key=New Key: & slmgr /ipk !key! & pause & goto win_activation)
if "%c%"=="5" (slmgr /rearm & echo Rearm Done. Restart. & pause & goto win_activation)
if "%c%"=="6" (start "" ms-settings:activation & goto win_activation)
if "%c%"=="7" (slmgr /ato & pause & goto win_activation)
if "%c%"=="8" (call :ps_oem_key & pause & goto win_activation)
if "%c%"=="99" goto go_back
goto win_activation

:env_vars
cls & color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [8.7] ENVIRONMENT VARIABLES%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] View All Variables                         [2] View User Variables                        [3] View System Variables                      %C_RESET%
echo %C_GREEN%  [4] Add User Variable                          [5] Add System Variable                        [6] Delete Variable                            %C_RESET%
echo %C_GREEN%  [7] Edit PATH                                  [8] Env Variables GUI                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (set & pause & goto env_vars)
if "%c%"=="2" (reg query "HKCU\Environment" & pause & goto env_vars)
if "%c%"=="3" (reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" & pause & goto env_vars)
if "%c%"=="4" (set "var=" & set /p var=Variable Name: & set "val=" & set /p val=Value: & setx !var! "!val!" & pause & goto env_vars)
if "%c%"=="5" (set "var=" & set /p var=Variable Name: & set "val=" & set /p val=Value: & setx !var! "!val!" /m & pause & goto env_vars)
if "%c%"=="6" (set "var=" & set /p var=Variable Name: & reg delete "HKCU\Environment" /v !var! /f & pause & goto env_vars)
if "%c%"=="7" (start "" sysdm.cpl & goto env_vars)
if "%c%"=="8" (start "" sysdm.cpl & goto env_vars)
if "%c%"=="99" goto go_back
goto env_vars

:sched_tasks
cls & color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [8.8] SCHEDULED TASKS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Task Scheduler GUI                         [2] List All Tasks                             [3] Run a Task                                 %C_RESET%
echo %C_GREEN%  [4] Delete a Task                              [5] Disable a Task                             [6] Enable a Task                              %C_RESET%
echo %C_GREEN%  [7] Create Basic Task                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" taskschd.msc & goto sched_tasks)
if "%c%"=="2" (schtasks /query /fo list & pause & goto sched_tasks)
if "%c%"=="3" (set "task=" & set /p task=Task Name: & schtasks /run /tn "!task!" & pause & goto sched_tasks)
if "%c%"=="4" (set "task=" & set /p task=Task Name: & schtasks /delete /tn "!task!" /f & pause & goto sched_tasks)
if "%c%"=="5" (set "task=" & set /p task=Task Name: & schtasks /change /tn "!task!" /disable & pause & goto sched_tasks)
if "%c%"=="6" (set "task=" & set /p task=Task Name: & schtasks /change /tn "!task!" /enable & pause & goto sched_tasks)
if "%c%"=="7" (start "" taskschd.msc & echo Use the GUI to create a task. & pause & goto sched_tasks)
if "%c%"=="99" goto go_back
goto sched_tasks

:adv_admin
cls & color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [8.9] ADVANCED ADMIN TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Computer Management                        [2] Local Users ^& Groups                      [3] Services (Advanced)                        %C_RESET%
echo %C_GREEN%  [4] Component Services                         [5] Performance Monitor                        [6] Resource Monitor                           %C_RESET%
echo %C_GREEN%  [7] Reliability Monitor                        [8] Disk Management                            [9] Print Management                           %C_RESET%
echo %C_GREEN%  [10] Remote Desktop                            [11] Shared Folders                            [12] Certificate Manager                       %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" compmgmt.msc & goto adv_admin)
if "%c%"=="2" (start "" lusrmgr.msc & goto adv_admin)
if "%c%"=="3" (start "" services.msc & goto adv_admin)
if "%c%"=="4" (start "" dcomcnfg & goto adv_admin)
if "%c%"=="5" (start "" perfmon & goto adv_admin)
if "%c%"=="6" (start "" resmon & goto adv_admin)
if "%c%"=="7" (start "" perfmon /rel & goto adv_admin)
if "%c%"=="8" (start "" diskmgmt.msc & goto adv_admin)
if "%c%"=="9" (start "" printmanagement.msc & goto adv_admin)
if "%c%"=="10" (start "" mstsc & pause & goto adv_admin)
if "%c%"=="11" (start "" fsmgmt.msc & pause & goto adv_admin)
if "%c%"=="12" (start "" certmgr.msc & pause & goto adv_admin)
if "%c%"=="99" goto go_back
goto adv_admin

:net_adv_diag
cls & color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [8.4] NETWORK ADVANCED DIAGNOSTICS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Full Diagnostics Report                    [2] Bandwidth Test (Browser)                   [3] TCP/IP Full Reset                          %C_RESET%
echo %C_GREEN%  [4] DNS Full Reset                             [5] IP Conflict Check                          [6] Gateway Check                              %C_RESET%
echo %C_GREEN%  [7] Latency Check (Ping)                       [8] ISP Check                                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (
    echo === FULL NETWORK DIAGNOSTICS REPORT ===
    echo Date: %date% Time: %time%
    echo. & ipconfig /all
    echo. & echo === PING 8.8.8.8 === & ping 8.8.8.8 -n 4
    echo. & echo === NSLOOKUP === & nslookup google.com
    echo. & echo === ROUTE TABLE === & route print
    echo. & echo === OPEN CONNECTIONS === & netstat -an
    echo. & echo === FIREWALL === & netsh advfirewall show allprofiles state
    pause & goto net_adv_diag
)
if "%c%"=="2" (start "" "https://fast.com" & goto net_adv_diag)
if "%c%"=="3" (netsh int tcp reset & netsh int ip reset & netsh winsock reset & echo TCP/IP Reset. Restart. & pause & goto net_adv_diag)
if "%c%"=="4" (ipconfig /flushdns & ipconfig /registerdns & echo DNS Full Reset. & pause & goto net_adv_diag)
if "%c%"=="5" (arp -a & pause & goto net_adv_diag)
if "%c%"=="6" (ipconfig ^| findstr "Default Gateway" & pause & goto net_adv_diag)
if "%c%"=="7" (ping 8.8.8.8 -n 20 & pause & goto net_adv_diag)
if "%c%"=="8" (start "" "https://www.whatismyisp.com" & goto net_adv_diag)
if "%c%"=="99" goto go_back
goto net_adv_diag

:: ============================================================
:: [9] QUICK TOOLS - ONE CLICK
:: ============================================================
:quicktools
set "BACK_MENU=quicktools"
cls
color 0F
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [9] QUICK TOOLS - ONE CLICK FIX%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [9] QUICK TOOLS - ONE CLICK FIX                [1] ONE CLICK - Internet Fix                   [2] ONE CLICK - Windows Full Repair            %C_RESET%
echo %C_GREEN%  [3] ONE CLICK - Malware Cleanup                [4] ONE CLICK - Speed Boost                    [5] ONE CLICK - Full System Cleanup            %C_RESET%
echo %C_GREEN%  [6] ONE CLICK - Print Spooler Fix              [7] ONE CLICK - Audio Fix                      [8] ONE CLICK - Explorer Fix                   %C_RESET%
echo %C_GREEN%  [10] ONE CLICK - Security Hardening            [11] ONE CLICK - Browser Cache Fix             [12] ONE CLICK - Teams/Zoom Cache Fix          %C_RESET%
echo %C_GREEN%  [13] ONE CLICK - Windows Apps Fix              [14] ONE CLICK - Location/GPS Fix              [15] Create Restore Point First                %C_RESET%
echo %C_GREEN%  [16] Quick Health Report                       %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub

if "%c%"=="1" (
    echo INTERNET FIX RUNNING...
    ipconfig /release >nul & ipconfig /flushdns >nul & netsh winsock reset >nul & netsh int ip reset >nul & ipconfig /renew >nul
    echo INTERNET FIX DONE! Restart recommended.
    pause & goto quicktools
)
if "%c%"=="2" (
    echo WINDOWS FULL REPAIR RUNNING...
    sfc /scannow
    DISM /Online /Cleanup-Image /RestoreHealth
    echo DONE. Restart recommended.
    pause & goto quicktools
)
if "%c%"=="3" (
    echo MALWARE CLEANUP RUNNING...
    call :clean_folder_contents "%TEMP%" "User Temp"
    call :clean_folder_contents "C:\Windows\Temp" "Windows Temp"
    powershell -command "Start-MpScan -ScanType QuickScan"
    echo MALWARE CLEANUP DONE!
    pause & goto quicktools
)
if "%c%"=="4" (
    echo SPEED BOOST RUNNING...
    powercfg /setactive SCHEME_MIN >nul
    call :clean_folder_contents "%TEMP%" "User Temp"
    call :clean_folder_contents "C:\Windows\Temp" "Windows Temp"
    ipconfig /flushdns >nul
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul
    echo SPEED BOOST DONE! Restart for full effect.
    pause & goto quicktools
)
if "%c%"=="5" (
    echo FULL SYSTEM CLEANUP RUNNING...
    call :one_clean_core
    echo FULL CLEANUP DONE!
    pause & goto quicktools
)
if "%c%"=="6" (
    echo PRINT SPOOLER FIX RUNNING...
    net stop spooler >nul
    del /f /s /q "C:\Windows\System32\spool\PRINTERS\*" >nul 2>&1
    net start spooler >nul
    echo PRINT SPOOLER FIXED!
    pause & goto quicktools
)
if "%c%"=="7" (
    echo AUDIO FIX RUNNING...
    net stop audiosrv >nul & net stop AudioEndpointBuilder >nul
    net start AudioEndpointBuilder >nul & net start audiosrv >nul
    echo AUDIO FIX DONE!
    pause & goto quicktools
)
if "%c%"=="8" (
    echo EXPLORER FIX RUNNING...
    taskkill /f /im explorer.exe >nul 2>&1
    start explorer.exe
    echo EXPLORER FIX DONE!
    pause & goto quicktools
)
if "%c%"=="9" (
    echo WINDOWS UPDATE FIX RUNNING...
    net stop wuauserv >nul & net stop bits >nul & net stop cryptSvc >nul
    ren C:\Windows\SoftwareDistribution SoftwareDistribution.old >nul 2>&1
    net start wuauserv >nul & net start bits >nul & net start cryptSvc >nul
    echo WINDOWS UPDATE FIX DONE!
    pause & goto quicktools
)
if "%c%"=="10" (
    echo SECURITY HARDENING RUNNING...
    netsh advfirewall set allprofiles state on >nul
    powershell -command "Set-MpPreference -DisableRealtimeMonitoring $false" >nul 2>&1
    powershell -command "Set-MpPreference -PUAProtection Enabled" >nul 2>&1
    net user Guest /active:no >nul
    echo SECURITY HARDENING DONE!
    pause & goto quicktools
)
if "%c%"=="11" (
    echo BROWSER CACHE FIX RUNNING...
    taskkill /f /im chrome.exe >nul 2>&1
    taskkill /f /im msedge.exe >nul 2>&1
    call :clean_browser_caches
    ipconfig /flushdns >nul 2>&1
    echo Browser cache and DNS cache cleaned. Bookmarks/passwords untouched.
    pause & goto quicktools
)
if "%c%"=="12" (
    echo TEAMS/ZOOM CACHE FIX RUNNING...
    taskkill /f /im ms-teams.exe >nul 2>&1
    taskkill /f /im Teams.exe >nul 2>&1
    taskkill /f /im Zoom.exe >nul 2>&1
    del /f /s /q "%AppData%\Microsoft\Teams\Cache\*" >nul 2>&1
    del /f /s /q "%AppData%\Microsoft\Teams\GPUCache\*" >nul 2>&1
    del /f /s /q "%AppData%\Zoom\data\WebviewCache\*" >nul 2>&1
    echo Teams/Zoom cache cleanup done.
    pause & goto quicktools
)
if "%c%"=="13" (
    echo WINDOWS APPS FIX RUNNING...
    wsreset.exe
    powershell -command "Get-AppxPackage Microsoft.WindowsStore | Reset-AppxPackage" >nul 2>&1
    powershell -command "Get-AppxPackage Microsoft.Windows.ShellExperienceHost | Reset-AppxPackage" >nul 2>&1
    echo Windows apps fix done.
    pause & goto quicktools
)
if "%c%"=="14" (
    echo LOCATION/GPS QUICK FIX RUNNING...
    net stop lfsvc >nul 2>&1
    net stop SensorService >nul 2>&1
    del /f /s /q "%ProgramData%\Microsoft\Windows\Location\*" >nul 2>&1
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f >nul 2>&1
    net start SensorService >nul 2>&1
    net start lfsvc >nul 2>&1
    echo Location/GPS fix done. Open Settings if the app still needs permission.
    pause & goto quicktools
)
if "%c%"=="15" goto create_restore_point
if "%c%"=="16" goto quick_health_report
if "%c%"=="99" goto main
goto quicktools

:: ============================================================
:: [11] WOW HEALTH DASHBOARD
:: ============================================================
:health_dashboard
cls
color 0F
if exist "%TEMP%\toolkit_alerts.txt" del "%TEMP%\toolkit_alerts.txt" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$severeAlerts = @();" ^
    "$critCount = 0; $warnCount = 0; $okCount = 0;" ^
    "Write-Host '=================================================================================' -ForegroundColor Cyan;" ^
    "Write-Host '                AI CYBER-HEURISTIC DIAGNOSTIC ENGINE (CMD MODE)                  ' -ForegroundColor Magenta -BackgroundColor Black;" ^
    "Write-Host '=================================================================================' -ForegroundColor Cyan;" ^
    "Write-Host 'Target PC: '$env:COMPUTERNAME' | Time: '$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -ForegroundColor Gray;" ^
    "Write-Host '=================================================================================' -ForegroundColor Cyan;" ^
    "Write-Host '';" ^
    "Write-Host '[1/6] Scanning Storage S.M.A.R.T. & Memory Modules...' -ForegroundColor Yellow;" ^
    "$smartAlert = $false;" ^
    "try { $drives = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue; foreach ($d in $drives) { if ($d.PredictFailure) { $smartAlert = $true } } } catch {};" ^
    "$queueAlert = $false;" ^
    "try { $diskPerf = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter \"Name='_Total'\" -ErrorAction SilentlyContinue; if ($null -ne $diskPerf -and $diskPerf.CurrentDiskQueueLength -gt 2) { $queueAlert = $true } } catch {};" ^
    "$ramHardwareAlert = $false;" ^
    "try { $memDevices = Get-CimInstance Win32_MemoryDevice -ErrorAction SilentlyContinue; foreach ($m in $memDevices) { if ($m.ErrorAccess -or $m.ErrorDescription -or ($m.ErrorMethodology -match 'Error Correction')) { $ramHardwareAlert = $true } } } catch {};" ^
    "if ($smartAlert) { Write-Host '   [CRITICAL] S.M.A.R.T. predictive failure detected on storage drive!' -ForegroundColor Red; $critCount++ } else { $okCount++ };" ^
    "if ($queueAlert) { Write-Host '   [WARNING] Extreme disk active queue saturation detected!' -ForegroundColor Yellow; $warnCount++ };" ^
    "if ($ramHardwareAlert) { Write-Host '   [CRITICAL] Motherboard physical RAM memory faults found!' -ForegroundColor Red; $critCount++ } else { $okCount++ };" ^
    "if (-not ($smartAlert -or $queueAlert -or $ramHardwareAlert)) { Write-Host '   [OK] Storage & Memory hardware healthy.' -ForegroundColor Green };" ^
    "Write-Host '[2/6] Parsing OS crash logs and BSOD dumps...' -ForegroundColor Yellow;" ^
    "$unexpectedShutdownCount = 0; $bsodAlert = $false; $thermalAlert = $false; $cpuTemp = 0;" ^
    "try { $startTime = (Get-Date).AddDays(-3); $events = Get-WinEvent -FilterHashtable @{ LogName='System'; Id=@(41, 6008); StartTime=$startTime } -MaxEvents 10 -ErrorAction SilentlyContinue; if ($events) { $unexpectedShutdownCount = $events.Count } } catch {};" ^
    "try { $dumpPath = 'C:\Windows\Minidump'; if (Test-Path -LiteralPath $dumpPath) { $dumps = Get-ChildItem -LiteralPath $dumpPath -Filter '*.dmp' -ErrorAction SilentlyContinue; if ($null -ne $dumps -and $dumps.Count -gt 0) { $bsodAlert = $true } } } catch {};" ^
    "try { $zones = Get-CimInstance -Namespace root\wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue; foreach ($z in $zones) { $tempC = ($z.CurrentTemperature - 2732) / 10; if ($tempC -gt $cpuTemp) { $cpuTemp = $tempC } }; if ($cpuTemp -gt 82) { $thermalAlert = $true } } catch {};" ^
    "if ($unexpectedShutdownCount -gt 0) { if ($thermalAlert) { Write-Host '   [CRITICAL] CPU Overheating ('$([Math]::Round($cpuTemp,1))'C) caused sudden shutdowns!' -ForegroundColor Red; $critCount++ } else { Write-Host '   [CRITICAL] Detected '$unexpectedShutdownCount' unexpected power-off events.' -ForegroundColor Red; $critCount++ } } else { $okCount++ };" ^
    "if ($bsodAlert) { Write-Host '   [CRITICAL] Blue Screen of Death (BSOD) minidump logs detected!' -ForegroundColor Red; $critCount++ } else { $okCount++ };" ^
    "if ($unexpectedShutdownCount -eq 0 -and -not $bsodAlert) { Write-Host '   [OK] OS stability logs healthy.' -ForegroundColor Green };" ^
    "Write-Host '[3/6] Auditing system drivers and battery wear...' -ForegroundColor Yellow;" ^
    "$driverAlert = $false; $crashedDrivers = @();" ^
    "try { $badDevices = Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } -ErrorAction SilentlyContinue; if ($badDevices) { $driverAlert = $true; foreach ($d in $badDevices) { $crashedDrivers += $d.Name } } } catch {};" ^
    "$batteryAlert = $false; $batteryWear = 0;" ^
    "try { $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue; if ($battery) { $design = $battery.DesignCapacity; $full = $battery.FullChargeCapacity; if ($design -gt 0 -and $full -gt 0) { $batteryWear = [Math]::Round((1 - ($full / $design)) * 100, 1); if ($batteryWear -gt 25) { $batteryAlert = $true } } } } catch {};" ^
    "if ($driverAlert) { Write-Host '   [CRITICAL] Found '$crashedDrivers.Count' faulty device drivers in Device Manager!' -ForegroundColor Red; $critCount++ } else { $okCount++ };" ^
    "if ($batteryAlert) { Write-Host '   [WARNING] Laptop battery wear is severe ('$batteryWear'%)!' -ForegroundColor Yellow; $warnCount++ };" ^
    "if (-not ($driverAlert -or $batteryAlert)) { Write-Host '   [OK] System device drivers & battery healthy.' -ForegroundColor Green };" ^
    "Write-Host '[4/6] Auditing OS integrity, updates & security policies...' -ForegroundColor Yellow;" ^
    "$osFileAlert = $false;" ^
    "try { $cbsPath = 'C:\Windows\Logs\CBS\CBS.log'; if (Test-Path $cbsPath) { $corruptLines = Get-Content -Path $cbsPath -Tail 500 -ErrorAction SilentlyContinue | Where-Object { $_ -like \"*Corrupt*\" -and $_ -like \"*Repair*\" }; if ($corruptLines) { $osFileAlert = $true } } } catch {};" ^
    "$wuAlert = $false; $wuDetails = '';" ^
    "try { $rebootPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'; $wuauserv = Get-Service wuauserv -ErrorAction SilentlyContinue; if ($rebootPending) { $wuAlert = $true; $wuDetails = 'Pending Restart' } elseif ($wuauserv -and $wuauserv.Status -eq 'Stopped' -and $wuauserv.StartType -eq 'Disabled') { $wuAlert = $true; $wuDetails = 'Service Disabled' } } catch {};" ^
    "$activationAlert = $false;" ^
    "try { $lic = Get-CimInstance SoftwareLicensingProduct -Filter \"ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' and LicenseStatus=1\" -ErrorAction SilentlyContinue; if (-not $lic) { $activationAlert = $true } } catch {};" ^
    "$uacAlert = $false;" ^
    "try { $uacVal = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin' -ErrorAction SilentlyContinue; if ($uacVal -eq 0) { $uacAlert = $true } } catch {};" ^
    "$volumeAlert = $false;" ^
    "try { $vols = Get-Volume -ErrorAction SilentlyContinue; foreach ($v in $vols) { if ($v.HealthStatus -ne 'Healthy' -or $v.OperationalStatus -match 'Dirty') { $volumeAlert = $true } } } catch {};" ^
    "if ($osFileAlert) { Write-Host '   [CRITICAL] System file integrity issues found in CBS log!' -ForegroundColor Red; $critCount++ } else { $okCount++ };" ^
    "if ($wuAlert) { Write-Host '   [WARNING] Windows Update requires attention: '$wuDetails -ForegroundColor Yellow; $warnCount++ };" ^
    "if ($activationAlert) { Write-Host '   [WARNING] Windows license is not activated/expired!' -ForegroundColor Yellow; $warnCount++ };" ^
    "if ($uacAlert) { Write-Host '   [CRITICAL] UAC Security Policy is disabled! High Risk.' -ForegroundColor Red; $critCount++ } else { $okCount++ };" ^
    "if ($volumeAlert) { Write-Host '   [CRITICAL] Active storage volume is dirty/corrupted!' -ForegroundColor Red; $critCount++ } else { $okCount++ };" ^
    "if (-not ($osFileAlert -or $wuAlert -or $activationAlert -or $uacAlert -or $volumeAlert)) { Write-Host '   [OK] OS integrity & security policies healthy.' -ForegroundColor Green };" ^
    "Write-Host '[5/6] Pinpointing network routing & DNS resolution...' -ForegroundColor Yellow;" ^
    "$netIP = \"\"; $netGateway = \"\"; $isApipa = $false; $gatewayPingOk = $false; $pingISP = $false; $pingDNS = $false;" ^
    "try { $config = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address } | Select-Object -First 1; if ($config) { $netIP = $config.IPv4Address.IPAddress; if ($config.IPv4DefaultGateway) { $netGateway = $config.IPv4DefaultGateway.NextHop } } } catch {};" ^
    "if ([string]::IsNullOrEmpty($netIP)) { Write-Host '   [CRITICAL] No local IP Address. Adapter offline!' -ForegroundColor Red; $critCount++ } elseif ($netIP -like '169.254.*') { $isApipa = $true; Write-Host '   [CRITICAL] DHCP Failure - APIPA IP ('$netIP') assigned!' -ForegroundColor Red; $critCount++ } else { if (-not [string]::IsNullOrEmpty($netGateway)) { try { $gatewayPingOk = Test-Connection $netGateway -Count 1 -Quiet -ErrorAction SilentlyContinue } catch {} }; try { $pingISP = Test-Connection 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue } catch {}; try { $pingDNS = Test-Connection google.com -Count 1 -Quiet -ErrorAction SilentlyContinue } catch {}; if ($gatewayPingOk -and -not $pingISP) { Write-Host '   [CRITICAL] Wi-Fi/Router OK but Internet WAN Offline (Aage se net nahi aa raha)!' -ForegroundColor Red; $critCount++ } elseif ($pingISP -and -not $pingDNS) { Write-Host '   [WARNING] DNS Resolution Failure. Websites will not load.' -ForegroundColor Yellow; $warnCount++ } elseif ($pingDNS) { Write-Host '   [OK] Internet connection & DNS healthy.' -ForegroundColor Green; $okCount++ } else { Write-Host '   [CRITICAL] Complete network route is offline!' -ForegroundColor Red; $critCount++ } };" ^
    "Write-Host '[6/6] Sweeping system resource loads...' -ForegroundColor Yellow;" ^
    "$cpuLoad = 0; $ramPercent = 0; $totalGB = 0; $usedGB = 0;" ^
    "try { $cpuInstance = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue; if ($cpuInstance) { $cpuLoad = $cpuInstance.LoadPercentage } } catch {};" ^
    "try { Add-Type -AssemblyName 'Microsoft.VisualBasic' -ErrorAction SilentlyContinue; $info = New-Object Microsoft.VisualBasic.Devices.ComputerInfo; $totalGB = [Math]::Round($info.TotalPhysicalMemory / 1GB, 1); $freeGB = [Math]::Round($info.AvailablePhysicalMemory / 1GB, 1); $usedGB = $totalGB - $freeGB; if ($totalGB -gt 0) { $ramPercent = [Math]::Round(($usedGB / $totalGB) * 100, 1) } } catch {};" ^
    "if ($cpuLoad -gt 85 -or $ramPercent -gt 90) { Write-Host '   [WARNING] High resource load: CPU '$cpuLoad'% | RAM '$ramPercent'%!' -ForegroundColor Yellow; $warnCount++ } else { Write-Host '   [OK] System resources in healthy range: CPU '$cpuLoad'% | RAM '$ramPercent'%.' -ForegroundColor Green; $okCount++ };" ^
    "Write-Host '';" ^
    "Write-Host '=================================================================================' -ForegroundColor Cyan;" ^
    "Write-Host '                       DIAGNOSTIC SUMMARY & ADVISORIES                           ' -ForegroundColor Magenta;" ^
    "Write-Host '=================================================================================' -ForegroundColor Cyan;" ^
    "if ($critCount -gt 0) { Write-Host '  - Critical Issues: '$critCount -ForegroundColor Red } else { Write-Host '  - Critical Issues: '$critCount -ForegroundColor Green };" ^
    "if ($warnCount -gt 0) { Write-Host '  - Warnings:        '$warnCount -ForegroundColor Yellow } else { Write-Host '  - Warnings:        '$warnCount -ForegroundColor Gray };" ^
    "Write-Host '  - Healthy Checks:  '$okCount -ForegroundColor Green;" ^
    "Write-Host '=================================================================================' -ForegroundColor Cyan;" ^
    "$severeAlerts = @();" ^
    "if ($smartAlert) { $severeAlerts += 'STORAGE_SMART' }; if ($queueAlert) { $severeAlerts += 'STORAGE_QUEUE' }; if ($ramHardwareAlert) { $severeAlerts += 'RAM_FAULT' };" ^
    "if ($unexpectedShutdownCount -gt 0) { $severeAlerts += 'OS_SHUTDOWN' }; if ($bsodAlert) { $severeAlerts += 'OS_BSOD' };" ^
    "if ($driverAlert) { $severeAlerts += 'FAULTY_DRIVERS' }; if ($batteryAlert) { $severeAlerts += 'BATTERY_WEAR' };" ^
    "if ($osFileAlert) { $severeAlerts += 'OS_CORRUPTION' }; if ($wuAlert) { $severeAlerts += 'WINDOWS_UPDATE' };" ^
    "if ($activationAlert) { $severeAlerts += 'WINDOWS_LICENSE' }; if ($uacAlert) { $severeAlerts += 'UAC_RISK' }; if ($volumeAlert) { $severeAlerts += 'VOLUME_DIRTY' };" ^
    "if ([string]::IsNullOrEmpty($netIP) -or $isApipa -or ($gatewayPingOk -and -not $pingISP) -or -not $pingDNS) { $severeAlerts += 'NET_OFFLINE' };" ^
    "if ($severeAlerts.Count -gt 0) { [System.IO.File]::WriteAllText('%TEMP%\toolkit_alerts.txt', ($severeAlerts -join ',')) }"

set "SEVERE_ALERTS="
if exist "%TEMP%\toolkit_alerts.txt" (
    set /p SEVERE_ALERTS=<%TEMP%\toolkit_alerts.txt
    del "%TEMP%\toolkit_alerts.txt" >nul 2>&1
)

if "%SEVERE_ALERTS%"=="" (
    echo.
    echo %C_GREEN%>> AI HEALTH ADVISORY: EXCELLENT PC HEALTH!%C_RESET%
    echo %C_GREEN%>> All system components are operating optimally. No actions required.%C_RESET%
    echo.
    pause
    goto go_back
)

echo.
echo %C_RED%>> Severe issues detected: %SEVERE_ALERTS%%C_RESET%
echo.
echo %C_YELLOW%[1] Run 1-Click AI Auto-Repair now%C_RESET%
echo %C_YELLOW%[2] Back to menu%C_RESET%
echo.
set /p opt="Select Option: "
if "%opt%"=="1" (
    cls
    echo %C_CYAN%=================================================================================%C_RESET%
    echo                      APPLYING 1-CLICK AI AUTO-REPAIR                         
    echo %C_CYAN%=================================================================================%C_RESET%
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$alerts = '%SEVERE_ALERTS%' -split ',';" ^
        "Write-Host 'Starting 1-Click AI Auto-Repair...' -ForegroundColor Yellow;" ^
        "if ($alerts -contains 'NET_OFFLINE') {" ^
        "    Write-Host 'Repairing network stack and resetting TCP/IP...' -ForegroundColor Green;" ^
        "    $null = ipconfig /flushdns;" ^
        "    $null = netsh int ip reset;" ^
        "    $null = netsh winsock reset;" ^
        "    $null = ipconfig /release;" ^
        "    Start-Sleep -Seconds 1;" ^
        "    $null = ipconfig /renew;" ^
        "}" ^
        "if ($alerts -contains 'WINDOWS_UPDATE') {" ^
        "    Write-Host 'Restoring Windows Update services...' -ForegroundColor Green;" ^
        "    Set-Service wuauserv -StartupType Automatic;" ^
        "    Start-Service wuauserv -ErrorAction SilentlyContinue;" ^
        "}" ^
        "if ($alerts -contains 'UAC_RISK') {" ^
        "    Write-Host 'Restoring User Account Control (UAC) policy settings...' -ForegroundColor Green;" ^
        "    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin' -Value 5;" ^
        "}" ^
        "if ($alerts -contains 'OS_CORRUPTION' -or $alerts -contains 'OS_BSOD' -or $alerts -contains 'OS_SHUTDOWN') {" ^
        "    Write-Host 'Repairing system file integrity (SFC & DISM)...' -ForegroundColor Green;" ^
        "    sfc /scannow;" ^
        "    dism /Online /Cleanup-Image /RestoreHealth;" ^
        "}" ^
        "if ($alerts -contains 'VOLUME_DIRTY') {" ^
        "    Write-Host 'Scheduling volume repair for next system boot...' -ForegroundColor Green;" ^
        "    $psi = New-Object System.Diagnostics.ProcessStartInfo;" ^
        "    $psi.FileName = 'cmd.exe';" ^
        "    $psi.Arguments = '/c echo Y | chkdsk C: /f';" ^
        "    $psi.UseShellExecute = $false;" ^
        "    $psi.CreateNoWindow = $true;" ^
        "    $proc = [System.Diagnostics.Process]::Start($psi);" ^
        "    $proc.WaitForExit();" ^
        "}" ^
        "Write-Host 'AI Auto-Repair completed successfully!' -ForegroundColor Green;"
    pause
)
goto go_back

:: ============================================================
:: [12] SMART FIX WIZARD
:: ============================================================
:smartfix
set "BACK_MENU=smartfix"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [12] SMART FIX WIZARD - PROBLEM TO SOLUTION%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [12] SMART FIX WIZARD - PROBLEM TO SOLUTION    [1] Internet not working / DNS issue           [2] Slow PC / lag / high temp cleanup          %C_RESET%
echo %C_GREEN%  [3] Windows Update error                       [4] Printer offline / stuck queue              [5] Audio not working                          %C_RESET%
echo %C_GREEN%  [6] Microsoft Store / apps broken              [7] Browser slow / site not opening            [8] Location / GPS not working                 %C_RESET%
echo %C_GREEN%  [9] Blue screen / random restart               [10] Make restore point first                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto smart_internet
if "%c%"=="2" goto smart_slowpc
if "%c%"=="3" goto smart_update
if "%c%"=="4" goto smart_printer
if "%c%"=="5" goto smart_audio
if "%c%"=="6" goto smart_store
if "%c%"=="7" goto smart_browser
if "%c%"=="8" goto smart_location
if "%c%"=="9" goto smart_bsod
if "%c%"=="10" goto create_restore_point
if "%c%"=="99" goto main
goto smartfix

:smart_internet
cls
echo Recommended steps: flush DNS, reset Winsock/TCP-IP, renew IP, show adapter status.
set "ok=" & set /p ok=Run Internet Smart Fix now? (Y/N):
if /i not "%ok%"=="Y" goto smartfix
ipconfig /flushdns
netsh winsock reset
netsh int ip reset
ipconfig /release
ipconfig /renew
netsh interface show interface
echo Done. Restart is recommended after Winsock/TCP reset.
pause
goto smartfix

:smart_slowpc
cls
echo Recommended steps: clean temp/cache, flush DNS, set balanced visuals, show startup items.
set "ok=" & set /p ok=Run Slow PC Smart Fix now? (Y/N):
if /i not "%ok%"=="Y" goto smartfix
call :one_clean_core
ipconfig /flushdns >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul 2>&1
echo Startup items:
reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
echo Done. Restart recommended.
pause
goto smartfix

:smart_update
cls
echo Recommended steps: stop update services, reset update cache, restart services.
set "ok=" & set /p ok=Run Windows Update Smart Fix now? (Y/N):
if /i not "%ok%"=="Y" goto smartfix
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net stop cryptSvc >nul 2>&1
net stop msiserver >nul 2>&1
ren C:\Windows\SoftwareDistribution SoftwareDistribution.old_%RANDOM% >nul 2>&1
ren C:\Windows\System32\catroot2 catroot2.old_%RANDOM% >nul 2>&1
net start msiserver >nul 2>&1
net start cryptSvc >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
echo Windows Update cache reset done.
pause
goto smartfix

:smart_printer
cls
echo Recommended steps: stop spooler, clean stuck queue, restart spooler.
set "ok=" & set /p ok=Run Printer Smart Fix now? (Y/N):
if /i not "%ok%"=="Y" goto smartfix
net stop spooler
del /f /s /q "C:\Windows\System32\spool\PRINTERS\*" >nul 2>&1
net start spooler
printui /s /t2
echo Printer queue fixed. Printer driver window opened.
pause
goto smartfix

:smart_audio
cls
echo Recommended steps: restart Windows Audio services and open sound settings.
set "ok=" & set /p ok=Run Audio Smart Fix now? (Y/N):
if /i not "%ok%"=="Y" goto smartfix
net stop audiosrv >nul 2>&1
net stop AudioEndpointBuilder >nul 2>&1
net start AudioEndpointBuilder >nul 2>&1
net start audiosrv >nul 2>&1
start "" ms-settings:sound
echo Audio service restart done.
pause
goto smartfix

:smart_store
cls
echo Recommended steps: reset Store cache and repair Store package.
set "ok=" & set /p ok=Run Store/App Smart Fix now? (Y/N):
if /i not "%ok%"=="Y" goto smartfix
wsreset.exe
powershell -NoProfile -Command "Get-AppxPackage Microsoft.WindowsStore | Reset-AppxPackage" >nul 2>&1
powershell -NoProfile -Command "Get-AppxPackage Microsoft.Windows.ShellExperienceHost | Reset-AppxPackage" >nul 2>&1
echo Store/App fix completed.
pause
goto smartfix

:smart_browser
cls
echo Recommended steps: close Chrome/Edge, clean cache only, flush DNS.
set "ok=" & set /p ok=Run Browser Smart Fix now? (Y/N):
if /i not "%ok%"=="Y" goto smartfix
taskkill /f /im chrome.exe >nul 2>&1
taskkill /f /im msedge.exe >nul 2>&1
call :clean_browser_caches
ipconfig /flushdns >nul 2>&1
echo Browser smart fix done. Bookmarks/passwords untouched.
pause
goto smartfix

:smart_location
cls
echo Recommended steps: restart location services, clear Windows location cache, open settings.
set "ok=" & set /p ok=Run Location Smart Fix now? (Y/N):
if /i not "%ok%"=="Y" goto smartfix
net stop lfsvc >nul 2>&1
net stop SensorService >nul 2>&1
del /f /s /q "%ProgramData%\Microsoft\Windows\Location\*" >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f >nul 2>&1
net start SensorService >nul 2>&1
net start lfsvc >nul 2>&1
start "" ms-settings:privacy-location
echo Location smart fix done.
pause
goto smartfix

:smart_bsod
cls
echo Recommended steps: show BSOD events, run SFC, run DISM health check.
set "ok=" & set /p ok=Run BSOD Smart Diagnostics now? (Y/N):
if /i not "%ok%"=="Y" goto smartfix
powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,1001,6008} -ErrorAction SilentlyContinue | Select-Object -First 10 TimeCreated,Id,ProviderName,Message | Format-List"
sfc /verifyonly
DISM /Online /Cleanup-Image /CheckHealth
echo Diagnostics complete. Use Windows Repair menu for full repair.
pause
goto smartfix

:: ============================================================
:: [13] TOOLKIT UTILITIES
:: ============================================================
:toolkit_utilities
set "BACK_MENU=toolkit_utilities"
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [13] TOOLKIT UTILITIES%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [13] TOOLKIT UTILITIES                         [1] Backup this toolkit file                   [2] Create restore point                       %C_RESET%
echo %C_GREEN%  [3] Quick health report                        [4] Full system report                         [5] Open toolkit logs folder                   %C_RESET%
echo %C_GREEN%  [6] Check core Windows tools                   [7] Toolkit file checksum                      [8] About this WOW build                       %C_RESET%
echo %C_GREEN%  [9] Open legacy original backup                %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto backup_toolkit_file
if "%c%"=="2" goto create_restore_point
if "%c%"=="3" goto quick_health_report
if "%c%"=="4" goto sysreport
if "%c%"=="5" (explorer "%LOGROOT%" & goto toolkit_utilities)
if "%c%"=="6" goto check_core_tools
if "%c%"=="7" goto toolkit_checksum
if "%c%"=="8" goto about_wow
if "%c%"=="9" goto open_legacy_backup
if "%c%"=="99" goto main
goto toolkit_utilities

:backup_toolkit_file
if not exist "%USERPROFILE%\Desktop\IT_Toolkit_Backups" mkdir "%USERPROFILE%\Desktop\IT_Toolkit_Backups" >nul 2>&1
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "backup=%USERPROFILE%\Desktop\IT_Toolkit_Backups\IT_Toolkit_%stamp%.cmd"
copy "%~f0" "%backup%" >nul
echo Backup created:
echo %backup%
pause
goto go_back

:create_restore_point
cls
color 0A
echo %C_CYAN%============================================================%C_RESET%
echo  CREATE RESTORE POINT
echo %C_CYAN%============================================================%C_RESET%
echo  This is recommended before repair, update reset, registry, driver,
echo  service, cleanup, or boot-related changes.
echo %C_CYAN%============================================================%C_RESET%
set "ok=" & set /p ok=Create restore point now? (Y/N):
if /i not "%ok%"=="Y" goto go_back
powershell -NoProfile -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'IT Toolkit WOW Before Fix' -RestorePointType 'MODIFY_SETTINGS'"
echo Restore point command finished. If System Protection is off, enable it from System Restore menu.
pause
goto go_back

:quick_health_report
cls
color 0B
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "report=%LOGROOT%\Quick_Health_%stamp%.txt"
(
echo ================================================================
echo  ULTIMATE X PRO MAX %TOOLKIT_VERSION% - QUICK HEALTH REPORT
echo  By %TOOLKIT_AUTHOR%
echo  Generated: %DATE% %TIME%
echo ================================================================
echo.
echo === WINDOWS ===
powershell -NoProfile -Command "Get-CimInstance Win32_OperatingSystem | Select Caption,Version,BuildNumber,OSArchitecture,LastBootUpTime | Format-List"
echo.
echo === CPU/RAM ===
powershell -NoProfile -Command "$os=Get-CimInstance Win32_OperatingSystem; $cpu=Get-CimInstance Win32_Processor | Select -First 1; [pscustomobject]@{CPU=$cpu.Name; Cores=$cpu.NumberOfCores; LogicalCPU=$cpu.NumberOfLogicalProcessors; TotalRAMGB=[math]::Round($os.TotalVisibleMemorySize/1MB,2); FreeRAMGB=[math]::Round($os.FreePhysicalMemory/1MB,2)} | Format-List"
echo.
echo === DISKS ===
powershell -NoProfile -Command "Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select DeviceID,VolumeName,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},@{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,2)}} | Format-Table -AutoSize"
echo.
echo === NETWORK ===
ipconfig /all
echo.
echo === FIREWALL ===
netsh advfirewall show allprofiles state
echo.
echo === DEFENDER ===
powershell -NoProfile -Command "try { Get-MpComputerStatus | Select AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntispywareEnabled | Format-List } catch { 'Defender status not available.' }"
echo.
echo === LAST CRITICAL SYSTEM EVENTS ===
powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName='System'; Level=1; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue | Select -First 10 TimeCreated,Id,ProviderName | Format-Table -AutoSize"
echo.
echo ================================================================
echo  REPORT END
echo ================================================================
) > "%report%"
echo Quick health report saved:
echo %report%
start "" notepad "%report%"
pause
goto go_back

:check_core_tools
cls
color 0D
echo %C_CYAN%============================================================%C_RESET%
echo  CORE WINDOWS TOOL CHECK
echo %C_CYAN%============================================================%C_RESET%
for %%T in (sfc.exe dism.exe netsh.exe ipconfig.exe powershell.exe reg.exe sc.exe wevtutil.exe pnputil.exe chkdsk.exe) do (
    where %%T >nul 2>&1 && (echo [OK] %%T) || (echo [MISSING] %%T)
)
echo %C_CYAN%============================================================%C_RESET%
pause
goto go_back

:toolkit_checksum
cls
color 0D
echo %C_CYAN%============================================================%C_RESET%
echo  TOOLKIT FILE CHECKSUM
echo %C_CYAN%============================================================%C_RESET%
certutil -hashfile "%~f0" SHA256
echo.
pause
goto go_back

:about_wow
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  ULTIMATE X PRO MAX %TOOLKIT_VERSION% - By %TOOLKIT_AUTHOR%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  WOW upgrades added:
echo  - Ultra 01-30 control center dashboard with PC/user/log status.
echo  - Matching box-style submenus for every main module.
echo  - Smart Fix Wizard for common support problems.
echo  - Quick Health Dashboard and report generator.
echo  - Toolkit backup, checksum, restore point, and tool checks.
echo  - Safer guided VHD creation instead of broken diskpart shortcut.
echo  - Extra one-click fixes for browser, Teams/Zoom, Store apps, and Location/GPS.
echo  - Complete Issue Library for Windows, Network, Printer, Hardware, Apps, Security, Enterprise, Laptop.
echo  - 5000+ Winget Software Library with search, exact ID install, packs, export/import.
echo  - Legacy original backup launcher is available in Toolkit Utilities.
echo.
echo  Note: No remote-control payloads or hidden network code were added.
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
pause
goto go_back

:open_legacy_backup
cls
color 0D
echo %C_CYAN%============================================================%C_RESET%
echo  OPEN LEGACY ORIGINAL BACKUP
echo %C_CYAN%============================================================%C_RESET%
echo  This opens the preserved original full toolkit backup.
echo %C_CYAN%============================================================%C_RESET%
set "legacy=%TOOLKIT_ROOT%Backups\OriginalToolkitSnapshot.cmd"
if exist "%legacy%" (
    start "" "%legacy%"
    echo Legacy backup opened:
    echo %legacy%
) else (
    echo Legacy backup not found at:
    echo %legacy%
)
pause
goto go_back

:: ============================================================
:: [14] COMPLETE ISSUE LIBRARY
:: ============================================================
:issue_library
set "BACK_MENU=issue_library"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [14] COMPLETE ISSUE LIBRARY - ORGANIZED TROUBLESHOOTING HUB%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [14] COMPLETE ISSUE LIBRARY - ORGANIZED TR...  [1] Windows Core Issues                        [2] Network / WiFi / Internet                  %C_RESET%
echo %C_GREEN%  [3] Printer / Scanner / Spooler                [4] Hardware / Device / Driver                 [5] User / Profile / Apps                      %C_RESET%
echo %C_GREEN%  [6] Browser / Cloud / Office                   [7] Security / Privacy / Defender              [8] Enterprise / Admin / RDP                   %C_RESET%
echo %C_GREEN%  [9] Laptop / Power / Mobility                  [10] Deep Diagnostics Pack                     [11] Storage / Disk / Data                     %C_RESET%
echo %C_GREEN%  [12] Boot / Login / Profile                    [13] Software / Winget / Installer             [15] Reports / Evidence Collectors             %C_RESET%
echo %C_GREEN%  [16] All-In-One Problem Solver                 [17] Open Windows Troubleshooters              [18] Microsoft Problem Library                 %C_RESET%
echo %C_GREEN%  [19] 10000+ CMD Vault                                                                    %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto issue_windows_core
if "%c%"=="2" goto issue_network_pro
if "%c%"=="3" goto issue_printer_pro
if "%c%"=="4" goto issue_hardware_devices
if "%c%"=="5" goto issue_user_apps
if "%c%"=="6" goto issue_browser_cloud
if "%c%"=="7" goto issue_security_privacy
if "%c%"=="8" goto issue_enterprise_admin
if "%c%"=="9" goto issue_laptop_power
if "%c%"=="10" goto issue_deep_diagnostics
if "%c%"=="11" goto issue_storage_data
if "%c%"=="12" goto issue_boot_login
if "%c%"=="13" goto issue_software_install
if "%c%"=="14" goto issue_av_display_camera
if "%c%"=="15" goto issue_reports_evidence
if "%c%"=="16" goto problem_master_hub
if "%c%"=="17" (start "" ms-settings:troubleshoot & pause & goto issue_library)
if "%c%"=="18" goto microsoft_problem_library
if "%c%"=="19" goto cmd_vault
if "%c%"=="99" goto main
goto issue_library

:: ============================================================
:: [32] ALL-IN-ONE PROBLEM SOLVER / MASTER ISSUE HUB
:: ============================================================
:problem_master_hub
set "BACK_MENU=problem_master_hub"
cls
color 0F
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [32] ALL-IN-ONE PROBLEM SOLVER - MASTER HUB%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Windows Core Repair                    [02] Network / WiFi / DNS                 [03] Printer / Scanner%C_RESET%
echo %C_GREEN%  [04] Hardware / Driver / USB                [05] Storage / Disk / Data                [06] Boot / Login / Profile%C_RESET%
echo %C_GREEN%  [07] Software / Winget / Installer          [08] Browser / Cloud / Office             [09] Security / Privacy%C_RESET%
echo %C_GREEN%  [10] Performance / BSOD / Deep Diag         [11] Laptop / Battery / Power             [12] Enterprise / RDP / Policy%C_RESET%
echo %C_GREEN%  [13] Reports / Evidence Pack                [14] Smart Fix Wizard                     [15] Quick Health Report%C_RESET%
echo %C_GREEN%  [16] Search 5000+ Software                  [17] Windows Troubleshooters              [18] System Restore%C_RESET%
echo %C_GREEN%  [19] Full System Report                     [20] Smart Driver Auto Center             [21] 10000+ CMD Vault%C_RESET%
echo %C_GREEN%  [22] Microsoft Problem Library              [23] Open Backup Root%C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="01" goto issue_windows_core
if "%c%"=="02" goto issue_network_pro
if "%c%"=="03" goto issue_printer_pro
if "%c%"=="04" goto issue_hardware_devices
if "%c%"=="05" goto issue_storage_data
if "%c%"=="06" goto issue_boot_login
if "%c%"=="07" goto issue_software_install
if "%c%"=="08" goto issue_browser_cloud
if "%c%"=="09" goto issue_security_privacy
if "%c%"=="10" goto issue_deep_diagnostics
if "%c%"=="11" goto issue_laptop_power
if "%c%"=="12" goto issue_enterprise_admin
if "%c%"=="13" goto issue_reports_evidence
if "%c%"=="14" goto smartfix
if "%c%"=="15" goto quick_health_report
if "%c%"=="16" goto winget_installer
if "%c%"=="17" (start "" ms-settings:troubleshoot & pause & goto problem_master_hub)
if "%c%"=="18" (start "" rstrui.exe & pause & goto problem_master_hub)
if "%c%"=="19" goto sysreport
if "%c%"=="20" goto driver_auto_center
if "%c%"=="21" goto cmd_vault
if "%c%"=="22" goto microsoft_problem_library
if "%c%"=="23" goto open_backup_root
if "%c%"=="24" goto open_backup_root
if "%c%"=="99" goto main
goto problem_master_hub

:issue_storage_data
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  STORAGE / DISK / DATA ISSUES - SPACE / CHKDSK / SMART / BITLOCKER / PARTITION / LARGE FILES
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Disk Health Summary                        [2] CHKDSK C: Read-Only Scan                   [3] Schedule CHKDSK C: Repair                  %C_RESET%
echo %C_GREEN%  [4] Storage Sense Settings                     [5] Disk Management                            [6] Clean Temp Files                           %C_RESET%
echo %C_GREEN%  [7] Find Large Files on C:                     [8] BitLocker Status                           [9] Volume / Drive Letter Summary              %C_RESET%
echo %C_GREEN%  [10] Recycle Bin Cleanup                       [11] Full Storage Evidence Report              [12] Open Data Recovery Guidance               %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto issue_storage_disk_health
if "%c%"=="2" (chkdsk C: & pause & goto issue_storage_data)
if "%c%"=="3" goto issue_storage_chkdsk_repair
if "%c%"=="4" (start "" ms-settings:storagesense & pause & goto issue_storage_data)
if "%c%"=="5" (start "" diskmgmt.msc & pause & goto issue_storage_data)
if "%c%"=="6" goto issue_storage_temp_clean
if "%c%"=="7" goto issue_storage_large_files
if "%c%"=="8" (manage-bde -status & pause & goto issue_storage_data)
if "%c%"=="9" (powershell -NoProfile -Command "Get-Volume | Sort DriveLetter | Format-Table DriveLetter,FileSystemLabel,FileSystem,HealthStatus,SizeRemaining,Size -AutoSize" & pause & goto issue_storage_data)
if "%c%"=="10" (powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" & echo Recycle Bin cleanup command finished. & pause & goto issue_storage_data)
if "%c%"=="11" goto issue_storage_report
if "%c%"=="12" (start "" "https://support.microsoft.com/windows/recovery-options-in-windows" & pause & goto issue_storage_data)
if "%c%"=="99" goto go_back
goto issue_storage_data

:issue_storage_disk_health
cls
echo Disk health summary:
call :ps_disk_drives
echo.
powershell -NoProfile -Command "Get-PhysicalDisk | Select FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize" 2>nul
echo.
powershell -NoProfile -Command "Get-Volume | Sort DriveLetter | Format-Table DriveLetter,FileSystemLabel,FileSystem,HealthStatus,SizeRemaining,Size -AutoSize" 2>nul
pause
goto issue_storage_data

:issue_storage_chkdsk_repair
cls
echo This schedules CHKDSK C: /F /R if Windows says the drive is in use.
set "ok=" & set /p ok=Schedule disk repair for next restart? (Y/N):
if /i "%ok%"=="Y" (echo Y^|chkdsk C: /f /r)
pause
goto issue_storage_data

:issue_storage_temp_clean
cls
echo Cleaning user temp and Windows temp files.
call :clean_folder_contents "%TEMP%" "User Temp"
call :clean_folder_contents "C:\Windows\Temp" "Windows Temp"
cleanmgr
echo Temp cleanup command finished. Some locked files are normal.
pause
goto issue_storage_data

:issue_storage_large_files
cls
echo Scanning top 50 files larger than 1GB on C:. This can take time.
powershell -NoProfile -Command "Get-ChildItem -Path C:\ -File -Recurse -Force -ErrorAction SilentlyContinue | Where-Object Length -gt 1GB | Sort-Object Length -Descending | Select-Object -First 50 FullName,@{Name='GB';Expression={[math]::Round($_.Length/1GB,2)}} | Format-Table -AutoSize"
pause
goto issue_storage_data

:issue_storage_report
cls
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "report=%LOGROOT%\Storage_Evidence_%stamp%.txt"
(
echo === STORAGE EVIDENCE REPORT ===
echo Computer: %COMPUTERNAME%
echo User: %USERNAME%
echo Date: %DATE% %TIME%
echo.
echo === DISKDRIVE CIM ===
call :ps_disk_drives
echo.
echo === VOLUMES ===
powershell -NoProfile -Command "Get-Volume | Sort DriveLetter | Format-Table DriveLetter,FileSystemLabel,FileSystem,HealthStatus,SizeRemaining,Size -AutoSize"
echo.
echo === BITLOCKER ===
manage-bde -status
echo.
echo === TOP LARGE FILES OVER 1GB ===
powershell -NoProfile -Command "Get-ChildItem -Path C:\ -File -Recurse -Force -ErrorAction SilentlyContinue | Where-Object Length -gt 1GB | Sort-Object Length -Descending | Select-Object -First 25 FullName,@{Name='GB';Expression={[math]::Round($_.Length/1GB,2)}} | Format-Table -AutoSize"
) > "%report%" 2>&1
echo Storage report saved:
echo %report%
start "" notepad "%report%"
pause
goto issue_storage_data

:issue_boot_login
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  BOOT / LOGIN / PROFILE ISSUES - SAFE MODE / STARTUP / PROFILE / CREDENTIAL / SHELL / RECOVERY
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Advanced Startup Restart                   [2] Enable Safe Mode on Next Boot              [3] Disable Safe Mode Flag                     %C_RESET%
echo %C_GREEN%  [4] Startup Apps Review                        [5] User Profile Diagnostics                   [6] Create Local Admin User                    %C_RESET%
echo %C_GREEN%  [7] Credential Manager                         [8] Sign-in Options Settings                   [9] Explorer / Start Shell Repair              %C_RESET%
echo %C_GREEN%  [10] Boot Performance Events                   [11] System Restore                            [12] Reset PC Options                          %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto issue_boot_advanced_startup
if "%c%"=="2" (bcdedit /set {current} safeboot minimal & echo Safe Mode enabled for next boot. Use option 3 later to disable. & pause & goto issue_boot_login)
if "%c%"=="3" (bcdedit /deletevalue {current} safeboot & echo Safe Mode flag removed. & pause & goto issue_boot_login)
if "%c%"=="4" (start "" ms-settings:startupapps & taskmgr & pause & goto issue_boot_login)
if "%c%"=="5" goto issue_boot_profile_diag
if "%c%"=="6" goto issue_boot_create_admin
if "%c%"=="7" (control /name Microsoft.CredentialManager & pause & goto issue_boot_login)
if "%c%"=="8" (start "" ms-settings:signinoptions & pause & goto issue_boot_login)
if "%c%"=="9" goto issue_boot_shell_repair
if "%c%"=="10" goto issue_boot_perf_local
if "%c%"=="11" (start "" rstrui.exe & pause & goto issue_boot_login)
if "%c%"=="12" (start "" ms-settings:recovery & pause & goto issue_boot_login)
if "%c%"=="99" goto go_back
goto issue_boot_login

:issue_boot_advanced_startup
cls
echo Advanced Startup will restart this PC now.
set "ok=" & set /p ok=Restart now into Advanced Startup? (Y/N):
if /i "%ok%"=="Y" shutdown /r /o /t 0
goto issue_boot_login

:issue_boot_profile_diag
cls
echo Current user:
whoami
echo.
echo Local users:
net user
echo.
echo ProfileList registry:
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
echo.
echo If a TEMP profile is active, back up user data before editing ProfileList.
pause
goto issue_boot_login

:issue_boot_create_admin
cls
set "newuser=" & set /p newuser=Enter new local admin username:
if "%newuser%"=="" goto issue_boot_login
net user "%newuser%" * /add
net localgroup administrators "%newuser%" /add
echo Local admin user created/updated.
pause
goto issue_boot_login

:issue_boot_shell_repair
cls
echo Restarting Explorer and repairing shell packages.
taskkill /f /im explorer.exe >nul 2>&1
powershell -NoProfile -Command "Get-AppxPackage Microsoft.Windows.ShellExperienceHost | Reset-AppxPackage" >nul 2>&1
powershell -NoProfile -Command "Get-AppxPackage Microsoft.Windows.StartMenuExperienceHost | Reset-AppxPackage" >nul 2>&1
start explorer.exe
echo Shell repair finished.
pause
goto issue_boot_login

:issue_boot_perf_local
cls
wevtutil qe Microsoft-Windows-Diagnostics-Performance/Operational /q:"*[System[(EventID=100 or EventID=101 or EventID=102 or EventID=103)]]" /f:text /c:20
pause
goto issue_boot_login

:issue_software_install
cls
color 06
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  SOFTWARE / WINGET / INSTALLER ISSUES - 5000+ APPS / STORE / MSI / RUNTIMES / INVENTORY
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Search 5000+ Winget Software               [2] Install by Exact Winget ID                 [3] Winget Health / Source Repair              %C_RESET%
echo %C_GREEN%  [4] Microsoft Store / App Installer Repair     [5] Windows Installer Service Fix              [6] Installed Apps Inventory                   %C_RESET%
echo %C_GREEN%  [7] Programs and Features                      [8] Default Apps Settings                      [9] Optional Windows Features                  %C_RESET%
echo %C_GREEN%  [10] Runtime Pack Installer                    [11] Utility Pack Installer                    [12] Export Winget Apps JSON                   %C_RESET%
echo %C_GREEN%  [13] Import Winget Apps JSON                   [14] Clear Installer Temp Cache                [15] Mass Software Installer                   %C_RESET%
echo %C_GREEN%  [16] Custom Batch Winget IDs                   %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto winget_search_install
if "%c%"=="2" goto winget_install_by_id
if "%c%"=="3" goto issue_software_winget_health
if "%c%"=="4" goto issue_software_store_repair
if "%c%"=="5" goto issue_software_installer_fix
if "%c%"=="6" goto issue_software_apps_inventory
if "%c%"=="7" (start "" appwiz.cpl & pause & goto issue_software_install)
if "%c%"=="8" (start "" ms-settings:defaultapps & pause & goto issue_software_install)
if "%c%"=="9" (optionalfeatures & goto issue_software_install)
if "%c%"=="10" (set "PACK_RETURN=issue_software_install" & goto install_runtime_pack)
if "%c%"=="11" (set "PACK_RETURN=issue_software_install" & goto install_utility_pack)
if "%c%"=="12" goto winget_export_installed
if "%c%"=="13" goto winget_import_json
if "%c%"=="14" goto issue_software_temp_clean
if "%c%"=="15" goto menu_mass_installer
if "%c%"=="16" (set "PACK_RETURN=issue_software_install" & goto winget_custom_batch)
if "%c%"=="99" goto go_back
goto issue_software_install

:issue_software_winget_health
cls
call :winget_health
pause
goto issue_software_install

:issue_software_store_repair
cls
echo Resetting Store cache and repairing Store/App Installer.
wsreset.exe
powershell -NoProfile -Command "Get-AppxPackage Microsoft.WindowsStore | Reset-AppxPackage" >nul 2>&1
call :repair_app_installer
echo Store/App Installer repair finished.
pause
goto issue_software_install

:issue_software_installer_fix
cls
echo Fixing Windows Installer service.
sc config msiserver start= demand
net stop msiserver >nul 2>&1
net start msiserver
msiexec /regserver
echo Windows Installer service refreshed.
pause
goto issue_software_install

:issue_software_apps_inventory
cls
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "apps=%LOGROOT%\Software_Inventory_%stamp%.txt"
(
echo === WINGET APPS ===
call :winget_list_installed
echo.
echo === APPX PACKAGES ===
powershell -NoProfile -Command "Get-AppxPackage | Select Name,Version,PackageFullName | Sort Name | Format-Table -AutoSize"
echo.
echo === MSI / PROGRAMS REGISTRY ===
powershell -NoProfile -Command "Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | Select DisplayName,DisplayVersion,Publisher,InstallDate | Sort DisplayName | Format-Table -AutoSize"
) > "%apps%" 2>&1
echo Software inventory saved:
echo %apps%
start "" notepad "%apps%"
pause
goto issue_software_install

:issue_software_temp_clean
cls
echo Cleaning installer temp caches.
call :clean_folder_contents "%TEMP%" "User Temp"
call :clean_folder_contents "C:\Windows\Temp" "Windows Temp"
call :clean_folder_contents "%LocalAppData%\Temp" "LocalAppData Temp"
echo Installer temp cleanup command finished. Locked files are normal.
pause
goto issue_software_install

:issue_av_display_camera
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  AUDIO / DISPLAY / CAMERA ISSUES - SOUND / MIC / GPU / BLUETOOTH / USB / PRIVACY / DIRECTX
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Audio No Sound / Crackling Fix             [2] Display / GPU Diagnostic                   [3] Camera / Microphone Permissions            %C_RESET%
echo %C_GREEN%  [4] Bluetooth Service / Pairing Fix            [5] USB Not Recognized Fix                     [6] Device Manager                             %C_RESET%
echo %C_GREEN%  [7] Sound Settings                             [8] Display Settings                           [9] Camera and Microphone Privacy              %C_RESET%
echo %C_GREEN%  [10] DirectX Diagnostic                        [11] Driver Store Diagnostics                  [12] Restart Audio Service Only                %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto issue_av_audio_fix
if "%c%"=="2" goto issue_av_display_gpu
if "%c%"=="3" goto issue_av_camera_mic
if "%c%"=="4" goto issue_av_bluetooth_fix
if "%c%"=="5" goto issue_av_usb_fix
if "%c%"=="6" (start "" devmgmt.msc & pause & goto issue_av_display_camera)
if "%c%"=="7" (start "" ms-settings:sound & start "" mmsys.cpl & pause & goto issue_av_display_camera)
if "%c%"=="8" (start "" ms-settings:display & pause & goto issue_av_display_camera)
if "%c%"=="9" (start "" ms-settings:privacy-webcam & start "" ms-settings:privacy-microphone & pause & goto issue_av_display_camera)
if "%c%"=="10" (dxdiag & goto issue_av_display_camera)
if "%c%"=="11" goto issue_av_driver_store_diag
if "%c%"=="12" (net stop audiosrv >nul 2>&1 & net stop AudioEndpointBuilder >nul 2>&1 & net start AudioEndpointBuilder >nul 2>&1 & net start audiosrv >nul 2>&1 & echo Audio services restarted. & pause & goto issue_av_display_camera)
if "%c%"=="99" goto go_back
goto issue_av_display_camera

:issue_av_audio_fix
cls
echo Audio fix: services, sound settings, classic sound panel.
net stop audiosrv >nul 2>&1
net stop AudioEndpointBuilder >nul 2>&1
net start AudioEndpointBuilder >nul 2>&1
net start audiosrv >nul 2>&1
start "" ms-settings:sound
start "" mmsys.cpl
echo Check output device, microphone permissions, enhancements, and driver rollback.
pause
goto issue_av_display_camera

:issue_av_display_gpu
cls
echo Display/GPU helper.
dxdiag
start "" ms-settings:display
start "" devmgmt.msc
echo Tip: Press Win+Ctrl+Shift+B manually to reset display driver.
pause
goto issue_av_display_camera

:issue_av_camera_mic
cls
start "" ms-settings:privacy-webcam
start "" ms-settings:privacy-microphone
start "" mmsys.cpl
echo Check app permissions and correct input device.
pause
goto issue_av_display_camera

:issue_av_bluetooth_fix
cls
echo Restarting Bluetooth service and opening Bluetooth settings.
sc config bthserv start= demand
net stop bthserv >nul 2>&1
net start bthserv
pnputil /scan-devices
start "" ms-settings:bluetooth
pause
goto issue_av_display_camera

:issue_av_usb_fix
cls
echo USB fix: scan devices, open Device Manager and power settings.
pnputil /scan-devices
powercfg /devicequery wake_armed
start "" devmgmt.msc
start "" powercfg.cpl
pause
goto issue_av_display_camera

:issue_av_driver_store_diag
cls
pnputil /enum-drivers
pnputil /enum-devices /problem
echo Use Driver Manager menu for backup/restore. Avoid deleting unknown OEM drivers.
pause
goto issue_av_display_camera

:issue_reports_evidence
cls
color 0F
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  REPORTS / EVIDENCE COLLECTORS - SYSTEM / NETWORK / DRIVER / BOOT / BATTERY / EVENTS / LOGS
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Quick Health Report                        [2] Full System Report                         [3] Complete Issue Evidence Pack               %C_RESET%
echo %C_GREEN%  [4] Network Evidence Report                    [5] Driver Evidence Report                     [6] Boot Performance Events                    %C_RESET%
echo %C_GREEN%  [7] Battery Report                             [8] Reliability Monitor                        [9] Event Viewer                               %C_RESET%
echo %C_GREEN%  [10] Open Toolkit Log Folder                   [11] Export MSInfo NFO                         [12] Open Windows Logs Folder                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto quick_health_report
if "%c%"=="2" goto sysreport
if "%c%"=="3" goto issue_reports_full_pack
if "%c%"=="4" goto issue_reports_network
if "%c%"=="5" goto issue_reports_driver
if "%c%"=="6" goto issue_reports_boot_perf
if "%c%"=="7" goto issue_reports_battery
if "%c%"=="8" (start "" perfmon /rel & pause & goto issue_reports_evidence)
if "%c%"=="9" (eventvwr.msc & pause & goto issue_reports_evidence)
if "%c%"=="10" (explorer "%LOGROOT%" & goto issue_reports_evidence)
if "%c%"=="11" goto issue_reports_msinfo
if "%c%"=="12" (explorer "C:\Windows\Logs" & goto issue_reports_evidence)
if "%c%"=="99" goto go_back
goto issue_reports_evidence

:issue_reports_full_pack
cls
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "report=%LOGROOT%\All_In_One_Evidence_%stamp%.txt"
(
echo === ALL-IN-ONE EVIDENCE PACK ===
echo Computer: %COMPUTERNAME%
echo User: %USERNAME%
echo Date: %DATE% %TIME%
echo.
echo === SYSTEMINFO ===
systeminfo
echo.
echo === IP CONFIG ===
ipconfig /all
echo.
echo === DISK HEALTH ===
call :ps_disk_drives
echo.
echo === PROBLEM DEVICES ===
pnputil /enum-devices /problem
echo.
echo === SERVICES AUTO STOPPED ===
sc query state= all
echo.
echo === RECENT SYSTEM ERRORS ===
wevtutil qe System /q:"*[System[(Level=1 or Level=2)]]" /f:text /c:40
) > "%report%" 2>&1
echo Evidence pack saved:
echo %report%
start "" notepad "%report%"
pause
goto issue_reports_evidence

:issue_reports_network
cls
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "report=%LOGROOT%\Network_Evidence_%stamp%.txt"
(
echo === NETWORK EVIDENCE REPORT ===
ipconfig /all
echo.
netsh wlan show interfaces
echo.
netsh winhttp show proxy
echo.
route print
echo.
netstat -ano
echo.
nslookup google.com
) > "%report%" 2>&1
echo Network report saved:
echo %report%
start "" notepad "%report%"
pause
goto issue_reports_evidence

:issue_reports_driver
cls
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "report=%LOGROOT%\Driver_Evidence_%stamp%.txt"
(
echo === DRIVER EVIDENCE REPORT ===
driverquery /v
echo.
pnputil /enum-devices /problem
echo.
pnputil /enum-drivers
) > "%report%" 2>&1
echo Driver report saved:
echo %report%
start "" notepad "%report%"
pause
goto issue_reports_evidence

:issue_reports_boot_perf
cls
wevtutil qe Microsoft-Windows-Diagnostics-Performance/Operational /q:"*[System[(EventID=100 or EventID=101 or EventID=102 or EventID=103)]]" /f:text /c:40
pause
goto issue_reports_evidence

:issue_reports_battery
cls
set "battery=%USERPROFILE%\Desktop\battery-report.html"
powercfg /batteryreport /output "%battery%"
echo Battery report saved:
echo %battery%
start "" "%battery%"
pause
goto issue_reports_evidence

:issue_reports_msinfo
cls
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "nfo=%LOGROOT%\MSInfo_%stamp%.nfo"
msinfo32 /nfo "%nfo%"
echo MSInfo export started/saved:
echo %nfo%
pause
goto issue_reports_evidence

:issue_windows_core
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  WINDOWS CORE ISSUES - UPDATE / SETTINGS / START / SEARCH / STORE / TIME / INSTALLER / RECOVERY
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Open Get Help / Troubleshooter Hub         [2] Windows Update Modern Settings             [3] Windows Update Deep Reset                  %C_RESET%
echo %C_GREEN%  [4] Component Store Repair (DISM + SFC)        [5] Start Menu / Shell Repair                  [6] Windows Search / Index Rebuild             %C_RESET%
echo %C_GREEN%  [7] Microsoft Store / App Installer Repair     [8] Windows Installer Service Fix              [9] Date / Time / Time Sync Fix                %C_RESET%
echo %C_GREEN%  [10] File Association / Default Apps Fix       [11] Windows Settings App / Apps Settings      [12] Recovery Options / Reset PC               %C_RESET%
echo %C_GREEN%  [13] Font Cache Reset                          [14] Clipboard / Snipping / Screenshot Fix     [15] Open Reliability Monitor                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" ms-settings:troubleshoot & pause & goto issue_windows_core)
if "%c%"=="2" (start "" ms-settings:windowsupdate & pause & goto issue_windows_core)
if "%c%"=="3" goto issue_win_update_deep
if "%c%"=="4" goto issue_component_repair
if "%c%"=="5" goto issue_shell_repair
if "%c%"=="6" goto issue_search_rebuild
if "%c%"=="7" goto issue_store_repair
if "%c%"=="8" goto issue_installer_fix
if "%c%"=="9" goto issue_time_sync
if "%c%"=="10" (start "" ms-settings:defaultapps & pause & goto issue_windows_core)
if "%c%"=="11" (start "" ms-settings:appsfeatures & pause & goto issue_windows_core)
if "%c%"=="12" (start "" ms-settings:recovery & pause & goto issue_windows_core)
if "%c%"=="13" goto issue_font_cache
if "%c%"=="14" goto issue_clipboard_fix
if "%c%"=="15" (start "" perfmon /rel & pause & goto issue_windows_core)
if "%c%"=="99" goto go_back
goto issue_windows_core

:issue_win_update_deep
cls
echo Windows Update Deep Reset stops update services and renames update cache folders.
set "ok=" & set /p ok=Run Windows Update Deep Reset? (Y/N):
if /i not "%ok%"=="Y" goto issue_windows_core
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net stop cryptSvc >nul 2>&1
net stop msiserver >nul 2>&1
sc config wuauserv start= demand >nul 2>&1
sc config bits start= delayed-auto >nul 2>&1
ren C:\Windows\SoftwareDistribution SoftwareDistribution.old_%RANDOM% >nul 2>&1
ren C:\Windows\System32\catroot2 catroot2.old_%RANDOM% >nul 2>&1
net start msiserver >nul 2>&1
net start cryptSvc >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
UsoClient StartScan >nul 2>&1
echo Windows Update reset done. Restart recommended.
pause
goto issue_windows_core

:issue_component_repair
cls
echo Running DISM ScanHealth, RestoreHealth, then SFC ScanNow.
DISM /Online /Cleanup-Image /ScanHealth
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow
echo Component repair finished.
pause
goto issue_windows_core

:issue_shell_repair
cls
echo Restarting Explorer and repairing shell packages.
taskkill /f /im explorer.exe >nul 2>&1
powershell -NoProfile -Command "Get-AppxPackage Microsoft.Windows.ShellExperienceHost | Reset-AppxPackage" >nul 2>&1
powershell -NoProfile -Command "Get-AppxPackage Microsoft.Windows.StartMenuExperienceHost | Reset-AppxPackage" >nul 2>&1
start explorer.exe
echo Shell repair finished.
pause
goto issue_windows_core

:issue_search_rebuild
cls
echo Restarting Windows Search and opening Indexing Options.
net stop WSearch >nul 2>&1
net start WSearch >nul 2>&1
control /name Microsoft.IndexingOptions
echo Use Advanced - Rebuild if search index is still broken.
pause
goto issue_windows_core

:issue_store_repair
cls
echo Resetting Store cache and repairing Store/App Installer.
wsreset.exe
powershell -NoProfile -Command "Get-AppxPackage Microsoft.WindowsStore | Reset-AppxPackage" >nul 2>&1
powershell -NoProfile -Command "Get-AppxPackage Microsoft.DesktopAppInstaller | Reset-AppxPackage" >nul 2>&1
echo Store/App Installer repair finished.
pause
goto issue_windows_core

:issue_installer_fix
cls
echo Fixing Windows Installer service.
sc config msiserver start= demand
net stop msiserver >nul 2>&1
net start msiserver
msiexec /regserver
echo Windows Installer service refreshed.
pause
goto issue_windows_core

:issue_time_sync
cls
echo Fixing Windows Time service and syncing clock.
sc config w32time start= auto
net stop w32time >nul 2>&1
net start w32time
w32tm /resync /force
start "" ms-settings:dateandtime
echo Time sync command finished.
pause
goto issue_windows_core

:issue_font_cache
cls
echo Rebuilding Windows Font Cache.
net stop FontCache >nul 2>&1
del /f /q "%WinDir%\ServiceProfiles\LocalService\AppData\Local\FontCache\*" >nul 2>&1
net start FontCache >nul 2>&1
echo Font cache reset done.
pause
goto issue_windows_core

:issue_clipboard_fix
cls
echo Opening Clipboard, Snipping Tool, and Screenshot settings.
cmd /c echo off ^| clip
start "" ms-settings:clipboard
start "" ms-screenclip:
echo Clipboard cleared. Settings opened.
pause
goto issue_windows_core

:issue_network_pro
cls
color 09
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  NETWORK PRO ISSUES - WIFI / DNS / DHCP / PROXY / VPN / SMB / NAS / FIREWALL / TCP
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Network Troubleshooter / Status            [2] WiFi Missing / WLAN Service Fix            [3] Connected but No Internet / APIPA Fix      %C_RESET%
echo %C_GREEN%  [4] DNS Full Repair                            [5] Proxy / VPN Stuck Fix                      [6] TCP/IP Advanced Reset                      %C_RESET%
echo %C_GREEN%  [7] Network Adapter Full Rebuild               [8] SMB / NAS Diagnostics                      [9] Forget WiFi Profile                        %C_RESET%
echo %C_GREEN%  [10] WiFi Signal / Profile Report              [11] Firewall Blocking Internet Check          [12] TLS / Certificate / Time Internet Fix     %C_RESET%
echo %C_GREEN%  [13] Network Share Credential Reset            [14] Port / Connection Diagnostics             [15] Open Network Advanced Settings            %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" ms-settings:network-status & start "" ms-settings:troubleshoot & pause & goto issue_network_pro)
if "%c%"=="2" goto issue_wifi_missing
if "%c%"=="3" goto issue_apipa_fix
if "%c%"=="4" goto issue_dns_full
if "%c%"=="5" goto issue_proxy_vpn
if "%c%"=="6" goto issue_tcp_advanced
if "%c%"=="7" goto issue_adapter_rebuild
if "%c%"=="8" goto issue_smb_nas
if "%c%"=="9" goto issue_forget_wifi
if "%c%"=="10" goto issue_wifi_report
if "%c%"=="11" goto issue_firewall_net_check
if "%c%"=="12" goto issue_tls_fix
if "%c%"=="13" goto issue_net_cred_reset
if "%c%"=="14" goto issue_port_diag
if "%c%"=="15" (start "" ms-settings:network-advancedsettings & pause & goto issue_network_pro)
if "%c%"=="99" goto go_back
goto issue_network_pro

:issue_wifi_missing
cls
echo Restarting WLAN AutoConfig and scanning devices.
sc config WlanSvc start= auto
net stop WlanSvc >nul 2>&1
net start WlanSvc
pnputil /scan-devices
start "" ms-settings:network-wifi
echo If WiFi is still missing, check Device Manager - Network adapters.
pause
goto issue_network_pro

:issue_apipa_fix
cls
echo Fixing DHCP/APIPA 169.254.x.x issue.
sc config Dhcp start= auto
net start Dhcp >nul 2>&1
ipconfig /release
ipconfig /flushdns
ipconfig /renew
ipconfig /all ^| findstr /i "IPv4 DHCP Gateway DNS"
pause
goto issue_network_pro

:issue_dns_full
cls
echo DNS full repair.
ipconfig /flushdns
ipconfig /registerdns
netsh interface ip set dns name="Wi-Fi" dhcp >nul 2>&1
netsh interface ip set dns name="Ethernet" dhcp >nul 2>&1
nslookup microsoft.com
pause
goto issue_network_pro

:issue_proxy_vpn
cls
echo Resetting WinHTTP proxy and opening Proxy/VPN settings.
netsh winhttp show proxy
netsh winhttp reset proxy
rasdial /disconnect >nul 2>&1
start "" ms-settings:network-proxy
start "" ms-settings:network-vpn
pause
goto issue_network_pro

:issue_tcp_advanced
cls
echo Showing TCP global state, then resetting TCP/IP to normal defaults.
netsh int tcp show global
netsh int tcp set global autotuninglevel=normal
netsh int tcp set global rss=enabled
netsh int ip reset
netsh winsock reset
echo Restart recommended.
pause
goto issue_network_pro

:issue_adapter_rebuild
cls
echo Network Adapter Full Rebuild can remove/reinstall network adapters and needs restart.
set "ok=" & set /p ok=Run netcfg -d full adapter rebuild? (Y/N):
if /i not "%ok%"=="Y" goto issue_network_pro
netcfg -d
echo Done. Restart required.
pause
goto issue_network_pro

:issue_smb_nas
cls
echo SMB / NAS diagnostics.
sc query LanmanWorkstation
sc query LanmanServer
net use
net view
cmdkey /list
echo If NAS login is wrong, use option 13 to clear network credentials.
pause
goto issue_network_pro

:issue_forget_wifi
cls
netsh wlan show profiles
set "wifi=" & set /p wifi=Enter WiFi profile name to forget:
if "%wifi%"=="" goto issue_network_pro
netsh wlan delete profile name="%wifi%"
pause
goto issue_network_pro

:issue_wifi_report
cls
echo Generating WLAN report.
netsh wlan show interfaces
netsh wlan show drivers
netsh wlan show wlanreport
echo Report usually opens from: %ProgramData%\Microsoft\Windows\WlanReport\wlan-report-latest.html
pause
goto issue_network_pro

:issue_firewall_net_check
cls
netsh advfirewall show allprofiles state
netsh advfirewall firewall show rule name=all ^| findstr /i "Block"
start "" wf.msc
pause
goto issue_network_pro

:issue_tls_fix
cls
echo TLS/Certificate internet issue helper: sync time, clear DNS, open Internet Options.
w32tm /resync /force
ipconfig /flushdns
rundll32.exe shell32.dll,Control_RunDLL inetcpl.cpl,,4
echo Check date/time and certificate errors after this.
pause
goto issue_network_pro

:issue_net_cred_reset
cls
echo Current saved credentials:
cmdkey /list
set "srv=" & set /p srv=Enter server name to clear (example: SERVER or 192.168.1.10), blank to cancel:
if "%srv%"=="" goto issue_network_pro
cmdkey /delete:%srv%
cmdkey /delete:TERMSRV/%srv% >nul 2>&1
net use \\%srv% /delete /y >nul 2>&1
pause
goto issue_network_pro

:issue_port_diag
cls
set "port=" & set /p port=Enter port number to check:
if "%port%"=="" goto issue_network_pro
netstat -ano ^| findstr :%port%
powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort %port% -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,RemoteAddress,State,OwningProcess | Format-Table -AutoSize"
pause
goto issue_network_pro

:issue_printer_pro
goto menu_printer_spooler

:issue_spooler_repair
cls
echo Repairing spooler dependencies and service startup.
sc config spooler start= auto
sc config spooler depend= RPCSS
net stop spooler >nul 2>&1
net start spooler
sc query spooler
pause
goto issue_printer_pro

:issue_hardware_devices
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  HARDWARE AND DEVICE ISSUES - USB / BLUETOOTH / AUDIO / DISPLAY / CAMERA / DRIVERS / WINDOWS HEL
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Device Manager + Problem Devices           [2] USB Not Recognized Fix                     [3] Bluetooth Missing / Pairing Fix            %C_RESET%
echo %C_GREEN%  [4] Audio No Sound / Crackling Fix             [5] Display Flicker / GPU Reset                [6] Camera / Microphone Permission Fix         %C_RESET%
echo %C_GREEN%  [7] Driver Store Diagnostics                   [8] Windows Hello / Biometric Fix              [9] Touchpad / Keyboard / Mouse Settings       %C_RESET%
echo %C_GREEN%  [10] Hardware Full Report                      [11] RAM Diagnostic                            [12] Disk SMART / Health Summary               %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto issue_problem_devices
if "%c%"=="2" goto issue_usb_fix
if "%c%"=="3" goto issue_bluetooth_fix
if "%c%"=="4" goto issue_audio_modern_fix
if "%c%"=="5" goto issue_display_gpu
if "%c%"=="6" goto issue_camera_mic
if "%c%"=="7" goto issue_driver_store_diag
if "%c%"=="8" goto issue_hello_fix
if "%c%"=="9" (start "" ms-settings:devices-touchpad & start "" ms-settings:mousetouchpad & pause & goto issue_hardware_devices)
if "%c%"=="10" (msinfo32 & goto issue_hardware_devices)
if "%c%"=="11" (start "" mdsched.exe & pause & goto issue_hardware_devices)
if "%c%"=="12" goto issue_disk_health
if "%c%"=="99" goto go_back
goto issue_hardware_devices

:issue_problem_devices
cls
pnputil /enum-devices /problem
start "" devmgmt.msc
pause
goto issue_hardware_devices

:issue_usb_fix
cls
echo USB fix: scan devices, open Device Manager and power settings.
pnputil /scan-devices
powercfg /devicequery wake_armed
start "" devmgmt.msc
start "" powercfg.cpl
pause
goto issue_hardware_devices

:issue_bluetooth_fix
cls
echo Restarting Bluetooth service and opening Bluetooth settings.
sc config bthserv start= demand
net stop bthserv >nul 2>&1
net start bthserv
pnputil /scan-devices
start "" ms-settings:bluetooth
echo Also keep USB 3.0 devices away from Bluetooth receiver if disconnecting.
pause
goto issue_hardware_devices

:issue_audio_modern_fix
cls
echo Audio fix: services, sound settings, classic sound panel.
net stop audiosrv >nul 2>&1
net stop AudioEndpointBuilder >nul 2>&1
net start AudioEndpointBuilder >nul 2>&1
net start audiosrv >nul 2>&1
start "" ms-settings:sound
start "" mmsys.cpl
echo Check output device, microphone permissions, enhancements, and driver rollback.
pause
goto issue_hardware_devices

:issue_display_gpu
cls
echo Display/GPU helper.
dxdiag
start "" ms-settings:display
start "" devmgmt.msc
echo Tip: Press Win+Ctrl+Shift+B manually to reset display driver.
pause
goto issue_hardware_devices

:issue_camera_mic
cls
start "" ms-settings:privacy-webcam
start "" ms-settings:privacy-microphone
start "" mmsys.cpl
echo Check app permissions and correct input device.
pause
goto issue_hardware_devices

:issue_driver_store_diag
cls
pnputil /enum-drivers
pnputil /enum-devices /problem
echo Use Driver Manager menu for backup/restore. Avoid deleting unknown OEM drivers.
pause
goto issue_hardware_devices

:issue_hello_fix
cls
echo Restarting biometric service and opening sign-in settings.
sc config WbioSrvc start= demand
net stop WbioSrvc >nul 2>&1
net start WbioSrvc
start "" ms-settings:signinoptions
pause
goto issue_hardware_devices

:issue_disk_health
cls
call :ps_disk_drives
powershell -NoProfile -Command "Get-PhysicalDisk | Select FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize" 2>nul
pause
goto issue_hardware_devices

:issue_user_apps
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  USER / PROFILE / APP ISSUES - TEMP PROFILE / LOGIN / DEFAULT APPS / ONEDRIVE / TEAMS / STORE /
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] User Profile Diagnostics                   [2] Create Local Admin User                    [3] Default Apps / File Association            %C_RESET%
echo %C_GREEN%  [4] OneDrive Sync Reset                        [5] Teams / Zoom Cache Repair                  [6] App Permissions Hub                        %C_RESET%
echo %C_GREEN%  [7] Credential Manager                         [8] Startup Apps Review                        [9] Account / Sign-in Settings                 %C_RESET%
echo %C_GREEN%  [10] Region / Language / Keyboard Fix          [11] App Installer / Winget Health             [12] Installed Apps Inventory                  %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto issue_profile_diag
if "%c%"=="2" goto issue_create_admin
if "%c%"=="3" (start "" ms-settings:defaultapps & pause & goto issue_user_apps)
if "%c%"=="4" goto issue_onedrive_reset
if "%c%"=="5" goto issue_teams_zoom_cache
if "%c%"=="6" (start "" ms-settings:privacy & pause & goto issue_user_apps)
if "%c%"=="7" (control /name Microsoft.CredentialManager & pause & goto issue_user_apps)
if "%c%"=="8" (start "" ms-settings:startupapps & taskmgr & pause & goto issue_user_apps)
if "%c%"=="9" (start "" ms-settings:signinoptions & pause & goto issue_user_apps)
if "%c%"=="10" (start "" ms-settings:regionlanguage & start "" ms-settings:keyboard & pause & goto issue_user_apps)
if "%c%"=="11" (set "WINGET_HEALTH_RETURN=issue_user_apps" & goto issue_winget_health)
if "%c%"=="12" goto issue_apps_inventory
if "%c%"=="99" goto go_back
goto issue_user_apps

:issue_profile_diag
cls
echo Current user:
whoami
echo.
echo Local users:
net user
echo.
echo ProfileList registry:
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
echo.
echo If user is logged into TEMP profile, create backup before editing ProfileList.
pause
goto issue_user_apps

:issue_create_admin
cls
set "newuser=" & set /p newuser=Enter new local admin username:
if "%newuser%"=="" goto issue_user_apps
net user "%newuser%" * /add
net localgroup administrators "%newuser%" /add
echo Local admin user created/updated.
pause
goto issue_user_apps

:issue_onedrive_reset
cls
echo Resetting OneDrive sync client.
powershell -NoProfile -Command "Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force" >nul 2>&1
"%LocalAppData%\Microsoft\OneDrive\OneDrive.exe" /reset
timeout /t 5 /nobreak >nul 2>&1
start "" "%LocalAppData%\Microsoft\OneDrive\OneDrive.exe"
echo OneDrive reset command finished.
pause
goto issue_user_apps

:issue_teams_zoom_cache
cls
taskkill /f /im ms-teams.exe >nul 2>&1
taskkill /f /im Teams.exe >nul 2>&1
taskkill /f /im Zoom.exe >nul 2>&1
del /f /s /q "%AppData%\Microsoft\Teams\Cache\*" >nul 2>&1
del /f /s /q "%AppData%\Microsoft\Teams\GPUCache\*" >nul 2>&1
del /f /s /q "%AppData%\Microsoft\Teams\Service Worker\CacheStorage\*" >nul 2>&1
del /f /s /q "%AppData%\Zoom\data\WebviewCache\*" >nul 2>&1
echo Teams/Zoom cache repair done.
pause
goto issue_user_apps

:issue_winget_health
cls
call :winget_health
pause
if defined WINGET_HEALTH_RETURN (
    set "WINGET_HEALTH_BACK=%WINGET_HEALTH_RETURN%"
    set "WINGET_HEALTH_RETURN="
    set "SAFE_TARGET=!WINGET_HEALTH_BACK!"
    goto safe_goto
)
goto go_back

:issue_apps_inventory
cls
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "apps=%LOGROOT%\Installed_Apps_%stamp%.txt"
(
echo === WINGET APPS ===
call :winget_list_installed
echo.
echo === APPX PACKAGES ===
powershell -NoProfile -Command "Get-AppxPackage | Select Name,Version,PackageFullName | Sort Name | Format-Table -AutoSize"
) > "%apps%"
echo App inventory saved:
echo %apps%
start "" notepad "%apps%"
pause
goto issue_user_apps

:issue_browser_cloud
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  BROWSER / CLOUD / OFFICE ISSUES - CHROME / EDGE / WEBVIEW2 / TLS / CAMERA / TEAMS / OUTLOOK / O
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Browser Cache + DNS Fix                    [2] Edge Repair / Reset Settings               [3] Chrome Camera / Location Settings          %C_RESET%
echo %C_GREEN%  [4] TLS / SSL / Certificate Helper             [5] Default Browser / Protocol Fix             [6] WebView2 / Apps Feature Page               %C_RESET%
echo %C_GREEN%  [7] Outlook Profile / Safe Mode                [8] Office Quick Repair Page                   [9] Teams Camera / Mic Permissions             %C_RESET%
echo %C_GREEN%  [10] OneDrive Reset                            [11] Browser Download Block Check              [12] Clear Windows Web Credentials             %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto issue_browser_cache_dns
if "%c%"=="2" (start "" ms-settings:appsfeatures & start "" microsoft-edge://settings/reset & pause & goto issue_browser_cloud)
if "%c%"=="3" (start "" chrome://settings/content/camera & start "" chrome://settings/content/location & pause & goto issue_browser_cloud)
if "%c%"=="4" goto issue_tls_fix
if "%c%"=="5" (start "" ms-settings:defaultapps & pause & goto issue_browser_cloud)
if "%c%"=="6" (start "" ms-settings:appsfeatures & pause & goto issue_browser_cloud)
if "%c%"=="7" goto issue_outlook_modern
if "%c%"=="8" (start "" appwiz.cpl & pause & goto issue_browser_cloud)
if "%c%"=="9" (start "" ms-settings:privacy-webcam & start "" ms-settings:privacy-microphone & pause & goto issue_browser_cloud)
if "%c%"=="10" goto issue_onedrive_reset
if "%c%"=="11" (start "" ms-settings:privacy-broadfilesystemaccess & start "" microsoft-edge://settings/downloads & pause & goto issue_browser_cloud)
if "%c%"=="12" (control /name Microsoft.CredentialManager & pause & goto issue_browser_cloud)
if "%c%"=="99" goto go_back
goto issue_browser_cloud

:issue_browser_cache_dns
cls
taskkill /f /im chrome.exe >nul 2>&1
taskkill /f /im msedge.exe >nul 2>&1
call :clean_browser_caches
ipconfig /flushdns
echo Browser cache and DNS cleaned. Passwords/bookmarks untouched.
pause
goto issue_browser_cloud

:issue_outlook_modern
cls
echo Opening Outlook in safe mode and Mail profile panel.
call :open_outlook_safe
control mlcfg32.cpl
pause
goto issue_browser_cloud

:issue_security_privacy
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  SECURITY / PRIVACY ISSUES - DEFENDER / FIREWALL / MALWARE / BITLOCKER / CREDENTIALS / PRIVACY
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Windows Security Dashboard                 [2] Defender Quick Scan                        [3] Defender Full Scan                         %C_RESET%
echo %C_GREEN%  [4] Defender Offline Scan (Restarts PC)        [5] Firewall Reset / Enable                    [6] Controlled Folder Access Settings          %C_RESET%
echo %C_GREEN%  [7] Ransomware Protection Settings             [8] BitLocker Recovery / Status                [9] Security App Repair                        %C_RESET%
echo %C_GREEN%  [10] Credential Manager                        [11] Privacy Permissions Hub                   [12] Security Event Audit                      %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" (start "" windowsdefender: & pause & goto issue_security_privacy)
if "%c%"=="2" (powershell -NoProfile -Command "Start-MpScan -ScanType QuickScan" & pause & goto issue_security_privacy)
if "%c%"=="3" (powershell -NoProfile -Command "Start-MpScan -ScanType FullScan" & pause & goto issue_security_privacy)
if "%c%"=="4" goto issue_defender_offline
if "%c%"=="5" goto issue_firewall_reset
if "%c%"=="6" (start "" windowsdefender://RansomwareProtection & pause & goto issue_security_privacy)
if "%c%"=="7" (start "" windowsdefender://RansomwareProtection & pause & goto issue_security_privacy)
if "%c%"=="8" (manage-bde -status & pause & goto issue_security_privacy)
if "%c%"=="9" goto issue_security_app_repair
if "%c%"=="10" (control /name Microsoft.CredentialManager & pause & goto issue_security_privacy)
if "%c%"=="11" (start "" ms-settings:privacy & pause & goto issue_security_privacy)
if "%c%"=="12" goto issue_security_events
if "%c%"=="99" goto go_back
goto issue_security_privacy

:issue_defender_offline
cls
echo Defender Offline Scan will restart the PC.
set "ok=" & set /p ok=Start Defender Offline Scan now? (Y/N):
if /i not "%ok%"=="Y" goto issue_security_privacy
powershell -NoProfile -Command "Start-MpWDOScan"
goto issue_security_privacy

:issue_firewall_reset
cls
echo Resetting and enabling Windows Firewall.
netsh advfirewall reset
netsh advfirewall set allprofiles state on
netsh advfirewall show allprofiles state
pause
goto issue_security_privacy

:issue_security_app_repair
cls
powershell -NoProfile -Command "Get-AppxPackage Microsoft.SecHealthUI -AllUsers | Reset-AppxPackage" >nul 2>&1
start "" windowsdefender:
echo Windows Security app repair command finished.
pause
goto issue_security_privacy

:issue_security_events
cls
powershell -NoProfile -Command "Get-WinEvent -LogName Security -MaxEvents 30 | Select TimeCreated,Id,ProviderName,Message | Format-List"
pause
goto issue_security_privacy

:issue_enterprise_admin
cls
color 05
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  ENTERPRISE ADMIN ISSUES - DOMAIN / GPO / RDP / CERTS / SERVICES / TASKS / SHARES / WSUS
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Domain / Workgroup Info                    [2] GPUpdate + GPResult HTML                   [3] RSOP / Policy Result GUI                   %C_RESET%
echo %C_GREEN%  [4] RDP / NLA / Firewall Fix                   [5] Shared Folders / Sessions                  [6] Certificate Manager                        %C_RESET%
echo %C_GREEN%  [7] Services Failure Diagnostics               [8] Scheduled Task Diagnostics                 [9] WSUS / Windows Update Policy View          %C_RESET%
echo %C_GREEN%  [10] Time Sync / Domain Clock                  [11] Local Users and Groups                    [12] Event Log Critical Export                 %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto issue_domain_info
if "%c%"=="2" goto issue_gp_report
if "%c%"=="3" (rsop.msc & pause & goto issue_enterprise_admin)
if "%c%"=="4" goto issue_rdp_nla
if "%c%"=="5" (fsmgmt.msc & net session & pause & goto issue_enterprise_admin)
if "%c%"=="6" (certmgr.msc & certlm.msc & pause & goto issue_enterprise_admin)
if "%c%"=="7" goto issue_services_diag
if "%c%"=="8" goto issue_tasks_diag
if "%c%"=="9" goto issue_wsus_policy
if "%c%"=="10" goto issue_time_sync
if "%c%"=="11" (lusrmgr.msc & pause & goto issue_enterprise_admin)
if "%c%"=="12" goto issue_event_export
if "%c%"=="99" goto go_back
goto issue_enterprise_admin

:issue_domain_info
cls
systeminfo ^| findstr /i "Domain Host"
whoami /fqdn
nltest /dsgetdc:%USERDNSDOMAIN% 2>nul
pause
goto issue_enterprise_admin

:issue_gp_report
cls
gpupdate /force
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "gpreport=%LOGROOT%\GPResult_%stamp%.html"
gpresult /h "%gpreport%" /f
start "" "%gpreport%"
pause
goto issue_enterprise_admin

:issue_rdp_nla
cls
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
sc config TermService start= demand
net start TermService >nul 2>&1
start "" ms-settings:remotedesktop
pause
goto issue_enterprise_admin

:issue_services_diag
cls
sc query state= all ^| findstr /i "SERVICE_NAME STATE"
powershell -NoProfile -Command "Get-WinEvent -LogName System -MaxEvents 100 | Where-Object {$_.ProviderName -like '*Service Control Manager*'} | Select -First 20 TimeCreated,Id,Message | Format-List"
pause
goto issue_enterprise_admin

:issue_tasks_diag
cls
schtasks /query /fo table /v
powershell -NoProfile -Command "Get-WinEvent -LogName Microsoft-Windows-TaskScheduler/Operational -MaxEvents 30 | Select TimeCreated,Id,Message | Format-List" 2>nul
pause
goto issue_enterprise_admin

:issue_wsus_policy
cls
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /s
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /s
pause
goto issue_enterprise_admin

:issue_event_export
cls
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
wevtutil epl System "%LOGROOT%\System_%stamp%.evtx"
wevtutil epl Application "%LOGROOT%\Application_%stamp%.evtx"
echo Logs exported to %LOGROOT%
pause
goto issue_enterprise_admin

:issue_laptop_power
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  LAPTOP / POWER / MOBILITY ISSUES - BATTERY / SLEEP / WAKE / WIFI POWER / CAMERA / LOCATION / DO
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Battery Report                             [2] Energy Report                              [3] Sleep / Wake Diagnostics                   %C_RESET%
echo %C_GREEN%  [4] Power Requests Blocking Sleep              [5] WiFi Power Saving Settings                 [6] Lid / Sleep Settings                       %C_RESET%
echo %C_GREEN%  [7] Location / GPS Fix                         [8] Camera / Mic Permissions                   [9] Dock / USB-C / Thunderbolt Help            %C_RESET%
echo %C_GREEN%  [10] Ultimate Performance Plan                 %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto issue_battery_report
if "%c%"=="2" goto issue_energy_report
if "%c%"=="3" goto issue_sleep_wake
if "%c%"=="4" (powercfg /requests & pause & goto issue_laptop_power)
if "%c%"=="5" (start "" powercfg.cpl & start "" devmgmt.msc & pause & goto issue_laptop_power)
if "%c%"=="6" (start "" ms-settings:powersleep & pause & goto issue_laptop_power)
if "%c%"=="7" goto smart_location
if "%c%"=="8" goto issue_camera_mic
if "%c%"=="9" goto issue_dock_usb
if "%c%"=="10" (powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 & pause & goto issue_laptop_power)
if "%c%"=="99" goto go_back
goto issue_laptop_power

:issue_battery_report
cls
powercfg /batteryreport /output "%LOGROOT%\BatteryReport.html"
start "" "%LOGROOT%\BatteryReport.html"
pause
goto issue_laptop_power

:issue_energy_report
cls
echo Generating energy report for 60 seconds.
powercfg /energy /output "%LOGROOT%\EnergyReport.html"
start "" "%LOGROOT%\EnergyReport.html"
pause
goto issue_laptop_power

:issue_sleep_wake
cls
powercfg /lastwake
powercfg /waketimers
powercfg /devicequery wake_armed
pause
goto issue_laptop_power

:issue_dock_usb
cls
echo Dock/USB-C helper: scan devices, open Device Manager and Display settings.
pnputil /scan-devices
start "" devmgmt.msc
start "" ms-settings:display
echo Check OEM dock firmware and USB-C power/data cable if issue remains.
pause
goto issue_laptop_power

:issue_deep_diagnostics
cls
color 0F
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  DEEP DIAGNOSTICS PACK - READ-ONLY REPORTS FIRST
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [1] Create Complete Issue Report               [2] Export Event Logs                          [3] Network Deep Report                        %C_RESET%
echo %C_GREEN%  [4] Driver and Problem Device Report           [5] Update / Servicing Logs Shortcut           [6] Performance Boot Diagnostics               %C_RESET%
echo.
echo %C_YELLOW%  [P] Problem Hub / Guided Fixes              [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if /i "%c%"=="P" goto problem_master_hub
if "%c%"=="1" goto issue_complete_report
if "%c%"=="2" goto issue_event_export
if "%c%"=="3" goto issue_network_report
if "%c%"=="4" goto issue_driver_report
if "%c%"=="5" (explorer "C:\Windows\Logs" & goto issue_deep_diagnostics)
if "%c%"=="6" goto issue_boot_perf
if "%c%"=="99" goto go_back
goto issue_deep_diagnostics

:issue_complete_report
cls
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "ireport=%LOGROOT%\Complete_Issue_Report_%stamp%.txt"
(
echo ================================================================
echo ULTIMATE X PRO MAX %TOOLKIT_VERSION% - COMPLETE ISSUE REPORT
echo Generated: %DATE% %TIME%
echo ================================================================
echo.
echo === SYSTEMINFO ===
systeminfo
echo.
echo === DISK ===
call :ps_logical_disks
call :ps_disk_drives
echo.
echo === NETWORK ===
ipconfig /all
netsh wlan show interfaces
netsh int tcp show global
echo.
echo === PRINTERS ===
call :ps_printers
sc query spooler
echo.
echo === PROBLEM DEVICES ===
pnputil /enum-devices /problem
echo.
echo === FIREWALL ===
netsh advfirewall show allprofiles state
echo.
echo === UPDATE POLICIES ===
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /s
echo.
echo === RECENT SYSTEM ERRORS ===
powershell -NoProfile -Command "Get-WinEvent -LogName System -MaxEvents 60 | Where-Object {$_.Level -le 2} | Select TimeCreated,Id,ProviderName,Message | Format-List"
) > "%ireport%"
echo Complete issue report saved:
echo %ireport%
start "" notepad "%ireport%"
pause
goto issue_deep_diagnostics

:issue_network_report
cls
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "nreport=%LOGROOT%\Network_Report_%stamp%.txt"
(
echo === IPCONFIG ===
ipconfig /all
echo.
echo === NETSH INTERFACES ===
netsh interface show interface
echo.
echo === WLAN ===
netsh wlan show interfaces
netsh wlan show drivers
echo.
echo === TCP GLOBAL ===
netsh int tcp show global
echo.
echo === ROUTE ===
route print
echo.
echo === DNS TEST ===
nslookup microsoft.com
) > "%nreport%"
echo Network report saved:
echo %nreport%
start "" notepad "%nreport%"
pause
goto issue_deep_diagnostics

:issue_driver_report
cls
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "dreport=%LOGROOT%\Driver_Report_%stamp%.txt"
(
echo === DRIVERQUERY ===
driverquery /v
echo.
echo === PNPUTIL DRIVERS ===
pnputil /enum-drivers
echo.
echo === PROBLEM DEVICES ===
pnputil /enum-devices /problem
) > "%dreport%"
echo Driver report saved:
echo %dreport%
start "" notepad "%dreport%"
pause
goto issue_deep_diagnostics

:issue_boot_perf
cls
powershell -NoProfile -Command "Get-WinEvent -ProviderName Microsoft-Windows-Diagnostics-Performance -MaxEvents 30 | Select TimeCreated,Id,Message | Format-List"
pause
goto issue_deep_diagnostics

:: ============================================================
:: [10] SYSTEM REPORT GENERATOR
:: ============================================================
:sysreport
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo                               [10] SYSTEM REPORT GENERATOR
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo  Generating Full System Report... Please wait...
echo.

set "report=%USERPROFILE%\Desktop\IT_System_Report_%date:~-4,4%%date:~-7,2%%date:~0,2%_%time:~0,2%%time:~3,2%.txt"
set report=%report: =0%

(
echo ================================================================
echo  ULTIMATE X PRO MAX %TOOLKIT_VERSION% - SYSTEM REPORT
echo  By Ultimate Toolkit
echo  Generated: %date% %time%
echo ================================================================
echo.
echo === SYSTEM INFO ===
systeminfo
echo.
echo === NETWORK INFO ===
ipconfig /all
echo.
echo === DISK INFO ===
call :ps_logical_disks
echo.
echo === RUNNING PROCESSES ===
tasklist
echo.
echo === RUNNING SERVICES ===
sc query type= service state= running
echo.
echo === STARTUP PROGRAMS ===
reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
echo.
echo === FIREWALL STATUS ===
netsh advfirewall show allprofiles state
echo.
echo === DEFENDER STATUS ===
powershell -command "Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled,AntispywareEnabled"
echo.
echo === WINDOWS LICENSE ===
slmgr /xpr
echo.
echo ================================================================
echo  REPORT END
echo ================================================================
) > "%report%"

echo Report saved to: %report%
echo Opening report...
start "" notepad "%report%"
pause
goto go_back

:: ============================================================
:: CLEANUP HELPERS
:: ============================================================
:clean_folder_contents
set "CLEAN_TARGET=%~1"
set "CLEAN_NAME=%~2"
if not defined CLEAN_NAME set "CLEAN_NAME=%CLEAN_TARGET%"
echo Cleaning %CLEAN_NAME%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:CLEAN_TARGET; if([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path -LiteralPath $p)){ Write-Host ('Skipped (not found): ' + $p); exit 0 }; Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Write-Host ('Cleaned: ' + $p)"
exit /b

:clean_browser_caches
call :clean_folder_contents "%LocalAppData%\Google\Chrome\User Data\Default\Cache" "Chrome Cache"
call :clean_folder_contents "%LocalAppData%\Google\Chrome\User Data\Default\Code Cache" "Chrome Code Cache"
call :clean_folder_contents "%LocalAppData%\Google\Chrome\User Data\Default\GPUCache" "Chrome GPU Cache"
call :clean_folder_contents "%LocalAppData%\Microsoft\Edge\User Data\Default\Cache" "Edge Cache"
call :clean_folder_contents "%LocalAppData%\Microsoft\Edge\User Data\Default\Code Cache" "Edge Code Cache"
call :clean_folder_contents "%LocalAppData%\Microsoft\Edge\User Data\Default\GPUCache" "Edge GPU Cache"
echo Browser caches cleaned. Close browsers first for best results.
exit /b

:clean_thumbnail_cache
echo Cleaning thumbnail cache...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'; Get-ChildItem -LiteralPath $p -Force -Filter 'thumbcache_*.db' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue; Write-Host 'Thumbnail cache cleaned.'"
exit /b

:clean_icon_cache
echo Cleaning icon cache...
taskkill /f /im explorer.exe >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$paths=@((Join-Path $env:LOCALAPPDATA 'IconCache.db'),(Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer\iconcache_*.db')); foreach($p in $paths){ Remove-Item -Path $p -Force -ErrorAction SilentlyContinue }; Write-Host 'Icon cache cleaned.'"
start explorer.exe
exit /b

:clean_crash_dumps
call :clean_folder_contents "C:\Windows\Minidump" "Minidump"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Remove-Item -LiteralPath 'C:\Windows\memory.dmp' -Force -ErrorAction SilentlyContinue; Write-Host 'Memory dump cleaned if present.'"
exit /b

:one_clean
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% ONE CLEAN - TEMP / %%TEMP%% / PREFETCH / CACHE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
call :one_clean_core
echo.
echo ONE CLEAN DONE!
pause
goto go_back

:one_clean_core
call :clean_folder_contents "%TEMP%" "User Temp"
call :clean_folder_contents "C:\Windows\Temp" "Windows Temp"
call :clean_folder_contents "C:\Windows\Prefetch" "Prefetch"
call :clean_folder_contents "C:\Windows\SoftwareDistribution\DeliveryOptimization" "Delivery Optimization"
call :clean_folder_contents "C:\ProgramData\Microsoft\Windows\WER" "Windows Error Reports"
call :clean_browser_caches
call :clean_thumbnail_cache
call :clean_crash_dumps
ipconfig /flushdns >nul 2>&1
exit /b

:: ============================================================
:: EXIT
:: ============================================================

:: ---- MISSING ONLY 20000+ COMMAND MEGA VAULT LAUNCHER ----
:missing_mega_vault_launcher
set "MISSING_VAULT=%~dp0CMD IT Toolkit Missing Mega Vault By Ultimate Toolkit.cmd"
if exist "%MISSING_VAULT%" (
    call "%MISSING_VAULT%"
) else (
    echo Missing add-on file not found:
    echo "%MISSING_VAULT%"
    echo Keep the add-on CMD and TSV file beside this toolkit.
    pause
)
goto main
:exitprog
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo                         Thank you for using ULTIMATE X PRO MAX %TOOLKIT_VERSION%
echo                                   By Ultimate Toolkit
echo.
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
timeout /t 3 /nobreak >nul 2>&1
exit /b




:menu_1click_100_apps
set "BACK_MENU=main"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% [37] 100 APPS 1-CLICK INSTALL ^& SOFTWARE CATALOG%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Web Browsers                        [02] Communication                       %C_RESET%
echo %C_GREEN%  [03] Media & Audio                       [04] Utilities & Tools                   %C_RESET%
echo %C_GREEN%  [05] Maintenance & Hardware              [06] Productivity & Office               %C_RESET%
echo %C_GREEN%  [07] Development & IT                    [08] Cloud & Remote                      %C_RESET%
echo %C_GREEN%  [09] Security, VPN & Runtimes            [10] AI Tools                            %C_RESET%
echo %C_GREEN%  [11] Install ALL 100 Apps (Bulk)%C_RESET%
echo.
echo %C_YELLOW%                                               [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto menu_apps_browsers
if "%c%"=="1" goto menu_apps_browsers
if "%c%"=="02" goto menu_apps_communication
if "%c%"=="2" goto menu_apps_communication
if "%c%"=="03" goto menu_apps_media
if "%c%"=="3" goto menu_apps_media
if "%c%"=="04" goto menu_apps_utilities
if "%c%"=="4" goto menu_apps_utilities
if "%c%"=="05" goto menu_apps_maintenance
if "%c%"=="5" goto menu_apps_maintenance
if "%c%"=="06" goto menu_apps_productivity
if "%c%"=="6" goto menu_apps_productivity
if "%c%"=="07" goto menu_apps_dev
if "%c%"=="7" goto menu_apps_dev
if "%c%"=="08" goto menu_apps_cloud
if "%c%"=="8" goto menu_apps_cloud
if "%c%"=="09" goto menu_apps_security
if "%c%"=="9" goto menu_apps_security
if "%c%"=="10" goto menu_apps_ai
if "%c%"=="10" goto menu_apps_ai
if "%c%"=="11" goto menu_apps_bulk_install
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_1click_100_apps

:menu_apps_online_search
set "BACK_MENU=menu_1click_100_apps"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% ONLINE WINGET SOFTWARE SEARCH%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo  Type a keyword to search the official Microsoft Winget repository.
echo.
set "sq=" & set /p sq=Enter Search Query (or 99 to go back): 
if "%sq%"=="99" goto menu_1click_100_apps
if "%sq%"=="" goto menu_apps_online_search
cls
echo Searching for "%sq%" on Winget...
winget search "%sq%" --accept-source-agreements
echo.
set "sid=" & set /p sid=Enter exact App ID to install (or press Enter to search again): 
if "%sid%"=="" goto menu_apps_online_search
echo Installing %sid%...
winget install --id "%sid%" -e --accept-source-agreements --accept-package-agreements
pause
goto menu_apps_online_search


:menu_apps_browsers
set "BACK_MENU=menu_1click_100_apps"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% SOFTWARE CATALOG - WEB BROWSERS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Google Chrome                       [02] Mozilla Firefox                     %C_RESET%
echo %C_GREEN%  [03] Brave                               [04] Microsoft Edge                      %C_RESET%
echo %C_GREEN%  [05] Opera                               [06] Vivaldi                             %C_RESET%
echo %C_GREEN%  [07] Tor Browser                         [08] Waterfox                            %C_RESET%
echo.
echo %C_YELLOW%  [09] Install All in this Category         [99] Back to Categories%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT APP TO INSTALL / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" (winget install --id "Google.Chrome" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="1" (winget install --id "Google.Chrome" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="02" (winget install --id "Mozilla.Firefox" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="2" (winget install --id "Mozilla.Firefox" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="03" (winget install --id "Brave.Brave" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="3" (winget install --id "Brave.Brave" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="04" (winget install --id "Microsoft.Edge" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="4" (winget install --id "Microsoft.Edge" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="05" (winget install --id "Opera.Opera" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="5" (winget install --id "Opera.Opera" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="06" (winget install --id "Vivaldi.Vivaldi" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="6" (winget install --id "Vivaldi.Vivaldi" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="07" (winget install --id "TorProject.TorBrowser" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="7" (winget install --id "TorProject.TorBrowser" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="08" (winget install --id "Waterfox.Waterfox" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="8" (winget install --id "Waterfox.Waterfox" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="09" (winget install --id "Google.Chrome" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Mozilla.Firefox" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Brave.Brave" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.Edge" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Opera.Opera" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Vivaldi.Vivaldi" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "TorProject.TorBrowser" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Waterfox.Waterfox" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="9" (winget install --id "Google.Chrome" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Mozilla.Firefox" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Brave.Brave" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.Edge" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Opera.Opera" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Vivaldi.Vivaldi" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "TorProject.TorBrowser" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Waterfox.Waterfox" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_browsers)
if "%c%"=="99" goto menu_1click_100_apps
if "%c%"=="00" goto menu_1click_100_apps
goto menu_apps_browsers

:menu_apps_communication
set "BACK_MENU=menu_1click_100_apps"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% SOFTWARE CATALOG - COMMUNICATION%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Discord                             [02] Slack                               %C_RESET%
echo %C_GREEN%  [03] Telegram                            [04] WhatsApp                            %C_RESET%
echo %C_GREEN%  [05] Zoom                                [06] Microsoft Teams                     %C_RESET%
echo %C_GREEN%  [07] Rambox                              [08] Viber                               %C_RESET%
echo %C_GREEN%  [09] Element                             [10] Signal                              %C_RESET%
echo.
echo %C_YELLOW%  [11] Install All in this Category         [99] Back to Categories%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT APP TO INSTALL / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" (winget install --id "Discord.Discord" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="1" (winget install --id "Discord.Discord" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="02" (winget install --id "SlackTechnologies.Slack" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="2" (winget install --id "SlackTechnologies.Slack" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="03" (winget install --id "Telegram.TelegramDesktop" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="3" (winget install --id "Telegram.TelegramDesktop" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="04" (winget install --id "9NKSQGP7F2NH" --source msstore -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="4" (winget install --id "9NKSQGP7F2NH" --source msstore -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="05" (winget install --id "Zoom.Zoom" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="5" (winget install --id "Zoom.Zoom" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="06" (winget install --id "Microsoft.Teams" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="6" (winget install --id "Microsoft.Teams" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="07" (winget install --id "Rambox.Rambox.Community" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="7" (winget install --id "Rambox.Rambox.Community" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="08" (winget install --id "Rakuten.Viber" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="8" (winget install --id "Rakuten.Viber" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="09" (winget install --id "Element.Element" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="9" (winget install --id "Element.Element" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="10" (winget install --id "OpenWhisperSystems.Signal" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="10" (winget install --id "OpenWhisperSystems.Signal" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="11" (winget install --id "Discord.Discord" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "SlackTechnologies.Slack" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Telegram.TelegramDesktop" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "9NKSQGP7F2NH" --source msstore -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Zoom.Zoom" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.Teams" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Rambox.Rambox.Community" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Rakuten.Viber" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Element.Element" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "OpenWhisperSystems.Signal" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="11" (winget install --id "Discord.Discord" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "SlackTechnologies.Slack" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Telegram.TelegramDesktop" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "9NKSQGP7F2NH" --source msstore -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Zoom.Zoom" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.Teams" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Rambox.Rambox.Community" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Rakuten.Viber" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Element.Element" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "OpenWhisperSystems.Signal" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_communication)
if "%c%"=="99" goto menu_1click_100_apps
if "%c%"=="00" goto menu_1click_100_apps
goto menu_apps_communication

:menu_apps_media
set "BACK_MENU=menu_1click_100_apps"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% SOFTWARE CATALOG - MEDIA & AUDIO%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] VLC Media Player                    [02] OBS Studio                          %C_RESET%
echo %C_GREEN%  [03] Spotify                             [04] iTunes                              %C_RESET%
echo %C_GREEN%  [05] AIMP                                [06] Audacity                            %C_RESET%
echo %C_GREEN%  [07] GIMP                                [08] K-Lite Codec Pack Full              %C_RESET%
echo %C_GREEN%  [09] HandBrake                           [10] MPC-HC                              %C_RESET%
echo %C_GREEN%  [11] Kdenlive                            [12] Amazon Music                        %C_RESET%
echo.
echo %C_YELLOW%  [13] Install All in this Category         [99] Back to Categories%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT APP TO INSTALL / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" (winget install --id "VideoLAN.VLC" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="1" (winget install --id "VideoLAN.VLC" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="02" (winget install --id "OBSProject.OBSStudio" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="2" (winget install --id "OBSProject.OBSStudio" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="03" (winget install --id "Spotify.Spotify" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="3" (winget install --id "Spotify.Spotify" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="04" (winget install --id "Apple.iTunes" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="4" (winget install --id "Apple.iTunes" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="05" (winget install --id "AIMP.AIMP" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="5" (winget install --id "AIMP.AIMP" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="06" (winget install --id "Audacity.Audacity" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="6" (winget install --id "Audacity.Audacity" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="07" (winget install --id "GIMP.GIMP" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="7" (winget install --id "GIMP.GIMP" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="08" (winget install --id "CodecGuide.K-LiteCodecPack.Full" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="8" (winget install --id "CodecGuide.K-LiteCodecPack.Full" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="09" (winget install --id "HandBrake.HandBrake" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="9" (winget install --id "HandBrake.HandBrake" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="10" (winget install --id "clsid2.mpc-hc" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="10" (winget install --id "clsid2.mpc-hc" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="11" (winget install --id "KDE.Kdenlive" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="11" (winget install --id "KDE.Kdenlive" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="12" (winget install --id "Amazon.Music" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="12" (winget install --id "Amazon.Music" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="13" (winget install --id "VideoLAN.VLC" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "OBSProject.OBSStudio" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Spotify.Spotify" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Apple.iTunes" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "AIMP.AIMP" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Audacity.Audacity" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "GIMP.GIMP" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "CodecGuide.K-LiteCodecPack.Full" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "HandBrake.HandBrake" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "clsid2.mpc-hc" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "KDE.Kdenlive" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Amazon.Music" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="13" (winget install --id "VideoLAN.VLC" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "OBSProject.OBSStudio" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Spotify.Spotify" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Apple.iTunes" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "AIMP.AIMP" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Audacity.Audacity" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "GIMP.GIMP" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "CodecGuide.K-LiteCodecPack.Full" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "HandBrake.HandBrake" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "clsid2.mpc-hc" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "KDE.Kdenlive" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Amazon.Music" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_media)
if "%c%"=="99" goto menu_1click_100_apps
if "%c%"=="00" goto menu_1click_100_apps
goto menu_apps_media

:menu_apps_utilities
set "BACK_MENU=menu_1click_100_apps"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% SOFTWARE CATALOG - UTILITIES & TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] 7-Zip                               [02] WinRAR                              %C_RESET%
echo %C_GREEN%  [03] Notepad++                           [04] PowerToys                           %C_RESET%
echo %C_GREEN%  [05] Everything                          [06] Sysinternals Suite                  %C_RESET%
echo %C_GREEN%  [07] Flow-Launcher                                                                %C_RESET%
echo.
echo %C_YELLOW%  [08] Install All in this Category         [99] Back to Categories%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT APP TO INSTALL / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" (winget install --id "7zip.7zip" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="1" (winget install --id "7zip.7zip" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="02" (winget install --id "RARLab.WinRAR" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="2" (winget install --id "RARLab.WinRAR" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="03" (winget install --id "Notepad++.Notepad++" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="3" (winget install --id "Notepad++.Notepad++" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="04" (winget install --id "Microsoft.PowerToys" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="4" (winget install --id "Microsoft.PowerToys" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="05" (winget install --id "voidtools.Everything" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="5" (winget install --id "voidtools.Everything" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="06" (winget install --id "Microsoft.Sysinternals.Suite" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="6" (winget install --id "Microsoft.Sysinternals.Suite" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="07" (winget install --id "Flow-Launcher.Flow-Launcher" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="7" (winget install --id "Flow-Launcher.Flow-Launcher" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="08" (winget install --id "7zip.7zip" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "RARLab.WinRAR" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Notepad++.Notepad++" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.PowerToys" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "voidtools.Everything" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.Sysinternals.Suite" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Flow-Launcher.Flow-Launcher" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="8" (winget install --id "7zip.7zip" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "RARLab.WinRAR" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Notepad++.Notepad++" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.PowerToys" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "voidtools.Everything" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.Sysinternals.Suite" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Flow-Launcher.Flow-Launcher" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_utilities)
if "%c%"=="99" goto menu_1click_100_apps
if "%c%"=="00" goto menu_1click_100_apps
goto menu_apps_utilities

:menu_apps_maintenance
set "BACK_MENU=menu_1click_100_apps"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% SOFTWARE CATALOG - MAINTENANCE & HARDWARE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] CPU-Z                               [02] HWMonitor                           %C_RESET%
echo %C_GREEN%  [03] CCleaner                            [04] Rufus                               %C_RESET%
echo %C_GREEN%  [05] Etcher                              [06] Revo Uninstaller                    %C_RESET%
echo %C_GREEN%  [07] CrystalDiskInfo                     [08] CrystalDiskMark                     %C_RESET%
echo %C_GREEN%  [09] Winaero Tweaker                                                              %C_RESET%
echo.
echo %C_YELLOW%  [10] Install All in this Category         [99] Back to Categories%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT APP TO INSTALL / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" (winget install --id "CPUID.CPU-Z" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="1" (winget install --id "CPUID.CPU-Z" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="02" (winget install --id "CPUID.HWMonitor" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="2" (winget install --id "CPUID.HWMonitor" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="03" (winget install --id "Piriform.CCleaner" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="3" (winget install --id "Piriform.CCleaner" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="04" (winget install --id "Rufus.Rufus" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="4" (winget install --id "Rufus.Rufus" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="05" (winget install --id "Balena.Etcher" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="5" (winget install --id "Balena.Etcher" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="06" (winget install --id "RevoUninstaller.RevoUninstaller" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="6" (winget install --id "RevoUninstaller.RevoUninstaller" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="07" (winget install --id "CrystalDewWorld.CrystalDiskInfo" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="7" (winget install --id "CrystalDewWorld.CrystalDiskInfo" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="08" (winget install --id "CrystalDewWorld.CrystalDiskMark" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="8" (winget install --id "CrystalDewWorld.CrystalDiskMark" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="09" (winget install --id "winaero.tweaker" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="9" (winget install --id "winaero.tweaker" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="10" (winget install --id "CPUID.CPU-Z" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "CPUID.HWMonitor" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Piriform.CCleaner" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Rufus.Rufus" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Balena.Etcher" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "RevoUninstaller.RevoUninstaller" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "CrystalDewWorld.CrystalDiskInfo" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "CrystalDewWorld.CrystalDiskMark" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "winaero.tweaker" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="10" (winget install --id "CPUID.CPU-Z" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "CPUID.HWMonitor" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Piriform.CCleaner" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Rufus.Rufus" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Balena.Etcher" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "RevoUninstaller.RevoUninstaller" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "CrystalDewWorld.CrystalDiskInfo" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "CrystalDewWorld.CrystalDiskMark" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "winaero.tweaker" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_maintenance)
if "%c%"=="99" goto menu_1click_100_apps
if "%c%"=="00" goto menu_1click_100_apps
goto menu_apps_maintenance

:menu_apps_productivity
set "BACK_MENU=menu_1click_100_apps"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% SOFTWARE CATALOG - PRODUCTIVITY & OFFICE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Acrobat Reader                      [02] Foxit Reader                        %C_RESET%
echo %C_GREEN%  [03] LibreOffice                         [04] Notion                              %C_RESET%
echo %C_GREEN%  [05] Obsidian                            [06] Evernote                            %C_RESET%
echo %C_GREEN%  [07] SumatraPDF                          [08] PDF24 Creator                       %C_RESET%
echo %C_GREEN%  [09] Focus To-Do                         [10] Microsoft To Do                     %C_RESET%
echo %C_GREEN%  [11] Joplin                              [12] Simplenote                          %C_RESET%
echo %C_GREEN%  [13] Microsoft Office                                                             %C_RESET%
echo.
echo %C_YELLOW%  [14] Install All in this Category         [99] Back to Categories%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT APP TO INSTALL / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" (winget install --id "Adobe.Acrobat.Reader.64-bit" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="1" (winget install --id "Adobe.Acrobat.Reader.64-bit" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="02" (winget install --id "Foxit.FoxitReader" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="2" (winget install --id "Foxit.FoxitReader" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="03" (winget install --id "TheDocumentFoundation.LibreOffice" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="3" (winget install --id "TheDocumentFoundation.LibreOffice" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="04" (winget install --id "Notion.Notion" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="4" (winget install --id "Notion.Notion" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="05" (winget install --id "Obsidian.Obsidian" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="5" (winget install --id "Obsidian.Obsidian" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="06" (winget install --id "Evernote.Evernote" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="6" (winget install --id "Evernote.Evernote" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="07" (winget install --id "SumatraPDF.SumatraPDF" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="7" (winget install --id "SumatraPDF.SumatraPDF" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="08" (winget install --id "geeksoftwareGmbH.PDF24Creator" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="8" (winget install --id "geeksoftwareGmbH.PDF24Creator" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="09" (winget install --id "9N8GPB2TK8GB" --source msstore -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="9" (winget install --id "9N8GPB2TK8GB" --source msstore -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="10" (winget install --id "9NBLGGH5R558" --source msstore -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="10" (winget install --id "9NBLGGH5R558" --source msstore -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="11" (winget install --id "Joplin.Joplin" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="11" (winget install --id "Joplin.Joplin" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="12" (winget install --id "Automattic.Simplenote" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="12" (winget install --id "Automattic.Simplenote" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="13" (winget install --id "Microsoft.Office" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="13" (winget install --id "Microsoft.Office" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="14" (winget install --id "Adobe.Acrobat.Reader.64-bit" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Foxit.FoxitReader" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "TheDocumentFoundation.LibreOffice" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Notion.Notion" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Obsidian.Obsidian" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Evernote.Evernote" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "SumatraPDF.SumatraPDF" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "geeksoftwareGmbH.PDF24Creator" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "9N8GPB2TK8GB" --source msstore -e --accept-source-agreements --accept-package-agreements ^& winget install --id "9NBLGGH5R558" --source msstore -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Joplin.Joplin" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Automattic.Simplenote" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.Office" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="14" (winget install --id "Adobe.Acrobat.Reader.64-bit" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Foxit.FoxitReader" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "TheDocumentFoundation.LibreOffice" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Notion.Notion" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Obsidian.Obsidian" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Evernote.Evernote" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "SumatraPDF.SumatraPDF" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "geeksoftwareGmbH.PDF24Creator" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "9N8GPB2TK8GB" --source msstore -e --accept-source-agreements --accept-package-agreements ^& winget install --id "9NBLGGH5R558" --source msstore -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Joplin.Joplin" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Automattic.Simplenote" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.Office" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_productivity)
if "%c%"=="99" goto menu_1click_100_apps
if "%c%"=="00" goto menu_1click_100_apps
goto menu_apps_productivity

:menu_apps_dev
set "BACK_MENU=menu_1click_100_apps"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% SOFTWARE CATALOG - DEVELOPMENT & IT%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Visual Studio Code                  [02] Git                                 %C_RESET%
echo %C_GREEN%  [03] Python 3.11                         [04] NodeJS                              %C_RESET%
echo %C_GREEN%  [05] Docker Desktop                      [06] Oracle VirtualBox                   %C_RESET%
echo %C_GREEN%  [07] PuTTY                               [08] WinSCP                              %C_RESET%
echo %C_GREEN%  [09] Cyberduck                           [10] Postman                             %C_RESET%
echo %C_GREEN%  [11] Notepad3                            [12] DB Browser for SQLite               %C_RESET%
echo %C_GREEN%  [13] Windows Terminal                    [14] PowerShell 7                        %C_RESET%
echo %C_GREEN%  [15] SQL Server Mgmt Studio              [16] Ubuntu on Windows                   %C_RESET%
echo %C_GREEN%  [17] MongoDB Compass                     [18] Wireshark                           %C_RESET%
echo.
echo %C_YELLOW%  [19] Install All in this Category         [99] Back to Categories%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT APP TO INSTALL / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" (winget install --id "Microsoft.VisualStudioCode" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="1" (winget install --id "Microsoft.VisualStudioCode" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="02" (winget install --id "Git.Git" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="2" (winget install --id "Git.Git" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="03" (winget install --id "Python.Python.3.11" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="3" (winget install --id "Python.Python.3.11" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="04" (winget install --id "OpenJS.NodeJS" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="4" (winget install --id "OpenJS.NodeJS" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="05" (winget install --id "Docker.DockerDesktop" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="5" (winget install --id "Docker.DockerDesktop" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="06" (winget install --id "Oracle.VirtualBox" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="6" (winget install --id "Oracle.VirtualBox" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="07" (winget install --id "PuTTY.PuTTY" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="7" (winget install --id "PuTTY.PuTTY" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="08" (winget install --id "WinSCP.WinSCP" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="8" (winget install --id "WinSCP.WinSCP" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="09" (winget install --id "Iterate.Cyberduck" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="9" (winget install --id "Iterate.Cyberduck" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="10" (winget install --id "Postman.Postman" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="10" (winget install --id "Postman.Postman" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="11" (winget install --id "Rizonesoft.Notepad3" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="11" (winget install --id "Rizonesoft.Notepad3" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="12" (winget install --id "DBBrowserForSQLite.DBBrowserForSQLite" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="12" (winget install --id "DBBrowserForSQLite.DBBrowserForSQLite" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="13" (winget install --id "Microsoft.WindowsTerminal" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="13" (winget install --id "Microsoft.WindowsTerminal" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="14" (winget install --id "Microsoft.PowerShell" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="14" (winget install --id "Microsoft.PowerShell" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="15" (winget install --id "Microsoft.SQLServerManagementStudio" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="15" (winget install --id "Microsoft.SQLServerManagementStudio" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="16" (winget install --id "Canonical.Ubuntu.2404" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="16" (winget install --id "Canonical.Ubuntu.2404" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="17" (winget install --id "MongoDB.Compass.Full" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="17" (winget install --id "MongoDB.Compass.Full" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="18" (winget install --id "WiresharkFoundation.Wireshark" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="18" (winget install --id "WiresharkFoundation.Wireshark" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="19" (winget install --id "Microsoft.VisualStudioCode" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Git.Git" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Python.Python.3.11" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "OpenJS.NodeJS" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Docker.DockerDesktop" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Oracle.VirtualBox" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "PuTTY.PuTTY" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "WinSCP.WinSCP" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Iterate.Cyberduck" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Postman.Postman" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Rizonesoft.Notepad3" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "DBBrowserForSQLite.DBBrowserForSQLite" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.WindowsTerminal" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.PowerShell" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.SQLServerManagementStudio" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Canonical.Ubuntu.2404" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "MongoDB.Compass.Full" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "WiresharkFoundation.Wireshark" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="19" (winget install --id "Microsoft.VisualStudioCode" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Git.Git" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Python.Python.3.11" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "OpenJS.NodeJS" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Docker.DockerDesktop" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Oracle.VirtualBox" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "PuTTY.PuTTY" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "WinSCP.WinSCP" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Iterate.Cyberduck" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Postman.Postman" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Rizonesoft.Notepad3" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "DBBrowserForSQLite.DBBrowserForSQLite" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.WindowsTerminal" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.PowerShell" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.SQLServerManagementStudio" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Canonical.Ubuntu.2404" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "MongoDB.Compass.Full" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "WiresharkFoundation.Wireshark" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_dev)
if "%c%"=="99" goto menu_1click_100_apps
if "%c%"=="00" goto menu_1click_100_apps
goto menu_apps_dev

:menu_apps_cloud
set "BACK_MENU=menu_1click_100_apps"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% SOFTWARE CATALOG - CLOUD & REMOTE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] TeamViewer                          [02] AnyDesk                             %C_RESET%
echo %C_GREEN%  [03] OneDrive                            [04] Dropbox                             %C_RESET%
echo %C_GREEN%  [05] Google Drive                        [06] MEGAsync                            %C_RESET%
echo %C_GREEN%  [07] Nextcloud                           [08] Box                                 %C_RESET%
echo.
echo %C_YELLOW%  [09] Install All in this Category         [99] Back to Categories%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT APP TO INSTALL / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" (winget install --id "TeamViewer.TeamViewer" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="1" (winget install --id "TeamViewer.TeamViewer" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="02" (winget install --id "AnyDesk.AnyDesk" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="2" (winget install --id "AnyDesk.AnyDesk" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="03" (winget install --id "Microsoft.OneDrive" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="3" (winget install --id "Microsoft.OneDrive" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="04" (winget install --id "Dropbox.Dropbox" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="4" (winget install --id "Dropbox.Dropbox" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="05" (winget install --id "Google.GoogleDrive" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="5" (winget install --id "Google.GoogleDrive" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="06" (winget install --id "Mega.MEGASync" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="6" (winget install --id "Mega.MEGASync" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="07" (winget install --id "Nextcloud.NextcloudDesktop" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="7" (winget install --id "Nextcloud.NextcloudDesktop" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="08" (winget install --id "Box.Box" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="8" (winget install --id "Box.Box" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="09" (winget install --id "TeamViewer.TeamViewer" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "AnyDesk.AnyDesk" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.OneDrive" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Dropbox.Dropbox" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Google.GoogleDrive" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Mega.MEGASync" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Nextcloud.NextcloudDesktop" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Box.Box" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="9" (winget install --id "TeamViewer.TeamViewer" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "AnyDesk.AnyDesk" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.OneDrive" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Dropbox.Dropbox" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Google.GoogleDrive" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Mega.MEGASync" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Nextcloud.NextcloudDesktop" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Box.Box" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_cloud)
if "%c%"=="99" goto menu_1click_100_apps
if "%c%"=="00" goto menu_1click_100_apps
goto menu_apps_cloud

:menu_apps_security
set "BACK_MENU=menu_1click_100_apps"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% SOFTWARE CATALOG - SECURITY, VPN & RUNTIMES%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Malwarebytes                        [02] Bitwarden                           %C_RESET%
echo %C_GREEN%  [03] ProtonVPN                           [04] Cloudflare WARP                     %C_RESET%
echo %C_GREEN%  [05] OpenVPN Connect                     [06] Viscosity OpenVPN                   %C_RESET%
echo %C_GREEN%  [07] VCRedist 2015+                      [08] .NET Desktop Runtime 8              %C_RESET%
echo %C_GREEN%  [09] Java Runtime                        [10] DirectX                             %C_RESET%
echo.
echo %C_YELLOW%  [11] Install All in this Category         [99] Back to Categories%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT APP TO INSTALL / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" (winget install --id "Malwarebytes.Malwarebytes" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="1" (winget install --id "Malwarebytes.Malwarebytes" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="02" (winget install --id "Bitwarden.Bitwarden" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="2" (winget install --id "Bitwarden.Bitwarden" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="03" (winget install --id "Proton.ProtonVPN" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="3" (winget install --id "Proton.ProtonVPN" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="04" (winget install --id "Cloudflare.Warp" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="4" (winget install --id "Cloudflare.Warp" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="05" (winget install --id "OpenVPNTechnologies.OpenVPN" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="5" (winget install --id "OpenVPNTechnologies.OpenVPN" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="06" (winget install --id "SparkLabs.Viscosity" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="6" (winget install --id "SparkLabs.Viscosity" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="07" (winget install --id "Microsoft.VCRedist.2015+.x64" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="7" (winget install --id "Microsoft.VCRedist.2015+.x64" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="08" (winget install --id "Microsoft.DotNet.DesktopRuntime.8" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="8" (winget install --id "Microsoft.DotNet.DesktopRuntime.8" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="09" (winget install --id "Oracle.JavaRuntimeEnvironment" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="9" (winget install --id "Oracle.JavaRuntimeEnvironment" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="10" (winget install --id "Microsoft.DirectX" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="10" (winget install --id "Microsoft.DirectX" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="11" (winget install --id "Malwarebytes.Malwarebytes" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Bitwarden.Bitwarden" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Proton.ProtonVPN" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Cloudflare.Warp" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "OpenVPNTechnologies.OpenVPN" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "SparkLabs.Viscosity" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.VCRedist.2015+.x64" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.DotNet.DesktopRuntime.8" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Oracle.JavaRuntimeEnvironment" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.DirectX" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="11" (winget install --id "Malwarebytes.Malwarebytes" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Bitwarden.Bitwarden" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Proton.ProtonVPN" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Cloudflare.Warp" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "OpenVPNTechnologies.OpenVPN" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "SparkLabs.Viscosity" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.VCRedist.2015+.x64" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.DotNet.DesktopRuntime.8" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Oracle.JavaRuntimeEnvironment" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Microsoft.DirectX" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_security)
if "%c%"=="99" goto menu_1click_100_apps
if "%c%"=="00" goto menu_1click_100_apps
goto menu_apps_security

:menu_apps_ai
set "BACK_MENU=menu_1click_100_apps"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA% SOFTWARE CATALOG - AI TOOLS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] ChatGPT (lencx)                     [02] GAI                                 %C_RESET%
echo %C_GREEN%  [03] LobeHub                             [04] Dive (OpenAgentPlatform)            %C_RESET%
echo %C_GREEN%  [05] PrivacyPal AI                       [06] Poe                                 %C_RESET%
echo.
echo %C_YELLOW%  [07] Install All in this Category         [99] Back to Categories%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT APP TO INSTALL / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" (winget install --id "lencx.ChatGPT" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="1" (winget install --id "lencx.ChatGPT" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="02" (winget install --id "GAI.GAI" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="2" (winget install --id "GAI.GAI" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="03" (winget install --id "LobeHub.LobeHub" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="3" (winget install --id "LobeHub.LobeHub" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="04" (winget install --id "OpenAgentPlatform.Dive" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="4" (winget install --id "OpenAgentPlatform.Dive" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="05" (winget install --id "PrivacyPal.AI" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="5" (winget install --id "PrivacyPal.AI" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="06" (winget install --id "Quora.Poe" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="6" (winget install --id "Quora.Poe" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="07" (winget install --id "lencx.ChatGPT" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "GAI.GAI" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "LobeHub.LobeHub" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "OpenAgentPlatform.Dive" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "PrivacyPal.AI" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Quora.Poe" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="7" (winget install --id "lencx.ChatGPT" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "GAI.GAI" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "LobeHub.LobeHub" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "OpenAgentPlatform.Dive" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "PrivacyPal.AI" -e --accept-source-agreements --accept-package-agreements ^& winget install --id "Quora.Poe" -e --accept-source-agreements --accept-package-agreements & pause & goto menu_apps_ai)
if "%c%"=="99" goto menu_1click_100_apps
if "%c%"=="00" goto menu_1click_100_apps
goto menu_apps_ai

:menu_apps_bulk_install
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  Installing ALL 100 APPS...
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
winget install --id "Google.Chrome" -e --accept-source-agreements --accept-package-agreements
winget install --id "Mozilla.Firefox" -e --accept-source-agreements --accept-package-agreements
winget install --id "Brave.Brave" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.Edge" -e --accept-source-agreements --accept-package-agreements
winget install --id "Opera.Opera" -e --accept-source-agreements --accept-package-agreements
winget install --id "Vivaldi.Vivaldi" -e --accept-source-agreements --accept-package-agreements
winget install --id "TorProject.TorBrowser" -e --accept-source-agreements --accept-package-agreements
winget install --id "Waterfox.Waterfox" -e --accept-source-agreements --accept-package-agreements
winget install --id "Discord.Discord" -e --accept-source-agreements --accept-package-agreements
winget install --id "SlackTechnologies.Slack" -e --accept-source-agreements --accept-package-agreements
winget install --id "Telegram.TelegramDesktop" -e --accept-source-agreements --accept-package-agreements
winget install --id "9NKSQGP7F2NH" --source msstore -e --accept-source-agreements --accept-package-agreements
winget install --id "Zoom.Zoom" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.Teams" -e --accept-source-agreements --accept-package-agreements
winget install --id "Rambox.Rambox.Community" -e --accept-source-agreements --accept-package-agreements
winget install --id "Rakuten.Viber" -e --accept-source-agreements --accept-package-agreements
winget install --id "Element.Element" -e --accept-source-agreements --accept-package-agreements
winget install --id "OpenWhisperSystems.Signal" -e --accept-source-agreements --accept-package-agreements
winget install --id "VideoLAN.VLC" -e --accept-source-agreements --accept-package-agreements
winget install --id "OBSProject.OBSStudio" -e --accept-source-agreements --accept-package-agreements
winget install --id "Spotify.Spotify" -e --accept-source-agreements --accept-package-agreements
winget install --id "Apple.iTunes" -e --accept-source-agreements --accept-package-agreements
winget install --id "AIMP.AIMP" -e --accept-source-agreements --accept-package-agreements
winget install --id "Audacity.Audacity" -e --accept-source-agreements --accept-package-agreements
winget install --id "GIMP.GIMP" -e --accept-source-agreements --accept-package-agreements
winget install --id "CodecGuide.K-LiteCodecPack.Full" -e --accept-source-agreements --accept-package-agreements
winget install --id "HandBrake.HandBrake" -e --accept-source-agreements --accept-package-agreements
winget install --id "clsid2.mpc-hc" -e --accept-source-agreements --accept-package-agreements
winget install --id "KDE.Kdenlive" -e --accept-source-agreements --accept-package-agreements
winget install --id "Amazon.Music" -e --accept-source-agreements --accept-package-agreements
winget install --id "7zip.7zip" -e --accept-source-agreements --accept-package-agreements
winget install --id "RARLab.WinRAR" -e --accept-source-agreements --accept-package-agreements
winget install --id "Notepad++.Notepad++" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.PowerToys" -e --accept-source-agreements --accept-package-agreements
winget install --id "voidtools.Everything" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.Sysinternals.Suite" -e --accept-source-agreements --accept-package-agreements
winget install --id "Flow-Launcher.Flow-Launcher" -e --accept-source-agreements --accept-package-agreements
winget install --id "CPUID.CPU-Z" -e --accept-source-agreements --accept-package-agreements
winget install --id "CPUID.HWMonitor" -e --accept-source-agreements --accept-package-agreements
winget install --id "Piriform.CCleaner" -e --accept-source-agreements --accept-package-agreements
winget install --id "Rufus.Rufus" -e --accept-source-agreements --accept-package-agreements
winget install --id "Balena.Etcher" -e --accept-source-agreements --accept-package-agreements
winget install --id "RevoUninstaller.RevoUninstaller" -e --accept-source-agreements --accept-package-agreements
winget install --id "CrystalDewWorld.CrystalDiskInfo" -e --accept-source-agreements --accept-package-agreements
winget install --id "CrystalDewWorld.CrystalDiskMark" -e --accept-source-agreements --accept-package-agreements
winget install --id "winaero.tweaker" -e --accept-source-agreements --accept-package-agreements
winget install --id "Adobe.Acrobat.Reader.64-bit" -e --accept-source-agreements --accept-package-agreements
winget install --id "Foxit.FoxitReader" -e --accept-source-agreements --accept-package-agreements
winget install --id "TheDocumentFoundation.LibreOffice" -e --accept-source-agreements --accept-package-agreements
winget install --id "Notion.Notion" -e --accept-source-agreements --accept-package-agreements
winget install --id "Obsidian.Obsidian" -e --accept-source-agreements --accept-package-agreements
winget install --id "Evernote.Evernote" -e --accept-source-agreements --accept-package-agreements
winget install --id "SumatraPDF.SumatraPDF" -e --accept-source-agreements --accept-package-agreements
winget install --id "geeksoftwareGmbH.PDF24Creator" -e --accept-source-agreements --accept-package-agreements
winget install --id "9N8GPB2TK8GB" --source msstore -e --accept-source-agreements --accept-package-agreements
winget install --id "9NBLGGH5R558" --source msstore -e --accept-source-agreements --accept-package-agreements
winget install --id "Joplin.Joplin" -e --accept-source-agreements --accept-package-agreements
winget install --id "Automattic.Simplenote" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.VisualStudioCode" -e --accept-source-agreements --accept-package-agreements
winget install --id "Git.Git" -e --accept-source-agreements --accept-package-agreements
winget install --id "Python.Python.3.11" -e --accept-source-agreements --accept-package-agreements
winget install --id "OpenJS.NodeJS" -e --accept-source-agreements --accept-package-agreements
winget install --id "Docker.DockerDesktop" -e --accept-source-agreements --accept-package-agreements
winget install --id "Oracle.VirtualBox" -e --accept-source-agreements --accept-package-agreements
winget install --id "PuTTY.PuTTY" -e --accept-source-agreements --accept-package-agreements
winget install --id "WinSCP.WinSCP" -e --accept-source-agreements --accept-package-agreements
winget install --id "Iterate.Cyberduck" -e --accept-source-agreements --accept-package-agreements
winget install --id "Postman.Postman" -e --accept-source-agreements --accept-package-agreements
winget install --id "Rizonesoft.Notepad3" -e --accept-source-agreements --accept-package-agreements
winget install --id "DBBrowserForSQLite.DBBrowserForSQLite" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.WindowsTerminal" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.PowerShell" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.SQLServerManagementStudio" -e --accept-source-agreements --accept-package-agreements
winget install --id "Canonical.Ubuntu.2404" -e --accept-source-agreements --accept-package-agreements
winget install --id "MongoDB.Compass.Full" -e --accept-source-agreements --accept-package-agreements
winget install --id "WiresharkFoundation.Wireshark" -e --accept-source-agreements --accept-package-agreements
winget install --id "TeamViewer.TeamViewer" -e --accept-source-agreements --accept-package-agreements
winget install --id "AnyDesk.AnyDesk" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.OneDrive" -e --accept-source-agreements --accept-package-agreements
winget install --id "Dropbox.Dropbox" -e --accept-source-agreements --accept-package-agreements
winget install --id "Google.GoogleDrive" -e --accept-source-agreements --accept-package-agreements
winget install --id "Mega.MEGASync" -e --accept-source-agreements --accept-package-agreements
winget install --id "Nextcloud.NextcloudDesktop" -e --accept-source-agreements --accept-package-agreements
winget install --id "Box.Box" -e --accept-source-agreements --accept-package-agreements
winget install --id "Malwarebytes.Malwarebytes" -e --accept-source-agreements --accept-package-agreements
winget install --id "Bitwarden.Bitwarden" -e --accept-source-agreements --accept-package-agreements
winget install --id "Proton.ProtonVPN" -e --accept-source-agreements --accept-package-agreements
winget install --id "Cloudflare.Warp" -e --accept-source-agreements --accept-package-agreements
winget install --id "OpenVPNTechnologies.OpenVPN" -e --accept-source-agreements --accept-package-agreements
winget install --id "SparkLabs.Viscosity" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.VCRedist.2015+.x64" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.DotNet.DesktopRuntime.8" -e --accept-source-agreements --accept-package-agreements
winget install --id "Oracle.JavaRuntimeEnvironment" -e --accept-source-agreements --accept-package-agreements
winget install --id "Microsoft.DirectX" -e --accept-source-agreements --accept-package-agreements
winget install --id "lencx.ChatGPT" -e --accept-source-agreements --accept-package-agreements
winget install --id "GAI.GAI" -e --accept-source-agreements --accept-package-agreements
winget install --id "LobeHub.LobeHub" -e --accept-source-agreements --accept-package-agreements
winget install --id "OpenAgentPlatform.Dive" -e --accept-source-agreements --accept-package-agreements
winget install --id "PrivacyPal.AI" -e --accept-source-agreements --accept-package-agreements
winget install --id "Quora.Poe" -e --accept-source-agreements --accept-package-agreements
echo.
echo %C_GREEN%Installation complete!%C_RESET%
pause
goto menu_1click_100_apps

:: ============================================================
:: MENU: SOFTWARE UPDATER / UPDATE MANAGER
:: ============================================================
:menu_apps_update_manager
set "BACK_MENU=main"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          SOFTWARE UPDATER - UPDATE MANAGER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Winget Upgrade All Apps%C_RESET%
echo %C_GREEN%  [02] Check Updates Available (List)%C_RESET%
echo %C_GREEN%  [03] Update Specific App (by ID)%C_RESET%
echo %C_GREEN%  [04] Windows Update (Open Settings)%C_RESET%
echo %C_GREEN%  [05] Microsoft Store Updates%C_RESET%
echo %C_GREEN%  [06] View Upgrade History%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto upd_mgr_01
if "%c%"=="1"  goto upd_mgr_01
if "%c%"=="02" goto upd_mgr_02
if "%c%"=="2"  goto upd_mgr_02
if "%c%"=="03" goto upd_mgr_03
if "%c%"=="3"  goto upd_mgr_03
if "%c%"=="04" goto upd_mgr_04
if "%c%"=="4"  goto upd_mgr_04
if "%c%"=="05" goto upd_mgr_05
if "%c%"=="5"  goto upd_mgr_05
if "%c%"=="06" goto upd_mgr_06
if "%c%"=="6"  goto upd_mgr_06
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_apps_update_manager

:upd_mgr_01
cls
echo Upgrading all apps via Winget...
echo This may take several minutes. Please wait.
echo.
winget upgrade --all --accept-source-agreements --accept-package-agreements
pause
goto menu_apps_update_manager

:upd_mgr_02
cls
echo Checking for available updates...
echo.
winget upgrade --include-unknown --accept-source-agreements
pause
goto menu_apps_update_manager

:upd_mgr_03
cls
echo Enter the exact Winget App ID to update (e.g. Mozilla.Firefox):
set "APPID=" & set /p APPID=App ID: 
if "%APPID%"=="" goto menu_apps_update_manager
winget upgrade --id "%APPID%" -e --accept-source-agreements --accept-package-agreements
pause
goto menu_apps_update_manager

:upd_mgr_04
start "" ms-settings:windowsupdate
goto menu_apps_update_manager

:upd_mgr_05
start "" ms-windows-store://updates
goto menu_apps_update_manager

:upd_mgr_06
cls
echo Winget Upgrade History:
echo.
winget upgrade --include-unknown --accept-source-agreements 2>nul
echo.
echo (Full history is stored in Windows Event Viewer under AppXDeployment-Server)
pause
goto menu_apps_update_manager

:: ============================================================
:: MENU: CUSTOM APPS BUNDLER
:: ============================================================
:menu_apps_custom_bundler
set "BACK_MENU=main"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          CUSTOM APPS BUNDLER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Create Custom Install Bundle%C_RESET%
echo %C_GREEN%  [02] Run Saved Bundle%C_RESET%
echo %C_GREEN%  [03] Add App to Bundle%C_RESET%
echo %C_GREEN%  [04] View Bundle List%C_RESET%
echo %C_GREEN%  [05] Export Bundle Script%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto bundler_01
if "%c%"=="1"  goto bundler_01
if "%c%"=="02" goto bundler_02
if "%c%"=="2"  goto bundler_02
if "%c%"=="03" goto bundler_03
if "%c%"=="3"  goto bundler_03
if "%c%"=="04" goto bundler_04
if "%c%"=="4"  goto bundler_04
if "%c%"=="05" goto bundler_05
if "%c%"=="5"  goto bundler_05
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_apps_custom_bundler

:bundler_01
set "BUNDLE_FILE=%~dp0Config\custom_bundle.txt"
if not exist "%~dp0Config" mkdir "%~dp0Config"
echo Creating a new bundle. Enter App IDs one per line. Type DONE when finished.
echo (Bundle will be saved to: %BUNDLE_FILE%)
echo.> "%BUNDLE_FILE%"
:bundler_input_loop
set "APPID=" & set /p APPID=  Enter App ID (or DONE): 
if /i "%APPID%"=="DONE" goto bundler_01_done
if "%APPID%"=="" goto bundler_input_loop
echo %APPID%>> "%BUNDLE_FILE%"
goto bundler_input_loop
:bundler_01_done
echo Bundle saved to: %BUNDLE_FILE%
pause
goto menu_apps_custom_bundler

:bundler_02
set "BUNDLE_FILE=%~dp0Config\custom_bundle.txt"
if not exist "%BUNDLE_FILE%" (
    echo No bundle file found. Create one first with option 01.
    pause
    goto menu_apps_custom_bundler
)
echo Running saved bundle...
echo.
for /f "usebackq tokens=*" %%A in ("%BUNDLE_FILE%") do (
    if not "%%A"=="" (
        echo Installing: %%A
        winget install --id "%%A" -e --accept-source-agreements --accept-package-agreements
    )
)
echo.
echo Bundle installation complete!
pause
goto menu_apps_custom_bundler

:bundler_03
set "BUNDLE_FILE=%~dp0Config\custom_bundle.txt"
if not exist "%~dp0Config" mkdir "%~dp0Config"
if not exist "%BUNDLE_FILE%" echo.> "%BUNDLE_FILE%"
echo Enter App ID to add to bundle:
set "APPID=" & set /p APPID=  App ID: 
if "%APPID%"=="" goto menu_apps_custom_bundler
echo %APPID%>> "%BUNDLE_FILE%"
echo Added '%APPID%' to bundle.
pause
goto menu_apps_custom_bundler

:bundler_04
set "BUNDLE_FILE=%~dp0Config\custom_bundle.txt"
if not exist "%BUNDLE_FILE%" (
    echo No bundle file found.
    pause
    goto menu_apps_custom_bundler
)
echo Current Bundle Contents:
echo.
type "%BUNDLE_FILE%"
echo.
pause
goto menu_apps_custom_bundler

:bundler_05
set "BUNDLE_FILE=%~dp0Config\custom_bundle.txt"
set "EXPORT_FILE=%USERPROFILE%\Desktop\Install_Bundle_%date:~-4,4%%date:~-7,2%%date:~0,2%.bat"
if not exist "%BUNDLE_FILE%" (
    echo No bundle file found. Create one first.
    pause
    goto menu_apps_custom_bundler
)
echo @echo off> "%EXPORT_FILE%"
echo echo Installing Custom App Bundle...>> "%EXPORT_FILE%"
for /f "usebackq tokens=*" %%A in ("%BUNDLE_FILE%") do (
    if not "%%A"=="" echo winget install --id "%%A" -e --accept-source-agreements --accept-package-agreements>> "%EXPORT_FILE%"
)
echo echo Installation complete!>> "%EXPORT_FILE%"
echo pause>> "%EXPORT_FILE%"
echo Bundle script exported to Desktop: %EXPORT_FILE%
pause
goto menu_apps_custom_bundler

:: ============================================================
:: MENU: SYSTEM CLEANER
:: ============================================================
:menu_system_cleaner
set "BACK_MENU=main"
cls
color 0D
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          SYSTEM CLEANER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Clean Temp Files (User %%TEMP%%)%C_RESET%
echo %C_GREEN%  [02] Clean Windows Temp (C:\Windows\Temp)%C_RESET%
echo %C_GREEN%  [03] Clean Prefetch%C_RESET%
echo %C_GREEN%  [04] Clean Browser Cache (Chrome / Edge)%C_RESET%
echo %C_GREEN%  [05] Empty Recycle Bin%C_RESET%
echo %C_GREEN%  [06] Clean System Logs (WER)%C_RESET%
echo %C_GREEN%  [07] Disk Usage Report (Top Folders)%C_RESET%
echo %C_GREEN%  [08] 1-Click Full System Clean%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto sysclean_01
if "%c%"=="1"  goto sysclean_01
if "%c%"=="02" goto sysclean_02
if "%c%"=="2"  goto sysclean_02
if "%c%"=="03" goto sysclean_03
if "%c%"=="3"  goto sysclean_03
if "%c%"=="04" goto sysclean_04
if "%c%"=="4"  goto sysclean_04
if "%c%"=="05" goto sysclean_05
if "%c%"=="5"  goto sysclean_05
if "%c%"=="06" goto sysclean_06
if "%c%"=="6"  goto sysclean_06
if "%c%"=="07" goto sysclean_07
if "%c%"=="7"  goto sysclean_07
if "%c%"=="08" goto sysclean_08
if "%c%"=="8"  goto sysclean_08
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_system_cleaner

:sysclean_01
echo Cleaning User Temp folder...
call :clean_folder_contents "%TEMP%" "User Temp"
pause
goto menu_system_cleaner

:sysclean_02
echo Cleaning Windows Temp folder...
call :clean_folder_contents "C:\Windows\Temp" "Windows Temp"
pause
goto menu_system_cleaner

:sysclean_03
echo Cleaning Prefetch...
call :clean_folder_contents "C:\Windows\Prefetch" "Prefetch"
pause
goto menu_system_cleaner

:sysclean_04
echo Cleaning Browser Caches...
call :clean_browser_caches
pause
goto menu_system_cleaner

:sysclean_05
echo Emptying Recycle Bin...
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Host 'Recycle Bin emptied.'"
pause
goto menu_system_cleaner

:sysclean_06
echo Cleaning Windows Error Reporting logs...
call :clean_folder_contents "C:\ProgramData\Microsoft\Windows\WER" "Windows Error Reports"
pause
goto menu_system_cleaner

:sysclean_07
cls
echo Disk Usage Report - Top 15 Largest Folders on C:
echo.
powershell -NoProfile -Command "Get-ChildItem 'C:\' -Directory -ErrorAction SilentlyContinue | ForEach-Object { $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum; [PSCustomObject]@{Folder=$_.FullName; SizeGB=[math]::Round($size/1GB,2)} } | Sort-Object SizeGB -Descending | Select-Object -First 15 | Format-Table -AutoSize"
pause
goto menu_system_cleaner

:sysclean_08
cls
echo Running 1-Click Full System Clean...
echo.
call :one_clean_core
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Host 'Recycle Bin emptied.'"
echo.
echo *** FULL SYSTEM CLEAN COMPLETE ***
pause
goto menu_system_cleaner

:: ============================================================
:: MENU: 1-CLICK BACKUP AND MIGRATE
:: ============================================================
:menu_user_backup
set "BACK_MENU=main"
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          1-CLICK BACKUP AND MIGRATE%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Backup User Documents%C_RESET%
echo %C_GREEN%  [02] Backup Desktop%C_RESET%
echo %C_GREEN%  [03] Backup AppData Roaming%C_RESET%
echo %C_GREEN%  [04] Full User Profile Backup%C_RESET%
echo %C_GREEN%  [05] Migrate to New PC Guide%C_RESET%
echo %C_GREEN%  [06] Windows Easy Transfer Info%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto backup_01
if "%c%"=="1"  goto backup_01
if "%c%"=="02" goto backup_02
if "%c%"=="2"  goto backup_02
if "%c%"=="03" goto backup_03
if "%c%"=="3"  goto backup_03
if "%c%"=="04" goto backup_04
if "%c%"=="4"  goto backup_04
if "%c%"=="05" goto backup_05
if "%c%"=="5"  goto backup_05
if "%c%"=="06" goto backup_06
if "%c%"=="6"  goto backup_06
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_user_backup

:backup_01
set "DEST=%USERPROFILE%\Desktop\Backup_Documents_%date:~-4,4%%date:~-7,2%%date:~0,2%"
echo Backing up Documents to Desktop...
echo Destination: %DEST%
robocopy "%USERPROFILE%\Documents" "%DEST%\Documents" /E /R:1 /W:1 /NP /LOG+:"%DEST%\backup.log"
echo Done! Check Desktop for Backup_Documents folder.
pause
goto menu_user_backup

:backup_02
set "DEST=%USERPROFILE%\Desktop\Backup_Desktop_%date:~-4,4%%date:~-7,2%%date:~0,2%"
echo Backing up Desktop to a subfolder...
echo Destination: %DEST%
robocopy "%USERPROFILE%\Desktop" "%DEST%\Desktop" /E /R:1 /W:1 /NP /XD "%DEST%"
echo Done!
pause
goto menu_user_backup

:backup_03
set "DEST=%USERPROFILE%\Desktop\Backup_AppData_%date:~-4,4%%date:~-7,2%%date:~0,2%"
echo Backing up AppData\Roaming...
echo Destination: %DEST%
robocopy "%APPDATA%" "%DEST%\AppData_Roaming" /E /R:1 /W:1 /NP /XJD
echo Done!
pause
goto menu_user_backup

:backup_04
set "DEST=%USERPROFILE%\Desktop\Backup_FullProfile_%date:~-4,4%%date:~-7,2%%date:~0,2%"
echo Backing up Full User Profile (may take a while)...
echo Destination: %DEST%
robocopy "%USERPROFILE%" "%DEST%\UserProfile" /E /R:1 /W:1 /NP /XJD /XD "%USERPROFILE%\AppData\Local\Temp"
echo Done! Full profile backed up.
pause
goto menu_user_backup

:backup_05
cls
echo %C_CYAN%=== MIGRATE TO NEW PC GUIDE ===%C_RESET%
echo.
echo Step 1: On OLD PC - Use this toolkit to backup Documents, Desktop, AppData.
echo Step 2: Copy the Backup folder to a USB drive or network share.
echo Step 3: On NEW PC - Copy the Backup folder from USB to Desktop.
echo Step 4: Restore files manually or use xcopy/robocopy.
echo Step 5: Use option [01] Winget Upgrade All on new PC to reinstall apps.
echo Step 6: Export browser bookmarks from old PC and import on new PC.
echo Step 7: Re-activate Windows license using License Vault menu.
echo.
echo For settings migration: Use Windows Backup (Settings -^> Accounts -^> Windows Backup)
echo.
pause
goto menu_user_backup

:backup_06
cls
echo %C_CYAN%=== WINDOWS EASY TRANSFER INFO ===%C_RESET%
echo.
echo Windows Easy Transfer was removed in Windows 10/11.
echo.
echo Modern alternatives:
echo  - PCmover (paid): www.laplink.com/pcmover
echo  - OneDrive: Sync Documents, Desktop, Pictures to cloud
echo  - Windows Backup: Settings -^> System -^> Backup (Windows 11)
echo  - File History: Control Panel -^> File History
echo.
echo Opening Windows Backup Settings...
start "" ms-settings:backup
pause
goto menu_user_backup

:: ============================================================
:: MENU: WINDOWS DEBLOATER / BLOATWARE REMOVER
:: ============================================================
:menu_bloatware_remover
set "BACK_MENU=main"
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          WINDOWS DEBLOATER - BLOATWARE REMOVER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Remove Xbox Apps%C_RESET%
echo %C_GREEN%  [02] Remove Microsoft Solitaire%C_RESET%
echo %C_GREEN%  [03] Remove Weather / News App%C_RESET%
echo %C_GREEN%  [04] Remove Cortana%C_RESET%
echo %C_GREEN%  [05] Remove Edge WebView2 Bloat (disable auto-launch)%C_RESET%
echo %C_GREEN%  [06] Remove OneDrive%C_RESET%
echo %C_GREEN%  [07] Restore Removed Apps (Windows Store reinstall)%C_RESET%
echo %C_GREEN%  [08] 1-Click Safe Debloat (Safe set)%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto bloat_01
if "%c%"=="1"  goto bloat_01
if "%c%"=="02" goto bloat_02
if "%c%"=="2"  goto bloat_02
if "%c%"=="03" goto bloat_03
if "%c%"=="3"  goto bloat_03
if "%c%"=="04" goto bloat_04
if "%c%"=="4"  goto bloat_04
if "%c%"=="05" goto bloat_05
if "%c%"=="5"  goto bloat_05
if "%c%"=="06" goto bloat_06
if "%c%"=="6"  goto bloat_06
if "%c%"=="07" goto bloat_07
if "%c%"=="7"  goto bloat_07
if "%c%"=="08" goto bloat_08
if "%c%"=="8"  goto bloat_08
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_bloatware_remover

:bloat_01
echo Removing Xbox Apps...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage *Xbox* | Remove-AppxPackage -ErrorAction SilentlyContinue; Write-Host 'Xbox apps removed.'"
pause
goto menu_bloatware_remover

:bloat_02
echo Removing Microsoft Solitaire Collection...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage *MicrosoftSolitaireCollection* | Remove-AppxPackage -ErrorAction SilentlyContinue; Write-Host 'Solitaire removed.'"
pause
goto menu_bloatware_remover

:bloat_03
echo Removing Weather and News apps...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage *BingWeather* | Remove-AppxPackage -ErrorAction SilentlyContinue; Get-AppxPackage *BingNews* | Remove-AppxPackage -ErrorAction SilentlyContinue; Write-Host 'Weather/News apps removed.'"
pause
goto menu_bloatware_remover

:bloat_04
echo Removing Cortana...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage *Microsoft.549981C3F5F10* | Remove-AppxPackage -ErrorAction SilentlyContinue; Write-Host 'Cortana removed (if installed as app).'"
pause
goto menu_bloatware_remover

:bloat_05
echo Disabling Edge WebView2 auto-launch on startup...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch" /f 2>nul
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch" /f 2>nul
echo Edge auto-launch entries removed (if they existed).
pause
goto menu_bloatware_remover

:bloat_06
echo Removing OneDrive...
taskkill /f /im OneDrive.exe 2>nul
if exist "%SystemRoot%\System32\OneDriveSetup.exe" (
    "%SystemRoot%\System32\OneDriveSetup.exe" /uninstall
) else if exist "%SystemRoot%\SysWOW64\OneDriveSetup.exe" (
    "%SystemRoot%\SysWOW64\OneDriveSetup.exe" /uninstall
) else (
    echo OneDrive setup not found in system paths.
)
echo OneDrive removal attempted.
pause
goto menu_bloatware_remover

:bloat_07
echo Restoring default Windows apps via PowerShell...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage -AllUsers | Where-Object {$_.NonRemovable -eq $false} | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $_.InstallLocation 'AppxManifest.xml') -ErrorAction SilentlyContinue}; Write-Host 'Restore attempt complete.'"
pause
goto menu_bloatware_remover

:bloat_08
echo Running 1-Click Safe Debloat...
powershell -NoProfile -ExecutionPolicy Bypass -Command "
$safe = @('*Xbox*','*MicrosoftSolitaireCollection*','*BingWeather*','*BingNews*','*ZuneMusic*','*ZuneVideo*','*GetHelp*','*Getstarted*','*Messaging*','*Microsoft3DViewer*','*MixedReality*','*Office.Sway*','*People*','*Print3D*','*SkypeApp*')
foreach($pkg in $safe){
    Get-AppxPackage $pkg | Remove-AppxPackage -ErrorAction SilentlyContinue
    Write-Host ('Removed: ' + $pkg)
}
Write-Host 'Safe Debloat Complete!'
"
pause
goto menu_bloatware_remover

:: ============================================================
:: MENU: HARDWARE DIAGNOSTICS
:: ============================================================
:menu_hardware_diagnostics
set "BACK_MENU=main"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          HARDWARE DIAGNOSTICS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] CPU Info and Health%C_RESET%
echo %C_GREEN%  [02] RAM Test (Windows Memory Diagnostic)%C_RESET%
echo %C_GREEN%  [03] Disk SMART Status%C_RESET%
echo %C_GREEN%  [04] Battery Health%C_RESET%
echo %C_GREEN%  [05] GPU Info%C_RESET%
echo %C_GREEN%  [06] Temperature Check (via WMI)%C_RESET%
echo %C_GREEN%  [07] Power Supply / Power Plan Check%C_RESET%
echo %C_GREEN%  [08] Full Hardware Report%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto hwdiag_01
if "%c%"=="1"  goto hwdiag_01
if "%c%"=="02" goto hwdiag_02
if "%c%"=="2"  goto hwdiag_02
if "%c%"=="03" goto hwdiag_03
if "%c%"=="3"  goto hwdiag_03
if "%c%"=="04" goto hwdiag_04
if "%c%"=="4"  goto hwdiag_04
if "%c%"=="05" goto hwdiag_05
if "%c%"=="5"  goto hwdiag_05
if "%c%"=="06" goto hwdiag_06
if "%c%"=="6"  goto hwdiag_06
if "%c%"=="07" goto hwdiag_07
if "%c%"=="7"  goto hwdiag_07
if "%c%"=="08" goto hwdiag_08
if "%c%"=="8"  goto hwdiag_08
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_hardware_diagnostics

:hwdiag_01
cls
echo === CPU INFO ===
powershell -NoProfile -Command "Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,LoadPercentage,Status | Format-List"
pause
goto menu_hardware_diagnostics

:hwdiag_02
echo Launching Windows Memory Diagnostic (will require restart)...
mdsched.exe
goto menu_hardware_diagnostics

:hwdiag_03
cls
echo === DISK SMART STATUS ===
powershell -NoProfile -Command "Get-Disk | Format-Table Number,FriendlyName,OperationalStatus,HealthStatus,Size -AutoSize; Get-PhysicalDisk | Select-Object DeviceId,FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize"
pause
goto menu_hardware_diagnostics

:hwdiag_04
cls
echo === BATTERY HEALTH ===
powercfg /batteryreport /output "%USERPROFILE%\Desktop\battery_report.html" 2>nul
if exist "%USERPROFILE%\Desktop\battery_report.html" (
    echo Battery report generated on Desktop.
    start "" "%USERPROFILE%\Desktop\battery_report.html"
) else (
    echo No battery detected or battery report failed. This may be a desktop PC.
)
pause
goto menu_hardware_diagnostics

:hwdiag_05
cls
echo === GPU INFO ===
powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Select-Object Caption,AdapterRAM,CurrentRefreshRate,VideoModeDescription,Status | Format-List"
pause
goto menu_hardware_diagnostics

:hwdiag_06
cls
echo === TEMPERATURE CHECK ===
powershell -NoProfile -Command "
try {
    $temps = Get-CimInstance MSAcpi_ThermalZoneTemperature -Namespace root/wmi -ErrorAction Stop
    foreach($t in $temps){ Write-Host ('Zone: ' + $t.InstanceName + ' | Temp: ' + [math]::Round(($t.CurrentTemperature/10 - 273.15),1) + ' C') }
} catch {
    Write-Host 'WMI temperature sensors not available on this system.'
    Write-Host 'Try HWInfo64 or HWMonitor for detailed temperature readings.'
}
"
pause
goto menu_hardware_diagnostics

:hwdiag_07
cls
echo === POWER PLAN / POWER SUPPLY CHECK ===
powercfg /list
echo.
echo === Active Power Plan ===
powercfg /getactivescheme
echo.
echo === System Sleep Settings ===
powercfg /query
pause
goto menu_hardware_diagnostics

:hwdiag_08
cls
set "HWREP=%USERPROFILE%\Desktop\HW_Report_%date:~-4,4%%date:~-7,2%%date:~0,2%.txt"
echo Generating Full Hardware Report...
(
echo ===== HARDWARE DIAGNOSTICS REPORT =====
echo Generated: %date% %time%
echo.
echo === CPU ===
powershell -NoProfile -Command "Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,Status | Format-List"
echo.
echo === MEMORY ===
powershell -NoProfile -Command "Get-CimInstance Win32_PhysicalMemory | Select-Object Tag,Capacity,Speed,Manufacturer,MemoryType | Format-Table -AutoSize"
echo.
echo === DISKS ===
powershell -NoProfile -Command "Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,Size | Format-Table -AutoSize"
echo.
echo === GPU ===
powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Select-Object Caption,AdapterRAM,Status | Format-List"
echo.
echo === MOTHERBOARD ===
powershell -NoProfile -Command "Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer,Product,SerialNumber | Format-List"
) > "%HWREP%"
echo Report saved to: %HWREP%
start "" notepad "%HWREP%"
pause
goto menu_hardware_diagnostics

:: ============================================================
:: MENU: SOFTWARE DIAGNOSTICS
:: ============================================================
:menu_software_diagnostics
set "BACK_MENU=main"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          SOFTWARE DIAGNOSTICS%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Check .NET Framework Versions%C_RESET%
echo %C_GREEN%  [02] Check VC++ Redistributables%C_RESET%
echo %C_GREEN%  [03] Check DirectX Version%C_RESET%
echo %C_GREEN%  [04] App Crash History (Event Log)%C_RESET%
echo %C_GREEN%  [05] Missing DLL Check (SFC)%C_RESET%
echo %C_GREEN%  [06] Windows Store App Health%C_RESET%
echo %C_GREEN%  [07] Software Conflict Check%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto swdiag_01
if "%c%"=="1"  goto swdiag_01
if "%c%"=="02" goto swdiag_02
if "%c%"=="2"  goto swdiag_02
if "%c%"=="03" goto swdiag_03
if "%c%"=="3"  goto swdiag_03
if "%c%"=="04" goto swdiag_04
if "%c%"=="4"  goto swdiag_04
if "%c%"=="05" goto swdiag_05
if "%c%"=="5"  goto swdiag_05
if "%c%"=="06" goto swdiag_06
if "%c%"=="6"  goto swdiag_06
if "%c%"=="07" goto swdiag_07
if "%c%"=="7"  goto swdiag_07
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_software_diagnostics

:swdiag_01
cls
echo === .NET FRAMEWORK VERSIONS INSTALLED ===
powershell -NoProfile -Command "
$netVersions = @()
$ndpPath = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP'
if(Test-Path $ndpPath){ Get-ChildItem $ndpPath -Recurse | Get-ItemProperty -Name Version,Release -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq 'Full' -or $_.PSChildName -match 'v[0-9]'} | Select-Object PSChildName,Version | Format-Table -AutoSize }
Write-Host ''
Write-Host '=== .NET Core / .NET 5+ ==='
dotnet --list-runtimes 2>nul
"
pause
goto menu_software_diagnostics

:swdiag_02
cls
echo === VISUAL C++ REDISTRIBUTABLES ===
powershell -NoProfile -Command "
Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
Where-Object { $_.DisplayName -like '*Visual C++*' } |
Select-Object DisplayName,DisplayVersion,Publisher |
Sort-Object DisplayName |
Format-Table -AutoSize
"
pause
goto menu_software_diagnostics

:swdiag_03
cls
echo === DIRECTX DIAGNOSTIC ===
echo Launching DirectX Diagnostic Tool...
dxdiag /t "%USERPROFILE%\Desktop\dxdiag_report.txt"
timeout /t 5 /nobreak >nul
if exist "%USERPROFILE%\Desktop\dxdiag_report.txt" (
    start "" notepad "%USERPROFILE%\Desktop\dxdiag_report.txt"
    echo Report saved to Desktop: dxdiag_report.txt
) else (
    start "" dxdiag
)
pause
goto menu_software_diagnostics

:swdiag_04
cls
echo === APP CRASH HISTORY (Last 20 Application Errors) ===
powershell -NoProfile -Command "Get-WinEvent -LogName Application -ErrorAction SilentlyContinue | Where-Object {$_.LevelDisplayName -eq 'Error'} | Select-Object -First 20 TimeCreated,Id,Message | Format-List"
pause
goto menu_software_diagnostics

:swdiag_05
cls
echo === MISSING DLL / SYSTEM FILE CHECK (SFC) ===
echo Running System File Checker (sfc /verifyonly)...
echo This checks for integrity violations without fixing.
echo.
sfc /verifyonly
echo.
echo If violations found, run SFC /SCANNOW from an admin prompt to repair.
pause
goto menu_software_diagnostics

:swdiag_06
cls
echo === WINDOWS STORE APP HEALTH ===
powershell -NoProfile -Command "
Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.PackageUserInformation -match 'Error' } | Select-Object Name,Version | Format-Table -AutoSize
Write-Host 'Checking for broken packages...'
Get-AppxPackage -AllUsers | ForEach-Object { $status = $_.Status; if($status -ne 'Ok'){ Write-Host ('BROKEN: ' + $_.Name + ' Status: ' + $status) } }
Write-Host 'App health check complete.'
"
pause
goto menu_software_diagnostics

:swdiag_07
cls
echo === SOFTWARE CONFLICT CHECK ===
echo Checking for known conflict indicators...
echo.
powershell -NoProfile -Command "
$conflicts = @()
$procs = Get-Process -ErrorAction SilentlyContinue
$antivirus = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
Write-Host '=== Antivirus Products Installed ==='
$antivirus | Select-Object displayName,productState | Format-Table -AutoSize
Write-Host '=== Multiple Security Tools (potential conflicts) ==='
$secTools = $procs | Where-Object { $_.Name -match 'avast|avg|mcafee|norton|kaspersky|malwarebytes|defender|bitdefender' }
$secTools | Select-Object Name,Id,CPU | Format-Table -AutoSize
Write-Host '=== System Resource Hogs ==='
$procs | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name,@{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize
"
pause
goto menu_software_diagnostics

:: ============================================================
:: MENU: OFFLINE RECOVERY CENTER
:: ============================================================
:menu_offline_recovery
set "BACK_MENU=main"
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          OFFLINE RECOVERY CENTER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Bootrec MBR Fix (requires WinRE/Admin)%C_RESET%
echo %C_GREEN%  [02] Bootrec Boot Rebuild%C_RESET%
echo %C_GREEN%  [03] BCDEdit Repair Info%C_RESET%
echo %C_GREEN%  [04] SFC Offline Scan (run SFC /SCANNOW)%C_RESET%
echo %C_GREEN%  [05] DISM Restore Health%C_RESET%
echo %C_GREEN%  [06] Create Recovery USB Guide%C_RESET%
echo %C_GREEN%  [07] Access Windows Recovery Environment (WinRE)%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto recovery_01
if "%c%"=="1"  goto recovery_01
if "%c%"=="02" goto recovery_02
if "%c%"=="2"  goto recovery_02
if "%c%"=="03" goto recovery_03
if "%c%"=="3"  goto recovery_03
if "%c%"=="04" goto recovery_04
if "%c%"=="4"  goto recovery_04
if "%c%"=="05" goto recovery_05
if "%c%"=="5"  goto recovery_05
if "%c%"=="06" goto recovery_06
if "%c%"=="6"  goto recovery_06
if "%c%"=="07" goto recovery_07
if "%c%"=="7"  goto recovery_07
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_offline_recovery

:recovery_01
echo Running Bootrec /fixmbr (requires Admin)...
bootrec /fixmbr
pause
goto menu_offline_recovery

:recovery_02
echo Running Bootrec /rebuildbcd (requires Admin)...
bootrec /scanos
bootrec /rebuildbcd
pause
goto menu_offline_recovery

:recovery_03
cls
echo === BCDEDIT CURRENT BOOT CONFIG ===
bcdedit /enum all
pause
goto menu_offline_recovery

:recovery_04
echo Running System File Checker (SFC /SCANNOW)...
echo This requires Administrator privileges. May take 10-15 minutes.
sfc /scannow
pause
goto menu_offline_recovery

:recovery_05
echo Running DISM RestoreHealth...
echo This downloads repair files from Windows Update. Internet required.
echo May take 15-30 minutes.
dism /Online /Cleanup-Image /RestoreHealth
pause
goto menu_offline_recovery

:recovery_06
cls
echo %C_CYAN%=== CREATE RECOVERY USB GUIDE ===%C_RESET%
echo.
echo Method 1: Windows Built-in Recovery Drive
echo   1. Search: Recovery Drive in Start Menu
echo   2. Check "Back up system files to the recovery drive"
echo   3. Connect USB (8GB minimum), click Next, Create
echo.
echo Method 2: Windows Media Creation Tool
echo   1. Go to microsoft.com/software-download/windows11
echo   2. Download Media Creation Tool
echo   3. Run and choose "Create installation media for another PC"
echo   4. Select USB flash drive
echo.
echo Method 3: Rufus with Windows ISO
echo   1. Download Rufus from rufus.ie
echo   2. Download Windows ISO from Microsoft
echo   3. Select ISO in Rufus, click START
echo.
pause
goto menu_offline_recovery

:recovery_07
echo Rebooting to Windows Recovery Environment...
echo WARNING: System will restart in 15 seconds!
echo Press Ctrl+C to cancel.
timeout /t 15
shutdown /r /o /f /t 0
goto menu_offline_recovery

:: ============================================================
:: MENU: STARTUP OPTIMIZER
:: ============================================================
:menu_startup_optimizer
set "BACK_MENU=main"
cls
color 0E
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          STARTUP OPTIMIZER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] View Startup Programs (Registry)%C_RESET%
echo %C_GREEN%  [02] Disable Startup App%C_RESET%
echo %C_GREEN%  [03] Enable Startup App%C_RESET%
echo %C_GREEN%  [04] View Startup Impact (via PowerShell)%C_RESET%
echo %C_GREEN%  [05] Startup Service Manager%C_RESET%
echo %C_GREEN%  [06] Open Task Manager Startup Tab%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto startup_01
if "%c%"=="1"  goto startup_01
if "%c%"=="02" goto startup_02
if "%c%"=="2"  goto startup_02
if "%c%"=="03" goto startup_03
if "%c%"=="3"  goto startup_03
if "%c%"=="04" goto startup_04
if "%c%"=="4"  goto startup_04
if "%c%"=="05" goto startup_05
if "%c%"=="5"  goto startup_05
if "%c%"=="06" goto startup_06
if "%c%"=="6"  goto startup_06
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_startup_optimizer

:startup_01
cls
echo === STARTUP PROGRAMS ===
echo.
echo -- HKCU Run --
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" 2>nul
echo.
echo -- HKLM Run --
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" 2>nul
echo.
echo -- Startup Folder (User) --
dir "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup" /b 2>nul
echo.
echo -- Startup Folder (All Users) --
dir "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup" /b 2>nul
pause
goto menu_startup_optimizer

:startup_02
echo Enter the registry value name to DISABLE from HKCU\Run:
echo (This removes it from startup. Run 'View Startup Programs' first to see names.)
set "SNAME=" & set /p SNAME=  Name: 
if "%SNAME%"=="" goto menu_startup_optimizer
echo Backing up value before removal...
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%SNAME%" 2>nul
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%SNAME%" /f 2>nul
echo Done. '%SNAME%' removed from startup (HKCU).
pause
goto menu_startup_optimizer

:startup_03
echo Enter Name and Command to ADD to startup:
set "SNAME=" & set /p SNAME=  Display Name: 
if "%SNAME%"=="" goto menu_startup_optimizer
set "SCMD=" & set /p SCMD=  Full path to exe (e.g. C:\Program Files\App\app.exe): 
if "%SCMD%"=="" goto menu_startup_optimizer
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%SNAME%" /t REG_SZ /d "\"%SCMD%\"" /f
echo '%SNAME%' added to startup.
pause
goto menu_startup_optimizer

:startup_04
cls
echo === STARTUP IMPACT (via CIM) ===
powershell -NoProfile -Command "
Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User | Format-Table -AutoSize
"
pause
goto menu_startup_optimizer

:startup_05
cls
echo === STARTUP SERVICES (Auto-start) ===
powershell -NoProfile -Command "Get-Service | Where-Object {$_.StartType -eq 'Automatic'} | Select-Object Name,DisplayName,Status | Format-Table -AutoSize"
echo.
echo To disable a service: sc config ServiceName start= disabled
echo To enable a service:  sc config ServiceName start= auto
pause
goto menu_startup_optimizer

:startup_06
start "" taskmgr.exe /7
timeout /t 2 /nobreak >nul
goto menu_startup_optimizer

:: ============================================================
:: MENU: LICENSE VAULT
:: ============================================================
:menu_license_vault
set "BACK_MENU=main"
cls
color 0A
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          LICENSE VAULT%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Show Windows Product Key%C_RESET%
echo %C_GREEN%  [02] Show Office Product Key (if stored)%C_RESET%
echo %C_GREEN%  [03] Export All License Keys to Desktop%C_RESET%
echo %C_GREEN%  [04] View BIOS / UEFI Embedded Key%C_RESET%
echo %C_GREEN%  [05] Show Installed Software Keys%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto vault_01
if "%c%"=="1"  goto vault_01
if "%c%"=="02" goto vault_02
if "%c%"=="2"  goto vault_02
if "%c%"=="03" goto vault_03
if "%c%"=="3"  goto vault_03
if "%c%"=="04" goto vault_04
if "%c%"=="4"  goto vault_04
if "%c%"=="05" goto vault_05
if "%c%"=="5"  goto vault_05
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_license_vault

:vault_01
cls
echo === WINDOWS PRODUCT KEY ===
echo.
powershell -NoProfile -Command "
$key = (Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey
if($key){ Write-Host 'OEM Key (BIOS embedded): ' $key }
else { Write-Host 'No OEM key found in BIOS.' }
$key2 = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DigitalProductId
if($key2){ Write-Host 'DigitalProductId is present (Digital License - no visible key)' }
"
echo.
echo Note: Digital Licenses are tied to hardware. No key is shown.
echo Use 'slmgr /xpr' to confirm activation status.
slmgr /xpr
pause
goto menu_license_vault

:vault_02
cls
echo === OFFICE PRODUCT KEY ===
echo.
powershell -NoProfile -Command "
$officeKeys = @()
$paths = @('HKLM:\SOFTWARE\Microsoft\Office','HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office')
foreach($p in $paths){
    if(Test-Path $p){
        Get-ChildItem $p -ErrorAction SilentlyContinue | ForEach-Object {
            $child = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if($child.ProductName){ Write-Host ('Office Product: ' + $child.ProductName) }
        }
    }
}
Write-Host ''
Write-Host 'Note: Office 365/Microsoft 365 uses account-based licensing.'
Write-Host 'Log into office.com with your Microsoft account to manage.'
"
pause
goto menu_license_vault

:vault_03
set "KEYFILE=%USERPROFILE%\Desktop\License_Keys_%date:~-4,4%%date:~-7,2%%date:~0,2%.txt"
echo Exporting license keys to Desktop...
(
echo ===== LICENSE KEY EXPORT =====
echo Generated: %date% %time%
echo.
echo === WINDOWS KEY ===
powershell -NoProfile -Command "$k=(Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey; if($k){Write-Host $k}else{Write-Host 'Digital License (no key)' }"
echo.
echo === WINDOWS ACTIVATION STATUS ===
slmgr /dli
echo.
echo === INSTALLED SOFTWARE (from registry) ===
powershell -NoProfile -Command "Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object DisplayName | Select-Object DisplayName,DisplayVersion,Publisher | Sort-Object DisplayName | Format-Table -AutoSize"
) > "%KEYFILE%"
echo Keys exported to: %KEYFILE%
start "" notepad "%KEYFILE%"
pause
goto menu_license_vault

:vault_04
cls
echo === BIOS / UEFI EMBEDDED PRODUCT KEY ===
echo.
powershell -NoProfile -Command "
$key = (Get-CimInstance SoftwareLicensingService -ErrorAction SilentlyContinue).OA3xOriginalProductKey
if($key -and $key.Length -gt 5){ Write-Host 'BIOS/UEFI OEM Key: ' $key }
else { Write-Host 'No BIOS/UEFI key found. This system may use a Digital License.' }
Write-Host ''
$biosInfo = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
Write-Host ('BIOS Manufacturer: ' + $biosInfo.Manufacturer)
Write-Host ('BIOS Version: ' + $biosInfo.SMBIOSBIOSVersion)
Write-Host ('BIOS Serial: ' + $biosInfo.SerialNumber)
"
pause
goto menu_license_vault

:vault_05
cls
echo === INSTALLED SOFTWARE KEYS (Registry scan) ===
echo.
powershell -NoProfile -Command "
Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
Where-Object { $_.DisplayName -and $_.DisplayVersion } |
Select-Object DisplayName,DisplayVersion,Publisher |
Sort-Object DisplayName |
Format-Table -AutoSize
"
pause
goto menu_license_vault

:: ============================================================
:: MENU: BSOD CRASH ANALYZER
:: ============================================================
:menu_bsod_analyzer
set "BACK_MENU=main"
cls
color 0C
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          BSOD CRASH ANALYZER%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] View Latest BSOD Info (Event Log)%C_RESET%
echo %C_GREEN%  [02] View All Minidumps%C_RESET%
echo %C_GREEN%  [03] Open Event Viewer Crash Logs%C_RESET%
echo %C_GREEN%  [04] Check System Error History%C_RESET%
echo %C_GREEN%  [05] Open BlueScreenView (if available)%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto bsod_01
if "%c%"=="1"  goto bsod_01
if "%c%"=="02" goto bsod_02
if "%c%"=="2"  goto bsod_02
if "%c%"=="03" goto bsod_03
if "%c%"=="3"  goto bsod_03
if "%c%"=="04" goto bsod_04
if "%c%"=="4"  goto bsod_04
if "%c%"=="05" goto bsod_05
if "%c%"=="5"  goto bsod_05
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_bsod_analyzer

:bsod_01
cls
echo === LATEST BSOD / BUGCHECK EVENTS ===
powershell -NoProfile -Command "
try {
    $events = Get-WinEvent -LogName System -ErrorAction Stop | Where-Object {$_.Id -eq 41 -or $_.Id -eq 1001 -or $_.Id -eq 6008}
    $events | Select-Object -First 10 TimeCreated,Id,Message | Format-List
} catch {
    Write-Host 'Could not read event log. Try running as Administrator.'
}
"
pause
goto menu_bsod_analyzer

:bsod_02
echo === MINIDUMP FILES ===
if exist "C:\Windows\Minidump" (
    dir "C:\Windows\Minidump" /b /od 2>nul
    echo.
    echo Minidump location: C:\Windows\Minidump
    echo Use WinDbg or BlueScreenView to analyze .dmp files.
    start "" explorer "C:\Windows\Minidump"
) else (
    echo No Minidump folder found. No crashes recorded, or dumps are disabled.
    echo To enable: Control Panel -^> System -^> Advanced -^> Startup and Recovery -^> Small memory dump
)
pause
goto menu_bsod_analyzer

:bsod_03
eventvwr.msc
goto menu_bsod_analyzer

:bsod_04
cls
echo === SYSTEM ERROR HISTORY (Last 15 Critical/Error Events) ===
powershell -NoProfile -Command "
Get-WinEvent -LogName System -ErrorAction SilentlyContinue | 
Where-Object {$_.Level -le 2} | 
Select-Object -First 15 TimeCreated,LevelDisplayName,Id,Message | 
Format-List
"
pause
goto menu_bsod_analyzer

:bsod_05
set "BSV1=%ProgramFiles%\NirSoft\BlueScreenView\BlueScreenView.exe"
set "BSV2=%ProgramFiles(x86)%\NirSoft\BlueScreenView\BlueScreenView.exe"
set "BSV3=%~dp0Tools\BlueScreenView.exe"
if exist "%BSV1%" (
    start "" "%BSV1%"
) else if exist "%BSV2%" (
    start "" "%BSV2%"
) else if exist "%BSV3%" (
    start "" "%BSV3%"
) else (
    echo BlueScreenView not found.
    echo Download from: https://www.nirsoft.net/utils/blue_screen_view.html
    echo Place BlueScreenView.exe in the Tools\ subfolder of this toolkit.
    echo.
    echo As alternative, opening Event Viewer for crash analysis...
    eventvwr.msc
)
pause
goto menu_bsod_analyzer

:: ============================================================
:: MENU: CPU/GPU TEMP MONITOR
:: ============================================================
:menu_temp_monitor
set "BACK_MENU=main"
cls
color 0B
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_MAGENTA%                          CPU / GPU TEMPERATURE MONITOR%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Check CPU Temperature (via WMI/PowerShell)%C_RESET%
echo %C_GREEN%  [02] Check Battery Temperature%C_RESET%
echo %C_GREEN%  [03] HWInfo64 (if available)%C_RESET%
echo %C_GREEN%  [04] System Health Overview%C_RESET%
echo.
echo %C_YELLOW%  [99] Back to Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto temp_01
if "%c%"=="1"  goto temp_01
if "%c%"=="02" goto temp_02
if "%c%"=="2"  goto temp_02
if "%c%"=="03" goto temp_03
if "%c%"=="3"  goto temp_03
if "%c%"=="04" goto temp_04
if "%c%"=="4"  goto temp_04
if "%c%"=="99" goto main
if "%c%"=="00" goto main
goto menu_temp_monitor

:temp_01
cls
echo === CPU TEMPERATURE CHECK ===
echo.
powershell -NoProfile -Command "
Write-Host 'Attempting WMI thermal zone query...'
Write-Host ''
try {
    $temps = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
    foreach ($t in $temps) {
        $celsius = [math]::Round(($t.CurrentTemperature / 10) - 273.15, 1)
        Write-Host ('Thermal Zone: ' + $t.InstanceName + ' -> ' + $celsius + ' C')
    }
} catch {
    Write-Host 'MSAcpi_ThermalZoneTemperature not available on this hardware.'
    Write-Host ''
    Write-Host 'Falling back to processor load info:'
    Get-CimInstance Win32_Processor | Select-Object Name,LoadPercentage,CurrentClockSpeed | Format-Table -AutoSize
    Write-Host ''
    Write-Host 'For actual temperatures, install:'
    Write-Host '  - HWMonitor (CPUID): https://www.cpuid.com/softwares/hwmonitor.html'
    Write-Host '  - HWInfo64: https://www.hwinfo.com'
    Write-Host '  - Core Temp: https://www.alcpu.com/CoreTemp/'
}
"
pause
goto menu_temp_monitor

:temp_02
cls
echo === BATTERY TEMPERATURE ===
echo.
powershell -NoProfile -Command "
$bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
if($bat){
    Write-Host ('Battery Status: ' + $bat.BatteryStatus)
    Write-Host ('Battery Name: ' + $bat.Name)
    Write-Host ('Estimated Charge: ' + $bat.EstimatedChargeRemaining + '%')
    Write-Host ''
    Write-Host 'Note: Windows WMI does not expose battery temperature directly.'
    Write-Host 'For battery temp, use HWInfo64 or manufacturer diagnostics.'
} else {
    Write-Host 'No battery detected. This may be a desktop system.'
}
"
pause
goto menu_temp_monitor

:temp_03
set "HWI1=%ProgramFiles%\HWiNFO64\HWiNFO64.exe"
set "HWI2=%ProgramFiles(x86)%\HWiNFO32\HWiNFO32.exe"
set "HWI3=%~dp0Tools\HWiNFO64.exe"
set "HWI4=%~dp0Tools\HWiNFO32.exe"
if exist "%HWI1%" (
    start "" "%HWI1%"
) else if exist "%HWI2%" (
    start "" "%HWI2%"
) else if exist "%HWI3%" (
    start "" "%HWI3%"
) else if exist "%HWI4%" (
    start "" "%HWI4%"
) else (
    echo HWInfo64 not found.
    echo Download from: https://www.hwinfo.com/download/
    echo Place HWiNFO64.exe in the Tools\ subfolder for quick access.
)
pause
goto menu_temp_monitor

:temp_04
cls
echo === SYSTEM HEALTH OVERVIEW ===
echo.
powershell -NoProfile -Command "
Write-Host '=== CPU ===' -ForegroundColor Cyan
Get-CimInstance Win32_Processor | Select-Object Name,LoadPercentage,CurrentClockSpeed,NumberOfCores | Format-Table -AutoSize

Write-Host '=== MEMORY ===' -ForegroundColor Cyan
$os = Get-CimInstance Win32_OperatingSystem
$totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeRAM  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedRAM  = [math]::Round($totalRAM - $freeRAM, 2)
Write-Host ('Total RAM: ' + $totalRAM + ' GB  |  Used: ' + $usedRAM + ' GB  |  Free: ' + $freeRAM + ' GB')

Write-Host ''
Write-Host '=== DISK ===' -ForegroundColor Cyan
Get-PSDrive -PSProvider FileSystem | Select-Object Name,@{N='Used(GB)';E={[math]::Round(($_.Used/1GB),1)}},@{N='Free(GB)';E={[math]::Round(($_.Free/1GB),1)}} | Format-Table -AutoSize

Write-Host '=== GPU ===' -ForegroundColor Cyan
Get-CimInstance Win32_VideoController | Select-Object Caption,@{N='VRAM(GB)';E={[math]::Round($_.AdapterRAM/1GB,1)}},Status | Format-Table -AutoSize
"
pause
goto menu_temp_monitor

:: ============================================================
:: DISK SPEED BENCHMARK
:: ============================================================
:menu_disk_benchmark
set "BACK_MENU=main"
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  DISK SPEED BENCHMARK
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] WinSAT Disk Assessment           [02] Sequential Read Test              [03] Random Read Test                  %C_RESET%
echo %C_GREEN%  [04] Full Disk Performance Report     [05] Compare with Baseline             %C_RESET%
echo.
echo %C_YELLOW%  [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto disk_bench_winsat
if "%c%"=="1" goto disk_bench_winsat
if "%c%"=="02" goto disk_bench_seq_read
if "%c%"=="2" goto disk_bench_seq_read
if "%c%"=="03" goto disk_bench_rand_read
if "%c%"=="3" goto disk_bench_rand_read
if "%c%"=="04" goto disk_bench_full_report
if "%c%"=="4" goto disk_bench_full_report
if "%c%"=="05" goto disk_bench_compare
if "%c%"=="5" goto disk_bench_compare
if "%c%"=="99" goto main
goto menu_disk_benchmark

:disk_bench_winsat
cls
echo %C_CYAN%Running WinSAT Disk Assessment on C: drive...%C_RESET%
echo.
winsat disk -seq -read -drive c
echo.
pause
goto menu_disk_benchmark

:disk_bench_seq_read
cls
echo %C_CYAN%Sequential Read Test - Measuring throughput with PowerShell...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$file='C:\Windows\System32\ntoskrnl.exe'; $buf=New-Object byte[] 67108864; $sw=[System.Diagnostics.Stopwatch]::StartNew(); $fs=[IO.File]::OpenRead($file); $read=0; while(($n=$fs.Read($buf,0,$buf.Length)) -gt 0){$read+=$n}; $fs.Close(); $sw.Stop(); $mb=[math]::Round($read/1MB,2); $secs=$sw.Elapsed.TotalSeconds; $speed=[math]::Round($mb/$secs,2); Write-Host ('Read: ' + $mb + ' MB in ' + [math]::Round($secs,3) + ' sec = ' + $speed + ' MB/s')"
echo.
echo %C_YELLOW%For larger sequential test, use WinSAT (option 01) or CrystalDiskMark.%C_RESET%
pause
goto menu_disk_benchmark

:disk_bench_rand_read
cls
echo %C_CYAN%Random Read Test - Measuring random access performance...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$rng=[Random]::new(); $disk=(Get-CimInstance Win32_LogicalDisk -Filter 'DeviceID=''C:'''); $sizeMB=[math]::Floor($disk.Size/1MB); $reads=100; $buf=New-Object byte[] 4096; $sw=[System.Diagnostics.Stopwatch]::StartNew(); $total=0; try{$fs=[IO.File]::OpenRead('C:\Windows\System32\ntoskrnl.exe'); for($i=0;$i -lt $reads;$i++){$pos=[long]($rng.NextDouble()*($fs.Length-4096)); $fs.Seek($pos,[IO.SeekOrigin]::Begin)|Out-Null; $n=$fs.Read($buf,0,4096); $total+=$n}; $fs.Close()}catch{}; $sw.Stop(); Write-Host ('Random reads: ' + $reads + ' x 4KB in ' + [math]::Round($sw.Elapsed.TotalMilliseconds,1) + ' ms'); Write-Host ('Average latency: ' + [math]::Round($sw.Elapsed.TotalMilliseconds/$reads,2) + ' ms per read')"
echo.
pause
goto menu_disk_benchmark

:disk_bench_full_report
cls
echo %C_CYAN%Full Disk Performance Report - Running WinSAT formal assessment...%C_RESET%
echo.
winsat disk -drive c
echo.
echo %C_GREEN%WinSAT formal disk assessment complete. Results stored in C:\Windows\Performance\WinSAT\DataStore\%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-CimInstance -Namespace root\cimv2 -ClassName Win32_DiskDrive | Select-Object Model,@{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}},Status,MediaType | Format-Table -AutoSize; Write-Host ''; Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,VolumeName,@{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,2)}},@{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}} | Format-Table -AutoSize"
pause
goto menu_disk_benchmark

:disk_bench_compare
cls
echo %C_CYAN%Comparing current disk performance with WinSAT baseline...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$winsatPath='C:\Windows\Performance\WinSAT\DataStore'; if(Test-Path $winsatPath){$files=Get-ChildItem $winsatPath -Filter '*.xml' | Sort-Object LastWriteTime -Descending; Write-Host ('Found ' + $files.Count + ' WinSAT result files.'); $files | Select-Object -First 5 | ForEach-Object {Write-Host ('  ' + $_.Name + ' - ' + $_.LastWriteTime)}} else {Write-Host 'No WinSAT data store found. Run option 04 first.'}; Write-Host ''; Write-Host 'Running fresh winsat quick:'; winsat quick 2>&1 | Select-Object -Last 10 | ForEach-Object {Write-Host $_}"
echo.
pause
goto menu_disk_benchmark

:: ============================================================
:: DNS FLUSH AND NETWORK REPAIR
:: ============================================================
:menu_dns_repair
set "BACK_MENU=main"
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  DNS FLUSH AND NETWORK REPAIR
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Flush DNS Cache                  [02] Reset Winsock                     [03] Reset TCP/IP Stack                %C_RESET%
echo %C_GREEN%  [04] Set Google DNS (8.8.8.8)         [05] Set Cloudflare DNS (1.1.1.1)      [06] Restore Automatic DNS             %C_RESET%
echo %C_GREEN%  [07] DNS Lookup Test                  %C_RESET%
echo.
echo %C_YELLOW%  [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto dns_flush
if "%c%"=="1" goto dns_flush
if "%c%"=="02" goto dns_winsock_reset
if "%c%"=="2" goto dns_winsock_reset
if "%c%"=="03" goto dns_tcpip_reset
if "%c%"=="3" goto dns_tcpip_reset
if "%c%"=="04" goto dns_set_google
if "%c%"=="4" goto dns_set_google
if "%c%"=="05" goto dns_set_cloudflare
if "%c%"=="5" goto dns_set_cloudflare
if "%c%"=="06" goto dns_restore_auto
if "%c%"=="6" goto dns_restore_auto
if "%c%"=="07" goto dns_lookup_test
if "%c%"=="7" goto dns_lookup_test
if "%c%"=="99" goto main
goto menu_dns_repair

:dns_flush
cls
echo %C_CYAN%Flushing DNS Cache...%C_RESET%
ipconfig /flushdns
echo.
echo %C_GREEN%DNS Cache flushed successfully.%C_RESET%
pause
goto menu_dns_repair

:dns_winsock_reset
cls
echo %C_CYAN%Resetting Winsock...%C_RESET%
netsh winsock reset
echo.
echo %C_YELLOW%Winsock reset complete. A restart may be required for full effect.%C_RESET%
pause
goto menu_dns_repair

:dns_tcpip_reset
cls
echo %C_CYAN%Resetting TCP/IP Stack...%C_RESET%
netsh int ip reset
netsh int ipv6 reset
ipconfig /flushdns
ipconfig /release
ipconfig /renew
echo.
echo %C_GREEN%TCP/IP stack reset complete. A restart is recommended.%C_RESET%
pause
goto menu_dns_repair

:dns_set_google
cls
echo %C_CYAN%Setting DNS to Google (8.8.8.8 / 8.8.4.4) on all active adapters...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object {$name=$_.Name; try{Set-DnsClientServerAddress -InterfaceAlias $name -ServerAddresses ('8.8.8.8','8.8.4.4'); Write-Host ('Set Google DNS on: ' + $name)}catch{Write-Host ('Failed on: ' + $name + ' - ' + $_.Exception.Message)}}"
ipconfig /flushdns
echo.
echo %C_GREEN%Google DNS applied.%C_RESET%
pause
goto menu_dns_repair

:dns_set_cloudflare
cls
echo %C_CYAN%Setting DNS to Cloudflare (1.1.1.1 / 1.0.0.1) on all active adapters...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object {$name=$_.Name; try{Set-DnsClientServerAddress -InterfaceAlias $name -ServerAddresses ('1.1.1.1','1.0.0.1'); Write-Host ('Set Cloudflare DNS on: ' + $name)}catch{Write-Host ('Failed on: ' + $name + ' - ' + $_.Exception.Message)}}"
ipconfig /flushdns
echo.
echo %C_GREEN%Cloudflare DNS applied.%C_RESET%
pause
goto menu_dns_repair

:dns_restore_auto
cls
echo %C_CYAN%Restoring automatic DNS (DHCP) on all active adapters...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object {$name=$_.Name; try{Set-DnsClientServerAddress -InterfaceAlias $name -ResetServerAddresses; Write-Host ('Restored auto DNS on: ' + $name)}catch{Write-Host ('Failed on: ' + $name + ' - ' + $_.Exception.Message)}}"
ipconfig /flushdns
echo.
echo %C_GREEN%Automatic DNS (DHCP) restored.%C_RESET%
pause
goto menu_dns_repair

:dns_lookup_test
cls
echo %C_CYAN%DNS Lookup Test%C_RESET%
echo.
set "dns_host=" & set /p dns_host=Enter hostname to resolve (e.g. google.com) or press ENTER for google.com: 
if "%dns_host%"=="" set "dns_host=google.com"
echo.
echo %C_YELLOW%Resolving: %dns_host%%C_RESET%
nslookup %dns_host%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$h=$env:dns_host; if(-not $h){$h='google.com'}; try{$r=[System.Net.Dns]::GetHostAddresses($h); Write-Host '.NET Resolution:'; $r | ForEach-Object {Write-Host ('  ' + $_.ToString())}}catch{Write-Host 'DNS resolution failed: ' + $_.Exception.Message}"
echo.
pause
goto menu_dns_repair

:: ============================================================
:: HOSTS FILE EDITOR
:: ============================================================
:menu_restore_manager
set "BACK_MENU=main"
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  SYSTEM RESTORE MANAGER
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Create Restore Point Now         [02] View All Restore Points           [03] Restore to a Point (Opens GUI)    %C_RESET%
echo %C_GREEN%  [04] Enable System Restore            [05] Disable System Restore            [06] Delete Old Restore Points         %C_RESET%
echo.
echo %C_YELLOW%  [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto restore_create
if "%c%"=="1" goto restore_create
if "%c%"=="02" goto restore_view
if "%c%"=="2" goto restore_view
if "%c%"=="03" goto restore_gui
if "%c%"=="3" goto restore_gui
if "%c%"=="04" goto restore_enable
if "%c%"=="4" goto restore_enable
if "%c%"=="05" goto restore_disable
if "%c%"=="5" goto restore_disable
if "%c%"=="06" goto restore_delete_old
if "%c%"=="6" goto restore_delete_old
if "%c%"=="99" goto main
goto menu_restore_manager

:restore_create
cls
echo %C_CYAN%Creating System Restore Point...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue; Checkpoint-Computer -Description 'UltimateToolkit Manual Restore Point' -RestorePointType MODIFY_SETTINGS; Write-Host 'Restore point created successfully.' -ForegroundColor Green"
echo.
pause
goto menu_restore_manager

:restore_view
cls
echo %C_CYAN%All System Restore Points:%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-ComputerRestorePoint | Select-Object @{N='#';E={$_.SequenceNumber}},@{N='Created';E={$_.ConvertToDateTime($_.CreationTime)}},Description,EventType | Format-Table -AutoSize"
echo.
pause
goto menu_restore_manager

:restore_gui
cls
echo %C_CYAN%Opening System Restore GUI...%C_RESET%
rstrui.exe
pause
goto menu_restore_manager

:restore_enable
cls
echo %C_CYAN%Enabling System Restore on C: drive...%C_RESET%
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Enable-ComputerRestore -Drive 'C:\'; Write-Host 'System Restore enabled on C: drive.' -ForegroundColor Green"
echo.
pause
goto menu_restore_manager

:restore_disable
cls
echo %C_RED%WARNING: Disabling System Restore will delete all existing restore points!%C_RESET%
echo.
set "confirm=" & set /p confirm=Type YES to confirm: 
if /i not "%confirm%"=="YES" goto menu_restore_manager
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Disable-ComputerRestore -Drive 'C:\'; Write-Host 'System Restore disabled on C: drive.' -ForegroundColor Yellow"
echo.
pause
goto menu_restore_manager

:restore_delete_old
cls
echo %C_CYAN%Deleting old restore points (keeping most recent)...%C_RESET%
echo.
vssadmin delete shadows /for=C: /oldest /quiet
echo.
echo %C_GREEN%Old restore points deleted. Most recent restore point preserved.%C_RESET%
pause
goto menu_restore_manager

:: ============================================================
:: SCHEDULED TASKS MANAGER
:: ============================================================
:menu_task_scheduler
set "BACK_MENU=main"
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  SCHEDULED TASKS MANAGER
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] List All Enabled Tasks            [02] List Suspicious Tasks             [03] Disable Task by Name              %C_RESET%
echo %C_GREEN%  [04] Enable Task by Name               [05] Open Task Scheduler GUI           [06] Export Task List to Log           %C_RESET%
echo.
echo %C_YELLOW%  [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto tasks_list_enabled
if "%c%"=="1" goto tasks_list_enabled
if "%c%"=="02" goto tasks_list_suspicious
if "%c%"=="2" goto tasks_list_suspicious
if "%c%"=="03" goto tasks_disable
if "%c%"=="3" goto tasks_disable
if "%c%"=="04" goto tasks_enable
if "%c%"=="4" goto tasks_enable
if "%c%"=="05" goto tasks_open_gui
if "%c%"=="5" goto tasks_open_gui
if "%c%"=="06" goto tasks_export_log
if "%c%"=="6" goto tasks_export_log
if "%c%"=="99" goto main
goto menu_task_scheduler

:tasks_list_enabled
cls
echo %C_CYAN%All Enabled Scheduled Tasks:%C_RESET%
echo.
schtasks /query /fo TABLE /nh | findstr /i "Ready Running"
echo.
pause
goto menu_task_scheduler

:tasks_list_suspicious
cls
echo %C_CYAN%Scanning for Suspicious Scheduled Tasks...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-ScheduledTask | Where-Object {$_.State -eq 'Ready'} | ForEach-Object {$task=$_; $actions=$task.Actions; foreach($a in $actions){$cmd=$a.Execute; if($cmd -match 'temp|appdata|\\$|wscript|cscript|powershell|cmd\.exe|mshta|rundll32' -and $cmd -notmatch 'System32|SysWOW64|Program Files'){Write-Host ('SUSPICIOUS: ' + $task.TaskPath + $task.TaskName) -ForegroundColor Red; Write-Host ('  Command: ' + $cmd) -ForegroundColor Yellow; Write-Host ''}}} ; Write-Host 'Scan complete.' -ForegroundColor Green"
echo.
pause
goto menu_task_scheduler

:tasks_disable
cls
echo %C_CYAN%Disable Scheduled Task by Name%C_RESET%
echo.
set "taskname=" & set /p taskname=Enter task name (or full path like \Microsoft\Windows\TaskName): 
if "%taskname%"=="" goto menu_task_scheduler
schtasks /change /tn "%taskname%" /disable
echo.
echo %C_GREEN%Task disable command issued for: %taskname%%C_RESET%
pause
goto menu_task_scheduler

:tasks_enable
cls
echo %C_CYAN%Enable Scheduled Task by Name%C_RESET%
echo.
set "taskname=" & set /p taskname=Enter task name (or full path like \Microsoft\Windows\TaskName): 
if "%taskname%"=="" goto menu_task_scheduler
schtasks /change /tn "%taskname%" /enable
echo.
echo %C_GREEN%Task enable command issued for: %taskname%%C_RESET%
pause
goto menu_task_scheduler

:tasks_open_gui
cls
echo %C_CYAN%Opening Task Scheduler...%C_RESET%
start "" taskschd.msc
pause
goto menu_task_scheduler

:tasks_export_log
cls
echo %C_CYAN%Exporting all scheduled tasks to log...%C_RESET%
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "TASKS_LOG=%LOGROOT%\ScheduledTasks_%stamp%.txt"
schtasks /query /fo LIST /v > "%TASKS_LOG%"
echo.
echo %C_GREEN%Task list exported to: %TASKS_LOG%%C_RESET%
pause
goto menu_task_scheduler

:: ============================================================
:: FIREWALL MANAGER
:: ============================================================
:menu_firewall_manager
set "BACK_MENU=main"
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  FIREWALL MANAGER
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Show Firewall Status              [02] Enable All Profiles               [03] Disable All Profiles              %C_RESET%
echo %C_GREEN%  [04] Show Inbound Rules                [05] Show Outbound Rules               [06] Add Allow Rule                    %C_RESET%
echo %C_GREEN%  [07] Reset Firewall to Default         [08] Open Firewall GUI                 %C_RESET%
echo.
echo %C_YELLOW%  [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto fw_status
if "%c%"=="1" goto fw_status
if "%c%"=="02" goto fw_enable_all
if "%c%"=="2" goto fw_enable_all
if "%c%"=="03" goto fw_disable_all
if "%c%"=="3" goto fw_disable_all
if "%c%"=="04" goto fw_inbound
if "%c%"=="4" goto fw_inbound
if "%c%"=="05" goto fw_outbound
if "%c%"=="5" goto fw_outbound
if "%c%"=="06" goto fw_add_rule
if "%c%"=="6" goto fw_add_rule
if "%c%"=="07" goto fw_reset
if "%c%"=="7" goto fw_reset
if "%c%"=="08" goto fw_gui
if "%c%"=="8" goto fw_gui
if "%c%"=="99" goto main
goto menu_firewall_manager

:fw_status
cls
echo %C_CYAN%Windows Firewall Status:%C_RESET%
echo.
netsh advfirewall show allprofiles
echo.
pause
goto menu_firewall_manager

:fw_enable_all
cls
echo %C_CYAN%Enabling Windows Firewall on all profiles...%C_RESET%
netsh advfirewall set allprofiles state on
echo.
echo %C_GREEN%Firewall enabled on Domain, Private, and Public profiles.%C_RESET%
pause
goto menu_firewall_manager

:fw_disable_all
cls
echo %C_RED%WARNING: Disabling firewall reduces system security!%C_RESET%
echo.
set "confirm=" & set /p confirm=Type YES to confirm disabling firewall: 
if /i not "%confirm%"=="YES" goto menu_firewall_manager
netsh advfirewall set allprofiles state off
echo.
echo %C_YELLOW%Firewall disabled on all profiles. Re-enable when done.%C_RESET%
pause
goto menu_firewall_manager

:fw_inbound
cls
echo %C_CYAN%Inbound Firewall Rules (Enabled):%C_RESET%
echo.
netsh advfirewall firewall show rule name=all dir=in status=enabled | more
echo.
pause
goto menu_firewall_manager

:fw_outbound
cls
echo %C_CYAN%Outbound Firewall Rules (Enabled):%C_RESET%
echo.
netsh advfirewall firewall show rule name=all dir=out status=enabled | more
echo.
pause
goto menu_firewall_manager

:fw_add_rule
cls
echo %C_CYAN%Add a New Firewall Allow Rule%C_RESET%
echo.
set "fw_rulename=" & set /p fw_rulename=Enter rule name: 
if "%fw_rulename%"=="" goto menu_firewall_manager
set "fw_program=" & set /p fw_program=Enter full path to program (or press ENTER to skip): 
set "fw_port=" & set /p fw_port=Enter port number (or press ENTER to skip): 
set "fw_proto=tcp"
if not "%fw_port%"=="" set /p fw_proto=Protocol [tcp/udp] (default tcp): 
if "%fw_proto%"=="" set "fw_proto=tcp"
if not "%fw_program%"=="" (
    netsh advfirewall firewall add rule name="%fw_rulename%" dir=in action=allow program="%fw_program%" enable=yes
    netsh advfirewall firewall add rule name="%fw_rulename%" dir=out action=allow program="%fw_program%" enable=yes
)
if not "%fw_port%"=="" (
    netsh advfirewall firewall add rule name="%fw_rulename%_port" dir=in action=allow protocol=%fw_proto% localport=%fw_port% enable=yes
)
echo.
echo %C_GREEN%Firewall rule added: %fw_rulename%%C_RESET%
pause
goto menu_firewall_manager

:fw_reset
cls
echo %C_RED%WARNING: This resets ALL firewall rules to Windows defaults!%C_RESET%
echo.
set "confirm=" & set /p confirm=Type YES to confirm reset: 
if /i not "%confirm%"=="YES" goto menu_firewall_manager
netsh advfirewall reset
echo.
echo %C_GREEN%Firewall reset to default settings.%C_RESET%
pause
goto menu_firewall_manager

:fw_gui
cls
echo %C_CYAN%Opening Windows Defender Firewall with Advanced Security...%C_RESET%
start "" wf.msc
pause
goto menu_firewall_manager

:: ============================================================
:: AI SMART DIAGNOSTICS
:: ============================================================
:menu_ai_diagnostics
set "BACK_MENU=main"
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  AI SMART DIAGNOSTICS
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] AI Auto-Detect PC Issues         [02] Smart Memory Leak Detector        [03] Smart Disk Health AI Check        %C_RESET%
echo %C_GREEN%  [04] Smart Network Issue AI           [05] Auto-Generate Fix Script          [06] Performance AI Analysis           %C_RESET%
echo.
echo %C_YELLOW%  [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto ai_detect_issues
if "%c%"=="1" goto ai_detect_issues
if "%c%"=="02" goto ai_memory_leak
if "%c%"=="2" goto ai_memory_leak
if "%c%"=="03" goto ai_disk_health
if "%c%"=="3" goto ai_disk_health
if "%c%"=="04" goto ai_network_issue
if "%c%"=="4" goto ai_network_issue
if "%c%"=="05" goto ai_generate_fix
if "%c%"=="5" goto ai_generate_fix
if "%c%"=="06" goto ai_perf_analysis
if "%c%"=="6" goto ai_perf_analysis
if "%c%"=="99" goto main
goto menu_ai_diagnostics

:ai_detect_issues
cls
echo %C_CYAN%AI Auto-Detect PC Issues - Analyzing system health...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$issues=@(); $cpu=(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average; if($cpu -gt 80){$issues+='HIGH CPU: ' + [math]::Round($cpu,0) + '%%'}; $mem=Get-CimInstance Win32_OperatingSystem; $memPct=[math]::Round(100*(($mem.TotalVisibleMemorySize-$mem.FreePhysicalMemory)/$mem.TotalVisibleMemorySize),1); if($memPct -gt 85){$issues+='HIGH MEMORY: ' + $memPct + '%%'}; $disks=Get-CimInstance Win32_LogicalDisk | Where-Object {$_.Size -gt 0}; foreach($d in $disks){$pct=[math]::Round(100*($d.FreeSpace/$d.Size),1); if($pct -lt 10){$issues+='LOW DISK: ' + $d.DeviceID + ' only ' + $pct + '%% free'}}; $errors=Get-EventLog -LogName System -EntryType Error -Newest 10 -ErrorAction SilentlyContinue; if($errors.Count -gt 5){$issues+='SYSTEM EVENT ERRORS: ' + $errors.Count + ' recent errors found'}; if($issues.Count -eq 0){Write-Host 'AI ANALYSIS: System looks healthy! No major issues detected.' -ForegroundColor Green}else{Write-Host 'AI ANALYSIS: Issues detected:' -ForegroundColor Red; $issues | ForEach-Object {Write-Host ('  [!] ' + $_) -ForegroundColor Yellow}}"
echo.
pause
goto menu_ai_diagnostics

:ai_memory_leak
cls
echo %C_CYAN%Smart Memory Leak Detector - Scanning high memory processes...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$totalMem=(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize; $procs=Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15; Write-Host ('Top 15 Memory Consuming Processes:') -ForegroundColor Cyan; Write-Host ('%-30s %10s %10s %s' -f 'Name','RAM(MB)','CPU(s)','PID'); Write-Host ('-'*65); foreach($p in $procs){$ram=[math]::Round($p.WorkingSet64/1MB,1); $cpu=[math]::Round($p.TotalProcessorTime.TotalSeconds,1); $pct=[math]::Round(100*$p.WorkingSet64/($totalMem*1024),1); $flag=''; if($pct -gt 10){$flag=' <<< HIGH USAGE'}; Write-Host ('%-30s %10s %10s %s%s' -f $p.Name,$ram,$cpu,$p.Id,$flag) -ForegroundColor $(if($pct -gt 10){'Yellow'}else{'White'})}"
echo.
pause
goto menu_ai_diagnostics

:ai_disk_health
cls
echo %C_CYAN%Smart Disk Health AI Check - Running WMI disk diagnostics...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$disks=Get-CimInstance Win32_DiskDrive; foreach($d in $disks){Write-Host ('Drive: ' + $d.Model) -ForegroundColor Cyan; Write-Host ('  Status: ' + $d.Status + ' | Size: ' + [math]::Round($d.Size/1GB,1) + ' GB | Media: ' + $d.MediaType); if($d.Status -eq 'OK'){Write-Host '  AI Result: DISK HEALTHY' -ForegroundColor Green}else{Write-Host ('  AI Result: CHECK REQUIRED - Status: ' + $d.Status) -ForegroundColor Red}; Write-Host ''}; Write-Host 'Running WinSAT quick disk check:'; winsat disk -drive c 2>&1 | Select-String 'Disk|Score|GB' | ForEach-Object {Write-Host ('  ' + $_)}"
echo.
pause
goto menu_ai_diagnostics

:ai_network_issue
cls
echo %C_CYAN%Smart Network Issue AI - Diagnosing connectivity...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$issues=@(); $ping=Test-Connection -ComputerName '8.8.8.8' -Count 2 -Quiet -ErrorAction SilentlyContinue; if(-not $ping){$issues+='NO INTERNET: Cannot reach 8.8.8.8 (Google DNS)'}; $dnsTest=Resolve-DnsName 'microsoft.com' -ErrorAction SilentlyContinue; if(-not $dnsTest){$issues+='DNS FAILURE: Cannot resolve microsoft.com'}; $adapters=Get-NetAdapter | Where-Object {$_.Status -eq 'Up'}; if($adapters.Count -eq 0){$issues+='NO ACTIVE ADAPTER: No network interface is Up'}; $ipConfig=Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -notmatch '169\.254|127\.0'}; if(-not $ipConfig){$issues+='APIPA/NO IP: No valid IPv4 address found'}; if($issues.Count -eq 0){Write-Host 'NETWORK AI: All network checks passed!' -ForegroundColor Green}else{Write-Host 'NETWORK AI: Issues detected:' -ForegroundColor Red; $issues | ForEach-Object {Write-Host ('  [!] ' + $_) -ForegroundColor Yellow}}; Write-Host ''; Write-Host 'Active adapters:' -ForegroundColor Cyan; Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object {Write-Host ('  ' + $_.Name + ' - ' + $_.InterfaceDescription)}"
echo.
pause
goto menu_ai_diagnostics

:ai_generate_fix
cls
echo %C_CYAN%Auto-Generate Fix Script - Creating personalized repair script...%C_RESET%
echo.
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "FIX_SCRIPT=%LOGROOT%\AI_FixScript_%stamp%.bat"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$out=$env:FIX_SCRIPT; $lines=@('@echo off','setlocal','echo AI Generated Fix Script - ' + (Get-Date),'echo.'); $cpu=(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average; $mem=Get-CimInstance Win32_OperatingSystem; $memPct=[math]::Round(100*(($mem.TotalVisibleMemorySize-$mem.FreePhysicalMemory)/$mem.TotalVisibleMemorySize),1); if($memPct -gt 80){$lines+='echo Clearing temp files to free memory...'; $lines+='del /f /q \"%TEMP%\\*\" 2^>nul'; $lines+='del /f /q \"C:\\Windows\\Temp\\*\" 2^>nul'}; $ping=Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue; if(-not $ping){$lines+='echo Repairing network...'; $lines+='netsh winsock reset'; $lines+='ipconfig /flushdns'; $lines+='ipconfig /release'; $lines+='ipconfig /renew'}; $lines+='echo Running SFC scan...'; $lines+='sfc /scannow'; $lines+='echo Fix script complete.'; $lines+='pause'; $lines | Out-File -FilePath $out -Encoding ASCII; Write-Host ('Fix script generated: ' + $out)"
echo.
echo %C_GREEN%Fix script created. Opening...%C_RESET%
start "" notepad.exe "%FIX_SCRIPT%"
pause
goto menu_ai_diagnostics

:ai_perf_analysis
cls
echo %C_CYAN%Performance AI Analysis - Comprehensive performance review...%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Write-Host '=== PERFORMANCE AI ANALYSIS ===' -ForegroundColor Cyan; Write-Host ''; $cpu=Get-CimInstance Win32_Processor; $cpuLoad=(($cpu | Measure-Object LoadPercentage -Average).Average); Write-Host ('CPU: ' + $cpu[0].Name) -ForegroundColor White; Write-Host ('  Load: ' + $cpuLoad + '%% | Cores: ' + $cpu[0].NumberOfCores + ' | Logical: ' + $cpu[0].NumberOfLogicalProcessors); Write-Host ''; $os=Get-CimInstance Win32_OperatingSystem; $memTotal=[math]::Round($os.TotalVisibleMemorySize/1MB,2); $memFree=[math]::Round($os.FreePhysicalMemory/1MB,2); $memUsed=[math]::Round($memTotal-$memFree,2); Write-Host 'MEMORY:' -ForegroundColor White; Write-Host ('  Total: ' + $memTotal + ' GB | Used: ' + $memUsed + ' GB | Free: ' + $memFree + ' GB'); Write-Host ''; Write-Host 'TOP 5 CPU PROCESSES:' -ForegroundColor White; Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {Write-Host ('  ' + $_.Name + ' - CPU: ' + [math]::Round($_.TotalProcessorTime.TotalSeconds,1) + 's | RAM: ' + [math]::Round($_.WorkingSet64/1MB,0) + 'MB')}; Write-Host ''; $score=''; try{$score=(Get-CimInstance -ClassName Win32_WinSAT).CPUScore}catch{}; if($score){Write-Host ('WINSAT CPU Score: ' + $score) -ForegroundColor Green}; Write-Host ''; Write-Host 'AI RECOMMENDATION:' -ForegroundColor Yellow; if($cpuLoad -gt 70){Write-Host '  Consider closing background apps or upgrading CPU.'}elseif($memUsed/$memTotal -gt 0.8){Write-Host '  RAM usage is high. Consider adding more RAM or closing apps.'}else{Write-Host '  System performance appears normal.'}"
echo.
pause
goto menu_ai_diagnostics

:: ============================================================
:menu_process_manager
set "BACK_MENU=main"
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  VISUAL PROCESS MANAGER
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] List All Running Processes        [02] Kill Process by Name              [03] Kill Process by PID               %C_RESET%
echo %C_GREEN%  [04] View CPU-Heavy Processes          [05] View RAM-Heavy Processes          [06] Suspend Process                   %C_RESET%
echo %C_GREEN%  [07] Open Task Manager                 %C_RESET%
echo.
echo %C_YELLOW%  [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto proc_list_all
if "%c%"=="1" goto proc_list_all
if "%c%"=="02" goto proc_kill_name
if "%c%"=="2" goto proc_kill_name
if "%c%"=="03" goto proc_kill_pid
if "%c%"=="3" goto proc_kill_pid
if "%c%"=="04" goto proc_cpu_heavy
if "%c%"=="4" goto proc_cpu_heavy
if "%c%"=="05" goto proc_ram_heavy
if "%c%"=="5" goto proc_ram_heavy
if "%c%"=="06" goto proc_suspend
if "%c%"=="6" goto proc_suspend
if "%c%"=="07" goto proc_task_manager
if "%c%"=="7" goto proc_task_manager
if "%c%"=="99" goto main
goto menu_process_manager

:proc_list_all
cls
echo %C_CYAN%All Running Processes:%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-Process | Sort-Object Name | Select-Object @{N='Name';E={$_.Name.PadRight(30)}},Id,@{N='CPU(s)';E={[math]::Round($_.TotalProcessorTime.TotalSeconds,1)}},@{N='RAM(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize | more"
echo.
pause
goto menu_process_manager

:proc_kill_name
cls
echo %C_CYAN%Kill Process by Name%C_RESET%
echo.
set "pname=" & set /p pname=Enter process name (without .exe, e.g. notepad): 
if "%pname%"=="" goto menu_process_manager
taskkill /f /im "%pname%.exe"
echo.
echo %C_GREEN%Kill command issued for: %pname%.exe%C_RESET%
pause
goto menu_process_manager

:proc_kill_pid
cls
echo %C_CYAN%Kill Process by PID%C_RESET%
echo.
set "ppid=" & set /p ppid=Enter Process ID (PID): 
if "%ppid%"=="" goto menu_process_manager
taskkill /f /pid %ppid%
echo.
echo %C_GREEN%Kill command issued for PID: %ppid%%C_RESET%
pause
goto menu_process_manager

:proc_cpu_heavy
cls
echo %C_CYAN%Top 15 CPU-Consuming Processes:%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-Process | Sort-Object TotalProcessorTime -Descending | Select-Object -First 15 | Format-Table Name,Id,@{N='CPU(s)';E={[math]::Round($_.TotalProcessorTime.TotalSeconds,1)}},@{N='RAM(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}} -AutoSize"
echo.
pause
goto menu_process_manager

:proc_ram_heavy
cls
echo %C_CYAN%Top 15 RAM-Consuming Processes:%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 | Format-Table Name,Id,@{N='RAM(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}},@{N='CPU(s)';E={[math]::Round($_.TotalProcessorTime.TotalSeconds,1)}} -AutoSize"
echo.
pause
goto menu_process_manager

:proc_suspend
cls
echo %C_CYAN%Suspend Process (Debug Pause) by Name%C_RESET%
echo.
set "pname=" & set /p pname=Enter process name to suspend (e.g. notepad): 
if "%pname%"=="" goto menu_process_manager
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$proc=Get-Process -Name $env:pname -ErrorAction SilentlyContinue; if($proc){$proc | ForEach-Object {$_.Suspend(); Write-Host ('Suspended: ' + $_.Name + ' PID: ' + $_.Id) -ForegroundColor Yellow}; Write-Host 'Note: Run option 01 and kill the process to fully terminate.'}else{Write-Host ('Process not found: ' + $env:pname) -ForegroundColor Red}"
echo.
pause
goto menu_process_manager

:proc_task_manager
cls
echo %C_CYAN%Opening Task Manager...%C_RESET%
start "" taskmgr.exe
pause
goto menu_process_manager

:: ============================================================
:: NETSTAT CONNECTIONS
:: ============================================================
:menu_netstat_conn
set "BACK_MENU=main"
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  NETSTAT CONNECTIONS
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] All Active Connections            [02] Listening Ports Only              [03] Established Connections           %C_RESET%
echo %C_GREEN%  [04] Foreign Connections (Internet)    [05] Connections with Process Names    [06] Export Netstat Log                %C_RESET%
echo.
echo %C_YELLOW%  [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto netstat_all
if "%c%"=="1" goto netstat_all
if "%c%"=="02" goto netstat_listening
if "%c%"=="2" goto netstat_listening
if "%c%"=="03" goto netstat_established
if "%c%"=="3" goto netstat_established
if "%c%"=="04" goto netstat_foreign
if "%c%"=="4" goto netstat_foreign
if "%c%"=="05" goto netstat_procs
if "%c%"=="5" goto netstat_procs
if "%c%"=="06" goto netstat_export
if "%c%"=="6" goto netstat_export
if "%c%"=="99" goto main
goto menu_netstat_conn

:netstat_all
cls
echo %C_CYAN%All Active Connections:%C_RESET%
echo.
netsh interface show interface
echo.
netstat -ano | more
echo.
pause
goto menu_netstat_conn

:netstat_listening
cls
echo %C_CYAN%Listening Ports Only:%C_RESET%
echo.
netstat -ano | findstr /i "LISTENING"
echo.
pause
goto menu_netstat_conn

:netstat_established
cls
echo %C_CYAN%Established Connections:%C_RESET%
echo.
netstat -ano | findstr /i "ESTABLISHED"
echo.
pause
goto menu_netstat_conn

:netstat_foreign
cls
echo %C_CYAN%Foreign (Internet) Connections - Excluding localhost:%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "netstat -ano | Select-String 'ESTABLISHED' | ForEach-Object {$line=$_.ToString().Trim(); if($line -notmatch '127\.0\.0\.1|0\.0\.0\.0|\[::1\]|\[::\]'){Write-Host $line}}"
echo.
pause
goto menu_netstat_conn

:netstat_procs
cls
echo %C_CYAN%Active Connections with Process Names:%C_RESET%
echo.
netstat -anob 2>nul | more
echo.
pause
goto menu_netstat_conn

:netstat_export
cls
echo %C_CYAN%Exporting Netstat log...%C_RESET%
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "stamp=%%i"
set "NETSTAT_LOG=%LOGROOT%\Netstat_%stamp%.txt"
netstat -ano > "%NETSTAT_LOG%"
netstat -anob >> "%NETSTAT_LOG%" 2>nul
echo.
echo %C_GREEN%Netstat log exported to: %NETSTAT_LOG%%C_RESET%
pause
goto menu_netstat_conn

:: ============================================================
:: SERVICES CONTROL PANEL
:: ============================================================
:menu_services_dashboard
set "BACK_MENU=main"
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  SERVICES CONTROL PANEL
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] List All Running Services         [02] List Stopped Services             [03] Start a Service                   %C_RESET%
echo %C_GREEN%  [04] Stop a Service                    [05] Restart a Service                 [06] Set Service to Auto               %C_RESET%
echo %C_GREEN%  [07] Set Service to Disabled           [08] Open Services.msc                 %C_RESET%
echo.
echo %C_YELLOW%  [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto svc_list_running
if "%c%"=="1" goto svc_list_running
if "%c%"=="02" goto svc_list_stopped
if "%c%"=="2" goto svc_list_stopped
if "%c%"=="03" goto svc_start
if "%c%"=="3" goto svc_start
if "%c%"=="04" goto svc_stop
if "%c%"=="4" goto svc_stop
if "%c%"=="05" goto svc_restart
if "%c%"=="5" goto svc_restart
if "%c%"=="06" goto svc_set_auto
if "%c%"=="6" goto svc_set_auto
if "%c%"=="07" goto svc_set_disabled
if "%c%"=="7" goto svc_set_disabled
if "%c%"=="08" goto svc_open_msc
if "%c%"=="8" goto svc_open_msc
if "%c%"=="99" goto main
goto menu_services_dashboard

:svc_list_running
cls
echo %C_CYAN%All Running Services:%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-Service | Where-Object {$_.Status -eq 'Running'} | Sort-Object DisplayName | Select-Object Name,DisplayName,Status,StartType | Format-Table -AutoSize | more"
echo.
pause
goto menu_services_dashboard

:svc_list_stopped
cls
echo %C_CYAN%Stopped Services:%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-Service | Where-Object {$_.Status -eq 'Stopped'} | Sort-Object DisplayName | Select-Object Name,DisplayName,Status,StartType | Format-Table -AutoSize | more"
echo.
pause
goto menu_services_dashboard

:svc_start
cls
echo %C_CYAN%Start a Service%C_RESET%
echo.
set "svcname=" & set /p svcname=Enter service name (e.g. wuauserv, Spooler): 
if "%svcname%"=="" goto menu_services_dashboard
net start "%svcname%"
echo.
pause
goto menu_services_dashboard

:svc_stop
cls
echo %C_CYAN%Stop a Service%C_RESET%
echo.
set "svcname=" & set /p svcname=Enter service name (e.g. Spooler, wuauserv): 
if "%svcname%"=="" goto menu_services_dashboard
net stop "%svcname%"
echo.
pause
goto menu_services_dashboard

:svc_restart
cls
echo %C_CYAN%Restart a Service%C_RESET%
echo.
set "svcname=" & set /p svcname=Enter service name to restart: 
if "%svcname%"=="" goto menu_services_dashboard
net stop "%svcname%" 2>nul
net start "%svcname%"
echo.
echo %C_GREEN%Service restart command complete for: %svcname%%C_RESET%
pause
goto menu_services_dashboard

:svc_set_auto
cls
echo %C_CYAN%Set Service Startup Type to Automatic%C_RESET%
echo.
set "svcname=" & set /p svcname=Enter service name: 
if "%svcname%"=="" goto menu_services_dashboard
sc config "%svcname%" start=auto
echo.
echo %C_GREEN%Service set to Automatic: %svcname%%C_RESET%
pause
goto menu_services_dashboard

:svc_set_disabled
cls
echo %C_CYAN%Set Service Startup Type to Disabled%C_RESET%
echo.
set "svcname=" & set /p svcname=Enter service name: 
if "%svcname%"=="" goto menu_services_dashboard
sc config "%svcname%" start=disabled
echo.
echo %C_YELLOW%Service set to Disabled: %svcname%%C_RESET%
pause
goto menu_services_dashboard

:svc_open_msc
cls
echo %C_CYAN%Opening Services.msc...%C_RESET%
start "" services.msc
pause
goto menu_services_dashboard

:: ============================================================
:: REGISTRY TELEMETRY TWEAKS
:: ============================================================
:menu_registry_tweaks
set "BACK_MENU=main"
cls
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo  REGISTRY TELEMETRY TWEAKS
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo.
echo %C_GREEN%  [01] Disable Windows Telemetry         [02] Enable Telemetry (Restore)        [03] Disable Cortana                   %C_RESET%
echo %C_GREEN%  [04] Disable Activity History          [05] Disable Advertising ID            [06] Disable Location Tracking         %C_RESET%
echo %C_GREEN%  [07] Restore All Privacy Settings      [08] View Current Privacy State        %C_RESET%
echo.
echo %C_YELLOW%  [99] Back / Main Menu%C_RESET%
echo %C_CYAN%=========================================================================================================================================================%C_RESET%
echo %C_CYAN%SELECT OPTION / 99 BACK:%C_RESET%
set "c=" & set /p c=  ^> 
if "%c%"=="01" goto reg_disable_telemetry
if "%c%"=="1" goto reg_disable_telemetry
if "%c%"=="02" goto reg_enable_telemetry
if "%c%"=="2" goto reg_enable_telemetry
if "%c%"=="03" goto reg_disable_cortana
if "%c%"=="3" goto reg_disable_cortana
if "%c%"=="04" goto reg_disable_activity
if "%c%"=="4" goto reg_disable_activity
if "%c%"=="05" goto reg_disable_adid
if "%c%"=="5" goto reg_disable_adid
if "%c%"=="06" goto reg_disable_location
if "%c%"=="6" goto reg_disable_location
if "%c%"=="07" goto reg_restore_all
if "%c%"=="7" goto reg_restore_all
if "%c%"=="08" goto reg_view_state
if "%c%"=="8" goto reg_view_state
if "%c%"=="99" goto main
goto menu_registry_tweaks

:reg_disable_telemetry
cls
echo %C_CYAN%Disabling Windows Telemetry...%C_RESET%
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DisableEnterpriseAuthProxy /t REG_DWORD /d 1 /f
sc config DiagTrack start=disabled >nul 2>&1
sc stop DiagTrack >nul 2>&1
echo.
echo %C_GREEN%Telemetry disabled. Windows data collection restricted.%C_RESET%
pause
goto menu_registry_tweaks

:reg_enable_telemetry
cls
echo %C_CYAN%Restoring Windows Telemetry to default...%C_RESET%
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 3 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 3 /f
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DisableEnterpriseAuthProxy /f >nul 2>&1
sc config DiagTrack start=auto >nul 2>&1
net start DiagTrack >nul 2>&1
echo.
echo %C_GREEN%Telemetry restored to Windows defaults.%C_RESET%
pause
goto menu_registry_tweaks

:reg_disable_cortana
cls
echo %C_CYAN%Disabling Cortana...%C_RESET%
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v CortanaEnabled /t REG_DWORD /d 0 /f
reg add "HKCU\Software\Microsoft\Personalization\Settings" /v AcceptedPrivacyPolicy /t REG_DWORD /d 0 /f
echo.
echo %C_GREEN%Cortana disabled via registry policy.%C_RESET%
pause
goto menu_registry_tweaks

:reg_disable_activity
cls
echo %C_CYAN%Disabling Activity History...%C_RESET%
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v UploadUserActivities /t REG_DWORD /d 0 /f
echo.
echo %C_GREEN%Activity History disabled.%C_RESET%
pause
goto menu_registry_tweaks

:reg_disable_adid
cls
echo %C_CYAN%Disabling Advertising ID...%C_RESET%
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /t REG_DWORD /d 1 /f
echo.
echo %C_GREEN%Advertising ID disabled.%C_RESET%
pause
goto menu_registry_tweaks

:reg_disable_location
cls
echo %C_CYAN%Disabling Location Tracking...%C_RESET%
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" /v SensorPermissionState /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" /v Status /t REG_DWORD /d 0 /f
echo.
echo %C_GREEN%Location tracking disabled.%C_RESET%
pause
goto menu_registry_tweaks

:reg_restore_all
cls
echo %C_CYAN%Restoring All Privacy Settings to Windows Defaults...%C_RESET%
echo.
:: Telemetry
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 3 /f
:: Cortana
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /f >nul 2>&1
:: Activity History
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /f >nul 2>&1
:: Advertising ID
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 1 /f
:: Location
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /f >nul 2>&1
echo.
echo %C_GREEN%All privacy registry tweaks restored to Windows defaults.%C_RESET%
pause
goto menu_registry_tweaks

:reg_view_state
cls
echo %C_CYAN%Current Privacy / Telemetry Registry State:%C_RESET%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$checks=@(@{Name='Telemetry Level';Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';Val='AllowTelemetry';Default=3},@{Name='Cortana Enabled';Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search';Val='AllowCortana';Default=1},@{Name='Activity Feed';Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System';Val='EnableActivityFeed';Default=1},@{Name='Advertising ID';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo';Val='Enabled';Default=1},@{Name='Location Tracking';Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors';Val='DisableLocation';Default=0}); foreach($c in $checks){$v=try{(Get-ItemProperty -Path $c.Path -Name $c.Val -ErrorAction Stop).$($c.Val)}catch{'NOT SET (default)'}; $status=if($v -eq 'NOT SET (default)'){'DEFAULT'}elseif($v -ne $c.Default){'MODIFIED'}else{'DEFAULT'}; $color=if($status -eq 'MODIFIED'){'Yellow'}else{'Green'}; Write-Host ('  ' + $c.Name.PadRight(25) + ': ' + $v + ' [' + $status + ']') -ForegroundColor $color}"
echo.
pause
goto menu_registry_tweaks
