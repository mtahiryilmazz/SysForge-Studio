# =======================================================================
# GUI-SelfRepair.ps1 — AI-Powered GUI Self-Repair Engine
# UltimateToolkit v5 Pro
# Scans gui_errors.jsonl, applies pattern + AI fixes to Toolkit-GUI-Pro.ps1
# =======================================================================

param(
    [string]$GuiScript    = '',
    [string]$ErrorLog     = '',
    [string]$RepairLog    = '',
    [string]$ApiKey       = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'

# ============================================================
# PATHS
# ============================================================
$ScriptDir     = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { Get-Location }
$ToolkitRoot   = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir '..'))

if (-not $GuiScript) { $GuiScript  = Join-Path $ToolkitRoot 'Modules\Toolkit-GUI-Pro.ps1' }
if (-not $ErrorLog)  { $ErrorLog   = Join-Path $ToolkitRoot 'Logs\gui_errors.jsonl' }
if (-not $RepairLog) { $RepairLog  = Join-Path $ToolkitRoot 'Logs\gui_repair.log' }
$BackupDir     = Join-Path $ToolkitRoot 'Backups'
$ApiKeyFile    = Join-Path $ToolkitRoot 'Config\gemini_api.key'
$AiRepairLog   = Join-Path $ToolkitRoot 'Logs\ai_repair_history.log'

# ============================================================
# LOGGING
# ============================================================
function Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] [$Level] $Msg"
    Write-Output $line
    try { $line | Out-File -LiteralPath $RepairLog -Encoding UTF8 -Append } catch {}
}

function Save-ApiKey {
    param([string]$Key)
    $Key | Out-File -LiteralPath $ApiKeyFile -Encoding UTF8 -Force
}

function Get-ApiKey {
    # First try parameter
    if ($ApiKey) { return $ApiKey }
    
    # Then try web GUI settings file (Config\ai_settings.json)
    $aiSettingsFile = Join-Path $ToolkitRoot 'Config\ai_settings.json'
    if (Test-Path $aiSettingsFile) {
        try {
            $settings = Get-Content -LiteralPath $aiSettingsFile -Raw | ConvertFrom-Json
            if ($settings.geminiKey) { return $settings.geminiKey }
        } catch {}
    }
    
    # Fallback to key file
    if (Test-Path $ApiKeyFile) {
        $key = (Get-Content -LiteralPath $ApiKeyFile -Raw -ErrorAction SilentlyContinue).Trim()
        if ($key) { return $key }
    }
    return $null
}

# ============================================================
# GEMINI AI CALL
# ============================================================
function Invoke-GeminiAI {
    param(
        [string]$Prompt,
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 5
    )
    $key = Get-ApiKey
    if (-not $key) {
        Log "No Gemini API key configured - skipping AI fix" 'WARN'
        return $null
    }
    
    $url  = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$key"
    $body = @{
        contents = @(@{ parts = @(@{ text = $Prompt }) })
        generationConfig = @{ temperature = 0.1; maxOutputTokens = 4096 }
    } | ConvertTo-Json -Depth 6
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $resp = Invoke-RestMethod -Uri $url -Method POST -Body $body -ContentType 'application/json' -TimeoutSec 60 -ErrorAction Stop
            $text = $resp.candidates[0].content.parts[0].text
            if ($text) { return $text }
            Log "Gemini returned empty text (attempt $attempt)" 'WARN'
        } catch {
            $errMsg = $_.Exception.Message
            if ($errMsg -like '*429*' -or $errMsg -like '*quota*') {
                Log "Rate limited on attempt $attempt - waiting ${RetryDelaySeconds}s" 'WARN'
                Start-Sleep -Seconds $RetryDelaySeconds
            } else {
                Log "Gemini API failed after $MaxRetries attempts: $errMsg" 'ERROR'
                return $null
            }
        }
    }
    return $null
}

# ============================================================
# RESOLVE PANEL LINE NUMBER IN SCRIPT
# ============================================================
function Resolve-PanelLineNumber {
    param([string]$PanelName)
    if ([string]::IsNullOrWhiteSpace($PanelName) -or $PanelName -eq 'ThreadException') { return 0 }
    if (Test-Path $GuiScript) {
        $scriptLines = Get-Content -LiteralPath $GuiScript -ErrorAction SilentlyContinue
        for ($idx = 0; $idx -lt $scriptLines.Count; $idx++) {
            if ($scriptLines[$idx] -match "function\s+Show-$PanelName" -or $scriptLines[$idx] -match "function\s+Show-$($PanelName)Panel" -or $scriptLines[$idx] -match "function\s+$PanelName\b") {
                return $idx + 1
            }
        }
    }
    return 0
}

