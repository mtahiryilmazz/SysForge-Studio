@echo off
title PRN UET Enterprise V2.3 Visual Backup
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PRN_UET_ENTERPRISE_V2_3_VISUAL_BACKUP.ps1"
pause
