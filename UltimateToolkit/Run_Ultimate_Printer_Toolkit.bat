@echo off
chcp 65001 >nul
title Ultimate Printer Toolkit
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Ultimate_Printer_Toolkit_v3.ps1"
pause