# ============================================================
# EXTRACT CODE CONTEXT AROUND ERROR LINE
# ============================================================
function Get-CodeContext {
    param(
        [string[]]$Lines,
        [int]$ErrorLine,
        [string]$PanelName,
        [int]$Context = 60
    )

    # Try to find the panel function start
    $funcStart = 0
    $funcEnd   = $Lines.Count - 1
    $panelFuncName = $PanelName -replace '^Invoke-ItemClick.*', ''

    if ($panelFuncName -match '^Show-') {
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -match "^function $([regex]::Escape($panelFuncName))\s*\{") {
                $funcStart = $i
                # Find closing brace
                $depth = 0
                for ($j = $i; $j -lt $Lines.Count; $j++) {
                    $depth += ($Lines[$j].ToCharArray() | Where-Object { $_ -eq '{' }).Count
                    $depth -= ($Lines[$j].ToCharArray() | Where-Object { $_ -eq '}' }).Count
                    if ($depth -le 0 -and $j -gt $i) {
                        $funcEnd = $j
                        break
                    }
                }
                break
            }
        }
    }

    # If error line is known, center context on it
    $center = if ($ErrorLine -gt 0) { $ErrorLine - 1 } else { [Math]::Floor(($funcStart + $funcEnd) / 2) }
    $startIdx = [Math]::Max($funcStart, $center - $Context)
    $endIdx   = [Math]::Min($funcEnd,   $center + $Context)

    $contextLines = @()
    for ($i = $startIdx; $i -le $endIdx; $i++) {
        $lineNum = $i + 1
        $marker  = if ($i -eq ($ErrorLine - 1)) { " <-- ERROR HERE" } else { "" }
        $contextLines += ("L{0:D5}: {1}{2}" -f $lineNum, $Lines[$i], $marker)
    }

    return @{
        Code      = $contextLines -join "`n"
        StartLine = $startIdx + 1
        EndLine   = $endIdx + 1
    }
}

# ============================================================
# BUILD GEMINI PROMPT
# ============================================================
function Build-RepairPrompt {
    param(
        [string]$PanelName,
        [string]$ErrorMessage,
        [int]$ErrorLine,
        [string]$StackTrace,
        [string]$CodeContext,
        [int]$CtxStartLine,
        [int]$CtxEndLine
    )

    return @"
You are an expert PowerShell 5.1 and Windows Forms (WinForms) developer.

TASK: Fix a bug in a PowerShell WinForms desktop application (UltimateToolkit).

ERROR DETAILS:
  Panel/Function : $PanelName
  Error Message  : $ErrorMessage
  Error Line     : $ErrorLine
  Stack Trace    : $StackTrace

CODE CONTEXT (Lines $CtxStartLine-$CtxEndLine of the file):
$CodeContext

INSTRUCTIONS:
1. Identify the root cause of the error
2. Provide the COMPLETE fixed version of the entire shown code block (lines $CtxStartLine-$CtxEndLine)
3. Do NOT truncate, summarize or omit any lines - output ALL lines from $CtxStartLine to $CtxEndLine
4. Wrap your fixed code block in triple backticks (```)
5. Common patterns to fix:
   - Null reference: wrap in null-check: if (`$control -and `$control.IsDisposed -eq `$false)
   - Property not found: add -ErrorAction SilentlyContinue and null check
   - WaitForExit() infinite: replace with WaitForExit(30000)
   - DialogResult string: replace with [System.Windows.Forms.DialogResult]::Yes etc
   - Inner function scope death: move function to script: scope
6. Inner function scope death: function defined inside Show-X panel not visible in event handlers after panel function returns. Fix: move to `$script:_funcName = { ... }` scriptblock.

Only output the fixed code block. No explanations outside of code comments.
"@
}

# ============================================================
# APPLY AI FIX
# ============================================================
function Apply-AiFix {
    param(
        [string[]]$AllLines,
        [string]$FixedCode,
        [int]$StartLine,
        [int]$EndLine
    )

    $cleaned = $FixedCode -replace '(?s)^```+\w*\r?\n?', '' -replace '(?s)\r?\n?```+$', ''
    $cleaned = $cleaned.Trim("`r", "`n", " ")

    # Build new content
    $before    = $AllLines[0..($StartLine - 2)]      # lines before context
    $after     = $AllLines[$EndLine..($AllLines.Count - 1)]  # lines after context
    $fixedLines = $cleaned -split '\r?\n'

    $newLines   = @()
    if ($before.Count -gt 0) { $newLines += $before }
    $newLines  += $fixedLines
    if ($after.Count -gt 0)  { $newLines += $after }

    return $newLines -join "`n"
}

