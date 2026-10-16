#Requires -Version 5.1
#Requires -RunAsAdministrator
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$ErrorActionPreference = "Continue"

# ============================================================
# PRN ULTIMATE ENTERPRISE TOOL V1 FULL REPAIR
# Alias: PRN_UET_ENTERPRISE_V2_3_VISUAL_BACKUP
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

$script:AppCode = "PRN_UET_ENTERPRISE_V2_3_VISUAL_BACKUP"
$script:AppName = "PRN Kurumsal Yazıcı Ağ Paylaşım Onarım Merkezi"
$script:DetectedRole = "Belirsiz"
$script:LogDir = Join-Path $env:USERPROFILE "Desktop\PRN_UET_Logs"
if (!(Test-Path $script:LogDir)) { New-Item -Path $script:LogDir -ItemType Directory -Force | Out-Null }

$script:BackupRoot = Join-Path $PSScriptRoot "Backups"
if (!(Test-Path $script:BackupRoot)) { New-Item -Path $script:BackupRoot -ItemType Directory -Force | Out-Null }
$script:LastBackupPath = ""

$script:LogFile = Join-Path $script:LogDir ("PRN_UET_FULL_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

$script:FoundItems = New-Object System.Collections.Generic.List[object]
$script:DiagItems = New-Object System.Collections.Generic.List[object]
$script:ActionItems = New-Object System.Collections.Generic.List[object]

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
}

