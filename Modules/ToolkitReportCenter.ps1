param(
    [string]$OutputRoot = (Join-Path $env:SystemDrive 'System Inventory'),
    [ValidateSet('inventory','quick-health','dashboard','system','complete-issue','network','driver','apps','evidence','boot','battery','energy','gpresult','wlan','msinfo','events','all')]
    [string]$Mode = 'inventory',
    [switch]$IncludeSecrets,
    [switch]$Open,
    [switch]$Fast
)

$ErrorActionPreference = 'SilentlyContinue'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolkitRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir '..'))
$FallbackRoot = Join-Path $ToolkitRoot 'Logs\SystemInventory'
$InventoryScript = Join-Path $ScriptDir 'SystemInventoryReport.ps1'
$Now = Get-Date
$Stamp = $Now.ToString('yyyyMMdd_HHmmss')
$ComputerSafe = ($env:COMPUTERNAME -replace '[^A-Za-z0-9_.-]', '_')
$script:FactsCache = $null
$script:ShouldOpenSingle = $Open -and $Mode -ne 'all'
$script:FastMode = [bool]$Fast
$script:MergeMode = $false

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

function Format-DateValue {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'N/A' }
    try {
        if ($Value -is [datetime]) { return $Value.ToString('dd-MMM-yyyy hh:mm tt') }
        return ([datetime]$Value).ToString('dd-MMM-yyyy hh:mm tt')
    } catch {
        return [string]$Value
    }
}

function Format-GB {
    param($Bytes)
    if ($null -eq $Bytes -or [double]$Bytes -le 0) { return 'N/A' }
    return ('{0:N2} GB' -f ([double]$Bytes / 1GB))
}

function Get-CellClass {
    param([string]$Column, $Value)

    $text = ([string]$Value).Trim()
    $lower = $text.ToLowerInvariant()

    if ($Column -match '(Status|Health|State|Protection|Enabled|Result)') {
        if ($lower -match '^(ok|healthy|normal|active|running|online|ready|enabled|true|success|good|found|protected|on|up)$') { return 'status-ok' }
        if ($lower -match '(disabled|inactive|stopped|offline|error|fail|failed|critical|warning|degraded|unknown|bad|not found|off|down)') { return 'status-bad' }
    }

    if ($Column -match '(FreePercent|Free %)' -and $text -match '\d') {
        $valueNumber = [double](($text -replace '[^0-9.]', ''))
        if ($valueNumber -lt 10) { return 'status-bad' }
        if ($valueNumber -lt 20) { return 'status-warn' }
        return 'status-ok'
    }

    if ($Column -match '(UsedPercent|Used %)' -and $text -match '\d') {
        $valueNumber = [double](($text -replace '[^0-9.]', ''))
        if ($valueNumber -ge 90) { return 'status-bad' }
        if ($valueNumber -ge 80) { return 'status-warn' }
        return 'status-ok'
    }

    return ''
}