# ============================================================
# MAIN START
# ============================================================
$dryTag = if ($DryRun) { '[DRY RUN] ' } else { '' }
Log ("=== GUI-SelfRepair.ps1 (AI Edition) started $dryTag===") 'START'
Log "Target : $GuiScript"
Log "Log    : $ErrorLog"

if (-not (Test-Path $GuiScript)) {
    Log "FATAL: GUI script not found" 'ERROR'; exit 1
}

# ============================================================
# READ ERROR LOG
# ============================================================
$allErrors = @()
if (Test-Path $ErrorLog) {
    $rawLines = @(Get-Content -LiteralPath $ErrorLog -Encoding UTF8 -ErrorAction SilentlyContinue)
    foreach ($rawLine in $rawLines) {
        if ([string]::IsNullOrWhiteSpace($rawLine)) { continue }
        try {
            $parsed = ConvertFrom-Json $rawLine -ErrorAction Stop
            $obj = [ordered]@{
                ts        = $parsed.ts
                panel     = $parsed.panel
                context   = $parsed.context
                error     = $parsed.error
                line      = [int]$parsed.line
                stack     = $parsed.stack
                recovered = [bool]$parsed.recovered
                repaired  = [bool]$parsed.repaired
                rawLine   = $rawLine
            }
            $allErrors += [pscustomobject]$obj
        } catch {
            try {
                $obj = [ordered]@{ ts=''; panel=''; context=''; error=''; line=0; stack=''; recovered=$false; repaired=$false; rawLine=$rawLine }
                if ($rawLine -match '"ts":"([^"]+)"')      { $obj.ts      = $Matches[1] }
                if ($rawLine -match '"panel":"([^"]+)"')   { $obj.panel   = $Matches[1] }
                if ($rawLine -match '"context":"([^"]*)"') { $obj.context = $Matches[1] }
                if ($rawLine -match '"error":"([^"]*)"')   { $obj.error   = $Matches[1] }
                if ($rawLine -match '"line":(\d+)')        { $obj.line    = [int]$Matches[1] }
                if ($rawLine -match '"stack":"([^"]*)"')   { $obj.stack   = $Matches[1] }
                $obj.recovered = ($rawLine -like '*"recovered":true*')
                $obj.repaired  = ($rawLine -like '*"repaired":true*')
                $allErrors += [pscustomobject]$obj
            } catch {}
        }
    }
    Log "Loaded $($allErrors.Count) entries ($(@($allErrors | Where-Object { $_.repaired }).Count) already repaired)"
    # Dynamically resolve line numbers for panel errors that have line=0
    foreach ($err in $allErrors) {
        if ($err.line -eq 0 -and $err.panel) {
            $resolvedLine = Resolve-PanelLineNumber $err.panel
            if ($resolvedLine -gt 0) {
                $err.line = $resolvedLine
                Log "Resolved panel error [$($err.panel)] to L$resolvedLine in Toolkit-GUI-Pro.ps1"
            }
        }
    }
} else {
    Log "No error log found - nothing to repair" 'OK'
    exit 0
}

$unrepaired = @($allErrors | Where-Object { -not $_.repaired })
if ($unrepaired.Count -eq 0) {
    Log "All errors already repaired - nothing to do" 'OK'
    exit 0
}
Log "Unrepaired errors: $($unrepaired.Count)"

# ============================================================
# READ SCRIPT CONTENT
# ============================================================
$content  = Get-Content -LiteralPath $GuiScript -Raw -Encoding UTF8
$allLines = $content -split '\r?\n'
$fixesApplied = 0
$aiFixes      = 0
$fixLog = [System.Collections.Generic.List[string]]::new()
$contentModified = $content

# ============================================================
# PHASE 1: PATTERN-BASED FIXES (fast, no AI needed)
# ============================================================
Log "" 'INFO'
Log "--- PHASE 1: Pattern-Based Auto-Fixes ---" 'SCAN'