# ---------- LOG ----------
function Write-Log {
    param([string]$Message,[string]$Level="INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
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
    Clear-Diag
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

    foreach ($port in 445,135,139) {
        try {
            $r = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($r) { Add-Diag "Port" "127.0.0.1:$port" "OK" "Açık" "Sorun yok" }
            else { Add-Diag "Port" "127.0.0.1:$port" "Uyarı" "Kapalı/Erişilemez" "Firewall/Servis fix kontrol edilmeli" }
        } catch { Add-Diag "Port" "127.0.0.1:$port" "Uyarı" "$_" "Port testi başarısız" }
    }

    $rpcPrivacy = Get-DWordSafe "HKLM:\System\CurrentControlSet\Control\Print" "RpcAuthnLevelPrivacyEnabled"
    if ($rpcPrivacy -eq 0) { Add-Diag "Registry" "RpcAuthnLevelPrivacyEnabled" "OK" "0" "11b uyumluluğu uygulanmış" }
    else { Add-Diag "Registry" "RpcAuthnLevelPrivacyEnabled" "Uyarı" "$rpcPrivacy" "RPC/11b fix çalıştırılmalı" }

    $pnpRestrict = Get-DWordSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" "RestrictDriverInstallationToAdministrators"
    if ($pnpRestrict -eq 0) { Add-Diag "Registry" "RestrictDriverInstallationToAdministrators" "OK" "0" "Point&Print uyumluluğu uygulanmış" }
    else { Add-Diag "Registry" "RestrictDriverInstallationToAdministrators" "Uyarı" "$pnpRestrict" "Point&Print/709 fix çalıştırılmalı" }

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
    Show-Info "Tespit Tamamlandı" "Yerel arıza tespiti tamamlandı."
}
function Run-RemoteDiagnosis {
    $server = $txtRemotePc.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($server)) { Show-Warn "Eksik Bilgi" "Uzak PC adı/IP girin."; return }
    Clear-Diag
    Write-Log "=== UZAK PC ARIZA TESPİTİ BAŞLADI: $server ==="

    try {
        $dns = Resolve-DnsName $server -ErrorAction Stop | Select-Object -First 1
        Add-Diag "Uzak Ağ" "DNS/Ad Çözümleme" "OK" "$($dns.IPAddress)" "Sorun yok"
    } catch { Add-Diag "Uzak Ağ" "DNS/Ad Çözümleme" "Uyarı" "$_" "PC adı yerine IP deneyin" }

    try {
        if (Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue) { Add-Diag "Uzak Ağ" "Ping" "OK" "Başarılı" "Sorun yok" }
        else { Add-Diag "Uzak Ağ" "Ping" "Uyarı" "Başarısız" "Ping firewall kapalı olabilir; 445/135 daha önemlidir" }
    } catch { Add-Diag "Uzak Ağ" "Ping" "Uyarı" "$_" "Ping testi başarısız" }

    foreach ($port in 445,135,139) {
        try {
            $r = Test-NetConnection -ComputerName $server -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($r) { Add-Diag "Uzak Port" "${server}:$port" "OK" "Açık" "Sorun yok" }
            else { Add-Diag "Uzak Port" "${server}:$port" "Hata" "Kapalı/Erişilemiyor" "Host PC firewall/paylaşım/RPC servisleri kontrol edilmeli" }
        } catch { Add-Diag "Uzak Port" "${server}:$port" "Uyarı" "$_" "Port testi başarısız" }
    }

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
    if ($chkSmbSigning.Checked) {
        try {
            Set-SmbServerConfiguration -RequireSecuritySignature $false -Force | Out-Null
            Set-SmbClientConfiguration -RequireSecuritySignature $false -Confirm:$false | Out-Null
            OK "SMB imzalama zorunluluğu uyumluluk için opsiyonel yapıldı"
        } catch { WARN "SMB signing ayarı uygulanamadı: $_" }
    } else { WARN "SMB signing ayarı kullanıcı tercihiyle atlandı" }

    if ($chkGuest.Checked) {
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
function Apply-DriverCacheCleanup {
    Write-Log "Driver cache temizliği başlıyor..."
    $filter = $txtDriverFilter.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($filter)) {
        $answer = [System.Windows.Forms.MessageBox]::Show("Driver filtresi boş. Tüm üçüncü parti yazıcı driverlarını silmeye çalışmak riskli olabilir.`r`n`r`nDevam etmek istiyor musun?","Driver Temizliği", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { WARN "Driver temizliği iptal edildi"; return }
    }
    try { Stop-Service Spooler -Force -ErrorAction SilentlyContinue } catch {}
    Start-Sleep -Seconds 1

    try {
        $printers = Get-Printer -ErrorAction SilentlyContinue
        foreach ($p in $printers) {
            if (-not [string]::IsNullOrWhiteSpace($filter) -and ($p.DriverName -like "*$filter*" -or $p.Name -like "*$filter*")) {
                try { Remove-Printer -Name $p.Name -ErrorAction SilentlyContinue; OK "Yazıcı kaldırıldı: $($p.Name)" } catch { WARN "Yazıcı kaldırılamadı: $($p.Name) - $_" }
            }
        }
    } catch { WARN "Yazıcı kaldırma taraması başarısız: $_" }

    try {
        $drivers = Get-PrinterDriver -ErrorAction SilentlyContinue
        foreach ($d in $drivers) {
            if ([string]::IsNullOrWhiteSpace($filter) -or $d.Name -like "*$filter*") {
                try { Remove-PrinterDriver -Name $d.Name -ErrorAction SilentlyContinue; OK "Printer driver kaldırma denendi: $($d.Name)" } catch { WARN "Printer driver kaldırılamadı: $($d.Name) - $_" }
            }
        }
    } catch { WARN "Driver temizliği başarısız: $_" }

    try {
        $spoolPath = "$env:SystemRoot\System32\spool\PRINTERS"
        Get-ChildItem -Path $spoolPath -Include "*.spl","*.shd" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        OK "Spool kuyruk dosyaları temizlendi"
    } catch { WARN "Spool temizliği başarısız: $_" }

    try { Start-Service Spooler -ErrorAction SilentlyContinue } catch {}
    OK "Driver cache temizliği tamamlandı"
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
function Scan-CimPrinters {
    param([string]$Server)
    Write-Log "CIM/WMI yazıcı taraması: $Server"
    try {
        $printers = Get-CimInstance -ClassName Win32_Printer -ComputerName $Server -ErrorAction Stop
        foreach ($p in $printers) {
            if ($p.Shared -eq $true -and -not [string]::IsNullOrWhiteSpace($p.ShareName)) {
                Add-FoundItem "Printer" "$($p.Name)" "$($p.ShareName)" "\\$Server\$($p.ShareName)" "$($p.DriverName)" "CIM" "Shared=True"
            } else { Write-Log "CIM local/non-shared: $($p.Name) | Shared=$($p.Shared) | ShareName=$($p.ShareName)" }
        }
        OK "CIM yazıcı taraması tamamlandı"
    } catch { WARN "CIM/WMI taraması başarısız: $_" }
}
function Scan-NetViewShares {
    param([string]$Server)
    Write-Log "NET VIEW paylaşım taraması: \\$Server"
    try {
        $items = Get-NetViewItemsSafe -Server $Server
        foreach ($it in $items) {
            Add-FoundItem $it.Type $it.Share $it.Share $it.UNC "" "net view" $it.Note
        }
        OK "NET VIEW taraması tamamlandı. Bulunan: $($items.Count)"
    } catch { WARN "NET VIEW taraması başarısız: $_" }
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
    else { Show-Info "Tarama Tamamlandı" "$($script:FoundItems.Count) seçenek bulundu." }
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

    $ok = $false
    $method = ""
    $lastError = ""

    try {
        Add-Printer -ConnectionName $UNC -ErrorAction Stop
        Start-Sleep -Seconds 2
        if (Wait-PrinterConnection -UNC $UNC -Seconds 8) { OK "Add-Printer doğrulandı: $UNC"; $ok = $true; $method = "Add-Printer" }
        else { WARN "Add-Printer hata vermedi ancak bağlantı doğrulanamadı" }
    } catch { $lastError = $_.Exception.Message; WARN "Add-Printer başarısız: $lastError" }

    if (-not $ok) {
        try {
            Write-Log "PrintUI /in deneniyor..."
            $p = Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /in /n `"$UNC`"" -Wait -PassThru -WindowStyle Hidden
            Start-Sleep -Seconds 2
            if (Wait-PrinterConnection -UNC $UNC -Seconds 8) { OK "PrintUI /in doğrulandı: $UNC"; $ok = $true; $method = "PrintUI /in" }
            else { WARN "PrintUI /in çıkış kodu $($p.ExitCode), fakat doğrulanamadı" }
        } catch { $lastError = $_.Exception.Message; WARN "PrintUI /in başarısız: $lastError" }
    }
    if (-not $ok) {
        try {
            Write-Log "WScript.Network deneniyor..."
            $net = New-Object -ComObject WScript.Network
            $net.AddWindowsPrinterConnection($UNC)
            Start-Sleep -Seconds 2
            if (Wait-PrinterConnection -UNC $UNC -Seconds 8) { OK "WScript doğrulandı: $UNC"; $ok = $true; $method = "WScript.Network" }
            else { WARN "WScript hata vermedi ancak doğrulanamadı" }
        } catch { $lastError = $_.Exception.Message; WARN "WScript başarısız: $lastError" }
    }
    if (-not $ok) {
        try {
            Write-Log "PrintUI /ga per-machine deneniyor..."
            $p = Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /ga /n `"$UNC`"" -Wait -PassThru -WindowStyle Hidden
            Restart-Service Spooler -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
            if (Wait-PrinterConnection -UNC $UNC -Seconds 8) { OK "PrintUI /ga doğrulandı: $UNC"; $ok = $true; $method = "PrintUI /ga" }
            else { WARN "PrintUI /ga çıkış kodu $($p.ExitCode), fakat doğrulanamadı" }
        } catch { $lastError = $_.Exception.Message; WARN "PrintUI /ga başarısız: $lastError" }
    }

    if ($ok) { Show-Info "Bağlantı Başarılı" "Yazıcı doğrulanarak bağlandı:`r`n$UNC`r`nYöntem: $method" }
    else {
        ERR "Bağlantı doğrulanamadı: $UNC | Son hata: $lastError"
        Show-Err "Bağlantı Başarısız" "Yazıcı bağlanamadı veya doğrulanamadı.`r`nUNC: $UNC`r`nSon hata: $lastError`r`n`r`nC client üzerinde Driver Temizliği + Credential Temizliği + RPC + Point&Print seçip tekrar deneyin.`r`n`r`nLog: $script:LogFile"
    }
}
function Connect-SelectedPrinter {
    if ($gridPrinters.SelectedRows.Count -lt 1) { Show-Warn "Seçim Yok" "Listeden bir yazıcı/paylaşım seçin."; return }
    Connect-PrinterUNC $gridPrinters.SelectedRows[0].Cells[3].Value
}
function Connect-ManualPrinter {
    Connect-PrinterUNC $txtManualUNC.Text.Trim()
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
        "CREDENTIAL" { if ($chkFixCredential) { $chkFixCredential.Checked = $true
$chkFixWorkgroup.Checked = $true } }
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

    $msg = "Önerilen fixler seçildi:`r`n" + (($fixes | Sort-Object) -join "`r`n")
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
        Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $server -Concatenate -Force -ErrorAction Stop
        OK "TrustedHosts listesine eklendi: $server"
        Add-Action "TrustedHosts" "OK" "Client TrustedHosts += $server"
    } catch { WARN "TrustedHosts uygulanamadı: $_" }
}

function Apply-WinRMHostFix {
    Write-Log "WinRM/PSRemoting host uyumluluğu uygulanıyor..."
    try {
        Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
        Set-Service WinRM -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service WinRM -ErrorAction SilentlyContinue
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
        Show-Warn "Yeniden Başlatma Önerilir" "Workgroup/Policy düzeltmeleri uygulandı.`r`nBazı ayarlar için bilgisayarı yeniden başlatmak gerekebilir."
    }
    Write-Log "=== WORKGROUP / WIN10-WIN11 COMPATIBILITY FIX BİTTİ ===" "OK"
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
            if ($trim -match 'komut başarıyla tamamlandı|command completed successfully') { break }
            if ($capture) {
                if ($trim -match '^(.*?)\s+(Disk|Yazdır|Print)\s*(.*)$') {
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

# ---------- GUI ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = $script:AppName
$form.Size = New-Object System.Drawing.Size(1580,940)
$form.MinimumSize = New-Object System.Drawing.Size(1360,820)
$form.StartPosition = "CenterScreen"
$form.BackColor = $C_Bg
$form.ForeColor = $C_Fg
try { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$env:SystemRoot\system32\shell32.dll") } catch {}

$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = "Fill"
$root.ColumnCount = 2
$root.RowCount = 1
[void]$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,315)))
[void]$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,100)))
$form.Controls.Add($root)

$side = New-Object System.Windows.Forms.Panel
$side.Dock = "Fill"
$side.BackColor = $C_Side
$root.Controls.Add($side,0,0)

