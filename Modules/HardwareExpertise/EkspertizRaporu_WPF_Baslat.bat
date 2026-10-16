@echo off
chcp 65001 > nul
title Donanim Ekspertiz Merkezi - Modern WPF
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0EkspertizRaporu_WPF_Fluent.ps1"
