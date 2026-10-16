@echo off
chcp 65001 > nul
title Ultimate Toolkit - Multi-Architecture Publisher (x86 & x64)

echo ========================================================
echo   Ultimate Enterprise IT Toolkit - Derleme & Paketleme
echo   Mimariler: x86 (32-Bit) & x64 (64-Bit)
echo ========================================================
echo.

set PROJECT_PATH=UltimateToolkit.Modern\UltimateToolkit.Modern.csproj
set OUTPUT_BASE=publish_output

echo [1/2] x64 (64-bit) Portable Derleniyor...
dotnet publish "%PROJECT_PATH%" -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o "%OUTPUT_BASE%\win-x64"
if %errorlevel% neq 0 (
    echo [HATA] x64 derlemesi basarisiz oldu!
    pause
    exit /b %errorlevel%
)
echo [OK] x64 surumu hazir: %OUTPUT_BASE%\win-x64\UltimateToolkit.exe
echo.

echo [2/2] x86 (32-bit) Portable Derleniyor...
dotnet publish "%PROJECT_PATH%" -c Release -r win-x86 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o "%OUTPUT_BASE%\win-x86"
if %errorlevel% neq 0 (
    echo [HATA] x86 derlemesi basarisiz oldu!
    pause
    exit /b %errorlevel%
)
echo [OK] x86 surumu hazir: %OUTPUT_BASE%\win-x86\UltimateToolkit.exe
echo.

echo ========================================================
echo   Tebrikler! Hem x86 hem x64 surumleri basariyla uretildi.
echo   Konum: %CD%\%OUTPUT_BASE%\
echo ========================================================
pause