$main = New-Object System.Windows.Forms.TableLayoutPanel
$main.Dock = "Fill"
$main.ColumnCount = 1
$main.RowCount = 3
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,78)))
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,36)))
$root.Controls.Add($main,1,0)

$brand = New-Object System.Windows.Forms.Label
$brand.Text = "PRN Kurumsal`r`nYazıcı Onarım"
$brand.ForeColor = $C_Fg
$brand.Font = New-Object System.Drawing.Font("Segoe UI",13,[System.Drawing.FontStyle]::Bold)
$brand.Location = New-Object System.Drawing.Point(16,16)
$brand.AutoSize = $true
$side.Controls.Add($brand)

function New-SideButton {
    param([string]$Text,[int]$Top,[object]$Back=$null,[string]$Icon="")
    $b = New-Object System.Windows.Forms.Button
    $b.Text = "  " + $(if($Icon){$Icon + " "}) + $Text
    $b.Left = 14
    $b.Top = $Top
    $b.Width = 285
    $b.Height = 34
    $b.BackColor = $(if($Back){$Back}else{$C_Panel2})
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(80,92,110)
    $b.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $b.Font = New-Object System.Drawing.Font("Segoe UI Emoji",9,[System.Drawing.FontStyle]::Bold)
    return $b
}

$btnDashboard = New-SideButton "Dashboard" 92 -Icon $script:Icons.Dashboard
$btnFinder = New-SideButton "Yazıcı Bul / Bağla" 132 -Icon $script:Icons.Finder
$btnFixes = New-SideButton "Ultimate Fix" 172 -Icon $script:Icons.Fixes
$btnDiag = New-SideButton "Arıza Tespit" 212 -Icon $script:Icons.Diag
$btnDriver = New-SideButton "Driver Temizliği" 252 -Icon $script:Icons.Driver
$btnLogs = New-SideButton "Log / Rapor" 292 -Icon $script:Icons.Logs
$btnAutoFix = New-SideButton "Seçili Fixleri Uygula" 342 $C_Accent $script:Icons.AutoFix
$btnDetect = New-SideButton "Rol Algıla" 382 -Icon $script:Icons.Detect
$btnDiagLocal = New-SideButton "Yerel Tespit" 422 $C_Ok $script:Icons.Local
$btnDiagRemote = New-SideButton "Uzak PC Tespit" 462 $C_Warn $script:Icons.Remote
$btnWorkgroup = New-SideButton "Workgroup Uyumluluk" 512 $C_Accent $script:Icons.Workgroup
$btnBackup = New-SideButton "Yedek Oluştur" 522 $C_Ok $script:Icons.Backup
$btnRestore = New-SideButton "Yedekten Geri Yükle" 562 $C_Warn $script:Icons.Restore
$btnBackupFolder = New-SideButton "Yedek Klasörü" 602 -Icon $script:Icons.Folder
$btnRecommend = New-SideButton "Önerilen Fix Seç" 512 $C_Accent $script:Icons.Recommend
$btnAutoRemediate = New-SideButton "Auto Remediation" 552 $C_Ok $script:Icons.Rocket
$btnWorkflow = New-SideButton "Enterprise Workflow" 592 $C_Warn $script:Icons.Workflow

foreach($b in @($btnDashboard,$btnFinder,$btnFixes,$btnDiag,$btnDriver,$btnLogs,$btnAutoFix,$btnDetect,$btnDiagLocal,$btnDiagRemote,$btnRecommend,$btnAutoRemediate,$btnWorkflow)){
    $side.Controls.Add($b)
}

$sideInfo = New-Object System.Windows.Forms.Label
$sideInfo.Text = "Önce teşhis → seçili fix → driver/credential → bağlantı doğrulama."
$sideInfo.ForeColor = $C_Muted
$sideInfo.Location = New-Object System.Drawing.Point(18,650)
$sideInfo.Size = New-Object System.Drawing.Size(245,80)
$side.Controls.Add($sideInfo)

$header = New-Object System.Windows.Forms.Panel
$header.Dock = "Fill"
$header.BackColor = $C_Panel
$main.Controls.Add($header,0,0)

