param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath
)

$ErrorActionPreference = 'Stop'
$resolvedExe = (Resolve-Path -LiteralPath $ExePath).Path
$exeBytes = [IO.File]::ReadAllBytes($resolvedExe)
$assembly = [Reflection.Assembly]::Load($exeBytes)
$resourceStream = $assembly.GetManifestResourceStream('bundled_server.ps1')
if (-not $resourceStream) { throw 'bundled_server.ps1 resource was not found.' }
$reader = [IO.StreamReader]::new($resourceStream)
$serverScript = $reader.ReadToEnd()
$reader.Dispose()
$resourceStream.Dispose()

$keyMatch = [regex]::Match($serverScript, '\$aesKeyObf\s*=\s*"([^"]+)"')
$ivMatch = [regex]::Match($serverScript, '\$aesIvObf\s*=\s*"([^"]+)"')
if (-not $keyMatch.Success -or -not $ivMatch.Success) { throw 'Encrypted asset key material was not found.' }
$key = [Convert]::FromBase64String($keyMatch.Groups[1].Value)
$iv = [Convert]::FromBase64String($ivMatch.Groups[1].Value)
for ($i = 0; $i -lt $key.Length; $i++) { $key[$i] = $key[$i] -bxor 0x5A }
for ($i = 0; $i -lt $iv.Length; $i++) { $iv[$i] = $iv[$i] -bxor 0xA5 }