function New-KvTable {
    param([System.Collections.IDictionary]$Map)

    $rows = foreach ($item in $Map.GetEnumerator()) {
        $class = Get-CellClass -Column ([string]$item.Key) -Value $item.Value
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

    $head = foreach ($column in $Columns) {
        $label = if ($Headers.ContainsKey($column)) { $Headers[$column] } else { $column }
        '<th>{0}</th>' -f (ConvertTo-HtmlText $label)
    }

    $body = @()
    foreach ($row in @($Rows)) {
        $cells = foreach ($column in $Columns) {
            $value = ''
            if ($row -is [System.Collections.IDictionary]) {
                if ($row.Contains($column)) { $value = $row[$column] }
            } elseif ($row.PSObject.Properties.Name -contains $column) {
                $value = $row.$column
            }
            $class = Get-CellClass -Column $column -Value $value
            $classAttr = if ($class) { ' class="{0}"' -f $class } else { '' }
            '<td{0}>{1}</td>' -f $classAttr, (ConvertTo-HtmlText $value)
        }
        $body += '<tr>{0}</tr>' -f ($cells -join '')
    }

    if ($body.Count -eq 0) {
        $body += '<tr><td colspan="{0}" class="empty">No data found</td></tr>' -f [Math]::Max(1, $Columns.Count)
    }

    return '<table><thead><tr>{0}</tr></thead><tbody>{1}</tbody></table>' -f ($head -join ''), ($body -join "`n")
}

function New-Section {
    param(
        [string]$Title,
        [string]$Body,
        [switch]$OpenSection
    )

    $openText = if ($OpenSection) { ' open' } else { '' }
    return @"
<details class="section"$openText>
  <summary><span>$(ConvertTo-HtmlText $Title)</span><span class="toggle">+</span></summary>
  <div class="section-body">
    $Body
  </div>
</details>
"@
}

function New-PreSection {
    param(
        [string]$Title,
        [string]$Text,
        [switch]$OpenSection
    )

    $safe = if ([string]::IsNullOrWhiteSpace($Text)) { 'No data found.' } else { $Text }
    return New-Section -Title $Title -Body ('<pre>{0}</pre>' -f (ConvertTo-HtmlText $safe)) -OpenSection:$OpenSection
}

function Get-ScriptOutput {
    param([scriptblock]$Script)

    try {
        $raw = & $Script 2>&1 | Out-String -Width 5000
    } catch {
        $raw = $_ | Out-String -Width 5000
    }

    if ([string]::IsNullOrWhiteSpace($raw)) { return 'No data returned.' }
    return $raw.Trim()
}

function Get-CmdOutput {
    param([string]$CommandText)
    return Get-ScriptOutput { & $env:ComSpec /d /c $CommandText }
}

function Copy-LatestFile {
    param(
        [string]$SourcePath,
        [string]$LatestName
    )

    $latestPath = Join-Path $OutputRoot $LatestName
    Copy-Item -LiteralPath $SourcePath -Destination $latestPath -Force
    return $latestPath
}

function Save-ReportHtml {
    param(
        [string]$Slug,
        [string]$Title,
        [string]$Subtitle,
        [object[]]$Cards,
        [string[]]$Sections,
        [string]$Notice = '',
        [switch]$OpenDocument
    )

    if ($script:MergeMode) {
        return [pscustomobject]@{
            Slug = $Slug
            Title = $Title
            Subtitle = $Subtitle
            Cards = $Cards
            Sections = $Sections
            Notice = $Notice
        }
    }

    $cardHtml = foreach ($card in @($Cards)) {
        if ($card -is [System.Collections.IDictionary]) {
            $label = if ($card.Contains('Label')) { $card['Label'] } else { '' }
            $value = if ($card.Contains('Value')) { $card['Value'] } else { '' }
        } else {
            $label = if ($card.PSObject.Properties.Name -contains 'Label') { $card.Label } else { '' }
            $value = if ($card.PSObject.Properties.Name -contains 'Value') { $card.Value } else { '' }
        }
        '<div class="card"><span>{0}</span><strong>{1}</strong></div>' -f (ConvertTo-HtmlText $label), (ConvertTo-HtmlText $value)
    }

    $noticeHtml = if ([string]::IsNullOrWhiteSpace($Notice)) { '' } else { '<div class="notice">{0}</div>' -f (ConvertTo-HtmlText $Notice) }

    $html = @"
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$(ConvertTo-HtmlText $Title)</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@400;500;700;800;900&family=Outfit:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@300;400;500;600;700&display=swap');

    :root[data-theme="dark"] {
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

    :root[data-theme="light"] {
      --bg1: #f0f4f8;
      --bg2: #e2e8f0;
      --bg3: #cbd5e1;
      --panel: rgba(255, 255, 255, 0.9);
      --border: rgba(0, 0, 0, 0.08);
      --glass-border: rgba(0, 128, 128, 0.2);
      --borda: rgba(0, 128, 128, 0.4);
      --text: #0f172a;
      --text-muted: #475569;
      --sub: #334155;
      --a: #0d9488;
      --a2: #b004c2;
      --green: #15803d;
      --red: #b91c1c;
      --gold: #b45309;
      
      --header-bg: linear-gradient(135deg, #f0f4f8, #cbd5e1);
      --card-bg: rgba(255, 255, 255, 0.85);
      --card-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
      --th-bg: rgba(13, 148, 136, 0.08);
      --zebra-bg: rgba(0, 0, 0, 0.02);
      --sec-header: linear-gradient(90deg, rgba(13, 148, 136, 0.12), transparent);
      --btn-bg: #ffffff;
      --btn-text: #0d9488;
      --btn-border: rgba(13, 148, 136, 0.3);
      
      --status-ok-bg: rgba(21, 128, 61, 0.08);
      --status-ok-text: #15803d;
      --status-ok-border: rgba(21, 128, 61, 0.2);
      --status-warn-bg: rgba(180, 83, 9, 0.08);
      --status-warn-text: #b45309;
      --status-warn-border: rgba(180, 83, 9, 0.2);
      --status-bad-bg: rgba(185, 28, 28, 0.08);
      --status-bad-text: #b91c1c;
      --status-bad-border: rgba(185, 28, 28, 0.2);
      
      --notice-bg: rgba(176, 4, 194, 0.05);
      --notice-text: #b004c2;
      --notice-border: rgba(176, 4, 194, 0.2);
      --pre-bg: #ffffff;
      --h1-shadow: none;
    }

    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: 'Outfit', "Segoe UI", Arial, sans-serif;
      background: radial-gradient(circle at 50% 50%, var(--bg2) 0%, var(--bg1) 100%);
      color: var(--text);
      transition: background-color 0.3s ease, color 0.3s ease;
      min-height: 100vh;
    }
    
    :root[data-theme="dark"] body::before {
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
    ::-webkit-scrollbar-track { background: var(--bg1); }
    ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 6px; border: 2px solid var(--bg1); }
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
    button, .theme-btn {
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
    button:hover, .theme-btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 0 15px rgba(0, 255, 255, 0.35);
      border-color: var(--a);
      background-color: rgba(0, 255, 255, 0.05);
    }
    button:active, .theme-btn:active {
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
      margin: 0 0 20px;
      font-size: 14px;
      line-height: 1.5;
      font-weight: 500;
    }
    .status-ok { color: var(--status-ok-text) !important; font-weight: 700; background-color: var(--status-ok-bg) !important; border: 1px solid var(--status-ok-border) !important; border-radius: 6px; padding: 2px 8px; }
    .status-warn { color: var(--status-warn-text) !important; font-weight: 700; background-color: var(--status-warn-bg) !important; border: 1px solid var(--status-warn-border) !important; border-radius: 6px; padding: 2px 8px; }
    .status-bad { color: var(--status-bad-text) !important; font-weight: 700; background-color: var(--status-bad-bg) !important; border: 1px solid var(--status-bad-border) !important; border-radius: 6px; padding: 2px 8px; }
    
    /* 4K Split Widescreen Panel Layout */
    .main-layout { display: flex; gap: 28px; margin-top: 24px; width: 100%; align-items: start; }
    .content-area { flex: 1; min-width: 0; }
    .toc-sidebar {
      width: 340px;
      background-color: var(--panel);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 24px;
      position: sticky;
      top: 24px;
      max-height: calc(100vh - 48px);
      overflow-y: auto;
      box-shadow: var(--card-shadow);
      display: none;
      border-left: 3px solid var(--a2);
    }
    .toc-sidebar:hover { border-color: var(--glass-border); }
    .toc-sidebar::-webkit-scrollbar { width: 6px; }
    .toc-sidebar::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
    @media (min-width: 1400px) {
      .toc-sidebar { display: block; }
    }
    .toc-sidebar h3 {
      margin-top: 0;
      margin-bottom: 20px;
      font-size: 16px;
      font-weight: 800;
      font-family: 'Orbitron', sans-serif;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      border-bottom: 1px solid var(--border);
      padding-bottom: 12px;
      color: var(--text);
    }
    .toc-sidebar ul {
      list-style: none;
      padding: 0;
      margin: 0;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .toc-sidebar li a {
      display: block;
      padding: 10px 14px;
      border-radius: 8px;
      color: var(--text-muted);
      font-size: 13px;
      font-weight: 600;
      transition: all 0.2s ease;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      text-decoration: none;
    }
    .toc-sidebar li a:hover, .toc-sidebar li a.active {
      background-color: rgba(0, 255, 255, 0.05);
      color: var(--a);
      padding-left: 20px;
      border-left: 2px solid var(--a);
    }

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
    .summary-line { margin: 0 0 16px; font-size: 14px; color: var(--text-muted); }
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
    td.key { width: 30%; font-weight: 700; background-color: rgba(255, 255, 255, 0.01); color: var(--sub); }
    td.empty { text-align: center; color: var(--text-muted); padding: 24px; font-weight: 500; }
    pre {
      margin: 0;
      white-space: pre-wrap;
      word-break: break-all;
      background-color: var(--pre-bg);
      border: 1px solid var(--border);
      color: var(--green);
      padding: 20px;
      border-radius: 10px;
      font-family: 'JetBrains Mono', Consolas, monospace;
      font-size: 13px;
      line-height: 1.6;
      box-shadow: inset 0 0 20px rgba(0,0,0,0.5);
      border-left: 3px solid var(--green);
    }
    a { color: var(--a); text-decoration: none; font-weight: 500; }
    a:hover { text-decoration: underline; text-shadow: 0 0 5px var(--a); }
    footer { color: var(--text-muted); text-align: center; padding: 32px 24px 24px; font-size: 13px; font-weight: 500; border-top: 1px solid var(--border); margin-top: 40px; }
    @media print { .toolbar { display: none; } body { background: white; color: black; } .shell { max-width: none; padding: 0; } details.section { break-inside: avoid; } details.section:not([open]) .section-body { display: block; } }
  </style>
</head>
<body>
  <div class="shell">
    <header>
      <h1>$(ConvertTo-HtmlText $Title)</h1>
      <div class="meta">$(ConvertTo-HtmlText $Subtitle) | Generated: $(ConvertTo-HtmlText ($Now.ToString('dd-MMM-yyyy hh:mm tt'))) | Output: $(ConvertTo-HtmlText $OutputRoot)</div>
    </header>
    <div class="toolbar">
      <input id="filter" type="search" placeholder="Search report sections...">
      <button onclick="setAll(true)">Expand All</button>
      <button onclick="setAll(false)">Collapse All</button>
      <button onclick="window.print()">Print / PDF</button>
      <button id="theme-toggle" onclick="toggleTheme()">☀️ Light Mode</button>
    </div>
    <div class="cards">$($cardHtml -join "`n")</div>
    
    <div class="main-layout">
      <aside class="toc-sidebar">
        <h3>📋 Diagnostics Explorer</h3>
        <ul id="toc-list"></ul>
      </aside>
      <main class="content-area">
        $noticeHtml
        $($Sections -join "`n")
      </main>
    </div>

    <footer>
      <strong>SysForge Studio Report Center</strong><br>
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
    function toggleTheme() {
      var current = document.documentElement.getAttribute('data-theme');
      var target = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', target);
      localStorage.setItem('venom-theme', target);
      updateThemeButton(target);
    }
    function updateThemeButton(theme) {
      var btn = document.getElementById('theme-toggle');
      if (btn) {
        if (theme === 'dark') {
          btn.innerHTML = '☀️ Light Mode';
        } else {
          btn.innerHTML = '🌙 Dark Mode';
        }
      }
    }
    var savedTheme = localStorage.getItem('venom-theme');
    if (!savedTheme) {
      savedTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    document.documentElement.setAttribute('data-theme', savedTheme);
    
    window.addEventListener('DOMContentLoaded', function() {
      updateThemeButton(savedTheme);
      
      // Dynamic TOC Explorer & Scrollspy Generation
      var sections = document.querySelectorAll('details.section');
      var tocList = document.getElementById('toc-list');
      if (tocList && sections.length > 0) {
        sections.forEach(function(section, idx) {
          var id = 'section-' + idx;
          section.setAttribute('id', id);
          var titleSpan = section.querySelector('summary span');
          if (titleSpan) {
            var title = titleSpan.innerText;
            var li = document.createElement('li');
            var a = document.createElement('a');
            a.href = '#' + id;
            a.innerText = title;
            a.setAttribute('id', 'toc-link-' + id);
            a.addEventListener('click', function(e) {
              e.preventDefault();
              section.open = true;
              section.scrollIntoView({ behavior: 'smooth' });
            });
            li.appendChild(a);
            tocList.appendChild(li);
          }
        });
        
        // Scrollspy to highlight active TOC item
        var observerOptions = {
          root: null,
          rootMargin: '-10% 0px -80% 0px',
          threshold: 0
        };
        var observer = new IntersectionObserver(function(entries) {
          entries.forEach(function(entry) {
            if (entry.isIntersecting) {
              var id = entry.target.getAttribute('id');
              document.querySelectorAll('#toc-list a').forEach(function(a) {
                a.classList.remove('active');
              });
              var activeLink = document.getElementById('toc-link-' + id);
              if (activeLink) activeLink.classList.add('active');
            }
          });
        }, observerOptions);
        sections.forEach(function(sec) { observer.observe(sec); });
      }
    });
  </script>
</body>
</html>
"@

    $slugSafe = $Slug -replace '[^A-Za-z0-9_.-]', '_'
    $reportPath = Join-Path $OutputRoot ("{0}_{1}_{2}.html" -f $ComputerSafe, $slugSafe, $Stamp)
    $latestPath = Join-Path $OutputRoot ("{0}_{1}.html" -f $ComputerSafe, $slugSafe)
    [System.IO.File]::WriteAllText($reportPath, $html, [System.Text.Encoding]::UTF8)
    Copy-Item -LiteralPath $reportPath -Destination $latestPath -Force

    if ($OpenDocument) {
        Start-Process -FilePath $latestPath | Out-Null
    }

    return [pscustomobject]@{
        Name = $Title
        Path = $latestPath
        ArtifactPath = $latestPath
        Kind = 'html'
    }
}

function Get-QuickFacts {
    if ($script:FactsCache) { return $script:FactsCache }

    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $logicalDisks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3')
    $adapterCount = 0
    try {
        $adapterCount = @(Get-NetAdapter | Where-Object Status -eq 'Up').Count
    } catch {}

    $uptimeText = 'N/A'
    if ($os.LastBootUpTime) {
        $span = New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date)
        $uptimeText = '{0}d {1}h {2}m' -f $span.Days, $span.Hours, $span.Minutes
    }

    $lowSpace = @($logicalDisks | Where-Object {
        $_.Size -and $_.FreeSpace -ne $null -and (($_.FreeSpace / $_.Size) * 100) -lt 20
    }).Count

    $networkIdentity = if ($cs.PartOfDomain) { "Domain: $($cs.Domain)" } else { "Workgroup: $($cs.Workgroup)" }

    $script:FactsCache = [pscustomobject]@{
        Computer = $env:COMPUTERNAME
        User = $env:USERNAME
        OS = $os.Caption
        Uptime = $uptimeText
        RAM = Format-GB $cs.TotalPhysicalMemory
        CPU = if ($cpu) { $cpu.Name } else { 'N/A' }
        DriveCount = $logicalDisks.Count
        LowSpace = $lowSpace
        NetworkIdentity = $networkIdentity
        AdapterCount = $adapterCount
    }

    return $script:FactsCache
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
        if ($parts[2].Trim().ToLowerInvariant() -ne 'exe') { continue }

        $target = $parts[3].Trim()
        $resolved = if ([System.IO.Path]::IsPathRooted($target)) { $target } else { Join-Path $ToolkitRoot $target }
        if (-not (Test-Path -LiteralPath $resolved)) { continue }
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

    return @($items | Sort-Object Name)
}

function Get-LogicalDiskRows {
    return @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        $used = if ($_.Size -and $_.FreeSpace -ne $null) { [double]$_.Size - [double]$_.FreeSpace } else { $null }
        $usedPercent = if ($_.Size -and $used -ne $null) { ($used / $_.Size) * 100 } else { $null }
        $freePercent = if ($_.Size) { ($_.FreeSpace / $_.Size) * 100 } else { $null }
        [pscustomobject]@{
            Drive = $_.DeviceID
            Volume = $_.VolumeName
            FileSystem = $_.FileSystem
            TotalSize = Format-GB $_.Size
            UsedSpace = Format-GB $used
            FreeSpace = Format-GB $_.FreeSpace
            UsedPercent = if ($usedPercent -ne $null) { '{0:N1}%' -f $usedPercent } else { 'N/A' }
            FreePercent = if ($freePercent -ne $null) { '{0:N1}%' -f $freePercent } else { 'N/A' }
            HealthStatus = if ($freePercent -eq $null) { 'Unknown' } elseif ($freePercent -lt 10) { 'Critical' } elseif ($freePercent -lt 20) { 'Warning' } else { 'OK' }
        }
    })
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

function Get-WifiProfiles {
    $profiles = @()
    $raw = & netsh wlan show profiles 2>$null
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

function New-FastInventoryReport {
    $facts = Get-QuickFacts
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $baseboard = Get-CimInstance Win32_BaseBoard
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $productId = 'N/A'
    try { $productId = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name ProductId).ProductId } catch {}
    $uptime = if ($os.LastBootUpTime) { New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date) } else { $null }
    $uptimeText = if ($uptime) { '{0} Days, {1} Hours, {2} Mins' -f $uptime.Days, $uptime.Hours, $uptime.Minutes } else { 'N/A' }

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

    $physicalDisks = @(try {
        Get-PhysicalDisk | ForEach-Object {
            [pscustomobject]@{
                DiskModel = $_.FriendlyName
                SerialNumber = $_.SerialNumber
                MediaType = $_.MediaType
                BusType = $_.BusType
                TotalSize = Format-GB $_.Size
                HealthStatus = $_.HealthStatus
                OperationalStatus = ($_.OperationalStatus -join ', ')
            }
        }
    } catch { @() })
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

    $networkRows = @(try {
        Get-NetIPConfiguration | ForEach-Object {
            $adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
            $ip = @($_.IPv4Address | Select-Object -First 1)
            $gw = @($_.IPv4DefaultGateway | Select-Object -First 1)
            [pscustomobject]@{
                Interface = $_.InterfaceAlias
                IPAddress = if ($ip.Count) { $ip[0].IPAddress } else { 'N/A' }
                Prefix = if ($ip.Count) { $ip[0].PrefixLength } else { 'N/A' }
                Gateway = if ($gw.Count) { $gw[0].NextHop } else { 'N/A' }
                MacAddress = if ($adapter) { $adapter.MacAddress } else { 'N/A' }
                LinkSpeed = if ($adapter) { $adapter.LinkSpeed } else { 'N/A' }
            }
        }
    } catch { @() })

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
    $monitorRows = @(try {
        Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
            [pscustomobject]@{
                Manufacturer = Convert-MonitorString $_.ManufacturerName
                ModelName = Convert-MonitorString $_.UserFriendlyName
                SerialNumber = Convert-MonitorString $_.SerialNumberID
            }
        }
    } catch { @() })
    $apps = @(Get-RegistryApps)
    $portable = @(Read-ToolsCatalog)
    $hotfixes = @(try {
        Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 30 | ForEach-Object {
            [pscustomobject]@{
                HotFixID = $_.HotFixID
                Description = $_.Description
                InstalledOn = Format-DateValue $_.InstalledOn
                InstalledBy = $_.InstalledBy
            }
        }
    } catch { @() })
    $batteryRows = @(Get-CimInstance Win32_Battery | ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            Status = $_.Status
            EstimatedCharge = if ($_.EstimatedChargeRemaining -ne $null) { "$($_.EstimatedChargeRemaining)%" } else { 'N/A' }
            EstimatedRunTime = if ($_.EstimatedRunTime -and $_.EstimatedRunTime -ne 71582788) { "$($_.EstimatedRunTime) minutes" } else { 'N/A' }
        }
    })

    $cards = @(
        @{ Label = 'Computer'; Value = $facts.Computer },
        @{ Label = 'User'; Value = $env:USERNAME },
        @{ Label = 'OS'; Value = $facts.OS },
        @{ Label = 'RAM'; Value = $facts.RAM },
        @{ Label = 'Apps'; Value = $apps.Count },
        @{ Label = 'Portable Tools'; Value = $portable.Count },
        @{ Label = 'Mode'; Value = 'One Click' }
    )

    $osDetails = [ordered]@{
        'Current Logged User' = $env:USERNAME
        'Computer Description' = if ($os.Description) { $os.Description } else { 'No Description Set' }
        'OS Edition' = '{0} (Version: {1})' -f $os.Caption, $os.Version
        'Build Version' = '{0} ({1})' -f $os.Version, $os.OSArchitecture
        'Windows Key' = Get-WindowsKey
        'Windows Product ID' = $productId
        'Network Identity' = $facts.NetworkIdentity
        'Install Date' = Format-DateValue $os.InstallDate
        'Last Boot Time' = Format-DateValue $os.LastBootUpTime
        'System Uptime' = $uptimeText
    }

    $boardCpu = [ordered]@{
        'Manufacturer' = $cs.Manufacturer
        'System Model' = $cs.Model
        'System Serial / Service Tag' = $bios.SerialNumber
        'System UUID' = if ($cs.UUID) { $cs.UUID } else { 'N/A' }
        'Motherboard Serial' = $baseboard.SerialNumber
        'BIOS Version/Date' = '{0} {1}' -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion
        'CPU (Processor)' = if ($cpu) { $cpu.Name } else { 'N/A' }
        'CPU Cores / Logical' = if ($cpu) { '{0} Cores / {1} Threads' -f $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors } else { 'N/A' }
    }

    $sections = @(
        (New-Section -Title 'Operating System Details' -Body (New-KvTable $osDetails) -OpenSection),
        (New-Section -Title 'User Accounts' -Body (New-Table $users @('Username','AccountType','Caption','Status') @{ AccountType = 'Account Type'; Caption = 'Full Caption' })),
        (New-Section -Title 'Motherboard & CPU Information' -Body (New-KvTable $boardCpu)),
        (New-Section -Title 'Memory Details' -Body ($memorySummary + (New-Table $memoryModules @('Slot','Size','Speed','Manufacturer','PartNumber') @{ PartNumber = 'Part Number' }))),
        (New-Section -Title 'Storage & Physical Disk Health' -Body ((New-Table (Get-LogicalDiskRows) @('Drive','Volume','FileSystem','TotalSize','UsedSpace','FreeSpace','UsedPercent','FreePercent','HealthStatus') @{ Volume = 'Volume Name'; TotalSize = 'Total Size'; UsedSpace = 'Used Space'; FreeSpace = 'Free Space'; UsedPercent = 'Used %'; FreePercent = 'Free %'; HealthStatus = 'Health Status' }) + '<h3>Physical Disks</h3>' + (New-Table $physicalDisks @('DiskModel','SerialNumber','MediaType','BusType','TotalSize','HealthStatus','OperationalStatus') @{ DiskModel = 'Disk Model'; SerialNumber = 'Serial Number'; MediaType = 'Media Type'; BusType = 'Bus Type'; TotalSize = 'Total Size'; HealthStatus = 'Health Status'; OperationalStatus = 'Operational Status' }))),
        (New-Section -Title 'Network Configuration & Link Speed' -Body (New-Table $networkRows @('Interface','IPAddress','Prefix','Gateway','MacAddress','LinkSpeed') @{ IPAddress = 'IP Address'; MacAddress = 'MAC Address'; LinkSpeed = 'Link Speed' })),
        (New-Section -Title 'Saved Wi-Fi' -Body (New-Table $wifiRows @('SSID','Password','Status') @{ SSID = 'Wi-Fi SSID'; Password = 'Password (Key Content)' })),
        (New-Section -Title 'Shared Folders Configuration' -Body (New-Table $shares @('ShareName','LocalPath','Description') @{ ShareName = 'Share Name'; LocalPath = 'Local Path' })),
        (New-Section -Title 'Installed Printers' -Body (New-Table $printerRows @('PrinterName','PortName','IPAddress','DriverName','Status') @{ PrinterName = 'Printer Name'; PortName = 'Port Name'; IPAddress = 'IP Address'; DriverName = 'Driver Name' })),
        (New-Section -Title 'Monitor Details' -Body (New-Table $monitorRows @('Manufacturer','ModelName','SerialNumber') @{ ModelName = 'Model / Name'; SerialNumber = 'Serial Number' })),
        (New-Section -Title 'Software Inventory' -Body (New-Table $apps @('Name','Version','Publisher','InstallDate') @{ InstallDate = 'Install Date' })),
        (New-Section -Title 'Portable Tools Inventory' -Body (New-Table $portable @('ID','Name','Path','Size','LastModified','Status') @{ LastModified = 'Last Modified' })),
        (New-Section -Title 'Recent Hotfixes' -Body (New-Table $hotfixes @('HotFixID','Description','InstalledOn','InstalledBy') @{ HotFixID = 'HotFix ID'; InstalledOn = 'Installed On'; InstalledBy = 'Installed By' })),
        (New-Section -Title 'Battery Summary' -Body (New-Table $batteryRows @('Name','Status','EstimatedCharge','EstimatedRunTime') @{ EstimatedCharge = 'Estimated Charge'; EstimatedRunTime = 'Estimated Run Time' }))
    )

    $secretMode = 'Full report with Wi-Fi keys and Windows product key'
    return Save-ReportHtml -Slug 'Inventory' -Title ("System Inventory Report: {0}" -f $env:COMPUTERNAME) -Subtitle $secretMode -Cards $cards -Sections $sections -Notice 'Contains Windows license keys and saved Wi-Fi connection passwords.' -OpenDocument:$script:ShouldOpenSingle
}