# P1: WaitForExit() infinite
$p1Count = ([regex]::Matches($contentModified, '\.WaitForExit\(\)')).Count
if ($p1Count -gt 0) {
    $contentModified = $contentModified -replace '\.WaitForExit\(\)', '.WaitForExit(30000)'
    $fixed = $p1Count - ([regex]::Matches($contentModified, '\.WaitForExit\(\)')).Count
    if ($fixed -gt 0) {
        Log "P1 FIXED: $fixed x WaitForExit() -> WaitForExit(30000)" 'FIX'
        $fixLog.Add("WaitForExit timeout: $fixed fixed")
        $fixesApplied += $fixed
    }
} else { Log "P1: WaitForExit - clean" 'OK' }

# P2: DialogResult string comparison
$contentBefore = $contentModified
$contentModified = [regex]::Replace($contentModified, "(-eq\s+)'Yes'", '$1[System.Windows.Forms.DialogResult]::Yes')
$contentModified = [regex]::Replace($contentModified, '(-eq\s+)"Yes"', '$1[System.Windows.Forms.DialogResult]::Yes')
$contentModified = [regex]::Replace($contentModified, "(-eq\s+)'OK'",  '$1[System.Windows.Forms.DialogResult]::OK')
$contentModified = [regex]::Replace($contentModified, '(-eq\s+)"OK"',  '$1[System.Windows.Forms.DialogResult]::OK')
$contentModified = [regex]::Replace($contentModified, "(-eq\s+)'No'",  '$1[System.Windows.Forms.DialogResult]::No')
$contentModified = [regex]::Replace($contentModified, '(-eq\s+)"No"',  '$1[System.Windows.Forms.DialogResult]::No')
if ($contentModified -ne $contentBefore) {
    Log "P2 FIXED: DialogResult string comparisons -> enum" 'FIX'
    $fixLog.Add("DialogResult enum fix applied")
    $fixesApplied++
} else { Log "P2: DialogResult - clean" 'OK' }

# P3: $pid shadowing
$contentBefore = $contentModified
$pidCount = ([regex]::Matches($contentModified, '(?<!\$script:)\$pid\b(?!\s*=\s*\[System)')).Count
if ($pidCount -gt 0) {
    $contentModified = [regex]::Replace($contentModified, '(?<!\$script:)\$pid\b(?!\s*=\s*\[System)', '$connPid')
    if ($contentModified -ne $contentBefore) {
        Log "P3 FIXED: dollar-pid renamed to dollar-connPid" 'FIX'
        $fixLog.Add("pid variable shadow fix")
        $fixesApplied++
    }
} else { Log "P3: pid shadowing - clean" 'OK' }

# ============================================================
# PHASE 2: AI-POWERED FIX (for complex bugs patterns can't fix)
# ============================================================
Log "" 'INFO'
Log "--- PHASE 2: AI-Powered Fix (Google Gemini) ---" 'AI'

# Determine which errors need AI (unrepaired, with valid line numbers)
$needsAI = @($unrepaired | Where-Object {
    $_.line -gt 0 -and -not [string]::IsNullOrWhiteSpace($_.panel)
})

# Report global/un-localizable errors that cannot be automatically targeted
$globalErrors = @($unrepaired | Where-Object { $_.line -eq 0 })
if ($globalErrors.Count -gt 0) {
    Log "Skipped AI repair for $($globalErrors.Count) error(s) with line=0 (global exceptions) - please inspect manually." 'WARN'
    foreach ($ge in $globalErrors) {
        $truncatedErr = if ($ge.error.Length -gt 80) { $ge.error.Substring(0, 80) + "..." } else { $ge.error }
        Log "  - $truncatedErr" 'WARN'
    }
}