$utf8 = [Text.UTF8Encoding]::new($false)
$assets = @{}
$originalAssetBytes = @{}
foreach ($assetName in @('Html', 'Css', 'Js')) {
    $match = [regex]::Match($serverScript, '(?m)^\$embedded' + $assetName + '\s*=\s*"([^"]+)"')
    if (-not $match.Success) { throw "Embedded $assetName payload was not found." }
    $cipher = [Convert]::FromBase64String($match.Groups[1].Value)
    $aes = [Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = $iv
    $decryptor = $aes.CreateDecryptor()
    $plainBytes = $decryptor.TransformFinalBlock($cipher, 0, $cipher.Length)
    $decryptor.Dispose()
    $aes.Dispose()
    $assets[$assetName] = $utf8.GetString($plainBytes)
    $originalAssetBytes[$assetName] = $plainBytes.Length
}

function Replace-TextSameSize([string]$Text, [string]$Old, [string]$New, [string]$Context) {
    $oldBytes = $utf8.GetByteCount($Old)
    $newBytes = $utf8.GetByteCount($New)
    if ($newBytes -gt $oldBytes) { throw "Translation too long in ${Context}: '$Old' -> '$New' ($newBytes > $oldBytes UTF-8 bytes)." }
    $replacement = $New + (' ' * ($oldBytes - $newBytes))
    return $Text.Replace($Old, $replacement)
}

# Replace the attribution link with a same-size, neutral product label.
$html = $assets.Html
$identityIndex = $html.IndexOf('technicalanshu7593', [StringComparison]::OrdinalIgnoreCase)
if ($identityIndex -ge 0) {
    $anchorStart = $html.LastIndexOf('<a ', $identityIndex, [StringComparison]::OrdinalIgnoreCase)
    $anchorEnd = $html.IndexOf('</a>', $identityIndex, [StringComparison]::OrdinalIgnoreCase) + 4
    if ($anchorStart -lt 0 -or $anchorEnd -lt 4) { throw 'Could not isolate the old attribution link.' }
    $anchor = $html.Substring($anchorStart, $anchorEnd - $anchorStart)
    $label = 'SysForge Studio'
    $paddingLength = $anchor.Length - $label.Length - 7
    if ($paddingLength -lt 0) { throw 'The attribution slot is too small for a safe replacement.' }
    $html = $html.Substring(0, $anchorStart) + $label + '<!--' + (' ' * $paddingLength) + '-->' + $html.Substring($anchorEnd)
}

$translations = @(
    @('Printer Analyzer Pro v1.0 - Root Cause Diagnostic & Auto-Fix Engine', 'SysForge Studio v1.0 - Yazıcı Tanılama ve Onarım'),
    @('PRINTER ANALYZER PRO v1.0', 'SYSFORGE STUDIO v1.0'),
    @('technical Anshu', 'SysForge Studio'),
    @('Restart Spooler', 'Yeniden Başlat'),
    @('Purge Queue', 'Kuyruk Sil'),
    @('Flush DNS', 'DNS Sil'),
    @('Export PDF', 'PDF Kaydet'),
    @('Fix Shared Print', 'Paylaşım Onar'),
    @('Connection Protocol', 'Bağlantı Tipi'),
    @('USB Port', 'USB'),
    @('Shared SMB', 'SMB Ağ'),
    @('Select USB Printer', 'USB Yazıcı Seç'),
    @('Domain \ Username', 'Etki\Kullanıcı'),
    @('Password', 'Parola'),
    @('Print Server IP / Hostname', 'Sunucu IP / Adı'),
    @('Scan Server Printers', 'Yazıcıları Tara'),
    @('Connect Direct', 'Doğrudan'),
    @('Inject Credentials', 'Kimlik Bilgisi Gir'),
    @('ARP Scan', 'ARP Tara'),
    @('Subnet Scan', 'Alt Ağ'),
    @('Telemetry Mode', 'Telemetri Modu'),
    @('Demo / Simulation', 'Deneme / Benzetim'),
    @('Live System Scan', 'Canlı Tara'),
    @('Auto-Remediation (Self-Healing)', 'Otomatik Onarım'),
    @('Universal AI Auto-Healer (Gemini)', 'Yapay Zekâ Onarımı (Gemini)'),
    @('Failure Scenario Template', 'Arıza Senaryosu Şablonu'),
    @('Drop Telemetry JSON Report', 'JSON Rapor Yükle'),
    @('START DIAGNOSTIC SCAN 10-Layer Root Cause Engine', 'TANIYI BAŞLAT • 10 Katmanlı Analiz'),
    @('1-CLICK MASTER FIX Fix Shared Printer Blocks, Ports & Spooler', 'TEK TIKLA ONAR • Paylaşımlı Yazıcı'),
    @('10-Layer Diagnostic Analyzer', '10 Katmanlı Tanılama'),
    @('Detected Windows Printers & Queues', 'Bulunan Yazıcılar ve Kuyruklar'),
    @('Staged Printer Driver Packages (WDI DriverStore)', 'Hazır Sürücü Paketleri (WDI)'),
    @('Active Installed Printer Drivers (WMI Spooler)', 'Yüklü Yazıcı Sürücüleri (WMI)'),
    @('Microsoft Catalog Driver Downloader & Installer', 'Microsoft Sürücü Kataloğu • İndir ve Kur'),
    @('Search Catalog', 'Katalogda Ara'),
    @('Domain & Group Policy (GPO) Audit Visualizer Bypass All GPO Blocks', 'Etki Alanı İlkesi (GPO) Denetimi'),
    @('Scan to SMB (Network Folder) Troubleshooter', 'SMB Ağ Klasörü Sorun Giderici'),
    @('Local Folder Path', 'Yerel Yol'),
    @('Network Share Name', 'Ağ Paylaşım'),
    @('Run SMB Audit', 'SMB Denetle'),
    @('SMB Auto-Fix Console', 'SMB Otomatik Onarım'),
    @('1-Click Share', 'Paylaş'),
    @('Net Profile & FW', 'Ağ ve Güvenlik'),
    @('Enable SMBv1', 'Etkinleştir'),
    @('Copy Script', 'Kopyala'),
    @('Execute SMB Repair Action', 'SMB Onarımını Uygula'),
    @('Application & Scanner Settings', 'Uygulama Ayarları'),
    @('Diagnostic Logging Level', 'Tanılama Kayıt Düzeyi'),
    @('Automated Repair Defaults', 'Otomatik Onarım'),
    @('Always backup registry keys before patching spooler policies', 'Onarım öncesi kayıt defterini yedekle'),
    @('Clear print spooler queues immediately on service reset', 'Hizmet sıfırlanınca yazdırma kuyruğunu temizle'),
    @('Google Gemini API Key (Optional)', 'Gemini API Anahtarı'),
    @('Save Key', 'Kaydet'),
    @('Remote System Diagnostics Agent (WinRM)', 'Uzak Sistem Tanısı (WinRM)'),
    @('Enable Remote Targeting', 'Uzak Hedef Aç'),
    @('Remote Server / Host IP', 'Uzak Sunucu IP Adresi'),
    @('Username (Admin)', 'Yönetici'),
    @('Print Spooler Registry Tweak Console', 'Yazdırma Hizmeti Ayarları'),
    @('Scan History Last 20 scans saved locally', 'Tarama Geçmişi • Son 20 kayıt'),
    @('Export All (JSON)', 'Tümünü Al'),
    @('Clear History', 'Geçmiş Sil'),
    @('Diagnostics History Trend', 'Geçmiş Eğilimi'),
    @('Diagnostics Logs LIVE 0 ERRORS', 'Canlı Günlük • 0 Hata'),
    @('INFO', 'Bil'),
    @('WARN', 'Uyar'),
    @('ERROR', 'HATA'),
    @('Refresh', 'Yenile'),
    @('Download', 'İndir'),
    @('Clear', 'Sil'),
    @('Auto-scroll', 'Oto Kaydır'),
    @('Layer Status Matrix', 'Durum Tablosu'),
    @('Print Spooler Live Telemetry ACTIVE', 'Canlı Yazdırma İzleme AÇIK'),
    @('Purge Spooler Cache (.SPL/.SHD)', 'Kuyruk Önbelleğini Temizle'),
    @('Spooler Healer (Auto-Fix)', 'Yazdırma Onarımı'),
    @('Root Cause Diagnostic Report', 'Kök Neden Tanılama Raporu'),
    @('Run Performance Test', 'Performans Testi'),
    @('Secondary Findings / Warnings', 'Ek Bulgular / Uyarılar'),
    @('Step-by-Step Remediation Action Plan', 'Adım Adım Onarım Planı'),
    @('Automated One-Click Repairs', 'Otomatik Tek Tık Onarım'),
    @('Remediation Console', 'Onarım Konsolu'),
    @('Send Test Print Page', 'Test Yazdır'),
    @('Clear Queue', 'Kuyruk Sil'),
    @('Repair Registry', 'Defteri Onar'),
    @('Reset Services', 'Sıfırla'),
    @('Resolve Share Blocking', 'Paylaşım Engeli'),
    @('Clean Drivers', 'Sürücü Sil'),
    @('Reinstall Queue', 'Kuyruk Kur'),
    @('Execute Repair', 'Onar'),
    @('Copy Code', 'Kopyala'),
    @('Download .ps1', '.ps1 İndir'),
    @('Error Code Lookup & Decoder', 'Hata Kodu Bul ve Çöz'),
    @('0x0000011B - PrintNightmare RPC Privacy Mismatch', '0x0000011B • RPC Gizlilik Uyumsuzluğu'),
    @('Generate AI Fix (Gemini)', 'Yapay Zekâ (Gemini)'),
    @('Run Script', 'Başlat'),
    @('Refresh Dashboard', 'Paneli Yenile'),
    @('Toggle Light/Dark Mode', 'Tema Değiştir'),
    @('Toggle WOW Mode (Ultra Cyberpunk Neon)', 'WOW Görünümünü Değiştir'),
    @('Printer_Toolkit_Master .ps1 • Windows Only', 'Printer_Toolkit_Master.ps1 • Windows')
)
foreach ($pair in $translations) { $html = Replace-TextSameSize $html $pair[0] $pair[1] 'HTML' }

$css = $assets.Css
$css = $css.Replace('--bg-primary: #eef0f8;', '--bg-main   : #eef0f8;')
$css = $css.Replace('--bg-secondary: #e2e6f0;', '--bg-panel    : #ffffff;')
if ($css -match '--bg-primary:|--bg-secondary:') { throw 'A light-mode background alias remains uncorrected.' }

$js = $assets.Js
# The old initialization followed Windows' light preference even without a saved choice,
# and the light-mode colors used aliases that the UI never reads. Default new profiles to dark.
$oldPreference = 'const prefersLight = window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches;'
$js = Replace-TextSameSize $js $oldPreference 'const prefersLight = false;' 'JavaScript'
$oldCondition = 'if (savedTheme === "light" || (savedTheme === null && prefersLight)) {'
$js = Replace-TextSameSize $js $oldCondition 'if (savedTheme === "light") {' 'JavaScript'
# Make the icon show the action available (sun in dark mode, moon in light mode).
$themeMarker = '// Theme Toggle Listener with localStorage persistency'
$themeIndex = $js.IndexOf($themeMarker, [StringComparison]::Ordinal)
$iconCondition = 'if (isLight) {'
$iconIndex = $js.IndexOf($iconCondition, $themeIndex, [StringComparison]::Ordinal)
if ($themeIndex -lt 0) { throw 'Theme icon update block was not found.' }
if ($iconIndex -ge 0) {
    $js = $js.Substring(0, $iconIndex) + 'if (!isLight){' + $js.Substring($iconIndex + $iconCondition.Length)
} elseif ($js.IndexOf('if (!isLight){', $themeIndex, [StringComparison]::Ordinal) -lt 0) {
    throw 'Theme icon update block was not found.'
}

$updated = @{ Html = $html; Css = $css; Js = $js }
foreach ($assetName in @('Html', 'Css', 'Js')) {
    $newPlain = $utf8.GetBytes($updated[$assetName])
    if ($newPlain.Length -ne $originalAssetBytes[$assetName]) {
        throw "$assetName byte length changed from $($originalAssetBytes[$assetName]) to $($newPlain.Length)."
    }
    $aes = [Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = $iv
    $encryptor = $aes.CreateEncryptor()
    $newCipher = $encryptor.TransformFinalBlock($newPlain, 0, $newPlain.Length)
    $encryptor.Dispose()
    $aes.Dispose()
    $oldPayload = [regex]::Match($serverScript, '(?m)^\$embedded' + $assetName + '\s*=\s*"([^"]+)"').Groups[1].Value
    $newPayload = [Convert]::ToBase64String($newCipher)
    if ($newPayload.Length -ne $oldPayload.Length) { throw "$assetName encoded size changed." }
    $ascii = [Text.Encoding]::ASCII.GetString($exeBytes)
    $offset = $ascii.IndexOf($oldPayload, [StringComparison]::Ordinal)
    if ($offset -lt 0 -or $ascii.IndexOf($oldPayload, $offset + $oldPayload.Length, [StringComparison]::Ordinal) -ge 0) {
        throw "$assetName payload was not found uniquely in the executable."
    }
    $payloadBytes = [Text.Encoding]::ASCII.GetBytes($newPayload)
    [Array]::Copy($payloadBytes, 0, $exeBytes, $offset, $payloadBytes.Length)
}

[IO.File]::WriteAllBytes($resolvedExe, $exeBytes)
"Patched $resolvedExe`nTranslated HTML strings: $($translations.Count)`nLight/dark CSS aliases corrected; default theme is dark; toggle icon now indicates the available action."
