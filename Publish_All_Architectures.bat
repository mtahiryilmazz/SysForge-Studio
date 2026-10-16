@echo off
chcp 65001 > nul
title SysForge Studio - Tek Parca Portable Derleyici (x86 & x64)

echo ========================================================
echo   SysForge Studio - Tum Moduller Dahili Tek EXE Uretimi
echo   Mimariler: x86 (32-Bit) & x64 (64-Bit)
echo ========================================================
echo.

set PROJECT_PATH=UltimateToolkit.Modern\UltimateToolkit.Modern.csproj
set OUTPUT_BASE=publish_output

echo [1/2] x64 (64-bit) Tek Parca Portable EXE Derleniyor...
dotnet publish "%PROJECT_PATH%" -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o "%OUTPUT_BASE%\win-x64"
if %errorlevel% neq 0 (
    echo [HATA] x64 derlemesi basarisiz oldu!
    pause
    exit /b %errorlevel%
)
echo [OK] x64 Tek Parca EXE Hazir: %OUTPUT_BASE%\win-x64\SysForgeStudio.exe
echo.

echo [2/2] x86 (32-bit) Tek Parca Portable EXE Derleniyor...
dotnet publish "%PROJECT_PATH%" -c Release -r win-x86 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o "%OUTPUT_BASE%\win-x86"
if %errorlevel% neq 0 (
    echo [HATA] x86 derlemesi basarisiz oldu!
    pause
    exit /b %errorlevel%
)
echo [OK] x86 Tek Parca EXE Hazir: %OUTPUT_BASE%\win-x86\SysForgeStudio.exe
echo.

echo ========================================================
echo   Tebrikler! Hem x86 hem x64 surumleri basariyla uretildi.
echo   Tek EXE Konumlari:
echo   - 64-Bit: %CD%\%OUTPUT_BASE%\win-x64\SysForgeStudio.exe
echo   - 32-Bit: %CD%\%OUTPUT_BASE%\win-x86\SysForgeStudio.exe
echo ========================================================
pause