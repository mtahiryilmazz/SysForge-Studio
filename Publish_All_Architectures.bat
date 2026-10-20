@echo off
chcp 65001 > nul
title SysForge Studio - Multi-Architecture Publisher (x86 ^& x64)

echo ========================================================
echo   SysForge Studio - Enterprise IT Suite - Derleme
echo   Mimariler: x86 (32-Bit) ^& x64 (64-Bit) [.NET 4.8]
echo ========================================================
echo.

set PROJECT_PATH=SysForgeStudio\SysForgeStudio.csproj
set OUTPUT_BASE=publish_output

echo [1/2] x64 (64-bit) Derleniyor...
dotnet publish "%PROJECT_PATH%" -c Release -p:PlatformTarget=x64 -o "%OUTPUT_BASE%\win-x64"
if %errorlevel% neq 0 (
    echo [HATA] x64 derlemesi basarisiz oldu!
    pause
    exit /b %errorlevel%
)
echo [OK] x64 surumu hazir: %OUTPUT_BASE%\win-x64\SysForgeStudio.exe
echo.

echo [2/2] x86 (32-bit) Derleniyor...
dotnet publish "%PROJECT_PATH%" -c Release -p:PlatformTarget=x86 -o "%OUTPUT_BASE%\win-x86"
if %errorlevel% neq 0 (
    echo [HATA] x86 derlemesi basarisiz oldu!
    pause
    exit /b %errorlevel%
)
echo [OK] x86 surumu hazir: %OUTPUT_BASE%\win-x86\SysForgeStudio.exe
echo.

echo ========================================================
echo   Tebrikler! Hem x86 hem x64 surumleri basariyla uretildi.
echo   Konum: %CD%\%OUTPUT_BASE%\
echo ========================================================
pause
