# ==========================================================================================
#         ULTIMATE TOOLKIT - WEB COMMAND CENTER SERVER
#         Hosts a local HTTP server on http://localhost:8282
# ==========================================================================================

$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Path

# Command Definitions
$commands = @{
    "sfc" = @{
        Name = "SFC System Repair"
        Script = {
            Write-Output "Running System File Checker (sfc /scannow)..."
            sfc /scannow
        }
    }
    "dism" = @{
        Name = "DISM Image Health Restoration"
        Script = {
            Write-Output "Running Deployment Image Servicing and Management (DISM)..."
            dism /online /cleanup-image /restorehealth
        }
    }
    "flushdns" = @{
        Name = "DNS Flush & Network Stack Repair"
        Script = {
            Write-Output "Flushing DNS resolver cache..."
            ipconfig /flushdns
            Write-Output "Resetting Winsock catalog..."
            netsh winsock reset
            Write-Output "Resetting IP stack..."
            netsh int ip reset
            Write-Output "Releasing and renewing IP configurations..."
            ipconfig /release
            ipconfig /renew
            Write-Output "DNS and network stack repair completed."
        }
    }
    "wifi" = @{
        Name = "Retrieve Saved WiFi Passwords"
        Script = {
            Write-Output "Retrieving saved WiFi profiles from this computer..."
            $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
                $line = $_.Line
                if ($line -match ":\s*(.*)$") {
                    $matches[1].Trim()
                }
            }
            if ($null -eq $profiles -or $profiles.Count -eq 0) {
                Write-Output "No saved WiFi profiles found."
            } else {
                Write-Output "Found $($profiles.Count) profiles. Decrypting keys..."
                Write-Output "=========================================================="
                foreach ($profile in $profiles) {
                    Write-Output "SSID/Profile Name : $profile"
                    $pass = "None (Open Network / Enterprise)"
                    $details = netsh wlan show profile name="$profile" key=clear
                    $keyLine = $details | Select-String "Key Content"
                    if ($keyLine -and $keyLine.Line -match ":\s*(.*)$") {
                        $pass = $matches[1].Trim()
                    }
                    Write-Output "Security Password : $pass"
                    Write-Output "----------------------------------------------------------"
                }
            }
        }
    }
    "cleanup" = @{
        Name = "System Cache & Temporary Files Cleanup"
        Script = {
            Write-Output "Starting Windows System cleanup..."
            
            # Temp folders
            $tempDirs = @(
                "$env:TEMP",
                "C:\Windows\Temp",
                "C:\Windows\Prefetch"
            )
            foreach ($dir in $tempDirs) {
                if (Test-Path $dir) {
                    Write-Output "Cleaning contents of $dir..."
                    Get-ChildItem -Path $dir -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                        try {
                            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        } catch {}
                    }
                }
            }
            
            # Recycle Bin
            Write-Output "Emptying System Recycle Bin..."
            try {
                $sha = New-Object -ComObject Shell.Application
                $bin = $sha.Namespace(0x0a) # Recycle Bin namespace ID
                $bin.Items() | ForEach-Object { 
                    Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue 
                }
                Write-Output "Recycle bin emptied."
            } catch {
                Write-Output "Could not empty recycle bin programmatically."
            }
            
            # DNS Client Cache
            Write-Output "Clearing DNS cache..."
            Clear-DnsClientCache -ErrorAction SilentlyContinue
            
            Write-Output "Cleanup completed successfully!"
        }
    }
    "spooler" = @{
        Name = "Restart Printer Spooler"
        Script = {
            Write-Output "Stopping Print Spooler service..."
            Stop-Service -Name spooler -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            Write-Output "Starting Print Spooler service..."
            Start-Service -Name spooler
            Write-Output "Print Spooler service successfully restarted."
        }
    }
    "battery" = @{
        Name = "Generate HTML Battery Health Report"
        Script = {
            Write-Output "Generating detailed battery report..."
            $outPath = "$using:PSScriptRoot\..\Logs\battery-report.html"
            powercfg /batteryreport /output "$outPath"
            Write-Output "Report generated at Logs\battery-report.html"
            Write-Output "You can view this report inside the Logs directory."
        }
    }
    "sys_report" = @{
        Name = "System Inventory Report"
        Script = {
            Write-Output "Executing System Inventory Report..."
            $reportScript = "$using:PSScriptRoot\SystemInventoryReport.ps1"
            if (Test-Path $reportScript) {
                powershell -NoProfile -ExecutionPolicy Bypass -File "$reportScript"
            } else {
                Write-Output "Error: SystemInventoryReport.ps1 not found in Modules."
            }
        }
    }
    "scan_subnet" = @{
        Name = "Active Subnet IP Host Discovery"
        Script = {
            Write-Output "Detecting local network interfaces..."
            $ipConfig = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
                $_.InterfaceAlias -notlike "*Loopback*" -and 
                $_.IPAddress -notlike "169.254.*" -and 
                $_.IPAddress -ne "127.0.0.1" 
            } | Select-Object -First 1
            
            if ($null -eq $ipConfig) {
                Write-Output "Error: No active IP interfaces found to scan."
                return
            }
            
            $ip = $ipConfig.IPAddress
            $octets = $ip.Split(".")
            $subnet = "$($octets[0]).$($octets[1]).$($octets[2])"
            Write-Output "Local IP detected: $ip on interface '$($ipConfig.InterfaceAlias)'"
            Write-Output "Scanning subnet range: $subnet.1 to $subnet.254..."
            Write-Output "Launching fast multi-threaded ping sweep (using RunspacePool)..."
            Write-Output "=========================================================="
            
            # Use RunspacePool for extreme speed in pings
            $RunspacePool = [runspacefactory]::CreateRunspacePool(1, 40)
            $RunspacePool.Open()
            $Jobs = [System.Collections.Generic.List[PSObject]]::new()
            
            for ($i = 1; $i -le 254; $i++) {
                $target = "$subnet.$i"
                $PowerShell = [PowerShell]::Create().AddScript({
                    param($targetIP)
                    $ping = New-Object System.Net.NetworkInformation.Ping
                    try {
                        $reply = $ping.Send($targetIP, 120)
                        if ($reply.Status -eq "Success") {
                            return $targetIP
                        }
                    } catch {}
                    return $null
                }).AddArgument($target)
                
                $PowerShell.RunspacePool = $RunspacePool
                $Jobs.Add([PSCustomObject]@{
                    Instance = $PowerShell
                    Result = $PowerShell.BeginInvoke()
                })
            }
            
            # Wait for all async jobs
            while ($Jobs.Result.IsCompleted -contains $false) {
                Start-Sleep -Milliseconds 50
            }
            
            $activeHosts = [System.Collections.Generic.List[string]]::new()
            foreach ($Job in $Jobs) {
                $res = $Job.Instance.EndInvoke($Job.Result)
                if ($res) {
                    $activeHosts.Add($res)
                }
                $Job.Instance.Dispose()
            }
            $RunspacePool.Close()
            $RunspacePool.Dispose()
            
            Write-Output "Scan complete. Active Network Hosts found:"
            if ($activeHosts.Count -eq 0) {
                Write-Output "No hosts responded (besides this PC)."
            } else {
                foreach ($hostIP in $activeHosts) {
                    $status = if ($hostIP -eq $ip) { " (This PC)" } else { "" }
                    Write-Output "  -> $hostIP$status"
                }
            }
            Write-Output "=========================================================="
        }
    }
}