function Invoke-InventoryReport {
    if ($script:FastMode) {
        return New-FastInventoryReport
    }

    if (-not (Test-Path -LiteralPath $InventoryScript)) {
        throw "Missing SystemInventoryReport.ps1 at $InventoryScript"
    }

    & $InventoryScript -OutputRoot $OutputRoot -IncludeSecrets:$IncludeSecrets | Out-Null
    $inventoryPath = Join-Path $OutputRoot ("{0}_Inventory.html" -f $ComputerSafe)
    if ($script:ShouldOpenSingle) {
        Start-Process -FilePath $inventoryPath | Out-Null
    }

    return [pscustomobject]@{
        Name = 'Complete System Inventory'
        Path = $inventoryPath
        ArtifactPath = $inventoryPath
        Kind = 'html'
    }
}

function New-QuickHealthReport {
    $facts = Get-QuickFacts
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    
    # Cards
    $cards = @(
        @{ Label = 'Computer'; Value = $facts.Computer },
        @{ Label = 'OS Edition'; Value = $facts.OS },
        @{ Label = 'Uptime'; Value = $facts.Uptime },
        @{ Label = 'RAM Size'; Value = $facts.RAM },
        @{ Label = 'Drives Scanned'; Value = $facts.DriveCount },
        @{ Label = 'Low Space'; Value = $facts.LowSpace }
    )

    # Windows Snapshot Info
    $osDetails = [ordered]@{
        'OS Edition' = $os.Caption
        'Version' = $os.Version
        'Build Number' = $os.BuildNumber
        'Architecture' = $os.OSArchitecture
        'Last Boot Time' = Format-DateValue $os.LastBootUpTime
        'Logged User' = $env:USERNAME
    }

    # CPU/RAM Row
    $memoryRow = [pscustomobject]@{
        CPU = if ($cpu) { $cpu.Name } else { 'N/A' }
        Cores = if ($cpu) { $cpu.NumberOfCores } else { 'N/A' }
        Threads = if ($cpu) { $cpu.NumberOfLogicalProcessors } else { 'N/A' }
        TotalRAM = Format-GB ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory)
        FreeRAM = if ($os.FreePhysicalMemory) { '{0:N2} GB' -f ($os.FreePhysicalMemory / 1MB) } else { 'N/A' }
    }

    # Disk space
    $disks = @(Get-LogicalDiskRows)

    # Network adapters
    $networkRows = @(try {
        Get-NetIPConfiguration | ForEach-Object {
            $adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
            $ip = @($_.IPv4Address | Select-Object -First 1)
            $gw = @($_.IPv4DefaultGateway | Select-Object -First 1)
            [pscustomobject]@{
                Interface = $_.InterfaceAlias
                IPAddress = if ($ip.Count) { $ip[0].IPAddress } else { 'N/A' }
                Gateway = if ($gw.Count) { $gw[0].NextHop } else { 'N/A' }
                DNSServers = if ($_.DNSServer.ServerAddresses) { ($_.DNSServer.ServerAddresses -join ', ') } else { 'N/A' }
                Status = if ($adapter) { $adapter.Status.ToString() } else { 'Unknown' }
            }
        }
    } catch { @() })

    # Firewall Profile Table
    $fwRows = @(try {
        Get-NetFirewallProfile | ForEach-Object {
            [pscustomobject]@{
                Profile = $_.Name
                Status = if ($_.Enabled -eq $true) { 'Active' } else { 'Disabled' }
                InboundAction = $_.DefaultInboundAction.ToString()
                OutboundAction = $_.DefaultOutboundAction.ToString()
            }
        }
    } catch { @() })

    # Defender Status
    $def = try { Get-MpComputerStatus } catch { $null }
    $defInfo = [ordered]@{
        'Antivirus Service' = if ($def) { if ($def.AMServiceEnabled) { 'Running' } else { 'Stopped' } } else { 'Unavailable' }
        'Antivirus Protection' = if ($def) { if ($def.AntivirusEnabled) { 'Active' } else { 'Disabled' } } else { 'Unavailable' }
        'Real-Time Protection' = if ($def) { if ($def.RealTimeProtectionEnabled) { 'Active' } else { 'Disabled' } } else { 'Unavailable' }
        'Antispyware Protection' = if ($def) { if ($def.AntispywareEnabled) { 'Active' } else { 'Disabled' } } else { 'Unavailable' }
        'Signature Update Age' = if ($def) { "$($def.AntivirusSignatureAge) Days" } else { 'N/A' }
        'Engine Version' = if ($def) { $def.EngineVersion } else { 'N/A' }
    }

    # Critical Events
    $criticalEvents = @(try {
        Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1; StartTime = (Get-Date).AddDays(-7) } -ErrorAction SilentlyContinue |
            Select-Object -First 10 TimeCreated, Id, ProviderName, Message |
            ForEach-Object {
                [pscustomobject]@{
                    Time = Format-DateValue $_.TimeCreated
                    EventID = $_.Id
                    Source = $_.ProviderName
                    Message = if ($_.Message) { $_.Message.Split("`n")[0] } else { 'N/A' }
                }
            }
    } catch { @() })

    $sections = @(
        (New-Section -Title 'System Telemetry & OS Snapshot' -Body (New-KvTable $osDetails) -OpenSection),
        (New-Section -Title 'CPU & Memory Diagnostics' -Body (New-Table @($memoryRow) @('CPU','Cores','Threads','TotalRAM','FreeRAM') @{ TotalRAM = 'Total RAM'; FreeRAM = 'Free RAM' })),
        (New-Section -Title 'Disk Space & Volumes Health' -Body (New-Table $disks @('Drive','Volume','FileSystem','TotalSize','UsedSpace','FreeSpace','UsedPercent','FreePercent','HealthStatus') @{ TotalSize = 'Total Size'; UsedSpace = 'Used Space'; FreeSpace = 'Free Space'; UsedPercent = 'Used %'; FreePercent = 'Free %'; HealthStatus = 'Health Status' })),
        (New-Section -Title 'Active Network Interfaces' -Body (New-Table $networkRows @('Interface','IPAddress','Gateway','DNSServers','Status') @{ IPAddress = 'IP Address'; DNSServers = 'DNS Servers' })),
        (New-Section -Title 'Firewall Profile Settings' -Body (New-Table $fwRows @('Profile','Status','InboundAction','OutboundAction') @{ InboundAction = 'Inbound Action'; OutboundAction = 'Outbound Action' })),
        (New-Section -Title 'Windows Defender Antivirus' -Body (New-KvTable $defInfo)),
        (New-Section -Title 'Critical System Event Logs (Last 7 Days)' -Body (New-Table $criticalEvents @('Time','EventID','Source','Message') @{ EventID = 'Event ID' }))
    )

    return Save-ReportHtml -Slug 'Quick_Health' -Title 'Quick Health Diagnostics Report' -Subtitle 'Rapid hardware diagnostics, network check and antivirus status snapshot' -Cards $cards -Sections $sections -Notice 'Compiled automatically by UltimateToolkit Diagnostics Core.' -OpenDocument:$script:ShouldOpenSingle
}

