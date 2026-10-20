param(
    [string]$OutputRoot = (Join-Path $env:SystemDrive 'System Inventory'),
    [switch]$IncludeSecrets,
    [switch]$Open
)

$ErrorActionPreference = 'SilentlyContinue'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir '..'))
$FallbackRoot = Join-Path $ToolkitRoot 'Logs\SystemInventory'

function Initialize-OutputRoot {
    param([string]$PreferredRoot, [string]$Fallback)

    foreach ($path in @($PreferredRoot, $Fallback)) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        try {
            if (-not (Test-Path -LiteralPath $path)) {
                New-Item -ItemType Directory -Force -Path $path | Out-Null
            }
            return [System.IO.Path]::GetFullPath($path)
        } catch {
            continue
        }
    }

    return [System.IO.Path]::GetFullPath($env:TEMP)
}

$OutputRoot = Initialize-OutputRoot -PreferredRoot $OutputRoot -Fallback $FallbackRoot

function ConvertTo-HtmlText {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'N/A' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Format-GB {
    param($Bytes)
    if ($null -eq $Bytes -or [double]$Bytes -le 0) { return 'N/A' }
    return ('{0:N2} GB' -f ([double]$Bytes / 1GB))
}

function Format-DateValue {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'N/A' }
    try {
        if ($Value -is [datetime]) { return $Value.ToString('dd-MMM-yyyy hh:mm tt') }
        $text = [string]$Value
        if ($text -match '^\d{8}$') {
            return ([datetime]::ParseExact($text, 'yyyyMMdd', $null)).ToString('dd-MMM-yyyy')
        }
        return ([datetime]$Value).ToString('dd-MMM-yyyy hh:mm tt')
    } catch {
        return [string]$Value
    }
}

function ConvertFrom-DigitalProductId {
    param([byte[]]$DigitalProductId)

    if ($null -eq $DigitalProductId -or $DigitalProductId.Length -lt 67) { return '' }

    try {
        $keyOffset = 52
        $chars = 'BCDFGHJKMPQRTVWXY2346789'.ToCharArray()
        $isWin8 = [math]::Floor($DigitalProductId[66] / 6) -band 1
        $DigitalProductId[66] = ($DigitalProductId[66] -band 0xF7) -bor (($isWin8 -band 2) * 4)
        $result = ''

        for ($i = 24; $i -ge 0; $i--) {
            $current = 0
            for ($j = 14; $j -ge 0; $j--) {
                $current = ($current * 256) -bxor $DigitalProductId[$j + $keyOffset]
                $DigitalProductId[$j + $keyOffset] = [math]::Floor($current / 24)
                $current = $current % 24
            }
            $result = $chars[$current] + $result
        }

        if ($isWin8 -eq 1) {
            $first = $result.Substring(1, $current)
            $last = $result.Substring($current + 1)
            $result = $first + 'N' + $last
        }

        return (($result -split '(.{5})' | Where-Object { $_ }) -join '-').Trim('-')
    } catch {
        return ''
    }
}

function Get-WindowsKey {
    $key = ''

    try {
        $lic = Get-CimInstance -Query 'select OA3xOriginalProductKey from SoftwareLicensingService'
        if ($lic.OA3xOriginalProductKey) { $key = $lic.OA3xOriginalProductKey }
    } catch {}

    if ([string]::IsNullOrWhiteSpace($key)) {
        try {
            $digital = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name DigitalProductId).DigitalProductId
            $key = ConvertFrom-DigitalProductId $digital
        } catch {}
    }

    if ([string]::IsNullOrWhiteSpace($key)) { return 'Not available' }
    return $key
}

function Get-CellClass {
    param(
        [string]$Column,
        $Value,
        $Row
    )

    $text = ([string]$Value).Trim()
    $lower = $text.ToLowerInvariant()

    if ($Column -match '(Status|Health|Operational|Active|Enabled)') {
        if ($lower -match '^(ok|healthy|normal|active|running|online|ready|enabled|true|success|good|found)$') { return 'status-ok' }
        if ($lower -match '(disabled|inactive|stopped|offline|error|fail|failed|critical|warning|degraded|unknown|bad|no media)') { return 'status-bad' }
        if ($lower -match '(warn|caution|attention)') { return 'status-warn' }
    }

    if ($Column -match 'FreePercent') {
        $number = 0.0
        if ([double]::TryParse(($text -replace '[^0-9.]',''), [ref]$number)) {
            if ($number -lt 10) { return 'status-bad' }
            if ($number -lt 20) { return 'status-warn' }
            return 'status-ok'
        }
    }

    if ($Column -match 'UsedPercent') {
        $number = 0.0
        if ([double]::TryParse(($text -replace '[^0-9.]',''), [ref]$number)) {
            if ($number -ge 90) { return 'status-bad' }
            if ($number -ge 80) { return 'status-warn' }
            return 'status-ok'
        }
    }

    if ($Column -match 'FreeSpace' -and $Row -and $Row.PSObject.Properties.Name -contains 'FreePercent') {
        return Get-CellClass -Column 'FreePercent' -Value $Row.FreePercent -Row $Row
    }

    if ($Column -match 'UsedSpace' -and $Row -and $Row.PSObject.Properties.Name -contains 'UsedPercent') {
        return Get-CellClass -Column 'UsedPercent' -Value $Row.UsedPercent -Row $Row
    }

    return ''
}

