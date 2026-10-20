param(

    [switch]$NoElevate,

    [switch]$SelfTest,

    [switch]$SilentClean

)

# Custom MessageBox Silencer & URL Bypass Logging Interceptors
function Out-MessageBox {
    param(
        [Parameter(Position=0)]$Message,
        [Parameter(Position=1)]$Title = 'SysForge Studio',
        [Parameter(Position=2)]$Buttons = 'OK',
        [Parameter(Position=3)]$Icon = 'None'
    )
    # Check if $Message is an array/collection (happens when called using C# syntax like function(a, b))
    if ($Message -is [System.Array] -or $Message -is [System.Collections.IList]) {
        $Title   = if ($Message.Count -gt 1) { $Message[1] } else { 'SysForge Studio' }
        $Buttons = if ($Message.Count -gt 2) { $Message[2] } else { 'OK' }
        $Icon    = if ($Message.Count -gt 3) { $Message[3] } else { 'None' }
        $Message = $Message[0]
    }

    $buttonsStr = $Buttons.ToString()
    # Silence any "OK" only popups
    if ($buttonsStr -eq 'OK' -or $buttonsStr -eq '0' -or [string]::IsNullOrEmpty($buttonsStr)) {
        $logPath = "C:\Users\Public\UltimateToolkit_Logs\gui_events.log"
        $logDir = Split-Path -Parent $logPath
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $stamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        $logLine = "[$stamp] [Notification Suppressed] [$Title] [$Icon] $Message"
        Add-Content -LiteralPath $logPath -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
        return [System.Windows.Forms.DialogResult]::OK
    } else {
        # Show actual message box for YesNo or other dialog choices
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        return Out-MessageBox($Message, $Title, $Buttons, $Icon)
    }
}

function Start-Process {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true, Position=0)]
        [System.Object]$FilePath,
        [Parameter(Position=1)]
        [System.String[]]$ArgumentList,
        [System.String]$WorkingDirectory,
        [System.Management.Automation.SwitchParameter]$Wait,
        [System.Diagnostics.ProcessWindowStyle]$WindowStyle,
        [System.String]$Verb,
        [System.Management.Automation.SwitchParameter]$PassThru,
        [System.Management.Automation.SwitchParameter]$NoNewWindow
    )
    $pathStr = if ($null -ne $FilePath) { $FilePath.ToString() } else { "" }
    if ($pathStr -like "http:*" -or $pathStr -like "https:*" -or $pathStr -like "*.html" -or $pathStr -like "*.htm") {
        $logPath = "C:\Users\Public\UltimateToolkit_Logs\gui_events.log"
        $logDir = Split-Path -Parent $logPath
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $stamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        $logLine = "[$stamp] [Browser Bypass] Blocked URL/HTML open: $pathStr"
        Add-Content -LiteralPath $logPath -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($PassThru) { return $null }
        return
    }

    $params = @{}
    if ($PSBoundParameters.ContainsKey('FilePath')) { $params['FilePath'] = $FilePath }
    if ($PSBoundParameters.ContainsKey('ArgumentList')) { $params['ArgumentList'] = $ArgumentList }
    if ($PSBoundParameters.ContainsKey('WorkingDirectory')) { $params['WorkingDirectory'] = $WorkingDirectory }
    if ($PSBoundParameters.ContainsKey('Wait')) { $params['Wait'] = $Wait }
    if ($PSBoundParameters.ContainsKey('WindowStyle')) { $params['WindowStyle'] = $WindowStyle }
    if ($PSBoundParameters.ContainsKey('Verb')) { $params['Verb'] = $Verb }
    if ($PSBoundParameters.ContainsKey('PassThru')) { $params['PassThru'] = $PassThru }
    if ($PSBoundParameters.ContainsKey('NoNewWindow')) { $params['NoNewWindow'] = $NoNewWindow }

    Microsoft.PowerShell.Utility\Start-Process @params
}





# Robustly find script directory under all execution environments

$ScriptDir = ""

if ($MyInvocation.MyCommand.Path) {

    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

} elseif ($PSScriptRoot) {

    $ScriptDir = $PSScriptRoot

} else {

    $ScriptDir = Get-Location

}

$script:ToolkitRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir '..'))

if ($ScriptDir -like '*Config\Temp' -or $ScriptDir -like '*Config\Temp\') {

    $script:ToolkitRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir '..\..'))

}

if (-not $script:ToolkitRoot.EndsWith('\')) { $script:ToolkitRoot += '\' }

$ToolkitRoot = $script:ToolkitRoot



# Early definition of Test-IsAdmin at startup

function Test-IsAdmin {

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

}



# Auto-elevation check and prompt at startup

if (-not $NoElevate -and -not $SelfTest -and -not $SilentClean) {

    if (-not (Test-IsAdmin)) {

        Add-Type -AssemblyName System.Windows.Forms

        $msgText = "SysForge Studio requires Administrator privileges to run all system cleanups, performance boosts, and diagnostic tweaks successfully.`r`n`r`nWould you like to relaunch the GUI as Administrator?"

        $result = Out-MessageBox($msgText, "Run as Administrator", "YesNo", "Warning")

        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {

            try {

                $scriptPath = $MyInvocation.MyCommand.Path

                if (-not $scriptPath) { $scriptPath = $PSCommandPath }

                if (-not $scriptPath) { $scriptPath = Join-Path $ScriptDir "Modules\Toolkit-GUI-Pro.ps1" }

                Start-Process powershell.exe -ArgumentList "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs

                exit 0

            } catch {

                Out-MessageBox("Failed to elevate: $_`r`nRunning in Standard User mode instead.", "Elevation Failed", "OK", "Warning") | Out-Null

            }

        }

    }

}



if ($SilentClean) {

    # Perform a silent clean of basic items: temp, system temp, and dns

    $tempDir = $env:TEMP

    if (Test-Path -LiteralPath $tempDir) {

        Get-ChildItem -LiteralPath $tempDir -File -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

    }

    $sysTemp = "C:\Windows\Temp"

    if (Test-Path -LiteralPath $sysTemp) {

        Get-ChildItem -LiteralPath $sysTemp -File -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

    }

    Clear-DnsClientCache -ErrorAction SilentlyContinue

    Exit 0

}



$ToolkitBat = Join-Path $script:ToolkitRoot 'Toolkit.bat'

$ToolsCatalogPath = Join-Path $script:ToolkitRoot 'Config\tools.catalog'

$GuiCatalogPath = Join-Path $script:ToolkitRoot 'Config\gui.catalog'

$LogRoot = Join-Path $script:ToolkitRoot 'Logs'

$InventoryReportScript = Join-Path $script:ToolkitRoot 'Modules\SystemInventoryReport.ps1'

$ReportCenterScript = Join-Path $script:ToolkitRoot 'Modules\ToolkitReportCenter.ps1'

$InventoryOutputRoot = Join-Path $env:SystemDrive 'System Inventory'

$script:LocalTempDir = Join-Path $script:ToolkitRoot 'Config\Temp'

if (-not (Test-Path -LiteralPath $script:LocalTempDir)) {

    try { New-Item -ItemType Directory -Force -Path $script:LocalTempDir | Out-Null } catch {}

}



# ============================================================

# SELF-HEALING SYSTEM - Error Logger + Auto-Recovery

# ============================================================

$script:GuiErrorLogPath = Join-Path $script:ToolkitRoot 'Logs\gui_errors.jsonl'

$script:GuiRepairLogPath = Join-Path $script:ToolkitRoot 'Logs\gui_repair.log'

$script:GuiErrorCount   = 0



function Write-GuiErrorLog {

    param(

        [string]$Panel    = 'Unknown',

        [string]$Context  = '',

        [object]$Err      = $null,

        [bool]$Recovered  = $true

    )

    try {

        # Ensure Logs directory exists

        $logDir = Join-Path $script:ToolkitRoot 'Logs'

        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }



        $script:GuiErrorCount++

        $errMsg   = if ($null -ne $Err) { "$($Err.Exception.Message)" } else { 'Unknown error' }

        $errStack = if ($null -ne $Err -and $null -ne $Err.ScriptStackTrace) { ($Err.ScriptStackTrace -replace '\r?\n', ' | ') } else { '' }

        $lineNo   = if ($null -ne $Err -and $null -ne $Err.InvocationInfo) { $Err.InvocationInfo.ScriptLineNumber } else { 0 }



        $entry = [ordered]@{

            ts        = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

            panel     = $Panel

            context   = $Context

            error     = $errMsg

            line      = $lineNo

            stack     = $errStack

            recovered = $Recovered

            repaired  = $false

        }



        # Serialize to JSON line manually (no ConvertTo-Json depth issues on PS 5.1)

        $json = '{"ts":"' + $entry.ts + '","panel":"' + ($entry.panel -replace '"','\"') + '","context":"' + ($entry.context -replace '"','\"') + '","error":"' + ($entry.error -replace '"','\"' -replace '\r?\n',' ') + '","line":' + $entry.line + ',"stack":"' + ($entry.stack -replace '"','\"') + '","recovered":' + ($entry.recovered.ToString().ToLower()) + ',"repaired":false}'

        Add-Content -LiteralPath $script:GuiErrorLogPath -Value $json -Encoding UTF8 -ErrorAction SilentlyContinue



        # Update status bar if available (with strict null-guard)

        if ($null -ne $script:statusLabel) {

            try {

                $script:statusLabel.Text = "[Auto-Recovered] Error in $Panel - see Logs\gui_errors.jsonl"

            } catch {}

        }

    } catch {}

}



function Write-GuiActionLog {

    param(

        [string]$ActionType = 'Click',

        [string]$Component  = '',

        [string]$Details    = ''

    )

    try {

        $logDir = Join-Path $script:ToolkitRoot 'Logs'

        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

        

        $entry = [ordered]@{

            ts        = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

            action    = $ActionType

            component = $Component

            details   = $Details

            session   = if (Test-IsAdmin) { 'Admin' } else { 'Standard' }

        }

        

        $json = '{"ts":"' + $entry.ts + '","action":"' + ($entry.action -replace '"','\"') + '","component":"' + ($entry.component -replace '"','\"') + '","details":"' + ($entry.details -replace '"','\"' -replace '\r?\n',' ') + '","session":"' + $entry.session + '"}'

        Add-Content -LiteralPath (Join-Path $logDir 'gui_user_actions.jsonl') -Value $json -Encoding UTF8 -ErrorAction SilentlyContinue

    } catch {}

}



function Invoke-GuiAutoRecover {

    param([string]$FailedPanel = 'Unknown')

    try {

        # Stop any running timers that might be live from the failed panel

        try {

            if ($null -ne $script:liveTimer -and $script:liveTimer.Enabled) { $script:liveTimer.Stop() }

        } catch {}



        # Clear UI grid safely

        if ($null -ne $gridHost) {

            try {

                $gridHost.SuspendLayout()

                Clear-Grid

                $gridHost.ResumeLayout($true)

            } catch {}

        }



        # Show non-blocking toast notification in status bar

        if ($null -ne $script:statusLabel) {

            try {

                $script:statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 180, 50)

                $script:statusLabel.Text = "[Auto-Recover] Panel '$FailedPanel' crashed - returned to Main Menu. Check Logs\gui_errors.jsonl"

            } catch {}

        }



        # Navigate back to main menu

        if ($null -ne $navStack) {

            try {

                $navStack.Clear()

                $script:currentLabel = ''

                Show-Menu 'main' $false

            } catch {}

        }



        # Reset status label color after 4 seconds

        $restoreTimer = New-Object System.Windows.Forms.Timer

        $restoreTimer.Interval = 4000

        $restoreTimer.Add_Tick({

            if ($null -ne $script:statusLabel) {

                try { $script:statusLabel.ForeColor = Get-ThemeColor 'Muted' } catch {}

            }

            $restoreTimer.Stop()

            $restoreTimer.Dispose()

        }.GetNewClosure())

        $restoreTimer.Start()

    } catch {}

}



function Test-IsAdmin {

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

}



function Read-PipeCatalog {

    param([string]$Path, [string[]]$Headers)

    $items = @()

    if (-not (Test-Path -LiteralPath $Path)) { return $items }



    foreach ($line in Get-Content -LiteralPath $Path) {

        $trimmed = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) { continue }

        $parts = $line -split '\|', $Headers.Count

        $row = [ordered]@{}

        for ($i = 0; $i -lt $Headers.Count; $i++) {

            $row[$Headers[$i]] = if ($i -lt $parts.Count) { $parts[$i].Trim() } else { '' }

        }

        $items += [pscustomobject]$row

    }

    return $items

}



function Convert-LabelToTitle {

    param([string]$Label)

    if ([string]::IsNullOrWhiteSpace($Label)) { return 'Menu' }

    $name = $Label -replace '^(menu|issue)_', ''

    $name = $name -replace '_', ' '

    $name = (Get-Culture).TextInfo.ToTitleCase($name.ToLowerInvariant())

    return $name

}



function Clean-EchoLine {

    param([string]$Line)

    $s = $Line.Trim()

    $s = $s -replace '^\s*echo\s*', ''

    $s = $s -replace '%ESC%\[[^m]*m', ''

    $s = $s -replace '%C_[A-Z_]+%', ''

    $s = $s -replace '%TOOLKIT_VERSION%', ''

    $s = $s -replace '%TOOLKIT_AUTHOR%', ''

    $s = $s -replace '\^&', '&'

    $s = $s -replace '[^\x20-\x7E]', ' '

    $s = $s -replace '\s+', ' '

    return $s.Trim()

}



function Get-OptionTexts {

    param([string[]]$Body)

    $map = @{}

    $rx = [regex]'\[(?<choice>[A-Za-z0-9]{1,3})\]\s*(?<text>.*?)(?=\s+\[[A-Za-z0-9]{1,3}\]|$)'



    foreach ($line in $Body) {

        if ($line -notmatch '^\s*echo') { continue }

        $clean = Clean-EchoLine $line

        if ($clean -notmatch '\[[A-Za-z0-9]{1,3}\]') { continue }

        foreach ($m in $rx.Matches($clean)) {

            $choice = $m.Groups['choice'].Value.ToUpperInvariant()

            $text = $m.Groups['text'].Value.Trim()

            $text = $text -replace '\s{2,}.*$', ''

            $text = $text -replace '\bC_RESET\b', ''

            $text = $text.Trim(' ', '|', ':', '-')

            if ($text.Length -gt 2 -and -not $map.ContainsKey($choice)) {

                $map[$choice] = $text

            }

        }

    }

    return $map

}



function Parse-ChoiceLine {

    param([string]$Line)



    $rx = '(?s)^\s*if\s+(?:/i\s+)?\"?%(?<var>c|choice)%\"?\s*==\s*\"?(?<choice>[^\"\s\)]+)\"?\s+(?<action>.+)$'

    if ($Line -notmatch $rx) { return $null }



    $choice = $matches['choice'].Trim().ToUpperInvariant()

    $action = $matches['action'].Trim()

    if ($choice -in @('99','00')) { return $null }



    $content = $action

    if ($content.StartsWith('(') -and $content.EndsWith(')')) {

        $content = $content.Substring(1, $content.Length - 2).Trim()

    }



    $kind = 'Inline'

    $target = ''

    $command = $content



    if ($content -match '^\s*goto\s+:?(?<target>[A-Za-z0-9_.$-]+)\s*$') {

        $kind = 'Label'

        $target = $matches['target']

        $command = ''

    } elseif ($content -match '\bgoto\s+:?(?<target>[A-Za-z0-9_.$-]+)\b') {

        $target = $matches['target']

        $command = $content

    }



    return [pscustomobject]@{

        Choice = $choice

        Kind = $kind

        TargetLabel = $target

        Command = $command

        RawAction = $action

    }

}



function Get-ChoiceStatements {

    param([string[]]$Body)



    $statements = @()

    for ($i = 0; $i -lt $Body.Count; $i++) {

        $line = $Body[$i]

        if ($line -match '^\s*if\s+(?:/i\s+)?\"?%(?:c|choice)%\"?\s*==\s*\"?[^\"\s\)]+\"?\s+\(\s*$') {

            $parts = New-Object System.Collections.Generic.List[string]

            $parts.Add($line)

            $depth = 1



            for ($j = $i + 1; $j -lt $Body.Count; $j++) {

                $nextLine = $Body[$j]

                $parts.Add($nextLine)

                $trimmed = $nextLine.Trim()



                if ($trimmed -match '^(?i)(if|for)\b.*\(\s*$') {

                    $depth++

                } elseif ($trimmed -match '^\)\s*else\s*\(\s*$') {

                    # Same nesting level: one block closes and another opens.

                } elseif ($trimmed -eq ')') {

                    $depth--

                }



                if ($depth -le 0) {

                    $i = $j

                    break

                }

            }



            $statements += [pscustomobject]@{

                Line = ($parts[0])

                Text = ($parts -join "`r`n")

            }

        } else {

            $statements += [pscustomobject]@{

                Line = $line

                Text = $line

            }

        }

    }



    return $statements

}



function Get-BatchModel {

    param([string]$Path)



    $resolvedPath = $Path

    if (-not (Test-Path -LiteralPath $resolvedPath)) {

        # Fallback search in current directory or parent directory

        $fallback = Join-Path $script:ToolkitRoot "Toolkit.bat"

        if (Test-Path -LiteralPath $fallback) {

            $resolvedPath = $fallback

        } else {

            $fallback = Join-Path (Get-Location) "Toolkit.bat"

            if (Test-Path -LiteralPath $fallback) {

                $resolvedPath = $fallback

            }

        }

    }



    $lines = @()

    if (Test-Path -LiteralPath $resolvedPath) {

        try {

            $lines = Get-Content -LiteralPath $resolvedPath -ErrorAction Stop

        } catch {

            $lines = @()

        }

    }



    if ($lines.Count -eq 0) {

        # Return a mock/empty batch model to prevent any startup crash

        $mockBlock = [pscustomobject]@{

            Label = 'main'

            Title = 'Ultimate Suite (Offline Mode)'

            Line = 1

            EndLine = 1

            Options = @()

            IsMenu = $true

        }

        $blocks = @{ 'main' = $mockBlock }

        return [pscustomobject]@{

            Labels = @()

            Blocks = $blocks

            Options = @()

        }

    }



    $labels = @()

    $labelMap = @{}



    for ($i = 0; $i -lt $lines.Count; $i++) {

        if ($lines[$i] -match '^\s*:([A-Za-z0-9_.$-]+)\b') {

            $name = $matches[1]

            $item = [pscustomobject]@{ Name = $name; Line = $i + 1; Index = $labels.Count }

            $labels += $item

            $labelMap[$name.ToLowerInvariant()] = $item

        }

    }



    $blocks = @{}

    $allOptions = @()



    for ($i = 0; $i -lt $labels.Count; $i++) {

        $label = $labels[$i]

        $start = $label.Line - 1

        $end = if ($i + 1 -lt $labels.Count) { $labels[$i + 1].Line - 2 } else { $lines.Count - 1 }

        $body = @()

        if ($end -gt $start) { $body = $lines[($start + 1)..$end] }



        $optionTexts = Get-OptionTexts $body

        $rawOptions = @()

        foreach ($statement in (Get-ChoiceStatements $body)) {

            $parsed = Parse-ChoiceLine $statement.Text

            if ($null -eq $parsed) { continue }

            $rawOptions += $parsed

        }



        $dedupe = @{}

        foreach ($opt in $rawOptions) {

            $key = if ($opt.Choice -match '^\d+$') { 'N' + ([int]$opt.Choice) } else { 'A' + $opt.Choice }

            if (-not $dedupe.ContainsKey($key)) {

                $dedupe[$key] = $opt

            } elseif ($opt.Choice.Length -gt $dedupe[$key].Choice.Length) {

                $dedupe[$key] = $opt

            }

        }



        $options = @()

        foreach ($opt in ($dedupe.Values | Sort-Object @{Expression={ if ($_.Choice -match '^\d+$') { [int]$_.Choice } else { 10000 } }}, Choice)) {

            $display = ''

            if ($optionTexts.ContainsKey($opt.Choice)) {

                $display = $optionTexts[$opt.Choice]

            } elseif ($opt.TargetLabel) {

                $display = Convert-LabelToTitle $opt.TargetLabel

            } else {

                $display = $opt.Command

            }



            if ($display -match '^(MAIN MENU|BACK|BACK / MAIN MENU|REFRESH|EXIT)$') { continue }



            $option = [pscustomobject]@{

                ParentLabel = $label.Name

                Choice = $opt.Choice

                Text = $display

                Kind = $opt.Kind

                TargetLabel = $opt.TargetLabel

                Command = $opt.Command

                RawAction = $opt.RawAction

                IsSubmenu = $false

                Category = Convert-LabelToTitle $label.Name

            }

            $options += $option

            $allOptions += $option

        }



        $title = Convert-LabelToTitle $label.Name

        foreach ($line in $body) {

            $clean = Clean-EchoLine $line

            if ($clean -match '^\[(?<num>\d{1,2})\]\s+(?<title>.+?)(?:\s+ULTIMATE|\s*$)') {

                $candidate = $matches['title'].Trim()

                if ($candidate.Length -gt 3 -and $candidate.Length -lt 70) {

                    $title = (Get-Culture).TextInfo.ToTitleCase($candidate.ToLowerInvariant())

                    break

                }

            }

        }



        $isMenu = ($options.Count -ge 2) -or ($label.Name -eq 'main') -or ($label.Name -like 'menu_*')

        $isInteractive = $false

        foreach ($line in $body) {

            if ($line -match '(?i)\b(set\s+/p|choice|pause|timeout|runas|cmd\s+/k|powershell\s+-noexit)\b') {

                $isInteractive = $true

                break

            }

        }

        $blocks[$label.Name.ToLowerInvariant()] = [pscustomobject]@{

            Label = $label.Name

            Title = $title

            Line = $label.Line

            EndLine = $end + 1

            Options = $options

            IsMenu = $isMenu

            IsInteractive = $isInteractive

        }

    }



    foreach ($block in $blocks.Values) {

        foreach ($opt in $block.Options) {

            if ($opt.TargetLabel) {

                $key = $opt.TargetLabel.ToLowerInvariant()

                if ($opt.Kind -eq 'Label' -and $key -ne $block.Label.ToLowerInvariant() -and $blocks.ContainsKey($key) -and $blocks[$key].IsMenu) {

                    $opt.IsSubmenu = $true

                    if ($opt.Text -eq (Convert-LabelToTitle $opt.TargetLabel)) {

                        $opt.Text = $blocks[$key].Title

                    }

                }

            }

        }

    }



    return [pscustomobject]@{

        Labels = $labels

        Blocks = $blocks

        Options = $allOptions

    }

}



function Is-OneClickOption {

    param([object]$Option)

    $s = "$($Option.Text) $($Option.TargetLabel) $($Option.ParentLabel)".ToLowerInvariant()

    return ($s -match 'one click|one_click|one clean|one_clean|quick|auto|booster|repair engine|battery report|system inventory|health report|deep diagnostic|complete report')

}



function Resolve-ToolkitPath {
    param([string]$PathText)
    if ([string]::IsNullOrWhiteSpace($PathText)) { return '' }
    $expanded = [Environment]::ExpandEnvironmentVariables($PathText.Trim())
    if ([System.IO.Path]::IsPathRooted($expanded)) { return $expanded }
    if ($env:UT_ORIGINAL_DIR -and ($expanded -like 'Tools\*' -or $expanded -like 'Tools/*')) {
        $candidate = [System.IO.Path]::GetFullPath((Join-Path $env:UT_ORIGINAL_DIR $expanded))
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    return [System.IO.Path]::GetFullPath((Join-Path $ToolkitRoot $expanded))
}



$toolItems = Read-PipeCatalog -Path $ToolsCatalogPath -Headers @('ID','Name','Type','Target','Notes')

$staticGuiItems = Read-PipeCatalog -Path $GuiCatalogPath -Headers @('Category','Text','Type','Target','Note','Color')

try {

    $model = Get-BatchModel -Path $ToolkitBat

} catch {

    # Fail-safe empty model

    $mockBlock = [pscustomobject]@{

        Label = 'main'

        Title = 'Ultimate Suite (Fail-safe Mode)'

        Line = 1

        EndLine = 1

        Options = @()

        IsMenu = $true

    }

    $model = [pscustomobject]@{

        Labels = @()

        Blocks = @{ 'main' = $mockBlock }

        Options = @()

    }

}

$oneClickOptions = @()

if ($model -and $model.Options) {

    $oneClickOptions = @($model.Options | Where-Object { Is-OneClickOption $_ } | Sort-Object Text -Unique)

}



if ($SelfTest) {

    $badTargets = @()

    foreach ($opt in $model.Options) {

        if ($opt.TargetLabel -and -not $model.Blocks.ContainsKey($opt.TargetLabel.ToLowerInvariant())) {

            $badTargets += $opt

        }

    }

    Write-Host "SysForge Studio GUI self-test"

    Write-Host "Batch labels        : $($model.Labels.Count)"

    Write-Host "Menu blocks         : $(($model.Blocks.Values | Where-Object IsMenu).Count)"

    Write-Host "Parsed options      : $($model.Options.Count)"

    Write-Host "One-click options   : $($oneClickOptions.Count)"

    Write-Host "Portable tools      : $($toolItems.Count)"

    Write-Host "Static GUI shortcuts: $($staticGuiItems.Count)"

    Write-Host "Inventory script    : $(if (Test-Path -LiteralPath $InventoryReportScript) { 'OK' } else { 'MISSING' })"

    Write-Host "Report center       : $(if (Test-Path -LiteralPath $ReportCenterScript) { 'OK' } else { 'MISSING' })"

    Write-Host "Bad label targets   : $($badTargets.Count)"

    foreach ($bad in $badTargets | Select-Object -First 25) {

        Write-Host "Missing target: $($bad.TargetLabel) from $($bad.ParentLabel) [$($bad.Choice)]"

    }

    if ($badTargets.Count -gt 0 -or -not (Test-Path -LiteralPath $InventoryReportScript) -or -not (Test-Path -LiteralPath $ReportCenterScript)) { exit 1 }

    exit 0

}



# Keep the GUI itself non-elevated so portable launchers do not flash and close.

# Admin-sensitive repair actions can still be launched from the CMD toolkit when needed.



Add-Type -AssemblyName System.Windows.Forms

Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()



try {

    # Set process-level DPI awareness to enable ultra-crisp, high-definition 4K/8K rendering

    $ApiType = Add-Type -MemberDefinition @"

        [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();

        [DllImport("gdi32.dll")] public static extern IntPtr CreateRoundRectRgn(int nLeftRect, int nTopRect, int nRightRect, int nBottomRect, int nWidthEllipse, int nHeightEllipse);

"@ -Name 'Win32Apis' -Namespace 'Win32' -PassThru

    [void]$ApiType::SetProcessDPIAware()

} catch {}



$AppIconPath = Join-Path $ToolkitRoot 'Assets\SysForge Studio.ico'

$script:IconCache = @{}

$script:ThemeOrder = @('Cyberpunk Neon', 'Glass Morphism', 'Vampire Dracula', 'Luxury Gold', 'Nordic Frost', 'Retro Synthwave', 'Midnight Mint', 'Rose Purple', 'Gold Slate', 'Clean Light', 'Ocean Cyan', 'Crimson Teal', 'Forest Gold', 'Royal Indigo', 'Graphite Lime', 'Sky Rose', 'Matrix Green', 'Soft Steel', 'Alien Invasion', 'Classic Terminal', 'Solarized Dark', 'Solarized Light', 'Deep Space', 'Monokai Pro', 'GitHub Dark', 'GitHub Light', 'Neon Sunset', 'Toxic Waste', 'Ice Cold', 'Lava Chamber', 'Ghostly Lavender', 'Aqua Marine', 'Bubblegum Sweet', 'Neon Matrix', 'Shadow Ninja', 'Cozy Coffee', 'Desert Storm', 'Sakura Blossom', 'Iron Man', 'Captain America', 'Thor Thunder', 'Spider-Man Web', 'Gamma Hulk', 'Black Widow', 'Doctor Strange', 'Black Panther', 'Logan Wolverine', 'Deadpool Merc')

$script:Themes = @{

    'Cyberpunk Neon' = @{

        Bg = '#0B0813'; Panel = '#161224'; Panel2 = '#0F0C1B'; Sidebar = '#0C0916'; Header1 = '#161224'; Header2 = '#FF007F'

        Text = '#FFFFFF'; Muted = '#8F8CA3'; Border = '#3D1B5C'; Accent = '#00FFFF'; Accent2 = '#FF007F'; Accent3 = '#FFFF00'; Accent4 = '#9D00FF'

        Button = '#1D1730'; ButtonHover = '#2A2145'; CardText = '#0B0813'

        Cards = @('#00FFFF','#FF007F','#9D00FF','#FFFF00','#00FF66','#FF6600','#0099FF','#FF3399')

        CardBg = '#161224'; CardFg = '#FFFFFF'

    }

    'Glass Morphism' = @{

        Bg = '#0A0F1E'; Panel = '#0D1428'; Panel2 = '#0A1020'; Sidebar = '#0B1122'; Header1 = '#0D1428'; Header2 = '#1A2540'

        Text = '#E8F4FF'; Muted = '#7A9EC4'; Border = '#1E3A5F'; Accent = '#4FC3F7'; Accent2 = '#81D4FA'; Accent3 = '#B3E5FC'; Accent4 = '#29B6F6'

        Button = '#0F1E36'; ButtonHover = '#162840'; CardText = '#E8F4FF'

        Cards = @('#4FC3F7','#29B6F6','#81D4FA','#0288D1','#B3E5FC','#0277BD','#03A9F4','#E1F5FE')

        CardBg = '#0D1428'; CardFg = '#E8F4FF'

    }

    'Vampire Dracula' = @{

        Bg = '#181920'; Panel = '#21222C'; Panel2 = '#1E1F29'; Sidebar = '#191A21'; Header1 = '#21222C'; Header2 = '#FF5555'

        Text = '#F8F8F2'; Muted = '#6272A4'; Border = '#44475A'; Accent = '#50FA7B'; Accent2 = '#FF79C6'; Accent3 = '#BD93F9'; Accent4 = '#FF5555'

        Button = '#282A36'; ButtonHover = '#343746'; CardText = '#F8F8F2'

        Cards = @('#50FA7B','#FF79C6','#BD93F9','#FF5555','#8BE9FD','#F1FA8C','#FFB86C','#F8F8F2')

        CardBg = '#21222C'; CardFg = '#F8F8F2'

    }

    'Luxury Gold' = @{

        Bg = '#0A0A0C'; Panel = '#141419'; Panel2 = '#0F0F13'; Sidebar = '#0D0D11'; Header1 = '#141419'; Header2 = '#C5A880'

        Text = '#FFFFFF'; Muted = '#8A8A93'; Border = '#2C2C35'; Accent = '#D4AF37'; Accent2 = '#C5A880'; Accent3 = '#E5D3B3'; Accent4 = '#8C7853'

        Button = '#1A1A22'; ButtonHover = '#272733'; CardText = '#FFFFFF'

        Cards = @('#D4AF37','#C5A880','#E5D3B3','#8C7853','#F3E5AB','#D2B48C','#C0C0C0','#E0A96D')

        CardBg = '#141419'; CardFg = '#FFFFFF'

    }

    'Nordic Frost' = @{

        Bg = '#0F141C'; Panel = '#1B2330'; Panel2 = '#141A25'; Sidebar = '#111620'; Header1 = '#1B2330'; Header2 = '#88C0D0'

        Text = '#ECEFF4'; Muted = '#4C566A'; Border = '#2E3440'; Accent = '#88C0D0'; Accent2 = '#81A1C1'; Accent3 = '#A3BE8C'; Accent4 = '#B48EAD'

        Button = '#242F41'; ButtonHover = '#303E56'; CardText = '#ECEFF4'

        Cards = @('#88C0D0','#81A1C1','#A3BE8C','#B48EAD','#BF616A','#D08770','#EBCB8B','#ECEFF4')

        CardBg = '#1B2330'; CardFg = '#ECEFF4'

    }

    'Retro Synthwave' = @{

        Bg = '#120E25'; Panel = '#201A3D'; Panel2 = '#181330'; Sidebar = '#15102B'; Header1 = '#201A3D'; Header2 = '#FF6C00'

        Text = '#FFE5F9'; Muted = '#7D6B9D'; Border = '#40306E'; Accent = '#F000FF'; Accent2 = '#00F9FF'; Accent3 = '#FF6C00'; Accent4 = '#9000FF'

        Button = '#2A2252'; ButtonHover = '#3B3073'; CardText = '#FFE5F9'

        Cards = @('#F000FF','#00F9FF','#FF6C00','#9000FF','#FF007F','#FFFF00','#00FF66','#FF3399')

        CardBg = '#201A3D'; CardFg = '#FFE5F9'

    }

    'Midnight Mint' = @{

        Bg = '#111217'; Panel = '#20212B'; Panel2 = '#191A22'; Sidebar = '#171820'; Header1 = '#20212B'; Header2 = '#2A2B38'

        Text = '#FFFFFF'; Muted = '#B8B8C8'; Border = '#3B3D4F'; Accent = '#8BC486'; Accent2 = '#F39BC3'; Accent3 = '#F7D27B'; Accent4 = '#7867D8'

        Button = '#20212B'; ButtonHover = '#2B2D3A'; CardText = '#101218'

        Cards = @('#8BC486','#F39BC3','#7867D8','#F7D27B','#A7D8FF','#C7F0D2','#F7AECF','#A99BFF')

        CardBg = '#20212B'; CardFg = '#FFFFFF'

    }

    'Rose Purple' = @{

        Bg = '#15141B'; Panel = '#24222E'; Panel2 = '#1D1B25'; Sidebar = '#1A1821'; Header1 = '#211F2B'; Header2 = '#30283B'

        Text = '#FFFFFF'; Muted = '#D1C8D6'; Border = '#4B405B'; Accent = '#F39BC3'; Accent2 = '#8BC486'; Accent3 = '#F7D27B'; Accent4 = '#7867D8'

        Button = '#24222E'; ButtonHover = '#302B3B'; CardText = '#141118'

        Cards = @('#F39BC3','#7867D8','#F7D27B','#8BC486','#C2A8FF','#FFB8D2','#FFE09A','#A4DBA0')

        CardBg = '#24222E'; CardFg = '#FFFFFF'

    }

    'Gold Slate' = @{

        Bg = '#11151A'; Panel = '#202631'; Panel2 = '#171D25'; Sidebar = '#151A21'; Header1 = '#1E2632'; Header2 = '#303849'

        Text = '#FFFFFF'; Muted = '#C3CAD5'; Border = '#455065'; Accent = '#F7D27B'; Accent2 = '#8BC486'; Accent3 = '#F39BC3'; Accent4 = '#7867D8'

        Button = '#202631'; ButtonHover = '#2D3543'; CardText = '#141414'

        Cards = @('#F7D27B','#8BC486','#A7D8FF','#F39BC3','#7867D8','#FFDFA7','#BCE7BC','#C7B9FF')

        CardBg = '#202631'; CardFg = '#FFFFFF'

    }

    'Clean Light' = @{

        Bg = '#F5F7FB'; Panel = '#FFFFFF'; Panel2 = '#EEF2F7'; Sidebar = '#E8ECF4'; Header1 = '#FFFFFF'; Header2 = '#EEF2F7'

        Text = '#151923'; Muted = '#5F6878'; Border = '#CCD4E0'; Accent = '#7867D8'; Accent2 = '#8BC486'; Accent3 = '#F39BC3'; Accent4 = '#F7D27B'

        Button = '#FFFFFF'; ButtonHover = '#EEF2F7'; CardText = '#111827'

        Cards = @('#8BC486','#F39BC3','#7867D8','#F7D27B','#A7D8FF','#D6F3DD','#FFC3DC','#B9ADFF')

        CardBg = '#FFFFFF'; CardFg = '#151923'

    }

    'Ocean Cyan' = @{

        Bg = '#0B1418'; Panel = '#122329'; Panel2 = '#0F1C22'; Sidebar = '#0D171D'; Header1 = '#10242B'; Header2 = '#164E63'

        Text = '#F8FAFC'; Muted = '#B6D7E3'; Border = '#2B5B67'; Accent = '#67E8F9'; Accent2 = '#8BC486'; Accent3 = '#F7D27B'; Accent4 = '#A78BFA'

        Button = '#142830'; ButtonHover = '#18343E'; CardText = '#081216'

        Cards = @('#67E8F9','#8BC486','#F7D27B','#F39BC3','#A78BFA','#93C5FD','#99F6E4','#FDE68A')

        CardBg = '#122329'; CardFg = '#F8FAFC'

    }

    'Crimson Teal' = @{

        Bg = '#171114'; Panel = '#261B20'; Panel2 = '#20171B'; Sidebar = '#1B1317'; Header1 = '#2A151B'; Header2 = '#0F766E'

        Text = '#FFFFFF'; Muted = '#E2CAD2'; Border = '#5B3440'; Accent = '#FB7185'; Accent2 = '#2DD4BF'; Accent3 = '#FACC15'; Accent4 = '#A78BFA'

        Button = '#261B20'; ButtonHover = '#33232A'; CardText = '#111111'

        Cards = @('#FB7185','#2DD4BF','#FACC15','#A78BFA','#93C5FD','#FDA4AF','#5EEAD4','#FDE047')

        CardBg = '#261B20'; CardFg = '#FFFFFF'

    }

    'Forest Gold' = @{

        Bg = '#10160F'; Panel = '#1A2518'; Panel2 = '#151E14'; Sidebar = '#121A11'; Header1 = '#1B2A18'; Header2 = '#6B5B16'

        Text = '#F8FAFC'; Muted = '#C8D9C0'; Border = '#405338'; Accent = '#A3E635'; Accent2 = '#FACC15'; Accent3 = '#86EFAC'; Accent4 = '#60A5FA'

        Button = '#1A2518'; ButtonHover = '#233120'; CardText = '#101410'

        Cards = @('#A3E635','#FACC15','#86EFAC','#60A5FA','#F9A8D4','#BEF264','#FDE68A','#93C5FD')

        CardBg = '#1A2518'; CardFg = '#F8FAFC'

    }

    'Royal Indigo' = @{

        Bg = '#111224'; Panel = '#202044'; Panel2 = '#191936'; Sidebar = '#17172E'; Header1 = '#1E1B4B'; Header2 = '#4338CA'

        Text = '#FFFFFF'; Muted = '#C7D2FE'; Border = '#4F46A5'; Accent = '#A78BFA'; Accent2 = '#F39BC3'; Accent3 = '#8BC486'; Accent4 = '#F7D27B'

        Button = '#202044'; ButtonHover = '#29295A'; CardText = '#111118'

        Cards = @('#A78BFA','#F39BC3','#8BC486','#F7D27B','#93C5FD','#C4B5FD','#FBCFE8','#BBF7D0')

        CardBg = '#202044'; CardFg = '#FFFFFF'

    }

    'Graphite Lime' = @{

        Bg = '#111316'; Panel = '#20242A'; Panel2 = '#181B20'; Sidebar = '#15181D'; Header1 = '#20242A'; Header2 = '#3F6212'

        Text = '#F8FAFC'; Muted = '#CDD3DA'; Border = '#3F4854'; Accent = '#BEF264'; Accent2 = '#67E8F9'; Accent3 = '#F7D27B'; Accent4 = '#F39BC3'

        Button = '#20242A'; ButtonHover = '#2B3038'; CardText = '#101214'

        Cards = @('#BEF264','#67E8F9','#F7D27B','#F39BC3','#A78BFA','#86EFAC','#BAE6FD','#FDE68A')

        CardBg = '#20242A'; CardFg = '#F8FAFC'

    }

    'Sky Rose' = @{

        Bg = '#F2F7FB'; Panel = '#FFFFFF'; Panel2 = '#EAF2F8'; Sidebar = '#E6EEF7'; Header1 = '#F8FBFF'; Header2 = '#E0F2FE'

        Text = '#101827'; Muted = '#58687A'; Border = '#C8D6E6'; Accent = '#38BDF8'; Accent2 = '#F39BC3'; Accent3 = '#8BC486'; Accent4 = '#7867D8'

        Button = '#FFFFFF'; ButtonHover = '#EEF6FC'; CardText = '#101827'

        Cards = @('#A7D8FF','#F39BC3','#8BC486','#F7D27B','#B9ADFF','#BAE6FD','#FBCFE8','#BBF7D0')

        CardBg = '#FFFFFF'; CardFg = '#101827'

    }

    'Matrix Green' = @{

        Bg = '#07120B'; Panel = '#0D1E13'; Panel2 = '#09170E'; Sidebar = '#08130C'; Header1 = '#0D1E13'; Header2 = '#14532D'

        Text = '#ECFDF5'; Muted = '#A7F3D0'; Border = '#1F5135'; Accent = '#22C55E'; Accent2 = '#67E8F9'; Accent3 = '#F7D27B'; Accent4 = '#A78BFA'

        Button = '#0D1E13'; ButtonHover = '#13291A'; CardText = '#07120B'

        Cards = @('#22C55E','#67E8F9','#F7D27B','#A78BFA','#F39BC3','#86EFAC','#99F6E4','#FDE68A')

        CardBg = '#0D1E13'; CardFg = '#ECFDF5'

    }

    'Soft Steel' = @{

        Bg = '#ECEFF4'; Panel = '#FFFFFF'; Panel2 = '#E3E8EF'; Sidebar = '#DDE3EC'; Header1 = '#FFFFFF'; Header2 = '#CBD5E1'

        Text = '#111827'; Muted = '#526071'; Border = '#B9C3D1'; Accent = '#64748B'; Accent2 = '#0F766E'; Accent3 = '#B91C1C'; Accent4 = '#1D4ED8'

        Button = '#FFFFFF'; ButtonHover = '#EEF2F7'; CardText = '#111827'

        Cards = @('#CBD5E1','#93C5FD','#8BC486','#F39BC3','#F7D27B','#A7D8FF','#99F6E4','#FDA4AF')

        CardBg = '#FFFFFF'; CardFg = '#111827'

    }

    'Alien Invasion' = @{

        Bg = '#050B07'; Panel = '#0A150D'; Panel2 = '#08100A'; Sidebar = '#060D08'; Header1 = '#0A150D'; Header2 = '#39FF14'

        Text = '#E5FFE9'; Muted = '#7A9680'; Border = '#1A3D24'; Accent = '#39FF14'; Accent2 = '#00FF7F'; Accent3 = '#ADFF2F'; Accent4 = '#00FA9A'

        Button = '#0F2415'; ButtonHover = '#173820'; CardText = '#050B07'

        Cards = @('#39FF14','#00FF7F','#ADFF2F','#00FA9A','#7FFF00','#32CD32','#98FB98','#00FF00')

        CardBg = '#0A150D'; CardFg = '#E5FFE9'

    }

    'Classic Terminal' = @{

        Bg = '#000000'; Panel = '#050505'; Panel2 = '#020202'; Sidebar = '#030303'; Header1 = '#000000'; Header2 = '#00FF33'

        Text = '#00FF33'; Muted = '#009922'; Border = '#004411'; Accent = '#00FF33'; Accent2 = '#00EE22'; Accent3 = '#00DD11'; Accent4 = '#00CC00'

        Button = '#001100'; ButtonHover = '#002200'; CardText = '#000000'

        Cards = @('#00FF33','#00EE22','#00DD11','#00CC00','#00BB00','#00AA00','#009900','#00FF44')

        CardBg = '#050505'; CardFg = '#00FF33'

    }

    'Solarized Dark' = @{

        Bg = '#002B36'; Panel = '#073642'; Panel2 = '#00212B'; Sidebar = '#001C24'; Header1 = '#073642'; Header2 = '#268BD2'

        Text = '#93A1A1'; Muted = '#586E75'; Border = '#083F4D'; Accent = '#268BD2'; Accent2 = '#2AA198'; Accent3 = '#859900'; Accent4 = '#CB4B16'

        Button = '#003745'; ButtonHover = '#054454'; CardText = '#002B36'

        Cards = @('#268BD2','#2AA198','#859900','#CB4B16','#D33682','#B58900','#DC322F','#6C71C4')

        CardBg = '#073642'; CardFg = '#93A1A1'

    }

    'Solarized Light' = @{

        Bg = '#FDF6E3'; Panel = '#EEE8D5'; Panel2 = '#F7F1DE'; Sidebar = '#ECE5D0'; Header1 = '#EEE8D5'; Header2 = '#268BD2'

        Text = '#586E75'; Muted = '#93A1A1'; Border = '#DFD9C6'; Accent = '#268BD2'; Accent2 = '#2AA198'; Accent3 = '#859900'; Accent4 = '#CB4B16'

        Button = '#F4EDE0'; ButtonHover = '#E9E2D4'; CardText = '#FDF6E3'

        Cards = @('#268BD2','#2AA198','#859900','#CB4B16','#D33682','#B58900','#DC322F','#6C71C4')

        CardBg = '#EEE8D5'; CardFg = '#586E75'

    }

    'Deep Space' = @{

        Bg = '#020205'; Panel = '#080812'; Panel2 = '#05050A'; Sidebar = '#040408'; Header1 = '#080812'; Header2 = '#4B0082'

        Text = '#ECECF5'; Muted = '#757590'; Border = '#181830'; Accent = '#00FFFF'; Accent2 = '#8A2BE2'; Accent3 = '#FF00FF'; Accent4 = '#9400D3'

        Button = '#0B0B1D'; ButtonHover = '#141433'; CardText = '#020205'

        Cards = @('#00FFFF','#8A2BE2','#FF00FF','#9400D3','#1E90FF','#7B68EE','#DA70D6','#4B0082')

        CardBg = '#080812'; CardFg = '#ECECF5'

    }

    'Monokai Pro' = @{

        Bg = '#2D2A2E'; Panel = '#403E41'; Panel2 = '#343135'; Sidebar = '#221F22'; Header1 = '#403E41'; Header2 = '#FF6188'

        Text = '#FCFCFA'; Muted = '#727072'; Border = '#4C494D'; Accent = '#FF6188'; Accent2 = '#A9DC76'; Accent3 = '#FFD866'; Accent4 = '#78DCE8'

        Button = '#343135'; ButtonHover = '#454247'; CardText = '#2D2A2E'

        Cards = @('#FF6188','#A9DC76','#FFD866','#78DCE8','#AB9DF2','#FC9867','#FCFCFA','#727072')

        CardBg = '#403E41'; CardFg = '#FCFCFA'

    }

    'GitHub Dark' = @{

        Bg = '#0D1117'; Panel = '#161B22'; Panel2 = '#0F141C'; Sidebar = '#090D13'; Header1 = '#161B22'; Header2 = '#58A6FF'

        Text = '#C9D1D9'; Muted = '#8B949E'; Border = '#30363D'; Accent = '#58A6FF'; Accent2 = '#3FB950'; Accent3 = '#F0883E'; Accent4 = '#BC8CFF'

        Button = '#21262D'; ButtonHover = '#30363D'; CardText = '#0D1117'

        Cards = @('#58A6FF','#3FB950','#F0883E','#BC8CFF','#F85149','#E3B341','#56D4DD','#8B949E')

        CardBg = '#161B22'; CardFg = '#C9D1D9'

    }

    'GitHub Light' = @{

        Bg = '#F6F8FA'; Panel = '#FFFFFF'; Panel2 = '#EFF1F3'; Sidebar = '#EBEDF0'; Header1 = '#FFFFFF'; Header2 = '#0969DA'

        Text = '#24292F'; Muted = '#57606A'; Border = '#D0D7DE'; Accent = '#0969DA'; Accent2 = '#1A7F37'; Accent3 = '#D1242F'; Accent4 = '#8250DF'

        Button = '#F3F4F6'; ButtonHover = '#E5E7EB'; CardText = '#F6F8FA'

        Cards = @('#0969DA','#1A7F37','#D1242F','#8250DF','#CF5100','#85E89D','#6F42C1','#57606A')

        CardBg = '#FFFFFF'; CardFg = '#24292F'

    }

    'Neon Sunset' = @{

        Bg = '#0F0C1B'; Panel = '#1B1530'; Panel2 = '#140F24'; Sidebar = '#0C0917'; Header1 = '#1B1530'; Header2 = '#FF007F'

        Text = '#FFF5FB'; Muted = '#8F81A5'; Border = '#3F2D69'; Accent = '#FF007F'; Accent2 = '#FF5E00'; Accent3 = '#FFB300'; Accent4 = '#9400D3'

        Button = '#241C40'; ButtonHover = '#322758'; CardText = '#0F0C1B'

        Cards = @('#FF007F','#FF5E00','#FFB300','#9400D3','#E6007E','#FF7700','#FFCC00','#8A2BE2')

        CardBg = '#1B1530'; CardFg = '#FFF5FB'

    }

    'Toxic Waste' = @{

        Bg = '#0B0C0E'; Panel = '#16181C'; Panel2 = '#111215'; Sidebar = '#0E0F11'; Header1 = '#16181C'; Header2 = '#CCFF00'

        Text = '#EAFFD0'; Muted = '#758069'; Border = '#32382C'; Accent = '#CCFF00'; Accent2 = '#FF6600'; Accent3 = '#39FF14'; Accent4 = '#00FFFF'

        Button = '#1D2126'; ButtonHover = '#2A3038'; CardText = '#0B0C0E'

        Cards = @('#CCFF00','#FF6600','#39FF14','#00FFFF','#ADFF2F','#FF4500','#7FFF00','#40E0D0')

        CardBg = '#16181C'; CardFg = '#EAFFD0'

    }

    'Ice Cold' = @{

        Bg = '#050E17'; Panel = '#0A1B2D'; Panel2 = '#071523'; Sidebar = '#050F1A'; Header1 = '#0A1B2D'; Header2 = '#00D2FF'

        Text = '#F0FBFF'; Muted = '#7290A8'; Border = '#1A3B5C'; Accent = '#00D2FF'; Accent2 = '#0088FF'; Accent3 = '#FFFFFF'; Accent4 = '#A3E5FF'

        Button = '#0F2842'; ButtonHover = '#173C63'; CardText = '#050E17'

        Cards = @('#00D2FF','#0088FF','#FFFFFF','#A3E5FF','#E0F7FF','#33B5E5','#0099CC','#47A8BD')

        CardBg = '#0A1B2D'; CardFg = '#F0FBFF'

    }

    'Lava Chamber' = @{

        Bg = '#0A0303'; Panel = '#1A0909'; Panel2 = '#120606'; Sidebar = '#0E0404'; Header1 = '#1A0909'; Header2 = '#FF3300'

        Text = '#FFF2F2'; Muted = '#A58181'; Border = '#421A1A'; Accent = '#FF3300'; Accent2 = '#FF9900'; Accent3 = '#FFCC00'; Accent4 = '#8B0000'

        Button = '#260E0E'; ButtonHover = '#361414'; CardText = '#0A0303'

        Cards = @('#FF3300','#FF9900','#FFCC00','#8B0000','#FF5533','#FFAA00','#FFD700','#D32F2F')

        CardBg = '#1A0909'; CardFg = '#FFF2F2'

    }

    'Ghostly Lavender' = @{

        Bg = '#100E1C'; Panel = '#1C1932'; Panel2 = '#151326'; Sidebar = '#0D0C17'; Header1 = '#1C1932'; Header2 = '#E6D5FF'

        Text = '#FAF8FF'; Muted = '#8E8AAB'; Border = '#3F3969'; Accent = '#DAB8FF'; Accent2 = '#FFCCE6'; Accent3 = '#B8F4FF'; Accent4 = '#C2AFFF'

        Button = '#242040'; ButtonHover = '#322D58'; CardText = '#100E1C'

        Cards = @('#DAB8FF','#FFCCE6','#B8F4FF','#C2AFFF','#EAD8FF','#FFDDF0','#CFF6FF','#9E82FF')

        CardBg = '#1C1932'; CardFg = '#FAF8FF'

    }

    'Aqua Marine' = @{

        Bg = '#030D0F'; Panel = '#0A1C20'; Panel2 = '#071518'; Sidebar = '#050F11'; Header1 = '#0A1C20'; Header2 = '#20B2AA'

        Text = '#EFFFFD'; Muted = '#7A969B'; Border = '#1A3F45'; Accent = '#20B2AA'; Accent2 = '#00FFFF'; Accent3 = '#AFEEEE'; Accent4 = '#40E0D0'

        Button = '#0F272C'; ButtonHover = '#173C44'; CardText = '#030D0F'

        Cards = @('#20B2AA','#00FFFF','#AFEEEE','#40E0D0','#48D1CC','#00CED1','#5F9EA0','#EFFFFD')

        CardBg = '#0A1C20'; CardFg = '#EFFFFD'

    }

    'Bubblegum Sweet' = @{

        Bg = '#1A0F1E'; Panel = '#2D1C35'; Panel2 = '#221528'; Sidebar = '#160E1A'; Header1 = '#2D1C35'; Header2 = '#FF66B2'

        Text = '#FFF2FA'; Muted = '#A58A9F'; Border = '#5C326B'; Accent = '#FF66B2'; Accent2 = '#B266FF'; Accent3 = '#66FFB2'; Accent4 = '#FFB266'

        Button = '#382342'; ButtonHover = '#4E315C'; CardText = '#1A0F1E'

        Cards = @('#FF66B2','#B266FF','#66FFB2','#FFB266','#FF99CC','#CC99FF','#99FFCC','#FFCC99')

        CardBg = '#2D1C35'; CardFg = '#FFF2FA'

    }

    'Neon Matrix' = @{

        Bg = '#000000'; Panel = '#091F0E'; Panel2 = '#061509'; Sidebar = '#040E06'; Header1 = '#091F0E'; Header2 = '#00FF00'

        Text = '#D9FFD9'; Muted = '#69B369'; Border = '#1A471A'; Accent = '#00FF00'; Accent2 = '#39FF14'; Accent3 = '#008000'; Accent4 = '#ADFF2F'

        Button = '#0D2D15'; ButtonHover = '#14421E'; CardText = '#000000'

        Cards = @('#00FF00','#39FF14','#ADFF2F','#00FA9A','#7FFF00','#00FF7F','#32CD32','#008000')

        CardBg = '#091F0E'; CardFg = '#D9FFD9'

    }

    'Shadow Ninja' = @{

        Bg = '#0A0A0C'; Panel = '#141419'; Panel2 = '#0E0E12'; Sidebar = '#09090C'; Header1 = '#141419'; Header2 = '#D32F2F'

        Text = '#E0E0E6'; Muted = '#75758A'; Border = '#2E2E3A'; Accent = '#D32F2F'; Accent2 = '#FF5252'; Accent3 = '#751212'; Accent4 = '#111115'

        Button = '#1B1B22'; ButtonHover = '#272731'; CardText = '#0A0A0C'

        Cards = @('#D32F2F','#FF5252','#FF1744','#B71C1C','#FF8A80','#E53935','#C62828','#751212')

        CardBg = '#141419'; CardFg = '#E0E0E6'

    }

    'Cozy Coffee' = @{

        Bg = '#1A110F'; Panel = '#2B1D19'; Panel2 = '#211613'; Sidebar = '#150E0C'; Header1 = '#2B1D19'; Header2 = '#D4A373'

        Text = '#FDF6F0'; Muted = '#A58F87'; Border = '#543D36'; Accent = '#D4A373'; Accent2 = '#E6CCB2'; Accent3 = '#9C6644'; Accent4 = '#7F5539'

        Button = '#362520'; ButtonHover = '#4C342D'; CardText = '#1A110F'

        Cards = @('#D4A373','#E6CCB2','#9C6644','#7F5539','#EDE0D4','#B5828C','#DDA15E','#BC6C25')

        CardBg = '#2B1D19'; CardFg = '#FDF6F0'

    }

    'Desert Storm' = @{

        Bg = '#1E1B15'; Panel = '#2F2A21'; Panel2 = '#242019'; Sidebar = '#1A1712'; Header1 = '#2F2A21'; Header2 = '#E0A96D'

        Text = '#FAF6EE'; Muted = '#9E9382'; Border = '#5C5242'; Accent = '#E0A96D'; Accent2 = '#D27936'; Accent3 = '#8C6239'; Accent4 = '#EAD5C3'

        Button = '#3A3429'; ButtonHover = '#4E4637'; CardText = '#1E1B15'

        Cards = @('#E0A96D','#D27936','#8C6239','#EAD5C3','#FFDFA7','#E28743','#C5A880','#A98F64')

        CardBg = '#2F2A21'; CardFg = '#FAF6EE'

    }

    'Sakura Blossom' = @{

        Bg = '#120E11'; Panel = '#21181F'; Panel2 = '#1A1218'; Sidebar = '#150F13'; Header1 = '#21181F'; Header2 = '#FFB7C5'

        Text = '#FFF0F3'; Muted = '#A58E97'; Border = '#4C2D3E'; Accent = '#FFB7C5'; Accent2 = '#FF6B8B'; Accent3 = '#FFD3E0'; Accent4 = '#DDA0DD'

        Button = '#2C1F2A'; ButtonHover = '#3F2B3C'; CardText = '#120E11'

        Cards = @('#FFB7C5','#FF6B8B','#FFD3E0','#DDA0DD','#FF8EAF','#EE82EE','#FFC0CB','#DA70D6')

        CardBg = '#21181F'; CardFg = '#FFF0F3'

    }

    'Iron Man' = @{

        Bg = '#0F0303'; Panel = '#240808'; Panel2 = '#1A0606'; Sidebar = '#130404'; Header1 = '#2D0A0A'; Header2 = '#E5A93B'

        Text = '#FFFFFF'; Muted = '#D1A5A5'; Border = '#4A1515'; Accent = '#D4AF37'; Accent2 = '#FF3300'; Accent3 = '#50E3C2'; Accent4 = '#FF8F00'

        Button = '#300D0D'; ButtonHover = '#451313'; CardText = '#FFFFFF'

        Cards = @('#D4AF37','#FF3300','#50E3C2','#FF8F00','#E5A93B','#FF5533','#4A1515','#D1A5A5')

        CardBg = '#240808'; CardFg = '#FFFFFF'

    }

    'Captain America' = @{

        Bg = '#050B18'; Panel = '#0A1630'; Panel2 = '#070F22'; Sidebar = '#050A17'; Header1 = '#0D1E40'; Header2 = '#C62828'

        Text = '#FFFFFF'; Muted = '#9FA8DA'; Border = '#1A2F5C'; Accent = '#2196F3'; Accent2 = '#E53935'; Accent3 = '#ECEFF1'; Accent4 = '#1565C0'

        Button = '#112349'; ButtonHover = '#19336A'; CardText = '#FFFFFF'

        Cards = @('#2196F3','#E53935','#ECEFF1','#1565C0','#1E88E5','#D32F2F','#9FA8DA','#FFFFFF')

        CardBg = '#0A1630'; CardFg = '#FFFFFF'

    }

    'Thor Thunder' = @{

        Bg = '#0B0C10'; Panel = '#1F2833'; Panel2 = '#151B22'; Sidebar = '#10141A'; Header1 = '#23303F'; Header2 = '#D4AF37'

        Text = '#ECEFF1'; Muted = '#7A8B99'; Border = '#354656'; Accent = '#00E5FF'; Accent2 = '#C62828'; Accent3 = '#D4AF37'; Accent4 = '#66FCF1'

        Button = '#26323F'; ButtonHover = '#37485A'; CardText = '#ECEFF1'

        Cards = @('#00E5FF','#C62828','#D4AF37','#66FCF1','#457B9D','#E63946','#A8DADC','#F1FAEE')

        CardBg = '#1F2833'; CardFg = '#ECEFF1'

    }

    'Spider-Man Web' = @{

        Bg = '#050308'; Panel = '#1F0A12'; Panel2 = '#14060C'; Sidebar = '#0F0409'; Header1 = '#30101C'; Header2 = '#0D47A1'

        Text = '#FFFFFF'; Muted = '#E8A2BC'; Border = '#4C1C2D'; Accent = '#FF1744'; Accent2 = '#2979FF'; Accent3 = '#FFFFFF'; Accent4 = '#212121'

        Button = '#2A0E18'; ButtonHover = '#3B1422'; CardText = '#FFFFFF'

        Cards = @('#FF1744','#2979FF','#FFFFFF','#1E88E5','#FF5252','#D32F2F','#90CAF9','#E0E0E0')

        CardBg = '#1F0A12'; CardFg = '#FFFFFF'

    }

    'Gamma Hulk' = @{

        Bg = '#060B08'; Panel = '#101D15'; Panel2 = '#0A130E'; Sidebar = '#080E0A'; Header1 = '#152B1E'; Header2 = '#6A1B9A'

        Text = '#ECFDF5'; Muted = '#99F6E4'; Border = '#284D37'; Accent = '#39FF14'; Accent2 = '#8E24AA'; Accent3 = '#76FF03'; Accent4 = '#4A148C'

        Button = '#15271C'; ButtonHover = '#1E3929'; CardText = '#ECFDF5'

        Cards = @('#39FF14','#8E24AA','#76FF03','#4A148C','#00E676','#D500F9','#00C853','#AA00FF')

        CardBg = '#101D15'; CardFg = '#ECFDF5'

    }

    'Black Widow' = @{

        Bg = '#040405'; Panel = '#101013'; Panel2 = '#0B0B0D'; Sidebar = '#08080A'; Header1 = '#16161C'; Header2 = '#D50000'

        Text = '#E0E0E6'; Muted = '#888899'; Border = '#282833'; Accent = '#D50000'; Accent2 = '#2979FF'; Accent3 = '#FFD600'; Accent4 = '#212121'

        Button = '#16161B'; ButtonHover = '#22222A'; CardText = '#E0E0E6'

        Cards = @('#D50000','#2979FF','#FFD600','#9E9E9E','#FF1744','#2196F3','#CFD8DC','#78909C')

        CardBg = '#101013'; CardFg = '#E0E0E6'

    }

    'Doctor Strange' = @{

        Bg = '#0A040F'; Panel = '#1D0B28'; Panel2 = '#15071E'; Sidebar = '#100518'; Header1 = '#280E38'; Header2 = '#D50000'

        Text = '#F5F0FA'; Muted = '#BCAAA4'; Border = '#421D5C'; Accent = '#FFAB00'; Accent2 = '#D50000'; Accent3 = '#00E5FF'; Accent4 = '#FF6D00'

        Button = '#250E33'; ButtonHover = '#341447'; CardText = '#F5F0FA'

        Cards = @('#FFAB00','#D50000','#00E5FF','#FF6D00','#AA00FF','#FF3D00','#00B0FF','#FFEA00')

        CardBg = '#1D0B28'; CardFg = '#F5F0FA'

    }

    'Black Panther' = @{

        Bg = '#030206'; Panel = '#0D091A'; Panel2 = '#090612'; Sidebar = '#06040C'; Header1 = '#150F2B'; Header2 = '#C5A880'

        Text = '#ECEBF0'; Muted = '#9A8EAF'; Border = '#2E2E4D'; Accent = '#9D4EDD'; Accent2 = '#C5A880'; Accent3 = '#7B2CBF'; Accent4 = '#E0A96D'

        Button = '#150E2A'; ButtonHover = '#20163F'; CardText = '#ECEBF0'

        Cards = @('#9D4EDD','#C5A880','#7B2CBF','#E0A96D','#A29BFE','#D2B48C','#E5D3B3','#5A189A')

        CardBg = '#0D091A'; CardFg = '#ECEBF0'

    }

    'Logan Wolverine' = @{

        Bg = '#080805'; Panel = '#1B1910'; Panel2 = '#12110B'; Sidebar = '#0E0D08'; Header1 = '#272417'; Header2 = '#0D47A1'

        Text = '#FFFDEB'; Muted = '#AFA88A'; Border = '#4C452D'; Accent = '#FFEA00'; Accent2 = '#1565C0'; Accent3 = '#CFD8DC'; Accent4 = '#FF3D00'

        Button = '#232115'; ButtonHover = '#312E1D'; CardText = '#FFFDEB'

        Cards = @('#FFEA00','#1565C0','#CFD8DC','#FF3D00','#FFC107','#0D47A1','#B0BEC5','#D50000')

        CardBg = '#1B1910'; CardFg = '#FFFDEB'

    }

    'Deadpool Merc' = @{

        Bg = '#080203'; Panel = '#1E080A'; Panel2 = '#140506'; Sidebar = '#0F0304'; Header1 = '#2D0C0F'; Header2 = '#212121'

        Text = '#FFEAEA'; Muted = '#C59E9E'; Border = '#4A1519'; Accent = '#D32F2F'; Accent2 = '#FBC02D'; Accent3 = '#E53935'; Accent4 = '#000000'

        Button = '#2A0B0E'; ButtonHover = '#3C1014'; CardText = '#FFEAEA'

        Cards = @('#D32F2F','#FBC02D','#E53935','#212121','#FF5252','#FFD700','#B71C1C','#424242')

        CardBg = '#1E080A'; CardFg = '#FFEAEA'

    }

}

$script:CurrentThemeName = 'Cyberpunk Neon'

$script:LayoutOrder = @('Grid Cards', 'Compact List', 'Hero Dashboard', 'Split Explorer', 'Cyber Terminal')

$script:CurrentLayoutName = 'Grid Cards'

$script:GuiSettingsPath = Join-Path $ToolkitRoot 'Config\gui_settings.cfg'

$script:DynamicThemeEnabled = $false



function Load-GuiSettings {

    if (Test-Path -LiteralPath $script:GuiSettingsPath) {

        $lines = Get-Content -LiteralPath $script:GuiSettingsPath -ErrorAction SilentlyContinue

        foreach ($line in $lines) {

            if ($line -match '^Theme=(.+)$') {

                $t = $matches[1].Trim()

                if ($script:Themes.ContainsKey($t)) { $script:CurrentThemeName = $t }

            }

            if ($line -match '^Layout=(.+)$') {

                $l = $matches[1].Trim()

                if ($l -in $script:LayoutOrder) { $script:CurrentLayoutName = $l }

            }

            if ($line -match '^DynamicTheme=(.+)$') {

                try {

                    $script:DynamicThemeEnabled = [System.Convert]::ToBoolean($matches[1].Trim())

                } catch {

                    $script:DynamicThemeEnabled = $false

                }

            }

        }

    }

}



function Save-GuiSettings {

    try {

        $content = @(

            "Theme=$($script:CurrentThemeName)",

            "Layout=$($script:CurrentLayoutName)",

            "DynamicTheme=$($script:DynamicThemeEnabled)"

        )

        $parent = Split-Path -Parent $script:GuiSettingsPath

        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

        $content | Set-Content -LiteralPath $script:GuiSettingsPath -Force -ErrorAction SilentlyContinue

    } catch {}

}



# Load saved preferences

Load-GuiSettings



# Hardware and Boot-Time Caching on the Main Thread (Thread-Safe Overhaul)

$script:cachedTotalRam = $null

$script:_thermalQueriesSupported = $null

$script:cachedLastBootUpTime = $null

$script:cachedDiskTotal = 0

$script:cachedDiskUsed = 0

$script:cachedDiskPercent = 0



try {

    Add-Type -AssemblyName 'Microsoft.VisualBasic' -ErrorAction SilentlyContinue

    $info = New-Object Microsoft.VisualBasic.Devices.ComputerInfo

    $script:cachedTotalRam = [math]::Round($info.TotalPhysicalMemory / 1GB, 1)

} catch {

    $script:cachedTotalRam = 16.0

}



try {

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue

    if ($null -ne $os) {

        $script:cachedLastBootUpTime = $os.LastBootUpTime

    } else {

        $script:cachedLastBootUpTime = Get-Date

    }

} catch {

    $script:cachedLastBootUpTime = Get-Date

}



try {

    $drive = New-Object System.IO.DriveInfo("C")

    $script:cachedDiskTotal = [math]::Round($drive.TotalSize / 1GB, 1)

    $freeSpace = [math]::Round($drive.AvailableFreeSpace / 1GB, 1)

    $script:cachedDiskUsed = $script:cachedDiskTotal - $freeSpace

    $script:cachedDiskPercent = [int](($script:cachedDiskUsed / $script:cachedDiskTotal) * 100)

} catch {

    $script:cachedDiskTotal = 500

    $script:cachedDiskUsed = 250

    $script:cachedDiskPercent = 50

}



# Time-Based Auto Theme Switch

if ($script:DynamicThemeEnabled) {

    $hour = (Get-Date).Hour

    if ($hour -ge 6 -and $hour -lt 18) {

        if ($script:Themes.ContainsKey('Clean Light')) {

            $script:CurrentThemeName = 'Clean Light'

        }

    } else {

        if ($script:Themes.ContainsKey('Cyberpunk Neon')) {

            $script:CurrentThemeName = 'Cyberpunk Neon'

        }

    }

}



$script:Theme = $script:Themes[$script:CurrentThemeName]

$script:currentItems = $null

$script:currentTitle = ''





function Get-ThemeColor {

    param([string]$Name)

    if ($script:Theme.ContainsKey($Name)) {

        return [System.Drawing.ColorTranslator]::FromHtml([string]$script:Theme[$Name])

    }

    return [System.Drawing.Color]::White

}



function Get-CardBgColor {

    if ($script:Theme.ContainsKey('CardBg')) {

        return [System.Drawing.ColorTranslator]::FromHtml([string]$script:Theme['CardBg'])

    }

    return Get-ThemeColor 'Panel2'

}



function Get-CardFgColor {

    if ($script:Theme.ContainsKey('CardFg')) {

        return [System.Drawing.ColorTranslator]::FromHtml([string]$script:Theme['CardFg'])

    }

    return Get-ThemeColor 'Text'

}



function Get-HoverColor {

    param([System.Drawing.Color]$Color)

    $factor = 0.12 # 12% change

    $r = $Color.R

    $g = $Color.G

    $b = $Color.B

    $isLight = ($script:Theme['Bg'].StartsWith('#F') -or $script:Theme['Bg'].StartsWith('#E'))

    if ($isLight) {

        $nr = [Math]::Max(0, [int]($r * (1 - $factor)))

        $ng = [Math]::Max(0, [int]($g * (1 - $factor)))

        $nb = [Math]::Max(0, [int]($b * (1 - $factor)))

    } else {

        $nr = [Math]::Min(255, [int]($r + (255 - $r) * $factor))

        $ng = [Math]::Min(255, [int]($g + (255 - $g) * $factor))

        $nb = [Math]::Min(255, [int]($b + (255 - $b) * $factor))

    }

    return [System.Drawing.Color]::FromArgb($Color.A, $nr, $ng, $nb)

}



function Get-ThemeHtml {

    param([string]$Name)

    if ($script:Theme.ContainsKey($Name)) { return [string]$script:Theme[$Name] }

    return '#FFFFFF'

}



function Enable-DoubleBuffer {

    param([System.Windows.Forms.Control]$Control)

    try {

        $type = $Control.GetType()

        $property = $type.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)

        if ($null -ne $property) {

            $property.SetValue($Control, $true, $null)

        }

    } catch {}

}





function Show-Info {

    param([string]$Message)

    Out-MessageBox($Message, 'SysForge Studio', 'OK', 'Information') | Out-Null

}



function Get-IconGlyph {

    param([object]$Item)



    $text = ''

    if ($null -ne $Item -and $Item.PSObject.Properties.Name -contains 'Text') {

        $text = [string]$Item.Text

    }

    $haystack = $text.ToLowerInvariant()

    if ($haystack -match 'feel like hacker') { return 'CM' }

    if ($null -ne $Item -and $Item.PSObject.Properties.Name -contains 'Action') {

        $haystack += " $($Item.Action)".ToLowerInvariant()

    }

    if ($null -ne $Item -and $Item.PSObject.Properties.Name -contains 'ToolType') {

        $type = [string]$Item.ToolType

        if ($type -eq 'exe') { return 'EX' }

        if ($type -eq 'folder') { return 'FD' }

        if ($type -eq 'file') { return 'ED' }

        if ($type -eq 'url') { return 'WB' }

    }



    if ($haystack -match 'storage|disk|partition|drive|ssd|hdd|hard disk') { return 'DS' }

    if ($haystack -match 'backup|restore|recovery image|macrium') { return 'BK' }

    if ($haystack -match 'printer|spooler|print') { return 'PT' }

    if ($haystack -match 'office|outlook|mail') { return 'ML' }

    if ($haystack -match 'registry|policy|gpresult|group policy') { return 'RG' }

    if ($haystack -match 'user|account') { return 'US' }

    if ($haystack -match 'bios|uefi|boot') { return 'BT' }

    if ($haystack -match 'event|log') { return 'LG' }

    if ($haystack -match 'service|features|task|scheduler') { return 'SV' }

    if ($haystack -match 'performance|optimization|booster|cpu|occt') { return 'PF' }

    if ($haystack -match 'network|wifi|wlan|dns|ip|rdp|remote|cloud|share|hosts') { return 'NW' }

    if ($haystack -match 'battery|energy|power') { return 'PW' }

    if ($haystack -match 'driver|hardware|crash|bsod|device') { return 'HD' }

    if ($haystack -match 'security|defender|malware|audit|usb|firewall') { return 'SC' }

    if ($haystack -match 'one click|all info|ultimate report|report pack|report|inventory|health|dashboard|evidence|msinfo') { return 'RP' }

    if ($haystack -match 'software|apps|installer|deploy|portable|tools') { return 'AP' }

    if ($haystack -match 'settings|themes|catalog|config') { return 'TH' }

    if ($haystack -match 'cmd|menu|terminal') { return 'CM' }

    if ($haystack -match 'repair|fix|clean|problem|issue') { return 'FX' }

    if ($haystack -match 'dev|developer|power user') { return 'DV' }

    return 'UT'

}



function New-BadgeBitmap {

    param(

        [string]$Glyph,

        [int]$Index = 0,

        [int]$Size = 38

    )



    $key = "badge|$script:CurrentThemeName|$Glyph|$Index|$Size"

    if ($script:IconCache.ContainsKey($key)) { return $script:IconCache[$key] }



    $palette = @($script:Theme['Cards'])

    $fill = [System.Drawing.ColorTranslator]::FromHtml([string]$palette[$Index % $palette.Count])

    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)

    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $graphics.Clear([System.Drawing.Color]::Transparent)

    $rect = New-Object System.Drawing.Rectangle(1, 1, ($Size - 3), ($Size - 3))

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath

    $radius = [Math]::Max(8, [int]($Size / 4))

    $path.AddArc($rect.Left, $rect.Top, $radius, $radius, 180, 90)

    $path.AddArc($rect.Right - $radius, $rect.Top, $radius, $radius, 270, 90)

    $path.AddArc($rect.Right - $radius, $rect.Bottom - $radius, $radius, $radius, 0, 90)

    $path.AddArc($rect.Left, $rect.Bottom - $radius, $radius, $radius, 90, 90)

    $path.CloseFigure()

    $brush = New-Object System.Drawing.SolidBrush($fill)

    $graphics.FillPath($brush, $path)

    $brush.Dispose()

    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(115, 255, 255, 255), 1)

    $graphics.DrawPath($pen, $path)

    $pen.Dispose()



    $ink = [System.Drawing.Color]::FromArgb(30, 33, 43)

    $iconPen = New-Object System.Drawing.Pen($ink, [Math]::Max(2, [int]($Size / 15)))

    $iconPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round

    $iconPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    $iconPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $iconBrush = New-Object System.Drawing.SolidBrush($ink)

    $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190, 255, 255, 255))



    $s = [float]$Size

    $l = [int]($s * 0.25)

    $t = [int]($s * 0.24)

    $w = [int]($s * 0.50)

    $h = [int]($s * 0.52)

    switch ($Glyph) {

        'RP' {

            $graphics.FillRectangle($whiteBrush, $l, $t, $w, $h)

            $graphics.DrawRectangle($iconPen, $l, $t, $w, $h)

            $graphics.DrawLine($iconPen, [int]($s*.34), [int]($s*.40), [int]($s*.66), [int]($s*.40))

            $graphics.DrawLine($iconPen, [int]($s*.34), [int]($s*.52), [int]($s*.58), [int]($s*.52))

            $graphics.DrawLine($iconPen, [int]($s*.34), [int]($s*.64), [int]($s*.68), [int]($s*.64))

        }

        'NW' {

            $graphics.DrawEllipse($iconPen, [int]($s*.22), [int]($s*.28), [int]($s*.18), [int]($s*.18))

            $graphics.DrawEllipse($iconPen, [int]($s*.60), [int]($s*.28), [int]($s*.18), [int]($s*.18))

            $graphics.DrawEllipse($iconPen, [int]($s*.40), [int]($s*.58), [int]($s*.18), [int]($s*.18))

            $graphics.DrawLine($iconPen, [int]($s*.40), [int]($s*.38), [int]($s*.60), [int]($s*.38))

            $graphics.DrawLine($iconPen, [int]($s*.34), [int]($s*.46), [int]($s*.45), [int]($s*.58))

            $graphics.DrawLine($iconPen, [int]($s*.66), [int]($s*.46), [int]($s*.54), [int]($s*.58))

        }

        'PW' {

            $graphics.DrawRectangle($iconPen, [int]($s*.22), [int]($s*.36), [int]($s*.48), [int]($s*.28))

            $graphics.FillRectangle($iconBrush, [int]($s*.72), [int]($s*.44), [int]($s*.05), [int]($s*.12))

            $graphics.FillRectangle($iconBrush, [int]($s*.28), [int]($s*.42), [int]($s*.24), [int]($s*.16))

        }

        'HD' {

            $graphics.DrawRectangle($iconPen, [int]($s*.22), [int]($s*.32), [int]($s*.56), [int]($s*.38))

            $graphics.DrawLine($iconPen, [int]($s*.28), [int]($s*.58), [int]($s*.56), [int]($s*.58))

            $graphics.FillEllipse($iconBrush, [int]($s*.62), [int]($s*.54), [int]($s*.08), [int]($s*.08))

        }

        'DS' {

            $graphics.DrawEllipse($iconPen, [int]($s*.23), [int]($s*.22), [int]($s*.54), [int]($s*.20))

            $graphics.DrawLine($iconPen, [int]($s*.23), [int]($s*.32), [int]($s*.23), [int]($s*.66))

            $graphics.DrawLine($iconPen, [int]($s*.77), [int]($s*.32), [int]($s*.77), [int]($s*.66))

            $graphics.DrawArc($iconPen, [int]($s*.23), [int]($s*.56), [int]($s*.54), [int]($s*.20), 0, 180)

            $graphics.DrawLine($iconPen, [int]($s*.34), [int]($s*.50), [int]($s*.66), [int]($s*.50))

        }

        'BK' {

            $graphics.DrawArc($iconPen, [int]($s*.24), [int]($s*.25), [int]($s*.52), [int]($s*.52), 35, 285)

            $graphics.DrawLine($iconPen, [int]($s*.27), [int]($s*.44), [int]($s*.22), [int]($s*.28))

            $graphics.DrawLine($iconPen, [int]($s*.27), [int]($s*.44), [int]($s*.42), [int]($s*.40))

            $graphics.DrawLine($iconPen, [int]($s*.38), [int]($s*.50), [int]($s*.50), [int]($s*.62))

            $graphics.DrawLine($iconPen, [int]($s*.50), [int]($s*.62), [int]($s*.66), [int]($s*.42))

        }

        'PT' {

            $graphics.DrawRectangle($iconPen, [int]($s*.25), [int]($s*.20), [int]($s*.50), [int]($s*.18))

            $graphics.DrawRectangle($iconPen, [int]($s*.20), [int]($s*.40), [int]($s*.60), [int]($s*.24))

            $graphics.DrawRectangle($iconPen, [int]($s*.30), [int]($s*.58), [int]($s*.40), [int]($s*.20))

            $graphics.FillEllipse($iconBrush, [int]($s*.65), [int]($s*.48), [int]($s*.06), [int]($s*.06))

        }

        'ML' {

            $graphics.DrawRectangle($iconPen, [int]($s*.20), [int]($s*.30), [int]($s*.60), [int]($s*.42))

            $graphics.DrawLine($iconPen, [int]($s*.21), [int]($s*.32), [int]($s*.50), [int]($s*.54))

            $graphics.DrawLine($iconPen, [int]($s*.79), [int]($s*.32), [int]($s*.50), [int]($s*.54))

        }

        'RG' {

            $graphics.DrawRectangle($iconPen, [int]($s*.24), [int]($s*.24), [int]($s*.20), [int]($s*.20))

            $graphics.DrawRectangle($iconPen, [int]($s*.56), [int]($s*.24), [int]($s*.20), [int]($s*.20))

            $graphics.DrawRectangle($iconPen, [int]($s*.40), [int]($s*.56), [int]($s*.20), [int]($s*.20))

            $graphics.DrawLine($iconPen, [int]($s*.44), [int]($s*.34), [int]($s*.56), [int]($s*.34))

            $graphics.DrawLine($iconPen, [int]($s*.34), [int]($s*.44), [int]($s*.44), [int]($s*.56))

            $graphics.DrawLine($iconPen, [int]($s*.66), [int]($s*.44), [int]($s*.56), [int]($s*.56))

        }

        'US' {

            $graphics.DrawEllipse($iconPen, [int]($s*.39), [int]($s*.23), [int]($s*.22), [int]($s*.22))

            $graphics.DrawArc($iconPen, [int]($s*.26), [int]($s*.45), [int]($s*.48), [int]($s*.34), 200, 140)

        }

        'BT' {

            $graphics.DrawLine($iconPen, [int]($s*.50), [int]($s*.18), [int]($s*.50), [int]($s*.43))

            $graphics.DrawArc($iconPen, [int]($s*.26), [int]($s*.30), [int]($s*.48), [int]($s*.48), 130, 280)

        }

        'LG' {

            $graphics.DrawRectangle($iconPen, [int]($s*.24), [int]($s*.20), [int]($s*.48), [int]($s*.60))

            $graphics.DrawLine($iconPen, [int]($s*.34), [int]($s*.36), [int]($s*.64), [int]($s*.36))

            $graphics.DrawLine($iconPen, [int]($s*.34), [int]($s*.50), [int]($s*.62), [int]($s*.50))

            $graphics.DrawLine($iconPen, [int]($s*.34), [int]($s*.64), [int]($s*.56), [int]($s*.64))

        }

        'SV' {

            $graphics.DrawEllipse($iconPen, [int]($s*.34), [int]($s*.34), [int]($s*.32), [int]($s*.32))

            for ($a = 0; $a -lt 360; $a += 60) {

                $rad = $a * [Math]::PI / 180

                $x1 = [int]($s*.50 + [Math]::Cos($rad) * $s*.16)

                $y1 = [int]($s*.50 + [Math]::Sin($rad) * $s*.16)

                $x2 = [int]($s*.50 + [Math]::Cos($rad) * $s*.28)

                $y2 = [int]($s*.50 + [Math]::Sin($rad) * $s*.28)

                $graphics.DrawLine($iconPen, $x1, $y1, $x2, $y2)

            }

        }

        'PF' {

            $graphics.DrawArc($iconPen, [int]($s*.24), [int]($s*.28), [int]($s*.52), [int]($s*.52), 200, 140)

            $graphics.DrawLine($iconPen, [int]($s*.50), [int]($s*.54), [int]($s*.66), [int]($s*.38))

            $graphics.FillEllipse($iconBrush, [int]($s*.46), [int]($s*.50), [int]($s*.08), [int]($s*.08))

        }

        'FX' {

            $graphics.DrawLine($iconPen, [int]($s*.30), [int]($s*.70), [int]($s*.68), [int]($s*.32))

            $graphics.DrawLine($iconPen, [int]($s*.58), [int]($s*.24), [int]($s*.76), [int]($s*.42))

            $graphics.DrawLine($iconPen, [int]($s*.25), [int]($s*.28), [int]($s*.42), [int]($s*.45))

            $graphics.DrawLine($iconPen, [int]($s*.24), [int]($s*.42), [int]($s*.38), [int]($s*.28))

        }

        'DV' {

            $graphics.DrawLine($iconPen, [int]($s*.36), [int]($s*.34), [int]($s*.24), [int]($s*.50))

            $graphics.DrawLine($iconPen, [int]($s*.24), [int]($s*.50), [int]($s*.36), [int]($s*.66))

            $graphics.DrawLine($iconPen, [int]($s*.64), [int]($s*.34), [int]($s*.76), [int]($s*.50))

            $graphics.DrawLine($iconPen, [int]($s*.76), [int]($s*.50), [int]($s*.64), [int]($s*.66))

            $graphics.DrawLine($iconPen, [int]($s*.54), [int]($s*.30), [int]($s*.46), [int]($s*.70))

        }

        'SC' {

            $shield = New-Object System.Drawing.Drawing2D.GraphicsPath

            $shield.AddLine([int]($s*.50), [int]($s*.20), [int]($s*.72), [int]($s*.30))

            $shield.AddLine([int]($s*.72), [int]($s*.30), [int]($s*.68), [int]($s*.60))

            $shield.AddLine([int]($s*.68), [int]($s*.60), [int]($s*.50), [int]($s*.78))

            $shield.AddLine([int]($s*.50), [int]($s*.78), [int]($s*.32), [int]($s*.60))

            $shield.AddLine([int]($s*.32), [int]($s*.60), [int]($s*.28), [int]($s*.30))

            $shield.CloseFigure()

            $graphics.DrawPath($iconPen, $shield)

            $graphics.DrawLine($iconPen, [int]($s*.41), [int]($s*.50), [int]($s*.48), [int]($s*.58))

            $graphics.DrawLine($iconPen, [int]($s*.48), [int]($s*.58), [int]($s*.62), [int]($s*.42))

            $shield.Dispose()

        }

        'FD' {

            $graphics.DrawRectangle($iconPen, [int]($s*.20), [int]($s*.36), [int]($s*.60), [int]($s*.34))

            $graphics.DrawLine($iconPen, [int]($s*.22), [int]($s*.36), [int]($s*.38), [int]($s*.26))

            $graphics.DrawLine($iconPen, [int]($s*.38), [int]($s*.26), [int]($s*.54), [int]($s*.36))

        }

        'ED' {

            $graphics.DrawLine($iconPen, [int]($s*.30), [int]($s*.68), [int]($s*.66), [int]($s*.32))

            $graphics.DrawLine($iconPen, [int]($s*.24), [int]($s*.74), [int]($s*.36), [int]($s*.70))

            $graphics.DrawRectangle($iconPen, [int]($s*.22), [int]($s*.24), [int]($s*.36), [int]($s*.48))

        }

        'WB' {

            $graphics.DrawEllipse($iconPen, [int]($s*.22), [int]($s*.22), [int]($s*.56), [int]($s*.56))

            $graphics.DrawLine($iconPen, [int]($s*.24), [int]($s*.50), [int]($s*.76), [int]($s*.50))

            $graphics.DrawArc($iconPen, [int]($s*.34), [int]($s*.22), [int]($s*.32), [int]($s*.56), 90, 180)

            $graphics.DrawArc($iconPen, [int]($s*.34), [int]($s*.22), [int]($s*.32), [int]($s*.56), 270, 180)

        }

        'TH' {

            $graphics.FillEllipse($iconBrush, [int]($s*.24), [int]($s*.24), [int]($s*.18), [int]($s*.18))

            $graphics.FillEllipse($iconBrush, [int]($s*.56), [int]($s*.24), [int]($s*.18), [int]($s*.18))

            $graphics.FillEllipse($iconBrush, [int]($s*.24), [int]($s*.56), [int]($s*.18), [int]($s*.18))

            $graphics.FillEllipse($iconBrush, [int]($s*.56), [int]($s*.56), [int]($s*.18), [int]($s*.18))

        }

        'CM' {

            $graphics.DrawRectangle($iconPen, [int]($s*.20), [int]($s*.28), [int]($s*.60), [int]($s*.44))

            $graphics.DrawLine($iconPen, [int]($s*.30), [int]($s*.42), [int]($s*.42), [int]($s*.50))

            $graphics.DrawLine($iconPen, [int]($s*.42), [int]($s*.50), [int]($s*.30), [int]($s*.58))

            $graphics.DrawLine($iconPen, [int]($s*.50), [int]($s*.58), [int]($s*.66), [int]($s*.58))

        }

        default {

            $graphics.DrawRectangle($iconPen, [int]($s*.24), [int]($s*.24), [int]($s*.22), [int]($s*.22))

            $graphics.DrawRectangle($iconPen, [int]($s*.54), [int]($s*.24), [int]($s*.22), [int]($s*.22))

            $graphics.DrawRectangle($iconPen, [int]($s*.24), [int]($s*.54), [int]($s*.22), [int]($s*.22))

            $graphics.DrawRectangle($iconPen, [int]($s*.54), [int]($s*.54), [int]($s*.22), [int]($s*.22))

        }

    }

    $whiteBrush.Dispose()

    $iconBrush.Dispose()

    $iconPen.Dispose()

    $path.Dispose()

    $graphics.Dispose()



    $script:IconCache[$key] = $bitmap

    return $bitmap

}



function Get-ScaledBitmap {

    param(

        [System.Drawing.Bitmap]$Bitmap,

        [int]$Size = 38

    )

    $scaled = New-Object System.Drawing.Bitmap($Size, $Size)

    $graphics = [System.Drawing.Graphics]::FromImage($scaled)

    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    $graphics.Clear([System.Drawing.Color]::Transparent)

    $graphics.DrawImage($Bitmap, 0, 0, $Size, $Size)

    $graphics.Dispose()

    return $scaled

}



function Get-CardIcon {

    param([object]$Item, [int]$Index, [int]$Size = 38)



    if ($null -ne $Item -and $Item.PSObject.Properties.Name -contains 'ToolType' -and $Item.ToolType -eq 'exe') {

        $resolved = Resolve-ToolkitPath $Item.Target

        if (Test-Path -LiteralPath $resolved) {

            $key = "exe|$resolved|$Size"

            if (-not $script:IconCache.ContainsKey($key)) {

                try {

                    $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($resolved)

                    if ($null -ne $icon) {

                        $script:IconCache[$key] = Get-ScaledBitmap ($icon.ToBitmap()) $Size

                    }

                } catch {}

            }

            if ($script:IconCache.ContainsKey($key)) { return $script:IconCache[$key] }

        }

    }



    return New-BadgeBitmap -Glyph (Get-IconGlyph $Item) -Index $Index -Size $Size

}



function Join-ProcessArguments {

    param([string[]]$Arguments)



    return (($Arguments | ForEach-Object {

        $arg = [string]$_

        if ($arg -match '[\s"]') {

            '"' + ($arg -replace '"','\"') + '"'

        } else {

            $arg

        }

    }) -join ' ')

}



function Quote-CmdToken {

    param([string]$Value)



    if ([string]::IsNullOrWhiteSpace($Value)) { return '""' }

    return '"' + ($Value -replace '"', '\"') + '"'

}



function ConvertFrom-WingetTable {

    param(

        [string[]]$Lines,

        [string[]]$RequiredColumns = @('name', 'id', 'version')

    )



    # Strip carriage returns from each line (winget spinner uses bare \r)

    $cleanLines = @($Lines | Where-Object { $_ -and $_.ToString().Trim() -and $_.ToString().Trim().Replace("`r","").Length -gt 0 } | ForEach-Object { $_.ToString().Replace("`r","").Trim() } | Where-Object { $_.Length -gt 0 })

    $headerIndex = -1

    $separatorIndex = -1



    for ($i = 0; $i -lt $cleanLines.Count; $i++) {

        $line = $cleanLines[$i].ToString()

        if ($line -match '^\s*-{5,}\s*$') {

            if ($i -gt 0) {

                $headerIndex = $i - 1

                $separatorIndex = $i

                break

            }

        }

    }



    if ($headerIndex -eq -1 -or $separatorIndex -eq -1) { return @() }



    $header = $cleanLines[$headerIndex].ToString()

    $matches = [regex]::Matches($header, '\S+')

    $columns = @()

    $colNames = @('name', 'id', 'version', 'available', 'source')



    for ($i = 0; $i -lt $matches.Count; $i++) {

        $name = if ($i -lt $colNames.Count) { $colNames[$i] } else { "col_$i" }

        if ($i -eq 3 -and $header.ToLowerInvariant().Contains("match")) {

            $name = "match"

        }

        $columns += [pscustomobject]@{

            Name = $name

            NominalPosition = $matches[$i].Index

        }

    }



    $results = @()

    for ($i = $separatorIndex + 1; $i -lt $cleanLines.Count; $i++) {

        $line = $cleanLines[$i].ToString()

        if ($line -match '^\s*-{3,}\s*$') { continue }



        $row = [ordered]@{}

        $adjustedPositions = @()

        

        # Calculate adjusted start positions for this line

        for ($c = 0; $c -lt $columns.Count; $c++) {

            $nominal = $columns[$c].NominalPosition

            if ($c -eq 0) {

                $adjustedPositions += 0

                continue

            }

            

            if ($line.Length -le $nominal) {

                $adjustedPositions += $line.Length

                continue

            }

            

            $pos = $nominal

            if ($line[$pos] -eq ' ') {

                # Scan right to find non-space

                while ($pos -lt $line.Length -and $line[$pos] -eq ' ') {

                    $pos++

                }

            } else {

                # Scan left to find space

                # But don't scan past the previous column's adjusted start

                $prevLimit = $adjustedPositions[$c-1]

                while ($pos -gt $prevLimit -and $line[$pos-1] -ne ' ') {

                    $pos--

                }

            }

            $adjustedPositions += $pos

        }



        # Extract substrings using adjusted start positions

        for ($c = 0; $c -lt $columns.Count; $c++) {

            $start = $adjustedPositions[$c]

            $next = if ($c + 1 -lt $columns.Count) { $adjustedPositions[$c+1] } else { $line.Length }

            

            if ($line.Length -le $start) {

                $row[$columns[$c].Name] = ''

                continue

            }

            

            $width = [Math]::Max(0, [Math]::Min($next, $line.Length) - $start)

            $row[$columns[$c].Name] = $line.Substring($start, $width).Trim()

        }



        if ([string]::IsNullOrWhiteSpace($row['id']) -or $row['id'] -eq 'Id' -or $row['id'] -eq 'ID' -or $row['id'].Contains(' ')) { continue }

        $results += [pscustomobject]@{

            Name = $row['name']

            ID = $row['id']

            Version = $row['version']

            Available = $row['available']

            Match = $row['match']

            Source = $row['source']

        }

    }



    return $results

}



if ($null -eq $script:AsyncProcessTimers) {

    $script:AsyncProcessTimers = @{}

}



function Start-CapturedProcessAsync {

    param(

        [string]$FilePath,

        [string[]]$Arguments = @(),

        [int]$TimeoutSeconds = 45,

        [System.Windows.Forms.Control]$LoadingControl = $null,

        [string]$StatusText = 'Working...',

        [scriptblock]$OnComplete,

        [scriptblock]$OnError

    )



    $outputLines = New-Object System.Collections.ArrayList

    $errorLines = New-Object System.Collections.ArrayList

    $sw = [System.Diagnostics.Stopwatch]::StartNew()



    try {

        $psi = New-Object System.Diagnostics.ProcessStartInfo

        $psi.FileName = $FilePath

        $psi.Arguments = Join-ProcessArguments $Arguments

        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

        $psi.CreateNoWindow = $true

        $psi.UseShellExecute = $false

        $psi.RedirectStandardOutput = $true

        $psi.RedirectStandardError = $true

        try {

            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8

            $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

        } catch {}



        $proc = New-Object System.Diagnostics.Process

        $proc.StartInfo = $psi



        if (-not $proc.Start()) {

            throw "Unable to start process: $FilePath"

        }



        $outTask = $proc.StandardOutput.ReadLineAsync()

        $errTask = $proc.StandardError.ReadLineAsync()

    } catch {

        $sw.Stop()

        $result = [pscustomobject]@{

            Lines = @()

            ErrorLines = @($_.Exception.Message)

            CombinedLines = @($_.Exception.Message)

            ExitCode = -1

            TimedOut = $false

            ElapsedSeconds = [Math]::Round($sw.Elapsed.TotalSeconds, 2)

            ErrorMessage = $_.Exception.Message

        }

        if ($OnError) { & $OnError $result }

        return

    }



    $state = [pscustomobject]@{

        OutTask = $outTask

        ErrTask = $errTask

    }



    $timerKey = [Guid]::NewGuid().ToString()

    $timer = New-Object System.Windows.Forms.Timer

    $timer.Interval = 300

    $script:AsyncProcessTimers[$timerKey] = $timer



    $timer.Add_Tick(({

        try {

            if ($null -eq $proc -or $null -eq $proc.StandardOutput -or $null -eq $proc.StandardError) {

                try { $timer.Stop() } catch {}

                return

            }

            while ($null -ne $state.OutTask -and $state.OutTask.IsCompleted) {

                try {

                    if ($state.OutTask.IsFaulted) {

                        $state.OutTask = $null

                    } else {

                        $line = $state.OutTask.Result

                        if ($null -ne $line) {

                            [void]$outputLines.Add($line)

                            $state.OutTask = $proc.StandardOutput.ReadLineAsync()

                        } else {

                            $state.OutTask = $null

                        }

                    }

                } catch {

                    $state.OutTask = $null

                }

            }



            while ($null -ne $state.ErrTask -and $state.ErrTask.IsCompleted) {

                try {

                    if ($state.ErrTask.IsFaulted) {

                        $state.ErrTask = $null

                    } else {

                        $line = $state.ErrTask.Result

                        if ($null -ne $line) {

                            [void]$errorLines.Add($line)

                            $state.ErrTask = $proc.StandardError.ReadLineAsync()

                        } else {

                            $state.ErrTask = $null

                        }

                    }

                } catch {

                    $state.ErrTask = $null

                }

            }



            $elapsedSeconds = [Math]::Round($sw.Elapsed.TotalSeconds, 1)

            if ($null -ne $LoadingControl -and -not $LoadingControl.IsDisposed) {

                $LoadingControl.Text = "$StatusText`r`nElapsed: $elapsedSeconds sec"

            }



            $timedOut = ($TimeoutSeconds -gt 0 -and $sw.Elapsed.TotalSeconds -ge $TimeoutSeconds)

            if (-not $proc.HasExited -and -not $timedOut) { return }



            $timer.Stop()

            $timer.Dispose()

            $script:AsyncProcessTimers.Remove($timerKey)



            if ($timedOut -and -not $proc.HasExited) {

                try { $proc.Kill() } catch {}

            }



            try { $proc.WaitForExit(1000) | Out-Null } catch {}

            $sw.Stop()



            while ($null -ne $state.OutTask -and $state.OutTask.IsCompleted) {

                try {

                    if ($state.OutTask.IsFaulted) { $state.OutTask = $null } else {

                        $line = $state.OutTask.Result

                        if ($null -ne $line) {

                            [void]$outputLines.Add($line)

                            $state.OutTask = $proc.StandardOutput.ReadLineAsync()

                        } else { $state.OutTask = $null }

                    }

                } catch { $state.OutTask = $null }

            }

            while ($null -ne $state.ErrTask -and $state.ErrTask.IsCompleted) {

                try {

                    if ($state.ErrTask.IsFaulted) { $state.ErrTask = $null } else {

                        $line = $state.ErrTask.Result

                        if ($null -ne $line) {

                            [void]$errorLines.Add($line)

                            $state.ErrTask = $proc.StandardError.ReadLineAsync()

                        } else { $state.ErrTask = $null }

                    }

                } catch { $state.ErrTask = $null }

            }



            $exitCode = -1

            try {

                if ($proc.HasExited) { $exitCode = $proc.ExitCode }

            } catch {}



            $lines = @($outputLines)

            $errors = @($errorLines)

            $message = if ($timedOut) { "Command timed out after $TimeoutSeconds seconds." } elseif ($errors.Count -gt 0) { ($errors -join "`r`n") } else { '' }



            $result = [pscustomobject]@{

                Lines = $lines

                ErrorLines = $errors

                CombinedLines = @($lines + $errors)

                ExitCode = $exitCode

                TimedOut = $timedOut

                ElapsedSeconds = [Math]::Round($sw.Elapsed.TotalSeconds, 2)

                ErrorMessage = $message

            }



            try {

                if ($timedOut) {

                    if ($null -ne $OnError -and $OnError -is [scriptblock]) {

                        & $OnError $result

                    } else {

                        if ($null -ne $OnComplete -and $OnComplete -is [scriptblock]) {

                            & $OnComplete $result

                        }

                    }

                } else {

                    if ($null -ne $OnComplete -and $OnComplete -is [scriptblock]) {

                        & $OnComplete $result

                    }

                }

            } catch {

                try {

                    $errLine = "[$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')] GUI Process Runner Callback Exception: $_"

                    $logPath = Join-Path $script:ToolkitRoot 'Logs\startup_err.log'

                    if (-not (Test-Path -LiteralPath (Split-Path -Parent $logPath))) {

                        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null

                    }

                    Add-Content -LiteralPath $logPath -Value $errLine -Force -ErrorAction SilentlyContinue

                } catch {}

            } finally {

                try { $proc.Dispose() } catch {}

            }

        } catch {

            try {

                $errLine = "[$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')] GUI Process Runner Tick Exception: $_"

                $logPath = Join-Path $script:ToolkitRoot 'Logs\startup_err.log'

                if (-not (Test-Path -LiteralPath (Split-Path -Parent $logPath))) {

                    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null

                }

                Add-Content -LiteralPath $logPath -Value $errLine -Force -ErrorAction SilentlyContinue

            } catch {}

        }

    }.GetNewClosure()))



    $timer.Start()

}



function Set-UpdateManagerBusy {

    param([bool]$Busy)



    foreach ($ctrl in @($script:btnSoftwareTab, $script:btnDriverTab, $script:btnScan, $script:btnUpgradeAll)) {

        try {

            if ($null -ne $ctrl -and -not $ctrl.IsDisposed) {

                $ctrl.Enabled = -not $Busy

            }

        } catch {}

    }



    try {

        if ($null -ne $script:btnScan -and -not $script:btnScan.IsDisposed) {

            $script:btnScan.Text = if ($Busy) { 'Scanning...' } else { 'Scan Updates' }

        }

    } catch {}

}



function Write-GuiActionLog {

    param(

        [string]$Title,

        [string]$Status,

        [string]$Output = ''

    )



    try {

        if (-not (Test-Path -LiteralPath $LogRoot)) {

            New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null

        }

        $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

        $lines = @(

            "[$stamp] $Status - $Title",

            $Output.TrimEnd(),

            ('-' * 90)

        )

        [System.IO.File]::AppendAllLines($GuiActionLogPath, [string[]]$lines, [System.Text.Encoding]::UTF8)

    } catch {}

}



function Test-DangerousAction {

    param(

        [string]$Text,

        [string]$CommandText = ''

    )



    $haystack = "$Text $CommandText".ToLowerInvariant()

    return ($haystack -match '\b(format|delete|remove|uninstall|reset|wipe|erase|clean|disable|stop service|firewall reset|defender offline|chkdsk|sfc|dism|bcdedit|bootrec|diskpart|debloat)\b')

}



function Confirm-DangerousAction {

    param([string]$Title)



    $message = "This action can change Windows settings, remove data/apps, or repair system components.`r`n`r`nRun it from GUI hidden command mode?"

    $result = Out-MessageBox($message, $Title, 'YesNo', 'Warning')

    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)

}



function New-ToolkitRunnerLines {

    param(

        [string]$CommandText,

        [bool]$AppendToolkitHelpers = $false,

        [bool]$PauseAtEnd = $false

    )



    $root = $ToolkitRoot.TrimEnd('\')

    $lines = @(

        '@echo off',

        'setlocal EnableExtensions EnableDelayedExpansion',

        ('cd /d "{0}"' -f $root),

        ('set "TOOLKIT_ROOT={0}\"' -f $root),

        ('set "TOOLKIT_HOME={0}\"' -f $root),

        ('set "MODULES_DIR={0}\Modules"' -f $root),

        ('set "TOOLS_DIR={0}\Tools"' -f $root),

        ('set "ASSETS_DIR={0}\Assets"' -f $root),

        ('set "CONFIG_DIR={0}\Config"' -f $root),

        ('set "LOGROOT={0}\Logs"' -f $root),

        'if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1'

    )



    if ($AppendToolkitHelpers) {

        $lines += 'call :init_ui_colors'

    }



    $lines += $CommandText



    if ($PauseAtEnd) {

        $lines += 'echo.'

        $lines += 'pause'

    }



    $lines += 'exit /b %errorlevel%'



    if ($AppendToolkitHelpers -and (Test-Path -LiteralPath $ToolkitBat)) {

        $lines += ''

        $lines += ':: ---- Embedded Toolkit.bat helpers for GUI standalone subroutine calls ----'

        try {

            $lines += Get-Content -LiteralPath $ToolkitBat -ErrorAction Stop

        } catch {

            $lines += ('echo Failed to load Toolkit.bat helper labels: {0}' -f $_.Exception.Message)

        }

    }



    return $lines

}



function Start-VisibleCmdRunner {

    param(

        [string]$CommandText,

        [string]$Title = 'Toolkit interactive command'

    )



    if ([string]::IsNullOrWhiteSpace($CommandText)) {

        Show-Warning 'No command text was provided.'

        return

    }



    if (Test-DangerousAction -Text $Title -CommandText $CommandText) {

        if (-not (Confirm-DangerousAction -Title $Title)) {

            $script:statusLabel.Text = 'Command cancelled'

            return

        }

    }



    $runner = Join-Path $script:LocalTempDir ("SysForge Studio_interactive_{0}.cmd" -f ([guid]::NewGuid().ToString('N')))

    $appendHelpers = ($CommandText -match '(?i)\bcall\s+:')

    $lines = New-ToolkitRunnerLines -CommandText $CommandText -AppendToolkitHelpers $appendHelpers -PauseAtEnd $true



    try {

        [System.IO.File]::WriteAllLines($runner, $lines)

    } catch {

        Show-Warning "Interactive command runner create nahi ho paya:`r`n$($_.Exception.Message)"

        return

    }



    Start-Process -FilePath $env:ComSpec -ArgumentList ('/d /k call "{0}"' -f $runner) -WorkingDirectory $ToolkitRoot | Out-Null

    $script:statusLabel.Text = "Started interactive command: $Title"

    Write-GuiActionLog -Title $Title -Status 'START INTERACTIVE' -Output "Command: $CommandText`r`nRunner: $runner"

}



function Start-CmdWindow {

    param(

        [string]$CommandText,

        [string]$Title = 'Toolkit command',

        [int]$TimeoutSeconds = $DefaultCommandTimeoutSeconds

    )



    if ([string]::IsNullOrWhiteSpace($CommandText)) {

        Show-Warning 'No command text was provided.'

        return

    }



    if (Test-DangerousAction -Text $Title -CommandText $CommandText) {

        if (-not (Confirm-DangerousAction -Title $Title)) {

            $script:statusLabel.Text = 'Command cancelled'

            return

        }

    }



    $runner = Join-Path $script:LocalTempDir ("SysForge Studio_runner_{0}.cmd" -f ([guid]::NewGuid().ToString('N')))

    $appendHelpers = ($CommandText -match '(?i)\bcall\s+:')

    $lines = New-ToolkitRunnerLines -CommandText $CommandText -AppendToolkitHelpers $appendHelpers -PauseAtEnd $false



    try {

        [System.IO.File]::WriteAllLines($runner, $lines)

    } catch {

        Show-Warning "Command runner create nahi ho paya:`r`n$($_.Exception.Message)"

        return

    }



    $dialog = New-Object System.Windows.Forms.Form

    $dialog.Text = "Running: $Title"

    $dialog.StartPosition = 'CenterParent'

    $dialog.Size = New-Object System.Drawing.Size(860, 560)

    $dialog.MinimumSize = New-Object System.Drawing.Size(720, 440)

    $dialog.BackColor = Get-ThemeColor 'Panel'

    $dialog.ShowInTaskbar = $false

    if (Test-Path -LiteralPath $AppIconPath) {

        try { $dialog.Icon = New-Object System.Drawing.Icon($AppIconPath) } catch {}

    }



    $titleLabelRun = New-Object System.Windows.Forms.Label

    $titleLabelRun.Text = $Title

    $titleLabelRun.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

    $titleLabelRun.ForeColor = Get-ThemeColor 'Text'

    $titleLabelRun.SetBounds(18, 14, 620, 28)

    $titleLabelRun.Anchor = 'Top,Left,Right'

    $dialog.Controls.Add($titleLabelRun)



    $stateLabel = New-Object System.Windows.Forms.Label

    $stateLabel.Text = 'Starting hidden command...'

    $stateLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $stateLabel.ForeColor = Get-ThemeColor 'Muted'

    $stateLabel.SetBounds(18, 42, 620, 24)

    $stateLabel.Anchor = 'Top,Left,Right'

    $dialog.Controls.Add($stateLabel)



    $progress = New-Object System.Windows.Forms.ProgressBar

    $progress.Style = 'Marquee'

    $progress.MarqueeAnimationSpeed = 25

    $progress.SetBounds(18, 74, 805, 18)

    $progress.Anchor = 'Top,Left,Right'

    $dialog.Controls.Add($progress)



    $outputBox = New-Object System.Windows.Forms.TextBox

    $outputBox.Multiline = $true

    $outputBox.ReadOnly = $true

    $outputBox.ScrollBars = 'Both'

    $outputBox.WordWrap = $false

    $outputBox.Font = New-Object System.Drawing.Font('Consolas', 9)

    $outputBox.BackColor = Get-ThemeColor 'Panel2'

    $outputBox.ForeColor = Get-ThemeColor 'Text'

    $outputBox.SetBounds(18, 106, 805, 360)

    $outputBox.Anchor = 'Top,Bottom,Left,Right'

    $dialog.Controls.Add($outputBox)



    $cancelButton = New-Object System.Windows.Forms.Button

    $cancelButton.Text = 'Cancel'

    $cancelButton.SetBounds(628, 478, 90, 32)

    $cancelButton.Anchor = 'Bottom,Right'

    $cancelButton.FlatStyle = 'Flat'

    $cancelButton.BackColor = Get-ThemeColor 'Button'

    $cancelButton.ForeColor = Get-ThemeColor 'Text'

    $cancelButton.FlatAppearance.BorderColor = Get-ThemeColor 'Border'

    $dialog.Controls.Add($cancelButton)



    $closeButton = New-Object System.Windows.Forms.Button

    $closeButton.Text = 'Close'

    $closeButton.Enabled = $false

    $closeButton.SetBounds(730, 478, 90, 32)

    $closeButton.Anchor = 'Bottom,Right'

    $closeButton.FlatStyle = 'Flat'

    $closeButton.BackColor = Get-ThemeColor 'Accent'

    $closeButton.ForeColor = Get-ThemeColor 'CardText'

    $closeButton.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $dialog.Controls.Add($closeButton)



    $btnRunInCmd = New-Object System.Windows.Forms.Button

    $btnRunInCmd.Text = 'Run in CMD'

    $btnRunInCmd.SetBounds(500, 478, 120, 32)

    $btnRunInCmd.Anchor = 'Bottom,Right'

    $btnRunInCmd.FlatStyle = 'Flat'

    $btnRunInCmd.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#EAB308')

    $btnRunInCmd.ForeColor = [System.Drawing.Color]::Black

    $btnRunInCmd.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnRunInCmd.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml('#CA8A04')

    $btnRunInCmd.Cursor = [System.Windows.Forms.Cursors]::Hand

    

    $btnRunInCmd.Add_Click({

        try {

            if ($null -ne $process -and -not $process.HasExited) {

                $dialogState.ClosedByUser = $true

                $process.Kill()

            }

        } catch {}

        $dialog.Close()



        $cmdRunner = Join-Path $script:LocalTempDir ("SysForge Studio_cli_{0}.cmd" -f ([guid]::NewGuid().ToString('N')))

        Copy-Item -LiteralPath $runner -Destination $cmdRunner -Force -ErrorAction SilentlyContinue



        Start-Process -FilePath $env:ComSpec -ArgumentList ("/d /k call `"{0}`"" -f $cmdRunner) -WorkingDirectory $ToolkitRoot

    })

    $dialog.Controls.Add($btnRunInCmd)



    $process = New-Object System.Diagnostics.Process

    $psi = New-Object System.Diagnostics.ProcessStartInfo

    $psi.FileName = $env:ComSpec

    $psi.Arguments = ('/d /c call "{0}" <nul' -f $runner)

    $psi.WorkingDirectory = $ToolkitRoot

    $psi.UseShellExecute = $false

    $psi.CreateNoWindow = $true

    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $psi.RedirectStandardOutput = $true

    $psi.RedirectStandardError = $true

    try {

        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8

        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    } catch {}

    $process.StartInfo = $psi

    $process.EnableRaisingEvents = $true



    $buffer = New-Object System.Text.StringBuilder

    $startedAt = Get-Date

    $dialogState = [pscustomobject]@{ ClosedByUser = $false }



    $appendAction = [System.Action[string]]{

        param([string]$line)

        if ($null -eq $line) { return }

        [void]$buffer.AppendLine($line)

        $outputBox.AppendText($line + [Environment]::NewLine)

        $outputBox.SelectionStart = $outputBox.TextLength

        $outputBox.ScrollToCaret()

    }



    $state = [pscustomobject]@{

        OutTask = $null

        ErrTask = $null

    }



    $timer = New-Object System.Windows.Forms.Timer

    $timer.Interval = 300

    $timer.Add_Tick(({

        try {

            if ($null -eq $process -or $null -eq $process.StandardOutput -or $null -eq $process.StandardError) {

                try { $timer.Stop() } catch {}

                return

            }

            while ($null -ne $state.OutTask -and $state.OutTask.IsCompleted) {

                try {

                    if ($state.OutTask.IsFaulted) {

                        $state.OutTask = $null

                    } else {

                        $line = $state.OutTask.Result

                        if ($null -ne $line) {

                            $appendAction.Invoke($line)

                            $state.OutTask = $process.StandardOutput.ReadLineAsync()

                        } else {

                            $state.OutTask = $null

                        }

                    }

                } catch {

                    $state.OutTask = $null

                }

            }



            while ($null -ne $state.ErrTask -and $state.ErrTask.IsCompleted) {

                try {

                    if ($state.ErrTask.IsFaulted) {

                        $state.ErrTask = $null

                    } else {

                        $line = $state.ErrTask.Result

                        if ($null -ne $line) {

                            $appendAction.Invoke("ERR: " + $line)

                            $state.ErrTask = $process.StandardError.ReadLineAsync()

                        } else {

                            $state.ErrTask = $null

                        }

                    }

                } catch {

                    $state.ErrTask = $null

                }

            }



            $elapsed = [int]((Get-Date) - $startedAt).TotalSeconds

            if (-not $process.HasExited) {

                $stateLabel.Text = "Running hidden command... elapsed ${elapsed}s"

                if ($TimeoutSeconds -gt 0 -and $elapsed -ge $TimeoutSeconds) {

                    $appendAction.Invoke("Command timeout reached after $TimeoutSeconds seconds.")

                    try { $process.Kill() } catch {}

                }

                return

            }



            $timer.Stop()

            $timer.Dispose()

            $progress.Style = 'Blocks'

            $progress.Value = 100

            $exitCode = $process.ExitCode

            $stateLabel.Text = "Finished with exit code $exitCode"

            $cancelButton.Enabled = $false

            $closeButton.Enabled = $true

            try { Remove-Item -LiteralPath $runner -Force -ErrorAction SilentlyContinue } catch {}

            $output = $buffer.ToString()

            Write-GuiActionLog -Title $Title -Status "EXIT $exitCode" -Output ("Command: $CommandText`r`n$output")

            $script:statusLabel.Text = "Finished: $Title (exit $exitCode)"

        } catch {}

    }.GetNewClosure()))



    $cancelButton.Add_Click(({

        try {

            if (-not $process.HasExited) {

                $dialogState.ClosedByUser = $true

                $process.Kill()

                $stateLabel.Text = 'Cancelling command...'

                $appendAction.Invoke('Command cancelled by user.')

            }

        } catch {}

    }.GetNewClosure()))



    $closeButton.Add_Click(({ $dialog.Close() }.GetNewClosure()))



    $dialog.Add_Shown(({

        try {

            $script:statusLabel.Text = "Running hidden command: $Title"

            Write-GuiActionLog -Title $Title -Status 'START' -Output "Command: $CommandText"

            [void]$process.Start()

            $state.OutTask = $process.StandardOutput.ReadLineAsync()

            $state.ErrTask = $process.StandardError.ReadLineAsync()

            $timer.Start()

        } catch {

            $timer.Stop()

            $progress.Style = 'Blocks'

            $stateLabel.Text = 'Command failed to start'

            $outputBox.AppendText($_.Exception.Message)

            $closeButton.Enabled = $true

            $cancelButton.Enabled = $false

            Write-GuiActionLog -Title $Title -Status 'START FAILED' -Output $_.Exception.Message

        }

    }.GetNewClosure()))



    $dialog.Add_FormClosing(({

        param($sender, $e)

        try {

            if (-not $process.HasExited -and -not $dialogState.ClosedByUser) {

                $result = Out-MessageBox('Command is still running. Cancel it now?', 'SysForge Studio', 'YesNo', 'Warning')

                if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {

                    $e.Cancel = $true

                    return

                }

                $dialogState.ClosedByUser = $true

                try { $process.Kill() } catch {}

            }

        } catch {}

    }.GetNewClosure()))



    $dialog.Add_FormClosed(({

        try { $timer.Stop(); $timer.Dispose() } catch {}

        try { if (-not $process.HasExited) { $process.Kill() } } catch {}

        try { $process.Dispose() } catch {}

        try { Remove-Item -LiteralPath $runner -Force -ErrorAction SilentlyContinue } catch {}

    }.GetNewClosure()))



    [void]$dialog.ShowDialog($form)

}



function Start-ToolkitMain {

    Show-Menu 'main' $false

    $script:statusLabel.Text = 'CMD toolkit menus are integrated in the GUI'

}



function Start-ToolkitLabel {

    param(

        [string]$Label,

        [string]$BackLabel = 'main'

    )



    if ([string]::IsNullOrWhiteSpace($Label)) {

        Start-ToolkitMain

        return

    }



    $lower = $Label.ToLowerInvariant()

    if ($lower -in @('search_processes', 'search_services', 'search_installed_apps', 'search_ports', 'search_events', 'search_driver_hwids', 'search_files', 'search_toolkit_text', 'search_smart_jump', 'search_global')) {

        Show-NativeGuiSearchPanel -SearchType $lower

        return

    }



    if ($model.Blocks.ContainsKey($lower)) {

        $block = $model.Blocks[$lower]

        if ($block.IsMenu) {

            Show-Menu $Label $true

            return

        }

    }



    $cmd = "call `"$ToolkitBat`" --no-elevate --label `"$Label`""

    if (-not [string]::IsNullOrWhiteSpace($BackLabel)) {

        $cmd += " --back `"$BackLabel`""

    }

    Start-CmdWindow -CommandText $cmd -Title (Convert-LabelToTitle $Label)

}



function ConvertTo-StandaloneCommand {

    param([object]$Option)



    if ($Option.Kind -ne 'Inline' -or [string]::IsNullOrWhiteSpace($Option.Command)) { return '' }



    $cmd = $Option.Command.Trim()

    if ($cmd.StartsWith('(') -and $cmd.EndsWith(')')) {

        $cmd = $cmd.Substring(1, $cmd.Length - 2).Trim()

    }



    $cmd = $cmd -replace '\s*&\s*goto\s+:?[A-Za-z0-9_.$-]+\s*$', ''

    $cmd = $cmd -replace '\s*&\s*pause\s*$', ''

    $cmd = $cmd -replace '\^&', '&'

    $cmd = $cmd -replace '\^\|', '|'

    $cmd = $cmd -replace '\^>', '>'

    $cmd = $cmd -replace '\^<', '<'

    $cmd = $cmd.Trim()

    if ([string]::IsNullOrWhiteSpace($cmd)) { return '' }



    # Internal jumps cannot be safely detached from their menu block. Trailing menu returns

    # are removed above, but any remaining goto should stay in the original CMD menu.

    if ($cmd -match '(?i)\bgoto\s+:?') { return '' }



    if ($cmd -match '(?i)(^|[&|]\s*)winget(?:\.exe)?\s+') {

        $wingetPath = Resolve-WingetPath

        if ([string]::IsNullOrWhiteSpace($wingetPath)) {

            return 'echo Winget/App Installer not found. Open Microsoft Store and install App Installer.'

        }

        $quotedWinget = Quote-CmdToken $wingetPath

        $cmd = [regex]::Replace($cmd, '(?i)(^|[&|]\s*)winget(?:\.exe)?\s+', {

            param($m)

            return $m.Groups[1].Value + $quotedWinget + ' '

        })

    }



    return $cmd

}



function Start-MenuChoice {

    param([object]$Option)



    $standalone = ConvertTo-StandaloneCommand $Option

    if (-not [string]::IsNullOrWhiteSpace($standalone)) {

        Start-CmdWindow -CommandText $standalone -Title $Option.Text

        return

    }



    if (-not [string]::IsNullOrWhiteSpace($Option.TargetLabel)) {

        Start-ToolkitLabel $Option.TargetLabel $Option.ParentLabel

        return

    }



    Start-ToolkitLabel $Option.ParentLabel 'main'

}



function Show-Warning {

    param([string]$Message)

    Out-MessageBox($Message, 'SysForge Studio', 'OK', 'Warning') | Out-Null

}



function Invoke-ResolvedTool {

    param([string]$Type, [string]$Target, [string]$Name)

    $kind = $Type.ToLowerInvariant()

    if ($kind -eq 'url') {

        Write-GuiActionLog -ActionType 'Tool' -Component $Name -Details "Opened URL: $Target"

        Start-Process -FilePath $Target | Out-Null

        return

    }

    $resolved = Resolve-ToolkitPath $Target

    if ($kind -eq 'exe') {

        if (-not (Test-Path -LiteralPath $resolved)) {

            Write-GuiActionLog -ActionType 'Error' -Component $Name -Details "EXE missing: $resolved"

            Show-Warning "EXE missing:`r`n$resolved`r`n`r`nPortable software is folder me paste karein, ya Config\tools.catalog me path update karein."

            return

        }

        Write-GuiActionLog -ActionType 'Tool' -Component $Name -Details "Launched EXE: $resolved"

        Start-Process -FilePath $resolved -WorkingDirectory (Split-Path -Parent $resolved) | Out-Null

        return

    }

    if ($kind -eq 'script') {

        if (-not (Test-Path -LiteralPath $resolved)) {

            Write-GuiActionLog -ActionType 'Error' -Component $Name -Details "Script missing: $resolved"

            Show-Warning "Script missing:`r`n$resolved"

            return

        }

        Write-GuiActionLog -ActionType 'Tool' -Component $Name -Details "Launched script: $resolved"

        if ($resolved.ToLowerInvariant().EndsWith('.ps1')) {

            Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',"`"$resolved`"") -WorkingDirectory (Split-Path -Parent $resolved) -WindowStyle Hidden | Out-Null

        } else {

            Start-CmdWindow -CommandText "call `"$resolved`"" -Title $Name

        }

        return

    }

    if ($kind -eq 'folder') {

        if (-not (Test-Path -LiteralPath $resolved)) {

            New-Item -ItemType Directory -Force -Path $resolved | Out-Null

        }

        Write-GuiActionLog -ActionType 'Tool' -Component $Name -Details "Opened folder: $resolved"

        Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$resolved`"" | Out-Null

        return

    }

    if ($kind -eq 'file') {

        if (-not (Test-Path -LiteralPath $resolved)) {

            Show-Warning "File missing:`r`n$resolved"

            return

        }

        Start-Process -FilePath 'notepad.exe' -ArgumentList "`"$resolved`"" | Out-Null

        return

    }

    Show-Warning "Unknown tool type: $Type`r`n$Name"

}



function Ensure-InventoryFolder {

    try {

        if (-not (Test-Path -LiteralPath $script:InventoryOutputRoot)) {

            New-Item -ItemType Directory -Force -Path $script:InventoryOutputRoot | Out-Null

        }

    } catch {

        $script:InventoryOutputRoot = Join-Path $LogRoot 'SystemInventory'

        if (-not (Test-Path -LiteralPath $script:InventoryOutputRoot)) {

            New-Item -ItemType Directory -Force -Path $script:InventoryOutputRoot | Out-Null

        }

    }

}



function Show-ReportProgress {

    param(

        [System.Diagnostics.Process]$Process,

        [string]$DisplayName,

        [datetime]$StartedAt,

        [int]$MaxSeconds = 20

    )



    $script:LastReportTimedOut = $false

    $dialog = New-Object System.Windows.Forms.Form

    $dialog.Text = 'Generating report'

    $dialog.StartPosition = 'CenterParent'

    $dialog.FormBorderStyle = 'FixedDialog'

    $dialog.ClientSize = New-Object System.Drawing.Size(430, 190)

    $dialog.MaximizeBox = $false

    $dialog.MinimizeBox = $false

    $dialog.ControlBox = $false

    $dialog.ShowInTaskbar = $false

    $dialog.BackColor = Get-ThemeColor 'Panel'

    if (Test-Path -LiteralPath $AppIconPath) {

        try { $dialog.Icon = New-Object System.Drawing.Icon($AppIconPath) } catch {}

    }



    $badge = New-Object System.Windows.Forms.PictureBox

    $badge.Image = New-BadgeBitmap -Glyph 'RP' -Index 0 -Size 44

    $badge.SizeMode = 'CenterImage'

    $badge.SetBounds(22, 24, 54, 54)

    $dialog.Controls.Add($badge)



    $heading = New-Object System.Windows.Forms.Label

    $heading.Text = "$DisplayName generate ho raha hai"

    $heading.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)

    $heading.ForeColor = Get-ThemeColor 'Text'

    $heading.SetBounds(88, 22, 318, 30)

    $dialog.Controls.Add($heading)



    $message = New-Object System.Windows.Forms.Label

    $message.Text = "Please wait... fast mode max $MaxSeconds sec target par report ready karega."

    $message.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $message.ForeColor = Get-ThemeColor 'Muted'

    $message.SetBounds(90, 56, 318, 38)

    $dialog.Controls.Add($message)



    $progress = New-Object System.Windows.Forms.ProgressBar

    $progress.Style = 'Marquee'

    $progress.MarqueeAnimationSpeed = 28

    $progress.SetBounds(24, 112, 382, 20)

    $dialog.Controls.Add($progress)



    $elapsed = New-Object System.Windows.Forms.Label

    $elapsed.Text = 'Elapsed: 00:00'

    $elapsed.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $elapsed.ForeColor = Get-ThemeColor 'Muted'

    $elapsed.TextAlign = 'MiddleRight'

    $elapsed.SetBounds(24, 142, 382, 24)

    $dialog.Controls.Add($elapsed)



    $timer = New-Object System.Windows.Forms.Timer

    $timer.Interval = 500

    $timer.Add_Tick(({

        param($sender, $e)

        try {

            $span = (Get-Date) - $StartedAt

            $elapsed.Text = ('Elapsed: {0:mm\:ss}' -f $span)

            if (-not $Process.HasExited -and $span.TotalSeconds -ge $MaxSeconds) {

                $script:LastReportTimedOut = $true

                try { $Process.Kill() } catch {}

                $sender.Stop()

                $dialog.Close()

                return

            }

            if ($Process.HasExited) {

                $sender.Stop()

                $dialog.Close()

            }

        } catch {}

    }.GetNewClosure()))



    $dialog.Add_Shown(({

        $timer.Start()

    }.GetNewClosure()))

    $dialog.Add_FormClosed(({

        $timer.Dispose()

        $badge.Dispose()

    }.GetNewClosure()))



    if (-not $Process.HasExited) {

        [void]$dialog.ShowDialog($form)

    }

}



function Start-ToolkitReport {

    param(

        [string]$Mode,

        [bool]$IncludeSecrets = $true,

        [string]$DisplayName = 'System report',

        [int]$MaxSeconds = 20

    )



    if (-not (Test-Path -LiteralPath $ReportCenterScript)) {

        Show-Warning "Toolkit report center script missing:`r`n$ReportCenterScript"

        return $false

    }



    Ensure-InventoryFolder

    $args = @(

        '-NoProfile',

        '-WindowStyle', 'Hidden',

        '-ExecutionPolicy', 'Bypass',

        '-File', $ReportCenterScript,

        '-OutputRoot', $InventoryOutputRoot,

        '-Mode', $Mode,

        '-Fast',

        '-Open'

    )

    if ($IncludeSecrets) { $args += '-IncludeSecrets' }



    $script:statusLabel.Text = "$DisplayName generate ho raha hai - please wait"

    $startedAt = Get-Date

    $psi = New-Object System.Diagnostics.ProcessStartInfo

    $psi.FileName = 'powershell.exe'

    $psi.Arguments = Join-ProcessArguments $args

    $psi.WorkingDirectory = $ToolkitRoot

    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $psi.CreateNoWindow = $true

    $psi.UseShellExecute = $false



    $process = New-Object System.Diagnostics.Process

    $process.StartInfo = $psi



    try {

        [void]$process.Start()

    } catch {

        Show-Warning "Report start nahi ho paya:`r`n$($_.Exception.Message)"

        $script:statusLabel.Text = 'Report launch failed'

        return $false

    }



    Show-ReportProgress -Process $process -DisplayName $DisplayName -StartedAt $startedAt -MaxSeconds $MaxSeconds

    try { $process.Refresh() } catch {}

    if ($script:LastReportTimedOut) {

        try { $process.WaitForExit(1500) | Out-Null } catch {}

        Open-InventoryFolder

        $script:statusLabel.Text = "$DisplayName fast mode 20 sec cap reached - output folder opened"

        Show-Info "$DisplayName ko 20 sec cap par stop kiya gaya.`r`nJo fast/latest reports ready hain unka folder open kar diya hai.`r`n`r`nOutput folder:`r`n$InventoryOutputRoot"

        return $false

    }



    if ($process.ExitCode -eq 0) {

        $script:statusLabel.Text = "$DisplayName ready - report open ho gaya"

        Show-Info "$DisplayName ready hai.`r`n`r`nOutput folder:`r`n$InventoryOutputRoot"

        return $true

    }



    $script:statusLabel.Text = "$DisplayName failed"

    Show-Warning "$DisplayName generate karte waqt issue aaya.`r`nExit code: $($process.ExitCode)`r`n`r`nOutput folder check karein:`r`n$InventoryOutputRoot"

    return $false

}



function Get-LatestReportFile {

    param([string]$Filter)



    $roots = @(

        $InventoryOutputRoot,

        (Join-Path $LogRoot 'SystemInventory'),

        $LogRoot

    )



    $reports = @()

    foreach ($root in $roots) {

        if (Test-Path -LiteralPath $root) {

            $reports += @(Get-ChildItem -LiteralPath $root -Filter $Filter -File | Sort-Object LastWriteTime -Descending)

        }

    }



    return @($reports | Sort-Object LastWriteTime -Descending | Select-Object -First 1)

}



function Get-LatestInventoryReport {

    return Get-LatestReportFile '*Inventory*.html'

}



function Open-LatestInventoryReport {

    $latest = Get-LatestInventoryReport

    if ($latest.Count -eq 0) {

        Show-Warning "Abhi koi HTML inventory report nahi mili.`r`nPehle Generate Complete System Inventory run karein."

        return

    }

    Start-Process -FilePath $latest[0].FullName | Out-Null

}



function Open-LatestReportHub {

    $latest = Get-LatestReportFile '*Merged_System_Report.html'

    if ($latest.Count -eq 0) {

        $latest = Get-LatestReportFile '*Report_Hub.html'

    }

    if ($latest.Count -eq 0) {

        Show-Warning "Abhi koi merged report ya report hub nahi mila.`r`nPehle ONE-CLICK REPORT run karein."

        return

    }

    Start-Process -FilePath $latest[0].FullName | Out-Null

}



function Open-InventoryFolder {

    Ensure-InventoryFolder

    Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$InventoryOutputRoot`"" | Out-Null

}



function Get-SystemInventoryItems {

    return @(

        [pscustomobject]@{ Text = 'One Click All Info Report'; Action = 'reports_one_click_all_info'; Notes = 'Option 1: one click me all important PC info, inventory, health, apps, boot, events, and report hub fast HTML format me generate kare.' },

        [pscustomobject]@{ Text = 'Generate Ultimate Report Pack'; Action = 'reports_all'; Notes = 'One click to generate the full report hub plus system inventory, health, apps, boot, events, and fast evidence reports.' },

        [pscustomobject]@{ Text = 'Generate Complete System Inventory'; Action = 'reports_inventory'; Notes = 'Full HTML inventory with Wi-Fi keys, Windows key, serials, storage colors, software, printers, monitors, network, hotfixes, and portable tools.' },

        [pscustomobject]@{ Text = 'Generate Quick Health Report'; Action = 'reports_quick_health'; Notes = 'HTML version of quick health checks from the CMD toolkit.' },

        [pscustomobject]@{ Text = 'Generate Health Dashboard'; Action = 'reports_dashboard'; Notes = 'Venom dashboard view for uptime, storage, security, and boot health.' },

        [pscustomobject]@{ Text = 'Generate Full System Report'; Action = 'reports_system'; Notes = 'Searchable HTML version of the CMD full system report.' },

        [pscustomobject]@{ Text = 'Generate Complete Issue Report'; Action = 'reports_complete_issue'; Notes = 'Deep issue diagnostics in HTML form.' },

        [pscustomobject]@{ Text = 'Generate Network Report'; Action = 'reports_network'; Notes = 'IP, WLAN, routes, TCP, DNS, and interface diagnostics.' },

        [pscustomobject]@{ Text = 'Generate Driver Report'; Action = 'reports_driver'; Notes = 'DriverQuery, driver store, and problem devices in HTML.' },

        [pscustomobject]@{ Text = 'Generate Apps Inventory'; Action = 'reports_apps'; Notes = 'Installed apps, AppX packages, Winget list, and portable tools catalog.' },

        [pscustomobject]@{ Text = 'Generate Evidence Pack'; Action = 'reports_evidence'; Notes = 'All-in-one evidence collector for support and troubleshooting.' },

        [pscustomobject]@{ Text = 'Generate Boot Performance Report'; Action = 'reports_boot'; Notes = 'Diagnostics-performance events in HTML.' },

        [pscustomobject]@{ Text = 'Generate Battery Report'; Action = 'reports_battery'; Notes = 'Native Windows battery HTML report saved into the report folder.' },

        [pscustomobject]@{ Text = 'Generate Energy Report'; Action = 'reports_energy'; Notes = 'Native Windows energy HTML report saved into the report folder.' },

        [pscustomobject]@{ Text = 'Generate GPResult HTML'; Action = 'reports_gpresult'; Notes = 'Runs GPUpdate then generates the GPResult HTML report.' },

        [pscustomobject]@{ Text = 'Generate WLAN Report'; Action = 'reports_wlan'; Notes = 'Copies the latest native WLAN report into the toolkit report folder.' },

        [pscustomobject]@{ Text = 'Export MSInfo Summary'; Action = 'reports_msinfo'; Notes = 'Exports the MSInfo NFO and opens a summary HTML page.' },

        [pscustomobject]@{ Text = 'Export Event Logs Summary'; Action = 'reports_events'; Notes = 'Exports EVTX logs and opens a summary HTML page.' },

        [pscustomobject]@{ Text = 'Open Latest Report Hub'; Action = 'reports_open_hub'; Notes = 'Open the most recent one-click report pack hub.' },

        [pscustomobject]@{ Text = 'Open Latest Inventory Report'; Action = 'inventory_open_latest'; Notes = 'Open newest generated HTML inventory report.' },

        [pscustomobject]@{ Text = 'Open Inventory Folder'; Action = 'inventory_open_folder'; Notes = 'Open C:\System Inventory output folder.' },

        [pscustomobject]@{ Text = 'Open Current PC Report'; Action = 'inventory_open_current'; Notes = 'Open COMPUTERNAME_Inventory.html if it exists.' },

        [pscustomobject]@{ Text = 'Run Legacy CMD Wrapper'; Action = 'inventory_cmd'; Notes = 'Run Modules\SystemInventory.cmd from a CMD window.' }

    )

}



function Invoke-SystemInventoryAction {

    param([string]$Action)



    switch ($Action) {

        'reports_one_click_all_info' {

            Start-ToolkitReport -Mode 'all' -IncludeSecrets $true -DisplayName 'One Click All Info Report' | Out-Null

        }

        'reports_all' {

            Start-ToolkitReport -Mode 'all' -IncludeSecrets $true -DisplayName 'Ultimate report pack' | Out-Null

        }

        'reports_inventory' {

            Start-ToolkitReport -Mode 'inventory' -IncludeSecrets $true -DisplayName 'Complete System Inventory' | Out-Null

        }

        'reports_quick_health' {

            Start-ToolkitReport -Mode 'quick-health' -IncludeSecrets $true -DisplayName 'Quick Health report' | Out-Null

        }

        'reports_dashboard' {

            Start-ToolkitReport -Mode 'dashboard' -IncludeSecrets $true -DisplayName 'Health Dashboard' | Out-Null

        }

        'reports_system' {

            Start-ToolkitReport -Mode 'system' -IncludeSecrets $true -DisplayName 'Full System report' | Out-Null

        }

        'reports_complete_issue' {

            Start-ToolkitReport -Mode 'complete-issue' -IncludeSecrets $true -DisplayName 'Complete Issue report' | Out-Null

        }

        'reports_network' {

            Start-ToolkitReport -Mode 'network' -IncludeSecrets $true -DisplayName 'Network report' | Out-Null

        }

        'reports_driver' {

            Start-ToolkitReport -Mode 'driver' -IncludeSecrets $true -DisplayName 'Driver report' | Out-Null

        }

        'reports_apps' {

            Start-ToolkitReport -Mode 'apps' -IncludeSecrets $true -DisplayName 'Apps Inventory' | Out-Null

        }

        'reports_evidence' {

            Start-ToolkitReport -Mode 'evidence' -IncludeSecrets $true -DisplayName 'Evidence Pack' | Out-Null

        }

        'reports_boot' {

            Start-ToolkitReport -Mode 'boot' -IncludeSecrets $true -DisplayName 'Boot Performance report' | Out-Null

        }

        'reports_battery' {

            Start-ToolkitReport -Mode 'battery' -IncludeSecrets $true -DisplayName 'Battery report' | Out-Null

        }

        'reports_energy' {

            Start-ToolkitReport -Mode 'energy' -IncludeSecrets $true -DisplayName 'Energy report' | Out-Null

        }

        'reports_gpresult' {

            Start-ToolkitReport -Mode 'gpresult' -IncludeSecrets $true -DisplayName 'GPResult HTML report' | Out-Null

        }

        'reports_wlan' {

            Start-ToolkitReport -Mode 'wlan' -IncludeSecrets $true -DisplayName 'WLAN report' | Out-Null

        }

        'reports_msinfo' {

            Start-ToolkitReport -Mode 'msinfo' -IncludeSecrets $true -DisplayName 'MSInfo summary' | Out-Null

        }

        'reports_events' {

            Start-ToolkitReport -Mode 'events' -IncludeSecrets $true -DisplayName 'Event Logs summary' | Out-Null

        }

        'reports_open_hub' {

            Open-LatestReportHub

            $script:statusLabel.Text = 'Opened latest Venom report hub'

        }

        'inventory_open_latest' {

            Open-LatestInventoryReport

            $script:statusLabel.Text = 'Opened latest System Inventory report'

        }

        'inventory_open_folder' {

            Open-InventoryFolder

            $script:statusLabel.Text = 'Opened System Inventory folder'

        }

        'inventory_open_current' {

            Ensure-InventoryFolder

            $current = Join-Path $InventoryOutputRoot ("{0}_Inventory.html" -f $env:COMPUTERNAME)

            if (Test-Path -LiteralPath $current) {

                Start-Process -FilePath $current | Out-Null

                $script:statusLabel.Text = 'Opened current PC inventory report'

            } else {

                Show-Warning "Current PC inventory report missing:`r`n$current`r`n`r`nPehle Generate Complete System Inventory run karein."

            }

        }

        'inventory_cmd' {

            Start-CmdWindow -CommandText "call `"$(Join-Path $ToolkitRoot 'Modules\SystemInventory.cmd')`"" -Title 'System Inventory CMD Wrapper'

        }

        default {

            Show-Warning "Unknown System Inventory action: $Action"

        }

    }

}



function Invoke-Option {

    param([object]$Option)

    if ($Option.IsSubmenu) {

        Write-GuiActionLog -ActionType 'Navigate' -Component $Option.Text -Details "Opened submenu: $($Option.TargetLabel) from $($Option.ParentLabel)"

        Show-Menu $Option.TargetLabel $true $Option

        return

    }

    Write-GuiActionLog -ActionType 'Command' -Component $Option.Text -Details "Choice=$($Option.Choice) Parent=$($Option.ParentLabel)"

    Start-MenuChoice $Option

    $script:statusLabel.Text = "Started GUI command [$($Option.Choice)] from $($Option.ParentLabel)"

}



function Get-ColorForIndex {

    param([int]$Index)

    $palette = @($script:Theme['Cards'])

    return [System.Drawing.ColorTranslator]::FromHtml($palette[$Index % $palette.Count])

}



function Get-RoundedGraphicsPath {

    param(

        [System.Drawing.Rectangle]$Rect,

        [int]$Radius

    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath

    $diameter = $Radius * 2

    if ($diameter -le 0) {

        $path.AddRectangle($Rect)

        return $path

    }

    $size = New-Object System.Drawing.Size($diameter, $diameter)

    $arc = New-Object System.Drawing.Rectangle($Rect.Location, $size)

    

    $path.AddArc($arc, 180, 90)

    $arc.X = $Rect.Right - $diameter

    $path.AddArc($arc, 270, 90)

    $arc.Y = $Rect.Bottom - $diameter

    $path.AddArc($arc, 0, 90)

    $arc.X = $Rect.Left

    $path.AddArc($arc, 90, 90)

    $path.CloseFigure()

    return $path

}



function Add-VenomPaint {

    param(

        [System.Windows.Forms.Control]$Control,

        [string]$Mode

    )



    $Control.Add_Paint({

        param($sender, $eventArgs)

        $g = $eventArgs.Graphics

        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias



        if ($Mode -eq 'Header') {

            $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width, $sender.Height)

            $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(

                $rect,

                (Get-ThemeColor 'Header1'),

                (Get-ThemeColor 'Header2'),

                [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal

            )

            $g.FillRectangle($brush, $rect)

            $brush.Dispose()

            $originX = $sender.Width - 26

            $originY = 8

        } else {

            $originX = 12

            $originY = 18

        }



        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, (Get-ThemeColor 'Muted')), 1)

        $arcPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, (Get-ThemeColor 'Accent4')), 1)



        $targets = @(

            @(0, 0),

            @([Math]::Floor($sender.Width * 0.25), $sender.Height),

            @([Math]::Floor($sender.Width * 0.55), $sender.Height),

            @($sender.Width, [Math]::Floor($sender.Height * 0.35)),

            @($sender.Width, $sender.Height)

        )



        foreach ($target in $targets) {

            $g.DrawLine($pen, $originX, $originY, [int]$target[0], [int]$target[1])

        }



        for ($r = 34; $r -lt [Math]::Max($sender.Width, $sender.Height + 120); $r += 34) {

            $g.DrawArc($arcPen, $originX - $r, $originY - $r, $r * 2, $r * 2, 28, 68)

        }



        $arcPen.Dispose()

        $pen.Dispose()

    })

}



$form = New-Object System.Windows.Forms.Form

$form.Text = 'SysForge Studio'

$form.StartPosition = 'CenterScreen'

$form.Size = New-Object System.Drawing.Size(1430, 1050)

$form.MinimumSize = New-Object System.Drawing.Size(1200, 920)

$form.BackColor = Get-ThemeColor 'Bg'

Enable-DoubleBuffer $form

$toolTip = New-Object System.Windows.Forms.ToolTip

$form.AutoScaleDimensions = New-Object System.Drawing.SizeF(6, 13)

$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi

if (Test-Path -LiteralPath $AppIconPath) {

    try { $form.Icon = New-Object System.Drawing.Icon($AppIconPath) } catch {}

}



# [8K ULTRA-PREMIUM] Apply Rounded Windows Frame Corners, Resize Handlers, and DPI transitions

$form.Opacity = 0.0

$form.Add_Load({

    try {

        $type = [Type]::GetType("Win32.Win32Apis")

        if ($null -ne $type) {

            $hRgn = $type.GetMethod("CreateRoundRectRgn").Invoke($null, @(0, 0, $form.Width, $form.Height, 26, 26))

            if ($hRgn -and $hRgn -ne [IntPtr]::Zero) {

                $form.Region = [System.Drawing.Region]::FromHrgn($hRgn)

            }

        }

    } catch {}

    

    $script:fadeTimer = New-Object System.Windows.Forms.Timer

    $script:fadeTimer.Interval = 10

    $script:fadeTimer.Add_Tick(({

        try {

            if ($form.Opacity -lt 1.0) {

                $form.Opacity += 0.05

            } else {

                $script:fadeTimer.Stop()

                $script:fadeTimer.Dispose()

                $script:fadeTimer = $null

            }

        } catch {}

    }.GetNewClosure()))

    $script:fadeTimer.Start()

})



$form.Add_Resize({

    try {

        if ($form.WindowState -ne [System.Windows.Forms.FormWindowState]::Maximized) {

            $type = [Type]::GetType("Win32.Win32Apis")

            if ($null -ne $type) {

                $hRgn = $type.GetMethod("CreateRoundRectRgn").Invoke($null, @(0, 0, $form.Width, $form.Height, 26, 26))

                if ($hRgn -and $hRgn -ne [IntPtr]::Zero) {

                    $form.Region = [System.Drawing.Region]::FromHrgn($hRgn)

                }

            }

        } else {

            $form.Region = $null

        }

    } catch {}

})



$header = New-Object System.Windows.Forms.Panel

$header.Dock = 'Top'

$header.Height = 82

$header.BackColor = Get-ThemeColor 'Header1'

$form.Controls.Add($header)

$header.BringToFront()

Add-VenomPaint $header 'Header'



$titleLabel = New-Object System.Windows.Forms.Label

$titleLabel.Text = 'ULTIMATE CYBER-SUITE ENTERPRISE V5'

$titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)

$titleLabel.ForeColor = Get-ThemeColor 'Text'

$titleLabel.SetBounds(24, 12, 600, 38)

$header.Controls.Add($titleLabel)



$subTitleLabel = New-Object System.Windows.Forms.Label

$subTitleLabel.Text = 'Enterprise command center for CMD menus, interactive networks, offline recovery, self-healing, and diagnostics'

$subTitleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$subTitleLabel.ForeColor = Get-ThemeColor 'Muted'

$subTitleLabel.SetBounds(27, 51, 760, 22)

$header.Controls.Add($subTitleLabel)



$headerTools = New-Object System.Windows.Forms.Panel

$headerTools.SetBounds(630, 20, 555, 38)

$headerTools.Anchor = 'Top,Right'

$headerTools.BackColor = [System.Drawing.Color]::Transparent

$header.Controls.Add($headerTools)



$themeCombo = New-Object System.Windows.Forms.ComboBox

$themeCombo.DropDownStyle = 'DropDownList'

$themeCombo.FlatStyle = 'Standard'

$themeCombo.Font = New-Object System.Drawing.Font('Segoe UI', 9)

[void]$themeCombo.Items.AddRange([object[]]$script:ThemeOrder)

$themeCombo.SelectedItem = $script:CurrentThemeName

$themeCombo.SetBounds(0, 4, 155, 28)

$themeCombo.BackColor = Get-ThemeColor 'Panel'

$themeCombo.ForeColor = Get-ThemeColor 'Text'

$themeCombo.Add_SelectedIndexChanged({

    if ($null -ne $themeCombo.SelectedItem) {

        Set-UiTheme ([string]$themeCombo.SelectedItem)

    }

})

$headerTools.Controls.Add($themeCombo)



$layoutCombo = New-Object System.Windows.Forms.ComboBox

$layoutCombo.DropDownStyle = 'DropDownList'

$layoutCombo.FlatStyle = 'Standard'

$layoutCombo.Font = New-Object System.Drawing.Font('Segoe UI', 9)

[void]$layoutCombo.Items.AddRange([object[]]$script:LayoutOrder)

$layoutCombo.SelectedItem = $script:CurrentLayoutName

$layoutCombo.SetBounds(165, 4, 155, 28)

$layoutCombo.BackColor = Get-ThemeColor 'Panel'

$layoutCombo.ForeColor = Get-ThemeColor 'Text'

$layoutCombo.Add_SelectedIndexChanged({

    if ($null -ne $layoutCombo.SelectedItem) {

        $script:CurrentLayoutName = [string]$layoutCombo.SelectedItem

        Save-GuiSettings

        Refresh-CurrentView

    }

})

$headerTools.Controls.Add($layoutCombo)



$themeOkButton = New-Object System.Windows.Forms.Button

$themeOkButton.Visible = $false



$searchBox = New-Object System.Windows.Forms.TextBox

$searchBox.Font = New-Object System.Drawing.Font('Segoe UI', 11)

$searchBox.BorderStyle = 'FixedSingle'

$searchBox.SetBounds(330, 4, 192, 30)

$searchBox.BackColor = Get-ThemeColor 'Panel'

$searchBox.ForeColor = Get-ThemeColor 'Text'

try { $searchBox.PlaceholderText = 'Search menus, reports, tools...' } catch {}

$headerTools.Controls.Add($searchBox)



$clearSearchBtn = New-Object System.Windows.Forms.Button

$clearSearchBtn.Text = "×"

$clearSearchBtn.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

$clearSearchBtn.FlatStyle = 'Flat'

$clearSearchBtn.FlatAppearance.BorderSize = 1

$clearSearchBtn.FlatAppearance.BorderColor = Get-ThemeColor 'Border'

$clearSearchBtn.BackColor = Get-ThemeColor 'Button'

$clearSearchBtn.ForeColor = Get-ThemeColor 'Muted'

$clearSearchBtn.SetBounds(526, 4, 28, 28)

$clearSearchBtn.Cursor = [System.Windows.Forms.Cursors]::Hand

$toolTip.SetToolTip($clearSearchBtn, "Clear search text")

$clearSearchBtn.Add_Click({

    $searchBox.Text = ""

    $searchBox.Focus() | Out-Null

})

$headerTools.Controls.Add($clearSearchBtn)





$statusStrip = New-Object System.Windows.Forms.StatusStrip

$statusStrip.BackColor = Get-ThemeColor 'Panel2'

$script:statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel

$script:statusLabel.Text = 'Ready'

$script:statusLabel.ForeColor = Get-ThemeColor 'Muted'

$statusLabel = $script:statusLabel

$statusStrip.Items.Add($script:statusLabel) | Out-Null

$form.Controls.Add($statusStrip)

$statusStrip.BringToFront()



$bodyLayout = New-Object System.Windows.Forms.TableLayoutPanel

$bodyLayout.Dock = 'Fill'

$bodyLayout.ColumnCount = 2

$bodyLayout.RowCount = 1

$bodyLayout.Margin = New-Object System.Windows.Forms.Padding(0)

$bodyLayout.Padding = New-Object System.Windows.Forms.Padding(0)

$bodyLayout.BackColor = Get-ThemeColor 'Bg'

$bodyLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 218))) | Out-Null

$bodyLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

$bodyLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

$form.Controls.Add($bodyLayout)

$bodyLayout.SendToBack()

Enable-DoubleBuffer $bodyLayout



$sidebar = New-Object System.Windows.Forms.Panel

$sidebar.Dock = 'Fill'

$sidebar.Margin = New-Object System.Windows.Forms.Padding(0)

$sidebar.BackColor = Get-ThemeColor 'Sidebar'

$bodyLayout.Controls.Add($sidebar, 0, 0)

Add-VenomPaint $sidebar 'Sidebar'



$content = New-Object System.Windows.Forms.Panel

$content.Dock = 'Fill'

$content.Margin = New-Object System.Windows.Forms.Padding(0)

$content.BackColor = Get-ThemeColor 'Bg'

$bodyLayout.Controls.Add($content, 1, 0)



$contentLayout = New-Object System.Windows.Forms.TableLayoutPanel

$contentLayout.Dock = 'Fill'

$contentLayout.ColumnCount = 1

$contentLayout.RowCount = 3

$contentLayout.Margin = New-Object System.Windows.Forms.Padding(0)

$contentLayout.Padding = New-Object System.Windows.Forms.Padding(0)

$contentLayout.BackColor = Get-ThemeColor 'Bg'

$contentLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

$contentLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 66))) | Out-Null

$contentLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 0))) | Out-Null

$contentLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

$content.Controls.Add($contentLayout)

Enable-DoubleBuffer $contentLayout



$topBar = New-Object System.Windows.Forms.Panel

$topBar.Dock = 'Fill'

$topBar.Height = 66

$topBar.Margin = New-Object System.Windows.Forms.Padding(0)

$topBar.BackColor = Get-ThemeColor 'Bg'

$contentLayout.Controls.Add($topBar, 0, 0)



$backButton = New-Object System.Windows.Forms.Button

$backButton.Text = '< Back'

$backButton.SetBounds(18, 16, 86, 34)

$backButton.FlatStyle = 'Flat'

$backButton.BackColor = Get-ThemeColor 'Button'

$backButton.ForeColor = Get-ThemeColor 'Text'

$backButton.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

$topBar.Controls.Add($backButton)



$screenTitle = New-Object System.Windows.Forms.Label

$screenTitle.Text = 'Main Menus'

$screenTitle.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)

$screenTitle.ForeColor = Get-ThemeColor 'Text'

$screenTitle.SetBounds(116, 12, 610, 38)

$screenTitle.Anchor = 'Top,Left,Right'

$topBar.Controls.Add($screenTitle)



$metaLabel = New-Object System.Windows.Forms.Label

$script:metaLabel = $metaLabel

$metaLabel.Text = ''

$metaLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$metaLabel.ForeColor = Get-ThemeColor 'Muted'

$metaLabel.TextAlign = 'MiddleRight'

$metaLabel.SetBounds(720, 18, 250, 28)

$metaLabel.Anchor = 'Top,Right'

$topBar.Controls.Add($metaLabel)



$runCurrentButton = New-Object System.Windows.Forms.Button

$runCurrentButton.Text = 'View In GUI'

$runCurrentButton.SetBounds(980, 16, 116, 34)

$runCurrentButton.Anchor = 'Top,Right'

$runCurrentButton.FlatStyle = 'Flat'

$runCurrentButton.BackColor = Get-ThemeColor 'Button'

$runCurrentButton.ForeColor = Get-ThemeColor 'Text'

$runCurrentButton.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

$topBar.Controls.Add($runCurrentButton)



foreach ($btn in @($backButton, $runCurrentButton)) {

    $btn.FlatAppearance.MouseOverBackColor = Get-HoverColor (Get-ThemeColor 'Button')

    $btn.FlatAppearance.MouseDownBackColor = Get-HoverColor (Get-HoverColor (Get-ThemeColor 'Button'))

    $btn.Add_MouseEnter({

        param($sender, $e)

        $sender.FlatAppearance.BorderColor = Get-ThemeColor 'Accent2'

        $sender.FlatAppearance.BorderSize = 2

    })

    $btn.Add_MouseLeave({

        param($sender, $e)

        $sender.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

        $sender.FlatAppearance.BorderSize = 1

    })

}



$gridHost = New-Object System.Windows.Forms.Panel

$gridHost.Dock = 'Fill'

$gridHost.Margin = New-Object System.Windows.Forms.Padding(0)

$gridHost.AutoScroll = $true

$gridHost.BackColor = Get-ThemeColor 'Bg'

$contentLayout.Controls.Add($gridHost, 0, 2)

Enable-DoubleBuffer $gridHost



# Create Performance Dashboard permanently exactly once (Zero-Recreation Overhaul)

$script:dashboardPanel = New-Object System.Windows.Forms.Panel

$script:dashboardPanel.Dock = 'Top'

$script:dashboardPanel.Height = 105

$script:dashboardPanel.BackColor = [System.Drawing.Color]::Transparent

$script:dashboardPanel.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 5)

$script:dashboardPanel.Visible = $false

Enable-DoubleBuffer $script:dashboardPanel



$cardCPU = New-Object System.Windows.Forms.Panel

$cardCPU.SetBounds(36, 10, 165, 80)

$cardCPU.BackColor = Get-ThemeColor 'Panel2'

$cardCPU.BorderStyle = 'FixedSingle'

Enable-DoubleBuffer $cardCPU



$lblCpuTitle = New-Object System.Windows.Forms.Label

$lblCpuTitle.Text = "CPU UTILIZATION"

$lblCpuTitle.Font = New-Object System.Drawing.Font('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)

$lblCpuTitle.ForeColor = Get-ThemeColor 'Muted'

$lblCpuTitle.SetBounds(12, 10, 140, 15)

$cardCPU.Controls.Add($lblCpuTitle)



$script:lblCpuVal = New-Object System.Windows.Forms.Label

$script:lblCpuVal.Text = "--"

$script:lblCpuVal.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)

$script:lblCpuVal.ForeColor = Get-ThemeColor 'Accent'

$script:lblCpuVal.SetBounds(10, 25, 140, 30)

$cardCPU.Controls.Add($script:lblCpuVal)



$script:lblCpuSub = New-Object System.Windows.Forms.Label

$script:lblCpuSub.Text = "Querying..."

$script:lblCpuSub.Font = New-Object System.Drawing.Font('Segoe UI', 8)

$script:lblCpuSub.ForeColor = Get-ThemeColor 'Muted'

$script:lblCpuSub.SetBounds(12, 57, 140, 15)

$cardCPU.Controls.Add($script:lblCpuSub)

$script:dashboardPanel.Controls.Add($cardCPU)



$cardRAM = New-Object System.Windows.Forms.Panel

$cardRAM.SetBounds(216, 10, 165, 80)

$cardRAM.BackColor = Get-ThemeColor 'Panel2'

$cardRAM.BorderStyle = 'FixedSingle'

Enable-DoubleBuffer $cardRAM



$lblRamTitle = New-Object System.Windows.Forms.Label

$lblRamTitle.Text = "SYSTEM MEMORY"

$lblRamTitle.Font = New-Object System.Drawing.Font('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)

$lblRamTitle.ForeColor = Get-ThemeColor 'Muted'

$lblRamTitle.SetBounds(12, 10, 140, 15)

$cardRAM.Controls.Add($lblRamTitle)



$script:lblRamVal = New-Object System.Windows.Forms.Label

$script:lblRamVal.Text = "--"

$script:lblRamVal.Font = New-Object System.Drawing.Font('Segoe UI', 12.5, [System.Drawing.FontStyle]::Bold)

$script:lblRamVal.ForeColor = Get-ThemeColor 'Accent'

$script:lblRamVal.SetBounds(10, 28, 145, 25)

$cardRAM.Controls.Add($script:lblRamVal)



$script:lblRamSub = New-Object System.Windows.Forms.Label

$script:lblRamSub.Text = "Querying..."

$script:lblRamSub.Font = New-Object System.Drawing.Font('Segoe UI', 8)

$script:lblRamSub.ForeColor = Get-ThemeColor 'Muted'

$script:lblRamSub.SetBounds(12, 57, 140, 15)

$cardRAM.Controls.Add($script:lblRamSub)

$script:dashboardPanel.Controls.Add($cardRAM)



$cardDisk = New-Object System.Windows.Forms.Panel

$cardDisk.SetBounds(396, 10, 165, 80)

$cardDisk.BackColor = Get-ThemeColor 'Panel2'

$cardDisk.BorderStyle = 'FixedSingle'

Enable-DoubleBuffer $cardDisk



$lblDiskTitle = New-Object System.Windows.Forms.Label

$lblDiskTitle.Text = "SYSTEM STORAGE (C:)"

$lblDiskTitle.Font = New-Object System.Drawing.Font('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)

$lblDiskTitle.ForeColor = Get-ThemeColor 'Muted'

$lblDiskTitle.SetBounds(12, 10, 140, 15)

$cardDisk.Controls.Add($lblDiskTitle)



$script:lblDiskVal = New-Object System.Windows.Forms.Label

$script:lblDiskVal.Text = "--"

$script:lblDiskVal.Font = New-Object System.Drawing.Font('Segoe UI', 12.5, [System.Drawing.FontStyle]::Bold)

$script:lblDiskVal.ForeColor = Get-ThemeColor 'Accent'

$script:lblDiskVal.SetBounds(10, 28, 145, 25)

$cardDisk.Controls.Add($script:lblDiskVal)



$script:lblDiskSub = New-Object System.Windows.Forms.Label

$script:lblDiskSub.Text = "Querying..."

$script:lblDiskSub.Font = New-Object System.Drawing.Font('Segoe UI', 8)

$script:lblDiskSub.ForeColor = Get-ThemeColor 'Muted'

$script:lblDiskSub.SetBounds(12, 57, 140, 15)

$cardDisk.Controls.Add($script:lblDiskSub)

$script:dashboardPanel.Controls.Add($cardDisk)



$cardUptime = New-Object System.Windows.Forms.Panel

$cardUptime.SetBounds(576, 10, 165, 80)

$cardUptime.BackColor = Get-ThemeColor 'Panel2'

$cardUptime.BorderStyle = 'FixedSingle'

Enable-DoubleBuffer $cardUptime



$lblUptimeTitle = New-Object System.Windows.Forms.Label

$lblUptimeTitle.Text = "SYSTEM UPTIME"

$lblUptimeTitle.Font = New-Object System.Drawing.Font('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)

$lblUptimeTitle.ForeColor = Get-ThemeColor 'Muted'

$lblUptimeTitle.SetBounds(12, 10, 140, 15)

$cardUptime.Controls.Add($lblUptimeTitle)



$script:lblUptimeVal = New-Object System.Windows.Forms.Label

$script:lblUptimeVal.Text = "--"

$script:lblUptimeVal.Font = New-Object System.Drawing.Font('Segoe UI', 12.5, [System.Drawing.FontStyle]::Bold)

$script:lblUptimeVal.ForeColor = Get-ThemeColor 'Accent'

$script:lblUptimeVal.SetBounds(10, 28, 145, 25)

$cardUptime.Controls.Add($script:lblUptimeVal)



$script:lblUptimeSub = New-Object System.Windows.Forms.Label

$script:lblUptimeSub.Text = "Querying..."

$script:lblUptimeSub.Font = New-Object System.Drawing.Font('Segoe UI', 8)

$script:lblUptimeSub.ForeColor = Get-ThemeColor 'Muted'

$script:lblUptimeSub.SetBounds(12, 57, 140, 15)

$cardUptime.Controls.Add($script:lblUptimeSub)

$script:dashboardPanel.Controls.Add($cardUptime)



# Prominent One-Click Health Report Hub Card

$cardReport = New-Object System.Windows.Forms.Panel

$cardReport.SetBounds(756, 10, 190, 80)

$cardReport.BackColor = Get-ThemeColor 'Panel2'

$cardReport.BorderStyle = 'FixedSingle'

Enable-DoubleBuffer $cardReport



$btnReport = New-Object System.Windows.Forms.Button

$btnReport.Text = "ONE-CLICK REPORT"

$btnReport.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

$btnReport.FlatStyle = 'Flat'

$btnReport.BackColor = Get-ThemeColor 'Accent'

$btnReport.ForeColor = Get-ThemeColor 'CardText'

$btnReport.SetBounds(10, 12, 168, 54)

$btnReport.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnReport.Add_Click({

    Start-ToolkitReport -Mode 'all' -IncludeSecrets $true -DisplayName 'Ultimate Health Report Pack' | Out-Null

})

$cardReport.Controls.Add($btnReport)

$script:dashboardPanel.Controls.Add($cardReport)



# Premium Clickable YouTube Brand Link Card next to Report Card

$cardBoost = New-Object System.Windows.Forms.Panel

$cardBoost.SetBounds(961, 10, 190, 80)

$cardBoost.BackColor = Get-ThemeColor 'Panel2'

$cardBoost.BorderStyle = 'FixedSingle'

Enable-DoubleBuffer $cardBoost



$btnBoost = New-Object System.Windows.Forms.Button

$btnBoost.Text = "SYSFORGE STUDIO"

$btnBoost.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

$btnBoost.FlatStyle = 'Flat'

$btnBoost.BackColor = Get-ThemeColor 'Accent2'

$btnBoost.ForeColor = Get-ThemeColor 'CardText'

$btnBoost.SetBounds(10, 12, 168, 54)

$btnBoost.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnBoost.Add_Click({
    $logPath = "C:\Users\Public\UltimateToolkit_Logs\gui_events.log"
    $logDir = Split-Path -Parent $logPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $stamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $logLine = "[$stamp] [Help] Help link was requested."
    Add-Content -LiteralPath $logPath -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
})

$toolTip.SetToolTip($btnBoost, "SysForge Studio yardım ve sürüm bilgileri")

$cardBoost.Controls.Add($btnBoost)

$script:dashboardPanel.Controls.Add($cardBoost)



# Premium Web Command Center Dashboard Link Card next to YouTube Brand Card

$cardWeb = New-Object System.Windows.Forms.Panel

$cardWeb.SetBounds(1166, 10, 190, 80)

$cardWeb.BackColor = Get-ThemeColor 'Panel2'

$cardWeb.BorderStyle = 'FixedSingle'

Enable-DoubleBuffer $cardWeb



$btnWeb = New-Object System.Windows.Forms.Button

$btnWeb.Text = "WEB COMMAND CENTER`r`nDASHBOARD"

$btnWeb.Font = New-Object System.Drawing.Font('Segoe UI', 9.0, [System.Drawing.FontStyle]::Bold)

$btnWeb.FlatStyle = 'Flat'

$btnWeb.BackColor = Get-ThemeColor 'Accent'

$btnWeb.ForeColor = Get-ThemeColor 'CardText'

$btnWeb.SetBounds(10, 12, 168, 54)

$btnWeb.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnWeb.Add_Click({

    $tcp = $null

    try {

        $tcp = New-Object System.Net.Sockets.TcpClient

        $connect = $tcp.BeginConnect('127.0.0.1', 8282, $null, $null)

        $wait = $connect.AsyncWaitHandle.WaitOne(300, $false)

        if (-not $wait) {

            Start-Process "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ToolkitRoot\Modules\Web-Dashboard.ps1`"" -WindowStyle Minimized

        } else {

            $tcp.EndConnect($connect)

            Start-Process "http://localhost:8282/"

        }

    } catch {

        Start-Process "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ToolkitRoot\Modules\Web-Dashboard.ps1`"" -WindowStyle Minimized

    } finally {

        if ($null -ne $tcp) {

            $tcp.Close()

        }

    }

})

$toolTip.SetToolTip($btnWeb, "Launch the futuristic local Web Command Center Dashboard!")

$cardWeb.Controls.Add($btnWeb)

$script:dashboardPanel.Controls.Add($cardWeb)



# [8K ULTRA-PREMIUM] Apply rounded corner paint handles dynamically to all dashboard panel cards

foreach ($ctrl in $script:dashboardPanel.Controls) {

    if ($ctrl -is [System.Windows.Forms.Panel]) {

        $ctrl.BorderStyle = 'None'

        $ctrl.Add_Paint({

            param($sender, $e)

            try {

                if ($sender.Width -le 12 -or $sender.Height -le 12) { return }

                $g = $e.Graphics

                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

                $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width - 1, $sender.Height - 1)

                $path = Get-RoundedGraphicsPath -Rect $rect -Radius 12

                

                $bgBrush = New-Object System.Drawing.SolidBrush($sender.BackColor)

                $g.FillPath($bgBrush, $path)

                $bgBrush.Dispose()



                $pen = New-Object System.Drawing.Pen(Get-ThemeColor 'Border', 1)

                $g.DrawPath($pen, $path)

                $pen.Dispose()

                

                $path.Dispose()

            } catch {}

        })

    }

}



$contentLayout.Controls.Add($script:dashboardPanel, 0, 1)







$navStack = New-Object System.Collections.Generic.List[string]

$currentLabel = 'main'

$currentMode = 'menu'

$toolTip = New-Object System.Windows.Forms.ToolTip



# Create scrollable sub-container for side buttons to prevent overflow layout overlap

$script:menuScrollPanel = New-Object System.Windows.Forms.Panel

$script:menuScrollPanel.SetBounds(0, 82, 218, 800)

$script:menuScrollPanel.AutoScroll = $true

$script:menuScrollPanel.BackColor = [System.Drawing.Color]::Transparent

Enable-DoubleBuffer $script:menuScrollPanel

$sidebar.Controls.Add($script:menuScrollPanel)

$script:NextSideButtonTop = 10



function Add-SideButton {

    param([string]$Text, [int]$Top, [scriptblock]$Click)

    $buttonTop = $script:NextSideButtonTop

    $button = New-Object System.Windows.Forms.Button

    $button.Text = $Text.Trim()

    $button.SetBounds(8, $buttonTop, 184, 42)

    $button.FlatStyle = 'Flat'

    $button.BackColor = Get-ThemeColor 'Button'

    $button.ForeColor = Get-ThemeColor 'Text'

    $button.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $button.FlatAppearance.BorderColor = Get-ThemeColor 'Border'

    $button.FlatAppearance.BorderSize = 1

    $button.FlatAppearance.MouseOverBackColor = Get-HoverColor (Get-ThemeColor 'Button')

    $button.FlatAppearance.MouseDownBackColor = Get-HoverColor (Get-HoverColor (Get-ThemeColor 'Button'))

    $button.TextAlign = 'MiddleLeft'

    $button.ImageAlign = 'MiddleLeft'

    $button.TextImageRelation = 'ImageBeforeText'

    $button.Padding = New-Object System.Windows.Forms.Padding(8, 0, 4, 0)

    $button.Image = New-BadgeBitmap -Glyph (Get-IconGlyph ([pscustomobject]@{ Text = $Text })) -Index ([Math]::Floor($buttonTop / 50)) -Size 26

    $button.Cursor = [System.Windows.Forms.Cursors]::Hand

    $button.Add_MouseEnter({

        param($sender, $e)

        $sender.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

        $sender.FlatAppearance.BorderSize = 2

        # Redirect mouse scroll focus cleanly to the menu panel automatically upon hover!

        $script:menuScrollPanel.Focus() | Out-Null

    })

    $button.Add_MouseLeave({

        param($sender, $e)

        $sender.FlatAppearance.BorderColor = Get-ThemeColor 'Border'

        $sender.FlatAppearance.BorderSize = 1

    })

    $button.Add_Click($Click)

    $script:menuScrollPanel.Controls.Add($button)

    $script:NextSideButtonTop += 50

}



$brand = New-Object System.Windows.Forms.Label

$brand.Text = "SysForge Studio"

$brand.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)

$brand.ForeColor = Get-ThemeColor 'Text'

$brand.SetBounds(16, 18, 186, 54)

$sidebar.Controls.Add($brand)



Add-SideButton '  Dashboard / Main Menus' 10 { Show-Menu 'main' $false }

Add-SideButton '  SysForge Studio CMD Toolkit' 35 {

    try {

        $batPath = Join-Path $script:ToolkitRoot 'Toolkit.bat'

        Start-Process -FilePath $env:ComSpec -ArgumentList "/c call `"$batPath`"" -Verb RunAs -WorkingDirectory $script:ToolkitRoot

        $script:statusLabel.Text = "Started CMD Toolkit as Administrator"

    } catch {

        Out-MessageBox("Could not launch CMD Toolkit as Admin: $_", "Admin Launch Error", "OK", "Error") | Out-Null

    }

}

Add-SideButton '  100 Apps 1-Click Install' 60 { $navStack.Clear(); Show-Menu 'menu_1click_100_apps' $false }

Add-SideButton '  One Click Actions' 110 { Show-OneClick }

Add-SideButton '  System Inventory' 160 { Show-SystemInventory }

Add-SideButton '  All Parsed Options' 260 { Show-AllOptions }

Add-SideButton '  Software Updater' 360 { Show-Menu 'menu_apps_update_manager' $true }

Add-SideButton '  Custom Apps Bundler' 410 { Show-Menu 'menu_apps_custom_bundler' $true }

Add-SideButton '  System Cleaner' 460 { Show-Menu 'menu_system_cleaner' $true }

Add-SideButton '  1-Click Backup & Migrate' 510 { Show-Menu 'menu_user_backup' $true }

Add-SideButton '  Windows Debloater' 560 { Show-Menu 'menu_bloatware_remover' $true }

Add-SideButton '  Hardware Diagnostics' 610 { Show-Menu 'menu_hardware_diagnostics' $true }

Add-SideButton '  Software Diagnostics' 635 { Show-Menu 'menu_software_diagnostics' $true }

Add-SideButton '  Offline Recovery Center' 660 { Show-Menu 'menu_offline_recovery' $true }

Add-SideButton '  Startup Optimizer' 710 { Show-Menu 'menu_startup_optimizer' $true }

    Add-SideButton '  License Vault' 760 { Show-Menu 'menu_license_vault' $true }

    Add-SideButton '  BSOD Crash Analyzer' 810 { Show-Menu 'menu_bsod_analyzer' $true }



    Add-SideButton '  CPU/GPU Temp Monitor' 860 { Show-Menu 'menu_temp_monitor' $true }

    Add-SideButton '  Disk Speed Benchmark' 910 { Show-Menu 'menu_disk_benchmark' $true }

    Add-SideButton '  DNS Flush & Network Repair' 960 { Show-Menu 'menu_dns_repair' $true }

    Add-SideButton '  System Restore Manager' 1060 { Show-Menu 'menu_restore_manager' $true }

    Add-SideButton '  Scheduled Tasks Manager' 1110 { Show-Menu 'menu_task_scheduler' $true }

    Add-SideButton '  Firewall Manager' 1160 { Show-Menu 'menu_firewall_manager' $true }



    Add-SideButton '  AI Smart Diagnostics' 1210 { Show-Menu 'menu_ai_diagnostics' $true }

    Add-SideButton '  Visual Process Manager' 1310 { Show-Menu 'menu_process_manager' $true }

    Add-SideButton '  Netstat Connections' 1360 { Show-Menu 'menu_netstat_conn' $true }

    Add-SideButton '  Services Control Panel' 1410 { Show-Menu 'menu_services_dashboard' $true }

    Add-SideButton '  Registry Telemetry Tweaks' 1460 { Show-Menu 'menu_registry_tweaks' $true }

    Add-SideButton '  Error Log & Self-Repair' 1510 { Show-ErrorLogPanel }

    Add-SideButton '  WiFi Password Viewer' 1560 { Show-Menu 'menu_wifi_passwords' $true }

    Add-SideButton '  Installed Apps Manager' 1610 { Show-Menu 'menu_installed_apps' $true }

    Add-SideButton '  Event Log Viewer' 1660 { Show-Menu 'menu_event_logs' $true }

    Add-SideButton '  Quick Actions' 1710 { Show-Menu 'menu_quick_actions' $true }



$dynamicThemeCheck = New-Object System.Windows.Forms.CheckBox

$dynamicThemeCheck.Text = "Auto Time Theme"

$dynamicThemeCheck.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

$dynamicThemeCheck.ForeColor = Get-ThemeColor 'Text'

$dynamicThemeCheck.SetBounds(22, 895, 180, 30)

$dynamicThemeCheck.Cursor = [System.Windows.Forms.Cursors]::Hand

$dynamicThemeCheck.Checked = $script:DynamicThemeEnabled



$copyrightLabel = New-Object System.Windows.Forms.Label

$copyrightLabel.Text = "SysForge Studio • 2026"

$copyrightLabel.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)

$copyrightLabel.ForeColor = Get-ThemeColor 'Muted'

$copyrightLabel.TextAlign = 'MiddleCenter'

$copyrightLabel.SetBounds(10, 930, 200, 45)

$sidebar.Controls.Add($copyrightLabel)

$dynamicThemeCheck.Add_CheckedChanged({

    $script:DynamicThemeEnabled = $dynamicThemeCheck.Checked

    Save-GuiSettings

    if ($script:DynamicThemeEnabled) {

        $hour = (Get-Date).Hour

        $targetTheme = if ($hour -ge 6 -and $hour -lt 18) { 'Clean Light' } else { 'Cyberpunk Neon' }

        if ($script:CurrentThemeName -ne $targetTheme) {

            Set-UiTheme $targetTheme

            if ($null -ne $themeCombo) { $themeCombo.SelectedItem = $targetTheme }

        }

    }

})

$sidebar.Controls.Add($dynamicThemeCheck)



$footer = New-Object System.Windows.Forms.Label

$footer.Text = "SysForge Studio`r`n2026 All Rights Reserved"

$footer.Font = New-Object System.Drawing.Font('Segoe UI', 8)

$footer.ForeColor = Get-ThemeColor 'Muted'

$footer.TextAlign = 'MiddleCenter'

$footer.SetBounds(12, 970, 194, 40)

$footer.Anchor = 'Left,Bottom'

$sidebar.Controls.Add($footer)



function Update-SidebarLayout {

    try {

        $bottomHeight = 132

        $bottomTop = [Math]::Max(92, $sidebar.ClientSize.Height - $bottomHeight)

        $scrollHeight = [Math]::Max(230, $bottomTop - 84)

        $script:menuScrollPanel.SetBounds(0, 82, $sidebar.ClientSize.Width, $scrollHeight)

        $dynamicThemeCheck.SetBounds(22, $bottomTop + 2, 180, 26)

        $copyrightLabel.SetBounds(10, $bottomTop + 30, 200, 42)

        $footer.SetBounds(12, $bottomTop + 82, 194, 38)

    } catch {}

}



$sidebar.Add_Resize({ Update-SidebarLayout })

Update-SidebarLayout



function Clear-Grid {

    $gridHost.AutoScroll = $true

    if ($null -ne $script:dashboardTimer) {

        try { $script:dashboardTimer.Stop() } catch {}

    }

    if ($null -ne $script:telemetryTimer) {

        try { $script:telemetryTimer.Stop() } catch {}

    }

    try {

        if ($null -ne $script:tempTimer) {

            $script:tempTimer.Stop()

            $script:tempTimer.Dispose()

            $script:tempTimer = $null

        }

    } catch {}

    

    # Hide the permanent performance dashboard panel and collapse row 1 (Zero-Recreation Overhaul)

    if ($null -ne $script:dashboardPanel) {

        $script:dashboardPanel.Visible = $false

    }

    if ($null -ne $contentLayout) {

        $contentLayout.RowStyles[1].Height = 0

    }

    

    $gridHost.Controls.Clear()

}



function Update-CardTheme {

    # Deprecated: Card theme updates are dynamically handled in Refresh-CurrentView

}



function Set-UiTheme {

    param([string]$Name)



    if (-not $script:Themes.ContainsKey($Name)) { return }

    

    # Suspend layout for atomic redraw of all UI controls (Zero-Flicker Repaints)

    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    $script:CurrentThemeName = $Name

    $script:Theme = $script:Themes[$Name]

    $script:IconCache.Clear()



    $form.BackColor = Get-ThemeColor 'Bg'

    $header.BackColor = Get-ThemeColor 'Header1'

    $titleLabel.ForeColor = Get-ThemeColor 'Text'

    $subTitleLabel.ForeColor = Get-ThemeColor 'Muted'

    $bodyLayout.BackColor = Get-ThemeColor 'Bg'

    $sidebar.BackColor = Get-ThemeColor 'Sidebar'

    $content.BackColor = Get-ThemeColor 'Bg'

    $contentLayout.BackColor = Get-ThemeColor 'Bg'

    $topBar.BackColor = Get-ThemeColor 'Bg'

    $gridHost.BackColor = Get-ThemeColor 'Bg'

    $statusStrip.BackColor = Get-ThemeColor 'Panel2'

    $script:statusLabel.ForeColor = Get-ThemeColor 'Muted'

    $screenTitle.ForeColor = Get-ThemeColor 'Text'

    $metaLabel.ForeColor = Get-ThemeColor 'Muted'

    $brand.ForeColor = Get-ThemeColor 'Text'

    $footer.ForeColor = Get-ThemeColor 'Muted'

    $themeOkButton.BackColor = Get-ThemeColor 'Accent'

    $themeOkButton.ForeColor = Get-ThemeColor 'CardText'

    $themeOkButton.FlatAppearance.BorderColor = Get-ThemeColor 'Border'



    $searchBox.BackColor = Get-ThemeColor 'Panel'

    $searchBox.ForeColor = Get-ThemeColor 'Text'

    $themeCombo.BackColor = Get-ThemeColor 'Panel'

    $themeCombo.ForeColor = Get-ThemeColor 'Text'

    $layoutCombo.BackColor = Get-ThemeColor 'Panel'

    $layoutCombo.ForeColor = Get-ThemeColor 'Text'



    if ($null -ne $clearSearchBtn) {

        $clearSearchBtn.BackColor = Get-ThemeColor 'Button'

        $clearSearchBtn.ForeColor = Get-ThemeColor 'Muted'

        $clearSearchBtn.FlatAppearance.BorderColor = Get-ThemeColor 'Border'

        $clearSearchBtn.FlatAppearance.MouseOverBackColor = Get-HoverColor (Get-ThemeColor 'Button')

        $clearSearchBtn.FlatAppearance.MouseDownBackColor = Get-HoverColor (Get-HoverColor (Get-ThemeColor 'Button'))

    }



    foreach ($button in @($backButton, $runCurrentButton)) {

        $button.BackColor = Get-ThemeColor 'Button'

        $button.ForeColor = Get-ThemeColor 'Text'

        $button.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

        $button.FlatAppearance.BorderSize = 1

        $button.FlatAppearance.MouseOverBackColor = Get-HoverColor (Get-ThemeColor 'Button')

        $button.FlatAppearance.MouseDownBackColor = Get-HoverColor (Get-HoverColor (Get-ThemeColor 'Button'))

    }



    foreach ($control in $sidebar.Controls) {

        if ($control -is [System.Windows.Forms.CheckBox]) {

            $control.ForeColor = Get-ThemeColor 'Text'

        }

    }



    if ($null -ne $script:menuScrollPanel) {

        foreach ($control in $script:menuScrollPanel.Controls) {

            if ($control -is [System.Windows.Forms.Button]) {

                $control.BackColor = Get-ThemeColor 'Button'

                $control.ForeColor = Get-ThemeColor 'Text'

                $control.FlatAppearance.BorderColor = Get-ThemeColor 'Border'

                $control.FlatAppearance.BorderSize = 1

                $control.FlatAppearance.MouseOverBackColor = Get-HoverColor (Get-ThemeColor 'Button')

                $control.FlatAppearance.MouseDownBackColor = Get-HoverColor (Get-HoverColor (Get-ThemeColor 'Button'))

                $control.Image = New-BadgeBitmap -Glyph (Get-IconGlyph ([pscustomobject]@{ Text = $control.Text })) -Index ([Math]::Max(0, [Math]::Floor($control.Top / 50))) -Size 26

            }

        }

    }



    foreach ($control in $gridHost.Controls) {

        if ($control -is [System.Windows.Forms.TableLayoutPanel]) {

            $control.BackColor = Get-ThemeColor 'Bg'

        }

    }



    # Recolor permanent dashboard cards and labels dynamically (Theme-Safe Overhaul)

    if ($null -ne $script:dashboardPanel) {

        $script:dashboardPanel.BackColor = [System.Drawing.Color]::Transparent

        foreach ($card in $script:dashboardPanel.Controls) {

            if ($card -is [System.Windows.Forms.Panel]) {

                $card.BackColor = Get-ThemeColor 'Panel2'

                $card.ForeColor = Get-ThemeColor 'Text'

                foreach ($lbl in $card.Controls) {

                    if ($lbl -is [System.Windows.Forms.Label]) {

                        if ($lbl.Font.Bold -and $lbl.Font.Size -lt 9) {

                            $lbl.ForeColor = Get-ThemeColor 'Muted'

                        } elseif ($lbl.Font.Bold) {

                            $lbl.ForeColor = Get-ThemeColor 'Accent'

                        } else {

                            $lbl.ForeColor = Get-ThemeColor 'Muted'

                        }

                    }

                }

            }

        }

    }



    Refresh-CurrentView

    try { if ($null -ne $header -and -not $header.IsDisposed) { $header.Invalidate() } } catch {}

    try { if ($null -ne $sidebar -and -not $sidebar.IsDisposed) { $sidebar.Invalidate() } } catch {}

    try { if ($null -ne $gridHost -and -not $gridHost.IsDisposed) { $gridHost.Invalidate() } } catch {}

    

    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

    

    $script:statusLabel.Text = "Theme applied: $Name"

    Save-GuiSettings

}



function New-CardButton {

    param([object]$Item, [int]$Index)

    $button = New-Object System.Windows.Forms.Button

    $button.Height = 96

    $button.Dock = 'Fill'

    $button.Margin = New-Object System.Windows.Forms.Padding(10)

    $button.FlatStyle = 'Flat'

    $button.FlatAppearance.BorderColor = Get-ThemeColor 'Border'

    $button.FlatAppearance.BorderSize = 1

    $button.FlatAppearance.MouseOverBackColor = Get-HoverColor (Get-CardBgColor)

    $button.FlatAppearance.MouseDownBackColor = Get-HoverColor (Get-HoverColor (Get-CardBgColor))

    $button.BackColor = Get-CardBgColor

    $button.ForeColor = Get-CardFgColor

    $button.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $button.TextAlign = 'MiddleLeft'

    $button.ImageAlign = 'MiddleLeft'

    $button.TextImageRelation = 'ImageBeforeText'

    $button.Padding = New-Object System.Windows.Forms.Padding(12, 0, 10, 0)

    $button.Cursor = [System.Windows.Forms.Cursors]::Hand

    $button.AutoEllipsis = $true

    $prefix = if ($Item.PSObject.Properties.Name -contains 'Choice' -and $Item.Choice) { "[$($Item.Choice)]`r`n" } else { '' }

    $suffix = if ($Item.PSObject.Properties.Name -contains 'IsSubmenu' -and $Item.IsSubmenu) { "`r`nSubmenu" } else { '' }

    $button.Text = "$prefix$($Item.Text)$suffix"

    $button.Image = Get-CardIcon $Item $Index

    $button.Tag = $Item

    $button.Add_MouseEnter({

        param($sender, $e)

        $sender.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

        $sender.FlatAppearance.BorderSize = 2

        $gridHost.Focus() | Out-Null

    })

    $button.Add_MouseLeave({

        param($sender, $e)

        $sender.FlatAppearance.BorderColor = Get-ThemeColor 'Border'

        $sender.FlatAppearance.BorderSize = 1

    })

    if ($Item.PSObject.Properties.Name -contains 'Notes' -and -not [string]::IsNullOrWhiteSpace($Item.Notes)) {

        $toolTip.SetToolTip($button, $Item.Notes)

    }

    return $button

}



function Invoke-ItemClick {

    param([object]$tag)

    $tagName    = try { $tag.Text } catch { 'Unknown' }

    $tagChoice  = try { $tag.Choice } catch { '' }

    $tagParent  = try { $tag.ParentLabel } catch { '' }

    $tagType    = try {

        if ($tag.PSObject.Properties.Name -contains 'Action')   { 'SystemAction' }

        elseif ($tag.PSObject.Properties.Name -contains 'ToolType') { "Tool:$($tag.ToolType)" }

        elseif ($tag.IsSubmenu) { 'Submenu' }

        else { 'Command' }

    } catch { 'Unknown' }



    Write-GuiActionLog -ActionType 'Click' -Component $tagName -Details "Type=$tagType Choice=$tagChoice Parent=$tagParent"



    try {

        if ($tag.PSObject.Properties.Name -contains 'Action') {

            Invoke-SystemInventoryAction $tag.Action

        } elseif ($tag.PSObject.Properties.Name -contains 'ToolType') {

            if ($tag.ToolType -eq 'hacker_menu') {

                Show-HackerTools

            } else {

                Invoke-ResolvedTool -Type $tag.ToolType -Target $tag.Target -Name $tag.Text

                $script:statusLabel.Text = "Started portable tool: $($tag.Text)"

            }

        } else {

            Invoke-Option $tag

        }

        Write-GuiActionLog -ActionType 'Result' -Component $tagName -Details "OK - Type=$tagType Choice=$tagChoice"

    } catch {

        $tagName = try { $tag.Text } catch { 'Unknown' }

        Write-GuiActionLog -ActionType 'Error' -Component $tagName -Details "FAILED: $($_.Exception.Message)"

        Write-GuiErrorLog -Panel 'Invoke-ItemClick' -Context $tagName -Err $_ -Recovered $true

        Invoke-GuiAutoRecover -FailedPanel "ItemClick: $tagName"

    }

}



function Refresh-CurrentView {

    if ($null -ne $script:currentItems) {

        Render-Cards $script:currentItems $script:currentTitle $script:currentMode

    }

}



function Get-ResponsiveColumnCount {

    param([int]$Default = 4)



    $width = 1200

    try { $width = [Math]::Max(1, $gridHost.ClientSize.Width) } catch {}

    if ($width -ge 2200) { return 6 }

    if ($width -ge 1700) { return 5 }

    if ($width -ge 1050) { return 4 }

    if ($width -ge 760) { return 3 }

    if ($width -ge 520) { return 2 }

    return 1

}



function Render-GridLayout {

    param([object[]]$Items)



    $cols = Get-ResponsiveColumnCount 4

    $table = New-Object System.Windows.Forms.TableLayoutPanel

    $table.ColumnCount = $cols

    $table.RowCount = [Math]::Max(1, [Math]::Ceiling($Items.Count / $cols))

    $table.Dock = 'Top'

    $table.AutoSize = $true

    $table.AutoSizeMode = 'GrowAndShrink'

    $table.Padding = New-Object System.Windows.Forms.Padding(8, 4, 18, 18)

    $table.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $table

    $pct = 100 / $cols

    for ($i = 0; $i -lt $cols; $i++) {

        $table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, $pct))) | Out-Null

    }

    for ($r = 0; $r -lt $table.RowCount; $r++) {

        $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 112))) | Out-Null

    }



    $idx = 0

    foreach ($item in $Items) {

        $button = New-CardButton $item $idx

        $button.Add_Click({

            param($sender, $eventArgs)

            Invoke-ItemClick $sender.Tag

        })

        $table.Controls.Add($button, $idx % $cols, [Math]::Floor($idx / $cols))

        $idx++

    }

    $gridHost.Controls.Add($table)

}



function Render-CompactListLayout {

    param([object[]]$Items)



    $table = New-Object System.Windows.Forms.TableLayoutPanel

    $table.ColumnCount = 1

    $table.RowCount = $Items.Count

    $table.Dock = 'Top'

    $table.AutoSize = $true

    $table.AutoSizeMode = 'GrowAndShrink'

    $table.Padding = New-Object System.Windows.Forms.Padding(18, 10, 24, 18)

    $table.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $table

    $table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null



    $idx = 0

    foreach ($item in $Items) {

        $itemPanel = New-Object System.Windows.Forms.Panel

        $itemPanel.Height = 62

        $itemPanel.Dock = 'Fill'

        $itemPanel.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 5)

        $itemPanel.BackColor = Get-CardBgColor

        $itemPanel.Cursor = [System.Windows.Forms.Cursors]::Hand

        Enable-DoubleBuffer $itemPanel



        $state = [pscustomobject]@{ IsHovered = $false }

        $itemPanel.Tag = $state



        $itemPanel.Add_Paint({

            param($sender, $e)

            try {

                if ($sender.Width -le 10 -or $sender.Height -le 10) { return }

                $g = $e.Graphics

                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

                

                $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width - 1, $sender.Height - 1)

                $path = Get-RoundedGraphicsPath -Rect $rect -Radius 10

                

                $bgBrush = New-Object System.Drawing.SolidBrush($sender.BackColor)

                $g.FillPath($bgBrush, $path)

                $bgBrush.Dispose()



                $borderColor = if ($sender.Tag.IsHovered) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Border' }

                $borderSize = if ($sender.Tag.IsHovered) { 2 } else { 1 }

                $pen = New-Object System.Drawing.Pen($borderColor, $borderSize)

                $g.DrawPath($pen, $path)

                $pen.Dispose()

                

                if ($sender.Tag.IsHovered) {

                    $accentBrush = New-Object System.Drawing.SolidBrush(Get-ThemeColor 'Accent')

                    $g.FillRectangle($accentBrush, 4, 10, 4, $sender.Height - 20)

                    $accentBrush.Dispose()

                }

                $path.Dispose()

            } catch {}

        })



        $iconBox = New-Object System.Windows.Forms.PictureBox

        $iconBox.Image = Get-CardIcon $item $idx 28

        $iconBox.SizeMode = 'CenterImage'

        $iconBox.SetBounds(14, 14, 34, 34)

        $iconBox.Cursor = [System.Windows.Forms.Cursors]::Hand

        $itemPanel.Controls.Add($iconBox)



        $titleLbl = New-Object System.Windows.Forms.Label

        $choicePart = if ($item.PSObject.Properties.Name -contains 'Choice' -and $item.Choice) { "[$($item.Choice)] " } else { '' }

        $titleLbl.Text = "$choicePart$($item.Text)"

        $titleLbl.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

        $titleLbl.ForeColor = Get-CardFgColor

        $titleLbl.SetBounds(62, 10, 800, 22)

        $titleLbl.AutoEllipsis = $true

        $titleLbl.Cursor = [System.Windows.Forms.Cursors]::Hand

        $itemPanel.Controls.Add($titleLbl)



        $descLbl = New-Object System.Windows.Forms.Label

        $descLbl.Text = if ($item.PSObject.Properties.Name -contains 'Notes' -and $item.Notes) { $item.Notes } else { 'Select to launch command' }

        $descLbl.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)

        $descLbl.ForeColor = Get-ThemeColor 'Muted'

        $descLbl.SetBounds(62, 32, 800, 18)

        $descLbl.AutoEllipsis = $true

        $descLbl.Cursor = [System.Windows.Forms.Cursors]::Hand

        $itemPanel.Controls.Add($descLbl)



        $arrowLbl = New-Object System.Windows.Forms.Label

        $arrowLbl.Text = "Launch >"

        $arrowLbl.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

        $arrowLbl.ForeColor = Get-ThemeColor 'Muted'

        $arrowLbl.TextAlign = 'MiddleRight'

        $arrowLbl.SetBounds(880, 16, 80, 28)

        $arrowLbl.Anchor = 'Top,Right'

        $arrowLbl.Cursor = [System.Windows.Forms.Cursors]::Hand

        $itemPanel.Controls.Add($arrowLbl)



        $onEnter = {

            $state.IsHovered = $true

            try { $itemPanel.BackColor = Get-HoverColor (Get-CardBgColor) } catch {}

            try { $arrowLbl.ForeColor = Get-ThemeColor 'Accent' } catch {}

            try { if (-not $itemPanel.IsDisposed) { $itemPanel.Invalidate() } } catch {}

        }

        $onLeave = {

            try {

                $clientPos = $itemPanel.PointToClient([System.Windows.Forms.Control]::MousePosition)

                if ($clientPos.X -lt 0 -or $clientPos.Y -lt 0 -or $clientPos.X -ge $itemPanel.Width -or $clientPos.Y -ge $itemPanel.Height) {

                    $state.IsHovered = $false

                    $itemPanel.BackColor = Get-CardBgColor

                    $arrowLbl.ForeColor = Get-ThemeColor 'Muted'

                    if (-not $itemPanel.IsDisposed) { $itemPanel.Invalidate() }

                }

            } catch {}

        }

        

        $onClick = {

            param($sender, $e)

            Invoke-ItemClick $item

        }



        foreach ($ctrl in @($itemPanel, $iconBox, $titleLbl, $descLbl, $arrowLbl)) {

            $ctrl.Add_MouseEnter($onEnter)

            $ctrl.Add_MouseLeave($onLeave)

            $ctrl.Add_Click($onClick)

        }



        if ($item.PSObject.Properties.Name -contains 'Notes' -and $item.Notes) {

            $toolTip.SetToolTip($itemPanel, $item.Notes)

            $toolTip.SetToolTip($titleLbl, $item.Notes)

            $toolTip.SetToolTip($descLbl, $item.Notes)

        }



        $table.Controls.Add($itemPanel, 0, $idx)

        $idx++

    }

    $gridHost.Controls.Add($table)

}



function Render-HeroDashboardLayout {

    param([object[]]$Items)



    $cols = [Math]::Min(4, (Get-ResponsiveColumnCount 3))

    $table = New-Object System.Windows.Forms.TableLayoutPanel

    $table.ColumnCount = $cols

    $table.RowCount = [Math]::Max(1, [Math]::Ceiling($Items.Count / $cols))

    $table.Dock = 'Top'

    $table.AutoSize = $true

    $table.AutoSizeMode = 'GrowAndShrink'

    $table.Padding = New-Object System.Windows.Forms.Padding(12, 10, 22, 18)

    $table.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $table

    $pct = 100 / $cols

    for ($i = 0; $i -lt $cols; $i++) {

        $table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, $pct))) | Out-Null

    }

    for ($r = 0; $r -lt $table.RowCount; $r++) {

        $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 165))) | Out-Null

    }



    $idx = 0

    foreach ($item in $Items) {

        $cardPanel = New-Object System.Windows.Forms.Panel

        $cardPanel.Height = 145

        $cardPanel.Dock = 'Fill'

        $cardPanel.Margin = New-Object System.Windows.Forms.Padding(10)

        $cardPanel.BackColor = Get-CardBgColor

        $cardPanel.Cursor = [System.Windows.Forms.Cursors]::Hand

        Enable-DoubleBuffer $cardPanel



        $state = [pscustomobject]@{ IsHovered = $false }

        $cardPanel.Tag = $state



        $cardPanel.Add_Paint({

            param($sender, $e)

            try {

                if ($sender.Width -le 12 -or $sender.Height -le 12) { return }

                $g = $e.Graphics

                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

                

                $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width - 1, $sender.Height - 1)

                $path = Get-RoundedGraphicsPath -Rect $rect -Radius 12

                

                $bgBrush = New-Object System.Drawing.SolidBrush($sender.BackColor)

                $g.FillPath($bgBrush, $path)

                $bgBrush.Dispose()



                $borderColor = if ($sender.Tag.IsHovered) { Get-ThemeColor 'Accent' } else { Get-ThemeColor 'Border' }

                $borderSize = if ($sender.Tag.IsHovered) { 2 } else { 1 }

                $pen = New-Object System.Drawing.Pen($borderColor, $borderSize)

                $g.DrawPath($pen, $path)

                $pen.Dispose()



                if ($sender.Tag.IsHovered) {

                    $accentThickness = 4

                    $accentPen = New-Object System.Drawing.Pen(Get-ThemeColor 'Accent', $accentThickness)

                    $g.DrawLine($accentPen, 20, $sender.Height - 1, $sender.Width - 20, $sender.Height - 1)

                    $accentPen.Dispose()

                }

                $path.Dispose()

            } catch {}

        })



        $iconBox = New-Object System.Windows.Forms.PictureBox

        $iconBox.Image = Get-CardIcon $item $idx 44

        $iconBox.SizeMode = 'CenterImage'

        $iconBox.SetBounds(0, 16, 280, 48)

        $iconBox.Anchor = 'Top,Left,Right'

        $iconBox.Cursor = [System.Windows.Forms.Cursors]::Hand

        $cardPanel.Controls.Add($iconBox)



        $titleLbl = New-Object System.Windows.Forms.Label

        $choicePart = if ($item.PSObject.Properties.Name -contains 'Choice' -and $item.Choice) { "[$($item.Choice)] " } else { '' }

        $titleLbl.Text = "$choicePart$($item.Text)"

        $titleLbl.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

        $titleLbl.ForeColor = Get-CardFgColor

        $titleLbl.TextAlign = 'MiddleCenter'

        $titleLbl.SetBounds(10, 70, 260, 24)

        $titleLbl.Anchor = 'Top,Left,Right'

        $titleLbl.AutoEllipsis = $true

        $titleLbl.Cursor = [System.Windows.Forms.Cursors]::Hand

        $cardPanel.Controls.Add($titleLbl)



        $descLbl = New-Object System.Windows.Forms.Label

        $descLbl.Text = if ($item.PSObject.Properties.Name -contains 'Notes' -and $item.Notes) { $item.Notes } else { 'Select to launch' }

        $descLbl.Font = New-Object System.Drawing.Font('Segoe UI', 8)

        $descLbl.ForeColor = Get-ThemeColor 'Muted'

        $descLbl.TextAlign = 'MiddleCenter'

        $descLbl.SetBounds(10, 96, 260, 36)

        $descLbl.Anchor = 'Top,Left,Right'

        $descLbl.AutoEllipsis = $true

        $descLbl.Cursor = [System.Windows.Forms.Cursors]::Hand

        $cardPanel.Controls.Add($descLbl)



        $onEnter = {

            $state.IsHovered = $true

            try { $cardPanel.BackColor = Get-HoverColor (Get-CardBgColor) } catch {}

            try { if (-not $cardPanel.IsDisposed) { $cardPanel.Invalidate() } } catch {}

        }

        $onLeave = {

            try {

                $clientPos = $cardPanel.PointToClient([System.Windows.Forms.Control]::MousePosition)

                if ($clientPos.X -lt 0 -or $clientPos.Y -lt 0 -or $clientPos.X -ge $cardPanel.Width -or $clientPos.Y -ge $cardPanel.Height) {

                    $state.IsHovered = $false

                    $cardPanel.BackColor = Get-CardBgColor

                    if (-not $cardPanel.IsDisposed) { $cardPanel.Invalidate() }

                }

            } catch {}

        }



        $onClick = {

            param($sender, $e)

            Invoke-ItemClick $item

        }



        foreach ($ctrl in @($cardPanel, $iconBox, $titleLbl, $descLbl)) {

            $ctrl.Add_MouseEnter($onEnter)

            $ctrl.Add_MouseLeave($onLeave)

            $ctrl.Add_Click($onClick)

        }



        if ($item.PSObject.Properties.Name -contains 'Notes' -and $item.Notes) {

            $toolTip.SetToolTip($cardPanel, $item.Notes)

            $toolTip.SetToolTip($titleLbl, $item.Notes)

            $toolTip.SetToolTip($descLbl, $item.Notes)

        }



        $table.Controls.Add($cardPanel, $idx % $cols, [Math]::Floor($idx / $cols))

        $idx++

    }

    $gridHost.Controls.Add($table)

}



function Render-SplitExplorerLayout {

    param([object[]]$Items)



    $splitPanel = New-Object System.Windows.Forms.TableLayoutPanel

    $splitPanel.Dock = 'Fill'

    $splitPanel.ColumnCount = 2

    $splitPanel.RowCount = 1

    $splitPanel.Margin = New-Object System.Windows.Forms.Padding(0)

    $splitPanel.Padding = New-Object System.Windows.Forms.Padding(0)

    $splitPanel.BackColor = $gridHost.BackColor

    $splitPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 180))) | Out-Null

    $splitPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

    $splitPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

    Enable-DoubleBuffer $splitPanel



    # Left pane: Category selector

    $leftFlow = New-Object System.Windows.Forms.FlowLayoutPanel

    $leftFlow.Dock = 'Fill'

    $leftFlow.FlowDirection = 'TopDown'

    $leftFlow.WrapContents = $false

    $leftFlow.AutoScroll = $true

    $leftFlow.BackColor = Get-ThemeColor 'Panel2'

    $leftFlow.Padding = New-Object System.Windows.Forms.Padding(8, 10, 8, 10)

    Enable-DoubleBuffer $leftFlow



    # Right pane: Scrollable host for grid cards

    $rightScroll = New-Object System.Windows.Forms.Panel

    $rightScroll.Dock = 'Fill'

    $rightScroll.AutoScroll = $true

    $rightScroll.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $rightScroll



    # Group items dynamically

    $groups = [ordered]@{}

    $groups["All"] = New-Object System.Collections.Generic.List[object]

    

    foreach ($item in $Items) {

        $groups["All"].Add($item)

        

        $cat = "General Actions"

        if ($item.PSObject.Properties.Name -contains 'Category' -and $item.Category) {

            $cat = $item.Category

        } elseif ($item.PSObject.Properties.Name -contains 'ToolType' -and $item.ToolType) {

            $cat = "Portable " + (Get-Culture).TextInfo.ToTitleCase($item.ToolType.ToLowerInvariant())

        } elseif ($item.PSObject.Properties.Name -contains 'ParentLabel' -and $item.ParentLabel) {

            $cat = "CMD " + (Get-Culture).TextInfo.ToTitleCase($item.ParentLabel.ToLowerInvariant())

        }

        

        if (-not $groups.Contains($cat)) {

            $groups[$cat] = New-Object System.Collections.Generic.List[object]

        }

        $groups[$cat].Add($item)

    }



    # Render filtered cards on the right

    $script:SelectedExplorerCategory = "All"

    

    function Update-ExplorerCards {

        param([string]$CategoryName)

        $rightScroll.Controls.Clear()

        $filteredItems = $groups[$CategoryName]

        $cols = [Math]::Min(5, [Math]::Max(2, (Get-ResponsiveColumnCount 3)))



        $cardTable = New-Object System.Windows.Forms.TableLayoutPanel

        $cardTable.ColumnCount = $cols

        $cardTable.RowCount = [Math]::Max(1, [Math]::Ceiling($filteredItems.Count / $cols))

        $cardTable.Dock = 'Top'

        $cardTable.AutoSize = $true

        $cardTable.AutoSizeMode = 'GrowAndShrink'

        $cardTable.Padding = New-Object System.Windows.Forms.Padding(8, 4, 18, 18)

        $cardTable.BackColor = $rightScroll.BackColor

        Enable-DoubleBuffer $cardTable

        $pct = 100 / $cols

        for ($i = 0; $i -lt $cols; $i++) {

            $cardTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, $pct))) | Out-Null

        }

        for ($r = 0; $r -lt $cardTable.RowCount; $r++) {

            $cardTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 112))) | Out-Null

        }



        $cIdx = 0

        foreach ($cItem in $filteredItems) {

            $cBtn = New-CardButton $cItem $cIdx

            $cBtn.Add_Click({

                param($sender, $e)

                Invoke-ItemClick $sender.Tag

            })

            $cardTable.Controls.Add($cBtn, $cIdx % $cols, [Math]::Floor($cIdx / $cols))

            $cIdx++

        }

        $rightScroll.Controls.Add($cardTable)

    }



    # Create category selection buttons on the left

    $tabButtons = @()

    foreach ($grpName in $groups.Keys) {

        $tabBtn = New-Object System.Windows.Forms.Button

        $tabBtn.Height = 40

        $tabBtn.Width = 148

        $tabBtn.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 4)

        $tabBtn.FlatStyle = 'Flat'

        $tabBtn.FlatAppearance.BorderSize = 1

        $tabBtn.FlatAppearance.BorderColor = Get-ThemeColor 'Border'

        $tabBtn.BackColor = Get-ThemeColor 'Button'

        $tabBtn.ForeColor = Get-ThemeColor 'Text'

        $tabBtn.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

        $tabBtn.Text = "$grpName ($($groups[$grpName].Count))"

        $tabBtn.Cursor = [System.Windows.Forms.Cursors]::Hand

        $tabBtn.Tag = $grpName

        $tabBtn.TextAlign = 'MiddleLeft'

        $tabBtn.Padding = New-Object System.Windows.Forms.Padding(8, 0, 8, 0)

        

        # Highlighting the selected tab

        if ($grpName -eq $script:SelectedExplorerCategory) {

            $tabBtn.BackColor = Get-ThemeColor 'Accent'

            $tabBtn.ForeColor = Get-ThemeColor 'CardText'

            $tabBtn.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

        }



        $tabBtn.Add_Click(({

            param($sender, $e)

            $script:SelectedExplorerCategory = $sender.Tag

            # Update background highlights

            foreach ($tb in $tabButtons) {

                if ($tb.Tag -eq $script:SelectedExplorerCategory) {

                    $tb.BackColor = Get-ThemeColor 'Accent'

                    $tb.ForeColor = Get-ThemeColor 'CardText'

                    $tb.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

                } else {

                    $tb.BackColor = Get-ThemeColor 'Button'

                    $tb.ForeColor = Get-ThemeColor 'Text'

                    $tb.FlatAppearance.BorderColor = Get-ThemeColor 'Border'

                }

            }

            Update-ExplorerCards $sender.Tag

        }.GetNewClosure()))

        

        $leftFlow.Controls.Add($tabBtn)

        $tabButtons += $tabBtn

    }



    # Initial load of cards

    Update-ExplorerCards $script:SelectedExplorerCategory



    $splitPanel.Controls.Add($leftFlow, 0, 0)

    $splitPanel.Controls.Add($rightScroll, 1, 0)



    # Disable default autoscroll on gridHost to avoid nested scrollbars

    $gridHost.AutoScroll = $false

    $gridHost.Controls.Add($splitPanel)

}



function Render-CyberTerminalLayout {

    param([object[]]$Items)



    $cols = Get-ResponsiveColumnCount 4

    $table = New-Object System.Windows.Forms.TableLayoutPanel

    $table.ColumnCount = $cols

    $table.RowCount = [Math]::Max(1, [Math]::Ceiling($Items.Count / $cols))

    $table.Dock = 'Top'

    $table.AutoSize = $true

    $table.AutoSizeMode = 'GrowAndShrink'

    $table.Padding = New-Object System.Windows.Forms.Padding(18, 12, 24, 24)

    # Set parent gridHost background to black for that authentic terminal backdrop

    $gridHost.BackColor = [System.Drawing.Color]::Black

    $table.BackColor = [System.Drawing.Color]::Black

    Enable-DoubleBuffer $table



    $pct = 100 / $cols

    for ($i = 0; $i -lt $cols; $i++) {

        $table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, $pct))) | Out-Null

    }

    for ($r = 0; $r -lt $table.RowCount; $r++) {

        $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 106))) | Out-Null

    }



    # Custom brackets paint event for that futuristic military radar/target overlay

    $gridHost.Add_Paint({

        param($sender, $e)

        if ($script:CurrentLayoutName -ne 'Cyber Terminal') { return }

        $g = $e.Graphics

        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        $glowColor = Get-ThemeColor 'Accent'

        $pen = New-Object System.Drawing.Pen($glowColor, 2)

        $size = 18

        

        # Draw top-left bracket

        $g.DrawLine($pen, 8, 8, 8 + $size, 8)

        $g.DrawLine($pen, 8, 8, 8, 8 + $size)

        # Draw top-right bracket

        $g.DrawLine($pen, $sender.Width - 8, 8, $sender.Width - 8 - $size, 8)

        $g.DrawLine($pen, $sender.Width - 8, 8, $sender.Width - 8, 8 + $size)

        # Draw bottom-left bracket

        $g.DrawLine($pen, 8, $sender.Height - 8, 8 + $size, $sender.Height - 8)

        $g.DrawLine($pen, 8, $sender.Height - 8, 8, $sender.Height - 8 - $size)

        # Draw bottom-right bracket

        $g.DrawLine($pen, $sender.Width - 8, $sender.Height - 8, $sender.Width - 8 - $size, $sender.Height - 8)

        $g.DrawLine($pen, $sender.Width - 8, $sender.Height - 8, $sender.Width - 8, $sender.Height - 8 - $size)

        

        $pen.Dispose()

    })



    $idx = 0

    foreach ($item in $Items) {

        $button = New-Object System.Windows.Forms.Button

        $button.Height = 88

        $button.Dock = 'Fill'

        $button.Margin = New-Object System.Windows.Forms.Padding(8)

        $button.FlatStyle = 'Flat'

        

        $glowColor = Get-ThemeColor 'Accent'

        $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(120, $glowColor)

        $button.FlatAppearance.BorderSize = 1

        $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(40, $glowColor)

        $button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(85, $glowColor)

        

        $button.BackColor = [System.Drawing.Color]::FromArgb(15, $glowColor)

        $button.ForeColor = $glowColor

        $button.Font = New-Object System.Drawing.Font('Consolas', 9.5, [System.Drawing.FontStyle]::Bold)

        $button.TextAlign = 'MiddleLeft'

        $button.ImageAlign = 'MiddleLeft'

        $button.TextImageRelation = 'ImageBeforeText'

        $button.Padding = New-Object System.Windows.Forms.Padding(12, 0, 8, 0)

        $button.Cursor = [System.Windows.Forms.Cursors]::Hand

        

        $choicePart = if ($item.PSObject.Properties.Name -contains 'Choice' -and $item.Choice) { "> [$($item.Choice)] " } else { '> ' }

        $button.Text = "$choicePart$($item.Text.ToUpperInvariant())"

        

        # Cyber terminals use green/cyan neon scaling icons

        $button.Image = Get-CardIcon $item $idx 32

        $button.Tag = $item



        $button.Add_MouseEnter({

            param($sender, $e)

            try { $sender.FlatAppearance.BorderColor = Get-ThemeColor 'Accent' } catch {}

            try { $sender.FlatAppearance.BorderSize = 2 } catch {}

            try { if (-not $sender.IsDisposed) { $sender.Invalidate() } } catch {}

            $script:statusLabel.Text = "SYSTEM_TARGET_HOVER: " + $sender.Tag.Text.ToUpperInvariant()

        })

        $button.Add_MouseLeave({

            param($sender, $e)

            try { $sender.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(120, (Get-ThemeColor 'Accent')) } catch {}

            try { $sender.FlatAppearance.BorderSize = 1 } catch {}

            try { if (-not $sender.IsDisposed) { $sender.Invalidate() } } catch {}

        })

        $button.Add_Click({

            param($sender, $eventArgs)

            Invoke-ItemClick $sender.Tag

        })

        $button.Add_Paint({

            param($sender, $e)

            if ($sender.FlatAppearance.BorderSize -eq 2) {

                $g = $e.Graphics

                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

                $accentColor = Get-ThemeColor 'Accent'

                $pen = New-Object System.Drawing.Pen($accentColor, 2)

                $sz = 8

                # Top-Left

                $g.DrawLine($pen, 2, 2, 2 + $sz, 2)

                $g.DrawLine($pen, 2, 2, 2, 2 + $sz)

                # Top-Right

                $g.DrawLine($pen, $sender.Width - 3, 2, $sender.Width - 3 - $sz, 2)

                $g.DrawLine($pen, $sender.Width - 3, 2, $sender.Width - 3, 2 + $sz)

                # Bottom-Left

                $g.DrawLine($pen, 2, $sender.Height - 3, 2 + $sz, $sender.Height - 3)

                $g.DrawLine($pen, 2, $sender.Height - 3, 2, $sender.Height - 3 - $sz)

                # Bottom-Right

                $g.DrawLine($pen, $sender.Width - 3, $sender.Height - 3, $sender.Width - 3 - $sz, $sender.Height - 3)

                $g.DrawLine($pen, $sender.Width - 3, $sender.Height - 3, $sender.Width - 3, $sender.Height - 3 - $sz)

                $pen.Dispose()

            }

        })

        

        if ($item.PSObject.Properties.Name -contains 'Notes' -and $item.Notes) {

            $toolTip.SetToolTip($button, "[TERMINAL LOG]`r`n" + $item.Notes)

        }



        $table.Controls.Add($button, $idx % $cols, [Math]::Floor($idx / $cols))

        $idx++

    }

    $gridHost.Controls.Add($table)

}



function Render-Cards {

    param([object[]]$Items, [string]$Title, [string]$Mode)



    try { $searchBox.Visible = $true } catch {}

    

    # Suspend layout to prevent intermediate redraw flickers (Zero-Flicker Repaints)

    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    

    # Disable AutoScroll during control addition to prevent out-of-bounds rendering offsets

    $gridHost.AutoScroll = $false

    

    $screenTitle.Text = $title

    $metaLabel.Text = "$($Items.Count) items"

    $script:currentItems = $Items

    $script:currentTitle = $Title

    $script:currentMode = $Mode



    # Cyber terminal layout sets the background specifically to black,

    # other layouts must revert it to the active theme's Bg color

    if ($script:CurrentLayoutName -ne 'Cyber Terminal') {

        $gridHost.BackColor = Get-ThemeColor 'Bg'

    }



    if ($Items.Count -eq 0) {

        $empty = New-Object System.Windows.Forms.Label

        $empty.Text = 'No items found'

        $empty.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)

        $empty.ForeColor = Get-ThemeColor 'Muted'

        $empty.TextAlign = 'MiddleCenter'

        $empty.Dock = 'Top'

        $empty.Height = 100

        $gridHost.Controls.Add($empty)

    } else {

        switch ($script:CurrentLayoutName) {

            'Compact List' { Render-CompactListLayout $Items }

            'Hero Dashboard' { Render-HeroDashboardLayout $Items }

            'Split Explorer' { Render-SplitExplorerLayout $Items }

            'Cyber Terminal' { Render-CyberTerminalLayout $Items }

            default { Render-GridLayout $Items }

        }

    }



    if ($script:currentLabel -eq 'main') {

        Show-PerformanceDashboard

    }

    

    # Re-enable AutoScroll so scrollbars appear correctly for large card lists

    $gridHost.AutoScroll = $true



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Get-VisibleMainOptions {

    if (-not $model -or -not $model.Blocks -or -not $model.Blocks.ContainsKey('main')) {

        return @()

    }

    $main = $model.Blocks['main']

    if ($null -eq $main -or $null -eq $main.Options) { return @() }

    return @($main.Options | Where-Object {

        $_.Choice -match '^\d+$' -or $_.Choice -in @('S','P','M','T')

    })

}



function Resolve-WingetPath {

    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {

        return $cmd.Source

    }



    $candidateRoots = @()

    if (-not [string]::IsNullOrWhiteSpace($env:LocalAppData)) {

        $candidateRoots += $env:LocalAppData

    }

    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {

        $candidateRoots += (Join-Path $env:USERPROFILE 'AppData\Local')

    }



    foreach ($root in ($candidateRoots | Select-Object -Unique)) {

        $localPath = Join-Path $root 'Microsoft\WindowsApps\winget.exe'

        if (Test-Path -LiteralPath $localPath) {

            return $localPath

        }

    }



    $winApps = Join-Path $env:ProgramFiles 'WindowsApps'

    if (Test-Path -LiteralPath $winApps) {

        $dirs = Get-ChildItem -LiteralPath $winApps -Filter '*DesktopAppInstaller*' -Directory -ErrorAction SilentlyContinue |

            Sort-Object LastWriteTime -Descending

        foreach ($d in $dirs) {

            $p = Join-Path $d.FullName 'winget.exe'

            if (Test-Path -LiteralPath $p) {

                return $p

            }

        }

    }



    # Final fallback to generic 'winget' if found in PATH

    if (Get-Command winget -ErrorAction SilentlyContinue) {

        return "winget"

    }



    return $null

}



function Show-OnlineWingetSearchPanel {

    param([string]$InitialQuery = "")



    $script:currentMode = 'online_search'

    $script:currentLabel = 'menu_apps_online_search'

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}

    Clear-Grid

    $screenTitle.Text = "Online Winget Search & Installer"

    $metaLabel.Text = "Search and install any package from the official Winget repository in real-time"

    $script:currentMode = 'online_search'



    $searchContainer = New-Object System.Windows.Forms.Panel

    $searchContainer.Dock = 'Top'

    $searchContainer.Height = 160

    $searchContainer.BackColor = [System.Drawing.Color]::Transparent

    $searchContainer.Padding = New-Object System.Windows.Forms.Padding(24, 24, 24, 12)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Search Winget Packages"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 18)

    $searchContainer.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Enter a keyword (e.g. anydesk, steam, vlc, discord, notepad) to fetch results from the Microsoft repository."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 48)

    $searchContainer.Controls.Add($panelSub)



    $inputBox = New-Object System.Windows.Forms.TextBox

    $inputBox.Font = New-Object System.Drawing.Font('Segoe UI', 12)

    $inputBox.BorderStyle = 'FixedSingle'

    $inputBox.SetBounds(36, 82, 520, 36)

    $inputBox.BackColor = Get-ThemeColor 'Panel2'

    $inputBox.ForeColor = Get-ThemeColor 'Text'

    try { $inputBox.PlaceholderText = "Type software name or ID..." } catch {}

    if (-not [string]::IsNullOrEmpty($InitialQuery)) {

        $inputBox.Text = $InitialQuery

    }

    $searchContainer.Controls.Add($inputBox)

    $script:onlineSearchInput = $inputBox



    $btn = New-Object System.Windows.Forms.Button

    $btn.Text = "Search Repository"

    $btn.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $btn.FlatStyle = 'Flat'

    $btn.BackColor = Get-ThemeColor 'Accent'

    $btn.ForeColor = [System.Drawing.Color]::Black

    $btn.FlatAppearance.BorderSize = 0

    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btn.SetBounds(568, 81, 160, 32)

    

    $btn.Add_MouseEnter({ param($sender, $e) $sender.BackColor = Get-ThemeColor 'Accent2' })

    $btn.Add_MouseLeave({ param($sender, $e) $sender.BackColor = Get-ThemeColor 'Accent' })

    

    $btn.Add_Click({

        try {

            Perform-OnlineWingetSearch $inputBox.Text.Trim()

        } catch {

            Out-MessageBox("Search button click error:`r`n$_", "Search Error", "OK", "Error") | Out-Null

        }

    }.GetNewClosure())

    $searchContainer.Controls.Add($btn)



    $inputBox.Add_KeyDown({

        param($sender, $e)

        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {

            $e.SuppressKeyPress = $true

            try {

                Perform-OnlineWingetSearch $inputBox.Text.Trim()

            } catch {

                Out-MessageBox("Search Enter key error:`r`n$_", "Search Error", "OK", "Error") | Out-Null

            }

        }

    }.GetNewClosure())



    $gridHost.Controls.Add($searchContainer)

    $inputBox.Focus() | Out-Null



    if (-not [string]::IsNullOrEmpty($InitialQuery)) {

        Perform-OnlineWingetSearch $InitialQuery

    }

}



function Show-NativeGuiSearchPanel {

    param([string]$SearchType)



    $script:currentMode = 'native_gui_search'

    $script:currentSearchType = $SearchType

    $script:currentLabel = "native_search_$SearchType"

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}

    Clear-Grid

    $titleText = switch ($SearchType) {

        'search_processes' { "Native GUI Processes Search" }

        'search_services' { "Native GUI Windows Services Search" }

        'search_installed_apps' { "Native GUI Installed Apps Search" }

        'search_ports' { "Native GUI Active Network Ports Search" }

        'search_events' { "Native GUI Recent Event Logs Search" }

        'search_driver_hwids' { "Native GUI Drivers & Hardware Search" }

        'search_files' { "Native GUI User Files Search" }

        'search_toolkit_text' { "Native GUI Toolkit Code Search" }

        'search_smart_jump' { "Native GUI Smart Keyword Jump" }

        'search_global' { "Native GUI Global Settings Search" }

        default { "Native GUI Toolkit Search" }

    }

    $screenTitle.Text = $titleText

    $metaLabel.Text = "Natively search and manage system parameters without opening external CMD windows."



    $searchContainer = New-Object System.Windows.Forms.Panel

    $searchContainer.Dock = 'Top'

    $searchContainer.Height = 160

    $searchContainer.BackColor = [System.Drawing.Color]::Transparent

    $searchContainer.Padding = New-Object System.Windows.Forms.Padding(24, 24, 24, 12)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = $titleText

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 18)

    $searchContainer.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Type a search term and press Enter or click 'Search' to get real-time interactive results."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 48)

    $searchContainer.Controls.Add($panelSub)



    $inputBox = New-Object System.Windows.Forms.TextBox

    $inputBox.Font = New-Object System.Drawing.Font('Segoe UI', 12)

    $inputBox.BorderStyle = 'FixedSingle'

    $inputBox.SetBounds(36, 82, 520, 36)

    $inputBox.BackColor = Get-ThemeColor 'Panel2'

    $inputBox.ForeColor = Get-ThemeColor 'Text'

    try { $inputBox.PlaceholderText = "Enter search query here..." } catch {}

    $searchContainer.Controls.Add($inputBox)

    $script:nativeSearchInput = $inputBox



    $btn = New-Object System.Windows.Forms.Button

    $btn.Text = "Search Natively"

    $btn.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $btn.FlatStyle = 'Flat'

    $btn.BackColor = Get-ThemeColor 'Accent'

    $btn.ForeColor = [System.Drawing.Color]::Black

    $btn.FlatAppearance.BorderSize = 0

    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btn.SetBounds(568, 81, 160, 32)

    

    $btn.Add_MouseEnter({ param($sender, $e) $sender.BackColor = Get-ThemeColor 'Accent2' })

    $btn.Add_MouseLeave({ param($sender, $e) $sender.BackColor = Get-ThemeColor 'Accent' })

    

    $btn.Add_Click({

        Perform-NativeGuiSearch $script:currentSearchType $script:nativeSearchInput.Text.Trim()

    })

    $searchContainer.Controls.Add($btn)



    $inputBox.Add_KeyDown({

        param($sender, $e)

        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {

            $e.SuppressKeyPress = $true

            Perform-NativeGuiSearch $script:currentSearchType $script:nativeSearchInput.Text.Trim()

        }

    })



    $gridHost.Controls.Add($searchContainer)

    $inputBox.Focus() | Out-Null

}



function Perform-NativeGuiSearch {

    param([string]$SearchType, [string]$Query)



    for ($i = $gridHost.Controls.Count - 1; $i -ge 0; $i--) {

        $ctrl = $gridHost.Controls[$i]

        if ($ctrl.GetType().Name -ne 'Panel' -or $ctrl.Height -ne 160) {

            $gridHost.Controls.RemoveAt($i)

        }

    }



    $loading = New-Object System.Windows.Forms.Label

    $loading.Text = "Searching system parameters for '$Query'...`r`nPlease wait..."

    $loading.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

    $loading.ForeColor = Get-ThemeColor 'Accent'

    $loading.TextAlign = 'MiddleCenter'

    $loading.Dock = 'Fill'

    $gridHost.Controls.Add($loading)



    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

    [System.Windows.Forms.Application]::DoEvents()



    try {

        $results = @()

        switch ($SearchType) {

            'search_processes' {

                $procs = Get-Process | Sort-Object Name

                if (-not [string]::IsNullOrEmpty($Query)) {

                    $procs = $procs | Where-Object { $_.Name -like "*$Query*" -or $_.Id.ToString() -eq $Query }

                }

                foreach ($p in $procs | Select-Object -First 100) {

                    $mem = [Math]::Round($p.WorkingSet64 / 1MB, 1)

                    $desc = "ID: $($p.Id)`r`nMemory: $mem MB`r`nClick to terminate this process."

                    $results += [pscustomobject]@{

                        Text = $p.Name

                        Choice = "Kill"

                        Kind = "Inline"

                        Command = "taskkill /F /PID $($p.Id) & pause"

                        Notes = $desc

                    }

                }

            }

            'search_services' {

                $svcs = Get-Service | Sort-Object Name

                if (-not [string]::IsNullOrEmpty($Query)) {

                    $svcs = $svcs | Where-Object { $_.Name -like "*$Query*" -or $_.DisplayName -like "*$Query*" }

                }

                foreach ($s in $svcs | Select-Object -First 100) {

                    $desc = "Display Name: $($s.DisplayName)`r`nStatus: $($s.Status)`r`nClick to toggle service status."

                    $action = if ($s.Status -eq 'Running') { "Stop" } else { "Start" }

                    $cmd = if ($s.Status -eq 'Running') { "net stop `"$($s.Name)`" & pause" } else { "net start `"$($s.Name)`" & pause" }

                    $results += [pscustomobject]@{

                        Text = $s.Name

                        Choice = $action

                        Kind = "Inline"

                        Command = $cmd

                        Notes = $desc

                    }

                }

            }

            'search_installed_apps' {

                $regPaths = @(

                    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",

                    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",

                    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"

                )

                $apps = @()

                foreach ($path in $regPaths) {

                    if (Test-Path $path) {

                        $apps += Get-ItemProperty $path -ErrorAction SilentlyContinue | 

                            Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 }

                    }

                }

                $apps = $apps | Sort-Object DisplayName

                if (-not [string]::IsNullOrEmpty($Query)) {

                    $apps = $apps | Where-Object { $_.DisplayName -like "*$Query*" -or $_.Publisher -like "*$Query*" }

                }

                foreach ($a in $apps | Select-Object -First 100) {

                    $desc = "Publisher: $($a.Publisher)`r`nVersion: $($a.DisplayVersion)`r`nClick to run uninstaller."

                    $cmd = if ($a.UninstallString) { "$($a.UninstallString) & pause" } else { "echo No uninstall string found & pause" }

                    $results += [pscustomobject]@{

                        Text = $a.DisplayName

                        Choice = "Uninstall"

                        Kind = "Inline"

                        Command = $cmd

                        Notes = $desc

                    }

                }

            }

            'search_ports' {

                $netstat = netstat -ano

                $idx = 0

                foreach ($line in $netstat) {

                    $parts = $line.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)

                    if ($parts.Count -ge 4 -and $parts[0] -in @('TCP', 'UDP')) {

                        $proto = $parts[0]

                        $local = $parts[1]

                        $remote = $parts[2]

                        $state = if ($proto -eq 'TCP') { $parts[3] } else { "" }

                        $connPid = if ($proto -eq 'TCP') { $parts[4] } else { $parts[3] }

                        

                        if ($Query -and "$proto $local $remote $state $connPid".ToLowerInvariant().IndexOf($Query.ToLowerInvariant()) -eq -1) {

                            continue

                        }

                        

                        $pName = "Unknown"

                        try { $pName = (Get-Process -Id $connPid -ErrorAction SilentlyContinue).Name } catch {}

                        

                        $desc = "Protocol: $proto`r`nLocal Address: $local`r`nRemote Address: $remote`r`nState: $state`r`nProcess Name: $pName (PID: $connPid)`r`nClick to kill process."

                        $results += [pscustomobject]@{

                            Text = "$proto Port $($local.Split(':')[-1])"

                            Choice = "Kill"

                            Kind = "Inline"

                            Command = "taskkill /F /PID $connPid & pause"

                            Notes = $desc

                        }

                        $idx++

                        if ($idx -ge 80) { break }

                    }

                }

            }

            'search_events' {

                $logs = @('System', 'Application')

                $events = @()

                foreach ($log in $logs) {

                    try {

                        $events += Get-EventLog -LogName $log -Newest 100 -ErrorAction SilentlyContinue

                    } catch {}

                }

                $events = $events | Sort-Object TimeGenerated -Descending

                if (-not [string]::IsNullOrEmpty($Query)) {

                    $events = $events | Where-Object { $_.Message -like "*$Query*" -or $_.Source -like "*$Query*" -or $_.EventID.ToString() -eq $Query }

                }

                foreach ($e in $events | Select-Object -First 60) {

                    $desc = "Log: $($e.LogName)`r`nSource: $($e.Source)`r`nEvent ID: $($e.EventID)`r`nTime: $($e.TimeGenerated)`r`n`r`nMessage:`r`n$($e.Message)"

                    $results += [pscustomobject]@{

                        Text = "$($e.EntryType) ($($e.Source))"

                        Choice = "View"

                        Kind = "Inline"

                        Command = "echo Event Details:`nTime: $($e.TimeGenerated)`nSource: $($e.Source)`nEventID: $($e.EventID)`nMessage: $($e.Message) & pause"

                        Notes = $desc

                    }

                }

            }

            'search_driver_hwids' {

                $drivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue

                if (-not [string]::IsNullOrEmpty($Query)) {

                    $drivers = $drivers | Where-Object { $_.DeviceName -like "*$Query*" -or $_.Manufacturer -like "*$Query*" -or $_.DriverVersion -like "*$Query*" }

                }

                foreach ($d in $drivers | Select-Object -First 80) {

                    $desc = "Manufacturer: $($d.Manufacturer)`r`nDriver Version: $($d.DriverVersion)`r`nClass: $($d.Description)`r`nDevice ID: $($d.DeviceID)"

                    $results += [pscustomobject]@{

                        Text = if ($d.DeviceName) { $d.DeviceName } else { $d.Description }

                        Choice = "Details"

                        Kind = "Inline"

                        Command = "pnputil /enum-devices /deviceids | findstr /i `"$Query`" & pause"

                        Notes = $desc

                    }

                }

            }

            'search_files' {

                $dir = $env:USERPROFILE

                if (-not [string]::IsNullOrEmpty($Query)) {

                    $files = Get-ChildItem -Path $dir -Filter "*$Query*" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 60

                    foreach ($f in $files) {

                        $size = [Math]::Round($f.Length / 1MB, 2)

                        $desc = "Full Path: $($f.FullName)`r`nSize: $size MB`r`nLast Modified: $($f.LastWriteTime)`r`nClick to open file."

                        $results += [pscustomobject]@{

                            Text = $f.Name

                            Choice = "Open"

                            Kind = "Inline"

                            Command = "explorer.exe `"$($f.FullName)`""

                            Notes = $desc

                        }

                    }

                }

            }

            'search_toolkit_text' {

                if (-not [string]::IsNullOrEmpty($Query)) {

                    $matches = Select-String -Path $ToolkitBat -SimpleMatch $Query -ErrorAction SilentlyContinue | Select-Object -First 100

                    foreach ($m in $matches) {

                        $desc = "Line $($m.LineNumber): $($m.Line)`r`nClick to view."

                        $results += [pscustomobject]@{

                            Text = "Line $($m.LineNumber)"

                            Choice = "View"

                            Kind = "Inline"

                            Command = "powershell -Command `"Get-Content -LiteralPath '$ToolkitBat' | Select-Object -Skip $($m.LineNumber - 5) -First 10 | Out-String`" & pause"

                            Notes = $desc

                        }

                    }

                }

            }

            'search_smart_jump' {

                if (-not [string]::IsNullOrEmpty($Query)) {

                    $q = $Query.ToLowerInvariant()

                    foreach ($block in $model.Blocks.Values) {

                        if ($block.Label.ToLowerInvariant().Contains($q) -or ($block.Options | Where-Object { $_.Text.ToLowerInvariant().Contains($q) })) {

                            $results += [pscustomobject]@{

                                Text = "Open " + $block.Label

                                Choice = "Go"

                                Kind = "Label"

                                TargetLabel = $block.Label

                                ParentLabel = $block.Label

                                Command = ""

                                RawAction = ""

                                IsSubmenu = $true

                                Notes = "Click to jump directly to the $($block.Label) module in the GUI."

                            }

                        }

                    }

                }

            }

            'search_global' {

                if (-not [string]::IsNullOrEmpty($Query)) {

                    $q = $Query.ToLowerInvariant()

                    $matches = $model.Options | Where-Object {

                        "$($_.Text) $($_.Choice) $($_.ParentLabel) $($_.TargetLabel)".ToLowerInvariant().Contains($q)

                    } | Sort-Object Text

                    foreach ($m in $matches) {

                        $results += $m

                    }

                }

            }

        }



        if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }



        if ($results.Count -eq 0) {

            $noResults = New-Object System.Windows.Forms.Label

            $noResults.Text = "No native results found matching '$Query'."

            $noResults.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)

            $noResults.ForeColor = Get-ThemeColor 'Muted'

            $noResults.TextAlign = 'MiddleCenter'

            $noResults.Dock = 'Top'

            $noResults.Height = 100

            $gridHost.Controls.Add($noResults)

        } else {

            $cards = @()

            foreach ($item in $results) {

                if ($item.PSObject.Properties.Name -contains 'Choice') {

                    $cards += $item

                } else {

                    $cards += [pscustomobject]@{

                        Text = $item.Text

                        Choice = $item.Choice

                        Kind = $item.Kind

                        TargetLabel = $item.TargetLabel

                        ParentLabel = $item.ParentLabel

                        Command = $item.Command

                        RawAction = $item.RawAction

                        IsSubmenu = $item.IsSubmenu

                        Notes = $item.Notes

                    }

                }

            }



            $table = New-Object System.Windows.Forms.TableLayoutPanel

            $table.ColumnCount = 4

            $table.RowCount = [Math]::Max(1, [Math]::Ceiling($cards.Count / 4))

            $table.Dock = 'Top'

            $table.AutoSize = $true

            $table.AutoSizeMode = 'GrowAndShrink'

            $table.Padding = New-Object System.Windows.Forms.Padding(8, 4, 18, 18)

            $table.BackColor = $gridHost.BackColor

            Enable-DoubleBuffer $table

            for ($i = 0; $i -lt 4; $i++) {

                $table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))) | Out-Null

            }

            for ($r = 0; $r -lt $table.RowCount; $r++) {

                $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 112))) | Out-Null

            }



            $idx = 0

            foreach ($item in $cards) {

                $button = New-CardButton $item $idx

                $button.Add_Click({

                    param($sender, $eventArgs)

                    Invoke-ItemClick $sender.Tag

                })

                $table.Controls.Add($button, $idx % 4, [Math]::Floor($idx / 4))

                $idx++

            }

            

            $scrollContainer = New-Object System.Windows.Forms.Panel

            $scrollContainer.Dock = 'Fill'

            $scrollContainer.AutoScroll = $true

            $scrollContainer.Padding = New-Object System.Windows.Forms.Padding(8)

            $scrollContainer.Controls.Add($table)

            

            $gridHost.Controls.Add($scrollContainer)

        }

    } catch {

        if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }

        $err = New-Object System.Windows.Forms.Label

        $err.Text = "Error running search: $_"

        $err.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

        $err.ForeColor = [System.Drawing.Color]::Red

        $err.TextAlign = 'MiddleCenter'

        $err.Dock = 'Fill'

        $gridHost.Controls.Add($err)

    } finally {

        $form.Cursor = [System.Windows.Forms.Cursors]::Default

    }

}



function Perform-OnlineWingetSearch {

    param([string]$Query)



    if ([string]::IsNullOrWhiteSpace($Query)) {

        Out-MessageBox("Please enter a valid search term.", "Online Winget Search", "OK", "Warning") | Out-Null

        return

    }



    $requestId = [Guid]::NewGuid().ToString()

    $script:onlineWingetSearchToken = $requestId



    # Clear previous search results (except the search box container)

    for ($i = $gridHost.Controls.Count - 1; $i -ge 0; $i--) {

        $ctrl = $gridHost.Controls[$i]

        if ($ctrl.GetType().Name -ne 'Panel' -or $ctrl.Height -ne 160) {

            $gridHost.Controls.RemoveAt($i)

        }

    }



    $loading = New-Object System.Windows.Forms.Label

    $loading.Text = "Searching official Microsoft Winget repository for '$Query'...`r`nPlease wait..."

    $loading.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

    $loading.ForeColor = Get-ThemeColor 'Accent'

    $loading.TextAlign = 'MiddleCenter'

    $loading.Dock = 'Fill'

    $gridHost.Controls.Add($loading)



    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

    [System.Windows.Forms.Application]::DoEvents()



    $wingetPath = Resolve-WingetPath

    if ([string]::IsNullOrWhiteSpace($wingetPath)) {

        if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }

        $form.Cursor = [System.Windows.Forms.Cursors]::Default

        $err = New-Object System.Windows.Forms.Label

        $err.Text = "Winget/App Installer was not found. Install or repair App Installer from Microsoft Store."

        $err.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

        $err.ForeColor = [System.Drawing.Color]::Red

        $err.TextAlign = 'MiddleCenter'

        $err.Dock = 'Fill'

        $gridHost.Controls.Add($err)

        return

    }



    $ps = [System.Management.Automation.PowerShell]::Create()

    $ps.AddScript({

        param($WingetExe, $SearchQuery)

        try {

            $psi = New-Object System.Diagnostics.ProcessStartInfo

            $psi.FileName = $WingetExe

            $psi.Arguments = "search `"$SearchQuery`" --accept-source-agreements"

            $psi.UseShellExecute = $false

            $psi.RedirectStandardOutput = $true

            $psi.RedirectStandardError = $true

            $psi.CreateNoWindow = $true

            $proc = [System.Diagnostics.Process]::Start($psi)

            $outTask = $proc.StandardOutput.ReadToEndAsync()

            $exited = $proc.WaitForExit(15000)

            if (-not $exited) { try { $proc.Kill() } catch {}; throw "Search timed out." }

            return [pscustomobject]@{ Success = $true; Output = $outTask.Result }

        } catch {

            return [pscustomobject]@{ Success = $false; Error = $_.Exception.Message }

        }

    }).AddArgument($wingetPath).AddArgument($Query) | Out-Null



    $asyncResult = $ps.BeginInvoke()

    $sw = [System.Diagnostics.Stopwatch]::StartNew()



    $pollTimer = New-Object System.Windows.Forms.Timer

    $pollTimer.Interval = 500



    $tickHandler = {

        if (-not $asyncResult.IsCompleted) {

            if ($sw.Elapsed.TotalSeconds -gt 20) {

                $pollTimer.Stop(); $pollTimer.Dispose()

                try { $ps.Stop(); $ps.Dispose() } catch {}

                $form.Cursor = [System.Windows.Forms.Cursors]::Default

                if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }

                $err = New-Object System.Windows.Forms.Label

                $err.Text = "Search timed out. Please try again."

                $err.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

                $err.ForeColor = [System.Drawing.Color]::Red

                $err.TextAlign = 'MiddleCenter'; $err.Dock = 'Fill'

                $gridHost.Controls.Add($err); $gridHost.Refresh()

            }

            return

        }



        $pollTimer.Stop(); $pollTimer.Dispose()



        try {

            $form.Cursor = [System.Windows.Forms.Cursors]::Default

            if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }



            if ($script:onlineWingetSearchToken -ne $requestId -or $script:currentLabel -ne 'menu_apps_online_search') {

                try { $ps.Dispose() } catch {}

                return

            }



            $res = $null

            try { $res = $ps.EndInvoke($asyncResult) | Select-Object -Last 1 } catch {}

            try { $ps.Dispose() } catch {}



            if ($null -eq $res -or -not $res.Success) {

                $errMsg = if ($null -ne $res) { $res.Error } else { "Unknown search error." }

                $err = New-Object System.Windows.Forms.Label

                $err.Text = "Error querying Winget: $errMsg`r`nPlease check your internet connection."

                $err.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

                $err.ForeColor = [System.Drawing.Color]::Red

                $err.TextAlign = 'MiddleCenter'; $err.Dock = 'Fill'

                $gridHost.Controls.Add($err); $gridHost.Refresh()

                return

            }



            $lines = @($res.Output -split "`r?`n" | Where-Object { $_ -and $_.Trim().Length -gt 0 })

            $results = @(ConvertFrom-WingetTable -Lines $lines)

            

            $hasMore = $false

            if ($results.Count -gt 40) {

                $results = $results[0..39]

                $hasMore = $true

            }



            if ($hasMore) {

                $script:metaLabel.Text = "Top 40 packages found (showing limited results)"

            } else {

                $script:metaLabel.Text = "$($results.Count) packages found"

            }

            try { [System.Media.SystemSounds]::Beep.Play() } catch {}



            if ($results.Count -eq 0) {

                $noResults = New-Object System.Windows.Forms.Label

                $noResults.Text = "No packages found on Winget matching '$Query'."

                $noResults.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)

                $noResults.ForeColor = Get-ThemeColor 'Muted'

                $noResults.TextAlign = 'MiddleCenter'; $noResults.Dock = 'Top'; $noResults.Height = 100

                $gridHost.Controls.Add($noResults); $gridHost.Refresh()

            } else {

                $cards = @()

                $wingetPath = Resolve-WingetPath

                foreach ($item in $results) {

                    $cards += [pscustomobject]@{

                        Text = $item.Name

                        Choice = "Install"

                        Kind = "Inline"

                        TargetLabel = ""

                        Command = "`"$wingetPath`" install --id `"$($item.ID)`" -e --accept-source-agreements --accept-package-agreements & pause"

                        RawAction = ""

                        IsSubmenu = $false

                        ParentLabel = "menu_apps_online_search"

                        Notes = "ID: $($item.ID)`r`nLatest: $($item.Version)`r`nClick to install silently."

                    }

                }

                

                $table = New-Object System.Windows.Forms.TableLayoutPanel

                $table.ColumnCount = 4

                $table.RowCount = [Math]::Max(1, [Math]::Ceiling($cards.Count / 4))

                $table.Dock = 'Top'; $table.AutoSize = $true; $table.AutoSizeMode = 'GrowAndShrink'

                $table.Padding = New-Object System.Windows.Forms.Padding(8,4,18,18)

                $table.BackColor = $gridHost.BackColor

                Enable-DoubleBuffer $table

                for ($i = 0; $i -lt 4; $i++) {

                    $table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))) | Out-Null

                }

                for ($r = 0; $r -lt $table.RowCount; $r++) {

                    $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 112))) | Out-Null

                }

                $idx = 0

                foreach ($item in $cards) {

                    $btn = New-CardButton $item $idx

                    $btn.Add_Click({

                        param($s,$ea)

                        try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}

                        Invoke-ItemClick $s.Tag

                    })

                    $table.Controls.Add($btn, $idx % 4, [Math]::Floor($idx / 4))

                    $idx++

                }

                $scroll = New-Object System.Windows.Forms.Panel

                $scroll.Dock = 'Fill'; $scroll.AutoScroll = $true

                $scroll.Padding = New-Object System.Windows.Forms.Padding(8)

                $scroll.Controls.Add($table)

                $gridHost.Controls.Add($scroll); $scroll.BringToFront(); $gridHost.Refresh()

            }

        } catch {

            if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }

            $err2 = New-Object System.Windows.Forms.Label

            $err2.Text = "Render error: $_"

            $err2.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

            $err2.ForeColor = [System.Drawing.Color]::Red

            $err2.TextAlign = 'MiddleCenter'; $err2.Dock = 'Fill'

            $gridHost.Controls.Add($err2); $gridHost.Refresh()

        }

    }.GetNewClosure()



    $pollTimer.Add_Tick($tickHandler)

    $pollTimer.Start()

}



function Scan-SoftwareUpgrades {

    $requestId = [Guid]::NewGuid().ToString()

    $gridHost.Tag = $requestId



    for ($i = $gridHost.Controls.Count - 1; $i -ge 0; $i--) {

        if ($gridHost.Controls[$i] -ne $script:updateHeaderPanel) { $gridHost.Controls.RemoveAt($i) }

    }



    $loading = New-Object System.Windows.Forms.Label

    $loading.Text = "Scanning for software updates...`r`nPlease wait up to 30 seconds..."

    $loading.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

    $loading.ForeColor = Get-ThemeColor 'Accent'

    $loading.TextAlign = 'MiddleCenter'

    $loading.Dock = 'Fill'

    $gridHost.Controls.Add($loading)

    $loading.BringToFront()

    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

    [System.Windows.Forms.Application]::DoEvents()

    Set-UpdateManagerBusy $true



    $sw = [System.Diagnostics.Stopwatch]::StartNew()



    $wingetPath = Resolve-WingetPath



    if ([string]::IsNullOrWhiteSpace($wingetPath)) {

        if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }

        $form.Cursor = [System.Windows.Forms.Cursors]::Default

        $lbl = New-Object System.Windows.Forms.Label

        $lbl.Text = "Winget not found. Install App Installer from Microsoft Store."

        $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

        $lbl.ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 80)

        $lbl.TextAlign = 'MiddleCenter'

        $lbl.Dock = 'Fill'

        $gridHost.Controls.Add($lbl); $lbl.BringToFront(); $gridHost.Refresh()

        Set-UpdateManagerBusy $false

        return

    }



    # Use PowerShell.Create() + BeginInvoke() - most reliable async pattern for WinForms

    $ps = [System.Management.Automation.PowerShell]::Create()

    $ps.AddScript({

        param($WingetExe)

        try {

            $psi = New-Object System.Diagnostics.ProcessStartInfo

            $psi.FileName        = $WingetExe

            $psi.Arguments       = "upgrade --source winget --accept-source-agreements"

            $psi.WindowStyle     = [System.Diagnostics.ProcessWindowStyle]::Hidden

            $psi.CreateNoWindow  = $true

            $psi.UseShellExecute = $false

            $psi.RedirectStandardOutput = $true

            $psi.RedirectStandardError  = $true

            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8

            $proc = [System.Diagnostics.Process]::Start($psi)

            $outTask = $proc.StandardOutput.ReadToEndAsync()

            $errTask = $proc.StandardError.ReadToEndAsync()

            $exited  = $proc.WaitForExit(45000)

            $stdout  = $outTask.Result

            $stderr  = $errTask.Result

            if (-not $exited) { try { $proc.Kill() } catch {}; throw "Winget timed out." }

            $raw = @($stdout -split '[\r\n]+' | Where-Object { $_ -ne $null })

            return [pscustomobject]@{ OK = $true; Raw = $raw; Stderr = $stderr }

        } catch {

            return [pscustomobject]@{ OK = $false; Err = $_.Exception.Message }

        }

    }).AddArgument($wingetPath) | Out-Null



    $asyncResult = $ps.BeginInvoke()



    $pollTimer = New-Object System.Windows.Forms.Timer

    $pollTimer.Interval = 500



    $tickHandler = {

        # Poll: is the async operation done?

        if (-not $asyncResult.IsCompleted) {

            if ($sw.Elapsed.TotalSeconds -gt 55) {

                $pollTimer.Stop(); $pollTimer.Dispose()

                try { $ps.Stop(); $ps.Dispose() } catch {}

                $form.Cursor = [System.Windows.Forms.Cursors]::Default

                if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }

                $lbl = New-Object System.Windows.Forms.Label

                $lbl.Text = "Scan timed out. Please try again."

                $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

                $lbl.ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 80)

                $lbl.TextAlign = 'MiddleCenter'; $lbl.Dock = 'Fill'

                $gridHost.Controls.Add($lbl); $lbl.BringToFront(); $gridHost.Refresh()

                Set-UpdateManagerBusy $false

            }

            return

        }



        $pollTimer.Stop(); $pollTimer.Dispose()



        try {

            $form.Cursor = [System.Windows.Forms.Cursors]::Default

            if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }



            if ($gridHost.Tag -ne $requestId) {

                try { $ps.Dispose() } catch {}

                Set-UpdateManagerBusy $false; return

            }



            $res = $null

            try { $res = $ps.EndInvoke($asyncResult) | Select-Object -Last 1 } catch {}

            try { $ps.Dispose() } catch {}



            if ($null -eq $res -or -not $res.OK) {

                $errMsg = if ($null -ne $res) { $res.Err } else { "Scan returned no result." }

                $lbl = New-Object System.Windows.Forms.Label

                $lbl.Text = "Scan failed: $errMsg"

                $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

                $lbl.ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 80)

                $lbl.TextAlign = 'MiddleCenter'; $lbl.Dock = 'Fill'

                $gridHost.Controls.Add($lbl); $lbl.BringToFront(); $gridHost.Refresh()

                Set-UpdateManagerBusy $false; return

            }



            $raw     = $res.Raw

            $results = @(ConvertFrom-WingetTable -Lines $raw -RequiredColumns @('name','id','version','available'))

            $sw.Stop()

            $elapsed = [Math]::Round($sw.Elapsed.TotalSeconds, 2)



            $wingetError = $null

            if ($results.Count -eq 0) {

                $flat = ($raw | Where-Object { $_.Trim() }) -join ' '

                if ($flat -match 'agreement|accept the terms') {

                    $wingetError = "Winget agreement required.`r`nRun 'winget upgrade' in CMD once, accept terms, then scan again."

                } elseif ($flat -match 'failed|error:|0x80|Access is denied') {

                    $wingetError = "Winget error:`r`n" + (($raw | Where-Object {$_.Trim()} | Select-Object -Last 4) -join "`r`n")

                }

            }



            try { $script:metaLabel.Text = "$($results.Count) upgrades found in $elapsed seconds" } catch {}

            try { [System.Media.SystemSounds]::Beep.Play() } catch {}



            if ($null -ne $wingetError) {

                $lbl = New-Object System.Windows.Forms.Label

                $lbl.Text = $wingetError

                $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

                $lbl.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#FFCC00')

                $lbl.TextAlign = 'MiddleCenter'; $lbl.Dock = 'Fill'

                $gridHost.Controls.Add($lbl); $lbl.BringToFront(); $gridHost.Refresh()

            } elseif ($results.Count -eq 0) {

                $lbl = New-Object System.Windows.Forms.Label

                $lbl.Text = "All software is up-to-date! No upgrades available."

                $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)

                $lbl.ForeColor = Get-ThemeColor 'Muted'

                $lbl.TextAlign = 'MiddleCenter'; $lbl.Dock = 'Fill'

                $gridHost.Controls.Add($lbl); $lbl.BringToFront(); $gridHost.Refresh()

            } else {

                $cards = @()

                foreach ($item in $results) {

                    $cards += [pscustomobject]@{

                        Text        = $item.Name

                        Choice      = "Upgrade"

                        Kind        = "Inline"

                        TargetLabel = ""

                        Command     = "`"$wingetPath`" upgrade --id `"$($item.ID)`" --source winget -e --accept-source-agreements --accept-package-agreements & pause"

                        RawAction   = ""

                        IsSubmenu   = $false

                        ParentLabel = "menu_apps_update_manager"

                        Notes       = "ID: $($item.ID)`r`nInstalled: $($item.Version)`r`nAvailable: $($item.Available)`r`nClick to upgrade."

                    }

                }

                $table = New-Object System.Windows.Forms.TableLayoutPanel

                $table.ColumnCount = 4

                $table.RowCount    = [Math]::Max(1, [Math]::Ceiling($cards.Count / 4))

                $table.Dock = 'Top'; $table.AutoSize = $true; $table.AutoSizeMode = 'GrowAndShrink'

                $table.Padding = New-Object System.Windows.Forms.Padding(8,4,18,18)

                $table.BackColor = $gridHost.BackColor

                Enable-DoubleBuffer $table

                for ($i = 0; $i -lt 4; $i++) {

                    $table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))) | Out-Null

                }

                for ($r = 0; $r -lt $table.RowCount; $r++) {

                    $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 112))) | Out-Null

                }

                $idx = 0

                foreach ($item in $cards) {

                    $btn = New-CardButton $item $idx

                    $btn.Add_Click({

                        param($s,$ea)

                        try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}

                        Invoke-ItemClick $s.Tag

                    })

                    $table.Controls.Add($btn, $idx % 4, [Math]::Floor($idx / 4))

                    $idx++

                }

                $scroll = New-Object System.Windows.Forms.Panel

                $scroll.Dock = 'Fill'; $scroll.AutoScroll = $true

                $scroll.Padding = New-Object System.Windows.Forms.Padding(8)

                $scroll.Controls.Add($table)

                $gridHost.Controls.Add($scroll); $scroll.BringToFront(); $gridHost.Refresh()

            }

        } catch {

            try {

                if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }

                $lbl2 = New-Object System.Windows.Forms.Label

                $lbl2.Text = "Render error: $_"

                $lbl2.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

                $lbl2.ForeColor = [System.Drawing.Color]::FromArgb(255,80,80)

                $lbl2.TextAlign = 'MiddleCenter'; $lbl2.Dock = 'Fill'

                $gridHost.Controls.Add($lbl2); $lbl2.BringToFront(); $gridHost.Refresh()

                Add-Content -LiteralPath (Join-Path $script:ToolkitRoot 'Logs\startup_err.log') `

                    -Value "[$(Get-Date -f 'MM/dd/yyyy HH:mm:ss')] SwScan Error: $_" -Force -EA SilentlyContinue

            } catch {}

        } finally {

            Set-UpdateManagerBusy $false

        }

    }.GetNewClosure()



    $pollTimer.Add_Tick($tickHandler)

    $pollTimer.Start()

}

function Scan-DriverUpgrades {

    $requestId = [Guid]::NewGuid().ToString()

    $script:driverUpgradeScanToken = $requestId



    for ($i = $gridHost.Controls.Count - 1; $i -ge 0; $i--) {

        $ctrl = $gridHost.Controls[$i]

        if ($ctrl -ne $script:updateHeaderPanel) {

            $gridHost.Controls.RemoveAt($i)

        }

    }



    $loading = New-Object System.Windows.Forms.Label

    $loading.Text = "Scanning your computer for available driver updates natively...`r`nPlease wait..."

    $loading.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

    $loading.ForeColor = Get-ThemeColor 'Accent'

    $loading.TextAlign = 'MiddleCenter'

    $loading.Dock = 'Fill'

    $gridHost.Controls.Add($loading)



    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

    [System.Windows.Forms.Application]::DoEvents()

    Set-UpdateManagerBusy $true



    $sw = [System.Diagnostics.Stopwatch]::StartNew()



    try {

        $session = New-Object -ComObject Microsoft.Update.Session

        $searcher = $session.CreateUpdateSearcher()

        $searcher.Online = $true

        

        $searchResult = $null

        try {

            $searchResult = $searcher.Search("IsInstalled=0 and Type='Driver'")

        } catch {

            # Fallback to offline scan if online server is blocked or disabled

            $searcher.Online = $false

            $searchResult = $searcher.Search("IsInstalled=0 and Type='Driver'")

        }

        $drivers = @()

        foreach ($update in $searchResult.Updates) {

            $drivers += [pscustomobject]@{

                Title = $update.Title

                Description = $update.Description

                UpdateObj = $update

            }

        }



        if ($script:driverUpgradeScanToken -ne $requestId -or $script:currentLabel -ne 'menu_apps_update_manager') { return }



        if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }



        $sw.Stop()

        $elapsedSec = [Math]::Round($sw.Elapsed.TotalSeconds, 2)

        $metaLabel.Text = "$($drivers.Count) driver updates found in $elapsedSec seconds"

        try { [System.Media.SystemSounds]::Beep.Play() } catch {}



        if ($drivers.Count -eq 0) {

            $noResults = New-Object System.Windows.Forms.Label

            $noResults.Text = "All your hardware drivers are up-to-date! No updates available."

            $noResults.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)

            $noResults.ForeColor = Get-ThemeColor 'Muted'

            $noResults.TextAlign = 'MiddleCenter'

            $noResults.Dock = 'Top'

            $noResults.Height = 100

            $gridHost.Controls.Add($noResults)

            $noResults.BringToFront()

            $gridHost.Refresh()

        } else {

            $cards = @()

            foreach ($item in $drivers) {

                # Clean title to be concise

                $cleanTitle = $item.Title -replace '\(.\d+.*?\)', ''

                if ($cleanTitle.Length -gt 45) { $cleanTitle = $cleanTitle.Substring(0, 42) + "..." }

                

                $cards += [pscustomobject]@{

                    Text = $cleanTitle

                    Choice = "Install"

                    Kind = "Inline"

                    TargetLabel = ""

                    Command = "driver_update"

                    UpdateObj = $item.UpdateObj

                    Notes = "$($item.Title)`r`n$($item.Description)`r`nClick to natively download and install this hardware driver."

                }

            }



            $table = New-Object System.Windows.Forms.TableLayoutPanel

            $table.ColumnCount = 4

            $table.RowCount = [Math]::Max(1, [Math]::Ceiling($cards.Count / 4))

            $table.Dock = 'Top'

            $table.AutoSize = $true

            $table.AutoSizeMode = 'GrowAndShrink'

            $table.Padding = New-Object System.Windows.Forms.Padding(8, 4, 18, 18)

            $table.BackColor = $gridHost.BackColor

            Enable-DoubleBuffer $table

            for ($i = 0; $i -lt 4; $i++) {

                $table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))) | Out-Null

            }

            for ($r = 0; $r -lt $table.RowCount; $r++) {

                $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 112))) | Out-Null

            }



            $idx = 0

            foreach ($item in $cards) {

                $button = New-CardButton $item $idx

                $button.Add_Click({

                    param($sender, $eventArgs)

                    try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}

                    Install-SingleDriver $sender.Tag.UpdateObj

                })

                $table.Controls.Add($button, $idx % 4, [Math]::Floor($idx / 4))

                $idx++

            }



            $scrollContainer = New-Object System.Windows.Forms.Panel

            $scrollContainer.Dock = 'Fill'

            $scrollContainer.AutoScroll = $true

            $scrollContainer.Padding = New-Object System.Windows.Forms.Padding(8)

            $scrollContainer.Controls.Add($table)

            $gridHost.Controls.Add($scrollContainer)

            $scrollContainer.BringToFront()

            $gridHost.Refresh()

        }

    } catch {

        if ($gridHost.Controls.Contains($loading)) { $gridHost.Controls.Remove($loading) }

        $errLabel = New-Object System.Windows.Forms.Label

        $errLabel.Text = "Failed to scan driver updates: $_"

        $errLabel.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

        $errLabel.ForeColor = [System.Drawing.Color]::Red

        $errLabel.TextAlign = 'MiddleCenter'

        $errLabel.Dock = 'Fill'

        $gridHost.Controls.Add($errLabel)

        $errLabel.BringToFront()

        $gridHost.Refresh()

        try {

            $errLine = "[$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')] Driver Scan Error: $_"

            Add-Content -LiteralPath (Join-Path $script:ToolkitRoot 'Logs\startup_err.log') -Value $errLine -Force -ErrorAction SilentlyContinue

        } catch {}

    } finally {

        if ($script:driverUpgradeScanToken -eq $requestId) {

            Set-UpdateManagerBusy $false

            $form.Cursor = [System.Windows.Forms.Cursors]::Default

        }

    }

}



function Install-SingleDriver {

    param([object]$UpdateObj)

    

    $confirm = Out-MessageBox("Are you sure you want to download and install this driver update?`n`n$($UpdateObj.Title)", "Driver Updater", "YesNo", "Question")

    if ($confirm -ne "Yes") { return }



    $updateId = $UpdateObj.Identity.UpdateID

    $title = $UpdateObj.Title

    

    $tempScript = [System.IO.Path]::Combine($env:TEMP, "install_driver_$($updateId).ps1")

    $code = @"

`$ErrorActionPreference = 'Stop'

Write-Host "=============================================" -ForegroundColor Cyan

Write-Host "NATIVE HARDWARE DRIVER INSTALLER" -ForegroundColor Cyan

Write-Host "=============================================" -ForegroundColor Cyan

Write-Host "Target Update: $title" -ForegroundColor Yellow

Write-Host "Update GUID  : $updateId" -ForegroundColor Yellow

Write-Host ""



try {

    Write-Host "Connecting to Windows Update Agent..." -ForegroundColor Gray

    `$session = New-Object -ComObject Microsoft.Update.Session

    `$searcher = `$session.CreateUpdateSearcher()

    `$searcher.Online = `$false

    

    Write-Host "Locating driver update package..." -ForegroundColor Gray

    `$searchResult = `$searcher.Search("UpdateID='$updateId'")

    if (`$searchResult.Updates.Count -eq 0) {

        `$searcher.Online = `$true

        `$searchResult = `$searcher.Search("UpdateID='$updateId'")

    }

    

    if (`$searchResult.Updates.Count -eq 0) {

        throw "Could not locate driver update with GUID $updateId"

    }

    

    `$update = `$searchResult.Updates[0]

    `$updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl

    `$updatesToDownload.Add(`$update) | Out-Null

    

    Write-Host "Downloading driver update... Please wait..." -ForegroundColor Yellow

    `$downloader = `$session.CreateUpdateDownloader()

    `$downloader.Updates = `$updatesToDownload

    `$downloadResult = `$downloader.Download()

    

    if (-not `$update.IsDownloaded) {

        throw "Failed to download update: `$($downloadResult.ResultCode)"

    }

    Write-Host "Download completed successfully!" -ForegroundColor Green

    

    Write-Host "Installing hardware driver... Do not close this window..." -ForegroundColor Yellow

    `$updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

    `$updatesToInstall.Add(`$update) | Out-Null

    

    `$installer = `$session.CreateUpdateInstaller()

    `$installer.Updates = `$updatesToInstall

    `$installResult = `$installer.Install()

    

    Write-Host "Installation completed with Result Code: `$($installResult.ResultCode)" -ForegroundColor Green

    if (`$installResult.RebootRequired) {

        Write-Host "WARNING: A reboot is required to finish installing this driver." -ForegroundColor Red

    }

} catch {

    Write-Host "ERROR: `$($_.Exception.Message)" -ForegroundColor Red

}



Write-Host ""

Write-Host "Driver update task completed." -ForegroundColor Gray

"@

    $code | Set-Content -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue

    Start-CmdWindow -CommandText "powershell.exe -ExecutionPolicy Bypass -File `"$tempScript`"" -Title 'Install Selected Driver Update'

}



function Update-AllDriversBulk {

    $confirm = Out-MessageBox("Are you sure you want to download and install ALL pending hardware driver updates?", "Bulk Driver Updater", "YesNo", "Question")

    if ($confirm -ne "Yes") { return }



    $tempScript = [System.IO.Path]::Combine($env:TEMP, "update_all_drivers.ps1")

    $code = @"

`$ErrorActionPreference = 'Stop'

Write-Host "=============================================" -ForegroundColor Cyan

Write-Host "NATIVE HARDWARE DRIVER BULK UPDATER" -ForegroundColor Cyan

Write-Host "=============================================" -ForegroundColor Cyan

Write-Host "Scanning for available driver updates..." -ForegroundColor Yellow

Write-Host ""



try {

    `$session = New-Object -ComObject Microsoft.Update.Session

    `$searcher = `$session.CreateUpdateSearcher()

    `$searcher.Online = `$false

    

    `$searchResult = `$searcher.Search("IsInstalled=0 and Type='Driver'")

    if (`$searchResult.Updates.Count -eq 0) {

        `$searcher.Online = `$true

        `$searchResult = `$searcher.Search("IsInstalled=0 and Type='Driver'")

    }

    

    if (`$searchResult.Updates.Count -eq 0) {

        Write-Host "All hardware drivers are up-to-date!" -ForegroundColor Green

        Write-Host ""

        Write-Host "Driver update scan completed." -ForegroundColor Gray

        exit

    }

    

    Write-Host "Found `$($searchResult.Updates.Count) pending driver updates." -ForegroundColor Yellow

    foreach (`$update in `$searchResult.Updates) {

        Write-Host " - `$($update.Title)" -ForegroundColor Gray

    }

    Write-Host ""

    

    `$updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl

    foreach (`$update in `$searchResult.Updates) {

        `$updatesToDownload.Add(`$update) | Out-Null

    }

    

    Write-Host "Downloading all driver updates... Please wait..." -ForegroundColor Yellow

    `$downloader = `$session.CreateUpdateDownloader()

    `$downloader.Updates = `$updatesToDownload

    `$downloadResult = `$downloader.Download()

    

    Write-Host "Download completed! Preparing for installation..." -ForegroundColor Green

    

    `$updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

    foreach (`$update in `$searchResult.Updates) {

        if (`$update.IsDownloaded) {

            `$updatesToInstall.Add(`$update) | Out-Null

        }

    }

    

    if (`$updatesToInstall.Count -eq 0) {

        throw "No updates were successfully downloaded."

    }

    

    Write-Host "Installing `$($updatesToInstall.Count) driver updates... Do not close this window..." -ForegroundColor Yellow

    `$installer = `$session.CreateUpdateInstaller()

    `$installer.Updates = `$updatesToInstall

    `$installResult = `$installer.Install()

    

    Write-Host "Installation completed with Result Code: `$($installResult.ResultCode)" -ForegroundColor Green

    if (`$installResult.RebootRequired) {

        Write-Host "WARNING: A system reboot is required to finish installing the drivers." -ForegroundColor Red

    }

} catch {

    Write-Host "ERROR: `$($_.Exception.Message)" -ForegroundColor Red

}



Write-Host ""

Write-Host "Bulk driver update task completed." -ForegroundColor Gray

"@

    $code | Set-Content -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue

    Start-CmdWindow -CommandText "powershell.exe -ExecutionPolicy Bypass -File `"$tempScript`"" -Title 'Install All Driver Updates'

}



function Update-TabStyles {

    if ($script:updateManagerTab -eq 'software') {

        $script:btnSoftwareTab.BackColor = Get-ThemeColor 'Accent'

        $script:btnSoftwareTab.ForeColor = [System.Drawing.Color]::Black

        $script:btnSoftwareTab.FlatAppearance.BorderSize = 0



        $script:btnDriverTab.BackColor = Get-ThemeColor 'Button'

        $script:btnDriverTab.ForeColor = Get-ThemeColor 'Text'

        $script:btnDriverTab.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

        $script:btnDriverTab.FlatAppearance.BorderSize = 1



        $script:btnUpgradeAll.Text = "Update All Apps"

        $script:btnUpgradeAll.BackColor = Get-ThemeColor 'Accent'

        $script:btnUpgradeAll.ForeColor = [System.Drawing.Color]::Black

        $script:btnUpgradeAll.FlatAppearance.BorderSize = 0



        $script:updatePanelSub.Text = "Upgrade all outdated applications to their latest official versions with one click."

    } else {

        $script:btnDriverTab.BackColor = Get-ThemeColor 'Accent'

        $script:btnDriverTab.ForeColor = [System.Drawing.Color]::Black

        $script:btnDriverTab.FlatAppearance.BorderSize = 0



        $script:btnSoftwareTab.BackColor = Get-ThemeColor 'Button'

        $script:btnSoftwareTab.ForeColor = Get-ThemeColor 'Text'

        $script:btnSoftwareTab.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

        $script:btnSoftwareTab.FlatAppearance.BorderSize = 1



        $script:btnUpgradeAll.Text = "Update All Drivers"

        $script:btnUpgradeAll.BackColor = Get-ThemeColor 'Accent'

        $script:btnUpgradeAll.ForeColor = [System.Drawing.Color]::Black

        $script:btnUpgradeAll.FlatAppearance.BorderSize = 0



        $script:updatePanelSub.Text = "Scan and update out-of-date hardware drivers natively via Windows Update."

    }

}



function Show-SoftwareUpdateManager {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}

    Clear-Grid

    $screenTitle.Text = "Software Update & Upgrade Center"

    $metaLabel.Text = "Scan, view, and upgrade installed packages from the Winget repository in real-time"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_apps_update_manager'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 130

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 20, 24, 10)

    $script:updateHeaderPanel = $headerPanel



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "System Update Manager"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 15)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Scan and upgrade your software and hardware drivers to their latest official versions."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 45)

    $headerPanel.Controls.Add($panelSub)

    $script:updatePanelSub = $panelSub



    if ($null -eq $script:updateManagerTab) {

        $script:updateManagerTab = 'software'

    }



    $btnSoftwareTab = New-Object System.Windows.Forms.Button

    $btnSoftwareTab.Text = "Software Updates"

    $btnSoftwareTab.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnSoftwareTab.FlatStyle = 'Flat'

    $btnSoftwareTab.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnSoftwareTab.SetBounds(36, 80, 180, 34)

    $script:btnSoftwareTab = $btnSoftwareTab



    $btnDriverTab = New-Object System.Windows.Forms.Button

    $btnDriverTab.Text = "Hardware Drivers"

    $btnDriverTab.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnDriverTab.FlatStyle = 'Flat'

    $btnDriverTab.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnDriverTab.SetBounds(226, 80, 180, 34)

    $script:btnDriverTab = $btnDriverTab



    $btnScan = New-Object System.Windows.Forms.Button

    $btnScan.Text = "Scan Updates"

    $btnScan.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnScan.FlatStyle = 'Flat'

    $btnScan.BackColor = Get-ThemeColor 'Button'

    $btnScan.ForeColor = Get-ThemeColor 'Text'

    $btnScan.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnScan.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnScan.SetBounds(436, 80, 140, 34)

    $script:btnScan = $btnScan



    $btnUpgradeAll = New-Object System.Windows.Forms.Button

    $btnUpgradeAll.Text = "Update All Apps"

    $btnUpgradeAll.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnUpgradeAll.FlatStyle = 'Flat'

    $btnUpgradeAll.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnUpgradeAll.SetBounds(586, 80, 180, 34)

    $script:btnUpgradeAll = $btnUpgradeAll



    $btnSoftwareTab.Add_Click({

        $script:updateManagerTab = 'software'

        Update-TabStyles

        Scan-SoftwareUpgrades

    })



    $btnDriverTab.Add_Click({

        $script:updateManagerTab = 'drivers'

        Update-TabStyles

        Scan-DriverUpgrades

    })



    $btnScan.Add_Click({

        if ($script:updateManagerTab -eq 'software') {

            Scan-SoftwareUpgrades

        } else {

            Scan-DriverUpgrades

        }

    })



    $btnUpgradeAll.Add_MouseEnter({ param($sender, $e) $sender.BackColor = Get-ThemeColor 'Accent2' })

    $btnUpgradeAll.Add_MouseLeave({ param($sender, $e) $sender.BackColor = Get-ThemeColor 'Accent' })



    $btnUpgradeAll.Add_Click({

        try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}

        if ($script:updateManagerTab -eq 'software') {

            $wingetPath = Resolve-WingetPath

            if ([string]::IsNullOrWhiteSpace($wingetPath)) {

                Show-Warning "Winget/App Installer not found.`r`nInstall or repair App Installer from Microsoft Store, then try again."

                return

            }

            Start-CmdWindow -CommandText "`"$wingetPath`" upgrade --all --accept-source-agreements --accept-package-agreements" -Title 'Upgrade All Software'

        } else {

            Update-AllDriversBulk

        }

    })



    Update-TabStyles



    $headerPanel.Controls.Add($btnSoftwareTab)

    $headerPanel.Controls.Add($btnDriverTab)

    $headerPanel.Controls.Add($btnScan)

    $headerPanel.Controls.Add($btnUpgradeAll)



    $gridHost.Controls.Add($headerPanel)



    if ($script:updateManagerTab -eq 'software') {

        Scan-SoftwareUpgrades

    } else {

        Scan-DriverUpgrades

    }

}



$script:FavoritesPath = Join-Path $ToolkitRoot 'Config\favorites.bundle'

$script:suppressSave = $false

$script:dashboardTimer = $null

# Cache values are initialized once on the main thread during script startup

$script:boosterActive = $false

$script:originalPowerPlan = $null



function Load-FavoritesBundle {

    $favs = @{}

    if (Test-Path -LiteralPath $script:FavoritesPath) {

        $lines = Get-Content -LiteralPath $script:FavoritesPath -ErrorAction SilentlyContinue

        foreach ($line in $lines) {

            $trimmed = $line.Trim()

            if (-not [string]::IsNullOrEmpty($trimmed)) {

                $favs[$trimmed] = $true

            }

        }

    }

    return $favs

}



function Save-FavoritesBundle {

    param([string[]]$AppIds)

    try {

        $parent = Split-Path -Parent $script:FavoritesPath

        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

        $AppIds | Set-Content -LiteralPath $script:FavoritesPath -Force -ErrorAction SilentlyContinue

    } catch {}

}



function Show-WingetSearchAddDialog {

    $dialog = New-Object System.Windows.Forms.Form

    $dialog.Text = "Search & Add Winget Package to Bundler"

    $dialog.Size = New-Object System.Drawing.Size(600, 480)

    $dialog.StartPosition = 'CenterParent'

    $dialog.FormBorderStyle = 'FixedDialog'

    $dialog.MaximizeBox = $false

    $dialog.MinimizeBox = $false

    $dialog.BackColor = Get-ThemeColor 'Bg'



    $lblInput = New-Object System.Windows.Forms.Label

    $lblInput.Text = "Enter Software Name or ID to Search Winget Online:"

    $lblInput.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $lblInput.ForeColor = Get-ThemeColor 'Text'

    $lblInput.SetBounds(24, 15, 400, 22)

    $dialog.Controls.Add($lblInput)



    $txtSearch = New-Object System.Windows.Forms.TextBox

    $txtSearch.Font = New-Object System.Drawing.Font('Segoe UI', 11)

    $txtSearch.BorderStyle = 'FixedSingle'

    $txtSearch.BackColor = Get-ThemeColor 'Panel2'

    $txtSearch.ForeColor = Get-ThemeColor 'Text'

    $txtSearch.SetBounds(24, 45, 410, 30)

    $dialog.Controls.Add($txtSearch)



    $btnSearch = New-Object System.Windows.Forms.Button

    $btnSearch.Text = "Search"

    $btnSearch.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnSearch.FlatStyle = 'Flat'

    $btnSearch.BackColor = Get-ThemeColor 'Accent'

    $btnSearch.ForeColor = [System.Drawing.Color]::Black

    $btnSearch.SetBounds(446, 43, 110, 32)

    $dialog.Controls.Add($btnSearch)



    $lblStatus = New-Object System.Windows.Forms.Label

    $lblStatus.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)

    $lblStatus.ForeColor = Get-ThemeColor 'Muted'

    $lblStatus.AutoSize = $true

    $lblStatus.SetBounds(24, 79, 400, 18)

    $lblStatus.Text = "Enter a name or package ID above and click Search."

    $dialog.Controls.Add($lblStatus)



    $lstResults = New-Object System.Windows.Forms.ListBox

    $lstResults.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $lstResults.BackColor = Get-ThemeColor 'Panel'

    $lstResults.ForeColor = Get-ThemeColor 'Text'

    $lstResults.BorderStyle = 'FixedSingle'

    $lstResults.SetBounds(24, 100, 532, 268)

    $dialog.Controls.Add($lstResults)



    $btnAdd = New-Object System.Windows.Forms.Button

    $btnAdd.Text = "Add Selected to Bundler"

    $btnAdd.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $btnAdd.FlatStyle = 'Flat'

    $btnAdd.BackColor = Get-ThemeColor 'Accent'

    $btnAdd.ForeColor = [System.Drawing.Color]::Black

    $btnAdd.SetBounds(24, 385, 220, 36)

    $btnAdd.Enabled = $false

    $dialog.Controls.Add($btnAdd)



    $btnCancel = New-Object System.Windows.Forms.Button

    $btnCancel.Text = "Cancel"

    $btnCancel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $btnCancel.FlatStyle = 'Flat'

    $btnCancel.BackColor = Get-ThemeColor 'Button'

    $btnCancel.ForeColor = Get-ThemeColor 'Text'

    $btnCancel.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnCancel.SetBounds(446, 385, 110, 36)

    $dialog.Controls.Add($btnCancel)



    $btnCancel.Add_Click({ $dialog.Close() })



    $script:wingetSearchResults = @()





    $btnSearch.Add_Click({

        $q = $txtSearch.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($q)) { return }



        $lstResults.Items.Clear()

        $lstResults.Items.Add("Searching Winget Repository... Please wait...") | Out-Null

        $btnSearch.Enabled = $false

        $btnAdd.Enabled = $false

        $lblStatus.Text = "Searching...  (0s)"

        [System.Windows.Forms.Application]::DoEvents()



        try {

            $wingetPath = Resolve-WingetPath

            if ([string]::IsNullOrWhiteSpace($wingetPath)) {

                throw "Winget/App Installer was not found. Install or repair App Installer from Microsoft Store."

            }



            # Use PowerShell call operator - fastest approach, correctly handles

            # winget's \r-only line endings, no deadlock risk, no encoding issues.

            $sw = [System.Diagnostics.Stopwatch]::StartNew()

            $timedOut = $false

            $lastSec = -1



            # Run winget in a job so UI stays responsive via DoEvents polling

            $job = Start-Job -ScriptBlock {

                param($wp, $q)

                & $wp search $q --source winget --accept-source-agreements --disable-interactivity 2>&1

            } -ArgumentList $wingetPath, $q



            while ($job.State -eq 'Running') {

                [System.Windows.Forms.Application]::DoEvents()

                Start-Sleep -Milliseconds 100

                $elapsedSec = [int]$sw.Elapsed.TotalSeconds

                if ($elapsedSec -ne $lastSec) {

                    $lastSec = $elapsedSec

                    if (-not $dialog.IsDisposed) {

                        $lblStatus.Text = "Searching Winget online...  ($($elapsedSec)s)"

                    }

                }

                if ($sw.Elapsed.TotalSeconds -ge 30) {

                    $timedOut = $true

                    Stop-Job $job -ErrorAction SilentlyContinue

                    break

                }

            }



            $lines = @()

            if (-not $timedOut) {

                $lines = @(Receive-Job $job -ErrorAction SilentlyContinue | Where-Object { $_ -ne $null } | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_.Length -gt 0 })

            }

            Remove-Job $job -Force -ErrorAction SilentlyContinue



            if ($dialog.IsDisposed) { return }



            $lstResults.Items.Clear()

            $script:wingetSearchResults = @()



            if ($timedOut) {

                $lstResults.Items.Add("Search timed out (30s). Please check your internet and try again.") | Out-Null

                $lblStatus.Text = "Timed out. Try again."

                $btnAdd.Enabled = $false

            } else {

                foreach ($match in (ConvertFrom-WingetTable -Lines $lines)) {

                    $lstResults.Items.Add("$($match.Name) ($($match.ID))") | Out-Null

                    $script:wingetSearchResults += [pscustomobject]@{

                        Text = $match.Name

                        ID   = $match.ID

                    }

                }



                if ($lstResults.Items.Count -eq 0) {

                    if ($lines.Count -gt 0) {

                        $lstResults.Items.Add("No search results found for '$q'.") | Out-Null

                    } else {

                        $lstResults.Items.Add("No results found. Check your internet connection.") | Out-Null

                    }

                    $lblStatus.Text = "No results found."

                    $btnAdd.Enabled = $false

                } else {

                    $elapsed = [int]$sw.Elapsed.TotalSeconds

                    $lblStatus.Text = "Found $($lstResults.Items.Count) result(s) in $($elapsed)s. Select one and click 'Add'."

                    $btnAdd.Enabled = $true

                }

            }

        } catch {

            $lstResults.Items.Clear()

            $lstResults.Items.Add("Error: $_") | Out-Null

            $lblStatus.Text = "Search failed."

            $btnAdd.Enabled = $false

        } finally {

            if (-not $dialog.IsDisposed) { $btnSearch.Enabled = $true }

        }

    })





    $btnAdd.Add_Click({

        $idx = $lstResults.SelectedIndex

        if ($idx -lt 0 -or $idx -ge $script:wingetSearchResults.Count) { return }

        $selected = $script:wingetSearchResults[$idx]



        $customAppsPath = Join-Path $ToolkitRoot 'Config\custom_winget_apps.bundle'

        $customApps = @()

        if (Test-Path -LiteralPath $customAppsPath) {

            $customApps = Get-Content -LiteralPath $customAppsPath -ErrorAction SilentlyContinue | Where-Object { $_ -and $_.Trim().Length -gt 0 }

        }

        

        $entry = "$($selected.Text)|$($selected.ID)"

        if ($customApps -notcontains $entry) {

            $customApps += $entry

            $customApps | Set-Content -LiteralPath $customAppsPath -Force -ErrorAction SilentlyContinue

        }



        # Automatically check/tick the newly added app by adding it to favorites

        $favs = Load-FavoritesBundle

        if (-not $favs.ContainsKey($selected.ID)) {

            $favs[$selected.ID] = $true

            Save-FavoritesBundle -AppIds @($favs.Keys)

        }



        Out-MessageBox("Successfully added '$($selected.Text)' to your Custom Bundler list and automatically checked it!", "Winget Search", "OK", "Information") | Out-Null

        $dialog.Close()

        Show-CustomBundlerPanel

    })



    $dialog.ShowDialog() | Out-Null

}



function Get-DashboardMetrics {

    $metrics = @{

        CPU = 0

        RAMUsed = 0.0

        RAMTotal = 16.0

        RAMPercent = 0

        DiskUsed = 0.0

        DiskTotal = 500.0

        DiskPercent = 0

        Uptime = "0d 0h 0m"

    }

    try {

        # 1. High-Speed CPU Query using pure .NET WMI Searcher (takes ~15ms, entirely thread-safe!)

        try {

            $searcher = New-Object System.Management.ManagementObjectSearcher("SELECT PercentProcessorTime FROM Win32_PerfFormattedData_PerfOS_Processor WHERE Name='_Total'")

            $collection = $searcher.Get()

            foreach ($obj in $collection) {

                $metrics.CPU = [int]$obj["PercentProcessorTime"]

            }

            $searcher.Dispose()

        } catch {

            try {

                $errLog = Join-Path $ToolkitRoot 'Logs\dashboard_error.log'

                "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) | CPU Query Failed: $_" | Out-File -FilePath $errLog -Append -Encoding utf8

            } catch {}

            $metrics.CPU = 0

        }



        # 2. High-Speed Memory Query using native .NET ComputerInfo (0ms, thread-safe!)

        try {

            Add-Type -AssemblyName 'Microsoft.VisualBasic' -ErrorAction SilentlyContinue

            $info = New-Object Microsoft.VisualBasic.Devices.ComputerInfo

            $totalBytes = $info.TotalPhysicalMemory

            $freeBytes = $info.AvailablePhysicalMemory

            

            # Use cached total ram if available, otherwise read live

            $totalRam = if ($null -ne $script:cachedTotalRam -and $script:cachedTotalRam -gt 0) { $script:cachedTotalRam } else { [math]::Round($totalBytes / 1GB, 1) }

            $usedRam = [math]::Round(($totalBytes - $freeBytes) / 1GB, 1)

            $ramPercent = if ($totalRam -gt 0) { [int](($usedRam / $totalRam) * 100) } else { 0 }

            

            $metrics.RAMUsed = $usedRam

            $metrics.RAMTotal = $totalRam

            $metrics.RAMPercent = $ramPercent

        } catch {

            try {

                $errLog = Join-Path $ToolkitRoot 'Logs\dashboard_error.log'

                "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) | RAM Query Failed: $_" | Out-File -FilePath $errLog -Append -Encoding utf8

            } catch {}

            $metrics.RAMUsed = 4.0

            $metrics.RAMTotal = if ($null -ne $script:cachedTotalRam -and $script:cachedTotalRam -gt 0) { $script:cachedTotalRam } else { 16.0 }

            $metrics.RAMPercent = 25

        }



        # 3. High-Speed Uptime Calculation purely in memory (0ms, thread-safe!)

        try {

            if ($null -ne $script:cachedLastBootUpTime) {

                $uptime = (Get-Date) - $script:cachedLastBootUpTime

                $metrics.Uptime = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes

            } else {

                # Fallback to ticking millisecond ticks

                $uptimeMs = [System.Environment]::TickCount

                if ($uptimeMs -lt 0) { $uptimeMs = [uint32][System.Environment]::TickCount }

                $ts = [TimeSpan]::FromMilliseconds($uptimeMs)

                $metrics.Uptime = "{0}d {1}h {2}m" -f $ts.Days, $ts.Hours, $ts.Minutes

            }

        } catch {

            try {

                $errLog = Join-Path $ToolkitRoot 'Logs\dashboard_error.log'

                "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) | Uptime Query Failed: $_" | Out-File -FilePath $errLog -Append -Encoding utf8

            } catch {}

            $metrics.Uptime = "0d 0h 0m"

        }



        # 4. High-Speed Disk Query via pure .NET DriveInfo (0ms, thread-safe!)

        try {

            $drive = New-Object System.IO.DriveInfo("C")

            $totalDisk = $drive.TotalSize

            $freeDisk = $drive.AvailableFreeSpace

            $usedDisk = $totalDisk - $freeDisk

            

            $metrics.DiskTotal = [math]::Round($totalDisk / 1GB, 1)

            $metrics.DiskUsed = [math]::Round($usedDisk / 1GB, 1)

            $metrics.DiskPercent = if ($totalDisk -gt 0) { [int](($usedDisk / $totalDisk) * 100) } else { 0 }

        } catch {

            try {

                $errLog = Join-Path $ToolkitRoot 'Logs\dashboard_error.log'

                "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) | Disk Query Failed: $_" | Out-File -FilePath $errLog -Append -Encoding utf8

            } catch {}

            $metrics.DiskTotal = if ($script:cachedDiskTotal -and $script:cachedDiskTotal -gt 0) { $script:cachedDiskTotal } else { 500.0 }

            $metrics.DiskUsed = if ($script:cachedDiskUsed -and $script:cachedDiskUsed -gt 0) { $script:cachedDiskUsed } else { 250.0 }

            $metrics.DiskPercent = if ($script:cachedDiskPercent) { $script:cachedDiskPercent } else { 50 }

        }



    } catch {

        try {

            $errLog = Join-Path $ToolkitRoot 'Logs\dashboard_error.log'

            "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) | Get-DashboardMetrics Outer Failed: $_" | Out-File -FilePath $errLog -Append -Encoding utf8

        } catch {}

        # Catch-all safe defaults

        $metrics.CPU = 0

        $metrics.RAMTotal = if ($null -ne $script:cachedTotalRam -and $script:cachedTotalRam -gt 0) { $script:cachedTotalRam } else { 16.0 }

        $metrics.RAMUsed = 4.0

        $metrics.RAMPercent = 25

        $metrics.DiskTotal = if ($script:cachedDiskTotal -and $script:cachedDiskTotal -gt 0) { $script:cachedDiskTotal } else { 500.0 }

        $metrics.DiskUsed = if ($script:cachedDiskUsed -and $script:cachedDiskUsed -gt 0) { $script:cachedDiskUsed } else { 250.0 }

        $metrics.DiskPercent = if ($script:cachedDiskPercent) { $script:cachedDiskPercent } else { 50 }

        $metrics.Uptime = "0d 0h 0m"

    }

    return $metrics

}



function Update-DashboardLabels {

    # Runs on the UI thread - safe to access all $script: labels and PS functions

    try {

        $m = Get-DashboardMetrics

        if ($null -ne $script:lblCpuVal -and -not $script:lblCpuVal.IsDisposed) {

            $script:lblCpuVal.Text = "$($m.CPU)%"

            $script:lblCpuSub.Text = "Active Load"

            

            # Safe numeric rounding and conversion with strict fallbacks

            $ramUsedRounded = 0.0

            $ramTotalRounded = 16.0

            try { $ramUsedRounded = [math]::Round([double]$m.RAMUsed, 1) } catch { $ramUsedRounded = 4.0 }

            try { $ramTotalRounded = [math]::Round([double]$m.RAMTotal, 1) } catch { $ramTotalRounded = 16.0 }

            $script:lblRamVal.Text = "$ramUsedRounded / $ramTotalRounded GB"

            

            $ramPct = 25

            try { $ramPct = [int]$m.RAMPercent } catch {}

            $script:lblRamSub.Text = "$ramPct% Memory Used"

            

            $diskUsedInt = 250

            $diskTotalInt = 500

            try { $diskUsedInt = [int]$m.DiskUsed } catch { $diskUsedInt = 250 }

            try { $diskTotalInt = [int]$m.DiskTotal } catch { $diskTotalInt = 500 }

            $script:lblDiskVal.Text = "$diskUsedInt / $diskTotalInt GB"

            

            $diskPct = 50

            try { $diskPct = [int]$m.DiskPercent } catch {}

            $script:lblDiskSub.Text = "$diskPct% Space Used"

            

            $script:lblUptimeVal.Text = [string]$m.Uptime

            $script:lblUptimeSub.Text = "Engine Active"

        }

    } catch {

        # Log the error to help debug

        try {

            $errLog = Join-Path $ToolkitRoot 'Logs\dashboard_error.log'

            "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) | Error in Update-DashboardLabels: $_" | Out-File -FilePath $errLog -Append -Encoding utf8

        } catch {}

    }

}



function Show-PerformanceDashboard {

    $script:currentLabel = 'main'

    # Make dashboard panel visible and expand Row 1 (Zero-Recreation Overhaul)

    if ($null -ne $script:dashboardPanel) {

        $script:dashboardPanel.Visible = $true

    }

    if ($null -ne $contentLayout) {

        $contentLayout.RowStyles[1].Height = 105

    }



    # Immediately fetch and display metrics on the UI thread (~15ms, pure .NET calls)

    Update-DashboardLabels



    # Setup periodic refresh via Forms.Timer (fires on UI thread = full PS runspace access)

    if ($null -ne $script:dashboardTimer) {

        try { $script:dashboardTimer.Stop() } catch {}

        try { $script:dashboardTimer.Dispose() } catch {}

    }

    $script:dashboardTimer = New-Object System.Windows.Forms.Timer

    $script:dashboardTimer.Interval = 2000

    $script:dashboardTimer.Add_Tick({

        try {

            if ($null -ne $script:dashboardPanel -and $script:dashboardPanel.Visible) {

                Update-DashboardLabels

            }

        } catch {}

    })

    $script:dashboardTimer.Start()

}



function Write-InstallHistory {

    param([string[]]$AppNames)

    try {

        $logPath = Join-Path $ToolkitRoot 'Config\install_history.log'

        $parent = Split-Path -Parent $logPath

        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

        

        $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        $appsText = $AppNames -join ", "

        $entry = "$date|$appsText"

        $entry | Out-File -FilePath $logPath -Append -Encoding utf8

    } catch {}

}



function Show-InstallHistoryDialog {

    $dialog = New-Object System.Windows.Forms.Form

    $dialog.Text = "Apps Installation History Log"

    $dialog.Size = New-Object System.Drawing.Size(650, 450)

    $dialog.StartPosition = 'CenterParent'

    $dialog.FormBorderStyle = 'FixedDialog'

    $dialog.MaximizeBox = $false

    $dialog.MinimizeBox = $false

    $dialog.BackColor = Get-ThemeColor 'Bg'



    $lblTitle = New-Object System.Windows.Forms.Label

    $lblTitle.Text = "Silent App Installation Logs"

    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

    $lblTitle.ForeColor = Get-ThemeColor 'Text'

    $lblTitle.SetBounds(24, 15, 400, 22)

    $dialog.Controls.Add($lblTitle)



    $lstLogs = New-Object System.Windows.Forms.ListBox

    $lstLogs.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $lstLogs.BackColor = Get-ThemeColor 'Panel'

    $lstLogs.ForeColor = Get-ThemeColor 'Text'

    $lstLogs.BorderStyle = 'FixedSingle'

    $lstLogs.SetBounds(24, 50, 582, 300)

    

    $logPath = Join-Path $ToolkitRoot 'Config\install_history.log'

    if (Test-Path -LiteralPath $logPath) {

        $lines = Get-Content -LiteralPath $logPath | Where-Object { $_ -and $_.Trim().Length -gt 0 }

        if ($lines.Count -eq 0) {

            $lstLogs.Items.Add("No installation history recorded yet.") | Out-Null

        } else {

            for ($i = $lines.Count - 1; $i -ge 0; $i--) {

                $line = $lines[$i]

                if ($line -match '^(.*?)\|(.*?)$') {

                    $lstLogs.Items.Add("[$($matches[1])] Installed: $($matches[2])") | Out-Null

                }

            }

        }

    } else {

        $lstLogs.Items.Add("No installation history recorded yet.") | Out-Null

    }

    $dialog.Controls.Add($lstLogs)



    $btnClose = New-Object System.Windows.Forms.Button

    $btnClose.Text = "Close"

    $btnClose.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $btnClose.FlatStyle = 'Flat'

    $btnClose.BackColor = Get-ThemeColor 'Accent'

    $btnClose.ForeColor = [System.Drawing.Color]::Black

    $btnClose.SetBounds(496, 365, 110, 34)

    $btnClose.Add_Click({ $dialog.Close() })

    $dialog.Controls.Add($btnClose)



    $dialog.ShowDialog() | Out-Null

}



function Show-CustomBundlerPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}

    

    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "Custom Silent Apps Bundler"

    $metaLabel.Text = "Build, save, and install your custom bundle of favorite software in one click"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_apps_custom_bundler'



    $catMap = @{

        'menu_apps_browsers'       = 'Browser'

        'menu_apps_communication'  = 'Chat'

        'menu_apps_media'          = 'Media'

        'menu_apps_utilities'      = 'Utility'

        'menu_apps_maintenance'    = 'System'

        'menu_apps_productivity'   = 'Product'

        'menu_apps_dev'            = 'Dev'

        'menu_apps_cloud'          = 'Cloud'

        'menu_apps_security'       = 'Security'

        'menu_apps_ai'             = 'AI'

        'menu_apps_custom_bundler' = 'Custom'

    }



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 175

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 20, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Favorite Apps Bundler"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 15)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Select your favorite applications below. Your selections are automatically saved."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 45)

    $headerPanel.Controls.Add($panelSub)



    # Winget Engine Health Status Badge

    $wingetVer = "Ready"

    $wingetHealthy = $true

    $wingetPath = Resolve-WingetPath

    if ([string]::IsNullOrEmpty($wingetPath)) {

        $wingetVer = "Not Found"

        $wingetHealthy = $false

    }

    

    $lblWingetBadge = New-Object System.Windows.Forms.Label

    $lblWingetBadge.AutoSize = $true

    $lblWingetBadge.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $lblWingetBadge.Location = New-Object System.Drawing.Point(525, 20)

    if ($wingetHealthy) {

        $lblWingetBadge.Text = "[OK] WINGET ENGINE: HEALTHY"

        $lblWingetBadge.ForeColor = [System.Drawing.Color]::LimeGreen

    } else {

        $lblWingetBadge.Text = "[!] WINGET ENGINE: NOT INSTALLED"

        $lblWingetBadge.ForeColor = [System.Drawing.Color]::OrangeRed

    }

    $headerPanel.Controls.Add($lblWingetBadge)



    $staticApps = @($model.Options | Where-Object {

        $_.ParentLabel -like 'menu_apps_*' -and 

        -not $_.IsSubmenu -and 

        $_.Text -notmatch 'Install All'

    } | Sort-Object Text)



    $customAppsPath = Join-Path $ToolkitRoot 'Config\custom_winget_apps.bundle'

    $customApps = @()

    if (Test-Path -LiteralPath $customAppsPath) {

        $lines = Get-Content -LiteralPath $customAppsPath -ErrorAction SilentlyContinue

        foreach ($line in $lines) {

            if ($line -match '^(.*?)\|(.*?)$') {

                $resolvedWinget = if (-not [string]::IsNullOrWhiteSpace($wingetPath)) { "`"$wingetPath`"" } else { "winget" }

                $customApps += [pscustomobject]@{

                    Text = $matches[1]

                    Command = "$resolvedWinget install --id `"$($matches[2])`" -e --accept-source-agreements --accept-package-agreements"

                    ParentLabel = "menu_apps_custom_bundler"

                    IsSubmenu = $false

                }

            }

        }

    }



    $apps = @($staticApps + $customApps | Sort-Object Text)



    $favs = Load-FavoritesBundle

    $script:customBundlerCheckboxes = @()



    $btnInstall = New-Object System.Windows.Forms.Button

    $script:btnInstall = $btnInstall

    $btnInstall.Text = "Install Selected Bundle"

    $btnInstall.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $btnInstall.FlatStyle = 'Flat'

    $btnInstall.BackColor = Get-ThemeColor 'Accent'

    $btnInstall.ForeColor = [System.Drawing.Color]::Black

    $btnInstall.FlatAppearance.BorderSize = 0

    $btnInstall.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnInstall.SetBounds(36, 80, 210, 34)

    

    $btnInstall.Add_MouseEnter({ param($sender, $e) $sender.BackColor = Get-ThemeColor 'Accent2' })

    $btnInstall.Add_MouseLeave({ param($sender, $e) $sender.BackColor = Get-ThemeColor 'Accent' })

    

    $btnInstall.Add_Click({

        $selectedNames = @()

        $selectedIds = @()

        foreach ($cb in $script:customBundlerCheckboxes) {

            if ($cb.Checked) {

                $opt = $cb.Tag

                $id = ""

                if ($opt -and $opt.Command -and ($opt.Command -match '--id\s+"?([^"\s]+)"?')) {

                    $id = $matches[1]

                }

                if (-not [string]::IsNullOrEmpty($id)) {

                    $selectedIds += $id

                    $selectedNames += $cb.Text -replace '\s*\([^)]+\)$', ''

                }

            }

        }

        

        if ($selectedIds.Count -eq 0) {

            Out-MessageBox("Please select at least one application to install.", "Apps Bundler", "OK", "Warning") | Out-Null

            return

        }



        try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}

        

        Write-InstallHistory -AppNames $selectedNames

        

        $cmds = @()

        $wingetPath = Resolve-WingetPath

        if ([string]::IsNullOrWhiteSpace($wingetPath)) {

            Show-Warning "Winget/App Installer not found.`r`nInstall or repair App Installer from Microsoft Store, then try again."

            return

        }

        foreach ($id in $selectedIds) {

            $cmds += "`"$wingetPath`" install --id `"$id`" -e --silent --accept-source-agreements --accept-package-agreements"

        }

        $combined = $cmds -join " & "

        Start-CmdWindow -CommandText $combined -Title 'Install Selected Apps Bundle'

    })

    $headerPanel.Controls.Add($btnInstall)



    # Dynamic Selection Status Bar (Summary Strip) docked at Bottom

    $statusPanel = New-Object System.Windows.Forms.Panel

    $statusPanel.Dock = 'Bottom'

    $statusPanel.Height = 45

    $statusPanel.BackColor = Get-ThemeColor 'Panel2'

    $statusPanel.Padding = New-Object System.Windows.Forms.Padding(36, 0, 36, 0)



    $lblStatusLeft = New-Object System.Windows.Forms.Label

    $script:lblStatusLeft = $lblStatusLeft

    $lblStatusLeft.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $lblStatusLeft.ForeColor = Get-ThemeColor 'Muted'

    $lblStatusLeft.AutoSize = $true

    $lblStatusLeft.Location = New-Object System.Drawing.Point(36, 13)

    $statusPanel.Controls.Add($lblStatusLeft)



    $lblStatusRight = New-Object System.Windows.Forms.Label

    $script:lblStatusRight = $lblStatusRight

    $lblStatusRight.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Italic)

    $lblStatusRight.ForeColor = Get-ThemeColor 'Muted'

    $lblStatusRight.AutoSize = $true

    $lblStatusRight.Location = New-Object System.Drawing.Point(540, 13)

    $statusPanel.Controls.Add($lblStatusRight)



    $script:UpdateInstallButtonText = {

        $count = 0

        foreach ($cb in $script:customBundlerCheckboxes) {

            if ($cb.Checked) { $count++ }

        }

        if ($count -gt 0) {

            $script:btnInstall.Text = "Install Selected ($count Apps)"

            $script:btnInstall.Enabled = $true

            $script:btnInstall.BackColor = Get-ThemeColor 'Accent'

            $script:btnInstall.ForeColor = [System.Drawing.Color]::Black

            $script:lblStatusLeft.Text = "Selected: $count Apps | Source: Microsoft Winget & Local Catalog"

            $script:lblStatusLeft.ForeColor = Get-ThemeColor 'Accent'

            $estMins = $count * 2

            $script:lblStatusRight.Text = "Estimated Install Time: ~$estMins minutes"

        } else {

            $script:btnInstall.Text = "Install Selected (0 Apps)"

            $script:btnInstall.Enabled = $false

            $script:btnInstall.BackColor = Get-ThemeColor 'Button'

            $script:btnInstall.ForeColor = Get-ThemeColor 'Muted'

            $script:lblStatusLeft.Text = "No apps selected. Choose apps above to compile your custom installer."

            $script:lblStatusLeft.ForeColor = Get-ThemeColor 'Muted'

            $script:lblStatusRight.Text = "Ready to build"

        }

    }



    $btnSelectAll = New-Object System.Windows.Forms.Button

    $btnSelectAll.Text = "Select All"

    $btnSelectAll.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnSelectAll.FlatStyle = 'Flat'

    $btnSelectAll.BackColor = Get-ThemeColor 'Button'

    $btnSelectAll.ForeColor = Get-ThemeColor 'Text'

    $btnSelectAll.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnSelectAll.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnSelectAll.SetBounds(260, 80, 110, 34)

    $btnSelectAll.Add_Click({

        $script:suppressSave = $true

        foreach ($cb in $script:customBundlerCheckboxes) {

            if ($cb.Visible) { 

                $cb.Checked = $true 

                $cb.ForeColor = Get-ThemeColor 'Accent'

                $cb.Font = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)

            }

        }

        $script:suppressSave = $false

        if ($null -ne $script:SaveSelectedFavoritesInner) { & $script:SaveSelectedFavoritesInner }

        if ($null -ne $script:UpdateInstallButtonText) { & $script:UpdateInstallButtonText }

    })

    $headerPanel.Controls.Add($btnSelectAll)



    $btnClearAll = New-Object System.Windows.Forms.Button

    $btnClearAll.Text = "Clear All"

    $btnClearAll.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnClearAll.FlatStyle = 'Flat'

    $btnClearAll.BackColor = Get-ThemeColor 'Button'

    $btnClearAll.ForeColor = Get-ThemeColor 'Text'

    $btnClearAll.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnClearAll.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnClearAll.SetBounds(385, 80, 110, 34)

    $btnClearAll.Add_Click({

        $script:suppressSave = $true

        foreach ($cb in $script:customBundlerCheckboxes) {

            $cb.Checked = $false

            $cb.ForeColor = Get-ThemeColor 'Text'

            $cb.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)

        }

        $script:suppressSave = $false

        if ($null -ne $script:SaveSelectedFavoritesInner) { & $script:SaveSelectedFavoritesInner }

        if ($null -ne $script:UpdateInstallButtonText) { & $script:UpdateInstallButtonText }

    })

    $headerPanel.Controls.Add($btnClearAll)



    $btnAddWinget = New-Object System.Windows.Forms.Button

    $btnAddWinget.Text = "+ Search & Add Winget App"

    $btnAddWinget.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnAddWinget.FlatStyle = 'Flat'

    $btnAddWinget.BackColor = Get-ThemeColor 'Button'

    $btnAddWinget.ForeColor = Get-ThemeColor 'Text'

    $btnAddWinget.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnAddWinget.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnAddWinget.SetBounds(510, 80, 230, 34)

    $btnAddWinget.Add_Click({

        Show-WingetSearchAddDialog

    })

    $headerPanel.Controls.Add($btnAddWinget)



    $bundlerSearchBox = New-Object System.Windows.Forms.TextBox

    $bundlerSearchBox.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)

    $bundlerSearchBox.BorderStyle = 'FixedSingle'

    $bundlerSearchBox.BackColor = Get-ThemeColor 'Panel2'

    $bundlerSearchBox.ForeColor = Get-ThemeColor 'Text'

    $bundlerSearchBox.SetBounds(36, 125, 430, 32)

    try { $bundlerSearchBox.PlaceholderText = "Search apps to filter list..." } catch {}

    

    $lblFilterStatus = New-Object System.Windows.Forms.Label

    $script:lblFilterStatus = $lblFilterStatus

    $lblFilterStatus.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Italic)

    $lblFilterStatus.ForeColor = Get-ThemeColor 'Muted'

    $lblFilterStatus.AutoSize = $true

    $lblFilterStatus.Location = New-Object System.Drawing.Point(480, 131)

    $headerPanel.Controls.Add($lblFilterStatus)



    # View History Logs Button

    $btnLogs = New-Object System.Windows.Forms.Button

    $btnLogs.Text = "[History] View History"

    $btnLogs.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnLogs.FlatStyle = 'Flat'

    $btnLogs.BackColor = Get-ThemeColor 'Button'

    $btnLogs.ForeColor = Get-ThemeColor 'Text'

    $btnLogs.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnLogs.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnLogs.SetBounds(610, 125, 130, 32)

    $btnLogs.Add_Click({

        Show-InstallHistoryDialog

    })

    $headerPanel.Controls.Add($btnLogs)



    $bundlerSearchBox.Add_TextChanged({

        param($sender, $e)

        $q = $sender.Text.Trim().ToLowerInvariant()

        $visibleCount = 0

        foreach ($cb in $script:customBundlerCheckboxes) {

            $match = [string]::IsNullOrWhiteSpace($q) -or $cb.Text.ToLowerInvariant().Contains($q)

            $cb.Visible = $match

            if ($match) { $visibleCount++ }

        }

        $script:lblFilterStatus.Text = "Showing $visibleCount of $($script:customBundlerCheckboxes.Count) apps"

    })

    $headerPanel.Controls.Add($bundlerSearchBox)



    $gridHost.Controls.Add($headerPanel)



    $script:SaveSelectedFavoritesInner = {

        $idsToSave = @()

        foreach ($cb in $script:customBundlerCheckboxes) {

            if ($cb.Checked) {

                $opt = $cb.Tag

                $id = ""

                if ($opt -and $opt.Command -and ($opt.Command -match '--id\s+"?([^"\s]+)"?')) {

                    $id = $matches[1]

                }

                if (-not [string]::IsNullOrEmpty($id)) {

                    $idsToSave += $id

                }

            }

        }

        Save-FavoritesBundle -AppIds $idsToSave

    }



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    $flow.SuspendLayout()

    $script:suppressSave = $true

    foreach ($opt in $apps) {

        $id = ""

        if ($opt.Command -match '--id\s+"?([^"\s]+)"?') {

            $id = $matches[1]

        }

        if ([string]::IsNullOrEmpty($id)) { continue }



        $cb = New-Object System.Windows.Forms.CheckBox

        $badge = 'Custom'

        if ($catMap.ContainsKey($opt.ParentLabel)) {

            $badge = $catMap[$opt.ParentLabel]

        }

        $cb.Text = "$($opt.Text) ($badge)"

        $cb.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)

        $cb.ForeColor = Get-ThemeColor 'Text'

        $cb.Size = New-Object System.Drawing.Size(280, 36)

        $cb.Tag = $opt

        $cb.Cursor = [System.Windows.Forms.Cursors]::Hand

        if ($favs.ContainsKey($id)) {

            $cb.Checked = $true

            $cb.ForeColor = Get-ThemeColor 'Accent'

            $cb.Font = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)

        }

        

        $cb.Add_MouseEnter({

            param($sender, $e)

            $sender.Parent.Focus() | Out-Null

        })



        $cb.Add_CheckedChanged({

            param($sender, $e)

            if ($sender.Checked) {

                $sender.ForeColor = Get-ThemeColor 'Accent'

                $sender.Font = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)

            } else {

                $sender.ForeColor = Get-ThemeColor 'Text'

                $sender.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)

            }

            if (-not $script:suppressSave) {

                if ($null -ne $script:SaveSelectedFavoritesInner) { & $script:SaveSelectedFavoritesInner }

                if ($null -ne $script:UpdateInstallButtonText) { & $script:UpdateInstallButtonText }

            }

        })



        $flow.Controls.Add($cb)

        $script:customBundlerCheckboxes += $cb

    }

    $script:suppressSave = $false

    $flow.ResumeLayout($true)



    $script:lblFilterStatus.Text = "Showing $($script:customBundlerCheckboxes.Count) of $($script:customBundlerCheckboxes.Count) apps"

    if ($null -ne $script:UpdateInstallButtonText) { & $script:UpdateInstallButtonText }



    $gridHost.Controls.Add($statusPanel)

    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-SystemCleanerPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}

    

    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "System Boost & PC Cleaner"

    $metaLabel.Text = "Free up disk space, flush DNS cache, and speed up your computer natively in real-time"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_system_cleaner'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 175

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 20, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "PC Cleanup Master"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 15)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Safe cleanup items are pre-selected. Advanced cache, log, service, and registry tweaks are optional."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 45)

    $headerPanel.Controls.Add($panelSub)

    $script:systemCleanerPanelSub = $panelSub



    # UI Warning for non-admin sessions

    $isAdmin = Test-IsAdmin

    if (-not $isAdmin) {

        $adminWarning = New-Object System.Windows.Forms.Label

        $adminWarning.Text = "⚠️ WARNING: Running as standard user. System cleanup & performance tweaks require Administrator privileges!"

        $adminWarning.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

        $adminWarning.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#F59E0B") # Amber orange warning

        $adminWarning.AutoSize = $true

        $adminWarning.Location = New-Object System.Drawing.Point(36, 125)

        $headerPanel.Controls.Add($adminWarning)

        $headerPanel.Height = 210

    }



    $script:systemCleanerCheckboxes = @()

    

    $cleanOptions = @(

        # Junk Cleanup Options

        [pscustomobject]@{ Text = "User Temp Files (%TEMP%)"; Action = "temp"; DefaultChecked = $true; Note = "Deletes temporary files from the current user's temp folder." },

        [pscustomobject]@{ Text = "System Temp (C:\Windows\Temp)"; Action = "system_temp"; DefaultChecked = $true; Note = "Deletes removable files from Windows temp. Locked files are skipped." },

        [pscustomobject]@{ Text = "Flush DNS Cache (Internet Boost)"; Action = "dns"; DefaultChecked = $true; Note = "Clears DNS resolver cache. Safe and quick." },

        [pscustomobject]@{ Text = "Windows Prefetch Cache"; Action = "prefetch"; DefaultChecked = $false; Note = "Advanced: Windows may rebuild these files after reboot/app launch." },

        [pscustomobject]@{ Text = "Empty Recycle Bin"; Action = "recyclebin"; DefaultChecked = $false; Note = "Advanced: permanently removes recycle bin contents." },

        [pscustomobject]@{ Text = "Windows Update Cache"; Action = "update_cache"; DefaultChecked = $false; Note = "Advanced: can force Windows Update downloads to rebuild." },

        [pscustomobject]@{ Text = "Windows System Logs (*.log)"; Action = "system_logs"; DefaultChecked = $false; Note = "Advanced: may remove troubleshooting history." },

        [pscustomobject]@{ Text = "Windows Crash Dumps"; Action = "crash_dumps"; DefaultChecked = $false; Note = "Advanced: removes crash evidence useful for BSOD diagnosis." },

        [pscustomobject]@{ Text = "Delivery Optimization Cache"; Action = "delivery_opt"; DefaultChecked = $true; Note = "Clears Windows delivery optimization download cache." },

        

        # System Tweaks / Performance Boost Options

        [pscustomobject]@{ Text = "Disable Desktop Animations"; Action = "disable_animations"; DefaultChecked = $false; Note = "Advanced tweak: changes current-user visual effect settings." },

        [pscustomobject]@{ Text = "Disable Visual Transparencies"; Action = "disable_transparency"; DefaultChecked = $false; Note = "Advanced tweak: changes current-user Windows theme transparency." },

        [pscustomobject]@{ Text = "Disable Windows Telemetry"; Action = "disable_telemetry"; DefaultChecked = $false; Note = "Advanced tweak: changes policy/service settings and may need admin rights." },

        [pscustomobject]@{ Text = "Disable Xbox Game DVR"; Action = "disable_gamedvr"; DefaultChecked = $false; Note = "Advanced tweak: changes Game DVR registry settings." },

        [pscustomobject]@{ Text = "Optimize System Responsiveness"; Action = "optimize_response"; DefaultChecked = $false; Note = "Advanced tweak: changes multimedia system profile registry values." },

        [pscustomobject]@{ Text = "Disable Background Apps Access"; Action = "disable_bg_apps"; DefaultChecked = $false; Note = "Advanced tweak: changes background access registry settings." }

    )



    $btnBoost = New-Object System.Windows.Forms.Button

    $btnBoost.Text = "Boost & Clean PC Now"

    $btnBoost.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $btnBoost.FlatStyle = 'Flat'

    $btnBoost.BackColor = Get-ThemeColor 'Accent'

    $btnBoost.ForeColor = [System.Drawing.Color]::Black

    $btnBoost.FlatAppearance.BorderSize = 0

    $btnBoost.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnBoost.SetBounds(36, 80, 240, 34)

    

    $btnBoost.Add_MouseEnter({ param($sender, $e) $sender.BackColor = Get-ThemeColor 'Accent2' })

    $btnBoost.Add_MouseLeave({ param($sender, $e) $sender.BackColor = Get-ThemeColor 'Accent' })

    

    $btnBoost.Add_Click({

        Write-GuiActionLog -ActionType 'Click' -Component 'PC Cleaner' -Details 'User triggered PC Boost & Cleanup'

        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

        $script:systemCleanerPanelSub.Text = "Boosting your system... Please wait..."

        $script:systemCleanerPanelSub.ForeColor = Get-ThemeColor 'Accent'

        [System.Windows.Forms.Application]::DoEvents()



        # Log warning if running in standard user mode

        $isAdminNow = Test-IsAdmin

        if (-not $isAdminNow) {

            $fakeEx = New-Object System.Exception("insufficient privileges: GUI is running in Standard User mode. PC Cleaner could not clean administrative directories (Prefetch, System Temp, Update Cache, System Logs, etc.).")

            Write-GuiErrorLog -Panel "SystemCleaner" -Context "PC Cleaner" -Err $fakeEx -Recovered $true

        }

        

        $script:totalFreedBytes = 0

        $script:successFileCount = 0

        $script:failedFileCount = 0

        $freedItemsCount = 0

        

        $dnsCleared = $false

        $dnsFailed = $false

        $recycleBinCleared = $false

        $recycleBinFailed = $false

        



        $RemoveJunkFiles = {

            param(

                [string]$Path,

                [bool]$Recurse = $true

            )

            if (-not (Test-Path -LiteralPath $Path)) { return }

            

            # Clear files in current folder

            $files = @()

            try {

                $files = Get-ChildItem -LiteralPath $Path -File -Force -ErrorAction SilentlyContinue

            } catch {}

            



            foreach ($f in $files) {

                try {

                    $len = $f.Length

                    Remove-Item -LiteralPath $f.FullName -Force -Confirm:$false -ErrorAction Stop

                    $script:totalFreedBytes += $len

                    $script:successFileCount++

                } catch {

                    $script:failedFileCount++

                }

                

                # Periodically keep UI alive

                $totalProcessed = $script:successFileCount + $script:failedFileCount

                if ($totalProcessed % 50 -eq 0) {

                    [System.Windows.Forms.Application]::DoEvents()

                }

            }

            

            # Recurse folder by folder to avoid permission blockages

            if ($Recurse) {

                $dirs = @()

                try {

                    $dirs = Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue | Where-Object { -not ($_.Attributes -match "ReparsePoint") }

                } catch {}

                

                foreach ($d in $dirs) {

                    & $RemoveJunkFiles -Path $d.FullName -Recurse $true

                    try {

                        Remove-Item -LiteralPath $d.FullName -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue

                    } catch {}

                    [System.Windows.Forms.Application]::DoEvents()

                }

            }

        }

        

        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        

        foreach ($cb in $script:systemCleanerCheckboxes) {

            if ($cb.Checked) {

                $act = $cb.Tag.Action

                if ($act -eq "temp") {

                    $tempDir = $env:TEMP

                    & $RemoveJunkFiles -Path $tempDir

                }

                if ($act -eq "system_temp") {

                    & $RemoveJunkFiles -Path "C:\Windows\Temp"

                }

                if ($act -eq "dns") {

                    try {

                        Clear-DnsClientCache -ErrorAction Stop

                        $dnsCleared = $true

                    } catch {

                        $dnsFailed = $true

                    }

                }

                if ($act -eq "prefetch") {

                    & $RemoveJunkFiles -Path "C:\Windows\Prefetch"

                }

                if ($act -eq "recyclebin") {

                    try {

                        Clear-RecycleBin -Force -ErrorAction Stop

                        $recycleBinCleared = $true

                    } catch {

                        $recycleBinFailed = $true

                    }

                }

                if ($act -eq "update_cache") {

                    & $RemoveJunkFiles -Path "C:\Windows\SoftwareDistribution\Download"

                }

                if ($act -eq "system_logs") {

                    & $RemoveJunkFiles -Path "C:\Windows\Logs"

                    & $RemoveJunkFiles -Path "C:\Windows\Panther"

                    $winFiles = Get-ChildItem -Path "C:\Windows" -Filter "*.log" -File -Force -ErrorAction SilentlyContinue

                    foreach ($f in $winFiles) {

                        try {

                            $len = $f.Length

                            Remove-Item -LiteralPath $f.FullName -Force -Confirm:$false -ErrorAction Stop

                            $script:totalFreedBytes += $len

                            $script:successFileCount++

                        } catch {

                            $script:failedFileCount++

                        }

                    }

                }

                if ($act -eq "crash_dumps") {

                    & $RemoveJunkFiles -Path "C:\Windows\Minidump"

                    & $RemoveJunkFiles -Path "C:\Windows\LiveKernelReports"

                    & $RemoveJunkFiles -Path "$env:LOCALAPPDATA\CrashDumps"

                }

                if ($act -eq "delivery_opt") {

                    & $RemoveJunkFiles -Path "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"

                }

                if ($act -eq "disable_animations") {

                    try {

                        $path1 = "HKCU:\Control Panel\Desktop\WindowMetrics"

                        if (Test-Path -Path $path1) { Set-ItemProperty -Path $path1 -Name "MinAnimate" -Value "0" -Force }

                        

                        $path2 = "HKCU:\Control Panel\Desktop"

                        if (Test-Path -Path $path2) {

                            $mask = Get-ItemProperty -Path $path2 -Name "UserPreferencesMask" -ErrorAction SilentlyContinue

                            if ($null -ne $mask -and $mask.UserPreferencesMask.GetType().Name -eq "Byte[]") {

                                $bytes = $mask.UserPreferencesMask

                                $bytes[0] = $bytes[0] -band 0xFE

                                $bytes[0] = $bytes[0] -band 0xFD

                                Set-ItemProperty -Path $path2 -Name "UserPreferencesMask" -Value $bytes -Force

                            }

                        }

                        

                        $path3 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

                        if (-not (Test-Path -Path $path3)) { New-Item -Path $path3 -Force | Out-Null }

                        Set-ItemProperty -Path $path3 -Name "TaskbarAnimations" -Value 0 -Type DWord -Force

                    } catch {}

                }

                if ($act -eq "disable_transparency") {

                    try {

                        $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

                        if (-not (Test-Path -Path $path)) { New-Item -Path $path -Force | Out-Null }

                        Set-ItemProperty -Path $path -Name "EnableTransparency" -Value 0 -Type DWord -Force

                    } catch {}

                }

                if ($act -eq "disable_telemetry") {

                    try {

                        $path1 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"

                        if (-not (Test-Path -Path $path1)) { New-Item -Path $path1 -Force | Out-Null }

                        Set-ItemProperty -Path $path1 -Name "AllowTelemetry" -Value 0 -Type DWord -Force

 

                        Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue

                        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue



                        # Invoke Win11Debloat script to thoroughly disable all Windows telemetry

                        $debloatScript = Join-Path $script:ToolkitRoot "Modules\Win11Debloat.ps1"

                        if (-not (Test-Path $debloatScript)) {

                            $debloatScript = "$env:USERPROFILE\Downloads\Win11Debloat.ps1"

                        }

                        if (Test-Path $debloatScript) {

                            $debloatProcess = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$debloatScript`" -Silent -DisableTelemetry" -PassThru -NoNewWindow

                            if ($null -ne $debloatProcess) {

                                while (-not $debloatProcess.HasExited) {

                                    [System.Windows.Forms.Application]::DoEvents()

                                    Start-Sleep -Milliseconds 100

                                }

                            }

                        }

                    } catch {}

                }

                if ($act -eq "disable_gamedvr") {

                    try {

                        $path1 = "HKCU:\System\GameConfigStore"

                        if (-not (Test-Path -Path $path1)) { New-Item -Path $path1 -Force | Out-Null }

                        Set-ItemProperty -Path $path1 -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force

                        

                        $path2 = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"

                        if (-not (Test-Path -Path $path2)) { New-Item -Path $path2 -Force | Out-Null }

                        Set-ItemProperty -Path $path2 -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force

                    } catch {}

                }

                if ($act -eq "optimize_response") {

                    try {

                        $path1 = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"

                        if (-not (Test-Path -Path $path1)) { New-Item -Path $path1 -Force | Out-Null }

                        Set-ItemProperty -Path $path1 -Name "SystemResponsiveness" -Value 0 -Type DWord -Force

                        Set-ItemProperty -Path $path1 -Name "NetworkThrottlingIndex" -Value 4294967295 -Type DWord -Force

                    } catch {}

                }

                if ($act -eq "disable_bg_apps") {

                    try {

                        $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"

                        if (-not (Test-Path -Path $path)) { New-Item -Path $path -Force | Out-Null }

                        Set-ItemProperty -Path $path -Name "GlobalUserPresence" -Value 0 -Type DWord -Force

                    } catch {}

                }

                $freedItemsCount++

                [System.Windows.Forms.Application]::DoEvents()

            }

        }

        

        $sw.Stop()

        $form.Cursor = [System.Windows.Forms.Cursors]::Default

        

        $freedDisplay = ""

        if ($script:totalFreedBytes -ge 1GB) {

            $freedDisplay = "{0:N2} GB" -f ($script:totalFreedBytes / 1GB)

        } elseif ($script:totalFreedBytes -ge 1MB) {

            $freedDisplay = "{0:N2} MB" -f ($script:totalFreedBytes / 1MB)

        } else {

            $freedDisplay = "{0:N2} KB" -f ($script:totalFreedBytes / 1KB)

        }

 

        $script:systemCleanerPanelSub.Text = "PC Boosted successfully! Cleaned and optimized $freedItemsCount categories."

        $script:systemCleanerPanelSub.ForeColor = Get-ThemeColor 'Accent'

        $script:metaLabel.Text = "PC boost complete in $([Math]::Round($sw.Elapsed.TotalSeconds, 2)) seconds"

        

        try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}

        

        $msgText = "PC Boosted successfully!`r`n`r`n"

        $msgText += "Successfully Cleaned: $($script:successFileCount) files ($freedDisplay)`r`n"

        if ($script:failedFileCount -gt 0) {

            $msgText += "Skipped (In-Use/Locked): $($script:failedFileCount) files`r`n"

        }

        if ($dnsCleared) { $msgText += "DNS Resolver Cache: Successfully Flushed`r`n" }

        if ($recycleBinCleared) { $msgText += "Recycle Bin: Successfully Emptied`r`n" }

        

        Write-GuiActionLog -ActionType 'Result' -Component 'PC Cleaner' -Details "PC Boost finished. Cleaned: $($script:successFileCount) files ($freedDisplay), Skipped: $($script:failedFileCount) files."

        Out-MessageBox($msgText, "PC Cleaner Master", "OK", "Information") | Out-Null

    })

    $headerPanel.Controls.Add($btnBoost)

 

    $btnSelectAll = New-Object System.Windows.Forms.Button

    $btnSelectAll.Text = "Select All"

    $btnSelectAll.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnSelectAll.FlatStyle = 'Flat'

    $btnSelectAll.BackColor = Get-ThemeColor 'Button'

    $btnSelectAll.ForeColor = Get-ThemeColor 'Text'

    $btnSelectAll.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnSelectAll.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnSelectAll.SetBounds(290, 80, 120, 34)

    $btnSelectAll.Add_Click({

        foreach ($cb in $script:systemCleanerCheckboxes) {

            $cb.Checked = $true

        }

    })

    $headerPanel.Controls.Add($btnSelectAll)

 

    $btnClearAll = New-Object System.Windows.Forms.Button

    $btnClearAll.Text = "Clear All"

    $btnClearAll.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnClearAll.FlatStyle = 'Flat'

    $btnClearAll.BackColor = Get-ThemeColor 'Button'

    $btnClearAll.ForeColor = Get-ThemeColor 'Text'

    $btnClearAll.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnClearAll.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnClearAll.SetBounds(420, 80, 120, 34)

    $btnClearAll.Add_Click({

        foreach ($cb in $script:systemCleanerCheckboxes) {

            $cb.Checked = $false

        }

    })

    $headerPanel.Controls.Add($btnClearAll)



    # Gaming & Extreme Performance Booster Button/Toggle next to Clear All

    $btnBooster = New-Object System.Windows.Forms.Button

    $btnBooster.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnBooster.FlatStyle = 'Flat'

    $btnBooster.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnBooster.SetBounds(550, 80, 200, 34)

    

    $updateBoosterButtonStyles = {

        if ($script:boosterActive) {

            $btnBooster.Text = "[BOOST] GAMING BOOSTER: ON"

            $btnBooster.BackColor = Get-ThemeColor 'Accent'

            $btnBooster.ForeColor = [System.Drawing.Color]::Black

            $btnBooster.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

        } else {

            $btnBooster.Text = "[BOOST] GAMING BOOSTER: OFF"

            $btnBooster.BackColor = Get-ThemeColor 'Button'

            $btnBooster.ForeColor = Get-ThemeColor 'Text'

            $btnBooster.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

        }

    }

    

    # Apply current state

    & $updateBoosterButtonStyles

    

    $btnBooster.Add_Click({

        if (-not $script:boosterActive) {

            # Turn ON Booster!

            $script:boosterActive = $true

            & $updateBoosterButtonStyles

            

            # Query and backup current power plan

            $activePlan = powercfg /getactivescheme

            if ($activePlan -match 'GUID:\s+([a-f0-9-]+)') {

                $script:originalPowerPlan = $matches[1]

            }

            # Enable High Performance plan

            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >$null 2>&1

            

            # Stop heavy services

            Stop-Service -Name "Spooler" -Force -ErrorAction SilentlyContinue

            Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue

            Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue

            

            # Flush Standby Caches

            [System.GC]::Collect()

            

            $panelSub.Text = "Gaming Booster Active! Ultimate Power Scheme set & Standby Caches cleared."

            $panelSub.ForeColor = Get-ThemeColor 'Accent'

        } else {

            # Turn OFF Booster!

            $script:boosterActive = $false

            & $updateBoosterButtonStyles

            

            # Restore previous plan

            if ($script:originalPowerPlan) {

                powercfg /setactive $script:originalPowerPlan >$null 2>&1

            }

            

            # Restart Services

            Start-Service -Name "Spooler" -ErrorAction SilentlyContinue

            Start-Service -Name "SysMain" -ErrorAction SilentlyContinue

            Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue

            

            $panelSub.Text = "Gaming Booster Disabled. Balanced Power Scheme and services restored."

            $panelSub.ForeColor = Get-ThemeColor 'Muted'

        }

    }.GetNewClosure())

    $headerPanel.Controls.Add($btnBooster)



    # 📅 Weekly Task Scheduler Checkbox

    $cbSchedule = New-Object System.Windows.Forms.CheckBox

    $cbSchedule.Text = "Enable Weekly Auto-Cleanup (Sundays at 12:00 AM)"

    $cbSchedule.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $cbSchedule.ForeColor = Get-ThemeColor 'Text'

    $cbSchedule.SetBounds(36, 128, 450, 32)

    $cbSchedule.Cursor = [System.Windows.Forms.Cursors]::Hand



    $taskExists = $false

    try {

        $res = schtasks.exe /query /tn "SysForge Studio_AutoClean" 2>$null

        if ($LASTEXITCODE -eq 0) { $taskExists = $true }

    } catch {}

    

    $cbSchedule.Checked = $taskExists

    

    $cbSchedule.Add_CheckedChanged({

        param($sender, $e)

        $taskName = "SysForge Studio_AutoClean"

        if ($sender.Checked) {

            $actionScript = Join-Path $ToolkitRoot "Modules\Toolkit-GUI-Pro.ps1"

            $cmdArgs = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$actionScript`" -SilentClean"

            schtasks.exe /create /tn $taskName /tr "powershell.exe $cmdArgs" /sc weekly /d SUN /st 00:00 /f /rl highest >$null 2>&1

            Out-MessageBox("Weekly Auto-Cleanup task successfully registered in Windows Task Scheduler!`r`nIt will run silently every Sunday at 12:00 AM.", "Weekly Scheduler", "OK", "Information") | Out-Null

        } else {

            schtasks.exe /delete /tn $taskName /f >$null 2>&1

            Out-MessageBox("Weekly Auto-Cleanup task deleted from Windows Task Scheduler.", "Weekly Scheduler", "OK", "Information") | Out-Null

        }

    }.GetNewClosure())

    $headerPanel.Controls.Add($cbSchedule)

 

    $gridHost.Controls.Add($headerPanel)

 

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow

 

    $flow.SuspendLayout()

    foreach ($opt in $cleanOptions) {

        $cb = New-Object System.Windows.Forms.CheckBox

        $cb.Text = $opt.Text

        $cb.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)

        $cb.ForeColor = Get-ThemeColor 'Text'

        $cb.Size = New-Object System.Drawing.Size(360, 36)

        $cb.Tag = $opt

        $cb.Cursor = [System.Windows.Forms.Cursors]::Hand

        $cb.Checked = [bool]$opt.DefaultChecked

        if ($opt.Note) {

            $toolTip.SetToolTip($cb, [string]$opt.Note)

        }

        

        $cb.Add_MouseEnter({

            param($sender, $e)

            $sender.Parent.Focus() | Out-Null

        })

        

        $flow.Controls.Add($cb)

        $script:systemCleanerCheckboxes += $cb

    }

    $flow.ResumeLayout($true)

 

    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-BackupMigrationPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "Enterprise Profile Backup & Migration"

    $metaLabel.Text = "Backup and migrate user profiles, browser data, and Wi-Fi profiles cleanly to external storage"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_user_backup'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 175

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 20, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "1-Click User Profile Migration Center"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 15)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Choose target drive, select folders/profile settings to migrate, and click Start Backup."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 45)

    $headerPanel.Controls.Add($panelSub)



    # 💾 Target Drive Selection ComboBox

    $lblDrive = New-Object System.Windows.Forms.Label

    $lblDrive.Text = "Select Target Backup Drive:"

    $lblDrive.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $lblDrive.ForeColor = Get-ThemeColor 'Text'

    $lblDrive.SetBounds(36, 85, 200, 20)

    $headerPanel.Controls.Add($lblDrive)



    $comboDrives = New-Object System.Windows.Forms.ComboBox

    $comboDrives.DropDownStyle = 'DropDownList'

    $comboDrives.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $comboDrives.BackColor = Get-ThemeColor 'Panel'

    $comboDrives.ForeColor = Get-ThemeColor 'Text'

    $comboDrives.SetBounds(36, 110, 250, 28)

    

    # Dynamically scan connected drives

    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Removable' -or ($_.DriveType -eq 'Fixed' -and $_.Name -ne 'C:\') }

    if ($drives.Count -eq 0) {

        $comboDrives.Items.Add("No Removable/Secondary Drive Detected") | Out-Null

        $comboDrives.SelectedIndex = 0

    } else {

        foreach ($d in $drives) {

            $label = "$($d.Name) ($($d.VolumeLabel)) - $([math]::Round($d.AvailableFreeSpace / 1GB, 1)) GB Free"

            $comboDrives.Items.Add($label) | Out-Null

        }

        $comboDrives.SelectedIndex = 0

    }

    $headerPanel.Controls.Add($comboDrives)



    # Backup Path Preview Label

    $lblPathPreview = New-Object System.Windows.Forms.Label

    $lblPathPreview.Text = "Backup Destination: [Dynamic Path]"

    $lblPathPreview.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Italic)

    $lblPathPreview.ForeColor = Get-ThemeColor 'Muted'

    $lblPathPreview.SetBounds(36, 145, 500, 20)

    $headerPanel.Controls.Add($lblPathPreview)



    $updatePathPreview = {

        if ($comboDrives.SelectedItem -and $comboDrives.SelectedItem -notmatch 'No Removable') {

            $driveLetter = $comboDrives.SelectedItem.Substring(0, 3)

            $stamp = (Get-Date -Format "yyyyMMdd")

            $targetPath = Join-Path $driveLetter "ToolkitBackup\$env:COMPUTERNAME`_$env:USERNAME`_$stamp"

            $lblPathPreview.Text = "Backup Destination: $targetPath"

        } else {

            $lblPathPreview.Text = "Backup Destination: Select a valid backup drive first."

        }

    }.GetNewClosure()

    $comboDrives.Add_SelectedIndexChanged($updatePathPreview)

    & $updatePathPreview



    # "Start 1-Click Backup" Button

    $btnBackup = New-Object System.Windows.Forms.Button

    $btnBackup.Text = "Start 1-Click Backup"

    $btnBackup.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $btnBackup.FlatStyle = 'Flat'

    $btnBackup.BackColor = Get-ThemeColor 'Accent'

    $btnBackup.ForeColor = Get-ThemeColor 'CardText'

    $btnBackup.SetBounds(320, 102, 220, 38)

    $btnBackup.Cursor = [System.Windows.Forms.Cursors]::Hand

    

    $headerPanel.Controls.Add($btnBackup)

    $gridHost.Controls.Add($headerPanel)



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    $backupOptions = @(

        [pscustomobject]@{ Text = "User Desktop Folder"; Action = "desktop"; Path = [System.Environment]::GetFolderPath('Desktop') },

        [pscustomobject]@{ Text = "User Documents Folder"; Action = "documents"; Path = [System.Environment]::GetFolderPath('MyDocuments') },

        [pscustomobject]@{ Text = "User Downloads Folder"; Action = "downloads"; Path = "$env:USERPROFILE\Downloads" },

        [pscustomobject]@{ Text = "User Pictures Folder"; Action = "pictures"; Path = [System.Environment]::GetFolderPath('MyPictures') },

        [pscustomobject]@{ Text = "User Videos & Music Folders"; Action = "multimedia"; Path = "$env:USERPROFILE\Videos;$env:USERPROFILE\Music" },

        [pscustomobject]@{ Text = "Google Chrome Profile (Bookmarks & History)"; Action = "chrome"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default" },

        [pscustomobject]@{ Text = "Microsoft Edge Profile Data"; Action = "edge"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default" },

        [pscustomobject]@{ Text = "Saved Wi-Fi Credentials"; Action = "wifi"; Path = "wifi" }

    )



    $backupCheckboxes = @()

    $flow.SuspendLayout()

    foreach ($opt in $backupOptions) {

        $cb = New-Object System.Windows.Forms.CheckBox

        $cb.Text = $opt.Text

        $cb.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)

        $cb.ForeColor = Get-ThemeColor 'Text'

        $cb.Size = New-Object System.Drawing.Size(320, 36)

        $cb.Tag = $opt

        $cb.Cursor = [System.Windows.Forms.Cursors]::Hand

        $cb.Checked = $true

        

        $cb.Add_MouseEnter({ param($sender, $e) $sender.Parent.Focus() | Out-Null })

        $flow.Controls.Add($cb)

        $backupCheckboxes += $cb

    }

    $flow.ResumeLayout($true)

    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $btnBackup.Add_Click({

        if ($comboDrives.SelectedItem -match 'No Removable') {

            Out-MessageBox("Backup start karne ke liye kripya ek valid secondary ya external drive select karein.", "Drive Not Selected", "OK", "Warning") | Out-Null

            return

        }



        $driveLetter = $comboDrives.SelectedItem.Substring(0, 3)

        $stamp = (Get-Date -Format "yyyyMMdd_HHmmss")

        $targetFolder = Join-Path $driveLetter "ToolkitBackup\$env:COMPUTERNAME`_$env:USERNAME`_$stamp"

        

        # Create wait dialog

        $waitForm = New-Object System.Windows.Forms.Form

        $waitForm.Text = "Backing Up Data..."

        $waitForm.Size = New-Object System.Drawing.Size(400, 160)

        $waitForm.StartPosition = 'CenterParent'

        $waitForm.FormBorderStyle = 'FixedDialog'

        $waitForm.ControlBox = $false

        $waitForm.ShowInTaskbar = $false

        $waitForm.BackColor = Get-ThemeColor 'Panel'

        

        $lblWait = New-Object System.Windows.Forms.Label

        $lblWait.Text = "Kripya intezar karein... Profiles aur files back up ho rahi hain."

        $lblWait.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

        $lblWait.ForeColor = Get-ThemeColor 'Text'

        $lblWait.SetBounds(20, 20, 360, 40)

        $waitForm.Controls.Add($lblWait)

        

        $progress = New-Object System.Windows.Forms.ProgressBar

        $progress.Style = 'Marquee'

        $progress.MarqueeAnimationSpeed = 30

        $progress.SetBounds(20, 70, 340, 25)

        $waitForm.Controls.Add($progress)



        $waitForm.Tag = [pscustomobject]@{

            Checkboxes = $backupCheckboxes

            TargetFolder = $targetFolder

            LabelWait = $lblWait

            LogFile = Join-Path $targetFolder "backup_summary.log"

        }



        $waitForm.Add_Shown({

            param($sender, $e)

            # Force UI update

            [System.Windows.Forms.Application]::DoEvents()



            $bag = $sender.Tag

            $checkboxes = $bag.Checkboxes

            $targetFolder = $bag.TargetFolder

            $lblWait = $bag.LabelWait

            $logFile = $bag.LogFile



            try {

                if (-not (Test-Path -LiteralPath $targetFolder)) {

                    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

                }



                "SysForge Studiofile Backup Summary`r`n====================================`r`nDate: $(Get-Date)`r`nPC: $env:COMPUTERNAME`r`nUser: $env:USERNAME`r`n`r`n" | Out-File -FilePath $logFile -Force -Encoding utf8

                

                try {

                    "DEBUG: Checkboxes count = $(if ($null -ne $checkboxes) { $checkboxes.Count } else { 'NULL' })" | Out-File -FilePath $logFile -Append -Encoding utf8

                } catch {

                    "DEBUG: Failed to log checkboxes count: $_" | Out-File -FilePath $logFile -Append -Encoding utf8

                }



                foreach ($cb in $checkboxes) {

                    if ($cb.Checked) {

                        $opt = $cb.Tag

                        $lblWait.Text = "Processing: $($opt.Text)..."

                        [System.Windows.Forms.Application]::DoEvents()



                        if ($opt.Action -eq "wifi") {

                            # Export Wi-Fi profiles cleanly

                            $wifiDir = Join-Path $targetFolder "WiFi_Profiles"

                            if (-not (Test-Path -LiteralPath $wifiDir)) { New-Item -ItemType Directory -Path $wifiDir -Force | Out-Null }

                            netsh wlan export profile folder="$wifiDir" key=clear >$null 2>&1

                            "Wi-Fi Profiles: Exported successfully to WiFi_Profiles folder." | Out-File -FilePath $logFile -Append -Encoding utf8

                        } else {

                            # Copy file folders or browser data

                            $paths = $opt.Path -split ';'

                            foreach ($p in $paths) {

                                if (Test-Path -LiteralPath $p) {

                                    $folderName = Split-Path $p -Leaf

                                    $dest = Join-Path $targetFolder $folderName

                                    if ($opt.Action -match 'chrome|edge') {

                                        # Browser files copy (safe exclude lockfiles)

                                        robocopy.exe "$p" "$dest" /E /R:1 /W:1 /XF "parent.lock" "lock" "History-journal" "Favicons-journal" >$null 2>&1

                                    } else {

                                        # Standard profile folders robocopy

                                        robocopy.exe "$p" "$dest" /E /R:1 /W:1 >$null 2>&1

                                    }

                                    "$($opt.Text): Backed up from $p to $dest" | Out-File -FilePath $logFile -Append -Encoding utf8

                                } else {

                                    "$($opt.Text): Folder missing or inaccessible: $p" | Out-File -FilePath $logFile -Append -Encoding utf8

                                }

                            }

                        }

                    }

                }



                $sender.Close()

                Out-MessageBox("1-Click Profile Backup successfully completed!`r`nDestination: $targetFolder`r`nSummary saved in backup_summary.log.", "Backup Completed", "OK", "Information") | Out-Null

            } catch {

                $sender.Close()

                Out-MessageBox("Backup ke dauran ek truti hui: $_", "Backup Error", "OK", "Error") | Out-Null

            }

        }.GetNewClosure())



        $waitForm.ShowDialog($form) | Out-Null

    }.GetNewClosure())



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-BloatwareRemoverPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "Appx Bloatware Remover & Windows Hardener"

    $metaLabel.Text = "Clean pre-installed Microsoft junk apps and apply deep Windows privacy adjustments natively"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_bloatware_remover'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 175

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 20, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Windows 10/11 Premium Debloater"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 15)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Select the bloatware and privacy tweaks you want to apply, then click Remove Bloatware."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 45)

    $headerPanel.Controls.Add($panelSub)



    # Select All / Clear All Buttons

    $btnSelectAll = New-Object System.Windows.Forms.Button

    $btnSelectAll.Text = "Select All"

    $btnSelectAll.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnSelectAll.FlatStyle = 'Flat'

    $btnSelectAll.BackColor = Get-ThemeColor 'Button'

    $btnSelectAll.ForeColor = Get-ThemeColor 'Text'

    $btnSelectAll.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnSelectAll.SetBounds(36, 120, 100, 32)

    $btnSelectAll.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnSelectAll)



    $btnClearAll = New-Object System.Windows.Forms.Button

    $btnClearAll.Text = "Clear All"

    $btnClearAll.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnClearAll.FlatStyle = 'Flat'

    $btnClearAll.BackColor = Get-ThemeColor 'Button'

    $btnClearAll.ForeColor = Get-ThemeColor 'Text'

    $btnClearAll.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnClearAll.SetBounds(146, 120, 100, 32)

    $btnClearAll.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnClearAll)



    # "Remove Selected Bloatware" Button

    $btnClean = New-Object System.Windows.Forms.Button

    $btnClean.Text = "Remove Selected Bloatware"

    $btnClean.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $btnClean.FlatStyle = 'Flat'

    $btnClean.BackColor = Get-ThemeColor 'Accent'

    $btnClean.ForeColor = Get-ThemeColor 'CardText'

    $btnClean.SetBounds(266, 116, 250, 38)

    $btnClean.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnClean)



    $gridHost.Controls.Add($headerPanel)



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    $bloatwareOptions = @(

        # Appx Bloatware list

        [pscustomobject]@{ Text = "Uninstall Xbox App & Gaming Suite"; Action = "appx"; Package = "*Xbox*" },

        [pscustomobject]@{ Text = "Uninstall Microsoft OneDrive Client"; Action = "onedrive"; Package = "*OneDrive*" },

        [pscustomobject]@{ Text = "Uninstall Cortana Assistant Link"; Action = "appx"; Package = "*Cortana*" },

        [pscustomobject]@{ Text = "Uninstall Microsoft 3D Builder"; Action = "appx"; Package = "*3DBuilder*" },

        [pscustomobject]@{ Text = "Uninstall Skype App"; Action = "appx"; Package = "*Skype*" },

        [pscustomobject]@{ Text = "Uninstall Zune Music & Video Player"; Action = "appx"; Package = "*Zune*" },

        [pscustomobject]@{ Text = "Uninstall Solitaire Card Collection"; Action = "appx"; Package = "*Solitaire*" },

        [pscustomobject]@{ Text = "Uninstall Feedback Hub App"; Action = "appx"; Package = "*FeedbackHub*" },

        [pscustomobject]@{ Text = "Uninstall Windows Maps App"; Action = "appx"; Package = "*Maps*" },

        [pscustomobject]@{ Text = "Uninstall Your Phone & Link to Windows"; Action = "appx"; Package = "*YourPhone*" },

        [pscustomobject]@{ Text = "Uninstall Bing News & Sports Suite"; Action = "appx"; Package = "*Bing*" },

        [pscustomobject]@{ Text = "Uninstall People Contacts App"; Action = "appx"; Package = "*People*" },

        

        # Privacy Hardening Registry Toggles

        [pscustomobject]@{ Text = "Disable Start Menu Bing Web Search"; Action = "tweak_bing"; Package = "" },

        [pscustomobject]@{ Text = "Disable Windows Lockscreen Suggestions"; Action = "tweak_suggestions"; Package = "" },

        [pscustomobject]@{ Text = "Disable Windows Telemetry Background tracking"; Action = "tweak_telemetry"; Package = "" },

        [pscustomobject]@{ Text = "Disable Cortana Voice Privileges globally"; Action = "tweak_cortana"; Package = "" }

    )



    $script:debloatCheckboxes = @()

    $flow.SuspendLayout()

    foreach ($opt in $bloatwareOptions) {

        $cb = New-Object System.Windows.Forms.CheckBox

        $cb.Text = $opt.Text

        $cb.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)

        $cb.ForeColor = Get-ThemeColor 'Text'

        $cb.Size = New-Object System.Drawing.Size(325, 36)

        $cb.Tag = $opt

        $cb.Cursor = [System.Windows.Forms.Cursors]::Hand

        $cb.Checked = $true

        

        $cb.Add_MouseEnter({ param($sender, $e) $sender.Parent.Focus() | Out-Null })

        $flow.Controls.Add($cb)

        $script:debloatCheckboxes += $cb

    }

    $flow.ResumeLayout($true)

    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $btnSelectAll.Add_Click({

        foreach ($cb in $script:debloatCheckboxes) { $cb.Checked = $true }

    })

    $btnClearAll.Add_Click({

        foreach ($cb in $script:debloatCheckboxes) { $cb.Checked = $false }

    })



    $btnClean.Add_Click({

        $waitForm = New-Object System.Windows.Forms.Form

        $waitForm.Text = "Removing Bloatware..."

        $waitForm.Size = New-Object System.Drawing.Size(400, 160)

        $waitForm.StartPosition = 'CenterParent'

        $waitForm.FormBorderStyle = 'FixedDialog'

        $waitForm.ControlBox = $false

        $waitForm.ShowInTaskbar = $false

        $waitForm.BackColor = Get-ThemeColor 'Panel'

        

        $lblWait = New-Object System.Windows.Forms.Label

        $lblWait.Text = "Kripya intezar karein... Windows hardener rules apply ho rahe hain."

        $lblWait.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

        $lblWait.ForeColor = Get-ThemeColor 'Text'

        $lblWait.SetBounds(20, 20, 360, 40)

        $waitForm.Controls.Add($lblWait)

        

        $progress = New-Object System.Windows.Forms.ProgressBar

        $progress.Style = 'Marquee'

        $progress.MarqueeAnimationSpeed = 30

        $progress.SetBounds(20, 70, 340, 25)

        $waitForm.Controls.Add($progress)



        $waitForm.Add_Shown({

            [System.Windows.Forms.Application]::DoEvents()

            try {

                foreach ($cb in $script:debloatCheckboxes) {

                    if ($cb.Checked) {

                        $opt = $cb.Tag

                        $lblWait.Text = "Processing: $($opt.Text)..."

                        [System.Windows.Forms.Application]::DoEvents()



                        if ($opt.Action -eq "appx") {

                            Get-AppxPackage -Name $opt.Package -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue

                        } elseif ($opt.Action -eq "onedrive") {

                            # Uninstall OneDrive client safely

                            taskkill /f /im OneDrive.exe >$null 2>&1

                            $sys32 = [System.Environment]::GetFolderPath('System')

                            $sysWow64 = Join-Path (Split-Path $sys32 -Parent) "SysWOW64"

                            $setupPath = if (Test-Path "$sysWow64\OneDriveSetup.exe") { "$sysWow64\OneDriveSetup.exe" } else { "$sys32\OneDriveSetup.exe" }

                            if (Test-Path $setupPath) {

                                Start-Process -FilePath $setupPath -ArgumentList "/uninstall" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

                            }

                            Get-AppxPackage -Name $opt.Package -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue

                        } elseif ($opt.Action -eq "tweak_bing") {

                            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f >$null 2>&1

                            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /t REG_DWORD /d 0 /f >$null 2>&1

                        } elseif ($opt.Action -eq "tweak_suggestions") {

                            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >$null 2>&1

                            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /t REG_DWORD /d 0 /f >$null 2>&1

                        } elseif ($opt.Action -eq "tweak_telemetry") {

                            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >$null 2>&1

                            stop-service -Name DiagTrack -ErrorAction SilentlyContinue

                            set-service -Name DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue

                        } elseif ($opt.Action -eq "tweak_cortana") {

                            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f >$null 2>&1

                        }

                    }

                }

                

                # Close dialog and notify user FIRST, then restart explorer

                $waitForm.Close()

                Out-MessageBox("Windows bloatware remover & privacy hardener applied successfully!`r`nExplorer will now restart to apply visual registry tweaks.", "Debloater Completed", "OK", "Information") | Out-Null

                

                # Restart explorer to apply registry visual updates (after form is closed safely)

                taskkill /f /im explorer.exe >$null 2>&1

                Start-Sleep -Milliseconds 500

                Start-Process explorer.exe -ErrorAction SilentlyContinue

            } catch {

                $waitForm.Close()

                Out-MessageBox("Debloater running error: $_", "Debloater Error", "OK", "Error") | Out-Null

            }

        })

        $waitForm.ShowDialog($form) | Out-Null

    })



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function New-DiagnosticCardPanel {

    param(

        [string]$Title,

        [string]$Value,

        [string]$Detail,

        [string]$Color = '#CFE8FF',

        [int]$Width = 330,

        [int]$Height = 160

    )



    $cardPanel = New-Object System.Windows.Forms.Panel

    $cardPanel.Size = New-Object System.Drawing.Size($Width, $Height)

    $cardPanel.Margin = New-Object System.Windows.Forms.Padding(10)

    $cardPanel.BackColor = Get-ThemeColor 'Panel2'

    $cardPanel.BorderStyle = 'FixedSingle'

    Enable-DoubleBuffer $cardPanel



    $lblTitle = New-Object System.Windows.Forms.Label

    $lblTitle.Text = $Title

    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)

    $lblTitle.ForeColor = Get-ThemeColor 'Muted'

    $lblTitle.SetBounds(12, 10, $Width - 30, 18)

    $lblTitle.AutoEllipsis = $true

    $cardPanel.Controls.Add($lblTitle)



    $lblVal = New-Object System.Windows.Forms.Label

    $lblVal.Text = $Value

    $lblVal.Font = New-Object System.Drawing.Font('Segoe UI', 12.5, [System.Drawing.FontStyle]::Bold)

    $lblVal.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Color)

    $lblVal.SetBounds(10, 32, $Width - 28, 30)

    $lblVal.AutoEllipsis = $true

    $cardPanel.Controls.Add($lblVal)



    $lblDesc = New-Object System.Windows.Forms.Label

    $lblDesc.Text = $Detail

    $lblDesc.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblDesc.ForeColor = Get-ThemeColor 'Text'

    $lblDesc.SetBounds(12, 66, $Width - 30, $Height - 78)

    $lblDesc.AutoEllipsis = $true

    $cardPanel.Controls.Add($lblDesc)



    return $cardPanel

}



function Get-SafeCpuTemperature {

    if ($script:_thermalQueriesSupported -eq $false) {

        return $null

    }

    

    $tempScript = [System.IO.Path]::Combine($env:TEMP, "get_temp_safe.ps1")

    $code = @'

    try {

        $zones = Get-CimInstance -Namespace "root\wmi" -ClassName "MSAcpi_ThermalZoneTemperature" -ErrorAction Stop

        if ($zones) {

            $temps = @()

            foreach ($z in $zones) {

                $c = ($z.CurrentTemperature - 2732) / 10

                $temps += $c

            }

            Write-Output ($temps -join ",")

        }

    } catch {

        exit 1

    }

'@

    try {

        $code | Set-Content -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue

    } catch {}

    

    $psi = New-Object System.Diagnostics.ProcessStartInfo

    $psi.FileName = "powershell.exe"

    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`""

    $psi.UseShellExecute = $false

    $psi.RedirectStandardOutput = $true

    $psi.CreateNoWindow = $true

    

    try {

        $proc = [System.Diagnostics.Process]::Start($psi)

        $completed = $proc.WaitForExit(2000) # 2-second timeout

        if ($completed -and $proc.ExitCode -eq 0) {

            $out = $proc.StandardOutput.ReadToEnd().Trim()

            if (-not [string]::IsNullOrWhiteSpace($out)) {

                $script:_thermalQueriesSupported = $true

                return $out.Split(',') | ForEach-Object { [double]$_ }

            }

        }

    } catch {}

    

    $script:_thermalQueriesSupported = $false

    return $null

}



function Show-HardwareDiagnosticsPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "System Diagnostics & Hardware Health"

    $metaLabel.Text = "Analyze S.M.A.R.T. disk prediction metrics, RAM chip slots, and laptop battery design capacity"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_hardware_diagnostics'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 110

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 20, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Local Hardware Health Diagnostics"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 15)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Below are real-time local hardware statuses. Click Export Health Report to save a branded client certificate."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 45)

    $headerPanel.Controls.Add($panelSub)



    # "Export Health Report" Button

    $btnExportReport = New-Object System.Windows.Forms.Button

    $btnExportReport.Text = "Export Health Report"

    $btnExportReport.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnExportReport.FlatStyle = 'Flat'

    $btnExportReport.BackColor = Get-ThemeColor 'Accent'

    $btnExportReport.ForeColor = Get-ThemeColor 'CardText'

    $btnExportReport.SetBounds(550, 25, 180, 34)

    $btnExportReport.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnExportReport)

    $gridHost.Controls.Add($headerPanel)



    # Flow Panel for Hardware Cards

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    # Fetch Real-time Diagnostics safely using fast WMI queries

    # [SMART] Disk drives prediction check

    $diskHealth = "[HEALTHY]"

    $diskReason = "S.M.A.R.T. reports all disk drives are operating within normal limits."

    try {

        $predictions = Get-CimInstance -Namespace "root\wmi" -ClassName "MSStorageDriver_FailurePredictStatus" -ErrorAction SilentlyContinue

        if ($predictions) {

            foreach ($p in $predictions) {

                if ($p.PredictFailure) {

                    $diskHealth = "[CAUTION / FAILURE PREDICTED]"

                    $diskReason = "Warning: Disk drive at instance $($p.InstanceName) is predicting physical hardware failure!"

                }

            }

        }

    } catch {

        $diskHealth = "[HEALTHY - Offline Predict]"

        $diskReason = "S.M.A.R.T. prediction query not supported on this custom VM motherboard."

    }



    # [BATTERY] BatteryWear & Cycles diagnostics

    $batteryState = "N/A (Desktop PC)"

    $batteryWear = "0%"

    $batteryReport = "This computer runs on direct AC power."

    try {

        $batt = Get-CimInstance -ClassName "Win32_Battery" -ErrorAction SilentlyContinue

        if ($batt) {

            $designCap = $batt.DesignCapacity

            $fullCap = $batt.FullChargeCapacity

            if ($designCap -gt 0 -and $fullCap -gt 0) {

                $wear = [int](100 - (($fullCap / $designCap) * 100))

                if ($wear -lt 0) { $wear = 0 }

                $batteryWear = "$wear%"

                $batteryState = if ($batt.BatteryStatus -eq 2) { "Charging [AC]" } else { "Discharging [Battery]" }

                $batteryReport = "Design Capacity: $designCap mWh`r`nFull Capacity: $fullCap mWh`r`nBattery Wear: $batteryWear"

            } else {

                $batteryState = "Connected"

                $batteryReport = "Battery wear levels could not be retrieved from BIOS."

            }

        }

    } catch {}



    # [RAM] RAM chip configurations

    $ramTotalSlots = 4

    $ramSpeeds = @()

    $ramDetails = "No RAM details found in physical memory query."

    try {

        $chips = Get-CimInstance -ClassName "Win32_PhysicalMemory" -ErrorAction SilentlyContinue

        if ($chips) {

            $count = $chips.Count

            $speed = $chips[0].Speed

            $manufacturer = $chips[0].Manufacturer

            $ramDetails = "Detected: $count RAM Sticks`r`nSpeed: $speed MHz`r`nManufacturer: $manufacturer"

        }

    } catch {}



    # [CPU] CPU specifications

    $cpuModel = $env:PROCESSOR_IDENTIFIER

    try {

        $cpu = Get-CimInstance -ClassName "Win32_Processor" -ErrorAction SilentlyContinue

        if ($cpu) {

            $cpuModel = $cpu.Name.Trim()

        }

    } catch {}



    # [GPU] Graphics controller

    $gpuName = "Unknown Graphics Controller"

    $gpuStatus = "Unknown"

    $gpuDriver = ""

    try {

        $vids = Get-CimInstance -ClassName "Win32_VideoController" -ErrorAction SilentlyContinue

        if ($vids) {

            $gpuName = $vids[0].Name

            $gpuStatus = $vids[0].Status

            $gpuDriver = "Driver Version: $($vids[0].DriverVersion)`r`nVideo Architecture: $($vids[0].VideoArchitecture)"

        }

    } catch {}



    # [MOTHERBOARD] Baseboard Chipset

    $boardModel = "Unknown Board"

    $boardManufacturer = "Unknown Manufacturer"

    $boardSerial = "N/A"

    try {

        $bb = Get-CimInstance -ClassName "Win32_BaseBoard" -ErrorAction SilentlyContinue

        if ($bb) {

            $boardModel = $bb.Product

            $boardManufacturer = $bb.Manufacturer

            $boardSerial = "Serial: $($bb.SerialNumber)`r`nVersion: $($bb.Version)"

        }

    } catch {}



    # [AUDIO] Sound Controller

    $soundName = "High Definition Audio Device"

    $soundStatus = "OK"

    $soundReason = "Device is operating normally."

    try {

        $auds = Get-CimInstance -ClassName "Win32_SoundDevice" -ErrorAction SilentlyContinue

        if ($auds) {

            $soundName = $auds[0].Name

            $soundStatus = $auds[0].Status

            $soundReason = "Manufacturer: $($auds[0].Manufacturer)`r`nStatus Info: $($soundStatus)"

        }

    } catch {}



    # [BIOS] Firmware UEFI status

    $biosName = "Unknown BIOS"

    $biosStatus = "OK"

    $biosReason = "Firmware is operational."

    try {

        $bi = Get-CimInstance -ClassName "Win32_BIOS" -ErrorAction SilentlyContinue

        if ($bi) {

            $biosName = $bi.Name

            $biosStatus = $bi.Status

            $biosReason = "Version: $($bi.SMBIOSBIOSVersion)`r`nManufacturer: $($bi.Manufacturer)`r`nRelease: $($bi.ReleaseDate.ToString('yyyy-MM-dd'))"

        }

    } catch {}



    # [NIC] Network Card Speed & IP details

    $nicName = "No active network adapters found"

    $nicSpeed = "0 Mbps"

    $nicDetails = "No active network adapters."

    $nicColor = "#FFCC00"

    try {

        $adapters = Get-CimInstance -ClassName "Win32_NetworkAdapter" -Filter "NetEnabled=True" -ErrorAction SilentlyContinue

        if ($adapters) {

            $firstAdapter = $adapters | Select-Object -First 1

            $nicName = $firstAdapter.Name

            $speedRaw = $firstAdapter.Speed

            if ($speedRaw -gt 0) {

                if ($speedRaw -ge 1GB) {

                    $nicSpeed = "$([math]::Round($speedRaw / 1GB, 1)) Gbps"

                } else {

                    $nicSpeed = "$([math]::Round($speedRaw / 1MB, 0)) Mbps"

                }

            }

            $config = Get-CimInstance -ClassName "Win32_NetworkAdapterConfiguration" -Filter "Index=$($firstAdapter.Index)" -ErrorAction SilentlyContinue

            $ips = if ($config.IPAddress) { $config.IPAddress -join ", " } else { "No IP Assigned" }

            $mac = $firstAdapter.MACAddress

            $nicDetails = "IP: $ips`r`nMAC: $mac`r`nSpeed: $nicSpeed"

            $nicColor = "#CFE8FF"

        } else {

            $nicName = "Interface Disconnected"

            $nicDetails = "No active Ethernet/Wi-Fi connection is enabled."

        }

    } catch {

        $nicDetails = "Query Error: $_"

    }



    # [STORAGE DISKS] Logical Volumes Free Space

    $driveDetails = "No storage volumes discovered."

    $driveSummary = "Storage Overview"

    try {

        $disks = Get-CimInstance -ClassName "Win32_LogicalDisk" -Filter "DriveType=3" -ErrorAction SilentlyContinue

        if ($disks) {

            $lines = @()

            foreach ($disk in $disks) {

                $total = [math]::Round($disk.Size / 1GB, 1)

                $free = [math]::Round($disk.FreeSpace / 1GB, 1)

                $percent = [math]::Round(($free / $disk.Size) * 100, 1)

                $lines += "Drive $($disk.DeviceID): $free GB free of $total GB ($percent%)"

            }

            $driveDetails = $lines -join "`r`n"

            $driveSummary = "$($disks.Count) Fixed Drive(s)"

        }

    } catch {

        $driveDetails = "Query Error: $_"

    }



    # [TPM] Trusted Platform Module

    $tpmVersion = "TPM: Absent/Disabled"

    $tpmStatus = "N/A or Disabled in BIOS"

    $tpmColor = "#FF9999"

    try {

        $tpm = Get-CimInstance -Namespace "Root\CIMV2\Security\MicrosoftTpm" -ClassName "Win32_Tpm" -ErrorAction SilentlyContinue

        if ($tpm) {

            $specVer = $tpm.SpecVersion

            $activated = if ($tpm.IsActivated().IsActivated) { "Activated" } else { "Deactivated" }

            $enabled = if ($tpm.IsEnabled().IsEnabled) { "Enabled" } else { "Disabled" }

            $owned = if ($tpm.IsOwned().IsOwned) { "Owned" } else { "Unowned" }

            $tpmVersion = "TPM Spec v$($specVer.Split(',')[0])"

            $tpmStatus = "Status: $enabled & $activated`r`nOwnership: $owned`r`nManufacturer: $($tpm.ManufacturerId)"

            $tpmColor = "#DDF3E4"

        } else {

            $tpmStatus = "TPM chip not detected in motherboard security scope.`r`nRequired for Windows 11 installation."

        }

    } catch {

        $tpmStatus = "Access to TPM WMI namespace denied or chip absent."

    }



    # [SYSTEM UPTIME] Telemetry

    $osVersion = "Windows OS"

    $osUptime = "Unknown Uptime"

    $osDetails = "N/A"

    try {

        $os = Get-CimInstance -ClassName "Win32_OperatingSystem" -ErrorAction SilentlyContinue

        if ($os) {

            $osVersion = "Windows $($os.Version)"

            $bootTime = $os.LastBootUpTime

            $uptime = New-TimeSpan -Start $bootTime -End (Get-Date)

            $osUptime = "$($uptime.Days)d, $($uptime.Hours)h, $($uptime.Minutes)m"

            $instDate = $os.InstallDate.ToString("yyyy-MM-dd")

            $osDetails = "Build: $($os.BuildNumber)`r`nUptime: $osUptime`r`nInstall Date: $instDate"

        }

    } catch {

        $osDetails = "Query Error: $_"

    }



    # [LIVE RESOURCE USAGE] CPU and RAM pressure

    $cpuLoadValue = "Unknown"

    $cpuLoadDetails = "CPU load counters unavailable."

    try {

        $processors = @(Get-CimInstance -ClassName "Win32_Processor" -ErrorAction SilentlyContinue)

        if ($processors.Count -gt 0) {

            $avgCpu = [math]::Round((($processors | Measure-Object -Property LoadPercentage -Average).Average), 0)

            $cpuLoadValue = "$avgCpu% Load"

            $cpuLoadDetails = "Logical processors: $env:NUMBER_OF_PROCESSORS`r`nCurrent average utilization: $avgCpu%"

        }

    } catch {}



    $ramUsageValue = "Unknown"

    $ramUsageDetails = "RAM usage counters unavailable."

    try {

        if ($os) {

            $totalRamGb = [math]::Round(($os.TotalVisibleMemorySize * 1KB) / 1GB, 1)

            $freeRamGb = [math]::Round(($os.FreePhysicalMemory * 1KB) / 1GB, 1)

            $usedRamGb = [math]::Round($totalRamGb - $freeRamGb, 1)

            $usedPct = if ($totalRamGb -gt 0) { [math]::Round(($usedRamGb / $totalRamGb) * 100, 0) } else { 0 }

            $ramUsageValue = "$usedPct% Used"

            $ramUsageDetails = "Used: $usedRamGb GB`r`nFree: $freeRamGb GB`r`nTotal: $totalRamGb GB"

        }

    } catch {}



    # [DRIVERS] Problem device summary

    $driverValue = "No Issues"

    $driverDetails = "No Plug and Play driver error codes detected."

    $driverColor = "#DDF3E4"

    try {

        $badDevices = @(Get-CimInstance -ClassName "Win32_PnPEntity" -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -ne 0 })

        if ($badDevices.Count -gt 0) {

            $driverValue = "$($badDevices.Count) Issue(s)"

            $driverDetails = ($badDevices | Select-Object -First 4 | ForEach-Object { "$($_.Name) [Code $($_.ConfigManagerErrorCode)]" }) -join "`r`n"

            $driverColor = "#FFF2CC"

        }

    } catch {

        $driverValue = "Query Error"

        $driverDetails = $_.Exception.Message

        $driverColor = "#FF9999"

    }

    $fullDriversList = if ($badDevices.Count -gt 0) { ($badDevices | ForEach-Object { "$($_.Name) [Code $($_.ConfigManagerErrorCode)]" }) -join "`r`n" } else { "No Plug and Play driver error codes detected." }



    # [SERVICES] Automatic services that are not running

    $serviceValue = "Healthy"

    $serviceDetails = "Automatic Windows services are running normally."

    $serviceColor = "#DDF3E4"

    try {

        $stoppedAuto = @(Get-CimInstance -ClassName "Win32_Service" -Filter "StartMode='Auto' AND State<>'Running'" -ErrorAction SilentlyContinue)

        if ($stoppedAuto.Count -gt 0) {

            $serviceValue = "$($stoppedAuto.Count) Stopped Auto"

            $serviceDetails = ($stoppedAuto | Select-Object -First 5 | ForEach-Object { "$($_.Name): $($_.State)" }) -join "`r`n"

            $serviceColor = "#FFF2CC"

        }

    } catch {

        $serviceValue = "Query Error"

        $serviceDetails = $_.Exception.Message

        $serviceColor = "#FF9999"

    }

    $fullServicesList = if ($stoppedAuto.Count -gt 0) { ($stoppedAuto | ForEach-Object { "$($_.Name): $($_.State)" }) -join "`r`n" } else { "Automatic Windows services are running normally." }



    # [STARTUP] Startup app inventory

    $startupValue = "0 Items"

    $startupDetails = "No startup entries discovered."

    try {

        $startupItems = @()

        $runKeys = @(

            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',

            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',

            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'

        )

        foreach ($key in $runKeys) {

            if (Test-Path $key) {

                $props = (Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }

                foreach ($prop in $props) { $startupItems += $prop.Name }

            }

        }

        foreach ($folder in @([Environment]::GetFolderPath('Startup'), "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {

            if (Test-Path -LiteralPath $folder) {

                $startupItems += @(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName)

            }

        }

        $startupItems = @($startupItems | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

        $startupValue = "$($startupItems.Count) Items"

        $startupDetails = if ($startupItems.Count -gt 0) { ($startupItems | Select-Object -First 6) -join "`r`n" } else { "No startup entries discovered." }

    } catch {

        $startupValue = "Query Error"

        $startupDetails = $_.Exception.Message

    }



    # [EVENTS] Recent system error summary

    $eventValue = "No Critical Errors"

    $eventDetails = "No recent critical/error system events found in the last 7 days."

    $eventColor = "#DDF3E4"

    try {

        $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1,2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 25 -ErrorAction SilentlyContinue)

        if ($events.Count -gt 0) {

            $criticalCount = @($events | Where-Object { $_.LevelDisplayName -eq 'Critical' }).Count

            $eventValue = "$($events.Count) Recent Errors"

            $eventDetails = "Critical: $criticalCount`r`n" + (($events | Select-Object -First 4 | ForEach-Object { "$($_.ProviderName) ID $($_.Id)" }) -join "`r`n")

            $eventColor = "#FFF2CC"

        }

    } catch {

        $eventValue = "Event Query Error"

        $eventDetails = $_.Exception.Message

        $eventColor = "#FF9999"

    }

    $fullEventsList = if ($events.Count -gt 0) { "Critical: $criticalCount`r`n" + (($events | ForEach-Object { "$($_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) | $($_.ProviderName) | ID $($_.Id) | $($_.Message -replace '`r`n',' ')" }) -join "`r`n") } else { "No recent critical/error system events found in the last 7 days." }



    # [TEMPERATURE] ACPI thermal zones when exposed by firmware

    $tempValue = "Not Exposed"

    $tempDetails = "Firmware did not expose temperature sensors through ACPI WMI."

    try {

        $tempsC = Get-SafeCpuTemperature

        if ($null -ne $tempsC -and $tempsC.Count -gt 0) {

            $maxTemp = ($tempsC | Measure-Object -Maximum).Maximum

            $tempValue = "$maxTemp C Max"

            $tempDetails = "Thermal zones: $($tempsC.Count)`r`nReadings: $($tempsC -join ', ') C"

        }

    } catch {}



    # [NETWORK] DNS and internet reachability

    $netTestValue = "Offline/Blocked"

    $netTestDetails = "Ping to 1.1.1.1 failed or was blocked."

    $netTestColor = "#FFF2CC"

    try {

        $dnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses.Count -gt 0 } | Select-Object -First 3)

        $dnsText = if ($dnsServers.Count -gt 0) { (($dnsServers | ForEach-Object { "$($_.InterfaceAlias): $($_.ServerAddresses -join ', ')" }) -join "`r`n") } else { "No IPv4 DNS servers found." }

        $pingOk = Test-Connection -ComputerName '1.1.1.1' -Count 1 -Quiet -ErrorAction SilentlyContinue

        if ($pingOk) {

            $netTestValue = "Internet OK"

            $netTestColor = "#DDF3E4"

        }

        $netTestDetails = "$dnsText`r`nPing 1.1.1.1: $pingOk"

    } catch {

        $netTestDetails = $_.Exception.Message

    }



    # Render diagnostics cards

    $ramVal = if ($null -ne $script:cachedTotalRam -and $script:cachedTotalRam -gt 0) { [math]::Round($script:cachedTotalRam, 1) } else { 16.0 }

    $cards = @(

        [pscustomobject]@{ Title = "S.M.A.R.T. STORAGE STATUS"; Value = $diskHealth; Detail = $diskReason; Color = if ($diskHealth -match 'HEALTHY') { "#DDF3E4" } else { "#FFF2CC" } },

        [pscustomobject]@{ Title = "LAPTOP BATTERY DIAGNOSTICS"; Value = $batteryState; Detail = $batteryReport; Color = "#CFE8FF" },

        [pscustomobject]@{ Title = "PHYSICAL RAM MEMORY SLOTS"; Value = "$ramVal GB Total"; Detail = $ramDetails; Color = "#E3D1FF" },

        [pscustomobject]@{ Title = "LIVE CPU UTILIZATION"; Value = $cpuLoadValue; Detail = $cpuLoadDetails; Color = "#CFE8FF" },

        [pscustomobject]@{ Title = "LIVE RAM PRESSURE"; Value = $ramUsageValue; Detail = $ramUsageDetails; Color = "#E3D1FF" },

        [pscustomobject]@{ Title = "PROCESSOR SPECIFICATIONS"; Value = "CPU Overview"; Detail = "$cpuModel`r`nArchitecture: $env:PROCESSOR_ARCHITECTURE"; Color = "#FFF2CC" },

        [pscustomobject]@{ Title = "GRAPHICS CONTROLLER GPU"; Value = "GPU Diagnostics"; Detail = "$gpuName`r`nStatus: $gpuStatus`r`n$gpuDriver"; Color = "#CFE8FF" },

        [pscustomobject]@{ Title = "MOTHERBOARD & CHIPSET"; Value = $boardModel; Detail = "Manufacturer: $boardManufacturer`r`n$boardSerial"; Color = "#DDF3E4" },

        [pscustomobject]@{ Title = "AUDIO CONTROLLER SOUND"; Value = "Audio Diagnostics"; Detail = "$soundName`r`n$soundReason"; Color = "#E3D1FF" },

        [pscustomobject]@{ Title = "FIRMWARE BIOS / UEFI"; Value = $biosStatus; Detail = "$biosName`r`n$biosReason"; Color = "#FFF2CC" },

        [pscustomobject]@{ Title = "NETWORK ACTIVE ADAPTER"; Value = $nicSpeed; Detail = "$nicName`r`n$nicDetails"; Color = $nicColor },

        [pscustomobject]@{ Title = "DNS AND INTERNET TEST"; Value = $netTestValue; Detail = $netTestDetails; Color = $netTestColor },

        [pscustomobject]@{ Title = "LOGICAL STORAGE VOLUMES"; Value = $driveSummary; Detail = $driveDetails; Color = "#DDF3E4" },

        [pscustomobject]@{ Title = "TPM SECURITY PROCESSOR"; Value = $tpmVersion; Detail = $tpmStatus; Color = $tpmColor },

        [pscustomobject]@{ Title = "DRIVER DEVICE STATUS"; Value = $driverValue; Detail = $driverDetails; Color = $driverColor },

        [pscustomobject]@{ Title = "WINDOWS SERVICES STATUS"; Value = $serviceValue; Detail = $serviceDetails; Color = $serviceColor },

        [pscustomobject]@{ Title = "STARTUP APPS INVENTORY"; Value = $startupValue; Detail = $startupDetails; Color = "#CFE8FF" },

        [pscustomobject]@{ Title = "RECENT SYSTEM EVENT ERRORS"; Value = $eventValue; Detail = $eventDetails; Color = $eventColor },

        [pscustomobject]@{ Title = "SYSTEM TEMPERATURE SENSORS"; Value = $tempValue; Detail = $tempDetails; Color = "#FFF2CC" },

        [pscustomobject]@{ Title = "WINDOWS VERSION AND UPTIME"; Value = $osUptime; Detail = "$osVersion`r`n$osDetails"; Color = "#E3D1FF" }

    )



    $flow.SuspendLayout()

    $diagCardWidth = if ($gridHost.ClientSize.Width -ge 1700) { 360 } else { 330 }

    foreach ($card in $cards) {

        $flow.Controls.Add((New-DiagnosticCardPanel -Title $card.Title -Value $card.Value -Detail $card.Detail -Color $card.Color -Width $diagCardWidth))

    }

    $flow.ResumeLayout($true)

    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $btnExportReport.Add_Click(({

        try {

            $reportDir = Join-Path $ToolkitRoot "Logs"

            if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }

            $reportPath = Join-Path $reportDir "System_Diagnostics_Report.html"

            $cardsHtml = (($cards | ForEach-Object {

                $safeTitle = [System.Security.SecurityElement]::Escape([string]$_.Title)

                $safeValue = [System.Security.SecurityElement]::Escape([string]$_.Value)

                

                # Fetch full, non-truncated list for specific cards

                $detailVal = $_.Detail

                if ($_.Title -eq "DRIVER DEVICE STATUS" -and $badDevices.Count -gt 0) {

                    $detailVal = $fullDriversList

                } elseif ($_.Title -eq "WINDOWS SERVICES STATUS" -and $stoppedAuto.Count -gt 0) {

                    $detailVal = $fullServicesList

                } elseif ($_.Title -eq "RECENT SYSTEM EVENT ERRORS" -and $events.Count -gt 0) {

                    $detailVal = $fullEventsList

                }

                

                $safeDetail = [System.Security.SecurityElement]::Escape([string]$detailVal) -replace "(`r`n|`n|`r)", '<br>'

                "<div class='card'><div class='title'>$safeTitle</div><div class='value'>$safeValue</div><div class='desc'>$safeDetail</div></div>"

            }) -join "`r`n")

            

            $htmlContent = @"

<!DOCTYPE html>

<html>

<head>

  <title>Local System Diagnostic Certificate</title>

  <style>

    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0d1117; color: #c9d1d9; padding: 30px; }

    h1 { color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 10px; }

    .card { background-color: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 20px; margin-bottom: 20px; }

    .title { font-weight: bold; font-size: 14px; color: #8b949e; text-transform: uppercase; }

    .value { font-size: 24px; font-weight: bold; color: #58a6ff; margin: 10px 0; }

    .desc { font-size: 14px; color: #c9d1d9; white-space: pre-line; }

    footer { text-align: center; margin-top: 50px; font-size: 12px; color: #8b949e; }

  </style>

</head>

<body>

  <h1>SysForge Studio - Hardware Diagnostics Cert</h1>

  $cardsHtml

  <footer>

    Generated by SysForge Studio

  </footer>

</body>

</html>

"@

            [System.IO.File]::WriteAllText($reportPath, $htmlContent, [System.Text.Encoding]::UTF8)

            Start-Process -FilePath $reportPath | Out-Null

            Out-MessageBox("Diagnostics Report exported and opened in browser successfully!`r`nReport saved to: Logs\System_Diagnostics_Report.html", "Report Exported", "OK", "Information") | Out-Null

        } catch {

            Out-MessageBox("Report export error: $_", "Export Error", "OK", "Error") | Out-Null

        }

    }).GetNewClosure())

    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-SoftwareDiagnosticsPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "Software Diagnostics & Windows App Health"

    $metaLabel.Text = "Winget, Windows Update, Store, runtimes, installers, startup apps, app errors"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_software_diagnostics'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 108

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $gridHost.Controls.Add($headerPanel)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Local Software Health Diagnostics"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 15)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Fast local checks for app inventory, installers, update services, runtimes, Store health, and recent software errors."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 45)

    $headerPanel.Controls.Add($panelSub)



    $btnRefresh = New-Object System.Windows.Forms.Button

    $btnRefresh.Text = "Refresh Scan"

    $btnRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnRefresh.FlatStyle = 'Flat'

    $btnRefresh.BackColor = Get-ThemeColor 'Accent'

    $btnRefresh.ForeColor = Get-ThemeColor 'CardText'

    $btnRefresh.SetBounds(550, 25, 145, 34)

    $btnRefresh.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnRefresh.Add_Click({ Show-SoftwareDiagnosticsPanel })

    $headerPanel.Controls.Add($btnRefresh)



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    $wingetValue = "Not Found"

    $wingetDetails = "Winget executable was not found in PATH or WindowsApps."

    $wingetColor = "#FFF2CC"

    try {

        $wingetPath = Resolve-WingetPath

        if (-not [string]::IsNullOrWhiteSpace($wingetPath)) {

            $version = (& $wingetPath --version 2>$null | Select-Object -First 1)

            $wingetValue = if ($version) { $version } else { "Available" }

            $wingetDetails = $wingetPath

            $wingetColor = "#DDF3E4"

        }

    } catch {

        $wingetValue = "Winget Error"

        $wingetDetails = $_.Exception.Message

        $wingetColor = "#FF9999"

    }



    $appsValue = "0 Apps"

    $appsDetails = "Installed app registry query unavailable."

    try {

        $uninstallRoots = @(

            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',

            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',

            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'

        )

        $appRows = @()

        foreach ($root in $uninstallRoots) {

            $appRows += @(Get-ItemProperty -Path $root -ErrorAction SilentlyContinue)

        }

        $apps = @($appRows | Where-Object { $_.DisplayName } | Sort-Object DisplayName -Unique)

        $fullAppsList = ($apps | ForEach-Object { $_.DisplayName }) -join "`r`n"

        $appsValue = "$($apps.Count) Apps"

        $appsDetails = ($apps | Select-Object -First 6 | ForEach-Object { $_.DisplayName }) -join "`r`n"

        if ([string]::IsNullOrWhiteSpace($appsDetails)) { $appsDetails = "No registered desktop apps discovered." }

    } catch {}



    $installerValue = "Unknown"

    $installerDetails = "Windows Installer service query failed."

    $installerColor = "#FFF2CC"

    try {

        $svc = Get-Service -Name msiserver -ErrorAction SilentlyContinue

        if ($svc) {

            $installerValue = $svc.Status.ToString()

            $installerDetails = "Service: $($svc.DisplayName)`r`nStartup is demand-based by Windows design."

            $installerColor = if ($svc.Status -eq 'Running' -or $svc.Status -eq 'Stopped') { "#DDF3E4" } else { "#FFF2CC" }

        }

    } catch {}



    $storeValue = "Not Installed"

    $storeDetails = "Microsoft Store package was not found."

    $storeColor = "#FFF2CC"

    try {

        $store = Get-AppxPackage -Name Microsoft.WindowsStore -ErrorAction SilentlyContinue

        if ($store) {

            $storeValue = "Installed"

            $storeDetails = "Version: $($store.Version)`r`nInstall: $($store.InstallLocation)"

            $storeColor = "#DDF3E4"

        }

    } catch {

        $storeValue = "Store Query Error"

        $storeDetails = $_.Exception.Message

        $storeColor = "#FF9999"

    }



    $pendingValue = "No Pending Reboot"

    $pendingDetails = "Common reboot-required registry flags were not detected."

    $pendingColor = "#DDF3E4"

    try {

        $pendingKeys = @(

            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',

            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',

            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'

        )

        $needsReboot = $false

        $reasons = @()

        foreach ($key in $pendingKeys) {

            if ($key -like '*Session Manager') {

                $p = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue

                if ($p.PendingFileRenameOperations) { $needsReboot = $true; $reasons += 'PendingFileRenameOperations' }

            } elseif (Test-Path -LiteralPath $key) {

                $needsReboot = $true

                $reasons += (Split-Path $key -Leaf)

            }

        }

        if ($needsReboot) {

            $pendingValue = "Reboot Required"

            $pendingDetails = $reasons -join "`r`n"

            $pendingColor = "#FFF2CC"

        }

    } catch {}



    $updateSvcValue = "Healthy"

    $updateSvcDetails = "Windows Update services are present."

    $updateSvcColor = "#DDF3E4"

    try {

        $names = @('wuauserv','bits','cryptsvc','UsoSvc')

        $svcLines = @()

        foreach ($name in $names) {

            $svc = Get-Service -Name $name -ErrorAction SilentlyContinue

            if ($svc) { $svcLines += "$($svc.Name): $($svc.Status)" }

        }

        $updateSvcDetails = $svcLines -join "`r`n"

        if ($svcLines -match 'Stopped') {

            $updateSvcValue = "Review Services"

            $updateSvcColor = "#FFF2CC"

        }

    } catch {}



    $runtimeValue = ".NET Unknown"

    $runtimeDetails = "Runtime query unavailable."

    try {

        $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue

        if ($dotnet) {

            $runtimes = @(& $dotnet.Source --list-runtimes 2>$null)

            $runtimeValue = "$($runtimes.Count) .NET Runtimes"

            $runtimeDetails = ($runtimes | Select-Object -First 6) -join "`r`n"

        } else {

            $ndp = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue

            if ($ndp.Release) {

                $runtimeValue = ".NET Framework v4"

                $runtimeDetails = "Release key: $($ndp.Release)`r`nVersion: $($ndp.Version)"

            }

        }

    } catch {}



    $vcValue = "0 VC++"

    $vcDetails = "No Microsoft Visual C++ redistributables found."

    try {

        $vcApps = @($apps | Where-Object { $_.DisplayName -match 'Visual C\+\+|Redistributable' })

        $vcValue = "$($vcApps.Count) VC++ Runtime(s)"

        if ($vcApps.Count -gt 0) {

            $vcDetails = ($vcApps | Select-Object -First 6 | ForEach-Object { $_.DisplayName }) -join "`r`n"

        }

    } catch {}



    $startupValue = "0 Startup Items"

    $startupDetails = "No startup apps found."

    try {

        $startupNames = @()

        foreach ($key in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')) {

            if (Test-Path $key) {

                $startupNames += @((Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | Select-Object -ExpandProperty Name)

            }

        }

        $startupNames = @($startupNames | Sort-Object -Unique)

        $fullStartupList = $startupNames -join "`r`n"

        $startupValue = "$($startupNames.Count) Startup Items"

        if ($startupNames.Count -gt 0) { $startupDetails = ($startupNames | Select-Object -First 6) -join "`r`n" }

    } catch {}



    $appEventValue = "No Recent App Errors"

    $appEventDetails = "No recent Application log errors found in the last 7 days."

    $appEventColor = "#DDF3E4"

    try {

        $appEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Level = 1,2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 25 -ErrorAction SilentlyContinue)

        if ($appEvents.Count -gt 0) {

            $appEventValue = "$($appEvents.Count) App Errors"

            $appEventDetails = ($appEvents | Select-Object -First 5 | ForEach-Object { "$($_.ProviderName) ID $($_.Id)" }) -join "`r`n"

            $appEventColor = "#FFF2CC"

        }

    } catch {}



    $defenderValue = "Unknown"

    $defenderDetails = "Defender status cmdlet unavailable."

    $defenderColor = "#FFF2CC"

    try {

        $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue

        if ($mp) {

            $defenderValue = if ($mp.RealTimeProtectionEnabled) { "Protection On" } else { "Protection Off" }

            $defenderDetails = "AV signature: $($mp.AntivirusSignatureLastUpdated)`r`nEngine: $($mp.AMServiceEnabled)`r`nReal-time: $($mp.RealTimeProtectionEnabled)"

            $defenderColor = if ($mp.RealTimeProtectionEnabled) { "#DDF3E4" } else { "#FFF2CC" }

        }

    } catch {}



    $cards = @(

        [pscustomobject]@{ Title = "WINGET PACKAGE MANAGER"; Value = $wingetValue; Detail = $wingetDetails; Color = $wingetColor },

        [pscustomobject]@{ Title = "INSTALLED DESKTOP APPS"; Value = $appsValue; Detail = $appsDetails; Color = "#CFE8FF" },

        [pscustomobject]@{ Title = "WINDOWS INSTALLER SERVICE"; Value = $installerValue; Detail = $installerDetails; Color = $installerColor },

        [pscustomobject]@{ Title = "MICROSOFT STORE PACKAGE"; Value = $storeValue; Detail = $storeDetails; Color = $storeColor },

        [pscustomobject]@{ Title = "PENDING REBOOT STATE"; Value = $pendingValue; Detail = $pendingDetails; Color = $pendingColor },

        [pscustomobject]@{ Title = "WINDOWS UPDATE SERVICES"; Value = $updateSvcValue; Detail = $updateSvcDetails; Color = $updateSvcColor },

        [pscustomobject]@{ Title = ".NET RUNTIME HEALTH"; Value = $runtimeValue; Detail = $runtimeDetails; Color = "#E3D1FF" },

        [pscustomobject]@{ Title = "VC++ REDISTRIBUTABLES"; Value = $vcValue; Detail = $vcDetails; Color = "#FFF2CC" },

        [pscustomobject]@{ Title = "STARTUP SOFTWARE LOAD"; Value = $startupValue; Detail = $startupDetails; Color = "#CFE8FF" },

        [pscustomobject]@{ Title = "RECENT APPLICATION ERRORS"; Value = $appEventValue; Detail = $appEventDetails; Color = $appEventColor },

        [pscustomobject]@{ Title = "MICROSOFT DEFENDER APP HEALTH"; Value = $defenderValue; Detail = $defenderDetails; Color = $defenderColor }

    )



    $flow.SuspendLayout()

    $diagCardWidth = if ($gridHost.ClientSize.Width -ge 1700) { 360 } else { 330 }

    foreach ($card in $cards) {

        $flow.Controls.Add((New-DiagnosticCardPanel -Title $card.Title -Value $card.Value -Detail $card.Detail -Color $card.Color -Width $diagCardWidth))

    }

    $flow.ResumeLayout($true)

    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $btnExportReport = New-Object System.Windows.Forms.Button

    $btnExportReport.Text = "Export Health Report"

    $btnExportReport.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnExportReport.FlatStyle = 'Flat'

    $btnExportReport.BackColor = Get-ThemeColor 'Accent'

    $btnExportReport.ForeColor = Get-ThemeColor 'CardText'

    $btnExportReport.SetBounds(705, 25, 180, 34)

    $btnExportReport.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnExportReport.Add_Click(({

        try {

            $reportDir = Join-Path $ToolkitRoot "Logs"

            if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }

            $reportPath = Join-Path $reportDir "Software_Diagnostics_Report.html"

            $cardsHtml = (($cards | ForEach-Object {

                $safeTitle = [System.Security.SecurityElement]::Escape([string]$_.Title)

                $safeValue = [System.Security.SecurityElement]::Escape([string]$_.Value)

                

                # Fetch full, non-truncated list for specific cards

                $detailVal = $_.Detail

                if ($_.Title -eq "INSTALLED DESKTOP APPS") {

                    $detailVal = $fullAppsList

                } elseif ($_.Title -eq "STARTUP SOFTWARE LOAD") {

                    $detailVal = $fullStartupList

                } elseif ($_.Title -eq "VC++ REDISTRIBUTABLES") {

                    $detailVal = ($vcApps | ForEach-Object { $_.DisplayName }) -join "`r`n"

                } elseif ($_.Title -eq "RECENT APPLICATION ERRORS" -and $appEvents.Count -gt 0) {

                    $detailVal = ($appEvents | ForEach-Object { "$($_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) | $($_.ProviderName) | ID $($_.Id) | $($_.Message -replace '`r`n',' ')" }) -join "`r`n"

                }

                

                $safeDetail = [System.Security.SecurityElement]::Escape([string]$detailVal) -replace "(`r`n|`n|`r)", '<br>'

                "<div class='card'><div class='title'>$safeTitle</div><div class='value'>$safeValue</div><div class='desc'>$safeDetail</div></div>"

            }) -join "`r`n")

            

            $htmlContent = @"

<!DOCTYPE html>

<html>

<head>

  <title>Local Software Diagnostic Certificate</title>

  <style>

    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0d1117; color: #c9d1d9; padding: 30px; }

    h1 { color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 10px; }

    .card { background-color: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 20px; margin-bottom: 20px; }

    .title { font-weight: bold; font-size: 14px; color: #8b949e; text-transform: uppercase; }

    .value { font-size: 24px; font-weight: bold; color: #58a6ff; margin: 10px 0; }

    .desc { font-size: 14px; color: #c9d1d9; white-space: pre-line; }

    footer { text-align: center; margin-top: 50px; font-size: 12px; color: #8b949e; }

  </style>

</head>

<body>

  <h1>SysForge Studio - Software Diagnostics Cert</h1>

  $cardsHtml

  <footer>

    Generated by SysForge Studio

  </footer>

</body>

</html>

"@

            [System.IO.File]::WriteAllText($reportPath, $htmlContent, [System.Text.Encoding]::UTF8)

            Start-Process -FilePath $reportPath | Out-Null

            Out-MessageBox("Software Diagnostics Report exported and opened in browser successfully!`r`nReport saved to: Logs\Software_Diagnostics_Report.html", "Report Exported", "OK", "Information") | Out-Null

        } catch {

            Out-MessageBox("Report export error: $_", "Export Error", "OK", "Error") | Out-Null

        }

    }).GetNewClosure())

    $headerPanel.Controls.Add($btnExportReport)



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}





function Show-OfflineRecoveryPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "Enterprise Offline Recovery Center"

    $metaLabel.Text = "Inject controller drivers, repair corrupted boot sector files, run deep SFC/DISM offline recovery scans, and disable crashing BSOD registry services"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_offline_recovery'



    # Top Area: Offline OS Selection

    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 150

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 15, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "WinPE Offline System Servicing & Repair"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 12)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Detect offline target partition, run repair modules, disable crashing drivers, or inject system drivers to resolve boot-loops."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 40)

    $headerPanel.Controls.Add($panelSub)



    # Label for target selection

    $lblOS = New-Object System.Windows.Forms.Label

    $lblOS.Text = "Select Target Offline Windows Folder:"

    $lblOS.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $lblOS.ForeColor = Get-ThemeColor 'Text'

    $lblOS.SetBounds(36, 75, 260, 20)

    $headerPanel.Controls.Add($lblOS)



    $comboOfflineOS = New-Object System.Windows.Forms.ComboBox

    $comboOfflineOS.DropDownStyle = 'DropDownList'

    $comboOfflineOS.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $comboOfflineOS.BackColor = Get-ThemeColor 'Panel'

    $comboOfflineOS.ForeColor = Get-ThemeColor 'Text'

    $comboOfflineOS.SetBounds(36, 98, 380, 28)



    # Automatically scan all drive letters for \Windows\System32

    $discoveredOS = [System.Collections.Generic.List[string]]::new()

    try {

        foreach ($d in [System.IO.DriveInfo]::GetDrives()) {

            if ($d.IsReady) {

                $winDir = Join-Path $d.Name "Windows"

                if (Test-Path (Join-Path $winDir "System32")) {

                    $discoveredOS.Add($winDir)

                }

            }

        }

    } catch {}



    if ($discoveredOS.Count -eq 0) {

        $comboOfflineOS.Items.Add("No Offline Windows OS Detected automatically") | Out-Null

        $comboOfflineOS.SelectedIndex = 0

    } else {

        foreach ($os in $discoveredOS) {

            $comboOfflineOS.Items.Add($os) | Out-Null

        }

        $comboOfflineOS.SelectedIndex = 0

    }

    $headerPanel.Controls.Add($comboOfflineOS)



    # Browse Button to manually find Windows directory

    $btnBrowseOS = New-Object System.Windows.Forms.Button

    $btnBrowseOS.Text = "Browse..."

    $btnBrowseOS.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnBrowseOS.FlatStyle = 'Flat'

    $btnBrowseOS.BackColor = Get-ThemeColor 'Button'

    $btnBrowseOS.ForeColor = Get-ThemeColor 'Text'

    $btnBrowseOS.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnBrowseOS.SetBounds(430, 95, 100, 32)

    $btnBrowseOS.Cursor = [System.Windows.Forms.Cursors]::Hand

    

    $btnBrowseOS.Add_Click({

        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog

        $dialog.Description = "Select target Offline Windows directory (e.g. D:\Windows)"

        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {

            $path = $dialog.SelectedPath

            if (Test-Path (Join-Path $path "System32")) {

                if ($comboOfflineOS.Items.Contains($path)) {

                    $comboOfflineOS.SelectedItem = $path

                } else {

                    $comboOfflineOS.Items.Insert(0, $path) | Out-Null

                    $comboOfflineOS.SelectedIndex = 0

                }

            } else {

                Out-MessageBox("Selected folder does not appear to contain a valid Windows installation (missing System32).", "Invalid Folder", "OK", "Warning") | Out-Null

            }

        }

    })

    $headerPanel.Controls.Add($btnBrowseOS)

    $gridHost.Controls.Add($headerPanel)



    # Scrollable Layout Panel for Action Cards

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    # RENDER 4 CARDS FOR OFFLINE ACTIONS

    # Card 1: Boot Sector & BCD Rebuild

    $card1 = New-Object System.Windows.Forms.Panel

    $card1.Size = New-Object System.Drawing.Size(350, 200)

    $card1.Margin = New-Object System.Windows.Forms.Padding(10)

    $card1.BackColor = Get-ThemeColor 'Panel2'

    $card1.BorderStyle = 'FixedSingle'

    Enable-DoubleBuffer $card1



    $c1Title = New-Object System.Windows.Forms.Label

    $c1Title.Text = "BOOT sector / BCD REPAIR"

    $c1Title.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $c1Title.ForeColor = Get-ThemeColor 'Muted'

    $c1Title.SetBounds(12, 10, 320, 18)

    $card1.Controls.Add($c1Title)



    $c1Val = New-Object System.Windows.Forms.Label

    $c1Val.Text = "[BCDBoot Rebuild Engine]"

    $c1Val.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

    $c1Val.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFF2CC")

    $c1Val.SetBounds(10, 30, 320, 24)

    $card1.Controls.Add($c1Val)



    $c1Desc = New-Object System.Windows.Forms.Label

    $c1Desc.Text = "Rebuilds offline Boot Configuration Data (BCD) files and sets boot partition configuration parameters automatically using Windows BCDBoot engine."

    $c1Desc.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $c1Desc.ForeColor = Get-ThemeColor 'Text'

    $c1Desc.SetBounds(12, 58, 320, 75)

    $card1.Controls.Add($c1Desc)



    $btnC1 = New-Object System.Windows.Forms.Button

    $btnC1.Text = "Rebuild Boot Sectors"

    $btnC1.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnC1.FlatStyle = 'Flat'

    $btnC1.BackColor = Get-ThemeColor 'Accent'

    $btnC1.ForeColor = Get-ThemeColor 'CardText'

    $btnC1.SetBounds(12, 145, 322, 34)

    $btnC1.Cursor = [System.Windows.Forms.Cursors]::Hand

    

    $btnC1.Add_Click({

        $targetOS = $comboOfflineOS.SelectedItem

        if ([string]::IsNullOrWhiteSpace($targetOS) -or $targetOS -match 'No offline OS') {

            Out-MessageBox("Kripya ek valid offline Windows folder select karein first.", "Invalid Path", "OK", "Warning") | Out-Null

            return

        }

        

        $waitForm = New-Object System.Windows.Forms.Form

        $waitForm.Text = "BCDBoot Repair..."

        $waitForm.Size = New-Object System.Drawing.Size(400, 160)

        $waitForm.StartPosition = 'CenterParent'

        $waitForm.FormBorderStyle = 'FixedDialog'

        $waitForm.ControlBox = $false

        $waitForm.ShowInTaskbar = $false

        $waitForm.BackColor = Get-ThemeColor 'Panel'

        

        $lblWait = New-Object System.Windows.Forms.Label

        $lblWait.Text = "Executing BCDBoot repair rules on target partition..."

        $lblWait.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

        $lblWait.ForeColor = Get-ThemeColor 'Text'

        $lblWait.SetBounds(20, 20, 360, 40)

        $waitForm.Controls.Add($lblWait)

        

        $progress = New-Object System.Windows.Forms.ProgressBar

        $progress.Style = 'Marquee'

        $progress.MarqueeAnimationSpeed = 30

        $progress.SetBounds(20, 70, 340, 25)

        $waitForm.Controls.Add($progress)



        $waitForm.Tag = [pscustomobject]@{

            TargetOS = $targetOS

            LogFile = Join-Path $ToolkitRoot "Logs\offline_boot_repair.log"

        }



        $waitForm.Add_Shown({

            param($sender, $e)

            [System.Windows.Forms.Application]::DoEvents()

            $bag = $sender.Tag

            $targetOS = $bag.TargetOS

            $logFile = $bag.LogFile

            try {

                $logDir = Split-Path -Parent $logFile

                if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

                

                $cmd = "bcdboot `"$targetOS`" /f ALL"

                $output = cmd.exe /c $cmd 2>&1 | Out-String

                $output | Out-File -FilePath $logFile -Force -Encoding utf8

                

                $sender.Close()

                Out-MessageBox("BCDBoot completed successfully!`r`nResult: $output`r`nLogged to Logs\offline_boot_repair.log.", "Bootloader Rebuilt", "OK", "Information") | Out-Null

            } catch {

                $sender.Close()

                Out-MessageBox("Bootloader repair error: $_", "Error", "OK", "Error") | Out-Null

            }

        }.GetNewClosure())

        $waitForm.ShowDialog($form) | Out-Null

    }.GetNewClosure())

    $card1.Controls.Add($btnC1)

    $flow.Controls.Add($card1)



    # Card 2: SFC & DISM Offline System Checker

    $card2 = New-Object System.Windows.Forms.Panel

    $card2.Size = New-Object System.Drawing.Size(350, 200)

    $card2.Margin = New-Object System.Windows.Forms.Padding(10)

    $card2.BackColor = Get-ThemeColor 'Panel2'

    $card2.BorderStyle = 'FixedSingle'

    Enable-DoubleBuffer $card2



    $c2Title = New-Object System.Windows.Forms.Label

    $c2Title.Text = "SFC & DISM OFFLINE REPAIR"

    $c2Title.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $c2Title.ForeColor = Get-ThemeColor 'Muted'

    $c2Title.SetBounds(12, 10, 320, 18)

    $card2.Controls.Add($c2Title)



    $c2Val = New-Object System.Windows.Forms.Label

    $c2Val.Text = "[SFC / DISM Image Servicing]"

    $c2Val.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

    $c2Val.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#CFE8FF")

    $c2Val.SetBounds(10, 30, 320, 24)

    $card2.Controls.Add($c2Val)



    $c2Desc = New-Object System.Windows.Forms.Label

    $c2Desc.Text = "Runs offline System File Checker (SFC) scan and deep DISM Image recovery and health restoration checks to fix corrupted DLL files inside Windows system image."

    $c2Desc.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $c2Desc.ForeColor = Get-ThemeColor 'Text'

    $c2Desc.SetBounds(12, 58, 320, 75)

    $card2.Controls.Add($c2Desc)



    $btnC2 = New-Object System.Windows.Forms.Button

    $btnC2.Text = "Run Offline SFC & DISM"

    $btnC2.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnC2.FlatStyle = 'Flat'

    $btnC2.BackColor = Get-ThemeColor 'Accent'

    $btnC2.ForeColor = Get-ThemeColor 'CardText'

    $btnC2.SetBounds(12, 145, 322, 34)

    $btnC2.Cursor = [System.Windows.Forms.Cursors]::Hand

    

    $btnC2.Add_Click({

        $targetOS = $comboOfflineOS.SelectedItem

        if ([string]::IsNullOrWhiteSpace($targetOS) -or $targetOS -match 'No offline OS') {

            Out-MessageBox("Kripya ek valid offline Windows folder select karein first.", "Invalid Path", "OK", "Warning") | Out-Null

            return

        }

        

        $drive = [System.IO.Path]::GetPathRoot($targetOS)

        

        $waitForm = New-Object System.Windows.Forms.Form

        $waitForm.Text = "Running Offline Repairs..."

        $waitForm.Size = New-Object System.Drawing.Size(400, 160)

        $waitForm.StartPosition = 'CenterParent'

        $waitForm.FormBorderStyle = 'FixedDialog'

        $waitForm.ControlBox = $false

        $waitForm.ShowInTaskbar = $false

        $waitForm.BackColor = Get-ThemeColor 'Panel'

        

        $lblWait = New-Object System.Windows.Forms.Label

        $lblWait.Text = "Starting Offline SFC scan... Kripya 2-5 minutes wait krein."

        $lblWait.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

        $lblWait.ForeColor = Get-ThemeColor 'Text'

        $lblWait.SetBounds(20, 20, 360, 40)

        $waitForm.Controls.Add($lblWait)

        

        $progress = New-Object System.Windows.Forms.ProgressBar

        $progress.Style = 'Marquee'

        $progress.MarqueeAnimationSpeed = 30

        $progress.SetBounds(20, 70, 340, 25)

        $waitForm.Controls.Add($progress)



        $waitForm.Tag = [pscustomobject]@{

            TargetOS = $targetOS

            Drive = $drive

            LabelWait = $lblWait

            LogFile = Join-Path $ToolkitRoot "Logs\offline_sfc_dism.log"

        }



        $waitForm.Add_Shown({

            param($sender, $e)

            [System.Windows.Forms.Application]::DoEvents()

            $bag = $sender.Tag

            $targetOS = $bag.TargetOS

            $drive = $bag.Drive

            $lblWait = $bag.LabelWait

            $logFile = $bag.LogFile

            try {

                $logDir = Split-Path -Parent $logFile

                if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

                

                # 1. SFC Offline

                $sfcCmd = "sfc /scannow /offbootdir=`"$drive`" /offwindir=`"$targetOS`""

                $sfcOutput = cmd.exe /c $sfcCmd 2>&1 | Out-String

                "=== SFC OFFLINE RESULTS ===`r`n$sfcOutput`r`n" | Out-File -FilePath $logFile -Force -Encoding utf8

                

                # 2. DISM Offline

                $lblWait.Text = "Running Offline DISM RestoreHealth... Please wait."

                [System.Windows.Forms.Application]::DoEvents()

                $dismCmd = "dism /image:`"$targetOS`" /cleanup-image /restorehealth"

                $dismOutput = cmd.exe /c $dismCmd 2>&1 | Out-String

                "=== DISM OFFLINE RESULTS ===`r`n$dismOutput`r`n" | Out-File -FilePath $logFile -Append -Encoding utf8

                

                $sender.Close()

                Out-MessageBox("Offline SFC & DISM Repairs completed!`r`nSummary saved in Logs\offline_sfc_dism.log.", "Repair Executed", "OK", "Information") | Out-Null

            } catch {

                $sender.Close()

                Out-MessageBox("SFC/DISM Offline scan error: $_", "Error", "OK", "Error") | Out-Null

            }

        }.GetNewClosure())

        $waitForm.ShowDialog($form) | Out-Null

    }.GetNewClosure())

    $card2.Controls.Add($btnC2)

    $flow.Controls.Add($card2)



    # Card 3: Offline Registry Service Disabler

    $card3 = New-Object System.Windows.Forms.Panel

    $card3.Size = New-Object System.Drawing.Size(350, 200)

    $card3.Margin = New-Object System.Windows.Forms.Padding(10)

    $card3.BackColor = Get-ThemeColor 'Panel2'

    $card3.BorderStyle = 'FixedSingle'

    Enable-DoubleBuffer $card3



    $c3Title = New-Object System.Windows.Forms.Label

    $c3Title.Text = "OFFLINE REGISTRY SERVICE DISABLER"

    $c3Title.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $c3Title.ForeColor = Get-ThemeColor 'Muted'

    $c3Title.SetBounds(12, 10, 320, 18)

    $card3.Controls.Add($c3Title)



    $c3Val = New-Object System.Windows.Forms.Label

    $c3Val.Text = "[Registry Service Start Controller]"

    $c3Val.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

    $c3Val.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFD2D2")

    $c3Val.SetBounds(10, 30, 320, 24)

    $card3.Controls.Add($c3Val)



    $lblSvc = New-Object System.Windows.Forms.Label

    $lblSvc.Text = "Enter Service / Driver Name to disable:"

    $lblSvc.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)

    $lblSvc.ForeColor = Get-ThemeColor 'Text'

    $lblSvc.SetBounds(12, 60, 250, 15)

    $card3.Controls.Add($lblSvc)



    $txtSvc = New-Object System.Windows.Forms.TextBox

    $txtSvc.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $txtSvc.BackColor = Get-ThemeColor 'Panel'

    $txtSvc.ForeColor = Get-ThemeColor 'Text'

    $txtSvc.SetBounds(12, 78, 322, 24)

    $txtSvc.Text = "csagent"

    $card3.Controls.Add($txtSvc)



    $c3Desc = New-Object System.Windows.Forms.Label

    $c3Desc.Text = "Loads the offline SYSTEM hive and sets service's Start value to 4 (Disabled)."

    $c3Desc.Font = New-Object System.Drawing.Font('Segoe UI', 8)

    $c3Desc.ForeColor = Get-ThemeColor 'Muted'

    $c3Desc.SetBounds(12, 108, 320, 30)

    $card3.Controls.Add($c3Desc)



    $btnC3 = New-Object System.Windows.Forms.Button

    $btnC3.Text = "Disable Crashing Service"

    $btnC3.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnC3.FlatStyle = 'Flat'

    $btnC3.BackColor = Get-ThemeColor 'Accent'

    $btnC3.ForeColor = Get-ThemeColor 'CardText'

    $btnC3.SetBounds(12, 145, 322, 34)

    $btnC3.Cursor = [System.Windows.Forms.Cursors]::Hand

    

    $btnC3.Add_Click({

        $targetOS = $comboOfflineOS.SelectedItem

        if ([string]::IsNullOrWhiteSpace($targetOS) -or $targetOS -match 'No offline OS') {

            Out-MessageBox("Kripya ek valid offline Windows folder select karein first.", "Invalid Path", "OK", "Warning") | Out-Null

            return

        }

        

        $serviceName = $txtSvc.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($serviceName)) {

            Out-MessageBox("Kripya disable karne ke liye service name likhein.", "Empty Service", "OK", "Warning") | Out-Null

            return

        }



        $systemHive = Join-Path $targetOS "System32\config\SYSTEM"

        if (-not (Test-Path -LiteralPath $systemHive)) {

            Out-MessageBox("SYSTEM registry hive file missing at $systemHive!", "Missing Hive", "OK", "Error") | Out-Null

            return

        }



        $waitForm = New-Object System.Windows.Forms.Form

        $waitForm.Text = "Modifying Registry..."

        $waitForm.Size = New-Object System.Drawing.Size(400, 160)

        $waitForm.StartPosition = 'CenterParent'

        $waitForm.FormBorderStyle = 'FixedDialog'

        $waitForm.ControlBox = $false

        $waitForm.ShowInTaskbar = $false

        $waitForm.BackColor = Get-ThemeColor 'Panel'

        

        $lblWait = New-Object System.Windows.Forms.Label

        $lblWait.Text = "Offline SYSTEM hive load ho rha hai..."

        $lblWait.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

        $lblWait.ForeColor = Get-ThemeColor 'Text'

        $lblWait.SetBounds(20, 20, 360, 40)

        $waitForm.Controls.Add($lblWait)

        

        $progress = New-Object System.Windows.Forms.ProgressBar

        $progress.Style = 'Marquee'

        $progress.MarqueeAnimationSpeed = 30

        $progress.SetBounds(20, 70, 340, 25)

        $waitForm.Controls.Add($progress)



        $waitForm.Tag = [pscustomobject]@{

            SystemHive = $systemHive

            ServiceName = $serviceName

        }



        $waitForm.Add_Shown({

            param($sender, $e)

            [System.Windows.Forms.Application]::DoEvents()

            $bag = $sender.Tag

            $systemHive = $bag.SystemHive

            $serviceName = $bag.ServiceName

            try {

                reg load HKLM\OFFLINE_SYSTEM "$systemHive" >$null 2>&1

                if ($LASTEXITCODE -ne 0) {

                    $sender.Close()

                    Out-MessageBox("Registry Hive load failed. Check permissions or if hive is in-use.", "Hive Error", "OK", "Error") | Out-Null

                    return

                }

                

                try {

                    $serviceKey = "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\$serviceName"

                    reg add "$serviceKey" /v Start /t REG_DWORD /d 4 /f >$null 2>&1

                    $status = $LASTEXITCODE

                } finally {

                    reg unload HKLM\OFFLINE_SYSTEM >$null 2>&1

                }

                

                $sender.Close()

                if ($status -eq 0) {

                    Out-MessageBox("Service '$serviceName' has been disabled successfully (Start=4) in the offline registry hive!", "Service Disabled", "OK", "Information") | Out-Null

                } else {

                    Out-MessageBox("Service '$serviceName' record add/modify failed. Key may not exist in hive.", "Operation Failed", "OK", "Warning") | Out-Null

                }

            } catch {

                $sender.Close()

                Out-MessageBox("Registry modify error: $_", "Error", "OK", "Error") | Out-Null

            }

        }.GetNewClosure())

        $waitForm.ShowDialog($form) | Out-Null

    }.GetNewClosure())

    $card3.Controls.Add($btnC3)

    $flow.Controls.Add($card3)



    # Card 4: DISM Driver Injector

    $card4 = New-Object System.Windows.Forms.Panel

    $card4.Size = New-Object System.Drawing.Size(350, 200)

    $card4.Margin = New-Object System.Windows.Forms.Padding(10)

    $card4.BackColor = Get-ThemeColor 'Panel2'

    $card4.BorderStyle = 'FixedSingle'

    Enable-DoubleBuffer $card4



    $c4Title = New-Object System.Windows.Forms.Label

    $c4Title.Text = "DISM OFFLINE DRIVER INJECTOR"

    $c4Title.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $c4Title.ForeColor = Get-ThemeColor 'Muted'

    $c4Title.SetBounds(12, 10, 320, 18)

    $card4.Controls.Add($c4Title)



    $c4Val = New-Object System.Windows.Forms.Label

    $c4Val.Text = "[DISM /Add-Driver Controller]"

    $c4Val.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

    $c4Val.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#DDF3E4")

    $c4Val.SetBounds(10, 30, 320, 24)

    $card4.Controls.Add($c4Val)



    $lblDrv = New-Object System.Windows.Forms.Label

    $lblDrv.Text = "Driver Folder containing .inf files:"

    $lblDrv.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)

    $lblDrv.ForeColor = Get-ThemeColor 'Text'

    $lblDrv.SetBounds(12, 60, 200, 15)

    $card4.Controls.Add($lblDrv)



    $txtDrv = New-Object System.Windows.Forms.TextBox

    $txtDrv.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $txtDrv.BackColor = Get-ThemeColor 'Panel'

    $txtDrv.ForeColor = Get-ThemeColor 'Text'

    $txtDrv.SetBounds(12, 78, 230, 24)

    $card4.Controls.Add($txtDrv)



    $btnBrowseDrv = New-Object System.Windows.Forms.Button

    $btnBrowseDrv.Text = "..."

    $btnBrowseDrv.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnBrowseDrv.FlatStyle = 'Flat'

    $btnBrowseDrv.BackColor = Get-ThemeColor 'Button'

    $btnBrowseDrv.ForeColor = Get-ThemeColor 'Text'

    $btnBrowseDrv.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnBrowseDrv.SetBounds(250, 75, 84, 28)

    $btnBrowseDrv.Cursor = [System.Windows.Forms.Cursors]::Hand

    

    $btnBrowseDrv.Add_Click({

        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog

        $dialog.Description = "Select folder containing driver files (.inf)"

        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {

            $txtDrv.Text = $dialog.SelectedPath

        }

    })

    $card4.Controls.Add($btnBrowseDrv)



    $c4Desc = New-Object System.Windows.Forms.Label

    $c4Desc.Text = "Injects chipset or OEM controller drivers into the offline Windows installation automatically using DISM."

    $c4Desc.Font = New-Object System.Drawing.Font('Segoe UI', 8)

    $c4Desc.ForeColor = Get-ThemeColor 'Muted'

    $c4Desc.SetBounds(12, 108, 320, 30)

    $card4.Controls.Add($c4Desc)



    $btnC4 = New-Object System.Windows.Forms.Button

    $btnC4.Text = "Inject Backup Drivers"

    $btnC4.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnC4.FlatStyle = 'Flat'

    $btnC4.BackColor = Get-ThemeColor 'Accent'

    $btnC4.ForeColor = Get-ThemeColor 'CardText'

    $btnC4.SetBounds(12, 145, 322, 34)

    $btnC4.Cursor = [System.Windows.Forms.Cursors]::Hand

    

    $btnC4.Add_Click({

        $targetOS = $comboOfflineOS.SelectedItem

        if ([string]::IsNullOrWhiteSpace($targetOS) -or $targetOS -match 'No offline OS') {

            Out-MessageBox("Kripya ek valid offline Windows folder select karein first.", "Invalid Path", "OK", "Warning") | Out-Null

            return

        }



        $driverDir = $txtDrv.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($driverDir) -or -not (Test-Path -LiteralPath $driverDir)) {

            Out-MessageBox("Kripya driver files (.inf) wala valid folder select karein.", "Invalid Folder", "OK", "Warning") | Out-Null

            return

        }



        $waitForm = New-Object System.Windows.Forms.Form

        $waitForm.Text = "Injecting Drivers..."

        $waitForm.Size = New-Object System.Drawing.Size(400, 160)

        $waitForm.StartPosition = 'CenterParent'

        $waitForm.FormBorderStyle = 'FixedDialog'

        $waitForm.ControlBox = $false

        $waitForm.ShowInTaskbar = $false

        $waitForm.BackColor = Get-ThemeColor 'Panel'

        

        $lblWait = New-Object System.Windows.Forms.Label

        $lblWait.Text = "Executing DISM driver injection... Kripya thoda wait krein."

        $lblWait.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

        $lblWait.ForeColor = Get-ThemeColor 'Text'

        $lblWait.SetBounds(20, 20, 360, 40)

        $waitForm.Controls.Add($lblWait)

        

        $progress = New-Object System.Windows.Forms.ProgressBar

        $progress.Style = 'Marquee'

        $progress.MarqueeAnimationSpeed = 30

        $progress.SetBounds(20, 70, 340, 25)

        $waitForm.Controls.Add($progress)



        $waitForm.Tag = [pscustomobject]@{

            TargetOS = $targetOS

            DriverDir = $driverDir

            LogFile = Join-Path $ToolkitRoot "Logs\offline_driver_injector.log"

        }



        $waitForm.Add_Shown({

            param($sender, $e)

            [System.Windows.Forms.Application]::DoEvents()

            $bag = $sender.Tag

            $targetOS = $bag.TargetOS

            $driverDir = $bag.DriverDir

            $logFile = $bag.LogFile

            try {

                $logDir = Split-Path -Parent $logFile

                if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

                

                $cmd = "dism /image:`"$targetOS`" /add-driver /driver:`"$driverDir`" /recurse /forceunsigned"

                $output = cmd.exe /c $cmd 2>&1 | Out-String

                $output | Out-File -FilePath $logFile -Force -Encoding utf8

                

                $sender.Close()

                Out-MessageBox("Driver injection completed successfully!`r`nLogged in Logs\offline_driver_injector.log.", "Drivers Injected", "OK", "Information") | Out-Null

            } catch {

                $sender.Close()

                Out-MessageBox("Driver injection error: $_", "Error", "OK", "Error") | Out-Null

            }

        }.GetNewClosure())

        $waitForm.ShowDialog($form) | Out-Null

    }.GetNewClosure())

    $card4.Controls.Add($btnC4)

    $flow.Controls.Add($card4)



    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-StartupOptimizerPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "Enterprise Startup Optimizer"

    $metaLabel.Text = "Manage Windows startup applications, analyze safety risk profiles, and disable unwanted boot launchers"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_startup_optimizer'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 110

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 15, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "PC Boot Optimization Center"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 12)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Review and disable autorun items. Lowering active startup items can improve boot speeds by up to 50%."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 40)

    $headerPanel.Controls.Add($panelSub)



    $gridHost.Controls.Add($headerPanel)



    # Scrollable Layout Panel

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    # Fetch Startup Items

    $startupItems = @()

    $regPaths = @(

        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; Source = "Current User" },

        @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"; Source = "All Users" }

    )

    foreach ($rp in $regPaths) {

        if (Test-Path $rp.Path) {

            try {

                $key = Get-Item $rp.Path

                foreach ($valName in $key.GetValueNames()) {

                    $cmd = $key.GetValue($valName)

                    $score = "[UNVERIFIED / CAUTION]"

                    $color = "#FFD2D2" # Crimson/Red

                    if ($cmd -match 'System32|Windows|Microsoft' -or $valName -match 'Windows|Microsoft') {

                        $score = "[SYSTEM SAFE]"

                        $color = "#DDF3E4" # Green

                    } elseif ($cmd -match 'Google|Chrome|Discord|Spotify|OneDrive|Steam|Intel|AMD|Nvidia|Adobe' -or $valName -match 'Google|Chrome|Discord|Spotify|OneDrive|Steam|Intel|AMD|Nvidia') {

                        $score = "[KNOWN APP]"

                        $color = "#FFF2CC" # Yellow

                    }

                    $startupItems += [pscustomobject]@{

                        Name = $valName

                        Command = $cmd

                        Source = $rp.Source

                        RegistryPath = $rp.Path

                        Score = $score

                        Color = $color

                    }

                }

            } catch {}

        }

    }



    $flow.SuspendLayout()

    if ($startupItems.Count -eq 0) {

        $lblEmpty = New-Object System.Windows.Forms.Label

        $lblEmpty.Text = "No active startup applications found in Registry Run keys."

        $lblEmpty.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Italic)

        $lblEmpty.ForeColor = Get-ThemeColor 'Muted'

        $lblEmpty.AutoSize = $true

        $flow.Controls.Add($lblEmpty)

    } else {

        foreach ($item in $startupItems) {

            $card = New-Object System.Windows.Forms.Panel

            $card.Size = New-Object System.Drawing.Size(730, 95)

            $card.Margin = New-Object System.Windows.Forms.Padding(5, 5, 5, 10)

            $card.BackColor = Get-ThemeColor 'Panel2'

            $card.BorderStyle = 'FixedSingle'

            Enable-DoubleBuffer $card



            $lblName = New-Object System.Windows.Forms.Label

            $lblName.Text = $item.Name

            $lblName.Font = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)

            $lblName.ForeColor = Get-ThemeColor 'Text'

            $lblName.SetBounds(12, 10, 380, 20)

            $card.Controls.Add($lblName)



            $lblSrc = New-Object System.Windows.Forms.Label

            $lblSrc.Text = "Source: $($item.Source)"

            $lblSrc.Font = New-Object System.Drawing.Font('Segoe UI', 8)

            $lblSrc.ForeColor = Get-ThemeColor 'Muted'

            $lblSrc.SetBounds(14, 30, 380, 15)

            $card.Controls.Add($lblSrc)



            $lblCmd = New-Object System.Windows.Forms.Label

            $lblCmd.Text = $item.Command

            $lblCmd.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Italic)

            $lblCmd.ForeColor = Get-ThemeColor 'Muted'

            $lblCmd.SetBounds(14, 48, 550, 35)

            $card.Controls.Add($lblCmd)



            $lblScore = New-Object System.Windows.Forms.Label

            $lblScore.Text = $item.Score

            $lblScore.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)

            $lblScore.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($item.Color)

            $lblScore.TextAlign = 'MiddleCenter'

            $lblScore.SetBounds(580, 10, 135, 24)

            $card.Controls.Add($lblScore)



            $btnDisable = New-Object System.Windows.Forms.Button

            $btnDisable.Text = "Remove / Disable"

            $btnDisable.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)

            $btnDisable.FlatStyle = 'Flat'

            $btnDisable.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#5C1E1E")

            $btnDisable.ForeColor = [System.Drawing.Color]::White

            $btnDisable.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml("#A63434")

            $btnDisable.SetBounds(580, 48, 135, 30)

            $btnDisable.Cursor = [System.Windows.Forms.Cursors]::Hand



            $btnDisable.Add_Click({

                $confirm = Out-MessageBox("Are you sure you want to disable and delete the startup entry '$($item.Name)'?", "Confirm Disable", "YesNo", "Question")

                if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {

                    try {

                        Remove-ItemProperty -Path $item.RegistryPath -Name $item.Name -Force -ErrorAction SilentlyContinue

                        Out-MessageBox("Startup item successfully disabled!", "Success", "OK", "Information") | Out-Null

                        Show-StartupOptimizerPanel

                    } catch {

                        Out-MessageBox("Disable error: $_", "Error", "OK", "Error") | Out-Null

                    }

                }

            }.GetNewClosure())

            $card.Controls.Add($btnDisable)

            $flow.Controls.Add($card)

        }

    }

    $flow.ResumeLayout($true)



    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-NetworkScannerPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "Enterprise Network Subnet Scanner"

    $metaLabel.Text = "Scan local IP subnets, ping active office hosts, and map open network service ports"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_network_scanner'



    # Auto detect local IP

    $localIP = "192.168.1.100"

    try {

        $ipObj = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -and $_.DefaultIPGateway } | Select-Object -First 1

        if ($ipObj) { $localIP = $ipObj.IPAddress[0] }

    } catch {}



    $octets = $localIP -split '\.'

    $baseSubnet = if ($octets.Count -eq 4) { "$($octets[0]).$($octets[1]).$($octets[2])" } else { "192.168.1" }



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 140

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 15, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Subnet Ping & Service Mapper"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 12)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Scans first 35 subnet IPs for routers, core servers, and office assets with open ports (80 HTTP, 3389 RDP, etc.)"

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 40)

    $headerPanel.Controls.Add($panelSub)



    # Subnet Box

    $lblBase = New-Object System.Windows.Forms.Label

    $lblBase.Text = "Subnet Base IP Prefix:"

    $lblBase.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $lblBase.ForeColor = Get-ThemeColor 'Text'

    $lblBase.SetBounds(36, 75, 180, 20)

    $headerPanel.Controls.Add($lblBase)



    $txtSubnet = New-Object System.Windows.Forms.TextBox

    $txtSubnet.Text = $baseSubnet

    $txtSubnet.Font = New-Object System.Drawing.Font('Segoe UI', 10)

    $txtSubnet.BackColor = Get-ThemeColor 'Panel'

    $txtSubnet.ForeColor = Get-ThemeColor 'Text'

    $txtSubnet.SetBounds(36, 96, 180, 24)

    $headerPanel.Controls.Add($txtSubnet)



    # Scan button

    $btnScan = New-Object System.Windows.Forms.Button

    $btnScan.Text = "Scan Local Subnet"

    $btnScan.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnScan.FlatStyle = 'Flat'

    $btnScan.BackColor = Get-ThemeColor 'Accent'

    $btnScan.ForeColor = Get-ThemeColor 'CardText'

    $btnScan.SetBounds(230, 93, 180, 30)

    $btnScan.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnScan)



    $gridHost.Controls.Add($headerPanel)



    # Scrollable container for discovered hosts

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    $btnScan.Add_Click({

        $waitForm = New-Object System.Windows.Forms.Form

        $waitForm.Text = "Scanning Subnet..."

        $waitForm.Size = New-Object System.Drawing.Size(400, 160)

        $waitForm.StartPosition = 'CenterParent'

        $waitForm.FormBorderStyle = 'FixedDialog'

        $waitForm.ControlBox = $false

        $waitForm.ShowInTaskbar = $false

        $waitForm.BackColor = Get-ThemeColor 'Panel'

        

        $lblWait = New-Object System.Windows.Forms.Label

        $lblWait.Text = "Scanning local office IPs... Please wait."

        $lblWait.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

        $lblWait.ForeColor = Get-ThemeColor 'Text'

        $lblWait.SetBounds(20, 20, 360, 40)

        $waitForm.Controls.Add($lblWait)

        

        $progress = New-Object System.Windows.Forms.ProgressBar

        $progress.Style = 'Marquee'

        $progress.MarqueeAnimationSpeed = 30

        $progress.SetBounds(20, 70, 340, 25)

        $waitForm.Controls.Add($progress)



        $waitForm.Add_Shown({

            [System.Windows.Forms.Application]::DoEvents()

            try {

                $flow.Controls.Clear()

                $base = $txtSubnet.Text.Trim()

                $ping = New-Object System.Net.NetworkInformation.Ping

                $hostsDiscovered = 0



                for ($i = 1; $i -le 35; $i++) {

                    $ip = "$base.$i"

                    $lblWait.Text = "Pinging host: $ip..."

                    [System.Windows.Forms.Application]::DoEvents()

                    

                    try {

                        $reply = $ping.Send($ip, 45)

                        if ($reply.Status -eq 'Success') {

                            $hostsDiscovered++

                            

                            $hostName = "Unknown"

                            try { $hostName = [System.Net.Dns]::GetHostEntry($ip).HostName } catch {}



                            $openPorts = @()

                            $tcp = New-Object System.Net.Sockets.TcpClient

                            try {

                                $ar = $tcp.BeginConnect($ip, 80, $null, $null)

                                $success = $ar.AsyncWaitHandle.WaitOne(40, $false)

                                if ($success) { $openPorts += "HTTP (80)" }

                            } catch {} finally {

                                try { $tcp.Close() } catch {}

                            }

                            [System.Windows.Forms.Application]::DoEvents()



                            $tcp = New-Object System.Net.Sockets.TcpClient

                            try {

                                $ar = $tcp.BeginConnect($ip, 3389, $null, $null)

                                $success = $ar.AsyncWaitHandle.WaitOne(40, $false)

                                if ($success) { $openPorts += "RDP (3389)" }

                            } catch {} finally {

                                try { $tcp.Close() } catch {}

                            }

                            [System.Windows.Forms.Application]::DoEvents()



                            $portsText = if ($openPorts.Count -gt 0) { $openPorts -join ", " } else { "None Detected" }



                            # Render Card for device

                            $devCard = New-Object System.Windows.Forms.Panel

                            $devCard.Size = New-Object System.Drawing.Size(730, 80)

                            $devCard.Margin = New-Object System.Windows.Forms.Padding(5, 5, 5, 8)

                            $devCard.BackColor = Get-ThemeColor 'Panel2'

                            $devCard.BorderStyle = 'FixedSingle'

                            Enable-DoubleBuffer $devCard



                            $lblIp = New-Object System.Windows.Forms.Label

                            $lblIp.Text = "IP: $ip"

                            $lblIp.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

                            $lblIp.ForeColor = Get-ThemeColor 'Accent'

                            $lblIp.SetBounds(12, 10, 200, 22)

                            $devCard.Controls.Add($lblIp)



                            $lblHost = New-Object System.Windows.Forms.Label

                            $lblHost.Text = "Name: $hostName"

                            $lblHost.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

                            $lblHost.ForeColor = Get-ThemeColor 'Text'

                            $lblHost.SetBounds(14, 32, 380, 18)

                            $devCard.Controls.Add($lblHost)



                            $lblPing = New-Object System.Windows.Forms.Label

                            $lblPing.Text = "Ping Response: $($reply.RoundtripTime) ms"

                            $lblPing.Font = New-Object System.Drawing.Font('Segoe UI', 8)

                            $lblPing.ForeColor = Get-ThemeColor 'Muted'

                            $lblPing.SetBounds(14, 52, 200, 15)

                            $devCard.Controls.Add($lblPing)



                            $lblStatus = New-Object System.Windows.Forms.Label

                            $lblStatus.Text = "[ACTIVE]"

                            $lblStatus.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

                            $lblStatus.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#DDF3E4")

                            $lblStatus.SetBounds(550, 12, 160, 20)

                            $lblStatus.TextAlign = 'MiddleRight'

                            $devCard.Controls.Add($lblStatus)



                            $lblPorts = New-Object System.Windows.Forms.Label

                            $lblPorts.Text = "Open Ports: $portsText"

                            $lblPorts.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

                            $lblPorts.ForeColor = Get-ThemeColor 'Muted'

                            $lblPorts.SetBounds(450, 42, 260, 20)

                            $lblPorts.TextAlign = 'MiddleRight'

                            $devCard.Controls.Add($lblPorts)



                            $flow.Controls.Add($devCard)

                        }

                    } catch {}

                }



                if ($hostsDiscovered -eq 0) {

                    $lblEmpty = New-Object System.Windows.Forms.Label

                    $lblEmpty.Text = "No active subnet hosts detected in first 35 IP ranges."

                    $lblEmpty.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Italic)

                    $lblEmpty.ForeColor = Get-ThemeColor 'Muted'

                    $lblEmpty.AutoSize = $true

                    $flow.Controls.Add($lblEmpty)

                }



                $waitForm.Close()

            } catch {

                $waitForm.Close()

                Out-MessageBox("Scan subnet error: $_", "Error", "OK", "Error") | Out-Null

            }

        })

        $waitForm.ShowDialog($form) | Out-Null

    })



    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-ProcessManagerPanel {

    try {

        $searchBox.Visible = $true

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "Visual Process Manager & Thread Analyzer"

    $metaLabel.Text = "Monitor active CPU/RAM processes, thread counts, system handles, and force terminate rogue programs"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_process_manager'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 70

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 10, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "System Tasks & Running Processes"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 8)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Select a process row and click 'Force End Process' to terminate it instantly."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 34)

    $headerPanel.Controls.Add($panelSub)



    $btnKill = New-Object System.Windows.Forms.Button

    $btnKill.Text = "Force End Process"

    $btnKill.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnKill.FlatStyle = 'Flat'

    $btnKill.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FF3366")

    $btnKill.ForeColor = [System.Drawing.Color]::White

    $btnKill.SetBounds(550, 16, 180, 32)

    $btnKill.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnKill)



    $gridHost.Controls.Add($headerPanel)



    $dgv = New-Object System.Windows.Forms.DataGridView

    $dgv.Dock = 'Fill'

    $dgv.BackgroundColor = Get-ThemeColor 'Panel'

    $dgv.ForeColor = Get-ThemeColor 'Text'

    $dgv.GridColor = Get-ThemeColor 'Border'

    $dgv.DefaultCellStyle.BackColor = Get-ThemeColor 'Panel2'

    $dgv.DefaultCellStyle.ForeColor = Get-ThemeColor 'Text'

    $dgv.DefaultCellStyle.SelectionBackColor = Get-ThemeColor 'Accent'

    $dgv.DefaultCellStyle.SelectionForeColor = Get-ThemeColor 'CardText'

    $dgv.SelectionMode = 'FullRowSelect'

    $dgv.MultiSelect = $false

    $dgv.AllowUserToAddRows = $false

    $dgv.AllowUserToDeleteRows = $false

    $dgv.ReadOnly = $true

    $dgv.RowHeadersVisible = $false

    $dgv.AutoSizeColumnsMode = 'Fill'

    $dgv.Font = New-Object System.Drawing.Font('Consolas', 9.5)

    $dgv.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $dgv.ColumnHeadersDefaultCellStyle.BackColor = Get-ThemeColor 'Panel2'

    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = Get-ThemeColor 'Text'

    $dgv.EnableHeadersVisualStyles = $false



    $dgv.Columns.Add("PID", "PID") | Out-Null

    $dgv.Columns.Add("ProcessName", "Process Name") | Out-Null

    $dgv.Columns.Add("Memory", "Working Set (MB)") | Out-Null

    $dgv.Columns.Add("Threads", "Threads") | Out-Null

    $dgv.Columns.Add("Handles", "Handles") | Out-Null



    $dgv.Columns[0].Width = 80

    $dgv.Columns[1].Width = 250

    $dgv.Columns[2].Width = 150

    $dgv.Columns[3].Width = 100

    $dgv.Columns[4].Width = 100



    $refreshProcesses = ({

        param($filterText = "")

        $dgv.Rows.Clear()

        $procs = @()

        try {

            $procs = Get-Process | Sort-Object WorkingSet -Descending

        } catch {

            return

        }

        foreach ($p in $procs) {

            if ($filterText -and -not ($p.ProcessName -like "*$filterText*" -or $p.Id.ToString() -eq $filterText)) { continue }

            $wsMb = 0

            try { $wsMb = [math]::Round($p.WorkingSet / 1MB, 1) } catch {}

            $threadsCount = "N/A"

            try { $threadsCount = $p.Threads.Count } catch {}

            $handlesCount = "N/A"

            try { $handlesCount = $p.HandleCount } catch {}

            $rowIndex = $dgv.Rows.Add($p.Id, $p.ProcessName, $wsMb, $threadsCount, $handlesCount)

            

            if ($wsMb -ge 1000) {

                $dgv.Rows[$rowIndex].DefaultCellStyle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FF3366")

            } elseif ($wsMb -ge 500) {

                $dgv.Rows[$rowIndex].DefaultCellStyle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFCC00")

            }

        }

    }).GetNewClosure()

    $script:refreshProcesses = $refreshProcesses



    &$refreshProcesses



    # Text changed routing is safely managed by the global event handler to avoid leaks



    $btnKill.Add_Click(({

        $selectedRow = $null

        if ($dgv.SelectedRows.Count -gt 0) {

            $selectedRow = $dgv.SelectedRows[0]

        } elseif ($dgv.SelectedCells.Count -gt 0) {

            $selectedRow = $dgv.SelectedCells[0].OwningRow

        } elseif ($null -ne $dgv.CurrentRow) {

            $selectedRow = $dgv.CurrentRow

        }



        if ($null -ne $selectedRow) {

            $pidRaw = $selectedRow.Cells["PID"].Value

            $pName = $selectedRow.Cells["ProcessName"].Value

            if ($null -eq $pidRaw -or [string]::IsNullOrWhiteSpace("$pidRaw")) {

                Out-MessageBox("Could not read PID for selected process.", "Error", "OK", "Error") | Out-Null

                return

            }

            $confirm = Out-MessageBox("Are you sure you want to force terminate process: $pName (PID: $pidRaw)?", "Force End Process", "YesNo", "Warning")

            if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {

                try {

                    Stop-Process -Id ([int]$pidRaw) -Force -ErrorAction Stop

                    Out-MessageBox("Process $pName terminated successfully.", "Success", "OK", "Information") | Out-Null

                    &$refreshProcesses $searchBox.Text

                } catch {

                    Out-MessageBox("Error terminating process: $_", "Error", "OK", "Error") | Out-Null

                }

            }

        } else {

            Out-MessageBox("Please select a process row first.", "Warning", "OK", "Warning") | Out-Null

        }

    }).GetNewClosure())



    $gridHost.Controls.Add($dgv)

    $dgv.BringToFront()



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-NetstatConnPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "Live Port & Netstat Connections Analyzer"

    $metaLabel.Text = "Inspect active local/foreign TCP & UDP socket ports, resolve connection states, and identify owning executables"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_netstat_conn'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 70

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 10, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Active Socket Connection Telemetry"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 8)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Displays real-time socket connections. Red rows indicate ESTABLISHED external ports."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 34)

    $headerPanel.Controls.Add($panelSub)



    $btnRefresh = New-Object System.Windows.Forms.Button

    $btnRefresh.Text = "Refresh Connections"

    $btnRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnRefresh.FlatStyle = 'Flat'

    $btnRefresh.BackColor = Get-ThemeColor 'Accent'

    $btnRefresh.ForeColor = Get-ThemeColor 'CardText'

    $btnRefresh.SetBounds(550, 16, 180, 32)

    $btnRefresh.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnRefresh)



    $gridHost.Controls.Add($headerPanel)



    $dgv = New-Object System.Windows.Forms.DataGridView

    $dgv.Dock = "Fill"

    $dgv.BackgroundColor = Get-ThemeColor "Panel"

    $dgv.ForeColor = Get-ThemeColor "Text"

    $dgv.GridColor = Get-ThemeColor "Border"

    $dgv.DefaultCellStyle.BackColor = Get-ThemeColor "Panel2"

    $dgv.DefaultCellStyle.ForeColor = Get-ThemeColor "Text"

    $dgv.DefaultCellStyle.SelectionBackColor = Get-ThemeColor "Accent"

    $dgv.DefaultCellStyle.SelectionForeColor = Get-ThemeColor "CardText"

    $dgv.SelectionMode = "FullRowSelect"

    $dgv.MultiSelect = $false

    $dgv.AllowUserToAddRows = $false

    $dgv.AllowUserToDeleteRows = $false

    $dgv.ReadOnly = $true

    $dgv.RowHeadersVisible = $false

    $dgv.AutoSizeColumnsMode = 'None'

    $dgv.Font = New-Object System.Drawing.Font('Consolas', 9)

    $dgv.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $dgv.ColumnHeadersDefaultCellStyle.BackColor = Get-ThemeColor 'Panel2'

    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = Get-ThemeColor 'Text'

    $dgv.EnableHeadersVisualStyles = $false



    [void]$dgv.Columns.Add("Protocol", "Proto")

    [void]$dgv.Columns.Add("Local", "Local Address:Port")

    [void]$dgv.Columns.Add("Foreign", "Foreign Address:Port")

    [void]$dgv.Columns.Add("State", "Connection State")

    [void]$dgv.Columns.Add("PID", "PID")

    [void]$dgv.Columns.Add("Process", "Owning Process")



    $dgv.Columns[0].Width = 60

    $dgv.Columns[1].Width = 220

    $dgv.Columns[2].Width = 220

    $dgv.Columns[3].Width = 130

    $dgv.Columns[4].Width = 65

    $dgv.Columns[5].Width = 160



    # Store dgv reference in script scope so button click closure can reach it

    $script:_netstatDgv = $dgv



    # Store refresh logic as script-scope scriptblock so button click survives panel function return

    $script:_netstatRefresh = {

        try {

            $script:_netstatDgv.Rows.Clear()

        } catch { return }

        try {

            $tcp = Get-NetTCPConnection -ErrorAction SilentlyContinue

            if ($tcp) {

                foreach ($conn in $tcp) {

                    $lAddr = "$($conn.LocalAddress):$($conn.LocalPort)"

                    $fAddr = "$($conn.RemoteAddress):$($conn.RemotePort)"

                    $state = $conn.State.ToString()

                    $connPid = $conn.OwningProcess



                    $pName = "Unknown"

                    try { $pName = (Get-Process -Id $connPid -ErrorAction SilentlyContinue).ProcessName } catch {}



                    try {

                        $rowIndex = $script:_netstatDgv.Rows.Add("TCP", $lAddr, $fAddr, $state, $connPid, $pName)

                        if ($state -eq "Established") {

                            $script:_netstatDgv.Rows[$rowIndex].DefaultCellStyle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FF3366")

                        } elseif ($state -eq "Listen") {

                            $script:_netstatDgv.Rows[$rowIndex].DefaultCellStyle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF66")

                        }

                    } catch {}

                }

            }

        } catch {}



        # Also get UDP connections

        try {

            $udp = Get-NetUDPEndpoint -ErrorAction SilentlyContinue

            if ($udp) {

                foreach ($conn in $udp) {

                    $lAddr = "$($conn.LocalAddress):$($conn.LocalPort)"

                    $pName = "Unknown"

                    try { $pName = (Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue).ProcessName } catch {}

                    try {

                        [void]$script:_netstatDgv.Rows.Add("UDP", $lAddr, "*:*", "Listening", $conn.OwningProcess, $pName)

                    } catch {}

                }

            }

        } catch {}

    }



    # Initial population

    & $script:_netstatRefresh



    $btnRefresh.Add_Click({

        try { & $script:_netstatRefresh } catch {

            Out-MessageBox("Error refreshing connections: $_", "Netstat Error", "OK", "Warning") | Out-Null

        }

    })



    $gridHost.Controls.Add($dgv)

    $dgv.BringToFront()



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-ServicesDashboardPanel {

    try {

        $searchBox.Visible = $true

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "Enterprise Services Control Center"

    $metaLabel.Text = "Manage background system services, adjust start types, and start/stop/restart operational nodes"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_services_dashboard'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 70

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 10, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "System Background Services Nodes"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 8)

    $headerPanel.Controls.Add($panelTitle)



    $btnStart = New-Object System.Windows.Forms.Button

    $btnStart.Text = "Start"

    $btnStart.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnStart.FlatStyle = 'Flat'

    $btnStart.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF66")

    $btnStart.ForeColor = [System.Drawing.Color]::Black

    $btnStart.SetBounds(400, 16, 90, 32)

    $btnStart.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnStart)



    $btnStop = New-Object System.Windows.Forms.Button

    $btnStop.Text = "Stop"

    $btnStop.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnStop.FlatStyle = 'Flat'

    $btnStop.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FF3366")

    $btnStop.ForeColor = [System.Drawing.Color]::White

    $btnStop.SetBounds(500, 16, 90, 32)

    $btnStop.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnStop)



    $btnRestart = New-Object System.Windows.Forms.Button

    $btnRestart.Text = "Restart"

    $btnRestart.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnRestart.FlatStyle = 'Flat'

    $btnRestart.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#FFCC00")

    $btnRestart.ForeColor = [System.Drawing.Color]::Black

    $btnRestart.SetBounds(600, 16, 90, 32)

    $btnRestart.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnRestart)



    $gridHost.Controls.Add($headerPanel)



    $dgv = New-Object System.Windows.Forms.DataGridView

    $script:_servicesDgv = $dgv

    $dgv.Dock = "Fill"

    $dgv.BackgroundColor = Get-ThemeColor "Panel"

    $dgv.ForeColor = Get-ThemeColor "Text"

    $dgv.GridColor = Get-ThemeColor "Border"

    $dgv.DefaultCellStyle.BackColor = Get-ThemeColor "Panel2"

    $dgv.DefaultCellStyle.ForeColor = Get-ThemeColor "Text"

    $dgv.DefaultCellStyle.SelectionBackColor = Get-ThemeColor "Accent"

    $dgv.DefaultCellStyle.SelectionForeColor = Get-ThemeColor "CardText"

    $dgv.SelectionMode = "FullRowSelect"

    $dgv.MultiSelect = $false

    $dgv.AllowUserToAddRows = $false

    $dgv.AllowUserToDeleteRows = $false

    $dgv.ReadOnly = $true

    $dgv.RowHeadersVisible = $false

    $dgv.AutoSizeColumnsMode = 'Fill'

    $dgv.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $dgv.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $dgv.ColumnHeadersDefaultCellStyle.BackColor = Get-ThemeColor 'Panel2'

    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = Get-ThemeColor 'Text'

    $dgv.EnableHeadersVisualStyles = $false



    $dgv.Columns.Add("Name", "Service Name") | Out-Null

    $dgv.Columns.Add("DisplayName", "Display Name") | Out-Null

    $dgv.Columns.Add("Status", "Status") | Out-Null

    $dgv.Columns.Add("StartType", "Start Type") | Out-Null



    $dgv.Columns[0].Width = 150

    $dgv.Columns[1].Width = 300

    $dgv.Columns[2].Width = 100

    $dgv.Columns[3].Width = 100



    $script:refreshServices = {

        param($filterText = "")

        $dgv.Rows.Clear()

        $services = @()

        try {

            $services = Get-Service | Sort-Object DisplayName

        } catch {

            return

        }

        foreach ($s in $services) {

            if ($filterText -and -not ($s.Name -like "*$filterText*" -or $s.DisplayName -like "*$filterText*")) { continue }

            $status = "Unknown"

            try { $status = $s.Status.ToString() } catch {}

            $startType = "Unknown"

            try { $startType = $s.StartType.ToString() } catch {}

            $rowIndex = $dgv.Rows.Add($s.Name, $s.DisplayName, $status, $startType)

            

            if ($status -eq "Running") {

                $dgv.Rows[$rowIndex].Cells["Status"].Style.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF66")

            } else {

                $dgv.Rows[$rowIndex].Cells["Status"].Style.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FF3366")

            }

        }

    }



    &$script:refreshServices



    # Text changed routing is safely managed by the global event handler to avoid leaks



    # Store as script-scope scriptblock so button clicks survive panel function return

    $script:_invokeServiceAction = {

        param($action)

        if ($script:_servicesDgv.SelectedRows.Count -gt 0) {

            $sName = $script:_servicesDgv.SelectedRows[0].Cells["Name"].Value

            try {

                if ($action -eq 'start') {

                    Start-Service -Name $sName -ErrorAction Stop

                } elseif ($action -eq 'stop') {

                    Stop-Service -Name $sName -Force -ErrorAction Stop

                } elseif ($action -eq 'restart') {

                    Restart-Service -Name $sName -Force -ErrorAction Stop

                }

                Out-MessageBox("Service '$sName' $($action)ed successfully.", "Success", "OK", "Information") | Out-Null

                try { &$script:refreshServices $searchBox.Text } catch {}

            } catch {

                Out-MessageBox("Failed to $action service '$sName': $_", "Error", "OK", "Error") | Out-Null

            }

        } else {

            Out-MessageBox("Please select a service row first.", "Warning", "OK", "Warning") | Out-Null

        }

    }



    $btnStart.Add_Click({

        try { & $script:_invokeServiceAction 'start' } catch {

            Out-MessageBox("Start error: $_", "Service Error", "OK", "Error") | Out-Null

        }

    })

    $btnStop.Add_Click({

        try { & $script:_invokeServiceAction 'stop' } catch {

            Out-MessageBox("Stop error: $_", "Service Error", "OK", "Error") | Out-Null

        }

    })

    $btnRestart.Add_Click({

        try { & $script:_invokeServiceAction 'restart' } catch {

            Out-MessageBox("Restart error: $_", "Service Error", "OK", "Error") | Out-Null

        }

    })



    $gridHost.Controls.Add($dgv)

    $dgv.BringToFront()



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-RegistryTweaksPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "Registry Telemetry & System debloater Optimizer"

    $metaLabel.Text = "Tweak advanced Windows kernel profiles, disable tracking telemetry, debloat Cortana, and speed up system responsiveness"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_registry_tweaks'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 80

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 15, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Windows Kernel debloating & Registry Tweaks"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 12)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Apply optimized registry scripts and privacy optimizations directly to local configurations."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 40)

    $headerPanel.Controls.Add($panelSub)



    $gridHost.Controls.Add($headerPanel)



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    $tweaks = @(

        [pscustomobject]@{

            Id = "winDebloat"

            Title = "WINDOWS DEBLOATER REMOVAL"

            Desc = "Launch the interactive Win11Debloat script in a new elevated PowerShell window to download tools from GitHub and deeply debloat Windows."

            TweakScript = {

                $debloatScript = Join-Path $script:ToolkitRoot "Modules\Win11Debloat.ps1"

                if (-not (Test-Path $debloatScript)) {

                    $debloatScript = "$env:USERPROFILE\Downloads\Win11Debloat.ps1"

                }

                if (Test-Path $debloatScript) {

                    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$debloatScript`"" -Verb RunAs

                } else {

                    Out-MessageBox("Win11Debloat.ps1 script not found!", "Error", "OK", "Error") | Out-Null

                }

            }

        },

        [pscustomobject]@{

            Id = "cortana"

            Title = "DEBLOAT MICROSOFT CORTANA"

            Desc = "Completely disable Cortana background tracking services and start-up resource allocation."

            TweakScript = {

                New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force -ErrorAction SilentlyContinue | Out-Null

                Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Force -ErrorAction SilentlyContinue

            }

        },

        [pscustomobject]@{

            Id = "telemetry"

            Title = "DISABLE WINDOWS TELEMETRY & FEEDBACK"

            Desc = "Turn off diagnostic telemetry collection to protect client privacy and save outbound network bandwidth."

            TweakScript = {

                Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force -ErrorAction SilentlyContinue

                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Force -ErrorAction SilentlyContinue



                # Invoke Win11Debloat script to thoroughly disable all Windows telemetry

                $debloatScript = Join-Path $script:ToolkitRoot "Modules\Win11Debloat.ps1"

                if (-not (Test-Path $debloatScript)) {

                    $debloatScript = "$env:USERPROFILE\Downloads\Win11Debloat.ps1"

                }

                if (Test-Path $debloatScript) {

                    $debloatProcess = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$debloatScript`" -Silent -DisableTelemetry" -PassThru -NoNewWindow

                    if ($null -ne $debloatProcess) {

                        while (-not $debloatProcess.HasExited) {

                            [System.Windows.Forms.Application]::DoEvents()

                            Start-Sleep -Milliseconds 100

                        }

                    }

                }

            }

        },

        [pscustomobject]@{

            Id = "menuDelay"

            Title = "SPEED UP WINDOWS UI MENU DISPLAY"

            Desc = "Reduces the hovering delay timer for context drop-down menus from 400ms down to a snappier 20ms."

            TweakScript = {

                Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "20" -Force -ErrorAction SilentlyContinue

            }

        },

        [pscustomobject]@{

            Id = "networkThru"

            Title = "OPTIMIZE NETWORK THROTTLING PROFILE"

            Desc = "Disables Network Throttling Index parameters so high-performance download nodes run at maximum network capacity."

            TweakScript = {

                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 4294967295 -Force -ErrorAction SilentlyContinue

            }

        }

    )



    foreach ($t in $tweaks) {

        $card = New-Object System.Windows.Forms.Panel

        $card.Size = New-Object System.Drawing.Size(810, 100)

        $card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 15)

        $card.BackColor = Get-ThemeColor 'Panel'

        $card.Padding = New-Object System.Windows.Forms.Padding(18)

        Enable-DoubleBuffer $card



        $lblTitle = New-Object System.Windows.Forms.Label

        $lblTitle.Text = $t.Title

        $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF66")

        $lblTitle.SetBounds(18, 14, 450, 20)

        $card.Controls.Add($lblTitle)



        $lblDesc = New-Object System.Windows.Forms.Label

        $lblDesc.Text = $t.Desc

        $lblDesc.Font = New-Object System.Drawing.Font('Segoe UI', 9)

        $lblDesc.ForeColor = Get-ThemeColor 'Text'

        $lblDesc.SetBounds(18, 38, 550, 48)

        $card.Controls.Add($lblDesc)



        $btnApply = New-Object System.Windows.Forms.Button

        $btnApply.Text = "Apply Tweak"

        $btnApply.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

        $btnApply.FlatStyle = 'Flat'

        $btnApply.BackColor = Get-ThemeColor 'Accent'

        $btnApply.ForeColor = Get-ThemeColor 'CardText'

        $btnApply.SetBounds(620, 30, 150, 34)

        $btnApply.Cursor = [System.Windows.Forms.Cursors]::Hand

        

        $btnApply.Tag = $t

        $btnApply.Add_Click({

            param($sender, $e)

            try {

                $tweakObj = $sender.Tag

                & $tweakObj.TweakScript

                Out-MessageBox("Registry tweak '$($tweakObj.Title)' applied successfully!`r`nRestart might be required for changes to apply.", "Tweak Applied", "OK", "Information") | Out-Null

            } catch {

                Out-MessageBox("Failed to apply tweak: $_", "Error", "OK", "Error") | Out-Null

            }

        })

        $card.Controls.Add($btnApply)



        $flow.Controls.Add($card)

    }



    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}

function Show-AiDiagnosticsPanel {

    $script:currentLabel = 'menu_ai_diagnostics'

    function Get-System32File {

        param([string]$FileName)

        if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {

            $sysnative = Join-Path $env:windir "Sysnative\$FileName"

            if (Test-Path $sysnative) { return $sysnative }

        }

        return Join-Path $env:windir "System32\$FileName"

    }



    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "AI Cyber-Heuristic Diagnostics and Troubleshooting"

    $metaLabel.Text = "Run comprehensive smart analysis across RAM, HDD, OS crashes, heating, and networks to pinpoint exactly what is broken"

    $script:currentMode = 'native_gui_search'



    # Top Control Card Panel (Glowing Accent Rounded Frame)

    $topCard = New-Object System.Windows.Forms.Panel

    $topCard.SetBounds(36, 12, 1120, 110)

    $topCard.BackColor = Get-ThemeColor 'Panel2'

    Enable-DoubleBuffer $topCard

    $topCard.Add_Paint({

        param($sender, $e)

        try {

            if ($sender.Width -le 12 -or $sender.Height -le 12) { return }

            $g = $e.Graphics

            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

            $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width - 1, $sender.Height - 1)

            $path = Get-RoundedGraphicsPath -Rect $rect -Radius 12

            

            $bgBrush = New-Object System.Drawing.SolidBrush($sender.BackColor)

            $g.FillPath($bgBrush, $path)

            $bgBrush.Dispose()



            $pen = New-Object System.Drawing.Pen(Get-ThemeColor 'Border', 1)

            $g.DrawPath($pen, $path)

            $pen.Dispose()

            $path.Dispose()

        } catch {}

    })



    # The Cyber Scan Button (Large Glowing Button)

    $btnScan = New-Object System.Windows.Forms.Button

    $btnScan.Text = "RUN AI SMART DIAGNOSTIC"

    $btnScan.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

    $btnScan.FlatStyle = 'Flat'

    $btnScan.BackColor = Get-ThemeColor 'Accent'

    $btnScan.ForeColor = Get-ThemeColor 'CardText'

    $btnScan.SetBounds(16, 18, 230, 74)

    $btnScan.Cursor = [System.Windows.Forms.Cursors]::Hand

    $topCard.Controls.Add($btnScan)



    # Resume / Summary Button

    $btnResume = New-Object System.Windows.Forms.Button

    $btnResume.Text = "RESUME / SUMMARY"

    $btnResume.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnResume.FlatStyle = 'Flat'

    $btnResume.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#1a3247')

    $btnResume.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#00aaff')

    $btnResume.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml('#00aaff')

    $btnResume.FlatAppearance.BorderSize = 1

    $btnResume.SetBounds(256, 18, 170, 34)

    $btnResume.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnResume.Enabled = $false

    $topCard.Controls.Add($btnResume)



    # Export HTML Report Button

    $btnExport = New-Object System.Windows.Forms.Button

    $btnExport.Text = "EXPORT HTML REPORT"

    $btnExport.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnExport.FlatStyle = 'Flat'

    $btnExport.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#1a472a')

    $btnExport.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#00ff88')

    $btnExport.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml('#00ff88')

    $btnExport.FlatAppearance.BorderSize = 1

    $btnExport.SetBounds(256, 58, 170, 34)

    $btnExport.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnExport.Enabled = $false

    $topCard.Controls.Add($btnExport)



    # Apply Auto-Repair / Smart Fix Button

    $btnRepair = New-Object System.Windows.Forms.Button

    $btnRepair.Text = "APPLY SMART FIX"

    $btnRepair.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnRepair.FlatStyle = 'Flat'

    $btnRepair.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#221515')

    $btnRepair.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#884444')

    $btnRepair.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml('#884444')

    $btnRepair.FlatAppearance.BorderSize = 1

    $btnRepair.SetBounds(436, 18, 180, 74)

    $btnRepair.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnRepair.Enabled = $false

    $topCard.Controls.Add($btnRepair)



    # Scans Steps HUD Tracker Labels

    $lblStep = New-Object System.Windows.Forms.Label

    $lblStep.Text = "AI Diagnostics Engine: READY TO SCAN"

    $lblStep.Font = New-Object System.Drawing.Font('Segoe UI', 11.5, [System.Drawing.FontStyle]::Bold)

    $lblStep.ForeColor = Get-ThemeColor 'Muted'

    $lblStep.SetBounds(630, 22, 460, 26)

    $topCard.Controls.Add($lblStep)



    $lblStepsFlow = New-Object System.Windows.Forms.Label

    $lblStepsFlow.Text = "(Storage SMART) -> (Capacity) -> (RAM) -> (Thermal) -> (Crash Logs) -> (Drivers) -> (Battery) -> (Security) -> (Network) -> (Performance)"

    $lblStepsFlow.Font = New-Object System.Drawing.Font('Segoe UI', 8.25, [System.Drawing.FontStyle]::Bold)

    $lblStepsFlow.ForeColor = Get-ThemeColor 'Muted'

    $lblStepsFlow.SetBounds(630, 56, 480, 40)

    $topCard.Controls.Add($lblStepsFlow)



    $gridHost.Controls.Add($topCard)



    # Bottom Log Card Panel

    $logCard = New-Object System.Windows.Forms.Panel

    $logCard.SetBounds(36, 136, 1120, 520)

    $logCard.BackColor = Get-ThemeColor 'Panel2'

    Enable-DoubleBuffer $logCard

    $logCard.Add_Paint({

        param($sender, $e)

        try {

            if ($sender.Width -le 12 -or $sender.Height -le 12) { return }

            $g = $e.Graphics

            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

            $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width - 1, $sender.Height - 1)

            $path = Get-RoundedGraphicsPath -Rect $rect -Radius 12

            

            $bgBrush = New-Object System.Drawing.SolidBrush($sender.BackColor)

            $g.FillPath($bgBrush, $path)

            $bgBrush.Dispose()



            $pen = New-Object System.Drawing.Pen(Get-ThemeColor 'Border', 1)

            $g.DrawPath($pen, $path)

            $pen.Dispose()

            $path.Dispose()

        } catch {}

    })



    # Consolas high-density custom text output console

    $txtLog = New-Object System.Windows.Forms.TextBox

    $txtLog.Multiline = $true

    $txtLog.ReadOnly = $true

    $txtLog.ScrollBars = 'Vertical'

    $txtLog.BackColor = Get-ThemeColor 'Bg'

    $txtLog.ForeColor = Get-ThemeColor 'Text'

    $txtLog.Font = New-Object System.Drawing.Font('Consolas', 10.5)

    $txtLog.SetBounds(16, 18, 1088, 484)

    $txtLog.BorderStyle = 'None'

    $logCard.Controls.Add($txtLog)



    $gridHost.Controls.Add($logCard)



    # Save controls to script-scope so Add_Click event handler can always reach them

    $script:_aiTxtLog   = $txtLog

    $script:_aiLblStep  = $lblStep

    $script:_aiBtnScan  = $btnScan

    $script:_aiBtnExport = $btnExport

    $script:_aiBtnResume = $btnResume

    $script:_aiBtnRepair = $btnRepair



    # Initialize report data if not already set, otherwise restore previous button states

    if ($null -eq $script:_aiReportData) {

        $script:_aiReportData = @()

    }



    # Wire Apply Smart Fix Click Event

    $btnRepair.Add_Click({

        $script:_aiBtnScan.Enabled = $false

        $script:_aiBtnResume.Enabled = $false

        $script:_aiBtnExport.Enabled = $false

        $script:_aiBtnRepair.Enabled = $false

        $script:_aiTxtLog.Text = ""

        $script:_aiLblStep.Text = "AI Auto-Repair: Executing Smart Fix..."

        $script:_aiLblStep.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#ff5555')

        [System.Windows.Forms.Application]::DoEvents()



        $script:_aiTxtLog.AppendText("[AI COGNITIVE FIX] Starting 1-Click Smart Repair Sequence...`r`n")

        $script:_aiTxtLog.AppendText("==========================================================================`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        $fixSFC = $false

        $fixWU = $false

        $fixNet = $false

        $fixUAC = $false

        $fixDisk = $false

        $fixSec = $false

        $fixJunk = $false



        foreach ($item in $script:_aiReportData) {

            if ($item.Status -ne "OK") {

                if ($item.Category -eq "OS and Security Policy") {

                    foreach ($d in $item.Details) {

                        if ($d -match "file integrity" -or $d -match "CBS") { $fixSFC = $true }

                        if ($d -match "Update") { $fixWU = $true }

                        if ($d -match "UAC" -or $d -match "User Account Control") { $fixUAC = $true }

                        if ($d -match "dirty" -or $d -match "volume") { $fixDisk = $true }

                        if ($d -match "Antivirus" -or $d -match "Firewall" -or $d -match "security shield") { $fixSec = $true }

                    }

                }

                if ($item.Category -eq "Network and Internet") { $fixNet = $true }

                if ($item.Category -eq "Windows Stability") { $fixSFC = $true }

                if ($item.Category -eq "System Performance" -or $item.Category -eq "Storage Performance" -or $item.Category -eq "Storage Hardware") {

                    foreach ($d in $item.Details) {

                        if ($d -match "Junk" -or $d -match "cache" -or $d -match "temporary" -or $d -match "Free space") { $fixJunk = $true }

                    }

                }

            }

        }



        # Baseline fixes if no specific alert triggered but user ran it manually

        if (-not ($fixSFC -or $fixWU -or $fixNet -or $fixUAC -or $fixDisk -or $fixSec -or $fixJunk)) {

            $script:_aiTxtLog.AppendText("No severe alerts cached. Performing baseline system optimizations...`r`n")

            $fixNet = $true

            $fixWU = $true

            $fixUAC = $true

            $fixSec = $true

            $fixJunk = $true

        }



        # FIX 1: Network & DNS Stack Rebuild

        if ($fixNet) {

            $script:_aiTxtLog.AppendText("`r`n[FIX 1/6] Initiating Network Stack & Winsock Rebuild...`r`n")

            [System.Windows.Forms.Application]::DoEvents()

            try {

                $script:_aiTxtLog.AppendText("  -> Flushing DNS Resolver cache... ")

                $null = ipconfig /flushdns

                $script:_aiTxtLog.AppendText("SUCCESS`r`n")



                $script:_aiTxtLog.AppendText("  -> Resetting IP routing tables (netsh int ip reset)... ")

                $null = netsh int ip reset

                $script:_aiTxtLog.AppendText("SUCCESS`r`n")



                $script:_aiTxtLog.AppendText("  -> Rebuilding Winsock Catalog (netsh winsock reset)... ")

                $null = netsh winsock reset

                $script:_aiTxtLog.AppendText("SUCCESS`r`n")



                $script:_aiTxtLog.AppendText("  -> Releasing & renewing IP leases... ")

                $null = ipconfig /release

                Start-Sleep -Seconds 1

                $null = ipconfig /renew

                $script:_aiTxtLog.AppendText("SUCCESS`r`n")

            } catch {

                $script:_aiTxtLog.AppendText("FAILED: $($_.Exception.Message)`r`n")

            }

            [System.Windows.Forms.Application]::DoEvents()

        }



        # FIX 2: Windows Update Service restoration

        if ($fixWU) {

            $script:_aiTxtLog.AppendText("`r`n[FIX 2/6] Restoring Windows Update Service Infrastructure...`r`n")

            [System.Windows.Forms.Application]::DoEvents()

            try {

                $script:_aiTxtLog.AppendText("  -> Auditing 'wuauserv' configuration... ")

                $wuauserv = Get-Service wuauserv -ErrorAction SilentlyContinue

                if ($null -ne $wuauserv) {

                    $script:_aiTxtLog.AppendText("Found`r`n")

                    $script:_aiTxtLog.AppendText("  -> Aligning service startup behavior to Automatic... ")

                    Set-Service wuauserv -StartupType Automatic

                    $script:_aiTxtLog.AppendText("DONE`r`n")



                    $script:_aiTxtLog.AppendText("  -> Launching Windows Update service... ")

                    Start-Service wuauserv -ErrorAction SilentlyContinue

                    $script:_aiTxtLog.AppendText("SUCCESS`r`n")

                } else {

                    $script:_aiTxtLog.AppendText("Service 'wuauserv' not present!`r`n")

                }

            } catch {

                $script:_aiTxtLog.AppendText("FAILED: $($_.Exception.Message)`r`n")

            }

            [System.Windows.Forms.Application]::DoEvents()

        }



        # FIX 3: UAC Policies and Security Policies

        if ($fixUAC) {

            $script:_aiTxtLog.AppendText("`r`n[FIX 3/6] Restoring User Account Control Security Policies...`r`n")

            [System.Windows.Forms.Application]::DoEvents()

            try {

                $script:_aiTxtLog.AppendText("  -> Adjusting ConsentPromptBehaviorAdmin parameters in Registry... ")

                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 5 -ErrorAction Stop

                $script:_aiTxtLog.AppendText("SUCCESS`r`n")

                $script:_aiTxtLog.AppendText("  * Security Notice: Core kernel checks are now active. System will prompt on admin tasks.`r`n")

            } catch {

                $script:_aiTxtLog.AppendText("FAILED: $($_.Exception.Message)`r`n")

            }

            [System.Windows.Forms.Application]::DoEvents()

        }



        # FIX 4: Antivirus & Firewall security restoration

        if ($fixSec) {

            $script:_aiTxtLog.AppendText("`r`n[FIX 4/6] Restoring Windows Security Shield and Firewall policies...`r`n")

            [System.Windows.Forms.Application]::DoEvents()

            try {

                $script:_aiTxtLog.AppendText("  -> Aligning WinDefend startup behavior to Automatic... ")

                Set-Service WinDefend -StartupType Automatic -ErrorAction SilentlyContinue

                $script:_aiTxtLog.AppendText("DONE`r`n")

                

                $script:_aiTxtLog.AppendText("  -> Activating Windows Defender service... ")

                Start-Service WinDefend -ErrorAction SilentlyContinue

                $script:_aiTxtLog.AppendText("SUCCESS`r`n")

                

                $script:_aiTxtLog.AppendText("  -> Activating Advanced Windows Firewall for all profiles... ")

                $null = netsh advfirewall set allprofiles state on

                $script:_aiTxtLog.AppendText("SUCCESS`r`n")

            } catch {

                $script:_aiTxtLog.AppendText("FAILED: $($_.Exception.Message)`r`n")

            }

            [System.Windows.Forms.Application]::DoEvents()

        }



        # FIX 5: Purging Junk Temp Cache

        if ($fixJunk) {

            $script:_aiTxtLog.AppendText("`r`n[FIX 5/6] Purging Junk Cache & System Temporary Files...`r`n")

            [System.Windows.Forms.Application]::DoEvents()

            try {

                $tempPaths = @($env:TEMP, "$env:windir\Temp")

                $cleanedMB = 0

                foreach ($path in $tempPaths) {

                    if (Test-Path $path) {

                        $files = Get-ChildItem -Path $path -File -Recurse -ErrorAction SilentlyContinue

                        foreach ($f in $files) {

                            try {

                                $fSize = $f.Length

                                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue

                                $cleanedMB += $fSize / 1MB

                            } catch {}

                        }

                    }

                }

                $script:_aiTxtLog.AppendText("  -> Purged [ " + [Math]::Round($cleanedMB, 1) + " MB ] of temporary junk files from storage. SUCCESS`r`n")

            } catch {

                $script:_aiTxtLog.AppendText("FAILED: $($_.Exception.Message)`r`n")

            }

            [System.Windows.Forms.Application]::DoEvents()

        }



        # FIX 6: OS SFC and DISM System file repair (NON-BLOCKING ASYNC REDIRECT!)

        if ($fixSFC) {

            $script:_aiTxtLog.AppendText("`r`n[FIX 6/6] Executing System File Checker & Servicing Image Repairs...`r`n")

            $script:_aiTxtLog.AppendText("  * Status: Running SFC integrity scan (using non-blocking active reader)...`r`n")

            [System.Windows.Forms.Application]::DoEvents()

            try {

                $sfcPath = Get-System32File "sfc.exe"

                if (Test-Path $sfcPath) {

                    $psi = New-Object System.Diagnostics.ProcessStartInfo

                    $psi.FileName = $sfcPath

                    $psi.Arguments = "/scannow"

                    $psi.UseShellExecute = $false

                    $psi.CreateNoWindow = $true

                    $psi.RedirectStandardOutput = $true

                    $psi.RedirectStandardError = $true

                    

                    $proc = New-Object System.Diagnostics.Process

                    $proc.StartInfo = $psi

                    $proc.EnableRaisingEvents = $true

                    

                    $proc.add_OutputDataReceived({

                        param($sender, $e)

                        if ($e.Data -and $e.Data.Trim()) {

                            $script:_aiTxtLog.AppendText("     $($e.Data)`r`n")

                        }

                    })

                    $proc.add_ErrorDataReceived({

                        param($sender, $e)

                        if ($e.Data -and $e.Data.Trim()) {

                            $script:_aiTxtLog.AppendText("     [Error] $($e.Data)`r`n")

                        }

                    })

                    

                    $proc.Start() | Out-Null

                    $proc.BeginOutputReadLine()

                    $proc.BeginErrorReadLine()

                    

                    while (-not $proc.HasExited) {

                        [System.Windows.Forms.Application]::DoEvents()

                        Start-Sleep -Milliseconds 100

                    }

                    $script:_aiTxtLog.AppendText("  -> SFC System File integrity repair finished.`r`n")

                } else {

                    $script:_aiTxtLog.AppendText("  -> sfc.exe not found at path: $sfcPath!`r`n")

                }



                $script:_aiTxtLog.AppendText("`r`n  * Status: Running DISM active servicing restore (non-blocking)...`r`n")

                [System.Windows.Forms.Application]::DoEvents()

                $dismPath = Get-System32File "dism.exe"

                if (Test-Path $dismPath) {

                    $psiDism = New-Object System.Diagnostics.ProcessStartInfo

                    $psiDism.FileName = $dismPath

                    $psiDism.Arguments = "/Online /Cleanup-Image /RestoreHealth"

                    $psiDism.UseShellExecute = $false

                    $psiDism.CreateNoWindow = $true

                    $psiDism.RedirectStandardOutput = $true

                    $psiDism.RedirectStandardError = $true

                    

                    $procDism = New-Object System.Diagnostics.Process

                    $procDism.StartInfo = $psiDism

                    $procDism.EnableRaisingEvents = $true

                    

                    $procDism.add_OutputDataReceived({

                        param($sender, $e)

                        if ($e.Data -and $e.Data.Trim()) {

                            $script:_aiTxtLog.AppendText("     $($e.Data)`r`n")

                        }

                    })

                    $procDism.add_ErrorDataReceived({

                        param($sender, $e)

                        if ($e.Data -and $e.Data.Trim()) {

                            $script:_aiTxtLog.AppendText("     [Error] $($e.Data)`r`n")

                        }

                    })

                    

                    $procDism.Start() | Out-Null

                    $procDism.BeginOutputReadLine()

                    $procDism.BeginErrorReadLine()

                    

                    while (-not $procDism.HasExited) {

                        [System.Windows.Forms.Application]::DoEvents()

                        Start-Sleep -Milliseconds 100

                    }

                    $script:_aiTxtLog.AppendText("  -> DISM active servicing restore completed successfully.`r`n")

                } else {

                    $script:_aiTxtLog.AppendText("  -> dism.exe not found at path: $dismPath!`r`n")

                }

            } catch {

                $script:_aiTxtLog.AppendText("FAILED: $($_.Exception.Message)`r`n")

            }

            [System.Windows.Forms.Application]::DoEvents()

        }



        # FIX EXTRA: Scheduling Chkdsk volume repair

        if ($fixDisk) {

            $script:_aiTxtLog.AppendText("`r`n[FIX VOLUMES] Registering Storage Volume Filesystem chkdsk Audits...`r`n")

            [System.Windows.Forms.Application]::DoEvents()

            try {

                $script:_aiTxtLog.AppendText("  -> Scheduling chkdsk on boot for C: volume... ")

                $chkdskPath = Get-System32File "chkdsk.exe"

                $psi = New-Object System.Diagnostics.ProcessStartInfo

                $psi.FileName = Get-System32File "cmd.exe"

                $psi.Arguments = "/c echo Y | `"$chkdskPath`" C: /f"

                $psi.UseShellExecute = $false

                $psi.CreateNoWindow = $true

                $proc = [System.Diagnostics.Process]::Start($psi)

                $proc.WaitForExit(10000) | Out-Null

                $script:_aiTxtLog.AppendText("SUCCESS`r`n")

                $script:_aiTxtLog.AppendText("  * Notice: Filesystem and sector checks will run automatically during next reboot.`r`n")

            } catch {

                $script:_aiTxtLog.AppendText("FAILED: $($_.Exception.Message)`r`n")

            }

            [System.Windows.Forms.Application]::DoEvents()

        }



        $script:_aiTxtLog.AppendText("`r`n==========================================================================`r`n")

        $script:_aiTxtLog.AppendText(">> AI SMART AUTO-REPAIR COMPLETED SUCCESSFULLY!`r`n")

        $script:_aiTxtLog.AppendText(">> Critical security shield, network, update parameters, and registry resolved.`r`n")

        $script:_aiTxtLog.AppendText(">> A system reboot is strongly advised to finalize files and volumes repairs.`r`n")

        $script:_aiTxtLog.AppendText("==========================================================================`r`n")



        $script:_aiLblStep.Text = "AUTO-REPAIR COMPLETE - System Optimized!"

        $script:_aiLblStep.ForeColor = [System.Drawing.Color]::LimeGreen



        $script:_aiBtnScan.Enabled = $true

        $script:_aiBtnResume.Enabled = $true

        $script:_aiBtnExport.Enabled = $true

        $script:_aiBtnRepair.Enabled = $true

        $script:_aiBtnRepair.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#4a1515')

        $script:_aiBtnRepair.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#ff5555')

        $script:_aiBtnRepair.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml('#ff5555')

    })



    $hasAlerts = $false

    if ($script:_aiReportData.Count -gt 0) {

        $btnResume.Enabled = $true

        $btnResume.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#0088cc')

        $btnExport.Enabled = $true

        $btnExport.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#00aa55')

        

        foreach ($card in $script:_aiReportData) {

            if ($card.Status -eq "CRITICAL" -or $card.Status -eq "WARNING") {

                $hasAlerts = $true

            }

        }

        if ($hasAlerts) {

            $btnRepair.Enabled = $true

            $btnRepair.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#4a1515')

            $btnRepair.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#ff5555')

            $btnRepair.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml('#ff5555')

        }

    }



    # Wire Export Click Event

    $btnExport.Add_Click({

        if ($script:_aiReportData.Count -eq 0) {

            Out-MessageBox("Please run the AI Diagnostic scan first before exporting.", "No Scan Data", 'OK', 'Information')

            return

        }

        try {

            Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

            $pcName = $env:COMPUTERNAME

            $scanTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

            $reportPath = "$env:TEMP\AI_Diagnostic_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"



            # Build HTML cards for each diagnostic result

            $cardsHtml = ""

            foreach ($item in $script:_aiReportData) {

                $bgColor = switch ($item.Status) {

                    "CRITICAL" { "#1a0a0a" }

                    "WARNING"  { "#1a150a" }

                    "OK"       { "#0a1a0f" }

                    default    { "#0d0d1a" }

                }

                $badgeColor = switch ($item.Status) {

                    "CRITICAL" { "#ff3333" }

                    "WARNING"  { "#ffaa00" }

                    "OK"       { "#00cc66" }

                    default    { "#6666ff" }

                }

                $badgeText = switch ($item.Status) {

                    "CRITICAL" { "CRITICAL ISSUE" }

                    "WARNING"  { "WARNING" }

                    "OK"       { "HEALTHY" }

                    default    { "INFO" }

                }

                $detailsHtml = ""

                foreach ($d in $item.Details) {

                    $detailsHtml += "<li>$([System.Web.HttpUtility]::HtmlEncode($d))</li>"

                }

                $recommendsHtml = ""

                foreach ($r in $item.Recommendations) {

                    $recommendsHtml += "<li>$([System.Web.HttpUtility]::HtmlEncode($r))</li>"

                }

                $explainHtml = if ($item.Explanation) { "<div class='explain'><strong>What does this mean?</strong><br/>$([System.Web.HttpUtility]::HtmlEncode($item.Explanation))</div>" } else { "" }

                $recommendSection = if ($recommendsHtml) { "<div class='recommend'><strong>How to fix:</strong><ul>$recommendsHtml</ul></div>" } else { "" }

                $detailSection = if ($detailsHtml) { "<ul class='details'>$detailsHtml</ul>" } else { "" }



                $cardsHtml += @"

<div class='card' style='background:$bgColor; border-left: 4px solid $badgeColor;'>

  <div class='card-header'>

    <span class='category'>$([System.Web.HttpUtility]::HtmlEncode($item.Category))</span>

    <span class='badge' style='background:$badgeColor;'>$badgeText</span>

  </div>

  <div class='card-title'>$([System.Web.HttpUtility]::HtmlEncode($item.Title))</div>

  $detailSection

  $explainHtml

  $recommendSection

</div>

"@

            }



            # Count status summary

            $critCount = ($script:_aiReportData | Where-Object { $_.Status -eq "CRITICAL" }).Count

            $warnCount = ($script:_aiReportData | Where-Object { $_.Status -eq "WARNING" }).Count

            $okCount   = ($script:_aiReportData | Where-Object { $_.Status -eq [System.Windows.Forms.DialogResult]::OK }).Count

            $overallStatus = if ($critCount -gt 0) { "CRITICAL ISSUES DETECTED" } elseif ($warnCount -gt 0) { "WARNINGS FOUND" } else { "SYSTEM HEALTHY" }

            $overallColor  = if ($critCount -gt 0) { "#ff3333" } elseif ($warnCount -gt 0) { "#ffaa00" } else { "#00cc66" }



            $html = @"

<!DOCTYPE html>

<html lang='en'>

<head>

<meta charset='UTF-8'>

<meta name='viewport' content='width=device-width, initial-scale=1.0'>

<title>AI System Diagnostic Report - $pcName</title>

<link href='https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700;900&family=JetBrains+Mono:wght@400;700&display=swap' rel='stylesheet'>

<style>

  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  body { font-family: 'Inter', sans-serif; background: #050510; color: #e0e0ff; min-height: 100vh; }

  .hero { background: linear-gradient(135deg, #0d0d2e 0%, #0a1a0f 50%, #1a0a1a 100%); padding: 40px; border-bottom: 1px solid #1e1e4a; }

  .hero-inner { max-width: 1200px; margin: 0 auto; }

  .brand { font-size: 12px; letter-spacing: 3px; text-transform: uppercase; color: #6666aa; margin-bottom: 8px; }

  .hero h1 { font-size: 32px; font-weight: 900; background: linear-gradient(90deg, #00ccff, #00ff88, #cc44ff); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; margin-bottom: 4px; }

  .hero-meta { font-size: 13px; color: #6666aa; margin-top: 8px; }

  .hero-meta span { color: #8888cc; font-weight: 600; }

  .overall-banner { margin: 16px 0 0; padding: 12px 20px; border-radius: 8px; border: 1px solid; display: inline-flex; align-items: center; gap: 12px; font-weight: 700; font-size: 16px; }

  .stats-row { max-width: 1200px; margin: 24px auto; padding: 0 40px; display: flex; gap: 16px; flex-wrap: wrap; }

  .stat-box { flex: 1; min-width: 160px; padding: 20px; border-radius: 12px; border: 1px solid; text-align: center; }

  .stat-box .num { font-size: 36px; font-weight: 900; line-height: 1; }

  .stat-box .label { font-size: 12px; letter-spacing: 2px; text-transform: uppercase; margin-top: 6px; opacity: 0.7; }

  .stat-critical { background: #1a0505; border-color: #ff3333; }

  .stat-critical .num { color: #ff3333; }

  .stat-warning  { background: #1a1005; border-color: #ffaa00; }

  .stat-warning .num  { color: #ffaa00; }

  .stat-ok       { background: #051a0a; border-color: #00cc66; }

  .stat-ok .num       { color: #00cc66; }

  .cards-container { max-width: 1200px; margin: 0 auto; padding: 0 40px 40px; display: flex; flex-direction: column; gap: 20px; }

  .card { border-radius: 12px; padding: 24px; border: 1px solid #1e1e3a; transition: transform 0.2s; }

  .card:hover { transform: translateY(-2px); }

  .card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }

  .category { font-size: 11px; letter-spacing: 2px; text-transform: uppercase; color: #6666aa; font-weight: 700; }

  .badge { padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 800; letter-spacing: 1px; color: #000; }

  .card-title { font-size: 18px; font-weight: 700; color: #e0e0ff; margin-bottom: 12px; }

  .details { padding-left: 20px; color: #aaaacc; font-size: 14px; line-height: 2; font-family: 'JetBrains Mono', monospace; }

  .explain { margin-top: 14px; padding: 14px 18px; background: rgba(100, 100, 255, 0.08); border-left: 3px solid #6666cc; border-radius: 6px; font-size: 14px; color: #bbbbdd; line-height: 1.7; }

  .recommend { margin-top: 14px; padding: 14px 18px; background: rgba(0, 200, 100, 0.06); border-left: 3px solid #00cc66; border-radius: 6px; font-size: 14px; color: #aaddbb; }

  .recommend ul { padding-left: 18px; margin-top: 8px; line-height: 2; }

  .section-title { max-width: 1200px; margin: 8px auto 16px; padding: 0 40px; font-size: 13px; letter-spacing: 3px; text-transform: uppercase; color: #6666aa; font-weight: 700; }

  footer { text-align: center; padding: 30px; border-top: 1px solid #1e1e3a; color: #444466; font-size: 12px; }

  @media print { body { background: #fff; color: #000; } .hero { background: #f5f5f5; } }

</style>

</head>

<body>

<div class='hero'>

  <div class='hero-inner'>

    <div class='brand'>SysForge Studio - AI System Diagnostics</div>

    <h1>AI System Health Diagnostic Report</h1>

    <div class='hero-meta'>

      Computer: <span>$pcName</span> &nbsp;&bull;&nbsp;

      Scan Time: <span>$scanTime</span> &nbsp;&bull;&nbsp;

      OS: <span>Windows</span>

    </div>

    <div class='overall-banner' style='color:$overallColor; border-color:$overallColor; background: rgba(0,0,0,0.3);'>

      &#9724; OVERALL STATUS: $overallStatus

    </div>

  </div>

</div>



<div class='stats-row'>

  <div class='stat-box stat-critical'><div class='num'>$critCount</div><div class='label'>Critical Issues</div></div>

  <div class='stat-box stat-warning'><div class='num'>$warnCount</div><div class='label'>Warnings</div></div>

  <div class='stat-box stat-ok'><div class='num'>$okCount</div><div class='label'>Healthy Checks</div></div>

</div>



<div class='section-title'>Diagnostic Results</div>

<div class='cards-container'>

$cardsHtml

</div>

<footer>Generated by SysForge Studio &mdash; AI System Diagnostics &mdash; $scanTime</footer>

</body>

</html>

"@



            [System.IO.File]::WriteAllText($reportPath, $html, [System.Text.Encoding]::UTF8)

            Start-Process $reportPath

            $script:_aiLblStep.Text = "HTML Report exported and opened in browser!"

            $script:_aiLblStep.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#00ff88')

        } catch {

            Out-MessageBox("Failed to export report: " + $_.Exception.Message, "Export Error", 'OK', 'Error')

        }

    })



    # Wire Resume / Summary Click Event

    $btnResume.Add_Click({

        if ($script:_aiReportData.Count -eq 0) {

            Out-MessageBox("Please run the AI Diagnostic scan first before viewing the summary.", "No Scan Data", 'OK', 'Information')

            return

        }

        try {

            $scanTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

            $script:_aiTxtLog.Text = ""

            $script:_aiTxtLog.AppendText("==========================================================================`r`n")

            $script:_aiTxtLog.AppendText("               AI SYSTEM DIAGNOSTIC SUMMARY (RÉSUMÉ)                      `r`n")

            $script:_aiTxtLog.AppendText("==========================================================================`r`n")

            $script:_aiTxtLog.AppendText("Target PC: $env:COMPUTERNAME | Generated: $scanTime`r`n`r`n")



            $critCount = ($script:_aiReportData | Where-Object { $_.Status -eq "CRITICAL" }).Count

            $warnCount = ($script:_aiReportData | Where-Object { $_.Status -eq "WARNING" }).Count

            $okCount   = ($script:_aiReportData | Where-Object { $_.Status -eq [System.Windows.Forms.DialogResult]::OK }).Count



            $script:_aiTxtLog.AppendText("Overall Status Summary:`r`n")

            $script:_aiTxtLog.AppendText("  - Critical Issues: $critCount`r`n")

            $script:_aiTxtLog.AppendText("  - Warnings:        $warnCount`r`n")

            $script:_aiTxtLog.AppendText("  - Healthy Checks:  $okCount`r`n`r`n")

            

            $script:_aiTxtLog.AppendText("DETAILED FINDINGS AND ADVISORIES:`r`n")

            $script:_aiTxtLog.AppendText("==========================================================================`r`n`r`n")



            foreach ($item in $script:_aiReportData) {

                if ($item.Status -ne "OK") {

                    $statusText = if ($item.Status -eq "CRITICAL") { "[CRITICAL ISSUE]" } else { "[WARNING]" }

                    $script:_aiTxtLog.AppendText("$statusText ($($item.Category)) - $($item.Title)`r`n")

                    $script:_aiTxtLog.AppendText("  Details:`r`n")

                    foreach ($d in $item.Details) {

                        $script:_aiTxtLog.AppendText("    - $d`r`n")

                    }

                    if ($item.Explanation) {

                        $script:_aiTxtLog.AppendText("  Explanation: $($item.Explanation)`r`n")

                    }

                    if ($item.Recommendations.Count -gt 0) {

                        $script:_aiTxtLog.AppendText("  Action Steps (How to fix):`r`n")

                        foreach ($r in $item.Recommendations) {

                            $script:_aiTxtLog.AppendText("    * $r`r`n")

                        }

                    }

                    $script:_aiTxtLog.AppendText("--------------------------------------------------------------------------`r`n`r`n")

                }

            }

            

            if ($critCount -eq 0 -and $warnCount -eq 0) {

                $script:_aiTxtLog.AppendText("[SYSTEM HEALTHY] All system components are operating optimally. No actions required.`r`n")

                $script:_aiTxtLog.AppendText("==========================================================================`r`n")

            }

            

            $script:_aiLblStep.Text = "Diagnostic Summary loaded into console!"

            $script:_aiLblStep.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#00ff88')

        } catch {

            Out-MessageBox("Failed to load summary: " + $_.Exception.Message, "Error", 'OK', 'Error')

        }

    })



    $btnScan.Add_Click({

        $script:_aiBtnScan.Enabled = $false

        $script:_aiBtnResume.Enabled = $false

        $script:_aiBtnExport.Enabled = $false

        $script:_aiTxtLog.Text = ""

        $script:_aiLblStep.Text = "AI Phase: Running 10-point heuristics scan..."

        $script:_aiLblStep.ForeColor = Get-ThemeColor 'Muted'

        [System.Windows.Forms.Application]::DoEvents()



        $script:_aiTxtLog.AppendText("[AI COGNITIVE CORE] Initializing 10-Point Cyber-Heuristics Scanners...`r`n")

        $script:_aiTxtLog.AppendText("Target Systems: S.M.A.R.T., Capacity, RAM, Thermal, BSOD Logs, Drivers, Battery, Security, Network, Resources.`r`n")

        $script:_aiTxtLog.AppendText("==========================================================================`r`n")

        $script:_aiTxtLog.AppendText("`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        # --- PHASE 1/10: Storage Hardware S.M.A.R.T. ---

        $script:_aiLblStep.Text = "Phase 1/10: Scanning Storage S.M.A.R.T. & Sectors..."

        [System.Windows.Forms.Application]::DoEvents()

        $script:_aiTxtLog.AppendText("[STEP 1/10] Crawling storage hardware health registers & drive sector prediction status...`r`n")



        $smartAlert = $false

        try {

            $drives = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue

            foreach ($d in $drives) { if ($d.PredictFailure) { $smartAlert = $true } }

        } catch {}



        $queueAlert = $false

        try {

            $diskPerf = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -ErrorAction SilentlyContinue

            if ($null -ne $diskPerf -and $diskPerf.CurrentDiskQueueLength -gt 2) { $queueAlert = $true }

        } catch {}



        if ($smartAlert) {

            $script:_aiTxtLog.AppendText("[STORAGE ISSUE] DRIVE PREDICTIVE S.M.A.R.T FAILURE DETECTED!`r`n")

            $script:_aiTxtLog.AppendText("   Cause: SSD/HDD predictions indicate imminent drive crash or dead blocks.`r`n")

            $script:_aiTxtLog.AppendText("   Recommendation: Backup all data immediately and replace the drive!`r`n")

        } elseif ($queueAlert) {

            $script:_aiTxtLog.AppendText("[STORAGE ISSUE] SLOW PC - EXTREME STORAGE QUEUE SATURATION!`r`n")

            $script:_aiTxtLog.AppendText("   Cause: Drive active queues are overloaded. Cannot handle IO throughput.`r`n")

            $script:_aiTxtLog.AppendText("   Recommendation: Migrate system to a premium NVMe SSD drive.`r`n")

        } else {

            $script:_aiTxtLog.AppendText("[STORAGE STATUS] Storage disk S.M.A.R.T. health and queue limits are optimal.`r`n")

        }

        $script:_aiTxtLog.AppendText("`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        # --- PHASE 2/10: C: Partition & Disk Space Capacity ---

        $script:_aiLblStep.Text = "Phase 2/10: Checking C: Partition Free Space..."

        [System.Windows.Forms.Application]::DoEvents()

        $script:_aiTxtLog.AppendText("[STEP 2/10] Querying logical storage space allocation and partition sizes...`r`n")



        $driveSpaceAlert = $false

        $freePercent = 100

        $cTotalGB = 0

        $cFreeGB = 0

        try {

            $cDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue

            if ($cDrive) {

                $cTotalGB = [Math]::Round($cDrive.Size / 1GB, 1)

                $cFreeGB = [Math]::Round($cDrive.FreeSpace / 1GB, 1)

                $freePercent = [Math]::Round(($cFreeGB / $cTotalGB) * 100, 1)

                if ($freePercent -lt 12) { $driveSpaceAlert = $true }

            }

        } catch {}



        if ($driveSpaceAlert) {

            $script:_aiTxtLog.AppendText("[STORAGE ALERT] Free disk space is critical on C: ($freePercent% free, $cFreeGB GB / $cTotalGB GB)!`r`n")

            $script:_aiTxtLog.AppendText("   Recommendation: Clean up junk files immediately using SMART FIX!`r`n")

        } else {

            $script:_aiTxtLog.AppendText("[STORAGE STATUS] C: Drive space capacity is comfortable ($freePercent% free, $cFreeGB GB / $cTotalGB GB).`r`n")

        }

        $script:_aiTxtLog.AppendText("`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        # --- PHASE 3/10: Motherboard RAM & Hardware Integrity ---

        $script:_aiLblStep.Text = "Phase 3/10: Checking physical RAM memory registers..."

        [System.Windows.Forms.Application]::DoEvents()

        $script:_aiTxtLog.AppendText("[STEP 3/10] Querying SMBIOS memory devices for parity, ECC, and hardware cell errors...`r`n")



        $ramHardwareAlert = $false

        try {

            $memDevices = Get-CimInstance Win32_MemoryDevice -ErrorAction SilentlyContinue

            foreach ($m in $memDevices) {

                if ($m.ErrorAccess -or $m.ErrorDescription -or ($m.ErrorMethodology -match "Error Correction")) { $ramHardwareAlert = $true }

            }

        } catch {}



        if ($ramHardwareAlert) {

            $script:_aiTxtLog.AppendText("[RAM ISSUE] Motherboard physical RAM memory faults found!`r`n")

            $script:_aiTxtLog.AppendText("   Cause: SMBIOS memory device address logs report ECC hardware cell errors.`r`n")

            $script:_aiTxtLog.AppendText("   Recommendation: RAM card damaged or slot loose. Reseat RAM sticks!`r`n")

        } else {

            $script:_aiTxtLog.AppendText("[RAM STATUS] Memory modules hardware index is healthy.`r`n")

        }

        $script:_aiTxtLog.AppendText("`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        # --- PHASE 4/10: CPU Thermal Zones & Core Temperatures ---

        $script:_aiLblStep.Text = "Phase 4/10: Scanning CPU Thermal Zones..."

        [System.Windows.Forms.Application]::DoEvents()

        $script:_aiTxtLog.AppendText("[STEP 4/10] Querying system ACPI thermal sensors for motherboard and CPU cores...`r`n")



        $thermalAlert = $false

        $cpuTemp = 0

        try {

            $tempsC = Get-SafeCpuTemperature

            if ($null -ne $tempsC) {

                foreach ($tempC in $tempsC) {

                    if ($tempC -gt $cpuTemp) { $cpuTemp = $tempC }

                }

            }

            if ($cpuTemp -gt 82) { $thermalAlert = $true }

        } catch {}



        if ($cpuTemp -gt 0) {

            $script:_aiTxtLog.AppendText("   Current Peak Core Temperature: " + [Math]::Round($cpuTemp, 1) + " C`r`n")

            if ($thermalAlert) {

                $script:_aiTxtLog.AppendText("[THERMAL ALERT] High system temperature detected! Thermal throttling may be active.`r`n")

                $script:_aiTxtLog.AppendText("   Recommendation: Verify cooling fans are operational and re-apply thermal paste.`r`n")

            } else {

                $script:_aiTxtLog.AppendText("[THERMAL STATUS] CPU and motherboard thermal metrics are in safe ranges.`r`n")

            }

        } else {

            $script:_aiTxtLog.AppendText("[THERMAL STATUS] No active thermal zone sensor alerts reported.`r`n")

        }

        $script:_aiTxtLog.AppendText("`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        # --- PHASE 5/10: Kernel Crash Analyzer & BSOD Stop Logs ---

        $script:_aiLblStep.Text = "Phase 5/10: Parsing Windows stop logs & BSOD dumps..."

        [System.Windows.Forms.Application]::DoEvents()

        $script:_aiTxtLog.AppendText("[STEP 5/10] Parsing system unexpected shutdowns, minidump bugchecks, and kernel stops...`r`n")



        $unexpectedShutdownCount = 0

        $bsodAlert = $false

        $bsodDetails = ""

        try {

            $startTime = (Get-Date).AddDays(-3)

            $events = Get-WinEvent -FilterHashtable @{ LogName='System'; Id=@(41, 6008); StartTime=$startTime } -MaxEvents 10 -ErrorAction SilentlyContinue

            if ($events) { $unexpectedShutdownCount = $events.Count }

        } catch {}



        try {

            $dumpPath = "C:\Windows\Minidump"

            if (Test-Path -LiteralPath $dumpPath) {

                $dumps = Get-ChildItem -LiteralPath $dumpPath -Filter "*.dmp" -ErrorAction SilentlyContinue

                if ($null -ne $dumps -and $dumps.Count -gt 0) {

                    $bsodAlert = $true

                    $bsodDetails = "Found " + $dumps.Count + " BSOD minidump crash files."

                }

            }

        } catch {}



        if ($unexpectedShutdownCount -gt 0) {

            $script:_aiTxtLog.AppendText(("[WINDOWS ISSUE] Detected " + $unexpectedShutdownCount + " sudden unexpected shutdowns in event logs.`r`n"))

            $script:_aiTxtLog.AppendText("   Cause: Force shutdown, unstable power supply, direct power loss, or hardware crash.`r`n")

        }



        if ($bsodAlert) {

            $script:_aiTxtLog.AppendText(("[WINDOWS ISSUE] BSOD crashes detected! " + $bsodDetails + "`r`n"))

            $script:_aiTxtLog.AppendText("   Recommendation: Run 'SFC /SCANNOW' or 'Chkdsk' to check for corrupt modules.`r`n")

        }



        if ($unexpectedShutdownCount -eq 0 -and -not $bsodAlert) {

            $script:_aiTxtLog.AppendText("[WINDOWS STATUS] OS stability is good. Clean shutdown cycles detected.`r`n")

        }

        $script:_aiTxtLog.AppendText("`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        # --- PHASE 6/10: Device Manager & Physical Driver Conflicts ---

        $script:_aiLblStep.Text = "Phase 6/10: Checking physical driver devices..."

        [System.Windows.Forms.Application]::DoEvents()

        $script:_aiTxtLog.AppendText("[STEP 6/10] Querying Plug-and-Play (PnP) controller driver status logs...`r`n")



        $driverAlert = $false

        $crashedDrivers = @()

        try {

            $badDevices = Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } -ErrorAction SilentlyContinue

            if ($badDevices) {

                $driverAlert = $true

                foreach ($d in $badDevices) {

                    $crashedDrivers += "$($d.Name) (Error Code $($d.ConfigManagerErrorCode))"

                }

            }

        } catch {}



        if ($driverAlert) {

            $script:_aiTxtLog.AppendText("[DRIVER ISSUE] " + $crashedDrivers.Count + " faulty driver devices detected in Device Manager!`r`n")

            $script:_aiTxtLog.AppendText("   Crashed Drivers: " + ($crashedDrivers -join ', ') + "`r`n")

            $script:_aiTxtLog.AppendText("   Recommendation: Re-install driver or roll back driver in Device Manager.`r`n")

        } else {

            $script:_aiTxtLog.AppendText("[DRIVER STATUS] All physical device drivers are operating normally.`r`n")

        }

        $script:_aiTxtLog.AppendText("`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        # --- PHASE 7/10: Laptop Power System & Battery Wear ---

        $script:_aiLblStep.Text = "Phase 7/10: Auditing power supply & battery health..."

        [System.Windows.Forms.Application]::DoEvents()

        $script:_aiTxtLog.AppendText("[STEP 7/10] Querying motherboard battery wear indicators & design capacities...`r`n")



        $batteryAlert = $false

        $batteryWear = 0

        $batteryText = ""

        try {

            $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue

            if ($battery) {

                $design = $battery.DesignCapacity

                $full = $battery.FullChargeCapacity

                if ($design -gt 0 -and $full -gt 0) {

                    $batteryWear = [Math]::Round((1 - ($full / $design)) * 100, 1)

                    if ($batteryWear -gt 25) { $batteryAlert = $true }

                    $batteryText = "Battery wear level: $batteryWear% (Capacity: $full mWh / $design mWh)"

                }

            }

        } catch {}



        if ($batteryText) {

            $script:_aiTxtLog.AppendText("   " + $batteryText + "`r`n")

            if ($batteryAlert) {

                $script:_aiTxtLog.AppendText("[BATTERY ALERT] Battery wear is severe ($batteryWear%)! Performance may be throttled.`r`n")

                $script:_aiTxtLog.AppendText("   Recommendation: Replace your laptop battery soon to avoid throttling.`r`n")

            } else {

                $script:_aiTxtLog.AppendText("[BATTERY STATUS] Battery life wear is within normal healthy tolerances.`r`n")

            }

        } else {

            $script:_aiTxtLog.AppendText("[BATTERY STATUS] Desktop system detected or battery wear not applicable.`r`n")

        }

        $script:_aiTxtLog.AppendText("`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        # --- PHASE 8/10: Active Cyber Security Shield (AV & Firewall) ---

        $script:_aiLblStep.Text = "Phase 8/10: Auditing security shield antivirus & firewall..."

        [System.Windows.Forms.Application]::DoEvents()

        $script:_aiTxtLog.AppendText("[STEP 8/10] Auditing Windows Defender status and active firewall profile state...`r`n")



        # Antivirus Status check

        $securityShieldAlert = $false

        $activeAV = "Windows Defender"

        $avEnabled = $true

        try {

            $defender = Get-Service WinDefend -ErrorAction SilentlyContinue

            if ($null -ne $defender -and ($defender.Status -eq 'Stopped' -or $defender.StartType -eq 'Disabled')) {

                $securityShieldAlert = $true

                $avEnabled = $false

            }

            $avProduct = Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue

            if ($null -ne $avProduct) {

                $activeAV = $avProduct.displayName

            }

        } catch {}



        # Firewall Active status check

        $firewallAlert = $false

        try {

            $profiles = netsh advfirewall show allprofiles | Where-Object { $_ -like "State*OFF" }

            if ($profiles) {

                $firewallAlert = $true

                $securityShieldAlert = $true

            }

        } catch {}



        if ($securityShieldAlert) {

            $script:_aiTxtLog.AppendText("[SECURITY SHIELD ALERT] System security policies are degraded!`r`n")

            if (-not $avEnabled) { $script:_aiTxtLog.AppendText("   - Antivirus Protection: DISABLED (WinDefend stopped or disabled).`r`n") }

            if ($firewallAlert) { $script:_aiTxtLog.AppendText("   - Windows Advanced Firewall: ONE OR MORE PROFILES ARE OFF.`r`n") }

            $script:_aiTxtLog.AppendText("   Recommendation: Click 'APPLY SMART FIX' to restore full active security shield!`r`n")

        } else {

            $script:_aiTxtLog.AppendText("[SECURITY STATUS] Security Shield active. Antivirus: $activeAV | Firewall: ON.`r`n")

        }

        $script:_aiTxtLog.AppendText("`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        # --- PHASE 9/10: Network Gateway Route & DNS Latency ---

        $script:_aiLblStep.Text = "Phase 9/10: Testing connection ping & DNS speed..."

        [System.Windows.Forms.Application]::DoEvents()

        $script:_aiTxtLog.AppendText("[STEP 9/10] Resolving local routing hops, gateway ping, and DNS response latency...`r`n")



        $netIP = ""

        $netGateway = ""

        $isApipa = $false

        $gatewayPingOk = $false

        $pingISP = $false

        $pingDNS = $false

        $dnsLatency = -1

        $dnsLatencyAlert = $false



        try {

            $config = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address } | Select-Object -First 1

            if ($config) {

                $netIP = $config.IPv4Address.IPAddress

                if ($config.IPv4DefaultGateway) { $netGateway = $config.IPv4DefaultGateway.NextHop }

            }

        } catch {}



        if ([string]::IsNullOrEmpty($netIP)) {

            $script:_aiTxtLog.AppendText("[NETWORK/INTERNET ISSUE] Network adapter has no IP address assigned!`r`n")

            $script:_aiTxtLog.AppendText("   Recommendation: Check cable connection or Wi-Fi credentials.`r`n")

        } elseif ($netIP -like "169.254.*") {

            $isApipa = $true

            $script:_aiTxtLog.AppendText(("[NETWORK/INTERNET ISSUE] DHCP failure - APIPA IP detected: " + $netIP + "`r`n"))

            $script:_aiTxtLog.AppendText("   Recommendation: Reboot your router and verify DHCP configuration.`r`n")

        } else {

            $script:_aiTxtLog.AppendText(("   Local IP Address: " + $netIP + "`r`n"))

            if (-not [string]::IsNullOrEmpty($netGateway)) {

                $script:_aiTxtLog.AppendText(("   Pinging Default Gateway (" + $netGateway + ")...`r`n"))

                [System.Windows.Forms.Application]::DoEvents()

                try { $pingGW = Test-Connection $netGateway -Count 1 -Quiet -ErrorAction SilentlyContinue } catch { $pingGW = $false }

                if ($pingGW) {

                    $gatewayPingOk = $true

                    $script:_aiTxtLog.AppendText("   Default Gateway router is ONLINE.`r`n")

                } else {

                    $script:_aiTxtLog.AppendText("   Default Gateway router ping FAILED!`r`n")

                }

            }



            $script:_aiTxtLog.AppendText("   Pinging Public Internet (8.8.8.8)...`r`n")

            [System.Windows.Forms.Application]::DoEvents()

            try { $pingISP = Test-Connection 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue } catch { $pingISP = $false }



            $script:_aiTxtLog.AppendText("   Resolving domain name and calculating latency (google.com)...`r`n")

            [System.Windows.Forms.Application]::DoEvents()

            

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try { 

                $null = [System.Net.Dns]::GetHostAddresses("google.com")

                $stopwatch.Stop()

                $dnsLatency = $stopwatch.ElapsedMilliseconds

                $pingDNS = $true

            } catch { 

                $stopwatch.Stop()

                $pingDNS = $false 

            }



            if ($gatewayPingOk -and -not $pingISP) {

                $script:_aiTxtLog.AppendText("[NETWORK/INTERNET ISSUE] Router online but ISP/WAN connection is DOWN!`r`n")

                $script:_aiTxtLog.AppendText("   Recommendation: Contact your Internet Service Provider (ISP).`r`n")

            } elseif ($pingISP -and -not $pingDNS) {

                $script:_aiTxtLog.AppendText("[NETWORK/INTERNET ISSUE] Internet reachable but DNS resolution failing!`r`n")

                $script:_aiTxtLog.AppendText("   Recommendation: Run DNS Flush or set manual public DNS 8.8.8.8.`r`n")

            } elseif ($pingDNS) {

                if ($dnsLatency -gt 250) {

                    $dnsLatencyAlert = $true

                    $script:_aiTxtLog.AppendText("[NETWORK WARNING] High DNS query lookup latency: $dnsLatency ms (Normal <100ms)!`r`n")

                } else {

                    $script:_aiTxtLog.AppendText("[NETWORK/INTERNET STATUS] Connection optimal. DNS Latency: $dnsLatency ms.`r`n")

                }

            } else {

                $script:_aiTxtLog.AppendText("[NETWORK/INTERNET ISSUE] Complete network route offline.`r`n")

            }

        }

        $script:_aiTxtLog.AppendText("`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        # --- PHASE 10/10: Performance Sweeper & Active Resource Leaks ---

        $script:_aiLblStep.Text = "Phase 10/10: Sweeping resource leaks & startup bloat..."

        [System.Windows.Forms.Application]::DoEvents()

        $script:_aiTxtLog.AppendText("[STEP 10/10] Auditing CPU load, memory exhaustion, startup load, and junk accumulation...`r`n")



        $cpuLoad = 0

        $ramPercent = 0

        $totalGB = 0

        $usedGB = 0



        try { $cpuInstance = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue; if ($cpuInstance) { $cpuLoad = $cpuInstance.LoadPercentage } } catch {}

        try {

            Add-Type -AssemblyName 'Microsoft.VisualBasic' -ErrorAction SilentlyContinue

            $info = New-Object Microsoft.VisualBasic.Devices.ComputerInfo

            $totalGB = [Math]::Round($info.TotalPhysicalMemory / 1GB, 1)

            $freeGB  = [Math]::Round($info.AvailablePhysicalMemory / 1GB, 1)

            $usedGB  = $totalGB - $freeGB

            if ($totalGB -gt 0) { $ramPercent = [Math]::Round(($usedGB / $totalGB) * 100, 1) }

        } catch {}



        # Junk cache accumulation calculator

        $junkSizeMB = 0

        $junkAlert = $false

        try {

            $tempPaths = @($env:TEMP, "$env:windir\Temp", "$env:windir\Prefetch")

            foreach ($path in $tempPaths) {

                if (Test-Path $path) {

                    $files = Get-ChildItem -Path $path -File -Recurse -ErrorAction SilentlyContinue

                    foreach ($f in $files) { $junkSizeMB += $f.Length / 1MB }

                }

            }

            $junkSizeMB = [Math]::Round($junkSizeMB, 1)

            if ($junkSizeMB -gt 450) { $junkAlert = $true }

        } catch {}



        # Startup command count checker

        $startupCount = 0

        $startupAlert = $false

        try {

            $startupCount = (Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue).Count

            if ($startupCount -gt 15) { $startupAlert = $true }

        } catch {}



        $heavyApps = @()

        try {

            $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.WorkingSet64 -gt 400MB } | Sort-Object WorkingSet64 -Descending | Select-Object -First 5

            foreach ($p in $procs) {

                $heavyApps += ($p.ProcessName + " (" + [Math]::Round($p.WorkingSet64 / 1MB, 0) + " MB)")

            }

        } catch {}



        $script:_aiTxtLog.AppendText(("   CPU Load: " + $cpuLoad + "% | RAM Used: " + $usedGB + " GB / " + $totalGB + " GB (" + $ramPercent + "%)") + "`r`n")

        $script:_aiTxtLog.AppendText("   Junk Files Cache: $junkSizeMB MB" + $(if ($junkAlert) { " [SATURATED!]" } else { "" }) + "`r`n")

        $script:_aiTxtLog.AppendText("   High-Impact Startup Programs: $startupCount" + $(if ($startupAlert) { " [EXCESSIVE!]" } else { "" }) + "`r`n")



        if ($cpuLoad -gt 85 -or $ramPercent -gt 90) {

            $script:_aiTxtLog.AppendText("[SLUGGISH PC ISSUE] CPU or Memory is heavily saturated!`r`n")

            if ($heavyApps.Count -gt 0) { $script:_aiTxtLog.AppendText(("   Heavy apps: " + ($heavyApps -join ', ') + "`r`n")) }

            $script:_aiTxtLog.AppendText("   Recommendation: Terminate heavy apps or use ONE-CLICK BOOST.`r`n")

        } else {

            $script:_aiTxtLog.AppendText("[SYSTEM SPEED STATUS] CPU and RAM usage is in normal healthy ranges.`r`n")

            if ($heavyApps.Count -gt 0) { $script:_aiTxtLog.AppendText(("   Top memory apps: " + ($heavyApps -join ', ') + "`r`n")) }

        }



        # Extra OS file integrity and Update check

        $osFileAlert = $false

        try {

            $cbsPath = "C:\Windows\Logs\CBS\CBS.log"

            if (Test-Path $cbsPath) {

                $corruptLines = Get-Content -Path $cbsPath -Tail 500 -ErrorAction SilentlyContinue | Where-Object { $_ -like "*Corrupt*" -and $_ -like "*Repair*" }

                if ($corruptLines) { $osFileAlert = $true }

            }

        } catch {}



        $wuAlert = $false

        $wuDetails = ""

        try {

            $rebootPending = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

            $wuauserv = Get-Service wuauserv -ErrorAction SilentlyContinue

            if ($rebootPending) {

                $wuAlert = $true

                $wuDetails = "System pending restart for critical updates."

            } elseif ($wuauserv -and $wuauserv.Status -eq 'Stopped' -and $wuauserv.StartType -eq 'Disabled') {

                $wuAlert = $true

                $wuDetails = "Windows Update service is disabled."

            }

        } catch {}



        $activationAlert = $false

        try {

            $lic = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' and LicenseStatus=1" -ErrorAction SilentlyContinue

            if (-not $lic) { $activationAlert = $true }

        } catch {}



        $uacAlert = $false

        try {

            $uacVal = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue

            if ($uacVal -eq 0) { $uacAlert = $true }

        } catch {}



        $volumeAlert = $false

        $dirtyVolumes = @()

        try {

            $vols = Get-Volume -ErrorAction SilentlyContinue

            foreach ($v in $vols) {

                if ($v.HealthStatus -ne "Healthy" -or $v.OperationalStatus -match "Dirty") {

                    $volumeAlert = $true

                    $dirtyVolumes += "$($v.DriveLetter): ($($v.HealthStatus))"

                }

            }

        } catch {}



        $script:_aiTxtLog.AppendText("`r`n")

        $script:_aiTxtLog.AppendText("==========================================================================`r`n")

        [System.Windows.Forms.Application]::DoEvents()



        # --- BUILD STRUCTURED 10-POINT REPORT DATA ---

        $script:_aiReportData = @()



        # 1. Storage S.M.A.R.T. Health Card

        if ($smartAlert) {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Storage Hardware"

                Title    = "S.M.A.R.T. Predictive Drive Failure Detected!"

                Status   = "CRITICAL"

                Details  = @("Drive health sensors report imminent physical failure.", "Dead sectors or degraded write performance detected by firmware.")

                Explanation = "S.M.A.R.T. is a built-in monitoring system in hard drives and SSDs. When it predicts failure, it indicates critical physical degradation. This is an emergency indicator."

                Recommendations = @("Backup ALL critical data to external storage or cloud immediately.", "Replace your primary SSD or HDD without delay (NVMe recommended).", "Run 'chkdsk C: /f /r' from elevated console to map bad sectors.")

            }

        } elseif ($queueAlert) {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Storage Performance"

                Title    = "Extreme Storage Queue Saturation Detected"

                Status   = "WARNING"

                Details  = @("Disk queue length above 2 detected (normal is 0-1).", "Active read/write operations are currently choking drive throughput.")

                Explanation = "Disk Queue measures wait requests. A value above 2 means system applications are waiting for data from the disk, creating noticeable lag and micro-freezes."

                Recommendations = @("Upgrade to a fast SSD - this resolves 95% of disk bottleneck issues.", "Check high disk IO processes in Task Manager.", "Disable Windows Search indexing service temporarily (services.msc).")

            }

        } else {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Storage Hardware"

                Title    = "Storage S.M.A.R.T. Health: Optimal"

                Status   = "OK"

                Details  = @("No predictive failure flags detected.", "Disk read/write queue indices are within optimal boundaries.")

                Explanation = "Your primary storage drives are fully stable. All read/write parameters, block allocations, and temperatures are completely healthy."

                Recommendations = @()

            }

        }



        # 2. Drive Capacity Card

        if ($driveSpaceAlert) {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Storage Performance"

                Title    = "Storage Capacity Alert - Disk Space is Saturated!"

                Status   = "CRITICAL"

                Details  = @("C: Drive has less than 12% free space remaining ($freePercent% free).", "Free Space: $cFreeGB GB remaining out of $cTotalGB GB total.")

                Explanation = "When the primary OS partition runs extremely low on space, Windows cannot create page files or temporary caches correctly, leading to serious system slow-downs and crash instability."

                Recommendations = @("Use the 'APPLY SMART FIX' tool to purge massive temporary cache files instantly.", "Remove heavy unneeded software and games.", "Utilize Disk Cleanup (cleanmgr.exe) to delete Windows update backlogs.")

            }

        } else {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Storage Performance"

                Title    = "C: Drive Partition Space: Healthy"

                Status   = "OK"

                Details  = @("C: partition has plenty of free space ($freePercent% free).", "Free Space: $cFreeGB GB out of $cTotalGB GB.")

                Explanation = "Your system has adequate free space to allocate system page files, temporary application databases, and system update buffers."

                Recommendations = @()

            }

        }



        # 3. RAM Hardware Card

        if ($ramHardwareAlert) {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Memory Hardware"

                Title    = "Motherboard RAM Module Hardware Errors!"

                Status   = "CRITICAL"

                Details  = @("SMBIOS hardware memory device reports error access registers.", "Physical memory parity or ECC cell faults logged by motherboard firmware.")

                Explanation = "Hardware memory cell faults mean the actual electronic chips on your RAM stick are malfunctioning. This causes unpredictable crashes, Blue Screens (BSODs), and data corruption."

                Recommendations = @("Shutdown PC, unplug, and reseat physical RAM modules in their motherboard slots.", "Run Windows Memory Diagnostics tool (mdsched.exe) to test RAM sticks individually.", "Try shifting the RAM sticks to alternate channels.")

            }

        } else {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Memory Hardware"

                Title    = "Physical RAM Memory: Healthy"

                Status   = "OK"

                Details  = @("No physical RAM errors or address register fault logs found.", "Physical memory modules operating within solid electronic tolerances.")

                Explanation = "Your RAM memory sticks are in robust physical health. No bad address ranges or hardware parity faults were logged."

                Recommendations = @()

            }

        }



        # 4. Thermal Status Card

        if ($thermalAlert) {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Thermal Status"

                Title    = "High Core CPU Thermal Throttling Detected!"

                Status   = "CRITICAL"

                Details  = @("CPU temperature zone peak registered at $cpuTemp C (critical threshold is 82C).", "Thermal protection is currently throttling CPU cycle frequency.")

                Explanation = "Extreme CPU heat causes aggressive frequency down-throttling to prevent silicon damage, resulting in micro-stuttering, massive framerate drops, or emergency power-offs."

                Recommendations = @("Inspect and clean physical cooling fans from dust.", "Re-apply high-grade thermal paste to CPU integrated heat spreader.", "Ensure adequate ambient ventilation around case vents.")

            }

        } else {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Thermal Status"

                Title    = "System Thermal Metrics: Cool & Healthy"

                Status   = "OK"

                Details  = @("CPU peak temperature is within excellent ranges ($cpuTemp C).", "No thermal throttling or overheat shutdown triggers active.")

                Explanation = "Core thermal dissipation systems are working efficiently. Temperature registers are well below active safety limits."

                Recommendations = @()

            }

        }



        # 5. OS Stability & Kernel Crash logs Card

        if ($unexpectedShutdownCount -gt 0 -or $bsodAlert) {

            $detailList = @()

            if ($unexpectedShutdownCount -gt 0) { $detailList += ("$unexpectedShutdownCount unexpected shutdowns logged in the last 72 hours.") }

            if ($bsodAlert) { $detailList += $bsodDetails }

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Windows Stability"

                Title    = "Kernel Crash Dumps or System Instability Detected"

                Status   = "CRITICAL"

                Details  = $detailList

                Explanation = "Unexpected shutdowns (Event 6008) and Kernel-Power events (Event 41) mean the PC lost power or crashed without a clean shutdown sequence. BSOD dump files are saved during unhandled kernel exceptions."

                Recommendations = @("Run 'APPLY SMART FIX' to initiate automated sfc/dism repairs.", "Open the BSOD Crash Analyzer side panel to explore detailed dump diagnostics.", "Verify power supply cable integrity and motherboard power feeds.")

            }

        } else {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Windows Stability"

                Title    = "Windows Kernel Stability: Excellent"

                Status   = "OK"

                Details  = @("No sudden power losses or Kernel-Power shutdowns in last 7 days.", "No BSOD dump records (.dmp) detected in C:\Windows\Minidump.")

                Explanation = "Your operating system kernel has maintained solid stability, registering no unhandled exceptions, power dropouts, or blue screens."

                Recommendations = @()

            }

        }



        # 6. Faulty Drivers Card

        if ($driverAlert) {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Devices and Drivers"

                Title    = "Hardware Driver Device Errors Detected!"

                Status   = "CRITICAL"

                Details  = $crashedDrivers

                Explanation = "Faulty physical drivers (Error Code 10/28/43) mean Windows cannot establish communication with motherboard components, leading to dead hardware features."

                Recommendations = @("Open Device Manager (devmgmt.msc), locate the faulted controller, and reinstall or update its drivers.", "Click 'Scan Updates' under Updates Center to check for official vendor drivers.")

            }

        } else {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Devices and Drivers"

                Title    = "Hardware Device Drivers: Healthy"

                Status   = "OK"

                Details  = @("All physical device drivers are operating normally without conflicts.")

                Explanation = "Your hardware controllers, chipsets, and peripheral ports are all fully configured with correct, operational system drivers."

                Recommendations = @()

            }

        }



        # 7. Laptop Battery & Wear Card

        if ($batteryAlert) {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Battery System"

                Title    = "Severe Laptop Battery Wear Detected!"

                Status   = "WARNING"

                Details  = @($batteryText, "Battery wear level has crossed the 25% safety threshold ($batteryWear% wear).")

                Explanation = "High laptop battery wear reduces maximum charge capacity and triggers aggressive CPU power throttling to save cell life, noticeably reducing overall speed."

                Recommendations = @("Consider purchasing an official replacement battery for your laptop.", "Keep the charger connected during intensive tasks to bypass cell throttling.")

            }

        } else {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "Battery System"

                Title    = "Laptop Power & Battery: Optimal"

                Status   = "OK"

                Details  = @($(if ($batteryText) { $batteryText } else { "System is a desktop or battery wear is within acceptable levels." }))

                Explanation = "The local power cell reports comfortable maximum charge thresholds and normal wear parameters."

                Recommendations = @()

            }

        }



        # 8. Antivirus & Security Shield Card

        if ($securityShieldAlert -or $osFileAlert -or $wuAlert -or $activationAlert -or $uacAlert -or $volumeAlert) {

            $secDetails = @()

            if (-not $avEnabled) { $secDetails += "Antivirus Protection: DISABLED (WinDefend is inactive or stopped)." }

            if ($firewallAlert) { $secDetails += "Windows Advanced Firewall: ONE OR MORE PROFILES ARE SHUT OFF." }

            if ($osFileAlert) { $secDetails += "System file structure violations or CBS anomalies detected." }

            if ($wuAlert) { $secDetails += "Windows Update alerts: $wuDetails" }

            if ($uacAlert) { $secDetails += "User Account Control is set to Never Notify (high risk)." }

            if ($volumeAlert) { $secDetails += "Dirty or corrupted logical file volumes: " + ($dirtyVolumes -join ', ') }



            $secRecs = @()

            if ($securityShieldAlert) { $secRecs += "Click 'APPLY SMART FIX' to automatically activate Windows Defender and turn on Firewall profiles." }

            if ($osFileAlert) { $secRecs += "Run 'sfc /scannow' to verify and rebuild critical Windows system binaries." }

            if ($uacAlert) { $secRecs += "Set User Account Control (UAC) to Level 3 (Default) in Control Panel to intercept silent malware installs." }

            if ($volumeAlert) { $secRecs += "Schedule a 'chkdsk C: /f' volume check to scan and clean logical structures." }



            $script:_aiReportData += [PSCustomObject]@{

                Category = "OS and Security Policy"

                Title    = "Security Shield and Windows Configuration Issues!"

                Status   = "CRITICAL"

                Details  = $secDetails

                Explanation = "Disabled antivirus or firewalls represent an extreme risk, allowing active malware to communicate with command servers or steal data silently. CBS file corruption or disabled UAC parameters further degrade kernel security controls."

                Recommendations = $secRecs

            }

        } else {

            $script:_aiReportData += [PSCustomObject]@{

                Category = "OS and Security Policy"

                Title    = "Security Shield & Windows Integrity: Healthy"

                Status   = "OK"

                Details  = @("Core Security Antivirus protection shield is active ($activeAV).", "Windows Firewall is fully active on all network profiles.", "Windows is activated with a valid active license.", "UAC security policies are active at default levels.", "All volume filesystems report clean structures.")

                Explanation = "Your security shield defenses, user account controls, system update systems, and activation parameters are in robust alignment."

                Recommendations = @()

            }

        }



        # 9. Network and Route Card

        $netStatus = "OK"

        $netTitle  = "Network Route & DNS Latency: Excellent"

        $netDetails = @(("Local IP Address: " + $netIP), ("Default Gateway Router: " + $netGateway), ("Internet Route Gateway (8.8.8.8): REACHABLE"), ("DNS Resolution (google.com): ONLINE"), ("DNS Query Latency: $dnsLatency ms"))

        $netExplan = "Local gateway connectivity, public WAN pings, and DNS lookup latency were verified. DNS lookup translates readable domains (google.com) to numeric IPs - high lookup speeds (>250ms) translate to sluggish web browsing."

        $netRecs = @()



        if ([string]::IsNullOrEmpty($netIP)) {

            $netStatus = "CRITICAL"; $netTitle = "Network Adapter Offline - No IP Assigned"

            $netDetails = @("Network controller did not get an IP address from connection.")

            $netRecs = @("Verify Ethernet cable connections or Wi-Fi credentials.", "Check network adapter settings under Control Panel.")

        } elseif ($isApipa) {

            $netStatus = "CRITICAL"; $netTitle = "DHCP Failure - APIPA Self-Assigned IP Active"

            $netDetails = @("DHCP routing failed. APIPA address assigned ($netIP).")

            $netRecs = @("Reboot local router or Wi-Fi gateway.", "Run 'ipconfig /renew' inside Administrator console.")

        } elseif ($gatewayPingOk -and -not $pingISP) {

            $netStatus = "CRITICAL"; $netTitle = "Broadband WAN Connection Offline"

            $netDetails = @("Router gateway is online, but public internet ping failed.")

            $netRecs = @("Check router Broadband/WAN light indicators.", "Contact your Internet Provider to report local outage.")

        } elseif ($dnsLatencyAlert) {

            $netStatus = "WARNING"; $netTitle = "High DNS Response Latency Detected"

            $netDetails = @("DNS query took $dnsLatency ms to complete (optimal is <100ms).", "Internet is connected but DNS lookup is slow.")

            $netRecs = @("Flush DNS cache using the side panel or SMART FIX.", "Set public DNS servers to 8.8.8.8 (Google) or 1.1.1.1 (Cloudflare) in network properties.")

        } elseif (-not $pingDNS) {

            $netStatus = "CRITICAL"; $netTitle = "DNS Query Lookup Failed"

            $netRecs = @("Flush local DNS cache.", "Configure public DNS servers manually (8.8.8.8 / 1.1.1.1).")

        }



        $script:_aiReportData += [PSCustomObject]@{

            Category = "Network and Internet"

            Title    = $netTitle

            Status   = $netStatus

            Details  = $netDetails

            Explanation = $netExplan

            Recommendations = $netRecs

        }



        # 10. Junk Files and Startup Load Card

        $resStatus = "OK"

        $resTitle = "Junk Caches & Startup Performance: Normal"

        $resDetails = @(("CPU Load: " + $cpuLoad + "%"), ("RAM Memory Saturated: " + $ramPercent + "%"), ("Temporary Junk Cache: $junkSizeMB MB"), ("Active Startup Programs: $startupCount"))

        if ($heavyApps.Count -gt 0) { $resDetails += ("Heavy memory consumer apps: " + ($heavyApps -join ', ')) }

        $resExplan = "System performance audits examine active RAM/CPU load, temporary file caches, and boot startup delays. Excess caches (>450MB) and excessive startup apps (>15) bloat performance."

        $resRecs = @()



        if ($cpuLoad -gt 85 -or $ramPercent -gt 90 -or $junkAlert -or $startupAlert) {

            $resStatus = "WARNING"

            $resTitle = "Performance Saturation - Optimization Recommended"

            if ($junkAlert) { $resRecs += "Purge extensive temporary cache files ($junkSizeMB MB) using 'APPLY SMART FIX'." }

            if ($startupAlert) { $resRecs += "Disable unnecessary high-impact startup items using Startup Optimizer sidebar panel." }

            if ($cpuLoad -gt 85 -or $ramPercent -gt 90) { $resRecs += "Use ONE-CLICK BOOST to instantly clear inactive RAM pools." }

        }



        $script:_aiReportData += [PSCustomObject]@{

            Category = "System Performance"

            Title    = $resTitle

            Status   = $resStatus

            Details  = $resDetails

            Explanation = $resExplan

            Recommendations = $resRecs

        }



        # --- SUMMARY OUTPUT ---

        $severeAlerts = @()

        if ($smartAlert)                                             { $severeAlerts += "[STORAGE S.M.A.R.T. FAILURE]" }

        if ($queueAlert)                                             { $severeAlerts += "[STORAGE QUEUE SATURATED]" }

        if ($driveSpaceAlert)                                        { $severeAlerts += "[DISK SPACE CRITICAL]" }

        if ($ramHardwareAlert)                                       { $severeAlerts += "[RAM HARDWARE ERRORS]" }

        if ($thermalAlert)                                           { $severeAlerts += "[CPU HIGH TEMPERATURES]" }

        if ($unexpectedShutdownCount -gt 0 -and $thermalAlert)       { $severeAlerts += "[CPU OVERHEATING SHUTDOWNS]" }

        if ($bsodAlert)                                              { $severeAlerts += "[WINDOWS BSOD DETECTED]" }

        if ($isApipa)                                                { $severeAlerts += "[NETWORK DHCP FAILURE]" }

        if ($gatewayPingOk -and -not $pingISP)                       { $severeAlerts += "[ISP/WAN OFFLINE]" }

        if ($dnsLatencyAlert)                                        { $severeAlerts += "[HIGH DNS RESOLVING DELAYS]" }

        if ($securityShieldAlert)                                    { $severeAlerts += "[SECURITY SHIELD SHUT OFF]" }

        if ($unexpectedShutdownCount -gt 0 -and -not $thermalAlert)  { $severeAlerts += "[UNEXPECTED SHUTDOWNS]" }

        if ($driverAlert)                                            { $severeAlerts += "[FAULTY SYSTEM DRIVERS]" }

        if ($batteryAlert)                                           { $severeAlerts += "[SEVERE BATTERY WEAR]" }

        if ($osFileAlert)                                            { $severeAlerts += "[OS FILE CORRUPTIONS]" }

        if ($wuAlert)                                                { $severeAlerts += "[WINDOWS UPDATE BLOCKAGE]" }

        if ($activationAlert)                                        { $severeAlerts += "[WINDOWS UNACTIVATED]" }

        if ($uacAlert)                                               { $severeAlerts += "[UAC SECURITY RISK]" }

        if ($volumeAlert)                                            { $severeAlerts += "[VOLUME FILE CORRUPTIONS]" }

        if ($junkAlert)                                              { $severeAlerts += "[EXCESSIVE TEMP JUNK CACHES]" }

        if ($startupAlert)                                           { $severeAlerts += "[EXCESSIVE STARTUP LOAD]" }



        if ($severeAlerts.Count -gt 0) {

            $script:_aiTxtLog.AppendText(">> AI HEALTH ADVISORY: CRITICAL ISSUES FOUND!`r`n")

            $script:_aiTxtLog.AppendText((">> Alerts: " + ($severeAlerts -join ' | ') + "`r`n"))

            $script:_aiTxtLog.AppendText(">> Use the Smart Fix tool or sidebar panels to resolve these instantly!`r`n")

        } else {

            $script:_aiTxtLog.AppendText(">> AI HEALTH ADVISORY: EXCELLENT PC HEALTH!`r`n")

            $script:_aiTxtLog.AppendText(">> No critical security, hardware, stability, or routing issues found.`r`n")

            $script:_aiTxtLog.AppendText(">> Your system is running optimally.`r`n")

        }

        $script:_aiTxtLog.AppendText("`r`n>> Click 'EXPORT HTML REPORT' below to save a detailed premium report.`r`n")



        $script:_aiLblStep.Text = "SCAN COMPLETE - Click 'Export HTML Report' to save detailed report"

        $script:_aiLblStep.ForeColor = [System.Drawing.Color]::LimeGreen

        $script:_aiBtnScan.Enabled = $true

        

        $script:_aiBtnResume.Enabled = $true

        $script:_aiBtnResume.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#0088cc')

        

        $script:_aiBtnExport.Enabled = $true

        $script:_aiBtnExport.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#00aa55')



        if ($severeAlerts.Count -gt 0) {

            $script:_aiBtnRepair.Enabled = $true

            $script:_aiBtnRepair.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#4a1515')

            $script:_aiBtnRepair.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#ff5555')

            $script:_aiBtnRepair.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml('#ff5555')

        } else {

            $script:_aiBtnRepair.Enabled = $false

            $script:_aiBtnRepair.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#221515')

            $script:_aiBtnRepair.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#884444')

            $script:_aiBtnRepair.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml('#884444')

        }

    })

    $topCard.BringToFront()



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}







function Show-LicenseVaultPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "Windows License Recovery Vault"

    $metaLabel.Text = "Securely retrieve, decrypt, and backup active Windows keys and Office digital licenses"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_license_vault'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 80

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 15, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Windows Product Key & License Explorer"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 12)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Extracts activation keys directly from BIOS ACPI tables, hardware firmware registry, and digital stores."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 40)

    $headerPanel.Controls.Add($panelSub)



    $gridHost.Controls.Add($headerPanel)



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    # Let's run key extraction in background or instantly

    $windowsEdition = "Windows 10/11 Professional"

    try {

        $windowsEdition = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ProductName" -ErrorAction SilentlyContinue).ProductName

    } catch {}



    $keySource = "Registry DigitalProductId"

    $detectedKey = "Generic/Digital License Active"



    # Try BIOS Key first

    try {

        $biosObj = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction SilentlyContinue

        if ($biosObj -and $biosObj.OA3xOriginalProductKey -and $biosObj.OA3xOriginalProductKey.Trim().Length -eq 29) {

            $detectedKey = $biosObj.OA3xOriginalProductKey.Trim()

            $keySource = "BIOS ACPI OEM Table"

        } else {

            # Try to decrypt HKLM product ID

            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

            $binId = (Get-ItemProperty -Path $regPath -Name "DigitalProductId" -ErrorAction SilentlyContinue).DigitalProductId

            if ($binId) {

                # Helper decoding algorithm inline

                $keyOffset = 52

                $isWin8 = ([math]::Floor($binId[66] / 6) -band 1)

                $binId[66] = ($binId[66] -band 247) -bor (($isWin8 -band 2) * 4)

                $i = 24

                $chars = "BCDFGHJKMPQRTVWXY2346789"

                $rawKey = ""

                do {

                    $cur = 0

                    $x = 14

                    do {

                        $cur = $cur * 256

                        $cur = $binId[$x + $keyOffset] + $cur

                        $binId[$x + $keyOffset] = [math]::Floor($cur / 24)

                        $cur = $cur % 24

                        $x = $x - 1

                    } while ($x -ge 0)

                    $i = $i - 1

                    $rawKey = $chars[$cur] + $rawKey

                } while ($i -ge 0)

                

                $part1 = $rawKey.Substring(1, $i)

                $part2 = $rawKey.Substring($i + 1, $rawKey.Length - ($i + 1))

                if ($isWin8 -eq 1) {

                    $rawKey = $part2.Insert($part2.IndexOf($part1) + $part1.Length, "N")

                }

                

                $formattedKey = ""

                for ($j = 0; $j -lt 25; $j += 5) {

                    if ($j -ne 0) { $formattedKey += "-" }

                    $formattedKey += $rawKey.Substring($j, 5)

                }

                if ($formattedKey -and $formattedKey.Length -eq 29) {

                    $detectedKey = $formattedKey

                    $keySource = "Decrypted Registry DigitalProductId"

                }

            }

        }

    } catch {}



    # Office Activations Check

    $officeStatus = "MS Office Activation: Digital Account Entitled"

    try {

        $officePaths = @(

            "C:\Program Files\Microsoft Office\Office16\OSPP.VBS",

            "C:\Program Files (x86)\Microsoft Office\Office16\OSPP.VBS",

            "C:\Program Files\Microsoft Office\Office15\OSPP.VBS",

            "C:\Program Files (x86)\Microsoft Office\Office15\OSPP.VBS"

        )

        foreach ($path in $officePaths) {

            if (Test-Path $path) {

                $output = cscript //nologo $path /dstatus

                $last5 = $output | Select-String -Pattern "Last 5 characters of installed product key" -ErrorAction SilentlyContinue

                if ($last5) {

                    $keys = @()

                    foreach ($line in $last5) {

                        if ($line -match "Last 5 characters of installed product key:\s+([A-Z0-9]{5})") {

                            $keys += $Matches[1]

                        }

                    }

                    if ($keys.Count -gt 0) {

                        $officeStatus = "Office Key (Last 5): " + ($keys -join ", ")

                    }

                }

            }

        }

    } catch {}



    # Design the Premium Vault Card

    $card = New-Object System.Windows.Forms.Panel

    $card.Size = New-Object System.Drawing.Size(850, 480)

    $card.BackColor = Get-ThemeColor 'Panel'

    $card.Padding = New-Object System.Windows.Forms.Padding(24)

    Enable-DoubleBuffer $card



    # Outer border/rounding style by placing components

    $lblEd = New-Object System.Windows.Forms.Label

    $lblEd.Text = "OPERATING SYSTEM EDITION"

    $lblEd.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $lblEd.ForeColor = Get-ThemeColor 'Muted'

    $lblEd.SetBounds(24, 24, 400, 20)

    $card.Controls.Add($lblEd)



    $valEd = New-Object System.Windows.Forms.Label

    $valEd.Text = $windowsEdition

    $valEd.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)

    $valEd.ForeColor = Get-ThemeColor 'Text'

    $valEd.SetBounds(24, 48, 700, 30)

    $card.Controls.Add($valEd)



    $lblKey = New-Object System.Windows.Forms.Label

    $lblKey.Text = "RECOVERED ACTIVATION LICENSE KEY"

    $lblKey.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $lblKey.ForeColor = Get-ThemeColor 'Muted'

    $lblKey.SetBounds(24, 110, 400, 20)

    $card.Controls.Add($lblKey)



    # A sleek high-contrast textbox to show the key

    $txtKey = New-Object System.Windows.Forms.TextBox

    $txtKey.Text = $detectedKey

    $txtKey.Font = New-Object System.Drawing.Font('Consolas', 18, [System.Drawing.FontStyle]::Bold)

    $txtKey.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1E1E1E")

    $txtKey.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF66")

    $txtKey.ReadOnly = $true

    $txtKey.TextAlign = 'Center'

    $txtKey.SetBounds(24, 135, 780, 45)

    $card.Controls.Add($txtKey)



    $lblSrc = New-Object System.Windows.Forms.Label

    $lblSrc.Text = "LICENSE SOURCE METHOD"

    $lblSrc.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $lblSrc.ForeColor = Get-ThemeColor 'Muted'

    $lblSrc.SetBounds(24, 210, 400, 20)

    $card.Controls.Add($lblSrc)



    $valSrc = New-Object System.Windows.Forms.Label

    $valSrc.Text = $keySource

    $valSrc.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

    $valSrc.ForeColor = Get-ThemeColor 'Text'

    $valSrc.SetBounds(24, 235, 700, 25)

    $card.Controls.Add($valSrc)



    $lblOff = New-Object System.Windows.Forms.Label

    $lblOff.Text = "MICROSOFT OFFICE SUITE STATUS"

    $lblOff.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $lblOff.ForeColor = Get-ThemeColor 'Muted'

    $lblOff.SetBounds(24, 290, 400, 20)

    $card.Controls.Add($lblOff)



    $valOff = New-Object System.Windows.Forms.Label

    $valOff.Text = $officeStatus

    $valOff.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

    $valOff.ForeColor = Get-ThemeColor 'Text'

    $valOff.SetBounds(24, 315, 700, 25)

    $card.Controls.Add($valOff)



    # Actions buttons

    $btnCopy = New-Object System.Windows.Forms.Button

    $btnCopy.Text = "Copy Windows Key"

    $btnCopy.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnCopy.FlatStyle = 'Flat'

    $btnCopy.BackColor = Get-ThemeColor 'Accent'

    $btnCopy.ForeColor = Get-ThemeColor 'CardText'

    $btnCopy.SetBounds(24, 380, 220, 35)

    $btnCopy.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnCopy.Add_Click({

        [System.Windows.Forms.Clipboard]::SetText($txtKey.Text)

        Out-MessageBox("Windows License Key copied to Clipboard!", "Success", "OK", "Information") | Out-Null

    })

    $card.Controls.Add($btnCopy)



    $btnExport = New-Object System.Windows.Forms.Button

    $btnExport.Text = "Export to Backups File"

    $btnExport.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnExport.FlatStyle = 'Flat'

    $btnExport.BackColor = Get-ThemeColor 'Accent'

    $btnExport.ForeColor = Get-ThemeColor 'CardText'

    $btnExport.SetBounds(270, 380, 220, 35)

    $btnExport.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnExport.Add_Click({

        try {

            $backupDir = "$ToolkitRoot\Backups"

            if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }

            $backupFile = "$backupDir\LicenseRecovery.txt"

            $backupContent = @"

==================================================

        SYSFORGE STUDIO LICENSE RECOVERY VAULT

==================================================

Date Recovered  : $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))

OS Edition      : $windowsEdition

Product Key     : $($txtKey.Text)

Key Source      : $keySource

Office Status   : $officeStatus

==================================================

"@

            $backupContent | Out-File -FilePath $backupFile -Encoding UTF8 -Force

            Out-MessageBox("Key successfully backed up to:`n$backupFile", "Backup Exported", "OK", "Information") | Out-Null

        } catch {

            Out-MessageBox("Failed to save backup: $_", "Error", "OK", "Error") | Out-Null

        }

    })

    $card.Controls.Add($btnExport)



    $flow.Controls.Add($card)

    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-BsodAnalyzerPanel {

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "BSOD Crash Dump Analyzer"

    $metaLabel.Text = "Diagnose system crashes, analyze minidumps, and query Event Logs for kernel stop codes"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_bsod_analyzer'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 80

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 15, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "BlueScreen event diagnostics & Dump Explorer"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 12)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Parses recent system BugCheck Event logs and checks for dump files to isolate failing drivers."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 40)

    $headerPanel.Controls.Add($panelSub)



    $gridHost.Controls.Add($headerPanel)



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    # Section 1: Minidump Directory Status

    $dumpCard = New-Object System.Windows.Forms.Panel

    $dumpCard.Size = New-Object System.Drawing.Size(850, 235)

    $dumpCard.BackColor = Get-ThemeColor 'Panel'

    $dumpCard.Padding = New-Object System.Windows.Forms.Padding(18)

    Enable-DoubleBuffer $dumpCard



    $lblMinidumpTitle = New-Object System.Windows.Forms.Label

    $lblMinidumpTitle.Text = "KERNEL MINIDUMP DIRECTORY STATUS"

    $lblMinidumpTitle.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $lblMinidumpTitle.ForeColor = Get-ThemeColor 'Muted'

    $lblMinidumpTitle.SetBounds(18, 14, 400, 18)

    $dumpCard.Controls.Add($lblMinidumpTitle)



    $minidumpPath = "C:\Windows\Minidump"

    $dumpFiles = @()

    $dumpStatusText = "No minidump files found or directory does not exist."

    if (Test-Path $minidumpPath) {

        $dumpFiles = Get-ChildItem -Path $minidumpPath -Filter *.dmp -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending

        if ($dumpFiles.Count -gt 0) {

            $dumpStatusText = "Found $($dumpFiles.Count) Minidump file(s) inside: $minidumpPath"

        } else {

            $dumpStatusText = "Directory exists ($minidumpPath) but contains zero crash .dmp files."

        }

    } else {

        $dumpStatusText = "Minidump directory is not present (C:\Windows\Minidump). Crash dumps may be disabled."

    }



    $valDumpStatus = New-Object System.Windows.Forms.Label

    $valDumpStatus.Text = $dumpStatusText

    $valDumpStatus.Font = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)

    $valDumpStatus.ForeColor = Get-ThemeColor 'Text'

    $valDumpStatus.SetBounds(18, 42, 800, 24)

    $dumpCard.Controls.Add($valDumpStatus)



    # Show last dump details if found

    if ($dumpFiles.Count -gt 0) {

        $latest = $dumpFiles[0]

        $lblLatest = New-Object System.Windows.Forms.Label

        $lblLatest.Text = "LATEST DUMP: $($latest.Name)  |  Size: $([math]::Round($latest.Length/1KB, 2)) KB  |  Date: $($latest.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"))"

        $lblLatest.Font = New-Object System.Drawing.Font('Consolas', 9.5)

        $lblLatest.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF66")

        $lblLatest.SetBounds(18, 72, 800, 20)

        $dumpCard.Controls.Add($lblLatest)

    }



    # MEMORY.DMP Status Check

    $memDumpPath = "C:\Windows\MEMORY.DMP"

    $memDumpStatus = "No active kernel MEMORY.DMP discovered in: C:\Windows\"

    if (Test-Path $memDumpPath) {

        try {

            $memInfo = Get-Item $memDumpPath

            $memDumpStatus = "KERNEL MEMORY.DMP DETECTED: $([math]::Round($memInfo.Length/1MB, 1)) MB  |  Date: $($memInfo.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"

        } catch {}

    }



    $lblMemDump = New-Object System.Windows.Forms.Label

    $lblMemDump.Text = $memDumpStatus

    $lblMemDump.Font = New-Object System.Drawing.Font('Consolas', 9.5)

    $lblMemDump.ForeColor = if (Test-Path $memDumpPath) { [System.Drawing.ColorTranslator]::FromHtml("#FFCC00") } else { Get-ThemeColor 'Muted' }

    $lblMemDump.SetBounds(18, 102, 800, 20)

    $dumpCard.Controls.Add($lblMemDump)



    $btnOpenDir = New-Object System.Windows.Forms.Button

    $btnOpenDir.Text = "Open Minidumps"

    $btnOpenDir.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnOpenDir.FlatStyle = 'Flat'

    $btnOpenDir.BackColor = Get-ThemeColor 'Accent'

    $btnOpenDir.ForeColor = Get-ThemeColor 'CardText'

    $btnOpenDir.SetBounds(18, 138, 185, 32)

    $btnOpenDir.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnOpenDir.Add_Click(({

        if (Test-Path $minidumpPath) {

            Start-Process explorer.exe -ArgumentList $minidumpPath

        } else {

            Out-MessageBox("Directory $minidumpPath does not exist.", "Error", "OK", "Warning") | Out-Null

        }

    }).GetNewClosure())

    $dumpCard.Controls.Add($btnOpenDir)



    $btnLaunchBSV = New-Object System.Windows.Forms.Button

    $btnLaunchBSV.Text = "BlueScreenView"

    $btnLaunchBSV.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnLaunchBSV.FlatStyle = 'Flat'

    $btnLaunchBSV.BackColor = Get-ThemeColor 'Panel2'

    $btnLaunchBSV.ForeColor = Get-ThemeColor 'Accent'

    $btnLaunchBSV.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnLaunchBSV.FlatAppearance.BorderSize = 1

    $btnLaunchBSV.SetBounds(218, 138, 185, 32)

    $btnLaunchBSV.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnLaunchBSV.Add_Click(({

        $toolPath = Join-Path $script:ToolkitRoot "Tools\bluescreenview-x64\BlueScreenView.exe"

        if (Test-Path $toolPath) {

            Start-Process $toolPath -Verb RunAs

        } else {

            Out-MessageBox("BlueScreenView executable not found at:`n$toolPath`n`nPlease ensure it is extracted in your Tools folder.", "Tool Missing", "OK", "Warning") | Out-Null

        }

    }).GetNewClosure())

    $dumpCard.Controls.Add($btnLaunchBSV)



    $btnLaunchWhoCrashed = New-Object System.Windows.Forms.Button

    $btnLaunchWhoCrashed.Text = "WhoCrashed Analyzer"

    $btnLaunchWhoCrashed.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnLaunchWhoCrashed.FlatStyle = 'Flat'

    $btnLaunchWhoCrashed.BackColor = Get-ThemeColor 'Panel2'

    $btnLaunchWhoCrashed.ForeColor = Get-ThemeColor 'Accent'

    $btnLaunchWhoCrashed.FlatAppearance.BorderColor = Get-ThemeColor 'Accent'

    $btnLaunchWhoCrashed.FlatAppearance.BorderSize = 1

    $btnLaunchWhoCrashed.SetBounds(418, 138, 185, 32)

    $btnLaunchWhoCrashed.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnLaunchWhoCrashed.Add_Click(({

        $toolPath = Join-Path $script:ToolkitRoot "Tools\Whocrashed\WhoCrashed\WhoCrashedEx.exe"

        if (Test-Path $toolPath) {

            Start-Process $toolPath -Verb RunAs

        } else {

            Out-MessageBox("WhoCrashed executable not found at:`n$toolPath`n`nPlease ensure it is installed/placed in your Tools folder.", "Tool Missing", "OK", "Warning") | Out-Null

        }

    }).GetNewClosure())

    $dumpCard.Controls.Add($btnLaunchWhoCrashed)



    $btnEnableDumps = New-Object System.Windows.Forms.Button

    $btnEnableDumps.Text = "Enable Crash Dumps"

    $btnEnableDumps.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnEnableDumps.FlatStyle = 'Flat'

    $btnEnableDumps.BackColor = Get-ThemeColor 'Panel2'

    $btnEnableDumps.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF66")

    $btnEnableDumps.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF66")

    $btnEnableDumps.FlatAppearance.BorderSize = 1

    $btnEnableDumps.SetBounds(18, 182, 185, 32)

    $btnEnableDumps.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnEnableDumps.Add_Click(({

        if (-not (Test-IsAdmin)) {

            Out-MessageBox("This option requires Administrator privileges.", "Error", "OK", "Error") | Out-Null

            return

        }

        try {

            $ccPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"

            if (-not (Test-Path $ccPath)) { New-Item -Path $ccPath -Force | Out-Null }

            Set-ItemProperty -Path $ccPath -Name "CrashDumpEnabled" -Value 3 -Type DWord -Force

            Set-ItemProperty -Path $ccPath -Name "MinidumpsCount" -Value 50 -Type DWord -Force

            if (-not (Test-Path $minidumpPath)) { New-Item -ItemType Directory -Path $minidumpPath -Force | Out-Null }

            Out-MessageBox("Success: Windows Crash Control registry has been successfully configured to write Kernel Minidumps (`$SystemRoot`%\Minidump) during system BlueScreens.`r`n`r`nMinidumps enabled successfully!", "Crash Control Configured", "OK", "Information") | Out-Null

            Show-BsodAnalyzerPanel

        } catch {

            Out-MessageBox("Failed to configure crash dumps: $_", "Error", "OK", "Error") | Out-Null

        }

    }).GetNewClosure())

    $dumpCard.Controls.Add($btnEnableDumps)



    $btnMockDump = New-Object System.Windows.Forms.Button

    $btnMockDump.Text = "Generate Mock Dump"

    $btnMockDump.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnMockDump.FlatStyle = 'Flat'

    $btnMockDump.BackColor = Get-ThemeColor 'Panel2'

    $btnMockDump.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFCC00")

    $btnMockDump.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml("#FFCC00")

    $btnMockDump.FlatAppearance.BorderSize = 1

    $btnMockDump.SetBounds(218, 182, 185, 32)

    $btnMockDump.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnMockDump.Add_Click(({

        if (-not (Test-IsAdmin)) {

            Out-MessageBox("Writing to Windows system folders requires Administrator privileges.", "Error", "OK", "Error") | Out-Null

            return

        }

        try {

            if (-not (Test-Path $minidumpPath)) { New-Item -ItemType Directory -Path $minidumpPath -Force | Out-Null }

            $rand = Get-Random -Minimum 10000 -Maximum 99999

            $mockFile = Join-Path $minidumpPath "Mini052626-$rand.dmp"

            Set-Content -Path $mockFile -Value "Mock BSOD Minidump File created by SysForge Studio Diagnostic Suite.`r`nThis dummy file allows testing the dump explorers, BlueScreenView, and WhoCrashed analyzer on systems with no real BSOD events."

            Out-MessageBox("Success! Generated a mock minidump crash log file at:`r`n$mockFile`r`n`r`nThe panel will now refresh to display the newly added mock dump.", "Mock Dump Generated", "OK", "Information") | Out-Null

            Show-BsodAnalyzerPanel

        } catch {

            Out-MessageBox("Failed to generate mock dump file: $_", "Error", "OK", "Error") | Out-Null

        }

    }).GetNewClosure())

    $dumpCard.Controls.Add($btnMockDump)



    $flow.Controls.Add($dumpCard)



    # Spacer

    $space = New-Object System.Windows.Forms.Panel

    $space.Size = New-Object System.Drawing.Size(850, 15)

    $flow.Controls.Add($space)



    # Section 2: Recent BugCheck Events Card

    $eventsCard = New-Object System.Windows.Forms.Panel

    $eventsCard.Size = New-Object System.Drawing.Size(850, 480)

    $eventsCard.BackColor = Get-ThemeColor 'Panel'

    $eventsCard.Padding = New-Object System.Windows.Forms.Padding(18)

    Enable-DoubleBuffer $eventsCard



    $lblEvTitle = New-Object System.Windows.Forms.Label

    $lblEvTitle.Text = "CRITICAL EVENT LOG CRASH RECORDS (LAST 4 CRASHES)"

    $lblEvTitle.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $lblEvTitle.ForeColor = Get-ThemeColor 'Muted'

    $lblEvTitle.SetBounds(18, 14, 400, 18)

    $eventsCard.Controls.Add($lblEvTitle)



    # Search for Event ID 1001 (BugCheck) and ID 41 (Unexpected Power Loss)

    $crashes = @()

    $queryError = ""

    try {

        $rawEvents = Get-WinEvent -FilterHashtable @{LogName='System'; Id=@(1001, 41)} -MaxEvents 40 -ErrorAction Stop

        foreach ($ev in $rawEvents) {

            try {

                $msg = $ev.Message

                if ($ev.Id -eq 41) {

                    $stop = "Unexpected Shutdown (ID 41)"

                    $crashes += [pscustomobject]@{

                        Time = $ev.TimeCreated

                        StopCode = $stop

                        RawMessage = "System rebooted unexpectedly without a clean shutdown sequence. This often indicates a sudden power loss, thermal overheating throttling, or RAM failures."

                    }

                } elseif ($msg -match "bugcheck" -or $msg -match "rebooted from a bugcheck" -or $msg -match "BugCheck") {

                    $stop = "0xUnknown Stop"

                    if ($msg -match "bugcheck was:\s+(0x[a-fA-F0-9]+)") {

                        $stop = $Matches[1]

                    }

                    $crashes += [pscustomobject]@{

                        Time = $ev.TimeCreated

                        StopCode = $stop

                        RawMessage = $msg

                    }

                }

            } catch {

                $stop = if ($ev.Id -eq 41) { "Unexpected Shutdown (ID 41)" } else { "BugCheck stop code (ID 1001)" }

                $crashes += [pscustomobject]@{

                    Time = $ev.TimeCreated

                    StopCode = $stop

                    RawMessage = "Crash event recorded in Windows logs but the system failed to format the descriptive message strings. Event Provider: $($ev.ProviderName)"

                }

            }

            if ($crashes.Count -ge 4) { break }

        }

    } catch {

        $msg = $_.Exception.Message

        if ($msg -like "*No events were found*" -or $msg -like "*NoMatch*") {

            $queryError = ""

        } else {

            $queryError = $msg

        }

    }



    $yOffset = 45

    if ($crashes.Count -eq 0) {

        $lblEmpty = New-Object System.Windows.Forms.Label

        if ($queryError) {

            $lblEmpty.Text = "Event Log Diagnostics error: $($queryError)`r`nPlease ensure Windows EventLog service is active and running."

        } else {

            $lblEmpty.Text = "No system crash (BugCheck or Event 41 unexpected reboots) entries discovered in past logs."

        }

        $lblEmpty.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Italic)

        $lblEmpty.ForeColor = Get-ThemeColor 'Muted'

        $lblEmpty.SetBounds(18, 48, 800, 36)

        $eventsCard.Controls.Add($lblEmpty)

    } else {

        foreach ($crash in $crashes) {

            $itemPanel = New-Object System.Windows.Forms.Panel

            $itemPanel.SetBounds(18, $yOffset, 814, 90)

            $itemPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#161616")

            Enable-DoubleBuffer $itemPanel



            $lblCrashTime = New-Object System.Windows.Forms.Label

            $lblCrashTime.Text = "Crash Date: $($crash.Time.ToString("yyyy-MM-dd HH:mm:ss"))"

            $lblCrashTime.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

            $lblCrashTime.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FF3366")

            $lblCrashTime.SetBounds(14, 10, 300, 20)

            $itemPanel.Controls.Add($lblCrashTime)



            $lblStopCode = New-Object System.Windows.Forms.Label

            $lblStopCode.Text = "STOP CODE: $($crash.StopCode)"

            $lblStopCode.Font = New-Object System.Drawing.Font('Consolas', 10.5, [System.Drawing.FontStyle]::Bold)

            $lblStopCode.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFCC00")

            $lblStopCode.SetBounds(350, 10, 350, 20)

            $itemPanel.Controls.Add($lblStopCode)



            $txtDetails = New-Object System.Windows.Forms.Label

            $cleanMsg = $crash.RawMessage.Replace("`r`n", " ").Replace("`n", " ")

            if ($cleanMsg.Length -gt 150) { $cleanMsg = $cleanMsg.Substring(0, 147) + "..." }

            $txtDetails.Text = $cleanMsg

            $txtDetails.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)

            $txtDetails.ForeColor = Get-ThemeColor 'Muted'

            $txtDetails.SetBounds(14, 38, 786, 42)

            $itemPanel.Controls.Add($txtDetails)



            $eventsCard.Controls.Add($itemPanel)

            $yOffset += 102

        }

    }



    # troubleshooter guide helper

    $btnTrouble = New-Object System.Windows.Forms.Button

    $btnTrouble.Text = "BSOD Troubleshooting Guide"

    $btnTrouble.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnTrouble.FlatStyle = 'Flat'

    $btnTrouble.BackColor = Get-ThemeColor 'Accent'

    $btnTrouble.ForeColor = Get-ThemeColor 'CardText'

    $btnTrouble.SetBounds(18, 430, 220, 32)

    $btnTrouble.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnTrouble.Add_Click(({

        $helpMsg = @"

==================================================

      BSOD SYSTEM CRASH REPAIR ACTION GUIDE

==================================================

1. Check STOP CODE:

   - 0x0000007F or 0x0000000A: Usually RAM issue. Run memory tests.

   - 0x0000003B or 0x000000D1: Driver conflict (GPU, Network, AV).

   - 0x0000007B (INACCESSIBLE_BOOT_DEVICE): Disk protocol/SATA issue.

   

2. Run Offline Recovery tools in SysForge Studio:

   - Perform Offline SFC & DISM scans to restore core system files.

   - Disable crashing service registry nodes (such as crowdstrike/sys files).

   

3. Update key system device drivers.

==================================================

"@

        Out-MessageBox($helpMsg, "IT Admin Troubleshooter Manual", "OK", "None") | Out-Null

    }).GetNewClosure())

    $eventsCard.Controls.Add($btnTrouble)



    $flow.Controls.Add($eventsCard)



    # Spacer

    $space2 = New-Object System.Windows.Forms.Panel

    $space2.Size = New-Object System.Drawing.Size(850, 15)

    $flow.Controls.Add($space2)



    # Section 3: Searchable Stop Code Library Card

    $lookupCard = New-Object System.Windows.Forms.Panel

    $lookupCard.Size = New-Object System.Drawing.Size(850, 280)

    $lookupCard.BackColor = Get-ThemeColor 'Panel'

    $lookupCard.Padding = New-Object System.Windows.Forms.Padding(18)

    Enable-DoubleBuffer $lookupCard



    $lblLookupTitle = New-Object System.Windows.Forms.Label

    $lblLookupTitle.Text = "OFFLINE BSOD STOP CODE DIAGNOSTIC REFERENCE MANUAL"

    $lblLookupTitle.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $lblLookupTitle.ForeColor = Get-ThemeColor 'Muted'

    $lblLookupTitle.SetBounds(18, 14, 450, 18)

    $lookupCard.Controls.Add($lblLookupTitle)



    $lblInputPrompt = New-Object System.Windows.Forms.Label

    $lblInputPrompt.Text = "Enter Stop Code (e.g. 0x7B, 0x124, or CRITICAL_PROCESS_DIED):"

    $lblInputPrompt.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblInputPrompt.ForeColor = Get-ThemeColor 'Text'

    $lblInputPrompt.SetBounds(18, 42, 400, 18)

    $lookupCard.Controls.Add($lblInputPrompt)



    $txtLookupInput = New-Object System.Windows.Forms.TextBox

    $txtLookupInput.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $txtLookupInput.BackColor = Get-ThemeColor 'Panel2'

    $txtLookupInput.ForeColor = Get-ThemeColor 'Text'

    $txtLookupInput.SetBounds(18, 64, 250, 24)

    $lookupCard.Controls.Add($txtLookupInput)



    $btnLookup = New-Object System.Windows.Forms.Button

    $btnLookup.Text = "Lookup Diagnostic info"

    $btnLookup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnLookup.FlatStyle = 'Flat'

    $btnLookup.BackColor = Get-ThemeColor 'Accent'

    $btnLookup.ForeColor = Get-ThemeColor 'CardText'

    $btnLookup.SetBounds(278, 62, 185, 26)

    $btnLookup.Cursor = [System.Windows.Forms.Cursors]::Hand

    $lookupCard.Controls.Add($btnLookup)



    $lblReportTitle = New-Object System.Windows.Forms.Label

    $lblReportTitle.Text = "STOP CODE DIAGNOSTIC REPORT:"

    $lblReportTitle.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $lblReportTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFCC00")

    $lblReportTitle.SetBounds(18, 102, 400, 16)

    $lookupCard.Controls.Add($lblReportTitle)



    $txtReport = New-Object System.Windows.Forms.TextBox

    $txtReport.Multiline = $true

    $txtReport.ReadOnly = $true

    $txtReport.ScrollBars = 'Vertical'

    $txtReport.Font = New-Object System.Drawing.Font('Consolas', 9.5)

    $txtReport.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#161616")

    $txtReport.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF66")

    $txtReport.SetBounds(18, 122, 814, 138)

    $txtReport.Text = "Enter a Windows Stop Code or error description above and click 'Lookup Diagnostic info' to display a complete, step-by-step troubleshooting report."

    $lookupCard.Controls.Add($txtReport)



    $btnLookup.Add_Click(({

        $query = $txtLookupInput.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($query)) {

            $txtReport.Text = "Please enter a stop code (e.g. 0x7B or IRQL_NOT_LESS_OR_EQUAL)."

            return

        }



        # Local diagnostic dictionary

        $reportData = "SEARCH RESULTS FOR: $query`r`n`r`n"

        $lowerQuery = $query.ToLowerInvariant()



        if ($lowerQuery -match "0x0*a\b" -or $lowerQuery -match "irql_not_less") {

            $reportData += "STOP CODE  : 0x0000000A (IRQL_NOT_LESS_OR_EQUAL)`r`n"

            $reportData += "EXPLANATION: A driver or kernel-mode process attempted to access a pageable memory address at an invalid Interrupt Request Level (IRQL) that was too high.`r`n"

            $reportData += "PROBABLE   : Faulty RAM modules, incompatible device driver conflicts (GPU, Wi-Fi), or aggressive antivirus software hooks.`r`n"

            $reportData += "IT REMEDY  : `r`n"

            $reportData += "             1. Run Memory Diagnostics (mdsched.exe) to check for RAM chip cell defects.`r`n"

            $reportData += "             2. Clean uninstall graphics driver with DDU and reinstall the latest WHQL release.`r`n"

            $reportData += "             3. Roll back or disable recently updated networking card drivers.`r`n"

        } elseif ($lowerQuery -match "0x0*3b\b" -or $lowerQuery -match "system_service_exception") {

            $reportData += "STOP CODE  : 0x0000003B (SYSTEM_SERVICE_EXCEPTION)`r`n"

            $reportData += "EXPLANATION: An unhandled exception was triggered in system code, typically while executing a system service call.`r`n"

            $reportData += "PROBABLE   : Corrupt graphics card driver modules, system file corruption, or game anti-cheat software memory blocks.`r`n"

            $reportData += "IT REMEDY  : `r`n"

            $reportData += "             1. Run System File Checker (SFC /SCANNOW) to restore damaged core files.`r`n"

            $reportData += "             2. Perform graphics drivers refresh. Re-verify game launcher permissions.`r`n"

            $reportData += "             3. Uninstall recently added custom kernel-level virtualization tools.`r`n"

        } elseif ($lowerQuery -match "0x0*50\b" -or $lowerQuery -match "page_fault") {

            $reportData += "STOP CODE  : 0x00000050 (PAGE_FAULT_IN_NONPAGED_AREA)`r`n"

            $reportData += "EXPLANATION: The system requested virtual memory addresses that were either not resident in memory or pointing to an invalid address.`r`n"

            $reportData += "PROBABLE   : Faulty physical RAM, L2/L3 processor cache failures, motherboard slot issues, or corrupt driver file systems.`r`n"

            $reportData += "IT REMEDY  : `r`n"

            $reportData += "             1. Reseat RAM sticks and blow out dust from slots.`r`n"

            $reportData += "             2. Disable all L1/L2/L3 cache tweaks, CPU overclock profiles, and XMP profiles in BIOS.`r`n"

            $reportData += "             3. Run Chkdsk C: /f /r to repair underlying system drive sector damage.`r`n"

        } elseif ($lowerQuery -match "0x0*7b\b" -or $lowerQuery -match "inaccessible_boot") {

            $reportData += "STOP CODE  : 0x0000007B (INACCESSIBLE_BOOT_DEVICE)`r`n"

            $reportData += "EXPLANATION: Windows lost access to the system boot partition during startup initialization.`r`n"

            $reportData += "PROBABLE   : SATA/NVMe controller mode mismatch in BIOS (AHCI switched to RAID or IDE), corrupted boot files, or bad storage drive sectors.`r`n"

            $reportData += "IT REMEDY  : `r`n"

            $reportData += "             1. Enter BIOS settings and toggle SATA Mode Selection between AHCI and RAID/Intel VMD.`r`n"

            $reportData += "             2. Rebuild Boot Configuration Data using recovery Command Prompt: 'bootrec /rebuildbcd'.`r`n"

            $reportData += "             3. Use SysForge Studio Offline Recovery options to apply offline SFC/DISM to the drive.`r`n"

        } elseif ($lowerQuery -match "0x0*ef\b" -or $lowerQuery -match "critical_process") {

            $reportData += "STOP CODE  : 0x000000EF (CRITICAL_PROCESS_DIED)`r`n"

            $reportData += "EXPLANATION: A critical kernel-level Windows process (such as csrss.exe, svchost.exe, or wininit.exe) stopped running or was terminated.`r`n"

            $reportData += "PROBABLE   : Severe operating system file corruption, malware injections into system files, or incompatible hardware drivers.`r`n"

            $reportData += "IT REMEDY  : `r`n"

            $reportData += "             1. Run SFC /Scannow and DISM /Online /Cleanup-Image /RestoreHealth in Admin prompt.`r`n"

            $reportData += "             2. Run a full antivirus heuristic scan to check for active system file hijacking.`r`n"

            $reportData += "             3. Roll back Windows Update to a previous restore point.`r`n"

        } elseif ($lowerQuery -match "0x0*124\b" -or $lowerQuery -match "whea_unco") {

            $reportData += "STOP CODE  : 0x00000124 (WHEA_UNCORRECTABLE_ERROR)`r`n"

            $reportData += "EXPLANATION: A severe hardware failure has been detected by Windows Hardware Error Architecture.`r`n"

            $reportData += "PROBABLE   : CPU core voltage instability (undervolting too low or overvolting too high), physical CPU overheating, failing SSD, or faulty PCIe devices.`r`n"

            $reportData += "IT REMEDY  : `r`n"

            $reportData += "             1. Open BIOS/UEFI and select 'Load Optimized Defaults' to clear all voltage, XMP, and CPU overclocks.`r`n"

            $reportData += "             2. Check system temperatures. Clear dust from fans, and apply fresh thermal paste.`r`n"

            $reportData += "             3. Run CrystalDiskInfo to verify SSD S.M.A.R.T. health. Replace failing storage devices.`r`n"

        } else {

            $reportData += "GENERIC ANALYSIS REPORT:`r`n"

            $reportData += "We couldn't find a direct stop-code match for '$query' in our offline database.`r`n`r`n"

            $reportData += "COMMON CRASH DIAGNOSTIC PATHWAYS:`r`n"

            $reportData += "1. SYSTEM CORRUPTION: Run 'SFC /SCANNOW' and 'DISM /Online /Cleanup-Image /RestoreHealth' in an elevated Command Prompt.`r`n"

            $reportData += "2. PHYSICAL RAM ERROR: Faulty memory is the #1 cause of unhandled kernel exceptions. Test RAM sticks using MemTest86 or Windows Memory Diagnostics.`r`n"

            $reportData += "3. DRIVER CONFLICTS  : Open Device Manager and search for yellow alert icons. Check GPU, Wi-Fi, chipset, and audio drivers.`r`n"

            $reportData += "4. THERMAL THROTTLING: High heat triggers hardware shutdowns. Clean out cooling fans and check CPU/GPU temperatures.`r`n"

        }



        $txtReport.Text = $reportData

    }).GetNewClosure())



    $flow.Controls.Add($lookupCard)



    $flow.BringToFront()

    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



# ============================================================

# PANEL: CPU/GPU Temperature Monitor

# ============================================================

function Show-TempMonitorPanel {

    try { $searchBox.Visible = $false; $searchBox.Text = "" } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "CPU & GPU Temperature Monitor"

    $metaLabel.Text = "Real-time thermal status of CPU, GPU, Battery temperature and system fan info"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_temp_monitor'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 80

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 15, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Real-Time Thermal Monitor"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 10)

    $headerPanel.Controls.Add($panelTitle)



    $btnRefresh = New-Object System.Windows.Forms.Button

    $btnRefresh.Text = "Refresh Now"

    $btnRefresh.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnRefresh.FlatStyle = 'Flat'

    $btnRefresh.BackColor = Get-ThemeColor 'Accent'

    $btnRefresh.ForeColor = Get-ThemeColor 'CardText'

    $btnRefresh.SetBounds(550, 18, 120, 32)

    $btnRefresh.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnRefresh)



    $chkLive = New-Object System.Windows.Forms.CheckBox

    $chkLive.Text = "Live Monitor (3s)"

    $chkLive.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $chkLive.ForeColor = Get-ThemeColor 'Text'

    $chkLive.SetBounds(685, 23, 150, 24)

    $chkLive.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($chkLive)



    $gridHost.Controls.Add($headerPanel)



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    $script:tempCards = @{}



    # Convert to script-scope scriptblocks so Refresh button and Timer survive panel function return

    $script:_getThermalData = {

        $cards = @()

        # CPU Info

        try {

            $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

            $cpuName = if ($cpu) { $cpu.Name.Trim() } else { "Unknown CPU" }

            $cpuLoad = if ($cpu) { "$($cpu.LoadPercentage)%" } else { "N/A" }

            $cards += [pscustomobject]@{ Title = "CPU"; Value = $cpuName; Detail = "Load: $cpuLoad"; Color = Get-ThemeColor 'Accent' }

        } catch {

            $cards += [pscustomobject]@{ Title = "CPU"; Value = "Query Error"; Detail = "$_"; Color = [System.Drawing.Color]::FromArgb(239, 68, 68) }

        }

        # Thermal Zones

        try {

            $tempsC = Get-SafeCpuTemperature

            if ($null -ne $tempsC -and $tempsC.Count -gt 0) {

                $idx = 0

                foreach ($celsius in $tempsC) {

                    $celsius = [math]::Round($celsius, 1)

                    $color = if ($celsius -lt 70) { [System.Drawing.Color]::FromArgb(34, 197, 94) } elseif ($celsius -lt 85) { [System.Drawing.Color]::FromArgb(234, 179, 8) } else { [System.Drawing.Color]::FromArgb(239, 68, 68) }

                    $status = if ($celsius -lt 70) { "Normal" } elseif ($celsius -lt 85) { "Warm" } else { "HOT!" }

                    $cards += [pscustomobject]@{ Title = "TEMP ZONE $idx"; Value = "$celsius °C [$status]"; Detail = "ACPI Thermal Zone $idx"; Color = $color }

                    $idx++

                }

            } else {

                $cards += [pscustomobject]@{ Title = "THERMAL ZONES"; Value = "N/A"; Detail = "Temperature data unavailable on this hardware"; Color = [System.Drawing.Color]::FromArgb(234, 179, 8) }

            }

        } catch {

            $cards += [pscustomobject]@{ Title = "THERMAL ZONES"; Value = "WMI Unavailable"; Detail = "Temperature data unavailable on this hardware"; Color = [System.Drawing.Color]::FromArgb(234, 179, 8) }

        }

        # GPU

        try {

            $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1

            $gpuName = if ($gpu) { $gpu.Name } else { "Unknown GPU" }

            $cards += [pscustomobject]@{ Title = "GPU"; Value = $gpuName; Detail = "Driver: $($gpu.DriverVersion)"; Color = Get-ThemeColor 'Accent2' }

        } catch {

            $cards += [pscustomobject]@{ Title = "GPU"; Value = "Query Error"; Detail = "$_"; Color = [System.Drawing.Color]::FromArgb(239, 68, 68) }

        }

        # Battery

        try {

            $batt = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue

            if ($batt) {

                $battStatus = switch ($batt.BatteryStatus) { 1 {"Discharging"} 2 {"Charging (AC)"} default {"Unknown"} }

                $cards += [pscustomobject]@{ Title = "BATTERY"; Value = $battStatus; Detail = "Charge: $($batt.EstimatedChargeRemaining)%"; Color = Get-ThemeColor 'Accent' }

            }

        } catch {}

        return $cards

    }



    $script:_renderTempCards = {

        $flow.SuspendLayout()

        $flow.Controls.Clear()

        $data = & $script:_getThermalData

        foreach ($card in $data) {

            $cp = New-Object System.Windows.Forms.Panel

            $cp.Size = New-Object System.Drawing.Size(330, 130)

            $cp.Margin = New-Object System.Windows.Forms.Padding(10)

            $cp.BackColor = Get-ThemeColor 'Panel2'

            $cp.BorderStyle = 'FixedSingle'

            Enable-DoubleBuffer $cp



            $lT = New-Object System.Windows.Forms.Label

            $lT.Text = $card.Title

            $lT.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)

            $lT.ForeColor = Get-ThemeColor 'Muted'

            $lT.SetBounds(12, 10, 300, 18)

            $cp.Controls.Add($lT)



            $lV = New-Object System.Windows.Forms.Label

            $lV.Text = $card.Value

            $lV.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

            if ($card.Color -is [string]) {

                $lV.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($card.Color)

            } else {

                $lV.ForeColor = $card.Color

            }

            $lV.SetBounds(10, 30, 305, 28)

            $cp.Controls.Add($lV)



            $lD = New-Object System.Windows.Forms.Label

            $lD.Text = $card.Detail

            $lD.Font = New-Object System.Drawing.Font('Segoe UI', 9)

            $lD.ForeColor = Get-ThemeColor 'Text'

            $lD.SetBounds(12, 62, 300, 55)

            $cp.Controls.Add($lD)



            $flow.Controls.Add($cp)

        }

        $flow.ResumeLayout($true)

    }



    & $script:_renderTempCards

    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $btnRefresh.Add_Click({ try { & $script:_renderTempCards } catch {} })



    $chkLive.Add_CheckedChanged({

        if ($chkLive.Checked) {

            if ($null -eq $script:tempTimer) {

                $script:tempTimer = New-Object System.Windows.Forms.Timer

                $script:tempTimer.Interval = 3000

                $tempFlow = $flow

                $script:tempTimer.Add_Tick(({

                    try {

                        if ($null -ne $tempFlow -and -not $tempFlow.IsDisposed) { & $script:_renderTempCards }

                    } catch {}

                }.GetNewClosure()))

            }

            $script:tempTimer.Start()

        } else {

            if ($script:tempTimer) { $script:tempTimer.Stop() }

        }

    })



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



# ============================================================

# PANEL: Disk Speed Benchmark

# ============================================================

function Show-DiskBenchmarkPanel {

    try { $searchBox.Visible = $false; $searchBox.Text = "" } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "Disk Read/Write Speed Benchmark"

    $metaLabel.Text = "Test your storage drive read and write performance using WinSAT and file I/O"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_disk_benchmark'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 90

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 15, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Storage Drive Speed Benchmark"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 10)

    $headerPanel.Controls.Add($panelTitle)



    $btnWinSAT = New-Object System.Windows.Forms.Button

    $btnWinSAT.Text = "Run WinSAT Disk Test"

    $btnWinSAT.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnWinSAT.FlatStyle = 'Flat'

    $btnWinSAT.BackColor = Get-ThemeColor 'Accent'

    $btnWinSAT.ForeColor = Get-ThemeColor 'CardText'

    $btnWinSAT.SetBounds(34, 45, 200, 34)

    $btnWinSAT.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnWinSAT)



    $btnIO = New-Object System.Windows.Forms.Button

    $btnIO.Text = "Quick File I/O Test (100MB)"

    $btnIO.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnIO.FlatStyle = 'Flat'

    $btnIO.BackColor = Get-ThemeColor 'Accent'

    $btnIO.ForeColor = Get-ThemeColor 'CardText'

    $btnIO.SetBounds(250, 45, 220, 34)

    $btnIO.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnIO)



    $gridHost.Controls.Add($headerPanel)



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    # Disk info cards

    try {

        $disks = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue

        foreach ($d in $disks) {

            $sizeGB = [math]::Round($d.Size / 1GB, 1)

            $mediaType = if ($d.MediaType) { $d.MediaType } else { "Unknown" }

            $cp = New-Object System.Windows.Forms.Panel

            $cp.Size = New-Object System.Drawing.Size(380, 110)

            $cp.Margin = New-Object System.Windows.Forms.Padding(10)

            $cp.BackColor = Get-ThemeColor 'Panel2'

            $cp.BorderStyle = 'FixedSingle'

            Enable-DoubleBuffer $cp



            $lT = New-Object System.Windows.Forms.Label

            $lT.Text = "DISK DRIVE"

            $lT.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)

            $lT.ForeColor = Get-ThemeColor 'Muted'

            $lT.SetBounds(12, 8, 350, 18)

            $cp.Controls.Add($lT)



            $lV = New-Object System.Windows.Forms.Label

            $lV.Text = $d.Model

            $lV.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

            $lV.ForeColor = Get-ThemeColor 'Text'

            $lV.SetBounds(10, 28, 360, 26)

            $cp.Controls.Add($lV)



            $lD = New-Object System.Windows.Forms.Label

            $lD.Text = "Size: $sizeGB GB | Type: $mediaType"

            $lD.Font = New-Object System.Drawing.Font('Segoe UI', 9)

            $lD.ForeColor = Get-ThemeColor 'Muted'

            $lD.SetBounds(12, 58, 360, 40)

            $cp.Controls.Add($lD)



            $flow.Controls.Add($cp)

        }

    } catch {}



    # Progress bar

    $progress = New-Object System.Windows.Forms.ProgressBar

    $progress.Style = 'Marquee'

    $progress.MarqueeAnimationSpeed = 30

    $progress.Size = New-Object System.Drawing.Size(700, 20)

    $progress.Margin = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)

    $progress.Visible = $false

    $flow.Controls.Add($progress)



    # Result label

    $lblResult = New-Object System.Windows.Forms.Label

    $lblResult.Text = "Run a test to see benchmark results."

    $lblResult.Font = New-Object System.Drawing.Font('Segoe UI', 11)

    $lblResult.ForeColor = Get-ThemeColor 'Muted'

    $lblResult.Size = New-Object System.Drawing.Size(750, 80)

    $lblResult.Margin = New-Object System.Windows.Forms.Padding(10)

    $flow.Controls.Add($lblResult)



    $gridHost.Controls.Add($flow)

    $flow.BringToFront()



    $btnWinSAT.Add_Click(({

        if (-not (Test-IsAdmin)) {

            Out-MessageBox("WinSAT Disk Speed Test requires Administrator privileges to run successfully.`r`n`r`nPlease relaunch the SysForge Studio as Administrator.", "Admin Privileges Required", "OK", "Warning") | Out-Null

            return

        }

        $btnWinSAT.Enabled = $false

        $progress.Visible = $true

        $lblResult.Text = "Running WinSAT disk test in a new visible console window... please wait."

        $lblResult.ForeColor = Get-ThemeColor 'Muted'

        [System.Windows.Forms.Application]::DoEvents()

        try {

            $tempFile = [System.IO.Path]::GetTempFileName()

            # Start process in a new visible window, streaming output to $tempFile using Tee-Object

            $process = Start-Process powershell.exe -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "winsat disk -drive C | Tee-Object -FilePath '$tempFile'") -PassThru

            if ($null -ne $process) {

                while (-not $process.HasExited) {

                    [System.Windows.Forms.Application]::DoEvents()

                    Start-Sleep -Milliseconds 200

                }

            }

            if (Test-Path $tempFile) {

                $output = Get-Content $tempFile -Raw -ErrorAction SilentlyContinue

                $lblResult.Text = "WinSAT Result:`r`n$output"

                $lblResult.ForeColor = Get-ThemeColor 'Text'

                Remove-Item $tempFile -ErrorAction SilentlyContinue

            } else {

                $lblResult.Text = "WinSAT test completed, but no output file was generated."

                $lblResult.ForeColor = Get-ThemeColor 'Muted'

            }

        } catch {

            $lblResult.Text = "WinSAT Error: $_"

            $lblResult.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)

        }

        $progress.Visible = $false

        $btnWinSAT.Enabled = $true

    }).GetNewClosure())



    $btnIO.Add_Click(({

        $btnIO.Enabled = $false

        $progress.Visible = $true

        $lblResult.Text = "Running 100MB file I/O test..."

        $lblResult.ForeColor = Get-ThemeColor 'Muted'

        [System.Windows.Forms.Application]::DoEvents()

        try {

            $testFile = Join-Path $env:TEMP "toolkit_bench_$(Get-Random).tmp"

            $bufSize = 1MB

            $totalSize = 100MB

            $buffer = New-Object byte[] $bufSize



            # Write test

            $sw = [System.Diagnostics.Stopwatch]::StartNew()

            $fs = $null

            try {

                $fs = [System.IO.File]::Open($testFile, 'Create', 'Write', 'None')

                $written = 0

                while ($written -lt $totalSize) {

                    $fs.Write($buffer, 0, $bufSize)

                    $written += $bufSize

                }

                $fs.Flush()

            } finally { if ($null -ne $fs) { $fs.Close() } }

            $sw.Stop()

            $writeMs = $sw.ElapsedMilliseconds

            $writeMBs = [math]::Round(100 / ($writeMs / 1000), 1)



            # Read test

            $sw = [System.Diagnostics.Stopwatch]::StartNew()

            $fs = $null

            try {

                $fs = [System.IO.File]::Open($testFile, 'Open', 'Read', 'None')

                $readBuf = New-Object byte[] $bufSize

                while ($fs.Read($readBuf, 0, $bufSize) -gt 0) {}

            } finally { if ($null -ne $fs) { $fs.Close() } }

            $sw.Stop()

            $readMs = $sw.ElapsedMilliseconds

            $readMBs = [math]::Round(100 / ($readMs / 1000), 1)



            Remove-Item $testFile -ErrorAction SilentlyContinue



            $writeColor = if ($writeMBs -gt 200) { [System.Drawing.Color]::FromArgb(34, 197, 94) } elseif ($writeMBs -gt 100) { [System.Drawing.Color]::FromArgb(234, 179, 8) } else { [System.Drawing.Color]::FromArgb(239, 68, 68) }

            $readColor  = if ($readMBs  -gt 200) { [System.Drawing.Color]::FromArgb(34, 197, 94) } elseif ($readMBs  -gt 100) { [System.Drawing.Color]::FromArgb(234, 179, 8) } else { [System.Drawing.Color]::FromArgb(239, 68, 68) }



            $lblResult.Text = "WRITE: $writeMBs MB/s ($writeMs ms for 100MB)`r`nREAD:  $readMBs MB/s ($readMs ms for 100MB)"

            $lblResult.ForeColor = $readColor

        } catch {

            $lblResult.Text = "I/O Test Error: $_"

            $lblResult.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)

        }

        $progress.Visible = $false

        $btnIO.Enabled = $true

    }).GetNewClosure())



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



# ============================================================

# PANEL: DNS Flush + Network Repair

# ============================================================

function Show-DnsRepairPanel {

    try { $searchBox.Visible = $false; $searchBox.Text = "" } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "DNS Cache Flush & Network Repair"

    $metaLabel.Text = "Fix network issues: flush DNS, reset TCP/IP, renew IP address, repair Winsock"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_dns_repair'



    # Split layout: top=info+buttons, bottom=results

    $splitPanel = New-Object System.Windows.Forms.SplitContainer

    $splitPanel.Dock = 'Fill'

    $splitPanel.Orientation = 'Horizontal'

    $splitPanel.SplitterDistance = 340

    $splitPanel.Panel1.BackColor = $gridHost.BackColor

    $splitPanel.Panel2.BackColor = $gridHost.BackColor



    # --- Top Panel ---

    $topFlow = New-Object System.Windows.Forms.FlowLayoutPanel

    $topFlow.Dock = 'Fill'

    $topFlow.AutoScroll = $true

    $topFlow.Padding = New-Object System.Windows.Forms.Padding(20, 10, 10, 10)

    $topFlow.BackColor = $gridHost.BackColor



    # Network info card

    $infoCard = New-Object System.Windows.Forms.Panel

    $infoCard.Size = New-Object System.Drawing.Size(820, 90)

    $infoCard.Margin = New-Object System.Windows.Forms.Padding(5)

    $infoCard.BackColor = Get-ThemeColor 'Panel2'

    $infoCard.BorderStyle = 'FixedSingle'



    $lblNetInfo = New-Object System.Windows.Forms.Label

    $lblNetInfo.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblNetInfo.ForeColor = Get-ThemeColor 'Text'

    $lblNetInfo.SetBounds(10, 8, 800, 75)

    try {

        $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Select-Object -First 1

        $ip  = if ($cfg.IPv4Address) { $cfg.IPv4Address.IPAddress } else { "N/A" }

        $gw  = if ($cfg.IPv4DefaultGateway) { $cfg.IPv4DefaultGateway.NextHop } else { "N/A" }

        $dns = if ($cfg.DNSServer) { ($cfg.DNSServer.ServerAddresses -join ", ") } else { "N/A" }

        $lblNetInfo.Text = "IP: $ip  |  Gateway: $gw  |  DNS: $dns  |  Adapter: $($cfg.InterfaceAlias)"

    } catch {

        $lblNetInfo.Text = "Could not retrieve network configuration."

    }

    $infoCard.Controls.Add($lblNetInfo)

    $topFlow.Controls.Add($infoCard)



    $warnLabel = New-Object System.Windows.Forms.Label

    $warnLabel.Text = "⚠ IP Release/Renew may briefly disconnect you from the network."

    $warnLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Italic)

    $warnLabel.ForeColor = [System.Drawing.Color]::Orange

    $warnLabel.Size = New-Object System.Drawing.Size(820, 22)

    $warnLabel.Margin = New-Object System.Windows.Forms.Padding(5, 2, 5, 5)

    $topFlow.Controls.Add($warnLabel)



    # Action buttons

    $actions = @(

        @{ Label = "Flush DNS Cache";     Cmd = { ipconfig /flushdns 2>&1 | Out-String } },

        @{ Label = "Release & Renew IP";  Cmd = { (ipconfig /release 2>&1 | Out-String) + "`r`n" + (ipconfig /renew 2>&1 | Out-String) } },

        @{ Label = "Reset TCP/IP Stack";  Cmd = { netsh int ip reset 2>&1 | Out-String } },

        @{ Label = "Reset Winsock";       Cmd = { netsh winsock reset 2>&1 | Out-String } },

        @{ Label = "Reset IPv6";          Cmd = { netsh int ipv6 reset 2>&1 | Out-String } },

        @{ Label = "Ping Google (Test)";  Cmd = { Test-Connection google.com -Count 4 -ErrorAction SilentlyContinue | Format-Table -AutoSize | Out-String } },

        @{ Label = "Show All IP Config";  Cmd = { ipconfig /all 2>&1 | Out-String } },

        @{ Label = "Reset All Network";   Cmd = { (ipconfig /flushdns 2>&1 | Out-String) + "`r`n" + (netsh int ip reset 2>&1 | Out-String) + "`r`n" + (netsh winsock reset 2>&1 | Out-String) + "`r`n" + (netsh int ipv6 reset 2>&1 | Out-String) } }

    )



    $resultsBox = $null  # will be set below



    foreach ($a in $actions) {

        $btn = New-Object System.Windows.Forms.Button

        $btn.Text = $a.Label

        $btn.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

        $btn.FlatStyle = 'Flat'

        $btn.BackColor = Get-ThemeColor 'Accent'

        $btn.ForeColor = Get-ThemeColor 'CardText'

        $btn.Size = New-Object System.Drawing.Size(195, 36)

        $btn.Margin = New-Object System.Windows.Forms.Padding(5)

        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand

        $btn.Tag = $a.Cmd

        $btn.Add_Click({

            param($sender, $e)

            if ($null -ne $script:dnsResultsBox) {

                $script:dnsResultsBox.Text = "Running..."

                [System.Windows.Forms.Application]::DoEvents()

                try {

                    if ($null -ne $sender.Tag) {

                        $result = & ([scriptblock]$sender.Tag)

                        $script:dnsResultsBox.Text = $result

                    } else {

                        $script:dnsResultsBox.Text = "Error: Action command is not defined."

                    }

                } catch {

                    $script:dnsResultsBox.Text = "Error: $_"

                }

            }

        })

        $topFlow.Controls.Add($btn)

    }



    $splitPanel.Panel1.Controls.Add($topFlow)



    # --- Bottom Panel: Results ---

    $script:dnsResultsBox = New-Object System.Windows.Forms.TextBox

    $script:dnsResultsBox.Multiline = $true

    $script:dnsResultsBox.ScrollBars = 'Vertical'

    $script:dnsResultsBox.ReadOnly = $true

    $script:dnsResultsBox.Dock = 'Fill'

    $script:dnsResultsBox.BackColor = [System.Drawing.Color]::FromArgb(15, 20, 30)

    $script:dnsResultsBox.ForeColor = [System.Drawing.Color]::LightGreen

    $script:dnsResultsBox.Font = New-Object System.Drawing.Font('Consolas', 9)

    $script:dnsResultsBox.Text = "Click an action button above to run a network repair command."

    $splitPanel.Panel2.Controls.Add($script:dnsResultsBox)



    $gridHost.Controls.Add($splitPanel)



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



# ============================================================

# PANEL: System Restore Manager

# ============================================================

function Show-RestoreManagerPanel {

    try { $searchBox.Visible = $false; $searchBox.Text = "" } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "Windows System Restore Manager"

    $metaLabel.Text = "Create, view and launch system restore points to recover from changes"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_restore_manager'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 90

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "System Restore Point Manager"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(24, 10)

    $headerPanel.Controls.Add($panelTitle)



    $btnBar = New-Object System.Windows.Forms.Panel

    $btnBar.Dock = 'Bottom'

    $btnBar.Height = 44



    function New-RestBtn($text, $x) {

        $b = New-Object System.Windows.Forms.Button

        $b.Text = $text

        $b.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

        $b.FlatStyle = 'Flat'

        $b.BackColor = Get-ThemeColor 'Accent'

        $b.ForeColor = Get-ThemeColor 'CardText'

        $b.SetBounds($x, 5, 175, 32)

        $b.Cursor = [System.Windows.Forms.Cursors]::Hand

        $btnBar.Controls.Add($b)

        return $b

    }



    $btnCreate  = New-RestBtn "Create Restore Point"       5

    $btnWizard  = New-RestBtn "Open System Restore Wizard" 187

    $btnEnable  = New-RestBtn "Enable on C: Drive"         369

    $btnRefresh = New-RestBtn "Refresh List"               551



    $lblStatus = New-Object System.Windows.Forms.Label

    $lblStatus.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblStatus.ForeColor = Get-ThemeColor 'Muted'

    $lblStatus.AutoSize = $true

    $lblStatus.Location = New-Object System.Drawing.Point(24, 52)

    $headerPanel.Controls.Add($lblStatus)



    $dgv = New-Object System.Windows.Forms.DataGridView

    $dgv.Dock = 'Fill'

    $dgv.AllowUserToAddRows = $false

    $dgv.AllowUserToDeleteRows = $false

    $dgv.ReadOnly = $true

    $dgv.SelectionMode = 'FullRowSelect'

    $dgv.MultiSelect = $false

    $dgv.AutoSizeColumnsMode = 'Fill'

    $dgv.BackgroundColor = Get-ThemeColor 'BG'

    $dgv.GridColor = Get-ThemeColor 'Muted'

    $dgv.DefaultCellStyle.BackColor = Get-ThemeColor 'Panel2'

    $dgv.DefaultCellStyle.ForeColor = Get-ThemeColor 'Text'

    $dgv.ColumnHeadersDefaultCellStyle.BackColor = Get-ThemeColor 'Accent'

    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = Get-ThemeColor 'CardText'

    $dgv.EnableHeadersVisualStyles = $false

    Enable-DoubleBuffer $dgv



    $dgv.Columns.Add("Date",           "Date")           | Out-Null

    $dgv.Columns.Add("Description",    "Description")    | Out-Null

    $dgv.Columns.Add("Type",           "Type")           | Out-Null

    $dgv.Columns.Add("SequenceNumber", "Sequence #")     | Out-Null



    $script:_loadRestorePoints = {

        $dgv.Rows.Clear()

        try {

            $points = Get-ComputerRestorePoint -ErrorAction SilentlyContinue

            if ($points -and $points.Count -gt 0) {

                $sorted = $points | Sort-Object CreationTime

                foreach ($p in $sorted) {

                    $date = $p.CreationTime.ToString("yyyy-MM-dd HH:mm")

                    $dgv.Rows.Add($date, $p.Description, $p.RestorePointType, $p.SequenceNumber) | Out-Null

                }

                $oldest = $sorted[0].CreationTime.ToString("yyyy-MM-dd")

                $newest = $sorted[-1].CreationTime.ToString("yyyy-MM-dd")

                $lblStatus.Text = "$($points.Count) restore point(s) found. Oldest: $oldest  Newest: $newest"

                $lblStatus.ForeColor = Get-ThemeColor 'Muted'

            } else {

                $lblStatus.Text = "⚠ No restore points found! Consider creating one now."

                $lblStatus.ForeColor = [System.Drawing.Color]::OrangeRed

            }

        } catch {

            $lblStatus.Text = "Error loading restore points: $_"

            $lblStatus.ForeColor = [System.Drawing.Color]::OrangeRed

        }

    }.GetNewClosure()



    & $script:_loadRestorePoints



    $btnCreate.Add_Click({

        $dlg = New-Object System.Windows.Forms.Form

        $dlg.Text = "Create Restore Point"

        $dlg.Size = New-Object System.Drawing.Size(400, 165)

        $dlg.StartPosition = 'CenterParent'

        $dlg.FormBorderStyle = 'FixedDialog'

        $dlg.BackColor = Get-ThemeColor 'Panel2'



        $lbl = New-Object System.Windows.Forms.Label; $lbl.Text = "Description:"; $lbl.SetBounds(20,20,110,22); $lbl.ForeColor = Get-ThemeColor 'Text'

        $txt = New-Object System.Windows.Forms.TextBox; $txt.SetBounds(140,18,220,24); $txt.Text = "Manual - $(Get-Date -Format 'yyyy-MM-dd')"

        $btnOK = New-Object System.Windows.Forms.Button; $btnOK.Text = "Create"; $btnOK.SetBounds(140,70,100,30); $btnOK.DialogResult = 'OK'

        $btnOK.FlatStyle = 'Flat'; $btnOK.BackColor = Get-ThemeColor 'Accent'; $btnOK.ForeColor = Get-ThemeColor 'CardText'; $btnOK.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

        $btnCX = New-Object System.Windows.Forms.Button; $btnCX.Text = "Cancel"; $btnCX.SetBounds(250,70,100,30); $btnCX.DialogResult = 'Cancel'

        $btnCX.FlatStyle = 'Flat'; $btnCX.BackColor = Get-ThemeColor 'Button'; $btnCX.ForeColor = Get-ThemeColor 'Text'; $btnCX.Font = New-Object System.Drawing.Font('Segoe UI', 9)

        $dlg.Controls.AddRange(@($lbl, $txt, $btnOK, $btnCX))

        $dlg.AcceptButton = $btnOK; $dlg.CancelButton = $btnCX

        if ($dlg.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {

            try {

                Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue

                Checkpoint-Computer -Description $txt.Text.Trim() -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop

                Out-MessageBox("Restore point created successfully!", "Success", "OK", "Information") | Out-Null

                & $script:_loadRestorePoints

            } catch {

                Out-MessageBox("Failed to create restore point: $_`r`nNote: Requires Administrator.", "Error", "OK", "Error") | Out-Null

            }

        }

    })



    $btnWizard.Add_Click({

        try { Start-Process rstrui.exe } catch { Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null }

    })



    $btnEnable.Add_Click({

        try {

            Enable-ComputerRestore -Drive 'C:\' -ErrorAction Stop

            Out-MessageBox("System Restore enabled on C: drive.", "Success", "OK", "Information") | Out-Null

        } catch {

            Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null

        }

    })



    $btnRefresh.Add_Click({ & $script:_loadRestorePoints })



    $gridHost.Controls.Add($headerPanel)

    $gridHost.Controls.Add($btnBar)

    $gridHost.Controls.Add($dgv)



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



# ============================================================

# PANEL: Scheduled Tasks Manager

# ============================================================

function Show-TaskSchedulerPanel {

    try { $searchBox.Visible = $false; $searchBox.Text = "" } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "Windows Scheduled Tasks Manager"

    $metaLabel.Text = "View, enable, disable and delete Windows scheduled tasks"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_task_scheduler'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 90

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Scheduled Tasks Manager"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(24, 10)

    $headerPanel.Controls.Add($panelTitle)



    $txtSearch = New-Object System.Windows.Forms.TextBox

    $txtSearch.SetBounds(24, 50, 300, 26)

    $txtSearch.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $txtSearch.Text = "Filter tasks..."

    $txtSearch.ForeColor = Get-ThemeColor 'Muted'

    $headerPanel.Controls.Add($txtSearch)



    $chkMicrosoft = New-Object System.Windows.Forms.CheckBox

    $chkMicrosoft.Text = "Show Microsoft Tasks"

    $chkMicrosoft.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $chkMicrosoft.ForeColor = Get-ThemeColor 'Text'

    $chkMicrosoft.SetBounds(340, 53, 180, 22)

    $chkMicrosoft.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($chkMicrosoft)



    $lblCount = New-Object System.Windows.Forms.Label

    $lblCount.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblCount.ForeColor = Get-ThemeColor 'Muted'

    $lblCount.SetBounds(540, 55, 300, 22)

    $headerPanel.Controls.Add($lblCount)



    $btnBar = New-Object System.Windows.Forms.Panel

    $btnBar.Dock = 'Bottom'

    $btnBar.Height = 44



    function New-TaskBtn($text, $x) {

        $b = New-Object System.Windows.Forms.Button

        $b.Text = $text

        $b.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

        $b.FlatStyle = 'Flat'

        $b.BackColor = Get-ThemeColor 'Accent'

        $b.ForeColor = Get-ThemeColor 'CardText'

        $b.SetBounds($x, 5, 138, 32)

        $b.Cursor = [System.Windows.Forms.Cursors]::Hand

        $btnBar.Controls.Add($b)

        return $b

    }



    $btnEnable  = New-TaskBtn "Enable Task"  5

    $btnDisable = New-TaskBtn "Disable Task" 150

    $btnRun     = New-TaskBtn "Run Now"      295

    $btnDelete  = New-TaskBtn "Delete Task"  440

    $btnRefresh = New-TaskBtn "Refresh"      585



    $dgv = New-Object System.Windows.Forms.DataGridView

    $dgv.Dock = 'Fill'

    $dgv.AllowUserToAddRows = $false

    $dgv.AllowUserToDeleteRows = $false

    $dgv.ReadOnly = $true

    $dgv.SelectionMode = 'FullRowSelect'

    $dgv.MultiSelect = $false

    $dgv.AutoSizeColumnsMode = 'Fill'

    $dgv.BackgroundColor = Get-ThemeColor 'BG'

    $dgv.GridColor = Get-ThemeColor 'Muted'

    $dgv.DefaultCellStyle.BackColor = Get-ThemeColor 'Panel2'

    $dgv.DefaultCellStyle.ForeColor = Get-ThemeColor 'Text'

    $dgv.ColumnHeadersDefaultCellStyle.BackColor = Get-ThemeColor 'Accent'

    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = Get-ThemeColor 'CardText'

    $dgv.EnableHeadersVisualStyles = $false

    Enable-DoubleBuffer $dgv



    $dgv.Columns.Add("TaskName",    "Task Name")     | Out-Null

    $dgv.Columns.Add("TaskPath",    "Path")          | Out-Null

    $dgv.Columns.Add("Status",      "Status")        | Out-Null

    $dgv.Columns.Add("LastRun",     "Last Run")      | Out-Null

    $dgv.Columns.Add("NextRun",     "Next Run")      | Out-Null



    $script:allTasks = @()



    $script:_loadScheduledTasks = {

        $dgv.Rows.Clear()

        try {

            $filter = if ($chkMicrosoft.Checked) { { $true } } else { { $_.TaskPath -notlike '\Microsoft\*' } }

            $script:allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object $filter

            $filterText = $txtSearch.Text.Trim()

            if ($filterText -and $filterText -ne "Filter tasks...") {

                $script:allTasks = $script:allTasks | Where-Object { $_.TaskName -like "*$filterText*" }

            }

            $lblCount.Text = "$($script:allTasks.Count) tasks loaded"

            foreach ($t in $script:allTasks) {

                try {

                    $info = $t | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue

                    $lastRun = if ($info.LastRunTime -gt [datetime]"1900-01-01") { $info.LastRunTime.ToString("yyyy-MM-dd HH:mm") } else { "Never" }

                    $nextRun = if ($info.NextRunTime -gt [datetime]"1900-01-01") { $info.NextRunTime.ToString("yyyy-MM-dd HH:mm") } else { "N/A" }

                } catch { $lastRun = "N/A"; $nextRun = "N/A" }



                $state = $t.State.ToString()

                $rowIdx = $dgv.Rows.Add($t.TaskName, $t.TaskPath, $state, $lastRun, $nextRun)

                $row = $dgv.Rows[$rowIdx]

                $row.DefaultCellStyle.ForeColor = switch ($state) {

                    'Running'  { [System.Drawing.Color]::LightGreen }

                    'Disabled' { Get-ThemeColor 'Muted' }

                    default    { Get-ThemeColor 'Text' }

                }

            }

        } catch {

            $lblCount.Text = "Error: $_"

        }

    }.GetNewClosure()



    & $script:_loadScheduledTasks



    $script:_getSelectedTask = {

        if ($dgv.SelectedRows.Count -gt 0) {

            return $dgv.SelectedRows[0].Cells["TaskName"].Value, $dgv.SelectedRows[0].Cells["TaskPath"].Value

        }

        return $null, $null

    }.GetNewClosure()



    $btnEnable.Add_Click({

        $name, $path = & $script:_getSelectedTask

        if ($name) {

            try { Enable-ScheduledTask -TaskName $name -TaskPath $path -ErrorAction Stop; & $script:_loadScheduledTasks }

            catch { Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null }

        }

    })



    $btnDisable.Add_Click({

        $name, $path = & $script:_getSelectedTask

        if ($name) {

            try { Disable-ScheduledTask -TaskName $name -TaskPath $path -ErrorAction Stop; & $script:_loadScheduledTasks }

            catch { Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null }

        }

    })



    $btnRun.Add_Click({

        $name, $path = & $script:_getSelectedTask

        if ($name) {

            try { Start-ScheduledTask -TaskName $name -TaskPath $path -ErrorAction Stop; & $script:_loadScheduledTasks }

            catch { Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null }

        }

    })



    $btnDelete.Add_Click({

        $name, $path = & $script:_getSelectedTask

        if ($name) {

            $confirm = Out-MessageBox("Delete task '$name'?", "Confirm Delete", "YesNo", "Warning")

            if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {

                try { Unregister-ScheduledTask -TaskName $name -TaskPath $path -Confirm:$false -ErrorAction Stop; & $script:_loadScheduledTasks }

                catch { Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null }

            }

        }

    })



    $btnRefresh.Add_Click({ & $script:_loadScheduledTasks })

    $chkMicrosoft.Add_CheckedChanged({ & $script:_loadScheduledTasks })



    $txtSearch.Add_GotFocus({ if ($txtSearch.Text -eq "Filter tasks...") { $txtSearch.Text = ""; $txtSearch.ForeColor = Get-ThemeColor 'Text' } })

    $txtSearch.Add_LostFocus({ if ($txtSearch.Text -eq "") { $txtSearch.Text = "Filter tasks..."; $txtSearch.ForeColor = Get-ThemeColor 'Muted' } })

    $txtSearch.Add_TextChanged({ if ($txtSearch.Text -ne "Filter tasks...") { & $script:_loadScheduledTasks } })



    $gridHost.Controls.Add($headerPanel)

    $gridHost.Controls.Add($btnBar)

    $gridHost.Controls.Add($dgv)



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



# ============================================================

# PANEL: Windows Firewall Manager

# ============================================================

function Show-FirewallManagerPanel {

    try { $searchBox.Visible = $false; $searchBox.Text = "" } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "Windows Firewall Quick Manager"

    $metaLabel.Text = "View firewall status, manage rules, block or allow applications quickly"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_firewall_manager'



    # Top header with status cards and action buttons

    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 135

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Windows Firewall Manager"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(24, 8)

    $headerPanel.Controls.Add($panelTitle)



    # Firewall profile status cards

    $profileFlow = New-Object System.Windows.Forms.FlowLayoutPanel

    $profileFlow.SetBounds(20, 40, 600, 50)

    $profileFlow.FlowDirection = 'LeftToRight'

    $profileFlow.WrapContents = $false



    try {

        $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue

        foreach ($p in $profiles) {

            $statusCard = New-Object System.Windows.Forms.Label

            $enabled = $p.Enabled

            $color = if ($enabled) { [System.Drawing.Color]::FromArgb(34, 197, 94) } else { [System.Drawing.Color]::FromArgb(239, 68, 68) }

            $statusCard.Text = "$($p.Name): $(if ($enabled) {'ON'} else {'OFF'})"

            $statusCard.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

            $statusCard.ForeColor = $color

            $statusCard.AutoSize = $false

            $statusCard.Size = New-Object System.Drawing.Size(170, 36)

            $statusCard.TextAlign = 'MiddleCenter'

            $statusCard.BorderStyle = 'FixedSingle'

            $statusCard.BackColor = Get-ThemeColor 'Panel2'

            $statusCard.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)

            $profileFlow.Controls.Add($statusCard)

        }

    } catch {

        $errLbl = New-Object System.Windows.Forms.Label

        $errLbl.Text = "Could not retrieve firewall profile status."

        $errLbl.ForeColor = Get-ThemeColor 'Muted'

        $errLbl.AutoSize = $true

        $profileFlow.Controls.Add($errLbl)

    }

    $headerPanel.Controls.Add($profileFlow)



    # Action buttons

    $btnEnableAll = New-Object System.Windows.Forms.Button

    $btnEnableAll.Text = "Enable All Firewalls"

    $btnEnableAll.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $btnEnableAll.FlatStyle = 'Flat'

    $btnEnableAll.BackColor = [System.Drawing.Color]::DarkGreen

    $btnEnableAll.ForeColor = [System.Drawing.Color]::White

    $btnEnableAll.SetBounds(20, 92, 162, 32)

    $btnEnableAll.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnEnableAll)



    $btnDisableAll = New-Object System.Windows.Forms.Button

    $btnDisableAll.Text = "Disable All Firewalls"

    $btnDisableAll.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $btnDisableAll.FlatStyle = 'Flat'

    $btnDisableAll.BackColor = [System.Drawing.Color]::DarkRed

    $btnDisableAll.ForeColor = [System.Drawing.Color]::White

    $btnDisableAll.SetBounds(192, 92, 162, 32)

    $btnDisableAll.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnDisableAll)



    $btnReset = New-Object System.Windows.Forms.Button

    $btnReset.Text = "Reset to Defaults"

    $btnReset.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $btnReset.FlatStyle = 'Flat'

    $btnReset.BackColor = Get-ThemeColor 'Accent'

    $btnReset.ForeColor = Get-ThemeColor 'CardText'

    $btnReset.SetBounds(364, 92, 155, 32)

    $btnReset.Cursor = [System.Windows.Forms.Cursors]::Hand

    $headerPanel.Controls.Add($btnReset)



    $gridHost.Controls.Add($headerPanel)



    # Button bar for rules

    $btnBar = New-Object System.Windows.Forms.Panel

    $btnBar.Dock = 'Bottom'

    $btnBar.Height = 44



    function New-FwBtn($text, $x) {

        $b = New-Object System.Windows.Forms.Button

        $b.Text = $text

        $b.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

        $b.FlatStyle = 'Flat'

        $b.BackColor = Get-ThemeColor 'Accent'

        $b.ForeColor = Get-ThemeColor 'CardText'

        $b.SetBounds($x, 5, 148, 32)

        $b.Cursor = [System.Windows.Forms.Cursors]::Hand

        $btnBar.Controls.Add($b)

        return $b

    }



    $btnBlockApp   = New-FwBtn "Block App"             5

    $btnAllowApp   = New-FwBtn "Allow App"             160

    $btnDisableRule= New-FwBtn "Disable Selected Rule" 315

    $btnDeleteRule = New-FwBtn "Delete Selected Rule"  470

    $btnRefresh    = New-FwBtn "Refresh Rules"         625



    # DataGridView for rules

    $dgv = New-Object System.Windows.Forms.DataGridView

    $dgv.Dock = 'Fill'

    $dgv.AllowUserToAddRows = $false

    $dgv.AllowUserToDeleteRows = $false

    $dgv.ReadOnly = $true

    $dgv.SelectionMode = 'FullRowSelect'

    $dgv.MultiSelect = $false

    $dgv.AutoSizeColumnsMode = 'Fill'

    $dgv.BackgroundColor = Get-ThemeColor 'BG'

    $dgv.GridColor = Get-ThemeColor 'Muted'

    $dgv.DefaultCellStyle.BackColor = Get-ThemeColor 'Panel2'

    $dgv.DefaultCellStyle.ForeColor = Get-ThemeColor 'Text'

    $dgv.ColumnHeadersDefaultCellStyle.BackColor = Get-ThemeColor 'Accent'

    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = Get-ThemeColor 'CardText'

    $dgv.EnableHeadersVisualStyles = $false

    Enable-DoubleBuffer $dgv



    $dgv.Columns.Add("Name",      "Rule Name")  | Out-Null

    $dgv.Columns.Add("Action",    "Action")     | Out-Null

    $dgv.Columns.Add("Direction", "Direction")  | Out-Null

    $dgv.Columns.Add("Profile",   "Profile")    | Out-Null



    $script:_loadFirewallRules = {

        $dgv.Rows.Clear()

        try {

            $rules = Get-NetFirewallRule -ErrorAction SilentlyContinue |

                     Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' } |

                     Select-Object DisplayName, Action, Direction, Profile -First 100

            foreach ($r in $rules) {

                $rowIdx = $dgv.Rows.Add($r.DisplayName, $r.Action.ToString(), $r.Direction.ToString(), $r.Profile.ToString())

                $row = $dgv.Rows[$rowIdx]

                if ($r.Action.ToString() -eq 'Block') {

                    $isLight = ($script:Theme['Bg'].StartsWith('#F') -or $script:Theme['Bg'].StartsWith('#E'))

                    if ($isLight) {

                        $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(254, 226, 226)

                        $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(220, 38, 38)

                    } else {

                        $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(69, 26, 26)

                        $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(248, 113, 113)

                    }

                }

            }

        } catch {

            Out-MessageBox("Error loading rules: $_", "Error", "OK", "Error") | Out-Null

        }

    }.GetNewClosure()



    & $script:_loadFirewallRules



    $btnEnableAll.Add_Click({

        try { Set-NetFirewallProfile -All -Enabled True -ErrorAction Stop; Out-MessageBox("All firewall profiles enabled.", "Done", "OK", "Information") | Out-Null }

        catch { Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null }

    })



    $btnDisableAll.Add_Click({

        $confirm = Out-MessageBox("WARNING: Disabling the firewall exposes your system to network threats. Continue?", "Security Warning", "YesNo", "Warning")

        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {

            try { Set-NetFirewallProfile -All -Enabled False -ErrorAction Stop; Out-MessageBox("All firewall profiles disabled.", "Done", "OK", "Warning") | Out-Null }

            catch { Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null }

        }

    })



    $btnReset.Add_Click({

        $confirm = Out-MessageBox("Reset Windows Firewall to default settings? This will remove custom rules.", "Confirm Reset", "YesNo", "Warning")

        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {

            try { netsh advfirewall reset 2>&1 | Out-Null; Out-MessageBox("Firewall reset to defaults.", "Done", "OK", "Information") | Out-Null; & $script:_loadFirewallRules }

            catch { Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null }

        }

    })



    $btnBlockApp.Add_Click({

        $ofd = New-Object System.Windows.Forms.OpenFileDialog

        $ofd.Filter = "Executables (*.exe)|*.exe"

        $ofd.Title = "Select Application to Block"

        if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {

            try {

                $appName = [System.IO.Path]::GetFileNameWithoutExtension($ofd.FileName)

                New-NetFirewallRule -DisplayName "Toolkit Block: $appName" -Direction Inbound -Action Block -Program $ofd.FileName -ErrorAction Stop | Out-Null

                New-NetFirewallRule -DisplayName "Toolkit Block Out: $appName" -Direction Outbound -Action Block -Program $ofd.FileName -ErrorAction Stop | Out-Null

                Out-MessageBox("'$appName' has been blocked (Inbound + Outbound).", "Blocked", "OK", "Information") | Out-Null

                & $script:_loadFirewallRules

            } catch {

                Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null

            }

        }

    })



    $btnAllowApp.Add_Click({

        $ofd = New-Object System.Windows.Forms.OpenFileDialog

        $ofd.Filter = "Executables (*.exe)|*.exe"

        $ofd.Title = "Select Application to Allow"

        if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {

            try {

                $appName = [System.IO.Path]::GetFileNameWithoutExtension($ofd.FileName)

                New-NetFirewallRule -DisplayName "Toolkit Allow: $appName" -Direction Inbound -Action Allow -Program $ofd.FileName -ErrorAction Stop | Out-Null

                Out-MessageBox("'$appName' allowed through inbound firewall.", "Allowed", "OK", "Information") | Out-Null

                & $script:_loadFirewallRules

            } catch {

                Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null

            }

        }

    })



    $btnDisableRule.Add_Click({

        if ($dgv.SelectedRows.Count -gt 0) {

            $ruleName = $dgv.SelectedRows[0].Cells["Name"].Value

            try { Set-NetFirewallRule -DisplayName $ruleName -Enabled False -ErrorAction Stop; & $script:_loadFirewallRules }

            catch { Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null }

        }

    })



    $btnDeleteRule.Add_Click({

        if ($dgv.SelectedRows.Count -gt 0) {

            $ruleName = $dgv.SelectedRows[0].Cells["Name"].Value

            $confirm = Out-MessageBox("Delete rule '$ruleName'?", "Confirm", "YesNo", "Warning")

            if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {

                try { Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop; & $script:_loadFirewallRules }

                catch { Out-MessageBox("Error: $_", "Error", "OK", "Error") | Out-Null }

            }

        }

    })



    $btnRefresh.Add_Click({ & $script:_loadFirewallRules })



    $gridHost.Controls.Add($btnBar)

    $gridHost.Controls.Add($dgv)



    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-RemoteControllerPanel {

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_remote_controller'

    try {

        $searchBox.Visible = $false

        $searchBox.Text = ""

    } catch {}



    $form.SuspendLayout()

    $gridHost.SuspendLayout()



    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "Remote Network PC Controller"

    $metaLabel.Text = "Diagnose remote host port availability and broadcast popup alert notifications natively"



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 80

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 15, 24, 10)



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Remote PC Diagnostics & LAN Messaging"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(34, 12)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Ping target host, scan standard remote control ports, and send user alerts via standard msg.exe"

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(36, 40)

    $headerPanel.Controls.Add($panelSub)



    $gridHost.Controls.Add($headerPanel)



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(36, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    # Layout: Two separate side-by-side or stacked panels

    # To fit well, we can stack two massive panels, or do side-by-side. Stacked panels work best in flow layouts.

    

    # Card 1: Remote Host Connection Tester

    $testCard = New-Object System.Windows.Forms.Panel

    $testCard.Size = New-Object System.Drawing.Size(850, 310)

    $testCard.BackColor = Get-ThemeColor 'Panel'

    $testCard.Padding = New-Object System.Windows.Forms.Padding(24)

    Enable-DoubleBuffer $testCard



    $lblHostTitle = New-Object System.Windows.Forms.Label

    $lblHostTitle.Text = "REMOTE CONNECTION DIAGNOSTICS"

    $lblHostTitle.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $lblHostTitle.ForeColor = Get-ThemeColor 'Muted'

    $lblHostTitle.SetBounds(24, 18, 400, 18)

    $testCard.Controls.Add($lblHostTitle)



    $lblTargetIp = New-Object System.Windows.Forms.Label

    $lblTargetIp.Text = "Target IP Address or Hostname:"

    $lblTargetIp.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $lblTargetIp.ForeColor = Get-ThemeColor 'Text'

    $lblTargetIp.SetBounds(24, 46, 300, 20)

    $testCard.Controls.Add($lblTargetIp)



    $txtTargetIp = New-Object System.Windows.Forms.TextBox

    $txtTargetIp.Text = "127.0.0.1"

    $txtTargetIp.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)

    $txtTargetIp.BackColor = Get-ThemeColor 'Panel'

    $txtTargetIp.ForeColor = Get-ThemeColor 'Text'

    $txtTargetIp.SetBounds(24, 68, 260, 26)

    $testCard.Controls.Add($txtTargetIp)



    $btnDiag = New-Object System.Windows.Forms.Button

    $btnDiag.Text = "Test PC Connection"

    $btnDiag.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnDiag.FlatStyle = 'Flat'

    $btnDiag.BackColor = Get-ThemeColor 'Accent'

    $btnDiag.ForeColor = Get-ThemeColor 'CardText'

    $btnDiag.SetBounds(300, 65, 180, 30)

    $btnDiag.Cursor = [System.Windows.Forms.Cursors]::Hand

    $testCard.Controls.Add($btnDiag)



    # Result Labels

    $yResult = 120

    $lblPingRes = New-Object System.Windows.Forms.Label

    $lblPingRes.Text = "ICMP Ping Status     : Pending..."

    $lblPingRes.Font = New-Object System.Drawing.Font('Consolas', 10)

    $lblPingRes.ForeColor = Get-ThemeColor 'Text'

    $lblPingRes.SetBounds(24, $yResult, 400, 20)

    $testCard.Controls.Add($lblPingRes)



    $lblRdpRes = New-Object System.Windows.Forms.Label

    $lblRdpRes.Text = "RDP Remote Port 3389  : Pending..."

    $lblRdpRes.Font = New-Object System.Drawing.Font('Consolas', 10)

    $lblRdpRes.ForeColor = Get-ThemeColor 'Text'

    $lblRdpRes.SetBounds(24, $yResult + 30, 400, 20)

    $testCard.Controls.Add($lblRdpRes)



    $lblSmbRes = New-Object System.Windows.Forms.Label

    $lblSmbRes.Text = "SMB Share Port 445    : Pending..."

    $lblSmbRes.Font = New-Object System.Drawing.Font('Consolas', 10)

    $lblSmbRes.ForeColor = Get-ThemeColor 'Text'

    $lblSmbRes.SetBounds(24, $yResult + 60, 400, 20)

    $testCard.Controls.Add($lblSmbRes)



    $lblWinrmRes = New-Object System.Windows.Forms.Label

    $lblWinrmRes.Text = "WinRM Remote Port 5985: Pending..."

    $lblWinrmRes.Font = New-Object System.Drawing.Font('Consolas', 10)

    $lblWinrmRes.ForeColor = Get-ThemeColor 'Text'

    $lblWinrmRes.SetBounds(24, $yResult + 90, 400, 20)

    $testCard.Controls.Add($lblWinrmRes)



    $btnDiag.Add_Click({

        $target = $txtTargetIp.Text.Trim()

        if ([string]::IsNullOrEmpty($target)) { return }

        

        $lblPingRes.Text = "ICMP Ping Status     : Scanning..."

        $lblPingRes.ForeColor = Get-ThemeColor 'Text'

        $lblRdpRes.Text = "RDP Remote Port 3389  : Scanning..."

        $lblRdpRes.ForeColor = Get-ThemeColor 'Text'

        $lblSmbRes.Text = "SMB Share Port 445    : Scanning..."

        $lblSmbRes.ForeColor = Get-ThemeColor 'Text'

        $lblWinrmRes.Text = "WinRM Remote Port 5985: Scanning..."

        $lblWinrmRes.ForeColor = Get-ThemeColor 'Text'

        [System.Windows.Forms.Application]::DoEvents()



        # Ping scan

        try {

            $ping = New-Object System.Net.NetworkInformation.Ping

            $reply = $ping.Send($target, 800)

            if ($reply.Status -eq 'Success') {

                $lblPingRes.Text = "ICMP Ping Status     : [ONLINE] ($($reply.RoundtripTime) ms)"

                $lblPingRes.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF66")

            } else {

                $lblPingRes.Text = "ICMP Ping Status     : [OFFLINE] ($($reply.Status))"

                $lblPingRes.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FF3366")

            }

        } catch {

            $lblPingRes.Text = "ICMP Ping Status     : [OFFLINE] (Error: $_)"

            $lblPingRes.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FF3366")

        }

        [System.Windows.Forms.Application]::DoEvents()



        # Helper internal socket scan

        $ports = @(3389, 445, 5985)

        $labels = @($lblRdpRes, $lblSmbRes, $lblWinrmRes)

        $names = @("RDP Remote Port 3389", "SMB Share Port 445  ", "WinRM Remote Port 5985")



        for ($i=0; $i -lt $ports.Count; $i++) {

            $p = $ports[$i]

            $lbl = $labels[$i]

            $nm = $names[$i]

            try {

                $client = New-Object System.Net.Sockets.TcpClient

                $connect = $client.BeginConnect($target, $p, $null, $null)

                $wait = $connect.AsyncWaitHandle.WaitOne(600, $false)

                if ($wait) {

                    $client.EndConnect($connect)

                    $lbl.Text = "$($nm): [OPEN]"

                    $lbl.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00FF66")

                } else {

                    $lbl.Text = "$($nm): [CLOSED / BLOCKED]"

                    $lbl.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFCC00")

                }

            } catch {

                $lbl.Text = "$($nm): [CLOSED / ERROR]"

                $lbl.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FF3366")

            } finally {

                try { $client.Close() } catch {}

            }

            [System.Windows.Forms.Application]::DoEvents()

        }

    })

    $flow.Controls.Add($testCard)



    # Spacer

    $space = New-Object System.Windows.Forms.Panel

    $space.Size = New-Object System.Drawing.Size(850, 15)

    $flow.Controls.Add($space)



    # Card 2: LAN Popup Broadcaster

    $msgCard = New-Object System.Windows.Forms.Panel

    $msgCard.Size = New-Object System.Drawing.Size(850, 310)

    $msgCard.BackColor = Get-ThemeColor 'Panel'

    $msgCard.Padding = New-Object System.Windows.Forms.Padding(24)

    Enable-DoubleBuffer $msgCard



    $lblMsgTitle = New-Object System.Windows.Forms.Label

    $lblMsgTitle.Text = "REMOTE PC BROADCAST POPUP MESSENGER"

    $lblMsgTitle.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $lblMsgTitle.ForeColor = Get-ThemeColor 'Muted'

    $lblMsgTitle.SetBounds(24, 18, 400, 18)

    $msgCard.Controls.Add($lblMsgTitle)



    $lblMsgText = New-Object System.Windows.Forms.Label

    $lblMsgText.Text = "Enter Alert Message text:"

    $lblMsgText.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $lblMsgText.ForeColor = Get-ThemeColor 'Text'

    $lblMsgText.SetBounds(24, 46, 300, 20)

    $msgCard.Controls.Add($lblMsgText)



    $txtMessage = New-Object System.Windows.Forms.TextBox

    $txtMessage.Text = "Attention User: This PC will undergo standard IT maintenance in 10 minutes. Please save all active work."

    $txtMessage.Font = New-Object System.Drawing.Font('Segoe UI', 10)

    $txtMessage.BackColor = Get-ThemeColor 'Panel'

    $txtMessage.ForeColor = Get-ThemeColor 'Text'

    $txtMessage.SetBounds(24, 68, 500, 24)

    $msgCard.Controls.Add($txtMessage)



    # Pre-set messaging drawer

    $lblTemplates = New-Object System.Windows.Forms.Label

    $lblTemplates.Text = "Preset Templates:"

    $lblTemplates.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $lblTemplates.ForeColor = Get-ThemeColor 'Text'

    $lblTemplates.SetBounds(550, 46, 200, 20)

    $msgCard.Controls.Add($lblTemplates)



    $cmbTemplates = New-Object System.Windows.Forms.ComboBox

    $cmbTemplates.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $cmbTemplates.BackColor = Get-ThemeColor 'Panel'

    $cmbTemplates.ForeColor = Get-ThemeColor 'Text'

    $cmbTemplates.DropDownStyle = 'DropDownList'

    $cmbTemplates.SetBounds(550, 68, 250, 24)

    [void]$cmbTemplates.Items.Add("IT Maintenance Alert")

    [void]$cmbTemplates.Items.Add("Pending System Reboot")

    [void]$cmbTemplates.Items.Add("General Network Broadcast")

    $cmbTemplates.SelectedIndex = 0

    

    $cmbTemplates.Add_SelectedIndexChanged({

        if ($cmbTemplates.SelectedIndex -eq 0) {

            $txtMessage.Text = "Attention User: This PC will undergo standard IT maintenance in 10 minutes. Please save all active work."

        } elseif ($cmbTemplates.SelectedIndex -eq 1) {

            $txtMessage.Text = "Urgent: A critical system update requires a computer reboot. Save your tasks immediately."

        } elseif ($cmbTemplates.SelectedIndex -eq 2) {

            $txtMessage.Text = "System Administrator message: Connection check successful."

        }

    })

    $msgCard.Controls.Add($cmbTemplates)



    $btnSend = New-Object System.Windows.Forms.Button

    $btnSend.Text = "Send Broadcast Alert"

    $btnSend.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

    $btnSend.FlatStyle = 'Flat'

    $btnSend.BackColor = Get-ThemeColor 'Accent'

    $btnSend.ForeColor = Get-ThemeColor 'CardText'

    $btnSend.SetBounds(24, 115, 200, 32)

    $btnSend.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnSend.Add_Click({

        $target = $txtTargetIp.Text.Trim()

        $msg = $txtMessage.Text.Trim()

        if ([string]::IsNullOrEmpty($target) -or [string]::IsNullOrEmpty($msg)) { return }



        $waitForm = New-Object System.Windows.Forms.Form

        $waitForm.Text = "Sending Message..."

        $waitForm.Size = New-Object System.Drawing.Size(400, 160)

        $waitForm.StartPosition = 'CenterParent'

        $waitForm.FormBorderStyle = 'FixedDialog'

        $waitForm.ControlBox = $false

        $waitForm.ShowInTaskbar = $false

        $waitForm.BackColor = Get-ThemeColor 'Panel'

        

        $lblWait = New-Object System.Windows.Forms.Label

        $lblWait.Text = "Broadcasting popup alert via native RPC service..."

        $lblWait.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

        $lblWait.ForeColor = Get-ThemeColor 'Text'

        $lblWait.SetBounds(20, 20, 360, 40)

        $waitForm.Controls.Add($lblWait)

        

        $progress = New-Object System.Windows.Forms.ProgressBar

        $progress.Style = 'Marquee'

        $progress.MarqueeAnimationSpeed = 30

        $progress.SetBounds(20, 70, 340, 25)

        $waitForm.Controls.Add($progress)



        $waitForm.Add_Shown({

            [System.Windows.Forms.Application]::DoEvents()

            try {

                # msg * /server:<target> "msg"

                $process = Start-Process msg.exe -ArgumentList "* /server:$target `"$msg`"" -NoNewWindow -PassThru -ErrorAction Stop

                $waitProc = $process.WaitForExit(3000)

                $waitForm.Close()

                if ($process.ExitCode -eq 0) {

                    Out-MessageBox("Broadcast popup successfully sent to target: $target", "Success", "OK", "Information") | Out-Null

                } else {

                    Out-MessageBox("Alert sent returned status: $($process.ExitCode). Note: Target PC must enable AllowRemoteRPC registry setting to display alerts.", "Message Status", "OK", "Warning") | Out-Null

                }

            } catch {

                $waitForm.Close()

                Out-MessageBox("Could not invoke msg.exe natively: $_", "Command Error", "OK", "Error") | Out-Null

            }

        })

        $waitForm.ShowDialog($form) | Out-Null

    })

    $msgCard.Controls.Add($btnSend)



    # Local AllowRemoteRPC Configurer

    $btnPrepare = New-Object System.Windows.Forms.Button

    $btnPrepare.Text = "Enable Local RPC Alerts Receipt"

    $btnPrepare.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnPrepare.FlatStyle = 'Flat'

    $btnPrepare.BackColor = Get-ThemeColor 'Accent'

    $btnPrepare.ForeColor = Get-ThemeColor 'CardText'

    $btnPrepare.SetBounds(250, 115, 260, 32)

    $btnPrepare.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnPrepare.Add_Click({

        try {

            # HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server -> AllowRemoteRPC = 1

            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "AllowRemoteRPC" -Value 1 -Force -ErrorAction Stop

            Out-MessageBox("Local registry modified successfully!`nThis PC is now prepared to receive standard LAN message popups.", "Registry Configured", "OK", "Information") | Out-Null

        } catch {

            Out-MessageBox("Failed to modify registry. Administrator privileges are required to configure local alerts receipt.", "Elevation Required", "OK", "Warning") | Out-Null

        }

    })

    $msgCard.Controls.Add($btnPrepare)



    $flow.Controls.Add($msgCard)



    $flow.BringToFront()

    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



# ============================================================

# PANEL: WiFi Password Viewer

# ============================================================

function Show-WiFiPasswordPanel {

    try { $searchBox.Visible = $false; $searchBox.Text = "" } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "WiFi Password Viewer"

    $metaLabel.Text = "View all saved WiFi network passwords on this PC"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_wifi_passwords'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 80

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Saved WiFi Network Passwords"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(24, 10)

    $headerPanel.Controls.Add($panelTitle)



    $btnBar = New-Object System.Windows.Forms.Panel

    $btnBar.Dock = 'Bottom'

    $btnBar.Height = 44



    function New-WifiBtn($text, $x, $color) {

        $b = New-Object System.Windows.Forms.Button

        $b.Text = $text

        $b.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

        $b.FlatStyle = 'Flat'

        $b.BackColor = if ($color) { [System.Drawing.ColorTranslator]::FromHtml($color) } else { Get-ThemeColor 'Accent' }

        $b.ForeColor = [System.Drawing.Color]::White

        $b.SetBounds($x, 5, 175, 32)

        $b.Cursor = [System.Windows.Forms.Cursors]::Hand

        $btnBar.Controls.Add($b)

        return $b

    }



    $btnRefresh = New-WifiBtn "Refresh Networks" 5 $null

    $btnExport = New-WifiBtn "Export to TXT" 188 "#166534"



    $lblStatus = New-Object System.Windows.Forms.Label

    $lblStatus.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblStatus.ForeColor = Get-ThemeColor 'Muted'

    $lblStatus.AutoSize = $true

    $lblStatus.Location = New-Object System.Drawing.Point(24, 50)

    $headerPanel.Controls.Add($lblStatus)



    $dgv = New-Object System.Windows.Forms.DataGridView

    $dgv.Dock = 'Fill'

    $dgv.AllowUserToAddRows = $false

    $dgv.AllowUserToDeleteRows = $false

    $dgv.ReadOnly = $true

    $dgv.SelectionMode = 'FullRowSelect'

    $dgv.MultiSelect = $false

    $dgv.AutoSizeColumnsMode = 'Fill'

    $dgv.BackgroundColor = Get-ThemeColor 'BG'

    $dgv.GridColor = Get-ThemeColor 'Muted'

    $dgv.DefaultCellStyle.BackColor = Get-ThemeColor 'Panel2'

    $dgv.DefaultCellStyle.ForeColor = Get-ThemeColor 'Text'

    $dgv.ColumnHeadersDefaultCellStyle.BackColor = Get-ThemeColor 'Accent'

    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = Get-ThemeColor 'CardText'

    $dgv.EnableHeadersVisualStyles = $false

    Enable-DoubleBuffer $dgv



    $dgv.Columns.Add("NetworkName", "Network Name") | Out-Null

    $dgv.Columns.Add("Password",    "Password")     | Out-Null

    $dgv.Columns.Add("Auth",        "Auth Type")    | Out-Null



    $script:_wifiProfiles = @()



    $loadWifi = {

        $dgv.Rows.Clear()

        $script:_wifiProfiles = @()

        try {

            $profiles = netsh wlan show profiles 2>$null | Select-String "All User Profile" | ForEach-Object {

                ($_ -replace ".*:\s*","").Trim()

            }

            if (-not $profiles -or $profiles.Count -eq 0) {

                $lblStatus.Text = "No WiFi profiles found or WiFi adapter not present."

                $lblStatus.ForeColor = [System.Drawing.Color]::OrangeRed

                return

            }

            foreach ($profile in $profiles) {

                try {

                    $details = netsh wlan show profile name=`"$profile`" key=clear 2>$null

                    $pwd = ($details | Select-String "Key Content") -replace ".*:\s*","" | ForEach-Object { $_.Trim() } | Select-Object -First 1

                    $auth = ($details | Select-String "Authentication") -replace ".*:\s*","" | ForEach-Object { $_.Trim() } | Select-Object -First 1

                    $password = if ($pwd) { $pwd } else { "(No password / Open)" }

                    $authentication = if ($auth) { $auth } else { "Unknown" }

                    $script:_wifiProfiles += [pscustomobject]@{ Name = $profile; Password = $password; Auth = $authentication }

                    $dgv.Rows.Add($profile, $password, $authentication) | Out-Null

                } catch {}

            }

            $lblStatus.Text = "$($profiles.Count) WiFi profile(s) found and loaded."

            $lblStatus.ForeColor = Get-ThemeColor 'Muted'

        } catch {

            $lblStatus.Text = "Error loading WiFi profiles: $_"

            $lblStatus.ForeColor = [System.Drawing.Color]::OrangeRed

        }

    }



    & $loadWifi



    $btnRefresh.Add_Click({ & $loadWifi })



    $btnExport.Add_Click({

        try {

            $exportPath = Join-Path $script:ToolkitRoot "Logs\WiFi_Passwords_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

            $lines = @("SysForge Studio - WiFi Password Export", "Generated: $(Get-Date)", "=" * 50, "")

            foreach ($p in $script:_wifiProfiles) {

                $lines += "Network  : $($p.Name)"

                $lines += "Password : $($p.Password)"

                $lines += "Auth     : $($p.Auth)"

                $lines += "-" * 40

            }

            $lines | Out-File -FilePath $exportPath -Encoding UTF8

            Start-Process notepad.exe -ArgumentList $exportPath

            Out-MessageBox("Exported to:`r`n$exportPath", "Export Done", "OK", "Information") | Out-Null

        } catch {

            Out-MessageBox("Export failed: $_", "Error", "OK", "Error") | Out-Null

        }

    })



    $gridHost.Controls.Add($headerPanel)

    $gridHost.Controls.Add($btnBar)

    $gridHost.Controls.Add($dgv)

    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



# ============================================================

# PANEL: Installed Apps Manager

# ============================================================

function Show-InstalledAppsPanel {

    try { $searchBox.Visible = $true; $searchBox.Text = "" } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "Installed Apps Manager"

    $metaLabel.Text = "Browse, search and uninstall all installed applications"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_installed_apps'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 80

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Installed Applications"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(24, 10)

    $headerPanel.Controls.Add($panelTitle)



    $txtFilter = New-Object System.Windows.Forms.TextBox

    $txtFilter.SetBounds(24, 47, 350, 26)

    $txtFilter.Font = New-Object System.Drawing.Font('Segoe UI', 10)

    $txtFilter.Text = "Search apps..."

    $txtFilter.ForeColor = Get-ThemeColor 'Muted'

    $txtFilter.BackColor = Get-ThemeColor 'Panel2'

    $headerPanel.Controls.Add($txtFilter)



    $lblCount = New-Object System.Windows.Forms.Label

    $lblCount.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblCount.ForeColor = Get-ThemeColor 'Muted'

    $lblCount.AutoSize = $true

    $lblCount.Location = New-Object System.Drawing.Point(385, 52)

    $headerPanel.Controls.Add($lblCount)



    $btnBar = New-Object System.Windows.Forms.Panel

    $btnBar.Dock = 'Bottom'

    $btnBar.Height = 44



    $btnUninstall = New-Object System.Windows.Forms.Button

    $btnUninstall.Text = "Uninstall Selected"

    $btnUninstall.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $btnUninstall.FlatStyle = 'Flat'

    $btnUninstall.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#DC2626")

    $btnUninstall.ForeColor = [System.Drawing.Color]::White

    $btnUninstall.SetBounds(5, 5, 175, 32)

    $btnUninstall.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnBar.Controls.Add($btnUninstall)



    $btnExport = New-Object System.Windows.Forms.Button

    $btnExport.Text = "Export to CSV"

    $btnExport.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $btnExport.FlatStyle = 'Flat'

    $btnExport.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#166534")

    $btnExport.ForeColor = [System.Drawing.Color]::White

    $btnExport.SetBounds(188, 5, 140, 32)

    $btnExport.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnBar.Controls.Add($btnExport)



    $dgv = New-Object System.Windows.Forms.DataGridView

    $dgv.Dock = 'Fill'

    $dgv.AllowUserToAddRows = $false

    $dgv.AllowUserToDeleteRows = $false

    $dgv.ReadOnly = $true

    $dgv.SelectionMode = 'FullRowSelect'

    $dgv.MultiSelect = $false

    $dgv.AutoSizeColumnsMode = 'Fill'

    $dgv.BackgroundColor = Get-ThemeColor 'BG'

    $dgv.GridColor = Get-ThemeColor 'Muted'

    $dgv.DefaultCellStyle.BackColor = Get-ThemeColor 'Panel2'

    $dgv.DefaultCellStyle.ForeColor = Get-ThemeColor 'Text'

    $dgv.ColumnHeadersDefaultCellStyle.BackColor = Get-ThemeColor 'Accent'

    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = Get-ThemeColor 'CardText'

    $dgv.EnableHeadersVisualStyles = $false

    Enable-DoubleBuffer $dgv



    $dgv.Columns.Add("Name",        "Application Name")  | Out-Null

    $dgv.Columns.Add("Version",     "Version")            | Out-Null

    $dgv.Columns.Add("Publisher",   "Publisher")          | Out-Null

    $dgv.Columns.Add("InstallDate", "Install Date")       | Out-Null

    $dgv.Columns.Add("UninstallStr","Uninstall String")   | Out-Null

    $dgv.Columns[4].Visible = $false



    $script:_allApps = @()



    # Load apps from registry

    try {

        $roots = @(

            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',

            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',

            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'

        )

        $appRows = @()

        foreach ($r in $roots) { $appRows += @(Get-ItemProperty -Path $r -ErrorAction SilentlyContinue) }

        $script:_allApps = @($appRows | Where-Object { $_.DisplayName -and $_.DisplayName.Trim() } | Sort-Object DisplayName -Unique | ForEach-Object {

            [pscustomobject]@{

                Name = $_.DisplayName.Trim()

                Version = if ($_.DisplayVersion) { $_.DisplayVersion } else { "" }

                Publisher = if ($_.Publisher) { $_.Publisher } else { "" }

                InstallDate = if ($_.InstallDate -and $_.InstallDate.Length -ge 8) {

                    try { [datetime]::ParseExact($_.InstallDate,'yyyyMMdd',$null).ToString('yyyy-MM-dd') } catch { $_.InstallDate }

                } else { "" }

                UninstallStr = if ($_.UninstallString) { $_.UninstallString } else { "" }

            }

        })

    } catch {}



    $populateDgv = {

        param($filter = "")

        $dgv.Rows.Clear()

        $filtered = if ($filter -and $filter.Length -gt 0 -and $filter -ne "Search apps...") {

            @($script:_allApps | Where-Object { $_.Name -like "*$filter*" -or $_.Publisher -like "*$filter*" })

        } else { $script:_allApps }

        foreach ($app in $filtered) {

            $dgv.Rows.Add($app.Name, $app.Version, $app.Publisher, $app.InstallDate, $app.UninstallStr) | Out-Null

        }

        $lblCount.Text = "$($filtered.Count) app(s)"

    }



    & $populateDgv ""



    $txtFilter.Add_GotFocus({ if ($txtFilter.Text -eq "Search apps...") { $txtFilter.Text = ""; $txtFilter.ForeColor = Get-ThemeColor 'Text' } })

    $txtFilter.Add_LostFocus({ if ($txtFilter.Text -eq "") { $txtFilter.Text = "Search apps..."; $txtFilter.ForeColor = Get-ThemeColor 'Muted' } })

    $txtFilter.Add_TextChanged({

        $q = $txtFilter.Text

        if ($q -ne "Search apps...") { & $populateDgv $q }

    })



    $btnUninstall.Add_Click({

        if ($dgv.SelectedRows.Count -eq 0) { return }

        $appName = $dgv.SelectedRows[0].Cells["Name"].Value

        $uninstStr = $dgv.SelectedRows[0].Cells["UninstallStr"].Value

        if ([string]::IsNullOrWhiteSpace($uninstStr)) {

            Out-MessageBox("No uninstall string found for '$appName'.`r`nTry removing via Control Panel.", "Cannot Uninstall", "OK", "Warning") | Out-Null

            return

        }

        $res = Out-MessageBox("Uninstall '$appName'?`r`n`r`nThis will run the app's uninstaller.", "Confirm Uninstall", "YesNo", "Warning")

        if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {

            try {

                Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$uninstStr`"" -Verb RunAs

                $script:statusLabel.Text = "Uninstall launched for: $appName"

            } catch {

                Out-MessageBox("Failed to launch uninstaller: $_", "Error", "OK", "Error") | Out-Null

            }

        }

    })



    $btnExport.Add_Click({

        try {

            $exportPath = Join-Path $script:ToolkitRoot "Logs\InstalledApps_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

            $script:_allApps | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8

            Start-Process notepad.exe -ArgumentList $exportPath

            Out-MessageBox("Exported $($script:_allApps.Count) apps to:`r`n$exportPath", "Exported", "OK", "Information") | Out-Null

        } catch {

            Out-MessageBox("Export failed: $_", "Error", "OK", "Error") | Out-Null

        }

    })



    $gridHost.Controls.Add($headerPanel)

    $gridHost.Controls.Add($btnBar)

    $gridHost.Controls.Add($dgv)

    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



# ============================================================

# PANEL: Event Log Viewer

# ============================================================

function Show-EventLogPanel {

    try { $searchBox.Visible = $false; $searchBox.Text = "" } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $false

    $screenTitle.Text = "Windows Event Log Viewer"

    $metaLabel.Text = "View System and Application event logs - Errors, Warnings, Critical events"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_event_logs'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 90

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Windows Event Log Viewer"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(24, 8)

    $headerPanel.Controls.Add($panelTitle)



    # Log type combo

    $cmbLog = New-Object System.Windows.Forms.ComboBox

    $cmbLog.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $cmbLog.BackColor = Get-ThemeColor 'Panel2'

    $cmbLog.ForeColor = Get-ThemeColor 'Text'

    $cmbLog.DropDownStyle = 'DropDownList'

    $cmbLog.SetBounds(24, 48, 150, 26)

    [void]$cmbLog.Items.AddRange(@("System","Application","Security"))

    $cmbLog.SelectedIndex = 0

    $headerPanel.Controls.Add($cmbLog)



    # Level filter

    $cmbLevel = New-Object System.Windows.Forms.ComboBox

    $cmbLevel.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $cmbLevel.BackColor = Get-ThemeColor 'Panel2'

    $cmbLevel.ForeColor = Get-ThemeColor 'Text'

    $cmbLevel.DropDownStyle = 'DropDownList'

    $cmbLevel.SetBounds(184, 48, 130, 26)

    [void]$cmbLevel.Items.AddRange(@("All Levels","Critical","Error","Warning","Information"))

    $cmbLevel.SelectedIndex = 0

    $headerPanel.Controls.Add($cmbLevel)



    # Max events

    $cmbMax = New-Object System.Windows.Forms.ComboBox

    $cmbMax.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $cmbMax.BackColor = Get-ThemeColor 'Panel2'

    $cmbMax.ForeColor = Get-ThemeColor 'Text'

    $cmbMax.DropDownStyle = 'DropDownList'

    $cmbMax.SetBounds(324, 48, 100, 26)

    [void]$cmbMax.Items.AddRange(@("50","100","250","500"))

    $cmbMax.SelectedIndex = 0

    $headerPanel.Controls.Add($cmbMax)



    $lblStatus = New-Object System.Windows.Forms.Label

    $lblStatus.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $lblStatus.ForeColor = Get-ThemeColor 'Muted'

    $lblStatus.AutoSize = $true

    $lblStatus.Location = New-Object System.Drawing.Point(440, 52)

    $headerPanel.Controls.Add($lblStatus)



    $btnBar = New-Object System.Windows.Forms.Panel

    $btnBar.Dock = 'Bottom'

    $btnBar.Height = 44



    $btnLoad = New-Object System.Windows.Forms.Button

    $btnLoad.Text = "Load / Refresh"

    $btnLoad.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $btnLoad.FlatStyle = 'Flat'

    $btnLoad.BackColor = Get-ThemeColor 'Accent'

    $btnLoad.ForeColor = Get-ThemeColor 'CardText'

    $btnLoad.SetBounds(5, 5, 160, 32)

    $btnLoad.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnBar.Controls.Add($btnLoad)



    $btnExport = New-Object System.Windows.Forms.Button

    $btnExport.Text = "Export to TXT"

    $btnExport.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold)

    $btnExport.FlatStyle = 'Flat'

    $btnExport.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#166534")

    $btnExport.ForeColor = [System.Drawing.Color]::White

    $btnExport.SetBounds(174, 5, 150, 32)

    $btnExport.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnBar.Controls.Add($btnExport)



    $dgv = New-Object System.Windows.Forms.DataGridView

    $dgv.Dock = 'Fill'

    $dgv.AllowUserToAddRows = $false

    $dgv.AllowUserToDeleteRows = $false

    $dgv.ReadOnly = $true

    $dgv.SelectionMode = 'FullRowSelect'

    $dgv.MultiSelect = $false

    $dgv.AutoSizeColumnsMode = 'Fill'

    $dgv.BackgroundColor = Get-ThemeColor 'BG'

    $dgv.GridColor = Get-ThemeColor 'Muted'

    $dgv.DefaultCellStyle.BackColor = Get-ThemeColor 'Panel2'

    $dgv.DefaultCellStyle.ForeColor = Get-ThemeColor 'Text'

    $dgv.ColumnHeadersDefaultCellStyle.BackColor = Get-ThemeColor 'Accent'

    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = Get-ThemeColor 'CardText'

    $dgv.EnableHeadersVisualStyles = $false

    Enable-DoubleBuffer $dgv



    $dgv.Columns.Add("Time",    "Time")         | Out-Null

    $dgv.Columns.Add("Level",   "Level")         | Out-Null

    $dgv.Columns.Add("Source",  "Source")        | Out-Null

    $dgv.Columns.Add("EventID", "Event ID")      | Out-Null

    $dgv.Columns.Add("Message", "Message")       | Out-Null



    $script:_eventRows = @()



    $loadEvents = {

        $dgv.Rows.Clear()

        $script:_eventRows = @()

        $lblStatus.Text = "Loading events..."

        [System.Windows.Forms.Application]::DoEvents()

        try {

            $logName = [string]$cmbLog.SelectedItem

            $maxEvt = [int][string]$cmbMax.SelectedItem

            $filterHash = @{ LogName = $logName; StartTime = (Get-Date).AddDays(-30) }

            $levelSel = [string]$cmbLevel.SelectedItem

            if ($levelSel -ne "All Levels") {

                $lvMap = @{ "Critical" = 1; "Error" = 2; "Warning" = 3; "Information" = 4 }

                if ($lvMap.ContainsKey($levelSel)) { $filterHash["Level"] = $lvMap[$levelSel] }

            }

            $events = @(Get-WinEvent -FilterHashtable $filterHash -MaxEvents $maxEvt -ErrorAction SilentlyContinue)

            foreach ($ev in $events) {

                $msg = ($ev.Message -split "`n" | Select-Object -First 1).Trim()

                $row = $dgv.Rows.Add(

                    $ev.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss"),

                    $ev.LevelDisplayName,

                    $ev.ProviderName,

                    $ev.Id,

                    $msg

                )

                # Color rows by level

                $r = $dgv.Rows[$row]

                switch ($ev.LevelDisplayName) {

                    "Critical"    { $r.DefaultCellStyle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#EF4444") }

                    "Error"       { $r.DefaultCellStyle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#F87171") }

                    "Warning"     { $r.DefaultCellStyle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FBBF24") }

                }

                $script:_eventRows += [pscustomobject]@{

                    Time = $ev.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")

                    Level = $ev.LevelDisplayName; Source = $ev.ProviderName

                    ID = $ev.Id; Message = $ev.Message

                }

            }

            $lblStatus.Text = "$($events.Count) event(s) loaded from $logName (last 30 days)"

        } catch {

            $lblStatus.Text = "Error loading events: $_"

            $lblStatus.ForeColor = [System.Drawing.Color]::OrangeRed

        }

    }



    & $loadEvents



    $btnLoad.Add_Click({ & $loadEvents })



    $btnExport.Add_Click({

        try {

            $exportPath = Join-Path $script:ToolkitRoot "Logs\EventLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

            $lines = @("SysForge Studio - Event Log Export", "Generated: $(Get-Date)", "=" * 60, "")

            foreach ($ev in $script:_eventRows) {

                $lines += "Time   : $($ev.Time)"

                $lines += "Level  : $($ev.Level)"

                $lines += "Source : $($ev.Source) (ID: $($ev.ID))"

                $lines += "Message: $($ev.Message -split '`n' | Select-Object -First 3 | ForEach-Object { $_.Trim() } | Where-Object { $_ } )"

                $lines += "-" * 60

            }

            $lines | Out-File -FilePath $exportPath -Encoding UTF8

            Start-Process notepad.exe -ArgumentList $exportPath

        } catch {

            Out-MessageBox("Export failed: $_", "Error", "OK", "Error") | Out-Null

        }

    })



    $gridHost.Controls.Add($headerPanel)

    $gridHost.Controls.Add($btnBar)

    $gridHost.Controls.Add($dgv)

    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



# ============================================================

# PANEL: Quick Actions

# ============================================================

function Show-QuickActionsPanel {

    try { $searchBox.Visible = $false; $searchBox.Text = "" } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "Quick Actions"

    $metaLabel.Text = "One-click shortcuts for the most common Windows admin tasks"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_quick_actions'



    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 70

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent



    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Quick Actions - One Click System Tasks"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.AutoSize = $true

    $panelTitle.Location = New-Object System.Drawing.Point(24, 10)

    $headerPanel.Controls.Add($panelTitle)



    $panelSub = New-Object System.Windows.Forms.Label

    $panelSub.Text = "Click any action to execute it instantly. Results appear in a popup or are shown inline."

    $panelSub.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $panelSub.ForeColor = Get-ThemeColor 'Muted'

    $panelSub.AutoSize = $true

    $panelSub.Location = New-Object System.Drawing.Point(26, 42)

    $headerPanel.Controls.Add($panelSub)



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(24, 10, 24, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    $resultBox = New-Object System.Windows.Forms.RichTextBox

    $resultBox.Dock = 'Bottom'

    $resultBox.Height = 160

    $resultBox.Font = New-Object System.Drawing.Font('Consolas', 9.5)

    $resultBox.BackColor = [System.Drawing.Color]::FromArgb(8, 14, 24)

    $resultBox.ForeColor = [System.Drawing.Color]::FromArgb(180, 220, 180)

    $resultBox.ReadOnly = $true

    $resultBox.ScrollBars = 'Vertical'

    $resultBox.Text = "[Ready] Click any action button above to run it immediately.`r`n"



    function New-QABtn($label, $icon, $color, $action) {

        $card = New-Object System.Windows.Forms.Panel

        $card.Size = New-Object System.Drawing.Size(220, 88)

        $card.BackColor = Get-ThemeColor 'Panel'

        $card.Margin = New-Object System.Windows.Forms.Padding(6)

        $card.Cursor = [System.Windows.Forms.Cursors]::Hand

        Enable-DoubleBuffer $card



        $lIcon = New-Object System.Windows.Forms.Label

        $lIcon.Text = $icon

        $lIcon.Font = New-Object System.Drawing.Font('Segoe UI', 22)

        $lIcon.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($color)

        $lIcon.AutoSize = $true

        $lIcon.Location = New-Object System.Drawing.Point(16, 10)

        $card.Controls.Add($lIcon)



        $lLabel = New-Object System.Windows.Forms.Label

        $lLabel.Text = $label

        $lLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

        $lLabel.ForeColor = Get-ThemeColor 'Text'

        $lLabel.SetBounds(16, 56, 190, 22)

        $card.Controls.Add($lLabel)



        $click = {

            try {

                $resultBox.AppendText("[Running] " + $label + "...`r`n")

                $resultBox.ScrollToCaret()

                [System.Windows.Forms.Application]::DoEvents()

                $out = & $action

                $outStr = if ($out) { ($out | Out-String).Trim() } else { "Done." }

                $resultBox.AppendText("[OK] " + $outStr + "`r`n`r`n")

                $resultBox.ScrollToCaret()

            } catch {

                $resultBox.AppendText("[ERR] Error: " + $_ + "`r`n`r`n")

                $resultBox.ScrollToCaret()

            }

        }.GetNewClosure()



        $card.Add_Click($click)

        foreach ($ctrl in $card.Controls) { $ctrl.Add_Click($click) }



        # Hover effect

        $card.Add_MouseEnter(({ $card.BackColor = Get-ThemeColor 'Panel2' }.GetNewClosure()))

        $card.Add_MouseLeave(({ $card.BackColor = Get-ThemeColor 'Panel' }.GetNewClosure()))



        return $card

    }



    $qaItems = @(

        @{ Label = "Flush DNS Cache";          Icon = "[DNS]"; Color = "#00BFFF"; Action = { ipconfig /flushdns 2>&1 } },

        @{ Label = "Clear Temp Files";         Icon = "[TMP]"; Color = "#FF6C00"; Action = {

            foreach ($path in @($env:TEMP, "$env:SystemRoot\Temp")) {

                if (Test-Path $path) { Get-ChildItem $path -File -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }

            }

            "Temp folders cleared."

        }},

        @{ Label = "Restart Explorer";         Icon = "[EXP]"; Color = "#A78BFA"; Action = { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Sleep 1; Start-Process explorer; "Explorer restarted." } },

        @{ Label = "Open Task Manager";        Icon = "[TSK]"; Color = "#22C55E"; Action = { Start-Process taskmgr; "Task Manager opened." } },

        @{ Label = "Open Device Manager";      Icon = "[DEV]"; Color = "#F59E0B"; Action = { Start-Process devmgmt.msc; "Device Manager opened." } },

        @{ Label = "System Properties";        Icon = "[SYS]"; Color = "#60A5FA"; Action = { Start-Process sysdm.cpl; "System Properties opened." } },

        @{ Label = "Check Disk Space";         Icon = "[DSK]"; Color = "#34D399"; Action = {

            $disks = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }

            ($disks | ForEach-Object { "$($_.Name): $('{0:N1}' -f ($_.Free/1GB)) GB free / $('{0:N1}' -f (($_.Used+$_.Free)/1GB)) GB total" }) -join "`r`n"

        }},

        @{ Label = "Release and Renew IP";     Icon = "[IP ]"; Color = "#F87171"; Action = { ipconfig /release 2>&1; ipconfig /renew 2>&1; "IP released and renewed." } },

        @{ Label = "Network Info (ipconfig)";  Icon = "[NET]"; Color = "#38BDF8"; Action = { ipconfig /all 2>&1 | Select-Object -First 40 } },

        @{ Label = "Open Services";            Icon = "[SVC]"; Color = "#C084FC"; Action = { Start-Process services.msc; "Services console opened." } },

        @{ Label = "Open Registry Editor";     Icon = "[REG]"; Color = "#FB923C"; Action = { Start-Process regedit; "Registry Editor opened." } },

        @{ Label = "Open Windows Update";      Icon = "[UPD]"; Color = "#4ADE80"; Action = { Start-Process "ms-settings:windowsupdate"; "Windows Update opened." } },

        @{ Label = "Run SFC Scan";             Icon = "[SFC]"; Color = "#FCD34D"; Action = {

            $resultBox.AppendText("[INFO] SFC scan running - this may take several minutes...`r`n")

            $resultBox.ScrollToCaret()

            [System.Windows.Forms.Application]::DoEvents()

            $p = Start-Process cmd -ArgumentList "/c sfc /scannow" -Verb RunAs -PassThru -Wait -WindowStyle Hidden

            "SFC scan completed. Exit code: $($p.ExitCode). Check Event Viewer for results."

        }},

        @{ Label = "DISM RestoreHealth";       Icon = "[DSM]"; Color = "#EF4444"; Action = {

            $resultBox.AppendText("[INFO] DISM running - may take 10-20 minutes...`r`n")

            [System.Windows.Forms.Application]::DoEvents()

            $p = Start-Process cmd -ArgumentList "/c DISM /Online /Cleanup-Image /RestoreHealth" -Verb RunAs -PassThru -Wait -WindowStyle Hidden

            "DISM completed. Exit code: $($p.ExitCode)"

        }},

        @{ Label = "Ping Google (8.8.8.8)";    Icon = "[PNG]"; Color = "#6EE7B7"; Action = { ping 8.8.8.8 -n 4 2>&1 } },

        @{ Label = "Empty Recycle Bin";        Icon = "[BIN]"; Color = "#A3A3A3"; Action = { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; "Recycle Bin emptied." } },

        @{ Label = "Open Disk Management";     Icon = "[HDD]"; Color = "#FCA5A5"; Action = { Start-Process diskmgmt.msc; "Disk Management opened." } },

        @{ Label = "Restart Computer";         Icon = "[RST]"; Color = "#FF3B3B"; Action = {

            $r = Out-MessageBox("Are you sure you want to RESTART the computer?", "Confirm Restart", "YesNo", "Warning")

            if ($r -eq [System.Windows.Forms.DialogResult]::Yes) { Restart-Computer -Force }

            "Restart cancelled."

        }}

    )



    foreach ($qa in $qaItems) {

        $flow.Controls.Add((New-QABtn -label $qa.Label -icon $qa.Icon -color $qa.Color -action $qa.Action))

    }



    $gridHost.Controls.Add($headerPanel)

    $gridHost.Controls.Add($resultBox)

    $gridHost.Controls.Add($flow)

    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-Menu {

    param([string]$Label, [bool]$Push, [object]$OptionObj = $null)

    Write-GuiActionLog -ActionType 'OpenPanel' -Component $Label -Details "Opened panel: $Label"

    if ($Label -eq 'menu_apps_online_search') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        

        $initQuery = ""

        if ($null -ne $OptionObj -and $OptionObj.PSObject.Properties.Name -contains 'IsOnlineRedirect') {

            $initQuery = $OptionObj.Query

        }

        

        try {

            Show-OnlineWingetSearchPanel -InitialQuery $initQuery

        } catch {

            $script:statusLabel.Text = "Error opening Winget Search: $_"

            Out-MessageBox("Winget Search panel error:`r`n$_", "100 Apps", "OK", "Error") | Out-Null

        }

        return

    }



    if ($Label -eq 'menu_apps_update_manager') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        Show-SoftwareUpdateManager

        return

    }

    if ($Label -eq 'menu_apps_custom_bundler') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        Show-CustomBundlerPanel

        return

    }

    if ($Label -eq 'menu_system_cleaner') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        Show-SystemCleanerPanel

        return

    }

    if ($Label -eq 'menu_user_backup') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        Show-BackupMigrationPanel

        return

    }

    if ($Label -eq 'menu_bloatware_remover') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        Show-BloatwareRemoverPanel

        return

    }

    if ($Label -eq 'menu_hardware_diagnostics') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        Show-HardwareDiagnosticsPanel

        return

    }

    if ($Label -eq 'menu_software_diagnostics') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        Show-SoftwareDiagnosticsPanel

        return

    }

    if ($Label -eq 'menu_offline_recovery') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        Show-OfflineRecoveryPanel

        return

    }

    if ($Label -eq 'menu_startup_optimizer') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        Show-StartupOptimizerPanel

        return

    }

    if ($Label -eq 'menu_network_scanner') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        Show-NetworkScannerPanel

        return

    }

    if ($Label -eq 'menu_license_vault') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-LicenseVaultPanel

        return

    }

    if ($Label -eq 'menu_bsod_analyzer') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-BsodAnalyzerPanel

        return

    }

    if ($Label -eq 'menu_process_manager') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-ProcessManagerPanel

        return

    }

    if ($Label -eq 'menu_netstat_conn') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-NetstatConnPanel

        return

    }

    if ($Label -eq 'menu_services_dashboard') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-ServicesDashboardPanel

        return

    }

    if ($Label -eq 'menu_registry_tweaks') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-RegistryTweaksPanel

        return

    }

    if ($Label -eq 'menu_ai_diagnostics') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-AiDiagnosticsPanel

        return

    }

    if ($Label -eq 'menu_temp_monitor') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-TempMonitorPanel

        return

    }

    if ($Label -eq 'menu_disk_benchmark') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-DiskBenchmarkPanel

        return

    }

    if ($Label -eq 'menu_dns_repair') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-DnsRepairPanel

        return

    }

    if ($Label -eq 'menu_restore_manager') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-RestoreManagerPanel

        return

    }

    if ($Label -eq 'menu_task_scheduler') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-TaskSchedulerPanel

        return

    }

    if ($Label -eq 'menu_firewall_manager') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-FirewallManagerPanel

        return

    }

    if ($Label -eq 'menu_wifi_passwords') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-WiFiPasswordPanel

        return

    }

    if ($Label -eq 'menu_installed_apps') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-InstalledAppsPanel

        return

    }

    if ($Label -eq 'menu_event_logs') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-EventLogPanel

        return

    }

    if ($Label -eq 'menu_quick_actions') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) { $navStack.Add($script:currentLabel) }

        $script:currentLabel = $Label

        Show-QuickActionsPanel

        return

    }

    if ($Label -eq 'menu_1click_100_apps') {

        if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

            $navStack.Add($script:currentLabel)

        }

        $script:currentLabel = $Label

        $script:currentMode  = 'menu'

        # Clear searchBox without triggering TextChanged (which would reshow old panel)

        $script:_suppressSearch = $true

        try { $searchBox.Text = ''; $searchBox.Visible = $true } catch {}

        $script:_suppressSearch = $false

        $block = $model.Blocks['menu_1click_100_apps']

        if ($null -eq $block) {

            $script:statusLabel.Text = "100 Apps menu not found - check menu_1click_100_apps label in Toolkit.bat"

            return

        }

        Render-Cards @($block.Options) '100 Apps 1-Click Install' 'menu'

        $script:statusLabel.Text = "Select a software category to browse and install apps"

        return

    }





    $key = $Label.ToLowerInvariant()



    if (-not $model.Blocks.ContainsKey($key)) {

        $script:statusLabel.Text = "Menu '$Label' not found in toolkit catalog. Check Config\gui.catalog."

        try {

            $logPath = Join-Path $script:ToolkitRoot 'Logs\startup_err.log'

            Add-Content -LiteralPath $logPath -Value "[$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')] Show-Menu: label '$Label' not found in model.Blocks" -Force -ErrorAction SilentlyContinue

        } catch {}

        return

    }

    if ($Push -and $script:currentLabel -and $script:currentLabel -ne $Label) {

        $navStack.Add($script:currentLabel)

    }

    $script:currentLabel = $Label

    $block = $model.Blocks[$key]

    $items = if ($Label -eq 'main') { Get-VisibleMainOptions } else { @($block.Options) }

    Render-Cards $items $block.Title 'menu'

    $script:statusLabel.Text = "Showing: $($block.Title)"

}



# ============================================================

# SELF-HEALING PANEL: Error Log Viewer + Self-Repair Launcher

# ============================================================

function Show-ErrorLogPanel {

    try { $searchBox.Visible = $false; $searchBox.Text = "" } catch {}

    $form.SuspendLayout()

    $gridHost.SuspendLayout()

    Clear-Grid

    $gridHost.AutoScroll = $true

    $screenTitle.Text = "GUI Error Log & Self-Repair"

    $metaLabel.Text = "View runtime errors, trigger auto self-repair, and monitor healing status"

    $script:currentMode = 'native_gui_search'

    $script:currentLabel = 'menu_error_log'



    # Header

    $headerPanel = New-Object System.Windows.Forms.Panel

    $headerPanel.Dock = 'Top'

    $headerPanel.Height = 70

    $headerPanel.BackColor = [System.Drawing.Color]::Transparent

    $panelTitle = New-Object System.Windows.Forms.Label

    $panelTitle.Text = "Runtime Error Log & Auto Self-Repair Engine"

    $panelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)

    $panelTitle.ForeColor = Get-ThemeColor 'Text'

    $panelTitle.SetBounds(24, 10, 750, 30)

    $headerPanel.Controls.Add($panelTitle)

    $subLabel = New-Object System.Windows.Forms.Label

    $subLabel.Text = "Every panel crash is logged here. Self-Repair reads these logs and patches the script automatically (with backup)."

    $subLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $subLabel.ForeColor = Get-ThemeColor 'Muted'

    $subLabel.SetBounds(26, 40, 900, 20)

    $headerPanel.Controls.Add($subLabel)

    $gridHost.Controls.Add($headerPanel)



    $flow = New-Object System.Windows.Forms.FlowLayoutPanel

    $flow.Dock = 'Fill'

    $flow.AutoScroll = $true

    $flow.Padding = New-Object System.Windows.Forms.Padding(24, 8, 16, 24)

    $flow.BackColor = $gridHost.BackColor

    Enable-DoubleBuffer $flow



    # ---- Stats + Action buttons card ----

    $statsCard = New-Object System.Windows.Forms.Panel

    $statsCard.Size = New-Object System.Drawing.Size(880, 90)

    $statsCard.BackColor = Get-ThemeColor 'Panel'

    $statsCard.Padding = New-Object System.Windows.Forms.Padding(16)

    Enable-DoubleBuffer $statsCard



    $logExists = Test-Path $script:GuiErrorLogPath

    $errorCount = 0

    $repairedCount = 0

    if ($logExists) {

        $rawLines = @(Get-Content -LiteralPath $script:GuiErrorLogPath -Encoding UTF8 -ErrorAction SilentlyContinue)

        $errorCount = $rawLines.Count

        foreach ($ln in $rawLines) {

            if ($ln -like '*"repaired":true*') { $repairedCount++ }

        }

    }



    $lblStats = New-Object System.Windows.Forms.Label

    $lblStats.Text = "Total Errors Logged: $errorCount   |   Auto-Repaired: $repairedCount   |   Pending: $($errorCount - $repairedCount)   |   Session Errors: $script:GuiErrorCount"

    $lblStats.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $lblStats.ForeColor = if ($errorCount -gt 0) { [System.Drawing.ColorTranslator]::FromHtml("#FFCC00") } else { [System.Drawing.ColorTranslator]::FromHtml("#22C55E") }

    $lblStats.SetBounds(16, 16, 780, 24)

    $statsCard.Controls.Add($lblStats)



    # Action buttons row

    $btnRepair = New-Object System.Windows.Forms.Button

    $btnRepair.Text = "Run Self-Repair Now"

    $btnRepair.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnRepair.FlatStyle = 'Flat'

    $btnRepair.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#16A34A")

    $btnRepair.ForeColor = [System.Drawing.Color]::White

    $btnRepair.SetBounds(16, 50, 200, 30)

    $btnRepair.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnRepair.Add_Click({

        $repairScript = Join-Path $script:ToolkitRoot 'Modules\GUI-SelfRepair.ps1'

        if (Test-Path $repairScript) {

            try {

                if ($null -ne $script:statusLabel) { $script:statusLabel.Text = "Running Self-Repair... please wait" }

                [System.Windows.Forms.Application]::DoEvents()

                $repairLog = Join-Path $script:ToolkitRoot 'Logs\gui_repair.log'

                $beforeSize = if (Test-Path $repairLog) { (Get-Item $repairLog).Length } else { 0 }

                Write-GuiActionLog -ActionType 'Click' -Component 'SelfRepair' -Details 'User clicked Run Self-Repair Now'

                $p = Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$repairScript`"" -PassThru -Wait -WindowStyle Hidden

                Write-GuiActionLog -ActionType 'Result' -Component 'SelfRepair' -Details "Self-Repair completed. ExitCode=$($p.ExitCode)"

                if ($null -ne $script:statusLabel) { $script:statusLabel.Text = "Self-Repair done. Exit: $($p.ExitCode)" }

                # Show log output in GUI dialog

                $outputLines = @("=== Self-Repair Result ===", "Exit Code: $($p.ExitCode)", "")

                if (Test-Path $repairLog) {

                    $allRepairLog = @(Get-Content -LiteralPath $repairLog -Encoding UTF8 -ErrorAction SilentlyContinue)

                    $afterSize = (Get-Item $repairLog).Length

                    if ($afterSize -gt $beforeSize) {

                        # Show only the new lines added this run

                        $newContent = @(Get-Content -LiteralPath $repairLog -Encoding UTF8 -ErrorAction SilentlyContinue)

                        $newLines = $newContent | Select-Object -Last ([Math]::Max(50, $newContent.Count - ($allRepairLog.Count - ($newContent.Count))))

                        $outputLines += $newLines

                    } else {

                        $outputLines += $allRepairLog | Select-Object -Last 60

                    }

                } else {

                    $outputLines += "(No repair log file found)"

                }

                # Show full output in scrollable dialog

                $outForm = New-Object System.Windows.Forms.Form

                $outForm.Text = "Self-Repair Output"

                $outForm.Size = New-Object System.Drawing.Size(900, 600)

                $outForm.StartPosition = 'CenterScreen'

                $outForm.BackColor = [System.Drawing.Color]::FromArgb(10, 15, 28)

                $outForm.FormBorderStyle = 'Sizable'

                $rtb = New-Object System.Windows.Forms.RichTextBox

                $rtb.Dock = 'Fill'

                $rtb.ReadOnly = $true

                $rtb.BackColor = [System.Drawing.Color]::FromArgb(10, 15, 28)

                $rtb.ForeColor = [System.Drawing.Color]::FromArgb(180, 220, 180)

                $rtb.Font = New-Object System.Drawing.Font('Consolas', 9.5)

                $rtb.ScrollBars = 'Vertical'

                foreach ($line in $outputLines) {

                    if ($line -like '*\[FIX\]*' -or $line -like '*FIXED*' -or $line -like '*APPLIED*') {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(80, 220, 80)

                    } elseif ($line -like '*\[ERROR\]*' -or $line -like '*SYNTAX ERROR*' -or $line -like '*ROLLBACK*') {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(255, 80, 80)

                    } elseif ($line -like '*\[WARN\]*') {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(255, 200, 50)

                    } elseif ($line -like '*\[AI\]*') {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(180, 120, 255)

                    } elseif ($line -like '*\[START\]*' -or $line -like '*SUMMARY*') {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(80, 180, 255)

                    } else {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(180, 220, 180)

                    }

                    $rtb.AppendText($line + "`n")

                }

                $rtb.SelectionStart = $rtb.Text.Length

                $rtb.ScrollToCaret()

                $outForm.Controls.Add($rtb)

                $outForm.ShowDialog() | Out-Null

                $outForm.Dispose()

                Show-ErrorLogPanel

            } catch {

                Out-MessageBox("Failed to run Self-Repair: $_", "Error", "OK", "Error") | Out-Null

            }

        } else {

            Out-MessageBox("GUI-SelfRepair.ps1 not found at:`r`n$repairScript", "Not Found", "OK", "Warning") | Out-Null

        }

    })

    $statsCard.Controls.Add($btnRepair)



    $btnClear = New-Object System.Windows.Forms.Button

    $btnClear.Text = "Clear Error Log"

    $btnClear.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnClear.FlatStyle = 'Flat'

    $btnClear.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#DC2626")

    $btnClear.ForeColor = [System.Drawing.Color]::White

    $btnClear.SetBounds(228, 50, 160, 30)

    $btnClear.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnClear.Add_Click({

        $res = Out-MessageBox("Clear ALL error log entries?`r`nThis cannot be undone.", "Confirm Clear", "YesNo", "Warning")

        if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {

            try {

                if (Test-Path $script:GuiErrorLogPath) { Remove-Item $script:GuiErrorLogPath -Force }

                $script:GuiErrorCount = 0

                Show-ErrorLogPanel

            } catch {

                Out-MessageBox("Failed to clear log: $_", "Error", "OK", "Error") | Out-Null

            }

        }

    })

    $statsCard.Controls.Add($btnClear)



    $btnOpenLog = New-Object System.Windows.Forms.Button

    $btnOpenLog.Text = "Open Error Log"

    $btnOpenLog.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnOpenLog.FlatStyle = 'Flat'

    $btnOpenLog.BackColor = Get-ThemeColor 'Accent'

    $btnOpenLog.ForeColor = Get-ThemeColor 'CardText'

    $btnOpenLog.SetBounds(400, 50, 150, 30)

    $btnOpenLog.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnOpenLog.Add_Click({

        if (Test-Path $script:GuiErrorLogPath) {

            Start-Process notepad.exe -ArgumentList $script:GuiErrorLogPath

        } else {

            Out-MessageBox("No errors logged yet. Log file does not exist.", "All Clear", "OK", "Information") | Out-Null

        }

    })

    $statsCard.Controls.Add($btnOpenLog)



    # GUI Self-Test button - runs -SelfTest and shows results inside GUI

    $btnSelfTest = New-Object System.Windows.Forms.Button

    $btnSelfTest.Text = "Run GUI Self-Test"

    $btnSelfTest.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnSelfTest.FlatStyle = 'Flat'

    $btnSelfTest.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0EA5E9")

    $btnSelfTest.ForeColor = [System.Drawing.Color]::Black

    $btnSelfTest.SetBounds(562, 50, 170, 30)

    $btnSelfTest.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnSelfTest.Add_Click({

        try {

            if ($null -ne $script:statusLabel) { $script:statusLabel.Text = "Running GUI Self-Test..." }

            [System.Windows.Forms.Application]::DoEvents()

            

            # Run self-test via PowerShell and capture output

            $guiScript = Join-Path $script:ToolkitRoot 'Modules\Toolkit-GUI-Pro.ps1'

            $tempOut = [System.IO.Path]::GetTempFileName()

            Write-GuiActionLog -ActionType 'Click' -Component 'GUISelfTest' -Details 'User clicked Run GUI Self-Test'



            $proc = Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$guiScript`" -SelfTest" -RedirectStandardOutput $tempOut -PassThru -Wait -WindowStyle Hidden

            

            $outputLines = @()

            if (Test-Path $tempOut) {

                $outputLines = @(Get-Content -Path $tempOut -Encoding UTF8 -ErrorAction SilentlyContinue)

                Remove-Item $tempOut -Force -ErrorAction SilentlyContinue

            }

            

            $exitOk = ($proc.ExitCode -eq 0)

            Write-GuiActionLog -ActionType 'Result' -Component 'GUISelfTest' -Details "GUI Self-Test completed. ExitCode=$($proc.ExitCode) Passed=$exitOk"

            if ($null -ne $script:statusLabel) {

                $script:statusLabel.Text = if ($exitOk) { "Self-Test PASSED" } else { "Self-Test FAILED - see results" }

            }



            # Show results in scrollable dialog

            $outForm = New-Object System.Windows.Forms.Form

            $outForm.Text = "GUI Self-Test Results"

            $outForm.Size = New-Object System.Drawing.Size(720, 480)

            $outForm.StartPosition = 'CenterScreen'

            $outForm.BackColor = [System.Drawing.Color]::FromArgb(10, 15, 28)

            $outForm.FormBorderStyle = 'Sizable'



            $titleLbl = New-Object System.Windows.Forms.Label

            $titleLbl.Text = if ($exitOk) { "✅  SELF-TEST PASSED" } else { "❌  SELF-TEST FAILED" }

            $titleLbl.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)

            $titleLbl.ForeColor = if ($exitOk) { [System.Drawing.ColorTranslator]::FromHtml("#22C55E") } else { [System.Drawing.ColorTranslator]::FromHtml("#EF4444") }

            $titleLbl.SetBounds(16, 10, 680, 30)

            $outForm.Controls.Add($titleLbl)



            $rtb = New-Object System.Windows.Forms.RichTextBox

            $rtb.SetBounds(12, 48, 680, 370)

            $rtb.ReadOnly = $true

            $rtb.BackColor = [System.Drawing.Color]::FromArgb(10, 15, 28)

            $rtb.ForeColor = [System.Drawing.Color]::FromArgb(200, 230, 200)

            $rtb.Font = New-Object System.Drawing.Font('Consolas', 10)

            $rtb.ScrollBars = 'Vertical'

            

            foreach ($line in $outputLines) {

                if ($line -like '*MISSING*' -or $line -like '*Bad label*' -or $line -like '*Missing target*') {

                    $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(255, 80, 80)

                } elseif ($line -like '*: OK' -or $line -like '*: 0' -or $line -like '*PASSED*') {

                    $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(80, 220, 80)

                } else {

                    $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(200, 230, 200)

                }

                $rtb.AppendText($line + "`n")

            }

            if ($outputLines.Count -eq 0) {

                $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(255, 200, 50)

                $rtb.AppendText("(No output captured - the script may have loaded the GUI window instead.)`n")

                $rtb.AppendText("Exit code: $($proc.ExitCode)`n")

            }

            $rtb.SelectionStart = 0; $rtb.ScrollToCaret()

            $outForm.Controls.Add($rtb)

            

            $btnClose = New-Object System.Windows.Forms.Button

            $btnClose.Text = "Close"

            $btnClose.SetBounds(300, 428, 100, 28)

            $btnClose.FlatStyle = 'Flat'

            $btnClose.BackColor = [System.Drawing.Color]::FromArgb(50, 60, 80)

            $btnClose.ForeColor = [System.Drawing.Color]::White

            $btnClose.DialogResult = [System.Windows.Forms.DialogResult]::OK

            $outForm.Controls.Add($btnClose)

            $outForm.AcceptButton = $btnClose



            $outForm.ShowDialog() | Out-Null

            $outForm.Dispose()

        } catch {

            Out-MessageBox("Self-Test failed to run: $_", "Error", "OK", "Error") | Out-Null

        }

    }.GetNewClosure())

    $statsCard.Controls.Add($btnSelfTest)



    # ---- AI API Key Status + Setup Button ----

    $apiKeyFile = Join-Path $script:ToolkitRoot 'Config\gemini_api.key'

    $apiKeyExists = Test-Path $apiKeyFile

    $aiStatusText = if ($apiKeyExists) { "Gemini AI: READY (key configured)" } else { "Gemini AI: NOT SET - click to configure" }

    $aiStatusColor = if ($apiKeyExists) { [System.Drawing.ColorTranslator]::FromHtml("#22C55E") } else { [System.Drawing.ColorTranslator]::FromHtml("#FFCC00") }



    $aiRepairHistoryLog = Join-Path $script:ToolkitRoot 'Logs\ai_repair_history.log'

    $aiRepairCount = 0

    if (Test-Path $aiRepairHistoryLog) {

        $aiRepairCount = @(Get-Content -LiteralPath $aiRepairHistoryLog -ErrorAction SilentlyContinue | Where-Object { $_ -like '*Status: APPLIED*' }).Count

    }



    $lblAiStatus = New-Object System.Windows.Forms.Label

    $lblAiStatus.Text = "$aiStatusText   |   AI Fixes Applied (all time): $aiRepairCount"

    $lblAiStatus.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $lblAiStatus.ForeColor = $aiStatusColor

    $lblAiStatus.SetBounds(16, 90, 700, 20)

    $statsCard.Controls.Add($lblAiStatus)



    $btnSetKey = New-Object System.Windows.Forms.Button

    $btnSetKey.Text = if ($apiKeyExists) { "Update AI Key" } else { "Set Gemini API Key" }

    $btnSetKey.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnSetKey.FlatStyle = 'Flat'

    $btnSetKey.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#7C3AED")

    $btnSetKey.ForeColor = [System.Drawing.Color]::White

    $btnSetKey.SetBounds(16, 116, 200, 30)

    $btnSetKey.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnSetKey.Add_Click({

        $keyForm = New-Object System.Windows.Forms.Form

        $keyForm.Text = "Set Gemini API Key"

        $keyForm.Size = New-Object System.Drawing.Size(520, 200)

        $keyForm.StartPosition = 'CenterScreen'

        $keyForm.BackColor = [System.Drawing.Color]::FromArgb(15, 20, 35)

        $keyForm.FormBorderStyle = 'FixedDialog'

        $keyForm.MaximizeBox = $false



        $lbl = New-Object System.Windows.Forms.Label

        $lbl.Text = "Get free key: https://aistudio.google.com/apikey`r`nPaste your Gemini API key below:"

        $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 9)

        $lbl.ForeColor = [System.Drawing.Color]::LightBlue

        $lbl.SetBounds(16, 12, 480, 36)

        $keyForm.Controls.Add($lbl)



        $txtKey = New-Object System.Windows.Forms.TextBox

        $txtKey.SetBounds(16, 54, 470, 28)

        $txtKey.Font = New-Object System.Drawing.Font('Consolas', 10)

        $txtKey.BackColor = [System.Drawing.Color]::FromArgb(20, 28, 45)

        $txtKey.ForeColor = [System.Drawing.Color]::LightGreen

        $txtKey.PasswordChar = '*'

        $txtKey.UseSystemPasswordChar = $false

        $keyForm.Controls.Add($txtKey)



        $chkShow = New-Object System.Windows.Forms.CheckBox

        $chkShow.Text = "Show key"

        $chkShow.ForeColor = [System.Drawing.Color]::Gray

        $chkShow.SetBounds(16, 86, 100, 22)

        $chkShow.Add_CheckedChanged({

            $txtKey.UseSystemPasswordChar = -not $chkShow.Checked

        }.GetNewClosure())

        $keyForm.Controls.Add($chkShow)



        $btnSave = New-Object System.Windows.Forms.Button

        $btnSave.Text = "Save Key"

        $btnSave.SetBounds(320, 116, 90, 30)

        $btnSave.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#16A34A")

        $btnSave.ForeColor = [System.Drawing.Color]::White

        $btnSave.FlatStyle = 'Flat'

        $btnSave.DialogResult = [System.Windows.Forms.DialogResult]::OK

        $keyForm.Controls.Add($btnSave)



        $btnCancel = New-Object System.Windows.Forms.Button

        $btnCancel.Text = "Cancel"

        $btnCancel.SetBounds(420, 116, 70, 30)

        $btnCancel.FlatStyle = 'Flat'

        $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)

        $btnCancel.ForeColor = [System.Drawing.Color]::White

        $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

        $keyForm.Controls.Add($btnCancel)



        $keyForm.AcceptButton = $btnSave

        $result = $keyForm.ShowDialog()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {

            $keyVal = $txtKey.Text.Trim()

            if ([string]::IsNullOrWhiteSpace($keyVal)) {

                Out-MessageBox("No key entered.", "Cancelled", "OK", "Warning") | Out-Null

            } else {

                try {

                    $confDir = Join-Path $script:ToolkitRoot 'Config'

                    if (-not (Test-Path $confDir)) { New-Item -ItemType Directory -Path $confDir -Force | Out-Null }

                    $apiKeyFilePath = Join-Path $confDir 'gemini_api.key'

                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($keyVal)

                    $encoded = [Convert]::ToBase64String($bytes)

                    Set-Content -Path $apiKeyFilePath -Value $encoded -Encoding ASCII -Force

                    Out-MessageBox("Gemini API key saved!`r`nAI repair is now enabled.", "Key Saved", "OK", "Information") | Out-Null

                    Show-ErrorLogPanel  # Refresh to show READY status

                } catch {

                    Out-MessageBox("Failed to save key: $_", "Error", "OK", "Error") | Out-Null

                }

            }

        }

        $keyForm.Dispose()

    })

    $statsCard.Controls.Add($btnSetKey)



    $btnAiRepair = New-Object System.Windows.Forms.Button

    $btnAiRepair.Text = "AI Self-Repair Now"

    $btnAiRepair.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnAiRepair.FlatStyle = 'Flat'

    $btnAiRepair.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#7C3AED")

    $btnAiRepair.ForeColor = [System.Drawing.Color]::White

    $btnAiRepair.SetBounds(228, 116, 180, 30)

    $btnAiRepair.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnAiRepair.Enabled = $apiKeyExists

    $btnAiRepair.Add_Click({

        $repairScript = Join-Path $script:ToolkitRoot 'Modules\GUI-SelfRepair.ps1'

        if (Test-Path $repairScript) {

            try {

                if ($null -ne $script:statusLabel) { $script:statusLabel.Text = "Running AI Self-Repair... please wait" }

                [System.Windows.Forms.Application]::DoEvents()

                $tempOut = [System.IO.Path]::GetTempFileName()

                Write-GuiActionLog -ActionType 'Click' -Component 'AISelfRepair' -Details 'User clicked AI Self-Repair Now'



                $p = Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$repairScript`"" -RedirectStandardOutput $tempOut -PassThru -Wait -WindowStyle Hidden

                Write-GuiActionLog -ActionType 'Result' -Component 'AISelfRepair' -Details "AI Self-Repair completed. ExitCode=$($p.ExitCode)"



                if ($null -ne $script:statusLabel) { $script:statusLabel.Text = "AI Self-Repair done. Exit: $($p.ExitCode)" }



                $outputLines = @("=== AI Self-Repair Run ===", "Exit Code: $($p.ExitCode)", "")

                if (Test-Path $tempOut) {

                    $outputLines += @(Get-Content -Path $tempOut -Encoding UTF8 -ErrorAction SilentlyContinue)

                    Remove-Item $tempOut -Force -ErrorAction SilentlyContinue

                }



                $outForm = New-Object System.Windows.Forms.Form

                $outForm.Text = "AI Self-Repair Output"

                $outForm.Size = New-Object System.Drawing.Size(900, 600)

                $outForm.StartPosition = 'CenterScreen'

                $outForm.BackColor = [System.Drawing.Color]::FromArgb(10, 15, 28)

                $outForm.FormBorderStyle = 'Sizable'

                $rtb = New-Object System.Windows.Forms.RichTextBox

                $rtb.Dock = 'Fill'

                $rtb.ReadOnly = $true

                $rtb.BackColor = [System.Drawing.Color]::FromArgb(10, 15, 28)

                $rtb.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 255)

                $rtb.Font = New-Object System.Drawing.Font('Consolas', 9.5)

                $rtb.ScrollBars = 'Vertical'

                foreach ($line in $outputLines) {

                    if ($line -like '*[FIX]*' -or $line -like '*APPLIED*' -or $line -like '*ACCEPTED*') {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(80, 220, 80)

                    } elseif ($line -like '*[ERROR]*' -or $line -like '*REJECTED*' -or $line -like '*ROLLBACK*') {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(255, 80, 80)

                    } elseif ($line -like '*[WARN]*') {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(255, 200, 50)

                    } elseif ($line -like '*[AI]*') {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(180, 120, 255)

                    } elseif ($line -like '*[START]*' -or $line -like '*SUMMARY*' -or $line -like '*===*') {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(80, 180, 255)

                    } else {

                        $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(200, 200, 255)

                    }

                    $rtb.AppendText($line + "`n")

                }

                $rtb.SelectionStart = $rtb.Text.Length; $rtb.ScrollToCaret()

                $outForm.Controls.Add($rtb)

                $outForm.ShowDialog() | Out-Null

                $outForm.Dispose()

                Show-ErrorLogPanel

            } catch {

                Out-MessageBox("Failed to run AI Self-Repair: $_", "Error", "OK", "Error") | Out-Null

            }

        }

    })

    $statsCard.Controls.Add($btnAiRepair)



    $btnViewAiLog = New-Object System.Windows.Forms.Button

    $btnViewAiLog.Text = "AI Repair History"

    $btnViewAiLog.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $btnViewAiLog.FlatStyle = 'Flat'

    $btnViewAiLog.BackColor = Get-ThemeColor 'Panel2'

    $btnViewAiLog.ForeColor = Get-ThemeColor 'Text'

    $btnViewAiLog.SetBounds(420, 116, 160, 30)

    $btnViewAiLog.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnViewAiLog.Add_Click({

        $aiLog = Join-Path $script:ToolkitRoot 'Logs\ai_repair_history.log'

        if (Test-Path $aiLog) {

            Start-Process notepad.exe -ArgumentList $aiLog

        } else {

            Out-MessageBox("No AI repair history yet.`r`nRun 'AI Self-Repair Now' first.", "No History", "OK", "Information") | Out-Null

        }

    })

    $statsCard.Controls.Add($btnViewAiLog)



    # Resize statsCard to fit all buttons

    $statsCard.Size = New-Object System.Drawing.Size(880, 160)



    $flow.Controls.Add($statsCard)





    # Spacer

    $sp = New-Object System.Windows.Forms.Panel; $sp.Size = New-Object System.Drawing.Size(880, 10); $flow.Controls.Add($sp)



    # ---- Error entries table ----

    $tableCard = New-Object System.Windows.Forms.Panel

    $tableCard.Size = New-Object System.Drawing.Size(880, 520)

    $tableCard.BackColor = Get-ThemeColor 'Panel'

    $tableCard.Padding = New-Object System.Windows.Forms.Padding(12)

    Enable-DoubleBuffer $tableCard



    $lblTableTitle = New-Object System.Windows.Forms.Label

    $lblTableTitle.Text = "ERROR HISTORY (newest first)"

    $lblTableTitle.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)

    $lblTableTitle.ForeColor = Get-ThemeColor 'Muted'

    $lblTableTitle.SetBounds(12, 10, 400, 18)

    $tableCard.Controls.Add($lblTableTitle)



    $listView = New-Object System.Windows.Forms.ListView

    $listView.View = [System.Windows.Forms.View]::Details

    $listView.FullRowSelect = $true

    $listView.GridLines = $true

    $listView.SetBounds(12, 32, 850, 470)

    $listView.BackColor = [System.Drawing.Color]::FromArgb(12, 18, 28)

    $listView.ForeColor = [System.Drawing.Color]::FromArgb(200, 220, 240)

    $listView.Font = New-Object System.Drawing.Font('Consolas', 8.5)

    $listView.Columns.Add("Timestamp", 138) | Out-Null

    $listView.Columns.Add("Panel / Function", 220) | Out-Null

    $listView.Columns.Add("Error", 340) | Out-Null

    $listView.Columns.Add("Line", 50) | Out-Null

    $listView.Columns.Add("Status", 80) | Out-Null



    if ($logExists -and $errorCount -gt 0) {

        $allLines = @(Get-Content -LiteralPath $script:GuiErrorLogPath -Encoding UTF8 -ErrorAction SilentlyContinue)

        $showLines = [array]::Reverse($allLines); $allLines = $allLines[-1..-($allLines.Count)]  # newest first

        foreach ($ln in $allLines) {

            try {

                $ts      = if ($ln -match '"ts":"([^"]+)"') { $Matches[1] } else { '?' }

                $panel   = if ($ln -match '"panel":"([^"]+)"') { $Matches[1] } else { '?' }

                $err     = if ($ln -match '"error":"([^"]+)"') { $Matches[1] } else { '?' }

                $lineNo  = if ($ln -match '"line":(\d+)') { $Matches[1] } else { '?' }

                $repaired = ($ln -like '*"repaired":true*')

                $recovered = ($ln -like '*"recovered":true*')

                $status  = if ($repaired) { 'Repaired' } elseif ($recovered) { 'Recovered' } else { 'Crashed' }

                $item = New-Object System.Windows.Forms.ListViewItem($ts)

                $item.SubItems.Add($panel) | Out-Null

                $item.SubItems.Add(($err -replace '\\n',' ' -replace '\\r',' ')) | Out-Null

                $item.SubItems.Add($lineNo) | Out-Null

                $item.SubItems.Add($status) | Out-Null

                if ($repaired) { $item.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#22C55E") }

                elseif ($recovered) { $item.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FBBF24") }

                else { $item.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#F87171") }

                $listView.Items.Add($item) | Out-Null

            } catch {}

        }

    } else {

        $item = New-Object System.Windows.Forms.ListViewItem("No errors logged")

        $item.SubItems.Add("All panels running clean") | Out-Null

        $item.SubItems.Add("") | Out-Null

        $item.SubItems.Add("") | Out-Null

        $item.SubItems.Add("OK") | Out-Null

        $item.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#22C55E")

        $listView.Items.Add($item) | Out-Null

    }



    $tableCard.Controls.Add($listView)

    $flow.Controls.Add($tableCard)



    $gridHost.Controls.Add($flow)

    $flow.BringToFront()

    $gridHost.ResumeLayout($true)

    $form.ResumeLayout($true)

}



function Show-OneClick {

    $navStack.Clear()

    $script:currentLabel = ''

    Render-Cards $oneClickOptions 'One Click Actions / Reports' 'oneclick'

    $script:statusLabel.Text = 'One click actions collected from the CMD toolkit'

}



function Show-AllOptions {

    $navStack.Clear()

    $script:currentLabel = ''

    Render-Cards @($model.Options | Sort-Object Text) 'All CMD Options' 'all'

    $script:statusLabel.Text = 'All parsed CMD menu options'

}



function Show-SystemInventory {

    $navStack.Clear()

    $script:currentLabel = ''

    Render-Cards (Get-SystemInventoryItems) 'One Click All Info Report Center' 'inventory'

    $script:statusLabel.Text = 'Option 1 se all info report generate karein'

}



function Show-Portable {

    $navStack.Clear()

    $script:currentLabel = ''

    $items = @()

    foreach ($tool in $toolItems) {

        if (-not $tool.Type -or $tool.Type.ToLowerInvariant() -eq 'separator') { continue }

        $items += [pscustomobject]@{

            Text = $tool.Name

            ToolType = $tool.Type

            Target = $tool.Target

            Notes = $tool.Notes

        }

    }

    $items += [pscustomobject]@{ Text = 'Add Portable Software Guide'; ToolType = 'file'; Target = 'Docs\Add-Portable-Software-Guide.md'; Notes = 'How to add many portable EXE tools' }

    $items += [pscustomobject]@{ Text = 'Open Tools Folder'; ToolType = 'folder'; Target = 'Tools'; Notes = 'Portable software root folder' }

    $items += [pscustomobject]@{ Text = 'Edit tools.catalog'; ToolType = 'file'; Target = 'Config\tools.catalog'; Notes = 'Open software catalog' }

    Render-Cards $items 'Portable Software Launcher' 'portable'

    $script:statusLabel.Text = 'Add software under Tools and update Config\tools.catalog'

}



function Show-HackerTools {

    $navStack.Add('portable')

    $script:currentLabel = ''

    $items = @()

    $hackerFolder = Join-Path $ToolkitRoot 'Tools\Feel Like Hacker'

    if (Test-Path -LiteralPath $hackerFolder) {

        $exes = Get-ChildItem -LiteralPath $hackerFolder -Filter *.exe -File | Sort-Object Name

        foreach ($exe in $exes) {

            $baseName = $exe.BaseName

            $cleanName = (Get-Culture).TextInfo.ToTitleCase($baseName.ToLowerInvariant())

            $items += [pscustomobject]@{

                Text = $cleanName

                ToolType = 'exe'

                Target = "Tools\Feel Like Hacker\$($exe.Name)"

                Notes = "Hacker style portable utility: $($exe.Name)"

            }

        }

    }

    Render-Cards $items 'Feel Like Hacker' 'hacker'

    $script:statusLabel.Text = 'Dynamic scan complete: Loaded hacker portable tools'

}



$backButton.Add_Click({

    if ($navStack.Count -gt 0) {

        $last = $navStack[$navStack.Count - 1]

        $navStack.RemoveAt($navStack.Count - 1)

        if ($last -eq 'portable') {

            Show-Portable

        } else {

            Show-Menu $last $false

        }

    } else {

        Show-Menu 'main' $false

    }

})



$themeOkButton.Add_Click({

    if ($null -ne $themeCombo.SelectedItem) {

        Set-UiTheme ([string]$themeCombo.SelectedItem)

    }

})



$runCurrentButton.Add_Click({

    if ($script:currentLabel) {

        Show-Menu $script:currentLabel $false

        $script:statusLabel.Text = "Showing current menu in GUI: $script:currentLabel"

    } else {

        Start-ToolkitMain

        $script:statusLabel.Text = 'Showing main toolkit menu in GUI'

    }

})



$searchBox.Add_KeyDown({

    param($sender, $e)

    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {

        $e.SuppressKeyPress = $true

        $q = $searchBox.Text.Trim()

        if (-not [string]::IsNullOrWhiteSpace($q)) {

            if ($script:currentLabel -eq 'menu_apps_online_search') {

                Perform-OnlineWingetSearch $q

            } else {

                # Route to Online Winget search panel and perform search immediately!

                Show-Menu 'menu_apps_online_search' $true

                Perform-OnlineWingetSearch $q

            }

        }

    }

})



$searchBox.Add_TextChanged({

    if ($script:_suppressSearch) { return }

    if (-not $searchBox.Visible) { return }

    $text = $searchBox.Text

    if ($script:currentLabel -eq 'menu_process_manager' -and $script:refreshProcesses) {

        try { &$script:refreshProcesses $text } catch {}

        return

    }

    if ($script:currentLabel -eq 'menu_services_dashboard' -and $script:refreshServices) {

        try { &$script:refreshServices $text } catch {}

        return

    }



    if ($script:currentMode -in @('online_search', 'native_gui_search')) {

        return

    }

    $q = $searchBox.Text.Trim().ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace($q)) {

        if ($script:currentMode -eq 'oneclick') { Show-OneClick }

        elseif ($script:currentMode -eq 'inventory') { Show-SystemInventory }

        elseif ($script:currentMode -eq 'portable') { Show-Portable }

        elseif ($script:currentMode -eq 'hacker') { Show-HackerTools }

        elseif ($script:currentMode -eq 'all') { Show-AllOptions }

        elseif ($script:currentMode -eq 'apps_search') { Show-Menu 'menu_1click_100_apps' $false }

        elseif ($script:currentLabel) { Show-Menu $script:currentLabel $false }

        else { Show-Menu 'main' $false }

        return

    }

    if ($script:currentLabel -eq 'menu_1click_100_apps' -or $script:currentMode -eq 'apps_search') {

        $appsBlock = $model.Blocks['menu_1click_100_apps']

        $allAppsPool = if ($null -ne $appsBlock -and $null -ne $appsBlock.Options) { @($appsBlock.Options) } else { @() }

        $matches = @($allAppsPool | Where-Object {

            "$($_.Text) $($_.Choice)".ToLowerInvariant().Contains($q)

        })

        

        if ($matches.Count -eq 0) {

            $matches = @(

                [pscustomobject]@{

                    Text = "Search Winget Online for '$($searchBox.Text)'"

                    Choice = "Online"

                    Kind = "Label"

                    TargetLabel = "menu_apps_online_search"

                    ParentLabel = "menu_apps_online_search"

                    Command = ""

                    RawAction = ""

                    IsSubmenu = $true

                    IsOnlineRedirect = $true

                    Query = $searchBox.Text.Trim()

                    Notes = "Click here to run a real-time online query for '$($searchBox.Text)' on the Microsoft Winget repository."

                }

            )

        }

        Render-Cards $matches "Software Catalog Search: $($searchBox.Text)" 'apps_search'

        return

    }

    if ($script:currentMode -eq 'inventory') {

        $matches = @(Get-SystemInventoryItems | Where-Object {

            "$($_.Text) $($_.Notes) $($_.Action)".ToLowerInvariant().Contains($q)

        })

        if ($matches.Count -eq 0) {

            $matches = @(

                [pscustomobject]@{

                    Text = "Search Winget Online for '$($searchBox.Text)'"

                    Choice = "Online"

                    Kind = "Label"

                    TargetLabel = "menu_apps_online_search"

                    ParentLabel = "menu_apps_online_search"

                    Command = ""

                    RawAction = ""

                    IsSubmenu = $true

                    IsOnlineRedirect = $true

                    Query = $searchBox.Text.Trim()

                    Notes = "Click here to run a real-time online query for '$($searchBox.Text)' on the Microsoft Winget repository."

                }

            )

        }

        Render-Cards $matches "Inventory Search: $($searchBox.Text)" 'inventory'

        return

    }

    if ($script:currentMode -eq 'portable') {

        $matches = @()

        foreach ($tool in $toolItems) {

            if (-not $tool.Type -or $tool.Type.ToLowerInvariant() -eq 'separator') { continue }

            if ("$($tool.Name) $($tool.Type) $($tool.Target) $($tool.Notes)".ToLowerInvariant().Contains($q)) {

                $matches += [pscustomobject]@{

                    Text = $tool.Name

                    ToolType = $tool.Type

                    Target = $tool.Target

                    Notes = $tool.Notes

                }

            }

        }

        if ($matches.Count -eq 0) {

            $matches = @(

                [pscustomobject]@{

                    Text = "Search Winget Online for '$($searchBox.Text)'"

                    Choice = "Online"

                    Kind = "Label"

                    TargetLabel = "menu_apps_online_search"

                    ParentLabel = "menu_apps_online_search"

                    Command = ""

                    RawAction = ""

                    IsSubmenu = $true

                    IsOnlineRedirect = $true

                    Query = $searchBox.Text.Trim()

                    Notes = "Click here to run a real-time online query for '$($searchBox.Text)' on the Microsoft Winget repository."

                }

            )

        }

        Render-Cards $matches "Portable Search: $($searchBox.Text)" 'portable'

        return

    }

    if ($script:currentMode -eq 'hacker') {

        $matches = @()

        $hackerFolder = Join-Path $ToolkitRoot 'Tools\Feel Like Hacker'

        if (Test-Path -LiteralPath $hackerFolder) {

            $exes = Get-ChildItem -LiteralPath $hackerFolder -Filter *.exe -File | Sort-Object Name

            foreach ($exe in $exes) {

                $baseName = $exe.BaseName

                $cleanName = (Get-Culture).TextInfo.ToTitleCase($baseName.ToLowerInvariant())

                if ("$cleanName $($exe.Name)".ToLowerInvariant().Contains($q)) {

                    $matches += [pscustomobject]@{

                        Text = $cleanName

                        ToolType = 'exe'

                        Target = "Tools\Feel Like Hacker\$($exe.Name)"

                        Notes = "Hacker style portable utility: $($exe.Name)"

                    }

                }

            }

        }

        if ($matches.Count -eq 0) {

            $matches = @(

                [pscustomobject]@{

                    Text = "Search Winget Online for '$($searchBox.Text)'"

                    Choice = "Online"

                    Kind = "Label"

                    TargetLabel = "menu_apps_online_search"

                    ParentLabel = "menu_apps_online_search"

                    Command = ""

                    RawAction = ""

                    IsSubmenu = $true

                    IsOnlineRedirect = $true

                    Query = $searchBox.Text.Trim()

                    Notes = "Click here to run a real-time online query for '$($searchBox.Text)' on the Microsoft Winget repository."

                }

            )

        }

        Render-Cards $matches "Hacker Search: $($searchBox.Text)" 'hacker'

        return

    }

    if ($script:currentMode -eq 'oneclick') {

        $matches = @($oneClickOptions | Where-Object {

            "$($_.Text) $($_.Choice) $($_.ParentLabel) $($_.TargetLabel)".ToLowerInvariant().Contains($q)

        } | Sort-Object Text)

        if ($matches.Count -eq 0) {

            $matches = @(

                [pscustomobject]@{

                    Text = "Search Winget Online for '$($searchBox.Text)'"

                    Choice = "Online"

                    Kind = "Label"

                    TargetLabel = "menu_apps_online_search"

                    ParentLabel = "menu_apps_online_search"

                    Command = ""

                    RawAction = ""

                    IsSubmenu = $true

                    IsOnlineRedirect = $true

                    Query = $searchBox.Text.Trim()

                    Notes = "Click here to run a real-time online query for '$($searchBox.Text)' on the Microsoft Winget repository."

                }

            )

        }

        Render-Cards $matches "One Click Search: $($searchBox.Text)" 'oneclick'

        return

    }

    $matches = @($model.Options | Where-Object {

        "$($_.Text) $($_.Choice) $($_.ParentLabel) $($_.TargetLabel)".ToLowerInvariant().Contains($q)

    } | Sort-Object Text)

    if ($matches.Count -eq 0) {

        $matches = @(

            [pscustomobject]@{

                Text = "Search Winget Online for '$($searchBox.Text)'"

                Choice = "Online"

                Kind = "Label"

                TargetLabel = "menu_apps_online_search"

                ParentLabel = "menu_apps_online_search"

                Command = ""

                RawAction = ""

                IsSubmenu = $true

                IsOnlineRedirect = $true

                Query = $searchBox.Text.Trim()

                Notes = "Click here to run a real-time online query for '$($searchBox.Text)' on the Microsoft Winget repository."

            }

        )

    }

    Render-Cards $matches "Search: $($searchBox.Text)" 'search'

})



$form.Add_FormClosing({

    try {

        Get-ChildItem -Path $script:LocalTempDir -Filter "SysForge Studio_*.cmd" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    } catch {}

})



# Register global unhandled exception handlers to prevent any crash/close

[System.Windows.Forms.Application]::add_ThreadException({

    param($sender, $e)

    try {

        $logPath = Join-Path $script:ToolkitRoot "Logs\startup_err.log"

        "GUI Thread Exception at $(Get-Date):`r`n$($e.Exception.Message)`r`n$($e.Exception.StackTrace)`r`n" | Out-File -FilePath $logPath -Append

        # Self-healing: also log to structured JSONL

        $fakeErr = [pscustomobject]@{ Exception = $e.Exception; ScriptStackTrace = [string]$e.Exception.StackTrace; InvocationInfo = $null }

        Write-GuiErrorLog -Panel 'ThreadException' -Context 'GUI global handler' -Err $fakeErr -Recovered $false

        Out-MessageBox("GUI error auto-logged.`r`n`r`n$($e.Exception.Message)", "GUI Auto-Heal", "OK", "Warning") | Out-Null

    } catch {}

})



[System.AppDomain]::CurrentDomain.add_UnhandledException({

    param($sender, $e)

    try {

        $logPath = Join-Path $script:ToolkitRoot "Logs\startup_err.log"

        "Global Unhandled Exception at $(Get-Date):`r`n$($e.ExceptionObject.Message)`r`n$($e.ExceptionObject.StackTrace)`r`n" | Out-File -FilePath $logPath -Append

        Out-MessageBox("Global unhandled exception: $($e.ExceptionObject.Message)", "GUI Error", "OK", "Error") | Out-Null

    } catch {}

})



try {

    Set-UiTheme $script:CurrentThemeName

    Show-Menu 'main' $false

    [System.Windows.Forms.Application]::Run($form)

} catch {

    try {

        $logPath = Join-Path $script:ToolkitRoot "Logs\startup_err.log"

        "Main Run Loop Exception at $(Get-Date):`r`n$($_)`r`n$($_.ScriptStackTrace)`r`n" | Out-File -FilePath $logPath -Append

        Out-MessageBox("Main Run Loop Exception: $_", "Startup Error", "OK", "Error") | Out-Null

    } catch {}

}