$title = New-Object System.Windows.Forms.Label
$title.Text = "$($script:Icons.Finder) PRN Kurumsal Yazıcı Ağ Paylaşım Onarım Merkezi"
$title.ForeColor = $C_Fg
$title.Font = New-Object System.Drawing.Font("Segoe UI Emoji",16,[System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(16,10)
$title.AutoSize = $true
$header.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = "Yazıcı ağ paylaşım hataları • Host/client tanılama • Otomatik onarım • Bağlantı doğrulama"
$sub.ForeColor = $C_Muted
$sub.Font = New-Object System.Drawing.Font("Segoe UI",9.5)
$sub.Location = New-Object System.Drawing.Point(18,43)
$sub.AutoSize = $true
$header.Controls.Add($sub)

$btnLang = New-Object System.Windows.Forms.Button
$btnLang.Text = "TR / EN"
$btnLang.Width = 88
$btnLang.Height = 30
$btnLang.Location = New-Object System.Drawing.Point(890,22)
$btnLang.BackColor = $C_Panel2
$btnLang.ForeColor = [System.Drawing.Color]::White
$btnLang.FlatStyle = "Flat"
$btnLang.Font = New-Object System.Drawing.Font("Segoe UI Emoji",9,[System.Drawing.FontStyle]::Bold)
$header.Controls.Add($btnLang)

$btnTheme = New-Object System.Windows.Forms.Button
$btnTheme.Text = "🌙 Koyu"
$btnTheme.Width = 92
$btnTheme.Height = 30
$btnTheme.Location = New-Object System.Drawing.Point(990,22)
$btnTheme.BackColor = $C_Accent
$btnTheme.ForeColor = [System.Drawing.Color]::White
$btnTheme.FlatStyle = "Flat"
$btnTheme.Font = New-Object System.Drawing.Font("Segoe UI Emoji",9,[System.Drawing.FontStyle]::Bold)
$header.Controls.Add($btnTheme)

function Update-HeaderActionLayout {
    if (-not $header -or $header.ClientSize.Width -le 0) { return }
    $btnTheme.Location = New-Object System.Drawing.Point(($header.ClientSize.Width - 110),22)
    $btnLang.Location = New-Object System.Drawing.Point(($header.ClientSize.Width - 206),22)
}
$header.Add_SizeChanged({ Update-HeaderActionLayout })

$script:LangMode = "TR"
$script:DarkMode = $true
function Toggle-LanguageSafe {
    if ($script:LangMode -eq "TR") {
        $script:LangMode = "EN"
        $btnDashboard.Text = "  $($script:Icons.Dashboard) Dashboard"
        $btnFinder.Text = "  $($script:Icons.Finder) Printer Find / Connect"
        $btnFixes.Text = "  $($script:Icons.Fixes) Advanced Fixes"
        $btnDiag.Text = "  $($script:Icons.Diag) Diagnostics"
        $btnDriver.Text = "  $($script:Icons.Driver) Driver Cleanup"
        $btnLogs.Text = "  $($script:Icons.Logs) Log / Report"
        $btnAutoFix.Text = "  $($script:Icons.AutoFix) Apply Selected Fixes"
        $btnDetect.Text = "  $($script:Icons.Detect) Detect Role"
        $btnDiagLocal.Text = "  $($script:Icons.Local) Local Diagnosis"
        $btnDiagRemote.Text = "  $($script:Icons.Remote) Remote Diagnosis"
        if ($btnWorkgroup) { $btnWorkgroup.Text = "  $($script:Icons.Workgroup) Workgroup Compatibility" }
        if ($btnBackup) { $btnBackup.Text = "  $($script:Icons.Backup) Create Backup" }
        if ($btnRestore) { $btnRestore.Text = "  $($script:Icons.Restore) Restore Backup" }
        if ($btnBackupFolder) { $btnBackupFolder.Text = "  $($script:Icons.Folder) Backup Folder" }
        $btnTheme.Text = $(if ($script:DarkMode) { "$($script:Icons.Moon) Dark" } else { "$($script:Icons.Sun) Light" })
    } else {
        $script:LangMode = "TR"
        $btnDashboard.Text = "  $($script:Icons.Dashboard) Ana Panel"
        $btnFinder.Text = "  $($script:Icons.Finder) Yazıcı Bul / Bağla"
        $btnFixes.Text = "  $($script:Icons.Fixes) Gelişmiş Düzeltmeler"
        $btnDiag.Text = "  $($script:Icons.Diag) Arıza Tespit"
        $btnDriver.Text = "  $($script:Icons.Driver) Sürücü Temizliği"
        $btnLogs.Text = "  $($script:Icons.Logs) Kayıt / Rapor"
        $btnAutoFix.Text = "  $($script:Icons.AutoFix) Seçili Düzeltmeleri Uygula"
        $btnDetect.Text = "  $($script:Icons.Detect) Rolü Algıla"
        $btnDiagLocal.Text = "  $($script:Icons.Local) Yerel Tespit"
        $btnDiagRemote.Text = "  $($script:Icons.Remote) Uzak PC Tespit"
        if ($btnWorkgroup) { $btnWorkgroup.Text = "  $($script:Icons.Workgroup) Workgroup Uyumluluk" }
        if ($btnBackup) { $btnBackup.Text = "  $($script:Icons.Backup) Yedek Oluştur" }
        if ($btnRestore) { $btnRestore.Text = "  $($script:Icons.Restore) Yedekten Geri Yükle" }
        if ($btnBackupFolder) { $btnBackupFolder.Text = "  $($script:Icons.Folder) Yedek Klasörü" }
        $btnTheme.Text = $(if ($script:DarkMode) { "$($script:Icons.Moon) Koyu" } else { "$($script:Icons.Sun) Açık" })
    }
    OK "Dil değiştirildi: $script:LangMode"
}
function Toggle-ThemeSafe {
    $script:DarkMode = -not $script:DarkMode
    
    $bg = if($script:DarkMode){[System.Drawing.Color]::FromArgb(15,23,32)}else{[System.Drawing.Color]::FromArgb(244,247,251)}
    $sideBg = if($script:DarkMode){[System.Drawing.Color]::FromArgb(20,29,40)}else{[System.Drawing.Color]::FromArgb(230,236,245)}
    $panelBg = if($script:DarkMode){[System.Drawing.Color]::FromArgb(27,38,51)}else{[System.Drawing.Color]::White}
    $panelBg2 = if($script:DarkMode){[System.Drawing.Color]::FromArgb(39,54,71)}else{[System.Drawing.Color]::FromArgb(210,220,235)}
    $fg = if($script:DarkMode){[System.Drawing.Color]::FromArgb(239,245,252)}else{[System.Drawing.Color]::FromArgb(20,28,38)}
    $muted = if($script:DarkMode){[System.Drawing.Color]::FromArgb(150,166,185)}else{[System.Drawing.Color]::FromArgb(76,86,100)}

    $form.BackColor = $bg
    $content.BackColor = $bg
    $side.BackColor = $sideBg
    $header.BackColor = $panelBg
    $status.BackColor = $panelBg
    $title.ForeColor = $fg
    $sub.ForeColor = $muted
    $script:LblStatus.ForeColor = $fg
    $sideInfo.ForeColor = $muted

    # Recursive helper
    $applyTheme = {
        param($control)
        if ($control -is [System.Windows.Forms.Label]) { $control.ForeColor = $fg }
        if ($control -is [System.Windows.Forms.CheckBox]) { $control.ForeColor = $fg }
        if ($control -is [System.Windows.Forms.RichTextBox]) { $control.BackColor = $panelBg; $control.ForeColor = $fg }
        if ($control -is [System.Windows.Forms.DataGridView]) {
            $control.BackgroundColor = $panelBg
            $control.DefaultCellStyle.BackColor = $panelBg
            $control.DefaultCellStyle.ForeColor = $fg
            $control.ColumnHeadersDefaultCellStyle.BackColor = $panelBg2
            $control.ColumnHeadersDefaultCellStyle.ForeColor = $fg
        }
        if ($control -is [System.Windows.Forms.Panel] -or $control -is [System.Windows.Forms.TableLayoutPanel] -or $control -is [System.Windows.Forms.FlowLayoutPanel]) {
            if ($control.Tag -eq "Card") { $control.BackColor = $panelBg }
            elseif ($control -ne $side -and $control -ne $header -and $control -ne $status) { $control.BackColor = $bg }
        }
        foreach($child in $control.Controls) { &$applyTheme $child }
    }
    &$applyTheme $form
    
    # Side buttons and special buttons
    foreach($b in $side.Controls) { if($b -is [System.Windows.Forms.Button] -and $b.BackColor -ne $C_Accent -and $b.BackColor -ne $C_Ok -and $b.BackColor -ne $C_Warn){ $b.BackColor = $panelBg2 } }
    $btnLang.BackColor = $panelBg2
    $btnTheme.Text = $(if ($script:LangMode -eq "TR") { if($script:DarkMode){"$($script:Icons.Moon) Koyu"}else{"$($script:Icons.Sun) Açık"} } else { if($script:DarkMode){"$($script:Icons.Moon) Dark"}else{"$($script:Icons.Sun) Light"} })
    OK "Tema değiştirildi: $(if($script:DarkMode){'Koyu'}else{'Açık'})"
}


$content = New-Object System.Windows.Forms.Panel
$content.Dock = "Fill"
$content.BackColor = $C_Bg
$main.Controls.Add($content,0,1)

$status = New-Object System.Windows.Forms.Panel
$status.Dock = "Fill"
$status.BackColor = $C_Panel
$main.Controls.Add($status,0,2)
$script:LblStatus = New-Object System.Windows.Forms.Label
$script:LblStatus.Text = "Durum: Hazır"
$script:LblStatus.ForeColor = $C_Fg
$script:LblStatus.Font = New-Object System.Drawing.Font("Segoe UI",9)
$script:LblStatus.Location = New-Object System.Drawing.Point(14,8)
$script:LblStatus.AutoSize = $true
$status.Controls.Add($script:LblStatus)

$pages = @{}
foreach ($name in @("dashboard","finder","fixes","diag","driver","logs")) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = "Fill"
    $p.BackColor = $C_Bg
    $p.Visible = $false
    $content.Controls.Add($p)
    $pages[$name] = $p
}
function Show-Page {
    param([string]$Name)
    foreach ($k in $pages.Keys) { $pages[$k].Visible = $false }
    $pages[$Name].Visible = $true
    $pages[$Name].BringToFront()
}

function New-TopButton {
    param([string]$Text,[object]$Back)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Dock = "Fill"
    $b.Margin = New-Object System.Windows.Forms.Padding(4)
    $b.BackColor = $Back
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatStyle = "Flat"
    $b.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    return $b
}

# DASHBOARD
$dash = $pages["dashboard"]
$dashLayout = New-Object System.Windows.Forms.TableLayoutPanel
$dashLayout.Dock = "Fill"
$dashLayout.Padding = New-Object System.Windows.Forms.Padding(14)
$dashLayout.ColumnCount = 3
$dashLayout.RowCount = 3
for($i=0;$i -lt 3;$i++){ [void]$dashLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,33.33))) }
[void]$dashLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,112)))
[void]$dashLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,230)))
[void]$dashLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
$dash.Controls.Add($dashLayout)