function New-KvTable {
    param([System.Collections.IDictionary]$Map)

    $rows = foreach ($item in $Map.GetEnumerator()) {
        $class = Get-CellClass -Column ([string]$item.Key) -Value $item.Value -Row $null
        $classAttr = if ($class) { ' class="{0}"' -f $class } else { '' }
        '<tr><td class="key">{0}</td><td{1}>{2}</td></tr>' -f (ConvertTo-HtmlText $item.Key), $classAttr, (ConvertTo-HtmlText $item.Value)
    }

    return '<table class="kv"><tbody>{0}</tbody></table>' -f ($rows -join "`n")
}

function New-Table {
    param(
        [object[]]$Rows,
        [string[]]$Columns,
        [hashtable]$Headers = @{}
    )

    $columnCount = [Math]::Max(1, $Columns.Count)
    $head = foreach ($column in $Columns) {
        $label = if ($Headers.ContainsKey($column)) { $Headers[$column] } else { $column }
        '<th>{0}</th>' -f (ConvertTo-HtmlText $label)
    }

    $body = @()
    foreach ($row in @($Rows)) {
        $cells = foreach ($column in $Columns) {
            $value = $null
            if ($row -is [System.Collections.IDictionary]) {
                if ($row.Contains($column)) { $value = $row[$column] }
            } elseif ($row.PSObject.Properties.Name -contains $column) {
                $value = $row.$column
            }
            $class = Get-CellClass -Column $column -Value $value -Row $row
            $classAttr = if ($class) { ' class="{0}"' -f $class } else { '' }
            '<td{0}>{1}</td>' -f $classAttr, (ConvertTo-HtmlText $value)
        }
        $body += '<tr>{0}</tr>' -f ($cells -join '')
    }

    if ($body.Count -eq 0) {
        $body += '<tr><td colspan="{0}" class="empty">No data found</td></tr>' -f $columnCount
    }

    return '<table><thead><tr>{0}</tr></thead><tbody>{1}</tbody></table>' -f ($head -join ''), ($body -join "`n")
}

function New-Section {
    param(
        [string]$Title,
        [string]$Body,
        [switch]$Open
    )

    $openText = if ($Open) { ' open' } else { '' }
    return @"
<details class="section"$openText data-title="$(ConvertTo-HtmlText $Title)">
  <summary><span>$(ConvertTo-HtmlText $Title)</span><span class="toggle">+</span></summary>
  <div class="section-body">
    $Body
  </div>
</details>
"@
}

function Convert-MonitorString {
    param($Value)
    if ($null -eq $Value) { return 'N/A' }
    $chars = @()
    foreach ($code in $Value) {
        if ($code -and [int]$code -gt 0) { $chars += [char][int]$code }
    }
    $text = -join $chars
    if ([string]::IsNullOrWhiteSpace($text)) { return 'N/A' }
    return $text
}

function Get-RegistryApps {
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $apps = foreach ($path in $paths) {
        Get-ItemProperty -Path $path | Where-Object { $_.DisplayName } | ForEach-Object {
            [pscustomobject]@{
                Name = $_.DisplayName
                Version = $_.DisplayVersion
                Publisher = $_.Publisher
                InstallDate = Format-DateValue $_.InstallDate
            }
        }
    }

    return @($apps | Sort-Object Name, Version -Unique)
}

function Read-ToolsCatalog {
    $catalogPath = Join-Path $ToolkitRoot 'Config\tools.catalog'
    $items = @()
    if (-not (Test-Path -LiteralPath $catalogPath)) { return $items }

    foreach ($line in Get-Content -LiteralPath $catalogPath) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) { continue }
        $parts = $line -split '\|', 5
        if ($parts.Count -lt 4) { continue }

        $type = $parts[2].Trim()
        $target = $parts[3].Trim()
        if ($type -ne 'exe') { continue }

        $resolved = if ([System.IO.Path]::IsPathRooted($target)) {
            $target
        } else {
            Join-Path $ToolkitRoot $target
        }

        if (Test-Path -LiteralPath $resolved) {
            $file = Get-Item -LiteralPath $resolved
            $items += [pscustomobject]@{
                ID = $parts[0].Trim()
                Name = $parts[1].Trim()
                Path = $target
                Size = Format-GB $file.Length
                LastModified = Format-DateValue $file.LastWriteTime
                Status = 'Ready'
            }
        }
    }

    return @($items | Sort-Object Name)
}

