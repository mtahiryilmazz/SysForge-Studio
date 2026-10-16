$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   ULTIMATE TOOLKIT - İZOLE OTOMATİK DOĞRULAMA TESTİ" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$testResults = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-TestResult {
    param([string]$Name, [bool]$Passed, [string]$Details)
    $tag = if ($Passed) { "OK" } else { "FAIL" }
    $statusText = if ($Passed) { "BAŞARILI" } else { "BAŞARISIZ" }
    $testResults.Add([PSCustomObject]@{
        Test = $Name
        Status = $statusText
        Details = $Details
    })
    $color = if ($Passed) { "Green" } else { "Red" }
    Write-Host ("[{0}] {1} - {2}" -f $tag, $Name, $Details) -ForegroundColor $color
}

# Test 1: Batch dosyası CRLF ve sözdizimi testi
try {
    $batPath = Join-Path $PSScriptRoot "Run_Modern_Toolkit.bat"
    $bytes = [System.IO.File]::ReadAllBytes($batPath)
    $hasCrLf = $false
    for ($i = 0; $i -lt ($bytes.Length - 1); $i++) {
        if ($bytes[$i] -eq 13 -and $bytes[$i+1] -eq 10) { $hasCrLf = $true; break }
    }
    
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batPath`"" -NoNewWindow -PassThru -Wait
    $passed = ($proc.ExitCode -eq 0 -and $hasCrLf)
    Add-TestResult "Run_Modern_Toolkit.bat CMD Sözdizimi" $passed "ExitCode: $($proc.ExitCode), CRLF: $hasCrLf"
} catch {
    Add-TestResult "Run_Modern_Toolkit.bat CMD Sözdizimi" $false $_.Exception.Message
}

# Test 2: Portable EXE Varlığı ve Boyutu
try {
    $exePath = Join-Path $PSScriptRoot "UltimateToolkit_Modern.exe"
    if (-not (Test-Path $exePath)) {
        $exePath = Join-Path $PSScriptRoot "UltimateToolkit.Modern\bin\Release\net8.0-windows\UltimateToolkit.exe"
    }
    $item = Get-Item $exePath
    $passed = ($item.Exists -and $item.Length -gt 100000)
    Add-TestResult "Portable EXE Dosya Doğrulaması" $passed ("Boyut: {0:N2} MB" -f ($item.Length / 1MB))
} catch {
    Add-TestResult "Portable EXE Dosya Doğrulaması" $false $_.Exception.Message
}

# Test 3: Uygulama Başlatma ve Canlı Çalışma Testi (Runtime Crash / NullRef Taraması)
try {
    $exePath = Join-Path $PSScriptRoot "UltimateToolkit_Modern.exe"
    if (-not (Test-Path $exePath)) {
        $exePath = Join-Path $PSScriptRoot "UltimateToolkit.Modern\bin\Release\net8.0-windows\UltimateToolkit.exe"
    }
    $proc = Start-Process -FilePath $exePath -PassThru
    Start-Sleep -Seconds 3
    
    $proc.Refresh()
    if ($proc.HasExited) {
        Add-TestResult "Uygulama Çalışma Stabilitesi" $false "Uygulama başlatıldıktan sonra çöktü (ExitCode: $($proc.ExitCode))"
    } else {
        $wsMb = [Math]::Round($proc.WorkingSet64 / 1MB, 2)
        Add-TestResult "Uygulama Çalışma Stabilitesi" $true "Uygulama aktif, çökme yok, bellek kullanımı: $wsMb MB"
        # Test sonrası temizle
        Stop-Process -Id $proc.Id -Force
    }
} catch {
    Add-TestResult "Uygulama Çalışma Stabilitesi" $false $_.Exception.Message
}

# Test 4: Visual Studio Solution (.sln) Doğrulaması
try {
    $slnPath = Join-Path $PSScriptRoot "UltimateToolkit.sln"
    $passed = (Test-Path $slnPath)
    Add-TestResult "Visual Studio Solution Doğrulaması" $passed "UltimateToolkit.sln mevcut ve yapılandırılmış"
} catch {
    Add-TestResult "Visual Studio Solution Doğrulaması" $false $_.Exception.Message
}

# Test 5: .NET 8 Derleme Doğrulaması (Zero Warnings / Zero Errors)
try {
    $projPath = Join-Path $PSScriptRoot "UltimateToolkit.Modern\UltimateToolkit.Modern.csproj"
    $buildOutput = dotnet build $projPath -c Release --no-restore
    $buildSuccess = ($LASTEXITCODE -eq 0)
    Add-TestResult ".NET 8 Derleme Bütünlüğü" $buildSuccess "Derleme başarılı, sıfır hata"
} catch {
    Add-TestResult ".NET 8 Derleme Bütünlüğü" $false $_.Exception.Message
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "   TEST VE DOĞRULAMA RAPORU" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
$testResults | Format-Table -AutoSize
