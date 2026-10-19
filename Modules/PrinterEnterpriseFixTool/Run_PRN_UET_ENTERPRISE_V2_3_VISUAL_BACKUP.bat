@echo off
title PRN UET Enterprise V2.3 Visual Backup
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Printer_Enterprise_FixTool.ps1"
pause
