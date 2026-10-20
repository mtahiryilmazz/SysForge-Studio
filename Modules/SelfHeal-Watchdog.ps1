# ═══════════════════════════════════════════════════════════════════
# SelfHeal-Watchdog.ps1 — UltimateToolkit Auto-Recovery Guardian
# Monitors WebBridgeServer and auto-restarts it if it crashes.
# Also checks disk, RAM, and CPU every 30 seconds.
# Run separately: powershell -File SelfHeal-Watchdog.ps1
# ═══════════════════════════════════════════════════════════════════

param([int]$Port = 9999)

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir '..'))
$LogDir      = Join-Path $ToolkitRoot 'Logs'
$LogPath     = Join-Path $LogDir 'SelfHeal-Watchdog.log'
$ServerScript = Join-Path $ScriptDir 'WebBridgeServer.ps1'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function WDLog($msg) {
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "[$ts] $msg" | Add-Content -LiteralPath $LogPath -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-Host "[$ts] [WATCHDOG] $msg" -ForegroundColor Green
}

function Test-ServerAlive {
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:$Port/api/status" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        return ($resp.StatusCode -eq 200)
    } catch { return $false }
}

function Get-ServerProcess {
    return Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -eq 'powershell' -and $_.MainWindowTitle -eq '' -and
        ($_.CommandLine -match 'WebBridgeServer' -or $true)
    } | Select-Object -First 1
}

function Restart-BridgeServer {
    WDLog "⚠️  Server not responding! Attempting restart..."
    # Kill any lingering powershell running the server
    try {
        $procs = Get-WmiObject Win32_Process -ErrorAction SilentlyContinue | 
                 Where-Object { $_.CommandLine -match 'WebBridgeServer' }
        foreach ($p in $procs) {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
            WDLog "Killed old server process PID $($p.ProcessId)"
        }
    } catch {}

    Start-Sleep 2

    # Relaunch
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName  = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ServerScript`" -Port $Port"
        $psi.UseShellExecute = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        WDLog "✅ Server relaunched (PID $($proc.Id)) — waiting for readiness..."
        Start-Sleep 5
        if (Test-ServerAlive) {
            WDLog "✅ Server is ONLINE and responding correctly"
        } else {
            WDLog "⚠️  Server launched but not responding yet — will retry next cycle"
        }
    } catch {
        WDLog "❌ Restart FAILED: $($_.Exception.Message)"
    }
}

function Check-SystemHealth {
    # RAM check
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $ramPct = [math]::Round((1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 1)
            if ($ramPct -gt 90) { WDLog "🔴 CRITICAL RAM: $ramPct% used" }
            elseif ($ramPct -gt 80) { WDLog "🟡 HIGH RAM: $ramPct% used" }
        }
    } catch {}
    
    # Disk check
    try {
        $disk = Get-PSDrive C -ErrorAction SilentlyContinue
        if ($disk) {
            $pct = [math]::Round($disk.Used / ($disk.Used + $disk.Free) * 100, 1)
            if ($pct -gt 95) { WDLog "🔴 CRITICAL DISK: C: at $pct%" }
            elseif ($pct -gt 85) { WDLog "🟡 LOW DISK: C: at $pct%" }
        }
    } catch {}

    # CPU check
    try {
        $cpu = [math]::Round((Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | 
               Measure-Object -Property LoadPercentage -Average).Average, 1)
        if ($cpu -gt 90) { WDLog "🔴 CRITICAL CPU: $cpu%" }
    } catch {}
}

# ─── MAIN WATCHDOG LOOP ─────────────────────────────────────────────

WDLog "═══════════════════════════════════════════"
WDLog "Self-Heal Watchdog STARTED"
WDLog "Monitoring: $ServerScript"
WDLog "Port: $Port | Check interval: 30s"
WDLog "═══════════════════════════════════════════"

$consecutiveFails = 0
$totalRestarts    = 0
$cycleCount       = 0

while ($true) {
    $cycleCount++

    # Health check every cycle (30s)
    $alive = Test-ServerAlive

    if ($alive) {
        $consecutiveFails = 0
        if ($cycleCount % 10 -eq 0) {
            # Every 5 minutes, log heartbeat + system health
            WDLog "💚 Heartbeat OK — Server alive | Cycle $cycleCount | Restarts: $totalRestarts"
            Check-SystemHealth
        }
    } else {
        $consecutiveFails++
        WDLog "🔴 Fail #$consecutiveFails — Server not responding on port $Port"
        
        if ($consecutiveFails -ge 2) {
            # 2 consecutive fails = restart
            Restart-BridgeServer
            $totalRestarts++
            $consecutiveFails = 0
            WDLog "Total restarts today: $totalRestarts"
        }
    }

    Start-Sleep 30
}