function Get-WifiProfiles {
    $profiles = @()
    $raw = netsh wlan show profiles 2>$null
    foreach ($line in $raw) {
        if ($line -match '^\s*All User Profile\s*:\s*(.+?)\s*$') {
            $name = $matches[1].Trim().Trim('"')
            if ([string]::IsNullOrWhiteSpace($name)) { continue }

            $password = 'Not found'
            $keyStatus = 'Not found'
            $profileRaw = & netsh wlan show profile name="$name" key=clear 2>$null
            $keyLine = @($profileRaw | Where-Object { $_ -match '^\s*Key Content\s*:\s*(.+?)\s*$' } | Select-Object -First 1)
            if ($keyLine.Count -gt 0 -and $keyLine[0] -match '^\s*Key Content\s*:\s*(.+?)\s*$') {
                $password = $matches[1].Trim()
                $keyStatus = 'Found'
            }

            $profiles += [pscustomobject]@{
                SSID = $name
                Password = $password
                Status = $keyStatus
            }
        }
    }
    return $profiles
}

Write-Host 'Collecting system inventory...'

$computerName = $env:COMPUTERNAME
$userName = $env:USERNAME
$now = Get-Date

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$baseboard = Get-CimInstance Win32_BaseBoard
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$uptime = if ($os.LastBootUpTime) { New-TimeSpan -Start $os.LastBootUpTime -End $now } else { $null }
$uptimeText = if ($uptime) { '{0} Days, {1} Hours, {2} Mins' -f $uptime.Days, $uptime.Hours, $uptime.Minutes } else { 'N/A' }

$productKey = Get-WindowsKey

$productId = 'N/A'
try {
    $productId = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name ProductId).ProductId
} catch {}

$networkIdentity = if ($cs.PartOfDomain) { "Domain: $($cs.Domain)" } else { "Workgroup: $($cs.Workgroup)" }

$osDetails = [ordered]@{
    'Current Logged User' = $userName
    'Computer Description' = if ($os.Description) { $os.Description } else { 'No Description Set' }
    'OS Edition' = '{0} (Version: {1})' -f $os.Caption, $os.Version
    'Build Version' = '{0} ({1})' -f $os.Version, $os.OSArchitecture
    'Windows Key' = $productKey
    'Windows Product ID' = $productId
    'Network Identity' = $networkIdentity
    'Install Date' = Format-DateValue $os.InstallDate
    'Last Boot Time' = Format-DateValue $os.LastBootUpTime
    'System Uptime' = $uptimeText
}

$users = @()
try {
    $users = @(Get-LocalUser -ErrorAction Stop | Sort-Object Name | ForEach-Object {
        $status = if ($_.Enabled) { 'Active' } else { 'Disabled' }
        [pscustomobject]@{
            Username = $_.Name
            AccountType = 'Local'
            Caption = if ($_.Description) { $_.Description } else { "$env:COMPUTERNAME\$($_.Name)" }
            Status = $status
        }
    })
} catch {
    try {
        $users = @(Get-CimInstance Win32_UserAccount -Filter 'LocalAccount=True' -ErrorAction Stop | Sort-Object Name | ForEach-Object {
            $status = if ($_.Disabled) { 'Disabled' } else { 'Active' }
            [pscustomobject]@{
                Username = $_.Name
                AccountType = 'Local'
                Caption = $_.Caption
                Status = $status
            }
        })
    } catch {
        try {
            $netUsers = net user 2>$null | Where-Object { $_ -and $_ -notmatch 'User accounts for' -and $_ -notmatch '----' -and $_ -notmatch 'The command completed successfully' }
            $userNames = @()
            foreach ($line in $netUsers) {
                $userNames += $line -split '\s{2,}' | Where-Object { $_.Trim() }
            }
            $users = @($userNames | Sort-Object | ForEach-Object {
                [pscustomobject]@{
                    Username = $_
                    AccountType = 'Local'
                    Caption = "$env:COMPUTERNAME\$_"
                    Status = 'Active'
                }
            })
        } catch {}
    }
}