function New-DashCard {
    param([string]$Title,[string]$Value,[int]$Col,[int]$Row)
    $card = New-Object System.Windows.Forms.TableLayoutPanel
    $card.Dock = "Fill"
    $card.Margin = New-Object System.Windows.Forms.Padding(6)
    $card.Padding = New-Object System.Windows.Forms.Padding(14,12,14,12)
    $card.BackColor = $C_Panel
    $card.Tag = "Card"
    $card.ColumnCount = 1
    $card.RowCount = 2
    [void]$card.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,28)))
    [void]$card.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
    $dashLayout.Controls.Add($card,$Col,$Row)

    $t = New-Object System.Windows.Forms.Label
    $t.Text = $Title
    $t.ForeColor = $C_Muted
    $t.Font = New-Object System.Drawing.Font("Segoe UI",9.5,[System.Drawing.FontStyle]::Bold)
    $t.Dock = "Fill"
    $t.TextAlign = "MiddleLeft"
    $card.Controls.Add($t,0,0)

    $v = New-Object System.Windows.Forms.Label
    $v.Text = $Value
    $v.ForeColor = $C_Fg
    $v.Font = New-Object System.Drawing.Font("Segoe UI",13.5,[System.Drawing.FontStyle]::Bold)
    $v.Dock = "Fill"
    $v.TextAlign = "MiddleLeft"
    $v.AutoEllipsis = $true
    $card.Controls.Add($v,0,1)
    return $v
}

try { $osCaption = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { $osCaption = "Windows bilgisi okunamadı" }
$script:LblRoleValue = New-DashCard "Rol" "Belirsiz" 0 0
$null = New-DashCard "OS" $osCaption 1 0
$null = New-DashCard "Bilgisayar" $env:COMPUTERNAME 2 0

$quickPanel = New-Object System.Windows.Forms.TableLayoutPanel
$quickPanel.Dock = "Fill"
$quickPanel.Margin = New-Object System.Windows.Forms.Padding(6)
$quickPanel.Padding = New-Object System.Windows.Forms.Padding(14,12,14,12)
$quickPanel.BackColor = $C_Panel
$quickPanel.Tag = "Card"
$quickPanel.ColumnCount = 1
$quickPanel.RowCount = 3
[void]$quickPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,44)))
[void]$quickPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
[void]$quickPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,54)))
$dashLayout.Controls.Add($quickPanel,0,1)
$dashLayout.SetColumnSpan($quickPanel,3)

$roleRow = New-Object System.Windows.Forms.TableLayoutPanel
$roleRow.Dock = "Fill"
$roleRow.ColumnCount = 5
$roleRow.RowCount = 1
[void]$roleRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,102)))
[void]$roleRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,150)))
[void]$roleRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,215)))
[void]$roleRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,195)))
[void]$roleRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,100)))
$quickPanel.Controls.Add($roleRow,0,0)

$roleLabel = New-Object System.Windows.Forms.Label
$roleLabel.Text = "Çalışma Rolü:"
$roleLabel.ForeColor = $C_Fg
$roleLabel.Dock = "Fill"
$roleLabel.TextAlign = "MiddleLeft"
$roleRow.Controls.Add($roleLabel,0,0)

$cmbRole = New-Object System.Windows.Forms.ComboBox
$cmbRole.DropDownStyle = "DropDownList"
$cmbRole.Items.AddRange(@("Auto","Host","Client","Both"))
$cmbRole.SelectedIndex = 0
$cmbRole.Dock = "Fill"
$cmbRole.Margin = New-Object System.Windows.Forms.Padding(4,8,16,6)
$roleRow.Controls.Add($cmbRole,1,0)

$chkSmbSigning = New-Object System.Windows.Forms.CheckBox
$chkSmbSigning.Text = "SMB signing uyumluluk"
$chkSmbSigning.Checked = $true
$chkSmbSigning.ForeColor = $C_Fg
$chkSmbSigning.BackColor = $C_Panel
$chkSmbSigning.Dock = "Fill"
$chkSmbSigning.TextAlign = "MiddleLeft"
$roleRow.Controls.Add($chkSmbSigning,2,0)

$chkGuest = New-Object System.Windows.Forms.CheckBox
$chkGuest.Text = "Konuk/insecure guest"
$chkGuest.Checked = $false
$chkGuest.ForeColor = $C_Fg
$chkGuest.BackColor = $C_Panel
$chkGuest.Dock = "Fill"
$chkGuest.TextAlign = "MiddleLeft"
$roleRow.Controls.Add($chkGuest,3,0)

$dashHint = New-Object System.Windows.Forms.Label
$dashHint.Text = "A/B/C senaryosu: C client üzerinde Yerel Tespit, Credential + Driver + RPC + Point&Print + Spooler seçimi ve Seçili Fixleri Uygula akışı önerilir. Host A üzerinde gerekirse Host rolüyle SMB/Firewall/Servis fix çalıştır."
$dashHint.ForeColor = $C_Muted
$dashHint.Font = New-Object System.Drawing.Font("Segoe UI",10)
$dashHint.Dock = "Fill"
$dashHint.TextAlign = "MiddleLeft"
$quickPanel.Controls.Add($dashHint,0,1)

$backupPanel = New-Object System.Windows.Forms.TableLayoutPanel
$backupPanel.Dock = "Fill"
$backupPanel.Margin = New-Object System.Windows.Forms.Padding(0,8,0,0)
$backupPanel.Padding = New-Object System.Windows.Forms.Padding(12,6,12,6)
$backupPanel.BackColor = [System.Drawing.Color]::FromArgb(35,48,64)
$backupPanel.ColumnCount = 4
$backupPanel.RowCount = 1
[void]$backupPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,100)))
[void]$backupPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,128)))
[void]$backupPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,128)))
[void]$backupPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,108)))
$quickPanel.Controls.Add($backupPanel,0,2)

$backupTitle = New-Object System.Windows.Forms.Label
$backupTitle.Text = "Güvenli İşlem: Düzeltme öncesi yedek al, gerekirse tek tık geri yükle"
$backupTitle.ForeColor = [System.Drawing.Color]::FromArgb(239,245,252)
$backupTitle.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$backupTitle.Dock = "Fill"
$backupTitle.TextAlign = "MiddleLeft"
$backupTitle.AutoEllipsis = $true
$backupPanel.Controls.Add($backupTitle,0,0)

$btnDashBackup = New-TopButton "Yedek Al" $C_Ok
$backupPanel.Controls.Add($btnDashBackup,1,0)

$btnDashRestore = New-TopButton "Geri Yükle" $C_Warn
$backupPanel.Controls.Add($btnDashRestore,2,0)

$btnDashBackupFolder = New-TopButton "Klasör" $C_Panel2
$backupPanel.Controls.Add($btnDashBackupFolder,3,0)