function New-HealthDashboardReport {
    $facts = Get-QuickFacts
    $os = Get-CimInstance Win32_OperatingSystem
    $freeDrives = @(Get-LogicalDiskRows)
    $defenderStatus = 'Unavailable'
    try {
        $mp = Get-MpComputerStatus
        if ($mp.RealTimeProtectionEnabled) { $defenderStatus = 'Active' } else { $defenderStatus = 'Disabled' }
    } catch {}

    $firewallStatus = if ((Get-CmdOutput 'netsh advfirewall show allprofiles state') -match 'State\s+ON') { 'Active' } else { 'Check' }
    $criticalCount = @(try {
        Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1; StartTime = (Get-Date).AddDays(-7) } -ErrorAction SilentlyContinue
    } catch { @() }).Count

    $cards = @(
        @{ Label = 'Machine'; Value = $facts.Computer },
        @{ Label = 'User'; Value = $facts.User },
        @{ Label = 'Uptime'; Value = $facts.Uptime },
        @{ Label = 'Adapters Up'; Value = $facts.AdapterCount },
        @{ Label = 'Firewall'; Value = $firewallStatus },
        @{ Label = 'Defender'; Value = $defenderStatus },
        @{ Label = 'Critical Events'; Value = $criticalCount }
    )

    $overview = [ordered]@{
        'Operating System' = $facts.OS
        'Network Identity' = $facts.NetworkIdentity
        'CPU' = $facts.CPU
        'Installed RAM' = $facts.RAM
        'Low Space Drives' = if ($facts.LowSpace -gt 0) { "$($facts.LowSpace) Warning" } else { 'OK' }
        'Firewall' = $firewallStatus
        'Defender Real-Time' = $defenderStatus
        'Last Boot' = Format-DateValue $os.LastBootUpTime
    }

    $eventRows = @(try {
        Get-WinEvent -ProviderName Microsoft-Windows-Diagnostics-Performance -MaxEvents 12 |
            Select-Object TimeCreated, Id, LevelDisplayName
    } catch { @() })

    $sections = @(
        (New-Section -Title 'Venom Health Overview' -Body (New-KvTable $overview) -OpenSection),
        (New-Section -Title 'Disk Space Dashboard' -Body (New-Table $freeDrives @('Drive','Volume','TotalSize','UsedSpace','FreeSpace','UsedPercent','FreePercent','HealthStatus') @{ TotalSize = 'Total Size'; UsedSpace = 'Used Space'; FreeSpace = 'Free Space'; UsedPercent = 'Used %'; FreePercent = 'Free %'; HealthStatus = 'Health Status' })),
        (New-Section -Title 'Boot Performance Signals' -Body (New-Table $eventRows @('TimeCreated','Id','LevelDisplayName') @{ TimeCreated = 'Time Created'; LevelDisplayName = 'Level' })),
        (New-PreSection -Title 'Quick Network View' -Text (Get-CmdOutput 'ipconfig | findstr /i "IPv4 Default Gateway DNS"')),
        (New-PreSection -Title 'Security Snapshot' -Text (Get-CmdOutput 'netsh advfirewall show allprofiles state'))
    )

    return Save-ReportHtml -Slug 'Health_Dashboard' -Title 'WOW Health Dashboard' -Subtitle 'HTML dashboard version of the CMD health screen' -Cards $cards -Sections $sections -Notice 'This dashboard keeps the fast high-signal checks from the CMD view, but lays them out in a cleaner Venom panel style.' -OpenDocument:$script:ShouldOpenSingle
}