$boardCpu = [ordered]@{
    'Manufacturer' = $cs.Manufacturer
    'System Model' = $cs.Model
    'System Serial / Service Tag' = $bios.SerialNumber
    'System UUID' = if ($cs.UUID) { $cs.UUID } else { 'N/A' }
    'Motherboard Serial' = $baseboard.SerialNumber
    'BIOS Version/Date' = '{0} {1}' -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion
    'CPU (Processor)' = $cpu.Name
    'CPU Cores / Logical' = '{0} Cores / {1} Threads' -f $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors
}

$memoryModules = @(Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
    [pscustomobject]@{
        Slot = $_.BankLabel
        Size = Format-GB $_.Capacity
        Speed = if ($_.Speed) { "$($_.Speed) MHz" } else { 'N/A' }
        Manufacturer = $_.Manufacturer
        PartNumber = $_.PartNumber
    }
})
$memoryArrays = @(Get-CimInstance Win32_PhysicalMemoryArray)
$slotTotal = ($memoryArrays | Measure-Object -Property MemoryDevices -Sum).Sum
if (-not $slotTotal) { $slotTotal = $memoryModules.Count }
$memorySummary = '<p class="summary-line"><strong>Total RAM:</strong> {0} | <strong>Slots:</strong> Total: {1} | Occupied: {2} | Empty: {3}</p>' -f (Format-GB $cs.TotalPhysicalMemory), $slotTotal, $memoryModules.Count, [Math]::Max(0, $slotTotal - $memoryModules.Count)

$logicalDisks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
    $used = if ($_.Size -and $_.FreeSpace -ne $null) { [double]$_.Size - [double]$_.FreeSpace } else { $null }
    $usedPercent = if ($_.Size -and $used -ne $null) { ($used / $_.Size) * 100 } else { $null }
    $freePercent = if ($_.Size) { ($_.FreeSpace / $_.Size) * 100 } else { $null }
    [pscustomobject]@{
        Drive = $_.DeviceID
        VolumeName = $_.VolumeName
        FileSystem = $_.FileSystem
        TotalSize = Format-GB $_.Size
        UsedSpace = Format-GB $used
        FreeSpace = Format-GB $_.FreeSpace
        UsedPercent = if ($usedPercent -ne $null) { '{0:N1}%' -f $usedPercent } else { 'N/A' }
        FreePercent = if ($freePercent -ne $null) { '{0:N1}%' -f $freePercent } else { 'N/A' }
        HealthStatus = if ($freePercent -eq $null) { 'Unknown' } elseif ($freePercent -lt 10) { 'Critical' } elseif ($freePercent -lt 20) { 'Warning' } else { 'OK' }
    }
})

$physicalDisks = @(Get-PhysicalDisk | ForEach-Object {
    [pscustomobject]@{
        DiskModel = $_.FriendlyName
        SerialNumber = $_.SerialNumber
        MediaType = $_.MediaType
        BusType = $_.BusType
        TotalSize = Format-GB $_.Size
        HealthStatus = $_.HealthStatus
        OperationalStatus = ($_.OperationalStatus -join ', ')
    }
})
if ($physicalDisks.Count -eq 0) {
    $physicalDisks = @(Get-CimInstance Win32_DiskDrive | ForEach-Object {
        [pscustomobject]@{
            DiskModel = $_.Model
            SerialNumber = $_.SerialNumber
            MediaType = $_.MediaType
            BusType = $_.InterfaceType
            TotalSize = Format-GB $_.Size
            HealthStatus = $_.Status
            OperationalStatus = $_.Status
        }
    })
}

$networkRows = @()
try {
    $networkRows = @(Get-NetIPConfiguration | ForEach-Object {
        $adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex
        $ip = @($_.IPv4Address | Select-Object -First 1)
        $gateway = @($_.IPv4DefaultGateway | Select-Object -First 1)
        [pscustomobject]@{
            Interface = $_.InterfaceAlias
            IPAddress = if ($ip.Count) { $ip[0].IPAddress } else { 'N/A' }
            Prefix = if ($ip.Count) { $ip[0].PrefixLength } else { 'N/A' }
            Gateway = if ($gateway.Count) { $gateway[0].NextHop } else { 'N/A' }
            MacAddress = if ($adapter) { $adapter.MacAddress } else { 'N/A' }
            LinkSpeed = if ($adapter) { $adapter.LinkSpeed } else { 'N/A' }
        }
    })
} catch {}

$wifiRows = @(Get-WifiProfiles)

$shares = @(Get-CimInstance Win32_Share | Where-Object { $_.Name -notmatch '\$$' } | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{
        ShareName = $_.Name
        LocalPath = $_.Path
        Description = $_.Description
    }
})