$dashActions = New-Object System.Windows.Forms.TableLayoutPanel
$dashActions.Dock = "Fill"
$dashActions.Margin = New-Object System.Windows.Forms.Padding(6)
$dashActions.Padding = New-Object System.Windows.Forms.Padding(14)
$dashActions.BackColor = $C_Panel
$dashActions.Tag = "Card"
$dashActions.ColumnCount = 4
$dashActions.RowCount = 2
for($i=0;$i -lt 4;$i++){ [void]$dashActions.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,25))) }
[void]$dashActions.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,34)))
[void]$dashActions.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,48)))
$dashLayout.Controls.Add($dashActions,0,2)
$dashLayout.SetColumnSpan($dashActions,3)

$dashActionsTitle = New-Object System.Windows.Forms.Label
$dashActionsTitle.Text = "Hızlı İşlemler"
$dashActionsTitle.ForeColor = $C_Fg
$dashActionsTitle.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$dashActionsTitle.Dock = "Fill"
$dashActionsTitle.TextAlign = "MiddleLeft"
$dashActions.Controls.Add($dashActionsTitle,0,0)
$dashActions.SetColumnSpan($dashActionsTitle,4)

$btnDashLocalDiag = New-TopButton "Yerel Tespit" $C_Ok
$btnDashFind = New-TopButton "Yazıcı Bul / Bağla" $C_Panel2
$btnDashRecommended = New-TopButton "Önerilen Fix Seç" $C_Accent
$btnDashAutoRemediate = New-TopButton "Auto Remediation" $C_Warn
$dashActions.Controls.Add($btnDashLocalDiag,0,1)
$dashActions.Controls.Add($btnDashFind,1,1)
$dashActions.Controls.Add($btnDashRecommended,2,1)
$dashActions.Controls.Add($btnDashAutoRemediate,3,1)

$btnDashLocalDiag.Add_Click({ Show-Page "diag"; Run-LocalDiagnosis })
$btnDashFind.Add_Click({ Show-Page "finder" })
$btnDashRecommended.Add_Click({ Show-Page "fixes"; Apply-RecommendedFixSelection })
$btnDashAutoRemediate.Add_Click({ Show-Page "logs"; Invoke-AutoRemediation })
# FINDER
$finder = $pages["finder"]
$finderLayout = New-Object System.Windows.Forms.TableLayoutPanel
$finderLayout.Dock = "Fill"
$finderLayout.Padding = New-Object System.Windows.Forms.Padding(10)
$finderLayout.ColumnCount = 1
$finderLayout.RowCount = 2
[void]$finderLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,122)))
[void]$finderLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
$finder.Controls.Add($finderLayout)

$findTop = New-Object System.Windows.Forms.TableLayoutPanel
$findTop.Dock = "Fill"
$findTop.ColumnCount = 7
$findTop.RowCount = 2
[void]$findTop.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,95)))
[void]$findTop.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,30)))
[void]$findTop.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,105)))
[void]$findTop.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,38)))
[void]$findTop.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,120)))
[void]$findTop.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,135)))
[void]$findTop.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,130)))
$finderLayout.Controls.Add($findTop,0,0)

function New-FindLabel {
    param([string]$text)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Dock = "Fill"
    $l.ForeColor = $C_Fg
    $l.TextAlign = "MiddleLeft"
    $l.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    return $l
}
$findTop.Controls.Add((New-FindLabel "PC/IP:"),0,0)
$txtRemotePc = New-Object System.Windows.Forms.TextBox
$txtRemotePc.Dock = "Fill"
$txtRemotePc.Font = New-Object System.Drawing.Font("Segoe UI",10)
$findTop.Controls.Add($txtRemotePc,1,0)

$findTop.Controls.Add((New-FindLabel "UNC:"),2,0)
$txtManualUNC = New-Object System.Windows.Forms.TextBox
$txtManualUNC.Dock = "Fill"
$txtManualUNC.Font = New-Object System.Drawing.Font("Segoe UI",10)
$txtManualUNC.Text = "\\PCADI\PAYLASIM"
$findTop.Controls.Add($txtManualUNC,3,0)

$btnScan = New-TopButton "Tara" $C_Accent
$btnConnect = New-TopButton "Seçileni Bağla" $C_Ok
$btnManualConnect = New-TopButton "UNC Bağla" $C_Panel2
$findTop.Controls.Add($btnScan,4,0)
$findTop.Controls.Add($btnConnect,5,0)
$findTop.Controls.Add($btnManualConnect,6,0)

$chkAutoFixBeforeScan = New-Object System.Windows.Forms.CheckBox
$chkAutoFixBeforeScan.Text = "Tarama öncesi seçili client fix"
$chkAutoFixBeforeScan.Checked = $false
$chkAutoFixBeforeScan.ForeColor = $C_Fg
$chkAutoFixBeforeScan.BackColor = $C_Bg
$chkAutoFixBeforeScan.Dock = "Fill"
$findTop.Controls.Add($chkAutoFixBeforeScan,1,1)

$chkAutoFixBeforeConnect = New-Object System.Windows.Forms.CheckBox
$chkAutoFixBeforeConnect.Text = "Bağlantı öncesi seçili client fix"
$chkAutoFixBeforeConnect.Checked = $true
$chkAutoFixBeforeConnect.ForeColor = $C_Fg
$chkAutoFixBeforeConnect.BackColor = $C_Bg
$chkAutoFixBeforeConnect.Dock = "Fill"
$findTop.Controls.Add($chkAutoFixBeforeConnect,3,1)

$chkRemoveOld = New-Object System.Windows.Forms.CheckBox
$chkRemoveOld.Text = "Eski bağlantıyı temizle"
$chkRemoveOld.Checked = $true
$chkRemoveOld.ForeColor = $C_Fg
$chkRemoveOld.BackColor = $C_Bg
$chkRemoveOld.Dock = "Fill"
$findTop.Controls.Add($chkRemoveOld,4,1)
$findTop.SetColumnSpan($chkRemoveOld,2)

$gridPrinters = New-Object System.Windows.Forms.DataGridView
$gridPrinters.Dock = "Fill"
$gridPrinters.BackgroundColor = $C_Panel
$gridPrinters.BorderStyle = "None"
$gridPrinters.RowHeadersVisible = $false
$gridPrinters.AllowUserToAddRows = $false
$gridPrinters.AllowUserToDeleteRows = $false
$gridPrinters.ReadOnly = $true
$gridPrinters.MultiSelect = $false
$gridPrinters.SelectionMode = "FullRowSelect"
$gridPrinters.AutoSizeColumnsMode = "Fill"
$gridPrinters.EnableHeadersVisualStyles = $false
$gridPrinters.ColumnHeadersDefaultCellStyle.BackColor = $C_Panel2
$gridPrinters.ColumnHeadersDefaultCellStyle.ForeColor = $C_Fg
$gridPrinters.DefaultCellStyle.BackColor = $C_Panel
$gridPrinters.DefaultCellStyle.ForeColor = $C_Fg
$gridPrinters.DefaultCellStyle.SelectionBackColor = $C_Accent
[void]$gridPrinters.Columns.Add("Type","Tür")
[void]$gridPrinters.Columns.Add("Name","Ad")
[void]$gridPrinters.Columns.Add("ShareName","Paylaşım")
[void]$gridPrinters.Columns.Add("UNC","UNC")
[void]$gridPrinters.Columns.Add("Driver","Sürücü")
[void]$gridPrinters.Columns.Add("Source","Kaynak")
[void]$gridPrinters.Columns.Add("Note","Not")
$finderLayout.Controls.Add($gridPrinters,0,1)