function New-SystemReportHtml {
    if ($script:FastMode) {
        return New-FastInventoryReport
    }

    $facts = Get-QuickFacts
    $processCount = @(Get-Process).Count
    $serviceCount = @(Get-Service | Where-Object Status -eq 'Running').Count
    $startupCount = @(Get-CimInstance Win32_StartupCommand).Count
    $licenseText = Get-ScriptOutput {
        Get-CimInstance SoftwareLicensingProduct |
            Where-Object { $_.PartialProductKey -and $_.Name -like 'Windows*' } |
            Select-Object Name, LicenseStatus, PartialProductKey |
            Format-Table -AutoSize
    }

    $cards = @(
        @{ Label = 'Computer'; Value = $facts.Computer },
        @{ Label = 'OS'; Value = $facts.OS },
        @{ Label = 'Processes'; Value = $processCount },
        @{ Label = 'Running Services'; Value = $serviceCount },
        @{ Label = 'Startup Items'; Value = $startupCount },
        @{ Label = 'RAM'; Value = $facts.RAM }
    )

    $diskText = Get-ScriptOutput {
        Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
            Select-Object DeviceID, VolumeName,
            @{ n = 'SizeGB'; e = { [math]::Round($_.Size / 1GB, 2) } },
            @{ n = 'FreeGB'; e = { [math]::Round($_.FreeSpace / 1GB, 2) } } |
            Format-Table -AutoSize
    }

    $startupText = @(
        (Get-CmdOutput 'reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'),
        '',
        (Get-CmdOutput 'reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run')
    ) -join "`r`n"

    $sections = @(
        (New-PreSection -Title 'System Info' -Text (Get-CmdOutput 'systeminfo') -OpenSection),
        (New-PreSection -Title 'Network Info' -Text (Get-CmdOutput 'ipconfig /all')),
        (New-PreSection -Title 'Disk Info' -Text $diskText),
        (New-PreSection -Title 'Running Processes' -Text (Get-CmdOutput 'tasklist')),
        (New-PreSection -Title 'Running Services' -Text (Get-CmdOutput 'sc query type= service state= running')),
        (New-PreSection -Title 'Startup Programs' -Text $startupText),
        (New-PreSection -Title 'Firewall Status' -Text (Get-CmdOutput 'netsh advfirewall show allprofiles state')),
        (New-PreSection -Title 'Defender Status' -Text (Get-ScriptOutput {
            try {
                Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled, AntispywareEnabled | Format-Table -AutoSize
            } catch {
                'Defender status not available.'
            }
        })),
        (New-PreSection -Title 'Windows License' -Text $licenseText)
    )

    return Save-ReportHtml -Slug 'System_Report' -Title 'Full System Report' -Subtitle 'HTML version of the CMD full system report' -Cards $cards -Sections $sections -Notice 'This report mirrors the big CMD system report, but keeps everything in a searchable HTML file.' -OpenDocument:$script:ShouldOpenSingle
}

function New-CompleteIssueReport {
    if ($script:FastMode) {
        return New-QuickHealthReport
    }

    $facts = Get-QuickFacts
    $os = Get-CimInstance Win32_OperatingSystem

    # Cards
    $cards = @(
        @{ Label = 'Computer'; Value = $facts.Computer },
        @{ Label = 'User'; Value = $facts.User },
        @{ Label = 'OS Edition'; Value = $facts.OS },
        @{ Label = 'Uptime'; Value = $facts.Uptime },
        @{ Label = 'Low Disk Space'; Value = $facts.LowSpace },
        @{ Label = 'Adapters Active'; Value = $facts.AdapterCount }
    )

    # System Info Summary
    $sysSummary = [ordered]@{
        'Computer Name' = $facts.Computer
        'Operating System' = $facts.OS
        'Logged User' = $env:USERNAME
        'System Model' = (Get-CimInstance Win32_ComputerSystem).Model
        'BIOS Version' = (Get-CimInstance Win32_BIOS).Version
        'Last Boot' = Format-DateValue $os.LastBootUpTime
    }

    # Printers Table
    $printers = @(try {
        Get-CimInstance Win32_Printer | ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Driver = $_.DriverName
                Port = $_.PortName
                Status = $_.PrinterStatus
            }
        }
    } catch { @() })

    # Problem Devices (Device manager issues)
    $problemDevices = @(try {
        Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } | ForEach-Object {
            [pscustomobject]@{
                Device = $_.Name
                Class = $_.PNPClass
                Manufacturer = $_.Manufacturer
                ErrorCode = $_.ConfigManagerErrorCode
                Status = $_.Status
            }
        }
    } catch { @() })

    # Firewall Profile Table
    $fwRows = @(try {
        Get-NetFirewallProfile | ForEach-Object {
            [pscustomobject]@{
                Profile = $_.Name
                Status = if ($_.Enabled -eq $true) { 'Active' } else { 'Disabled' }
                InboundAction = $_.DefaultInboundAction.ToString()
                OutboundAction = $_.DefaultOutboundAction.ToString()
            }
        }
    } catch { @() })

    # Windows Update Policies
    $wuPolicies = @(try {
        $paths = @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate', 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU')
        $list = @()
        foreach ($p in $paths) {
            if (Test-Path $p) {
                Get-ItemProperty -Path $p | Get-Member -MemberType NoteProperty | ForEach-Object {
                    $name = $_.Name
                    $val = (Get-ItemProperty -Path $p).$name
                    $list += [pscustomobject]@{ Policy = $name; Value = $val; Path = $p }
                }
            }
        }
        $list
    } catch { @() })

    # Recent System Errors
    $systemErrors = @(try {
        Get-WinEvent -LogName System -MaxEvents 50 -ErrorAction SilentlyContinue |
            Where-Object { $_.Level -le 2 } |
            ForEach-Object {
                [pscustomobject]@{
                    Time = Format-DateValue $_.TimeCreated
                    EventID = $_.Id
                    Source = $_.ProviderName
                    Message = if ($_.Message) { $_.Message.Split("`n")[0] } else { 'N/A' }
                }
            }
    } catch { @() })

    $disks = @(Get-LogicalDiskRows)

    $sections = @(
        (New-Section -Title 'System Properties & BIOS Info' -Body (New-KvTable $sysSummary) -OpenSection),
        (New-Section -Title 'Logical Volumes & Disks Health' -Body (New-Table $disks @('Drive','Volume','FileSystem','TotalSize','UsedSpace','FreeSpace','UsedPercent','FreePercent','HealthStatus') @{ TotalSize = 'Total Size'; UsedSpace = 'Used Space'; FreeSpace = 'Free Space'; UsedPercent = 'Used %'; FreePercent = 'Free %'; HealthStatus = 'Health Status' })),
        (New-Section -Title 'Device Manager Problem Devices' -Body (
            if ($problemDevices.Count -gt 0) {
                New-Table $problemDevices @('Device','Class','Manufacturer','ErrorCode','Status') @{ ErrorCode = 'Error Code' }
            } else {
                '<div class="status-ok">✔ All PnP system hardware devices are operating normally. Zero driver errors logged.</div>'
            }
        ) -OpenSection),
        (New-Section -Title 'Installed Printers & Status' -Body (New-Table $printers @('Name','Driver','Port','Status'))),
        (New-Section -Title 'Windows Firewall Profiles State' -Body (New-Table $fwRows @('Profile','Status','InboundAction','OutboundAction') @{ InboundAction = 'Inbound Action'; OutboundAction = 'Outbound Action' })),
        (New-Section -Title 'Configured Windows Update Policies' -Body (
            if ($wuPolicies.Count -gt 0) {
                New-Table $wuPolicies @('Policy','Value','Path')
            } else {
                '<div style="color:var(--text-muted); font-size:12.5px; padding:6px;">No custom Group Policies set for Windows Update.</div>'
            }
        )),
        (New-Section -Title 'Critical Errors & Warnings Log (Last 50 Events)' -Body (New-Table $systemErrors @('Time','EventID','Source','Message') @{ EventID = 'Event ID' })),
        (New-PreSection -Title 'Raw Network Diagnostics Output' -Text (Get-CmdOutput 'ipconfig /all'))
    )

    return Save-ReportHtml -Slug 'Complete_Issue_Report' -Title 'Complete System Issue & Diagnostics Report' -Subtitle 'Comprehensive diagnostics pack documenting device manager errors, group policies, update state and event logs' -Cards $cards -Sections $sections -Notice 'Contains detailed administrative logs useful for support and repair dispatch.' -OpenDocument:$script:ShouldOpenSingle
}