$printerRows = @(Get-CimInstance Win32_Printer | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{
        PrinterName = $_.Name
        PortName = $_.PortName
        IPAddress = 'N/A'
        DriverName = $_.DriverName
        Status = $_.PrinterStatus
    }
})

$monitorRows = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
    [pscustomobject]@{
        Manufacturer = Convert-MonitorString $_.ManufacturerName
        ModelName = Convert-MonitorString $_.UserFriendlyName
        SerialNumber = Convert-MonitorString $_.SerialNumberID
    }
})

$apps = @(Get-RegistryApps)
$portableTools = @(Read-ToolsCatalog)
$hotfixes = @(Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 30 | ForEach-Object {
    [pscustomobject]@{
        HotFixID = $_.HotFixID
        Description = $_.Description
        InstalledOn = Format-DateValue $_.InstalledOn
        InstalledBy = $_.InstalledBy
    }
})

$batteryRows = @(Get-CimInstance Win32_Battery | ForEach-Object {
    [pscustomobject]@{
        Name = $_.Name
        Status = $_.Status
        EstimatedCharge = if ($_.EstimatedChargeRemaining -ne $null) { "$($_.EstimatedChargeRemaining)%" } else { 'N/A' }
        EstimatedRunTime = if ($_.EstimatedRunTime -and $_.EstimatedRunTime -ne 71582788) { "$($_.EstimatedRunTime) minutes" } else { 'N/A' }
    }
})

$sections = @()
$sections += New-Section -Title 'Operating System Details' -Body (New-KvTable $osDetails) -Open
$sections += New-Section -Title 'User Accounts' -Body (New-Table $users @('Username','AccountType','Caption','Status') @{ AccountType = 'Account Type'; Caption = 'Full Caption' })
$sections += New-Section -Title 'Motherboard & CPU Information' -Body (New-KvTable $boardCpu)
$sections += New-Section -Title 'Memory Details' -Body ($memorySummary + (New-Table $memoryModules @('Slot','Size','Speed','Manufacturer','PartNumber') @{ PartNumber = 'Part Number' }))
$sections += New-Section -Title 'Storage & Physical Disk Health' -Body ((New-Table $logicalDisks @('Drive','VolumeName','FileSystem','TotalSize','UsedSpace','FreeSpace','UsedPercent','FreePercent','HealthStatus') @{ VolumeName = 'Volume Name'; TotalSize = 'Total Size'; UsedSpace = 'Used Space'; FreeSpace = 'Free Space'; UsedPercent = 'Used %'; FreePercent = 'Free %'; HealthStatus = 'Health Status' }) + '<h3>Physical Disks</h3>' + (New-Table $physicalDisks @('DiskModel','SerialNumber','MediaType','BusType','TotalSize','HealthStatus','OperationalStatus') @{ DiskModel = 'Disk Model'; SerialNumber = 'Serial Number'; MediaType = 'Media Type'; BusType = 'Bus Type'; TotalSize = 'Total Size'; HealthStatus = 'Health Status'; OperationalStatus = 'Operational Status' }))
$sections += New-Section -Title 'Network Configuration & Link Speed' -Body (New-Table $networkRows @('Interface','IPAddress','Prefix','Gateway','MacAddress','LinkSpeed') @{ IPAddress = 'IP Address'; MacAddress = 'MAC Address'; LinkSpeed = 'Link Speed' })
$sections += New-Section -Title 'Saved Wi-Fi' -Body (New-Table $wifiRows @('SSID','Password','Status') @{ SSID = 'Wi-Fi SSID'; Password = 'Password (Key Content)' })
$sections += New-Section -Title 'Shared Folders Configuration' -Body (New-Table $shares @('ShareName','LocalPath','Description') @{ ShareName = 'Share Name'; LocalPath = 'Local Path' })
$sections += New-Section -Title 'Installed Printers' -Body (New-Table $printerRows @('PrinterName','PortName','IPAddress','DriverName','Status') @{ PrinterName = 'Printer Name'; PortName = 'Port Name'; IPAddress = 'IP Address'; DriverName = 'Driver Name' })
$sections += New-Section -Title 'Monitor Details' -Body (New-Table $monitorRows @('Manufacturer','ModelName','SerialNumber') @{ ModelName = 'Model / Name'; SerialNumber = 'Serial Number' })
$sections += New-Section -Title 'Software Inventory' -Body (New-Table $apps @('Name','Version','Publisher','InstallDate') @{ InstallDate = 'Install Date' })
$sections += New-Section -Title 'Portable Tools Inventory' -Body (New-Table $portableTools @('ID','Name','Path','Size','LastModified','Status') @{ LastModified = 'Last Modified' })
$sections += New-Section -Title 'Recent Hotfixes' -Body (New-Table $hotfixes @('HotFixID','Description','InstalledOn','InstalledBy') @{ HotFixID = 'HotFix ID'; InstalledOn = 'Installed On'; InstalledBy = 'Installed By' })
$sections += New-Section -Title 'Battery Summary' -Body (New-Table $batteryRows @('Name','Status','EstimatedCharge','EstimatedRunTime') @{ EstimatedCharge = 'Estimated Charge'; EstimatedRunTime = 'Estimated Run Time' })