# FIXES
$fixes = $pages["fixes"]
$fixWrap = New-Object System.Windows.Forms.TableLayoutPanel
$fixWrap.Dock = "Fill"
$fixWrap.ColumnCount = 2
$fixWrap.RowCount = 1
[void]$fixWrap.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,74)))
[void]$fixWrap.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,26)))
$fixes.Controls.Add($fixWrap)

$fixFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$fixFlow.Dock = "Fill"
$fixFlow.AutoScroll = $true
$fixFlow.WrapContents = $true
$fixFlow.Padding = New-Object System.Windows.Forms.Padding(10)
$fixFlow.BackColor = $C_Bg
$fixWrap.Controls.Add($fixFlow,0,0)

$fixHelp = New-Object System.Windows.Forms.RichTextBox
$fixHelp.Dock = "Fill"
$fixHelp.BackColor = $C_Panel
$fixHelp.Tag = "Card"
$fixHelp.ForeColor = $C_Fg
$fixHelp.BorderStyle = "None"
$fixHelp.ReadOnly = $true
$fixHelp.Font = New-Object System.Drawing.Font("Segoe UI Emoji",9.5)
$fixHelp.Text = "Ultimate Fix Kullanımı:`r`n`r`nC client için önerilen seçim:`r`n$($script:Icons.Check) RPC/11b`r`n$($script:Icons.Check) Point&Print/709`r`n$($script:Icons.Check) Firewall/Discovery`r`n$($script:Icons.Check) Servisler`r`n$($script:Icons.Check) Spooler Reset`r`n$($script:Icons.Check) Credential Temizliği`r`n$($script:Icons.Check) Driver Temizliği`r`n`r`nDriver filtresine marka/modelden bir kelime yazın.`r`nÖrnek: HP, Canon, Kyocera, Ricoh.`r`n`r`n$($script:Icons.Shield) Güvenlik: Düzeltme öncesi otomatik yedek alınır.`r`nManuel yedek için Ana Paneldeki $($script:Icons.Backup) Yedek Al butonunu kullanın.`r`n`r`nHost A için Driver/Credential seçmeyin."
$fixWrap.Controls.Add($fixHelp,1,0)

function Add-FixCard {
    param([string]$Title,[string]$Purpose,[string]$Desc,[ref]$CheckRef)
    $card = New-Object System.Windows.Forms.Panel
    $card.Size = New-Object System.Drawing.Size(310,165)
    $card.Margin = New-Object System.Windows.Forms.Padding(8)
    $card.BackColor = $C_Panel
    $card.Tag = "Card"
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $Title
    $chk.ForeColor = $C_Fg
    $chk.BackColor = $C_Panel
    $chk.Font = New-Object System.Drawing.Font("Segoe UI",9.5,[System.Drawing.FontStyle]::Bold)
    $chk.Location = New-Object System.Drawing.Point(12,10)
    $chk.AutoSize = $true
    $card.Controls.Add($chk)
    $p = New-Object System.Windows.Forms.Label
    $p.Text = "Amaç: $Purpose"
    $p.ForeColor = $C_Ok
    $p.Font = New-Object System.Drawing.Font("Segoe UI",8.5,[System.Drawing.FontStyle]::Bold)
    $p.Location = New-Object System.Drawing.Point(14,40)
    $p.Size = New-Object System.Drawing.Size(285,34)
    $card.Controls.Add($p)
    $d = New-Object System.Windows.Forms.Label
    $d.Text = $Desc
    $d.ForeColor = $C_Muted
    $d.Font = New-Object System.Drawing.Font("Segoe UI",8.4)
    $d.Location = New-Object System.Drawing.Point(14,78)
    $d.Size = New-Object System.Drawing.Size(285,70)
    $card.Controls.Add($d)
    $CheckRef.Value = $chk
    $fixFlow.Controls.Add($card)
}

$chkFixRpc = $null
$chkFixPoint = $null
$chkFixSmb = $null
$chkFixFirewall = $null
$chkFixServices = $null
$chkFixSpooler = $null
$chkFixNtlm = $null
$chkFixCredential = $null
$chkFixDriver = $null
$chkFixWorkgroup = $null

Add-FixCard "RPC / 0x0000011b" "11b ve RPC uyumluluğu" "RPC privacy, Named Pipes ve listener policy ayarlarını uygular." ([ref]$chkFixRpc)
Add-FixCard "Point&Print / 709" "Sürücü yükleme engeli" "Trusted servers, Package Point&Print ve driver policy ayarlarını düzenler." ([ref]$chkFixPoint)
Add-FixCard "SMB / Paylaşım" "Paylaşım uyumluluğu" "SMB2, signing ve isteğe bağlı guest uyumluluğu sağlar." ([ref]$chkFixSmb)
Add-FixCard "Firewall / Discovery" "Ağ görünürlüğü" "File/Printer Sharing, Network Discovery ve 445/135 port izinlerini açar." ([ref]$chkFixFirewall)
Add-FixCard "Servisler" "Windows servisleri" "Spooler, RPC, Lanman ve discovery servislerini otomatik/çalışır yapar." ([ref]$chkFixServices)
Add-FixCard "Spooler Reset" "Kuyruk temizliği" "Yazdırma kuyruğunu temizler ve spooler servisini yeniden başlatır." ([ref]$chkFixSpooler)
Add-FixCard "NTLM / NetBIOS" "Eski ağ uyumu" "NTLMv2 ve NetBIOS üzerinden ad çözümleme uyumluluğu sağlar." ([ref]$chkFixNtlm)
Add-FixCard "Credential Temizliği" "Eski kimlik bilgileri" "Hatalı Windows credential ve net use kayıtlarını temizler." ([ref]$chkFixCredential)
Add-FixCard "Driver Temizliği" "Bozuk driver cache" "Seçilen filtreye göre eski yazıcı/driver cache temizliği yapar." ([ref]$chkFixDriver)
Add-FixCard "Workgroup Win10/11" "TrustedHosts / WinRM / Policy" "Domain olmayan ağlarda Win10-Win11 bağlantı, TrustedHosts, LocalAccountTokenFilterPolicy ve gelişmiş yazıcı policylerini uygular." ([ref]$chkFixWorkgroup)

$chkFixRpc.Checked = $true
$chkFixPoint.Checked = $true
$chkFixServices.Checked = $true
$chkFixSpooler.Checked = $true
$chkFixFirewall.Checked = $true
$chkFixCredential.Checked = $true
$chkFixWorkgroup.Checked = $true

# DIAG PAGE
$diag = $pages["diag"]
$diagLayout = New-Object System.Windows.Forms.TableLayoutPanel
$diagLayout.Dock = "Fill"
$diagLayout.Padding = New-Object System.Windows.Forms.Padding(10)
$diagLayout.RowCount = 2
$diagLayout.ColumnCount = 1
[void]$diagLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,50)))
[void]$diagLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
$diag.Controls.Add($diagLayout)

$diagTop = New-Object System.Windows.Forms.FlowLayoutPanel
$diagTop.Dock = "Fill"
$diagTop.BackColor = $C_Bg
$diagLayout.Controls.Add($diagTop,0,0)

