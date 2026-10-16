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

function Invoke-ExternalTool {
    param([string]$RelativePath)
    $path = Join-Path $PSScriptRoot $RelativePath
    if (-not (Test-Path $path)) {
        Show-Warn "Araç Bulunamadı" "Dosya bulunamadı:`r`n$path"
        WARN "Harici araç bulunamadı: $path"
        return
    }
    $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
    switch ($ext) {
        ".ps1" {
            $psHost = Get-PreferredPowerShellHost
            Invoke-UptProcess -FilePath $psHost -Arguments "-NoProfile -ExecutionPolicy Bypass -File `"$path`"" | Out-Null
        }
        ".bat" { Invoke-UptProcess -FilePath "cmd.exe" -Arguments "/c `"$path`"" | Out-Null }
        ".cmd" { Invoke-UptProcess -FilePath "cmd.exe" -Arguments "/c `"$path`"" | Out-Null }
        default { Invoke-UptProcess -FilePath $path | Out-Null }
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
$brand.Text = "PRN FixTool"
$brand.ForeColor = $C_Fg
$brand.Font = New-Object System.Drawing.Font("Segoe UI",17,[System.Drawing.FontStyle]::Bold)
$brand.Location = New-Object System.Drawing.Point(18,22)
$brand.AutoSize = $true
$side.Controls.Add($brand)

$brandSub = New-Object System.Windows.Forms.Label
$brandSub.Text = "Yazıcı bağlantı ve onarım"
$brandSub.ForeColor = $C_Muted
$brandSub.Font = New-Object System.Drawing.Font("Segoe UI",9)
$brandSub.Location = New-Object System.Drawing.Point(20,56)
$brandSub.AutoSize = $true
$side.Controls.Add($brandSub)

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
$pageTitle.Text = "Ana Panel"
$pageTitle.ForeColor = $C_Fg
$pageTitle.Font = New-Object System.Drawing.Font("Segoe UI",18,[System.Drawing.FontStyle]::Bold)
$pageTitle.Location = New-Object System.Drawing.Point(20,18)
$pageTitle.AutoSize = $true
$header.Controls.Add($pageTitle)

$btnTheme = New-Object System.Windows.Forms.Button
$btnTheme.Text = "Tema"
$btnTheme.Size = New-Object System.Drawing.Size(76,34)
$btnTheme.Anchor = "Top,Right"
$btnTheme.Location = New-Object System.Drawing.Point(780,19)
$btnTheme.BackColor = $C_Panel2
$btnTheme.ForeColor = $C_Fg
$btnTheme.FlatStyle = "Flat"
$header.Controls.Add($btnTheme)
$header.Add_SizeChanged({ $btnTheme.Left = $header.Width - 96 })

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
$script:LblStatus.Text = "Hazır"
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
        "dashboard" { $pageTitle.Text = "Ana Panel"; $btnDashboard }
        "finder" { $pageTitle.Text = "Yazıcı Bağla"; $btnFinder }
        "fixes" { $pageTitle.Text = "Onarım"; $btnFixes }
        "driver" { $pageTitle.Text = "Sürücü Temizliği"; $btnDriver }
        "diag" { $pageTitle.Text = "Tespit"; $btnDiag }
        "logs" { $pageTitle.Text = "Kayıtlar"; $btnLogs }
        "tools" { $pageTitle.Text = "Araçlar"; $btnTools }
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
function New-ActionButton {
    param([string]$Text,[object]$Back,[int]$Width=130)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Width = $Width
    $b.Height = 34
    $b.Margin = New-Object System.Windows.Forms.Padding(4)
    $b.BackColor = $Back
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatStyle = "Flat"
    $b.Font = New-Object System.Drawing.Font("Segoe UI Emoji",9,[System.Drawing.FontStyle]::Bold)
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
$dash.Controls.Add((New-InfoLabel "En sık kullanılan akış: önce tespit, sonra önerilen onarım, sonra yazıcı bağlantısı." 8))
$script:LblRoleValue = New-Object System.Windows.Forms.Label
$script:LblRoleValue.Text = "Rol: Belirsiz"
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
$lblRemote.Text = "Uzak PC/IP"
$lblRemote.Width = 75
$lblRemote.Height = 28
$lblRemote.ForeColor = $C_Fg
$lblRemote.TextAlign = "MiddleLeft"
$finderTop.Controls.Add($lblRemote)
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
$chkAutoFixBeforeScan = New-Object System.Windows.Forms.CheckBox
$chkAutoFixBeforeScan.Text = "Tarama öncesi hazırlık yap"
$chkAutoFixBeforeScan.Width = 190
$chkAutoFixBeforeScan.Height = 28
$chkAutoFixBeforeScan.ForeColor = $C_Muted
$chkAutoFixBeforeScan.BackColor = $C_Bg
$finderTop.Controls.Add($chkAutoFixBeforeScan)
$chkAutoFixBeforeConnect = New-Object System.Windows.Forms.CheckBox
$chkAutoFixBeforeConnect.Text = "Bağlamadan önce onar"
$chkAutoFixBeforeConnect.Width = 170
$chkAutoFixBeforeConnect.Height = 28
$chkAutoFixBeforeConnect.ForeColor = $C_Muted
$chkAutoFixBeforeConnect.BackColor = $C_Bg
$finderTop.Controls.Add($chkAutoFixBeforeConnect)
$chkRemoveOld = New-Object System.Windows.Forms.CheckBox
$chkRemoveOld.Text = "Eski bağlantıyı temizle"
$chkRemoveOld.Width = 170
$chkRemoveOld.Height = 28
$chkRemoveOld.ForeColor = $C_Muted
$chkRemoveOld.BackColor = $C_Bg
$finderTop.Controls.Add($chkRemoveOld)
$txtManualUNC = New-Object System.Windows.Forms.TextBox
$txtManualUNC.Width = 250
$txtManualUNC.Text = "\\PCADI\PAYLASIM"
$finderTop.Controls.Add($txtManualUNC)
$btnManualConnect = New-ActionButton "UNC Bağla" $C_Panel2 110
$finderTop.Controls.Add($btnManualConnect)

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

# Fixes
$fixes = $pages["fixes"]
$fixes.Controls.Add((New-InfoLabel "Sorunu biliyorsanız yalnızca ilgili onarımları seçin. Emin değilseniz Önerilenleri Seç kullanın." 4))
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
$btnRunFixes = New-ActionButton "Seçili Onarımları Uygula" $C_Accent 210
$btnRunFixes.Location = New-Object System.Drawing.Point(320,34)
$fixes.Controls.Add($btnRunFixes)
$btnCommonFix = New-ActionButton "Hızlı Genel Onarım" $C_Ok 180
$btnCommonFix.Location = New-Object System.Drawing.Point(540,34)
$fixes.Controls.Add($btnCommonFix)
$btnSecureDefaults = New-ActionButton "Güvenli Varsayılanlar" $C_Err 190
$btnSecureDefaults.Location = New-Object System.Drawing.Point(730,34)
$fixes.Controls.Add($btnSecureDefaults)
$btnLpdLpr = New-ActionButton "LPD/LPR Aç" $C_Panel2 120
$btnLpdLpr.Location = New-Object System.Drawing.Point(4,72)
$fixes.Controls.Add($btnLpdLpr)
$btnSmb1 = New-ActionButton "SMB1 Client (Riskli)" $C_Err 170
$btnSmb1.Location = New-Object System.Drawing.Point(134,72)
$fixes.Controls.Add($btnSmb1)
$chkSmbSigning = New-Object System.Windows.Forms.CheckBox
$chkSmbSigning.Text = "SMB signing gevşet"
$chkSmbSigning.Location = New-Object System.Drawing.Point(314,78)
$chkSmbSigning.Size = New-Object System.Drawing.Size(160,24)
$chkSmbSigning.ForeColor = $C_Muted
$chkSmbSigning.BackColor = $C_Bg
$fixes.Controls.Add($chkSmbSigning)
$chkGuest = New-Object System.Windows.Forms.CheckBox
$chkGuest.Text = "Guest erişimi aç (riskli)"
$chkGuest.Location = New-Object System.Drawing.Point(484,78)
$chkGuest.Size = New-Object System.Drawing.Size(190,24)
$chkGuest.ForeColor = $C_Muted
$chkGuest.BackColor = $C_Bg
$fixes.Controls.Add($chkGuest)
$lblFixSection = New-Object System.Windows.Forms.Label
$lblFixSection.Text = "Önerilen / seçilebilir düzeltmeler"
$lblFixSection.ForeColor = $C_Fg
$lblFixSection.Font = New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)
$lblFixSection.Location = New-Object System.Drawing.Point(4,116)
$lblFixSection.Size = New-Object System.Drawing.Size(360,28)
$fixes.Controls.Add($lblFixSection)

$lblFixSummary = New-Object System.Windows.Forms.Label
$lblFixSummary.Text = "Henüz seçim yapılmadı. Önerilenleri Seç butonuna basabilirsiniz."
$lblFixSummary.ForeColor = $C_Muted
$lblFixSummary.Font = New-Object System.Drawing.Font("Segoe UI",9)
$lblFixSummary.Location = New-Object System.Drawing.Point(370,120)
$lblFixSummary.Size = New-Object System.Drawing.Size(520,24)
$fixes.Controls.Add($lblFixSummary)

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
$driver.Controls.Add((New-InfoLabel "Sistemdeki sürücüler listelenmiştir. Silmek istediğiniz sürücüyü seçip kaldırabilir veya geniş marka araması yapabilirsiniz." 4))
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
$btnDriverClean = New-ActionButton "Seçili Driverı Kaldır" $C_Err 190
$btnDriverClean.Location = New-Object System.Drawing.Point(500,39)
$driver.Controls.Add($btnDriverClean)
$btnPrintServerProps = New-ActionButton "Print Server Özellikleri" $C_Panel2 190
$btnPrintServerProps.Location = New-Object System.Drawing.Point(700,39)
$driver.Controls.Add($btnPrintServerProps)
$btnPnPScan = New-ActionButton "PnP Yeniden Tara" $C_Panel2 150
$btnPnPScan.Location = New-Object System.Drawing.Point(4,84)
$driver.Controls.Add($btnPnPScan)
$btnControlPrinters = New-ActionButton "Aygıtlar ve Yazıcılar" $C_Panel2 180
$btnControlPrinters.Location = New-Object System.Drawing.Point(164,84)
$driver.Controls.Add($btnControlPrinters)

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
$script:TxtLog = New-Object System.Windows.Forms.RichTextBox
$script:TxtLog.Dock = "Fill"
$script:TxtLog.BackColor = [System.Drawing.Color]::FromArgb(13,16,21)
$script:TxtLog.ForeColor = $C_Fg
$script:TxtLog.BorderStyle = "None"
$script:TxtLog.ReadOnly = $true
$script:TxtLog.Font = New-Object System.Drawing.Font("Consolas",9.5)
$logs.Controls.Add($script:TxtLog)

# Tools
$tools = $pages["tools"]
$tools.Controls.Add((New-InfoLabel "Klasördeki eski/yardımcı araçlara buradan ulaşabilirsiniz. Ultimate GUI içindeki onarımlar log ve yedek alır; eski CMD araçları kendi penceresinde çalışır." 4))
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
    $b = New-ActionButton $Text $(if ($Back) { $Back } else { $C_Panel2 }) 260
    $b.Height = 46
    $b.TextAlign = "MiddleCenter"
    $localPath = $RelativePath
    $b.Add_Click({ Invoke-ExternalTool -RelativePath $localPath }.GetNewClosure())
    $toolFlow.Controls.Add($b)
    return $b
}

New-ToolLaunchButton "Atom Driver Hub" "AtomDriver.ps1" $C_Accent | Out-Null
New-ToolLaunchButton "Eski Enterprise GUI V2" "Printer_Enterprise_FixTool_v2.ps1" $C_Panel2 | Out-Null
New-ToolLaunchButton "Advanced Printer Toolkit CMD" "Printer issues\ADVANCED PRINTER TOOLKIT  Ultimate Toolkit.cmd" $C_Warn | Out-Null
New-ToolLaunchButton "Ultimate Error Fix CMD" "Printer issues\ULTIMATE PRINTER ERROR FIX TOOLKIT.cmd" $C_Warn | Out-Null
New-ToolLaunchButton "0x0000011b CMD" "Printer issues\Fix Windows Cannot Connect to Printer Error 0x0000011b.cmd" $C_Panel2 | Out-Null
New-ToolLaunchButton "0x00000709 CMD" "Printer issues\Fix Printer Error 0x00000709.cmd" $C_Panel2 | Out-Null
New-ToolLaunchButton "Guest Share CMD" "Printer issues\GUEST SHARE ACCESS ERROR.cmd" $C_Err | Out-Null
New-ToolLaunchButton "Printer Sharing BAT" "Program\yazici.bat" $C_Panel2 | Out-Null
New-ToolLaunchButton "Ağ Sorun Giderici BAT" "Program\AgSorunGiderici.bat" $C_Panel2 | Out-Null
New-ToolLaunchButton "Yazıcı Yönetim Menüsü" "Program\YaziciPaylas_TR\YaziciYonetimMenusu.bat" $C_Panel2 | Out-Null
New-ToolLaunchButton "Universal Printer Sharing Fix" "Program\YaziciPaylas_TR\0000.bat" $C_Panel2 | Out-Null
New-ToolLaunchButton "Yazıcı Paylaşım Server PS1" "Program\YaziciPaylasim\Server_Setup_TR.ps1" $C_Panel2 | Out-Null
New-ToolLaunchButton "Yazıcı Paylaşım Client PS1" "Program\YaziciPaylasim\Client_Setup_TR.ps1" $C_Panel2 | Out-Null
New-ToolLaunchButton "Dosya Paylaşım Server PS1" "Program\DosyaPaylasim\Server_Setup_TR.ps1" $C_Panel2 | Out-Null
New-ToolLaunchButton "Dosya Paylaşım Client PS1" "Program\DosyaPaylasim\Client_Setup_TR.ps1" $C_Panel2 | Out-Null

$btnOpenToolkitFolder = New-ActionButton "Toolkit Klasörünü Aç" $C_Ok 260
$btnOpenToolkitFolder.Height = 46
$btnOpenToolkitFolder.Add_Click({ Open-ToolkitFolder })
$toolFlow.Controls.Add($btnOpenToolkitFolder)

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
    
    $btnTheme.Text = if ($script:DarkMode) { "Tema" } else { "Koyu" }
    
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
function Toggle-LanguageSafe { OK "Dil seçimi bu sade arayüzde Türkçe olarak sabit" }
function Update-HeaderActionLayout {
    if ($header -and $btnTheme) { $btnTheme.Left = [Math]::Max(12, $header.Width - 96) }
}

function Apply-ResponsiveLayout {
    try {
        $compact = ($form.ClientSize.Width -lt 920)
        $menuWidth = if ($compact) { 70 } else { 240 }
        $root.ColumnStyles[0].Width = $menuWidth
        $brand.Text = if ($compact) { "UPT" } else { "Ultimate" }
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
$btnTools.Add_Click({ Show-Page "tools" })
$btnWorkflow.Add_Click({ Show-Page "logs"; Run-EnterpriseWorkflow })
$btnBackup.Add_Click({ Show-Page "logs"; New-BackupSnapshot -Reason "Manual" | Out-Null })
$btnTheme.Add_Click({ Toggle-ThemeSafe })
$btnDashDiag.Add_Click({ Show-Page "diag"; Run-AllDiagnosis })
$btnDashRecommend.Add_Click({ Show-Page "fixes"; Apply-RecommendedFixSelection; $lblFixSummary.Text = "Seçili düzeltme sayısı: $(Get-SelectedFixCount)" })
$btnDashQuickFix.Add_Click({ Show-Page "logs"; Apply-CommonPrinterFixBundle })
$btnDashFind.Add_Click({ Show-FinderLocalPage })
$btnDashWorkflow.Add_Click({ Show-Page "logs"; Run-EnterpriseWorkflow })
$btnDashSecure.Add_Click({ Show-Page "logs"; Restore-SecurePrinterDefaults })
$btnDashTools.Add_Click({ Show-Page "tools" })
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
$btnRecommend.Add_Click({ Apply-RecommendedFixSelection; $lblFixSummary.Text = "Seçili düzeltme sayısı: $(Get-SelectedFixCount)" })
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
Apply-ResponsiveLayout
[void]$form.ShowDialog()
