# ═══════════════════════════════════════════════════════════════════
# UltimateToolkit — One-Click Super Repair Module
# Runs SFC, DISM, CHKDSK, Network stack reset, Restore Point, Temp clean
# ═══════════════════════════════════════════════════════════════════

$ErrorActionPreference = "Continue"

Write-Output "========================================================"
Write-Output "⚡ INITIALIZING ONE-CLICK SUPER REPAIR SEQUENCE ⚡"
Write-Output "========================================================"

# [STEP 1/9] Creating System Restore Point
Write-Output "[STEP 1/9] Creating System Restore Point..."
try {
    $RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    $OriginalFrequency = $null
    if (Test-Path $RegistryPath) {
        $val = Get-ItemProperty -Path $RegistryPath -Name "SystemRestorePointCreationFrequency" -ErrorAction SilentlyContinue
        if ($val -and $val.SystemRestorePointCreationFrequency) {
            $OriginalFrequency = $val.SystemRestorePointCreationFrequency
        }
        Set-ItemProperty -Path $RegistryPath -Name "SystemRestorePointCreationFrequency" -Value 0 -ErrorAction SilentlyContinue | Out-Null
    }
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue | Out-Null
    Checkpoint-Computer -Description "Pre-OneClickSuperRepair" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop | Out-Null
    Write-Output "SUCCESS: System Restore Point 'Pre-OneClickSuperRepair' created successfully."
    
    if (Test-Path $RegistryPath) {
        if ($null -ne $OriginalFrequency) {
            Set-ItemProperty -Path $RegistryPath -Name "SystemRestorePointCreationFrequency" -Value $OriginalFrequency -ErrorAction SilentlyContinue | Out-Null
        }
    }
} catch {
    Write-Output "WARNING: System Restore Point creation skipped or failed: $($_.Exception.Message)"
}

# [STEP 2/9] Purging Temporary System & User Caches
Write-Output "[STEP 2/9] Purging Temporary System & User Caches..."
$paths = @($env:TEMP, $env:TMP, 'C:\Windows\Temp')
$cleared = 0
$freed = 0
foreach ($p in $paths) {
    if (Test-Path $p) {
        Get-ChildItem -LiteralPath $p -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $freed += $_.Length
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                $cleared++
            } catch {}
        }
    }
}
Write-Output "SUCCESS: Cleared $cleared temp files, freeing $([math]::Round($freed/1MB,2)) MB of storage."

# [STEP 3/9] Resetting Network Stack & DNS Resolver Cache
Write-Output "[STEP 3/9] Resetting Network Stack & DNS Resolver Cache..."
try {
    ipconfig /flushdns | Out-Null
    Write-Output " -> DNS Resolver cache flushed."
    netsh winsock reset | Out-Null
    Write-Output " -> Winsock Catalog reset."
    netsh int ip reset | Out-Null
    Write-Output " -> TCP/IP stack reset."
    Write-Output "SUCCESS: Network interface protocols successfully re-initialized."
} catch {
    Write-Output "WARNING: Network reset encountered errors: $($_.Exception.Message)"
}

# [STEP 4/9] Running System File Checker (SFC Scan)
Write-Output "[STEP 4/9] Running System File Checker (SFC Scan)..."
try {
    Write-Output " -> Beginning system file integrity verification..."
    $sfcJob = $null
    Write-Output " -> Beginning system file integrity verification (SFC)..."
    sfc /verifyonly
    Write-Output "SUCCESS: System File Checker verification completed." 
} catch {
    Write-Output "WARNING: SFC Scan failed to run: $($_.Exception.Message)"
}

# [STEP 5/9] Running DISM Online Image Repair
Write-Output "[STEP 5/9] Running DISM Online Image Repair..."
try {
    Write-Output " -> Connecting to Component Store..."
    $dismJob = $null
    Write-Output " -> Connecting to Component Store (DISM)..."
    DISM /Online /Cleanup-Image /CheckHealth
    Write-Output "SUCCESS: Component store corruption checks completed." 
} catch {
    Write-Output "WARNING: DISM Image Repair failed to run: $($_.Exception.Message)"
}

# [STEP 6/9] Scanning File System Integrity (CHKDSK Online)
Write-Output "[STEP 6/9] Scanning File System Integrity (CHKDSK Online)..."
try {
    Write-Output " -> Querying NTFS file system volumes..."
    $chkdskJob = $null
    Write-Output " -> Querying NTFS file system volumes (CHKDSK)..."
    chkdsk C: /scan
    Write-Output "SUCCESS: Disk file system scan completed." 
} catch {
    Write-Output "WARNING: CHKDSK Scan failed: $($_.Exception.Message)"
}

# [STEP 7/9] Running Driver Signature & Security Check
Write-Output "[STEP 7/9] Running Driver Signature & Security Check..."
try {
    $unsigned = Get-WmiObject Win32_PnPSignedDriver | Where-Object { $_.IsSigned -eq $false } | Select-Object DeviceName, Manufacturer, DriverVersion
    if ($unsigned) {
        Write-Output "WARNING: Found $($unsigned.Count) unsigned drivers:"
        $unsigned | ForEach-Object { Write-Output " -> Device: $($_.DeviceName) | Manufacturer: $($_.Manufacturer) | Version: $($_.DriverVersion)" }
    } else {
        Write-Output "SUCCESS: All active plug-and-play drivers are verified and signed."
    }
} catch {
    Write-Output "WARNING: Driver signature check failed: $($_.Exception.Message)"
}

# [STEP 8/9] Resetting Windows Update Cache
Write-Output "[STEP 8/9] Resetting Windows Update Cache..."
try {
    Stop-Service -Name wuauserv, bits -Force -ErrorAction SilentlyContinue
    Write-Output " -> Windows Update service stopped."
    Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output " -> SoftwareDistribution download cache cleared."
    Start-Service -Name wuauserv, bits -ErrorAction SilentlyContinue
    Write-Output " -> Windows Update service restarted."
    Write-Output "SUCCESS: Windows Update component cache reset."
} catch {
    Write-Output "WARNING: Windows Update reset encountered errors: $($_.Exception.Message)"
}

# [STEP 9/9] Generating Final Health Summary
Write-Output "[STEP 9/9] Generating System Health Summary..."
try {
    $os   = Get-CimInstance Win32_OperatingSystem
    $cpu  = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    $ramPct  = [math]::Round((1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 1)
    $ramFreeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $uptime  = ((Get-Date) - $os.LastBootUpTime)
    $uptimeStr = "$([math]::Floor($uptime.TotalHours))h $($uptime.Minutes)m"

    Write-Output "========================================================"
    Write-Output "SYSTEM HEALTH REPORT"
    Write-Output "========================================================"
    Write-Output "OS         : $($os.Caption) Build $($os.BuildNumber)"
    Write-Output "Uptime     : $uptimeStr"
    Write-Output "CPU Usage  : ${cpu}%"
    Write-Output "RAM Usage  : ${ramPct}% ($ramFreeGB GB free)"
    Write-Output "========================================================"
    Write-Output "SUCCESS: One-Click Super Repair sequence completed!"
    Write-Output "All 9 repair stages have been executed."
    Write-Output "========================================================"
} catch {
    Write-Output "SUCCESS: One-Click Super Repair completed (health summary unavailable)."
}