$btnRunLocalDiag = New-TopButton "Yerel Arıza Tespit" $C_Ok
$btnRunRemoteDiag = New-TopButton "Uzak PC Tespit" $C_Warn
$btnClearDiag = New-TopButton "Sonuç Temizle" $C_Panel2
$btnRunLocalDiag.Width = 160
$btnRunRemoteDiag.Width = 140
$btnClearDiag.Width = 120
$diagTop.Controls.Add($btnRunLocalDiag)
$diagTop.Controls.Add($btnRunRemoteDiag)
$diagTop.Controls.Add($btnClearDiag)

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
$diagLayout.Controls.Add($script:GridDiag,0,1)

# DRIVER PAGE
$driver = $pages["driver"]
$driverLayout = New-Object System.Windows.Forms.TableLayoutPanel
$driverLayout.Dock = "Fill"
$driverLayout.Padding = New-Object System.Windows.Forms.Padding(16)
$driverLayout.RowCount = 5
$driverLayout.ColumnCount = 2
[void]$driverLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,180)))
[void]$driverLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,100)))
[void]$driverLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,45)))
[void]$driverLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,45)))
[void]$driverLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,45)))
[void]$driverLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,90)))
[void]$driverLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
$driver.Controls.Add($driverLayout)

$lFilter = New-Object System.Windows.Forms.Label
$lFilter.Text = "Driver filtresi:"
$lFilter.ForeColor = $C_Fg
$lFilter.Dock = "Fill"
$lFilter.TextAlign = "MiddleLeft"
$driverLayout.Controls.Add($lFilter,0,0)

$txtDriverFilter = New-Object System.Windows.Forms.TextBox
$txtDriverFilter.Dock = "Fill"
$txtDriverFilter.Text = ""
$txtDriverFilter.Font = New-Object System.Drawing.Font("Segoe UI",10)
$driverLayout.Controls.Add($txtDriverFilter,1,0)

$btnDriverClean = New-TopButton "Driver Cache Temizle" $C_Err
$driverLayout.Controls.Add($btnDriverClean,1,1)

$driverInfo = New-Object System.Windows.Forms.Label
$driverInfo.Text = "C client görüp bağlanamıyorsa en güçlü ihtimal bozuk/yarım kalmış driver package veya eski credentialdır. Filtreye HP/Canon/Kyocera/Ricoh gibi marka yazıp temizleyin."
$driverInfo.ForeColor = $C_Muted
$driverInfo.Dock = "Fill"
$driverInfo.Font = New-Object System.Drawing.Font("Segoe UI",10)
$driverLayout.Controls.Add($driverInfo,1,3)

# LOGS
$logs = $pages["logs"]
$logLayout = New-Object System.Windows.Forms.TableLayoutPanel
$logLayout.Dock = "Fill"
$logLayout.RowCount = 2
$logLayout.ColumnCount = 1
[void]$logLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute,48)))
[void]$logLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
$logLayout.Padding = New-Object System.Windows.Forms.Padding(10)
$logs.Controls.Add($logLayout)

$logTop = New-Object System.Windows.Forms.FlowLayoutPanel
$logTop.Dock = "Fill"
$logTop.BackColor = $C_Bg
$logLayout.Controls.Add($logTop,0,0)
$btnOpenLog = New-TopButton "Log Klasörü" $C_Panel2
$btnHtml = New-TopButton "HTML Rapor" $C_Accent
$btnClearLog = New-TopButton "Log Temizle" $C_Panel2
$btnOpenLog.Width = 130
$btnHtml.Width = 130
$btnClearLog.Width = 130
$logTop.Controls.Add($btnOpenLog)
$logTop.Controls.Add($btnHtml)
$logTop.Controls.Add($btnClearLog)

$script:TxtLog = New-Object System.Windows.Forms.RichTextBox
$script:TxtLog.Dock = "Fill"
$script:TxtLog.BackColor = [System.Drawing.Color]::FromArgb(13,16,21)
$script:TxtLog.ForeColor = $C_Fg
$script:TxtLog.BorderStyle = "None"
$script:TxtLog.ReadOnly = $true
$script:TxtLog.Font = New-Object System.Drawing.Font("Consolas",9.5)
$logLayout.Controls.Add($script:TxtLog,0,1)

# EVENTS
$btnDashboard.Add_Click({ Show-Page "dashboard"
Update-HeaderActionLayout })
$btnFinder.Add_Click({ Show-Page "finder" })
$btnFixes.Add_Click({ Show-Page "fixes" })
$btnDiag.Add_Click({ Show-Page "diag" })
$btnDriver.Add_Click({ Show-Page "driver" })
$btnLogs.Add_Click({ Show-Page "logs" })
$btnAutoFix.Add_Click({ Run-AutoFix })
$btnDetect.Add_Click({ Detect-Role | Out-Null; Show-Info "Rol" "Algılanan rol: $script:DetectedRole" })
$btnDiagLocal.Add_Click({ Show-Page "diag"; Run-LocalDiagnosis })
$btnDiagRemote.Add_Click({ Show-Page "diag"; Run-RemoteDiagnosis })
$btnWorkgroup.Add_Click({ Show-Page "logs"; Apply-WorkgroupCompatibilityFix })
$btnRecommend.Add_Click({ Show-Page "fixes"; Apply-RecommendedFixSelection })
$btnAutoRemediate.Add_Click({ Show-Page "logs"; Invoke-AutoRemediation })
$btnWorkflow.Add_Click({ Show-Page "logs"; Run-EnterpriseWorkflow })

$btnScan.Add_Click({ Scan-RemotePrinters })
$btnConnect.Add_Click({ Connect-SelectedPrinter })
$btnManualConnect.Add_Click({ Connect-ManualPrinter })
$gridPrinters.Add_CellDoubleClick({ Connect-SelectedPrinter })

$btnRunLocalDiag.Add_Click({ Run-LocalDiagnosis })
$btnRunRemoteDiag.Add_Click({ Run-RemoteDiagnosis })
$btnClearDiag.Add_Click({ Clear-Diag })
$btnDriverClean.Add_Click({ Apply-DriverCacheCleanup })

$btnOpenLog.Add_Click({ Start-Process explorer.exe $script:LogDir })
$btnHtml.Add_Click({ Export-Report })
$btnClearLog.Add_Click({ $script:TxtLog.Clear() })
$btnBackup.Add_Click({ Show-Page "logs"; New-BackupSnapshot -Reason "Manual" | Out-Null })
$btnRestore.Add_Click({ Show-Page "logs"; Restore-BackupSnapshot })
$btnBackupFolder.Add_Click({ Open-BackupFolder })
$btnDashBackup.Add_Click({ Show-Page "logs"; New-BackupSnapshot -Reason "Dashboard_Manual" | Out-Null })
$btnDashRestore.Add_Click({ Show-Page "logs"; Restore-BackupSnapshot })
$btnDashBackupFolder.Add_Click({ Open-BackupFolder })
$btnLang.Add_Click({ Toggle-LanguageSafe })
$btnTheme.Add_Click({ Toggle-ThemeSafe })

Toggle-LanguageSafe
Toggle-LanguageSafe
Write-Log "$($script:AppCode) başlatıldı."
Write-Log "Log dosyası: $script:LogFile"
Ensure-AppCodeSigningTrust
Detect-Role | Out-Null
Show-Page "dashboard"
Update-HeaderActionLayout

[void]$form.ShowDialog()