$secretMode = 'Full report with Wi-Fi keys and Windows product key'
$summaryCards = @(
    @{ Label = 'Computer'; Value = $computerName },
    @{ Label = 'User'; Value = $userName },
    @{ Label = 'OS'; Value = $os.Caption },
    @{ Label = 'RAM'; Value = Format-GB $cs.TotalPhysicalMemory },
    @{ Label = 'Apps'; Value = $apps.Count },
    @{ Label = 'Portable Tools'; Value = $portableTools.Count },
    @{ Label = 'Mode'; Value = 'Full' }
)
$cardHtml = foreach ($card in $summaryCards) {
    '<div class="card"><span>{0}</span><strong>{1}</strong></div>' -f (ConvertTo-HtmlText $card.Label), (ConvertTo-HtmlText $card.Value)
}

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>System Inventory Report - $(ConvertTo-HtmlText $computerName)</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@400;500;700;800;900&family=Outfit:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@300;400;500;600;700&display=swap');

    :root {
      --bg1: #020408;
      --bg2: #060a12;
      --bg3: #0a0e1a;
      --panel: rgba(10, 15, 30, 0.85);
      --border: rgba(255, 255, 255, 0.06);
      --glass-border: rgba(0, 255, 255, 0.15);
      --borda: rgba(0, 255, 255, 0.35);
      --text: #e6f3ff;
      --text-muted: #5b7c9f;
      --sub: #a2bcd7;
      --a: #00ffff;
      --a2: #d900ff;
      --green: #00ff9d;
      --red: #ff3b3b;
      --gold: #ffd700;
      
      --header-bg: linear-gradient(135deg, #020408, #0a0e1a);
      --card-bg: rgba(6, 10, 18, 0.7);
      --card-shadow: 0 0 20px rgba(0, 255, 255, 0.05), inset 0 0 15px rgba(0, 255, 255, 0.02);
      --th-bg: rgba(0, 255, 255, 0.05);
      --zebra-bg: rgba(255, 255, 255, 0.01);
      --sec-header: linear-gradient(90deg, rgba(0, 255, 255, 0.08), transparent);
      --btn-bg: rgba(10, 15, 30, 0.9);
      --btn-text: #00ffff;
      --btn-border: rgba(0, 255, 255, 0.3);
      
      --status-ok-bg: rgba(0, 255, 157, 0.1);
      --status-ok-text: #00ff9d;
      --status-ok-border: rgba(0, 255, 157, 0.3);
      --status-warn-bg: rgba(255, 215, 0, 0.1);
      --status-warn-text: #ffd700;
      --status-warn-border: rgba(255, 215, 0, 0.3);
      --status-bad-bg: rgba(255, 59, 59, 0.1);
      --status-bad-text: #ff3b3b;
      --status-bad-border: rgba(255, 59, 59, 0.3);
      
      --notice-bg: rgba(217, 0, 255, 0.08);
      --notice-text: #f3adff;
      --notice-border: rgba(217, 0, 255, 0.3);
      --pre-bg: rgba(2, 4, 8, 0.85);
      --h1-shadow: 0 0 15px rgba(0, 255, 255, 0.3);
    }

    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: 'Outfit', "Segoe UI", Arial, sans-serif;
      background: radial-gradient(circle at 50% 50%, var(--bg2) 0%, var(--bg1) 100%);
      color: var(--text);
      min-height: 100vh;
    }
    
    body::before {
      content: " ";
      display: block;
      position: fixed;
      top: 0; left: 0; bottom: 0; right: 0;
      background: linear-gradient(rgba(18, 16, 16, 0) 50%, rgba(0, 0, 0, 0.15) 50%);
      z-index: 99999;
      background-size: 100% 4px;
      pointer-events: none;
      opacity: 0.2;
    }
    
    /* Widescreen 4K Custom Scrollbar styling */
    ::-webkit-scrollbar { width: 10px; height: 10px; }
    ::-webkit-scrollbar-track { background: var(--bg2); }
    ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 6px; border: 2px solid var(--bg2); }
    ::-webkit-scrollbar-thumb:hover { background: var(--a); }

    .shell { max-width: 1680px; margin: 0 auto; padding: 24px; width: 100%; }
    header {
      background: var(--header-bg);
      border: 1px solid var(--glass-border);
      color: var(--text);
      padding: 30px 40px;
      border-radius: 16px;
      box-shadow: var(--card-shadow);
      position: relative;
      overflow: hidden;
      margin-bottom: 24px;
      border-left: 5px solid var(--a);
    }
    header::before {
      content: '';
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background: radial-gradient(circle at 90% 10%, rgba(0, 255, 255, 0.12) 0%, transparent 60%);
      pointer-events: none;
    }
    h1 { 
      margin: 0; 
      font-family: 'Orbitron', sans-serif;
      font-size: 34px; 
      font-weight: 900; 
      letter-spacing: 1px; 
      text-transform: uppercase;
      color: var(--text);
      text-shadow: var(--h1-shadow);
    }
    .meta { color: var(--text-muted); margin-top: 10px; font-size: 14px; font-weight: 500; }
    .toolbar { display: flex; gap: 12px; flex-wrap: wrap; margin: 24px 0; align-items: center; }
    button {
      border: 1px solid var(--btn-border);
      background-color: var(--btn-bg);
      color: var(--btn-text);
      border-radius: 8px;
      padding: 12px 20px;
      cursor: pointer;
      font-weight: 700;
      font-size: 13px;
      font-family: 'Orbitron', sans-serif;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      transition: all 0.2s ease;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    button:hover {
      transform: translateY(-2px);
      box-shadow: 0 0 15px rgba(0, 255, 255, 0.35);
      border-color: var(--a);
      background-color: rgba(0, 255, 255, 0.05);
    }
    button:active {
      transform: translateY(0);
    }
    input {
      min-width: 280px;
      flex: 1;
      border: 1px solid var(--btn-border);
      background-color: var(--panel);
      color: var(--text);
      border-radius: 8px;
      padding: 12px 20px;
      font-size: 14px;
      font-family: 'Outfit', sans-serif;
      transition: all 0.2s ease;
      outline: none;
    }
    input:focus {
      border-color: var(--a);
      box-shadow: 0 0 15px rgba(0, 255, 255, 0.2);
    }
    .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; margin: 24px 0; }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 20px;
      min-height: 90px;
      box-shadow: var(--card-shadow);
      transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
      position: relative;
      overflow: hidden;
    }
    .card::after {
      content: '';
      position: absolute;
      bottom: 0; left: 0; width: 100%; height: 3px;
      background: linear-gradient(90deg, var(--a), var(--a2));
      opacity: 0.7;
    }
    .card:hover {
      transform: translateY(-4px) scale(1.02);
      box-shadow: 0 15px 30px rgba(0, 255, 255, 0.12);
      border-color: var(--glass-border);
    }
    .card span { display: block; color: var(--text-muted); font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; font-family: 'Orbitron', sans-serif; }
    .card strong { display: block; margin-top: 10px; font-size: 20px; font-weight: 800; overflow-wrap: anywhere; color: var(--text); font-family: 'Outfit', sans-serif; }
    .notice {
      background-color: var(--notice-bg);
      border: 1px solid var(--notice-border);
      color: var(--notice-text);
      border-radius: 10px;
      padding: 14px 18px;
      margin: 20px 0;
      font-size: 14px;
      line-height: 1.5;
      font-weight: 500;
    }
    .status-ok { color: var(--status-ok-text) !important; font-weight: 700; background-color: var(--status-ok-bg) !important; border: 1px solid var(--status-ok-border) !important; border-radius: 6px; padding: 2px 8px; }
    .status-warn { color: var(--status-warn-text) !important; font-weight: 700; background-color: var(--status-warn-bg) !important; border: 1px solid var(--status-warn-border) !important; border-radius: 6px; padding: 2px 8px; }
    .status-bad { color: var(--status-bad-text) !important; font-weight: 700; background-color: var(--status-bad-bg) !important; border: 1px solid var(--status-bad-border) !important; border-radius: 6px; padding: 2px 8px; }
    
    details.section {
      background-color: var(--panel);
      border: 1px solid var(--border);
      border-radius: 14px;
      margin: 0 0 20px;
      overflow: hidden;
      box-shadow: var(--card-shadow);
      transition: all 0.3s ease;
      scroll-margin-top: 24px;
    }
    details.section:hover {
      border-color: var(--glass-border);
      box-shadow: 0 8px 24px rgba(0, 255, 255, 0.05);
    }
    details.section[open] {
      border-color: var(--glass-border);
      box-shadow: 0 12px 32px rgba(0, 0, 0, 0.4);
    }
    summary {
      list-style: none;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 18px 24px;
      background: var(--sec-header);
      color: var(--text);
      cursor: pointer;
      font-weight: 700;
      font-size: 16px;
      font-family: 'Orbitron', sans-serif;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      transition: all 0.2s ease;
      user-select: none;
      border-bottom: 1px solid var(--border);
    }
    summary::-webkit-details-marker { display: none; }
    details[open] summary {
      background: linear-gradient(90deg, rgba(0, 255, 255, 0.12), transparent);
    }
    details[open] summary .toggle { transform: rotate(45deg); color: var(--a2); }
    .toggle { font-family: Consolas, monospace; font-size: 24px; transition: transform 0.25s ease; color: var(--a); text-shadow: 0 0 5px currentColor; }
    .section-body { padding: 24px; overflow: auto; }
    h3 { margin: 24px 0 12px; font-size: 18px; font-weight: 700; }
    .summary-line { margin: 0 0 12px; }
    table { width: 100%; border-collapse: collapse; min-width: 680px; margin: 12px 0; background: rgba(2, 4, 8, 0.2); }
    th, td { border: 1px solid var(--border); padding: 14px 16px; text-align: left; vertical-align: middle; font-size: 14px; }
    th { 
      background-color: var(--th-bg); 
      font-weight: 700; 
      color: var(--text); 
      font-family: 'Orbitron', sans-serif; 
      font-size: 12px; 
      text-transform: uppercase; 
      letter-spacing: 0.8px;
      border-bottom: 2px solid var(--border);
    }
    tr:nth-child(even) td { background-color: var(--zebra-bg); }
    tr:hover td { background-color: rgba(0, 255, 255, 0.04) !important; transition: background-color 0.2s ease; }
    td.key { width: 36%; font-weight: 700; background-color: rgba(255, 255, 255, 0.01); color: var(--sub); }
    td.empty { text-align: center; color: var(--text-muted); padding: 18px; }
    footer { color: var(--text-muted); text-align: center; padding: 32px 24px 24px; font-size: 13px; font-weight: 500; border-top: 1px solid var(--border); margin-top: 40px; }
    @media print { .toolbar { display: none; } body { background: white; color: black; } .shell { max-width: none; padding: 0; } details.section { break-inside: avoid; } details.section:not([open]) .section-body { display: block; } }
  </style>