# Ensure Logs folder exists
$logFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "Logs"
if (!(Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

$global:logPath = Join-Path $logFolder "web_command.log"
Set-Content -Path $global:logPath -Value ""

$global:RunningPowerShell = $null
$global:AsyncResult = $null

# Set up HTTP Listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8282/")

try {
    $listener.Start()
    Write-Host "===========================================================" -ForegroundColor Green
    Write-Host "   ULTIMATE TOOLKIT WEB DASHBOARD IS RUNNING" -ForegroundColor Green
    Write-Host "   Access URL: http://localhost:8282/" -ForegroundColor Cyan
    Write-Host "   Close this window or click shutdown in browser to stop." -ForegroundColor Yellow
    Write-Host "===========================================================" -ForegroundColor Green
} catch {
    Write-Host "Error starting web server on port 8282: $_" -ForegroundColor Red
    Read-Host "Press enter to exit..."
    exit 1
}

# Auto-open browser
Start-Process "http://localhost:8282/"

# Server Loop
$running = $true
while ($running -and $listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $url = $request.Url.LocalPath
        
        if ($url -eq "/" -or $url -eq "/index.html") {
            $htmlPath = Join-Path $PSScriptRoot "web_assets\index.html"
            if (Test-Path $htmlPath) {
                $bytes = [System.IO.File]::ReadAllBytes($htmlPath)
                $response.ContentType = "text/html; charset=utf-8"
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $response.StatusCode = 404
                $bytes = [System.Text.Encoding]::UTF8.GetBytes("Dashboard assets not found. Create index.html in Modules/web_assets.")
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        }
        elseif ($url -eq "/api/sysinfo") {
            $os = Get-CimInstance Win32_OperatingSystem
            
            # Fast CPU percentage calculation
            $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
            $cpuPercent = if ($cpu.Average) { [Math]::Round($cpu.Average, 1) } else { 0.0 }
            
            # RAM metrics
            $totalRam = $os.TotalVisibleMemorySize
            $freeRam = $os.FreePhysicalMemory
            $usedRam = $totalRam - $freeRam
            $ramPercent = [Math]::Round(($usedRam / $totalRam) * 100, 1)
            
            # Disk metrics (System Drive C:)
            $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
            $totalDisk = $disk.Size
            $freeDisk = $disk.FreeSpace
            $usedDisk = $totalDisk - $freeDisk
            $diskPercent = [Math]::Round(($usedDisk / $totalDisk) * 100, 1)
            
            # Battery metrics
            $battery = Get-CimInstance Win32_Battery
            if ($battery) {
                $batteryPercent = $battery.EstimatedChargeRemaining
                $batteryStatus = $battery.BatteryStatus
                # 2 = Discharging/Plugged, 6 = Charging, 7 = Fully Charged, 8 = Default
                $batteryPlugged = ($batteryStatus -eq 2 -or $batteryStatus -eq 6 -or $batteryStatus -eq 7 -or $batteryStatus -eq 8)
            } else {
                $batteryPercent = 100
                $batteryPlugged = $true
            }
            
            # Uptime
            $uptime = (Get-Date) - $os.LastBootUpTime
            $uptimeStr = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
            
            # Top Memory Processes
            $topProcesses = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | ForEach-Object {
                [PSCustomObject]@{
                    name = $_.ProcessName
                    ram = [Math]::Round($_.WorkingSet64 / 1MB, 1)
                    id = $_.Id
                }
            }
            
            $data = @{
                cpu = $cpuPercent
                ram = $ramPercent
                ram_total = [Math]::Round($totalRam / 1MB, 1)
                ram_used = [Math]::Round($usedRam / 1MB, 1)
                disk = $diskPercent
                disk_total = [Math]::Round($totalDisk / 1GB, 1)
                disk_used = [Math]::Round($usedDisk / 1GB, 1)
                battery = $batteryPercent
                battery_plugged = $batteryPlugged
                uptime = $uptimeStr
                computer_name = $env:COMPUTERNAME
                user_name = $env:USERNAME
                os_name = $os.Caption
                processes = $topProcesses
            }
            
            $json = ConvertTo-Json $data -Depth 4
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        elseif ($url -eq "/api/run") {
            $cmd = $request.QueryString["cmd"]
            $rawCmd = $request.QueryString["raw_cmd"]
            
            $isBusy = $false
            if ($global:AsyncResult -and -not $global:AsyncResult.IsCompleted) {
                $isBusy = $true
            }
            
            if ($isBusy) {
                $response.StatusCode = 409
                $json = '{"status": "error", "message": "A command task is currently running. Please stop or wait for it to finish."}'
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $response.ContentType = "application/json"
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $scriptBlock = $null
                $displayName = "Custom Command"
                
                if ($cmd -eq "custom" -and $rawCmd) {
                    $displayName = $rawCmd
                    $scriptBlock = [scriptblock]::Create($rawCmd)
                } elseif ($commands.ContainsKey($cmd)) {
                    $displayName = $commands[$cmd].Name
                    $scriptBlock = $commands[$cmd].Script
                }
                
                if ($null -ne $scriptBlock) {
                    # Dispose old runner
                    if ($global:RunningPowerShell) {
                        $global:RunningPowerShell.Dispose()
                    }
                    
                    # Create runner
                    $global:RunningPowerShell = [PowerShell]::Create()
                    
                    # Note: We must share the PSScriptRoot for any child scripts.
                    # We pass the block, log path, and name.
                    $global:RunningPowerShell.AddScript({
                        param($cmdBlock, $logPath, $name)
                        Set-Content -Path $logPath -Value ">>> Starting: $name`r`n"
                        try {
                            & $cmdBlock 2>&1 | ForEach-Object {
                                $line = $_.ToString()
                                Add-Content -Path $logPath -Value $line
                            }
                        } catch {
                            Add-Content -Path $logPath -Value "Error details: $_"
                        }
                        Add-Content -Path $logPath -Value "`r`n>>> Command execution completed."
                    }).AddArgument($scriptBlock).AddArgument($global:logPath).AddArgument($displayName)
                    
                    $global:AsyncResult = $global:RunningPowerShell.BeginInvoke()
                    
                    $json = '{"status": "started", "name": "' + $displayName.Replace('"', '\"') + '"}'
                } else {
                    $response.StatusCode = 400
                    $json = '{"status": "error", "message": "Invalid command specified."}'
                }
                
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $response.ContentType = "application/json"
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        }
        elseif ($url -eq "/api/log") {
            $offset = 0
            if ($request.QueryString["lineOffset"]) {
                [void][int]::TryParse($request.QueryString["lineOffset"], [ref]$offset)
            }
            
            $lines = @()
            if (Test-Path $global:logPath) {
                $lines = Get-Content -Path $global:logPath -ErrorAction SilentlyContinue
            }
            
            $totalLines = if ($lines) { $lines.Count } else { 0 }
            $newLines = @()
            if ($offset -lt $totalLines) {
                if ($offset -eq 0) {
                    $newLines = $lines
                } else {
                    $newLines = $lines[$offset..($totalLines - 1)]
                }
            }
            
            $runningVal = $false
            if ($global:AsyncResult -and -not $global:AsyncResult.IsCompleted) {
                $runningVal = $true
            }
            
            $data = @{
                lines = $newLines
                offset = $totalLines
                running = $runningVal
            }
            
            $json = ConvertTo-Json $data
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        elseif ($url -eq "/api/stop") {
            if ($global:RunningPowerShell -and $global:AsyncResult -and -not $global:AsyncResult.IsCompleted) {
                $global:RunningPowerShell.Stop()
                Add-Content -Path $global:logPath -Value "`r`n>>> Command execution stopped by user."
                $json = '{"status": "stopped"}'
            } else {
                $json = '{"status": "not_running"}'
            }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        elseif ($url -eq "/api/shutdown") {
            $json = '{"status": "shutdown"}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.Close()
            $running = $false
            break
        }
        else {
            $response.StatusCode = 404
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        
        $response.Close()
    } catch {
        # Log to host screen if request fails
        Write-Host "Error processing HTTP request: $_" -ForegroundColor DarkYellow
        try {
            $response.StatusCode = 500
            $response.Close()
        } catch {}
    }
}

# Cleanup resources
if ($listener.IsListening) {
    $listener.Stop()
    $listener.Close()
}
if ($global:RunningPowerShell) {
    $global:RunningPowerShell.Dispose()
}
Write-Host "Server shut down." -ForegroundColor Red