function New-NetworkReport {
    $facts = Get-QuickFacts
    
    # Active IP address lookup
    $activeIP = 'N/A'
    try {
        $activeIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex (Get-NetConnectionProfile | Select-Object -First 1).InterfaceIndex -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
    } catch {}
    
    # Cards
    $cards = @(
        @{ Label = 'Computer'; Value = $facts.Computer },
        @{ Label = 'Adapters Active'; Value = $facts.AdapterCount },
        @{ Label = 'Connection Identity'; Value = $facts.NetworkIdentity },
        @{ Label = 'Active IPv4'; Value = $activeIP }
    )

    # Active IP config rows
    $netConfig = @(try {
        Get-NetIPConfiguration | ForEach-Object {
            $adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
            $ip = @($_.IPv4Address | Select-Object -First 1)
            $gw = @($_.IPv4DefaultGateway | Select-Object -First 1)
            [pscustomobject]@{
                Interface = $_.InterfaceAlias
                IPAddress = if ($ip.Count) { $ip[0].IPAddress } else { 'N/A' }
                Gateway = if ($gw.Count) { $gw[0].NextHop } else { 'N/A' }
                MacAddress = if ($adapter) { $adapter.MacAddress } else { 'N/A' }
                LinkSpeed = if ($adapter) { $adapter.LinkSpeed } else { 'N/A' }
                Status = if ($adapter) { $adapter.Status.ToString() } else { 'Unknown' }
            }
        }
    } catch { @() })

    # DNS configuration
    $dnsRows = @(try {
        Get-DnsClientServerAddress -AddressFamily IPv4 | ForEach-Object {
            [pscustomobject]@{
                Interface = $_.InterfaceAlias
                DNSServers = ($_.ServerAddresses -join ', ')
            }
        }
    } catch { @() })

    # Shared Folders
    $shares = @(Get-CimInstance Win32_Share | Where-Object { $_.Name -notmatch '\$$' } | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{
            ShareName = $_.Name
            LocalPath = $_.Path
            Description = $_.Description
        }
    })

    # Saved Wi-Fi passwords (Wi-Fi Vault)
    $wifiRows = @(Get-WifiProfiles)

    $sections = @(
        (New-Section -Title 'Physical & Virtual Adapters Configuration' -Body (New-Table $netConfig @('Interface','IPAddress','Gateway','MacAddress','LinkSpeed','Status') @{ IPAddress = 'IP Address'; MacAddress = 'MAC Address'; LinkSpeed = 'Link Speed' }) -OpenSection),
        (New-Section -Title 'Interface DNS Server Allocation' -Body (New-Table $dnsRows @('Interface','DNSServers') @{ DNSServers = 'DNS Servers' })),
        (New-Section -Title 'Saved Wi-Fi Profiles & Decrypted Keys' -Body (
            if ($wifiRows.Count -gt 0) {
                New-Table $wifiRows @('SSID','Password','Status') @{ SSID = 'Network SSID'; Password = 'Plaintext Password' }
            } else {
                '<div style="color:var(--text-muted); font-size:12.5px; padding:6px;">No saved Wi-Fi profiles found.</div>'
            }
        )),
        (New-Section -Title 'Active SMB Folder Shares' -Body (
            if ($shares.Count -gt 0) {
                New-Table $shares @('ShareName','LocalPath','Description') @{ ShareName = 'Share Name'; LocalPath = 'Local Path' }
            } else {
                '<div style="color:var(--text-muted); font-size:12.5px; padding:6px;">No folders shared over the network.</div>'
            }
        )),
        (New-PreSection -Title 'Raw ipconfig Configuration Detail' -Text (Get-CmdOutput 'ipconfig /all')),
        (New-PreSection -Title 'WLAN Interfaces & Wireless Drivers' -Text ((Get-CmdOutput 'netsh wlan show interfaces') + "`r`n`r`n" + (Get-CmdOutput 'netsh wlan show drivers'))),
        (New-PreSection -Title 'Active Connections Socket Routing Table' -Text (Get-CmdOutput 'route print'))
    )

    return Save-ReportHtml -Slug 'Network_Report' -Title 'Network Configuration & Evidence Report' -Subtitle 'Detailed inventory of network adapters, IPv4 routing tables, shared paths, and decrypted Wi-Fi profiles' -Cards $cards -Sections $sections -Notice 'Contains sensitive cleartext Wi-Fi connection credentials.' -OpenDocument:$script:ShouldOpenSingle
}

function New-DriverReport {
    $facts = Get-QuickFacts
    
    # Active driver query
    $signedDriversCount = @(Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.IsSigned -eq $true }).Count
    $unsignedCount = @(Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.IsSigned -eq $false }).Count
    
    $problemDevices = @(try {
        Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } | ForEach-Object {
            [pscustomobject]@{
                Device = $_.Name
                Class = $_.PNPClass
                Manufacturer = $_.Manufacturer
                ErrorCode = $_.ConfigManagerErrorCode
                Status = $_.Status
            }
        }
    } catch { @() })

    # Cards
    $cards = @(
        @{ Label = 'Computer'; Value = $facts.Computer },
        @{ Label = 'Signed Drivers'; Value = $signedDriversCount },
        @{ Label = 'Unsigned Drivers'; Value = $unsignedCount },
        @{ Label = 'Problem Devices'; Value = $problemDevices.Count }
    )

    # Active system drivers (loaded kernel modules)
    $loadedDrivers = @(try {
        Get-CimInstance Win32_SystemDriver | Where-Object { $_.State -eq 'Running' } | Sort-Object DisplayName | Select-Object -First 100 | ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Description = $_.DisplayName
                StartMode = $_.StartMode
                State = $_.State
                Path = $_.PathName
            }
        }
    } catch { @() })

    $sections = @(
        (New-Section -Title 'Problematic Hardware Devices (Alerts)' -Body (
            if ($problemDevices.Count -gt 0) {
                New-Table $problemDevices @('Device','Class','Manufacturer','ErrorCode','Status') @{ ErrorCode = 'Error Code' }
            } else {
                '<div class="status-ok">✔ All PnP system hardware devices are operating normally. Zero driver errors logged.</div>'
            }
        ) -OpenSection),
        (New-Section -Title 'Active System Drivers & Services (Top 100)' -Body (New-Table $loadedDrivers @('Name','Description','StartMode','State','Path') @{ StartMode = 'Start Mode' })),
        (New-PreSection -Title 'DriverQuery Verbose Console Dump' -Text (Get-CmdOutput 'driverquery /v')),
        (New-PreSection -Title 'Third-party PnP Driver Store' -Text (Get-CmdOutput 'pnputil /enum-drivers'))
    )

    return Save-ReportHtml -Slug 'Driver_Report' -Title 'System Driver Integrity Report' -Subtitle 'Deep audit of PnP hardware error status, kernel driver modules, and third-party driver stores' -Cards $cards -Sections $sections -Notice 'Compiled by UltimateToolkit Driver Audit daemon.' -OpenDocument:$script:ShouldOpenSingle
}

function New-AppsReport {
    $apps = @(Get-RegistryApps)
    $portable = @(Read-ToolsCatalog)
    $appx = if ($script:FastMode) { @() } else { @(try {
        Get-AppxPackage | Select-Object Name, Version, PackageFullName | Sort-Object Name
    } catch { @() }) }
    
    # Winget search
    $wingetList = @()
    if (-not $script:FastMode) {
        $wingetRaw = Get-CmdOutput 'winget list --accept-source-agreements'
    }
    $wingetText = if ($script:FastMode) { 'Skipped in fast mode to speed up report generation.' } else { $wingetRaw }

    # Cards
    $cards = @(
        @{ Label = 'Registry Apps'; Value = $apps.Count },
        @{ Label = 'AppX Packages'; Value = $appx.Count },
        @{ Label = 'Portable Tools'; Value = $portable.Count },
        @{ Label = 'Machine'; Value = $env:COMPUTERNAME }
    )

    $sections = @(
        (New-Section -Title 'Installed Applications (Registry Store)' -Body (New-Table $apps @('Name','Version','Publisher','InstallDate') @{ InstallDate = 'Install Date' }) -OpenSection),
        (New-Section -Title 'Portable Utilities Catalog' -Body (
            if ($portable.Count -gt 0) {
                New-Table $portable @('Name','Path') @{ Path = 'Local Catalog Path' }
            } else {
                '<div style="color:var(--text-muted); font-size:12.5px; padding:6px;">No portable utility packages cataloged.</div>'
            }
        )),
        (New-Section -Title 'AppX Universal Platform Packages' -Body (
            if ($appx.Count -gt 0) {
                New-Table $appx @('Name','Version','PackageFullName') @{ PackageFullName = 'Package Identity' }
            } else {
                '<div style="color:var(--text-muted); font-size:12.5px; padding:6px;">No AppX packages cataloged.</div>'
            }
        )),
        (New-PreSection -Title 'Winget Packages & Available Updates List' -Text $wingetText)
    )

    return Save-ReportHtml -Slug 'Apps_Inventory' -Title 'Software Asset & App Inventory Report' -Subtitle 'Consolidated record of standard applications, UWP platform packages, portable utilities, and winget packages' -Cards $cards -Sections $sections -Notice 'Compiled by UltimateToolkit Package Inspector.' -OpenDocument:$script:ShouldOpenSingle
}

function New-EvidencePackReport {
    if ($script:FastMode) {
        return New-QuickHealthReport
    }

    $cards = @(
        @{ Label = 'Computer'; Value = $env:COMPUTERNAME },
        @{ Label = 'User'; Value = $env:USERNAME },
        @{ Label = 'Generated'; Value = $Now.ToString('dd-MMM HH:mm') },
        @{ Label = 'Type'; Value = 'All-in-One Evidence' }
    )

    $sections = @(
        (New-PreSection -Title 'SystemInfo' -Text (Get-CmdOutput 'systeminfo') -OpenSection),
        (New-PreSection -Title 'IPConfig' -Text (Get-CmdOutput 'ipconfig /all')),
        (New-PreSection -Title 'Disk Health' -Text (Get-ScriptOutput {
            Get-CimInstance Win32_DiskDrive | Select-Object Model, SerialNumber, MediaType, InterfaceType, Status | Format-Table -AutoSize
        })),
        (New-PreSection -Title 'Problem Devices' -Text (Get-CmdOutput 'pnputil /enum-devices /problem')),
        (New-PreSection -Title 'Services State' -Text (Get-CmdOutput 'sc query state= all')),
        (New-PreSection -Title 'Recent System Errors' -Text (Get-CmdOutput 'wevtutil qe System /q:"*[System[(Level=1 or Level=2)]]" /f:text /c:40'))
    )

    return Save-ReportHtml -Slug 'Evidence_Pack' -Title 'Complete Issue Evidence Pack' -Subtitle 'Full evidence collector from the CMD toolkit, wrapped in HTML' -Cards $cards -Sections $sections -Notice 'This report is intentionally broad and verbose, useful when you want one bundle before deeper repair work.' -OpenDocument:$script:ShouldOpenSingle
}

