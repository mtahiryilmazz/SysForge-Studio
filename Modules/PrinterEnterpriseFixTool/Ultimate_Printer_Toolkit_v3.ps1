function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Get-PreferredPowerShellHost {
    try {
        $cmd = Get-Command pwsh.exe -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { return $cmd.Source }
    } catch {}
    return "powershell.exe"
}

if (-not (Test-IsAdministrator)) {
    try {
        $psHost = Get-PreferredPowerShellHost
        $argList = @("-NoProfile","-ExecutionPolicy","Bypass","-File",('"{0}"' -f $PSCommandPath))
        Start-Process -FilePath $psHost -ArgumentList $argList -Verb RunAs -WindowStyle Normal | Out-Null
    } catch {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show("Bu araç yazıcı, servis ve registry işlemleri için yönetici izni ister.`r`n`r`nYönetici olarak başlatılamadı: $($_.Exception.Message)","PRN Yetki Gerekli",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        } catch {}
    }
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$ErrorActionPreference = "Continue"

# ============================================================
# ULTIMATE PRINTER TOOLKIT
# Alias: ULTIMATE_PRINTER_TOOLKIT
# Tam özellikli onarım:
# - Host/Client otomatik algılama + manuel rol
# - Ağ yazıcısı bulma / net view / CIM
# - Yerel/uzak arıza tespit
# - RPC/11b, 709, Point&Print, Package Point&Print
# - SMB, guest, firewall, discovery, services, spooler
# - Credential cleanup, driver cache cleanup
# - Add-Printer, PrintUI, WScript, PrintUI /ga
# - Gerçek bağlantı doğrulama
# - Log + HTML rapor
# ============================================================

$script:AppCode = "ULTIMATE_PRINTER_TOOLKIT"
$script:AppName = "Ultimate Printer Toolkit"
$script:DetectedRole = "Belirsiz"

function Get-WritableToolDirectory {
    param([string]$Leaf)
    $candidates = @(
        (Join-Path $PSScriptRoot $Leaf),
        (Join-Path $env:ProgramData "PRN_Enterprise_FixTool\$Leaf"),
        (Join-Path $env:TEMP "PRN_Enterprise_FixTool\$Leaf")
    )
    foreach ($candidate in $candidates) {
        try {
            if (!(Test-Path $candidate)) { New-Item -Path $candidate -ItemType Directory -Force | Out-Null }
            $probe = Join-Path $candidate ".write_test"
            Set-Content -Path $probe -Value "ok" -Encoding ASCII -Force
            Remove-Item -Path $probe -Force -ErrorAction SilentlyContinue
            return $candidate
        } catch {}
    }
    return (Join-Path $env:TEMP "PRN_Enterprise_FixTool\$Leaf")
}

$script:LogDir = Get-WritableToolDirectory "UPT_Logs"
$script:BackupRoot = Get-WritableToolDirectory "UPT_Backups"
$script:LastBackupPath = ""

$script:LogFile = Join-Path $script:LogDir ("UPT_FULL_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

$script:FoundItems = New-Object System.Collections.Generic.List[object]
$script:DiagItems = New-Object System.Collections.Generic.List[object]
$script:ActionItems = New-Object System.Collections.Generic.List[object]
$script:PrinterVendorPatterns = @(
    [PSCustomObject]@{ Filter="HP"; Pattern="\b(HP|Hewlett[\s-]*Packard)\b" },
    [PSCustomObject]@{ Filter="Canon"; Pattern="\bCanon\b" },
    [PSCustomObject]@{ Filter="Kyocera"; Pattern="\bKyocera\b" },
    [PSCustomObject]@{ Filter="Ricoh"; Pattern="\bRicoh\b" },
    [PSCustomObject]@{ Filter="Konica"; Pattern="\b(Konica|Minolta|Konica[\s-]*Minolta)\b" },
    [PSCustomObject]@{ Filter="Xerox"; Pattern="\b(Xerox|Fuji[\s-]*Xerox)\b" },
    [PSCustomObject]@{ Filter="Brother"; Pattern="\bBrother\b" },
    [PSCustomObject]@{ Filter="Epson"; Pattern="\bEpson\b" },
    [PSCustomObject]@{ Filter="Samsung"; Pattern="\bSamsung\b" },
    [PSCustomObject]@{ Filter="Lexmark"; Pattern="\bLexmark\b" },
    [PSCustomObject]@{ Filter="Zebra"; Pattern="\bZebra\b" },
    [PSCustomObject]@{ Filter="OKI"; Pattern="\bOKI\b" },
    [PSCustomObject]@{ Filter="Sharp"; Pattern="\bSharp\b" },
    [PSCustomObject]@{ Filter="Toshiba"; Pattern="\bToshiba\b" },
    [PSCustomObject]@{ Filter="Riso"; Pattern="\bRiso\b" }
)

trap {
    try {
        $msg = "Yakalanmayan hata: $($_.Exception.Message)`r`n$($_.ScriptStackTrace)"
        Add-Content -Path $script:LogFile -Value ("[{0}] [FATAL] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg) -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show($msg, "PRN hata yakalandı", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    } catch {}
    continue
}

[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
[System.Windows.Forms.Application]::add_ThreadException({
    param($sender, $eventArgs)
    try {
        $msg = "Arayüz hatası: $($eventArgs.Exception.Message)`r`n$($eventArgs.Exception.StackTrace)"
        Add-Content -Path $script:LogFile -Value ("[{0}] [UIERR] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg) -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show($msg, "PRN arayüz hatası", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    } catch {}
})

# ---------- THEME ----------
# Dark Palette
$C_Bg = [System.Drawing.Color]::FromArgb(15,23,32)
$C_Side = [System.Drawing.Color]::FromArgb(20,29,40)
$C_Panel = [System.Drawing.Color]::FromArgb(27,38,51)
$C_Panel2 = [System.Drawing.Color]::FromArgb(39,54,71)
$C_Fg = [System.Drawing.Color]::FromArgb(239,245,252)
$C_Muted = [System.Drawing.Color]::FromArgb(150,166,185)
$C_Accent = [System.Drawing.Color]::FromArgb(76,132,255)
$C_Ok = [System.Drawing.Color]::FromArgb(34,197,94)
$C_Warn = [System.Drawing.Color]::FromArgb(245,158,11)
$C_Err = [System.Drawing.Color]::FromArgb(239,68,68)

# Light Palette
$L_Bg = [System.Drawing.Color]::FromArgb(248,250,252)
$L_Side = [System.Drawing.Color]::FromArgb(241,245,249)
$L_Panel = [System.Drawing.Color]::FromArgb(255,255,255)
$L_Panel2 = [System.Drawing.Color]::FromArgb(226,232,240)
$L_Fg = [System.Drawing.Color]::FromArgb(15,23,42)
$L_Muted = [System.Drawing.Color]::FromArgb(100,116,139)

# ---------- ICONS (Unicode Escape for Robustness) ----------
$script:Icons = @{
    Dashboard = [char]::ConvertFromUtf32(0x1F3E0)
    Finder    = [char]::ConvertFromUtf32(0x1F5A8)
    Fixes     = [char]::ConvertFromUtf32(0x1F6E0)
    Diag      = [char]::ConvertFromUtf32(0x1F50D)
    Driver    = [char]::ConvertFromUtf32(0x1F9F9)
    Logs      = [char]::ConvertFromUtf32(0x1F4C4)
    AutoFix   = [char]::ConvertFromUtf32(0x26A1)
    Detect    = [char]::ConvertFromUtf32(0x1F9E0)
    Local     = [char]::ConvertFromUtf32(0x1F7E2)
    Remote    = [char]::ConvertFromUtf32(0x1F7E1)
    Workgroup = [char]::ConvertFromUtf32(0x1F517)
    Backup    = [char]::ConvertFromUtf32(0x1F4BE)
    Restore   = [char]::ConvertFromUtf32(0x267B)
    Folder    = [char]::ConvertFromUtf32(0x1F4C1)
    Recommend = [char]::ConvertFromUtf32(0x1F3AF)
    Rocket    = [char]::ConvertFromUtf32(0x1F680)
    Workflow  = [char]::ConvertFromUtf32(0x1F3E2)
    Moon      = [char]::ConvertFromUtf32(0x1F319)
    Sun       = [char]::ConvertFromUtf32(0x2600)
    Info      = [char]::ConvertFromUtf32(0x2139)
    Check     = [char]::ConvertFromUtf32(0x2713)
    Shield    = [char]::ConvertFromUtf32(0x1F6E1)
    Tools     = [char]::ConvertFromUtf32(0x1F9F0)
    Print     = [char]::ConvertFromUtf32(0x1F5A8)
}

# ---------- LOG ----------
function Write-Log {
    param([string]$Message,[string]$Level="INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    if (-not [string]::IsNullOrWhiteSpace($script:LogFile)) {
        Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
    }
    if ($script:TxtLog) {
        $script:TxtLog.AppendText($line + [Environment]::NewLine)
        $script:TxtLog.SelectionStart = $script:TxtLog.TextLength
        $script:TxtLog.ScrollToCaret()
    }
    if ($script:LblStatus) { $script:LblStatus.Text = "Durum: $Message" }
    try { [System.Windows.Forms.Application]::DoEvents() } catch {}
}
function OK { param([string]$m) Write-Log $m "OK" }
function WARN { param([string]$m) Write-Log $m "WARN" }
function ERR { param([string]$m) Write-Log $m "ERR" }
function INFO { param([string]$m) Write-Log $m "INFO" }
function Show-Info { param($t,$m) [System.Windows.Forms.MessageBox]::Show($m,$t,[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null }
function Show-Warn { param($t,$m) [System.Windows.Forms.MessageBox]::Show($m,$t,[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null }
function Show-Err { param($t,$m) [System.Windows.Forms.MessageBox]::Show($m,$t,[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null }

function Ensure-AppCodeSigningTrust {
    $embeddedCertBase64 = "MIIEQDCCAqigAwIBAgIQI6crnCvyhohDLk7gaQ+gtjANBgkqhkiG9w0BAQsFADA4MRYwFAYDVQQKDA1tdGFoaXJ5aWxtYXp6MR4wHAYDVQQDDBVNdWhhbW1lZCBUYWhpciBZSUxNQVowHhcNMjYwNTE0MTIzNDM5WhcNMzEwNTE0MTI0NDM4WjA4MRYwFAYDVQQKDA1tdGFoaXJ5aWxtYXp6MR4wHAYDVQQDDBVNdWhhbW1lZCBUYWhpciBZSUxNQVowggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQDgv7e8+uZ2xtW8Nf3I/TpiPQG9hlHQUjdlY2NN0KDx5z4YS7xNRfo9dEHxt99SjuxzzMjGnopOKtYQN/r0GHAbkVyJwybPgvjDUoXdS1lnS3dMofzc+OSNmgn+jm2q+n9OaqDBuuB6pJx1E7AoxbEi/2MZDi0syryqno0KGWOZUDxZrf5I5nOpHcytB9PXBgz7rtl6s1d2UUeurAo8eDZn2I2kHdKlnZJAWnseQg5wVv3d09wRb4GMCEWH0HtBSKppDtSPCLT/oCKUrl56ZJLJMFmnQyHqMPmIwgI75ATQRSDpl9Uqa1aT+ULPN9+hYw7lZohoiC/kja6jc/AtM3mzQMhb8bS9oK5+39kQMUgV7EfbiCt+GUUdqbQb0ljk+rBndDFJgLaDEkJoYjh9Um1uUXRXQaYKVCxCZ4oNbRwqQDjl53fnfv2UwvV7+Vth5ds2q+MTpZ14Tcl4LsQXIMfOzcTaM2jBxrDFSNzn/tGXlDtLfG7Je8wKlWcBGCwIKv0CAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBRP9sQOwwO58TVkZmf7WqzQdQeYBzANBgkqhkiG9w0BAQsFAAOCAYEAsGWtegQFt7E+52bWbD9CBg49PCWPx/eIervncvaOPJZhr8DQf6PeaSXLnTxt8+dulOHTWxNwbU8dPiWDeCCPpSAQSNTd8W9xKIB0aZrO0tbqZaYr+jU8T5aMdhpkUnXx+yVzimFRiLfrsmIiYn/oY/OaPxRXXesOWjtIsR68FNn14yysGaJYADv+WnNzKhfdYld6uleuEJlmjspQ0xzZkEZFqUTEXCahR/Kuc6XmTBOAcc9Q70bFm+4Bq/kxlbbcpjC3dk9fc3+P54fd88GVmUPnZHWQ3FRhQrxuzWXBbyRMt9xR+ap2Zx5IHRmFaYom7GyYU3Tg75fgdTleRk42H3N7MXK2WE2ReY+qbln+rC+7RKljFl0VPAil5ePDcju4CEcYN/S5P+n4J8rZOtG4s73tMw0vsklOpuEsQAa+xFkB3pxgodoo/C+61eVSOAglhwYlcUwGEjwbZ1sjGgsUde88W3WHwFye388MI5euhbAjvTFX+E6U74wCO4NH1ak4"
    try {
        $certBytes = [Convert]::FromBase64String($embeddedCertBase64)
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @(,$certBytes)
        foreach ($storeName in @("Root","TrustedPublisher")) {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, "CurrentUser")
            try {
                $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
                $exists = $false
                foreach ($item in $store.Certificates) {
                    if ($item.Thumbprint -eq $cert.Thumbprint) { $exists = $true; break }
                }
                if (-not $exists) { $store.Add($cert) }
            } finally {
                if ($store) { $store.Close() }
            }
        }
        OK "Kod imza sertifikası kullanıcı güven deposunda hazır: $($cert.Subject)"
    } catch {
        WARN "Kod imza sertifikası otomatik eklenemedi: $_"
    }
}

function Add-Action {
    param([string]$Name,[string]$Status,[string]$Detail)
    $obj = [PSCustomObject]@{Time=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss");Name=$Name;Status=$Status;Detail=$Detail}
    $script:ActionItems.Add($obj) | Out-Null
}

# ---------- REGISTRY HELPERS ----------
function Ensure-Key {
    param([string]$Path)
    if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
}
function Set-DWordSafe {
    param([string]$Path,[string]$Name,[int]$Value)
    try {
        Ensure-Key $Path
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
        OK "$Path\$Name = $Value"
        Add-Action "Registry DWORD" "OK" "$Path\$Name=$Value"
    } catch { ERR "Registry yazılamadı: $Path\$Name -> $_" }
}
function Set-MultiStringSafe {
    param([string]$Path,[string]$Name,[string[]]$Value)
    try {
        Ensure-Key $Path
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType MultiString -Force | Out-Null
        OK "$Path\$Name = $($Value -join ',')"
        Add-Action "Registry MultiString" "OK" "$Path\$Name=$($Value -join ',')"
    } catch { ERR "Registry multistring yazılamadı: $Path\$Name -> $_" }
}
function Get-DWordSafe {
    param([string]$Path,[string]$Name)
    try {
        $v = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $v.$Name
    } catch { return $null }
}
function Invoke-GPUpdateSafe {
    Write-Log "Grup ilkesi yenileme deneniyor..."
    try {
        $p = Start-Process -FilePath "gpupdate.exe" -ArgumentList "/target:computer /force" -Wait -PassThru -WindowStyle Hidden
        if ($p.ExitCode -eq 0) { OK "gpupdate tamamlandı" } else { WARN "gpupdate çıkış kodu: $($p.ExitCode)" }
    } catch { WARN "gpupdate çalıştırılamadı: $_" }
}
function Get-ServerFromUNC {
    param([string]$UNC)
    try {
        $parts = $UNC.Trim().Trim('"').Trim("'").TrimStart("\").Split("\")
        if ($parts.Count -ge 2) { return $parts[0] }
    } catch {}
    return ""
}

# ---------- DIAG ----------
function Add-Diag {
    param([string]$Kategori,[string]$Ad,[string]$Durum,[string]$Detay,[string]$Oneri)
    $obj = [PSCustomObject]@{Kategori=$Kategori;Ad=$Ad;Durum=$Durum;Detay=$Detay;Oneri=$Oneri}
    $script:DiagItems.Add($obj) | Out-Null
    if ($script:GridDiag) { [void]$script:GridDiag.Rows.Add($Kategori,$Ad,$Durum,$Detay,$Oneri) }
    if ($Durum -eq "Hata") { ERR "$Kategori / $Ad / $Detay / Öneri: $Oneri" }
    elseif ($Durum -eq "Uyarı") { WARN "$Kategori / $Ad / $Detay / Öneri: $Oneri" }
    else { OK "$Kategori / $Ad / $Detay" }
}
function Clear-Diag {
    $script:DiagItems.Clear()
    if ($script:GridDiag) { $script:GridDiag.Rows.Clear() }
}
function Get-RegTextSafe {
    param([string]$Path,[string]$Name)
    try {
        $v = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return "$($v.$Name)"
    } catch { return "" }
}
function Add-DiagRegistryDword {
    param([string]$Path,[string]$Name,[Nullable[int]]$Expected,[string]$FixName,[string]$MissingText="Yok")
    $value = Get-DWordSafe $Path $Name
    if ($null -eq $value) {
        Add-Diag "Registry" $Name "Uyarı" $MissingText "$FixName çalıştırılmalı"
    } elseif ($null -ne $Expected -and $value -ne $Expected) {
        Add-Diag "Registry" $Name "Uyarı" "$value" "$FixName çalıştırılmalı"
    } else {
        Add-Diag "Registry" $Name "OK" "$value" "Sorun yok"
    }
}
function Detect-Role {
    Write-Log "Rol algılama başlatıldı..."
    $sharedCount = 0
    $connectionCount = 0
    try {
        $printers = Get-Printer -ErrorAction SilentlyContinue
        $sharedCount = @($printers | Where-Object { $_.Shared -eq $true }).Count
        $connectionCount = @($printers | Where-Object { $_.Type -match "Connection|Connections" -or $_.PortName -match "^\\\\" -or $_.Name -match "^\\\\" }).Count
    } catch { WARN "Get-Printer ile rol algılanamadı: $_" }

    if ($sharedCount -gt 0 -and $connectionCount -gt 0) { $script:DetectedRole = "Both" }
    elseif ($sharedCount -gt 0) { $script:DetectedRole = "Host" }
    elseif ($connectionCount -gt 0) { $script:DetectedRole = "Client" }
    else { $script:DetectedRole = "Client" }

    if ($script:LblRoleValue) { $script:LblRoleValue.Text = $script:DetectedRole }
    OK "Algılanan rol: $script:DetectedRole | Paylaşılan yazıcı: $sharedCount | Ağ yazıcı bağlantısı: $connectionCount"
    return $script:DetectedRole
}
function Get-SelectedRole {
    try {
        $selected = $cmbRole.SelectedItem
        if ([string]::IsNullOrWhiteSpace($selected) -or $selected -eq "Auto") { return Detect-Role }
        return $selected
    } catch { return Detect-Role }
}
function Run-LocalDiagnosis {
    param([switch]$Append)
    if (-not $Append) { Clear-Diag }
    Write-Log "=== YEREL ARIZA TESPİTİ BAŞLADI ==="
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        Add-Diag "Sistem" "İşletim Sistemi" "OK" "$($os.Caption) / Build $($os.BuildNumber)" "Güncel Windows yamaları kontrol edilmeli"
    } catch { Add-Diag "Sistem" "İşletim Sistemi" "Uyarı" "$_" "WMI/CIM erişimi kontrol edilmeli" }

    $role = Detect-Role
    Add-Diag "Rol" "Algılanan Rol" "OK" $role "Gerekiyorsa manuel rol seçimiyle tekrar deneyin"

    $services = @("Spooler","RpcSs","RpcEptMapper","LanmanServer","LanmanWorkstation","fdPHost","FDResPub","SSDPSRV","upnphost")
    foreach ($svc in $services) {
        try {
            $s = Get-Service -Name $svc -ErrorAction Stop
            if ($s.Status -eq "Running") { Add-Diag "Servis" $svc "OK" "$($s.Status)" "Sorun yok" }
            else { Add-Diag "Servis" $svc "Uyarı" "$($s.Status)" "Servis fix çalıştırılmalı" }
        } catch { Add-Diag "Servis" $svc "Hata" "Bulunamadı/okunamadı" "Windows bileşeni/yetki kontrol edilmeli" }
    }

    try {
        $profiles = Get-NetConnectionProfile -ErrorAction Stop
        foreach ($p in $profiles) {
            if ($p.NetworkCategory -eq "Private") { Add-Diag "Ağ" "Profil: $($p.Name)" "OK" "Private" "Sorun yok" }
            else { Add-Diag "Ağ" "Profil: $($p.Name)" "Uyarı" "$($p.NetworkCategory)" "Firewall/Discovery fix çalıştırın" }
        }
    } catch { Add-Diag "Ağ" "Network Profile" "Uyarı" "$_" "Ağ profil komutları kontrol edilmeli" }

    foreach ($port in 445,135) {
        try {
            $r = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($r) { Add-Diag "Port" "127.0.0.1:$port" "OK" "Açık" "Sorun yok" }
            else { Add-Diag "Port" "127.0.0.1:$port" "Uyarı" "Kapalı/Erişilemez" "Firewall/Servis fix kontrol edilmeli" }
        } catch { Add-Diag "Port" "127.0.0.1:$port" "Uyarı" "$_" "Port testi başarısız" }
    }
    try {
        $r139 = Test-NetConnection -ComputerName 127.0.0.1 -Port 139 -InformationLevel Quiet -WarningAction SilentlyContinue
        $detail139 = if ($r139) { "Açık" } else { "Kapalı/Erişilemez" }
        Add-Diag "Port" "127.0.0.1:139" "OK" "$detail139; eski NetBIOS portu" "Modern SMB için tek başına hata sayılmaz"
    } catch { Add-Diag "Port" "127.0.0.1:139" "OK" "Test atlandı" "Modern SMB için tek başına hata sayılmaz" }

    Add-DiagRegistryDword "HKLM:\System\CurrentControlSet\Control\Print" "RpcAuthnLevelPrivacyEnabled" 0 "RPC/11b fix" "Değer yok; Windows varsayılanı sorun çıkarabilir"
    Add-DiagRegistryDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" "RestrictDriverInstallationToAdministrators" 0 "Point&Print/709 fix" "Değer yok"
    Add-DiagRegistryDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" "NoWarningNoElevationOnInstall" 1 "Point&Print/709 fix" "Değer yok"
    Add-DiagRegistryDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" "UpdatePromptSettings" 0 "Point&Print/709 fix" "Değer yok"
    Add-DiagRegistryDword "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "AllowInsecureGuestAuth" 1 "SMB/Guest fix" "Değer yok; guest kullanılmıyorsa bilgi amaçlı"
    Add-DiagRegistryDword "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LmCompatibilityLevel" 3 "NTLM/NetBIOS fix" "Değer yok"
    Add-DiagRegistryDword "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "LocalAccountTokenFilterPolicy" 1 "Workgroup uyumluluk fix" "Değer yok; uzak yerel admin erişiminde sorun olabilir"

    try {
        $trustedHosts = Get-Item -Path WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue
        $trustedValue = if ($trustedHosts) { "$($trustedHosts.Value)" } else { "" }
        if ([string]::IsNullOrWhiteSpace($trustedValue)) {
            Add-Diag "Yerel İlke" "TrustedHosts" "Uyarı" "Boş" "Workgroup uyumluluk veya hedef PC/IP ile TrustedHosts uygulanmalı"
        } else {
            Add-Diag "Yerel İlke" "TrustedHosts" "OK" $trustedValue "Sorun yok"
        }
    } catch { Add-Diag "Yerel İlke" "TrustedHosts" "Uyarı" "$_" "WinRM/Workgroup uyumluluk kontrol edilmeli" }

    try {
        $fwProfiles = Get-NetFirewallProfile -ErrorAction Stop
        foreach ($fw in $fwProfiles) {
            if ($fw.Enabled) { Add-Diag "Firewall" "$($fw.Name) profil" "OK" "Aktif" "Gerekli yazıcı kuralları ayrıca kontrol edilmeli" }
            else { Add-Diag "Firewall" "$($fw.Name) profil" "Uyarı" "Kapalı" "Ortam politikasına göre firewall/discovery fix değerlendirilmeli" }
        }
    } catch { Add-Diag "Firewall" "Profil Okuma" "Uyarı" "$_" "Firewall modülü/yetki kontrol edilmeli" }

    try {
        $printers = Get-Printer -ErrorAction Stop
        foreach ($p in $printers) {
            $detail = "Name=$($p.Name); Shared=$($p.Shared); ShareName=$($p.ShareName); Port=$($p.PortName); Driver=$($p.DriverName)"
            if ($p.Shared -eq $true -and [string]::IsNullOrWhiteSpace($p.ShareName)) {
                Add-Diag "Yazıcı" $p.Name "Uyarı" $detail "Host PC'de paylaşım adı verilmeli"
            } else {
                Add-Diag "Yazıcı" $p.Name "OK" $detail "Bilgi"
            }
        }
    } catch { Add-Diag "Yazıcı" "Get-Printer" "Uyarı" "$_" "Yazdırma yönetimi kontrol edilmeli" }

    Write-Log "=== YEREL ARIZA TESPİTİ BİTTİ ===" "OK"
    if (-not $Append) { Show-Info "Tespit Tamamlandı" "Yerel arıza tespiti tamamlandı." }
}
function Run-RemoteDiagnosis {
    param([switch]$Append)
    $server = $txtRemotePc.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($server)) { Show-Warn "Eksik Bilgi" "Uzak PC adı/IP girin."; return }
    if (-not $Append) { Clear-Diag }
    Write-Log "=== UZAK PC ARIZA TESPİTİ BAŞLADI: $server ==="

    try {
        $dns = Resolve-DnsName $server -ErrorAction Stop | Select-Object -First 1
        Add-Diag "Uzak Ağ" "DNS/Ad Çözümleme" "OK" "$($dns.IPAddress)" "Sorun yok"
    } catch { Add-Diag "Uzak Ağ" "DNS/Ad Çözümleme" "Uyarı" "$_" "PC adı yerine IP deneyin" }

    try {
        if (Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue) { Add-Diag "Uzak Ağ" "Ping" "OK" "Başarılı" "Sorun yok" }
        else { Add-Diag "Uzak Ağ" "Ping" "Uyarı" "Başarısız" "Ping firewall kapalı olabilir; 445/135 daha önemlidir" }
    } catch { Add-Diag "Uzak Ağ" "Ping" "Uyarı" "$_" "Ping testi başarısız" }

    foreach ($port in 445,135) {
        try {
            $r = Test-NetConnection -ComputerName $server -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($r) { Add-Diag "Uzak Port" "${server}:$port" "OK" "Açık" "Sorun yok" }
            else { Add-Diag "Uzak Port" "${server}:$port" "Hata" "Kapalı/Erişilemiyor" "Host PC firewall/paylaşım/RPC servisleri kontrol edilmeli" }
        } catch { Add-Diag "Uzak Port" "${server}:$port" "Uyarı" "$_" "Port testi başarısız" }
    }
    try {
        $r139 = Test-NetConnection -ComputerName $server -Port 139 -InformationLevel Quiet -WarningAction SilentlyContinue
        $detail139 = if ($r139) { "Açık" } else { "Kapalı/Erişilemez" }
        Add-Diag "Uzak Port" "${server}:139" "OK" "$detail139; eski NetBIOS portu" "Modern SMB için tek başına hata sayılmaz"
    } catch { Add-Diag "Uzak Port" "${server}:139" "OK" "Test atlandı" "Modern SMB için tek başına hata sayılmaz" }

    try {
        $out = cmd /c "net view \\$server" 2>&1
        $joined = ($out -join " | ")
        if ($joined -match "Access is denied|Erişim engellendi") {
            Add-Diag "Uzak Paylaşım" "net view" "Hata" $joined "Credential/izin/konuk ayarları kontrol edilmeli"
        } elseif ($joined -match "System error 53|Sistem hatası 53") {
            Add-Diag "Uzak Paylaşım" "net view" "Hata" $joined "PC adı/IP veya ağ keşfi kontrol edilmeli"
        } elseif ($joined -match "command completed successfully|komut başarıyla tamamlandı") {
            Add-Diag "Uzak Paylaşım" "net view" "OK" "Paylaşımlar listelendi" "Sorun yok"
        } else {
            Add-Diag "Uzak Paylaşım" "net view" "Uyarı" $joined "Log detayını inceleyin"
        }
        foreach ($line in $out) { Write-Log "NETVIEW_DIAG: $line" }
    } catch { Add-Diag "Uzak Paylaşım" "net view" "Uyarı" "$_" "net view çalışmadı" }

    try {
        $printers = Get-CimInstance -ClassName Win32_Printer -ComputerName $server -ErrorAction Stop
        $shared = @($printers | Where-Object { $_.Shared -eq $true -and $_.ShareName })
        if ($shared.Count -gt 0) { Add-Diag "Uzak Yazıcı" "Paylaşılan Yazıcı" "OK" "$($shared.Count) adet" "Yazıcı Bul sekmesinden listeleyin" }
        else { Add-Diag "Uzak Yazıcı" "Paylaşılan Yazıcı" "Uyarı" "Bulunamadı" "Host PC'de yazıcı paylaşım adı kontrol edilmeli" }
    } catch { Add-Diag "Uzak Yazıcı" "CIM Win32_Printer" "Uyarı" "$_" "WMI kapalı olabilir; net view sonuçlarına bakın" }

    Write-Log "=== UZAK PC ARIZA TESPİTİ BİTTİ ===" "OK"
}

function Run-AllDiagnosis {
    Clear-Diag
    Write-Log "=== BİRLEŞİK YEREL/UZAK ARIZA TESPİTİ BAŞLADI ==="
    Run-LocalDiagnosis -Append
    if (-not [string]::IsNullOrWhiteSpace($txtRemotePc.Text.Trim())) {
        Run-RemoteDiagnosis -Append
    } else {
        Add-Diag "Uzak Tespit" "PC/IP alanı" "Uyarı" "Boş" "Uzak host kontrolü için Yazıcı Bul/Bağla ekranındaki PC/IP alanını doldurun"
    }
    Apply-RecommendedFixSelection
    Show-Page "diag"
    Write-Log "=== BİRLEŞİK YEREL/UZAK ARIZA TESPİTİ BİTTİ ===" "OK"
    Show-Info "Tespit Tamamlandı" "Yerel/uzak tespit tamamlandı ve önerilen fixler seçildi.`r`nFix ekranında seçili kutuları kontrol edip uygulayabilirsiniz."
}

# ---------- FIX ENGINE ----------
function Get-SelectedFixCount {
    $checks = @($chkFixRpc,$chkFixPoint,$chkFixSmb,$chkFixFirewall,$chkFixServices,$chkFixSpooler,$chkFixNtlm,$chkFixCredential,$chkFixDriver,$chkFixWorkgroup)
    return @($checks | Where-Object { $_ -and $_.Checked }).Count
}
function Ensure-AtLeastOneFixSelected {
    if ((Get-SelectedFixCount) -lt 1) {
        Show-Warn "Düzeltme Seçilmedi" "Hiçbir düzeltme seçili değil. Fix ekranından uygulanacak düzeltmeleri işaretleyin."
        WARN "Fix çalıştırılmadı: hiçbir düzeltme seçili değil."
        return $false
    }
    return $true
}
function Enable-NetworkProfilePrivate {
    Write-Log "Ağ profili Private yapılmaya çalışılıyor..."
    try {
        Get-NetConnectionProfile -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.NetworkCategory -ne "Private") {
                Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue
                OK "Private yapıldı: $($_.Name)"
            } else { OK "Zaten Private: $($_.Name)" }
        }
    } catch { WARN "Ağ profili değiştirilemedi: $_" }
}
function Enable-PrinterFirewall {
    Write-Log "Firewall File and Printer Sharing / Network Discovery kuralları etkinleştiriliyor..."
    try {
        Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing" -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Network Discovery" -ErrorAction SilentlyContinue
        OK "Firewall display group kuralları etkinleştirildi"
    } catch { WARN "DisplayGroup firewall etkinleştirilemedi: $_" }

    $rules = @(
        @{Name="PRN-UET-SMB-445-In"; Port=445; Protocol="TCP"},
        @{Name="PRN-UET-RPC-135-In"; Port=135; Protocol="TCP"},
        @{Name="PRN-UET-NetBIOS-139-In"; Port=139; Protocol="TCP"},
        @{Name="PRN-UET-NetBIOS-137-In"; Port=137; Protocol="UDP"},
        @{Name="PRN-UET-NetBIOS-138-In"; Port=138; Protocol="UDP"}
    )
    foreach ($r in $rules) {
        try {
            $exists = Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue
            if (-not $exists) {
                New-NetFirewallRule -DisplayName $r.Name -Direction Inbound -Protocol $r.Protocol -LocalPort $r.Port -Action Allow -Profile Any | Out-Null
                OK "Firewall kuralı eklendi: $($r.Name)"
            } else { OK "Firewall kuralı mevcut: $($r.Name)" }
        } catch { WARN "Firewall kuralı eklenemedi $($r.Name): $_" }
    }
}
function Ensure-Services {
    Write-Log "Gerekli servisler kontrol ediliyor..."
    $services = @("Spooler","RpcSs","RpcEptMapper","LanmanServer","LanmanWorkstation","fdPHost","FDResPub","SSDPSRV","upnphost")
    foreach ($svcName in $services) {
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                Set-Service -Name $svcName -StartupType Automatic -ErrorAction SilentlyContinue
                Start-Service -Name $svcName -ErrorAction SilentlyContinue
                OK "$svcName çalışır/otomatik kontrol edildi"
            } else { WARN "$svcName servisi bulunamadı" }
        } catch { WARN "$svcName servis hatası: $_" }
    }
}
function Reset-Spooler {
    Write-Log "Print Spooler sıfırlanıyor..."
    try {
        Stop-Service Spooler -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        $spoolPath = "$env:SystemRoot\System32\spool\PRINTERS"
        $files = Get-ChildItem -Path $spoolPath -Include "*.spl","*.shd" -Recurse -ErrorAction SilentlyContinue
        $cnt = @($files).Count
        $files | Remove-Item -Force -ErrorAction SilentlyContinue
        Start-Service Spooler -ErrorAction SilentlyContinue
        OK "Spooler sıfırlandı, $cnt kuyruk dosyası temizlendi"
    } catch { ERR "Spooler sıfırlama hatası: $_" }
}
function Apply-RPC-PrinterCore {
    Write-Log "RPC / 11b / yazdırma policy ayarları uygulanıyor..."
    Set-DWordSafe "HKLM:\System\CurrentControlSet\Control\Print" "RpcAuthnLevelPrivacyEnabled" 0
    $rpcPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC"
    Set-DWordSafe $rpcPath "RpcUseNamedPipeProtocol" 1
    Set-DWordSafe $rpcPath "RpcOverTcp" 1
    Set-DWordSafe $rpcPath "RpcOverNamedPipes" 1
    Set-DWordSafe $rpcPath "RpcProtocols" 7
}
function Apply-PointAndPrint {
    Write-Log "Point and Print / Package Point and Print ayarları uygulanıyor..."
    $pnp = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint"
    Set-DWordSafe $pnp "RestrictDriverInstallationToAdministrators" 0
    Set-DWordSafe $pnp "NoWarningNoElevationOnInstall" 1
    Set-DWordSafe $pnp "UpdatePromptSettings" 0
    Set-DWordSafe $pnp "TrustedServers" 1
    Set-DWordSafe $pnp "InForest" 0

    $server = $txtRemotePc.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($server)) { $server = Get-ServerFromUNC $txtManualUNC.Text.Trim() }
    if (-not [string]::IsNullOrWhiteSpace($server)) {
        Set-MultiStringSafe $pnp "ServerList" @($server)
        $pkg = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PackagePointAndPrint"
        Ensure-Key $pkg
        Set-MultiStringSafe $pkg "PackagePointAndPrintServerList" @($server)
        Set-DWordSafe $pkg "PackagePointAndPrintOnly" 0
        OK "Trusted server / Package Point and Print listesine eklendi: $server"
    } else { WARN "Trusted server için PC/IP girilmedi" }
}
function Apply-SMB-Compatibility {
    Write-Log "SMB uyumluluk ayarları uygulanıyor..."
    try { Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force | Out-Null; OK "SMB2 server etkin" } catch { WARN "SMB2 server yapılandırılamadı: $_" }
    if ($chkSmbSigning -and $chkSmbSigning.Checked) {
        try {
            Set-SmbServerConfiguration -RequireSecuritySignature $false -Force | Out-Null
            Set-SmbClientConfiguration -RequireSecuritySignature $false -Confirm:$false | Out-Null
            OK "SMB imzalama zorunluluğu uyumluluk için opsiyonel yapıldı"
        } catch { WARN "SMB signing ayarı uygulanamadı: $_" }
    } else { WARN "SMB signing ayarı kullanıcı tercihiyle atlandı" }

    if ($chkGuest -and $chkGuest.Checked) {
        Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "AllowInsecureGuestAuth" 1
        Set-DWordSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" "AllowInsecureGuestAuth" 1
        Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "restrictanonymous" 0
        Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "restrictanonymoussam" 0
        Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "everyoneincludesanonymous" 1
        Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "restrictnullsessaccess" 0
        OK "Konuk/insecure guest uyumluluğu uygulandı"
    } else { WARN "Konuk/insecure guest kapalı; atlandı" }
}
function Apply-NTLM-NetBIOS {
    Write-Log "NTLMv2 / NetBIOS uyumluluk ayarları uygulanıyor..."
    Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LmCompatibilityLevel" 3
    Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "NoLMHash" 1
    try {
        Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object {
            $null = $_.SetTcpipNetbios(1)
            OK "NetBIOS etkin: $($_.Description)"
        }
    } catch { WARN "NetBIOS etkinleştirilemedi: $_" }
}
function Apply-CredentialCleanup {
    Write-Log "Credential temizliği başlıyor..."
    try {
        $server = $txtRemotePc.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($server)) { $server = Get-ServerFromUNC $txtManualUNC.Text.Trim() }
        if (-not [string]::IsNullOrWhiteSpace($server)) {
            cmdkey /delete:$server 2>&1 | ForEach-Object { Write-Log "CMDKEY: $_" }
            cmdkey /delete:"TERMSRV/$server" 2>&1 | ForEach-Object { Write-Log "CMDKEY: $_" }
            cmd /c "net use \\$server /delete /y" 2>&1 | ForEach-Object { Write-Log "NETUSE: $_" }
            OK "Credential/net use temizliği denendi: $server"
        } else { WARN "Remote PC/UNC girilmediği için credential temizliği sınırlı atlandı" }
    } catch { WARN "Credential temizliği başarısız: $_" }
}
function Add-DriverFilterCandidate {
    param(
        [hashtable]$Candidates,
        [string]$Filter,
        [int]$Score,
        [string]$Source
    )
    if ([string]::IsNullOrWhiteSpace($Filter)) { return }
    $clean = $Filter.Trim()
    $clean = ($clean -replace "\s+"," ").Trim(" `t`r`n""'")
    if ([string]::IsNullOrWhiteSpace($clean)) { return }
    if ($clean.Length -lt 2) { return }

    $skip = @("driver","drivers","class","printer","printers","print","series","universal","software","microsoft","windows","remote","local","port","usb","wsp","xps","pdf","fax")
    if ($skip -contains $clean.ToLowerInvariant()) { return }

    $key = $clean.ToLowerInvariant()
    if ($Candidates.ContainsKey($key)) {
        $Candidates[$key].Score += $Score
        if ($Candidates[$key].Source -notlike "*$Source*") { $Candidates[$key].Source = "$($Candidates[$key].Source), $Source" }
    } else {
        $Candidates[$key] = [PSCustomObject]@{ Filter=$clean; Score=$Score; Source=$Source }
    }
}
function Add-DriverFilterCandidatesFromText {
    param(
        [hashtable]$Candidates,
        [string]$Text,
        [string]$Source
    )
    if ([string]::IsNullOrWhiteSpace($Text)) { return }

    foreach ($vendor in $script:PrinterVendorPatterns) {
        if ($Text -match $vendor.Pattern) {
            Add-DriverFilterCandidate -Candidates $Candidates -Filter $vendor.Filter -Score 100 -Source $Source
        }
    }

    if ($Text.Length -ge 4 -and $Text.Length -le 80) {
        Add-DriverFilterCandidate -Candidates $Candidates -Filter $Text -Score 25 -Source $Source
    }

    $tokens = (($Text -replace "[^A-Za-z0-9]+"," ") -split "\s+") | Where-Object { $_.Length -ge 3 -and $_.Length -le 24 }
    foreach ($token in $tokens) {
        Add-DriverFilterCandidate -Candidates $Candidates -Filter $token -Score 5 -Source $Source
    }
}
function Get-AutoDriverFilterCandidates {
    $candidates = @{}
    try {
        foreach ($p in @(Get-Printer -ErrorAction SilentlyContinue)) {
            Add-DriverFilterCandidatesFromText -Candidates $candidates -Text $p.DriverName -Source "Yerel driver"
            Add-DriverFilterCandidatesFromText -Candidates $candidates -Text $p.Name -Source "Yerel yazıcı"
            Add-DriverFilterCandidatesFromText -Candidates $candidates -Text $p.PortName -Source "Yerel port"
        }
    } catch { WARN "Yerel yazıcı filtre adayları okunamadı: $_" }

    try {
        foreach ($d in @(Get-PrinterDriver -ErrorAction SilentlyContinue)) {
            Add-DriverFilterCandidatesFromText -Candidates $candidates -Text $d.Name -Source "Sürücü listesi"
        }
    } catch { WARN "Sürücü filtre adayları okunamadı: $_" }

    try {
        foreach ($port in @(Get-PrinterPort -ErrorAction SilentlyContinue)) {
            Add-DriverFilterCandidatesFromText -Candidates $candidates -Text $port.Name -Source "Port"
            Add-DriverFilterCandidatesFromText -Candidates $candidates -Text $port.PrinterHostAddress -Source "Port adresi"
        }
    } catch { WARN "Port filtre adayları okunamadı: $_" }

    if ($script:FoundItems) {
        for ($idx = 0; $idx -lt $script:FoundItems.Count; $idx++) {
            $item = $script:FoundItems[$idx]
            Add-DriverFilterCandidatesFromText -Candidates $candidates -Text $item.Driver -Source "Tarama sonucu"
            Add-DriverFilterCandidatesFromText -Candidates $candidates -Text $item.Name -Source "Tarama sonucu"
            Add-DriverFilterCandidatesFromText -Candidates $candidates -Text $item.ShareName -Source "Tarama sonucu"
        }
    }

    return @($candidates.Values | Sort-Object @{Expression="Score";Descending=$true}, @{Expression="Filter";Ascending=$true} | Select-Object -First 30)
}
function Set-DriverFilterComboItems {
    param(
        [object[]]$Items,
        [switch]$SelectFirst
    )
    if ($null -eq $txtDriverFilter -or $null -eq $txtDriverFilter.Items) { return }

    $currentText = $txtDriverFilter.Text
    try {
        $txtDriverFilter.BeginUpdate()
        $txtDriverFilter.Items.Clear()
        foreach ($item in @($Items)) {
            $value = if ($item -is [string]) { $item } else { $item.Filter }
            if (-not [string]::IsNullOrWhiteSpace($value) -and -not $txtDriverFilter.Items.Contains($value)) {
                [void]$txtDriverFilter.Items.Add([string]$value)
            }
        }
    } finally {
        $txtDriverFilter.EndUpdate()
    }

    if ($SelectFirst -and $txtDriverFilter.Items.Count -gt 0) {
        $txtDriverFilter.SelectedIndex = 0
    } elseif (-not [string]::IsNullOrWhiteSpace($currentText)) {
        $txtDriverFilter.Text = $currentText
    } else {
        $txtDriverFilter.Text = ""
    }
}
function Get-DefaultDriverFilterOptions {
    return @($script:PrinterVendorPatterns | ForEach-Object { $_.Filter } | Select-Object -Unique)
}
function Update-DriverFilterCandidates {
    param([switch]$Silent)
    $items = @(Get-AutoDriverFilterCandidates)
    try {
        if ($null -ne $txtDriverFilter -and $null -ne $txtDriverFilter.Items) {
            if ($items.Count -gt 0) {
                $combinedItems = @($items) + @(Get-DefaultDriverFilterOptions)
                Set-DriverFilterComboItems -Items $combinedItems -SelectFirst
            } else {
                Set-DriverFilterComboItems -Items @(Get-DefaultDriverFilterOptions)
            }
        } elseif ($txtDriverFilter -and $items.Count -gt 0) {
            $txtDriverFilter.Text = $items[0].Filter
        }
    } catch { WARN "Driver filtre listesi güncellenemedi: $_" }

    if ($items.Count -gt 0) {
        OK "Driver filtresi otomatik tespit edildi: $($items[0].Filter) ($($items.Count) aday)"
        if (-not $Silent) { Show-Info "Driver Filtresi" "En uygun filtre seçildi: $($items[0].Filter)`r`nAçılır listeden farklı bir aday seçebilirsiniz." }
    } else {
        WARN "Otomatik driver filtresi bulunamadı"
        if (-not $Silent) { Show-Warn "Driver Filtresi" "Yerel yazıcı/sürücü kayıtlarından otomatik filtre çıkarılamadı. Marka veya modelden bir kelimeyi elle yazabilirsiniz." }
    }
    return $items
}
function Update-DriversGrid {
    param([switch]$Silent)
    if ($null -eq $script:GridDrivers) { return }
    
    try {
        $script:GridDrivers.Rows.Clear()
        $allPrinters = @(Get-Printer -ErrorAction SilentlyContinue)
        $allDrivers = @(Get-PrinterDriver -ErrorAction SilentlyContinue)
        
        $usedDriverNames = @{}
        foreach ($p in $allPrinters) {
            if (-not [string]::IsNullOrWhiteSpace($p.DriverName)) {
                $usedDriverNames[$p.DriverName] = $true
            }
        }
        
        foreach ($d in $allDrivers) {
            $inUseText = "Hayır (Boşta)"
            $inUseColor = [System.Drawing.Color]::FromArgb(34,197,94) # Green
            if ($usedDriverNames.ContainsKey($d.Name)) {
                $inUseText = "Evet (Kullanımda)"
                $inUseColor = [System.Drawing.Color]::FromArgb(239,68,68) # Red
            }
            
            $majorVersion = $d.MajorVersion
            $versionText = "v$majorVersion"
            
            $rowId = $script:GridDrivers.Rows.Add($d.Name, $d.Environment, $versionText, $inUseText)
            $row = $script:GridDrivers.Rows[$rowId]
            $row.Cells[3].Style.ForeColor = $inUseColor
            $row.Cells[3].Style.SelectionForeColor = $inUseColor
        }
        
        if (-not $Silent) {
            OK "Sürücü listesi güncellendi: $($allDrivers.Count) sürücü bulundu."
        }
    } catch {
        WARN "Sürücü listesi güncellenemedi: $_"
    }
}

function Apply-DriverCacheCleanup {
    $selectedDriverName = $null
    if ($null -ne $script:GridDrivers -and $script:GridDrivers.SelectedRows.Count -gt 0) {
        $selectedDriverName = $script:GridDrivers.SelectedRows[0].Cells[0].Value
    }

    if ($null -ne $selectedDriverName) {
        $allPrinters = @(Get-Printer -ErrorAction SilentlyContinue)
        $usingPrinters = @($allPrinters | Where-Object { $_.DriverName -eq $selectedDriverName })
        if ($usingPrinters.Count -gt 0) {
            $printerNames = ($usingPrinters | ForEach-Object { $_.Name }) -join ", "
            $answer = [System.Windows.Forms.MessageBox]::Show("Seçtiğiniz sürücü ('$selectedDriverName') şu anda şu yazıcılar tarafından kullanılmaktadır:`r`n$printerNames`r`n`r`nSürücüyü silmek bu yazıcıların çalışmasını bozacaktır. Yazıcılar silinmeyecektir ancak çalışmaz hale gelebilir.`r`n`r`nYine de bu sürücüyü kaldırmak istiyor musunuz?","Sürücü Kullanımda!", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        } else {
            $answer = [System.Windows.Forms.MessageBox]::Show("Seçilen '$selectedDriverName' sürücüsü sistemden kaldırılacaktır.`r`n`r`nDevam etmek istiyor musun?","Sürücü Kaldırma", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        }
        
        Write-Log "Tekil sürücü temizliği başlıyor: $selectedDriverName..."
        try {
            Remove-PrinterDriver -Name $selectedDriverName -ErrorAction SilentlyContinue
            OK "Sürücü kaldırılması denendi: $selectedDriverName"
        } catch {
            WARN "Sürücü kaldırılamadı: $selectedDriverName - $_"
        }
        
        try {
            $pnputil = "$env:SystemRoot\System32\pnputil.exe"
            if (Test-Path $pnputil) {
                $escapedName = [regex]::Escape($selectedDriverName)
                $enum = & $pnputil /enum-drivers 2>&1
                $blocks = (($enum -join "`n") -split "(\r?\n){2,}") | Where-Object { $_ -match $escapedName }
                foreach ($block in $blocks) {
                    $inf = ""
                    if ($block -match "Published Name\s*:\s*(oem\d+\.inf)") { $inf = $Matches[1] }
                    elseif ($block -match "Yayımlanan Ad\s*:\s*(oem\d+\.inf)") { $inf = $Matches[1] }
                    if ($inf) {
                        & $pnputil /delete-driver $inf /uninstall /force 2>&1 | ForEach-Object { Write-Log "PNPUTIL: $_" }
                        OK "PnP driver paketi kaldırma denendi: $inf"
                    }
                }
            }
        } catch { WARN "PnPUtil sürücü paketi temizliği başarısız: $_" }
        
        Update-DriversGrid -Silent
        return
    }

    Write-Log "Driver cache temizliği başlıyor..."
    $filter = $txtDriverFilter.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($filter)) {
        $autoItems = @(Update-DriverFilterCandidates -Silent)
        if ($autoItems.Count -gt 0) { $filter = $txtDriverFilter.Text.Trim() }
    }
    if ([string]::IsNullOrWhiteSpace($filter)) {
        $answer = [System.Windows.Forms.MessageBox]::Show("Driver filtresi boş. Tüm üçüncü parti yazıcı driverlarını silmeye çalışmak riskli olabilir.`r`n`r`nDevam etmek istiyor musun?","Driver Temizliği", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { WARN "Driver temizliği iptal edildi"; return }
    }

    $warnMsg = "Bu işlem, '$filter' filtresiyle eşleşen tüm yazıcıları, sürücüleri ve bağlantı noktalarını temizleyecektir.`r`n"
    $warnMsg += "Eğer çalışan yazıcılarınızın silinmesini istemiyorsanız, lütfen IPTAL edip aşağıdaki listeden silmek istediğiniz sürücüyü tek tek seçin.`r`n`r`nEşleşen yazıcıları da silerek devam etmek istiyor musunuz?"
    $answer = [System.Windows.Forms.MessageBox]::Show($warnMsg, "Geniş Filtreli Temizlik", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { WARN "Driver temizliği iptal edildi"; return }

    $matchedPrinters = @()
    $matchedDrivers = @()
    $matchedPorts = @()
    try {
        $allPrinters = @(Get-Printer -ErrorAction SilentlyContinue)
        if ([string]::IsNullOrWhiteSpace($filter)) {
            $matchedPrinters = $allPrinters
        } else {
            $matchedPrinters = @($allPrinters | Where-Object { $_.DriverName -like "*$filter*" -or $_.Name -like "*$filter*" -or $_.PortName -like "*$filter*" })
        }
        $allDrivers = @(Get-PrinterDriver -ErrorAction SilentlyContinue)
        if ([string]::IsNullOrWhiteSpace($filter)) {
            $matchedDrivers = $allDrivers
        } else {
            $matchedDrivers = @($allDrivers | Where-Object { $_.Name -like "*$filter*" })
        }
        $allPorts = @(Get-PrinterPort -ErrorAction SilentlyContinue)
        if (-not [string]::IsNullOrWhiteSpace($filter)) {
            $matchedPorts = @($allPorts | Where-Object { $_.Name -like "*$filter*" -or $_.PrinterHostAddress -like "*$filter*" })
        }
    } catch { WARN "Temizlik ön taraması başarısız: $_" }

    $preview = "Eşleşen yazıcı: $($matchedPrinters.Count)`r`nEşleşen sürücü: $($matchedDrivers.Count)`r`nEşleşen port: $($matchedPorts.Count)"
    if ($matchedPrinters.Count -gt 0) {
        $preview += "`r`n`r`nKaldırılacak yazıcılar:`r`n" + (($matchedPrinters | Select-Object -First 12 | ForEach-Object { "- $($_.Name) / $($_.DriverName)" }) -join "`r`n")
    }
    $answer2 = [System.Windows.Forms.MessageBox]::Show("$preview`r`n`r`nBu işlem seçilen marka/model yazıcıları ve sürücü izlerini daha önce kurulmamış gibi temizlemeye çalışır. Devam edilsin mi?","Driver/Yazıcı Temizliği Ön Tarama",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($answer2 -ne [System.Windows.Forms.DialogResult]::Yes) { WARN "Driver temizliği ön tarama sonrası iptal edildi"; return }

    try { Stop-Service Spooler -Force -ErrorAction SilentlyContinue } catch {}
    Start-Sleep -Seconds 1
    try { Start-Service Spooler -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 } catch {}

    try {
        foreach ($p in $matchedPrinters) {
            try {
                if ($p.Name -match "^\\\\") { rundll32 printui.dll,PrintUIEntry /dn /n "$($p.Name)" /q }
                Remove-Printer -Name $p.Name -ErrorAction SilentlyContinue
                OK "Yazıcı/bağlantı kaldırıldı: $($p.Name)"
            } catch { WARN "Yazıcı kaldırılamadı: $($p.Name) - $_" }
        }
    } catch { WARN "Yazıcı kaldırma taraması başarısız: $_" }

    try {
        foreach ($d in $matchedDrivers) {
            try { Remove-PrinterDriver -Name $d.Name -ErrorAction SilentlyContinue; OK "Printer driver kaldırma denendi: $($d.Name)" } catch { WARN "Printer driver kaldırılamadı: $($d.Name) - $_" }
        }
    } catch { WARN "Driver temizliği başarısız: $_" }

    try {
        foreach ($port in $matchedPorts) {
            try { Remove-PrinterPort -Name $port.Name -ErrorAction SilentlyContinue; OK "Printer port kaldırma denendi: $($port.Name)" } catch { WARN "Port kaldırılamadı: $($port.Name) - $_" }
        }
    } catch { WARN "Port temizliği başarısız: $_" }

    if (-not [string]::IsNullOrWhiteSpace($filter)) {
        foreach ($regPath in @("HKCU:\Printers\Connections","HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Devices","HKCU:\Software\Microsoft\Windows NT\CurrentVersion\PrinterPorts")) {
            try {
                if (Test-Path $regPath) {
                    Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like "*$filter*" } | ForEach-Object {
                        Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                        OK "Kullanıcı yazıcı registry izi temizlendi: $($_.PSChildName)"
                    }
                }
            } catch { WARN "Registry iz temizliği başarısız: $regPath - $_" }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($filter)) {
        try {
            $pnputil = "$env:SystemRoot\System32\pnputil.exe"
            if (Test-Path $pnputil) {
                $filterRegex = [regex]::Escape($filter)
                $enum = & $pnputil /enum-drivers 2>&1
                $blocks = (($enum -join "`n") -split "(\r?\n){2,}") | Where-Object { $_ -match $filterRegex }
                foreach ($block in $blocks) {
                    $inf = ""
                    if ($block -match "Published Name\s*:\s*(oem\d+\.inf)") { $inf = $Matches[1] }
                    elseif ($block -match "Yayımlanan Ad\s*:\s*(oem\d+\.inf)") { $inf = $Matches[1] }
                    if ($inf) {
                        & $pnputil /delete-driver $inf /uninstall /force 2>&1 | ForEach-Object { Write-Log "PNPUTIL: $_" }
                        OK "PnP driver paketi kaldırma denendi: $inf"
                    }
                }
            }
        } catch { WARN "PnP driver paketi temizliği başarısız: $_" }
    }

    try {
        $spoolPath = "$env:SystemRoot\System32\spool\PRINTERS"
        Get-ChildItem -Path $spoolPath -Include "*.spl","*.shd" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        OK "Spool kuyruk dosyaları temizlendi"
    } catch { WARN "Spool temizliği başarısız: $_" }

    try { Start-Service Spooler -ErrorAction SilentlyContinue } catch {}
    OK "Driver cache temizliği tamamlandı"
    Update-DriversGrid -Silent
}

# ---------- ULTIMATE EXTRA ACTIONS ----------
function Confirm-UptAction {
    param(
        [string]$Title,
        [string]$Message,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    $answer = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::YesNo, $Icon)
    return ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Invoke-UptProcess {
    param(
        [string]$FilePath,
        [string]$Arguments = "",
        [switch]$Wait,
        [switch]$Hidden
    )
    try {
        $startArgs = @{
            FilePath = $FilePath
            ErrorAction = "Stop"
        }
        if (-not [string]::IsNullOrWhiteSpace($Arguments)) { $startArgs.ArgumentList = $Arguments }
        if ($Wait) { $startArgs.Wait = $true; $startArgs.PassThru = $true }
        if ($Hidden) { $startArgs.WindowStyle = "Hidden" }
        $p = Start-Process @startArgs
        OK "Çalıştırıldı: $FilePath $Arguments"
        return $p
    } catch {
        ERR "Çalıştırılamadı: $FilePath $Arguments - $_"
        Show-Err "Çalıştırma Hatası" "$FilePath başlatılamadı.`r`n`r`n$($_.Exception.Message)"
    }
}

function Get-SelectedPrinterGridItem {
    if (-not $gridPrinters -or $gridPrinters.SelectedRows.Count -lt 1) {
        Show-Warn "Seçim Yok" "Listeden bir yazıcı seçin."
        return $null
    }
    $row = $gridPrinters.SelectedRows[0]
    return [PSCustomObject]@{
        Type = "$($row.Cells[0].Value)"
        Name = "$($row.Cells[1].Value)"
        ShareName = "$($row.Cells[2].Value)"
        UNC = "$($row.Cells[3].Value)"
        Driver = "$($row.Cells[4].Value)"
        Source = "$($row.Cells[5].Value)"
        Note = "$($row.Cells[6].Value)"
    }
}

function Get-PrinterTargetName {
    param([object]$Item)
    if (-not $Item) { return "" }
    if ("$($Item.UNC)" -like "local:*") { return "$($Item.UNC)".Substring(6) }
    if ("$($Item.UNC)" -match '^\\\\') { return "$($Item.UNC)" }
    return "$($Item.Name)"
}

function Get-SafePrinterShareName {
    param([string]$Name)
    $safe = ($Name -replace '[^A-Za-z0-9_-]', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = "PrinterShare" }
    if ($safe.Length -gt 32) { $safe = $safe.Substring(0,32).Trim('_') }
    return $safe
}

function Open-ControlPrinters {
    Invoke-UptProcess -FilePath "control.exe" -Arguments "printers" | Out-Null
}

function Open-PrintServerProperties {
    Invoke-UptProcess -FilePath "rundll32.exe" -Arguments "printui.dll,PrintUIEntry /s /t2" | Out-Null
}

function Open-SelectedPrinterQueue {
    $item = Get-SelectedPrinterGridItem
    if (-not $item) { return }
    $target = Get-PrinterTargetName -Item $item
    Invoke-UptProcess -FilePath "rundll32.exe" -Arguments "printui.dll,PrintUIEntry /o /n `"$target`"" | Out-Null
}

function Open-SelectedPrinterProperties {
    $item = Get-SelectedPrinterGridItem
    if (-not $item) { return }
    $target = Get-PrinterTargetName -Item $item
    Invoke-UptProcess -FilePath "rundll32.exe" -Arguments "printui.dll,PrintUIEntry /p /n `"$target`"" | Out-Null
}

function Print-SelectedPrinterTestPage {
    $item = Get-SelectedPrinterGridItem
    if (-not $item) { return }
    $target = Get-PrinterTargetName -Item $item
    if (-not (Confirm-UptAction "Test Sayfası" "Seçili yazıcıya Windows test sayfası gönderilecek:`r`n$target`r`n`r`nDevam edilsin mi?" ([System.Windows.Forms.MessageBoxIcon]::Question))) { return }
    Invoke-UptProcess -FilePath "rundll32.exe" -Arguments "printui.dll,PrintUIEntry /k /n `"$target`"" | Out-Null
}

function Set-SelectedPrinterDefault {
    $item = Get-SelectedPrinterGridItem
    if (-not $item) { return }
    $target = Get-PrinterTargetName -Item $item
    if ([string]::IsNullOrWhiteSpace($target) -or $target -like "unshared:*") {
        Show-Warn "Uygun Değil" "Paylaşılmamış veya geçersiz kayıt varsayılan yazıcı yapılamaz."
        return
    }
    try {
        Set-DWordSafe "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" "LegacyDefaultPrinterMode" 1
        $net = New-Object -ComObject WScript.Network
        $net.SetDefaultPrinter($target)
        OK "Varsayılan yazıcı ayarlandı: $target"
        Show-Info "Varsayılan Yazıcı" "Varsayılan yazıcı ayarlandı:`r`n$target"
    } catch {
        ERR "Varsayılan yazıcı ayarlanamadı: $target - $_"
        Show-Err "Varsayılan Yazıcı Hatası" "$target varsayılan yapılamadı.`r`n`r`n$($_.Exception.Message)"
    }
}

function Share-SelectedLocalPrinter {
    $item = Get-SelectedPrinterGridItem
    if (-not $item) { return }
    if ("$($item.UNC)" -notlike "local:*") {
        Show-Warn "Yerel Yazıcı Gerekli" "Paylaşıma açmak için bu bilgisayardaki yerel bir yazıcı seçin."
        return
    }
    $printerName = "$($item.UNC)".Substring(6)
    $shareName = Get-SafePrinterShareName -Name $printerName
    if (-not (Confirm-UptAction "Yazıcı Paylaşımı" "Seçili yerel yazıcı paylaşıma açılacak:`r`n$printerName`r`n`r`nPaylaşım adı: $shareName`r`nUNC: \\$env:COMPUTERNAME\$shareName`r`n`r`nDevam edilsin mi?" ([System.Windows.Forms.MessageBoxIcon]::Question))) { return }
    try {
        Enable-NetworkProfilePrivate
        Enable-PrinterFirewall
        Ensure-Services
        Set-Printer -Name $printerName -Shared $true -ShareName $shareName -ErrorAction Stop
        OK "Yazıcı paylaşıma açıldı: \\$env:COMPUTERNAME\$shareName"
        Scan-LocalPrintersOnly
        Show-Info "Paylaşım Hazır" "Yazıcı paylaşıma açıldı:`r`n\\$env:COMPUTERNAME\$shareName"
    } catch {
        ERR "Yazıcı paylaşımı başarısız: $printerName - $_"
        Show-Err "Paylaşım Hatası" "$printerName paylaşıma açılamadı.`r`n`r`n$($_.Exception.Message)"
    }
}

function Apply-DefaultPrinterIssueFix {
    Write-Log "Varsayılan yazıcı/Windows yönetimi düzeltmesi uygulanıyor..."
    try {
        Set-DWordSafe "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" "LegacyDefaultPrinterMode" 1
        OK "Windows varsayılan yazıcıyı kendisi değiştirmesin ayarı uygulandı"
    } catch { WARN "Varsayılan yazıcı policy uygulanamadı: $_" }
}

function Apply-CommonPrinterFixBundle {
    if (-not (Confirm-UptAction "Hızlı Genel Onarım" "Yedek alınacak ve güvenli ortak yazıcı düzeltmeleri uygulanacak:`r`n- RPC / 0x0000011b / 0x00000709 uyumluluğu`r`n- Varsayılan yazıcı modu`r`n- Firewall / Network Discovery`r`n- Gerekli servisler`r`n- Spooler kuyruk temizliği`r`n`r`nGuest/SMB1 otomatik açılmaz. Devam edilsin mi?")) { return }
    New-BackupSnapshot -Reason "Before_Common_Printer_Fix" | Out-Null
    Apply-RPC-PrinterCore
    Apply-DefaultPrinterIssueFix
    if (-not [string]::IsNullOrWhiteSpace($txtRemotePc.Text.Trim()) -or -not [string]::IsNullOrWhiteSpace((Get-ServerFromUNC $txtManualUNC.Text.Trim()))) {
        Apply-PointAndPrint
    } else {
        WARN "Trusted Point&Print için uzak PC/UNC girilmedi; server listesi atlandı"
    }
    Enable-NetworkProfilePrivate
    Enable-PrinterFirewall
    Ensure-Services
    Reset-Spooler
    Invoke-GPUpdateSafe
    Show-Info "Hızlı Onarım" "Genel yazıcı onarımı tamamlandı.`r`nLog: $script:LogFile"
}

function Enable-LpdLprFeatures {
    if (-not (Confirm-UptAction "LPD/LPR Özellikleri" "Printing-LPDPrintService ve Printing-LPRPortMonitor Windows özellikleri etkinleştirilecek.`r`n`r`nBu, eski ağ yazıcıları ve bazı 0x00000709/operation failed senaryolarında yardımcı olur. Devam edilsin mi?" ([System.Windows.Forms.MessageBoxIcon]::Question))) { return }
    try {
        Invoke-UptProcess -FilePath "dism.exe" -Arguments "/online /Enable-Feature /FeatureName:Printing-LPDPrintService /NoRestart" -Wait -Hidden | Out-Null
        Invoke-UptProcess -FilePath "dism.exe" -Arguments "/online /Enable-Feature /FeatureName:Printing-LPRPortMonitor /NoRestart" -Wait -Hidden | Out-Null
        OK "LPD/LPR özellikleri etkinleştirme komutları tamamlandı"
        Mark-RestartRequired "LPD/LPR Windows özellikleri"
    } catch { WARN "LPD/LPR etkinleştirme hatası: $_" }
}

function Enable-Smb1ClientFeature {
    if (-not (Confirm-UptAction "SMB1 Riskli Seçenek" "SMB1 eski ve güvenlik riski taşıyan bir protokoldür. Yalnızca çok eski yazıcı/NAS/paylaşım cihazları için son çare olarak kullanılmalıdır.`r`n`r`nSMB1 Client etkinleştirilsin mi?")) { return }
    if (-not (Confirm-UptAction "SMB1 Son Onay" "Bu işlem güvenlik yüzeyini büyütebilir ve yeniden başlatma gerektirebilir.`r`n`r`nGerçekten devam edilsin mi?")) { return }
    try {
        New-BackupSnapshot -Reason "Before_SMB1_Client_Enable" | Out-Null
        Invoke-UptProcess -FilePath "dism.exe" -Arguments "/online /Enable-Feature /FeatureName:SMB1Protocol-Client /NoRestart" -Wait -Hidden | Out-Null
        OK "SMB1 Client etkinleştirme komutu tamamlandı"
        Mark-RestartRequired "SMB1 Client"
    } catch { WARN "SMB1 Client etkinleştirme hatası: $_" }
}

function Restore-SecurePrinterDefaults {
    if (-not (Confirm-UptAction "Güvenli Varsayılanlara Dön" "Uyumluluk için açılmış olabilecek riskli yazıcı/paylaşım ayarları güvenli değerlere çekilecek:`r`n- RPC privacy varsayılanı güçlendirilir`r`n- Point&Print admin kısıtı geri alınır`r`n- Insecure guest kapatılır`r`n- Anonymous erişim gevşetmeleri kapatılır`r`n`r`nÖnce yedek alınacak. Devam edilsin mi?")) { return }
    New-BackupSnapshot -Reason "Before_Restore_Secure_Defaults" | Out-Null
    try {
        Set-DWordSafe "HKLM:\System\CurrentControlSet\Control\Print" "RpcAuthnLevelPrivacyEnabled" 1
        $pnp = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint"
        Set-DWordSafe $pnp "RestrictDriverInstallationToAdministrators" 1
        Set-DWordSafe $pnp "NoWarningNoElevationOnInstall" 0
        Set-DWordSafe $pnp "NoWarningNoElevationOnUpdate" 0
        Set-DWordSafe $pnp "UpdatePromptSettings" 0
        Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "AllowInsecureGuestAuth" 0
        Set-DWordSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" "AllowInsecureGuestAuth" 0
        Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "restrictanonymous" 1
        Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "restrictanonymoussam" 1
        Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "everyoneincludesanonymous" 0
        Set-DWordSafe "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "restrictnullsessaccess" 1
        try { Restart-Service Spooler -Force -ErrorAction SilentlyContinue } catch {}
        Invoke-GPUpdateSafe
        Mark-RestartRequired "Güvenli varsayılanlar"
        Show-Info "Güvenli Varsayılanlar" "Güvenli varsayılanlara dönüş tamamlandı.`r`nBazı ayarlar için yeniden başlatma önerilir."
    } catch {
        ERR "Güvenli varsayılanlara dönüş başarısız: $_"
    }
}

$script:EmbeddedTools = @{
    "Fix_11b.cmd" = @"
QGVjaG8gb2ZmCmNoY3AgNjUwMDEgPm51bAp0aXRsZSBZYXrEsWPEsSBIYXRhc8SxIDB4MDAwMDAx
MWIgRMO8emVsdGljaQpjb2xvciAwQQoKZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PQplY2hvICAgICBZQVpJQ0kgQkHEnkxBTlRJIEhBVEFT
SSAweDAwMDAwMTFiIE9OQVJJTQplY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09CmVjaG8uCgpuZXQgc2Vzc2lvbiA+bnVsIDI+JjEKaWYgJWVy
cm9yTGV2ZWwlIG5lcSAwICgKICAgIGVjaG8gTMO8dGZlbiBidSBkb3N5YXnEsSBZw7ZuZXRpY2kg
T2xhcmFrIMOHYWzEscWfdMSxcsSxbiEKICAgIHBhdXNlCiAgICBleGl0CikKCmVjaG8uCmVjaG8g
WzEvNV0gS2F5xLF0IERlZnRlcmkgKFJlZ2lzdHJ5KSBBeWFyxLEgWWFwxLFsxLF5b3IuLi4KcmVn
IGFkZCAiSEtMTVxTWVNURU1cQ3VycmVudENvbnRyb2xTZXRcQ29udHJvbFxQcmludCIgL3YgUnBj
QXV0aG5MZXZlbFByaXZhY3lFbmFibGVkIC90IFJFR19EV09SRCAvZCAwIC9mCgplY2hvLgplY2hv
IFsyLzVdIFlhemTEsXJtYSBCaXJpa3RpcmljaXNpIER1cmR1cnVsdXlvciB2ZSBCYcWfbGF0xLFs
xLF5b3IuLi4KbmV0IHN0b3Agc3Bvb2xlciAveQp0aW1lb3V0IC90IDMgPm51bApuZXQgc3RhcnQg
c3Bvb2xlcgoKZWNoby4KZWNobyBbMy81XSBZYXrEsWPEsSBLdXlydcSfdSDDlm5iZWxsZcSfaSBU
ZW1pemxlbml5b3IuLi4KZGVsIC9xIC9mICIlc3lzdGVtcm9vdCVcU3lzdGVtMzJcc3Bvb2xcUFJJ
TlRFUlNcKi4qIiA+bnVsIDI+JjEKCmVjaG8uCmVjaG8gWzQvNV0gWWF6xLFjxLEgU2VydmlzaSBP
dG9tYXRpayBCYcWfbGFuZ8SxY2EgQXlhcmxhbsSxeW9yLi4uCnNjIGNvbmZpZyBzcG9vbGVyIHN0
YXJ0PSBhdXRvCm5ldCBzdGFydCBzcG9vbGVyCgplY2hvLgplY2hvIFs1LzVdIMSwxZ9sZW0gQmHF
n2FyxLF5bGEgVGFtYW1sYW5kxLEhCmVjaG8uCmVjaG8gPT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KZWNobyBZYXrEsWPEsSBIYXRhc8SxIDB4MDAw
MDAxMWIgQmHFn2FyxLF5bGEgRMO8emVsdGlsZGkKZWNoby4KZWNobyBTb3J1biBkZXZhbSBlZGVy
c2U6CmVjaG8gMS4gQW5hIChQYXlsYcWfYW4pIEJpbGdpc2F5YXLEsSBZZW5pZGVuIEJhxZ9sYXTE
sW4KZWNobyAyLiDEsHN0ZW1jaSAoQmHEn2xhbmFuKSBCaWxnaXNheWFyxLEgWWVuaWRlbiBCYcWf
bGF0xLFuCmVjaG8gMy4gWWF6xLFjxLEgQmHEn2xhbnTEsXPEsW7EsSBLYWxkxLFyxLFwIFllbmlk
ZW4gRWtsZXlpbgplY2hvID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09CnBhdXNlCmV4aXQ=
"@;
    "Fix_709.cmd" = @"
QGVjaG8gb2ZmCmNoY3AgNjUwMDEgPm51bAp0aXRsZSBZYXrEsWPEsSBIYXRhc8SxIDB4MDAwMDA3
MDkgRMO8emVsdGljaQpjb2xvciAwQQoKZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PQplY2hvICAgICAgWUFaSUNJIEJBxJ5MQU5USSBIQVRB
U0kgMHgwMDAwMDcwOSBPTkFSSU0KZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PQplY2hvLgoKbmV0IHNlc3Npb24gPm51bCAyPiYxCmlmICVl
cnJvckxldmVsJSBuZXEgMCAoCiAgICBlY2hvIEzDvHRmZW4gYnUgZG9zeWF5xLEgWcO2bmV0aWNp
IE9sYXJhayDDh2FsxLHFn3TEsXLEsW4hCiAgICBwYXVzZQogICAgZXhpdAopCgplY2hvLgplY2hv
IFsxLzhdIExQRCBZYXpkxLFybWEgU2VydmlzaSBFdGtpbmxlxZ90aXJpbGl5b3IuLi4KZGlzbSAv
b25saW5lIC9FbmFibGUtRmVhdHVyZSAvRmVhdHVyZU5hbWU6UHJpbnRpbmctTFBEUHJpbnRTZXJ2
aWNlIC9Ob1Jlc3RhcnQKZGlzbSAvb25saW5lIC9FbmFibGUtRmVhdHVyZSAvRmVhdHVyZU5hbWU6
UHJpbnRpbmctTFBSUG9ydE1vbml0b3IgL05vUmVzdGFydAoKZWNoby4KZWNobyBbMi84XSBSUEMg
WWF6xLFjxLEgUG9saXRpa2FsYXLEsSBZYXDEsWxhbmTEsXLEsWzEsXlvci4uLgpyZWcgYWRkICJI
S0xNXFNPRlRXQVJFXFBvbGljaWVzXE1pY3Jvc29mdFxXaW5kb3dzIE5UXFByaW50ZXJzXFJQQyIg
L3YgUnBjVXNlTmFtZWRQaXBlUHJvdG9jb2wgL3QgUkVHX0RXT1JEIC9kIDEgL2YKcmVnIGFkZCAi
SEtMTVxTT0ZUV0FSRVxQb2xpY2llc1xNaWNyb3NvZnRcV2luZG93cyBOVFxQcmludGVyc1xSUEMi
IC92IFJwY1Byb3RvY29scyAvdCBSRUdfRFdPUkQgL2QgNyAvZgpyZWcgYWRkICJIS0xNXFNPRlRX
QVJFXFBvbGljaWVzXE1pY3Jvc29mdFxXaW5kb3dzIE5UXFByaW50ZXJzXFJQQyIgL3YgRm9yY2VL
ZXJiZXJvc0ZvclJwYyAvdCBSRUdfRFdPUkQgL2QgMCAvZgoKZWNoby4KZWNobyBbMy84XSBScGNB
dXRobkxldmVsUHJpdmFjeUVuYWJsZWQgQXlhcsSxIFlhcMSxbMSxeW9yLi4uCnJlZyBhZGQgIkhL
TE1cU1lTVEVNXEN1cnJlbnRDb250cm9sU2V0XENvbnRyb2xcUHJpbnQiIC92IFJwY0F1dGhuTGV2
ZWxQcml2YWN5RW5hYmxlZCAvdCBSRUdfRFdPUkQgL2QgMCAvZgoKZWNoby4KZWNobyBbNC84XSBL
YXnEsXQgRGVmdGVyaSDEsHppbmxlcmkgS29udHJvbCBFZGlsaXlvci4uLgp0YWtlb3duIC9mICIl
c3lzdGVtcm9vdCVcU3lzdGVtMzJcc3Bvb2wiIC9yIC9kIHkgPm51bCAyPiYxCgplY2hvLgplY2hv
IFs1LzhdIFlhemTEsXJtYSBCaXJpa3RpcmljaXNpIFllbmlkZW4gQmHFn2xhdMSxbMSxeW9yLi4u
Cm5ldCBzdG9wIHNwb29sZXIgL3kKdGltZW91dCAvdCAzID5udWwKbmV0IHN0YXJ0IHNwb29sZXIK
CmVjaG8uCmVjaG8gWzYvOF0gWWF6xLFjxLEgw5ZuYmVsbGXEn2kgVGVtaXpsZW5peW9yLi4uCmRl
bCAvcSAvZiAiJXN5c3RlbXJvb3QlXFN5c3RlbTMyXHNwb29sXFBSSU5URVJTXCouKiIgPm51bCAy
PiYxCgplY2hvLgplY2hvIFs3LzhdIFNlcnZpcyBCYcWfbGFuZ8Sxw6cgVMO8cmxlcmkgQXlhcmxh
bsSxeW9yLi4uCnNjIGNvbmZpZyBzcG9vbGVyIHN0YXJ0PSBhdXRvCm5ldCBzdGFydCBzcG9vbGVy
CgplY2hvLgplY2hvIFs4LzhdIMSwxZ9sZW0gQmHFn2FyxLF5bGEgVGFtYW1sYW5kxLEhCmVjaG8u
CmVjaG8gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT0KZWNobyBZYXrEsWPEsSBIYXRhc8SxIDB4MDAwMDA3MDkgQmHFn2FyxLF5bGEgRMO8emVsdGls
ZGkKZWNobyBMw7x0ZmVuIEJpbGdpc2F5YXLEsW7EsXrEsSBZZW5pZGVuIEJhxZ9sYXTEsW4KZWNo
byA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQpw
YXVzZQpleGl0
"@;
    "GuestShare.cmd" = @"
QGVjaG8gb2ZmCmNoY3AgNjUwMDEgPm51bAp0aXRsZSBLb251ayAoR3Vlc3QpIFBheWxhxZ/EsW0g
SGF0YXPEsSBEw7x6ZWx0aWNpCmNvbG9yIDBBCgplY2hvID09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CmVjaG8gICAgICAgICBLT05VSyBWRSBBxJ4g
UEFZTEHFnklNIEhBVEFTSSBPTkFSSU0KZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PQplY2hvLgoKbmV0IHNlc3Npb24gPm51bCAyPiYxCmlm
ICVlcnJvckxldmVsJSBuZXEgMCAoCiAgICBlY2hvIEzDvHRmZW4gYnUgZG9zeWF5xLEgWcO2bmV0
aWNpIE9sYXJhayDDh2FsxLHFn3TEsXLEsW4hCiAgICBwYXVzZQogICAgZXhpdAopCgplY2hvLgpl
Y2hvIFsxLzddIEfDvHZlbnNpeiBLb251ayBFcmnFn2ltbGVyaSBFdGtpbmxlxZ90aXJpbGl5b3Ig
KExhbm1hbldvcmtzdGF0aW9uKS4uLgpyZWcgYWRkICJIS0xNXFNPRlRXQVJFXFBvbGljaWVzXE1p
Y3Jvc29mdFxXaW5kb3dzXExhbm1hbldvcmtzdGF0aW9uIiAvdiBBbGxvd0luc2VjdXJlR3Vlc3RB
dXRoIC90IFJFR19EV09SRCAvZCAxIC9mCgplY2hvLgplY2hvIFsyLzddIEHEnyBLZcWfZmkgR8O8
dmVubGlrIER1dmFyxLEgS3VyYWxsYXLEsSBBw6fEsWzEsXlvci4uLgpuZXRzaCBhZHZmaXJld2Fs
bCBmaXJld2FsbCBzZXQgcnVsZSBncm91cD0iTmV0d29yayBEaXNjb3ZlcnkiIG5ldyBlbmFibGU9
WWVzCgplY2hvLgplY2hvIFszLzddIERvc3lhIHZlIFlhesSxY8SxIFBheWxhxZ/EsW3EsSBHw7x2
ZW5saWsgRHV2YXLEsSBLdXJhbGxhcsSxIEHDp8SxbMSxeW9yLi4uCm5ldHNoIGFkdmZpcmV3YWxs
IGZpcmV3YWxsIHNldCBydWxlIGdyb3VwPSJGaWxlIGFuZCBQcmludGVyIFNoYXJpbmciIG5ldyBl
bmFibGU9WWVzCgplY2hvLgplY2hvIFs0LzddIEdlcmVrbGkgQcSfIFNlcnZpc2xlcmkgQmHFn2xh
dMSxbMSxeW9yLi4uCnNjIGNvbmZpZyBsYW5tYW53b3Jrc3RhdGlvbiBzdGFydD0gYXV0bwpzYyBj
b25maWcgbGFubWFuc2VydmVyIHN0YXJ0PSBhdXRvCm5ldCBzdGFydCBsYW5tYW53b3Jrc3RhdGlv
bgpuZXQgc3RhcnQgbGFubWFuc2VydmVyCgplY2hvLgplY2hvIFs1LzddIFNNQnYxIMSwc3RlbWNp
c2kgS3VydWx1eW9yIChFc2tpIFNpc3RlbSBVeXVtbHVsdcSfdSkuLi4KZGlzbSAvb25saW5lIC9F
bmFibGUtRmVhdHVyZSAvRmVhdHVyZU5hbWU6U01CMVByb3RvY29sIC9BbGwgL05vUmVzdGFydAoK
ZWNoby4KZWNobyBbNi83XSBXaW5kb3dzIEdlemdpbmkgKEV4cGxvcmVyKSBZZW5pZGVuIEJhxZ9s
YXTEsWzEsXlvci4uLgp0YXNra2lsbCAvZiAvaW0gZXhwbG9yZXIuZXhlID5udWwgMj4mMQpzdGFy
dCBleHBsb3Jlci5leGUKCmVjaG8uCmVjaG8gWzcvN10gxLDFn2xlbSBCYcWfYXLEsXlsYSBUYW1h
bWxhbmTEsSEKZWNoby4KZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PQplY2hvIEtvbnVrIFBheWxhxZ/EsW0gU29ydW5sYXLEsSBEw7x6ZWx0
aWxkaQplY2hvLgplY2hvIMWeaW1kaSDFn3UgxZ9la2lsZGUgZXJpxZ9tZXlpIGRlbmV5aW46CmVj
aG8gXFxCSUxHSVNBWUFSX0FESVxQQVlMQVNJTV9BREkKZWNoby4KZWNobyBHZXJla2lyc2UgQmls
Z2lzYXlhcsSxbsSxesSxIFllbmlkZW4gQmHFn2xhdMSxbgplY2hvID09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CnBhdXNlCmV4aXQ=
"@;
    "AdvancedToolkit.cmd" = @"
QGVjaG8gb2ZmCmNoY3AgNjUwMDEgPm51bAp0aXRsZSBHRUzEsMWeTcSwxZ4gWUFaSUNJIEFSQcOH
IEtVVFVTVSAoS29uc29sIFPDvHLDvG3DvCkKY29sb3IgMEIKCjpNRU5VCmNscwplY2hvID09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CmVjaG8g
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBHRUzEsMWeTcSwxZ4gWUFaSUNJIE9O
QVJJTSBBUkHDhyBLVVRVU1UKZWNobyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PQplY2hvLgplY2hvICAgWzFdIEhhdGEgMHgwMDAwMDExYiDD
h8O2esO8bcO8ICAgIFsyXSBIYXRhIDB4MDAwMDA3MDkgw4fDtnrDvG3DvCAgICAgWzNdIFZhcnNh
ecSxbGFuIFlhesSxY8SxIFNvcnVudQplY2hvICAgICAgIFlhesSxY8SxeWEgQmHEn2xhbmFtxLF5
b3IgICAgICAgICBWYXJzYXnEsWxhbiBZYXDEsWxhbcSxeW9yICAgICAgICBWYXJzYXnEsWxhbiBE
ZcSfacWfbWl5b3IKZWNoby4KZWNobyAgIFs0XSBQYXlsYcWfxLFtIEJhxJ9sYW50xLEgSGF0YXPE
sSAgWzVdIMOHZXZyaW1kxLHFn8SxIFlhesSxY8SxIFNvcnVudSAgIFs2XSBCaXJpa3RpcmljaSAo
U3Bvb2xlcikgSGF0YXPEsQplY2hvICAgICAgIEHEnyBZYXrEsWPEsXPEsSBCYcSfbGFuYW1hZMSx
ICAgICAgIFlhesSxY8SxIMOHZXZyaW1kxLHFn8SxIEfDtnLDvG7DvHlvciAgIFNlcnZpcyDDh2Fs
xLHFn23EsXlvcgplY2hvLgplY2hvICAgWzddIFlhesSxY8SxIEt1eXJ1xJ91IFRlbWl6bGVtZSAg
WzhdIEVyacWfaW0gRW5nZWxsZW5kaSBIYXRhc8SxICAgWzldIFNNQiBLb251ayAoR3Vlc3QpIFBh
eWxhxZ/EsW3EsQplY2hvICAgICAgIFlhemTEsXLEsWxhbWF5YW4gQmVsZ2VsZXIgICAgICAgxLB6
aW4gdmUgWWV0a2kgU29ydW5sYXLEsSAgICAgICBLdWxsYW7EsWPEsSBBZMSxIMWeaWZyZSBTb3J1
bnUKZWNoby4KZWNobyAgIFsxMF0gU8O8csO8Y8O8IEFyYXnDvHrDvG7DvCBBw6cgICAgICBbMTFd
IEHEnyBCdWxtYSB2ZSBLZcWfaWYgQcOnICAgICAgWzEyXSBSUEMgU3VudWN1c3UgSGF0YXPEsQpl
Y2hvICAgICAgICBTw7xyw7xjw7wgRWtsZW1lL0thbGTEsXJtYSAgICAgICBZYXrEsWPEsSBBxJ9k
YSBHw7Zyw7xubcO8eW9yICAgICAgICBSUEMgxLBsZXRpxZ9pbSBIYXRhc8SxCmVjaG8uCmVjaG8g
ICBbMTNdIExQRC9MUFIgU2VydmlzIEt1cnVsdW11ICBbMTRdIFTDvG0gWWF6xLFjxLFsYXLEsSBL
YWxkxLFyICAgICBbMTVdIFPDvHLDvGPDvCBBcmF5w7x6w7xuw7wgQcOnCmVjaG8gICAgICAgIMSw
xZ9sZW0gVGFtYW1sYW5hbWFkxLEgSGF0YXPEsSAgIFnDvGtsw7wgWWF6xLFjxLFsYXLEsSBTaWxl
ciAgICAgICAgU8O8csO8Y8O8bGVyaSBUZW1pemxlCmVjaG8uCmVjaG8gICBbMTZdIFPDvHLDvG0g
MyBTw7xyw7xjw7xsZXJpIFNpbCAgIFsxN10gU8O8csO8bSA0IFPDvHLDvGPDvGxlcmkgU2lsICAg
IFsxOF0gS2F5xLF0IERlZnRlcmkgVGVtaXpsacSfaQplY2hvICAgICAgICBFc2tpIFPDvHLDvGPD
vCBQYWtldGxlcmkgICAgICAgIE1vZGVybiBTw7xyw7xjw7wgUGFrZXRsZXJpICAgICAgIFlhesSx
Y8SxIEthecSxdGxhcsSxbsSxIFNpbAplY2hvLgplY2hvICAgWzE5XSBZYXrEsWPEsSBLdXlydcSf
dW51IFNpbCAgICAgWzIwXSBCaXJpa3RpcmljaXlpIFJlc3RhcnQgRXQgIFsyMV0gS09NUExFIFlB
WklDSSBTSUZJUkxBTUEKZWNobyAgICAgICAgS3V5cnVrdGEgQmVrbGV5ZW4gxLDFn2xlciAgICAg
IFNlcnZpc2kgWWVuaWRlbiBCYcWfbGF0xLFyICAgICAgVMO8bSBTaXN0ZW0gU8SxZsSxcmxhbWEK
ZWNoby4KZWNobyAgIFsyMl0gw5ZORVLEsExFTiBUw5xNIE9OQVJJTUxBUiAgIFsyM10gw4fEsWvE
scWfCmVjaG8gICAgICAgIE90b21hdGlrIFRvcGx1IFBha2V0CmVjaG8uCmVjaG8gPT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0Kc2V0IC9wIGNo
b2ljZT1TZcOnZW5layBOdW1hcmFzxLFuxLEgR2lyaW4gKDEtMjMpOiAKCmlmICIlY2hvaWNlJSI9
PSIxIiBnb3RvIEZJWDExQgppZiAiJWNob2ljZSUiPT0iMiIgZ290byBGSVg3MDkKaWYgIiVjaG9p
Y2UlIj09IjMiIGdvdG8gREVGQVVMVFBSSU5URVIKaWYgIiVjaG9pY2UlIj09IjQiIGdvdG8gU0hB
UkVQUklOVEVSCmlmICIlY2hvaWNlJSI9PSI1IiBnb3RvIE9GRkxJTkUKaWYgIiVjaG9pY2UlIj09
IjYiIGdvdG8gU1BPT0xFUgppZiAiJWNob2ljZSUiPT0iNyIgZ290byBRVUVVRQppZiAiJWNob2lj
ZSUiPT0iOCIgZ290byBBQ0NFU1MKaWYgIiVjaG9pY2UlIj09IjkiIGdvdG8gU01CCmlmICIlY2hv
aWNlJSI9PSIxMCIgZ290byBEUklWRVIKaWYgIiVjaG9pY2UlIj09IjExIiBnb3RvIERJU0NPVkVS
WQppZiAiJWNob2ljZSUiPT0iMTIiIGdvdG8gUlBDCmlmICIlY2hvaWNlJSI9PSIxMyIgZ290byBP
UEZBSUxFRAppZiAiJWNob2ljZSUiPT0iMTQiIGdvdG8gUkVNT1ZFUFJJTlRFUgppZiAiJWNob2lj
ZSUiPT0iMTUiIGdvdG8gUkVNT1ZFRFJJVkVSCmlmICIlY2hvaWNlJSI9PSIxNiIgZ290byBWRVJT
SU9OMwppZiAiJWNob2ljZSUiPT0iMTciIGdvdG8gVkVSU0lPTjQKaWYgIiVjaG9pY2UlIj09IjE4
IiBnb3RvIFJFR0NMRUFOCmlmICIlY2hvaWNlJSI9PSIxOSIgZ290byBDTEVBUlFVRVVFCmlmICIl
Y2hvaWNlJSI9PSIyMCIgZ290byBSRVNUQVJUU1BPT0xFUgppZiAiJWNob2ljZSUiPT0iMjEiIGdv
dG8gRlVMTENMRUFOCmlmICIlY2hvaWNlJSI9PSIyMiIgZ290byBBTExGSVgKaWYgIiVjaG9pY2Ul
Ij09IjIzIiBleGl0Cgpnb3RvIE1FTlUKCjpGSVgxMUIKcmVnIGFkZCAiSEtMTVxTWVNURU1cQ3Vy
cmVudENvbnRyb2xTZXRcQ29udHJvbFxQcmludCIgL3YgUnBjQXV0aG5MZXZlbFByaXZhY3lFbmFi
bGVkIC90IFJFR19EV09SRCAvZCAwIC9mCm5ldCBzdG9wIHNwb29sZXIgL3kKbmV0IHN0YXJ0IHNw
b29sZXIKZWNobyBIQVRBIDB4MDAwMDAxMWIgRMOcWkVMVMSwTETEsCEKcGF1c2UKZ290byBNRU5V
Cgo6RklYNzA5CnJlZyBhZGQgIkhLTE1cU29mdHdhcmVcUG9saWNpZXNcTWljcm9zb2Z0XFdpbmRv
d3MgTlRcUHJpbnRlcnNcUlBDIiAvdiBScGNVc2VOYW1lZFBpcGVQcm90b2NvbCAvdCBSRUdfRFdP
UkQgL2QgMSAvZgpyZWcgYWRkICJIS0xNXFNZU1RFTVxDdXJyZW50Q29udHJvbFNldFxDb250cm9s
XFByaW50IiAvdiBScGNBdXRobkxldmVsUHJpdmFjeUVuYWJsZWQgL3QgUkVHX0RXT1JEIC9kIDAg
L2YKbmV0IHN0b3Agc3Bvb2xlciAveQpuZXQgc3RhcnQgc3Bvb2xlcgplY2hvIEhBVEEgMHgwMDAw
MDcwOSBEw5xaRUxUxLBMRMSwIQpwYXVzZQpnb3RvIE1FTlUKCjpERUZBVUxUUFJJTlRFUgpSRUcg
QUREICJIS0NVXFNvZnR3YXJlXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRWZXJzaW9uXFdp
bmRvd3MiIC92IExlZ2FjeURlZmF1bHRQcmludGVyTW9kZSAvdCBSRUdfRFdPUkQgL2QgMSAvZgpl
Y2hvIFZBUlNBWUlMQU4gWUFaSUNJIFNPUlVOVSBEw5xaRUxUxLBMRMSwIQpwYXVzZQpnb3RvIE1F
TlUKCjpTSEFSRVBSSU5URVIKbmV0c2ggYWR2ZmlyZXdhbGwgZmlyZXdhbGwgc2V0IHJ1bGUgZ3Jv
dXA9IkZpbGUgYW5kIFByaW50ZXIgU2hhcmluZyIgbmV3IGVuYWJsZT1ZZXMKZWNobyBET1NZQSBW
RSBZQVpJQ0kgUEFZTEHFnklNSSBBw4dJTERJIQpwYXVzZQpnb3RvIE1FTlUKCjpPRkZMSU5FCm5l
dCBzdG9wIHNwb29sZXIgL3kKbmV0IHN0YXJ0IHNwb29sZXIKZWNobyBZQVpJQ0kgw4dFVlLEsE1E
ScWeSSBTT1JVTlUgRMOcWkVMVMSwTETEsCEKcGF1c2UKZ290byBNRU5VCgo6U1BPT0xFUgpuZXQg
c3RvcCBzcG9vbGVyIC95Cm5ldCBzdGFydCBzcG9vbGVyCmVjaG8gWUFaSUNJIELEsFLEsEtUxLBS
xLBDxLBTxLAgRMOcWkVMVMSwTETEsCEKcGF1c2UKZ290byBNRU5VCgo6UVVFVUUKbmV0IHN0b3Ag
c3Bvb2xlciAveQpkZWwgL1EgL0YgL1MgIiVzeXN0ZW1yb290JVxTeXN0ZW0zMlxzcG9vbFxQUklO
VEVSU1wqLioiCm5ldCBzdGFydCBzcG9vbGVyCmVjaG8gWUFaSUNJIEtVWVJVxJ5VIFRFTcSwWkxF
TkTEsCEKcGF1c2UKZ290byBNRU5VCgo6QUNDRVNTCnRha2Vvd24gL2YgIiVzeXN0ZW1yb290JVxT
eXN0ZW0zMlxzcG9vbCIgL3IgL2QgeQppY2FjbHMgIiVzeXN0ZW1yb290JVxTeXN0ZW0zMlxzcG9v
bCIgL2dyYW50IGFkbWluaXN0cmF0b3JzOkYgL3QKZWNobyBFUsSwxZ7EsE0gWUVUS8SwTEVSxLAg
RMOcWkVMVMSwTETEsCEKcGF1c2UKZ290byBNRU5VCgo6U01CCnJlZyBhZGQgIkhLTE1cU09GVFdB
UkVcUG9saWNpZXNcTWljcm9zb2Z0XFdpbmRvd3NcTGFubWFuV29ya3N0YXRpb24iIC92IEFsbG93
SW5zZWN1cmVHdWVzdEF1dGggL3QgUkVHX0RXT1JEIC9kIDEgL2YKZWNobyBTTUIgS09OVUsgRVLE
sMWexLBNxLAgRMOcWkVMVMSwTETEsCEKcGF1c2UKZ290byBNRU5VCgo6RFJJVkVSCnJ1bmRsbDMy
IHByaW50dWkuZGxsLFByaW50VUlFbnRyeSAvcyAvdDIKZWNobyBTw5xSw5xDw5wgWcOWTkVUxLBN
IEFSQVnDnFrDnCBBw4dJTERJIQpwYXVzZQpnb3RvIE1FTlUKCjpESVNDT1ZFUlkKbmV0c2ggYWR2
ZmlyZXdhbGwgZmlyZXdhbGwgc2V0IHJ1bGUgZ3JvdXA9Ik5ldHdvcmsgRGlzY292ZXJ5IiBuZXcg
ZW5hYmxlPVllcwplY2hvIEHEniBLRcWeRsSwIEVUS8SwTkzEsMWeVMSwUsSwTETEsCEKcGF1c2UK
Z290byBNRU5VCgo6UlBDCnNjIGNvbmZpZyBScGNTcyBzdGFydD0gYXV0bwpuZXQgc3RhcnQgUnBj
U3MKZWNobyBSUEMgU0VSVsSwU8SwIFlBUElMQU5ESVJJTERJIQpwYXVzZQpnb3RvIE1FTlUKCjpP
UEZBSUxFRApkaXNtIC9vbmxpbmUgL0VuYWJsZS1GZWF0dXJlIC9GZWF0dXJlTmFtZTpQcmludGlu
Zy1MUERQcmludFNlcnZpY2UgL05vUmVzdGFydApkaXNtIC9vbmxpbmUgL0VuYWJsZS1GZWF0dXJl
IC9GZWF0dXJlTmFtZTpQcmludGluZy1MUFJQb3J0TW9uaXRvciAvTm9SZXN0YXJ0CmVjaG8gTFBE
L0xQUiBTRVJWxLBTIEtVUlVMVU1VIEJBxZ5MQVRJTERJIQpwYXVzZQpnb3RvIE1FTlUKCjpSRU1P
VkVQUklOVEVSCmZvciAvZiAic2tpcD0xIHRva2Vucz0qIiAlJXAgaW4gKCd3bWljIHByaW50ZXIg
Z2V0IG5hbWUnKSBkbyAoCiBpZiBub3QgIiUlcCI9PSIiICgKICBwcmludHVpLmV4ZSAvZGwgL24g
IiUlcCIKICkKKQplY2hvIFTDnE0gWUFaSUNJTEFSIFPEsEzEsE5ExLAhCnBhdXNlCmdvdG8gTUVO
VQoKOlJFTU9WRURSSVZFUgpydW5kbGwzMiBwcmludHVpLmRsbCxQcmludFVJRW50cnkgL3MgL3Qy
CmVjaG8gU8OcUsOcQ8OcIEVLUkFOSU5EQU4gTUFOVUVMIFPEsEzEsE7EsFohCnBhdXNlCmdvdG8g
TUVOVQoKOlZFUlNJT04zCm5ldCBzdG9wIHNwb29sZXIgL3kKcmVnIGRlbGV0ZSAiSEtMTVxTWVNU
RU1cQ3VycmVudENvbnRyb2xTZXRcQ29udHJvbFxQcmludFxFbnZpcm9ubWVudHNcV2luZG93cyB4
NjRcRHJpdmVyc1xWZXJzaW9uLTMiIC9mCm5ldCBzdGFydCBzcG9vbGVyCmVjaG8gU8OcUsOcTS0z
IFPDnFLDnEPDnExFUiBURU3EsFpMRU5ExLAhCnBhdXNlCmdvdG8gTUVOVQoKOlZFUlNJT040Cm5l
dCBzdG9wIHNwb29sZXIgL3kKcmVnIGRlbGV0ZSAiSEtMTVxTWVNURU1cQ3VycmVudENvbnRyb2xT
ZXRcQ29udHJvbFxQcmludFxFbnZpcm9ubWVudHNcV2luZG93cyB4NjRcRHJpdmVyc1xWZXJzaW9u
LTQiIC9mCm5ldCBzdGFydCBzcG9vbGVyCmVjaG8gU8OcUsOcTS00IFPDnFLDnEPDnExFUiBURU3E
sFpMRU5ExLAhCnBhdXNlCmdvdG8gTUVOVQoKOlJFR0NMRUFOCnJlZyBkZWxldGUgIkhLQ1VcUHJp
bnRlcnMiIC9mCnJlZyBkZWxldGUgIkhLTE1cU1lTVEVNXEN1cnJlbnRDb250cm9sU2V0XENvbnRy
b2xcUHJpbnRcUHJpbnRlcnMiIC9mCmVjaG8gUkVHSVNUUlkgWUFaSUNJIEFZQVJMQVJJIFRFTcSw
WkxFTkTEsCEKcGF1c2UKZ290byBNRU5VCgo6Q0xFQVJRVUVVRQpuZXQgc3RvcCBzcG9vbGVyIC95
CmRlbCAvUSAvRiAvUyAiJXN5c3RlbXJvb3QlXFN5c3RlbTMyXHNwb29sXFBSSU5URVJTXCouKiIK
bmV0IHN0YXJ0IHNwb29sZXIKZWNobyBZQVpJQ0kgS1VZUlXEnlUgVEVNxLBaTEVORMSwIQpwYXVz
ZQpnb3RvIE1FTlUKCjpSRVNUQVJUU1BPT0xFUgpuZXQgc3RvcCBzcG9vbGVyIC95CnRpbWVvdXQg
L3QgMiA+bnVsCm5ldCBzdGFydCBzcG9vbGVyCmVjaG8gQsSwUsSwS1TEsFLEsEPEsCBZRU7EsERF
TiBCQcWeTEFUSUxESSEKcGF1c2UKZ290byBNRU5VCgo6RlVMTENMRUFOCm5ldCBzdG9wIHNwb29s
ZXIgL3kKZGVsIC9RIC9GIC9TICIlc3lzdGVtcm9vdCVcU3lzdGVtMzJcc3Bvb2xcUFJJTlRFUlNc
Ki4qIgpyZWcgZGVsZXRlICJIS0NVXFByaW50ZXJzIiAvZgpyZWcgZGVsZXRlICJIS0xNXFNZU1RF
TVxDdXJyZW50Q29udHJvbFNldFxDb250cm9sXFByaW50XFByaW50ZXJzIiAvZgpyZWcgZGVsZXRl
ICJIS0xNXFNZU1RFTVxDdXJyZW50Q29udHJvbFNldFxDb250cm9sXFByaW50XEVudmlyb25tZW50
c1xXaW5kb3dzIHg2NFxEcml2ZXJzXFZlcnNpb24tMyIgL2YKcmVnIGRlbGV0ZSAiSEtMTVxTWVNU
RU1cQ3VycmVudENvbnRyb2xTZXRcQ29udHJvbFxQcmludFxFbnZpcm9ubWVudHNcV2luZG93cyB4
NjRcRHJpdmVyc1xWZXJzaW9uLTQiIC9mCm5ldCBzdGFydCBzcG9vbGVyCmVjaG8gS09NUExFIFPE
sFNURU0gU0lGSVJMQU1BU0kgVEFNQU1MQU5ESSEKcGF1c2UKZ290byBNRU5VCgo6QUxMRklYCnJl
ZyBhZGQgIkhLTE1cU1lTVEVNXEN1cnJlbnRDb250cm9sU2V0XENvbnRyb2xcUHJpbnQiIC92IFJw
Y0F1dGhuTGV2ZWxQcml2YWN5RW5hYmxlZCAvdCBSRUdfRFdPUkQgL2QgMCAvZgpyZWcgYWRkICJI
S0xNXFNvZnR3YXJlXFBvbGljaWVzXE1pY3Jvc29mdFxXaW5kb3dzIE5UXFByaW50ZXJzXFJQQyIg
L3YgUnBjVXNlTmFtZWRQaXBlUHJvdG9jb2wgL3QgUkVHX0RXT1JEIC9kIDEgL2YKUkVHIEFERCAi
SEtDVVxTb2Z0d2FyZVxNaWNyb3NvZnRcV2luZG93cyBOVFxDdXJyZW50VmVyc2lvblxXaW5kb3dz
IiAvdiBMZWdhY3lEZWZhdWx0UHJpbnRlck1vZGUgL3QgUkVHX0RXT1JEIC9kIDEgL2YKcmVnIGFk
ZCAiSEtMTVxTT0ZUV0FSRVxQb2xpY2llc1xNaWNyb3NvZnRcV2luZG93c1xMYW5tYW5Xb3Jrc3Rh
dGlvbiIgL3YgQWxsb3dJbnNlY3VyZUd1ZXN0QXV0aCAvdCBSRUdfRFdPUkQgL2QgMSAvZgpuZXRz
aCBhZHZmaXJld2FsbCBmaXJld2FsbCBzZXQgcnVsZSBncm91cD0iTmV0d29yayBEaXNjb3Zlcnki
IG5ldyBlbmFibGU9WWVzCm5ldHNoIGFkdmZpcmV3YWxsIGZpcmV3YWxsIHNldCBydWxlIGdyb3Vw
PSJGaWxlIGFuZCBQcmludGVyIFNoYXJpbmciIG5ldyBlbmFibGU9WWVzCm5ldCBzdG9wIHNwb29s
ZXIgL3kKZGVsIC9RIC9GIC9TICIlc3lzdGVtcm9vdCVcU3lzdGVtMzJcc3Bvb2xcUFJJTlRFUlNc
Ki4qIgpuZXQgc3RhcnQgc3Bvb2xlcgplY2hvIMOWTkVSxLBMRU4gVMOcTSBPTkFSSU1MQVIgVVlH
VUxBTkRJIQpwYXVzZQpnb3RvIE1FTlU=
"@;
    "Printer_Enterprise_FixTool_v2.ps1" = @"
ZnVuY3Rpb24gVGVzdC1Jc0FkbWluaXN0cmF0b3IgewogICAgdHJ5IHsKICAgICAgICAkaWRlbnRp
dHkgPSBbU2VjdXJpdHkuUHJpbmNpcGFsLldpbmRvd3NJZGVudGl0eV06OkdldEN1cnJlbnQoKQog
ICAgICAgICRwcmluY2lwYWwgPSBOZXctT2JqZWN0IFNlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dz
UHJpbmNpcGFsKCRpZGVudGl0eSkKICAgICAgICByZXR1cm4gJHByaW5jaXBhbC5Jc0luUm9sZShb
U2VjdXJpdHkuUHJpbmNpcGFsLldpbmRvd3NCdWlsdEluUm9sZV06OkFkbWluaXN0cmF0b3IpCiAg
ICB9IGNhdGNoIHsgcmV0dXJuICRmYWxzZSB9Cn0KCmZ1bmN0aW9uIEdldC1QcmVmZXJyZWRQb3dl
clNoZWxsSG9zdCB7CiAgICB0cnkgewogICAgICAgICRjbWQgPSBHZXQtQ29tbWFuZCBwd3NoLmV4
ZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgIGlmICgkY21kIC1hbmQgJGNt
ZC5Tb3VyY2UpIHsgcmV0dXJuICRjbWQuU291cmNlIH0KICAgIH0gY2F0Y2gge30KICAgIHJldHVy
biAicG93ZXJzaGVsbC5leGUiCn0KCmlmICgtbm90IChUZXN0LUlzQWRtaW5pc3RyYXRvcikpIHsK
ICAgIHRyeSB7CiAgICAgICAgJHBzSG9zdCA9IEdldC1QcmVmZXJyZWRQb3dlclNoZWxsSG9zdAog
ICAgICAgICRhcmdMaXN0ID0gQCgiLU5vUHJvZmlsZSIsIi1FeGVjdXRpb25Qb2xpY3kiLCJCeXBh
c3MiLCItRmlsZSIsKCciezB9IicgLWYgJFBTQ29tbWFuZFBhdGgpKQogICAgICAgIFN0YXJ0LVBy
b2Nlc3MgLUZpbGVQYXRoICRwc0hvc3QgLUFyZ3VtZW50TGlzdCAkYXJnTGlzdCAtVmVyYiBSdW5B
cyAtV2luZG93U3R5bGUgTm9ybWFsIHwgT3V0LU51bGwKICAgIH0gY2F0Y2ggewogICAgICAgIHRy
eSB7CiAgICAgICAgICAgIEFkZC1UeXBlIC1Bc3NlbWJseU5hbWUgU3lzdGVtLldpbmRvd3MuRm9y
bXMKICAgICAgICAgICAgW1N5c3RlbS5XaW5kb3dzLkZvcm1zLk1lc3NhZ2VCb3hdOjpTaG93KCJC
dSBhcmHDpyB5YXrEsWPEsSwgc2VydmlzIHZlIHJlZ2lzdHJ5IGnFn2xlbWxlcmkgacOnaW4gecO2
bmV0aWNpIGl6bmkgaXN0ZXIuYHJgbmByYG5Zw7ZuZXRpY2kgb2xhcmFrIGJhxZ9sYXTEsWxhbWFk
xLE6ICQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIiwiUFJOIFlldGtpIEdlcmVrbGkiLFtTeXN0ZW0u
V2luZG93cy5Gb3Jtcy5NZXNzYWdlQm94QnV0dG9uc106Ok9LLFtTeXN0ZW0uV2luZG93cy5Gb3Jt
cy5NZXNzYWdlQm94SWNvbl06OkVycm9yKSB8IE91dC1OdWxsCiAgICAgICAgfSBjYXRjaCB7fQog
ICAgfQogICAgZXhpdAp9CgpBZGQtVHlwZSAtQXNzZW1ibHlOYW1lIFN5c3RlbS5XaW5kb3dzLkZv
cm1zCkFkZC1UeXBlIC1Bc3NlbWJseU5hbWUgU3lzdGVtLkRyYXdpbmcKW1N5c3RlbS5XaW5kb3dz
LkZvcm1zLkFwcGxpY2F0aW9uXTo6RW5hYmxlVmlzdWFsU3R5bGVzKCkKCiRFcnJvckFjdGlvblBy
ZWZlcmVuY2UgPSAiQ29udGludWUiCgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojIFBSTiBVTFRJTUFURSBFTlRFUlBSSVNFIFRP
T0wgVjIuMyBWSVNVQUwgQkFDS1VQCiMgQWxpYXM6IFBSTl9VRVRfRU5URVJQUklTRV9WMl8zX1ZJ
U1VBTF9CQUNLVVAKIyBUYW0gw7Z6ZWxsaWtsaSBvbmFyxLFtOgojIC0gSG9zdC9DbGllbnQgb3Rv
bWF0aWsgYWxnxLFsYW1hICsgbWFudWVsIHJvbAojIC0gQcSfIHlhesSxY8Sxc8SxIGJ1bG1hIC8g
bmV0IHZpZXcgLyBDSU0KIyAtIFllcmVsL3V6YWsgYXLEsXphIHRlc3BpdAojIC0gUlBDLzExYiwg
NzA5LCBQb2ludCZQcmludCwgUGFja2FnZSBQb2ludCZQcmludAojIC0gU01CLCBndWVzdCwgZmly
ZXdhbGwsIGRpc2NvdmVyeSwgc2VydmljZXMsIHNwb29sZXIKIyAtIENyZWRlbnRpYWwgY2xlYW51
cCwgZHJpdmVyIGNhY2hlIGNsZWFudXAKIyAtIEFkZC1QcmludGVyLCBQcmludFVJLCBXU2NyaXB0
LCBQcmludFVJIC9nYQojIC0gR2Vyw6dlayBiYcSfbGFudMSxIGRvxJ9ydWxhbWEKIyAtIExvZyAr
IEhUTUwgcmFwb3IKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT0KCiRzY3JpcHQ6QXBwQ29kZSA9ICJQUk5fVUVUX0VOVEVSUFJJU0Vf
VjJfM19WSVNVQUxfQkFDS1VQIgokc2NyaXB0OkFwcE5hbWUgPSAiUFJOIEt1cnVtc2FsIFlhesSx
Y8SxIEHEnyBQYXlsYcWfxLFtIE9uYXLEsW0gTWVya2V6aSIKJHNjcmlwdDpEZXRlY3RlZFJvbGUg
PSAiQmVsaXJzaXoiCgpmdW5jdGlvbiBHZXQtV3JpdGFibGVUb29sRGlyZWN0b3J5IHsKICAgIHBh
cmFtKFtzdHJpbmddJExlYWYpCiAgICAkY2FuZGlkYXRlcyA9IEAoCiAgICAgICAgKEpvaW4tUGF0
aCAkUFNTY3JpcHRSb290ICRMZWFmKSwKICAgICAgICAoSm9pbi1QYXRoICRlbnY6UHJvZ3JhbURh
dGEgIlBSTl9FbnRlcnByaXNlX0ZpeFRvb2xcJExlYWYiKSwKICAgICAgICAoSm9pbi1QYXRoICRl
bnY6VEVNUCAiUFJOX0VudGVycHJpc2VfRml4VG9vbFwkTGVhZiIpCiAgICApCiAgICBmb3JlYWNo
ICgkY2FuZGlkYXRlIGluICRjYW5kaWRhdGVzKSB7CiAgICAgICAgdHJ5IHsKICAgICAgICAgICAg
aWYgKCEoVGVzdC1QYXRoICRjYW5kaWRhdGUpKSB7IE5ldy1JdGVtIC1QYXRoICRjYW5kaWRhdGUg
LUl0ZW1UeXBlIERpcmVjdG9yeSAtRm9yY2UgfCBPdXQtTnVsbCB9CiAgICAgICAgICAgICRwcm9i
ZSA9IEpvaW4tUGF0aCAkY2FuZGlkYXRlICIud3JpdGVfdGVzdCIKICAgICAgICAgICAgU2V0LUNv
bnRlbnQgLVBhdGggJHByb2JlIC1WYWx1ZSAib2siIC1FbmNvZGluZyBBU0NJSSAtRm9yY2UKICAg
ICAgICAgICAgUmVtb3ZlLUl0ZW0gLVBhdGggJHByb2JlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2ls
ZW50bHlDb250aW51ZQogICAgICAgICAgICByZXR1cm4gJGNhbmRpZGF0ZQogICAgICAgIH0gY2F0
Y2gge30KICAgIH0KICAgIHJldHVybiAoSm9pbi1QYXRoICRlbnY6VEVNUCAiUFJOX0VudGVycHJp
c2VfRml4VG9vbFwkTGVhZiIpCn0KCiRzY3JpcHQ6TG9nRGlyID0gR2V0LVdyaXRhYmxlVG9vbERp
cmVjdG9yeSAiUFJOX1VFVF9Mb2dzIgokc2NyaXB0OkJhY2t1cFJvb3QgPSBHZXQtV3JpdGFibGVU
b29sRGlyZWN0b3J5ICJCYWNrdXBzIgokc2NyaXB0Okxhc3RCYWNrdXBQYXRoID0gIiIKCiRzY3Jp
cHQ6TG9nRmlsZSA9IEpvaW4tUGF0aCAkc2NyaXB0OkxvZ0RpciAoIlBSTl9VRVRfRlVMTF97MH0u
bG9nIiAtZiAoR2V0LURhdGUgLUZvcm1hdCAieXl5eU1NZGRfSEhtbXNzIikpCgokc2NyaXB0OkZv
dW5kSXRlbXMgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbb2Jq
ZWN0XQokc2NyaXB0OkRpYWdJdGVtcyA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkdl
bmVyaWMuTGlzdFtvYmplY3RdCiRzY3JpcHQ6QWN0aW9uSXRlbXMgPSBOZXctT2JqZWN0IFN5c3Rl
bS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbb2JqZWN0XQokc2NyaXB0OlByaW50ZXJWZW5kb3JQ
YXR0ZXJucyA9IEAoCiAgICBbUFNDdXN0b21PYmplY3RdQHsgRmlsdGVyPSJIUCI7IFBhdHRlcm49
IlxiKEhQfEhld2xldHRbXHMtXSpQYWNrYXJkKVxiIiB9LAogICAgW1BTQ3VzdG9tT2JqZWN0XUB7
IEZpbHRlcj0iQ2Fub24iOyBQYXR0ZXJuPSJcYkNhbm9uXGIiIH0sCiAgICBbUFNDdXN0b21PYmpl
Y3RdQHsgRmlsdGVyPSJLeW9jZXJhIjsgUGF0dGVybj0iXGJLeW9jZXJhXGIiIH0sCiAgICBbUFND
dXN0b21PYmplY3RdQHsgRmlsdGVyPSJSaWNvaCI7IFBhdHRlcm49IlxiUmljb2hcYiIgfSwKICAg
IFtQU0N1c3RvbU9iamVjdF1AeyBGaWx0ZXI9IktvbmljYSI7IFBhdHRlcm49IlxiKEtvbmljYXxN
aW5vbHRhfEtvbmljYVtccy1dKk1pbm9sdGEpXGIiIH0sCiAgICBbUFNDdXN0b21PYmplY3RdQHsg
RmlsdGVyPSJYZXJveCI7IFBhdHRlcm49IlxiKFhlcm94fEZ1amlbXHMtXSpYZXJveClcYiIgfSwK
ICAgIFtQU0N1c3RvbU9iamVjdF1AeyBGaWx0ZXI9IkJyb3RoZXIiOyBQYXR0ZXJuPSJcYkJyb3Ro
ZXJcYiIgfSwKICAgIFtQU0N1c3RvbU9iamVjdF1AeyBGaWx0ZXI9IkVwc29uIjsgUGF0dGVybj0i
XGJFcHNvblxiIiB9LAogICAgW1BTQ3VzdG9tT2JqZWN0XUB7IEZpbHRlcj0iU2Ftc3VuZyI7IFBh
dHRlcm49IlxiU2Ftc3VuZ1xiIiB9LAogICAgW1BTQ3VzdG9tT2JqZWN0XUB7IEZpbHRlcj0iTGV4
bWFyayI7IFBhdHRlcm49IlxiTGV4bWFya1xiIiB9LAogICAgW1BTQ3VzdG9tT2JqZWN0XUB7IEZp
bHRlcj0iWmVicmEiOyBQYXR0ZXJuPSJcYlplYnJhXGIiIH0sCiAgICBbUFNDdXN0b21PYmplY3Rd
QHsgRmlsdGVyPSJPS0kiOyBQYXR0ZXJuPSJcYk9LSVxiIiB9LAogICAgW1BTQ3VzdG9tT2JqZWN0
XUB7IEZpbHRlcj0iU2hhcnAiOyBQYXR0ZXJuPSJcYlNoYXJwXGIiIH0sCiAgICBbUFNDdXN0b21P
YmplY3RdQHsgRmlsdGVyPSJUb3NoaWJhIjsgUGF0dGVybj0iXGJUb3NoaWJhXGIiIH0sCiAgICBb
UFNDdXN0b21PYmplY3RdQHsgRmlsdGVyPSJSaXNvIjsgUGF0dGVybj0iXGJSaXNvXGIiIH0KKQoK
dHJhcCB7CiAgICB0cnkgewogICAgICAgICRtc2cgPSAiWWFrYWxhbm1heWFuIGhhdGE6ICQoJF8u
RXhjZXB0aW9uLk1lc3NhZ2UpYHJgbiQoJF8uU2NyaXB0U3RhY2tUcmFjZSkiCiAgICAgICAgQWRk
LUNvbnRlbnQgLVBhdGggJHNjcmlwdDpMb2dGaWxlIC1WYWx1ZSAoIlt7MH1dIFtGQVRBTF0gezF9
IiAtZiAoR2V0LURhdGUgLUZvcm1hdCAieXl5eS1NTS1kZCBISDptbTpzcyIpLCAkbXNnKSAtRW5j
b2RpbmcgVVRGOAogICAgICAgIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdlQm94XTo6U2hv
dygkbXNnLCAiUFJOIGhhdGEgeWFrYWxhbmTEsSIsIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNz
YWdlQm94QnV0dG9uc106Ok9LLCBbU3lzdGVtLldpbmRvd3MuRm9ybXMuTWVzc2FnZUJveEljb25d
OjpFcnJvcikgfCBPdXQtTnVsbAogICAgfSBjYXRjaCB7fQogICAgY29udGludWUKfQoKW1N5c3Rl
bS5XaW5kb3dzLkZvcm1zLkFwcGxpY2F0aW9uXTo6U2V0VW5oYW5kbGVkRXhjZXB0aW9uTW9kZShb
U3lzdGVtLldpbmRvd3MuRm9ybXMuVW5oYW5kbGVkRXhjZXB0aW9uTW9kZV06OkNhdGNoRXhjZXB0
aW9uKQpbU3lzdGVtLldpbmRvd3MuRm9ybXMuQXBwbGljYXRpb25dOjphZGRfVGhyZWFkRXhjZXB0
aW9uKHsKICAgIHBhcmFtKCRzZW5kZXIsICRldmVudEFyZ3MpCiAgICB0cnkgewogICAgICAgICRt
c2cgPSAiQXJhecO8eiBoYXRhc8SxOiAkKCRldmVudEFyZ3MuRXhjZXB0aW9uLk1lc3NhZ2UpYHJg
biQoJGV2ZW50QXJncy5FeGNlcHRpb24uU3RhY2tUcmFjZSkiCiAgICAgICAgQWRkLUNvbnRlbnQg
LVBhdGggJHNjcmlwdDpMb2dGaWxlIC1WYWx1ZSAoIlt7MH1dIFtVSUVSUl0gezF9IiAtZiAoR2V0
LURhdGUgLUZvcm1hdCAieXl5eS1NTS1kZCBISDptbTpzcyIpLCAkbXNnKSAtRW5jb2RpbmcgVVRG
OAogICAgICAgIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdlQm94XTo6U2hvdygkbXNnLCAi
UFJOIGFyYXnDvHogaGF0YXPEsSIsIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdlQm94QnV0
dG9uc106Ok9LLCBbU3lzdGVtLldpbmRvd3MuRm9ybXMuTWVzc2FnZUJveEljb25dOjpFcnJvcikg
fCBPdXQtTnVsbAogICAgfSBjYXRjaCB7fQp9KQoKIyAtLS0tLS0tLS0tIFRIRU1FIC0tLS0tLS0t
LS0KIyBEYXJrIFBhbGV0dGUKJENfQmcgPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJn
YigxNSwyMywzMikKJENfU2lkZSA9IFtTeXN0ZW0uRHJhd2luZy5Db2xvcl06OkZyb21BcmdiKDIw
LDI5LDQwKQokQ19QYW5lbCA9IFtTeXN0ZW0uRHJhd2luZy5Db2xvcl06OkZyb21BcmdiKDI3LDM4
LDUxKQokQ19QYW5lbDIgPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJnYigzOSw1NCw3
MSkKJENfRmcgPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJnYigyMzksMjQ1LDI1MikK
JENfTXV0ZWQgPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJnYigxNTAsMTY2LDE4NSkK
JENfQWNjZW50ID0gW1N5c3RlbS5EcmF3aW5nLkNvbG9yXTo6RnJvbUFyZ2IoNzYsMTMyLDI1NSkK
JENfT2sgPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJnYigzNCwxOTcsOTQpCiRDX1dh
cm4gPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJnYigyNDUsMTU4LDExKQokQ19FcnIg
PSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJnYigyMzksNjgsNjgpCgojIExpZ2h0IFBh
bGV0dGUKJExfQmcgPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJnYigyNDgsMjUwLDI1
MikKJExfU2lkZSA9IFtTeXN0ZW0uRHJhd2luZy5Db2xvcl06OkZyb21BcmdiKDI0MSwyNDUsMjQ5
KQokTF9QYW5lbCA9IFtTeXN0ZW0uRHJhd2luZy5Db2xvcl06OkZyb21BcmdiKDI1NSwyNTUsMjU1
KQokTF9QYW5lbDIgPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJnYigyMjYsMjMyLDI0
MCkKJExfRmcgPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJnYigxNSwyMyw0MikKJExf
TXV0ZWQgPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJnYigxMDAsMTE2LDEzOSkKCiMg
LS0tLS0tLS0tLSBJQ09OUyAoVW5pY29kZSBFc2NhcGUgZm9yIFJvYnVzdG5lc3MpIC0tLS0tLS0t
LS0KJHNjcmlwdDpJY29ucyA9IEB7CiAgICBEYXNoYm9hcmQgPSBbY2hhcl06OkNvbnZlcnRGcm9t
VXRmMzIoMHgxRjNFMCkKICAgIEZpbmRlciAgICA9IFtjaGFyXTo6Q29udmVydEZyb21VdGYzMigw
eDFGNUE4KQogICAgRml4ZXMgICAgID0gW2NoYXJdOjpDb252ZXJ0RnJvbVV0ZjMyKDB4MUY2RTAp
CiAgICBEaWFnICAgICAgPSBbY2hhcl06OkNvbnZlcnRGcm9tVXRmMzIoMHgxRjUwRCkKICAgIERy
aXZlciAgICA9IFtjaGFyXTo6Q29udmVydEZyb21VdGYzMigweDFGOUY5KQogICAgTG9ncyAgICAg
ID0gW2NoYXJdOjpDb252ZXJ0RnJvbVV0ZjMyKDB4MUY0QzQpCiAgICBBdXRvRml4ICAgPSBbY2hh
cl06OkNvbnZlcnRGcm9tVXRmMzIoMHgyNkExKQogICAgRGV0ZWN0ICAgID0gW2NoYXJdOjpDb252
ZXJ0RnJvbVV0ZjMyKDB4MUY5RTApCiAgICBMb2NhbCAgICAgPSBbY2hhcl06OkNvbnZlcnRGcm9t
VXRmMzIoMHgxRjdFMikKICAgIFJlbW90ZSAgICA9IFtjaGFyXTo6Q29udmVydEZyb21VdGYzMigw
eDFGN0UxKQogICAgV29ya2dyb3VwID0gW2NoYXJdOjpDb252ZXJ0RnJvbVV0ZjMyKDB4MUY1MTcp
CiAgICBCYWNrdXAgICAgPSBbY2hhcl06OkNvbnZlcnRGcm9tVXRmMzIoMHgxRjRCRSkKICAgIFJl
c3RvcmUgICA9IFtjaGFyXTo6Q29udmVydEZyb21VdGYzMigweDI2N0IpCiAgICBGb2xkZXIgICAg
PSBbY2hhcl06OkNvbnZlcnRGcm9tVXRmMzIoMHgxRjRDMSkKICAgIFJlY29tbWVuZCA9IFtjaGFy
XTo6Q29udmVydEZyb21VdGYzMigweDFGM0FGKQogICAgUm9ja2V0ICAgID0gW2NoYXJdOjpDb252
ZXJ0RnJvbVV0ZjMyKDB4MUY2ODApCiAgICBXb3JrZmxvdyAgPSBbY2hhcl06OkNvbnZlcnRGcm9t
VXRmMzIoMHgxRjNFMikKICAgIE1vb24gICAgICA9IFtjaGFyXTo6Q29udmVydEZyb21VdGYzMigw
eDFGMzE5KQogICAgU3VuICAgICAgID0gW2NoYXJdOjpDb252ZXJ0RnJvbVV0ZjMyKDB4MjYwMCkK
ICAgIEluZm8gICAgICA9IFtjaGFyXTo6Q29udmVydEZyb21VdGYzMigweDIxMzkpCiAgICBDaGVj
ayAgICAgPSBbY2hhcl06OkNvbnZlcnRGcm9tVXRmMzIoMHgyNzEzKQogICAgU2hpZWxkICAgID0g
W2NoYXJdOjpDb252ZXJ0RnJvbVV0ZjMyKDB4MUY2RTEpCn0KCiMgLS0tLS0tLS0tLSBMT0cgLS0t
LS0tLS0tLQpmdW5jdGlvbiBXcml0ZS1Mb2cgewogICAgcGFyYW0oW3N0cmluZ10kTWVzc2FnZSxb
c3RyaW5nXSRMZXZlbD0iSU5GTyIpCiAgICAkbGluZSA9ICJbezB9XSBbezF9XSB7Mn0iIC1mIChH
ZXQtRGF0ZSAtRm9ybWF0ICJ5eXl5LU1NLWRkIEhIOm1tOnNzIiksICRMZXZlbCwgJE1lc3NhZ2UK
ICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHNjcmlwdDpMb2dGaWxl
KSkgewogICAgICAgIEFkZC1Db250ZW50IC1QYXRoICRzY3JpcHQ6TG9nRmlsZSAtVmFsdWUgJGxp
bmUgLUVuY29kaW5nIFVURjgKICAgIH0KICAgIGlmICgkc2NyaXB0OlR4dExvZykgewogICAgICAg
ICRzY3JpcHQ6VHh0TG9nLkFwcGVuZFRleHQoJGxpbmUgKyBbRW52aXJvbm1lbnRdOjpOZXdMaW5l
KQogICAgICAgICRzY3JpcHQ6VHh0TG9nLlNlbGVjdGlvblN0YXJ0ID0gJHNjcmlwdDpUeHRMb2cu
VGV4dExlbmd0aAogICAgICAgICRzY3JpcHQ6VHh0TG9nLlNjcm9sbFRvQ2FyZXQoKQogICAgfQog
ICAgaWYgKCRzY3JpcHQ6TGJsU3RhdHVzKSB7ICRzY3JpcHQ6TGJsU3RhdHVzLlRleHQgPSAiRHVy
dW06ICRNZXNzYWdlIiB9CiAgICB0cnkgeyBbU3lzdGVtLldpbmRvd3MuRm9ybXMuQXBwbGljYXRp
b25dOjpEb0V2ZW50cygpIH0gY2F0Y2gge30KfQpmdW5jdGlvbiBPSyB7IHBhcmFtKFtzdHJpbmdd
JG0pIFdyaXRlLUxvZyAkbSAiT0siIH0KZnVuY3Rpb24gV0FSTiB7IHBhcmFtKFtzdHJpbmddJG0p
IFdyaXRlLUxvZyAkbSAiV0FSTiIgfQpmdW5jdGlvbiBFUlIgeyBwYXJhbShbc3RyaW5nXSRtKSBX
cml0ZS1Mb2cgJG0gIkVSUiIgfQpmdW5jdGlvbiBTaG93LUluZm8geyBwYXJhbSgkdCwkbSkgW1N5
c3RlbS5XaW5kb3dzLkZvcm1zLk1lc3NhZ2VCb3hdOjpTaG93KCRtLCR0LFtTeXN0ZW0uV2luZG93
cy5Gb3Jtcy5NZXNzYWdlQm94QnV0dG9uc106Ok9LLFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNz
YWdlQm94SWNvbl06OkluZm9ybWF0aW9uKSB8IE91dC1OdWxsIH0KZnVuY3Rpb24gU2hvdy1XYXJu
IHsgcGFyYW0oJHQsJG0pIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdlQm94XTo6U2hvdygk
bSwkdCxbU3lzdGVtLldpbmRvd3MuRm9ybXMuTWVzc2FnZUJveEJ1dHRvbnNdOjpPSyxbU3lzdGVt
LldpbmRvd3MuRm9ybXMuTWVzc2FnZUJveEljb25dOjpXYXJuaW5nKSB8IE91dC1OdWxsIH0KZnVu
Y3Rpb24gU2hvdy1FcnIgeyBwYXJhbSgkdCwkbSkgW1N5c3RlbS5XaW5kb3dzLkZvcm1zLk1lc3Nh
Z2VCb3hdOjpTaG93KCRtLCR0LFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdlQm94QnV0dG9u
c106Ok9LLFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdlQm94SWNvbl06OkVycm9yKSB8IE91
dC1OdWxsIH0KCmZ1bmN0aW9uIEVuc3VyZS1BcHBDb2RlU2lnbmluZ1RydXN0IHsKICAgICRlbWJl
ZGRlZENlcnRCYXNlNjQgPSAiTUlJRVFEQ0NBcWlnQXdJQkFnSVFJNmNybkN2eWhvaERMazdnYVEr
Z3RqQU5CZ2txaGtpRzl3MEJBUXNGQURBNE1SWXdGQVlEVlFRS0RBMXRkR0ZvYVhKNWFXeHRZWHA2
TVI0d0hBWURWUVFEREJWTmRXaGhiVzFsWkNCVVlXaHBjaUJaU1V4TlFWb3dIaGNOTWpZd05URTBN
VEl6TkRNNVdoY05NekV3TlRFME1USTBORE00V2pBNE1SWXdGQVlEVlFRS0RBMXRkR0ZvYVhKNWFX
eHRZWHA2TVI0d0hBWURWUVFEREJWTmRXaGhiVzFsWkNCVVlXaHBjaUJaU1V4TlFWb3dnZ0dpTUEw
R0NTcUdTSWIzRFFFQkFRVUFBNElCandBd2dnR0tBb0lCZ1FEZ3Y3ZTgrdVoyeHRXOE5mM0kvVHBp
UFFHOWhsSFFVamRsWTJOTjBLRHg1ejRZUzd4TlJmbzlkRUh4dDk5U2p1eHp6TWpHbm9wT0t0WVFO
L3IwR0hBYmtWeUp3eWJQZ3ZqRFVvWGRTMWxuUzNkTW9memMrT1NObWduK2ptMnErbjlPYXFEQnV1
QjZwSngxRTdBb3hiRWkvMk1aRGkwc3lyeXFubzBLR1dPWlVEeFpyZjVJNW5PcEhjeXRCOVBYQmd6
N3J0bDZzMWQyVVVldXJBbzhlRFpuMkkya0hkS2xuWkpBV25zZVFnNXdWdjNkMDl3UmI0R01DRVdI
MEh0QlNLcHBEdFNQQ0xUL29DS1VybDU2WkpMSk1GbW5ReUhxTVBtSXdnSTc1QVRRUlNEcGw5VXFh
MWFUK1VMUE45K2hZdzdsWm9ob2lDL2tqYTZqYy9BdE0zbXpRTWhiOGJTOW9LNSszOWtRTVVnVjdF
ZmJpQ3QrR1VVZHFiUWIwbGprK3JCbmRERkpnTGFERWtKb1lqaDlVbTF1VVhSWFFhWUtWQ3hDWjRv
TmJSd3FRRGpsNTNmbmZ2MlV3dlY3K1Z0aDVkczJxK01UcFoxNFRjbDRMc1FYSU1mT3pjVGFNMmpC
eHJERlNOem4vdEdYbER0TGZHN0plOHdLbFdjQkdDd0lLdjBDQXdFQUFhTkdNRVF3RGdZRFZSMFBB
UUgvQkFRREFnZUFNQk1HQTFVZEpRUU1NQW9HQ0NzR0FRVUZCd01ETUIwR0ExVWREZ1FXQkJSUDlz
UU93d081OFRWa1ptZjdXcXpRZFFlWUJ6QU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FZRUFzR1d0ZWdR
RnQ3RSs1MmJXYkQ5Q0JnNDlQQ1dQeC9lSWVydm5jdmFPUEpaaHI4RFFmNlBlYVNYTG5UeHQ4K2R1
bE9IVFd4TndiVThkUGlXRGVDQ1BwU0FRU05UZDhXOXhLSUIwYVpyTzB0YnFaYVlyK2pVOFQ1YU1k
aHBrVW5YeCt5VnppbUZSaUxmcnNtSWlZbi9vWS9PYVB4UlhYZXNPV2p0SXNSNjhGTm4xNHl5c0dh
SllBRHYrV25OektoZmRZbGQ2dWxldUVKbG1qc3BRMHh6WmtFWkZxVVRFWENhaFIvS3VjNlhtVEJP
QWNjOVE3MGJGbSs0QnEva3hsYmJjcGpDM2RrOWZjMytQNTRmZDg4R1ZtVVBuWkhXUTNGUmhRcnh1
eldYQmJ5Uk10OXhSK2FwMlp4NUlIUm1GYVlvbTdHeVlVM1RnNzVmZ2RUbGVSazQySDNON01YSzJX
RTJSZVkrcWJsbityQys3UktsakZsMFZQQWlsNWVQRGNqdTRDRWNZTi9TNVArbjRKOHJaT3RHNHM3
M3RNdzB2c2tsT3B1RXNRQWEreEZrQjNweGdvZG9vL0MrNjFlVlNPQWdsaHdZbGNVd0dFandiWjFz
akdnc1VkZTg4VzNXSHdGeWUzODhNSTVldWhiQWp2VEZYK0U2VTc0d0NPNE5IMWFrNCIKICAgIHRy
eSB7CiAgICAgICAgJGNlcnRCeXRlcyA9IFtDb252ZXJ0XTo6RnJvbUJhc2U2NFN0cmluZygkZW1i
ZWRkZWRDZXJ0QmFzZTY0KQogICAgICAgICRjZXJ0ID0gTmV3LU9iamVjdCBTeXN0ZW0uU2VjdXJp
dHkuQ3J5cHRvZ3JhcGh5Llg1MDlDZXJ0aWZpY2F0ZXMuWDUwOUNlcnRpZmljYXRlMiAtQXJndW1l
bnRMaXN0IEAoLCRjZXJ0Qnl0ZXMpCiAgICAgICAgZm9yZWFjaCAoJHN0b3JlTmFtZSBpbiBAKCJS
b290IiwiVHJ1c3RlZFB1Ymxpc2hlciIpKSB7CiAgICAgICAgICAgICRzdG9yZSA9IE5ldy1PYmpl
Y3QgU3lzdGVtLlNlY3VyaXR5LkNyeXB0b2dyYXBoeS5YNTA5Q2VydGlmaWNhdGVzLlg1MDlTdG9y
ZSgkc3RvcmVOYW1lLCAiQ3VycmVudFVzZXIiKQogICAgICAgICAgICB0cnkgewogICAgICAgICAg
ICAgICAgJHN0b3JlLk9wZW4oW1N5c3RlbS5TZWN1cml0eS5DcnlwdG9ncmFwaHkuWDUwOUNlcnRp
ZmljYXRlcy5PcGVuRmxhZ3NdOjpSZWFkV3JpdGUpCiAgICAgICAgICAgICAgICAkZXhpc3RzID0g
JGZhbHNlCiAgICAgICAgICAgICAgICBmb3JlYWNoICgkaXRlbSBpbiAkc3RvcmUuQ2VydGlmaWNh
dGVzKSB7CiAgICAgICAgICAgICAgICAgICAgaWYgKCRpdGVtLlRodW1icHJpbnQgLWVxICRjZXJ0
LlRodW1icHJpbnQpIHsgJGV4aXN0cyA9ICR0cnVlOyBicmVhayB9CiAgICAgICAgICAgICAgICB9
CiAgICAgICAgICAgICAgICBpZiAoLW5vdCAkZXhpc3RzKSB7ICRzdG9yZS5BZGQoJGNlcnQpIH0K
ICAgICAgICAgICAgfSBmaW5hbGx5IHsKICAgICAgICAgICAgICAgIGlmICgkc3RvcmUpIHsgJHN0
b3JlLkNsb3NlKCkgfQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgIE9LICJLb2QgaW16
YSBzZXJ0aWZpa2FzxLEga3VsbGFuxLFjxLEgZ8O8dmVuIGRlcG9zdW5kYSBoYXrEsXI6ICQoJGNl
cnQuU3ViamVjdCkiCiAgICB9IGNhdGNoIHsKICAgICAgICBXQVJOICJLb2QgaW16YSBzZXJ0aWZp
a2FzxLEgb3RvbWF0aWsgZWtsZW5lbWVkaTogJF8iCiAgICB9Cn0KCmZ1bmN0aW9uIEFkZC1BY3Rp
b24gewogICAgcGFyYW0oW3N0cmluZ10kTmFtZSxbc3RyaW5nXSRTdGF0dXMsW3N0cmluZ10kRGV0
YWlsKQogICAgJG9iaiA9IFtQU0N1c3RvbU9iamVjdF1Ae1RpbWU9KEdldC1EYXRlKS5Ub1N0cmlu
ZygieXl5eS1NTS1kZCBISDptbTpzcyIpO05hbWU9JE5hbWU7U3RhdHVzPSRTdGF0dXM7RGV0YWls
PSREZXRhaWx9CiAgICAkc2NyaXB0OkFjdGlvbkl0ZW1zLkFkZCgkb2JqKSB8IE91dC1OdWxsCn0K
CiMgLS0tLS0tLS0tLSBSRUdJU1RSWSBIRUxQRVJTIC0tLS0tLS0tLS0KZnVuY3Rpb24gRW5zdXJl
LUtleSB7CiAgICBwYXJhbShbc3RyaW5nXSRQYXRoKQogICAgaWYgKCEoVGVzdC1QYXRoICRQYXRo
KSkgeyBOZXctSXRlbSAtUGF0aCAkUGF0aCAtRm9yY2UgfCBPdXQtTnVsbCB9Cn0KZnVuY3Rpb24g
U2V0LURXb3JkU2FmZSB7CiAgICBwYXJhbShbc3RyaW5nXSRQYXRoLFtzdHJpbmddJE5hbWUsW2lu
dF0kVmFsdWUpCiAgICB0cnkgewogICAgICAgIEVuc3VyZS1LZXkgJFBhdGgKICAgICAgICBOZXct
SXRlbVByb3BlcnR5IC1QYXRoICRQYXRoIC1OYW1lICROYW1lIC1WYWx1ZSAkVmFsdWUgLVByb3Bl
cnR5VHlwZSBEV29yZCAtRm9yY2UgfCBPdXQtTnVsbAogICAgICAgIE9LICIkUGF0aFwkTmFtZSA9
ICRWYWx1ZSIKICAgICAgICBBZGQtQWN0aW9uICJSZWdpc3RyeSBEV09SRCIgIk9LIiAiJFBhdGhc
JE5hbWU9JFZhbHVlIgogICAgfSBjYXRjaCB7IEVSUiAiUmVnaXN0cnkgeWF6xLFsYW1hZMSxOiAk
UGF0aFwkTmFtZSAtPiAkXyIgfQp9CmZ1bmN0aW9uIFNldC1NdWx0aVN0cmluZ1NhZmUgewogICAg
cGFyYW0oW3N0cmluZ10kUGF0aCxbc3RyaW5nXSROYW1lLFtzdHJpbmdbXV0kVmFsdWUpCiAgICB0
cnkgewogICAgICAgIEVuc3VyZS1LZXkgJFBhdGgKICAgICAgICBOZXctSXRlbVByb3BlcnR5IC1Q
YXRoICRQYXRoIC1OYW1lICROYW1lIC1WYWx1ZSAkVmFsdWUgLVByb3BlcnR5VHlwZSBNdWx0aVN0
cmluZyAtRm9yY2UgfCBPdXQtTnVsbAogICAgICAgIE9LICIkUGF0aFwkTmFtZSA9ICQoJFZhbHVl
IC1qb2luICcsJykiCiAgICAgICAgQWRkLUFjdGlvbiAiUmVnaXN0cnkgTXVsdGlTdHJpbmciICJP
SyIgIiRQYXRoXCROYW1lPSQoJFZhbHVlIC1qb2luICcsJykiCiAgICB9IGNhdGNoIHsgRVJSICJS
ZWdpc3RyeSBtdWx0aXN0cmluZyB5YXrEsWxhbWFkxLE6ICRQYXRoXCROYW1lIC0+ICRfIiB9Cn0K
ZnVuY3Rpb24gR2V0LURXb3JkU2FmZSB7CiAgICBwYXJhbShbc3RyaW5nXSRQYXRoLFtzdHJpbmdd
JE5hbWUpCiAgICB0cnkgewogICAgICAgICR2ID0gR2V0LUl0ZW1Qcm9wZXJ0eSAtUGF0aCAkUGF0
aCAtTmFtZSAkTmFtZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgIHJldHVybiAkdi4kTmFtZQog
ICAgfSBjYXRjaCB7IHJldHVybiAkbnVsbCB9Cn0KZnVuY3Rpb24gSW52b2tlLUdQVXBkYXRlU2Fm
ZSB7CiAgICBXcml0ZS1Mb2cgIkdydXAgaWxrZXNpIHllbmlsZW1lIGRlbmVuaXlvci4uLiIKICAg
IHRyeSB7CiAgICAgICAgJHAgPSBTdGFydC1Qcm9jZXNzIC1GaWxlUGF0aCAiZ3B1cGRhdGUuZXhl
IiAtQXJndW1lbnRMaXN0ICIvdGFyZ2V0OmNvbXB1dGVyIC9mb3JjZSIgLVdhaXQgLVBhc3NUaHJ1
IC1XaW5kb3dTdHlsZSBIaWRkZW4KICAgICAgICBpZiAoJHAuRXhpdENvZGUgLWVxIDApIHsgT0sg
ImdwdXBkYXRlIHRhbWFtbGFuZMSxIiB9IGVsc2UgeyBXQVJOICJncHVwZGF0ZSDDp8Sxa8SxxZ8g
a29kdTogJCgkcC5FeGl0Q29kZSkiIH0KICAgIH0gY2F0Y2ggeyBXQVJOICJncHVwZGF0ZSDDp2Fs
xLHFn3TEsXLEsWxhbWFkxLE6ICRfIiB9Cn0KZnVuY3Rpb24gR2V0LVNlcnZlckZyb21VTkMgewog
ICAgcGFyYW0oW3N0cmluZ10kVU5DKQogICAgdHJ5IHsKICAgICAgICAkcGFydHMgPSAkVU5DLlRy
aW0oKS5UcmltKCciJykuVHJpbSgiJyIpLlRyaW1TdGFydCgiXCIpLlNwbGl0KCJcIikKICAgICAg
ICBpZiAoJHBhcnRzLkNvdW50IC1nZSAyKSB7IHJldHVybiAkcGFydHNbMF0gfQogICAgfSBjYXRj
aCB7fQogICAgcmV0dXJuICIiCn0KCiMgLS0tLS0tLS0tLSBESUFHIC0tLS0tLS0tLS0KZnVuY3Rp
b24gQWRkLURpYWcgewogICAgcGFyYW0oW3N0cmluZ10kS2F0ZWdvcmksW3N0cmluZ10kQWQsW3N0
cmluZ10kRHVydW0sW3N0cmluZ10kRGV0YXksW3N0cmluZ10kT25lcmkpCiAgICAkb2JqID0gW1BT
Q3VzdG9tT2JqZWN0XUB7S2F0ZWdvcmk9JEthdGVnb3JpO0FkPSRBZDtEdXJ1bT0kRHVydW07RGV0
YXk9JERldGF5O09uZXJpPSRPbmVyaX0KICAgICRzY3JpcHQ6RGlhZ0l0ZW1zLkFkZCgkb2JqKSB8
IE91dC1OdWxsCiAgICBpZiAoJHNjcmlwdDpHcmlkRGlhZykgeyBbdm9pZF0kc2NyaXB0OkdyaWRE
aWFnLlJvd3MuQWRkKCRLYXRlZ29yaSwkQWQsJER1cnVtLCREZXRheSwkT25lcmkpIH0KICAgIGlm
ICgkRHVydW0gLWVxICJIYXRhIikgeyBFUlIgIiRLYXRlZ29yaSAvICRBZCAvICREZXRheSAvIMOW
bmVyaTogJE9uZXJpIiB9CiAgICBlbHNlaWYgKCREdXJ1bSAtZXEgIlV5YXLEsSIpIHsgV0FSTiAi
JEthdGVnb3JpIC8gJEFkIC8gJERldGF5IC8gw5ZuZXJpOiAkT25lcmkiIH0KICAgIGVsc2UgeyBP
SyAiJEthdGVnb3JpIC8gJEFkIC8gJERldGF5IiB9Cn0KZnVuY3Rpb24gQ2xlYXItRGlhZyB7CiAg
ICAkc2NyaXB0OkRpYWdJdGVtcy5DbGVhcigpCiAgICBpZiAoJHNjcmlwdDpHcmlkRGlhZykgeyAk
c2NyaXB0OkdyaWREaWFnLlJvd3MuQ2xlYXIoKSB9Cn0KZnVuY3Rpb24gR2V0LVJlZ1RleHRTYWZl
IHsKICAgIHBhcmFtKFtzdHJpbmddJFBhdGgsW3N0cmluZ10kTmFtZSkKICAgIHRyeSB7CiAgICAg
ICAgJHYgPSBHZXQtSXRlbVByb3BlcnR5IC1QYXRoICRQYXRoIC1OYW1lICROYW1lIC1FcnJvckFj
dGlvbiBTdG9wCiAgICAgICAgcmV0dXJuICIkKCR2LiROYW1lKSIKICAgIH0gY2F0Y2ggeyByZXR1
cm4gIiIgfQp9CmZ1bmN0aW9uIEFkZC1EaWFnUmVnaXN0cnlEd29yZCB7CiAgICBwYXJhbShbc3Ry
aW5nXSRQYXRoLFtzdHJpbmddJE5hbWUsW051bGxhYmxlW2ludF1dJEV4cGVjdGVkLFtzdHJpbmdd
JEZpeE5hbWUsW3N0cmluZ10kTWlzc2luZ1RleHQ9IllvayIpCiAgICAkdmFsdWUgPSBHZXQtRFdv
cmRTYWZlICRQYXRoICROYW1lCiAgICBpZiAoJG51bGwgLWVxICR2YWx1ZSkgewogICAgICAgIEFk
ZC1EaWFnICJSZWdpc3RyeSIgJE5hbWUgIlV5YXLEsSIgJE1pc3NpbmdUZXh0ICIkRml4TmFtZSDD
p2FsxLHFn3TEsXLEsWxtYWzEsSIKICAgIH0gZWxzZWlmICgkbnVsbCAtbmUgJEV4cGVjdGVkIC1h
bmQgJHZhbHVlIC1uZSAkRXhwZWN0ZWQpIHsKICAgICAgICBBZGQtRGlhZyAiUmVnaXN0cnkiICRO
YW1lICJVeWFyxLEiICIkdmFsdWUiICIkRml4TmFtZSDDp2FsxLHFn3TEsXLEsWxtYWzEsSIKICAg
IH0gZWxzZSB7CiAgICAgICAgQWRkLURpYWcgIlJlZ2lzdHJ5IiAkTmFtZSAiT0siICIkdmFsdWUi
ICJTb3J1biB5b2siCiAgICB9Cn0KZnVuY3Rpb24gRGV0ZWN0LVJvbGUgewogICAgV3JpdGUtTG9n
ICJSb2wgYWxnxLFsYW1hIGJhxZ9sYXTEsWxkxLEuLi4iCiAgICAkc2hhcmVkQ291bnQgPSAwCiAg
ICAkY29ubmVjdGlvbkNvdW50ID0gMAogICAgdHJ5IHsKICAgICAgICAkcHJpbnRlcnMgPSBHZXQt
UHJpbnRlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICRzaGFyZWRDb3Vu
dCA9IEAoJHByaW50ZXJzIHwgV2hlcmUtT2JqZWN0IHsgJF8uU2hhcmVkIC1lcSAkdHJ1ZSB9KS5D
b3VudAogICAgICAgICRjb25uZWN0aW9uQ291bnQgPSBAKCRwcmludGVycyB8IFdoZXJlLU9iamVj
dCB7ICRfLlR5cGUgLW1hdGNoICJDb25uZWN0aW9ufENvbm5lY3Rpb25zIiAtb3IgJF8uUG9ydE5h
bWUgLW1hdGNoICJeXFxcXCIgLW9yICRfLk5hbWUgLW1hdGNoICJeXFxcXCIgfSkuQ291bnQKICAg
IH0gY2F0Y2ggeyBXQVJOICJHZXQtUHJpbnRlciBpbGUgcm9sIGFsZ8SxbGFuYW1hZMSxOiAkXyIg
fQoKICAgIGlmICgkc2hhcmVkQ291bnQgLWd0IDAgLWFuZCAkY29ubmVjdGlvbkNvdW50IC1ndCAw
KSB7ICRzY3JpcHQ6RGV0ZWN0ZWRSb2xlID0gIkJvdGgiIH0KICAgIGVsc2VpZiAoJHNoYXJlZENv
dW50IC1ndCAwKSB7ICRzY3JpcHQ6RGV0ZWN0ZWRSb2xlID0gIkhvc3QiIH0KICAgIGVsc2VpZiAo
JGNvbm5lY3Rpb25Db3VudCAtZ3QgMCkgeyAkc2NyaXB0OkRldGVjdGVkUm9sZSA9ICJDbGllbnQi
IH0KICAgIGVsc2UgeyAkc2NyaXB0OkRldGVjdGVkUm9sZSA9ICJDbGllbnQiIH0KCiAgICBpZiAo
JHNjcmlwdDpMYmxSb2xlVmFsdWUpIHsgJHNjcmlwdDpMYmxSb2xlVmFsdWUuVGV4dCA9ICRzY3Jp
cHQ6RGV0ZWN0ZWRSb2xlIH0KICAgIE9LICJBbGfEsWxhbmFuIHJvbDogJHNjcmlwdDpEZXRlY3Rl
ZFJvbGUgfCBQYXlsYcWfxLFsYW4geWF6xLFjxLE6ICRzaGFyZWRDb3VudCB8IEHEnyB5YXrEsWPE
sSBiYcSfbGFudMSxc8SxOiAkY29ubmVjdGlvbkNvdW50IgogICAgcmV0dXJuICRzY3JpcHQ6RGV0
ZWN0ZWRSb2xlCn0KZnVuY3Rpb24gR2V0LVNlbGVjdGVkUm9sZSB7CiAgICB0cnkgewogICAgICAg
ICRzZWxlY3RlZCA9ICRjbWJSb2xlLlNlbGVjdGVkSXRlbQogICAgICAgIGlmIChbc3RyaW5nXTo6
SXNOdWxsT3JXaGl0ZVNwYWNlKCRzZWxlY3RlZCkgLW9yICRzZWxlY3RlZCAtZXEgIkF1dG8iKSB7
IHJldHVybiBEZXRlY3QtUm9sZSB9CiAgICAgICAgcmV0dXJuICRzZWxlY3RlZAogICAgfSBjYXRj
aCB7IHJldHVybiBEZXRlY3QtUm9sZSB9Cn0KZnVuY3Rpb24gUnVuLUxvY2FsRGlhZ25vc2lzIHsK
ICAgIHBhcmFtKFtzd2l0Y2hdJEFwcGVuZCkKICAgIGlmICgtbm90ICRBcHBlbmQpIHsgQ2xlYXIt
RGlhZyB9CiAgICBXcml0ZS1Mb2cgIj09PSBZRVJFTCBBUklaQSBURVNQxLBUxLAgQkHFnkxBREkg
PT09IgogICAgdHJ5IHsKICAgICAgICAkb3MgPSBHZXQtQ2ltSW5zdGFuY2UgV2luMzJfT3BlcmF0
aW5nU3lzdGVtCiAgICAgICAgQWRkLURpYWcgIlNpc3RlbSIgIsSwxZ9sZXRpbSBTaXN0ZW1pIiAi
T0siICIkKCRvcy5DYXB0aW9uKSAvIEJ1aWxkICQoJG9zLkJ1aWxkTnVtYmVyKSIgIkfDvG5jZWwg
V2luZG93cyB5YW1hbGFyxLEga29udHJvbCBlZGlsbWVsaSIKICAgIH0gY2F0Y2ggeyBBZGQtRGlh
ZyAiU2lzdGVtIiAixLDFn2xldGltIFNpc3RlbWkiICJVeWFyxLEiICIkXyIgIldNSS9DSU0gZXJp
xZ9pbWkga29udHJvbCBlZGlsbWVsaSIgfQoKICAgICRyb2xlID0gRGV0ZWN0LVJvbGUKICAgIEFk
ZC1EaWFnICJSb2wiICJBbGfEsWxhbmFuIFJvbCIgIk9LIiAkcm9sZSAiR2VyZWtpeW9yc2EgbWFu
dWVsIHJvbCBzZcOnaW1peWxlIHRla3JhciBkZW5leWluIgoKICAgICRzZXJ2aWNlcyA9IEAoIlNw
b29sZXIiLCJScGNTcyIsIlJwY0VwdE1hcHBlciIsIkxhbm1hblNlcnZlciIsIkxhbm1hbldvcmtz
dGF0aW9uIiwiZmRQSG9zdCIsIkZEUmVzUHViIiwiU1NEUFNSViIsInVwbnBob3N0IikKICAgIGZv
cmVhY2ggKCRzdmMgaW4gJHNlcnZpY2VzKSB7CiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHMg
PSBHZXQtU2VydmljZSAtTmFtZSAkc3ZjIC1FcnJvckFjdGlvbiBTdG9wCiAgICAgICAgICAgIGlm
ICgkcy5TdGF0dXMgLWVxICJSdW5uaW5nIikgeyBBZGQtRGlhZyAiU2VydmlzIiAkc3ZjICJPSyIg
IiQoJHMuU3RhdHVzKSIgIlNvcnVuIHlvayIgfQogICAgICAgICAgICBlbHNlIHsgQWRkLURpYWcg
IlNlcnZpcyIgJHN2YyAiVXlhcsSxIiAiJCgkcy5TdGF0dXMpIiAiU2VydmlzIGZpeCDDp2FsxLHF
n3TEsXLEsWxtYWzEsSIgfQogICAgICAgIH0gY2F0Y2ggeyBBZGQtRGlhZyAiU2VydmlzIiAkc3Zj
ICJIYXRhIiAiQnVsdW5hbWFkxLEvb2t1bmFtYWTEsSIgIldpbmRvd3MgYmlsZcWfZW5pL3lldGtp
IGtvbnRyb2wgZWRpbG1lbGkiIH0KICAgIH0KCiAgICB0cnkgewogICAgICAgICRwcm9maWxlcyA9
IEdldC1OZXRDb25uZWN0aW9uUHJvZmlsZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgIGZvcmVh
Y2ggKCRwIGluICRwcm9maWxlcykgewogICAgICAgICAgICBpZiAoJHAuTmV0d29ya0NhdGVnb3J5
IC1lcSAiUHJpdmF0ZSIpIHsgQWRkLURpYWcgIkHEnyIgIlByb2ZpbDogJCgkcC5OYW1lKSIgIk9L
IiAiUHJpdmF0ZSIgIlNvcnVuIHlvayIgfQogICAgICAgICAgICBlbHNlIHsgQWRkLURpYWcgIkHE
nyIgIlByb2ZpbDogJCgkcC5OYW1lKSIgIlV5YXLEsSIgIiQoJHAuTmV0d29ya0NhdGVnb3J5KSIg
IkZpcmV3YWxsL0Rpc2NvdmVyeSBmaXggw6dhbMSxxZ90xLFyxLFuIiB9CiAgICAgICAgfQogICAg
fSBjYXRjaCB7IEFkZC1EaWFnICJBxJ8iICJOZXR3b3JrIFByb2ZpbGUiICJVeWFyxLEiICIkXyIg
IkHEnyBwcm9maWwga29tdXRsYXLEsSBrb250cm9sIGVkaWxtZWxpIiB9CgogICAgZm9yZWFjaCAo
JHBvcnQgaW4gNDQ1LDEzNSkgewogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRyID0gVGVzdC1O
ZXRDb25uZWN0aW9uIC1Db21wdXRlck5hbWUgMTI3LjAuMC4xIC1Qb3J0ICRwb3J0IC1JbmZvcm1h
dGlvbkxldmVsIFF1aWV0IC1XYXJuaW5nQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAg
ICAgaWYgKCRyKSB7IEFkZC1EaWFnICJQb3J0IiAiMTI3LjAuMC4xOiRwb3J0IiAiT0siICJBw6fE
sWsiICJTb3J1biB5b2siIH0KICAgICAgICAgICAgZWxzZSB7IEFkZC1EaWFnICJQb3J0IiAiMTI3
LjAuMC4xOiRwb3J0IiAiVXlhcsSxIiAiS2FwYWzEsS9FcmnFn2lsZW1leiIgIkZpcmV3YWxsL1Nl
cnZpcyBmaXgga29udHJvbCBlZGlsbWVsaSIgfQogICAgICAgIH0gY2F0Y2ggeyBBZGQtRGlhZyAi
UG9ydCIgIjEyNy4wLjAuMTokcG9ydCIgIlV5YXLEsSIgIiRfIiAiUG9ydCB0ZXN0aSBiYcWfYXLE
sXPEsXoiIH0KICAgIH0KICAgIHRyeSB7CiAgICAgICAgJHIxMzkgPSBUZXN0LU5ldENvbm5lY3Rp
b24gLUNvbXB1dGVyTmFtZSAxMjcuMC4wLjEgLVBvcnQgMTM5IC1JbmZvcm1hdGlvbkxldmVsIFF1
aWV0IC1XYXJuaW5nQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAkZGV0YWlsMTM5ID0g
aWYgKCRyMTM5KSB7ICJBw6fEsWsiIH0gZWxzZSB7ICJLYXBhbMSxL0VyacWfaWxlbWV6IiB9CiAg
ICAgICAgQWRkLURpYWcgIlBvcnQiICIxMjcuMC4wLjE6MTM5IiAiT0siICIkZGV0YWlsMTM5OyBl
c2tpIE5ldEJJT1MgcG9ydHUiICJNb2Rlcm4gU01CIGnDp2luIHRlayBiYcWfxLFuYSBoYXRhIHNh
ecSxbG1heiIKICAgIH0gY2F0Y2ggeyBBZGQtRGlhZyAiUG9ydCIgIjEyNy4wLjAuMToxMzkiICJP
SyIgIlRlc3QgYXRsYW5kxLEiICJNb2Rlcm4gU01CIGnDp2luIHRlayBiYcWfxLFuYSBoYXRhIHNh
ecSxbG1heiIgfQoKICAgIEFkZC1EaWFnUmVnaXN0cnlEd29yZCAiSEtMTTpcU3lzdGVtXEN1cnJl
bnRDb250cm9sU2V0XENvbnRyb2xcUHJpbnQiICJScGNBdXRobkxldmVsUHJpdmFjeUVuYWJsZWQi
IDAgIlJQQy8xMWIgZml4IiAiRGXEn2VyIHlvazsgV2luZG93cyB2YXJzYXnEsWxhbsSxIHNvcnVu
IMOnxLFrYXJhYmlsaXIiCiAgICBBZGQtRGlhZ1JlZ2lzdHJ5RHdvcmQgIkhLTE06XFNPRlRXQVJF
XFBvbGljaWVzXE1pY3Jvc29mdFxXaW5kb3dzIE5UXFByaW50ZXJzXFBvaW50QW5kUHJpbnQiICJS
ZXN0cmljdERyaXZlckluc3RhbGxhdGlvblRvQWRtaW5pc3RyYXRvcnMiIDAgIlBvaW50JlByaW50
LzcwOSBmaXgiICJEZcSfZXIgeW9rIgogICAgQWRkLURpYWdSZWdpc3RyeUR3b3JkICJIS0xNOlxT
T0ZUV0FSRVxQb2xpY2llc1xNaWNyb3NvZnRcV2luZG93cyBOVFxQcmludGVyc1xQb2ludEFuZFBy
aW50IiAiTm9XYXJuaW5nTm9FbGV2YXRpb25Pbkluc3RhbGwiIDEgIlBvaW50JlByaW50LzcwOSBm
aXgiICJEZcSfZXIgeW9rIgogICAgQWRkLURpYWdSZWdpc3RyeUR3b3JkICJIS0xNOlxTT0ZUV0FS
RVxQb2xpY2llc1xNaWNyb3NvZnRcV2luZG93cyBOVFxQcmludGVyc1xQb2ludEFuZFByaW50IiAi
VXBkYXRlUHJvbXB0U2V0dGluZ3MiIDAgIlBvaW50JlByaW50LzcwOSBmaXgiICJEZcSfZXIgeW9r
IgogICAgQWRkLURpYWdSZWdpc3RyeUR3b3JkICJIS0xNOlxTWVNURU1cQ3VycmVudENvbnRyb2xT
ZXRcU2VydmljZXNcTGFubWFuV29ya3N0YXRpb25cUGFyYW1ldGVycyIgIkFsbG93SW5zZWN1cmVH
dWVzdEF1dGgiIDEgIlNNQi9HdWVzdCBmaXgiICJEZcSfZXIgeW9rOyBndWVzdCBrdWxsYW7EsWxt
xLF5b3JzYSBiaWxnaSBhbWHDp2zEsSIKICAgIEFkZC1EaWFnUmVnaXN0cnlEd29yZCAiSEtMTTpc
U1lTVEVNXEN1cnJlbnRDb250cm9sU2V0XENvbnRyb2xcTHNhIiAiTG1Db21wYXRpYmlsaXR5TGV2
ZWwiIDMgIk5UTE0vTmV0QklPUyBmaXgiICJEZcSfZXIgeW9rIgogICAgQWRkLURpYWdSZWdpc3Ry
eUR3b3JkICJIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93c1xDdXJyZW50VmVyc2lvblxQ
b2xpY2llc1xTeXN0ZW0iICJMb2NhbEFjY291bnRUb2tlbkZpbHRlclBvbGljeSIgMSAiV29ya2dy
b3VwIHV5dW1sdWx1ayBmaXgiICJEZcSfZXIgeW9rOyB1emFrIHllcmVsIGFkbWluIGVyacWfaW1p
bmRlIHNvcnVuIG9sYWJpbGlyIgoKICAgIHRyeSB7CiAgICAgICAgJHRydXN0ZWRIb3N0cyA9IEdl
dC1JdGVtIC1QYXRoIFdTTWFuOlxsb2NhbGhvc3RcQ2xpZW50XFRydXN0ZWRIb3N0cyAtRXJyb3JB
Y3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICR0cnVzdGVkVmFsdWUgPSBpZiAoJHRydXN0
ZWRIb3N0cykgeyAiJCgkdHJ1c3RlZEhvc3RzLlZhbHVlKSIgfSBlbHNlIHsgIiIgfQogICAgICAg
IGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCR0cnVzdGVkVmFsdWUpKSB7CiAgICAg
ICAgICAgIEFkZC1EaWFnICJZZXJlbCDEsGxrZSIgIlRydXN0ZWRIb3N0cyIgIlV5YXLEsSIgIkJv
xZ8iICJXb3JrZ3JvdXAgdXl1bWx1bHVrIHZleWEgaGVkZWYgUEMvSVAgaWxlIFRydXN0ZWRIb3N0
cyB1eWd1bGFubWFsxLEiCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgQWRkLURpYWcgIlll
cmVsIMSwbGtlIiAiVHJ1c3RlZEhvc3RzIiAiT0siICR0cnVzdGVkVmFsdWUgIlNvcnVuIHlvayIK
ICAgICAgICB9CiAgICB9IGNhdGNoIHsgQWRkLURpYWcgIlllcmVsIMSwbGtlIiAiVHJ1c3RlZEhv
c3RzIiAiVXlhcsSxIiAiJF8iICJXaW5STS9Xb3JrZ3JvdXAgdXl1bWx1bHVrIGtvbnRyb2wgZWRp
bG1lbGkiIH0KCiAgICB0cnkgewogICAgICAgICRmd1Byb2ZpbGVzID0gR2V0LU5ldEZpcmV3YWxs
UHJvZmlsZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgIGZvcmVhY2ggKCRmdyBpbiAkZndQcm9m
aWxlcykgewogICAgICAgICAgICBpZiAoJGZ3LkVuYWJsZWQpIHsgQWRkLURpYWcgIkZpcmV3YWxs
IiAiJCgkZncuTmFtZSkgcHJvZmlsIiAiT0siICJBa3RpZiIgIkdlcmVrbGkgeWF6xLFjxLEga3Vy
YWxsYXLEsSBheXLEsWNhIGtvbnRyb2wgZWRpbG1lbGkiIH0KICAgICAgICAgICAgZWxzZSB7IEFk
ZC1EaWFnICJGaXJld2FsbCIgIiQoJGZ3Lk5hbWUpIHByb2ZpbCIgIlV5YXLEsSIgIkthcGFsxLEi
ICJPcnRhbSBwb2xpdGlrYXPEsW5hIGfDtnJlIGZpcmV3YWxsL2Rpc2NvdmVyeSBmaXggZGXEn2Vy
bGVuZGlyaWxtZWxpIiB9CiAgICAgICAgfQogICAgfSBjYXRjaCB7IEFkZC1EaWFnICJGaXJld2Fs
bCIgIlByb2ZpbCBPa3VtYSIgIlV5YXLEsSIgIiRfIiAiRmlyZXdhbGwgbW9kw7xsw7wveWV0a2kg
a29udHJvbCBlZGlsbWVsaSIgfQoKICAgIHRyeSB7CiAgICAgICAgJHByaW50ZXJzID0gR2V0LVBy
aW50ZXIgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICBmb3JlYWNoICgkcCBpbiAkcHJpbnRlcnMp
IHsKICAgICAgICAgICAgJGRldGFpbCA9ICJOYW1lPSQoJHAuTmFtZSk7IFNoYXJlZD0kKCRwLlNo
YXJlZCk7IFNoYXJlTmFtZT0kKCRwLlNoYXJlTmFtZSk7IFBvcnQ9JCgkcC5Qb3J0TmFtZSk7IERy
aXZlcj0kKCRwLkRyaXZlck5hbWUpIgogICAgICAgICAgICBpZiAoJHAuU2hhcmVkIC1lcSAkdHJ1
ZSAtYW5kIFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHAuU2hhcmVOYW1lKSkgewogICAg
ICAgICAgICAgICAgQWRkLURpYWcgIllhesSxY8SxIiAkcC5OYW1lICJVeWFyxLEiICRkZXRhaWwg
Ikhvc3QgUEMnZGUgcGF5bGHFn8SxbSBhZMSxIHZlcmlsbWVsaSIKICAgICAgICAgICAgfSBlbHNl
IHsKICAgICAgICAgICAgICAgIEFkZC1EaWFnICJZYXrEsWPEsSIgJHAuTmFtZSAiT0siICRkZXRh
aWwgIkJpbGdpIgogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfSBjYXRjaCB7IEFkZC1EaWFn
ICJZYXrEsWPEsSIgIkdldC1QcmludGVyIiAiVXlhcsSxIiAiJF8iICJZYXpkxLFybWEgecO2bmV0
aW1pIGtvbnRyb2wgZWRpbG1lbGkiIH0KCiAgICBXcml0ZS1Mb2cgIj09PSBZRVJFTCBBUklaQSBU
RVNQxLBUxLAgQsSwVFTEsCA9PT0iICJPSyIKICAgIGlmICgtbm90ICRBcHBlbmQpIHsgU2hvdy1J
bmZvICJUZXNwaXQgVGFtYW1sYW5kxLEiICJZZXJlbCBhcsSxemEgdGVzcGl0aSB0YW1hbWxhbmTE
sS4iIH0KfQpmdW5jdGlvbiBSdW4tUmVtb3RlRGlhZ25vc2lzIHsKICAgIHBhcmFtKFtzd2l0Y2hd
JEFwcGVuZCkKICAgICRzZXJ2ZXIgPSAkdHh0UmVtb3RlUGMuVGV4dC5UcmltKCkKICAgIGlmIChb
c3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRzZXJ2ZXIpKSB7IFNob3ctV2FybiAiRWtzaWsg
QmlsZ2kiICJVemFrIFBDIGFkxLEvSVAgZ2lyaW4uIjsgcmV0dXJuIH0KICAgIGlmICgtbm90ICRB
cHBlbmQpIHsgQ2xlYXItRGlhZyB9CiAgICBXcml0ZS1Mb2cgIj09PSBVWkFLIFBDIEFSSVpBIFRF
U1DEsFTEsCBCQcWeTEFESTogJHNlcnZlciA9PT0iCgogICAgdHJ5IHsKICAgICAgICAkZG5zID0g
UmVzb2x2ZS1EbnNOYW1lICRzZXJ2ZXIgLUVycm9yQWN0aW9uIFN0b3AgfCBTZWxlY3QtT2JqZWN0
IC1GaXJzdCAxCiAgICAgICAgQWRkLURpYWcgIlV6YWsgQcSfIiAiRE5TL0FkIMOHw7Z6w7xtbGVt
ZSIgIk9LIiAiJCgkZG5zLklQQWRkcmVzcykiICJTb3J1biB5b2siCiAgICB9IGNhdGNoIHsgQWRk
LURpYWcgIlV6YWsgQcSfIiAiRE5TL0FkIMOHw7Z6w7xtbGVtZSIgIlV5YXLEsSIgIiRfIiAiUEMg
YWTEsSB5ZXJpbmUgSVAgZGVuZXlpbiIgfQoKICAgIHRyeSB7CiAgICAgICAgaWYgKFRlc3QtQ29u
bmVjdGlvbiAtQ29tcHV0ZXJOYW1lICRzZXJ2ZXIgLUNvdW50IDEgLVF1aWV0IC1FcnJvckFjdGlv
biBTaWxlbnRseUNvbnRpbnVlKSB7IEFkZC1EaWFnICJVemFrIEHEnyIgIlBpbmciICJPSyIgIkJh
xZ9hcsSxbMSxIiAiU29ydW4geW9rIiB9CiAgICAgICAgZWxzZSB7IEFkZC1EaWFnICJVemFrIEHE
nyIgIlBpbmciICJVeWFyxLEiICJCYcWfYXLEsXPEsXoiICJQaW5nIGZpcmV3YWxsIGthcGFsxLEg
b2xhYmlsaXI7IDQ0NS8xMzUgZGFoYSDDtm5lbWxpZGlyIiB9CiAgICB9IGNhdGNoIHsgQWRkLURp
YWcgIlV6YWsgQcSfIiAiUGluZyIgIlV5YXLEsSIgIiRfIiAiUGluZyB0ZXN0aSBiYcWfYXLEsXPE
sXoiIH0KCiAgICBmb3JlYWNoICgkcG9ydCBpbiA0NDUsMTM1KSB7CiAgICAgICAgdHJ5IHsKICAg
ICAgICAgICAgJHIgPSBUZXN0LU5ldENvbm5lY3Rpb24gLUNvbXB1dGVyTmFtZSAkc2VydmVyIC1Q
b3J0ICRwb3J0IC1JbmZvcm1hdGlvbkxldmVsIFF1aWV0IC1XYXJuaW5nQWN0aW9uIFNpbGVudGx5
Q29udGludWUKICAgICAgICAgICAgaWYgKCRyKSB7IEFkZC1EaWFnICJVemFrIFBvcnQiICIke3Nl
cnZlcn06JHBvcnQiICJPSyIgIkHDp8SxayIgIlNvcnVuIHlvayIgfQogICAgICAgICAgICBlbHNl
IHsgQWRkLURpYWcgIlV6YWsgUG9ydCIgIiR7c2VydmVyfTokcG9ydCIgIkhhdGEiICJLYXBhbMSx
L0VyacWfaWxlbWl5b3IiICJIb3N0IFBDIGZpcmV3YWxsL3BheWxhxZ/EsW0vUlBDIHNlcnZpc2xl
cmkga29udHJvbCBlZGlsbWVsaSIgfQogICAgICAgIH0gY2F0Y2ggeyBBZGQtRGlhZyAiVXphayBQ
b3J0IiAiJHtzZXJ2ZXJ9OiRwb3J0IiAiVXlhcsSxIiAiJF8iICJQb3J0IHRlc3RpIGJhxZ9hcsSx
c8SxeiIgfQogICAgfQogICAgdHJ5IHsKICAgICAgICAkcjEzOSA9IFRlc3QtTmV0Q29ubmVjdGlv
biAtQ29tcHV0ZXJOYW1lICRzZXJ2ZXIgLVBvcnQgMTM5IC1JbmZvcm1hdGlvbkxldmVsIFF1aWV0
IC1XYXJuaW5nQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAkZGV0YWlsMTM5ID0gaWYg
KCRyMTM5KSB7ICJBw6fEsWsiIH0gZWxzZSB7ICJLYXBhbMSxL0VyacWfaWxlbWV6IiB9CiAgICAg
ICAgQWRkLURpYWcgIlV6YWsgUG9ydCIgIiR7c2VydmVyfToxMzkiICJPSyIgIiRkZXRhaWwxMzk7
IGVza2kgTmV0QklPUyBwb3J0dSIgIk1vZGVybiBTTUIgacOnaW4gdGVrIGJhxZ/EsW5hIGhhdGEg
c2F5xLFsbWF6IgogICAgfSBjYXRjaCB7IEFkZC1EaWFnICJVemFrIFBvcnQiICIke3NlcnZlcn06
MTM5IiAiT0siICJUZXN0IGF0bGFuZMSxIiAiTW9kZXJuIFNNQiBpw6dpbiB0ZWsgYmHFn8SxbmEg
aGF0YSBzYXnEsWxtYXoiIH0KCiAgICB0cnkgewogICAgICAgICRvdXQgPSBjbWQgL2MgIm5ldCB2
aWV3IFxcJHNlcnZlciIgMj4mMQogICAgICAgICRqb2luZWQgPSAoJG91dCAtam9pbiAiIHwgIikK
ICAgICAgICBpZiAoJGpvaW5lZCAtbWF0Y2ggIkFjY2VzcyBpcyBkZW5pZWR8RXJpxZ9pbSBlbmdl
bGxlbmRpIikgewogICAgICAgICAgICBBZGQtRGlhZyAiVXphayBQYXlsYcWfxLFtIiAibmV0IHZp
ZXciICJIYXRhIiAkam9pbmVkICJDcmVkZW50aWFsL2l6aW4va29udWsgYXlhcmxhcsSxIGtvbnRy
b2wgZWRpbG1lbGkiCiAgICAgICAgfSBlbHNlaWYgKCRqb2luZWQgLW1hdGNoICJTeXN0ZW0gZXJy
b3IgNTN8U2lzdGVtIGhhdGFzxLEgNTMiKSB7CiAgICAgICAgICAgIEFkZC1EaWFnICJVemFrIFBh
eWxhxZ/EsW0iICJuZXQgdmlldyIgIkhhdGEiICRqb2luZWQgIlBDIGFkxLEvSVAgdmV5YSBhxJ8g
a2XFn2ZpIGtvbnRyb2wgZWRpbG1lbGkiCiAgICAgICAgfSBlbHNlaWYgKCRqb2luZWQgLW1hdGNo
ICJjb21tYW5kIGNvbXBsZXRlZCBzdWNjZXNzZnVsbHl8a29tdXQgYmHFn2FyxLF5bGEgdGFtYW1s
YW5kxLEiKSB7CiAgICAgICAgICAgIEFkZC1EaWFnICJVemFrIFBheWxhxZ/EsW0iICJuZXQgdmll
dyIgIk9LIiAiUGF5bGHFn8SxbWxhciBsaXN0ZWxlbmRpIiAiU29ydW4geW9rIgogICAgICAgIH0g
ZWxzZSB7CiAgICAgICAgICAgIEFkZC1EaWFnICJVemFrIFBheWxhxZ/EsW0iICJuZXQgdmlldyIg
IlV5YXLEsSIgJGpvaW5lZCAiTG9nIGRldGF5xLFuxLEgaW5jZWxleWluIgogICAgICAgIH0KICAg
ICAgICBmb3JlYWNoICgkbGluZSBpbiAkb3V0KSB7IFdyaXRlLUxvZyAiTkVUVklFV19ESUFHOiAk
bGluZSIgfQogICAgfSBjYXRjaCB7IEFkZC1EaWFnICJVemFrIFBheWxhxZ/EsW0iICJuZXQgdmll
dyIgIlV5YXLEsSIgIiRfIiAibmV0IHZpZXcgw6dhbMSxxZ9tYWTEsSIgfQoKICAgIHRyeSB7CiAg
ICAgICAgJHByaW50ZXJzID0gR2V0LUNpbUluc3RhbmNlIC1DbGFzc05hbWUgV2luMzJfUHJpbnRl
ciAtQ29tcHV0ZXJOYW1lICRzZXJ2ZXIgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICAkc2hhcmVk
ID0gQCgkcHJpbnRlcnMgfCBXaGVyZS1PYmplY3QgeyAkXy5TaGFyZWQgLWVxICR0cnVlIC1hbmQg
JF8uU2hhcmVOYW1lIH0pCiAgICAgICAgaWYgKCRzaGFyZWQuQ291bnQgLWd0IDApIHsgQWRkLURp
YWcgIlV6YWsgWWF6xLFjxLEiICJQYXlsYcWfxLFsYW4gWWF6xLFjxLEiICJPSyIgIiQoJHNoYXJl
ZC5Db3VudCkgYWRldCIgIllhesSxY8SxIEJ1bCBzZWttZXNpbmRlbiBsaXN0ZWxleWluIiB9CiAg
ICAgICAgZWxzZSB7IEFkZC1EaWFnICJVemFrIFlhesSxY8SxIiAiUGF5bGHFn8SxbGFuIFlhesSx
Y8SxIiAiVXlhcsSxIiAiQnVsdW5hbWFkxLEiICJIb3N0IFBDJ2RlIHlhesSxY8SxIHBheWxhxZ/E
sW0gYWTEsSBrb250cm9sIGVkaWxtZWxpIiB9CiAgICB9IGNhdGNoIHsgQWRkLURpYWcgIlV6YWsg
WWF6xLFjxLEiICJDSU0gV2luMzJfUHJpbnRlciIgIlV5YXLEsSIgIiRfIiAiV01JIGthcGFsxLEg
b2xhYmlsaXI7IG5ldCB2aWV3IHNvbnXDp2xhcsSxbmEgYmFrxLFuIiB9CgogICAgV3JpdGUtTG9n
ICI9PT0gVVpBSyBQQyBBUklaQSBURVNQxLBUxLAgQsSwVFTEsCA9PT0iICJPSyIKfQoKZnVuY3Rp
b24gUnVuLUFsbERpYWdub3NpcyB7CiAgICBDbGVhci1EaWFnCiAgICBXcml0ZS1Mb2cgIj09PSBC
xLBSTEXFnsSwSyBZRVJFTC9VWkFLIEFSSVpBIFRFU1DEsFTEsCBCQcWeTEFESSA9PT0iCiAgICBS
dW4tTG9jYWxEaWFnbm9zaXMgLUFwcGVuZAogICAgaWYgKC1ub3QgW3N0cmluZ106OklzTnVsbE9y
V2hpdGVTcGFjZSgkdHh0UmVtb3RlUGMuVGV4dC5UcmltKCkpKSB7CiAgICAgICAgUnVuLVJlbW90
ZURpYWdub3NpcyAtQXBwZW5kCiAgICB9IGVsc2UgewogICAgICAgIEFkZC1EaWFnICJVemFrIFRl
c3BpdCIgIlBDL0lQIGFsYW7EsSIgIlV5YXLEsSIgIkJvxZ8iICJVemFrIGhvc3Qga29udHJvbMO8
IGnDp2luIFlhesSxY8SxIEJ1bC9CYcSfbGEgZWtyYW7EsW5kYWtpIFBDL0lQIGFsYW7EsW7EsSBk
b2xkdXJ1biIKICAgIH0KICAgIEFwcGx5LVJlY29tbWVuZGVkRml4U2VsZWN0aW9uCiAgICBTaG93
LVBhZ2UgImRpYWciCiAgICBXcml0ZS1Mb2cgIj09PSBCxLBSTEXFnsSwSyBZRVJFTC9VWkFLIEFS
SVpBIFRFU1DEsFTEsCBCxLBUVMSwID09PSIgIk9LIgogICAgU2hvdy1JbmZvICJUZXNwaXQgVGFt
YW1sYW5kxLEiICJZZXJlbC91emFrIHRlc3BpdCB0YW1hbWxhbmTEsSB2ZSDDtm5lcmlsZW4gZml4
bGVyIHNlw6dpbGRpLmByYG5GaXggZWtyYW7EsW5kYSBzZcOnaWxpIGt1dHVsYXLEsSBrb250cm9s
IGVkaXAgdXlndWxheWFiaWxpcnNpbml6LiIKfQoKIyAtLS0tLS0tLS0tIEZJWCBFTkdJTkUgLS0t
LS0tLS0tLQpmdW5jdGlvbiBHZXQtU2VsZWN0ZWRGaXhDb3VudCB7CiAgICAkY2hlY2tzID0gQCgk
Y2hrRml4UnBjLCRjaGtGaXhQb2ludCwkY2hrRml4U21iLCRjaGtGaXhGaXJld2FsbCwkY2hrRml4
U2VydmljZXMsJGNoa0ZpeFNwb29sZXIsJGNoa0ZpeE50bG0sJGNoa0ZpeENyZWRlbnRpYWwsJGNo
a0ZpeERyaXZlciwkY2hrRml4V29ya2dyb3VwKQogICAgcmV0dXJuIEAoJGNoZWNrcyB8IFdoZXJl
LU9iamVjdCB7ICRfIC1hbmQgJF8uQ2hlY2tlZCB9KS5Db3VudAp9CmZ1bmN0aW9uIEVuc3VyZS1B
dExlYXN0T25lRml4U2VsZWN0ZWQgewogICAgaWYgKChHZXQtU2VsZWN0ZWRGaXhDb3VudCkgLWx0
IDEpIHsKICAgICAgICBTaG93LVdhcm4gIkTDvHplbHRtZSBTZcOnaWxtZWRpIiAiSGnDp2JpciBk
w7x6ZWx0bWUgc2XDp2lsaSBkZcSfaWwuIEZpeCBla3JhbsSxbmRhbiB1eWd1bGFuYWNhayBkw7x6
ZWx0bWVsZXJpIGnFn2FyZXRsZXlpbi4iCiAgICAgICAgV0FSTiAiRml4IMOnYWzEscWfdMSxcsSx
bG1hZMSxOiBoacOnYmlyIGTDvHplbHRtZSBzZcOnaWxpIGRlxJ9pbC4iCiAgICAgICAgcmV0dXJu
ICRmYWxzZQogICAgfQogICAgcmV0dXJuICR0cnVlCn0KZnVuY3Rpb24gRW5hYmxlLU5ldHdvcmtQ
cm9maWxlUHJpdmF0ZSB7CiAgICBXcml0ZS1Mb2cgIkHEnyBwcm9maWxpIFByaXZhdGUgeWFwxLFs
bWF5YSDDp2FsxLHFn8SxbMSxeW9yLi4uIgogICAgdHJ5IHsKICAgICAgICBHZXQtTmV0Q29ubmVj
dGlvblByb2ZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBGb3JFYWNoLU9iamVj
dCB7CiAgICAgICAgICAgIGlmICgkXy5OZXR3b3JrQ2F0ZWdvcnkgLW5lICJQcml2YXRlIikgewog
ICAgICAgICAgICAgICAgU2V0LU5ldENvbm5lY3Rpb25Qcm9maWxlIC1JbnRlcmZhY2VJbmRleCAk
Xy5JbnRlcmZhY2VJbmRleCAtTmV0d29ya0NhdGVnb3J5IFByaXZhdGUgLUVycm9yQWN0aW9uIFNp
bGVudGx5Q29udGludWUKICAgICAgICAgICAgICAgIE9LICJQcml2YXRlIHlhcMSxbGTEsTogJCgk
Xy5OYW1lKSIKICAgICAgICAgICAgfSBlbHNlIHsgT0sgIlphdGVuIFByaXZhdGU6ICQoJF8uTmFt
ZSkiIH0KICAgICAgICB9CiAgICB9IGNhdGNoIHsgV0FSTiAiQcSfIHByb2ZpbGkgZGXEn2nFn3Rp
cmlsZW1lZGk6ICRfIiB9Cn0KZnVuY3Rpb24gRW5hYmxlLVByaW50ZXJGaXJld2FsbCB7CiAgICBX
cml0ZS1Mb2cgIkZpcmV3YWxsIEZpbGUgYW5kIFByaW50ZXIgU2hhcmluZyAvIE5ldHdvcmsgRGlz
Y292ZXJ5IGt1cmFsbGFyxLEgZXRraW5sZcWfdGlyaWxpeW9yLi4uIgogICAgdHJ5IHsKICAgICAg
ICBFbmFibGUtTmV0RmlyZXdhbGxSdWxlIC1EaXNwbGF5R3JvdXAgIkZpbGUgYW5kIFByaW50ZXIg
U2hhcmluZyIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICBFbmFibGUtTmV0
RmlyZXdhbGxSdWxlIC1EaXNwbGF5R3JvdXAgIk5ldHdvcmsgRGlzY292ZXJ5IiAtRXJyb3JBY3Rp
b24gU2lsZW50bHlDb250aW51ZQogICAgICAgIE9LICJGaXJld2FsbCBkaXNwbGF5IGdyb3VwIGt1
cmFsbGFyxLEgZXRraW5sZcWfdGlyaWxkaSIKICAgIH0gY2F0Y2ggeyBXQVJOICJEaXNwbGF5R3Jv
dXAgZmlyZXdhbGwgZXRraW5sZcWfdGlyaWxlbWVkaTogJF8iIH0KCiAgICAkcnVsZXMgPSBAKAog
ICAgICAgIEB7TmFtZT0iUFJOLVVFVC1TTUItNDQ1LUluIjsgUG9ydD00NDU7IFByb3RvY29sPSJU
Q1AifSwKICAgICAgICBAe05hbWU9IlBSTi1VRVQtUlBDLTEzNS1JbiI7IFBvcnQ9MTM1OyBQcm90
b2NvbD0iVENQIn0sCiAgICAgICAgQHtOYW1lPSJQUk4tVUVULU5ldEJJT1MtMTM5LUluIjsgUG9y
dD0xMzk7IFByb3RvY29sPSJUQ1AifSwKICAgICAgICBAe05hbWU9IlBSTi1VRVQtTmV0QklPUy0x
MzctSW4iOyBQb3J0PTEzNzsgUHJvdG9jb2w9IlVEUCJ9LAogICAgICAgIEB7TmFtZT0iUFJOLVVF
VC1OZXRCSU9TLTEzOC1JbiI7IFBvcnQ9MTM4OyBQcm90b2NvbD0iVURQIn0KICAgICkKICAgIGZv
cmVhY2ggKCRyIGluICRydWxlcykgewogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRleGlzdHMg
PSBHZXQtTmV0RmlyZXdhbGxSdWxlIC1EaXNwbGF5TmFtZSAkci5OYW1lIC1FcnJvckFjdGlvbiBT
aWxlbnRseUNvbnRpbnVlCiAgICAgICAgICAgIGlmICgtbm90ICRleGlzdHMpIHsKICAgICAgICAg
ICAgICAgIE5ldy1OZXRGaXJld2FsbFJ1bGUgLURpc3BsYXlOYW1lICRyLk5hbWUgLURpcmVjdGlv
biBJbmJvdW5kIC1Qcm90b2NvbCAkci5Qcm90b2NvbCAtTG9jYWxQb3J0ICRyLlBvcnQgLUFjdGlv
biBBbGxvdyAtUHJvZmlsZSBBbnkgfCBPdXQtTnVsbAogICAgICAgICAgICAgICAgT0sgIkZpcmV3
YWxsIGt1cmFsxLEgZWtsZW5kaTogJCgkci5OYW1lKSIKICAgICAgICAgICAgfSBlbHNlIHsgT0sg
IkZpcmV3YWxsIGt1cmFsxLEgbWV2Y3V0OiAkKCRyLk5hbWUpIiB9CiAgICAgICAgfSBjYXRjaCB7
IFdBUk4gIkZpcmV3YWxsIGt1cmFsxLEgZWtsZW5lbWVkaSAkKCRyLk5hbWUpOiAkXyIgfQogICAg
fQp9CmZ1bmN0aW9uIEVuc3VyZS1TZXJ2aWNlcyB7CiAgICBXcml0ZS1Mb2cgIkdlcmVrbGkgc2Vy
dmlzbGVyIGtvbnRyb2wgZWRpbGl5b3IuLi4iCiAgICAkc2VydmljZXMgPSBAKCJTcG9vbGVyIiwi
UnBjU3MiLCJScGNFcHRNYXBwZXIiLCJMYW5tYW5TZXJ2ZXIiLCJMYW5tYW5Xb3Jrc3RhdGlvbiIs
ImZkUEhvc3QiLCJGRFJlc1B1YiIsIlNTRFBTUlYiLCJ1cG5waG9zdCIpCiAgICBmb3JlYWNoICgk
c3ZjTmFtZSBpbiAkc2VydmljZXMpIHsKICAgICAgICB0cnkgewogICAgICAgICAgICAkc3ZjID0g
R2V0LVNlcnZpY2UgLU5hbWUgJHN2Y05hbWUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUK
ICAgICAgICAgICAgaWYgKCRzdmMpIHsKICAgICAgICAgICAgICAgIFNldC1TZXJ2aWNlIC1OYW1l
ICRzdmNOYW1lIC1TdGFydHVwVHlwZSBBdXRvbWF0aWMgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29u
dGludWUKICAgICAgICAgICAgICAgIFN0YXJ0LVNlcnZpY2UgLU5hbWUgJHN2Y05hbWUgLUVycm9y
QWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgICAgIE9LICIkc3ZjTmFtZSDDp2Fs
xLHFn8Sxci9vdG9tYXRpayBrb250cm9sIGVkaWxkaSIKICAgICAgICAgICAgfSBlbHNlIHsgV0FS
TiAiJHN2Y05hbWUgc2VydmlzaSBidWx1bmFtYWTEsSIgfQogICAgICAgIH0gY2F0Y2ggeyBXQVJO
ICIkc3ZjTmFtZSBzZXJ2aXMgaGF0YXPEsTogJF8iIH0KICAgIH0KfQpmdW5jdGlvbiBSZXNldC1T
cG9vbGVyIHsKICAgIFdyaXRlLUxvZyAiUHJpbnQgU3Bvb2xlciBzxLFmxLFybGFuxLF5b3IuLi4i
CiAgICB0cnkgewogICAgICAgIFN0b3AtU2VydmljZSBTcG9vbGVyIC1Gb3JjZSAtRXJyb3JBY3Rp
b24gU2lsZW50bHlDb250aW51ZQogICAgICAgIFN0YXJ0LVNsZWVwIC1TZWNvbmRzIDEKICAgICAg
ICAkc3Bvb2xQYXRoID0gIiRlbnY6U3lzdGVtUm9vdFxTeXN0ZW0zMlxzcG9vbFxQUklOVEVSUyIK
ICAgICAgICAkZmlsZXMgPSBHZXQtQ2hpbGRJdGVtIC1QYXRoICRzcG9vbFBhdGggLUluY2x1ZGUg
Iiouc3BsIiwiKi5zaGQiIC1SZWN1cnNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAg
ICAgICAgJGNudCA9IEAoJGZpbGVzKS5Db3VudAogICAgICAgICRmaWxlcyB8IFJlbW92ZS1JdGVt
IC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgIFN0YXJ0LVNlcnZp
Y2UgU3Bvb2xlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgIE9LICJTcG9v
bGVyIHPEsWbEsXJsYW5kxLEsICRjbnQga3V5cnVrIGRvc3lhc8SxIHRlbWl6bGVuZGkiCiAgICB9
IGNhdGNoIHsgRVJSICJTcG9vbGVyIHPEsWbEsXJsYW1hIGhhdGFzxLE6ICRfIiB9Cn0KZnVuY3Rp
b24gQXBwbHktUlBDLVByaW50ZXJDb3JlIHsKICAgIFdyaXRlLUxvZyAiUlBDIC8gMTFiIC8geWF6
ZMSxcm1hIHBvbGljeSBheWFybGFyxLEgdXlndWxhbsSxeW9yLi4uIgogICAgU2V0LURXb3JkU2Fm
ZSAiSEtMTTpcU3lzdGVtXEN1cnJlbnRDb250cm9sU2V0XENvbnRyb2xcUHJpbnQiICJScGNBdXRo
bkxldmVsUHJpdmFjeUVuYWJsZWQiIDAKICAgICRycGNQYXRoID0gIkhLTE06XFNPRlRXQVJFXFBv
bGljaWVzXE1pY3Jvc29mdFxXaW5kb3dzIE5UXFByaW50ZXJzXFJQQyIKICAgIFNldC1EV29yZFNh
ZmUgJHJwY1BhdGggIlJwY1VzZU5hbWVkUGlwZVByb3RvY29sIiAxCiAgICBTZXQtRFdvcmRTYWZl
ICRycGNQYXRoICJScGNPdmVyVGNwIiAxCiAgICBTZXQtRFdvcmRTYWZlICRycGNQYXRoICJScGNP
dmVyTmFtZWRQaXBlcyIgMQogICAgU2V0LURXb3JkU2FmZSAkcnBjUGF0aCAiUnBjUHJvdG9jb2xz
IiA3Cn0KZnVuY3Rpb24gQXBwbHktUG9pbnRBbmRQcmludCB7CiAgICBXcml0ZS1Mb2cgIlBvaW50
IGFuZCBQcmludCAvIFBhY2thZ2UgUG9pbnQgYW5kIFByaW50IGF5YXJsYXLEsSB1eWd1bGFuxLF5
b3IuLi4iCiAgICAkcG5wID0gIkhLTE06XFNPRlRXQVJFXFBvbGljaWVzXE1pY3Jvc29mdFxXaW5k
b3dzIE5UXFByaW50ZXJzXFBvaW50QW5kUHJpbnQiCiAgICBTZXQtRFdvcmRTYWZlICRwbnAgIlJl
c3RyaWN0RHJpdmVySW5zdGFsbGF0aW9uVG9BZG1pbmlzdHJhdG9ycyIgMAogICAgU2V0LURXb3Jk
U2FmZSAkcG5wICJOb1dhcm5pbmdOb0VsZXZhdGlvbk9uSW5zdGFsbCIgMQogICAgU2V0LURXb3Jk
U2FmZSAkcG5wICJVcGRhdGVQcm9tcHRTZXR0aW5ncyIgMAogICAgU2V0LURXb3JkU2FmZSAkcG5w
ICJUcnVzdGVkU2VydmVycyIgMQogICAgU2V0LURXb3JkU2FmZSAkcG5wICJJbkZvcmVzdCIgMAoK
ICAgICRzZXJ2ZXIgPSAkdHh0UmVtb3RlUGMuVGV4dC5UcmltKCkKICAgIGlmIChbc3RyaW5nXTo6
SXNOdWxsT3JXaGl0ZVNwYWNlKCRzZXJ2ZXIpKSB7ICRzZXJ2ZXIgPSBHZXQtU2VydmVyRnJvbVVO
QyAkdHh0TWFudWFsVU5DLlRleHQuVHJpbSgpIH0KICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051
bGxPcldoaXRlU3BhY2UoJHNlcnZlcikpIHsKICAgICAgICBTZXQtTXVsdGlTdHJpbmdTYWZlICRw
bnAgIlNlcnZlckxpc3QiIEAoJHNlcnZlcikKICAgICAgICAkcGtnID0gIkhLTE06XFNPRlRXQVJF
XFBvbGljaWVzXE1pY3Jvc29mdFxXaW5kb3dzIE5UXFByaW50ZXJzXFBhY2thZ2VQb2ludEFuZFBy
aW50IgogICAgICAgIEVuc3VyZS1LZXkgJHBrZwogICAgICAgIFNldC1NdWx0aVN0cmluZ1NhZmUg
JHBrZyAiUGFja2FnZVBvaW50QW5kUHJpbnRTZXJ2ZXJMaXN0IiBAKCRzZXJ2ZXIpCiAgICAgICAg
U2V0LURXb3JkU2FmZSAkcGtnICJQYWNrYWdlUG9pbnRBbmRQcmludE9ubHkiIDAKICAgICAgICBP
SyAiVHJ1c3RlZCBzZXJ2ZXIgLyBQYWNrYWdlIFBvaW50IGFuZCBQcmludCBsaXN0ZXNpbmUgZWts
ZW5kaTogJHNlcnZlciIKICAgIH0gZWxzZSB7IFdBUk4gIlRydXN0ZWQgc2VydmVyIGnDp2luIFBD
L0lQIGdpcmlsbWVkaSIgfQp9CmZ1bmN0aW9uIEFwcGx5LVNNQi1Db21wYXRpYmlsaXR5IHsKICAg
IFdyaXRlLUxvZyAiU01CIHV5dW1sdWx1ayBheWFybGFyxLEgdXlndWxhbsSxeW9yLi4uIgogICAg
dHJ5IHsgU2V0LVNtYlNlcnZlckNvbmZpZ3VyYXRpb24gLUVuYWJsZVNNQjJQcm90b2NvbCAkdHJ1
ZSAtRm9yY2UgfCBPdXQtTnVsbDsgT0sgIlNNQjIgc2VydmVyIGV0a2luIiB9IGNhdGNoIHsgV0FS
TiAiU01CMiBzZXJ2ZXIgeWFwxLFsYW5kxLFyxLFsYW1hZMSxOiAkXyIgfQogICAgaWYgKCRjaGtT
bWJTaWduaW5nLkNoZWNrZWQpIHsKICAgICAgICB0cnkgewogICAgICAgICAgICBTZXQtU21iU2Vy
dmVyQ29uZmlndXJhdGlvbiAtUmVxdWlyZVNlY3VyaXR5U2lnbmF0dXJlICRmYWxzZSAtRm9yY2Ug
fCBPdXQtTnVsbAogICAgICAgICAgICBTZXQtU21iQ2xpZW50Q29uZmlndXJhdGlvbiAtUmVxdWly
ZVNlY3VyaXR5U2lnbmF0dXJlICRmYWxzZSAtQ29uZmlybTokZmFsc2UgfCBPdXQtTnVsbAogICAg
ICAgICAgICBPSyAiU01CIGltemFsYW1hIHpvcnVubHVsdcSfdSB1eXVtbHVsdWsgacOnaW4gb3Bz
aXlvbmVsIHlhcMSxbGTEsSIKICAgICAgICB9IGNhdGNoIHsgV0FSTiAiU01CIHNpZ25pbmcgYXlh
csSxIHV5Z3VsYW5hbWFkxLE6ICRfIiB9CiAgICB9IGVsc2UgeyBXQVJOICJTTUIgc2lnbmluZyBh
eWFyxLEga3VsbGFuxLFjxLEgdGVyY2loaXlsZSBhdGxhbmTEsSIgfQoKICAgIGlmICgkY2hrR3Vl
c3QuQ2hlY2tlZCkgewogICAgICAgIFNldC1EV29yZFNhZmUgIkhLTE06XFNZU1RFTVxDdXJyZW50
Q29udHJvbFNldFxTZXJ2aWNlc1xMYW5tYW5Xb3Jrc3RhdGlvblxQYXJhbWV0ZXJzIiAiQWxsb3dJ
bnNlY3VyZUd1ZXN0QXV0aCIgMQogICAgICAgIFNldC1EV29yZFNhZmUgIkhLTE06XFNPRlRXQVJF
XFBvbGljaWVzXE1pY3Jvc29mdFxXaW5kb3dzXExhbm1hbldvcmtzdGF0aW9uIiAiQWxsb3dJbnNl
Y3VyZUd1ZXN0QXV0aCIgMQogICAgICAgIFNldC1EV29yZFNhZmUgIkhLTE06XFNZU1RFTVxDdXJy
ZW50Q29udHJvbFNldFxDb250cm9sXExzYSIgInJlc3RyaWN0YW5vbnltb3VzIiAwCiAgICAgICAg
U2V0LURXb3JkU2FmZSAiSEtMTTpcU1lTVEVNXEN1cnJlbnRDb250cm9sU2V0XENvbnRyb2xcTHNh
IiAicmVzdHJpY3Rhbm9ueW1vdXNzYW0iIDAKICAgICAgICBTZXQtRFdvcmRTYWZlICJIS0xNOlxT
WVNURU1cQ3VycmVudENvbnRyb2xTZXRcQ29udHJvbFxMc2EiICJldmVyeW9uZWluY2x1ZGVzYW5v
bnltb3VzIiAxCiAgICAgICAgU2V0LURXb3JkU2FmZSAiSEtMTTpcU1lTVEVNXEN1cnJlbnRDb250
cm9sU2V0XFNlcnZpY2VzXExhbm1hblNlcnZlclxQYXJhbWV0ZXJzIiAicmVzdHJpY3RudWxsc2Vz
c2FjY2VzcyIgMAogICAgICAgIE9LICJLb251ay9pbnNlY3VyZSBndWVzdCB1eXVtbHVsdcSfdSB1
eWd1bGFuZMSxIgogICAgfSBlbHNlIHsgV0FSTiAiS29udWsvaW5zZWN1cmUgZ3Vlc3Qga2FwYWzE
sTsgYXRsYW5kxLEiIH0KfQpmdW5jdGlvbiBBcHBseS1OVExNLU5ldEJJT1MgewogICAgV3JpdGUt
TG9nICJOVExNdjIgLyBOZXRCSU9TIHV5dW1sdWx1ayBheWFybGFyxLEgdXlndWxhbsSxeW9yLi4u
IgogICAgU2V0LURXb3JkU2FmZSAiSEtMTTpcU1lTVEVNXEN1cnJlbnRDb250cm9sU2V0XENvbnRy
b2xcTHNhIiAiTG1Db21wYXRpYmlsaXR5TGV2ZWwiIDMKICAgIFNldC1EV29yZFNhZmUgIkhLTE06
XFNZU1RFTVxDdXJyZW50Q29udHJvbFNldFxDb250cm9sXExzYSIgIk5vTE1IYXNoIiAxCiAgICB0
cnkgewogICAgICAgIEdldC1XbWlPYmplY3QgV2luMzJfTmV0d29ya0FkYXB0ZXJDb25maWd1cmF0
aW9uIHwgV2hlcmUtT2JqZWN0IHsgJF8uSVBFbmFibGVkIH0gfCBGb3JFYWNoLU9iamVjdCB7CiAg
ICAgICAgICAgICRudWxsID0gJF8uU2V0VGNwaXBOZXRiaW9zKDEpCiAgICAgICAgICAgIE9LICJO
ZXRCSU9TIGV0a2luOiAkKCRfLkRlc2NyaXB0aW9uKSIKICAgICAgICB9CiAgICB9IGNhdGNoIHsg
V0FSTiAiTmV0QklPUyBldGtpbmxlxZ90aXJpbGVtZWRpOiAkXyIgfQp9CmZ1bmN0aW9uIEFwcGx5
LUNyZWRlbnRpYWxDbGVhbnVwIHsKICAgIFdyaXRlLUxvZyAiQ3JlZGVudGlhbCB0ZW1pemxpxJ9p
IGJhxZ9sxLF5b3IuLi4iCiAgICB0cnkgewogICAgICAgICRzZXJ2ZXIgPSAkdHh0UmVtb3RlUGMu
VGV4dC5UcmltKCkKICAgICAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkc2Vy
dmVyKSkgeyAkc2VydmVyID0gR2V0LVNlcnZlckZyb21VTkMgJHR4dE1hbnVhbFVOQy5UZXh0LlRy
aW0oKSB9CiAgICAgICAgaWYgKC1ub3QgW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkc2Vy
dmVyKSkgewogICAgICAgICAgICBjbWRrZXkgL2RlbGV0ZTokc2VydmVyIDI+JjEgfCBGb3JFYWNo
LU9iamVjdCB7IFdyaXRlLUxvZyAiQ01ES0VZOiAkXyIgfQogICAgICAgICAgICBjbWRrZXkgL2Rl
bGV0ZToiVEVSTVNSVi8kc2VydmVyIiAyPiYxIHwgRm9yRWFjaC1PYmplY3QgeyBXcml0ZS1Mb2cg
IkNNREtFWTogJF8iIH0KICAgICAgICAgICAgY21kIC9jICJuZXQgdXNlIFxcJHNlcnZlciAvZGVs
ZXRlIC95IiAyPiYxIHwgRm9yRWFjaC1PYmplY3QgeyBXcml0ZS1Mb2cgIk5FVFVTRTogJF8iIH0K
ICAgICAgICAgICAgT0sgIkNyZWRlbnRpYWwvbmV0IHVzZSB0ZW1pemxpxJ9pIGRlbmVuZGk6ICRz
ZXJ2ZXIiCiAgICAgICAgfSBlbHNlIHsgV0FSTiAiUmVtb3RlIFBDL1VOQyBnaXJpbG1lZGnEn2kg
acOnaW4gY3JlZGVudGlhbCB0ZW1pemxpxJ9pIHPEsW7EsXJsxLEgYXRsYW5kxLEiIH0KICAgIH0g
Y2F0Y2ggeyBXQVJOICJDcmVkZW50aWFsIHRlbWl6bGnEn2kgYmHFn2FyxLFzxLF6OiAkXyIgfQp9
CmZ1bmN0aW9uIEFkZC1Ecml2ZXJGaWx0ZXJDYW5kaWRhdGUgewogICAgcGFyYW0oCiAgICAgICAg
W2hhc2h0YWJsZV0kQ2FuZGlkYXRlcywKICAgICAgICBbc3RyaW5nXSRGaWx0ZXIsCiAgICAgICAg
W2ludF0kU2NvcmUsCiAgICAgICAgW3N0cmluZ10kU291cmNlCiAgICApCiAgICBpZiAoW3N0cmlu
Z106OklzTnVsbE9yV2hpdGVTcGFjZSgkRmlsdGVyKSkgeyByZXR1cm4gfQogICAgJGNsZWFuID0g
JEZpbHRlci5UcmltKCkKICAgICRjbGVhbiA9ICgkY2xlYW4gLXJlcGxhY2UgIlxzKyIsIiAiKS5U
cmltKCIgYHRgcmBuIiInIikKICAgIGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRj
bGVhbikpIHsgcmV0dXJuIH0KICAgIGlmICgkY2xlYW4uTGVuZ3RoIC1sdCAyKSB7IHJldHVybiB9
CgogICAgJHNraXAgPSBAKCJkcml2ZXIiLCJkcml2ZXJzIiwiY2xhc3MiLCJwcmludGVyIiwicHJp
bnRlcnMiLCJwcmludCIsInNlcmllcyIsInVuaXZlcnNhbCIsInNvZnR3YXJlIiwibWljcm9zb2Z0
Iiwid2luZG93cyIsInJlbW90ZSIsImxvY2FsIiwicG9ydCIsInVzYiIsIndzcCIsInhwcyIsInBk
ZiIsImZheCIpCiAgICBpZiAoJHNraXAgLWNvbnRhaW5zICRjbGVhbi5Ub0xvd2VySW52YXJpYW50
KCkpIHsgcmV0dXJuIH0KCiAgICAka2V5ID0gJGNsZWFuLlRvTG93ZXJJbnZhcmlhbnQoKQogICAg
aWYgKCRDYW5kaWRhdGVzLkNvbnRhaW5zS2V5KCRrZXkpKSB7CiAgICAgICAgJENhbmRpZGF0ZXNb
JGtleV0uU2NvcmUgKz0gJFNjb3JlCiAgICAgICAgaWYgKCRDYW5kaWRhdGVzWyRrZXldLlNvdXJj
ZSAtbm90bGlrZSAiKiRTb3VyY2UqIikgeyAkQ2FuZGlkYXRlc1ska2V5XS5Tb3VyY2UgPSAiJCgk
Q2FuZGlkYXRlc1ska2V5XS5Tb3VyY2UpLCAkU291cmNlIiB9CiAgICB9IGVsc2UgewogICAgICAg
ICRDYW5kaWRhdGVzWyRrZXldID0gW1BTQ3VzdG9tT2JqZWN0XUB7IEZpbHRlcj0kY2xlYW47IFNj
b3JlPSRTY29yZTsgU291cmNlPSRTb3VyY2UgfQogICAgfQp9CmZ1bmN0aW9uIEFkZC1Ecml2ZXJG
aWx0ZXJDYW5kaWRhdGVzRnJvbVRleHQgewogICAgcGFyYW0oCiAgICAgICAgW2hhc2h0YWJsZV0k
Q2FuZGlkYXRlcywKICAgICAgICBbc3RyaW5nXSRUZXh0LAogICAgICAgIFtzdHJpbmddJFNvdXJj
ZQogICAgKQogICAgaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJFRleHQpKSB7IHJl
dHVybiB9CgogICAgZm9yZWFjaCAoJHZlbmRvciBpbiAkc2NyaXB0OlByaW50ZXJWZW5kb3JQYXR0
ZXJucykgewogICAgICAgIGlmICgkVGV4dCAtbWF0Y2ggJHZlbmRvci5QYXR0ZXJuKSB7CiAgICAg
ICAgICAgIEFkZC1Ecml2ZXJGaWx0ZXJDYW5kaWRhdGUgLUNhbmRpZGF0ZXMgJENhbmRpZGF0ZXMg
LUZpbHRlciAkdmVuZG9yLkZpbHRlciAtU2NvcmUgMTAwIC1Tb3VyY2UgJFNvdXJjZQogICAgICAg
IH0KICAgIH0KCiAgICBpZiAoJFRleHQuTGVuZ3RoIC1nZSA0IC1hbmQgJFRleHQuTGVuZ3RoIC1s
ZSA4MCkgewogICAgICAgIEFkZC1Ecml2ZXJGaWx0ZXJDYW5kaWRhdGUgLUNhbmRpZGF0ZXMgJENh
bmRpZGF0ZXMgLUZpbHRlciAkVGV4dCAtU2NvcmUgMjUgLVNvdXJjZSAkU291cmNlCiAgICB9Cgog
ICAgJHRva2VucyA9ICgoJFRleHQgLXJlcGxhY2UgIlteQS1aYS16MC05XSsiLCIgIikgLXNwbGl0
ICJccysiKSB8IFdoZXJlLU9iamVjdCB7ICRfLkxlbmd0aCAtZ2UgMyAtYW5kICRfLkxlbmd0aCAt
bGUgMjQgfQogICAgZm9yZWFjaCAoJHRva2VuIGluICR0b2tlbnMpIHsKICAgICAgICBBZGQtRHJp
dmVyRmlsdGVyQ2FuZGlkYXRlIC1DYW5kaWRhdGVzICRDYW5kaWRhdGVzIC1GaWx0ZXIgJHRva2Vu
IC1TY29yZSA1IC1Tb3VyY2UgJFNvdXJjZQogICAgfQp9CmZ1bmN0aW9uIEdldC1BdXRvRHJpdmVy
RmlsdGVyQ2FuZGlkYXRlcyB7CiAgICAkY2FuZGlkYXRlcyA9IEB7fQogICAgdHJ5IHsKICAgICAg
ICBmb3JlYWNoICgkcCBpbiBAKEdldC1QcmludGVyIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRp
bnVlKSkgewogICAgICAgICAgICBBZGQtRHJpdmVyRmlsdGVyQ2FuZGlkYXRlc0Zyb21UZXh0IC1D
YW5kaWRhdGVzICRjYW5kaWRhdGVzIC1UZXh0ICRwLkRyaXZlck5hbWUgLVNvdXJjZSAiWWVyZWwg
ZHJpdmVyIgogICAgICAgICAgICBBZGQtRHJpdmVyRmlsdGVyQ2FuZGlkYXRlc0Zyb21UZXh0IC1D
YW5kaWRhdGVzICRjYW5kaWRhdGVzIC1UZXh0ICRwLk5hbWUgLVNvdXJjZSAiWWVyZWwgeWF6xLFj
xLEiCiAgICAgICAgICAgIEFkZC1Ecml2ZXJGaWx0ZXJDYW5kaWRhdGVzRnJvbVRleHQgLUNhbmRp
ZGF0ZXMgJGNhbmRpZGF0ZXMgLVRleHQgJHAuUG9ydE5hbWUgLVNvdXJjZSAiWWVyZWwgcG9ydCIK
ICAgICAgICB9CiAgICB9IGNhdGNoIHsgV0FSTiAiWWVyZWwgeWF6xLFjxLEgZmlsdHJlIGFkYXls
YXLEsSBva3VuYW1hZMSxOiAkXyIgfQoKICAgIHRyeSB7CiAgICAgICAgZm9yZWFjaCAoJGQgaW4g
QChHZXQtUHJpbnRlckRyaXZlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsKICAg
ICAgICAgICAgQWRkLURyaXZlckZpbHRlckNhbmRpZGF0ZXNGcm9tVGV4dCAtQ2FuZGlkYXRlcyAk
Y2FuZGlkYXRlcyAtVGV4dCAkZC5OYW1lIC1Tb3VyY2UgIlPDvHLDvGPDvCBsaXN0ZXNpIgogICAg
ICAgIH0KICAgIH0gY2F0Y2ggeyBXQVJOICJTw7xyw7xjw7wgZmlsdHJlIGFkYXlsYXLEsSBva3Vu
YW1hZMSxOiAkXyIgfQoKICAgIHRyeSB7CiAgICAgICAgZm9yZWFjaCAoJHBvcnQgaW4gQChHZXQt
UHJpbnRlclBvcnQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7CiAgICAgICAgICAg
IEFkZC1Ecml2ZXJGaWx0ZXJDYW5kaWRhdGVzRnJvbVRleHQgLUNhbmRpZGF0ZXMgJGNhbmRpZGF0
ZXMgLVRleHQgJHBvcnQuTmFtZSAtU291cmNlICJQb3J0IgogICAgICAgICAgICBBZGQtRHJpdmVy
RmlsdGVyQ2FuZGlkYXRlc0Zyb21UZXh0IC1DYW5kaWRhdGVzICRjYW5kaWRhdGVzIC1UZXh0ICRw
b3J0LlByaW50ZXJIb3N0QWRkcmVzcyAtU291cmNlICJQb3J0IGFkcmVzaSIKICAgICAgICB9CiAg
ICB9IGNhdGNoIHsgV0FSTiAiUG9ydCBmaWx0cmUgYWRheWxhcsSxIG9rdW5hbWFkxLE6ICRfIiB9
CgogICAgaWYgKCRzY3JpcHQ6Rm91bmRJdGVtcykgewogICAgICAgIGZvciAoJGlkeCA9IDA7ICRp
ZHggLWx0ICRzY3JpcHQ6Rm91bmRJdGVtcy5Db3VudDsgJGlkeCsrKSB7CiAgICAgICAgICAgICRp
dGVtID0gJHNjcmlwdDpGb3VuZEl0ZW1zWyRpZHhdCiAgICAgICAgICAgIEFkZC1Ecml2ZXJGaWx0
ZXJDYW5kaWRhdGVzRnJvbVRleHQgLUNhbmRpZGF0ZXMgJGNhbmRpZGF0ZXMgLVRleHQgJGl0ZW0u
RHJpdmVyIC1Tb3VyY2UgIlRhcmFtYSBzb251Y3UiCiAgICAgICAgICAgIEFkZC1Ecml2ZXJGaWx0
ZXJDYW5kaWRhdGVzRnJvbVRleHQgLUNhbmRpZGF0ZXMgJGNhbmRpZGF0ZXMgLVRleHQgJGl0ZW0u
TmFtZSAtU291cmNlICJUYXJhbWEgc29udWN1IgogICAgICAgICAgICBBZGQtRHJpdmVyRmlsdGVy
Q2FuZGlkYXRlc0Zyb21UZXh0IC1DYW5kaWRhdGVzICRjYW5kaWRhdGVzIC1UZXh0ICRpdGVtLlNo
YXJlTmFtZSAtU291cmNlICJUYXJhbWEgc29udWN1IgogICAgICAgIH0KICAgIH0KCiAgICByZXR1
cm4gQCgkY2FuZGlkYXRlcy5WYWx1ZXMgfCBTb3J0LU9iamVjdCBAe0V4cHJlc3Npb249IlNjb3Jl
IjtEZXNjZW5kaW5nPSR0cnVlfSwgQHtFeHByZXNzaW9uPSJGaWx0ZXIiO0FzY2VuZGluZz0kdHJ1
ZX0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAzMCkKfQpmdW5jdGlvbiBTZXQtRHJpdmVyRmlsdGVy
Q29tYm9JdGVtcyB7CiAgICBwYXJhbSgKICAgICAgICBbb2JqZWN0W11dJEl0ZW1zLAogICAgICAg
IFtzd2l0Y2hdJFNlbGVjdEZpcnN0CiAgICApCiAgICBpZiAoJG51bGwgLWVxICR0eHREcml2ZXJG
aWx0ZXIgLW9yICRudWxsIC1lcSAkdHh0RHJpdmVyRmlsdGVyLkl0ZW1zKSB7IHJldHVybiB9Cgog
ICAgJGN1cnJlbnRUZXh0ID0gJHR4dERyaXZlckZpbHRlci5UZXh0CiAgICB0cnkgewogICAgICAg
ICR0eHREcml2ZXJGaWx0ZXIuQmVnaW5VcGRhdGUoKQogICAgICAgICR0eHREcml2ZXJGaWx0ZXIu
SXRlbXMuQ2xlYXIoKQogICAgICAgIGZvcmVhY2ggKCRpdGVtIGluIEAoJEl0ZW1zKSkgewogICAg
ICAgICAgICAkdmFsdWUgPSBpZiAoJGl0ZW0gLWlzIFtzdHJpbmddKSB7ICRpdGVtIH0gZWxzZSB7
ICRpdGVtLkZpbHRlciB9CiAgICAgICAgICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051bGxPcldo
aXRlU3BhY2UoJHZhbHVlKSAtYW5kIC1ub3QgJHR4dERyaXZlckZpbHRlci5JdGVtcy5Db250YWlu
cygkdmFsdWUpKSB7CiAgICAgICAgICAgICAgICBbdm9pZF0kdHh0RHJpdmVyRmlsdGVyLkl0ZW1z
LkFkZChbc3RyaW5nXSR2YWx1ZSkKICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0gZmluYWxs
eSB7CiAgICAgICAgJHR4dERyaXZlckZpbHRlci5FbmRVcGRhdGUoKQogICAgfQoKICAgIGlmICgk
U2VsZWN0Rmlyc3QgLWFuZCAkdHh0RHJpdmVyRmlsdGVyLkl0ZW1zLkNvdW50IC1ndCAwKSB7CiAg
ICAgICAgJHR4dERyaXZlckZpbHRlci5TZWxlY3RlZEluZGV4ID0gMAogICAgfSBlbHNlaWYgKC1u
b3QgW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkY3VycmVudFRleHQpKSB7CiAgICAgICAg
JHR4dERyaXZlckZpbHRlci5UZXh0ID0gJGN1cnJlbnRUZXh0CiAgICB9IGVsc2UgewogICAgICAg
ICR0eHREcml2ZXJGaWx0ZXIuVGV4dCA9ICIiCiAgICB9Cn0KZnVuY3Rpb24gR2V0LURlZmF1bHRE
cml2ZXJGaWx0ZXJPcHRpb25zIHsKICAgIHJldHVybiBAKCRzY3JpcHQ6UHJpbnRlclZlbmRvclBh
dHRlcm5zIHwgRm9yRWFjaC1PYmplY3QgeyAkXy5GaWx0ZXIgfSB8IFNlbGVjdC1PYmplY3QgLVVu
aXF1ZSkKfQpmdW5jdGlvbiBVcGRhdGUtRHJpdmVyRmlsdGVyQ2FuZGlkYXRlcyB7CiAgICBwYXJh
bShbc3dpdGNoXSRTaWxlbnQpCiAgICAkaXRlbXMgPSBAKEdldC1BdXRvRHJpdmVyRmlsdGVyQ2Fu
ZGlkYXRlcykKICAgIHRyeSB7CiAgICAgICAgaWYgKCRudWxsIC1uZSAkdHh0RHJpdmVyRmlsdGVy
IC1hbmQgJG51bGwgLW5lICR0eHREcml2ZXJGaWx0ZXIuSXRlbXMpIHsKICAgICAgICAgICAgaWYg
KCRpdGVtcy5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAgICAgJGNvbWJpbmVkSXRlbXMgPSBA
KCRpdGVtcykgKyBAKEdldC1EZWZhdWx0RHJpdmVyRmlsdGVyT3B0aW9ucykKICAgICAgICAgICAg
ICAgIFNldC1Ecml2ZXJGaWx0ZXJDb21ib0l0ZW1zIC1JdGVtcyAkY29tYmluZWRJdGVtcyAtU2Vs
ZWN0Rmlyc3QKICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgICAgIFNldC1Ecml2ZXJG
aWx0ZXJDb21ib0l0ZW1zIC1JdGVtcyBAKEdldC1EZWZhdWx0RHJpdmVyRmlsdGVyT3B0aW9ucykK
ICAgICAgICAgICAgfQogICAgICAgIH0gZWxzZWlmICgkdHh0RHJpdmVyRmlsdGVyIC1hbmQgJGl0
ZW1zLkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICR0eHREcml2ZXJGaWx0ZXIuVGV4dCA9ICRp
dGVtc1swXS5GaWx0ZXIKICAgICAgICB9CiAgICB9IGNhdGNoIHsgV0FSTiAiRHJpdmVyIGZpbHRy
ZSBsaXN0ZXNpIGfDvG5jZWxsZW5lbWVkaTogJF8iIH0KCiAgICBpZiAoJGl0ZW1zLkNvdW50IC1n
dCAwKSB7CiAgICAgICAgT0sgIkRyaXZlciBmaWx0cmVzaSBvdG9tYXRpayB0ZXNwaXQgZWRpbGRp
OiAkKCRpdGVtc1swXS5GaWx0ZXIpICgkKCRpdGVtcy5Db3VudCkgYWRheSkiCiAgICAgICAgaWYg
KC1ub3QgJFNpbGVudCkgeyBTaG93LUluZm8gIkRyaXZlciBGaWx0cmVzaSIgIkVuIHV5Z3VuIGZp
bHRyZSBzZcOnaWxkaTogJCgkaXRlbXNbMF0uRmlsdGVyKWByYG5Bw6fEsWzEsXIgbGlzdGVkZW4g
ZmFya2zEsSBiaXIgYWRheSBzZcOnZWJpbGlyc2luaXouIiB9CiAgICB9IGVsc2UgewogICAgICAg
IFdBUk4gIk90b21hdGlrIGRyaXZlciBmaWx0cmVzaSBidWx1bmFtYWTEsSIKICAgICAgICBpZiAo
LW5vdCAkU2lsZW50KSB7IFNob3ctV2FybiAiRHJpdmVyIEZpbHRyZXNpIiAiWWVyZWwgeWF6xLFj
xLEvc8O8csO8Y8O8IGthecSxdGxhcsSxbmRhbiBvdG9tYXRpayBmaWx0cmUgw6fEsWthcsSxbGFt
YWTEsS4gTWFya2EgdmV5YSBtb2RlbGRlbiBiaXIga2VsaW1leWkgZWxsZSB5YXphYmlsaXJzaW5p
ei4iIH0KICAgIH0KICAgIHJldHVybiAkaXRlbXMKfQpmdW5jdGlvbiBTaG93LURyaXZlckNsZWFu
dXBQYWdlIHsKICAgIFNob3ctUGFnZSAiZHJpdmVyIgogICAgVXBkYXRlLURyaXZlckZpbHRlckNh
bmRpZGF0ZXMgLVNpbGVudCB8IE91dC1OdWxsCn0KZnVuY3Rpb24gQXBwbHktRHJpdmVyQ2FjaGVD
bGVhbnVwIHsKICAgIFdyaXRlLUxvZyAiRHJpdmVyIGNhY2hlIHRlbWl6bGnEn2kgYmHFn2zEsXlv
ci4uLiIKICAgICRmaWx0ZXIgPSAkdHh0RHJpdmVyRmlsdGVyLlRleHQuVHJpbSgpCiAgICBpZiAo
W3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkZmlsdGVyKSkgewogICAgICAgICRhdXRvSXRl
bXMgPSBAKFVwZGF0ZS1Ecml2ZXJGaWx0ZXJDYW5kaWRhdGVzIC1TaWxlbnQpCiAgICAgICAgaWYg
KCRhdXRvSXRlbXMuQ291bnQgLWd0IDApIHsgJGZpbHRlciA9ICR0eHREcml2ZXJGaWx0ZXIuVGV4
dC5UcmltKCkgfQogICAgfQogICAgaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJGZp
bHRlcikpIHsKICAgICAgICAkYW5zd2VyID0gW1N5c3RlbS5XaW5kb3dzLkZvcm1zLk1lc3NhZ2VC
b3hdOjpTaG93KCJEcml2ZXIgZmlsdHJlc2kgYm/Fny4gVMO8bSDDvMOnw7xuY8O8IHBhcnRpIHlh
esSxY8SxIGRyaXZlcmxhcsSxbsSxIHNpbG1leWUgw6dhbMSxxZ9tYWsgcmlza2xpIG9sYWJpbGly
LmByYG5gcmBuRGV2YW0gZXRtZWsgaXN0aXlvciBtdXN1bj8iLCJEcml2ZXIgVGVtaXpsacSfaSIs
IFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdlQm94QnV0dG9uc106Olllc05vLCBbU3lzdGVt
LldpbmRvd3MuRm9ybXMuTWVzc2FnZUJveEljb25dOjpXYXJuaW5nKQogICAgICAgIGlmICgkYW5z
d2VyIC1uZSBbU3lzdGVtLldpbmRvd3MuRm9ybXMuRGlhbG9nUmVzdWx0XTo6WWVzKSB7IFdBUk4g
IkRyaXZlciB0ZW1pemxpxJ9pIGlwdGFsIGVkaWxkaSI7IHJldHVybiB9CiAgICB9CgogICAgJG1h
dGNoZWRQcmludGVycyA9IEAoKQogICAgJG1hdGNoZWREcml2ZXJzID0gQCgpCiAgICAkbWF0Y2hl
ZFBvcnRzID0gQCgpCiAgICB0cnkgewogICAgICAgICRhbGxQcmludGVycyA9IEAoR2V0LVByaW50
ZXIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgaWYgKFtzdHJpbmddOjpJ
c051bGxPcldoaXRlU3BhY2UoJGZpbHRlcikpIHsKICAgICAgICAgICAgJG1hdGNoZWRQcmludGVy
cyA9ICRhbGxQcmludGVycwogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICRtYXRjaGVkUHJp
bnRlcnMgPSBAKCRhbGxQcmludGVycyB8IFdoZXJlLU9iamVjdCB7ICRfLkRyaXZlck5hbWUgLWxp
a2UgIiokZmlsdGVyKiIgLW9yICRfLk5hbWUgLWxpa2UgIiokZmlsdGVyKiIgLW9yICRfLlBvcnRO
YW1lIC1saWtlICIqJGZpbHRlcioiIH0pCiAgICAgICAgfQogICAgICAgICRhbGxEcml2ZXJzID0g
QChHZXQtUHJpbnRlckRyaXZlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICAg
ICBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkZmlsdGVyKSkgewogICAgICAgICAg
ICAkbWF0Y2hlZERyaXZlcnMgPSAkYWxsRHJpdmVycwogICAgICAgIH0gZWxzZSB7CiAgICAgICAg
ICAgICRtYXRjaGVkRHJpdmVycyA9IEAoJGFsbERyaXZlcnMgfCBXaGVyZS1PYmplY3QgeyAkXy5O
YW1lIC1saWtlICIqJGZpbHRlcioiIH0pCiAgICAgICAgfQogICAgICAgICRhbGxQb3J0cyA9IEAo
R2V0LVByaW50ZXJQb3J0IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgIGlm
ICgtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJGZpbHRlcikpIHsKICAgICAgICAg
ICAgJG1hdGNoZWRQb3J0cyA9IEAoJGFsbFBvcnRzIHwgV2hlcmUtT2JqZWN0IHsgJF8uTmFtZSAt
bGlrZSAiKiRmaWx0ZXIqIiAtb3IgJF8uUHJpbnRlckhvc3RBZGRyZXNzIC1saWtlICIqJGZpbHRl
cioiIH0pCiAgICAgICAgfQogICAgfSBjYXRjaCB7IFdBUk4gIlRlbWl6bGlrIMO2biB0YXJhbWFz
xLEgYmHFn2FyxLFzxLF6OiAkXyIgfQoKICAgICRwcmV2aWV3ID0gIkXFn2xlxZ9lbiB5YXrEsWPE
sTogJCgkbWF0Y2hlZFByaW50ZXJzLkNvdW50KWByYG5FxZ9sZcWfZW4gc8O8csO8Y8O8OiAkKCRt
YXRjaGVkRHJpdmVycy5Db3VudClgcmBuRcWfbGXFn2VuIHBvcnQ6ICQoJG1hdGNoZWRQb3J0cy5D
b3VudCkiCiAgICBpZiAoJG1hdGNoZWRQcmludGVycy5Db3VudCAtZ3QgMCkgewogICAgICAgICRw
cmV2aWV3ICs9ICJgcmBuYHJgbkthbGTEsXLEsWxhY2FrIHlhesSxY8SxbGFyOmByYG4iICsgKCgk
bWF0Y2hlZFByaW50ZXJzIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMTIgfCBGb3JFYWNoLU9iamVj
dCB7ICItICQoJF8uTmFtZSkgLyAkKCRfLkRyaXZlck5hbWUpIiB9KSAtam9pbiAiYHJgbiIpCiAg
ICB9CiAgICAkYW5zd2VyMiA9IFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdlQm94XTo6U2hv
dygiJHByZXZpZXdgcmBuYHJgbkJ1IGnFn2xlbSBzZcOnaWxlbiBtYXJrYS9tb2RlbCB5YXrEsWPE
sWxhcsSxIHZlIHPDvHLDvGPDvCBpemxlcmluaSBkYWhhIMO2bmNlIGt1cnVsbWFtxLHFnyBnaWJp
IHRlbWl6bGVtZXllIMOnYWzEscWfxLFyLiBEZXZhbSBlZGlsc2luIG1pPyIsIkRyaXZlci9ZYXrE
sWPEsSBUZW1pemxpxJ9pIMOWbiBUYXJhbWEiLFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdl
Qm94QnV0dG9uc106Olllc05vLFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdlQm94SWNvbl06
Oldhcm5pbmcpCiAgICBpZiAoJGFuc3dlcjIgLW5lIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5EaWFs
b2dSZXN1bHRdOjpZZXMpIHsgV0FSTiAiRHJpdmVyIHRlbWl6bGnEn2kgw7ZuIHRhcmFtYSBzb25y
YXPEsSBpcHRhbCBlZGlsZGkiOyByZXR1cm4gfQoKICAgIHRyeSB7IFN0b3AtU2VydmljZSBTcG9v
bGVyIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9IGNhdGNoIHt9CiAgICBT
dGFydC1TbGVlcCAtU2Vjb25kcyAxCiAgICB0cnkgeyBTdGFydC1TZXJ2aWNlIFNwb29sZXIgLUVy
cm9yQWN0aW9uIFNpbGVudGx5Q29udGludWU7IFN0YXJ0LVNsZWVwIC1TZWNvbmRzIDEgfSBjYXRj
aCB7fQoKICAgIHRyeSB7CiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJG1hdGNoZWRQcmludGVycykg
ewogICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgaWYgKCRwLk5hbWUgLW1hdGNoICJe
XFxcXCIpIHsgcnVuZGxsMzIgcHJpbnR1aS5kbGwsUHJpbnRVSUVudHJ5IC9kbiAvbiAiJCgkcC5O
YW1lKSIgL3EgfQogICAgICAgICAgICAgICAgUmVtb3ZlLVByaW50ZXIgLU5hbWUgJHAuTmFtZSAt
RXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICAgICAgICAgT0sgIllhesSxY8Sx
L2JhxJ9sYW50xLEga2FsZMSxcsSxbGTEsTogJCgkcC5OYW1lKSIKICAgICAgICAgICAgfSBjYXRj
aCB7IFdBUk4gIllhesSxY8SxIGthbGTEsXLEsWxhbWFkxLE6ICQoJHAuTmFtZSkgLSAkXyIgfQog
ICAgICAgIH0KICAgIH0gY2F0Y2ggeyBXQVJOICJZYXrEsWPEsSBrYWxkxLFybWEgdGFyYW1hc8Sx
IGJhxZ9hcsSxc8SxejogJF8iIH0KCiAgICB0cnkgewogICAgICAgIGZvcmVhY2ggKCRkIGluICRt
YXRjaGVkRHJpdmVycykgewogICAgICAgICAgICB0cnkgeyBSZW1vdmUtUHJpbnRlckRyaXZlciAt
TmFtZSAkZC5OYW1lIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlOyBPSyAiUHJpbnRlciBk
cml2ZXIga2FsZMSxcm1hIGRlbmVuZGk6ICQoJGQuTmFtZSkiIH0gY2F0Y2ggeyBXQVJOICJQcmlu
dGVyIGRyaXZlciBrYWxkxLFyxLFsYW1hZMSxOiAkKCRkLk5hbWUpIC0gJF8iIH0KICAgICAgICB9
CiAgICB9IGNhdGNoIHsgV0FSTiAiRHJpdmVyIHRlbWl6bGnEn2kgYmHFn2FyxLFzxLF6OiAkXyIg
fQoKICAgIHRyeSB7CiAgICAgICAgZm9yZWFjaCAoJHBvcnQgaW4gJG1hdGNoZWRQb3J0cykgewog
ICAgICAgICAgICB0cnkgeyBSZW1vdmUtUHJpbnRlclBvcnQgLU5hbWUgJHBvcnQuTmFtZSAtRXJy
b3JBY3Rpb24gU2lsZW50bHlDb250aW51ZTsgT0sgIlByaW50ZXIgcG9ydCBrYWxkxLFybWEgZGVu
ZW5kaTogJCgkcG9ydC5OYW1lKSIgfSBjYXRjaCB7IFdBUk4gIlBvcnQga2FsZMSxcsSxbGFtYWTE
sTogJCgkcG9ydC5OYW1lKSAtICRfIiB9CiAgICAgICAgfQogICAgfSBjYXRjaCB7IFdBUk4gIlBv
cnQgdGVtaXpsacSfaSBiYcWfYXLEsXPEsXo6ICRfIiB9CgogICAgaWYgKC1ub3QgW3N0cmluZ106
OklzTnVsbE9yV2hpdGVTcGFjZSgkZmlsdGVyKSkgewogICAgICAgIGZvcmVhY2ggKCRyZWdQYXRo
IGluIEAoIkhLQ1U6XFByaW50ZXJzXENvbm5lY3Rpb25zIiwiSEtDVTpcU29mdHdhcmVcTWljcm9z
b2Z0XFdpbmRvd3MgTlRcQ3VycmVudFZlcnNpb25cRGV2aWNlcyIsIkhLQ1U6XFNvZnR3YXJlXE1p
Y3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRWZXJzaW9uXFByaW50ZXJQb3J0cyIpKSB7CiAgICAg
ICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRyZWdQYXRoKSB7CiAg
ICAgICAgICAgICAgICAgICAgR2V0LUNoaWxkSXRlbSAtUGF0aCAkcmVnUGF0aCAtRXJyb3JBY3Rp
b24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJlLU9iamVjdCB7ICRfLlBTQ2hpbGROYW1lIC1saWtl
ICIqJGZpbHRlcioiIH0gfCBGb3JFYWNoLU9iamVjdCB7CiAgICAgICAgICAgICAgICAgICAgICAg
IFJlbW92ZS1JdGVtIC1QYXRoICRfLlBTUGF0aCAtUmVjdXJzZSAtRm9yY2UgLUVycm9yQWN0aW9u
IFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgICAgICAgICAgICAgT0sgIkt1bGxhbsSxY8Sx
IHlhesSxY8SxIHJlZ2lzdHJ5IGl6aSB0ZW1pemxlbmRpOiAkKCRfLlBTQ2hpbGROYW1lKSIKICAg
ICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0gY2F0Y2gg
eyBXQVJOICJSZWdpc3RyeSBpeiB0ZW1pemxpxJ9pIGJhxZ9hcsSxc8SxejogJHJlZ1BhdGggLSAk
XyIgfQogICAgICAgIH0KICAgIH0KCiAgICBpZiAoLW5vdCBbc3RyaW5nXTo6SXNOdWxsT3JXaGl0
ZVNwYWNlKCRmaWx0ZXIpKSB7CiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHBucHV0aWwgPSAi
JGVudjpTeXN0ZW1Sb290XFN5c3RlbTMyXHBucHV0aWwuZXhlIgogICAgICAgICAgICBpZiAoVGVz
dC1QYXRoICRwbnB1dGlsKSB7CiAgICAgICAgICAgICAgICAkZmlsdGVyUmVnZXggPSBbcmVnZXhd
OjpFc2NhcGUoJGZpbHRlcikKICAgICAgICAgICAgICAgICRlbnVtID0gJiAkcG5wdXRpbCAvZW51
bS1kcml2ZXJzIDI+JjEKICAgICAgICAgICAgICAgICRibG9ja3MgPSAoKCRlbnVtIC1qb2luICJg
biIpIC1zcGxpdCAiKFxyP1xuKXsyLH0iKSB8IFdoZXJlLU9iamVjdCB7ICRfIC1tYXRjaCAkZmls
dGVyUmVnZXggfQogICAgICAgICAgICAgICAgZm9yZWFjaCAoJGJsb2NrIGluICRibG9ja3MpIHsK
ICAgICAgICAgICAgICAgICAgICAkaW5mID0gIiIKICAgICAgICAgICAgICAgICAgICBpZiAoJGJs
b2NrIC1tYXRjaCAiUHVibGlzaGVkIE5hbWVccyo6XHMqKG9lbVxkK1wuaW5mKSIpIHsgJGluZiA9
ICRNYXRjaGVzWzFdIH0KICAgICAgICAgICAgICAgICAgICBlbHNlaWYgKCRibG9jayAtbWF0Y2gg
IllhecSxbWxhbmFuIEFkXHMqOlxzKihvZW1cZCtcLmluZikiKSB7ICRpbmYgPSAkTWF0Y2hlc1sx
XSB9CiAgICAgICAgICAgICAgICAgICAgaWYgKCRpbmYpIHsKICAgICAgICAgICAgICAgICAgICAg
ICAgJiAkcG5wdXRpbCAvZGVsZXRlLWRyaXZlciAkaW5mIC91bmluc3RhbGwgL2ZvcmNlIDI+JjEg
fCBGb3JFYWNoLU9iamVjdCB7IFdyaXRlLUxvZyAiUE5QVVRJTDogJF8iIH0KICAgICAgICAgICAg
ICAgICAgICAgICAgT0sgIlBuUCBkcml2ZXIgcGFrZXRpIGthbGTEsXJtYSBkZW5lbmRpOiAkaW5m
IgogICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQog
ICAgICAgIH0gY2F0Y2ggeyBXQVJOICJQblAgZHJpdmVyIHBha2V0aSB0ZW1pemxpxJ9pIGJhxZ9h
csSxc8SxejogJF8iIH0KICAgIH0KCiAgICB0cnkgewogICAgICAgICRzcG9vbFBhdGggPSAiJGVu
djpTeXN0ZW1Sb290XFN5c3RlbTMyXHNwb29sXFBSSU5URVJTIgogICAgICAgIEdldC1DaGlsZEl0
ZW0gLVBhdGggJHNwb29sUGF0aCAtSW5jbHVkZSAiKi5zcGwiLCIqLnNoZCIgLVJlY3Vyc2UgLUVy
cm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBSZW1vdmUtSXRlbSAtRm9yY2UgLUVycm9yQWN0
aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICBPSyAiU3Bvb2wga3V5cnVrIGRvc3lhbGFyxLEg
dGVtaXpsZW5kaSIKICAgIH0gY2F0Y2ggeyBXQVJOICJTcG9vbCB0ZW1pemxpxJ9pIGJhxZ9hcsSx
c8SxejogJF8iIH0KCiAgICB0cnkgeyBTdGFydC1TZXJ2aWNlIFNwb29sZXIgLUVycm9yQWN0aW9u
IFNpbGVudGx5Q29udGludWUgfSBjYXRjaCB7fQogICAgT0sgIkRyaXZlciBjYWNoZSB0ZW1pemxp
xJ9pIHRhbWFtbGFuZMSxIgp9CmZ1bmN0aW9uIEFwcGx5LVNlbGVjdGVkRml4ZXMgewogICAgcGFy
YW0oW3N0cmluZ10kUm9sZUxhYmVsKQogICAgaWYgKC1ub3QgKEVuc3VyZS1BdExlYXN0T25lRml4
U2VsZWN0ZWQpKSB7IHJldHVybiB9CiAgICBOZXctQmFja3VwU25hcHNob3QgLVJlYXNvbiAiQmVm
b3JlX1NlbGVjdGVkX0ZpeGVzIiB8IE91dC1OdWxsCiAgICBXcml0ZS1Mb2cgIj09PSBTRcOHxLBM
xLAgRklYIEFLScWeSSBCQcWeTEFESSB8IFJvbDogJFJvbGVMYWJlbCA9PT0iCiAgICBpZiAoJGNo
a0ZpeFJwYy5DaGVja2VkKSB7IEFwcGx5LVJQQy1QcmludGVyQ29yZSB9IGVsc2UgeyBXQVJOICJS
UEMvMTFiIGZpeCBzZcOnaWxpIGRlxJ9pbCwgYXRsYW5kxLEiIH0KICAgIGlmICgkY2hrRml4UG9p
bnQuQ2hlY2tlZCAtYW5kICRSb2xlTGFiZWwgLW5lICJIb3N0IikgeyBBcHBseS1Qb2ludEFuZFBy
aW50IH0gZWxzZWlmICgkY2hrRml4UG9pbnQuQ2hlY2tlZCkgeyBXQVJOICJQb2ludCZQcmludCBn
ZW5lbGxpa2xlIGNsaWVudCBmaXg7IEhvc3Qgcm9sw7xuZGUgYXRsYW5kxLEiIH0gZWxzZSB7IFdB
Uk4gIlBvaW50JlByaW50LzcwOSBmaXggc2XDp2lsaSBkZcSfaWwsIGF0bGFuZMSxIiB9CiAgICBp
ZiAoJGNoa0ZpeFNtYi5DaGVja2VkKSB7IEFwcGx5LVNNQi1Db21wYXRpYmlsaXR5IH0gZWxzZSB7
IFdBUk4gIlNNQi9HdWVzdCBmaXggc2XDp2lsaSBkZcSfaWwsIGF0bGFuZMSxIiB9CiAgICBpZiAo
JGNoa0ZpeEZpcmV3YWxsLkNoZWNrZWQpIHsgRW5hYmxlLU5ldHdvcmtQcm9maWxlUHJpdmF0ZTsg
RW5hYmxlLVByaW50ZXJGaXJld2FsbCB9IGVsc2UgeyBXQVJOICJGaXJld2FsbC9EaXNjb3Zlcnkg
Zml4IHNlw6dpbGkgZGXEn2lsLCBhdGxhbmTEsSIgfQogICAgaWYgKCRjaGtGaXhTZXJ2aWNlcy5D
aGVja2VkKSB7IEVuc3VyZS1TZXJ2aWNlcyB9IGVsc2UgeyBXQVJOICJTZXJ2aXMgZml4IHNlw6dp
bGkgZGXEn2lsLCBhdGxhbmTEsSIgfQogICAgaWYgKCRjaGtGaXhTcG9vbGVyLkNoZWNrZWQpIHsg
UmVzZXQtU3Bvb2xlciB9IGVsc2UgeyBXQVJOICJTcG9vbGVyIHJlc2V0IHNlw6dpbGkgZGXEn2ls
LCBhdGxhbmTEsSIgfQogICAgaWYgKCRjaGtGaXhOdGxtLkNoZWNrZWQpIHsgQXBwbHktTlRMTS1O
ZXRCSU9TIH0gZWxzZSB7IFdBUk4gIk5UTE0vTmV0QklPUyBmaXggc2XDp2lsaSBkZcSfaWwsIGF0
bGFuZMSxIiB9CiAgICBpZiAoJGNoa0ZpeENyZWRlbnRpYWwuQ2hlY2tlZCAtYW5kICRSb2xlTGFi
ZWwgLW5lICJIb3N0IikgeyBBcHBseS1DcmVkZW50aWFsQ2xlYW51cCB9IGVsc2VpZiAoJGNoa0Zp
eENyZWRlbnRpYWwuQ2hlY2tlZCkgeyBXQVJOICJDcmVkZW50aWFsIHRlbWl6bGnEn2kgSG9zdCBy
b2zDvG5kZSBhdGxhbmTEsSIgfSBlbHNlIHsgV0FSTiAiQ3JlZGVudGlhbCB0ZW1pemxpxJ9pIHNl
w6dpbGkgZGXEn2lsLCBhdGxhbmTEsSIgfQogICAgaWYgKCRjaGtGaXhEcml2ZXIuQ2hlY2tlZCAt
YW5kICRSb2xlTGFiZWwgLW5lICJIb3N0IikgeyBBcHBseS1Ecml2ZXJDYWNoZUNsZWFudXAgfSBl
bHNlaWYgKCRjaGtGaXhEcml2ZXIuQ2hlY2tlZCkgeyBXQVJOICJEcml2ZXIgdGVtaXpsacSfaSBI
b3N0IHJvbMO8bmRlIGF0bGFuZMSxIiB9IGVsc2UgeyBXQVJOICJEcml2ZXIgdGVtaXpsacSfaSBz
ZcOnaWxpIGRlxJ9pbCwgYXRsYW5kxLEiIH0KICAgIGlmICgkY2hrRml4V29ya2dyb3VwIC1hbmQg
JGNoa0ZpeFdvcmtncm91cC5DaGVja2VkKSB7IEFwcGx5LVdvcmtncm91cENvbXBhdGliaWxpdHlG
aXggfSBlbHNlIHsgV0FSTiAiV29ya2dyb3VwIGTDvHplbHRtZXNpIHNlw6dpbGkgZGXEn2lsLCBh
dGxhbmTEsSIgfQogICAgSW52b2tlLUdQVXBkYXRlU2FmZQogICAgV3JpdGUtTG9nICI9PT0gU0XD
h8SwTMSwIEZJWCBBS0nFnkkgQsSwVFTEsCA9PT0iICJPSyIKfQpmdW5jdGlvbiBSdW4tQXV0b0Zp
eCB7CiAgICAkcm9sZSA9IEdldC1TZWxlY3RlZFJvbGUKICAgIFdyaXRlLUxvZyAiU2XDp2lsaS9B
bGfEsWxhbmFuIHJvbDogJHJvbGUiCiAgICBBcHBseS1TZWxlY3RlZEZpeGVzIC1Sb2xlTGFiZWwg
JHJvbGUKICAgIFNob3ctSW5mbyAixLDFn2xlbSBUYW1hbWxhbmTEsSIgIlNlw6dpbGkgZMO8emVs
dG1lIGFrxLHFn8SxIHRhbWFtbGFuZMSxLmByYG5Sb2w6ICRyb2xlYHJgbkxvZzogJHNjcmlwdDpM
b2dGaWxlIgp9CgojIC0tLS0tLS0tLS0gRklOREVSIC8gQ09OTkVDVCAtLS0tLS0tLS0tCmZ1bmN0
aW9uIENsZWFyLUZvdW5kIHsKICAgICRzY3JpcHQ6Rm91bmRJdGVtcy5DbGVhcigpCiAgICBpZiAo
JGdyaWRQcmludGVycykgeyAkZ3JpZFByaW50ZXJzLlJvd3MuQ2xlYXIoKSB9Cn0KZnVuY3Rpb24g
QWRkLUZvdW5kSXRlbSB7CiAgICBwYXJhbShbc3RyaW5nXSRUeXBlLFtzdHJpbmddJE5hbWUsW3N0
cmluZ10kU2hhcmVOYW1lLFtzdHJpbmddJFVOQyxbc3RyaW5nXSREcml2ZXIsW3N0cmluZ10kU291
cmNlLFtzdHJpbmddJE5vdGUpCiAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgk
VU5DKSkgeyByZXR1cm4gfQogICAgZm9yZWFjaCAoJGkgaW4gJHNjcmlwdDpGb3VuZEl0ZW1zKSB7
IGlmICgkaS5VTkMgLWVxICRVTkMpIHsgcmV0dXJuIH0gfQogICAgJG9iaiA9IFtQU0N1c3RvbU9i
amVjdF1Ae1R5cGU9JFR5cGU7IE5hbWU9JE5hbWU7IFNoYXJlTmFtZT0kU2hhcmVOYW1lOyBVTkM9
JFVOQzsgRHJpdmVyPSREcml2ZXI7IFNvdXJjZT0kU291cmNlOyBOb3RlPSROb3RlfQogICAgJHNj
cmlwdDpGb3VuZEl0ZW1zLkFkZCgkb2JqKSB8IE91dC1OdWxsCiAgICBpZiAoJGdyaWRQcmludGVy
cykgeyBbdm9pZF0kZ3JpZFByaW50ZXJzLlJvd3MuQWRkKCRUeXBlLCROYW1lLCRTaGFyZU5hbWUs
JFVOQywkRHJpdmVyLCRTb3VyY2UsJE5vdGUpIH0KfQpmdW5jdGlvbiBSZXNldC1QcmludGVyR3Jp
ZFZpZXcgewogICAgdHJ5IHsKICAgICAgICBpZiAoJGdyaWRQcmludGVycyAtYW5kICRncmlkUHJp
bnRlcnMuUm93cy5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAkZ3JpZFByaW50ZXJzLkNsZWFy
U2VsZWN0aW9uKCkKICAgICAgICAgICAgJGdyaWRQcmludGVycy5GaXJzdERpc3BsYXllZFNjcm9s
bGluZ1Jvd0luZGV4ID0gMAogICAgICAgICAgICAkZ3JpZFByaW50ZXJzLlJvd3NbMF0uU2VsZWN0
ZWQgPSAkdHJ1ZQogICAgICAgICAgICAkZ3JpZFByaW50ZXJzLkN1cnJlbnRDZWxsID0gJGdyaWRQ
cmludGVycy5Sb3dzWzBdLkNlbGxzWzFdCiAgICAgICAgfQogICAgfSBjYXRjaCB7fQp9CmZ1bmN0
aW9uIFRlc3QtSXNWaXJ0dWFsUHJpbnRlciB7CiAgICBwYXJhbShbc3RyaW5nXSROYW1lLFtzdHJp
bmddJERyaXZlcixbc3RyaW5nXSRQb3J0KQogICAgJHRleHQgPSAoInswfSB7MX0gezJ9IiAtZiAk
TmFtZSwkRHJpdmVyLCRQb3J0KS5Ub0xvd2VySW52YXJpYW50KCkKICAgIHJldHVybiAoJHRleHQg
LW1hdGNoICJtaWNyb3NvZnQgcHJpbnQgdG8gcGRmfG1pY3Jvc29mdCB4cHMgZG9jdW1lbnQgd3Jp
dGVyfG9uZW5vdGV8c2VuZCB0byBtaWNyb3NvZnQgb25lbm90ZXxzaGFyZWQgZmF4fFxcYmZheFxc
Ynxwb3J0cHJvbXB0OnxudWw6IikKfQpmdW5jdGlvbiBTY2FuLUNpbVByaW50ZXJzIHsKICAgIHBh
cmFtKFtzdHJpbmddJFNlcnZlcikKICAgIFdyaXRlLUxvZyAiQ0lNL1dNSSB5YXrEsWPEsSB0YXJh
bWFzxLE6ICRTZXJ2ZXIiCiAgICB0cnkgewogICAgICAgICRwcmludGVycyA9IEdldC1DaW1JbnN0
YW5jZSAtQ2xhc3NOYW1lIFdpbjMyX1ByaW50ZXIgLUNvbXB1dGVyTmFtZSAkU2VydmVyIC1FcnJv
ckFjdGlvbiBTdG9wCiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJHByaW50ZXJzKSB7CiAgICAgICAg
ICAgICRpc1ZpcnR1YWwgPSBUZXN0LUlzVmlydHVhbFByaW50ZXIgIiQoJHAuTmFtZSkiICIkKCRw
LkRyaXZlck5hbWUpIiAiJCgkcC5Qb3J0TmFtZSkiCiAgICAgICAgICAgIGlmICgkcC5TaGFyZWQg
LWVxICR0cnVlIC1hbmQgLW5vdCBbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRwLlNoYXJl
TmFtZSkpIHsKICAgICAgICAgICAgICAgICR0eXBlID0gaWYgKCRpc1ZpcnR1YWwpIHsgIlNhbmFs
L1Npc3RlbSBZYXrEsWPEsSIgfSBlbHNlIHsgIlByaW50ZXIiIH0KICAgICAgICAgICAgICAgICRu
b3RlID0gaWYgKCRpc1ZpcnR1YWwpIHsgIlNhbmFsL3Npc3RlbSB5YXrEsWPEsXPEsTsgU2hhcmVk
PVRydWUiIH0gZWxzZSB7ICJTaGFyZWQ9VHJ1ZSIgfQogICAgICAgICAgICAgICAgQWRkLUZvdW5k
SXRlbSAkdHlwZSAiJCgkcC5OYW1lKSIgIiQoJHAuU2hhcmVOYW1lKSIgIlxcJFNlcnZlclwkKCRw
LlNoYXJlTmFtZSkiICIkKCRwLkRyaXZlck5hbWUpIiAiQ0lNIiAkbm90ZQogICAgICAgICAgICB9
IGVsc2UgewogICAgICAgICAgICAgICAgJHNhZmVOYW1lID0gIiQoJHAuTmFtZSkiIC1yZXBsYWNl
ICdbXFwvOio/Ijw+fF0nLCAnXycKICAgICAgICAgICAgICAgICRwc2V1ZG9QYXRoID0gInVuc2hh
cmVkOiQoJFNlcnZlcik6JHNhZmVOYW1lIgogICAgICAgICAgICAgICAgJHR5cGUgPSBpZiAoJGlz
VmlydHVhbCkgeyAiU2FuYWwvU2lzdGVtIFlhesSxY8SxIiB9IGVsc2UgeyAiVXphayBZYXrEsWPE
sSAoUGF5bGHFn8SxbG1hbcSxxZ8pIiB9CiAgICAgICAgICAgICAgICAkbm90ZSA9ICJQYXlsYcWf
xLFtIHlvazsgUG9ydD0kKCRwLlBvcnROYW1lKTsgU2hhcmVkPSQoJHAuU2hhcmVkKTsgU2hhcmVO
YW1lPSQoJHAuU2hhcmVOYW1lKSIKICAgICAgICAgICAgICAgIGlmICgkaXNWaXJ0dWFsKSB7ICRu
b3RlID0gIlNhbmFsL3Npc3RlbSB5YXrEsWPEsXPEsTsgJG5vdGUiIH0KICAgICAgICAgICAgICAg
IEFkZC1Gb3VuZEl0ZW0gJHR5cGUgIiQoJHAuTmFtZSkiICIkKCRwLlNoYXJlTmFtZSkiICRwc2V1
ZG9QYXRoICIkKCRwLkRyaXZlck5hbWUpIiAiQ0lNIiAkbm90ZQogICAgICAgICAgICAgICAgV3Jp
dGUtTG9nICJDSU0gdXphayB5YXrEsWPEsSBsaXN0ZWxlbmRpIGFtYSBwYXlsYcWfxLFsbWFtxLHF
nzogJCgkcC5OYW1lKSB8IFNoYXJlZD0kKCRwLlNoYXJlZCkgfCBTaGFyZU5hbWU9JCgkcC5TaGFy
ZU5hbWUpIgogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgIE9LICJDSU0geWF6xLFjxLEg
dGFyYW1hc8SxIHRhbWFtbGFuZMSxIgogICAgfSBjYXRjaCB7IFdBUk4gIkNJTS9XTUkgdGFyYW1h
c8SxIGJhxZ9hcsSxc8SxejogJF8iIH0KfQpmdW5jdGlvbiBHZXQtTmV0Vmlld0l0ZW1zU2FmZSB7
CiAgICBwYXJhbShbc3RyaW5nXSRTZXJ2ZXIpCiAgICAkaXRlbXMgPSBOZXctT2JqZWN0IFN5c3Rl
bS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbb2JqZWN0XQogICAgdHJ5IHsKICAgICAgICAkb3V0
ID0gY21kIC9jICJuZXQgdmlldyBcXCRTZXJ2ZXIiIDI+JjEKICAgICAgICAkY2FwdHVyZSA9ICRm
YWxzZQogICAgICAgIGZvcmVhY2ggKCRsaW5lIGluICRvdXQpIHsKICAgICAgICAgICAgV3JpdGUt
TG9nICJORVRWSUVXOiAkbGluZSIKICAgICAgICAgICAgJHRyaW0gPSAoW3N0cmluZ10kbGluZSku
VHJpbSgpCiAgICAgICAgICAgIGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCR0cmlt
KSkgeyBjb250aW51ZSB9CiAgICAgICAgICAgIGlmICgkdHJpbSAtbWF0Y2ggJ14tezMsfScpIHsg
JGNhcHR1cmUgPSAkdHJ1ZTsgY29udGludWUgfQogICAgICAgICAgICBpZiAoJHRyaW0gLW1hdGNo
ICdrb211dC4qdGFtYW1sYW58Y29tbWFuZCBjb21wbGV0ZWQgc3VjY2Vzc2Z1bGx5JykgeyBicmVh
ayB9CiAgICAgICAgICAgIGlmICgkY2FwdHVyZSkgewogICAgICAgICAgICAgICAgaWYgKCR0cmlt
IC1tYXRjaCAnXiguKj8pXHMrKERpc2t8UHJpbnR8WWF6XFMqcilccyooLiopJCcpIHsKICAgICAg
ICAgICAgICAgICAgICAkc2hhcmUgPSAoJG1hdGNoZXNbMV0pLlRyaW0oKQogICAgICAgICAgICAg
ICAgICAgICR0eXBlID0gKCRtYXRjaGVzWzJdKS5UcmltKCkKICAgICAgICAgICAgICAgICAgICAk
bm90ZSA9ICgkbWF0Y2hlc1szXSkuVHJpbSgpCiAgICAgICAgICAgICAgICAgICAgaWYgKC1ub3Qg
W3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkc2hhcmUpKSB7CiAgICAgICAgICAgICAgICAg
ICAgICAgICRpdGVtcy5BZGQoW1BTQ3VzdG9tT2JqZWN0XUB7U2hhcmU9JHNoYXJlO1R5cGU9JHR5
cGU7Tm90ZT0kbm90ZTtVTkM9IlxcJFNlcnZlclwkc2hhcmUifSkgfCBPdXQtTnVsbAogICAgICAg
ICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgIH0K
ICAgIH0gY2F0Y2ggeyBXQVJOICJORVQgVklFVyBzYWZlIHBhcnNlciBoYXRhc8SxOiAkXyIgfQog
ICAgcmV0dXJuICRpdGVtcwp9CmZ1bmN0aW9uIFNjYW4tTmV0Vmlld1NoYXJlcyB7CiAgICBwYXJh
bShbc3RyaW5nXSRTZXJ2ZXIpCiAgICBXcml0ZS1Mb2cgIk5FVCBWSUVXIHBheWxhxZ/EsW0gdGFy
YW1hc8SxOiBcXCRTZXJ2ZXIiCiAgICB0cnkgewogICAgICAgICRpdGVtcyA9IEdldC1OZXRWaWV3
SXRlbXNTYWZlIC1TZXJ2ZXIgJFNlcnZlcgogICAgICAgICRwcmludGVySXRlbXMgPSBAKCRpdGVt
cyB8IFdoZXJlLU9iamVjdCB7ICIkKCRfLlR5cGUpIiAtbm90bWF0Y2ggJ15EaXNrJCcgfSkKICAg
ICAgICBmb3JlYWNoICgkaXQgaW4gJHByaW50ZXJJdGVtcykgewogICAgICAgICAgICBBZGQtRm91
bmRJdGVtICJQcmludGVyIiAkaXQuU2hhcmUgJGl0LlNoYXJlICRpdC5VTkMgIiIgIm5ldCB2aWV3
IiAkaXQuTm90ZQogICAgICAgIH0KICAgICAgICBPSyAiTkVUIFZJRVcgdGFyYW1hc8SxIHRhbWFt
bGFuZMSxLiBZYXrEsWPEsTogJCgkcHJpbnRlckl0ZW1zLkNvdW50KSwgZGnEn2VyIHBheWxhxZ/E
sW06ICQoJGl0ZW1zLkNvdW50IC0gJHByaW50ZXJJdGVtcy5Db3VudCkiCiAgICB9IGNhdGNoIHsg
V0FSTiAiTkVUIFZJRVcgdGFyYW1hc8SxIGJhxZ9hcsSxc8SxejogJF8iIH0KfQoKZnVuY3Rpb24g
U2Nhbi1Mb2NhbFByaW50ZXJzIHsKICAgIFdyaXRlLUxvZyAiWWVyZWwgeWF6xLFjxLEgdGFyYW1h
c8SxIGJhxZ9sYWTEsS4uLiIKICAgIHRyeSB7CiAgICAgICAgJHByaW50ZXJzID0gR2V0LVByaW50
ZXIgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICAkdmlzaWJsZUNvdW50ID0gMAogICAgICAgIGZv
cmVhY2ggKCRwIGluICRwcmludGVycykgewogICAgICAgICAgICAkaXNWaXJ0dWFsID0gVGVzdC1J
c1ZpcnR1YWxQcmludGVyICIkKCRwLk5hbWUpIiAiJCgkcC5Ecml2ZXJOYW1lKSIgIiQoJHAuUG9y
dE5hbWUpIgogICAgICAgICAgICAkdHlwZSA9IGlmICgkaXNWaXJ0dWFsKSB7ICJTYW5hbC9TaXN0
ZW0gWWF6xLFjxLEiIH0gZWxzZWlmICgkcC5Qb3J0TmFtZSAtbWF0Y2ggIl5cXFxcIiAtb3IgJHAu
TmFtZSAtbWF0Y2ggIl5cXFxcIikgeyAiQcSfIEJhxJ9sYW50xLFzxLEiIH0gZWxzZSB7ICJZZXJl
bCBZYXrEsWPEsSIgfQogICAgICAgICAgICAkdW5jID0gIiIKICAgICAgICAgICAgaWYgKCRwLlNo
YXJlZCAtZXEgJHRydWUgLWFuZCAtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHAu
U2hhcmVOYW1lKSkgewogICAgICAgICAgICAgICAgJHVuYyA9ICJcXCRlbnY6Q09NUFVURVJOQU1F
XCQoJHAuU2hhcmVOYW1lKSIKICAgICAgICAgICAgfSBlbHNlaWYgKCRwLlBvcnROYW1lIC1tYXRj
aCAiXlxcXFwiKSB7CiAgICAgICAgICAgICAgICAkdW5jID0gIiQoJHAuUG9ydE5hbWUpIgogICAg
ICAgICAgICB9IGVsc2VpZiAoJHAuTmFtZSAtbWF0Y2ggIl5cXFxcIikgewogICAgICAgICAgICAg
ICAgJHVuYyA9ICIkKCRwLk5hbWUpIgogICAgICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAg
ICAgJHVuYyA9ICJsb2NhbDokKCRwLk5hbWUpIgogICAgICAgICAgICB9CiAgICAgICAgICAgICRu
b3RlID0gIlBvcnQ9JCgkcC5Qb3J0TmFtZSk7IFNoYXJlZD0kKCRwLlNoYXJlZCk7IFZhcnNhecSx
bGFuPSQoJHAuRGVmYXVsdCkiCiAgICAgICAgICAgIGlmICgkaXNWaXJ0dWFsKSB7ICRub3RlID0g
IlNhbmFsL3Npc3RlbSB5YXrEsWPEsXPEsTsgJG5vdGUiIH0KICAgICAgICAgICAgQWRkLUZvdW5k
SXRlbSAkdHlwZSAiJCgkcC5OYW1lKSIgIiQoJHAuU2hhcmVOYW1lKSIgJHVuYyAiJCgkcC5Ecml2
ZXJOYW1lKSIgIlllcmVsIiAkbm90ZQogICAgICAgICAgICAkdmlzaWJsZUNvdW50KysKICAgICAg
ICB9CiAgICAgICAgT0sgIlllcmVsIHlhesSxY8SxIHRhcmFtYXPEsSB0YW1hbWxhbmTEsS4gR8O2
c3RlcmlsZW46ICR2aXNpYmxlQ291bnQgLyBUb3BsYW0gYXlnxLF0OiAkKEAoJHByaW50ZXJzKS5D
b3VudCkiCiAgICB9IGNhdGNoIHsgV0FSTiAiWWVyZWwgeWF6xLFjxLEgdGFyYW1hc8SxIGJhxZ9h
csSxc8SxejogJF8iIH0KfQoKZnVuY3Rpb24gU2Nhbi1Mb2NhbFByaW50ZXJzT25seSB7CiAgICBD
bGVhci1Gb3VuZAogICAgV3JpdGUtTG9nICJCdSBQQyB5YXrEsWPEsSBsaXN0ZXNpIGlzdGVuaXlv
ci4iCiAgICBTY2FuLUxvY2FsUHJpbnRlcnMKICAgIGlmICgkc2NyaXB0OkZvdW5kSXRlbXMuQ291
bnQgLWVxIDApIHsgU2hvdy1XYXJuICJTb251w6cgWW9rIiAiQnUgYmlsZ2lzYXlhcmRhIHlhesSx
Y8SxIGF5Z8SxdMSxIGJ1bHVuYW1hZMSxLiIgfQogICAgZWxzZSB7IFJlc2V0LVByaW50ZXJHcmlk
VmlldzsgT0sgIkJ1IFBDIHlhesSxY8SxIGxpc3Rlc2kgaGF6xLFyLiBHw7ZzdGVyaWxlbjogJCgk
c2NyaXB0OkZvdW5kSXRlbXMuQ291bnQpIiB9Cn0KCmZ1bmN0aW9uIFNjYW4tUHJpbnRlcnNVbmlm
aWVkIHsKICAgIENsZWFyLUZvdW5kCiAgICBXcml0ZS1Mb2cgIkJpcmxlxZ9payB5YXrEsWPEsSB0
YXJhbWFzxLEgYmHFn2xhZMSxLiIKICAgIFNjYW4tTG9jYWxQcmludGVycwogICAgJHNlcnZlciA9
ICR0eHRSZW1vdGVQYy5UZXh0LlRyaW0oKQogICAgaWYgKC1ub3QgW3N0cmluZ106OklzTnVsbE9y
V2hpdGVTcGFjZSgkc2VydmVyKSkgewogICAgICAgIFdyaXRlLUxvZyAiVXphayBQQyB5YXrEsWPE
sS9wYXlsYcWfxLFtIHRhcmFtYXPEsSBiYcWfbGFkxLE6ICRzZXJ2ZXIiCiAgICAgICAgaWYgKCRj
aGtBdXRvRml4QmVmb3JlU2Nhbi5DaGVja2VkKSB7IEFwcGx5LVNlbGVjdGVkRml4ZXMgLVJvbGVM
YWJlbCAiQ2xpZW50IiB9CiAgICAgICAgUnVuLVJlbW90ZURpYWdub3NpcwogICAgICAgIFNjYW4t
Q2ltUHJpbnRlcnMgJHNlcnZlcgogICAgICAgIFNjYW4tTmV0Vmlld1NoYXJlcyAkc2VydmVyCiAg
ICB9IGVsc2UgewogICAgICAgIFdBUk4gIlBDL0lQIGJvxZ87IHNhZGVjZSB5ZXJlbCB5YXrEsWPE
sWxhciB0YXJhbmTEsS4iCiAgICB9CiAgICBpZiAoJHNjcmlwdDpGb3VuZEl0ZW1zLkNvdW50IC1l
cSAwKSB7IFNob3ctV2FybiAiU29udcOnIFlvayIgIlllcmVsIHZleWEgdXphayB5YXrEsWPEsSBi
dWx1bmFtYWTEsS4iIH0KICAgIGVsc2UgeyBSZXNldC1QcmludGVyR3JpZFZpZXc7IFNob3ctSW5m
byAiVGFyYW1hIFRhbWFtbGFuZMSxIiAiJCgkc2NyaXB0OkZvdW5kSXRlbXMuQ291bnQpIHNlw6dl
bmVrIGJ1bHVuZHUuIiB9Cn0KCmZ1bmN0aW9uIFNjYW4tUmVtb3RlUHJpbnRlcnMgewogICAgJHNl
cnZlciA9ICR0eHRSZW1vdGVQYy5UZXh0LlRyaW0oKQogICAgaWYgKFtzdHJpbmddOjpJc051bGxP
cldoaXRlU3BhY2UoJHNlcnZlcikpIHsgU2hvdy1XYXJuICJFa3NpayBCaWxnaSIgIkzDvHRmZW4g
dXphayBQQyBhZMSxIHZleWEgSVAgZ2lyaW4uIjsgcmV0dXJuIH0KICAgIENsZWFyLUZvdW5kCiAg
ICBXcml0ZS1Mb2cgIlV6YWsgUEMgeWF6xLFjxLEvcGF5bGHFn8SxbSB0YXJhbWFzxLEgYmHFn2xh
ZMSxOiAkc2VydmVyIgogICAgaWYgKCRjaGtBdXRvRml4QmVmb3JlU2Nhbi5DaGVja2VkKSB7IEFw
cGx5LVNlbGVjdGVkRml4ZXMgLVJvbGVMYWJlbCAiQ2xpZW50IiB9CiAgICBSdW4tUmVtb3RlRGlh
Z25vc2lzCiAgICBTY2FuLUNpbVByaW50ZXJzICRzZXJ2ZXIKICAgIFNjYW4tTmV0Vmlld1NoYXJl
cyAkc2VydmVyCiAgICBpZiAoJHNjcmlwdDpGb3VuZEl0ZW1zLkNvdW50IC1lcSAwKSB7IFNob3ct
V2FybiAiU29udcOnIFlvayIgIlBheWxhxZ/EsW0veWF6xLFjxLEgYnVsdW5hbWFkxLEgdmV5YSBl
cmnFn2ltIGVuZ2VsbGVuZGkuIiB9CiAgICBlbHNlIHsgUmVzZXQtUHJpbnRlckdyaWRWaWV3OyBT
aG93LUluZm8gIlRhcmFtYSBUYW1hbWxhbmTEsSIgIiQoJHNjcmlwdDpGb3VuZEl0ZW1zLkNvdW50
KSBzZcOnZW5layBidWx1bmR1LiIgfQp9CmZ1bmN0aW9uIFNob3ctRmluZGVyTG9jYWxQYWdlIHsK
ICAgIFNob3ctUGFnZSAiZmluZGVyIgogICAgU2Nhbi1Mb2NhbFByaW50ZXJzT25seQp9CmZ1bmN0
aW9uIFJlbW92ZS1PbGRQcmludGVyQ29ubmVjdGlvbiB7CiAgICBwYXJhbShbc3RyaW5nXSRVTkMp
CiAgICBXcml0ZS1Mb2cgIkVza2kgeWF6xLFjxLEgYmHEn2xhbnTEsXPEsSB0ZW1pemxlbml5b3I6
ICRVTkMiCiAgICB0cnkgewogICAgICAgICRleGlzdGluZyA9IEdldC1QcmludGVyIC1FcnJvckFj
dGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgV2hlcmUtT2JqZWN0IHsgJF8uTmFtZSAtZXEgJFVOQyAt
b3IgJF8uUG9ydE5hbWUgLWVxICRVTkMgLW9yICRfLk5hbWUgLWxpa2UgIiokVU5DKiIgfQogICAg
ICAgIGZvcmVhY2ggKCRwIGluICRleGlzdGluZykgeyBSZW1vdmUtUHJpbnRlciAtTmFtZSAkcC5O
YW1lIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlOyBPSyAiRXNraSB5YXrEsWPEsSBrYWxk
xLFyxLFsZMSxOiAkKCRwLk5hbWUpIiB9CiAgICB9IGNhdGNoIHsgV0FSTiAiRXNraSBiYcSfbGFu
dMSxIHRlbWl6bGnEn2kgYmHFn2FyxLFzxLF6OiAkXyIgfQogICAgdHJ5IHsgcnVuZGxsMzIgcHJp
bnR1aS5kbGwsUHJpbnRVSUVudHJ5IC9kbiAvbiAiJFVOQyIgL3E7IE9LICJQcmludFVJIGVza2kg
YmHEn2xhbnTEsSBrYWxkxLFybWEgZGVuZW5kaSIgfSBjYXRjaCB7fQp9CmZ1bmN0aW9uIEdldC1Q
cmludGVyQ29ubmVjdGlvbkV4aXN0cyB7CiAgICBwYXJhbShbc3RyaW5nXSRVTkMpCiAgICB0cnkg
ewogICAgICAgICR0YXJnZXQgPSAkVU5DLlRyaW0oKQogICAgICAgICRwcmludGVycyA9IEdldC1Q
cmludGVyIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgZm9yZWFjaCAoJHAg
aW4gJHByaW50ZXJzKSB7CiAgICAgICAgICAgIGlmICgkcC5OYW1lIC1lcSAkdGFyZ2V0IC1vciAk
cC5Qb3J0TmFtZSAtZXEgJHRhcmdldCkgeyByZXR1cm4gJHRydWUgfQogICAgICAgICAgICBpZiAo
JHAuTmFtZSAtbGlrZSAiKiR0YXJnZXQqIiAtb3IgJHAuUG9ydE5hbWUgLWxpa2UgIiokdGFyZ2V0
KiIpIHsgcmV0dXJuICR0cnVlIH0KICAgICAgICB9CiAgICB9IGNhdGNoIHt9CiAgICB0cnkgewog
ICAgICAgICRlc2NhcGVkID0gW3JlZ2V4XTo6RXNjYXBlKCRVTkMpCiAgICAgICAgJHdtaSA9IEdl
dC1DaW1JbnN0YW5jZSBXaW4zMl9QcmludGVyIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVl
IHwgV2hlcmUtT2JqZWN0IHsgJF8uTmFtZSAtbWF0Y2ggJGVzY2FwZWQgLW9yICRfLkRldmljZUlE
IC1tYXRjaCAkZXNjYXBlZCB9CiAgICAgICAgaWYgKCR3bWkpIHsgcmV0dXJuICR0cnVlIH0KICAg
IH0gY2F0Y2gge30KICAgIHJldHVybiAkZmFsc2UKfQpmdW5jdGlvbiBXYWl0LVByaW50ZXJDb25u
ZWN0aW9uIHsKICAgIHBhcmFtKFtzdHJpbmddJFVOQyxbaW50XSRTZWNvbmRzPTEwKQogICAgZm9y
ICgkaT0wOyAkaSAtbHQgJFNlY29uZHM7ICRpKyspIHsKICAgICAgICBpZiAoR2V0LVByaW50ZXJD
b25uZWN0aW9uRXhpc3RzIC1VTkMgJFVOQykgeyByZXR1cm4gJHRydWUgfQogICAgICAgIFN0YXJ0
LVNsZWVwIC1TZWNvbmRzIDEKICAgICAgICBbU3lzdGVtLldpbmRvd3MuRm9ybXMuQXBwbGljYXRp
b25dOjpEb0V2ZW50cygpCiAgICB9CiAgICByZXR1cm4gJGZhbHNlCn0KZnVuY3Rpb24gR2V0LVNo
YXJlRnJvbVVOQyB7CiAgICBwYXJhbShbc3RyaW5nXSRVTkMpCiAgICB0cnkgewogICAgICAgICRw
YXJ0cyA9ICRVTkMuVHJpbSgpLlRyaW0oJyInKS5UcmltKCInIikuVHJpbVN0YXJ0KCJcIikuU3Bs
aXQoIlwiKQogICAgICAgIGlmICgkcGFydHMuQ291bnQgLWdlIDIpIHsgcmV0dXJuICRwYXJ0c1sx
XSB9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gIiIKfQpmdW5jdGlvbiBBZGQtUHJlQ29ubmVj
dFJlc3VsdCB7CiAgICBwYXJhbSgKICAgICAgICBbU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMu
TGlzdFtvYmplY3RdXSRSZXN1bHRzLAogICAgICAgIFtzdHJpbmddJExldmVsLAogICAgICAgIFtz
dHJpbmddJENoZWNrLAogICAgICAgIFtzdHJpbmddJERldGFpbCwKICAgICAgICBbc3RyaW5nXSRT
dWdnZXN0aW9uID0gIiIKICAgICkKICAgICRSZXN1bHRzLkFkZChbUFNDdXN0b21PYmplY3RdQHtM
ZXZlbD0kTGV2ZWw7Q2hlY2s9JENoZWNrO0RldGFpbD0kRGV0YWlsO1N1Z2dlc3Rpb249JFN1Z2dl
c3Rpb259KSB8IE91dC1OdWxsCiAgICAkbGluZSA9ICJQUkVDT05ORUNUIC8gJENoZWNrIC8gJERl
dGFpbCIKICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJFN1Z2dlc3Rp
b24pKSB7ICRsaW5lICs9ICIgLyDDlm5lcmk6ICRTdWdnZXN0aW9uIiB9CiAgICBzd2l0Y2ggKCRM
ZXZlbCkgewogICAgICAgICJPSyIgeyBPSyAkbGluZSB9CiAgICAgICAgIldBUk4iIHsgV0FSTiAk
bGluZSB9CiAgICAgICAgIkVSUiIgeyBFUlIgJGxpbmUgfQogICAgICAgIGRlZmF1bHQgeyBXcml0
ZS1Mb2cgJGxpbmUgfQogICAgfQp9CmZ1bmN0aW9uIEludm9rZS1QcmludGVyUHJlQ29ubmVjdFRl
c3QgewogICAgcGFyYW0oW3N0cmluZ10kVU5DKQogICAgJHJlc3VsdHMgPSBOZXctT2JqZWN0IFN5
c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbb2JqZWN0XQogICAgJHNlcnZlciA9IEdldC1T
ZXJ2ZXJGcm9tVU5DICRVTkMKICAgICRzaGFyZSA9IEdldC1TaGFyZUZyb21VTkMgJFVOQwoKICAg
IFdyaXRlLUxvZyAiPT09IFBSRUNPTk5FQ1QgWUFaSUNJIFRFU1TEsCBCQcWeTEFESSB8IFVOQzog
JFVOQyA9PT0iCiAgICBBZGQtUHJlQ29ubmVjdFJlc3VsdCAkcmVzdWx0cyAiSU5GTyIgIlVOQyIg
IlNlcnZlcj0kc2VydmVyOyBTaGFyZT0kc2hhcmU7IENsaWVudD0kZW52OkNPTVBVVEVSTkFNRTsg
VXNlcj0kZW52OlVTRVJET01BSU5cJGVudjpVU0VSTkFNRSIKCiAgICBpZiAoW3N0cmluZ106Oklz
TnVsbE9yV2hpdGVTcGFjZSgkc2VydmVyKSAtb3IgW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFj
ZSgkc2hhcmUpKSB7CiAgICAgICAgQWRkLVByZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIkVSUiIg
IlVOQyBmb3JtYXQiICJVTkMgc2VydmVyL3BheWxhxZ/EsW0gYXlyxLHFn3TEsXLEsWxhbWFkxLE6
ICRVTkMiICJcXFBDQURJXFBBWUxBU0lNX0FESSBmb3JtYXTEsW7EsSBrdWxsYW7EsW4iCiAgICAg
ICAgV3JpdGUtTG9nICI9PT0gUFJFQ09OTkVDVCBZQVpJQ0kgVEVTVMSwIELEsFRUxLAgfCBIYXRh
OiAxIHwgVXlhcsSxOiAwID09PSIKICAgICAgICByZXR1cm4gW1BTQ3VzdG9tT2JqZWN0XUB7UmVz
dWx0cz0kcmVzdWx0cztFcnJvckNvdW50PTE7V2FybkNvdW50PTB9CiAgICB9CgogICAgdHJ5IHsK
ICAgICAgICBpZiAoVGVzdC1Db25uZWN0aW9uIC1Db21wdXRlck5hbWUgJHNlcnZlciAtQ291bnQg
MSAtUXVpZXQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpIHsKICAgICAgICAgICAgQWRk
LVByZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIk9LIiAiUGluZyIgIiRzZXJ2ZXIgSUNNUCB5YW7E
sXQgdmVyZGkiCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgQWRkLVByZUNvbm5lY3RSZXN1
bHQgJHJlc3VsdHMgIldBUk4iICJQaW5nIiAiJHNlcnZlciBJQ01QIHlhbsSxdCB2ZXJtZWRpIiAi
RmlyZXdhbGwgSUNNUCBrYXBhbMSxIG9sYWJpbGlyOyBTTUIvUlBDIHRlc3RsZXJpIGJlbGlybGV5
aWNpIG9sYWNhayIKICAgICAgICB9CiAgICB9IGNhdGNoIHsgQWRkLVByZUNvbm5lY3RSZXN1bHQg
JHJlc3VsdHMgIldBUk4iICJQaW5nIiAiUGluZyB0ZXN0aSDDp2FsxLHFn21hZMSxOiAkKCRfLkV4
Y2VwdGlvbi5NZXNzYWdlKSIgfQoKICAgIGZvcmVhY2ggKCRwb3J0IGluIEAoNDQ1LDEzNSkpIHsK
ICAgICAgICB0cnkgewogICAgICAgICAgICAkdG5jID0gVGVzdC1OZXRDb25uZWN0aW9uIC1Db21w
dXRlck5hbWUgJHNlcnZlciAtUG9ydCAkcG9ydCAtV2FybmluZ0FjdGlvbiBTaWxlbnRseUNvbnRp
bnVlIC1JbmZvcm1hdGlvbkxldmVsIFF1aWV0CiAgICAgICAgICAgIGlmICgkdG5jKSB7CiAgICAg
ICAgICAgICAgICBBZGQtUHJlQ29ubmVjdFJlc3VsdCAkcmVzdWx0cyAiT0siICJUQ1AgJHBvcnQi
ICIkKCRzZXJ2ZXIpOiRwb3J0IGVyacWfaWxlYmlsaXIiCiAgICAgICAgICAgIH0gZWxzZSB7CiAg
ICAgICAgICAgICAgICAkc3VnZ2VzdCA9IGlmICgkcG9ydCAtZXEgNDQ1KSB7ICJVemFrIFBDJ2Rl
IEZpbGUgYW5kIFByaW50ZXIgU2hhcmluZy9TTUIgdmUgZmlyZXdhbGwga3VyYWxsYXLEsW7EsSBr
b250cm9sIGVkaW4iIH0gZWxzZSB7ICJSUEMgRW5kcG9pbnQgTWFwcGVyL2ZpcmV3YWxsIGtvbnRy
b2wgZWRpbG1lbGkiIH0KICAgICAgICAgICAgICAgIEFkZC1QcmVDb25uZWN0UmVzdWx0ICRyZXN1
bHRzICJXQVJOIiAiVENQICRwb3J0IiAiJCgkc2VydmVyKTokcG9ydCBlcmnFn2lsZW1lZGkiICRz
dWdnZXN0CiAgICAgICAgICAgIH0KICAgICAgICB9IGNhdGNoIHsgQWRkLVByZUNvbm5lY3RSZXN1
bHQgJHJlc3VsdHMgIldBUk4iICJUQ1AgJHBvcnQiICIkKCRzZXJ2ZXIpOiRwb3J0IHRlc3QgZWRp
bGVtZWRpOiAkKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIgfQogICAgfQogICAgdHJ5IHsKICAgICAg
ICAkdG5jMTM5ID0gVGVzdC1OZXRDb25uZWN0aW9uIC1Db21wdXRlck5hbWUgJHNlcnZlciAtUG9y
dCAxMzkgLVdhcm5pbmdBY3Rpb24gU2lsZW50bHlDb250aW51ZSAtSW5mb3JtYXRpb25MZXZlbCBR
dWlldAogICAgICAgIGlmICgkdG5jMTM5KSB7CiAgICAgICAgICAgIEFkZC1QcmVDb25uZWN0UmVz
dWx0ICRyZXN1bHRzICJPSyIgIlRDUCAxMzkiICIkKCRzZXJ2ZXIpOjEzOSBlcmnFn2lsZWJpbGly
IChlc2tpIE5ldEJJT1MvU01CIHV5dW1sdWx1xJ91KSIKICAgICAgICB9IGVsc2UgewogICAgICAg
ICAgICBBZGQtUHJlQ29ubmVjdFJlc3VsdCAkcmVzdWx0cyAiSU5GTyIgIlRDUCAxMzkiICIkKCRz
ZXJ2ZXIpOjEzOSBrYXBhbMSxIHZleWEgZXJpxZ9pbGVtZWRpOyBtb2Rlcm4gU01CIGnDp2luIHRl
ayBiYcWfxLFuYSBoYXRhIHNhecSxbG1heiIKICAgICAgICB9CiAgICB9IGNhdGNoIHsgQWRkLVBy
ZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIklORk8iICJUQ1AgMTM5IiAiMTM5IHRlc3RpIGF0bGFu
ZMSxOiAkKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIgfQoKICAgIHRyeSB7CiAgICAgICAgJHN2YyA9
IEdldC1TZXJ2aWNlIC1Db21wdXRlck5hbWUgJHNlcnZlciAtTmFtZSBTcG9vbGVyIC1FcnJvckFj
dGlvbiBTdG9wCiAgICAgICAgaWYgKCRzdmMuU3RhdHVzIC1lcSAiUnVubmluZyIpIHsKICAgICAg
ICAgICAgQWRkLVByZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIk9LIiAiVXphayBTcG9vbGVyIiAi
U3Bvb2xlciDDp2FsxLHFn8SxeW9yOiAkc2VydmVyIgogICAgICAgIH0gZWxzZSB7CiAgICAgICAg
ICAgIEFkZC1QcmVDb25uZWN0UmVzdWx0ICRyZXN1bHRzICJFUlIiICJVemFrIFNwb29sZXIiICJT
cG9vbGVyIGR1cnVtdTogJCgkc3ZjLlN0YXR1cykiICJVemFrIFBDJ2RlIFByaW50IFNwb29sZXIg
c2VydmlzaW5pIGJhxZ9sYXTEsW4iCiAgICAgICAgfQogICAgfSBjYXRjaCB7IEFkZC1QcmVDb25u
ZWN0UmVzdWx0ICRyZXN1bHRzICJXQVJOIiAiVXphayBTcG9vbGVyIiAiU2VydmlzIGR1cnVtdSBv
a3VuYW1hZMSxOiAkKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIgIlJQQy9maXJld2FsbC95ZXRraSBz
b3J1bnUgb2xhYmlsaXIiIH0KCiAgICB0cnkgewogICAgICAgICR1bmNSb290ID0gIlxcJHNlcnZl
clxJUEMkIgogICAgICAgIGlmIChUZXN0LVBhdGggJHVuY1Jvb3QgLUVycm9yQWN0aW9uIFNpbGVu
dGx5Q29udGludWUpIHsKICAgICAgICAgICAgQWRkLVByZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMg
Ik9LIiAiSVBDJCIgIiR1bmNSb290IGVyacWfaWxlYmlsaXIiCiAgICAgICAgfSBlbHNlIHsKICAg
ICAgICAgICAgQWRkLVByZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIldBUk4iICJJUEMkIiAiJHVu
Y1Jvb3QgZXJpxZ9pbGVtZWRpIiAiS2ltbGlrIGJpbGdpc2ksIFNNQiB2ZXlhIGZpcmV3YWxsIHNv
cnVudSBvbGFiaWxpciIKICAgICAgICB9CiAgICB9IGNhdGNoIHsgQWRkLVByZUNvbm5lY3RSZXN1
bHQgJHJlc3VsdHMgIldBUk4iICJJUEMkIiAiSVBDIGVyacWfaW0gdGVzdGkgYmHFn2FyxLFzxLF6
OiAkKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIgfQoKICAgICRuZXRWaWV3SXRlbXMgPSBAKCkKICAg
IHRyeSB7CiAgICAgICAgJG5ldFZpZXdJdGVtcyA9IEAoR2V0LU5ldFZpZXdJdGVtc1NhZmUgLVNl
cnZlciAkc2VydmVyKQogICAgICAgICRtYXRjaCA9ICRuZXRWaWV3SXRlbXMgfCBXaGVyZS1PYmpl
Y3QgeyAkXy5TaGFyZSAtaWVxICRzaGFyZSAtb3IgJF8uVU5DIC1pZXEgJFVOQyB9IHwgU2VsZWN0
LU9iamVjdCAtRmlyc3QgMQogICAgICAgIGlmICgkbWF0Y2gpIHsKICAgICAgICAgICAgQWRkLVBy
ZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIk9LIiAiUGF5bGHFn8SxbSBnw7Zyw7xuw7xybMO8xJ/D
vCIgIiRVTkMgTkVUIFZJRVcgacOnaW5kZSBnw7Zyw7xuw7x5b3I7IFR5cGU9JCgkbWF0Y2guVHlw
ZSk7IE5vdGU9JCgkbWF0Y2guTm90ZSkiCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgQWRk
LVByZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIkVSUiIgIlBheWxhxZ/EsW0gZ8O2csO8bsO8cmzD
vMSfw7wiICIkVU5DIE5FVCBWSUVXIGnDp2luZGUgYnVsdW5hbWFkxLEiICJQYXlsYcWfxLFtIGFk
xLFuxLEsIHlhesSxY8SxbsSxbiBwYXlsYcWfxLFtYSBhw6fEsWsgb2xkdcSfdW51IHZlIGVyacWf
aW0gaXppbmxlcmluaSBrb250cm9sIGVkaW4iCiAgICAgICAgfQogICAgfSBjYXRjaCB7IEFkZC1Q
cmVDb25uZWN0UmVzdWx0ICRyZXN1bHRzICJXQVJOIiAiUGF5bGHFn8SxbSBnw7Zyw7xuw7xybMO8
xJ/DvCIgIk5FVCBWSUVXIHRlc3RpIGJhxZ9hcsSxc8SxejogJCgkXy5FeGNlcHRpb24uTWVzc2Fn
ZSkiIH0KCiAgICAkcmVtb3RlUHJpbnRlciA9ICRudWxsCiAgICB0cnkgewogICAgICAgICRwcmlu
dGVycyA9IEAoR2V0LUNpbUluc3RhbmNlIC1DbGFzc05hbWUgV2luMzJfUHJpbnRlciAtQ29tcHV0
ZXJOYW1lICRzZXJ2ZXIgLUVycm9yQWN0aW9uIFN0b3ApCiAgICAgICAgJHJlbW90ZVByaW50ZXIg
PSAkcHJpbnRlcnMgfCBXaGVyZS1PYmplY3QgeyAkXy5TaGFyZU5hbWUgLWllcSAkc2hhcmUgLW9y
ICRfLk5hbWUgLWllcSAkc2hhcmUgLW9yICRfLk5hbWUgLWllcSAkVU5DIH0gfCBTZWxlY3QtT2Jq
ZWN0IC1GaXJzdCAxCiAgICAgICAgaWYgKCRyZW1vdGVQcmludGVyKSB7CiAgICAgICAgICAgIEFk
ZC1QcmVDb25uZWN0UmVzdWx0ICRyZXN1bHRzICJPSyIgIkNJTSB5YXrEsWPEsSIgIk5hbWU9JCgk
cmVtb3RlUHJpbnRlci5OYW1lKTsgU2hhcmVOYW1lPSQoJHJlbW90ZVByaW50ZXIuU2hhcmVOYW1l
KTsgRHJpdmVyPSQoJHJlbW90ZVByaW50ZXIuRHJpdmVyTmFtZSk7IFBvcnQ9JCgkcmVtb3RlUHJp
bnRlci5Qb3J0TmFtZSk7IFNoYXJlZD0kKCRyZW1vdGVQcmludGVyLlNoYXJlZCkiCiAgICAgICAg
ICAgIGlmICgkcmVtb3RlUHJpbnRlci5TaGFyZWQgLW5lICR0cnVlKSB7CiAgICAgICAgICAgICAg
ICBBZGQtUHJlQ29ubmVjdFJlc3VsdCAkcmVzdWx0cyAiRVJSIiAiQ0lNIHBheWxhxZ/EsW0iICJZ
YXrEsWPEsSBDSU0nZGUgYnVsdW5kdSBhbWEgU2hhcmVkPVRydWUgZGXEn2lsIiAiVXphayBQQydk
ZSB5YXrEsWPEsSBwYXlsYcWfxLFtxLFuxLEgYcOnxLFuIgogICAgICAgICAgICB9CiAgICAgICAg
fSBlbHNlIHsKICAgICAgICAgICAgQWRkLVByZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIldBUk4i
ICJDSU0geWF6xLFjxLEiICJTaGFyZU5hbWU9JHNoYXJlIGlsZSBlxZ9sZcWfZW4geWF6xLFjxLEg
YnVsdW5hbWFkxLEiICJDSU0vV01JIGVyacWfaW1pIGvEsXPEsXRsxLEgb2xhYmlsaXIgdmV5YSBw
YXlsYcWfxLFtIGFkxLEgZmFya2zEsSBvbGFiaWxpciIKICAgICAgICB9CiAgICB9IGNhdGNoIHsg
QWRkLVByZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIldBUk4iICJDSU0geWF6xLFjxLEiICJVemFr
IHlhesSxY8SxIGxpc3Rlc2kgb2t1bmFtYWTEsTogJCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiICJX
TUkvUlBDL2ZpcmV3YWxsL3lldGtpIGtvbnRyb2wgZWRpbiIgfQoKICAgIGlmICgkcmVtb3RlUHJp
bnRlcikgewogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRkcml2ZXJOYW1lID0gIiQoJHJlbW90
ZVByaW50ZXIuRHJpdmVyTmFtZSkiCiAgICAgICAgICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051
bGxPcldoaXRlU3BhY2UoJGRyaXZlck5hbWUpKSB7CiAgICAgICAgICAgICAgICAkbG9jYWxEcml2
ZXIgPSBHZXQtUHJpbnRlckRyaXZlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFdo
ZXJlLU9iamVjdCB7ICRfLk5hbWUgLWVxICRkcml2ZXJOYW1lIH0gfCBTZWxlY3QtT2JqZWN0IC1G
aXJzdCAxCiAgICAgICAgICAgICAgICBpZiAoJGxvY2FsRHJpdmVyKSB7CiAgICAgICAgICAgICAg
ICAgICAgQWRkLVByZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIk9LIiAiWWVyZWwgZHJpdmVyIGXF
n2xlxZ9tZXNpIiAiQ2xpZW50IMO8emVyaW5kZSBkcml2ZXIgbWV2Y3V0OiAkZHJpdmVyTmFtZSIK
ICAgICAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAgICAgQWRkLVByZUNvbm5l
Y3RSZXN1bHQgJHJlc3VsdHMgIldBUk4iICJZZXJlbCBkcml2ZXIgZcWfbGXFn21lc2kiICJDbGll
bnQgw7x6ZXJpbmRlIGRyaXZlciB5b2s6ICRkcml2ZXJOYW1lIiAiUG9pbnQmUHJpbnQvZHJpdmVy
IHBvbGljeSB2ZXlhIGRyaXZlciBwYWNrYWdlIHNvcnVudSDDp8Sxa2FiaWxpciIKICAgICAgICAg
ICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgIH0gY2F0Y2ggeyBBZGQtUHJlQ29ubmVjdFJl
c3VsdCAkcmVzdWx0cyAiV0FSTiIgIlllcmVsIGRyaXZlciBlxZ9sZcWfbWVzaSIgIlllcmVsIGRy
aXZlciBrb250cm9sw7wgeWFwxLFsYW1hZMSxOiAkKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIgfQoK
ICAgICAgICB0cnkgewogICAgICAgICAgICAkcG9ydHMgPSBAKEdldC1DaW1JbnN0YW5jZSAtQ2xh
c3NOYW1lIFdpbjMyX1RDUElQUHJpbnRlclBvcnQgLUNvbXB1dGVyTmFtZSAkc2VydmVyIC1FcnJv
ckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgICAgICAkcG9ydEluZm8gPSAkcG9ydHMg
fCBXaGVyZS1PYmplY3QgeyAkXy5OYW1lIC1lcSAkcmVtb3RlUHJpbnRlci5Qb3J0TmFtZSB9IHwg
U2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgICAgICAgICBpZiAoJHBvcnRJbmZvKSB7CiAgICAg
ICAgICAgICAgICBBZGQtUHJlQ29ubmVjdFJlc3VsdCAkcmVzdWx0cyAiT0siICJVemFrIHByaW50
ZXIgcG9ydCIgIlBvcnQ9JCgkcG9ydEluZm8uTmFtZSk7IEhvc3RBZGRyZXNzPSQoJHBvcnRJbmZv
Lkhvc3RBZGRyZXNzKTsgUHJvdG9jb2w9JCgkcG9ydEluZm8uUHJvdG9jb2wpOyBQb3J0TnVtYmVy
PSQoJHBvcnRJbmZvLlBvcnROdW1iZXIpIgogICAgICAgICAgICAgICAgaWYgKC1ub3QgW3N0cmlu
Z106OklzTnVsbE9yV2hpdGVTcGFjZSgkcG9ydEluZm8uSG9zdEFkZHJlc3MpKSB7CiAgICAgICAg
ICAgICAgICAgICAgZm9yZWFjaCAoJHByaW50ZXJQb3J0IGluIEAoW2ludF0kcG9ydEluZm8uUG9y
dE51bWJlciw5MTAwKSB8IFNlbGVjdC1PYmplY3QgLVVuaXF1ZSkgewogICAgICAgICAgICAgICAg
ICAgICAgICBpZiAoJHByaW50ZXJQb3J0IC1ndCAwKSB7CiAgICAgICAgICAgICAgICAgICAgICAg
ICAgICB0cnkgewogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICRva1BvcnQgPSBUZXN0
LU5ldENvbm5lY3Rpb24gLUNvbXB1dGVyTmFtZSAkcG9ydEluZm8uSG9zdEFkZHJlc3MgLVBvcnQg
JHByaW50ZXJQb3J0IC1XYXJuaW5nQWN0aW9uIFNpbGVudGx5Q29udGludWUgLUluZm9ybWF0aW9u
TGV2ZWwgUXVpZXQKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBpZiAoJG9rUG9ydCkg
eyBBZGQtUHJlQ29ubmVjdFJlc3VsdCAkcmVzdWx0cyAiT0siICJQcmludGVyIFRDUCAkcHJpbnRl
clBvcnQiICIkKCRwb3J0SW5mby5Ib3N0QWRkcmVzcyk6JHByaW50ZXJQb3J0IGNsaWVudCB0YXJh
ZsSxbmRhbiBlcmnFn2lsZWJpbGlyIiB9CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ZWxzZSB7IEFkZC1QcmVDb25uZWN0UmVzdWx0ICRyZXN1bHRzICJXQVJOIiAiUHJpbnRlciBUQ1Ag
JHByaW50ZXJQb3J0IiAiJCgkcG9ydEluZm8uSG9zdEFkZHJlc3MpOiRwcmludGVyUG9ydCBjbGll
bnQgdGFyYWbEsW5kYW4gZXJpxZ9pbGVtZWRpIiAiRml6aWtzZWwgeWF6xLFjxLEgYcSfxLEvVkxB
Ti9maXJld2FsbCBrb250cm9sIGVkaWxtZWxpOyB1emFrIFBDIGVyacWfaXlvciBvbGFiaWxpciBh
bWEgY2xpZW50IGVyacWfZW1peW9yIG9sYWJpbGlyIiB9CiAgICAgICAgICAgICAgICAgICAgICAg
ICAgICB9IGNhdGNoIHsgQWRkLVByZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIldBUk4iICJQcmlu
dGVyIFRDUCAkcHJpbnRlclBvcnQiICJQb3J0IHRlc3RpIHlhcMSxbGFtYWTEsTogJCgkXy5FeGNl
cHRpb24uTWVzc2FnZSkiIH0KICAgICAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAg
ICAgICAgIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAg
ICAgICAgIEFkZC1QcmVDb25uZWN0UmVzdWx0ICRyZXN1bHRzICJXQVJOIiAiVXphayBwcmludGVy
IHBvcnQiICJDSU0gVENQL0lQIHBvcnQgYmlsZ2lzaSBidWx1bmFtYWTEsTogJCgkcmVtb3RlUHJp
bnRlci5Qb3J0TmFtZSkiICJVU0IvV1NEL2xvY2FsIHBvcnQgb2xhYmlsaXI7IHV6YWsgUEMgdGFy
YWbEsW5kYSBwb3J0IGRldGF5xLFuxLEga29udHJvbCBlZGluIgogICAgICAgICAgICB9CiAgICAg
ICAgfSBjYXRjaCB7IEFkZC1QcmVDb25uZWN0UmVzdWx0ICRyZXN1bHRzICJXQVJOIiAiVXphayBw
cmludGVyIHBvcnQiICJQb3J0IGJpbGdpc2kgb2t1bmFtYWTEsTogJCgkXy5FeGNlcHRpb24uTWVz
c2FnZSkiIH0KICAgIH0KCiAgICB0cnkgewogICAgICAgICRleGlzdGluZyA9IEdldC1QcmludGVy
Q29ubmVjdGlvbkV4aXN0cyAtVU5DICRVTkMKICAgICAgICBpZiAoJGV4aXN0aW5nKSB7IEFkZC1Q
cmVDb25uZWN0UmVzdWx0ICRyZXN1bHRzICJXQVJOIiAiTWV2Y3V0IGJhxJ9sYW50xLEiICJDbGll
bnQgw7x6ZXJpbmRlIGJ1IFVOQyB6YXRlbiBtZXZjdXQgZ8O2csO8bsO8eW9yIiAiR2VyZWtpcnNl
IEVza2kgYmHEn2xhbnTEsXnEsSB0ZW1pemxlIHNlw6dlbmXEn2l5bGUgdGVrcmFyIGRlbmV5aW4i
IH0KICAgICAgICBlbHNlIHsgQWRkLVByZUNvbm5lY3RSZXN1bHQgJHJlc3VsdHMgIk9LIiAiTWV2
Y3V0IGJhxJ9sYW50xLEiICJDbGllbnQgw7x6ZXJpbmRlIG1ldmN1dCBiYcSfbGFudMSxIGJ1bHVu
bWFkxLEiIH0KICAgIH0gY2F0Y2ggeyBBZGQtUHJlQ29ubmVjdFJlc3VsdCAkcmVzdWx0cyAiV0FS
TiIgIk1ldmN1dCBiYcSfbGFudMSxIiAiTWV2Y3V0IGJhxJ9sYW50xLEga29udHJvbMO8IHlhcMSx
bGFtYWTEsTogJCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiIH0KCiAgICAkZXJyQ291bnQgPSBAKCRy
ZXN1bHRzIHwgV2hlcmUtT2JqZWN0IHsgJF8uTGV2ZWwgLWVxICJFUlIiIH0pLkNvdW50CiAgICAk
d2FybkNvdW50ID0gQCgkcmVzdWx0cyB8IFdoZXJlLU9iamVjdCB7ICRfLkxldmVsIC1lcSAiV0FS
TiIgfSkuQ291bnQKICAgIFdyaXRlLUxvZyAiPT09IFBSRUNPTk5FQ1QgWUFaSUNJIFRFU1TEsCBC
xLBUVMSwIHwgSGF0YTogJGVyckNvdW50IHwgVXlhcsSxOiAkd2FybkNvdW50IHwgVU5DOiAkVU5D
ID09PSIKICAgIHJldHVybiBbUFNDdXN0b21PYmplY3RdQHtSZXN1bHRzPSRyZXN1bHRzO0Vycm9y
Q291bnQ9JGVyckNvdW50O1dhcm5Db3VudD0kd2FybkNvdW50fQp9CmZ1bmN0aW9uIENvbm5lY3Qt
UHJpbnRlclVOQyB7CiAgICBwYXJhbShbc3RyaW5nXSRVTkMpCiAgICBpZiAoW3N0cmluZ106Oklz
TnVsbE9yV2hpdGVTcGFjZSgkVU5DKSkgeyBTaG93LVdhcm4gIkVrc2lrIEJpbGdpIiAiVU5DIGJv
xZ8uIMOWcm5lazogXFxQQ0FESVxQQVlMQVNJTV9BREkiOyByZXR1cm4gfQogICAgJFVOQyA9ICRV
TkMuVHJpbSgpLlRyaW0oJyInKS5UcmltKCInIikKICAgIGlmICgkVU5DIC1ub3RtYXRjaCAnXlxc
XFxbXlxcXStcXFteXFxdKycpIHsKICAgICAgICBTaG93LVdhcm4gIkhhdGFsxLEgVU5DIiAiWWF6
xLFjxLEgeW9sdSDFn3UgZm9ybWF0dGEgb2xtYWzEsTpgcmBuXFxQQ0FESVxQQVlMQVNJTV9BREki
CiAgICAgICAgV0FSTiAiR2XDp2Vyc2l6IFVOQyBmb3JtYXTEsTogJFVOQyIKICAgICAgICByZXR1
cm4KICAgIH0KCiAgICBXcml0ZS1Mb2cgIllhesSxY8SxIGJhxJ9sYW50xLFzxLEgYmHFn2zEsXlv
cjogJFVOQyIKICAgICRzZXJ2ZXIgPSBHZXQtU2VydmVyRnJvbVVOQyAkVU5DCiAgICBpZiAoLW5v
dCBbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRzZXJ2ZXIpIC1hbmQgW3N0cmluZ106Oklz
TnVsbE9yV2hpdGVTcGFjZSgkdHh0UmVtb3RlUGMuVGV4dC5UcmltKCkpKSB7ICR0eHRSZW1vdGVQ
Yy5UZXh0ID0gJHNlcnZlciB9CgogICAgaWYgKCRjaGtBdXRvRml4QmVmb3JlQ29ubmVjdC5DaGVj
a2VkKSB7IEFwcGx5LVNlbGVjdGVkRml4ZXMgLVJvbGVMYWJlbCAiQ2xpZW50IiB9CiAgICBpZiAo
JGNoa1JlbW92ZU9sZC5DaGVja2VkKSB7IFJlbW92ZS1PbGRQcmludGVyQ29ubmVjdGlvbiAkVU5D
IH0KCiAgICB0cnkgewogICAgICAgICRwcmVmbGlnaHQgPSBJbnZva2UtUHJpbnRlclByZUNvbm5l
Y3RUZXN0IC1VTkMgJFVOQwogICAgfSBjYXRjaCB7CiAgICAgICAgJHByZWZsaWdodEVycm9yID0g
JF8uRXhjZXB0aW9uLk1lc3NhZ2UKICAgICAgICBFUlIgIlByZWNvbm5lY3QgdGVzdGkgYmVrbGVu
bWV5ZW4gaGF0YSBpbGUgZHVyZHU6ICRwcmVmbGlnaHRFcnJvciIKICAgICAgICAkcHJlZmxpZ2h0
ID0gW1BTQ3VzdG9tT2JqZWN0XUB7UmVzdWx0cz1AKCk7RXJyb3JDb3VudD0xO1dhcm5Db3VudD0w
fQogICAgfQogICAgaWYgKCRwcmVmbGlnaHQuRXJyb3JDb3VudCAtZ3QgMCkgewogICAgICAgIFdB
Uk4gIlByZWNvbm5lY3QgdGVzdGkgJCgkcHJlZmxpZ2h0LkVycm9yQ291bnQpIGhhdGEgdmUgJCgk
cHJlZmxpZ2h0Lldhcm5Db3VudCkgdXlhcsSxIMO8cmV0dGk7IGJhxJ9sYW50xLEgZGVuZW1lbGVy
aSB5aW5lIGRlIGJhxZ9sYXTEsWzEsXlvciIKICAgIH0gZWxzZWlmICgkcHJlZmxpZ2h0Lldhcm5D
b3VudCAtZ3QgMCkgewogICAgICAgIFdBUk4gIlByZWNvbm5lY3QgdGVzdGkgJCgkcHJlZmxpZ2h0
Lldhcm5Db3VudCkgdXlhcsSxIMO8cmV0dGk7IGJhxJ9sYW50xLEgZGVuZW1lbGVyaSBiYcWfbGF0
xLFsxLF5b3IiCiAgICB9IGVsc2UgewogICAgICAgIE9LICJQcmVjb25uZWN0IHRlc3RpIHRlbWl6
OyBiYcSfbGFudMSxIGRlbmVtZWxlcmkgYmHFn2xhdMSxbMSxeW9yIgogICAgfQoKICAgICRvayA9
ICRmYWxzZQogICAgJG1ldGhvZCA9ICIiCiAgICAkbGFzdEVycm9yID0gIiIKICAgICRhdHRlbXB0
RXJyb3JzID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmlu
Z10KCiAgICB0cnkgewogICAgICAgIEFkZC1QcmludGVyIC1Db25uZWN0aW9uTmFtZSAkVU5DIC1F
cnJvckFjdGlvbiBTdG9wCiAgICAgICAgU3RhcnQtU2xlZXAgLVNlY29uZHMgMgogICAgICAgIGlm
IChXYWl0LVByaW50ZXJDb25uZWN0aW9uIC1VTkMgJFVOQyAtU2Vjb25kcyA4KSB7IE9LICJBZGQt
UHJpbnRlciBkb8SfcnVsYW5kxLE6ICRVTkMiOyAkb2sgPSAkdHJ1ZTsgJG1ldGhvZCA9ICJBZGQt
UHJpbnRlciIgfQogICAgICAgIGVsc2UgeyAkYXR0ZW1wdEVycm9ycy5BZGQoIkFkZC1QcmludGVy
OiBoYXRhIHlvayBhbWEgYmHEn2xhbnTEsSBkb8SfcnVsYW5hbWFkxLEiKSB8IE91dC1OdWxsOyBX
QVJOICJBZGQtUHJpbnRlciBoYXRhIHZlcm1lZGkgYW5jYWsgYmHEn2xhbnTEsSBkb8SfcnVsYW5h
bWFkxLEiIH0KICAgIH0gY2F0Y2ggeyAkbGFzdEVycm9yID0gJF8uRXhjZXB0aW9uLk1lc3NhZ2U7
ICRhdHRlbXB0RXJyb3JzLkFkZCgiQWRkLVByaW50ZXI6ICRsYXN0RXJyb3IiKSB8IE91dC1OdWxs
OyBXQVJOICJBZGQtUHJpbnRlciBiYcWfYXLEsXPEsXo6ICRsYXN0RXJyb3IiIH0KCiAgICBpZiAo
LW5vdCAkb2spIHsKICAgICAgICB0cnkgewogICAgICAgICAgICBXcml0ZS1Mb2cgIlByaW50VUkg
L2luIGRlbmVuaXlvci4uLiIKICAgICAgICAgICAgJHAgPSBTdGFydC1Qcm9jZXNzIC1GaWxlUGF0
aCAicnVuZGxsMzIuZXhlIiAtQXJndW1lbnRMaXN0ICJwcmludHVpLmRsbCxQcmludFVJRW50cnkg
L2luIC9uIGAiJFVOQ2AiIiAtV2FpdCAtUGFzc1RocnUgLVdpbmRvd1N0eWxlIEhpZGRlbgogICAg
ICAgICAgICBTdGFydC1TbGVlcCAtU2Vjb25kcyAyCiAgICAgICAgICAgIGlmIChXYWl0LVByaW50
ZXJDb25uZWN0aW9uIC1VTkMgJFVOQyAtU2Vjb25kcyA4KSB7IE9LICJQcmludFVJIC9pbiBkb8Sf
cnVsYW5kxLE6ICRVTkMiOyAkb2sgPSAkdHJ1ZTsgJG1ldGhvZCA9ICJQcmludFVJIC9pbiIgfQog
ICAgICAgICAgICBlbHNlIHsgJGF0dGVtcHRFcnJvcnMuQWRkKCJQcmludFVJIC9pbjogRXhpdENv
ZGU9JCgkcC5FeGl0Q29kZSksIGRvxJ9ydWxhbmFtYWTEsSIpIHwgT3V0LU51bGw7IFdBUk4gIlBy
aW50VUkgL2luIMOnxLFrxLHFnyBrb2R1ICQoJHAuRXhpdENvZGUpLCBmYWthdCBkb8SfcnVsYW5h
bWFkxLEiIH0KICAgICAgICB9IGNhdGNoIHsgJGxhc3RFcnJvciA9ICRfLkV4Y2VwdGlvbi5NZXNz
YWdlOyAkYXR0ZW1wdEVycm9ycy5BZGQoIlByaW50VUkgL2luOiAkbGFzdEVycm9yIikgfCBPdXQt
TnVsbDsgV0FSTiAiUHJpbnRVSSAvaW4gYmHFn2FyxLFzxLF6OiAkbGFzdEVycm9yIiB9CiAgICB9
CiAgICBpZiAoLW5vdCAkb2spIHsKICAgICAgICB0cnkgewogICAgICAgICAgICBXcml0ZS1Mb2cg
IldTY3JpcHQuTmV0d29yayBkZW5lbml5b3IuLi4iCiAgICAgICAgICAgICRuZXQgPSBOZXctT2Jq
ZWN0IC1Db21PYmplY3QgV1NjcmlwdC5OZXR3b3JrCiAgICAgICAgICAgICRuZXQuQWRkV2luZG93
c1ByaW50ZXJDb25uZWN0aW9uKCRVTkMpCiAgICAgICAgICAgIFN0YXJ0LVNsZWVwIC1TZWNvbmRz
IDIKICAgICAgICAgICAgaWYgKFdhaXQtUHJpbnRlckNvbm5lY3Rpb24gLVVOQyAkVU5DIC1TZWNv
bmRzIDgpIHsgT0sgIldTY3JpcHQgZG/En3J1bGFuZMSxOiAkVU5DIjsgJG9rID0gJHRydWU7ICRt
ZXRob2QgPSAiV1NjcmlwdC5OZXR3b3JrIiB9CiAgICAgICAgICAgIGVsc2UgeyAkYXR0ZW1wdEVy
cm9ycy5BZGQoIldTY3JpcHQuTmV0d29yazogaGF0YSB5b2sgYW1hIGJhxJ9sYW50xLEgZG/En3J1
bGFuYW1hZMSxIikgfCBPdXQtTnVsbDsgV0FSTiAiV1NjcmlwdCBoYXRhIHZlcm1lZGkgYW5jYWsg
ZG/En3J1bGFuYW1hZMSxIiB9CiAgICAgICAgfSBjYXRjaCB7ICRsYXN0RXJyb3IgPSAkXy5FeGNl
cHRpb24uTWVzc2FnZTsgJGF0dGVtcHRFcnJvcnMuQWRkKCJXU2NyaXB0Lk5ldHdvcms6ICRsYXN0
RXJyb3IiKSB8IE91dC1OdWxsOyBXQVJOICJXU2NyaXB0IGJhxZ9hcsSxc8SxejogJGxhc3RFcnJv
ciIgfQogICAgfQogICAgaWYgKC1ub3QgJG9rKSB7CiAgICAgICAgdHJ5IHsKICAgICAgICAgICAg
V3JpdGUtTG9nICJQcmludFVJIC9nYSBwZXItbWFjaGluZSBkZW5lbml5b3IuLi4iCiAgICAgICAg
ICAgICRwID0gU3RhcnQtUHJvY2VzcyAtRmlsZVBhdGggInJ1bmRsbDMyLmV4ZSIgLUFyZ3VtZW50
TGlzdCAicHJpbnR1aS5kbGwsUHJpbnRVSUVudHJ5IC9nYSAvbiBgIiRVTkNgIiIgLVdhaXQgLVBh
c3NUaHJ1IC1XaW5kb3dTdHlsZSBIaWRkZW4KICAgICAgICAgICAgUmVzdGFydC1TZXJ2aWNlIFNw
b29sZXIgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgICAgIFN0
YXJ0LVNsZWVwIC1TZWNvbmRzIDMKICAgICAgICAgICAgaWYgKFdhaXQtUHJpbnRlckNvbm5lY3Rp
b24gLVVOQyAkVU5DIC1TZWNvbmRzIDgpIHsgT0sgIlByaW50VUkgL2dhIGRvxJ9ydWxhbmTEsTog
JFVOQyI7ICRvayA9ICR0cnVlOyAkbWV0aG9kID0gIlByaW50VUkgL2dhIiB9CiAgICAgICAgICAg
IGVsc2UgeyAkYXR0ZW1wdEVycm9ycy5BZGQoIlByaW50VUkgL2dhOiBFeGl0Q29kZT0kKCRwLkV4
aXRDb2RlKSwgZG/En3J1bGFuYW1hZMSxIikgfCBPdXQtTnVsbDsgV0FSTiAiUHJpbnRVSSAvZ2Eg
w6fEsWvEscWfIGtvZHUgJCgkcC5FeGl0Q29kZSksIGZha2F0IGRvxJ9ydWxhbmFtYWTEsSIgfQog
ICAgICAgIH0gY2F0Y2ggeyAkbGFzdEVycm9yID0gJF8uRXhjZXB0aW9uLk1lc3NhZ2U7ICRhdHRl
bXB0RXJyb3JzLkFkZCgiUHJpbnRVSSAvZ2E6ICRsYXN0RXJyb3IiKSB8IE91dC1OdWxsOyBXQVJO
ICJQcmludFVJIC9nYSBiYcWfYXLEsXPEsXo6ICRsYXN0RXJyb3IiIH0KICAgIH0KCiAgICBpZiAo
JG9rKSB7IFNob3ctSW5mbyAiQmHEn2xhbnTEsSBCYcWfYXLEsWzEsSIgIllhesSxY8SxIGRvxJ9y
dWxhbmFyYWsgYmHEn2xhbmTEsTpgcmBuJFVOQ2ByYG5Zw7ZudGVtOiAkbWV0aG9kIiB9CiAgICBl
bHNlIHsKICAgICAgICBFUlIgIkJhxJ9sYW50xLEgZG/En3J1bGFuYW1hZMSxOiAkVU5DIHwgU29u
IGhhdGE6ICRsYXN0RXJyb3IiCiAgICAgICAgV3JpdGUtTG9nICI9PT0gR8OWTkRFUsSwTEVDRUsg
QkHEnkxBTlRJIEhBVEEgw5ZaRVTEsCBCQcWeTEFESSA9PT0iICJFUlIiCiAgICAgICAgV3JpdGUt
TG9nICJVTkM6ICRVTkMiICJFUlIiCiAgICAgICAgV3JpdGUtTG9nICJDbGllbnQ6ICRlbnY6Q09N
UFVURVJOQU1FIHwgVXNlcjogJGVudjpVU0VSRE9NQUlOXCRlbnY6VVNFUk5BTUUgfCBSb2xlOiAk
c2NyaXB0OkRldGVjdGVkUm9sZSIgIkVSUiIKICAgICAgICBXcml0ZS1Mb2cgIlByZWNvbm5lY3Q6
IEhhdGE9JCgkcHJlZmxpZ2h0LkVycm9yQ291bnQpLCBVeWFyxLE9JCgkcHJlZmxpZ2h0Lldhcm5D
b3VudCkiICJFUlIiCiAgICAgICAgZm9yZWFjaCAoJGF0dGVtcHQgaW4gJGF0dGVtcHRFcnJvcnMp
IHsgV3JpdGUtTG9nICJEZW5lbWU6ICRhdHRlbXB0IiAiRVJSIiB9CiAgICAgICAgV3JpdGUtTG9n
ICJTb24gaGF0YTogJGxhc3RFcnJvciIgIkVSUiIKICAgICAgICBXcml0ZS1Mb2cgIkxvZyBkb3N5
YXPEsTogJHNjcmlwdDpMb2dGaWxlIiAiRVJSIgogICAgICAgIFdyaXRlLUxvZyAiPT09IEfDlk5E
RVLEsExFQ0VLIEJBxJ5MQU5USSBIQVRBIMOWWkVUxLAgQsSwVFTEsCA9PT0iICJFUlIiCiAgICAg
ICAgU2hvdy1FcnIgIkJhxJ9sYW50xLEgQmHFn2FyxLFzxLF6IiAiWWF6xLFjxLEgYmHEn2xhbmFt
YWTEsSB2ZXlhIGRvxJ9ydWxhbmFtYWTEsS5gcmBuVU5DOiAkVU5DYHJgblNvbiBoYXRhOiAkbGFz
dEVycm9yYHJgbmByYG5Mb2cga2F5ZMSxbsSxIGJhbmEgZ8O2bmRlcmlyc2VuIGhhdGEgw7Z6ZXRp
bmRlbiBpbGVybGV5ZWJpbGlyaXouYHJgbmByYG5Mb2c6ICRzY3JpcHQ6TG9nRmlsZSIKICAgIH0K
fQpmdW5jdGlvbiBDb25uZWN0LVNlbGVjdGVkUHJpbnRlciB7CiAgICBpZiAoJGdyaWRQcmludGVy
cy5TZWxlY3RlZFJvd3MuQ291bnQgLWx0IDEpIHsgU2hvdy1XYXJuICJTZcOnaW0gWW9rIiAiTGlz
dGVkZW4gYmlyIHlhesSxY8SxL3BheWxhxZ/EsW0gc2XDp2luLiI7IHJldHVybiB9CiAgICAkdGFy
Z2V0ID0gIiQoJGdyaWRQcmludGVycy5TZWxlY3RlZFJvd3NbMF0uQ2VsbHNbM10uVmFsdWUpIgog
ICAgaWYgKCR0YXJnZXQgLWxpa2UgImxvY2FsOioiKSB7CiAgICAgICAgU2hvdy1XYXJuICJZZXJl
bCBZYXrEsWPEsSIgIlNlw6dpbGVuIGthecSxdCB6YXRlbiBidSBiaWxnaXNheWFyZGFraSB5ZXJl
bCB5YXrEsWPEsS5gcmBuxLDFn2xlbSBpw6dpbiAnU2XDp2lsZW5pIEthbGTEsXInIHZleWEgRHJp
dmVyIFRlbWl6bGnEn2kga3VsbGFuxLFsYWJpbGlyLiIKICAgICAgICByZXR1cm4KICAgIH0KICAg
IGlmICgkdGFyZ2V0IC1saWtlICJ1bnNoYXJlZDoqIikgewogICAgICAgICRuYW1lID0gIiQoJGdy
aWRQcmludGVycy5TZWxlY3RlZFJvd3NbMF0uQ2VsbHNbMV0uVmFsdWUpIgogICAgICAgIFNob3ct
V2FybiAiUGF5bGHFn8SxbG1hbcSxxZ8gWWF6xLFjxLEiICJTZcOnaWxlbiB1emFrIHlhesSxY8Sx
IGJ1bHVuZHUgYW1hIHBheWxhxZ/EsWxtYW3EscWfIGfDtnLDvG7DvHlvcjpgcmBuJG5hbWVgcmBu
YHJgbkJhxJ9sYW5hYmlsbWVrIGnDp2luIEhvc3QgUEMgw7x6ZXJpbmRlIHlhesSxY8SxIHBheWxh
xZ/EsW3EsW7EsSBhw6fEsXAgYmlyIHBheWxhxZ/EsW0gYWTEsSB2ZXJtZW5peiBnZXJla2lyLiIK
ICAgICAgICBXQVJOICJQYXlsYcWfxLFsbWFtxLHFnyB1emFrIHlhesSxY8SxIHNlw6dpbGRpOyBi
YcSfbGFudMSxIGJhxZ9sYXTEsWxtYWTEsTogJG5hbWUiCiAgICAgICAgcmV0dXJuCiAgICB9CiAg
ICBDb25uZWN0LVByaW50ZXJVTkMgJHRhcmdldAp9CmZ1bmN0aW9uIENvbm5lY3QtTWFudWFsUHJp
bnRlciB7CiAgICBDb25uZWN0LVByaW50ZXJVTkMgJHR4dE1hbnVhbFVOQy5UZXh0LlRyaW0oKQp9
CmZ1bmN0aW9uIFJlbW92ZS1TZWxlY3RlZFByaW50ZXJJdGVtIHsKICAgIGlmICgkZ3JpZFByaW50
ZXJzLlNlbGVjdGVkUm93cy5Db3VudCAtbHQgMSkgeyBTaG93LVdhcm4gIlNlw6dpbSBZb2siICJM
aXN0ZWRlbiBiaXIgeWF6xLFjxLEgc2XDp2luLiI7IHJldHVybiB9CiAgICAkbmFtZSA9ICIkKCRn
cmlkUHJpbnRlcnMuU2VsZWN0ZWRSb3dzWzBdLkNlbGxzWzFdLlZhbHVlKSIKICAgICR1bmMgPSAi
JCgkZ3JpZFByaW50ZXJzLlNlbGVjdGVkUm93c1swXS5DZWxsc1szXS5WYWx1ZSkiCiAgICAkdGFy
Z2V0TmFtZSA9IGlmICgkdW5jIC1saWtlICJsb2NhbDoqIikgeyAkdW5jLlN1YnN0cmluZyg2KSB9
IGVsc2UgeyAkbmFtZSB9CiAgICAkYW5zd2VyID0gW1N5c3RlbS5XaW5kb3dzLkZvcm1zLk1lc3Nh
Z2VCb3hdOjpTaG93KCJTZcOnaWxlbiB5YXrEsWPEsS9iYcSfbGFudMSxIGthbGTEsXLEsWxhY2Fr
OmByYG4kdGFyZ2V0TmFtZWByYG5gcmBuRGV2YW0gZWRpbHNpbiBtaT8iLCJZYXrEsWPEsSBLYWxk
xLFyIixbU3lzdGVtLldpbmRvd3MuRm9ybXMuTWVzc2FnZUJveEJ1dHRvbnNdOjpZZXNObyxbU3lz
dGVtLldpbmRvd3MuRm9ybXMuTWVzc2FnZUJveEljb25dOjpXYXJuaW5nKQogICAgaWYgKCRhbnN3
ZXIgLW5lIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5EaWFsb2dSZXN1bHRdOjpZZXMpIHsgV0FSTiAi
U2XDp2lsaSB5YXrEsWPEsSBrYWxkxLFybWEgaXB0YWwgZWRpbGRpIjsgcmV0dXJuIH0KICAgIHRy
eSB7CiAgICAgICAgaWYgKCR1bmMgLWxpa2UgIlxcKiIpIHsKICAgICAgICAgICAgUmVtb3ZlLU9s
ZFByaW50ZXJDb25uZWN0aW9uICR1bmMKICAgICAgICB9IGVsc2UgewogICAgICAgICAgICBSZW1v
dmUtUHJpbnRlciAtTmFtZSAkdGFyZ2V0TmFtZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgICAg
ICBPSyAiWWVyZWwgeWF6xLFjxLEga2FsZMSxcsSxbGTEsTogJHRhcmdldE5hbWUiCiAgICAgICAg
fQogICAgICAgIFNjYW4tUHJpbnRlcnNVbmlmaWVkCiAgICB9IGNhdGNoIHsKICAgICAgICBFUlIg
IlNlw6dpbGkgeWF6xLFjxLEga2FsZMSxcsSxbGFtYWTEsTogJHRhcmdldE5hbWUgLSAkXyIKICAg
ICAgICBTaG93LUVyciAiS2FsZMSxcm1hIEJhxZ9hcsSxc8SxeiIgIllhesSxY8SxIGthbGTEsXLE
sWxhbWFkxLE6YHJgbiR0YXJnZXROYW1lYHJgbmByYG4kKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIK
ICAgIH0KfQoKIyAtLS0tLS0tLS0tIFJFUE9SVCAtLS0tLS0tLS0tCmZ1bmN0aW9uIEV4cG9ydC1S
ZXBvcnQgewogICAgJHBhdGggPSBKb2luLVBhdGggJHNjcmlwdDpMb2dEaXIgKCJQUk5fVUVUX0ZV
TExfUkVQT1JUX3swfS5odG1sIiAtZiAoR2V0LURhdGUgLUZvcm1hdCAieXl5eU1NZGRfSEhtbXNz
IikpCiAgICAkcm93cyA9IGZvcmVhY2ggKCRpIGluICRzY3JpcHQ6Rm91bmRJdGVtcykgeyAiPHRy
Pjx0ZD4kKCRpLlR5cGUpPC90ZD48dGQ+JCgkaS5OYW1lKTwvdGQ+PHRkPiQoJGkuU2hhcmVOYW1l
KTwvdGQ+PHRkPiQoJGkuVU5DKTwvdGQ+PHRkPiQoJGkuRHJpdmVyKTwvdGQ+PHRkPiQoJGkuU291
cmNlKTwvdGQ+PHRkPiQoJGkuTm90ZSk8L3RkPjwvdHI+IiB9CiAgICAkZGlhZ1Jvd3MgPSBmb3Jl
YWNoICgkZCBpbiAkc2NyaXB0OkRpYWdJdGVtcykgeyAiPHRyPjx0ZD4kKCRkLkthdGVnb3JpKTwv
dGQ+PHRkPiQoJGQuQWQpPC90ZD48dGQ+JCgkZC5EdXJ1bSk8L3RkPjx0ZD4kKCRkLkRldGF5KTwv
dGQ+PHRkPiQoJGQuT25lcmkpPC90ZD48L3RyPiIgfQogICAgJGFjdFJvd3MgPSBmb3JlYWNoICgk
YSBpbiAkc2NyaXB0OkFjdGlvbkl0ZW1zKSB7ICI8dHI+PHRkPiQoJGEuVGltZSk8L3RkPjx0ZD4k
KCRhLk5hbWUpPC90ZD48dGQ+JCgkYS5TdGF0dXMpPC90ZD48dGQ+JCgkYS5EZXRhaWwpPC90ZD48
L3RyPiIgfQogICAgJGxvZ1RleHQgPSBHZXQtQ29udGVudCAkc2NyaXB0OkxvZ0ZpbGUgLUVycm9y
QWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBGb3JFYWNoLU9iamVjdCB7ICI8ZGl2PiQoJF8uUmVw
bGFjZSgnJicsJyZhbXA7JykuUmVwbGFjZSgnPCcsJyZsdDsnKS5SZXBsYWNlKCc+JywnJmd0Oycp
KTwvZGl2PiIgfQogICAgJGh0bWwgPSBAIgo8IWRvY3R5cGUgaHRtbD48aHRtbCBsYW5nPSd0cic+
PGhlYWQ+PG1ldGEgY2hhcnNldD0ndXRmLTgnPgo8dGl0bGU+JCgkc2NyaXB0OkFwcE5hbWUpPC90
aXRsZT4KPHN0eWxlPgpib2R5e2ZvbnQtZmFtaWx5OlNlZ29lIFVJLEFyaWFsO2JhY2tncm91bmQ6
IzExMTYxZDtjb2xvcjojZWVmMWY3O3BhZGRpbmc6MjRweH0KLmNhcmR7YmFja2dyb3VuZDojMWIy
MDI4O2JvcmRlcjoxcHggc29saWQgIzMxM2E0Nztib3JkZXItcmFkaXVzOjEycHg7cGFkZGluZzox
NnB4O21hcmdpbi1ib3R0b206MTZweH0KdGFibGV7d2lkdGg6MTAwJTtib3JkZXItY29sbGFwc2U6
Y29sbGFwc2V9dGgsdGR7Ym9yZGVyOjFweCBzb2xpZCAjMzY0MTUwO3BhZGRpbmc6OHB4O3RleHQt
YWxpZ246bGVmdH10aHtiYWNrZ3JvdW5kOiMyMzJjMzl9Cjwvc3R5bGU+PC9oZWFkPjxib2R5Pgo8
aDE+JCgkc2NyaXB0OkFwcE5hbWUpPC9oMT4KPGRpdiBjbGFzcz0nY2FyZCc+PGI+UEM6PC9iPiAk
ZW52OkNPTVBVVEVSTkFNRTxicj48Yj5Vc2VyOjwvYj4gJGVudjpVU0VSTkFNRTxicj48Yj5Sb2xl
OjwvYj4gJHNjcmlwdDpEZXRlY3RlZFJvbGU8YnI+PGI+RGF0ZTo8L2I+ICQoR2V0LURhdGUpPC9k
aXY+CjxkaXYgY2xhc3M9J2NhcmQnPjxoMj5BcsSxemEgVGVzcGl0PC9oMj48dGFibGU+PHRyPjx0
aD5LYXRlZ29yaTwvdGg+PHRoPkFkPC90aD48dGg+RHVydW08L3RoPjx0aD5EZXRheTwvdGg+PHRo
PsOWbmVyaTwvdGg+PC90cj4kKCRkaWFnUm93cyAtam9pbiAiYHJgbiIpPC90YWJsZT48L2Rpdj4K
PGRpdiBjbGFzcz0nY2FyZCc+PGgyPkJ1bHVuYW4gWWF6xLFjxLEvUGF5bGHFn8SxbWxhcjwvaDI+
PHRhYmxlPjx0cj48dGg+VMO8cjwvdGg+PHRoPkFkPC90aD48dGg+UGF5bGHFn8SxbTwvdGg+PHRo
PlVOQzwvdGg+PHRoPlPDvHLDvGPDvDwvdGg+PHRoPktheW5hazwvdGg+PHRoPk5vdDwvdGg+PC90
cj4kKCRyb3dzIC1qb2luICJgcmBuIik8L3RhYmxlPjwvZGl2Pgo8ZGl2IGNsYXNzPSdjYXJkJz48
aDI+xLDFn2xlbWxlcjwvaDI+PHRhYmxlPjx0cj48dGg+WmFtYW48L3RoPjx0aD7EsMWfbGVtPC90
aD48dGg+RHVydW08L3RoPjx0aD5EZXRheTwvdGg+PC90cj4kKCRhY3RSb3dzIC1qb2luICJgcmBu
Iik8L3RhYmxlPjwvZGl2Pgo8ZGl2IGNsYXNzPSdjYXJkJz48aDI+TG9nPC9oMj4kKCRsb2dUZXh0
IC1qb2luICJgcmBuIik8L2Rpdj4KPC9ib2R5PjwvaHRtbD4KIkAKICAgIFNldC1Db250ZW50IC1Q
YXRoICRwYXRoIC1WYWx1ZSAkaHRtbCAtRW5jb2RpbmcgVVRGOAogICAgU2hvdy1JbmZvICJSYXBv
ciIgIlJhcG9yIG9sdcWfdHVydWxkdTpgcmBuJHBhdGgiCiAgICBTdGFydC1Qcm9jZXNzICRwYXRo
Cn0KCgojIC0tLS0tLS0tLS0gRU5URVJQUklTRSBWMiBBVVRPIFJFTUVESUFUSU9OIC0tLS0tLS0t
LS0KZnVuY3Rpb24gU2VsZWN0LUZpeENoZWNrIHsKICAgIHBhcmFtKFtzdHJpbmddJEZpeE5hbWUp
CiAgICBzd2l0Y2ggKCRGaXhOYW1lKSB7CiAgICAgICAgIlJQQyIgeyBpZiAoJGNoa0ZpeFJwYykg
eyAkY2hrRml4UnBjLkNoZWNrZWQgPSAkdHJ1ZSB9IH0KICAgICAgICAiUE9JTlRQUklOVCIgeyBp
ZiAoJGNoa0ZpeFBvaW50KSB7ICRjaGtGaXhQb2ludC5DaGVja2VkID0gJHRydWUgfSB9CiAgICAg
ICAgIlNNQiIgeyBpZiAoJGNoa0ZpeFNtYikgeyAkY2hrRml4U21iLkNoZWNrZWQgPSAkdHJ1ZSB9
IH0KICAgICAgICAiRklSRVdBTEwiIHsgaWYgKCRjaGtGaXhGaXJld2FsbCkgeyAkY2hrRml4Rmly
ZXdhbGwuQ2hlY2tlZCA9ICR0cnVlIH0gfQogICAgICAgICJTRVJWSUNFUyIgeyBpZiAoJGNoa0Zp
eFNlcnZpY2VzKSB7ICRjaGtGaXhTZXJ2aWNlcy5DaGVja2VkID0gJHRydWUgfSB9CiAgICAgICAg
IlNQT09MRVIiIHsgaWYgKCRjaGtGaXhTcG9vbGVyKSB7ICRjaGtGaXhTcG9vbGVyLkNoZWNrZWQg
PSAkdHJ1ZSB9IH0KICAgICAgICAiTlRMTSIgeyBpZiAoJGNoa0ZpeE50bG0pIHsgJGNoa0ZpeE50
bG0uQ2hlY2tlZCA9ICR0cnVlIH0gfQogICAgICAgICJDUkVERU5USUFMIiB7IGlmICgkY2hrRml4
Q3JlZGVudGlhbCkgeyAkY2hrRml4Q3JlZGVudGlhbC5DaGVja2VkID0gJHRydWUgfSB9CiAgICAg
ICAgIldPUktHUk9VUCIgeyBpZiAoJGNoa0ZpeFdvcmtncm91cCkgeyAkY2hrRml4V29ya2dyb3Vw
LkNoZWNrZWQgPSAkdHJ1ZSB9IH0KICAgICAgICAiRFJJVkVSIiB7IGlmICgkY2hrRml4RHJpdmVy
KSB7ICRjaGtGaXhEcml2ZXIuQ2hlY2tlZCA9ICR0cnVlIH0gfQogICAgfQp9CgpmdW5jdGlvbiBD
bGVhci1BbGxGaXhDaGVja3MgewogICAgZm9yZWFjaCAoJGMgaW4gQCgkY2hrRml4UnBjLCRjaGtG
aXhQb2ludCwkY2hrRml4U21iLCRjaGtGaXhGaXJld2FsbCwkY2hrRml4U2VydmljZXMsJGNoa0Zp
eFNwb29sZXIsJGNoa0ZpeE50bG0sJGNoa0ZpeENyZWRlbnRpYWwsJGNoa0ZpeERyaXZlciwkY2hr
Rml4V29ya2dyb3VwKSkgewogICAgICAgIGlmICgkYykgeyAkYy5DaGVja2VkID0gJGZhbHNlIH0K
ICAgIH0KfQoKZnVuY3Rpb24gR2V0LVJlY29tbWVuZGVkRml4ZXNGcm9tRGlhZyB7CiAgICAkZml4
ZXMgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkhhc2hTZXRbc3RyaW5n
XQoKICAgIGZvcmVhY2ggKCRkIGluICRzY3JpcHQ6RGlhZ0l0ZW1zKSB7CiAgICAgICAgJHQgPSAo
InswfSB7MX0gezJ9IHszfSB7NH0iIC1mICRkLkthdGVnb3JpLCRkLkFkLCRkLkR1cnVtLCRkLkRl
dGF5LCRkLk9uZXJpKS5Ub0xvd2VySW52YXJpYW50KCkKCiAgICAgICAgaWYgKCR0IC1tYXRjaCAi
cnBjfDEzNXwweDAwMDAwMTFifG5hbWVkIHBpcGV8cnBjYXV0aG4iKSB7CiAgICAgICAgICAgIFt2
b2lkXSRmaXhlcy5BZGQoIlJQQyIpCiAgICAgICAgICAgIFt2b2lkXSRmaXhlcy5BZGQoIlNFUlZJ
Q0VTIikKICAgICAgICB9CiAgICAgICAgaWYgKCR0IC1tYXRjaCAicG9pbnR8cHJpbnR8NzA5fHJl
c3RyaWN0ZHJpdmVyfHBhY2thZ2UiKSB7CiAgICAgICAgICAgIFt2b2lkXSRmaXhlcy5BZGQoIlBP
SU5UUFJJTlQiKQogICAgICAgICAgICBbdm9pZF0kZml4ZXMuQWRkKCJTRVJWSUNFUyIpCiAgICAg
ICAgfQogICAgICAgIGlmICgkdCAtbWF0Y2ggIjQ0NXxzbWJ8bmV0IHZpZXd8cGF5bGHFn8SxbXxz
aGFyZXxhY2Nlc3MgaXMgZGVuaWVkfGVyacWfaW0gZW5nZWxsZW5kaSIpIHsKICAgICAgICAgICAg
W3ZvaWRdJGZpeGVzLkFkZCgiU01CIikKICAgICAgICAgICAgW3ZvaWRdJGZpeGVzLkFkZCgiRklS
RVdBTEwiKQogICAgICAgICAgICBbdm9pZF0kZml4ZXMuQWRkKCJDUkVERU5USUFMIikKICAgICAg
ICB9CiAgICAgICAgaWYgKCR0IC1tYXRjaCAiZmlyZXdhbGx8ZGlzY292ZXJ5fHByaXZhdGV8cHVi
bGljfG5ldHdvcmsgcHJvZmlsZXxhxJ8gcHJvZmlsaSIpIHsKICAgICAgICAgICAgW3ZvaWRdJGZp
eGVzLkFkZCgiRklSRVdBTEwiKQogICAgICAgIH0KICAgICAgICBpZiAoJHQgLW1hdGNoICJzcG9v
bHxzcG9vbGVyfHF1ZXVlfGt1eXJ1ayIpIHsKICAgICAgICAgICAgW3ZvaWRdJGZpeGVzLkFkZCgi
U1BPT0xFUiIpCiAgICAgICAgICAgIFt2b2lkXSRmaXhlcy5BZGQoIlNFUlZJQ0VTIikKICAgICAg
ICB9CiAgICAgICAgaWYgKCR0IC1tYXRjaCAiZHJpdmVyfHPDvHLDvGPDvHwweDAwMDAwMDdjfHnD
vGtsZW5lbWVkaXxwYWNrYWdlIikgewogICAgICAgICAgICBbdm9pZF0kZml4ZXMuQWRkKCJEUklW
RVIiKQogICAgICAgICAgICBbdm9pZF0kZml4ZXMuQWRkKCJQT0lOVFBSSU5UIikKICAgICAgICAg
ICAgW3ZvaWRdJGZpeGVzLkFkZCgiU1BPT0xFUiIpCiAgICAgICAgfQogICAgICAgIGlmICgkdCAt
bWF0Y2ggImNyZWRlbnRpYWx8a2ltbGlrfHBhcm9sYXzFn2lmcmV8bmV0IHVzZXxkZW5pZWQiKSB7
CiAgICAgICAgICAgIFt2b2lkXSRmaXhlcy5BZGQoIkNSRURFTlRJQUwiKQogICAgICAgIH0KICAg
ICAgICBpZiAoJHQgLW1hdGNoICJuZXRiaW9zfG50bG18ZG5zfGFkIMOnw7Z6w7xtbGVtZXxob3N0
bmFtZSIpIHsKICAgICAgICAgICAgW3ZvaWRdJGZpeGVzLkFkZCgiTlRMTSIpCiAgICAgICAgfQog
ICAgICAgIGlmICgkdCAtbWF0Y2ggInRydXN0ZWRob3N0c3xsb2NhbGFjY291bnR0b2tlbmZpbHRl
cnBvbGljeXx3b3JrZ3JvdXB8d2lucm18eWVyZWwgaWxrZSIpIHsKICAgICAgICAgICAgW3ZvaWRd
JGZpeGVzLkFkZCgiV09SS0dST1VQIikKICAgICAgICB9CiAgICB9CgogICAgaWYgKCRmaXhlcy5D
b3VudCAtZXEgMCkgewogICAgICAgIFt2b2lkXSRmaXhlcy5BZGQoIlJQQyIpCiAgICAgICAgW3Zv
aWRdJGZpeGVzLkFkZCgiUE9JTlRQUklOVCIpCiAgICAgICAgW3ZvaWRdJGZpeGVzLkFkZCgiRklS
RVdBTEwiKQogICAgICAgIFt2b2lkXSRmaXhlcy5BZGQoIlNFUlZJQ0VTIikKICAgICAgICBbdm9p
ZF0kZml4ZXMuQWRkKCJTUE9PTEVSIikKICAgIH0KCiAgICByZXR1cm4gJGZpeGVzCn0KCmZ1bmN0
aW9uIEFwcGx5LVJlY29tbWVuZGVkRml4U2VsZWN0aW9uIHsKICAgIENsZWFyLUFsbEZpeENoZWNr
cwogICAgJGZpeGVzID0gR2V0LVJlY29tbWVuZGVkRml4ZXNGcm9tRGlhZwogICAgZm9yZWFjaCAo
JGYgaW4gJGZpeGVzKSB7IFNlbGVjdC1GaXhDaGVjayAkZiB9CgogICAgJHJvbGUgPSBHZXQtU2Vs
ZWN0ZWRSb2xlDQogICAgJG1zZyA9ICJBbGfEsWxhbmFuL1Nlw6dpbGkgcm9sOiAkcm9sZWByYG5g
cmBuw5ZuZXJpbGVuIGZpeGxlciBzZcOnaWxkaTpgcmBuIiArICgoJGZpeGVzIHwgU29ydC1PYmpl
Y3QpIC1qb2luICJgcmBuIikKICAgIE9LICJBdXRvIHJlbWVkaWF0aW9uIMO2bmVyaWxlcmkgc2XD
p2lsZGk6ICQoKCRmaXhlcyB8IFNvcnQtT2JqZWN0KSAtam9pbiAnLCAnKSIKICAgIFNob3ctSW5m
byAiw5ZuZXJpbGVuIETDvHplbHRtZWxlciIgJG1zZwp9CgpmdW5jdGlvbiBJbnZva2UtQXV0b1Jl
bWVkaWF0aW9uIHsKICAgIGlmICgkc2NyaXB0OkRpYWdJdGVtcy5Db3VudCAtZXEgMCkgewogICAg
ICAgIFdBUk4gIlRlxZ9oaXMgc29udWN1IHlvay4gw5ZuY2UgeWVyZWwgYXLEsXphIHRlc3BpdGkg
w6dhbMSxxZ90xLFyxLFsxLF5b3IuIgogICAgICAgIFJ1bi1Mb2NhbERpYWdub3NpcwogICAgfQoK
ICAgIEFwcGx5LVJlY29tbWVuZGVkRml4U2VsZWN0aW9uCiAgICAkcm9sZSA9IEdldC1TZWxlY3Rl
ZFJvbGUKICAgIEFwcGx5LVNlbGVjdGVkRml4ZXMgLVJvbGVMYWJlbCAkcm9sZQogICAgU2hvdy1J
bmZvICJBdXRvIFJlbWVkaWF0aW9uIiAiw5ZuZXJpbGVuIGTDvHplbHRtZWxlciB1eWd1bGFuZMSx
LmByYG5Sb2w6ICRyb2xlYHJgbkxvZzogJHNjcmlwdDpMb2dGaWxlIgp9CgpmdW5jdGlvbiBSdW4t
RW50ZXJwcmlzZVdvcmtmbG93IHsKICAgIFdyaXRlLUxvZyAiPT09IEVOVEVSUFJJU0UgV09SS0ZM
T1cgQkHFnkxBREkgPT09IgogICAgUnVuLUxvY2FsRGlhZ25vc2lzCgogICAgaWYgKC1ub3QgW3N0
cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkdHh0UmVtb3RlUGMuVGV4dC5UcmltKCkpKSB7CiAg
ICAgICAgUnVuLVJlbW90ZURpYWdub3NpcwogICAgfSBlbHNlIHsKICAgICAgICBXQVJOICJVemFr
IFBDL0lQIGdpcmlsbWVkaTsgcmVtb3RlIGhvc3QgYW5hbGl6aSBhdGxhbmTEsS4iCiAgICB9Cgog
ICAgQXBwbHktUmVjb21tZW5kZWRGaXhTZWxlY3Rpb24KICAgICRyb2xlID0gR2V0LVNlbGVjdGVk
Um9sZQogICAgQXBwbHktU2VsZWN0ZWRGaXhlcyAtUm9sZUxhYmVsICRyb2xlCgogICAgaWYgKC1u
b3QgW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkdHh0TWFudWFsVU5DLlRleHQuVHJpbSgp
KSAtYW5kICR0eHRNYW51YWxVTkMuVGV4dC5UcmltKCkgLW5lICJcXFBDQURJXFBBWUxBU0lNIikg
ewogICAgICAgIENvbm5lY3QtTWFudWFsUHJpbnRlcgogICAgfSBlbHNlIHsKICAgICAgICBXQVJO
ICJNYW51ZWwgVU5DIGdpcmlsbWVkaTsgb3RvbWF0aWsgYmHEn2xhbnTEsSBhZMSxbcSxIGF0bGFu
ZMSxLiIKICAgIH0KCiAgICBXcml0ZS1Mb2cgIj09PSBFTlRFUlBSSVNFIFdPUktGTE9XIELEsFRU
xLAgPT09IiAiT0siCiAgICBTaG93LUluZm8gIkVudGVycHJpc2UgV29ya2Zsb3ciICJFbnRlcnBy
aXNlIGnFnyBha8SxxZ/EsSB0YW1hbWxhbmTEsS5gcmBuTG9nOiAkc2NyaXB0OkxvZ0ZpbGUiCn0K
CgoKIyAtLS0tLS0tLS0tIFYyLjIgQkFDS1VQIC8gUkVTVE9SRSBFTkdJTkUgLS0tLS0tLS0tLQpm
dW5jdGlvbiBOZXctQmFja3VwU25hcHNob3QgewogICAgcGFyYW0oW3N0cmluZ10kUmVhc29uPSJN
YW51YWwiKQoKICAgICRpZCA9ICJCQUNLVVBfezB9IiAtZiAoR2V0LURhdGUgLUZvcm1hdCAieXl5
eV9NTV9kZF9ISG1tc3MiKQogICAgJGJhY2t1cFBhdGggPSBKb2luLVBhdGggJHNjcmlwdDpCYWNr
dXBSb290ICRpZAogICAgJHJlZ1BhdGggPSBKb2luLVBhdGggJGJhY2t1cFBhdGggInJlZ2lzdHJ5
IgoKICAgIE5ldy1JdGVtIC1QYXRoICRiYWNrdXBQYXRoIC1JdGVtVHlwZSBEaXJlY3RvcnkgLUZv
cmNlIHwgT3V0LU51bGwKICAgIE5ldy1JdGVtIC1QYXRoICRyZWdQYXRoIC1JdGVtVHlwZSBEaXJl
Y3RvcnkgLUZvcmNlIHwgT3V0LU51bGwKCiAgICBXcml0ZS1Mb2cgIlllZGVrIHNuYXBzaG90IG9s
dcWfdHVydWx1eW9yOiAkaWQgLyBTZWJlcDogJFJlYXNvbiIKCiAgICAkcmVnVGFyZ2V0cyA9IEAo
CiAgICAgICAgQHtOYW1lPSJDb250cm9sX1ByaW50IjsgUGF0aD0iSEtMTVxTWVNURU1cQ3VycmVu
dENvbnRyb2xTZXRcQ29udHJvbFxQcmludCJ9LAogICAgICAgIEB7TmFtZT0iUG9saWNpZXNfUHJp
bnRlcnMiOyBQYXRoPSJIS0xNXFNPRlRXQVJFXFBvbGljaWVzXE1pY3Jvc29mdFxXaW5kb3dzIE5U
XFByaW50ZXJzIn0sCiAgICAgICAgQHtOYW1lPSJMYW5tYW5TZXJ2ZXIiOyBQYXRoPSJIS0xNXFNZ
U1RFTVxDdXJyZW50Q29udHJvbFNldFxTZXJ2aWNlc1xMYW5tYW5TZXJ2ZXIifSwKICAgICAgICBA
e05hbWU9Ikxhbm1hbldvcmtzdGF0aW9uIjsgUGF0aD0iSEtMTVxTWVNURU1cQ3VycmVudENvbnRy
b2xTZXRcU2VydmljZXNcTGFubWFuV29ya3N0YXRpb24ifSwKICAgICAgICBAe05hbWU9IlNwb29s
ZXIiOyBQYXRoPSJIS0xNXFNZU1RFTVxDdXJyZW50Q29udHJvbFNldFxTZXJ2aWNlc1xTcG9vbGVy
In0sCiAgICAgICAgQHtOYW1lPSJQb2xpY2llc19TeXN0ZW0iOyBQYXRoPSJIS0xNXFNPRlRXQVJF
XE1pY3Jvc29mdFxXaW5kb3dzXEN1cnJlbnRWZXJzaW9uXFBvbGljaWVzXFN5c3RlbSJ9LAogICAg
ICAgIEB7TmFtZT0iTHNhIjsgUGF0aD0iSEtMTVxTWVNURU1cQ3VycmVudENvbnRyb2xTZXRcQ29u
dHJvbFxMc2EifQogICAgKQoKICAgIGZvcmVhY2ggKCRyIGluICRyZWdUYXJnZXRzKSB7CiAgICAg
ICAgdHJ5IHsKICAgICAgICAgICAgJG91dEZpbGUgPSBKb2luLVBhdGggJHJlZ1BhdGggKCRyLk5h
bWUgKyAiLnJlZyIpCiAgICAgICAgICAgICRjbWQgPSAncmVnIGV4cG9ydCAiezB9IiAiezF9IiAv
eScgLWYgJHIuUGF0aCwgJG91dEZpbGUKICAgICAgICAgICAgY21kIC9jICRjbWQgMj4mMSB8IEZv
ckVhY2gtT2JqZWN0IHsgV3JpdGUtTG9nICJSRUdfRVhQT1JUOiAkXyIgfQogICAgICAgICAgICBp
ZiAoVGVzdC1QYXRoICRvdXRGaWxlKSB7IE9LICJSZWdpc3RyeSB5ZWRla2xlbmRpOiAkKCRyLlBh
dGgpIiB9IGVsc2UgeyBXQVJOICJSZWdpc3RyeSBleHBvcnQgZG9zeWFzxLEgb2x1xZ9tYWTEsTog
JCgkci5QYXRoKSIgfQogICAgICAgIH0gY2F0Y2ggewogICAgICAgICAgICBXQVJOICJSZWdpc3Ry
eSBleHBvcnQgaGF0YXPEsSAkKCRyLlBhdGgpOiAkXyIKICAgICAgICB9CiAgICB9CgogICAgdHJ5
IHsKICAgICAgICAkc2VydmljZXMgPSBmb3JlYWNoICgkc3ZjIGluIEAoIlNwb29sZXIiLCJXaW5S
TSIsIkZEUmVzUHViIiwiU1NEUFNSViIsInVwbnBob3N0IiwiTGFubWFuU2VydmVyIiwiTGFubWFu
V29ya3N0YXRpb24iLCJScGNTcyIsIlJwY0VwdE1hcHBlciIpKSB7CiAgICAgICAgICAgICRzID0g
R2V0LVNlcnZpY2UgLU5hbWUgJHN2YyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAg
ICAgICAgICBpZiAoJHMpIHsKICAgICAgICAgICAgICAgICR3ID0gR2V0LUNpbUluc3RhbmNlIFdp
bjMyX1NlcnZpY2UgLUZpbHRlciAiTmFtZT0nJHN2YyciIC1FcnJvckFjdGlvbiBTaWxlbnRseUNv
bnRpbnVlCiAgICAgICAgICAgICAgICBbUFNDdXN0b21PYmplY3RdQHsKICAgICAgICAgICAgICAg
ICAgICBOYW1lPSRzdmMKICAgICAgICAgICAgICAgICAgICBTdGF0dXM9IiQoJHMuU3RhdHVzKSIK
ICAgICAgICAgICAgICAgICAgICBTdGFydFR5cGU9IGlmICgkdykgeyAiJCgkdy5TdGFydE1vZGUp
IiB9IGVsc2UgeyAiIiB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICB9
CiAgICAgICAgJHNlcnZpY2VzIHwgQ29udmVydFRvLUpzb24gLURlcHRoIDQgfCBTZXQtQ29udGVu
dCAtUGF0aCAoSm9pbi1QYXRoICRiYWNrdXBQYXRoICJzZXJ2aWNlcy5qc29uIikgLUVuY29kaW5n
IFVURjgKICAgICAgICBPSyAiU2VydmlzIHNuYXBzaG90IGFsxLFuZMSxIgogICAgfSBjYXRjaCB7
IFdBUk4gIlNlcnZpcyBzbmFwc2hvdCBoYXRhc8SxOiAkXyIgfQoKICAgIHRyeSB7CiAgICAgICAg
R2V0LVByaW50ZXIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBTZWxlY3QtT2JqZWN0
IE5hbWUsU2hhcmVOYW1lLFNoYXJlZCxQb3J0TmFtZSxEcml2ZXJOYW1lLFR5cGUsQ29tcHV0ZXJO
YW1lIHwKICAgICAgICAgICAgQ29udmVydFRvLUpzb24gLURlcHRoIDUgfCBTZXQtQ29udGVudCAt
UGF0aCAoSm9pbi1QYXRoICRiYWNrdXBQYXRoICJwcmludGVycy5qc29uIikgLUVuY29kaW5nIFVU
RjgKICAgICAgICBPSyAiWWF6xLFjxLEgc25hcHNob3QgYWzEsW5kxLEiCiAgICB9IGNhdGNoIHsg
V0FSTiAiWWF6xLFjxLEgc25hcHNob3QgaGF0YXPEsTogJF8iIH0KCiAgICB0cnkgewogICAgICAg
IEdldC1QcmludGVyUG9ydCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFNlbGVjdC1P
YmplY3QgTmFtZSxQcmludGVySG9zdEFkZHJlc3MsUG9ydE51bWJlcixQcm90b2NvbCB8CiAgICAg
ICAgICAgIENvbnZlcnRUby1Kc29uIC1EZXB0aCA1IHwgU2V0LUNvbnRlbnQgLVBhdGggKEpvaW4t
UGF0aCAkYmFja3VwUGF0aCAicHJpbnRlcl9wb3J0cy5qc29uIikgLUVuY29kaW5nIFVURjgKICAg
ICAgICBPSyAiWWF6xLFjxLEgcG9ydCBzbmFwc2hvdCBhbMSxbmTEsSIKICAgIH0gY2F0Y2ggeyBX
QVJOICJZYXrEsWPEsSBwb3J0IHNuYXBzaG90IGhhdGFzxLE6ICRfIiB9CgogICAgdHJ5IHsKICAg
ICAgICBuZXRzaCBhZHZmaXJld2FsbCBleHBvcnQgKEpvaW4tUGF0aCAkYmFja3VwUGF0aCAiZmly
ZXdhbGwud2Z3IikgMj4mMSB8IEZvckVhY2gtT2JqZWN0IHsgV3JpdGUtTG9nICJGSVJFV0FMTF9F
WFBPUlQ6ICRfIiB9CiAgICAgICAgT0sgIkZpcmV3YWxsIHNuYXBzaG90IGFsxLFuZMSxIgogICAg
fSBjYXRjaCB7IFdBUk4gIkZpcmV3YWxsIHNuYXBzaG90IGhhdGFzxLE6ICRfIiB9CgogICAgdHJ5
IHsKICAgICAgICBjbWRrZXkgL2xpc3QgMj4mMSB8IFNldC1Db250ZW50IC1QYXRoIChKb2luLVBh
dGggJGJhY2t1cFBhdGggImNyZWRlbnRpYWxzX3RhcmdldHMudHh0IikgLUVuY29kaW5nIFVURjgK
ICAgICAgICBPSyAiQ3JlZGVudGlhbCBoZWRlZmxlcmkgbG9nbGFuZMSxIgogICAgfSBjYXRjaCB7
IFdBUk4gIkNyZWRlbnRpYWwgaGVkZWYgbG9nIGhhdGFzxLE6ICRfIiB9CgogICAgdHJ5IHsKICAg
ICAgICAkc25hcHNob3QgPSBbUFNDdXN0b21PYmplY3RdQHsKICAgICAgICAgICAgSWQ9JGlkCiAg
ICAgICAgICAgIFJlYXNvbj0kUmVhc29uCiAgICAgICAgICAgIENvbXB1dGVyPSRlbnY6Q09NUFVU
RVJOQU1FCiAgICAgICAgICAgIFVzZXI9JGVudjpVU0VSTkFNRQogICAgICAgICAgICBEYXRlPShH
ZXQtRGF0ZSkuVG9TdHJpbmcoInMiKQogICAgICAgICAgICBUb29sPSRzY3JpcHQ6QXBwQ29kZQog
ICAgICAgICAgICBQYXRoPSRiYWNrdXBQYXRoCiAgICAgICAgfQogICAgICAgICRzbmFwc2hvdCB8
IENvbnZlcnRUby1Kc29uIC1EZXB0aCA1IHwgU2V0LUNvbnRlbnQgLVBhdGggKEpvaW4tUGF0aCAk
YmFja3VwUGF0aCAic25hcHNob3QuanNvbiIpIC1FbmNvZGluZyBVVEY4CiAgICB9IGNhdGNoIHt9
CgogICAgJHNjcmlwdDpMYXN0QmFja3VwUGF0aCA9ICRiYWNrdXBQYXRoCiAgICBPSyAiWWVkZWsg
c25hcHNob3QgdGFtYW1sYW5kxLE6ICRiYWNrdXBQYXRoIgogICAgU2hvdy1JbmZvICJZZWRlayBB
bMSxbmTEsSIgIkF5YXIgeWVkZcSfaSBvbHXFn3R1cnVsZHU6YHJgbiRiYWNrdXBQYXRoIgogICAg
cmV0dXJuICRiYWNrdXBQYXRoCn0KCmZ1bmN0aW9uIEdldC1MYXRlc3RCYWNrdXBQYXRoIHsKICAg
IHRyeSB7CiAgICAgICAgJGxhdGVzdCA9IEdldC1DaGlsZEl0ZW0gLVBhdGggJHNjcmlwdDpCYWNr
dXBSb290IC1EaXJlY3RvcnkgLUZpbHRlciAiQkFDS1VQXyoiIC1FcnJvckFjdGlvbiBTaWxlbnRs
eUNvbnRpbnVlIHwKICAgICAgICAgICAgU29ydC1PYmplY3QgTGFzdFdyaXRlVGltZSAtRGVzY2Vu
ZGluZyB8CiAgICAgICAgICAgIFNlbGVjdC1PYmplY3QgLUZpcnN0IDEKICAgICAgICBpZiAoJGxh
dGVzdCkgeyByZXR1cm4gJGxhdGVzdC5GdWxsTmFtZSB9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1
cm4gIiIKfQoKZnVuY3Rpb24gUmVzdG9yZS1CYWNrdXBTbmFwc2hvdCB7CiAgICBwYXJhbShbc3Ry
aW5nXSRCYWNrdXBQYXRoPSIiKQoKICAgIGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNl
KCRCYWNrdXBQYXRoKSkgewogICAgICAgICRCYWNrdXBQYXRoID0gR2V0LUxhdGVzdEJhY2t1cFBh
dGgKICAgIH0KCiAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkQmFja3VwUGF0
aCkgLW9yICEoVGVzdC1QYXRoICRCYWNrdXBQYXRoKSkgewogICAgICAgIFNob3ctV2FybiAiWWVk
ZWsgQnVsdW5hbWFkxLEiICJHZXJpIHnDvGtsZW5lY2VrIGJhY2t1cCBidWx1bmFtYWTEsS4iCiAg
ICAgICAgcmV0dXJuCiAgICB9CgogICAgJGFuc3dlciA9IFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5N
ZXNzYWdlQm94XTo6U2hvdygKICAgICAgICAiU2XDp2lsZW4geWVkZWsgZ2VyaSB5w7xrbGVuZWNl
azpgcmBuJEJhY2t1cFBhdGhgcmBuYHJgbkRldmFtIGVkaWxzaW4gbWk/IiwKICAgICAgICAiWWVk
ZWt0ZW4gR2VyaSBZw7xrbGUiLAogICAgICAgIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdl
Qm94QnV0dG9uc106Olllc05vLAogICAgICAgIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdl
Qm94SWNvbl06Oldhcm5pbmcKICAgICkKICAgIGlmICgkYW5zd2VyIC1uZSBbU3lzdGVtLldpbmRv
d3MuRm9ybXMuRGlhbG9nUmVzdWx0XTo6WWVzKSB7CiAgICAgICAgV0FSTiAiR2VyaSB5w7xrbGVt
ZSBpcHRhbCBlZGlsZGkiCiAgICAgICAgcmV0dXJuCiAgICB9CgogICAgV3JpdGUtTG9nICJZZWRl
a3RlbiBnZXJpIHnDvGtsZW1lIGJhxZ9sxLF5b3I6ICRCYWNrdXBQYXRoIgoKICAgICRyZWdQYXRo
ID0gSm9pbi1QYXRoICRCYWNrdXBQYXRoICJyZWdpc3RyeSIKICAgIGlmIChUZXN0LVBhdGggJHJl
Z1BhdGgpIHsKICAgICAgICBHZXQtQ2hpbGRJdGVtIC1QYXRoICRyZWdQYXRoIC1GaWx0ZXIgIiou
cmVnIiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IEZvckVhY2gtT2JqZWN0IHsKICAg
ICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgIGNtZCAvYyAoJ3JlZyBpbXBvcnQgInswfSIn
IC1mICRfLkZ1bGxOYW1lKSAyPiYxIHwgRm9yRWFjaC1PYmplY3QgeyBXcml0ZS1Mb2cgIlJFR19J
TVBPUlQ6ICRfIiB9CiAgICAgICAgICAgICAgICBPSyAiUmVnaXN0cnkgZ2VyaSB5w7xrbGVuZGk6
ICQoJF8uTmFtZSkiCiAgICAgICAgICAgIH0gY2F0Y2ggewogICAgICAgICAgICAgICAgV0FSTiAi
UmVnaXN0cnkgaW1wb3J0IGhhdGFzxLEgJCgkXy5OYW1lKTogJF8iCiAgICAgICAgICAgIH0KICAg
ICAgICB9CiAgICB9CgogICAgJGZ3ID0gSm9pbi1QYXRoICRCYWNrdXBQYXRoICJmaXJld2FsbC53
ZnciCiAgICBpZiAoVGVzdC1QYXRoICRmdykgewogICAgICAgIHRyeSB7CiAgICAgICAgICAgIG5l
dHNoIGFkdmZpcmV3YWxsIGltcG9ydCAkZncgMj4mMSB8IEZvckVhY2gtT2JqZWN0IHsgV3JpdGUt
TG9nICJGSVJFV0FMTF9JTVBPUlQ6ICRfIiB9CiAgICAgICAgICAgIE9LICJGaXJld2FsbCB5ZWRl
xJ9pIGdlcmkgecO8a2xlbmRpIgogICAgICAgIH0gY2F0Y2ggeyBXQVJOICJGaXJld2FsbCBnZXJp
IHnDvGtsZW1lIGhhdGFzxLE6ICRfIiB9CiAgICB9CgogICAgJHN2Y0ZpbGUgPSBKb2luLVBhdGgg
JEJhY2t1cFBhdGggInNlcnZpY2VzLmpzb24iCiAgICBpZiAoVGVzdC1QYXRoICRzdmNGaWxlKSB7
CiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHN2Y3MgPSBHZXQtQ29udGVudCAkc3ZjRmlsZSAt
UmF3IHwgQ29udmVydEZyb20tSnNvbgogICAgICAgICAgICBmb3JlYWNoICgkcyBpbiAkc3Zjcykg
ewogICAgICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICAgICBpZiAoJHMuU3RhcnRU
eXBlKSB7CiAgICAgICAgICAgICAgICAgICAgICAgIHN3aXRjaCAtUmVnZXggKCRzLlN0YXJ0VHlw
ZSkgewogICAgICAgICAgICAgICAgICAgICAgICAgICAgIkF1dG8iIHsgU2V0LVNlcnZpY2UgLU5h
bWUgJHMuTmFtZSAtU3RhcnR1cFR5cGUgQXV0b21hdGljIC1FcnJvckFjdGlvbiBTaWxlbnRseUNv
bnRpbnVlIH0KICAgICAgICAgICAgICAgICAgICAgICAgICAgICJNYW51YWwiIHsgU2V0LVNlcnZp
Y2UgLU5hbWUgJHMuTmFtZSAtU3RhcnR1cFR5cGUgTWFudWFsIC1FcnJvckFjdGlvbiBTaWxlbnRs
eUNvbnRpbnVlIH0KICAgICAgICAgICAgICAgICAgICAgICAgICAgICJEaXNhYmxlZCIgeyBTZXQt
U2VydmljZSAtTmFtZSAkcy5OYW1lIC1TdGFydHVwVHlwZSBEaXNhYmxlZCAtRXJyb3JBY3Rpb24g
U2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAg
ICAgICAgICB9CiAgICAgICAgICAgICAgICAgICAgaWYgKCRzLlN0YXR1cyAtZXEgIlJ1bm5pbmci
KSB7IFN0YXJ0LVNlcnZpY2UgLU5hbWUgJHMuTmFtZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250
aW51ZSB9CiAgICAgICAgICAgICAgICAgICAgaWYgKCRzLlN0YXR1cyAtZXEgIlN0b3BwZWQiKSB7
IFN0b3AtU2VydmljZSAtTmFtZSAkcy5OYW1lIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlD
b250aW51ZSB9CiAgICAgICAgICAgICAgICAgICAgT0sgIlNlcnZpcyBnZXJpIHnDvGtsZW5kaTog
JCgkcy5OYW1lKSIKICAgICAgICAgICAgICAgIH0gY2F0Y2ggeyBXQVJOICJTZXJ2aXMgcmVzdG9y
ZSBoYXRhc8SxICQoJHMuTmFtZSk6ICRfIiB9CiAgICAgICAgICAgIH0KICAgICAgICB9IGNhdGNo
IHsgV0FSTiAiU2VydmlzIHJlc3RvcmUgZG9zeWFzxLEgb2t1bmFtYWTEsTogJF8iIH0KICAgIH0K
CiAgICB0cnkgeyBSZXN0YXJ0LVNlcnZpY2UgU3Bvb2xlciAtRm9yY2UgLUVycm9yQWN0aW9uIFNp
bGVudGx5Q29udGludWU7IE9LICJTcG9vbGVyIHllbmlkZW4gYmHFn2xhdMSxbGTEsSIgfSBjYXRj
aCB7fQoKICAgIFNob3ctV2FybiAiR2VyaSBZw7xrbGVtZSBUYW1hbWxhbmTEsSIgIlllZGVrIGdl
cmkgecO8a2xlbmRpLmByYG5EZcSfacWfaWtsaWtsZXJpbiB0YW0gdXlndWxhbm1hc8SxIGnDp2lu
IGJpbGdpc2F5YXLEsSB5ZW5pZGVuIGJhxZ9sYXRtYW7EsXogw7ZuZXJpbGlyLiIKfQoKZnVuY3Rp
b24gT3Blbi1CYWNrdXBGb2xkZXIgewogICAgdHJ5IHsKICAgICAgICBpZiAoIShUZXN0LVBhdGgg
JHNjcmlwdDpCYWNrdXBSb290KSkgeyBOZXctSXRlbSAtUGF0aCAkc2NyaXB0OkJhY2t1cFJvb3Qg
LUl0ZW1UeXBlIERpcmVjdG9yeSAtRm9yY2UgfCBPdXQtTnVsbCB9CiAgICAgICAgU3RhcnQtUHJv
Y2VzcyBleHBsb3Jlci5leGUgJHNjcmlwdDpCYWNrdXBSb290CiAgICB9IGNhdGNoIHsgV0FSTiAi
QmFja3VwIGtsYXPDtnLDvCBhw6fEsWxhbWFkxLE6ICRfIiB9Cn0KCiMgLS0tLS0tLS0tLSBWMi4x
IFdPUktHUk9VUCBQQVRDSCAtLS0tLS0tLS0tCiRzY3JpcHQ6UmVzdGFydFJlcXVpcmVkID0gJGZh
bHNlCgpmdW5jdGlvbiBNYXJrLVJlc3RhcnRSZXF1aXJlZCB7CiAgICBwYXJhbShbc3RyaW5nXSRS
ZWFzb24pCiAgICAkc2NyaXB0OlJlc3RhcnRSZXF1aXJlZCA9ICR0cnVlCiAgICBXQVJOICJZZW5p
ZGVuIGJhxZ9sYXRtYSBnZXJla2ViaWxpcjogJFJlYXNvbiIKfQpmdW5jdGlvbiBFbnN1cmUtV2lu
Uk1TZXJ2aWNlTm9Qcm9tcHQgewogICAgdHJ5IHsKICAgICAgICBTZXQtU2VydmljZSBXaW5STSAt
U3RhcnR1cFR5cGUgQXV0b21hdGljIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAg
ICAgJHN2YyA9IEdldC1TZXJ2aWNlIFdpblJNIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVl
CiAgICAgICAgaWYgKCRzdmMgLWFuZCAkc3ZjLlN0YXR1cyAtbmUgIlJ1bm5pbmciKSB7CiAgICAg
ICAgICAgIFN0YXJ0LVNlcnZpY2UgV2luUk0gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUK
ICAgICAgICAgICAgU3RhcnQtU2xlZXAgLU1pbGxpc2Vjb25kcyA1MDAKICAgICAgICB9CiAgICAg
ICAgcmV0dXJuICR0cnVlCiAgICB9IGNhdGNoIHsKICAgICAgICBXQVJOICJXaW5STSBzZXJ2aXNp
IHNlc3NpeiBiYcWfbGF0xLFsYW1hZMSxOiAkXyIKICAgICAgICByZXR1cm4gJGZhbHNlCiAgICB9
Cn0KCmZ1bmN0aW9uIEFwcGx5LVRydXN0ZWRIb3N0c0NsaWVudEZpeCB7CiAgICBXcml0ZS1Mb2cg
IlRydXN0ZWRIb3N0cyBjbGllbnQgdXl1bWx1bHXEn3UgdXlndWxhbsSxeW9yLi4uIgogICAgdHJ5
IHsKICAgICAgICAkc2VydmVyID0gIiIKICAgICAgICB0cnkgeyAkc2VydmVyID0gJHR4dFJlbW90
ZVBjLlRleHQuVHJpbSgpIH0gY2F0Y2gge30KICAgICAgICBpZiAoW3N0cmluZ106OklzTnVsbE9y
V2hpdGVTcGFjZSgkc2VydmVyKSkgewogICAgICAgICAgICB0cnkgeyAkc2VydmVyID0gR2V0LVNl
cnZlckZyb21VTkMgJHR4dE1hbnVhbFVOQy5UZXh0LlRyaW0oKSB9IGNhdGNoIHt9CiAgICAgICAg
fQogICAgICAgIGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRzZXJ2ZXIpIC1vciAk
c2VydmVyIC1lcSAiUENBREkiKSB7CiAgICAgICAgICAgIFdBUk4gIlRydXN0ZWRIb3N0cyBpw6dp
biBnZXLDp2VrIEhvc3QgUEMvSVAgZ2lyaWxtZWRpLiDEsMWfbGVtIGF0bGFuZMSxLiIKICAgICAg
ICAgICAgcmV0dXJuCiAgICAgICAgfQogICAgICAgIEVuc3VyZS1XaW5STVNlcnZpY2VOb1Byb21w
dCB8IE91dC1OdWxsCiAgICAgICAgU2V0LUl0ZW0gLVBhdGggV1NNYW46XGxvY2FsaG9zdFxDbGll
bnRcVHJ1c3RlZEhvc3RzIC1WYWx1ZSAkc2VydmVyIC1Db25jYXRlbmF0ZSAtRm9yY2UgLUVycm9y
QWN0aW9uIFN0b3AKICAgICAgICBPSyAiVHJ1c3RlZEhvc3RzIGxpc3Rlc2luZSBla2xlbmRpOiAk
c2VydmVyIgogICAgICAgIEFkZC1BY3Rpb24gIlRydXN0ZWRIb3N0cyIgIk9LIiAiQ2xpZW50IFRy
dXN0ZWRIb3N0cyArPSAkc2VydmVyIgogICAgfSBjYXRjaCB7IFdBUk4gIlRydXN0ZWRIb3N0cyB1
eWd1bGFuYW1hZMSxOiAkXyIgfQp9CgpmdW5jdGlvbiBBcHBseS1XaW5STUhvc3RGaXggewogICAg
V3JpdGUtTG9nICJXaW5STS9QU1JlbW90aW5nIGhvc3QgdXl1bWx1bHXEn3UgdXlndWxhbsSxeW9y
Li4uIgogICAgdHJ5IHsKICAgICAgICBFbnN1cmUtV2luUk1TZXJ2aWNlTm9Qcm9tcHQgfCBPdXQt
TnVsbAogICAgICAgIEVuYWJsZS1QU1JlbW90aW5nIC1Gb3JjZSAtU2tpcE5ldHdvcmtQcm9maWxl
Q2hlY2sgfCBPdXQtTnVsbAogICAgICAgIHdpbnJtIHF1aWNrY29uZmlnIC1xdWlldCAyPiYxIHwg
Rm9yRWFjaC1PYmplY3QgeyBXcml0ZS1Mb2cgIldJTlJNOiAkXyIgfQogICAgICAgIE9LICJXaW5S
TS9QU1JlbW90aW5nIGV0a2lubGXFn3RpcmlsZGkiCiAgICAgICAgQWRkLUFjdGlvbiAiV2luUk0g
SG9zdCIgIk9LIiAiRW5hYmxlLVBTUmVtb3RpbmcgKyBxdWlja2NvbmZpZyIKICAgIH0gY2F0Y2gg
eyBXQVJOICJXaW5STS9QU1JlbW90aW5nIHV5Z3VsYW5hbWFkxLE6ICRfIiB9Cn0KCmZ1bmN0aW9u
IEFwcGx5LUxvY2FsQWNjb3VudFRva2VuRmlsdGVyUG9saWN5IHsKICAgIFdyaXRlLUxvZyAiTG9j
YWxBY2NvdW50VG9rZW5GaWx0ZXJQb2xpY3kgdXlndWxhbsSxeW9yLi4uIgogICAgdHJ5IHsKICAg
ICAgICBTZXQtRFdvcmRTYWZlICJIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93c1xDdXJy
ZW50VmVyc2lvblxQb2xpY2llc1xTeXN0ZW0iICJMb2NhbEFjY291bnRUb2tlbkZpbHRlclBvbGlj
eSIgMQogICAgICAgIE9LICJMb2NhbEFjY291bnRUb2tlbkZpbHRlclBvbGljeT0xIHV5Z3VsYW5k
xLEiCiAgICAgICAgTWFyay1SZXN0YXJ0UmVxdWlyZWQgIkxvY2FsQWNjb3VudFRva2VuRmlsdGVy
UG9saWN5IgogICAgfSBjYXRjaCB7IFdBUk4gIkxvY2FsQWNjb3VudFRva2VuRmlsdGVyUG9saWN5
IHV5Z3VsYW5hbWFkxLE6ICRfIiB9Cn0KCmZ1bmN0aW9uIEFwcGx5LUFkdmFuY2VkUHJpbnRlclBv
bGljaWVzIHsKICAgIFdyaXRlLUxvZyAiR2VsacWfbWnFnyB5YXrEsWPEsSBncnVwIGlsa2VzaSB1
eXVtbHVsdWsgYXlhcmxhcsSxIHV5Z3VsYW7EsXlvci4uLiIKICAgIHRyeSB7CiAgICAgICAgJHBu
cCA9ICJIS0xNOlxTT0ZUV0FSRVxQb2xpY2llc1xNaWNyb3NvZnRcV2luZG93cyBOVFxQcmludGVy
c1xQb2ludEFuZFByaW50IgogICAgICAgIFNldC1EV29yZFNhZmUgJHBucCAiUmVzdHJpY3REcml2
ZXJJbnN0YWxsYXRpb25Ub0FkbWluaXN0cmF0b3JzIiAwCiAgICAgICAgU2V0LURXb3JkU2FmZSAk
cG5wICJOb1dhcm5pbmdOb0VsZXZhdGlvbk9uSW5zdGFsbCIgMQogICAgICAgIFNldC1EV29yZFNh
ZmUgJHBucCAiTm9XYXJuaW5nTm9FbGV2YXRpb25PblVwZGF0ZSIgMQogICAgICAgIFNldC1EV29y
ZFNhZmUgJHBucCAiVXBkYXRlUHJvbXB0U2V0dGluZ3MiIDAKICAgICAgICBTZXQtRFdvcmRTYWZl
ICRwbnAgIlRydXN0ZWRTZXJ2ZXJzIiAxCiAgICAgICAgU2V0LURXb3JkU2FmZSAkcG5wICJJbkZv
cmVzdCIgMAoKICAgICAgICAkc2VydmVyID0gIiIKICAgICAgICB0cnkgeyAkc2VydmVyID0gJHR4
dFJlbW90ZVBjLlRleHQuVHJpbSgpIH0gY2F0Y2gge30KICAgICAgICBpZiAoW3N0cmluZ106Oklz
TnVsbE9yV2hpdGVTcGFjZSgkc2VydmVyKSkgewogICAgICAgICAgICB0cnkgeyAkc2VydmVyID0g
R2V0LVNlcnZlckZyb21VTkMgJHR4dE1hbnVhbFVOQy5UZXh0LlRyaW0oKSB9IGNhdGNoIHt9CiAg
ICAgICAgfQogICAgICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHNl
cnZlcikgLWFuZCAkc2VydmVyIC1uZSAiUENBREkiKSB7CiAgICAgICAgICAgIFNldC1NdWx0aVN0
cmluZ1NhZmUgJHBucCAiU2VydmVyTGlzdCIgQCgkc2VydmVyKQogICAgICAgICAgICAkcGtnID0g
IkhLTE06XFNPRlRXQVJFXFBvbGljaWVzXE1pY3Jvc29mdFxXaW5kb3dzIE5UXFByaW50ZXJzXFBh
Y2thZ2VQb2ludEFuZFByaW50IgogICAgICAgICAgICBFbnN1cmUtS2V5ICRwa2cKICAgICAgICAg
ICAgU2V0LU11bHRpU3RyaW5nU2FmZSAkcGtnICJQYWNrYWdlUG9pbnRBbmRQcmludFNlcnZlckxp
c3QiIEAoJHNlcnZlcikKICAgICAgICAgICAgU2V0LURXb3JkU2FmZSAkcGtnICJQYWNrYWdlUG9p
bnRBbmRQcmludE9ubHkiIDAKICAgICAgICAgICAgT0sgIlRydXN0ZWQvUGFja2FnZSBQb2ludCBh
bmQgUHJpbnQgc2VydmVyIGxpc3Rlc2luZSBla2xlbmRpOiAkc2VydmVyIgogICAgICAgIH0KCiAg
ICAgICAgU2V0LURXb3JkU2FmZSAiSEtMTTpcU09GVFdBUkVcUG9saWNpZXNcTWljcm9zb2Z0XFdp
bmRvd3MgTlRcUHJpbnRlcnMiICJEaXNhYmxlSFRUUFByaW50aW5nIiAwCiAgICAgICAgU2V0LURX
b3JkU2FmZSAiSEtMTTpcU09GVFdBUkVcUG9saWNpZXNcTWljcm9zb2Z0XFdpbmRvd3MgTlRcUHJp
bnRlcnMiICJEaXNhYmxlV2ViUG5QRG93bmxvYWQiIDAKICAgICAgICBTZXQtRFdvcmRTYWZlICJI
S0xNOlxTT0ZUV0FSRVxQb2xpY2llc1xNaWNyb3NvZnRcV2luZG93cyBOVFxQcmludGVycyIgIlJl
Z2lzdGVyU3Bvb2xlclJlbW90ZVJwY0VuZFBvaW50IiAxCiAgICAgICAgU2V0LURXb3JkU2FmZSAi
SEtMTTpcU09GVFdBUkVcUG9saWNpZXNcTWljcm9zb2Z0XFdpbmRvd3MgTlRcUHJpbnRlcnMiICJS
ZW5kZXJQcmludEpvYnNPbkNsaWVudENvbXB1dGVycyIgMQogICAgICAgIFNldC1EV29yZFNhZmUg
IkhLTE06XFNPRlRXQVJFXFBvbGljaWVzXE1pY3Jvc29mdFxXaW5kb3dzIE5UXFByaW50ZXJzIiAi
Rm9yY2VDU1JFTUZEZXNwb29saW5nIiAwCiAgICAgICAgT0sgIkdlbGnFn21pxZ8geWF6xLFjxLEg
cG9saWN5bGVyaSB1eWd1bGFuZMSxIgogICAgICAgIE1hcmstUmVzdGFydFJlcXVpcmVkICJZYXrE
sWPEsSBwb2xpY3kgZGXEn2nFn2lrbGlrbGVyaSIKICAgIH0gY2F0Y2ggeyBXQVJOICJHZWxpxZ9t
acWfIHlhesSxY8SxIHBvbGljeWxlcmkgdXlndWxhbmFtYWTEsTogJF8iIH0KfQoKZnVuY3Rpb24g
QXBwbHktV29ya2dyb3VwQ29tcGF0aWJpbGl0eUZpeCB7CiAgICBXcml0ZS1Mb2cgIj09PSBXT1JL
R1JPVVAgLyBXSU4xMC1XSU4xMSBDT01QQVRJQklMSVRZIEZJWCBCQcWeTEFESSA9PT0iCiAgICAk
cm9sZSA9IEdldC1TZWxlY3RlZFJvbGUKICAgIGlmICgkcm9sZSAtZXEgIkhvc3QiIC1vciAkcm9s
ZSAtZXEgIkJvdGgiKSB7CiAgICAgICAgQXBwbHktV2luUk1Ib3N0Rml4CiAgICAgICAgQXBwbHkt
TG9jYWxBY2NvdW50VG9rZW5GaWx0ZXJQb2xpY3kKICAgICAgICBFbmFibGUtTmV0d29ya1Byb2Zp
bGVQcml2YXRlCiAgICAgICAgRW5hYmxlLVByaW50ZXJGaXJld2FsbAogICAgICAgIEVuc3VyZS1T
ZXJ2aWNlcwogICAgICAgIEFwcGx5LVJQQy1QcmludGVyQ29yZQogICAgICAgIEFwcGx5LVNNQi1D
b21wYXRpYmlsaXR5CiAgICB9CiAgICBpZiAoJHJvbGUgLWVxICJDbGllbnQiIC1vciAkcm9sZSAt
ZXEgIkJvdGgiKSB7CiAgICAgICAgQXBwbHktVHJ1c3RlZEhvc3RzQ2xpZW50Rml4CiAgICAgICAg
QXBwbHktQWR2YW5jZWRQcmludGVyUG9saWNpZXMKICAgICAgICBBcHBseS1SUEMtUHJpbnRlckNv
cmUKICAgICAgICBBcHBseS1Qb2ludEFuZFByaW50CiAgICAgICAgQXBwbHktQ3JlZGVudGlhbENs
ZWFudXAKICAgICAgICBFbnN1cmUtU2VydmljZXMKICAgICAgICBSZXNldC1TcG9vbGVyCiAgICB9
CiAgICBJbnZva2UtR1BVcGRhdGVTYWZlCiAgICBpZiAoJHNjcmlwdDpSZXN0YXJ0UmVxdWlyZWQp
IHsKICAgICAgICBTaG93LVdhcm4gIlllbmlkZW4gQmHFn2xhdG1hIMOWbmVyaWxpciIgIldvcmtn
cm91cC9Qb2xpY3kgZMO8emVsdG1lbGVyaSB1eWd1bGFuZMSxLmByYG5CYXrEsSBheWFybGFyxLFu
IHRhbSB1eWd1bGFubWFzxLEgacOnaW4gYmlsZ2lzYXlhcsSxIHllbmlkZW4gYmHFn2xhdG1hbsSx
eiDDtm5lcmlsaXIuIgogICAgfQogICAgV3JpdGUtTG9nICI9PT0gV09SS0dST1VQIC8gV0lOMTAt
V0lOMTEgQ09NUEFUSUJJTElUWSBGSVggQsSwVFTEsCA9PT0iICJPSyIKfQoKIyAtLS0tLS0tLS0t
IEdVSSAtLS0tLS0tLS0tCiRzY3JpcHQ6TGFuZ01vZGUgPSAiVFIiCiRzY3JpcHQ6RGFya01vZGUg
PSAkdHJ1ZQoKJGZvcm0gPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLkZvcm0KJGZv
cm0uVGV4dCA9ICRzY3JpcHQ6QXBwTmFtZQokZm9ybS5TaXplID0gTmV3LU9iamVjdCBTeXN0ZW0u
RHJhd2luZy5TaXplKDEyODAsODIwKQokZm9ybS5NaW5pbXVtU2l6ZSA9IE5ldy1PYmplY3QgU3lz
dGVtLkRyYXdpbmcuU2l6ZSgxMTAwLDcyMCkKJGZvcm0uU3RhcnRQb3NpdGlvbiA9ICJDZW50ZXJT
Y3JlZW4iCiRmb3JtLkJhY2tDb2xvciA9ICRDX0JnCiRmb3JtLkZvcmVDb2xvciA9ICRDX0ZnCnRy
eSB7ICRmb3JtLkljb24gPSBbU3lzdGVtLkRyYXdpbmcuSWNvbl06OkV4dHJhY3RBc3NvY2lhdGVk
SWNvbigiJGVudjpTeXN0ZW1Sb290XHN5c3RlbTMyXHNoZWxsMzIuZGxsIikgfSBjYXRjaCB7fQoK
JHJvb3QgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlRhYmxlTGF5b3V0UGFuZWwK
JHJvb3QuRG9jayA9ICJGaWxsIgokcm9vdC5Db2x1bW5Db3VudCA9IDIKJHJvb3QuUm93Q291bnQg
PSAxClt2b2lkXSRyb290LkNvbHVtblN0eWxlcy5BZGQoKE5ldy1PYmplY3QgU3lzdGVtLldpbmRv
d3MuRm9ybXMuQ29sdW1uU3R5bGUoW1N5c3RlbS5XaW5kb3dzLkZvcm1zLlNpemVUeXBlXTo6QWJz
b2x1dGUsMjQwKSkpClt2b2lkXSRyb290LkNvbHVtblN0eWxlcy5BZGQoKE5ldy1PYmplY3QgU3lz
dGVtLldpbmRvd3MuRm9ybXMuQ29sdW1uU3R5bGUoW1N5c3RlbS5XaW5kb3dzLkZvcm1zLlNpemVU
eXBlXTo6UGVyY2VudCwxMDApKSkKJGZvcm0uQ29udHJvbHMuQWRkKCRyb290KQoKJHNpZGUgPSBO
ZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlBhbmVsCiRzaWRlLkRvY2sgPSAiRmlsbCIK
JHNpZGUuQmFja0NvbG9yID0gJENfU2lkZQokcm9vdC5Db250cm9scy5BZGQoJHNpZGUsMCwwKQoK
JGJyYW5kID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5MYWJlbAokYnJhbmQuVGV4
dCA9ICJQUk4gRml4VG9vbCIKJGJyYW5kLkZvcmVDb2xvciA9ICRDX0ZnCiRicmFuZC5Gb250ID0g
TmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5Gb250KCJTZWdvZSBVSSIsMTcsW1N5c3RlbS5EcmF3
aW5nLkZvbnRTdHlsZV06OkJvbGQpCiRicmFuZC5Mb2NhdGlvbiA9IE5ldy1PYmplY3QgU3lzdGVt
LkRyYXdpbmcuUG9pbnQoMTgsMjIpCiRicmFuZC5BdXRvU2l6ZSA9ICR0cnVlCiRzaWRlLkNvbnRy
b2xzLkFkZCgkYnJhbmQpCgokYnJhbmRTdWIgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZv
cm1zLkxhYmVsCiRicmFuZFN1Yi5UZXh0ID0gIllhesSxY8SxIGJhxJ9sYW50xLEgdmUgb25hcsSx
bSIKJGJyYW5kU3ViLkZvcmVDb2xvciA9ICRDX011dGVkCiRicmFuZFN1Yi5Gb250ID0gTmV3LU9i
amVjdCBTeXN0ZW0uRHJhd2luZy5Gb250KCJTZWdvZSBVSSIsOSkKJGJyYW5kU3ViLkxvY2F0aW9u
ID0gTmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5Qb2ludCgyMCw1NikKJGJyYW5kU3ViLkF1dG9T
aXplID0gJHRydWUKJHNpZGUuQ29udHJvbHMuQWRkKCRicmFuZFN1YikKCmZ1bmN0aW9uIE5ldy1N
ZW51QnV0dG9uIHsKICAgIHBhcmFtKFtzdHJpbmddJFRleHQsW2ludF0kVG9wLFtzdHJpbmddJElj
b249IiIsW29iamVjdF0kQmFjaz0kbnVsbCkKICAgICRiID0gTmV3LU9iamVjdCBTeXN0ZW0uV2lu
ZG93cy5Gb3Jtcy5CdXR0b24KICAgICRiLlRleHQgPSBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hp
dGVTcGFjZSgkSWNvbikpIHsgJFRleHQgfSBlbHNlIHsgIiAgJEljb24gICRUZXh0IiB9CiAgICAk
Yi5Mb2NhdGlvbiA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuUG9pbnQoMTQsJFRvcCkKICAg
ICRiLlNpemUgPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlNpemUoMjEyLDQwKQogICAgJGIu
RmxhdFN0eWxlID0gIkZsYXQiCiAgICAkYi5GbGF0QXBwZWFyYW5jZS5Cb3JkZXJTaXplID0gMAog
ICAgJGIuVGV4dEFsaWduID0gIk1pZGRsZUxlZnQiCiAgICAkYi5Gb250ID0gTmV3LU9iamVjdCBT
eXN0ZW0uRHJhd2luZy5Gb250KCJTZWdvZSBVSSBFbW9qaSIsMTAsW1N5c3RlbS5EcmF3aW5nLkZv
bnRTdHlsZV06OkJvbGQpCiAgICAkYi5Gb3JlQ29sb3IgPSBpZiAoJEJhY2spIHsgW1N5c3RlbS5E
cmF3aW5nLkNvbG9yXTo6V2hpdGUgfSBlbHNlIHsgJENfTXV0ZWQgfQogICAgJGIuQmFja0NvbG9y
ID0gaWYgKCRCYWNrKSB7ICRCYWNrIH0gZWxzZSB7ICRDX1NpZGUgfQogICAgJGIuQ3Vyc29yID0g
W1N5c3RlbS5XaW5kb3dzLkZvcm1zLkN1cnNvcnNdOjpIYW5kCiAgICAkYi5UYWcgPSBpZiAoJEJh
Y2spIHsgIk1lbnVCdXR0b25BY3RpdmUiIH0gZWxzZSB7ICJNZW51QnV0dG9uIiB9CiAgICByZXR1
cm4gJGIKfQoKJGJ0bkRhc2hib2FyZCA9IE5ldy1NZW51QnV0dG9uICJBbmEgUGFuZWwiIDEwOCAk
c2NyaXB0Okljb25zLkRhc2hib2FyZCAkQ19BY2NlbnQKJGJ0bkZpbmRlciA9IE5ldy1NZW51QnV0
dG9uICJZYXrEsWPEsSBCYcSfbGEiIDE1NCAkc2NyaXB0Okljb25zLkZpbmRlcgokYnRuRml4ZXMg
PSBOZXctTWVudUJ1dHRvbiAiT25hcsSxbSIgMjAwICRzY3JpcHQ6SWNvbnMuRml4ZXMKJGJ0bkRy
aXZlciA9IE5ldy1NZW51QnV0dG9uICJTw7xyw7xjw7wgVGVtaXpsacSfaSIgMjQ2ICRzY3JpcHQ6
SWNvbnMuRHJpdmVyCiRidG5EaWFnID0gTmV3LU1lbnVCdXR0b24gIlRlc3BpdCIgMjkyICRzY3Jp
cHQ6SWNvbnMuRGlhZwokYnRuTG9ncyA9IE5ldy1NZW51QnV0dG9uICJLYXnEsXRsYXIiIDMzOCAk
c2NyaXB0Okljb25zLkxvZ3MKJGJ0bldvcmtmbG93ID0gTmV3LU1lbnVCdXR0b24gIkFrxLFsbMSx
IEFrxLHFnyIgNDA0ICRzY3JpcHQ6SWNvbnMuV29ya2Zsb3cgJENfT2sKJGJ0bkJhY2t1cCA9IE5l
dy1NZW51QnV0dG9uICJZZWRlayBBbCIgNDUwICRzY3JpcHQ6SWNvbnMuQmFja3VwCmZvcmVhY2gg
KCRiIGluIEAoJGJ0bkRhc2hib2FyZCwkYnRuRmluZGVyLCRidG5GaXhlcywkYnRuRHJpdmVyLCRi
dG5EaWFnLCRidG5Mb2dzLCRidG5Xb3JrZmxvdywkYnRuQmFja3VwKSkgeyAkc2lkZS5Db250cm9s
cy5BZGQoJGIpIH0KCiRtYWluID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5UYWJs
ZUxheW91dFBhbmVsCiRtYWluLkRvY2sgPSAiRmlsbCIKJG1haW4uUm93Q291bnQgPSAzCiRtYWlu
LkNvbHVtbkNvdW50ID0gMQpbdm9pZF0kbWFpbi5Sb3dTdHlsZXMuQWRkKChOZXctT2JqZWN0IFN5
c3RlbS5XaW5kb3dzLkZvcm1zLlJvd1N0eWxlKFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5TaXplVHlw
ZV06OkFic29sdXRlLDcyKSkpClt2b2lkXSRtYWluLlJvd1N0eWxlcy5BZGQoKE5ldy1PYmplY3Qg
U3lzdGVtLldpbmRvd3MuRm9ybXMuUm93U3R5bGUoW1N5c3RlbS5XaW5kb3dzLkZvcm1zLlNpemVU
eXBlXTo6UGVyY2VudCwxMDApKSkKW3ZvaWRdJG1haW4uUm93U3R5bGVzLkFkZCgoTmV3LU9iamVj
dCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5Sb3dTdHlsZShbU3lzdGVtLldpbmRvd3MuRm9ybXMuU2l6
ZVR5cGVdOjpBYnNvbHV0ZSwzNCkpKQokcm9vdC5Db250cm9scy5BZGQoJG1haW4sMSwwKQoKJGhl
YWRlciA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuUGFuZWwKJGhlYWRlci5Eb2Nr
ID0gIkZpbGwiCiRoZWFkZXIuQmFja0NvbG9yID0gJENfUGFuZWwKJG1haW4uQ29udHJvbHMuQWRk
KCRoZWFkZXIsMCwwKQoKJHBhZ2VUaXRsZSA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9y
bXMuTGFiZWwKJHBhZ2VUaXRsZS5UZXh0ID0gIkFuYSBQYW5lbCIKJHBhZ2VUaXRsZS5Gb3JlQ29s
b3IgPSAkQ19GZwokcGFnZVRpdGxlLkZvbnQgPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLkZv
bnQoIlNlZ29lIFVJIiwxOCxbU3lzdGVtLkRyYXdpbmcuRm9udFN0eWxlXTo6Qm9sZCkKJHBhZ2VU
aXRsZS5Mb2NhdGlvbiA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuUG9pbnQoMjAsMTgpCiRw
YWdlVGl0bGUuQXV0b1NpemUgPSAkdHJ1ZQokaGVhZGVyLkNvbnRyb2xzLkFkZCgkcGFnZVRpdGxl
KQoKJGJ0blRoZW1lID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5CdXR0b24KJGJ0
blRoZW1lLlRleHQgPSAiVGVtYSIKJGJ0blRoZW1lLlNpemUgPSBOZXctT2JqZWN0IFN5c3RlbS5E
cmF3aW5nLlNpemUoNzYsMzQpCiRidG5UaGVtZS5BbmNob3IgPSAiVG9wLFJpZ2h0IgokYnRuVGhl
bWUuTG9jYXRpb24gPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlBvaW50KDc4MCwxOSkKJGJ0
blRoZW1lLkJhY2tDb2xvciA9ICRDX1BhbmVsMgokYnRuVGhlbWUuRm9yZUNvbG9yID0gJENfRmcK
JGJ0blRoZW1lLkZsYXRTdHlsZSA9ICJGbGF0IgokaGVhZGVyLkNvbnRyb2xzLkFkZCgkYnRuVGhl
bWUpCiRoZWFkZXIuQWRkX1NpemVDaGFuZ2VkKHsgJGJ0blRoZW1lLkxlZnQgPSAkaGVhZGVyLldp
ZHRoIC0gOTYgfSkKCiRjb250ZW50ID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5Q
YW5lbAokY29udGVudC5Eb2NrID0gIkZpbGwiCiRjb250ZW50LlBhZGRpbmcgPSBOZXctT2JqZWN0
IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlBhZGRpbmcoMTYpCiRjb250ZW50LkJhY2tDb2xvciA9ICRD
X0JnCiRtYWluLkNvbnRyb2xzLkFkZCgkY29udGVudCwwLDEpCgokc3RhdHVzID0gTmV3LU9iamVj
dCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5QYW5lbAokc3RhdHVzLkRvY2sgPSAiRmlsbCIKJHN0YXR1
cy5CYWNrQ29sb3IgPSAkQ19QYW5lbAokbWFpbi5Db250cm9scy5BZGQoJHN0YXR1cywwLDIpCiRz
Y3JpcHQ6TGJsU3RhdHVzID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5MYWJlbAok
c2NyaXB0OkxibFN0YXR1cy5UZXh0ID0gIkhhesSxciIKJHNjcmlwdDpMYmxTdGF0dXMuRm9yZUNv
bG9yID0gJENfTXV0ZWQKJHNjcmlwdDpMYmxTdGF0dXMuTG9jYXRpb24gPSBOZXctT2JqZWN0IFN5
c3RlbS5EcmF3aW5nLlBvaW50KDEyLDgpCiRzY3JpcHQ6TGJsU3RhdHVzLkF1dG9TaXplID0gJHRy
dWUKJHN0YXR1cy5Db250cm9scy5BZGQoJHNjcmlwdDpMYmxTdGF0dXMpCgokcGFnZXMgPSBAe30K
Zm9yZWFjaCAoJG5hbWUgaW4gQCgiZGFzaGJvYXJkIiwiZmluZGVyIiwiZml4ZXMiLCJkcml2ZXIi
LCJkaWFnIiwibG9ncyIpKSB7CiAgICAkcCA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9y
bXMuUGFuZWwKICAgICRwLkRvY2sgPSAiRmlsbCIKICAgICRwLkJhY2tDb2xvciA9ICRDX0JnCiAg
ICAkcC5WaXNpYmxlID0gJGZhbHNlCiAgICAkY29udGVudC5Db250cm9scy5BZGQoJHApCiAgICAk
cGFnZXNbJG5hbWVdID0gJHAKfQoKZnVuY3Rpb24gU2V0LUFjdGl2ZU1lbnUgewogICAgcGFyYW0o
W3N0cmluZ10kTmFtZSkKICAgICRzaWRlQmcgPSBpZiAoJHNjcmlwdDpEYXJrTW9kZSkgeyAkQ19T
aWRlIH0gZWxzZSB7ICRMX1NpZGUgfQogICAgJG11dGVkID0gaWYgKCRzY3JpcHQ6RGFya01vZGUp
IHsgJENfTXV0ZWQgfSBlbHNlIHsgJExfTXV0ZWQgfQoKICAgIGZvcmVhY2ggKCRiIGluIEAoJGJ0
bkRhc2hib2FyZCwkYnRuRmluZGVyLCRidG5GaXhlcywkYnRuRHJpdmVyLCRidG5EaWFnLCRidG5M
b2dzKSkgewogICAgICAgICRiLkJhY2tDb2xvciA9ICRzaWRlQmcKICAgICAgICAkYi5Gb3JlQ29s
b3IgPSAkbXV0ZWQKICAgICAgICAkYi5UYWcgPSAiTWVudUJ1dHRvbiIKICAgIH0KICAgICR0YXJn
ZXQgPSBzd2l0Y2ggKCROYW1lKSB7CiAgICAgICAgImRhc2hib2FyZCIgeyAkcGFnZVRpdGxlLlRl
eHQgPSAiQW5hIFBhbmVsIjsgJGJ0bkRhc2hib2FyZCB9CiAgICAgICAgImZpbmRlciIgeyAkcGFn
ZVRpdGxlLlRleHQgPSAiWWF6xLFjxLEgQmHEn2xhIjsgJGJ0bkZpbmRlciB9CiAgICAgICAgImZp
eGVzIiB7ICRwYWdlVGl0bGUuVGV4dCA9ICJPbmFyxLFtIjsgJGJ0bkZpeGVzIH0KICAgICAgICAi
ZHJpdmVyIiB7ICRwYWdlVGl0bGUuVGV4dCA9ICJTw7xyw7xjw7wgVGVtaXpsacSfaSI7ICRidG5E
cml2ZXIgfQogICAgICAgICJkaWFnIiB7ICRwYWdlVGl0bGUuVGV4dCA9ICJUZXNwaXQiOyAkYnRu
RGlhZyB9CiAgICAgICAgImxvZ3MiIHsgJHBhZ2VUaXRsZS5UZXh0ID0gIkthecSxdGxhciI7ICRi
dG5Mb2dzIH0KICAgIH0KICAgIGlmICgkdGFyZ2V0KSB7CiAgICAgICAgJHRhcmdldC5CYWNrQ29s
b3IgPSAkQ19BY2NlbnQKICAgICAgICAkdGFyZ2V0LkZvcmVDb2xvciA9IFtTeXN0ZW0uRHJhd2lu
Zy5Db2xvcl06OldoaXRlCiAgICAgICAgJHRhcmdldC5UYWcgPSAiTWVudUJ1dHRvbkFjdGl2ZSIK
ICAgIH0KfQpmdW5jdGlvbiBTaG93LVBhZ2UgewogICAgcGFyYW0oW3N0cmluZ10kTmFtZSkKICAg
IGZvcmVhY2ggKCRrIGluICRwYWdlcy5LZXlzKSB7ICRwYWdlc1ska10uVmlzaWJsZSA9ICRmYWxz
ZSB9CiAgICAkcGFnZXNbJE5hbWVdLlZpc2libGUgPSAkdHJ1ZQogICAgJHBhZ2VzWyROYW1lXS5C
cmluZ1RvRnJvbnQoKQogICAgU2V0LUFjdGl2ZU1lbnUgJE5hbWUKfQpmdW5jdGlvbiBOZXctQWN0
aW9uQnV0dG9uIHsKICAgIHBhcmFtKFtzdHJpbmddJFRleHQsW29iamVjdF0kQmFjayxbaW50XSRX
aWR0aD0xMzApCiAgICAkYiA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuQnV0dG9u
CiAgICAkYi5UZXh0ID0gJFRleHQKICAgICRiLldpZHRoID0gJFdpZHRoCiAgICAkYi5IZWlnaHQg
PSAzNAogICAgJGIuTWFyZ2luID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5QYWRk
aW5nKDQpCiAgICAkYi5CYWNrQ29sb3IgPSAkQmFjawogICAgJGIuRm9yZUNvbG9yID0gW1N5c3Rl
bS5EcmF3aW5nLkNvbG9yXTo6V2hpdGUKICAgICRiLkZsYXRTdHlsZSA9ICJGbGF0IgogICAgJGIu
Rm9udCA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuRm9udCgiU2Vnb2UgVUkgRW1vamkiLDks
W1N5c3RlbS5EcmF3aW5nLkZvbnRTdHlsZV06OkJvbGQpCiAgICByZXR1cm4gJGIKfQpmdW5jdGlv
biBOZXctSW5mb0xhYmVsIHsKICAgIHBhcmFtKFtzdHJpbmddJFRleHQsW2ludF0kWSkKICAgICRs
ID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5MYWJlbAogICAgJGwuVGV4dCA9ICRU
ZXh0CiAgICAkbC5Gb3JlQ29sb3IgPSAkQ19NdXRlZAogICAgJGwuRm9udCA9IE5ldy1PYmplY3Qg
U3lzdGVtLkRyYXdpbmcuRm9udCgiU2Vnb2UgVUkiLDEwKQogICAgJGwuTG9jYXRpb24gPSBOZXct
T2JqZWN0IFN5c3RlbS5EcmF3aW5nLlBvaW50KDQsJFkpCiAgICAkbC5TaXplID0gTmV3LU9iamVj
dCBTeXN0ZW0uRHJhd2luZy5TaXplKDg4MCwyNCkKICAgIHJldHVybiAkbAp9CgojIERhc2hib2Fy
ZAokZGFzaCA9ICRwYWdlc1siZGFzaGJvYXJkIl0KJGRhc2guQ29udHJvbHMuQWRkKChOZXctSW5m
b0xhYmVsICJFbiBzxLFrIGt1bGxhbsSxbGFuIGFrxLHFnzogw7ZuY2UgdGVzcGl0LCBzb25yYSDD
tm5lcmlsZW4gb25hcsSxbSwgc29ucmEgeWF6xLFjxLEgYmHEn2xhbnTEsXPEsS4iIDgpKQokc2Ny
aXB0OkxibFJvbGVWYWx1ZSA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuTGFiZWwK
JHNjcmlwdDpMYmxSb2xlVmFsdWUuVGV4dCA9ICJSb2w6IEJlbGlyc2l6Igokc2NyaXB0OkxibFJv
bGVWYWx1ZS5Gb3JlQ29sb3IgPSAkQ19GZwokc2NyaXB0OkxibFJvbGVWYWx1ZS5Gb250ID0gTmV3
LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5Gb250KCJTZWdvZSBVSSIsMTMsW1N5c3RlbS5EcmF3aW5n
LkZvbnRTdHlsZV06OkJvbGQpCiRzY3JpcHQ6TGJsUm9sZVZhbHVlLkxvY2F0aW9uID0gTmV3LU9i
amVjdCBTeXN0ZW0uRHJhd2luZy5Qb2ludCg0LDQ4KQokc2NyaXB0OkxibFJvbGVWYWx1ZS5TaXpl
ID0gTmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5TaXplKDMyMCwzMikKJGRhc2guQ29udHJvbHMu
QWRkKCRzY3JpcHQ6TGJsUm9sZVZhbHVlKQoKJGRhc2hCdXR0b25zID0gTmV3LU9iamVjdCBTeXN0
ZW0uV2luZG93cy5Gb3Jtcy5GbG93TGF5b3V0UGFuZWwKJGRhc2hCdXR0b25zLkxvY2F0aW9uID0g
TmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5Qb2ludCgwLDk4KQokZGFzaEJ1dHRvbnMuU2l6ZSA9
IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuU2l6ZSg5NDAsNTIpCiRkYXNoQnV0dG9ucy5CYWNr
Q29sb3IgPSAkQ19CZwokZGFzaC5Db250cm9scy5BZGQoJGRhc2hCdXR0b25zKQokYnRuRGFzaERp
YWcgPSBOZXctQWN0aW9uQnV0dG9uICIkKCRzY3JpcHQ6SWNvbnMuRGlhZykgVGVzcGl0IFlhcCIg
JENfQWNjZW50IDE0MAokYnRuRGFzaFJlY29tbWVuZCA9IE5ldy1BY3Rpb25CdXR0b24gIiQoJHNj
cmlwdDpJY29ucy5SZWNvbW1lbmQpIMOWbmVyaWxlbmxlcmkgU2XDpyIgJENfV2FybiAxODAKJGJ0
bkRhc2hGaW5kID0gTmV3LUFjdGlvbkJ1dHRvbiAiJCgkc2NyaXB0Okljb25zLkZpbmRlcikgWWF6
xLFjxLEgQmHEn2xhIiAkQ19PayAxNTAKJGJ0bkRhc2hXb3JrZmxvdyA9IE5ldy1BY3Rpb25CdXR0
b24gIiQoJHNjcmlwdDpJY29ucy5Xb3JrZmxvdykgQWvEsWxsxLEgQWvEscWfIiAkQ19QYW5lbDIg
MTUwCmZvcmVhY2ggKCRiIGluIEAoJGJ0bkRhc2hEaWFnLCRidG5EYXNoUmVjb21tZW5kLCRidG5E
YXNoRmluZCwkYnRuRGFzaFdvcmtmbG93KSkgeyAkZGFzaEJ1dHRvbnMuQ29udHJvbHMuQWRkKCRi
KSB9CgojIEZpbmRlcgokZmluZGVyID0gJHBhZ2VzWyJmaW5kZXIiXQokZmluZGVyTGF5b3V0ID0g
TmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5UYWJsZUxheW91dFBhbmVsCiRmaW5kZXJM
YXlvdXQuRG9jayA9ICJGaWxsIgokZmluZGVyTGF5b3V0LlJvd0NvdW50ID0gMgokZmluZGVyTGF5
b3V0LkNvbHVtbkNvdW50ID0gMQpbdm9pZF0kZmluZGVyTGF5b3V0LlJvd1N0eWxlcy5BZGQoKE5l
dy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuUm93U3R5bGUoW1N5c3RlbS5XaW5kb3dzLkZv
cm1zLlNpemVUeXBlXTo6QWJzb2x1dGUsMTEyKSkpClt2b2lkXSRmaW5kZXJMYXlvdXQuUm93U3R5
bGVzLkFkZCgoTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5Sb3dTdHlsZShbU3lzdGVt
LldpbmRvd3MuRm9ybXMuU2l6ZVR5cGVdOjpQZXJjZW50LDEwMCkpKQokZmluZGVyLkNvbnRyb2xz
LkFkZCgkZmluZGVyTGF5b3V0KQoKJGZpbmRlclRvcCA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRv
d3MuRm9ybXMuRmxvd0xheW91dFBhbmVsCiRmaW5kZXJUb3AuRG9jayA9ICJGaWxsIgokZmluZGVy
VG9wLldyYXBDb250ZW50cyA9ICR0cnVlCiRmaW5kZXJUb3AuQXV0b1Njcm9sbCA9ICR0cnVlCiRm
aW5kZXJUb3AuQmFja0NvbG9yID0gJENfQmcKJGZpbmRlckxheW91dC5Db250cm9scy5BZGQoJGZp
bmRlclRvcCwwLDApCiRsYmxSZW1vdGUgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1z
LkxhYmVsCiRsYmxSZW1vdGUuVGV4dCA9ICJVemFrIFBDL0lQIgokbGJsUmVtb3RlLldpZHRoID0g
NzUKJGxibFJlbW90ZS5IZWlnaHQgPSAyOAokbGJsUmVtb3RlLkZvcmVDb2xvciA9ICRDX0ZnCiRs
YmxSZW1vdGUuVGV4dEFsaWduID0gIk1pZGRsZUxlZnQiCiRmaW5kZXJUb3AuQ29udHJvbHMuQWRk
KCRsYmxSZW1vdGUpCiR0eHRSZW1vdGVQYyA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9y
bXMuVGV4dEJveAokdHh0UmVtb3RlUGMuV2lkdGggPSAxNzAKJHR4dFJlbW90ZVBjLkZvbnQgPSBO
ZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLkZvbnQoIlNlZ29lIFVJIiwxMCkKJGZpbmRlclRvcC5D
b250cm9scy5BZGQoJHR4dFJlbW90ZVBjKQokYnRuU2NhbiA9IE5ldy1BY3Rpb25CdXR0b24gIiQo
JHNjcmlwdDpJY29ucy5Mb2NhbCkgQnUgUEMiICRDX0FjY2VudCAxMDAKJGJ0blJlbW90ZVNjYW4g
PSBOZXctQWN0aW9uQnV0dG9uICIkKCRzY3JpcHQ6SWNvbnMuUmVtb3RlKSBVemFrIFBDIFRhcmEi
ICRDX1dhcm4gMTUwCiRidG5Db25uZWN0ID0gTmV3LUFjdGlvbkJ1dHRvbiAiU2XDp2lsZW5pIEJh
xJ9sYSIgJENfT2sgMTUwCiRidG5SZW1vdmVTZWxlY3RlZFByaW50ZXIgPSBOZXctQWN0aW9uQnV0
dG9uICJTZcOnaWxlbmkgS2FsZMSxciIgJENfRXJyIDE1MApmb3JlYWNoICgkYiBpbiBAKCRidG5T
Y2FuLCRidG5SZW1vdGVTY2FuLCRidG5Db25uZWN0LCRidG5SZW1vdmVTZWxlY3RlZFByaW50ZXIp
KSB7ICRmaW5kZXJUb3AuQ29udHJvbHMuQWRkKCRiKSB9CiRjaGtBdXRvRml4QmVmb3JlU2NhbiA9
IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuQ2hlY2tCb3gKJGNoa0F1dG9GaXhCZWZv
cmVTY2FuLlRleHQgPSAiVGFyYW1hIMO2bmNlc2kgaGF6xLFybMSxayB5YXAiCiRjaGtBdXRvRml4
QmVmb3JlU2Nhbi5XaWR0aCA9IDE5MAokY2hrQXV0b0ZpeEJlZm9yZVNjYW4uSGVpZ2h0ID0gMjgK
JGNoa0F1dG9GaXhCZWZvcmVTY2FuLkZvcmVDb2xvciA9ICRDX011dGVkCiRjaGtBdXRvRml4QmVm
b3JlU2Nhbi5CYWNrQ29sb3IgPSAkQ19CZwokZmluZGVyVG9wLkNvbnRyb2xzLkFkZCgkY2hrQXV0
b0ZpeEJlZm9yZVNjYW4pCiRjaGtBdXRvRml4QmVmb3JlQ29ubmVjdCA9IE5ldy1PYmplY3QgU3lz
dGVtLldpbmRvd3MuRm9ybXMuQ2hlY2tCb3gKJGNoa0F1dG9GaXhCZWZvcmVDb25uZWN0LlRleHQg
PSAiQmHEn2xhbWFkYW4gw7ZuY2Ugb25hciIKJGNoa0F1dG9GaXhCZWZvcmVDb25uZWN0LldpZHRo
ID0gMTcwCiRjaGtBdXRvRml4QmVmb3JlQ29ubmVjdC5IZWlnaHQgPSAyOAokY2hrQXV0b0ZpeEJl
Zm9yZUNvbm5lY3QuRm9yZUNvbG9yID0gJENfTXV0ZWQKJGNoa0F1dG9GaXhCZWZvcmVDb25uZWN0
LkJhY2tDb2xvciA9ICRDX0JnCiRmaW5kZXJUb3AuQ29udHJvbHMuQWRkKCRjaGtBdXRvRml4QmVm
b3JlQ29ubmVjdCkKJGNoa1JlbW92ZU9sZCA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9y
bXMuQ2hlY2tCb3gKJGNoa1JlbW92ZU9sZC5UZXh0ID0gIkVza2kgYmHEn2xhbnTEsXnEsSB0ZW1p
emxlIgokY2hrUmVtb3ZlT2xkLldpZHRoID0gMTcwCiRjaGtSZW1vdmVPbGQuSGVpZ2h0ID0gMjgK
JGNoa1JlbW92ZU9sZC5Gb3JlQ29sb3IgPSAkQ19NdXRlZAokY2hrUmVtb3ZlT2xkLkJhY2tDb2xv
ciA9ICRDX0JnCiRmaW5kZXJUb3AuQ29udHJvbHMuQWRkKCRjaGtSZW1vdmVPbGQpCiR0eHRNYW51
YWxVTkMgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlRleHRCb3gKJHR4dE1hbnVh
bFVOQy5XaWR0aCA9IDI1MAokdHh0TWFudWFsVU5DLlRleHQgPSAiXFxQQ0FESVxQQVlMQVNJTSIK
JGZpbmRlclRvcC5Db250cm9scy5BZGQoJHR4dE1hbnVhbFVOQykKJGJ0bk1hbnVhbENvbm5lY3Qg
PSBOZXctQWN0aW9uQnV0dG9uICJVTkMgQmHEn2xhIiAkQ19QYW5lbDIgMTEwCiRmaW5kZXJUb3Au
Q29udHJvbHMuQWRkKCRidG5NYW51YWxDb25uZWN0KQoKJGdyaWRQcmludGVycyA9IE5ldy1PYmpl
Y3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuRGF0YUdyaWRWaWV3CiRncmlkUHJpbnRlcnMuRG9jayA9
ICJGaWxsIgokZ3JpZFByaW50ZXJzLkJhY2tncm91bmRDb2xvciA9ICRDX1BhbmVsCiRncmlkUHJp
bnRlcnMuQm9yZGVyU3R5bGUgPSAiTm9uZSIKJGdyaWRQcmludGVycy5Sb3dIZWFkZXJzVmlzaWJs
ZSA9ICRmYWxzZQokZ3JpZFByaW50ZXJzLkFsbG93VXNlclRvQWRkUm93cyA9ICRmYWxzZQokZ3Jp
ZFByaW50ZXJzLkFsbG93VXNlclRvRGVsZXRlUm93cyA9ICRmYWxzZQokZ3JpZFByaW50ZXJzLlJl
YWRPbmx5ID0gJHRydWUKJGdyaWRQcmludGVycy5TZWxlY3Rpb25Nb2RlID0gIkZ1bGxSb3dTZWxl
Y3QiCiRncmlkUHJpbnRlcnMuQXV0b1NpemVDb2x1bW5zTW9kZSA9ICJOb25lIgokZ3JpZFByaW50
ZXJzLlNjcm9sbEJhcnMgPSAiQm90aCIKJGdyaWRQcmludGVycy5FbmFibGVIZWFkZXJzVmlzdWFs
U3R5bGVzID0gJGZhbHNlCiRncmlkUHJpbnRlcnMuQ29sdW1uSGVhZGVyc0hlaWdodCA9IDM0CiRn
cmlkUHJpbnRlcnMuUm93VGVtcGxhdGUuSGVpZ2h0ID0gMzAKJGdyaWRQcmludGVycy5Db2x1bW5I
ZWFkZXJzRGVmYXVsdENlbGxTdHlsZS5CYWNrQ29sb3IgPSAkQ19QYW5lbDIKJGdyaWRQcmludGVy
cy5Db2x1bW5IZWFkZXJzRGVmYXVsdENlbGxTdHlsZS5Gb3JlQ29sb3IgPSAkQ19GZwokZ3JpZFBy
aW50ZXJzLkRlZmF1bHRDZWxsU3R5bGUuQmFja0NvbG9yID0gJENfUGFuZWwKJGdyaWRQcmludGVy
cy5EZWZhdWx0Q2VsbFN0eWxlLkZvcmVDb2xvciA9ICRDX0ZnCiRncmlkUHJpbnRlcnMuRGVmYXVs
dENlbGxTdHlsZS5TZWxlY3Rpb25CYWNrQ29sb3IgPSAkQ19BY2NlbnQKW3ZvaWRdJGdyaWRQcmlu
dGVycy5Db2x1bW5zLkFkZCgiVHlwZSIsIlTDvHIiKQpbdm9pZF0kZ3JpZFByaW50ZXJzLkNvbHVt
bnMuQWRkKCJOYW1lIiwiQWQiKQpbdm9pZF0kZ3JpZFByaW50ZXJzLkNvbHVtbnMuQWRkKCJTaGFy
ZU5hbWUiLCJQYXlsYcWfxLFtIikKW3ZvaWRdJGdyaWRQcmludGVycy5Db2x1bW5zLkFkZCgiVU5D
IiwiWW9sIikKW3ZvaWRdJGdyaWRQcmludGVycy5Db2x1bW5zLkFkZCgiRHJpdmVyIiwiU8O8csO8
Y8O8IikKW3ZvaWRdJGdyaWRQcmludGVycy5Db2x1bW5zLkFkZCgiU291cmNlIiwiS2F5bmFrIikK
W3ZvaWRdJGdyaWRQcmludGVycy5Db2x1bW5zLkFkZCgiTm90ZSIsIk5vdCIpCiRncmlkUHJpbnRl
cnMuQ29sdW1uc1siVHlwZSJdLldpZHRoID0gMTUwCiRncmlkUHJpbnRlcnMuQ29sdW1uc1siTmFt
ZSJdLldpZHRoID0gMjYwCiRncmlkUHJpbnRlcnMuQ29sdW1uc1siU2hhcmVOYW1lIl0uV2lkdGgg
PSAxNzAKJGdyaWRQcmludGVycy5Db2x1bW5zWyJVTkMiXS5XaWR0aCA9IDM0MAokZ3JpZFByaW50
ZXJzLkNvbHVtbnNbIkRyaXZlciJdLldpZHRoID0gMjgwCiRncmlkUHJpbnRlcnMuQ29sdW1uc1si
U291cmNlIl0uV2lkdGggPSA5MAokZ3JpZFByaW50ZXJzLkNvbHVtbnNbIk5vdGUiXS5XaWR0aCA9
IDQyMAokZmluZGVyTGF5b3V0LkNvbnRyb2xzLkFkZCgkZ3JpZFByaW50ZXJzLDAsMSkKCiMgRml4
ZXMKJGZpeGVzID0gJHBhZ2VzWyJmaXhlcyJdCiRmaXhlcy5Db250cm9scy5BZGQoKE5ldy1JbmZv
TGFiZWwgIlNvcnVudSBiaWxpeW9yc2FuxLF6IHlhbG7EsXpjYSBpbGdpbGkgb25hcsSxbWxhcsSx
IHNlw6dpbi4gRW1pbiBkZcSfaWxzZW5peiDDlm5lcmlsZW5sZXJpIFNlw6cga3VsbGFuxLFuLiIg
NCkpCiRjbWJSb2xlID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5Db21ib0JveAok
Y21iUm9sZS5Ecm9wRG93blN0eWxlID0gIkRyb3BEb3duTGlzdCIKW3ZvaWRdJGNtYlJvbGUuSXRl
bXMuQWRkKCJBdXRvIikKW3ZvaWRdJGNtYlJvbGUuSXRlbXMuQWRkKCJDbGllbnQiKQpbdm9pZF0k
Y21iUm9sZS5JdGVtcy5BZGQoIkhvc3QiKQpbdm9pZF0kY21iUm9sZS5JdGVtcy5BZGQoIkJvdGgi
KQokY21iUm9sZS5TZWxlY3RlZEluZGV4ID0gMAokY21iUm9sZS5Mb2NhdGlvbiA9IE5ldy1PYmpl
Y3QgU3lzdGVtLkRyYXdpbmcuUG9pbnQoNCwzOCkKJGNtYlJvbGUuV2lkdGggPSAxMzAKJGZpeGVz
LkNvbnRyb2xzLkFkZCgkY21iUm9sZSkKJGJ0blJlY29tbWVuZCA9IE5ldy1BY3Rpb25CdXR0b24g
IsOWbmVyaWxlbmxlcmkgU2XDpyIgJENfV2FybiAxNjAKJGJ0blJlY29tbWVuZC5Mb2NhdGlvbiA9
IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuUG9pbnQoMTUwLDM0KQokZml4ZXMuQ29udHJvbHMu
QWRkKCRidG5SZWNvbW1lbmQpCiRidG5SdW5GaXhlcyA9IE5ldy1BY3Rpb25CdXR0b24gIlNlw6dp
bGkgT25hcsSxbWxhcsSxIFV5Z3VsYSIgJENfQWNjZW50IDIxMAokYnRuUnVuRml4ZXMuTG9jYXRp
b24gPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlBvaW50KDMyMCwzNCkKJGZpeGVzLkNvbnRy
b2xzLkFkZCgkYnRuUnVuRml4ZXMpCiRsYmxGaXhTZWN0aW9uID0gTmV3LU9iamVjdCBTeXN0ZW0u
V2luZG93cy5Gb3Jtcy5MYWJlbAokbGJsRml4U2VjdGlvbi5UZXh0ID0gIsOWbmVyaWxlbiAvIHNl
w6dpbGViaWxpciBkw7x6ZWx0bWVsZXIiCiRsYmxGaXhTZWN0aW9uLkZvcmVDb2xvciA9ICRDX0Zn
CiRsYmxGaXhTZWN0aW9uLkZvbnQgPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLkZvbnQoIlNl
Z29lIFVJIiwxMixbU3lzdGVtLkRyYXdpbmcuRm9udFN0eWxlXTo6Qm9sZCkKJGxibEZpeFNlY3Rp
b24uTG9jYXRpb24gPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlBvaW50KDQsODIpCiRsYmxG
aXhTZWN0aW9uLlNpemUgPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlNpemUoMzYwLDI4KQok
Zml4ZXMuQ29udHJvbHMuQWRkKCRsYmxGaXhTZWN0aW9uKQoKJGxibEZpeFN1bW1hcnkgPSBOZXct
T2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLkxhYmVsCiRsYmxGaXhTdW1tYXJ5LlRleHQgPSAi
SGVuw7x6IHNlw6dpbSB5YXDEsWxtYWTEsS4gw5ZuZXJpbGVubGVyaSBTZcOnIGJ1dG9udW5hIGJh
c2FiaWxpcnNpbml6LiIKJGxibEZpeFN1bW1hcnkuRm9yZUNvbG9yID0gJENfTXV0ZWQKJGxibEZp
eFN1bW1hcnkuRm9udCA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuRm9udCgiU2Vnb2UgVUki
LDkpCiRsYmxGaXhTdW1tYXJ5LkxvY2F0aW9uID0gTmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5Q
b2ludCgzNzAsODYpCiRsYmxGaXhTdW1tYXJ5LlNpemUgPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3
aW5nLlNpemUoNTIwLDI0KQokZml4ZXMuQ29udHJvbHMuQWRkKCRsYmxGaXhTdW1tYXJ5KQoKJGZp
eExpc3QgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLkZsb3dMYXlvdXRQYW5lbAok
Zml4TGlzdC5Mb2NhdGlvbiA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuUG9pbnQoMCwxMTYp
CiRmaXhMaXN0LlNpemUgPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlNpemUoOTQwLDM5MCkK
JGZpeExpc3QuQXV0b1Njcm9sbCA9ICR0cnVlCiRmaXhMaXN0LkJhY2tDb2xvciA9ICRDX0JnCiRm
aXhlcy5Db250cm9scy5BZGQoJGZpeExpc3QpCiRjaGtGaXhScGM9JG51bGw7ICRjaGtGaXhQb2lu
dD0kbnVsbDsgJGNoa0ZpeFNtYj0kbnVsbDsgJGNoa0ZpeEZpcmV3YWxsPSRudWxsOyAkY2hrRml4
U2VydmljZXM9JG51bGw7ICRjaGtGaXhTcG9vbGVyPSRudWxsOyAkY2hrRml4TnRsbT0kbnVsbDsg
JGNoa0ZpeENyZWRlbnRpYWw9JG51bGw7ICRjaGtGaXhEcml2ZXI9JG51bGw7ICRjaGtGaXhXb3Jr
Z3JvdXA9JG51bGwKZnVuY3Rpb24gQWRkLVNpbXBsZUZpeENoZWNrIHsKICAgIHBhcmFtKFtzdHJp
bmddJFRleHQsW3N0cmluZ10kUm9sZSxbc3RyaW5nXSREZXNjLFtyZWZdJFJlZikKICAgICRjYXJk
ID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5QYW5lbAogICAgJGNhcmQuV2lkdGgg
PSA0MzAKICAgICRjYXJkLkhlaWdodCA9IDc2CiAgICAkY2FyZC5NYXJnaW4gPSBOZXctT2JqZWN0
IFN5c3RlbS5XaW5kb3dzLkZvcm1zLlBhZGRpbmcoOCkKICAgICRjYXJkLkJhY2tDb2xvciA9ICRD
X1BhbmVsCiAgICAkY2FyZC5UYWcgPSAiQ2FyZCIKCiAgICAkYyA9IE5ldy1PYmplY3QgU3lzdGVt
LldpbmRvd3MuRm9ybXMuQ2hlY2tCb3gKICAgICRjLlRleHQgPSAkVGV4dAogICAgJGMuV2lkdGgg
PSAyNzAKICAgICRjLkhlaWdodCA9IDI2CiAgICAkYy5Mb2NhdGlvbiA9IE5ldy1PYmplY3QgU3lz
dGVtLkRyYXdpbmcuUG9pbnQoMTAsOCkKICAgICRjLkZvcmVDb2xvciA9ICRDX0ZnCiAgICAkYy5C
YWNrQ29sb3IgPSAkQ19QYW5lbAogICAgJGMuRm9udCA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdp
bmcuRm9udCgiU2Vnb2UgVUkiLDEwLFtTeXN0ZW0uRHJhd2luZy5Gb250U3R5bGVdOjpCb2xkKQog
ICAgJGNhcmQuQ29udHJvbHMuQWRkKCRjKQoKICAgICRyb2xlTGFiZWwgPSBOZXctT2JqZWN0IFN5
c3RlbS5XaW5kb3dzLkZvcm1zLkxhYmVsCiAgICAkcm9sZUxhYmVsLlRleHQgPSAkUm9sZQogICAg
JHJvbGVMYWJlbC5XaWR0aCA9IDEzMAogICAgJHJvbGVMYWJlbC5IZWlnaHQgPSAyMgogICAgJHJv
bGVMYWJlbC5Mb2NhdGlvbiA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuUG9pbnQoMjkwLDEw
KQogICAgJHJvbGVMYWJlbC5Gb3JlQ29sb3IgPSAkQ19XYXJuCiAgICAkcm9sZUxhYmVsLlRleHRB
bGlnbiA9ICJNaWRkbGVSaWdodCIKICAgICRyb2xlTGFiZWwuRm9udCA9IE5ldy1PYmplY3QgU3lz
dGVtLkRyYXdpbmcuRm9udCgiU2Vnb2UgVUkiLDgsW1N5c3RlbS5EcmF3aW5nLkZvbnRTdHlsZV06
OkJvbGQpCiAgICAkY2FyZC5Db250cm9scy5BZGQoJHJvbGVMYWJlbCkKCiAgICAkZGVzY0xhYmVs
ID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jtcy5MYWJlbAogICAgJGRlc2NMYWJlbC5U
ZXh0ID0gJERlc2MKICAgICRkZXNjTGFiZWwuV2lkdGggPSA0MDUKICAgICRkZXNjTGFiZWwuSGVp
Z2h0ID0gMzQKICAgICRkZXNjTGFiZWwuTG9jYXRpb24gPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3
aW5nLlBvaW50KDEyLDM2KQogICAgJGRlc2NMYWJlbC5Gb3JlQ29sb3IgPSAkQ19NdXRlZAogICAg
JGRlc2NMYWJlbC5Gb250ID0gTmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5Gb250KCJTZWdvZSBV
SSIsOC41KQogICAgJGNhcmQuQ29udHJvbHMuQWRkKCRkZXNjTGFiZWwpCgogICAgJGZpeExpc3Qu
Q29udHJvbHMuQWRkKCRjYXJkKQogICAgJFJlZi5WYWx1ZSA9ICRjCn0KQWRkLVNpbXBsZUZpeENo
ZWNrICJSUEMgLyAweDAwMDAwMTFiIiAiQ2xpZW50ICsgSG9zdCIgIldpbmRvd3MgUlBDIHlhemTE
sXJtYSB1eXVtbHVsdcSfdSB2ZSAweDAwMDAwMTFiIGJhxJ9sYW50xLEgaGF0YWxhcsSxIGnDp2lu
LiIgKFtyZWZdJGNoa0ZpeFJwYykKQWRkLVNpbXBsZUZpeENoZWNrICJQb2ludCZQcmludCAvIDcw
OSIgIkNsaWVudCIgIkNsaWVudCB0YXJhZsSxbmRhIGRyaXZlciB5w7xrbGVtZSBpem5pLCA3MDkg
dmUgcGFja2FnZSBwb2xpY3kgc29ydW5sYXLEsSBpw6dpbi4iIChbcmVmXSRjaGtGaXhQb2ludCkK
QWRkLVNpbXBsZUZpeENoZWNrICJTTUIgLyBQYXlsYcWfxLFtIiAiSG9zdCIgIllhesSxY8SxIHBh
eWxhxZ/EsW3EsSB2ZSBTTUIgZXJpxZ9pbSB1eXVtbHVsdcSfdW51IGTDvHplbmxlci4iIChbcmVm
XSRjaGtGaXhTbWIpCkFkZC1TaW1wbGVGaXhDaGVjayAiRmlyZXdhbGwgLyBEaXNjb3ZlcnkiICJI
b3N0ICsgQ2xpZW50IiAiQcSfIGtlxZ9maSwgZG9zeWEveWF6xLFjxLEgcGF5bGHFn8SxbcSxIHZl
IGlsZ2lsaSBmaXJld2FsbCBrdXJhbGxhcsSxbsSxIGHDp2FyLiIgKFtyZWZdJGNoa0ZpeEZpcmV3
YWxsKQpBZGQtU2ltcGxlRml4Q2hlY2sgIlNlcnZpc2xlciIgIkhvc3QgKyBDbGllbnQiICJTcG9v
bGVyLCBSUEMsIFdvcmtzdGF0aW9uL1NlcnZlciB2ZSBrZcWfaWYgc2VydmlzbGVyaW5pIGhhesSx
cmxhci4iIChbcmVmXSRjaGtGaXhTZXJ2aWNlcykKQWRkLVNpbXBsZUZpeENoZWNrICJTcG9vbGVy
IFJlc2V0IiAiQ2xpZW50IiAiQm96dWsga3V5cnVrIHZlIHRha8SxbG3EscWfIHlhemTEsXJtYSBp
xZ9sZXJpbmkgdGVtaXpsZXlpcCBTcG9vbGVyJ8SxIHllbmlsZXIuIiAoW3JlZl0kY2hrRml4U3Bv
b2xlcikKQWRkLVNpbXBsZUZpeENoZWNrICJOVExNIC8gTmV0QklPUyIgIkNsaWVudCIgIldvcmtn
cm91cCBhxJ9sYXLEsW5kYSBpc2ltIMOnw7Z6w7xtbGVtZSB2ZSBOVExNIHV5dW1sdWx1xJ91IGnD
p2luLiIgKFtyZWZdJGNoa0ZpeE50bG0pCkFkZC1TaW1wbGVGaXhDaGVjayAiQ3JlZGVudGlhbCBU
ZW1pemxpxJ9pIiAiQ2xpZW50IiAiRXNraSBXaW5kb3dzIGtpbWxpayBiaWxnaWxlcmkgdmUgbmV0
IHVzZSBiYcSfbGFudMSxbGFyxLFuxLEgdGVtaXpsZXIuIiAoW3JlZl0kY2hrRml4Q3JlZGVudGlh
bCkKQWRkLVNpbXBsZUZpeENoZWNrICJEcml2ZXIgVGVtaXpsacSfaSIgIkNsaWVudCIgIlNlw6dp
bGVuIG1hcmthL21vZGVsaW4gYm96dWsgZHJpdmVyLCBwb3J0IHZlIFBuUCBpemxlcmluaSB0ZW1p
emxlci4iIChbcmVmXSRjaGtGaXhEcml2ZXIpCkFkZC1TaW1wbGVGaXhDaGVjayAiV29ya2dyb3Vw
IFdpbjEwLzExIiAiQ2xpZW50ICsgSG9zdCIgIkRvbWFpbiBvbG1heWFuIGHEn2xhcmRhIFRydXN0
ZWRIb3N0cywgV2luUk0gdmUgZ2VsacWfbWnFnyB5YXrEsWPEsSBwb2xpY3lsZXJpbmkgYXlhcmxh
ci4iIChbcmVmXSRjaGtGaXhXb3JrZ3JvdXApCiMgRHJpdmVyIHBhZ2UKJGRyaXZlciA9ICRwYWdl
c1siZHJpdmVyIl0KJGRyaXZlci5Db250cm9scy5BZGQoKE5ldy1JbmZvTGFiZWwgIk1hcmthL21v
ZGVsIGZpbHRyZXNpbmkgc2XDp2luLiBUZW1pemxpa3RlbiDDtm5jZSBrYWxkxLFyxLFsYWNhayDD
tsSfZWxlciBpw6dpbiDDtm4gaXpsZW1lIGfDtnN0ZXJpbGlyLiIgNCkpCiR0eHREcml2ZXJGaWx0
ZXIgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1zLkNvbWJvQm94CiR0eHREcml2ZXJG
aWx0ZXIuRHJvcERvd25TdHlsZSA9ICJEcm9wRG93biIKJHR4dERyaXZlckZpbHRlci5BdXRvQ29t
cGxldGVNb2RlID0gIlN1Z2dlc3RBcHBlbmQiCiR0eHREcml2ZXJGaWx0ZXIuQXV0b0NvbXBsZXRl
U291cmNlID0gIkxpc3RJdGVtcyIKJHR4dERyaXZlckZpbHRlci5Mb2NhdGlvbiA9IE5ldy1PYmpl
Y3QgU3lzdGVtLkRyYXdpbmcuUG9pbnQoNCw0MikKJHR4dERyaXZlckZpbHRlci5XaWR0aCA9IDMy
MAokdHh0RHJpdmVyRmlsdGVyLkZvbnQgPSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLkZvbnQo
IlNlZ29lIFVJIiwxMCkKJGRyaXZlci5Db250cm9scy5BZGQoJHR4dERyaXZlckZpbHRlcikKU2V0
LURyaXZlckZpbHRlckNvbWJvSXRlbXMgLUl0ZW1zIEAoR2V0LURlZmF1bHREcml2ZXJGaWx0ZXJP
cHRpb25zKQokYnRuRHJpdmVyRGV0ZWN0RmlsdGVyID0gTmV3LUFjdGlvbkJ1dHRvbiAiT3RvbWF0
aWsgVGVzcGl0IiAkQ19BY2NlbnQgMTUwCiRidG5Ecml2ZXJEZXRlY3RGaWx0ZXIuTG9jYXRpb24g
PSBOZXctT2JqZWN0IFN5c3RlbS5EcmF3aW5nLlBvaW50KDM0MCwzOSkKJGRyaXZlci5Db250cm9s
cy5BZGQoJGJ0bkRyaXZlckRldGVjdEZpbHRlcikKJGJ0bkRyaXZlckNsZWFuID0gTmV3LUFjdGlv
bkJ1dHRvbiAiU2XDp2lsaSBEcml2ZXLEsSBLYWxkxLFyIiAkQ19FcnIgMTkwCiRidG5Ecml2ZXJD
bGVhbi5Mb2NhdGlvbiA9IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuUG9pbnQoNTAwLDM5KQok
ZHJpdmVyLkNvbnRyb2xzLkFkZCgkYnRuRHJpdmVyQ2xlYW4pCgojIERpYWdub3NpcwokZGlhZyA9
ICRwYWdlc1siZGlhZyJdCiRkaWFnVG9wID0gTmV3LU9iamVjdCBTeXN0ZW0uV2luZG93cy5Gb3Jt
cy5GbG93TGF5b3V0UGFuZWwKJGRpYWdUb3AuRG9jayA9ICJUb3AiCiRkaWFnVG9wLkhlaWdodCA9
IDQ4CiRkaWFnVG9wLkJhY2tDb2xvciA9ICRDX0JnCiRkaWFnLkNvbnRyb2xzLkFkZCgkZGlhZ1Rv
cCkKJHR4dERpYWdSZW1vdGVQYyA9IE5ldy1PYmplY3QgU3lzdGVtLldpbmRvd3MuRm9ybXMuVGV4
dEJveAokdHh0RGlhZ1JlbW90ZVBjLldpZHRoID0gMTcwCiR0eHREaWFnUmVtb3RlUGMuRm9udCA9
IE5ldy1PYmplY3QgU3lzdGVtLkRyYXdpbmcuRm9udCgiU2Vnb2UgVUkiLDEwKQokZGlhZ1RvcC5D
b250cm9scy5BZGQoJHR4dERpYWdSZW1vdGVQYykKJGJ0blJ1bkFsbERpYWcgPSBOZXctQWN0aW9u
QnV0dG9uICJUZXNwaXQgWWFwIiAkQ19BY2NlbnQgMTIwCiRidG5SdW5Mb2NhbERpYWcgPSBOZXct
QWN0aW9uQnV0dG9uICJZZXJlbCIgJENfT2sgOTAKJGJ0blJ1blJlbW90ZURpYWcgPSBOZXctQWN0
aW9uQnV0dG9uICJVemFrIiAkQ19XYXJuIDkwCiRidG5DbGVhckRpYWcgPSBOZXctQWN0aW9uQnV0
dG9uICJUZW1pemxlIiAkQ19QYW5lbDIgOTAKZm9yZWFjaCAoJGIgaW4gQCgkYnRuUnVuQWxsRGlh
ZywkYnRuUnVuTG9jYWxEaWFnLCRidG5SdW5SZW1vdGVEaWFnLCRidG5DbGVhckRpYWcpKSB7ICRk
aWFnVG9wLkNvbnRyb2xzLkFkZCgkYikgfQokc2NyaXB0OkdyaWREaWFnID0gTmV3LU9iamVjdCBT
eXN0ZW0uV2luZG93cy5Gb3Jtcy5EYXRhR3JpZFZpZXcKJHNjcmlwdDpHcmlkRGlhZy5Eb2NrID0g
IkZpbGwiCiRzY3JpcHQ6R3JpZERpYWcuQmFja2dyb3VuZENvbG9yID0gJENfUGFuZWwKJHNjcmlw
dDpHcmlkRGlhZy5Cb3JkZXJTdHlsZSA9ICJOb25lIgokc2NyaXB0OkdyaWREaWFnLlJvd0hlYWRl
cnNWaXNpYmxlID0gJGZhbHNlCiRzY3JpcHQ6R3JpZERpYWcuQWxsb3dVc2VyVG9BZGRSb3dzID0g
JGZhbHNlCiRzY3JpcHQ6R3JpZERpYWcuQWxsb3dVc2VyVG9EZWxldGVSb3dzID0gJGZhbHNlCiRz
Y3JpcHQ6R3JpZERpYWcuUmVhZE9ubHkgPSAkdHJ1ZQokc2NyaXB0OkdyaWREaWFnLlNlbGVjdGlv
bk1vZGUgPSAiRnVsbFJvd1NlbGVjdCIKJHNjcmlwdDpHcmlkRGlhZy5BdXRvU2l6ZUNvbHVtbnNN
b2RlID0gIkZpbGwiCiRzY3JpcHQ6R3JpZERpYWcuRW5hYmxlSGVhZGVyc1Zpc3VhbFN0eWxlcyA9
ICRmYWxzZQokc2NyaXB0OkdyaWREaWFnLkNvbHVtbkhlYWRlcnNEZWZhdWx0Q2VsbFN0eWxlLkJh
Y2tDb2xvciA9ICRDX1BhbmVsMgokc2NyaXB0OkdyaWREaWFnLkNvbHVtbkhlYWRlcnNEZWZhdWx0
Q2VsbFN0eWxlLkZvcmVDb2xvciA9ICRDX0ZnCiRzY3JpcHQ6R3JpZERpYWcuRGVmYXVsdENlbGxT
dHlsZS5CYWNrQ29sb3IgPSAkQ19QYW5lbAokc2NyaXB0OkdyaWREaWFnLkRlZmF1bHRDZWxsU3R5
bGUuRm9yZUNvbG9yID0gJENfRmcKJHNjcmlwdDpHcmlkRGlhZy5EZWZhdWx0Q2VsbFN0eWxlLlNl
bGVjdGlvbkJhY2tDb2xvciA9ICRDX0FjY2VudApbdm9pZF0kc2NyaXB0OkdyaWREaWFnLkNvbHVt
bnMuQWRkKCJLYXRlZ29yaSIsIkthdGVnb3JpIikKW3ZvaWRdJHNjcmlwdDpHcmlkRGlhZy5Db2x1
bW5zLkFkZCgiQWQiLCJBZCIpClt2b2lkXSRzY3JpcHQ6R3JpZERpYWcuQ29sdW1ucy5BZGQoIkR1
cnVtIiwiRHVydW0iKQpbdm9pZF0kc2NyaXB0OkdyaWREaWFnLkNvbHVtbnMuQWRkKCJEZXRheSIs
IkRldGF5IikKW3ZvaWRdJHNjcmlwdDpHcmlkRGlhZy5Db2x1bW5zLkFkZCgiT25lcmkiLCLDlm5l
cmkiKQokZGlhZy5Db250cm9scy5BZGQoJHNjcmlwdDpHcmlkRGlhZykKCiMgTG9ncwokbG9ncyA9
ICRwYWdlc1sibG9ncyJdCiRsb2dUb3AgPSBOZXctT2JqZWN0IFN5c3RlbS5XaW5kb3dzLkZvcm1z
LkZsb3dMYXlvdXRQYW5lbAokbG9nVG9wLkRvY2sgPSAiVG9wIgokbG9nVG9wLkhlaWdodCA9IDQ0
CiRsb2dUb3AuQmFja0NvbG9yID0gJENfQmcKJGxvZ3MuQ29udHJvbHMuQWRkKCRsb2dUb3ApCiRi
dG5PcGVuTG9nID0gTmV3LUFjdGlvbkJ1dHRvbiAiTG9nIEtsYXPDtnLDvCIgJENfUGFuZWwyIDEy
MAokYnRuSHRtbCA9IE5ldy1BY3Rpb25CdXR0b24gIkhUTUwgUmFwb3IiICRDX0FjY2VudCAxMjAK
JGJ0bkNsZWFyTG9nID0gTmV3LUFjdGlvbkJ1dHRvbiAiVGVtaXpsZSIgJENfUGFuZWwyIDkwCmZv
cmVhY2ggKCRiIGluIEAoJGJ0bk9wZW5Mb2csJGJ0bkh0bWwsJGJ0bkNsZWFyTG9nKSkgeyAkbG9n
VG9wLkNvbnRyb2xzLkFkZCgkYikgfQokc2NyaXB0OlR4dExvZyA9IE5ldy1PYmplY3QgU3lzdGVt
LldpbmRvd3MuRm9ybXMuUmljaFRleHRCb3gKJHNjcmlwdDpUeHRMb2cuRG9jayA9ICJGaWxsIgok
c2NyaXB0OlR4dExvZy5CYWNrQ29sb3IgPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpGcm9tQXJn
YigxMywxNiwyMSkKJHNjcmlwdDpUeHRMb2cuRm9yZUNvbG9yID0gJENfRmcKJHNjcmlwdDpUeHRM
b2cuQm9yZGVyU3R5bGUgPSAiTm9uZSIKJHNjcmlwdDpUeHRMb2cuUmVhZE9ubHkgPSAkdHJ1ZQok
c2NyaXB0OlR4dExvZy5Gb250ID0gTmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5Gb250KCJDb25z
b2xhcyIsOS41KQokbG9ncy5Db250cm9scy5BZGQoJHNjcmlwdDpUeHRMb2cpCgpmdW5jdGlvbiBT
aG93LURyaXZlckNsZWFudXBQYWdlIHsKICAgIFNob3ctUGFnZSAiZHJpdmVyIgogICAgVXBkYXRl
LURyaXZlckZpbHRlckNhbmRpZGF0ZXMgLVNpbGVudCB8IE91dC1OdWxsCn0KZnVuY3Rpb24gVG9n
Z2xlLVRoZW1lU2FmZSB7CiAgICBwYXJhbShbc3dpdGNoXSRLZWVwTW9kZSxbc3dpdGNoXSRTaWxl
bnQpCiAgICBpZiAoLW5vdCAkS2VlcE1vZGUpIHsgJHNjcmlwdDpEYXJrTW9kZSA9IC1ub3QgJHNj
cmlwdDpEYXJrTW9kZSB9CiAgICAKICAgICRiZyA9IGlmICgkc2NyaXB0OkRhcmtNb2RlKSB7ICRD
X0JnIH0gZWxzZSB7ICRMX0JnIH0KICAgICRmZyA9IGlmICgkc2NyaXB0OkRhcmtNb2RlKSB7ICRD
X0ZnIH0gZWxzZSB7ICRMX0ZnIH0KICAgICRzaWRlQmcgPSBpZiAoJHNjcmlwdDpEYXJrTW9kZSkg
eyAkQ19TaWRlIH0gZWxzZSB7ICRMX1NpZGUgfQogICAgJHBhbmVsQmcgPSBpZiAoJHNjcmlwdDpE
YXJrTW9kZSkgeyAkQ19QYW5lbCB9IGVsc2UgeyAkTF9QYW5lbCB9CiAgICAkcGFuZWwyQmcgPSBp
ZiAoJHNjcmlwdDpEYXJrTW9kZSkgeyAkQ19QYW5lbDIgfSBlbHNlIHsgJExfUGFuZWwyIH0KICAg
ICRtdXRlZCA9IGlmICgkc2NyaXB0OkRhcmtNb2RlKSB7ICRDX011dGVkIH0gZWxzZSB7ICRMX011
dGVkIH0KICAgIAogICAgJGJ0blRoZW1lLlRleHQgPSBpZiAoJHNjcmlwdDpEYXJrTW9kZSkgeyAi
VGVtYSIgfSBlbHNlIHsgIktveXUiIH0KICAgIAogICAgIyBSZWN1cnNpdmUgVUkgVXBkYXRlCiAg
ICAkVXBkYXRlQ29udHJvbCA9IHsKICAgICAgICBwYXJhbSgkY3RybCkKICAgICAgICAKICAgICAg
ICAjIEdlbmVyaWMgY29sb3IgYXBwbGljYXRpb24KICAgICAgICBpZiAoJGN0cmwuVGFnIC1lcSAi
Q2FyZCIpIHsKICAgICAgICAgICAgJGN0cmwuQmFja0NvbG9yID0gJHBhbmVsQmcKICAgICAgICB9
IGVsc2VpZiAoJGN0cmwgLWlzIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5Gb3JtXSkgewogICAgICAg
ICAgICAkY3RybC5CYWNrQ29sb3IgPSAkYmcKICAgICAgICAgICAgJGN0cmwuRm9yZUNvbG9yID0g
JGZnCiAgICAgICAgfSBlbHNlaWYgKCRjdHJsIC1pcyBbU3lzdGVtLldpbmRvd3MuRm9ybXMuTGFi
ZWxdKSB7CiAgICAgICAgICAgIGlmICgkY3RybC5Gb3JlQ29sb3IgLW5lICRDX0FjY2VudCAtYW5k
ICRjdHJsLkZvcmVDb2xvciAtbmUgJENfT2sgLWFuZCAkY3RybC5Gb3JlQ29sb3IgLW5lICRDX1dh
cm4gLWFuZCAkY3RybC5Gb3JlQ29sb3IgLW5lICRDX0VyciAtYW5kICRjdHJsLkZvcmVDb2xvciAt
bmUgW1N5c3RlbS5EcmF3aW5nLkNvbG9yXTo6V2hpdGUpIHsKICAgICAgICAgICAgICAgICRjdHJs
LkZvcmVDb2xvciA9IGlmICgkY3RybC5Gb3JlQ29sb3IgLWVxICRDX011dGVkIC1vciAkY3RybC5G
b3JlQ29sb3IgLWVxICRMX011dGVkKSB7ICRtdXRlZCB9IGVsc2UgeyAkZmcgfQogICAgICAgICAg
ICB9CiAgICAgICAgfSBlbHNlaWYgKCRjdHJsIC1pcyBbU3lzdGVtLldpbmRvd3MuRm9ybXMuQnV0
dG9uXSkgewogICAgICAgICAgICBpZiAoJGN0cmwuVGFnIC1lcSAiTWVudUJ1dHRvbiIpIHsKICAg
ICAgICAgICAgICAgICRjdHJsLkJhY2tDb2xvciA9ICRzaWRlQmcKICAgICAgICAgICAgICAgICRj
dHJsLkZvcmVDb2xvciA9ICRtdXRlZAogICAgICAgICAgICB9IGVsc2VpZiAoJGN0cmwuVGFnIC1l
cSAiTWVudUJ1dHRvbkFjdGl2ZSIpIHsKICAgICAgICAgICAgICAgICMgS2VlcCBhY3RpdmUgbWVu
dSBidXR0b24gYmFja2dyb3VuZCAodXN1YWxseSAkQ19BY2NlbnQgb3IgJENfT2spCiAgICAgICAg
ICAgICAgICAkY3RybC5Gb3JlQ29sb3IgPSBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpXaGl0ZQog
ICAgICAgICAgICB9IGVsc2VpZiAoJGN0cmwuQmFja0NvbG9yIC1lcSAkQ19QYW5lbDIgLW9yICRj
dHJsLkJhY2tDb2xvciAtZXEgJExfUGFuZWwyKSB7CiAgICAgICAgICAgICAgICAkY3RybC5CYWNr
Q29sb3IgPSAkcGFuZWwyQmcKICAgICAgICAgICAgICAgICRjdHJsLkZvcmVDb2xvciA9ICRmZwog
ICAgICAgICAgICB9CiAgICAgICAgfSBlbHNlaWYgKCRjdHJsIC1pcyBbU3lzdGVtLldpbmRvd3Mu
Rm9ybXMuVGV4dEJveF0pIHsKICAgICAgICAgICAgJGN0cmwuQmFja0NvbG9yID0gaWYgKCRzY3Jp
cHQ6RGFya01vZGUpIHsgW1N5c3RlbS5EcmF3aW5nLkNvbG9yXTo6RnJvbUFyZ2IoNDUsNTUsNzIp
IH0gZWxzZSB7IFtTeXN0ZW0uRHJhd2luZy5Db2xvcl06OldoaXRlIH0KICAgICAgICAgICAgJGN0
cmwuRm9yZUNvbG9yID0gJGZnCiAgICAgICAgfSBlbHNlaWYgKCRjdHJsIC1pcyBbU3lzdGVtLldp
bmRvd3MuRm9ybXMuQ29tYm9Cb3hdKSB7CiAgICAgICAgICAgICRjdHJsLkJhY2tDb2xvciA9IGlm
ICgkc2NyaXB0OkRhcmtNb2RlKSB7IFtTeXN0ZW0uRHJhd2luZy5Db2xvcl06OkZyb21BcmdiKDQ1
LDU1LDcyKSB9IGVsc2UgeyBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpXaGl0ZSB9CiAgICAgICAg
ICAgICRjdHJsLkZvcmVDb2xvciA9ICRmZwogICAgICAgIH0gZWxzZWlmICgkY3RybCAtaXMgW1N5
c3RlbS5XaW5kb3dzLkZvcm1zLlJpY2hUZXh0Qm94XSkgewogICAgICAgICAgICAkY3RybC5CYWNr
Q29sb3IgPSBpZiAoJHNjcmlwdDpEYXJrTW9kZSkgeyBbU3lzdGVtLkRyYXdpbmcuQ29sb3JdOjpG
cm9tQXJnYigxMywxNiwyMSkgfSBlbHNlIHsgW1N5c3RlbS5EcmF3aW5nLkNvbG9yXTo6V2hpdGUg
fQogICAgICAgICAgICAkY3RybC5Gb3JlQ29sb3IgPSAkZmcKICAgICAgICB9IGVsc2VpZiAoJGN0
cmwgLWlzIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5EYXRhR3JpZFZpZXddKSB7CiAgICAgICAgICAg
ICRjdHJsLkJhY2tncm91bmRDb2xvciA9ICRwYW5lbEJnCiAgICAgICAgICAgICRjdHJsLkRlZmF1
bHRDZWxsU3R5bGUuQmFja0NvbG9yID0gJHBhbmVsQmcKICAgICAgICAgICAgJGN0cmwuRGVmYXVs
dENlbGxTdHlsZS5Gb3JlQ29sb3IgPSAkZmcKICAgICAgICAgICAgJGN0cmwuQ29sdW1uSGVhZGVy
c0RlZmF1bHRDZWxsU3R5bGUuQmFja0NvbG9yID0gJHBhbmVsMkJnCiAgICAgICAgICAgICRjdHJs
LkNvbHVtbkhlYWRlcnNEZWZhdWx0Q2VsbFN0eWxlLkZvcmVDb2xvciA9ICRmZwogICAgICAgICAg
ICAkY3RybC5HcmlkQ29sb3IgPSAkcGFuZWwyQmcKICAgICAgICB9IGVsc2VpZiAoJGN0cmwgLWlz
IFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5DaGVja0JveF0pIHsKICAgICAgICAgICAgJGN0cmwuRm9y
ZUNvbG9yID0gJGZnCiAgICAgICAgICAgIGlmICgkY3RybC5CYWNrQ29sb3IgLWVxICRDX1BhbmVs
IC1vciAkY3RybC5CYWNrQ29sb3IgLWVxICRMX1BhbmVsKSB7ICRjdHJsLkJhY2tDb2xvciA9ICRw
YW5lbEJnIH0KICAgICAgICAgICAgZWxzZWlmICgkY3RybC5CYWNrQ29sb3IgLWVxICRDX0JnIC1v
ciAkY3RybC5CYWNrQ29sb3IgLWVxICRMX0JnKSB7ICRjdHJsLkJhY2tDb2xvciA9ICRiZyB9CiAg
ICAgICAgfSBlbHNlaWYgKCRjdHJsIC1pcyBbU3lzdGVtLldpbmRvd3MuRm9ybXMuUGFuZWxdIC1v
ciAkY3RybCAtaXMgW1N5c3RlbS5XaW5kb3dzLkZvcm1zLlRhYmxlTGF5b3V0UGFuZWxdIC1vciAk
Y3RybCAtaXMgW1N5c3RlbS5XaW5kb3dzLkZvcm1zLkZsb3dMYXlvdXRQYW5lbF0pIHsKICAgICAg
ICAgICAgaWYgKCRjdHJsIC1lcSAkc2lkZSkgeyAkY3RybC5CYWNrQ29sb3IgPSAkc2lkZUJnIH0K
ICAgICAgICAgICAgZWxzZWlmICgkY3RybCAtZXEgJGhlYWRlciAtb3IgJGN0cmwgLWVxICRzdGF0
dXMpIHsgJGN0cmwuQmFja0NvbG9yID0gJHBhbmVsQmcgfQogICAgICAgICAgICBlbHNlaWYgKCRj
dHJsLkJhY2tDb2xvciAtZXEgJENfQmcgLW9yICRjdHJsLkJhY2tDb2xvciAtZXEgJExfQmcpIHsg
JGN0cmwuQmFja0NvbG9yID0gJGJnIH0KICAgICAgICAgICAgZWxzZWlmICgkY3RybC5CYWNrQ29s
b3IgLWVxICRDX1BhbmVsIC1vciAkY3RybC5CYWNrQ29sb3IgLWVxICRMX1BhbmVsKSB7ICRjdHJs
LkJhY2tDb2xvciA9ICRwYW5lbEJnIH0KICAgICAgICB9CgogICAgICAgIGZvcmVhY2ggKCRjaGls
ZCBpbiAkY3RybC5Db250cm9scykgeyAmJFVwZGF0ZUNvbnRyb2wgJGNoaWxkIH0KICAgIH0KICAg
IAogICAgJiRVcGRhdGVDb250cm9sICRmb3JtCn0KZnVuY3Rpb24gVG9nZ2xlLUxhbmd1YWdlU2Fm
ZSB7IE9LICJEaWwgc2XDp2ltaSBidSBzYWRlIGFyYXnDvHpkZSBUw7xya8OnZSBvbGFyYWsgc2Fi
aXQiIH0KZnVuY3Rpb24gVXBkYXRlLUhlYWRlckFjdGlvbkxheW91dCB7fQoKIyBFdmVudHMKJGJ0
bkRhc2hib2FyZC5BZGRfQ2xpY2soeyBTaG93LVBhZ2UgImRhc2hib2FyZCIgfSkKJGJ0bkZpbmRl
ci5BZGRfQ2xpY2soeyBTaG93LUZpbmRlckxvY2FsUGFnZSB9KQokYnRuRml4ZXMuQWRkX0NsaWNr
KHsgU2hvdy1QYWdlICJmaXhlcyIgfSkKJGJ0bkRyaXZlci5BZGRfQ2xpY2soeyBTaG93LURyaXZl
ckNsZWFudXBQYWdlIH0pCiRidG5EaWFnLkFkZF9DbGljayh7IFNob3ctUGFnZSAiZGlhZyIgfSkK
JGJ0bkxvZ3MuQWRkX0NsaWNrKHsgU2hvdy1QYWdlICJsb2dzIiB9KQokYnRuV29ya2Zsb3cuQWRk
X0NsaWNrKHsgU2hvdy1QYWdlICJsb2dzIjsgUnVuLUVudGVycHJpc2VXb3JrZmxvdyB9KQokYnRu
QmFja3VwLkFkZF9DbGljayh7IFNob3ctUGFnZSAibG9ncyI7IE5ldy1CYWNrdXBTbmFwc2hvdCAt
UmVhc29uICJNYW51YWwiIHwgT3V0LU51bGwgfSkKJGJ0blRoZW1lLkFkZF9DbGljayh7IFRvZ2ds
ZS1UaGVtZVNhZmUgfSkKJGJ0bkRhc2hEaWFnLkFkZF9DbGljayh7IFNob3ctUGFnZSAiZGlhZyI7
IFJ1bi1BbGxEaWFnbm9zaXMgfSkKJGJ0bkRhc2hSZWNvbW1lbmQuQWRkX0NsaWNrKHsgU2hvdy1Q
YWdlICJmaXhlcyI7IEFwcGx5LVJlY29tbWVuZGVkRml4U2VsZWN0aW9uOyAkbGJsRml4U3VtbWFy
eS5UZXh0ID0gIlNlw6dpbGkgZMO8emVsdG1lIHNhecSxc8SxOiAkKEdldC1TZWxlY3RlZEZpeENv
dW50KSIgfSkKJGJ0bkRhc2hGaW5kLkFkZF9DbGljayh7IFNob3ctRmluZGVyTG9jYWxQYWdlIH0p
CiRidG5EYXNoV29ya2Zsb3cuQWRkX0NsaWNrKHsgU2hvdy1QYWdlICJsb2dzIjsgUnVuLUVudGVy
cHJpc2VXb3JrZmxvdyB9KQokYnRuU2Nhbi5BZGRfQ2xpY2soeyBTY2FuLUxvY2FsUHJpbnRlcnNP
bmx5IH0pCiRidG5SZW1vdGVTY2FuLkFkZF9DbGljayh7IFNjYW4tUmVtb3RlUHJpbnRlcnMgfSkK
JGJ0bkNvbm5lY3QuQWRkX0NsaWNrKHsgQ29ubmVjdC1TZWxlY3RlZFByaW50ZXIgfSkKJGJ0bk1h
bnVhbENvbm5lY3QuQWRkX0NsaWNrKHsgQ29ubmVjdC1NYW51YWxQcmludGVyIH0pCiRidG5SZW1v
dmVTZWxlY3RlZFByaW50ZXIuQWRkX0NsaWNrKHsgUmVtb3ZlLVNlbGVjdGVkUHJpbnRlckl0ZW0g
fSkKJGdyaWRQcmludGVycy5BZGRfQ2VsbERvdWJsZUNsaWNrKHsgQ29ubmVjdC1TZWxlY3RlZFBy
aW50ZXIgfSkKJGJ0blJlY29tbWVuZC5BZGRfQ2xpY2soeyBBcHBseS1SZWNvbW1lbmRlZEZpeFNl
bGVjdGlvbjsgJGxibEZpeFN1bW1hcnkuVGV4dCA9ICJTZcOnaWxpIGTDvHplbHRtZSBzYXnEsXPE
sTogJChHZXQtU2VsZWN0ZWRGaXhDb3VudCkiIH0pCiRidG5SdW5GaXhlcy5BZGRfQ2xpY2soeyBS
dW4tQXV0b0ZpeCB9KQokYnRuRHJpdmVyRGV0ZWN0RmlsdGVyLkFkZF9DbGljayh7IFVwZGF0ZS1E
cml2ZXJGaWx0ZXJDYW5kaWRhdGVzIHwgT3V0LU51bGwgfSkKJGJ0bkRyaXZlckNsZWFuLkFkZF9D
bGljayh7IEFwcGx5LURyaXZlckNhY2hlQ2xlYW51cCB9KQokYnRuUnVuQWxsRGlhZy5BZGRfQ2xp
Y2soeyBpZiAoLW5vdCBbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCR0eHREaWFnUmVtb3Rl
UGMuVGV4dC5UcmltKCkpKSB7ICR0eHRSZW1vdGVQYy5UZXh0ID0gJHR4dERpYWdSZW1vdGVQYy5U
ZXh0LlRyaW0oKSB9OyBSdW4tQWxsRGlhZ25vc2lzIH0pCiRidG5SdW5Mb2NhbERpYWcuQWRkX0Ns
aWNrKHsgUnVuLUxvY2FsRGlhZ25vc2lzIH0pCiRidG5SdW5SZW1vdGVEaWFnLkFkZF9DbGljayh7
IGlmICgtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHR4dERpYWdSZW1vdGVQYy5U
ZXh0LlRyaW0oKSkpIHsgJHR4dFJlbW90ZVBjLlRleHQgPSAkdHh0RGlhZ1JlbW90ZVBjLlRleHQu
VHJpbSgpIH07IFJ1bi1SZW1vdGVEaWFnbm9zaXMgfSkKJGJ0bkNsZWFyRGlhZy5BZGRfQ2xpY2so
eyBDbGVhci1EaWFnIH0pCiRidG5PcGVuTG9nLkFkZF9DbGljayh7IFN0YXJ0LVByb2Nlc3MgZXhw
bG9yZXIuZXhlICRzY3JpcHQ6TG9nRGlyIH0pCiRidG5IdG1sLkFkZF9DbGljayh7IEV4cG9ydC1S
ZXBvcnQgfSkKJGJ0bkNsZWFyTG9nLkFkZF9DbGljayh7ICRzY3JpcHQ6VHh0TG9nLkNsZWFyKCkg
fSkKJHR4dFJlbW90ZVBjLkFkZF9UZXh0Q2hhbmdlZCh7IHRyeSB7IGlmICgkdHh0RGlhZ1JlbW90
ZVBjLlRleHQgLW5lICR0eHRSZW1vdGVQYy5UZXh0KSB7ICR0eHREaWFnUmVtb3RlUGMuVGV4dCA9
ICR0eHRSZW1vdGVQYy5UZXh0IH0gfSBjYXRjaCB7fSB9KQokdHh0RGlhZ1JlbW90ZVBjLkFkZF9U
ZXh0Q2hhbmdlZCh7IHRyeSB7IGlmICgkdHh0UmVtb3RlUGMuVGV4dCAtbmUgJHR4dERpYWdSZW1v
dGVQYy5UZXh0KSB7ICR0eHRSZW1vdGVQYy5UZXh0ID0gJHR4dERpYWdSZW1vdGVQYy5UZXh0IH0g
fSBjYXRjaCB7fSB9KQoKV3JpdGUtTG9nICIkKCRzY3JpcHQ6QXBwQ29kZSkgYmHFn2xhdMSxbGTE
sS4iCldyaXRlLUxvZyAiTG9nIGRvc3lhc8SxOiAkc2NyaXB0OkxvZ0ZpbGUiCkVuc3VyZS1BcHBD
b2RlU2lnbmluZ1RydXN0CkRldGVjdC1Sb2xlIHwgT3V0LU51bGwKU2hvdy1QYWdlICJkYXNoYm9h
cmQiClt2b2lkXSRmb3JtLlNob3dEaWFsb2coKQo=
"@;
}

# External tool launcher (Natively decoding and launching embedded tools)
function Invoke-ExternalTool {
    param([string]$RelativePath)
    
    # Get the file name from path
    $fileName = [System.IO.Path]::GetFileName($RelativePath)
    
    # Map old paths/names to embedded keys
    $key = switch -wildcard ($fileName) {
        "*11b*" { "Fix_11b.cmd" }
        "*709*" { "Fix_709.cmd" }
        "*GUEST*" { "GuestShare.cmd" }
        "*ADVANCED*" { "AdvancedToolkit.cmd" }
        "*ULTIMATE*" { "AdvancedToolkit.cmd" }
        "*v2*" { "Printer_Enterprise_FixTool_v2.ps1" }
        default { $fileName }
    }
    
    if ($script:EmbeddedTools.ContainsKey($key)) {
        $base64 = $script:EmbeddedTools[$key]
        $bytes = [Convert]::FromBase64String($base64)
        
        # Prepare temp directory
        $tempDir = Join-Path $env:TEMP "PRN_Enterprise_FixTool\Embedded"
        if (!(Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }
        $tempPath = Join-Path $tempDir $key
        
        # Write bytes directly to file
        [System.IO.File]::WriteAllBytes($tempPath, $bytes)
        
        Write-Log "GÃ¶mÃ¼lÃ¼ araÃ§ Ã§Ã¶zÃ¼mlendi: $key. Ã‡alÄ±ÅŸtÄ±rÄ±lÄ±yor..."
        
        if ($key.EndsWith(".cmd") -or $key.EndsWith(".bat")) {
            Invoke-UptProcess -FilePath "cmd.exe" -Arguments "/c `"$tempPath`"" | Out-Null
        } elseif ($key.EndsWith(".ps1")) {
            $psHost = Get-PreferredPowerShellHost
            Invoke-UptProcess -FilePath $psHost -Arguments "-NoProfile -ExecutionPolicy Bypass -File `"$tempPath`"" | Out-Null
        }
    } else {
        Show-Warn "Hata" "GÃ¶mÃ¼lÃ¼ araÃ§ bulunamadÄ±: $RelativePath"
    }
}

function Open-ToolkitFolder {
    Invoke-UptProcess -FilePath "explorer.exe" -Arguments "`"$PSScriptRoot`"" | Out-Null
}

function Apply-SelectedFixes {
    param([string]$RoleLabel)
    if (-not (Ensure-AtLeastOneFixSelected)) { return }
    New-BackupSnapshot -Reason "Before_Selected_Fixes" | Out-Null
    Write-Log "=== SEÇİLİ FIX AKIŞI BAŞLADI | Rol: $RoleLabel ==="
    if ($chkFixRpc.Checked) { Apply-RPC-PrinterCore } else { WARN "RPC/11b fix seçili değil, atlandı" }
    if ($chkFixPoint.Checked -and $RoleLabel -ne "Host") { Apply-PointAndPrint } elseif ($chkFixPoint.Checked) { WARN "Point&Print genellikle client fix; Host rolünde atlandı" } else { WARN "Point&Print/709 fix seçili değil, atlandı" }
    if ($chkFixSmb.Checked) { Apply-SMB-Compatibility } else { WARN "SMB/Guest fix seçili değil, atlandı" }
    if ($chkFixFirewall.Checked) { Enable-NetworkProfilePrivate; Enable-PrinterFirewall } else { WARN "Firewall/Discovery fix seçili değil, atlandı" }
    if ($chkFixServices.Checked) { Ensure-Services } else { WARN "Servis fix seçili değil, atlandı" }
    if ($chkFixSpooler.Checked) { Reset-Spooler } else { WARN "Spooler reset seçili değil, atlandı" }
    if ($chkFixNtlm.Checked) { Apply-NTLM-NetBIOS } else { WARN "NTLM/NetBIOS fix seçili değil, atlandı" }
    if ($chkFixCredential.Checked -and $RoleLabel -ne "Host") { Apply-CredentialCleanup } elseif ($chkFixCredential.Checked) { WARN "Credential temizliği Host rolünde atlandı" } else { WARN "Credential temizliği seçili değil, atlandı" }
    if ($chkFixDriver.Checked -and $RoleLabel -ne "Host") { Apply-DriverCacheCleanup } elseif ($chkFixDriver.Checked) { WARN "Driver temizliği Host rolünde atlandı" } else { WARN "Driver temizliği seçili değil, atlandı" }
    if ($chkFixWorkgroup -and $chkFixWorkgroup.Checked) { Apply-WorkgroupCompatibilityFix } else { WARN "Workgroup düzeltmesi seçili değil, atlandı" }
    Invoke-GPUpdateSafe
    Write-Log "=== SEÇİLİ FIX AKIŞI BİTTİ ===" "OK"
}
function Run-AutoFix {
    $role = Get-SelectedRole
    Write-Log "Seçili/Algılanan rol: $role"
    Apply-SelectedFixes -RoleLabel $role
    Show-Info "İşlem Tamamlandı" "Seçili düzeltme akışı tamamlandı.`r`nRol: $role`r`nLog: $script:LogFile"
}

# ---------- FINDER / CONNECT ----------
function Clear-Found {
    $script:FoundItems.Clear()
    if ($gridPrinters) { $gridPrinters.Rows.Clear() }
}
function Add-FoundItem {
    param([string]$Type,[string]$Name,[string]$ShareName,[string]$UNC,[string]$Driver,[string]$Source,[string]$Note)
    if ([string]::IsNullOrWhiteSpace($UNC)) { return }
    foreach ($i in $script:FoundItems) { if ($i.UNC -eq $UNC) { return } }
    $obj = [PSCustomObject]@{Type=$Type; Name=$Name; ShareName=$ShareName; UNC=$UNC; Driver=$Driver; Source=$Source; Note=$Note}
    $script:FoundItems.Add($obj) | Out-Null
    if ($gridPrinters) { [void]$gridPrinters.Rows.Add($Type,$Name,$ShareName,$UNC,$Driver,$Source,$Note) }
}
function Reset-PrinterGridView {
    try {
        if ($gridPrinters -and $gridPrinters.Rows.Count -gt 0) {
            $gridPrinters.ClearSelection()
            $gridPrinters.FirstDisplayedScrollingRowIndex = 0
            $gridPrinters.Rows[0].Selected = $true
            $gridPrinters.CurrentCell = $gridPrinters.Rows[0].Cells[1]
        }
    } catch {}
}
function Test-IsVirtualPrinter {
    param([string]$Name,[string]$Driver,[string]$Port)
    $text = ("{0} {1} {2}" -f $Name,$Driver,$Port).ToLowerInvariant()
    return ($text -match "microsoft print to pdf|microsoft xps document writer|onenote|send to microsoft onenote|shared fax|\\bfax\\b|portprompt:|nul:")
}
function Scan-CimPrinters {
    param([string]$Server)
    Write-Log "CIM/WMI yazıcı taraması: $Server"
    try {
        $printers = Get-CimInstance -ClassName Win32_Printer -ComputerName $Server -ErrorAction Stop
        foreach ($p in $printers) {
            $isVirtual = Test-IsVirtualPrinter "$($p.Name)" "$($p.DriverName)" "$($p.PortName)"
            if ($p.Shared -eq $true -and -not [string]::IsNullOrWhiteSpace($p.ShareName)) {
                $type = if ($isVirtual) { "Sanal/Sistem Yazıcı" } else { "Printer" }
                $note = if ($isVirtual) { "Sanal/sistem yazıcısı; Shared=True" } else { "Shared=True" }
                Add-FoundItem $type "$($p.Name)" "$($p.ShareName)" "\\$Server\$($p.ShareName)" "$($p.DriverName)" "CIM" $note
            } else {
                $safeName = "$($p.Name)" -replace '[\\/:*?"<>|]', '_'
                $pseudoPath = "unshared:$($Server):$safeName"
                $type = if ($isVirtual) { "Sanal/Sistem Yazıcı" } else { "Uzak Yazıcı (Paylaşılmamış)" }
                $note = "Paylaşım yok; Port=$($p.PortName); Shared=$($p.Shared); ShareName=$($p.ShareName)"
                if ($isVirtual) { $note = "Sanal/sistem yazıcısı; $note" }
                Add-FoundItem $type "$($p.Name)" "$($p.ShareName)" $pseudoPath "$($p.DriverName)" "CIM" $note
                Write-Log "CIM uzak yazıcı listelendi ama paylaşılmamış: $($p.Name) | Shared=$($p.Shared) | ShareName=$($p.ShareName)"
            }
        }
        OK "CIM yazıcı taraması tamamlandı"
    } catch { WARN "CIM/WMI taraması başarısız: $_" }
}
function Get-NetViewItemsSafe {
    param([string]$Server)
    $items = New-Object System.Collections.Generic.List[object]
    try {
        $out = cmd /c "net view \\$Server" 2>&1
        $capture = $false
        foreach ($line in $out) {
            Write-Log "NETVIEW: $line"
            $trim = ([string]$line).Trim()
            if ([string]::IsNullOrWhiteSpace($trim)) { continue }
            if ($trim -match '^-{3,}') { $capture = $true; continue }
            if ($trim -match 'komut.*tamamlan|command completed successfully') { break }
            if ($capture) {
                if ($trim -match '^(.*?)\s+(Disk|Print|Yaz\S*r)\s*(.*)$') {
                    $share = ($matches[1]).Trim()
                    $type = ($matches[2]).Trim()
                    $note = ($matches[3]).Trim()
                    if (-not [string]::IsNullOrWhiteSpace($share)) {
                        $items.Add([PSCustomObject]@{Share=$share;Type=$type;Note=$note;UNC="\\$Server\$share"}) | Out-Null
                    }
                }
            }
        }
    } catch { WARN "NET VIEW safe parser hatası: $_" }
    return $items
}
function Scan-NetViewShares {
    param([string]$Server)
    Write-Log "NET VIEW paylaşım taraması: \\$Server"
    try {
        $items = Get-NetViewItemsSafe -Server $Server
        $printerItems = @($items | Where-Object { "$($_.Type)" -notmatch '^Disk$' })
        foreach ($it in $printerItems) {
            Add-FoundItem "Printer" $it.Share $it.Share $it.UNC "" "net view" $it.Note
        }
        OK "NET VIEW taraması tamamlandı. Yazıcı: $($printerItems.Count), diğer paylaşım: $($items.Count - $printerItems.Count)"
    } catch { WARN "NET VIEW taraması başarısız: $_" }
}

function Scan-LocalPrinters {
    Write-Log "Yerel yazıcı taraması başladı..."
    try {
        $printers = Get-Printer -ErrorAction Stop
        $visibleCount = 0
        foreach ($p in $printers) {
            $isVirtual = Test-IsVirtualPrinter "$($p.Name)" "$($p.DriverName)" "$($p.PortName)"
            $type = if ($isVirtual) { "Sanal/Sistem Yazıcı" } elseif ($p.PortName -match "^\\\\" -or $p.Name -match "^\\\\") { "Ağ Bağlantısı" } else { "Yerel Yazıcı" }
            $unc = ""
            if ($p.Shared -eq $true -and -not [string]::IsNullOrWhiteSpace($p.ShareName)) {
                $unc = "\\$env:COMPUTERNAME\$($p.ShareName)"
            } elseif ($p.PortName -match "^\\\\") {
                $unc = "$($p.PortName)"
            } elseif ($p.Name -match "^\\\\") {
                $unc = "$($p.Name)"
            } else {
                $unc = "local:$($p.Name)"
            }
            $note = "Port=$($p.PortName); Shared=$($p.Shared); Varsayılan=$($p.Default)"
            if ($isVirtual) { $note = "Sanal/sistem yazıcısı; $note" }
            Add-FoundItem $type "$($p.Name)" "$($p.ShareName)" $unc "$($p.DriverName)" "Yerel" $note
            $visibleCount++
        }
        OK "Yerel yazıcı taraması tamamlandı. Gösterilen: $visibleCount / Toplam aygıt: $(@($printers).Count)"
    } catch { WARN "Yerel yazıcı taraması başarısız: $_" }
}

function Scan-LocalPrintersOnly {
    Clear-Found
    Write-Log "Bu PC yazıcı listesi isteniyor."
    Scan-LocalPrinters
    if ($script:FoundItems.Count -eq 0) { Show-Warn "Sonuç Yok" "Bu bilgisayarda yazıcı aygıtı bulunamadı." }
    else { Reset-PrinterGridView; OK "Bu PC yazıcı listesi hazır. Gösterilen: $($script:FoundItems.Count)" }
}

function Scan-PrintersUnified {
    Clear-Found
    Write-Log "Birleşik yazıcı taraması başladı."
    Scan-LocalPrinters
    $server = $txtRemotePc.Text.Trim()
    if (-not [string]::IsNullOrWhiteSpace($server)) {
        Write-Log "Uzak PC yazıcı/paylaşım taraması başladı: $server"
        if ($chkAutoFixBeforeScan.Checked) { Apply-SelectedFixes -RoleLabel "Client" }
        Run-RemoteDiagnosis
        Scan-CimPrinters $server
        Scan-NetViewShares $server
    } else {
        WARN "PC/IP boş; sadece yerel yazıcılar tarandı."
    }
    if ($script:FoundItems.Count -eq 0) { Show-Warn "Sonuç Yok" "Yerel veya uzak yazıcı bulunamadı." }
    else { Reset-PrinterGridView; Show-Info "Tarama Tamamlandı" "$($script:FoundItems.Count) seçenek bulundu." }
}

function Scan-RemotePrinters {
    $server = $txtRemotePc.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($server)) { Show-Warn "Eksik Bilgi" "Lütfen uzak PC adı veya IP girin."; return }
    Clear-Found
    Write-Log "Uzak PC yazıcı/paylaşım taraması başladı: $server"
    if ($chkAutoFixBeforeScan.Checked) { Apply-SelectedFixes -RoleLabel "Client" }
    Run-RemoteDiagnosis
    Scan-CimPrinters $server
    Scan-NetViewShares $server
    if ($script:FoundItems.Count -eq 0) { Show-Warn "Sonuç Yok" "Paylaşım/yazıcı bulunamadı veya erişim engellendi." }
    else { Reset-PrinterGridView; Show-Info "Tarama Tamamlandı" "$($script:FoundItems.Count) seçenek bulundu." }
}
function Show-FinderLocalPage {
    Show-Page "finder"
    Scan-LocalPrintersOnly
}
function Remove-OldPrinterConnection {
    param([string]$UNC)
    Write-Log "Eski yazıcı bağlantısı temizleniyor: $UNC"
    try {
        $existing = Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $UNC -or $_.PortName -eq $UNC -or $_.Name -like "*$UNC*" }
        foreach ($p in $existing) { Remove-Printer -Name $p.Name -ErrorAction SilentlyContinue; OK "Eski yazıcı kaldırıldı: $($p.Name)" }
    } catch { WARN "Eski bağlantı temizliği başarısız: $_" }
    try { rundll32 printui.dll,PrintUIEntry /dn /n "$UNC" /q; OK "PrintUI eski bağlantı kaldırma denendi" } catch {}
}
function Get-PrinterConnectionExists {
    param([string]$UNC)
    try {
        $target = $UNC.Trim()
        $printers = Get-Printer -ErrorAction SilentlyContinue
        foreach ($p in $printers) {
            if ($p.Name -eq $target -or $p.PortName -eq $target) { return $true }
            if ($p.Name -like "*$target*" -or $p.PortName -like "*$target*") { return $true }
        }
    } catch {}
    try {
        $escaped = [regex]::Escape($UNC)
        $wmi = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $escaped -or $_.DeviceID -match $escaped }
        if ($wmi) { return $true }
    } catch {}
    return $false
}
function Wait-PrinterConnection {
    param([string]$UNC,[int]$Seconds=10)
    for ($i=0; $i -lt $Seconds; $i++) {
        if (Get-PrinterConnectionExists -UNC $UNC) { return $true }
        Start-Sleep -Seconds 1
        [System.Windows.Forms.Application]::DoEvents()
    }
    return $false
}
function Get-ShareFromUNC {
    param([string]$UNC)
    try {
        $parts = $UNC.Trim().Trim('"').Trim("'").TrimStart("\").Split("\")
        if ($parts.Count -ge 2) { return $parts[1] }
    } catch {}
    return ""
}
function Add-PreConnectResult {
    param(
        [System.Collections.Generic.List[object]]$Results,
        [string]$Level,
        [string]$Check,
        [string]$Detail,
        [string]$Suggestion = ""
    )
    $Results.Add([PSCustomObject]@{Level=$Level;Check=$Check;Detail=$Detail;Suggestion=$Suggestion}) | Out-Null
    $line = "PRECONNECT / $Check / $Detail"
    if (-not [string]::IsNullOrWhiteSpace($Suggestion)) { $line += " / Öneri: $Suggestion" }
    switch ($Level) {
        "OK" { OK $line }
        "WARN" { WARN $line }
        "ERR" { ERR $line }
        default { Write-Log $line }
    }
}
function Invoke-PrinterPreConnectTest {
    param([string]$UNC)
    $results = New-Object System.Collections.Generic.List[object]
    $server = Get-ServerFromUNC $UNC
    $share = Get-ShareFromUNC $UNC

    Write-Log "=== PRECONNECT YAZICI TESTİ BAŞLADI | UNC: $UNC ==="
    Add-PreConnectResult $results "INFO" "UNC" "Server=$server; Share=$share; Client=$env:COMPUTERNAME; User=$env:USERDOMAIN\$env:USERNAME"

    if ([string]::IsNullOrWhiteSpace($server) -or [string]::IsNullOrWhiteSpace($share)) {
        Add-PreConnectResult $results "ERR" "UNC format" "UNC server/paylaşım ayrıştırılamadı: $UNC" "\\PCADI\PAYLASIM_ADI formatını kullanın"
        Write-Log "=== PRECONNECT YAZICI TESTİ BİTTİ | Hata: 1 | Uyarı: 0 ==="
        return [PSCustomObject]@{Results=$results;ErrorCount=1;WarnCount=0}
    }

    try {
        if (Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            Add-PreConnectResult $results "OK" "Ping" "$server ICMP yanıt verdi"
        } else {
            Add-PreConnectResult $results "WARN" "Ping" "$server ICMP yanıt vermedi" "Firewall ICMP kapalı olabilir; SMB/RPC testleri belirleyici olacak"
        }
    } catch { Add-PreConnectResult $results "WARN" "Ping" "Ping testi çalışmadı: $($_.Exception.Message)" }

    foreach ($port in @(445,135)) {
        try {
            $tnc = Test-NetConnection -ComputerName $server -Port $port -WarningAction SilentlyContinue -InformationLevel Quiet
            if ($tnc) {
                Add-PreConnectResult $results "OK" "TCP $port" "$($server):$port erişilebilir"
            } else {
                $suggest = if ($port -eq 445) { "Uzak PC'de File and Printer Sharing/SMB ve firewall kurallarını kontrol edin" } else { "RPC Endpoint Mapper/firewall kontrol edilmeli" }
                Add-PreConnectResult $results "WARN" "TCP $port" "$($server):$port erişilemedi" $suggest
            }
        } catch { Add-PreConnectResult $results "WARN" "TCP $port" "$($server):$port test edilemedi: $($_.Exception.Message)" }
    }
    try {
        $tnc139 = Test-NetConnection -ComputerName $server -Port 139 -WarningAction SilentlyContinue -InformationLevel Quiet
        if ($tnc139) {
            Add-PreConnectResult $results "OK" "TCP 139" "$($server):139 erişilebilir (eski NetBIOS/SMB uyumluluğu)"
        } else {
            Add-PreConnectResult $results "INFO" "TCP 139" "$($server):139 kapalı veya erişilemedi; modern SMB için tek başına hata sayılmaz"
        }
    } catch { Add-PreConnectResult $results "INFO" "TCP 139" "139 testi atlandı: $($_.Exception.Message)" }

    try {
        $svc = Get-Service -ComputerName $server -Name Spooler -ErrorAction Stop
        if ($svc.Status -eq "Running") {
            Add-PreConnectResult $results "OK" "Uzak Spooler" "Spooler çalışıyor: $server"
        } else {
            Add-PreConnectResult $results "ERR" "Uzak Spooler" "Spooler durumu: $($svc.Status)" "Uzak PC'de Print Spooler servisini başlatın"
        }
    } catch { Add-PreConnectResult $results "WARN" "Uzak Spooler" "Servis durumu okunamadı: $($_.Exception.Message)" "RPC/firewall/yetki sorunu olabilir" }

    try {
        $uncRoot = "\\$server\IPC$"
        if (Test-Path $uncRoot -ErrorAction SilentlyContinue) {
            Add-PreConnectResult $results "OK" "IPC$" "$uncRoot erişilebilir"
        } else {
            Add-PreConnectResult $results "WARN" "IPC$" "$uncRoot erişilemedi" "Kimlik bilgisi, SMB veya firewall sorunu olabilir"
        }
    } catch { Add-PreConnectResult $results "WARN" "IPC$" "IPC erişim testi başarısız: $($_.Exception.Message)" }

    $netViewItems = @()
    try {
        $netViewItems = @(Get-NetViewItemsSafe -Server $server)
        $match = $netViewItems | Where-Object { $_.Share -ieq $share -or $_.UNC -ieq $UNC } | Select-Object -First 1
        if ($match) {
            Add-PreConnectResult $results "OK" "Paylaşım görünürlüğü" "$UNC NET VIEW içinde görünüyor; Type=$($match.Type); Note=$($match.Note)"
        } else {
            Add-PreConnectResult $results "ERR" "Paylaşım görünürlüğü" "$UNC NET VIEW içinde bulunamadı" "Paylaşım adını, yazıcının paylaşıma açık olduğunu ve erişim izinlerini kontrol edin"
        }
    } catch { Add-PreConnectResult $results "WARN" "Paylaşım görünürlüğü" "NET VIEW testi başarısız: $($_.Exception.Message)" }

    $remotePrinter = $null
    try {
        $printers = @(Get-CimInstance -ClassName Win32_Printer -ComputerName $server -ErrorAction Stop)
        $remotePrinter = $printers | Where-Object { $_.ShareName -ieq $share -or $_.Name -ieq $share -or $_.Name -ieq $UNC } | Select-Object -First 1
        if ($remotePrinter) {
            Add-PreConnectResult $results "OK" "CIM yazıcı" "Name=$($remotePrinter.Name); ShareName=$($remotePrinter.ShareName); Driver=$($remotePrinter.DriverName); Port=$($remotePrinter.PortName); Shared=$($remotePrinter.Shared)"
            if ($remotePrinter.Shared -ne $true) {
                Add-PreConnectResult $results "ERR" "CIM paylaşım" "Yazıcı CIM'de bulundu ama Shared=True değil" "Uzak PC'de yazıcı paylaşımını açın"
            }
        } else {
            Add-PreConnectResult $results "WARN" "CIM yazıcı" "ShareName=$share ile eşleşen yazıcı bulunamadı" "CIM/WMI erişimi kısıtlı olabilir veya paylaşım adı farklı olabilir"
        }
    } catch { Add-PreConnectResult $results "WARN" "CIM yazıcı" "Uzak yazıcı listesi okunamadı: $($_.Exception.Message)" "WMI/RPC/firewall/yetki kontrol edin" }

    if ($remotePrinter) {
        try {
            $driverName = "$($remotePrinter.DriverName)"
            if (-not [string]::IsNullOrWhiteSpace($driverName)) {
                $localDriver = Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $driverName } | Select-Object -First 1
                if ($localDriver) {
                    Add-PreConnectResult $results "OK" "Yerel driver eşleşmesi" "Client üzerinde driver mevcut: $driverName"
                } else {
                    Add-PreConnectResult $results "WARN" "Yerel driver eşleşmesi" "Client üzerinde driver yok: $driverName" "Point&Print/driver policy veya driver package sorunu çıkabilir"
                }
            }
        } catch { Add-PreConnectResult $results "WARN" "Yerel driver eşleşmesi" "Yerel driver kontrolü yapılamadı: $($_.Exception.Message)" }

        try {
            $ports = @(Get-CimInstance -ClassName Win32_TCPIPPrinterPort -ComputerName $server -ErrorAction SilentlyContinue)
            $portInfo = $ports | Where-Object { $_.Name -eq $remotePrinter.PortName } | Select-Object -First 1
            if ($portInfo) {
                Add-PreConnectResult $results "OK" "Uzak printer port" "Port=$($portInfo.Name); HostAddress=$($portInfo.HostAddress); Protocol=$($portInfo.Protocol); PortNumber=$($portInfo.PortNumber)"
                if (-not [string]::IsNullOrWhiteSpace($portInfo.HostAddress)) {
                    foreach ($printerPort in @([int]$portInfo.PortNumber,9100) | Select-Object -Unique) {
                        if ($printerPort -gt 0) {
                            try {
                                $okPort = Test-NetConnection -ComputerName $portInfo.HostAddress -Port $printerPort -WarningAction SilentlyContinue -InformationLevel Quiet
                                if ($okPort) { Add-PreConnectResult $results "OK" "Printer TCP $printerPort" "$($portInfo.HostAddress):$printerPort client tarafından erişilebilir" }
                                else { Add-PreConnectResult $results "WARN" "Printer TCP $printerPort" "$($portInfo.HostAddress):$printerPort client tarafından erişilemedi" "Fiziksel yazıcı ağı/VLAN/firewall kontrol edilmeli; uzak PC erişiyor olabilir ama client erişemiyor olabilir" }
                            } catch { Add-PreConnectResult $results "WARN" "Printer TCP $printerPort" "Port testi yapılamadı: $($_.Exception.Message)" }
                        }
                    }
                }
            } else {
                Add-PreConnectResult $results "WARN" "Uzak printer port" "CIM TCP/IP port bilgisi bulunamadı: $($remotePrinter.PortName)" "USB/WSD/local port olabilir; uzak PC tarafında port detayını kontrol edin"
            }
        } catch { Add-PreConnectResult $results "WARN" "Uzak printer port" "Port bilgisi okunamadı: $($_.Exception.Message)" }
    }

    try {
        $existing = Get-PrinterConnectionExists -UNC $UNC
        if ($existing) { Add-PreConnectResult $results "WARN" "Mevcut bağlantı" "Client üzerinde bu UNC zaten mevcut görünüyor" "Gerekirse Eski bağlantıyı temizle seçeneğiyle tekrar deneyin" }
        else { Add-PreConnectResult $results "OK" "Mevcut bağlantı" "Client üzerinde mevcut bağlantı bulunmadı" }
    } catch { Add-PreConnectResult $results "WARN" "Mevcut bağlantı" "Mevcut bağlantı kontrolü yapılamadı: $($_.Exception.Message)" }

    $errCount = @($results | Where-Object { $_.Level -eq "ERR" }).Count
    $warnCount = @($results | Where-Object { $_.Level -eq "WARN" }).Count
    Write-Log "=== PRECONNECT YAZICI TESTİ BİTTİ | Hata: $errCount | Uyarı: $warnCount | UNC: $UNC ==="
    return [PSCustomObject]@{Results=$results;ErrorCount=$errCount;WarnCount=$warnCount}
}
function Connect-PrinterUNC {
    param([string]$UNC)
    if ([string]::IsNullOrWhiteSpace($UNC)) { Show-Warn "Eksik Bilgi" "UNC boş. Örnek: \\PCADI\PAYLASIM_ADI"; return }
    $UNC = $UNC.Trim().Trim('"').Trim("'")
    if ($UNC -notmatch '^\\\\[^\\]+\\[^\\]+') {
        Show-Warn "Hatalı UNC" "Yazıcı yolu şu formatta olmalı:`r`n\\PCADI\PAYLASIM_ADI"
        WARN "Geçersiz UNC formatı: $UNC"
        return
    }

    Write-Log "Yazıcı bağlantısı başlıyor: $UNC"
    $server = Get-ServerFromUNC $UNC
    if (-not [string]::IsNullOrWhiteSpace($server) -and [string]::IsNullOrWhiteSpace($txtRemotePc.Text.Trim())) { $txtRemotePc.Text = $server }

    if ($chkAutoFixBeforeConnect.Checked) { Apply-SelectedFixes -RoleLabel "Client" }
    if ($chkRemoveOld.Checked) { Remove-OldPrinterConnection $UNC }

    try {
        $preflight = Invoke-PrinterPreConnectTest -UNC $UNC
    } catch {
        $preflightError = $_.Exception.Message
        ERR "Preconnect testi beklenmeyen hata ile durdu: $preflightError"
        $preflight = [PSCustomObject]@{Results=@();ErrorCount=1;WarnCount=0}
    }
    if ($preflight.ErrorCount -gt 0) {
        WARN "Preconnect testi $($preflight.ErrorCount) hata ve $($preflight.WarnCount) uyarı üretti; bağlantı denemeleri yine de başlatılıyor"
    } elseif ($preflight.WarnCount -gt 0) {
        WARN "Preconnect testi $($preflight.WarnCount) uyarı üretti; bağlantı denemeleri başlatılıyor"
    } else {
        OK "Preconnect testi temiz; bağlantı denemeleri başlatılıyor"
    }

    $ok = $false
    $method = ""
    $lastError = ""
    $attemptErrors = New-Object System.Collections.Generic.List[string]

    try {
        Add-Printer -ConnectionName $UNC -ErrorAction Stop
        Start-Sleep -Seconds 2
        if (Wait-PrinterConnection -UNC $UNC -Seconds 8) { OK "Add-Printer doğrulandı: $UNC"; $ok = $true; $method = "Add-Printer" }
        else { $attemptErrors.Add("Add-Printer: hata yok ama bağlantı doğrulanamadı") | Out-Null; WARN "Add-Printer hata vermedi ancak bağlantı doğrulanamadı" }
    } catch { $lastError = $_.Exception.Message; $attemptErrors.Add("Add-Printer: $lastError") | Out-Null; WARN "Add-Printer başarısız: $lastError" }

    if (-not $ok) {
        try {
            Write-Log "PrintUI /in deneniyor..."
            $p = Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /in /n `"$UNC`"" -Wait -PassThru -WindowStyle Hidden
            Start-Sleep -Seconds 2
            if (Wait-PrinterConnection -UNC $UNC -Seconds 8) { OK "PrintUI /in doğrulandı: $UNC"; $ok = $true; $method = "PrintUI /in" }
            else { $attemptErrors.Add("PrintUI /in: ExitCode=$($p.ExitCode), doğrulanamadı") | Out-Null; WARN "PrintUI /in çıkış kodu $($p.ExitCode), fakat doğrulanamadı" }
        } catch { $lastError = $_.Exception.Message; $attemptErrors.Add("PrintUI /in: $lastError") | Out-Null; WARN "PrintUI /in başarısız: $lastError" }
    }
    if (-not $ok) {
        try {
            Write-Log "WScript.Network deneniyor..."
            $net = New-Object -ComObject WScript.Network
            $net.AddWindowsPrinterConnection($UNC)
            Start-Sleep -Seconds 2
            if (Wait-PrinterConnection -UNC $UNC -Seconds 8) { OK "WScript doğrulandı: $UNC"; $ok = $true; $method = "WScript.Network" }
            else { $attemptErrors.Add("WScript.Network: hata yok ama bağlantı doğrulanamadı") | Out-Null; WARN "WScript hata vermedi ancak doğrulanamadı" }
        } catch { $lastError = $_.Exception.Message; $attemptErrors.Add("WScript.Network: $lastError") | Out-Null; WARN "WScript başarısız: $lastError" }
    }
    if (-not $ok) {
        try {
            Write-Log "PrintUI /ga per-machine deneniyor..."
            $p = Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /ga /n `"$UNC`"" -Wait -PassThru -WindowStyle Hidden
            Restart-Service Spooler -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
            if (Wait-PrinterConnection -UNC $UNC -Seconds 8) { OK "PrintUI /ga doğrulandı: $UNC"; $ok = $true; $method = "PrintUI /ga" }
            else { $attemptErrors.Add("PrintUI /ga: ExitCode=$($p.ExitCode), doğrulanamadı") | Out-Null; WARN "PrintUI /ga çıkış kodu $($p.ExitCode), fakat doğrulanamadı" }
        } catch { $lastError = $_.Exception.Message; $attemptErrors.Add("PrintUI /ga: $lastError") | Out-Null; WARN "PrintUI /ga başarısız: $lastError" }
    }

    if ($ok) { Show-Info "Bağlantı Başarılı" "Yazıcı doğrulanarak bağlandı:`r`n$UNC`r`nYöntem: $method" }
    else {
        ERR "Bağlantı doğrulanamadı: $UNC | Son hata: $lastError"
        Write-Log "=== GÖNDERİLECEK BAĞLANTI HATA ÖZETİ BAŞLADI ===" "ERR"
        Write-Log "UNC: $UNC" "ERR"
        Write-Log "Client: $env:COMPUTERNAME | User: $env:USERDOMAIN\$env:USERNAME | Role: $script:DetectedRole" "ERR"
        Write-Log "Preconnect: Hata=$($preflight.ErrorCount), Uyarı=$($preflight.WarnCount)" "ERR"
        foreach ($attempt in $attemptErrors) { Write-Log "Deneme: $attempt" "ERR" }
        Write-Log "Son hata: $lastError" "ERR"
        Write-Log "Log dosyası: $script:LogFile" "ERR"
        Write-Log "=== GÖNDERİLECEK BAĞLANTI HATA ÖZETİ BİTTİ ===" "ERR"
        Show-Err "Bağlantı Başarısız" "Yazıcı bağlanamadı veya doğrulanamadı.`r`nUNC: $UNC`r`nSon hata: $lastError`r`n`r`nLog kaydını bana gönderirsen hata özetinden ilerleyebiliriz.`r`n`r`nLog: $script:LogFile"
    }
}
function Connect-SelectedPrinter {
    if ($gridPrinters.SelectedRows.Count -lt 1) { Show-Warn "Seçim Yok" "Listeden bir yazıcı/paylaşım seçin."; return }
    $target = "$($gridPrinters.SelectedRows[0].Cells[3].Value)"
    if ($target -like "local:*") {
        Show-Warn "Yerel Yazıcı" "Seçilen kayıt zaten bu bilgisayardaki yerel yazıcı.`r`nİşlem için 'Seçileni Kaldır' veya Driver Temizliği kullanılabilir."
        return
    }
    if ($target -like "unshared:*") {
        $name = "$($gridPrinters.SelectedRows[0].Cells[1].Value)"
        Show-Warn "Paylaşılmamış Yazıcı" "Seçilen uzak yazıcı bulundu ama paylaşılmamış görünüyor:`r`n$name`r`n`r`nBağlanabilmek için Host PC üzerinde yazıcı paylaşımını açıp bir paylaşım adı vermeniz gerekir."
        WARN "Paylaşılmamış uzak yazıcı seçildi; bağlantı başlatılmadı: $name"
        return
    }
    Connect-PrinterUNC $target
}
function Connect-ManualPrinter {
    Connect-PrinterUNC $txtManualUNC.Text.Trim()
}
function Remove-SelectedPrinterItem {
    if ($gridPrinters.SelectedRows.Count -lt 1) { Show-Warn "Seçim Yok" "Listeden bir yazıcı seçin."; return }
    $name = "$($gridPrinters.SelectedRows[0].Cells[1].Value)"
    $unc = "$($gridPrinters.SelectedRows[0].Cells[3].Value)"
    $targetName = if ($unc -like "local:*") { $unc.Substring(6) } else { $name }
    $answer = [System.Windows.Forms.MessageBox]::Show("Seçilen yazıcı/bağlantı kaldırılacak:`r`n$targetName`r`n`r`nDevam edilsin mi?","Yazıcı Kaldır",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { WARN "Seçili yazıcı kaldırma iptal edildi"; return }
    try {
        if ($unc -like "\\*") {
            Remove-OldPrinterConnection $unc
        } else {
            Remove-Printer -Name $targetName -ErrorAction Stop
            OK "Yerel yazıcı kaldırıldı: $targetName"
        }
        Scan-PrintersUnified
    } catch {
        ERR "Seçili yazıcı kaldırılamadı: $targetName - $_"
        Show-Err "Kaldırma Başarısız" "Yazıcı kaldırılamadı:`r`n$targetName`r`n`r`n$($_.Exception.Message)"
    }
}

# ---------- REPORT ----------
function Export-Report {
    $path = Join-Path $script:LogDir ("PRN_UET_FULL_REPORT_{0}.html" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    $rows = foreach ($i in $script:FoundItems) { "<tr><td>$($i.Type)</td><td>$($i.Name)</td><td>$($i.ShareName)</td><td>$($i.UNC)</td><td>$($i.Driver)</td><td>$($i.Source)</td><td>$($i.Note)</td></tr>" }
    $diagRows = foreach ($d in $script:DiagItems) { "<tr><td>$($d.Kategori)</td><td>$($d.Ad)</td><td>$($d.Durum)</td><td>$($d.Detay)</td><td>$($d.Oneri)</td></tr>" }
    $actRows = foreach ($a in $script:ActionItems) { "<tr><td>$($a.Time)</td><td>$($a.Name)</td><td>$($a.Status)</td><td>$($a.Detail)</td></tr>" }
    $logText = Get-Content $script:LogFile -ErrorAction SilentlyContinue | ForEach-Object { "<div>$($_.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;'))</div>" }
    $html = @"
<!doctype html><html lang='tr'><head><meta charset='utf-8'>
<title>$($script:AppName)</title>
<style>
body{font-family:Segoe UI,Arial;background:#11161d;color:#eef1f7;padding:24px}
.card{background:#1b2028;border:1px solid #313a47;border-radius:12px;padding:16px;margin-bottom:16px}
table{width:100%;border-collapse:collapse}th,td{border:1px solid #364150;padding:8px;text-align:left}th{background:#232c39}
</style></head><body>
<h1>$($script:AppName)</h1>
<div class='card'><b>PC:</b> $env:COMPUTERNAME<br><b>User:</b> $env:USERNAME<br><b>Role:</b> $script:DetectedRole<br><b>Date:</b> $(Get-Date)</div>
<div class='card'><h2>Arıza Tespit</h2><table><tr><th>Kategori</th><th>Ad</th><th>Durum</th><th>Detay</th><th>Öneri</th></tr>$($diagRows -join "`r`n")</table></div>
<div class='card'><h2>Bulunan Yazıcı/Paylaşımlar</h2><table><tr><th>Tür</th><th>Ad</th><th>Paylaşım</th><th>UNC</th><th>Sürücü</th><th>Kaynak</th><th>Not</th></tr>$($rows -join "`r`n")</table></div>
<div class='card'><h2>İşlemler</h2><table><tr><th>Zaman</th><th>İşlem</th><th>Durum</th><th>Detay</th></tr>$($actRows -join "`r`n")</table></div>
<div class='card'><h2>Log</h2>$($logText -join "`r`n")</div>
</body></html>
"@
    Set-Content -Path $path -Value $html -Encoding UTF8
    Show-Info "Rapor" "Rapor oluşturuldu:`r`n$path"
    Start-Process $path
}


# ---------- ENTERPRISE V2 AUTO REMEDIATION ----------
function Select-FixCheck {
    param([string]$FixName)
    switch ($FixName) {
        "RPC" { if ($chkFixRpc) { $chkFixRpc.Checked = $true } }
        "POINTPRINT" { if ($chkFixPoint) { $chkFixPoint.Checked = $true } }
        "SMB" { if ($chkFixSmb) { $chkFixSmb.Checked = $true } }
        "FIREWALL" { if ($chkFixFirewall) { $chkFixFirewall.Checked = $true } }
        "SERVICES" { if ($chkFixServices) { $chkFixServices.Checked = $true } }
        "SPOOLER" { if ($chkFixSpooler) { $chkFixSpooler.Checked = $true } }
        "NTLM" { if ($chkFixNtlm) { $chkFixNtlm.Checked = $true } }
        "CREDENTIAL" { if ($chkFixCredential) { $chkFixCredential.Checked = $true } }
        "WORKGROUP" { if ($chkFixWorkgroup) { $chkFixWorkgroup.Checked = $true } }
        "DRIVER" { if ($chkFixDriver) { $chkFixDriver.Checked = $true } }
    }
}

function Clear-AllFixChecks {
    foreach ($c in @($chkFixRpc,$chkFixPoint,$chkFixSmb,$chkFixFirewall,$chkFixServices,$chkFixSpooler,$chkFixNtlm,$chkFixCredential,$chkFixDriver,$chkFixWorkgroup)) {
        if ($c) { $c.Checked = $false }
    }
}

function Get-RecommendedFixesFromDiag {
    $fixes = New-Object System.Collections.Generic.HashSet[string]

    foreach ($d in $script:DiagItems) {
        $t = ("{0} {1} {2} {3} {4}" -f $d.Kategori,$d.Ad,$d.Durum,$d.Detay,$d.Oneri).ToLowerInvariant()

        if ($t -match "rpc|135|0x0000011b|named pipe|rpcauthn") {
            [void]$fixes.Add("RPC")
            [void]$fixes.Add("SERVICES")
        }
        if ($t -match "point|print|709|restrictdriver|package") {
            [void]$fixes.Add("POINTPRINT")
            [void]$fixes.Add("SERVICES")
        }
        if ($t -match "445|smb|net view|paylaşım|share|access is denied|erişim engellendi") {
            [void]$fixes.Add("SMB")
            [void]$fixes.Add("FIREWALL")
            [void]$fixes.Add("CREDENTIAL")
        }
        if ($t -match "firewall|discovery|private|public|network profile|ağ profili") {
            [void]$fixes.Add("FIREWALL")
        }
        if ($t -match "spool|spooler|queue|kuyruk") {
            [void]$fixes.Add("SPOOLER")
            [void]$fixes.Add("SERVICES")
        }
        if ($t -match "driver|sürücü|0x0000007c|yüklenemedi|package") {
            [void]$fixes.Add("DRIVER")
            [void]$fixes.Add("POINTPRINT")
            [void]$fixes.Add("SPOOLER")
        }
        if ($t -match "credential|kimlik|parola|şifre|net use|denied") {
            [void]$fixes.Add("CREDENTIAL")
        }
        if ($t -match "netbios|ntlm|dns|ad çözümleme|hostname") {
            [void]$fixes.Add("NTLM")
        }
        if ($t -match "trustedhosts|localaccounttokenfilterpolicy|workgroup|winrm|yerel ilke") {
            [void]$fixes.Add("WORKGROUP")
        }
    }

    if ($fixes.Count -eq 0) {
        [void]$fixes.Add("RPC")
        [void]$fixes.Add("POINTPRINT")
        [void]$fixes.Add("FIREWALL")
        [void]$fixes.Add("SERVICES")
        [void]$fixes.Add("SPOOLER")
    }

    return $fixes
}

function Apply-RecommendedFixSelection {
    Clear-AllFixChecks
    $fixes = Get-RecommendedFixesFromDiag
    foreach ($f in $fixes) { Select-FixCheck $f }

    $role = Get-SelectedRole
    $msg = "Algılanan/Seçili rol: $role`r`n`r`nÖnerilen fixler seçildi:`r`n" + (($fixes | Sort-Object) -join "`r`n")
    OK "Auto remediation önerileri seçildi: $(($fixes | Sort-Object) -join ', ')"
    Show-Info "Önerilen Düzeltmeler" $msg
}

function Invoke-AutoRemediation {
    if ($script:DiagItems.Count -eq 0) {
        WARN "Teşhis sonucu yok. Önce yerel arıza tespiti çalıştırılıyor."
        Run-LocalDiagnosis
    }

    Apply-RecommendedFixSelection
    $role = Get-SelectedRole
    Apply-SelectedFixes -RoleLabel $role
    Show-Info "Auto Remediation" "Önerilen düzeltmeler uygulandı.`r`nRol: $role`r`nLog: $script:LogFile"
}

function Run-EnterpriseWorkflow {
    Write-Log "=== ENTERPRISE WORKFLOW BAŞLADI ==="
    Run-LocalDiagnosis

    if (-not [string]::IsNullOrWhiteSpace($txtRemotePc.Text.Trim())) {
        Run-RemoteDiagnosis
    } else {
        WARN "Uzak PC/IP girilmedi; remote host analizi atlandı."
    }

    Apply-RecommendedFixSelection
    $role = Get-SelectedRole
    Apply-SelectedFixes -RoleLabel $role

    if (-not [string]::IsNullOrWhiteSpace($txtManualUNC.Text.Trim()) -and $txtManualUNC.Text.Trim() -ne "\\PCADI\PAYLASIM") {
        Connect-ManualPrinter
    } else {
        WARN "Manuel UNC girilmedi; otomatik bağlantı adımı atlandı."
    }

    Write-Log "=== ENTERPRISE WORKFLOW BİTTİ ===" "OK"
    Show-Info "Enterprise Workflow" "Enterprise iş akışı tamamlandı.`r`nLog: $script:LogFile"
}



# ---------- V2.2 BACKUP / RESTORE ENGINE ----------
function New-BackupSnapshot {
    param([string]$Reason="Manual")

    $id = "BACKUP_{0}" -f (Get-Date -Format "yyyy_MM_dd_HHmmss")
    $backupPath = Join-Path $script:BackupRoot $id
    $regPath = Join-Path $backupPath "registry"

    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    New-Item -Path $regPath -ItemType Directory -Force | Out-Null

    Write-Log "Yedek snapshot oluşturuluyor: $id / Sebep: $Reason"

    $regTargets = @(
        @{Name="Control_Print"; Path="HKLM\SYSTEM\CurrentControlSet\Control\Print"},
        @{Name="Policies_Printers"; Path="HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers"},
        @{Name="LanmanServer"; Path="HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer"},
        @{Name="LanmanWorkstation"; Path="HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation"},
        @{Name="Spooler"; Path="HKLM\SYSTEM\CurrentControlSet\Services\Spooler"},
        @{Name="Policies_System"; Path="HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"},
        @{Name="Lsa"; Path="HKLM\SYSTEM\CurrentControlSet\Control\Lsa"}
    )

    foreach ($r in $regTargets) {
        try {
            $outFile = Join-Path $regPath ($r.Name + ".reg")
            $cmd = 'reg export "{0}" "{1}" /y' -f $r.Path, $outFile
            cmd /c $cmd 2>&1 | ForEach-Object { Write-Log "REG_EXPORT: $_" }
            if (Test-Path $outFile) { OK "Registry yedeklendi: $($r.Path)" } else { WARN "Registry export dosyası oluşmadı: $($r.Path)" }
        } catch {
            WARN "Registry export hatası $($r.Path): $_"
        }
    }

    try {
        $services = foreach ($svc in @("Spooler","WinRM","FDResPub","SSDPSRV","upnphost","LanmanServer","LanmanWorkstation","RpcSs","RpcEptMapper")) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s) {
                $w = Get-CimInstance Win32_Service -Filter "Name='$svc'" -ErrorAction SilentlyContinue
                [PSCustomObject]@{
                    Name=$svc
                    Status="$($s.Status)"
                    StartType= if ($w) { "$($w.StartMode)" } else { "" }
                }
            }
        }
        $services | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $backupPath "services.json") -Encoding UTF8
        OK "Servis snapshot alındı"
    } catch { WARN "Servis snapshot hatası: $_" }

    try {
        Get-Printer -ErrorAction SilentlyContinue | Select-Object Name,ShareName,Shared,PortName,DriverName,Type,ComputerName |
            ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $backupPath "printers.json") -Encoding UTF8
        OK "Yazıcı snapshot alındı"
    } catch { WARN "Yazıcı snapshot hatası: $_" }

    try {
        Get-PrinterPort -ErrorAction SilentlyContinue | Select-Object Name,PrinterHostAddress,PortNumber,Protocol |
            ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $backupPath "printer_ports.json") -Encoding UTF8
        OK "Yazıcı port snapshot alındı"
    } catch { WARN "Yazıcı port snapshot hatası: $_" }

    try {
        netsh advfirewall export (Join-Path $backupPath "firewall.wfw") 2>&1 | ForEach-Object { Write-Log "FIREWALL_EXPORT: $_" }
        OK "Firewall snapshot alındı"
    } catch { WARN "Firewall snapshot hatası: $_" }

    try {
        cmdkey /list 2>&1 | Set-Content -Path (Join-Path $backupPath "credentials_targets.txt") -Encoding UTF8
        OK "Credential hedefleri loglandı"
    } catch { WARN "Credential hedef log hatası: $_" }

    try {
        $snapshot = [PSCustomObject]@{
            Id=$id
            Reason=$Reason
            Computer=$env:COMPUTERNAME
            User=$env:USERNAME
            Date=(Get-Date).ToString("s")
            Tool=$script:AppCode
            Path=$backupPath
        }
        $snapshot | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $backupPath "snapshot.json") -Encoding UTF8
    } catch {}

    $script:LastBackupPath = $backupPath
    OK "Yedek snapshot tamamlandı: $backupPath"
    Show-Info "Yedek Alındı" "Ayar yedeği oluşturuldu:`r`n$backupPath"
    return $backupPath
}

function Get-LatestBackupPath {
    try {
        $latest = Get-ChildItem -Path $script:BackupRoot -Directory -Filter "BACKUP_*" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($latest) { return $latest.FullName }
    } catch {}
    return ""
}

function Restore-BackupSnapshot {
    param([string]$BackupPath="")

    if ([string]::IsNullOrWhiteSpace($BackupPath)) {
        $BackupPath = Get-LatestBackupPath
    }

    if ([string]::IsNullOrWhiteSpace($BackupPath) -or !(Test-Path $BackupPath)) {
        Show-Warn "Yedek Bulunamadı" "Geri yüklenecek backup bulunamadı."
        return
    }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Seçilen yedek geri yüklenecek:`r`n$BackupPath`r`n`r`nDevam edilsin mi?",
        "Yedekten Geri Yükle",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        WARN "Geri yükleme iptal edildi"
        return
    }

    Write-Log "Yedekten geri yükleme başlıyor: $BackupPath"

    $regPath = Join-Path $BackupPath "registry"
    if (Test-Path $regPath) {
        Get-ChildItem -Path $regPath -Filter "*.reg" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                cmd /c ('reg import "{0}"' -f $_.FullName) 2>&1 | ForEach-Object { Write-Log "REG_IMPORT: $_" }
                OK "Registry geri yüklendi: $($_.Name)"
            } catch {
                WARN "Registry import hatası $($_.Name): $_"
            }
        }
    }

    $fw = Join-Path $BackupPath "firewall.wfw"
    if (Test-Path $fw) {
        try {
            netsh advfirewall import $fw 2>&1 | ForEach-Object { Write-Log "FIREWALL_IMPORT: $_" }
            OK "Firewall yedeği geri yüklendi"
        } catch { WARN "Firewall geri yükleme hatası: $_" }
    }

    $svcFile = Join-Path $BackupPath "services.json"
    if (Test-Path $svcFile) {
        try {
            $svcs = Get-Content $svcFile -Raw | ConvertFrom-Json
            foreach ($s in $svcs) {
                try {
                    if ($s.StartType) {
                        switch -Regex ($s.StartType) {
                            "Auto" { Set-Service -Name $s.Name -StartupType Automatic -ErrorAction SilentlyContinue }
                            "Manual" { Set-Service -Name $s.Name -StartupType Manual -ErrorAction SilentlyContinue }
                            "Disabled" { Set-Service -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue }
                        }
                    }
                    if ($s.Status -eq "Running") { Start-Service -Name $s.Name -ErrorAction SilentlyContinue }
                    if ($s.Status -eq "Stopped") { Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue }
                    OK "Servis geri yüklendi: $($s.Name)"
                } catch { WARN "Servis restore hatası $($s.Name): $_" }
            }
        } catch { WARN "Servis restore dosyası okunamadı: $_" }
    }

    try { Restart-Service Spooler -Force -ErrorAction SilentlyContinue; OK "Spooler yeniden başlatıldı" } catch {}

    Show-Warn "Geri Yükleme Tamamlandı" "Yedek geri yüklendi.`r`nDeğişikliklerin tam uygulanması için bilgisayarı yeniden başlatmanız önerilir."
}

function Open-BackupFolder {
    try {
        if (!(Test-Path $script:BackupRoot)) { New-Item -Path $script:BackupRoot -ItemType Directory -Force | Out-Null }
        Start-Process explorer.exe $script:BackupRoot
    } catch { WARN "Backup klasörü açılamadı: $_" }
}

# ---------- V2.1 WORKGROUP PATCH ----------
$script:RestartRequired = $false

function Mark-RestartRequired {
    param([string]$Reason)
    $script:RestartRequired = $true
    WARN "Yeniden başlatma gerekebilir: $Reason"
}
function Ensure-WinRMServiceNoPrompt {
    try {
        Set-Service WinRM -StartupType Automatic -ErrorAction SilentlyContinue
        $svc = Get-Service WinRM -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne "Running") {
            Start-Service WinRM -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
        return $true
    } catch {
        WARN "WinRM servisi sessiz başlatılamadı: $_"
        return $false
    }
}

function Apply-TrustedHostsClientFix {
    Write-Log "TrustedHosts client uyumluluğu uygulanıyor..."
    try {
        $server = ""
        try { $server = $txtRemotePc.Text.Trim() } catch {}
        if ([string]::IsNullOrWhiteSpace($server)) {
            try { $server = Get-ServerFromUNC $txtManualUNC.Text.Trim() } catch {}
        }
        if ([string]::IsNullOrWhiteSpace($server) -or $server -eq "PCADI") {
            WARN "TrustedHosts için gerçek Host PC/IP girilmedi. İşlem atlandı."
            return
        }
        Ensure-WinRMServiceNoPrompt | Out-Null
        Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $server -Concatenate -Force -ErrorAction Stop
        OK "TrustedHosts listesine eklendi: $server"
        Add-Action "TrustedHosts" "OK" "Client TrustedHosts += $server"
    } catch { WARN "TrustedHosts uygulanamadı: $_" }
}

function Apply-WinRMHostFix {
    Write-Log "WinRM/PSRemoting host uyumluluğu uygulanıyor..."
    try {
        Ensure-WinRMServiceNoPrompt | Out-Null
        Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
        winrm quickconfig -quiet 2>&1 | ForEach-Object { Write-Log "WINRM: $_" }
        OK "WinRM/PSRemoting etkinleştirildi"
        Add-Action "WinRM Host" "OK" "Enable-PSRemoting + quickconfig"
    } catch { WARN "WinRM/PSRemoting uygulanamadı: $_" }
}

function Apply-LocalAccountTokenFilterPolicy {
    Write-Log "LocalAccountTokenFilterPolicy uygulanıyor..."
    try {
        Set-DWordSafe "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "LocalAccountTokenFilterPolicy" 1
        OK "LocalAccountTokenFilterPolicy=1 uygulandı"
        Mark-RestartRequired "LocalAccountTokenFilterPolicy"
    } catch { WARN "LocalAccountTokenFilterPolicy uygulanamadı: $_" }
}

function Apply-AdvancedPrinterPolicies {
    Write-Log "Gelişmiş yazıcı grup ilkesi uyumluluk ayarları uygulanıyor..."
    try {
        $pnp = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint"
        Set-DWordSafe $pnp "RestrictDriverInstallationToAdministrators" 0
        Set-DWordSafe $pnp "NoWarningNoElevationOnInstall" 1
        Set-DWordSafe $pnp "NoWarningNoElevationOnUpdate" 1
        Set-DWordSafe $pnp "UpdatePromptSettings" 0
        Set-DWordSafe $pnp "TrustedServers" 1
        Set-DWordSafe $pnp "InForest" 0

        $server = ""
        try { $server = $txtRemotePc.Text.Trim() } catch {}
        if ([string]::IsNullOrWhiteSpace($server)) {
            try { $server = Get-ServerFromUNC $txtManualUNC.Text.Trim() } catch {}
        }
        if (-not [string]::IsNullOrWhiteSpace($server) -and $server -ne "PCADI") {
            Set-MultiStringSafe $pnp "ServerList" @($server)
            $pkg = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PackagePointAndPrint"
            Ensure-Key $pkg
            Set-MultiStringSafe $pkg "PackagePointAndPrintServerList" @($server)
            Set-DWordSafe $pkg "PackagePointAndPrintOnly" 0
            OK "Trusted/Package Point and Print server listesine eklendi: $server"
        }

        Set-DWordSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers" "DisableHTTPPrinting" 0
        Set-DWordSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers" "DisableWebPnPDownload" 0
        Set-DWordSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers" "RegisterSpoolerRemoteRpcEndPoint" 1
        Set-DWordSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers" "RenderPrintJobsOnClientComputers" 1
        Set-DWordSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers" "ForceCSREMFDespooling" 0
        OK "Gelişmiş yazıcı policyleri uygulandı"
        Mark-RestartRequired "Yazıcı policy değişiklikleri"
    } catch { WARN "Gelişmiş yazıcı policyleri uygulanamadı: $_" }
}

function Apply-WorkgroupCompatibilityFix {
    Write-Log "=== WORKGROUP / WIN10-WIN11 COMPATIBILITY FIX BAŞLADI ==="
    $role = Get-SelectedRole
    if ($role -eq "Host" -or $role -eq "Both") {
        Apply-WinRMHostFix
        Apply-LocalAccountTokenFilterPolicy
        Enable-NetworkProfilePrivate
        Enable-PrinterFirewall
        Ensure-Services
        Apply-RPC-PrinterCore
        Apply-SMB-Compatibility
    }
    if ($role -eq "Client" -or $role -eq "Both") {
        Apply-TrustedHostsClientFix
        Apply-AdvancedPrinterPolicies
        Apply-RPC-PrinterCore
        Apply-PointAndPrint
        Apply-CredentialCleanup
        Ensure-Services
        Reset-Spooler
    }
    Invoke-GPUpdateSafe
    if ($script:RestartRequired) {
        Show-Warn "Yeniden Başlatma Önerilir" "Workgroup/Policy düzeltmeleri uygulandı.`r`nBazı ayarların tam uygulanması için bilgisayarı yeniden başlatmanız önerilir."
    }
    Write-Log "=== WORKGROUP / WIN10-WIN11 COMPATIBILITY FIX BİTTİ ===" "OK"
}

# ---------- GUI ----------
$script:LangMode = "TR"
$script:DarkMode = $true
$script:UiTextBindings = New-Object System.Collections.Generic.List[object]
$script:ColumnTextBindings = New-Object System.Collections.Generic.List[object]
$script:PageTitles = @{
    dashboard = @{ TR="Ana Panel"; EN="Dashboard" }
    finder    = @{ TR="Yazıcı Bağla"; EN="Connect Printer" }
    fixes     = @{ TR="Onarım"; EN="Fixes" }
    driver    = @{ TR="Sürücü Temizliği"; EN="Driver Cleanup" }
    diag      = @{ TR="Tespit"; EN="Diagnostics" }
    logs      = @{ TR="Kayıtlar"; EN="Logs" }
    tools     = @{ TR="Araçlar"; EN="Tools" }
}
$script:UiTexts = @{
    Brand = @{ TR="Ultimate"; EN="Ultimate" }
    BrandCompact = @{ TR="UPT"; EN="UPT" }
    BrandSub = @{ TR="Yazıcı bağlantı ve onarım"; EN="Printer connection and repair" }
    ThemeDark = @{ TR="Tema"; EN="Theme" }
    ThemeLight = @{ TR="Koyu"; EN="Dark" }
    StatusReady = @{ TR="Hazır"; EN="Ready" }
    DashboardHint = @{ TR="En sık kullanılan akış: önce tespit, sonra önerilen onarım, sonra yazıcı bağlantısı."; EN="Recommended flow: diagnose first, apply suggested fixes, then connect the printer." }
    RoleUnknown = @{ TR="Rol: Belirsiz"; EN="Role: Unknown" }
    Detect = @{ TR="Tespit Yap"; EN="Diagnose" }
    SelectRecommended = @{ TR="Önerilenleri Seç"; EN="Select Suggested" }
    CommonFix = @{ TR="Genel Onarım"; EN="Common Fix" }
    QuickCommonFix = @{ TR="Hızlı Genel Onarım"; EN="Quick Common Fix" }
    ConnectPrinter = @{ TR="Yazıcı Bağla"; EN="Connect Printer" }
    SmartWorkflow = @{ TR="Akıllı Akış"; EN="Smart Workflow" }
    SecureDefault = @{ TR="Güvenli Varsayılan"; EN="Secure Defaults" }
    SecureDefaults = @{ TR="Güvenli Varsayılanlar"; EN="Secure Defaults" }
    Tools = @{ TR="Araçlar"; EN="Tools" }
    RemotePc = @{ TR="Uzak PC/IP"; EN="Remote PC/IP" }
    ThisPc = @{ TR="Bu PC"; EN="This PC" }
    ScanRemote = @{ TR="Uzak PC Tara"; EN="Scan Remote PC" }
    ConnectSelected = @{ TR="Seçileni Bağla"; EN="Connect Selected" }
    RemoveSelected = @{ TR="Seçileni Kaldır"; EN="Remove Selected" }
    SetDefault = @{ TR="Varsayılan Yap"; EN="Set Default" }
    TestPage = @{ TR="Test Sayfası"; EN="Test Page" }
    Queue = @{ TR="Kuyruk"; EN="Queue" }
    Properties = @{ TR="Özellikler"; EN="Properties" }
    Share = @{ TR="Paylaşıma Aç"; EN="Share" }
    PrepBeforeScan = @{ TR="Tarama öncesi hazırlık yap"; EN="Prepare before scan" }
    FixBeforeConnect = @{ TR="Bağlamadan önce onar"; EN="Fix before connect" }
    RemoveOld = @{ TR="Eski bağlantıyı temizle"; EN="Remove old connection" }
    ConnectUNC = @{ TR="UNC Bağla"; EN="Connect UNC" }
    FixesHint = @{ TR="Sorunu biliyorsanız yalnızca ilgili onarımları seçin. Emin değilseniz Önerilenleri Seç kullanın."; EN="Select only the fixes you need. If unsure, use Select Suggested." }
    ApplySelectedFixes = @{ TR="Seçili Onarımları Uygula"; EN="Apply Selected Fixes" }
    OpenLpdLpr = @{ TR="LPD/LPR Aç"; EN="Enable LPD/LPR" }
    Smb1Risk = @{ TR="SMB1 Client (Riskli)"; EN="SMB1 Client (Risky)" }
    RelaxSmbSigning = @{ TR="SMB signing gevşet"; EN="Relax SMB signing" }
    EnableGuestRisk = @{ TR="Guest erişimi aç (riskli)"; EN="Enable guest access (risky)" }
    FixSection = @{ TR="Önerilen / seçilebilir düzeltmeler"; EN="Suggested / selectable fixes" }
    FixSummaryEmpty = @{ TR="Henüz seçim yapılmadı. Önerilenleri Seç butonuna basabilirsiniz."; EN="No selection yet. You can press Select Suggested." }
    DriverHint = @{ TR="Sistemdeki sürücüler listelenmiştir. Silmek istediğiniz sürücüyü seçip kaldırabilir veya geniş marka araması yapabilirsiniz."; EN="Installed drivers are listed. Select a driver to remove it, or search broadly by brand/model." }
    AutoDetect = @{ TR="Otomatik Tespit"; EN="Auto Detect" }
    RemoveDriver = @{ TR="Seçili Driverı Kaldır"; EN="Remove Selected Driver" }
    PrintServerProps = @{ TR="Print Server Özellikleri"; EN="Print Server Properties" }
    PnpRescan = @{ TR="PnP Yeniden Tara"; EN="Rescan PnP" }
    DevicesPrinters = @{ TR="Aygıtlar ve Yazıcılar"; EN="Devices and Printers" }
    Local = @{ TR="Yerel"; EN="Local" }
    Remote = @{ TR="Uzak"; EN="Remote" }
    Clear = @{ TR="Temizle"; EN="Clear" }
    LogFolder = @{ TR="Log Klasörü"; EN="Log Folder" }
    HtmlReport = @{ TR="HTML Rapor"; EN="HTML Report" }
    ToolsHint = @{ TR="Araçlar: Embedded CMD/PS1 araçları ve eski sürümler buradan çalıştırılır. Yönetici penceresiyle açılır."; EN="Tools: Embedded CMD/PS1 tools and older versions launch here in an administrator window." }
    OpenToolkitFolder = @{ TR="Toolkit Klasörünü Aç"; EN="Open Toolkit Folder" }
    AdvancedConsole = @{ TR="Gelişmiş Yazıcı Onarım Konsolu"; EN="Advanced Printer Repair Console" }
    Fix11bConsole = @{ TR="0x0000011b Onarım Konsolu"; EN="0x0000011b Repair Console" }
    Fix709Console = @{ TR="0x00000709 Onarım Konsolu"; EN="0x00000709 Repair Console" }
    GuestConsole = @{ TR="Konuk Paylaşım Onarım Konsolu"; EN="Guest Share Repair Console" }
    LegacyV2 = @{ TR="Eski Kurumsal GUI Sürüm V2"; EN="Legacy Enterprise GUI V2" }
    ColType = @{ TR="Tür"; EN="Type" }
    ColName = @{ TR="Ad"; EN="Name" }
    ColShare = @{ TR="Paylaşım"; EN="Share" }
    ColPath = @{ TR="Yol"; EN="Path" }
    ColDriver = @{ TR="Sürücü"; EN="Driver" }
    ColSource = @{ TR="Kaynak"; EN="Source" }
    ColNote = @{ TR="Not"; EN="Note" }
    ColDriverName = @{ TR="Sürücü Adı"; EN="Driver Name" }
    ColEnvironment = @{ TR="Mimari / Ortam"; EN="Architecture / Environment" }
    ColVersion = @{ TR="Tip / Sürüm"; EN="Type / Version" }
    ColStatus = @{ TR="Durum (Kullanım)"; EN="Status (Usage)" }
    ColCategory = @{ TR="Kategori"; EN="Category" }
    ColState = @{ TR="Durum"; EN="Status" }
    ColDetail = @{ TR="Detay"; EN="Detail" }
    ColSuggestion = @{ TR="Öneri"; EN="Suggestion" }
    FixCount = @{ TR="Seçili düzeltme sayısı: {0}"; EN="Selected fix count: {0}" }
}

function T {
    param([string]$Key)
    if ($script:UiTexts.ContainsKey($Key) -and $script:UiTexts[$Key].ContainsKey($script:LangMode)) {
        return $script:UiTexts[$Key][$script:LangMode]
    }
    return $Key
}
function Register-UiText {
    param([object]$Control,[string]$Key,[string]$Prefix="")
    if (-not $Control) { return }
    $script:UiTextBindings.Add([PSCustomObject]@{Control=$Control;Key=$Key;Prefix=$Prefix}) | Out-Null
    $Control.Text = "$Prefix$(T $Key)"
}
function Register-ColumnText {
    param([System.Windows.Forms.DataGridView]$Grid,[string]$Column,[string]$Key)
    if (-not $Grid -or -not $Grid.Columns.Contains($Column)) { return }
    $script:ColumnTextBindings.Add([PSCustomObject]@{Grid=$Grid;Column=$Column;Key=$Key}) | Out-Null
    $Grid.Columns[$Column].HeaderText = T $Key
}
function Set-PageTitleText {
    param([string]$Name)
    if ($pageTitle -and $script:PageTitles.ContainsKey($Name)) {
        $pageTitle.Text = $script:PageTitles[$Name][$script:LangMode]
    }
}
function Update-FixSummaryText {
    if ($lblFixSummary) { $lblFixSummary.Text = [string]::Format((T "FixCount"), (Get-SelectedFixCount)) }
}
function Refresh-Language {
    foreach ($binding in $script:UiTextBindings) {
        if ($binding.Control) { $binding.Control.Text = "$($binding.Prefix)$(T $binding.Key)" }
    }
    foreach ($binding in $script:ColumnTextBindings) {
        if ($binding.Grid -and $binding.Grid.Columns.Contains($binding.Column)) {
            $binding.Grid.Columns[$binding.Column].HeaderText = T $binding.Key
        }
    }
    foreach ($pair in @(
        @{Button=$btnDashboard;Page="dashboard";Icon=$script:Icons.Dashboard},
        @{Button=$btnFinder;Page="finder";Icon=$script:Icons.Finder},
        @{Button=$btnFixes;Page="fixes";Icon=$script:Icons.Fixes},
        @{Button=$btnDriver;Page="driver";Icon=$script:Icons.Driver},
        @{Button=$btnDiag;Page="diag";Icon=$script:Icons.Diag},
        @{Button=$btnLogs;Page="logs";Icon=$script:Icons.Logs},
        @{Button=$btnTools;Page="tools";Icon=$script:Icons.Tools}
    )) {
        if ($pair.Button) {
            $label = $script:PageTitles[$pair.Page][$script:LangMode]
            $pair.Button.AccessibleDescription = "  $($pair.Icon)  $label"
        }
    }
    if ($btnWorkflow) { $btnWorkflow.AccessibleDescription = "  $($script:Icons.Workflow)  $(T "SmartWorkflow")" }
    if ($btnBackup) { $btnBackup.AccessibleDescription = "  $($script:Icons.Backup)  $(if ($script:LangMode -eq "TR") { "Yedek Al" } else { "Backup" })" }
    $activePage = ($pages.Keys | Where-Object { $pages[$_].Visible } | Select-Object -First 1)
    if ($activePage) { Set-PageTitleText $activePage }
    if ($btnLang) { $btnLang.Text = if ($script:LangMode -eq "TR") { "EN" } else { "TR" } }
    if ($btnTheme) { $btnTheme.Text = if ($script:DarkMode) { T "ThemeDark" } else { T "ThemeLight" } }
    if ($script:LblStatus -and $script:LblStatus.Text -in @("Hazır","Ready")) { $script:LblStatus.Text = T "StatusReady" }
    Apply-ResponsiveLayout
}

$form = New-Object System.Windows.Forms.Form
$form.Text = $script:AppName
$workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$initialWidth = [Math]::Min(1280, [Math]::Max(760, [int]($workingArea.Width * 0.92)))
$initialHeight = [Math]::Min(820, [Math]::Max(560, [int]($workingArea.Height * 0.90)))
$minWidth = [Math]::Min(760, [Math]::Max(640, $workingArea.Width - 80))
$minHeight = [Math]::Min(560, [Math]::Max(480, $workingArea.Height - 80))
$form.Size = New-Object System.Drawing.Size($initialWidth,$initialHeight)
$form.MinimumSize = New-Object System.Drawing.Size($minWidth,$minHeight)
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.StartPosition = "CenterScreen"
$form.BackColor = $C_Bg
$form.ForeColor = $C_Fg
try { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$env:SystemRoot\system32\shell32.dll") } catch {}

$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = "Fill"
$root.ColumnCount = 2
$root.RowCount = 1
[void]$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,240)))
[void]$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,100)))
$form.Controls.Add($root)

$side = New-Object System.Windows.Forms.Panel
$side.Dock = "Fill"
$side.BackColor = $C_Side
$side.AutoScroll = $true
$root.Controls.Add($side,0,0)

$brand = New-Object System.Windows.Forms.Label
$brand.Text = T "Brand"
$brand.ForeColor = $C_Fg
$brand.Font = New-Object System.Drawing.Font("Segoe UI",17,[System.Drawing.FontStyle]::Bold)
$brand.Location = New-Object System.Drawing.Point(18,22)
$brand.AutoSize = $true
$side.Controls.Add($brand)

$brandSub = New-Object System.Windows.Forms.Label
$brandSub.Text = T "BrandSub"
$brandSub.ForeColor = $C_Muted
$brandSub.Font = New-Object System.Drawing.Font("Segoe UI",9)
$brandSub.Location = New-Object System.Drawing.Point(20,56)
$brandSub.AutoSize = $true
$side.Controls.Add($brandSub)
Register-UiText $brandSub "BrandSub"

function New-MenuButton {
    param([string]$Text,[int]$Top,[string]$Icon="",[object]$Back=$null)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = if ([string]::IsNullOrWhiteSpace($Icon)) { $Text } else { "  $Icon  $Text" }
    $b.Location = New-Object System.Drawing.Point(14,$Top)
    $b.Size = New-Object System.Drawing.Size(212,40)
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize = 0
    $b.TextAlign = "MiddleLeft"
    $b.Font = New-Object System.Drawing.Font("Segoe UI Emoji",10,[System.Drawing.FontStyle]::Bold)
    $b.ForeColor = if ($Back) { [System.Drawing.Color]::White } else { $C_Muted }
    $b.BackColor = if ($Back) { $Back } else { $C_Side }
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Tag = if ($Back) { "MenuButtonActive" } else { "MenuButton" }
    $b.AccessibleDescription = $b.Text
    $b.AccessibleName = $Icon
    return $b
}

$btnDashboard = New-MenuButton "Ana Panel" 108 $script:Icons.Dashboard $C_Accent
$btnFinder = New-MenuButton "Yazıcı Bağla" 154 $script:Icons.Finder
$btnFixes = New-MenuButton "Onarım" 200 $script:Icons.Fixes
$btnDriver = New-MenuButton "Sürücü Temizliği" 246 $script:Icons.Driver
$btnDiag = New-MenuButton "Tespit" 292 $script:Icons.Diag
$btnLogs = New-MenuButton "Kayıtlar" 338 $script:Icons.Logs
$btnTools = New-MenuButton "Araçlar" 384 $script:Icons.Tools
$btnWorkflow = New-MenuButton "Akıllı Akış" 450 $script:Icons.Workflow $C_Ok
$btnBackup = New-MenuButton "Yedek Al" 496 $script:Icons.Backup
foreach ($b in @($btnDashboard,$btnFinder,$btnFixes,$btnDriver,$btnDiag,$btnLogs,$btnTools,$btnWorkflow,$btnBackup)) { $side.Controls.Add($b) }

$main = New-Object System.Windows.Forms.TableLayoutPanel
$main.Dock = "Fill"
$main.RowCount = 3
$main.ColumnCount = 1
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,72)))
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,34)))
$root.Controls.Add($main,1,0)

$header = New-Object System.Windows.Forms.Panel
$header.Dock = "Fill"
$header.BackColor = $C_Panel
$main.Controls.Add($header,0,0)

$pageTitle = New-Object System.Windows.Forms.Label
$pageTitle.Text = $script:PageTitles.dashboard[$script:LangMode]
$pageTitle.ForeColor = $C_Fg
$pageTitle.Font = New-Object System.Drawing.Font("Segoe UI",18,[System.Drawing.FontStyle]::Bold)
$pageTitle.Location = New-Object System.Drawing.Point(20,18)
$pageTitle.AutoSize = $true
$header.Controls.Add($pageTitle)

$btnTheme = New-Object System.Windows.Forms.Button
$btnTheme.Text = T "ThemeDark"
$btnTheme.Size = New-Object System.Drawing.Size(76,34)
$btnTheme.Anchor = "Top,Right"
$btnTheme.Location = New-Object System.Drawing.Point(780,19)
$btnTheme.BackColor = $C_Panel2
$btnTheme.ForeColor = $C_Fg
$btnTheme.FlatStyle = "Flat"
$header.Controls.Add($btnTheme)
$btnLang = New-Object System.Windows.Forms.Button
$btnLang.Text = "EN"
$btnLang.Size = New-Object System.Drawing.Size(58,34)
$btnLang.Anchor = "Top,Right"
$btnLang.Location = New-Object System.Drawing.Point(716,19)
$btnLang.BackColor = $C_Panel2
$btnLang.ForeColor = $C_Fg
$btnLang.FlatStyle = "Flat"
$btnLang.FlatAppearance.BorderSize = 0
$btnLang.Cursor = [System.Windows.Forms.Cursors]::Hand
$header.Controls.Add($btnLang)
$header.Add_SizeChanged({ Update-HeaderActionLayout })

$content = New-Object System.Windows.Forms.Panel
$content.Dock = "Fill"
$content.Padding = New-Object System.Windows.Forms.Padding(16)
$content.BackColor = $C_Bg
$content.AutoScroll = $false
$main.Controls.Add($content,0,1)

$status = New-Object System.Windows.Forms.Panel
$status.Dock = "Fill"
$status.BackColor = $C_Panel
$main.Controls.Add($status,0,2)
$script:LblStatus = New-Object System.Windows.Forms.Label
$script:LblStatus.Text = T "StatusReady"
$script:LblStatus.ForeColor = $C_Muted
$script:LblStatus.Location = New-Object System.Drawing.Point(12,8)
$script:LblStatus.AutoSize = $true
$status.Controls.Add($script:LblStatus)

$pages = @{}
foreach ($name in @("dashboard","finder","fixes","driver","diag","logs","tools")) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = "Fill"
    $p.BackColor = $C_Bg
    $p.Visible = $false
    $p.AutoScroll = $true
    $content.Controls.Add($p)
    $pages[$name] = $p
}

function Set-ActiveMenu {
    param([string]$Name)
    $sideBg = if ($script:DarkMode) { $C_Side } else { $L_Side }
    $muted = if ($script:DarkMode) { $C_Muted } else { $L_Muted }

    foreach ($b in @($btnDashboard,$btnFinder,$btnFixes,$btnDriver,$btnDiag,$btnLogs,$btnTools)) {
        $b.BackColor = $sideBg
        $b.ForeColor = $muted
        $b.Tag = "MenuButton"
    }
    $target = switch ($Name) {
        "dashboard" { Set-PageTitleText "dashboard"; $btnDashboard }
        "finder" { Set-PageTitleText "finder"; $btnFinder }
        "fixes" { Set-PageTitleText "fixes"; $btnFixes }
        "driver" { Set-PageTitleText "driver"; $btnDriver }
        "diag" { Set-PageTitleText "diag"; $btnDiag }
        "logs" { Set-PageTitleText "logs"; $btnLogs }
        "tools" { Set-PageTitleText "tools"; $btnTools }
    }
    if ($target) {
        $target.BackColor = $C_Accent
        $target.ForeColor = [System.Drawing.Color]::White
        $target.Tag = "MenuButtonActive"
    }
}
function Show-Page {
    param([string]$Name)
    foreach ($k in $pages.Keys) { $pages[$k].Visible = $false }
    $pages[$Name].Visible = $true
    $pages[$Name].BringToFront()
    Set-ActiveMenu $Name
}
function Add-HoverEffect {
    param([System.Windows.Forms.Button]$Btn, [System.Drawing.Color]$NormalColor, [System.Drawing.Color]$HoverColor)
    
    $Btn.Add_MouseEnter({
        $this.BackColor = $HoverColor
    }.GetNewClosure())
    
    $Btn.Add_MouseLeave({
        $this.BackColor = $NormalColor
    }.GetNewClosure())
}

function New-ActionButton {
    param([string]$Text,[object]$Back,[int]$Width=130)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Width = $Width
    $b.Height = 32
    $b.Margin = New-Object System.Windows.Forms.Padding(4)
    $b.BackColor = $Back
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize = 0
    $b.Font = New-Object System.Drawing.Font("Segoe UI Emoji",9,[System.Drawing.FontStyle]::Bold)
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    # Hover animation trigger
    $hover = [System.Drawing.Color]::FromArgb([Math]::Min(255, $Back.R + 25), [Math]::Min(255, $Back.G + 25), [Math]::Min(255, $Back.B + 25))
    Add-HoverEffect $b $Back $hover
    return $b
}

function New-InfoLabel {
    param([string]$Text,[int]$Y)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.ForeColor = $C_Muted
    $l.Font = New-Object System.Drawing.Font("Segoe UI",10)
    $l.Location = New-Object System.Drawing.Point(4,$Y)
    $l.Size = New-Object System.Drawing.Size(880,24)
    return $l
}

# Dashboard
$dash = $pages["dashboard"]
$lblDashboardHint = New-InfoLabel (T "DashboardHint") 8
Register-UiText $lblDashboardHint "DashboardHint"
$dash.Controls.Add($lblDashboardHint)
$script:LblRoleValue = New-Object System.Windows.Forms.Label
$script:LblRoleValue.Text = T "RoleUnknown"
$script:LblRoleValue.ForeColor = $C_Fg
$script:LblRoleValue.Font = New-Object System.Drawing.Font("Segoe UI",13,[System.Drawing.FontStyle]::Bold)
$script:LblRoleValue.Location = New-Object System.Drawing.Point(4,48)
$script:LblRoleValue.Size = New-Object System.Drawing.Size(320,32)
$dash.Controls.Add($script:LblRoleValue)

$dashButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$dashButtons.Location = New-Object System.Drawing.Point(0,98)
$dashButtons.Size = New-Object System.Drawing.Size(940,52)
$dashButtons.BackColor = $C_Bg
$dashButtons.WrapContents = $true
$dashButtons.AutoScroll = $true
$dashButtons.Anchor = "Top,Left,Right"
$dash.Controls.Add($dashButtons)
$btnDashDiag = New-ActionButton "$($script:Icons.Diag) Tespit Yap" $C_Accent 140
$btnDashRecommend = New-ActionButton "$($script:Icons.Recommend) Önerilenleri Seç" $C_Warn 180
$btnDashQuickFix = New-ActionButton "$($script:Icons.AutoFix) Genel Onarım" $C_Accent 160
$btnDashFind = New-ActionButton "$($script:Icons.Finder) Yazıcı Bağla" $C_Ok 150
$btnDashWorkflow = New-ActionButton "$($script:Icons.Workflow) Akıllı Akış" $C_Panel2 150
$btnDashSecure = New-ActionButton "$($script:Icons.Shield) Güvenli Varsayılan" $C_Err 190
$btnDashTools = New-ActionButton "$($script:Icons.Tools) Araçlar" $C_Panel2 120
foreach ($b in @($btnDashDiag,$btnDashRecommend,$btnDashQuickFix,$btnDashFind,$btnDashWorkflow,$btnDashSecure,$btnDashTools)) { $dashButtons.Controls.Add($b) }
Register-UiText $btnDashDiag "Detect" "$($script:Icons.Diag) "
Register-UiText $btnDashRecommend "SelectRecommended" "$($script:Icons.Recommend) "
Register-UiText $btnDashQuickFix "CommonFix" "$($script:Icons.AutoFix) "
Register-UiText $btnDashFind "ConnectPrinter" "$($script:Icons.Finder) "
Register-UiText $btnDashWorkflow "SmartWorkflow" "$($script:Icons.Workflow) "
Register-UiText $btnDashSecure "SecureDefault" "$($script:Icons.Shield) "
Register-UiText $btnDashTools "Tools" "$($script:Icons.Tools) "

# Finder
$finder = $pages["finder"]
$finderLayout = New-Object System.Windows.Forms.TableLayoutPanel
$finderLayout.Dock = "Fill"
$finderLayout.RowCount = 2
$finderLayout.ColumnCount = 1
[void]$finderLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,156)))
[void]$finderLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
$finder.Controls.Add($finderLayout)

$finderTop = New-Object System.Windows.Forms.FlowLayoutPanel
$finderTop.Dock = "Fill"
$finderTop.WrapContents = $true
$finderTop.AutoScroll = $true
$finderTop.BackColor = $C_Bg
$finderLayout.Controls.Add($finderTop,0,0)
$lblRemote = New-Object System.Windows.Forms.Label
$lblRemote.Text = T "RemotePc"
$lblRemote.Width = 75
$lblRemote.Height = 28
$lblRemote.ForeColor = $C_Fg
$lblRemote.TextAlign = "MiddleLeft"
$finderTop.Controls.Add($lblRemote)
Register-UiText $lblRemote "RemotePc"
$txtRemotePc = New-Object System.Windows.Forms.TextBox
$txtRemotePc.Width = 170
$txtRemotePc.Font = New-Object System.Drawing.Font("Segoe UI",10)
$finderTop.Controls.Add($txtRemotePc)
$btnScan = New-ActionButton "$($script:Icons.Local) Bu PC" $C_Accent 100
$btnRemoteScan = New-ActionButton "$($script:Icons.Remote) Uzak PC Tara" $C_Warn 150
$btnConnect = New-ActionButton "Seçileni Bağla" $C_Ok 150
$btnRemoveSelectedPrinter = New-ActionButton "Seçileni Kaldır" $C_Err 150
$btnSetDefault = New-ActionButton "Varsayılan Yap" $C_Panel2 135
$btnTestPage = New-ActionButton "Test Sayfası" $C_Panel2 125
$btnQueue = New-ActionButton "Kuyruk" $C_Panel2 90
$btnProperties = New-ActionButton "Özellikler" $C_Panel2 105
$btnSharePrinter = New-ActionButton "Paylaşıma Aç" $C_Warn 135
foreach ($b in @($btnScan,$btnRemoteScan,$btnConnect,$btnRemoveSelectedPrinter,$btnSetDefault,$btnTestPage,$btnQueue,$btnProperties,$btnSharePrinter)) { $finderTop.Controls.Add($b) }
Register-UiText $btnScan "ThisPc" "$($script:Icons.Local) "
Register-UiText $btnRemoteScan "ScanRemote" "$($script:Icons.Remote) "
Register-UiText $btnConnect "ConnectSelected"
Register-UiText $btnRemoveSelectedPrinter "RemoveSelected"
Register-UiText $btnSetDefault "SetDefault"
Register-UiText $btnTestPage "TestPage"
Register-UiText $btnQueue "Queue"
Register-UiText $btnProperties "Properties"
Register-UiText $btnSharePrinter "Share"
$chkAutoFixBeforeScan = New-Object System.Windows.Forms.CheckBox
$chkAutoFixBeforeScan.Text = T "PrepBeforeScan"
$chkAutoFixBeforeScan.Width = 190
$chkAutoFixBeforeScan.Height = 28
$chkAutoFixBeforeScan.ForeColor = $C_Muted
$chkAutoFixBeforeScan.BackColor = $C_Bg
$finderTop.Controls.Add($chkAutoFixBeforeScan)
Register-UiText $chkAutoFixBeforeScan "PrepBeforeScan"
$chkAutoFixBeforeConnect = New-Object System.Windows.Forms.CheckBox
$chkAutoFixBeforeConnect.Text = T "FixBeforeConnect"
$chkAutoFixBeforeConnect.Width = 170
$chkAutoFixBeforeConnect.Height = 28
$chkAutoFixBeforeConnect.ForeColor = $C_Muted
$chkAutoFixBeforeConnect.BackColor = $C_Bg
$finderTop.Controls.Add($chkAutoFixBeforeConnect)
Register-UiText $chkAutoFixBeforeConnect "FixBeforeConnect"
$chkRemoveOld = New-Object System.Windows.Forms.CheckBox
$chkRemoveOld.Text = T "RemoveOld"
$chkRemoveOld.Width = 170
$chkRemoveOld.Height = 28
$chkRemoveOld.ForeColor = $C_Muted
$chkRemoveOld.BackColor = $C_Bg
$finderTop.Controls.Add($chkRemoveOld)
Register-UiText $chkRemoveOld "RemoveOld"
$txtManualUNC = New-Object System.Windows.Forms.TextBox
$txtManualUNC.Width = 250
$txtManualUNC.Text = "\\PCADI\PAYLASIM"
$finderTop.Controls.Add($txtManualUNC)
$btnManualConnect = New-ActionButton "UNC Bağla" $C_Panel2 110
$finderTop.Controls.Add($btnManualConnect)
Register-UiText $btnManualConnect "ConnectUNC"

$gridPrinters = New-Object System.Windows.Forms.DataGridView
$gridPrinters.Dock = "Fill"
$gridPrinters.BackgroundColor = $C_Panel
$gridPrinters.BorderStyle = "None"
$gridPrinters.RowHeadersVisible = $false
$gridPrinters.AllowUserToAddRows = $false
$gridPrinters.AllowUserToDeleteRows = $false
$gridPrinters.ReadOnly = $true
$gridPrinters.SelectionMode = "FullRowSelect"
$gridPrinters.AutoSizeColumnsMode = "None"
$gridPrinters.ScrollBars = "Both"
$gridPrinters.EnableHeadersVisualStyles = $false
$gridPrinters.ColumnHeadersHeight = 34
$gridPrinters.RowTemplate.Height = 30
$gridPrinters.ColumnHeadersDefaultCellStyle.BackColor = $C_Panel2
$gridPrinters.ColumnHeadersDefaultCellStyle.ForeColor = $C_Fg
$gridPrinters.DefaultCellStyle.BackColor = $C_Panel
$gridPrinters.DefaultCellStyle.ForeColor = $C_Fg
$gridPrinters.DefaultCellStyle.SelectionBackColor = $C_Accent
[void]$gridPrinters.Columns.Add("Type","Tür")
[void]$gridPrinters.Columns.Add("Name","Ad")
[void]$gridPrinters.Columns.Add("ShareName","Paylaşım")
[void]$gridPrinters.Columns.Add("UNC","Yol")
[void]$gridPrinters.Columns.Add("Driver","Sürücü")
[void]$gridPrinters.Columns.Add("Source","Kaynak")
[void]$gridPrinters.Columns.Add("Note","Not")
$gridPrinters.Columns["Type"].Width = 150
$gridPrinters.Columns["Name"].Width = 260
$gridPrinters.Columns["ShareName"].Width = 170
$gridPrinters.Columns["UNC"].Width = 340
$gridPrinters.Columns["Driver"].Width = 280
$gridPrinters.Columns["Source"].Width = 90
$gridPrinters.Columns["Note"].Width = 420
$finderLayout.Controls.Add($gridPrinters,0,1)
Register-ColumnText $gridPrinters "Type" "ColType"
Register-ColumnText $gridPrinters "Name" "ColName"
Register-ColumnText $gridPrinters "ShareName" "ColShare"
Register-ColumnText $gridPrinters "UNC" "ColPath"
Register-ColumnText $gridPrinters "Driver" "ColDriver"
Register-ColumnText $gridPrinters "Source" "ColSource"
Register-ColumnText $gridPrinters "Note" "ColNote"

# Fixes
$fixes = $pages["fixes"]
$lblFixesHint = New-InfoLabel (T "FixesHint") 4
Register-UiText $lblFixesHint "FixesHint"
$fixes.Controls.Add($lblFixesHint)
$cmbRole = New-Object System.Windows.Forms.ComboBox
$cmbRole.DropDownStyle = "DropDownList"
[void]$cmbRole.Items.Add("Auto")
[void]$cmbRole.Items.Add("Client")
[void]$cmbRole.Items.Add("Host")
[void]$cmbRole.Items.Add("Both")
$cmbRole.SelectedIndex = 0
$cmbRole.Location = New-Object System.Drawing.Point(4,38)
$cmbRole.Width = 130
$fixes.Controls.Add($cmbRole)
$btnRecommend = New-ActionButton "Önerilenleri Seç" $C_Warn 160
$btnRecommend.Location = New-Object System.Drawing.Point(150,34)
$fixes.Controls.Add($btnRecommend)
Register-UiText $btnRecommend "SelectRecommended"
$btnRunFixes = New-ActionButton "Seçili Onarımları Uygula" $C_Accent 210
$btnRunFixes.Location = New-Object System.Drawing.Point(320,34)
$fixes.Controls.Add($btnRunFixes)
Register-UiText $btnRunFixes "ApplySelectedFixes"
$btnCommonFix = New-ActionButton "Hızlı Genel Onarım" $C_Ok 180
$btnCommonFix.Location = New-Object System.Drawing.Point(540,34)
$fixes.Controls.Add($btnCommonFix)
Register-UiText $btnCommonFix "QuickCommonFix"
$btnSecureDefaults = New-ActionButton "Güvenli Varsayılanlar" $C_Err 190
$btnSecureDefaults.Location = New-Object System.Drawing.Point(730,34)
$fixes.Controls.Add($btnSecureDefaults)
Register-UiText $btnSecureDefaults "SecureDefaults"
$btnLpdLpr = New-ActionButton "LPD/LPR Aç" $C_Panel2 120
$btnLpdLpr.Location = New-Object System.Drawing.Point(4,72)
$fixes.Controls.Add($btnLpdLpr)
Register-UiText $btnLpdLpr "OpenLpdLpr"
$btnSmb1 = New-ActionButton "SMB1 Client (Riskli)" $C_Err 170
$btnSmb1.Location = New-Object System.Drawing.Point(134,72)
$fixes.Controls.Add($btnSmb1)
Register-UiText $btnSmb1 "Smb1Risk"
$chkSmbSigning = New-Object System.Windows.Forms.CheckBox
$chkSmbSigning.Text = T "RelaxSmbSigning"
$chkSmbSigning.Location = New-Object System.Drawing.Point(314,78)
$chkSmbSigning.Size = New-Object System.Drawing.Size(160,24)
$chkSmbSigning.ForeColor = $C_Muted
$chkSmbSigning.BackColor = $C_Bg
$fixes.Controls.Add($chkSmbSigning)
Register-UiText $chkSmbSigning "RelaxSmbSigning"
$chkGuest = New-Object System.Windows.Forms.CheckBox
$chkGuest.Text = T "EnableGuestRisk"
$chkGuest.Location = New-Object System.Drawing.Point(484,78)
$chkGuest.Size = New-Object System.Drawing.Size(190,24)
$chkGuest.ForeColor = $C_Muted
$chkGuest.BackColor = $C_Bg
$fixes.Controls.Add($chkGuest)
Register-UiText $chkGuest "EnableGuestRisk"
$lblFixSection = New-Object System.Windows.Forms.Label
$lblFixSection.Text = T "FixSection"
$lblFixSection.ForeColor = $C_Fg
$lblFixSection.Font = New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)
$lblFixSection.Location = New-Object System.Drawing.Point(4,116)
$lblFixSection.Size = New-Object System.Drawing.Size(360,28)
$fixes.Controls.Add($lblFixSection)
Register-UiText $lblFixSection "FixSection"

$lblFixSummary = New-Object System.Windows.Forms.Label
$lblFixSummary.Text = T "FixSummaryEmpty"
$lblFixSummary.ForeColor = $C_Muted
$lblFixSummary.Font = New-Object System.Drawing.Font("Segoe UI",9)
$lblFixSummary.Location = New-Object System.Drawing.Point(370,120)
$lblFixSummary.Size = New-Object System.Drawing.Size(520,24)
$fixes.Controls.Add($lblFixSummary)
Register-UiText $lblFixSummary "FixSummaryEmpty"

$fixList = New-Object System.Windows.Forms.FlowLayoutPanel
$fixList.Location = New-Object System.Drawing.Point(0,150)
$fixList.Size = New-Object System.Drawing.Size(940,390)
$fixList.AutoScroll = $true
$fixList.BackColor = $C_Bg
$fixes.Controls.Add($fixList)
$chkFixRpc=$null; $chkFixPoint=$null; $chkFixSmb=$null; $chkFixFirewall=$null; $chkFixServices=$null; $chkFixSpooler=$null; $chkFixNtlm=$null; $chkFixCredential=$null; $chkFixDriver=$null; $chkFixWorkgroup=$null
function Add-SimpleFixCheck {
    param([string]$Text,[string]$Role,[string]$Desc,[ref]$Ref)
    $card = New-Object System.Windows.Forms.Panel
    $card.Width = 430
    $card.Height = 76
    $card.Margin = New-Object System.Windows.Forms.Padding(8)
    $card.BackColor = $C_Panel
    $card.Tag = "Card"

    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $Text
    $c.Width = 270
    $c.Height = 26
    $c.Location = New-Object System.Drawing.Point(10,8)
    $c.ForeColor = $C_Fg
    $c.BackColor = $C_Panel
    $c.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $card.Controls.Add($c)

    $roleLabel = New-Object System.Windows.Forms.Label
    $roleLabel.Text = $Role
    $roleLabel.Width = 130
    $roleLabel.Height = 22
    $roleLabel.Location = New-Object System.Drawing.Point(290,10)
    $roleLabel.ForeColor = $C_Warn
    $roleLabel.TextAlign = "MiddleRight"
    $roleLabel.Font = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $card.Controls.Add($roleLabel)

    $descLabel = New-Object System.Windows.Forms.Label
    $descLabel.Text = $Desc
    $descLabel.Width = 405
    $descLabel.Height = 34
    $descLabel.Location = New-Object System.Drawing.Point(12,36)
    $descLabel.ForeColor = $C_Muted
    $descLabel.Font = New-Object System.Drawing.Font("Segoe UI",8.5)
    $card.Controls.Add($descLabel)

    $fixList.Controls.Add($card)
    $Ref.Value = $c
}
Add-SimpleFixCheck "RPC / 0x0000011b" "Client + Host" "Windows RPC yazdırma uyumluluğu ve 0x0000011b bağlantı hataları için." ([ref]$chkFixRpc)
Add-SimpleFixCheck "Point&Print / 709" "Client" "Client tarafında driver yükleme izni, 709 ve package policy sorunları için." ([ref]$chkFixPoint)
Add-SimpleFixCheck "SMB / Paylaşım" "Host" "Yazıcı paylaşımı ve SMB erişim uyumluluğunu düzenler." ([ref]$chkFixSmb)
Add-SimpleFixCheck "Firewall / Discovery" "Host + Client" "Ağ keşfi, dosya/yazıcı paylaşımı ve ilgili firewall kurallarını açar." ([ref]$chkFixFirewall)
Add-SimpleFixCheck "Servisler" "Host + Client" "Spooler, RPC, Workstation/Server ve keşif servislerini hazırlar." ([ref]$chkFixServices)
Add-SimpleFixCheck "Spooler Reset" "Client" "Bozuk kuyruk ve takılmış yazdırma işlerini temizleyip Spooler'ı yeniler." ([ref]$chkFixSpooler)
Add-SimpleFixCheck "NTLM / NetBIOS" "Client" "Workgroup ağlarında isim çözümleme ve NTLM uyumluluğu için." ([ref]$chkFixNtlm)
Add-SimpleFixCheck "Credential Temizliği" "Client" "Eski Windows kimlik bilgileri ve net use bağlantılarını temizler." ([ref]$chkFixCredential)
Add-SimpleFixCheck "Driver Temizliği" "Client" "Seçilen marka/modelin bozuk driver, port ve PnP izlerini temizler." ([ref]$chkFixDriver)
Add-SimpleFixCheck "Workgroup Win10/11" "Client + Host" "Domain olmayan ağlarda TrustedHosts, WinRM ve gelişmiş yazıcı policylerini ayarlar." ([ref]$chkFixWorkgroup)
# Driver page
$driver = $pages["driver"]
$lblDriverHint = New-InfoLabel (T "DriverHint") 4
Register-UiText $lblDriverHint "DriverHint"
$driver.Controls.Add($lblDriverHint)
$txtDriverFilter = New-Object System.Windows.Forms.ComboBox
$txtDriverFilter.DropDownStyle = "DropDown"
$txtDriverFilter.AutoCompleteMode = "SuggestAppend"
$txtDriverFilter.AutoCompleteSource = "ListItems"
$txtDriverFilter.Location = New-Object System.Drawing.Point(4,42)
$txtDriverFilter.Width = 320
$txtDriverFilter.Font = New-Object System.Drawing.Font("Segoe UI",10)
$driver.Controls.Add($txtDriverFilter)
Set-DriverFilterComboItems -Items @(Get-DefaultDriverFilterOptions)
$btnDriverDetectFilter = New-ActionButton "Otomatik Tespit" $C_Accent 150
$btnDriverDetectFilter.Location = New-Object System.Drawing.Point(340,39)
$driver.Controls.Add($btnDriverDetectFilter)
Register-UiText $btnDriverDetectFilter "AutoDetect"
$btnDriverClean = New-ActionButton "Seçili Driverı Kaldır" $C_Err 190
$btnDriverClean.Location = New-Object System.Drawing.Point(500,39)
$driver.Controls.Add($btnDriverClean)
Register-UiText $btnDriverClean "RemoveDriver"
$btnPrintServerProps = New-ActionButton "Print Server Özellikleri" $C_Panel2 190
$btnPrintServerProps.Location = New-Object System.Drawing.Point(700,39)
$driver.Controls.Add($btnPrintServerProps)
Register-UiText $btnPrintServerProps "PrintServerProps"
$btnPnPScan = New-ActionButton "PnP Yeniden Tara" $C_Panel2 150
$btnPnPScan.Location = New-Object System.Drawing.Point(4,84)
$driver.Controls.Add($btnPnPScan)
Register-UiText $btnPnPScan "PnpRescan"
$btnControlPrinters = New-ActionButton "Aygıtlar ve Yazıcılar" $C_Panel2 180
$btnControlPrinters.Location = New-Object System.Drawing.Point(164,84)
$driver.Controls.Add($btnControlPrinters)
Register-UiText $btnControlPrinters "DevicesPrinters"

# Installed Drivers Grid Setup
$script:GridDrivers = New-Object System.Windows.Forms.DataGridView
$script:GridDrivers.Location = New-Object System.Drawing.Point(4,130)
$script:GridDrivers.Size = New-Object System.Drawing.Size(950, 400)
$script:GridDrivers.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$script:GridDrivers.BackgroundColor = $C_Panel
$script:GridDrivers.BorderStyle = "None"
$script:GridDrivers.RowHeadersVisible = $false
$script:GridDrivers.AllowUserToAddRows = $false
$script:GridDrivers.AllowUserToDeleteRows = $false
$script:GridDrivers.ReadOnly = $true
$script:GridDrivers.SelectionMode = "FullRowSelect"
$script:GridDrivers.AutoSizeColumnsMode = "Fill"
$script:GridDrivers.ScrollBars = "Both"
$script:GridDrivers.EnableHeadersVisualStyles = $false
$script:GridDrivers.ColumnHeadersHeight = 34
$script:GridDrivers.RowTemplate.Height = 30
$script:GridDrivers.ColumnHeadersDefaultCellStyle.BackColor = $C_Panel2
$script:GridDrivers.ColumnHeadersDefaultCellStyle.ForeColor = $C_Fg
$script:GridDrivers.DefaultCellStyle.BackColor = $C_Panel
$script:GridDrivers.DefaultCellStyle.ForeColor = $C_Fg
$script:GridDrivers.DefaultCellStyle.SelectionBackColor = $C_Accent
[void]$script:GridDrivers.Columns.Add("DriverName","Sürücü Adı")
[void]$script:GridDrivers.Columns.Add("Environment","Mimari / Ortam")
[void]$script:GridDrivers.Columns.Add("Version","Tip / Sürüm")
[void]$script:GridDrivers.Columns.Add("Status","Durum (Kullanım)")
$script:GridDrivers.Columns["DriverName"].FillWeight = 50
$script:GridDrivers.Columns["Environment"].FillWeight = 20
$script:GridDrivers.Columns["Version"].FillWeight = 15
$script:GridDrivers.Columns["Status"].FillWeight = 15
$driver.Controls.Add($script:GridDrivers)
Register-ColumnText $script:GridDrivers "DriverName" "ColDriverName"
Register-ColumnText $script:GridDrivers "Environment" "ColEnvironment"
Register-ColumnText $script:GridDrivers "Version" "ColVersion"
Register-ColumnText $script:GridDrivers "Status" "ColStatus"

$script:GridDrivers.Add_SelectionChanged({
    if ($script:GridDrivers.SelectedRows.Count -gt 0) {
        $val = $script:GridDrivers.SelectedRows[0].Cells[0].Value
        if ($null -ne $val) {
            $txtDriverFilter.Text = $val
        }
    }
})
# Diagnosis
$diag = $pages["diag"]
$diagTop = New-Object System.Windows.Forms.FlowLayoutPanel
$diagTop.Dock = "Top"
$diagTop.Height = 48
$diagTop.BackColor = $C_Bg
$diag.Controls.Add($diagTop)
$txtDiagRemotePc = New-Object System.Windows.Forms.TextBox
$txtDiagRemotePc.Width = 170
$txtDiagRemotePc.Font = New-Object System.Drawing.Font("Segoe UI",10)
$diagTop.Controls.Add($txtDiagRemotePc)
$btnRunAllDiag = New-ActionButton "Tespit Yap" $C_Accent 120
$btnRunLocalDiag = New-ActionButton "Yerel" $C_Ok 90
$btnRunRemoteDiag = New-ActionButton "Uzak" $C_Warn 90
$btnClearDiag = New-ActionButton "Temizle" $C_Panel2 90
foreach ($b in @($btnRunAllDiag,$btnRunLocalDiag,$btnRunRemoteDiag,$btnClearDiag)) { $diagTop.Controls.Add($b) }
Register-UiText $btnRunAllDiag "Detect"
Register-UiText $btnRunLocalDiag "Local"
Register-UiText $btnRunRemoteDiag "Remote"
Register-UiText $btnClearDiag "Clear"
$script:GridDiag = New-Object System.Windows.Forms.DataGridView
$script:GridDiag.Dock = "Fill"
$script:GridDiag.BackgroundColor = $C_Panel
$script:GridDiag.BorderStyle = "None"
$script:GridDiag.RowHeadersVisible = $false
$script:GridDiag.AllowUserToAddRows = $false
$script:GridDiag.AllowUserToDeleteRows = $false
$script:GridDiag.ReadOnly = $true
$script:GridDiag.SelectionMode = "FullRowSelect"
$script:GridDiag.AutoSizeColumnsMode = "Fill"
$script:GridDiag.EnableHeadersVisualStyles = $false
$script:GridDiag.ColumnHeadersDefaultCellStyle.BackColor = $C_Panel2
$script:GridDiag.ColumnHeadersDefaultCellStyle.ForeColor = $C_Fg
$script:GridDiag.DefaultCellStyle.BackColor = $C_Panel
$script:GridDiag.DefaultCellStyle.ForeColor = $C_Fg
$script:GridDiag.DefaultCellStyle.SelectionBackColor = $C_Accent
[void]$script:GridDiag.Columns.Add("Kategori","Kategori")
[void]$script:GridDiag.Columns.Add("Ad","Ad")
[void]$script:GridDiag.Columns.Add("Durum","Durum")
[void]$script:GridDiag.Columns.Add("Detay","Detay")
[void]$script:GridDiag.Columns.Add("Oneri","Öneri")
$diag.Controls.Add($script:GridDiag)
Register-ColumnText $script:GridDiag "Kategori" "ColCategory"
Register-ColumnText $script:GridDiag "Ad" "ColName"
Register-ColumnText $script:GridDiag "Durum" "ColState"
Register-ColumnText $script:GridDiag "Detay" "ColDetail"
Register-ColumnText $script:GridDiag "Oneri" "ColSuggestion"

# Logs
$logs = $pages["logs"]
$logTop = New-Object System.Windows.Forms.FlowLayoutPanel
$logTop.Dock = "Top"
$logTop.Height = 44
$logTop.BackColor = $C_Bg
$logs.Controls.Add($logTop)
$btnOpenLog = New-ActionButton "Log Klasörü" $C_Panel2 120
$btnHtml = New-ActionButton "HTML Rapor" $C_Accent 120
$btnClearLog = New-ActionButton "Temizle" $C_Panel2 90
foreach ($b in @($btnOpenLog,$btnHtml,$btnClearLog)) { $logTop.Controls.Add($b) }
Register-UiText $btnOpenLog "LogFolder"
Register-UiText $btnHtml "HtmlReport"
Register-UiText $btnClearLog "Clear"
$script:TxtLog = New-Object System.Windows.Forms.RichTextBox
$script:TxtLog.Dock = "Fill"
$script:TxtLog.BackColor = [System.Drawing.Color]::FromArgb(13,16,21)
$script:TxtLog.ForeColor = $C_Fg
$script:TxtLog.BorderStyle = "None"
$script:TxtLog.ReadOnly = $true
$script:TxtLog.Font = New-Object System.Drawing.Font("Consolas",9.5)
$logs.Controls.Add($script:TxtLog)

# ============================================================
# INVOKE-EXTERNALTOOL: Embedded araçları geçici klasöre yazar ve çalıştırır
# ============================================================
function Invoke-ExternalTool {
    param([string]$RelativePath)
    try {
        $toolName = [System.IO.Path]::GetFileName($RelativePath)
        $ext = [System.IO.Path]::GetExtension($toolName).ToLower()

        # Hedef dizin: PSScriptRoot içinde ara, sonra geçici klasör
        $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path) }
        if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = $env:TEMP }

        $directPath = Join-Path $scriptDir $toolName
        $tempDir = Join-Path $env:TEMP "UPT_Tools"
        if (!(Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }
        $tempPath = Join-Path $tempDir $toolName

        $targetPath = ""

        # Önce scriptle aynı klasörde ara
        if (Test-Path $directPath) {
            $targetPath = $directPath
            OK "Araç bulundu (yerel klasör): $targetPath"
        } elseif ($script:EmbeddedTools -and $script:EmbeddedTools.ContainsKey($toolName)) {
            # Embedded base64'ten çıkar
            $b64 = $script:EmbeddedTools[$toolName]
            $bytes = [Convert]::FromBase64String($b64)
            [System.IO.File]::WriteAllBytes($tempPath, $bytes)
            $targetPath = $tempPath
            OK "Araç embedded kaynaktan çıkarıldı: $targetPath"
        } else {
            Show-Warn "Araç Bulunamadı" "'$toolName' aracı ne toolkit klasöründe ne de gömülü kaynakta bulunamadı.`r`n`r`nTool beklenen konum: $directPath"
            return
        }

        if ($ext -eq ".cmd" -or $ext -eq ".bat") {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$targetPath`"" -Verb RunAs -WindowStyle Normal
        } elseif ($ext -eq ".ps1") {
            $psHost = Get-PreferredPowerShellHost
            Start-Process -FilePath $psHost -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$targetPath`"" -Verb RunAs -WindowStyle Normal
        } else {
            Start-Process -FilePath $targetPath -Verb RunAs
        }
        OK "Araç başlatıldı: $toolName"
    } catch {
        ERR "Araç başlatılamadı: $RelativePath - $_"
        Show-Err "Araç Hatası" "'$RelativePath' başlatılamadı.`r`n`r`n$($_.Exception.Message)"
    }
}

function Open-ToolkitFolder {
    try {
        $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path) }
        if ([string]::IsNullOrWhiteSpace($scriptDir) -or !(Test-Path $scriptDir)) {
            $scriptDir = $env:TEMP
        }
        Start-Process explorer.exe $scriptDir
        OK "Toolkit klasörü açıldı: $scriptDir"
    } catch {
        WARN "Toolkit klasörü açılamadı: $_"
    }
}

# Tools sayfası - pages hash'inde "tools" yoksa oluştur
if (-not $pages.ContainsKey("tools")) {
    $pTools = New-Object System.Windows.Forms.Panel
    $pTools.Dock = "Fill"
    $pTools.BackColor = $C_Bg
    $pTools.Visible = $false
    $content.Controls.Add($pTools)
    $pages["tools"] = $pTools
}
$tools = $pages["tools"]
$lblToolsHint = New-InfoLabel (T "ToolsHint") 4
Register-UiText $lblToolsHint "ToolsHint"
$tools.Controls.Add($lblToolsHint)
$toolFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$toolFlow.Location = New-Object System.Drawing.Point(0,42)
$toolFlow.Size = New-Object System.Drawing.Size(940,520)
$toolFlow.Anchor = "Top,Left,Right,Bottom"
$toolFlow.WrapContents = $true
$toolFlow.AutoScroll = $true
$toolFlow.BackColor = $C_Bg
$tools.Controls.Add($toolFlow)

function New-ToolLaunchButton {
    param([string]$Text,[string]$RelativePath,[object]$Back=$null)
    $b = New-ActionButton $Text $(if ($Back) { $Back } else { $C_Panel2 }) 270
    $b.Height = 42
    $b.TextAlign = "MiddleCenter"
    $localPath = $RelativePath
    $b.Add_Click({
        Invoke-ExternalTool -RelativePath $localPath
    }.GetNewClosure())
    $toolFlow.Controls.Add($b)
    return $b
}

$btnToolAdvanced = New-ToolLaunchButton (T "AdvancedConsole") "AdvancedToolkit.cmd" $C_Warn
$btnTool11b = New-ToolLaunchButton (T "Fix11bConsole") "Fix_11b.cmd" $C_Panel
$btnTool709 = New-ToolLaunchButton (T "Fix709Console") "Fix_709.cmd" $C_Panel
$btnToolGuest = New-ToolLaunchButton (T "GuestConsole") "GuestShare.cmd" $C_Err
$btnToolLegacy = New-ToolLaunchButton (T "LegacyV2") "Printer_Enterprise_FixTool_v2.ps1" $C_Accent
Register-UiText $btnToolAdvanced "AdvancedConsole"
Register-UiText $btnTool11b "Fix11bConsole"
Register-UiText $btnTool709 "Fix709Console"
Register-UiText $btnToolGuest "GuestConsole"
Register-UiText $btnToolLegacy "LegacyV2"
$btnOpenToolkitFolder = New-ActionButton "Toolkit Klasorunu Ac" $C_Ok 260
$btnOpenToolkitFolder.Height = 46
$btnOpenToolkitFolder.Add_Click({ Open-ToolkitFolder })
$toolFlow.Controls.Add($btnOpenToolkitFolder)
Register-UiText $btnOpenToolkitFolder "OpenToolkitFolder"

function Show-DriverCleanupPage {
    Show-Page "driver"
    Update-DriverFilterCandidates -Silent | Out-Null
    Update-DriversGrid -Silent
}
function Toggle-ThemeSafe {
    param([switch]$KeepMode,[switch]$Silent)
    if (-not $KeepMode) { $script:DarkMode = -not $script:DarkMode }
    
    $bg = if ($script:DarkMode) { $C_Bg } else { $L_Bg }
    $fg = if ($script:DarkMode) { $C_Fg } else { $L_Fg }
    $sideBg = if ($script:DarkMode) { $C_Side } else { $L_Side }
    $panelBg = if ($script:DarkMode) { $C_Panel } else { $L_Panel }
    $panel2Bg = if ($script:DarkMode) { $C_Panel2 } else { $L_Panel2 }
    $muted = if ($script:DarkMode) { $C_Muted } else { $L_Muted }
    
    $btnTheme.Text = if ($script:DarkMode) { T "ThemeDark" } else { T "ThemeLight" }
    
    # Recursive UI Update
    $UpdateControl = {
        param($ctrl)
        
        # Generic color application
        if ($ctrl.Tag -eq "Card") {
            $ctrl.BackColor = $panelBg
        } elseif ($ctrl -is [System.Windows.Forms.Form]) {
            $ctrl.BackColor = $bg
            $ctrl.ForeColor = $fg
        } elseif ($ctrl -is [System.Windows.Forms.Label]) {
            if ($ctrl.ForeColor -ne $C_Accent -and $ctrl.ForeColor -ne $C_Ok -and $ctrl.ForeColor -ne $C_Warn -and $ctrl.ForeColor -ne $C_Err -and $ctrl.ForeColor -ne [System.Drawing.Color]::White) {
                $ctrl.ForeColor = if ($ctrl.ForeColor -eq $C_Muted -or $ctrl.ForeColor -eq $L_Muted) { $muted } else { $fg }
            }
        } elseif ($ctrl -is [System.Windows.Forms.Button]) {
            if ($ctrl.Tag -eq "MenuButton") {
                $ctrl.BackColor = $sideBg
                $ctrl.ForeColor = $muted
            } elseif ($ctrl.Tag -eq "MenuButtonActive") {
                # Keep active menu button background (usually $C_Accent or $C_Ok)
                $ctrl.ForeColor = [System.Drawing.Color]::White
            } elseif ($ctrl.BackColor -eq $C_Panel2 -or $ctrl.BackColor -eq $L_Panel2) {
                $ctrl.BackColor = $panel2Bg
                $ctrl.ForeColor = $fg
            }
        } elseif ($ctrl -is [System.Windows.Forms.TextBox]) {
            $ctrl.BackColor = if ($script:DarkMode) { [System.Drawing.Color]::FromArgb(45,55,72) } else { [System.Drawing.Color]::White }
            $ctrl.ForeColor = $fg
        } elseif ($ctrl -is [System.Windows.Forms.ComboBox]) {
            $ctrl.BackColor = if ($script:DarkMode) { [System.Drawing.Color]::FromArgb(45,55,72) } else { [System.Drawing.Color]::White }
            $ctrl.ForeColor = $fg
        } elseif ($ctrl -is [System.Windows.Forms.RichTextBox]) {
            $ctrl.BackColor = if ($script:DarkMode) { [System.Drawing.Color]::FromArgb(13,16,21) } else { [System.Drawing.Color]::White }
            $ctrl.ForeColor = $fg
        } elseif ($ctrl -is [System.Windows.Forms.DataGridView]) {
            $ctrl.BackgroundColor = $panelBg
            $ctrl.DefaultCellStyle.BackColor = $panelBg
            $ctrl.DefaultCellStyle.ForeColor = $fg
            $ctrl.ColumnHeadersDefaultCellStyle.BackColor = $panel2Bg
            $ctrl.ColumnHeadersDefaultCellStyle.ForeColor = $fg
            $ctrl.GridColor = $panel2Bg
        } elseif ($ctrl -is [System.Windows.Forms.CheckBox]) {
            $ctrl.ForeColor = $fg
            if ($ctrl.BackColor -eq $C_Panel -or $ctrl.BackColor -eq $L_Panel) { $ctrl.BackColor = $panelBg }
            elseif ($ctrl.BackColor -eq $C_Bg -or $ctrl.BackColor -eq $L_Bg) { $ctrl.BackColor = $bg }
        } elseif ($ctrl -is [System.Windows.Forms.Panel] -or $ctrl -is [System.Windows.Forms.TableLayoutPanel] -or $ctrl -is [System.Windows.Forms.FlowLayoutPanel]) {
            if ($ctrl -eq $side) { $ctrl.BackColor = $sideBg }
            elseif ($ctrl -eq $header -or $ctrl -eq $status) { $ctrl.BackColor = $panelBg }
            elseif ($ctrl.BackColor -eq $C_Bg -or $ctrl.BackColor -eq $L_Bg) { $ctrl.BackColor = $bg }
            elseif ($ctrl.BackColor -eq $C_Panel -or $ctrl.BackColor -eq $L_Panel) { $ctrl.BackColor = $panelBg }
        }

        foreach ($child in $ctrl.Controls) { &$UpdateControl $child }
    }
    
    &$UpdateControl $form
}
function Toggle-LanguageSafe {
    $script:LangMode = if ($script:LangMode -eq "TR") { "EN" } else { "TR" }
    Refresh-Language
    OK "Language / Dil: $script:LangMode"
}
function Update-HeaderActionLayout {
    if ($header -and $btnTheme) { $btnTheme.Left = [Math]::Max(12, $header.Width - 96) }
    if ($header -and $btnLang) { $btnLang.Left = [Math]::Max(12, $header.Width - 164) }
}

function Apply-ResponsiveLayout {
    try {
        $compact = ($form.ClientSize.Width -lt 920)
        $menuWidth = if ($compact) { 70 } else { 240 }
        $root.ColumnStyles[0].Width = $menuWidth
        $brand.Text = if ($compact) { T "BrandCompact" } else { T "Brand" }
        $brand.Font = New-Object System.Drawing.Font("Segoe UI", $(if ($compact) { 15 } else { 17 }), [System.Drawing.FontStyle]::Bold)
        $brandSub.Visible = -not $compact
        $brand.Left = if ($compact) { 14 } else { 18 }

        $menuButtons = @($btnDashboard,$btnFinder,$btnFixes,$btnDriver,$btnDiag,$btnLogs,$btnTools,$btnWorkflow,$btnBackup)
        foreach ($b in $menuButtons) {
            if (-not $b) { continue }
            $b.Left = if ($compact) { 9 } else { 14 }
            $b.Width = if ($compact) { 52 } else { 212 }
            if ($compact) {
                $icon = $b.AccessibleName
                if ([string]::IsNullOrWhiteSpace($icon)) { $icon = ">" }
                $b.Text = "  $icon"
                $b.TextAlign = "MiddleCenter"
            } else {
                $b.Text = $b.AccessibleDescription
                $b.TextAlign = "MiddleLeft"
            }
        }

        $content.Padding = if ($compact) { New-Object System.Windows.Forms.Padding(8) } else { New-Object System.Windows.Forms.Padding(16) }
        $pageTitle.Font = New-Object System.Drawing.Font("Segoe UI", $(if ($compact) { 14 } else { 18 }), [System.Drawing.FontStyle]::Bold)
        Update-HeaderActionLayout

        $contentWidth = [Math]::Max(360, $content.ClientSize.Width - $content.Padding.Left - $content.Padding.Right)
        if ($dashButtons) {
            $dashButtons.Width = [Math]::Max(320, $dash.ClientSize.Width - 8)
            $dashButtons.Height = if ($compact) { 150 } elseif ($dashButtons.Width -lt 780) { 104 } else { 58 }
        }
        if ($finderLayout -and $finderLayout.RowStyles.Count -gt 0) {
            $finderLayout.RowStyles[0].Height = if ($compact) { 214 } elseif ($form.ClientSize.Width -lt 1120) { 186 } else { 156 }
        }
        if ($fixList) {
            $fixList.Width = [Math]::Max(330, $fixes.ClientSize.Width - 12)
            $fixList.Height = [Math]::Max(220, $fixes.ClientSize.Height - 168)
            foreach ($card in $fixList.Controls) {
                if ($card.Tag -eq "Card") {
                    $card.Width = [Math]::Max(310, [Math]::Min(430, $fixList.ClientSize.Width - 28))
                    foreach ($child in $card.Controls) {
                        if ($child -is [System.Windows.Forms.CheckBox]) { $child.Width = [Math]::Max(160, $card.Width - 160) }
                        elseif ($child -is [System.Windows.Forms.Label] -and $child.Text -match "Client|Host|Both") { $child.Left = [Math]::Max(180, $card.Width - 140) }
                        elseif ($child -is [System.Windows.Forms.Label]) { $child.Width = [Math]::Max(260, $card.Width - 24) }
                    }
                }
            }
        }
        if ($toolFlow) {
            $toolFlow.Width = [Math]::Max(330, $tools.ClientSize.Width - 12)
            $toolFlow.Height = [Math]::Max(260, $tools.ClientSize.Height - 52)
        }
        if ($txtDriverFilter) { $txtDriverFilter.Width = [Math]::Min(420, [Math]::Max(220, $driver.ClientSize.Width - 40)) }
        if ($script:GridDrivers) { $script:GridDrivers.AutoSizeColumnsMode = if ($compact) { "DisplayedCells" } else { "Fill" } }
        if ($script:GridDiag) { $script:GridDiag.AutoSizeColumnsMode = if ($compact) { "DisplayedCells" } else { "Fill" } }
    } catch {
        WARN "Responsive layout uygulanamadı: $_"
    }
}

# Events
$btnDashboard.Add_Click({ Show-Page "dashboard" })
$btnFinder.Add_Click({ Show-FinderLocalPage })
$btnFixes.Add_Click({ Show-Page "fixes" })
$btnDriver.Add_Click({ Show-DriverCleanupPage })
$btnDiag.Add_Click({ Show-Page "diag" })
$btnLogs.Add_Click({ Show-Page "logs" })
# Araçlar butonu: base64 GUI bloğunda tanımlı değilse oluştur
if (-not $btnTools) {
    try {
        $btnTools = New-MenuButton "Araclar" 496 $script:Icons.Tools
        $btnTools.AccessibleName = $script:Icons.Tools
        $btnTools.AccessibleDescription = "Araclar"
        if ($side) { $side.Controls.Add($btnTools) }
    } catch {
        $btnTools = New-Object System.Windows.Forms.Button
        $btnTools.Text = "Araclar"
        $btnTools.Size = New-Object System.Drawing.Size(212,40)
        $btnTools.Location = New-Object System.Drawing.Point(14,496)
        $btnTools.BackColor = $C_Side
        $btnTools.ForeColor = $C_Muted
        $btnTools.FlatStyle = "Flat"
        if ($side) { $side.Controls.Add($btnTools) }
    }
}
if ($btnTools) { $btnTools.Add_Click({ Show-Page "tools" }) }
$btnWorkflow.Add_Click({ Show-Page "logs"; Run-EnterpriseWorkflow })
$btnBackup.Add_Click({ Show-Page "logs"; New-BackupSnapshot -Reason "Manual" | Out-Null })
$btnTheme.Add_Click({ Toggle-ThemeSafe })
$btnLang.Add_Click({ Toggle-LanguageSafe })
$btnDashDiag.Add_Click({ Show-Page "diag"; Run-AllDiagnosis })
$btnDashRecommend.Add_Click({ Show-Page "fixes"; Apply-RecommendedFixSelection; Update-FixSummaryText })
$btnDashQuickFix.Add_Click({ Show-Page "logs"; Apply-CommonPrinterFixBundle })
$btnDashFind.Add_Click({ Show-FinderLocalPage })
$btnDashWorkflow.Add_Click({ Show-Page "logs"; Run-EnterpriseWorkflow })
$btnDashSecure.Add_Click({ Show-Page "logs"; Restore-SecurePrinterDefaults })
if ($btnDashTools) { $btnDashTools.Add_Click({ Show-Page "tools" }) }
$btnScan.Add_Click({ Scan-LocalPrintersOnly })
$btnRemoteScan.Add_Click({ Scan-RemotePrinters })
$btnConnect.Add_Click({ Connect-SelectedPrinter })
$btnManualConnect.Add_Click({ Connect-ManualPrinter })
$btnRemoveSelectedPrinter.Add_Click({ Remove-SelectedPrinterItem })
$btnSetDefault.Add_Click({ Set-SelectedPrinterDefault })
$btnTestPage.Add_Click({ Print-SelectedPrinterTestPage })
$btnQueue.Add_Click({ Open-SelectedPrinterQueue })
$btnProperties.Add_Click({ Open-SelectedPrinterProperties })
$btnSharePrinter.Add_Click({ Share-SelectedLocalPrinter })
$gridPrinters.Add_CellDoubleClick({ Connect-SelectedPrinter })
$btnRecommend.Add_Click({ Apply-RecommendedFixSelection; Update-FixSummaryText })
$btnRunFixes.Add_Click({ Run-AutoFix })
$btnCommonFix.Add_Click({ Show-Page "logs"; Apply-CommonPrinterFixBundle })
$btnSecureDefaults.Add_Click({ Show-Page "logs"; Restore-SecurePrinterDefaults })
$btnLpdLpr.Add_Click({ Show-Page "logs"; Enable-LpdLprFeatures })
$btnSmb1.Add_Click({ Show-Page "logs"; Enable-Smb1ClientFeature })
$btnDriverDetectFilter.Add_Click({ Update-DriverFilterCandidates | Out-Null; Update-DriversGrid })
$btnDriverClean.Add_Click({ Apply-DriverCacheCleanup })
$btnPrintServerProps.Add_Click({ Open-PrintServerProperties })
$btnPnPScan.Add_Click({ Invoke-UptProcess -FilePath "$env:SystemRoot\System32\pnputil.exe" -Arguments "/scan-devices" -Wait | Out-Null })
$btnControlPrinters.Add_Click({ Open-ControlPrinters })
$btnRunAllDiag.Add_Click({ if (-not [string]::IsNullOrWhiteSpace($txtDiagRemotePc.Text.Trim())) { $txtRemotePc.Text = $txtDiagRemotePc.Text.Trim() }; Run-AllDiagnosis })
$btnRunLocalDiag.Add_Click({ Run-LocalDiagnosis })
$btnRunRemoteDiag.Add_Click({ if (-not [string]::IsNullOrWhiteSpace($txtDiagRemotePc.Text.Trim())) { $txtRemotePc.Text = $txtDiagRemotePc.Text.Trim() }; Run-RemoteDiagnosis })
$btnClearDiag.Add_Click({ Clear-Diag })
$btnOpenLog.Add_Click({ Start-Process explorer.exe $script:LogDir })
$btnHtml.Add_Click({ Export-Report })
$btnClearLog.Add_Click({ $script:TxtLog.Clear() })
$txtRemotePc.Add_TextChanged({ try { if ($txtDiagRemotePc.Text -ne $txtRemotePc.Text) { $txtDiagRemotePc.Text = $txtRemotePc.Text } } catch {} })
$txtDiagRemotePc.Add_TextChanged({ try { if ($txtRemotePc.Text -ne $txtDiagRemotePc.Text) { $txtRemotePc.Text = $txtDiagRemotePc.Text } } catch {} })
$form.Add_SizeChanged({ Apply-ResponsiveLayout })

Write-Log "$($script:AppCode) başlatıldı."
Write-Log "Log dosyası: $script:LogFile"
Ensure-AppCodeSigningTrust
Detect-Role | Out-Null
Show-Page "dashboard"
Refresh-Language
Apply-ResponsiveLayout
[void]$form.ShowDialog()