</head>
<body>
  <div class="shell">
    <header>
      <h1>System Inventory Report: $(ConvertTo-HtmlText $computerName)</h1>
      <div class="meta">Generated: $(ConvertTo-HtmlText ($now.ToString('dd-MMM-yyyy hh:mm tt'))) | $secretMode | Output: $(ConvertTo-HtmlText $OutputRoot)</div>
    </header>
    <div class="toolbar">
      <input id="filter" type="search" placeholder="Search report sections...">
      <button onclick="setAll(true)">Expand All</button>
      <button onclick="setAll(false)">Collapse All</button>
      <button onclick="window.print()">Print / Save PDF</button>
    </div>
    <div class="cards">$($cardHtml -join "`n")</div>
    <div class="notice">Contains Windows license keys and saved Wi-Fi connection passwords.</div>
    $($sections -join "`n")
    <footer>
      <strong>SysForge Studio Inventory</strong><br>
      SysForge Studio • Sistem Raporu • 2026
    </footer>
  </div>
  <script>
    function setAll(open) {
      document.querySelectorAll('details.section').forEach(function(section) { section.open = open; });
    }
    document.getElementById('filter').addEventListener('input', function() {
      var q = this.value.toLowerCase();
      document.querySelectorAll('details.section').forEach(function(section) {
        var hit = section.innerText.toLowerCase().indexOf(q) !== -1;
        section.style.display = hit ? '' : 'none';
        if (q && hit) section.open = true;
      });
    });
  </script>
</body>
</html>
"@

$computerSafe = $computerName -replace '[^A-Za-z0-9_.-]', '_'
$timestamp = $now.ToString('yyyyMMdd_HHmmss')
$reportPath = Join-Path $OutputRoot ("{0}_Inventory_{1}.html" -f $computerSafe, $timestamp)
$latestPath = Join-Path $OutputRoot ("{0}_Inventory.html" -f $computerSafe)

[System.IO.File]::WriteAllText($reportPath, $html, [System.Text.Encoding]::UTF8)
Copy-Item -LiteralPath $reportPath -Destination $latestPath -Force

Write-Host "Report created: $reportPath"
Write-Host "Latest copy   : $latestPath"

if ($Open) {
    Start-Process -FilePath $latestPath | Out-Null
}