function New-BootPerformanceReport {
    $rows = @(try {
        Get-WinEvent -ProviderName Microsoft-Windows-Diagnostics-Performance -MaxEvents 30 |
            Select-Object TimeCreated, Id, LevelDisplayName, Message
    } catch { @() })

    $cards = @(
        @{ Label = 'Machine'; Value = $env:COMPUTERNAME },
        @{ Label = 'Events'; Value = $rows.Count },
        @{ Label = 'Focus'; Value = 'Boot / Resume' },
        @{ Label = 'Generated'; Value = $Now.ToString('HH:mm') }
    )

    $sections = @(
        (New-Section -Title 'Boot Performance Events' -Body (New-Table $rows @('TimeCreated','Id','LevelDisplayName','Message') @{ TimeCreated = 'Time Created'; LevelDisplayName = 'Level' }) -OpenSection)
    )

    return Save-ReportHtml -Slug 'Boot_Performance' -Title 'Boot Performance Events' -Subtitle 'HTML view of diagnostics-performance events' -Cards $cards -Sections $sections -Notice 'This is the readable HTML form of the boot diagnostics checks used in the CMD toolkit.' -OpenDocument:$script:ShouldOpenSingle
}

function New-BatteryReport {
    $reportPath = Join-Path $OutputRoot ("{0}_BatteryReport_{1}.html" -f $ComputerSafe, $Stamp)
    $commandOutput = Get-CmdOutput ('powercfg /batteryreport /output "{0}"' -f $reportPath)
    
    # Query CIM battery details
    $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($bat) {
        $wear = 0
        if ($bat.DesignCapacity -and $bat.FullChargeCapacity -and $bat.DesignCapacity -gt 0) {
            $wear = [math]::Round((1 - ($bat.FullChargeCapacity / $bat.DesignCapacity)) * 100, 1)
        }
        $health = 100 - $wear
        
        $cards = @(
            @{ Label = 'Battery Model'; Value = $bat.Name },
            @{ Label = 'Chemistry'; Value = $bat.Chemistry },
            @{ Label = 'Design Capacity'; Value = "$($bat.DesignCapacity) mWh" },
            @{ Label = 'Full Capacity'; Value = "$($bat.FullChargeCapacity) mWh" },
            @{ Label = 'Health Score'; Value = "$health%" },
            @{ Label = 'Current Charge'; Value = if ($bat.EstimatedChargeRemaining -ne $null) { "$($bat.EstimatedChargeRemaining)%" } else { 'N/A' } }
        )

        $batDetails = [ordered]@{
            'Friendly Name' = $bat.Name
            'Device ID' = $bat.DeviceID
            'Chemistry' = $bat.Chemistry
            'Design Capacity' = "$($bat.DesignCapacity) mWh"
            'Full Charge Capacity' = "$($bat.FullChargeCapacity) mWh"
            'Battery Wear Level' = "$wear%"
            'Battery Health State' = "$health%"
            'Design Voltage' = if ($bat.DesignVoltage) { "$($bat.DesignVoltage) mV" } else { 'N/A' }
            'Estimated Run Time' = if ($bat.EstimatedRunTime -and $bat.EstimatedRunTime -ne 71582788) { "$($bat.EstimatedRunTime) Minutes" } else { 'N/A' }
            'Status' = $bat.Status
        }

        $sections = @(
            (New-Section -Title 'Battery Charge & Longevity Metrics' -Body (New-KvTable $batDetails) -OpenSection),
            (New-PreSection -Title 'Power Configuration Requests & Inhibitors' -Text (Get-CmdOutput 'powercfg /requests')),
            (New-PreSection -Title 'Powercfg Battery Command Raw Output' -Text $commandOutput)
        )

        return Save-ReportHtml -Slug 'BatteryReport' -Title 'Power & Battery Diagnostics Report' -Subtitle 'Hardware charge capacity profiles, cells chemistry details, wear assessment and power inhibitors list' -Cards $cards -Sections $sections -Notice 'Compiled by UltimateToolkit Energy Diagnostics.' -OpenDocument:$script:ShouldOpenSingle
    }

    # Fallback if no hardware battery exists (e.g. desktop)
    $cards = @(
        @{ Label = 'Computer'; Value = $env:COMPUTERNAME },
        @{ Label = 'Battery Status'; Value = 'No Battery Detected' }
    )
    $sections = @(
        (New-PreSection -Title 'Power Configuration Requests' -Text (Get-CmdOutput 'powercfg /requests') -OpenSection),
        (New-PreSection -Title 'Powercfg Command Output' -Text $commandOutput)
    )
    return Save-ReportHtml -Slug 'BatteryReport' -Title 'Power Diagnostics Report' -Subtitle 'Power inhibitors and configuration summary' -Cards $cards -Sections $sections -Notice 'No battery hardware was detected on this machine.' -OpenDocument:$script:ShouldOpenSingle
}

function New-EnergyReport {
    if ($script:FastMode) {
        return Save-ReportHtml -Slug 'EnergyReport' -Title 'Fast Energy Summary' -Subtitle 'Fast mode avoids the 60-second native energy trace' -Cards @(
            @{ Label = 'Machine'; Value = $env:COMPUTERNAME },
            @{ Label = 'Mode'; Value = 'Fast' }
        ) -Sections @(
            (New-PreSection -Title 'Power Requests' -Text (Get-CmdOutput 'powercfg /requests') -OpenSection)
        ) -Notice 'Native powercfg /energy normally takes about 60 seconds, so fast mode uses a quick power request summary.' -OpenDocument:$script:ShouldOpenSingle
    }

    $reportPath = Join-Path $OutputRoot ("{0}_EnergyReport_{1}.html" -f $ComputerSafe, $Stamp)
    $commandOutput = Get-CmdOutput ('powercfg /energy /output "{0}"' -f $reportPath)
    if (Test-Path -LiteralPath $reportPath) {
        $latestPath = Copy-LatestFile -SourcePath $reportPath -LatestName ("{0}_EnergyReport.html" -f $ComputerSafe)
        if ($script:ShouldOpenSingle) {
            Start-Process -FilePath $latestPath | Out-Null
        }
        return [pscustomobject]@{
            Name = 'Energy Report'
            Path = $latestPath
            ArtifactPath = $latestPath
            Kind = 'html'
        }
    }

    return Save-ReportHtml -Slug 'EnergyReport' -Title 'Energy Report Fallback' -Subtitle 'Fallback summary when Windows does not create the native energy HTML report' -Cards @(
        @{ Label = 'Machine'; Value = $env:COMPUTERNAME },
        @{ Label = 'Status'; Value = 'Native report missing' }
    ) -Sections @(
        (New-PreSection -Title 'Energy Report Command Output' -Text $commandOutput -OpenSection),
        (New-PreSection -Title 'Power Requests' -Text (Get-CmdOutput 'powercfg /requests'))
    ) -Notice 'If this report is launched from the elevated GUI it should normally create the native HTML. This fallback keeps the result visible even when Windows blocks the native file.' -OpenDocument:$script:ShouldOpenSingle
}

function New-GPResultReport {
    if ($script:FastMode) {
        return Save-ReportHtml -Slug 'GPResult' -Title 'Fast GPResult Summary' -Subtitle 'Fast mode skips gpupdate /force and native GPResult export' -Cards @(
            @{ Label = 'Machine'; Value = $env:COMPUTERNAME },
            @{ Label = 'Mode'; Value = 'Fast' }
        ) -Sections @(
            (New-PreSection -Title 'Applied User Policy Summary' -Text (Get-CmdOutput 'gpresult /r /scope user') -OpenSection),
            (New-PreSection -Title 'Applied Computer Policy Summary' -Text (Get-CmdOutput 'gpresult /r /scope computer'))
        ) -Notice 'Fast mode skips gpupdate /force because it can take several minutes on domain systems.' -OpenDocument:$script:ShouldOpenSingle
    }

    $gpupdateOutput = Get-CmdOutput 'gpupdate /force'
    $reportPath = Join-Path $OutputRoot ("{0}_GPResult_{1}.html" -f $ComputerSafe, $Stamp)
    $gpresultOutput = Get-CmdOutput ('gpresult /h "{0}" /f' -f $reportPath)
    if (Test-Path -LiteralPath $reportPath) {
        $latestPath = Copy-LatestFile -SourcePath $reportPath -LatestName ("{0}_GPResult.html" -f $ComputerSafe)
        if ($script:ShouldOpenSingle) {
            Start-Process -FilePath $latestPath | Out-Null
        }
        return [pscustomobject]@{
            Name = 'GPResult HTML'
            Path = $latestPath
            ArtifactPath = $latestPath
            Kind = 'html'
        }
    }

    return Save-ReportHtml -Slug 'GPResult' -Title 'GPResult Fallback Summary' -Subtitle 'Fallback summary when GPResult HTML is not created' -Cards @(
        @{ Label = 'Machine'; Value = $env:COMPUTERNAME },
        @{ Label = 'Status'; Value = 'Native report missing' }
    ) -Sections @(
        (New-PreSection -Title 'GPUpdate Output' -Text $gpupdateOutput -OpenSection),
        (New-PreSection -Title 'GPResult Output' -Text $gpresultOutput)
    ) -Notice 'If Group Policy HTML cannot be created, this fallback still keeps the command results available.' -OpenDocument:$script:ShouldOpenSingle
}