if ($needsAI.Count -eq 0) {
    Log "No complex bugs requiring AI found - all handled by patterns" 'OK'
} else {
    $allLinesForAI = $contentModified -split '\r?\n'
    foreach ($err in $needsAI) {
        Log "" 'INFO'
        Log "Processing: [$($err.panel)] $($err.error.Substring(0, [Math]::Min(60, $err.error.Length)))..." 'AI'
        $ctx = Get-CodeContext -Lines $allLinesForAI -ErrorLine $err.line -PanelName $err.panel
        $prompt = Build-RepairPrompt -PanelName $err.panel -ErrorMessage $err.error -ErrorLine $err.line -StackTrace $err.stack -CodeContext $ctx.Code -CtxStartLine $ctx.StartLine -CtxEndLine $ctx.EndLine
        
        Log "Calling Gemini AI..." 'AI'
        $fixedCode = Invoke-GeminiAI -Prompt $prompt
        
        if ($fixedCode) {
            Log "AI returned fix - applying..." 'AI'
            $newContent = Apply-AiFix -AllLines $allLinesForAI -FixedCode $fixedCode -StartLine $ctx.StartLine -EndLine $ctx.EndLine
            
            # Syntax check
            $parseErrors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput($newContent, [ref]$null, [ref]$parseErrors)
            if ($parseErrors.Count -eq 0) {
                $contentModified = $newContent
                $allLinesForAI   = $contentModified -split '\r?\n'
                $fixLog.Add("AI fix applied: [$($err.panel)] L$($err.line)")
                $aiFixes++
                $fixesApplied++
                Log "AI fix APPLIED for [$($err.panel)] L$($err.line)" 'FIX'
                
                # Log to AI history
                try {
                    "[$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))] Fixed [$($err.panel)] L$($err.line): $($err.error)" | Out-File -LiteralPath $AiRepairLog -Encoding UTF8 -Append
                } catch {}
            } else {
                Log "AI fix REJECTED - syntax error in output (rolling back this fix)" 'ERROR'
                foreach ($pe in $parseErrors | Select-Object -First 3) {
                    Log "  Syntax: $($pe.Message)" 'ERROR'
                }
            }
        } else {
            Log "AI returned no fix for [$($err.panel)] L$($err.line)" 'WARN'
        }
    }
}

# ============================================================
# WRITE CHANGES
# ============================================================
Log "" 'INFO'
if ($fixesApplied -gt 0 -and -not $DryRun) {
    Log "--- Writing $fixesApplied fix(es) to disk ---" 'WRITE'

    # Step 1: Create backup
    if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
    $backupPath = Join-Path $BackupDir "GUI-AI-Repair-Backup-$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"
    Copy-Item -LiteralPath $GuiScript -Destination $backupPath -Force
    Log "Backup: $backupPath" 'BACKUP'

    # Step 2: Write patched file
    [System.IO.File]::WriteAllText($GuiScript, $contentModified, [System.Text.Encoding]::UTF8)
    Log "Patched file written" 'OK'

    # Step 3: Final syntax check
    $finalErrs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($GuiScript, [ref]$null, [ref]$finalErrs)
    if ($finalErrs.Count -gt 0) {
        Log "SYNTAX ERROR in final file - ROLLING BACK!" 'ERROR'
        foreach ($fe in $finalErrs | Select-Object -First 5) {
            Log ("  Line $($fe.Extent.StartLineNumber): $($fe.Message)") 'ERROR'
        }
        Copy-Item -LiteralPath $backupPath -Destination $GuiScript -Force
        Log "Rollback complete - original restored" 'ROLLBACK'
        exit 1
    }
    Log "Final syntax check: PASSED" 'OK'

    # Step 4: Mark all errors as repaired in the log
    $updatedLog = @()
    foreach ($logLine in @(Get-Content -LiteralPath $ErrorLog -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($logLine -like '*"repaired":false*') {
            $updatedLog += ($logLine -replace '"repaired":false', '"repaired":true')
        } else {
            $updatedLog += $logLine
        }
    }
    $updatedLog | Set-Content -LiteralPath $ErrorLog -Encoding UTF8
    Log "Error log: all entries marked repaired" 'OK'

} elseif ($DryRun -and $fixesApplied -gt 0) {
    Log "[DRY RUN] $fixesApplied fix(es) would be applied - nothing written" 'DRYRUN'
} elseif ($fixesApplied -eq 0) {
    Log "No fixes were needed - file is clean" 'OK'
}

# ============================================================
# SUMMARY
# ============================================================
Log "" 'SUMMARY'
Log "============================================" 'SUMMARY'
Log "         REPAIR COMPLETE - SUMMARY          " 'SUMMARY'
Log "============================================" 'SUMMARY'
Log "Total errors in log   : $($allErrors.Count)" 'SUMMARY'
Log "Previously repaired   : $(@($allErrors | Where-Object { $_.repaired }).Count)" 'SUMMARY'
Log "Pattern fixes applied : $($fixesApplied - $aiFixes)" 'SUMMARY'
Log "AI fixes applied      : $aiFixes" 'SUMMARY'
Log "Total fixes this run  : $fixesApplied" 'SUMMARY'
foreach ($fl in $fixLog) { Log "  + $fl" 'FIX' }
if (-not $DryRun -and $fixesApplied -gt 0) {
    Log "Backup saved to       : $backupPath" 'SUMMARY'
    Log "AI repair history     : $AiRepairLog" 'SUMMARY'
}
Log "============================================" 'SUMMARY'