function New-WlanReport {
    if ($script:FastMode) {
        return Save-ReportHtml -Slug 'WLAN_Report' -Title 'Fast WLAN Report' -Subtitle 'Fast WLAN interface and driver snapshot' -Cards @(
            @{ Label = 'Machine'; Value = $env:COMPUTERNAME },
            @{ Label = 'Mode'; Value = 'Fast' }
        ) -Sections @(
            (New-PreSection -Title 'WLAN Interfaces' -Text (Get-CmdOutput 'netsh wlan show interfaces') -OpenSection),
            (New-PreSection -Title 'WLAN Drivers' -Text (Get-CmdOutput 'netsh wlan show drivers'))
        ) -Notice 'Fast mode skips the native WLAN history export and keeps the current WLAN state.' -OpenDocument:$script:ShouldOpenSingle
    }

    & netsh wlan show wlanreport | Out-Null
    $source = Join-Path $env:ProgramData 'Microsoft\Windows\WlanReport\wlan-report-latest.html'
    if (Test-Path -LiteralPath $source) {
        $reportPath = Join-Path $OutputRoot ("{0}_WLAN_Report_{1}.html" -f $ComputerSafe, $Stamp)
        Copy-Item -LiteralPath $source -Destination $reportPath -Force
        $latestPath = Copy-LatestFile -SourcePath $reportPath -LatestName ("{0}_WLAN_Report.html" -f $ComputerSafe)
        if ($script:ShouldOpenSingle) {
            Start-Process -FilePath $latestPath | Out-Null
        }
        return [pscustomobject]@{
            Name = 'WLAN Report'
            Path = $latestPath
            ArtifactPath = $latestPath
            Kind = 'html'
        }
    }

    return Save-ReportHtml -Slug 'WLAN_Report' -Title 'WLAN Report' -Subtitle 'Fallback HTML summary when native WLAN report is unavailable' -Cards @(
        @{ Label = 'Machine'; Value = $env:COMPUTERNAME },
        @{ Label = 'Status'; Value = 'Native report missing' }
    ) -Sections @(
        (New-PreSection -Title 'WLAN Interfaces' -Text (Get-CmdOutput 'netsh wlan show interfaces') -OpenSection),
        (New-PreSection -Title 'WLAN Drivers' -Text (Get-CmdOutput 'netsh wlan show drivers'))
    ) -Notice 'Windows did not expose the native wlan-report-latest.html file, so this fallback HTML still preserves the WLAN diagnostics content.' -OpenDocument:$script:ShouldOpenSingle
}

function New-MsInfoSummary {
    if ($script:FastMode) {
        return New-FastInventoryReport
    }

    $nfoPath = Join-Path $OutputRoot ("{0}_MSInfo_{1}.nfo" -f $ComputerSafe, $Stamp)
    Start-Process -FilePath 'msinfo32.exe' -ArgumentList @('/nfo', $nfoPath) -WindowStyle Hidden -Wait | Out-Null

    $summary = [ordered]@{
        'MSInfo Export Path' = $nfoPath
        'Status' = if (Test-Path -LiteralPath $nfoPath) { 'Ready' } else { 'Not found' }
        'Computer Name' = $env:COMPUTERNAME
        'Generated' = Format-DateValue $Now
    }

    return Save-ReportHtml -Slug 'MSInfo_Export' -Title 'MSInfo Export Summary' -Subtitle 'Summary page for the exported MSInfo NFO file' -Cards @(
        @{ Label = 'Machine'; Value = $env:COMPUTERNAME },
        @{ Label = 'Artifact'; Value = 'NFO Export' }
    ) -Sections @(
        (New-Section -Title 'MSInfo Export' -Body (New-KvTable $summary) -OpenSection)
    ) -Notice 'The actual MSInfo report is saved as an NFO file so it can still open in System Information with full detail.' -OpenDocument:$script:ShouldOpenSingle
}

function New-EventExportSummary {
    if ($script:FastMode) {
        $rows = @(try {
            Get-WinEvent -LogName System -MaxEvents 80 |
                Where-Object { $_.Level -le 3 } |
                Select-Object TimeCreated, Id, LevelDisplayName, ProviderName
        } catch { @() })

        return Save-ReportHtml -Slug 'Event_Log_Export' -Title 'Fast Event Summary' -Subtitle 'Recent warning/error events without EVTX export' -Cards @(
            @{ Label = 'Machine'; Value = $env:COMPUTERNAME },
            @{ Label = 'Events'; Value = $rows.Count }
        ) -Sections @(
            (New-Section -Title 'Recent System Signals' -Body (New-Table $rows @('TimeCreated','Id','LevelDisplayName','ProviderName') @{ TimeCreated = 'Time Created'; LevelDisplayName = 'Level'; ProviderName = 'Provider' }) -OpenSection)
        ) -Notice 'Fast mode skips full EVTX export and shows recent high-signal events.' -OpenDocument:$script:ShouldOpenSingle
    }

    $systemPath = Join-Path $OutputRoot ("{0}_System_{1}.evtx" -f $ComputerSafe, $Stamp)
    $appPath = Join-Path $OutputRoot ("{0}_Application_{1}.evtx" -f $ComputerSafe, $Stamp)
    & wevtutil epl System $systemPath | Out-Null
    & wevtutil epl Application $appPath | Out-Null

    $rows = @(
        [pscustomobject]@{ Log = 'System'; Path = $systemPath; Status = if (Test-Path -LiteralPath $systemPath) { 'Ready' } else { 'Missing' } },
        [pscustomobject]@{ Log = 'Application'; Path = $appPath; Status = if (Test-Path -LiteralPath $appPath) { 'Ready' } else { 'Missing' } }
    )

    return Save-ReportHtml -Slug 'Event_Log_Export' -Title 'Event Log Export Summary' -Subtitle 'Summary page for exported EVTX files' -Cards @(
        @{ Label = 'Machine'; Value = $env:COMPUTERNAME },
        @{ Label = 'Exports'; Value = $rows.Count }
    ) -Sections @(
        (New-Section -Title 'Exported Event Files' -Body (New-Table $rows @('Log','Path','Status')) -OpenSection)
    ) -Notice 'The raw event exports are saved as EVTX files for later review in Event Viewer.' -OpenDocument:$script:ShouldOpenSingle
}

function New-ReportHub {
    param([object[]]$Reports)

    $cards = @(
        @{ Label = 'Machine'; Value = $env:COMPUTERNAME },
        @{ Label = 'Reports Created'; Value = $Reports.Count },
        @{ Label = 'HTML Files'; Value = @($Reports | Where-Object { $_.Kind -eq 'html' }).Count },
        @{ Label = 'Output Folder'; Value = Split-Path -Leaf $OutputRoot }
    )

    $rows = foreach ($report in $Reports) {
        [pscustomobject]@{
            Report = $report.Name
            File = $report.Path
            Type = $report.Kind
            Status = if (Test-Path -LiteralPath $report.Path) { 'Ready' } else { 'Missing' }
        }
    }

    return Save-ReportHtml -Slug 'Report_Hub' -Title 'One Click All Info Report Hub' -Subtitle 'All important PC info in one fast searchable report pack' -Cards $cards -Sections @(
        (New-Section -Title 'Generated Reports' -Body (New-Table $rows @('Report','File','Type','Status')) -OpenSection)
    ) -Notice 'One click report pack ready. Use the links/paths below to open inventory, health, apps, boot, events, and summary reports.' -OpenDocument:$Open
}

function Invoke-Mode {
    switch ($Mode) {
        'inventory' { return @(Invoke-InventoryReport) }
        'quick-health' { return @(New-QuickHealthReport) }
        'dashboard' { return @(New-HealthDashboardReport) }
        'system' { return @(New-SystemReportHtml) }
        'complete-issue' { return @(New-CompleteIssueReport) }
        'network' { return @(New-NetworkReport) }
        'driver' { return @(New-DriverReport) }
        'apps' { return @(New-AppsReport) }
        'evidence' { return @(New-EvidencePackReport) }
        'boot' { return @(New-BootPerformanceReport) }
        'battery' { return @(New-BatteryReport) }
        'energy' { return @(New-EnergyReport) }
        'gpresult' { return @(New-GPResultReport) }
        'wlan' { return @(New-WlanReport) }
        'msinfo' { return @(New-MsInfoSummary) }
        'events' { return @(New-EventExportSummary) }
        'all' {
            $script:MergeMode = $true
            $reportsData = @()
            if ($script:FastMode) {
                $reportsData += New-FastInventoryReport
                $reportsData += New-QuickHealthReport
                $reportsData += New-HealthDashboardReport
                $reportsData += New-AppsReport
                $reportsData += New-BootPerformanceReport
                $reportsData += New-EventExportSummary
            } else {
                # In non-fast mode, compile all diagnostic reports inline
                $reportsData += New-FastInventoryReport
                $reportsData += New-QuickHealthReport
                $reportsData += New-HealthDashboardReport
                $reportsData += New-SystemReportHtml
                $reportsData += New-CompleteIssueReport
                $reportsData += New-NetworkReport
                $reportsData += New-DriverReport
                $reportsData += New-AppsReport
                $reportsData += New-EvidencePackReport
                $reportsData += New-BootPerformanceReport
                $reportsData += New-BatteryReport
                $reportsData += New-EnergyReport
                $reportsData += New-GPResultReport
                $reportsData += New-WlanReport
                $reportsData += New-MsInfoSummary
                $reportsData += New-EventExportSummary
            }
            $script:MergeMode = $false

            # Extract unique KPI cards
            $mergedCards = @()
            $seenLabels = @{}
            foreach ($rep in $reportsData) {
                foreach ($card in $rep.Cards) {
                    $label = if ($card -is [System.Collections.IDictionary]) { $card['Label'] } else { $card.Label }
                    if (-not $seenLabels.ContainsKey($label)) {
                        $seenLabels[$label] = $true
                        $mergedCards += $card
                    }
                }
            }

            # Extract sections and prefix their titles to classify them nicely
            $mergedSections = @()
            foreach ($rep in $reportsData) {
                $prefix = $rep.Title -replace ' Report$', '' -replace ' Pack$', '' -replace ' Inventory$', '' -replace ' Snapshot$', ''
                foreach ($sec in $rep.Sections) {
                    # Prefix the summary span tag with the capitalized category
                    $secPrefixed = $sec -replace '<summary><span>', "<summary><span>[$($prefix.ToUpper())] "
                    $mergedSections += $secPrefixed
                }
            }

            # Build and return the unified master diagnostic report
            $mergedReport = Save-ReportHtml -Slug 'Merged_System_Report' `
                -Title 'Ultimate Merged System Diagnostics' `
                -Subtitle 'Unified Health, Inventory, Performance and Security diagnostics report' `
                -Cards $mergedCards `
                -Sections $mergedSections `
                -Notice 'This report compiles all individual diagnostic logs, performance telemetry, and system inventories into a single unified HTML view.' `
                -OpenDocument:$Open

            return @($mergedReport)
        }
    }
}

$results = Invoke-Mode
foreach ($result in @($results)) {
    if ($result -and $result.Path) {
        Write-Host ('Report ready: ' + $result.Path)
    }
}
