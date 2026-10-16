# ==============================================================================
# Donanım Ekspertiz Merkezi - Modern Fluent WPF GUI (PowerToys / DevToys Style)
# Mimari: Pure PowerShell + WPF XAML (x86 & x64 Native)
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$NoGui,
    [switch]$SaveSnapshot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Load WPF Assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Base Directories
$script:DesktopPath = [Environment]::GetFolderPath('Desktop')
$script:BaseFolder = Join-Path $script:DesktopPath 'EkspertizArsivi'
$script:SnapshotFolder = Join-Path $script:BaseFolder 'Snapshots'
$script:ReportFolder = Join-Path $script:BaseFolder 'Raporlar'
$script:BaselinePath = Join-Path $script:SnapshotFolder 'baseline_hardware.json'

foreach ($folder in @($script:BaseFolder, $script:SnapshotFolder, $script:ReportFolder)) {
    if (-not (Test-Path -LiteralPath $folder)) {
        [void](New-Item -ItemType Directory -Path $folder -Force)
    }
}

# --- Core Functions: WMI & Hardware Info ---
function Get-HardwareSnapshotData {
    $data = [ordered]@{
        Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        MachineName = $env:COMPUTERNAME
        Motherboard = @{}
        Bios = @{}
        Processor = @{}
        RAM = @()
        Disks = @()
        GPU = @()
        Hash = ''
    }

    # Motherboard
    try {
        $mb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
        $data.Motherboard = [ordered]@{
            Manufacturer = if ($mb.Manufacturer) { $mb.Manufacturer.Trim() } else { '-' }
            Product = if ($mb.Product) { $mb.Product.Trim() } else { '-' }
            SerialNumber = if ($mb.SerialNumber) { $mb.SerialNumber.Trim() } else { '-' }
        }
    } catch { }

    # BIOS & UUID
    try {
        $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
        $csp = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue | Select-Object -First 1
        $data.Bios = [ordered]@{
            Manufacturer = if ($bios.Manufacturer) { $bios.Manufacturer.Trim() } else { '-' }
            Version = if ($bios.Version) { $bios.Version.Trim() } else { '-' }
            SerialNumber = if ($bios.SerialNumber) { $bios.SerialNumber.Trim() } else { '-' }
            UUID = if ($csp.UUID) { $csp.UUID.Trim() } else { '-' }
        }
    } catch { }

    # CPU
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        $data.Processor = [ordered]@{
            Name = if ($cpu.Name) { $cpu.Name.Trim() } else { '-' }
            ProcessorId = if ($cpu.ProcessorId) { $cpu.ProcessorId.Trim() } else { '-' }
            Cores = $cpu.NumberOfCores
            Logical = $cpu.NumberOfLogicalProcessors
        }
    } catch { }

    # RAM
    try {
        $rams = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
        foreach ($r in $rams) {
            $cap = [Math]::Round(($r.Capacity / 1GB), 2)
            $data.RAM += [ordered]@{
                Bank = if ($r.BankLabel) { $r.BankLabel.Trim() } else { '-' }
                CapacityGB = $cap
                Speed = $r.Speed
                Manufacturer = if ($r.Manufacturer) { $r.Manufacturer.Trim() } else { '-' }
                SerialNumber = if ($r.SerialNumber) { $r.SerialNumber.Trim() } else { '-' }
                PartNumber = if ($r.PartNumber) { $r.PartNumber.Trim() } else { '-' }
            }
        }
    } catch { }

    # Disks
    try {
        $disks = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue
        foreach ($d in $disks) {
            $sz = [Math]::Round(($d.Size / 1GB), 2)
            $data.Disks += [ordered]@{
                Model = if ($d.Model) { $d.Model.Trim() } else { '-' }
                SerialNumber = if ($d.SerialNumber) { $d.SerialNumber.Trim() } else { '-' }
                SizeGB = $sz
                Interface = if ($d.InterfaceType) { $d.InterfaceType.Trim() } else { '-' }
            }
        }
    } catch { }

    # GPU
    try {
        $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        foreach ($g in $gpus) {
            $data.GPU += [ordered]@{
                Name = if ($g.Name) { $g.Name.Trim() } else { '-' }
                Driver = if ($g.DriverVersion) { $g.DriverVersion.Trim() } else { '-' }
            }
        }
    } catch { }

    # Generate SHA-256 Hash
    $hashString = "$($data.Motherboard.SerialNumber)|$($data.Bios.UUID)|$($data.Processor.ProcessorId)"
    foreach ($r in $data.RAM) { $hashString += "|$($r.SerialNumber):$($r.CapacityGB)" }
    foreach ($d in $data.Disks) { $hashString += "|$($d.SerialNumber):$($d.Model)" }
    
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($hashString)
    $hashBytes = $sha.ComputeHash($bytes)
    $data.Hash = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToUpperInvariant()
    $sha.Dispose()

    return $data
}

# --- XAML Definition (Fluent / DevToys Dark Theme) ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Donanım Ekspertizi &amp; Kimlik Doğrulama (WPF Fluent Edition)" 
        Height="780" Width="1020" MinHeight="600" MinWidth="850"
        WindowStartupLocation="CenterScreen"
        Background="#202020" Foreground="#FFFFFF" FontFamily="Segoe UI Variable Display, Segoe UI, sans-serif">

    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#333333" />
            <Setter Property="Foreground" Value="#FFFFFF" />
            <Setter Property="Padding" Value="14,8" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="FontSize" Value="13" />
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="BorderBrush" Value="#383838" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#3D3D3D"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#0078D4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PrimaryBtn" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="#0078D4" />
            <Setter Property="BorderBrush" Value="#005A9E" />
        </Style>
    </Window.Resources>

    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <!-- Top Header (DevToys Style) -->
        <Grid Grid.Row="0" Margin="0,0,0,16">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
                <TextBlock Text="🛡️ Donanım Ekspertizi &amp; Kimlik Kıyaslama" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" />
                <TextBlock Text="PowerToys / DevToys stili modern WPF altyapısı ile donanım dökümü, SHA-256 hash ve değişiklik tespiti" 
                           FontSize="13" Foreground="#A6A6A6" Margin="0,3,0,0" />
            </StackPanel>
            <Button x:Name="BtnOpenFolder" Grid.Column="1" Content="📂 Arşivi Aç" VerticalAlignment="Center" />
        </Grid>

        <!-- Action Toolbar -->
        <Border Grid.Row="1" Background="#2B2B2B" BorderBrush="#383838" BorderThickness="1" CornerRadius="8" Padding="14" Margin="0,0,0,14">
            <WrapPanel>
                <Button x:Name="BtnScan" Content="🔍 Donanımı Tara" Style="{StaticResource PrimaryBtn}" Margin="0,0,10,0"/>
                <Button x:Name="BtnSaveBaseline" Content="💾 Referans (Baseline) Kaydet" Margin="0,0,10,0"/>
                <Button x:Name="BtnCompare" Content="⚖️ Değişiklikleri Kıyasla" Margin="0,0,10,0"/>
                <Button x:Name="BtnHtmlReport" Content="📄 HTML Raporu Aç" Margin="0,0,10,0"/>
            </WrapPanel>
        </Border>

        <!-- Status & Comparison Banner -->
        <Border x:Name="BannerStatus" Grid.Row="2" Background="#1E293B" BorderBrush="#334155" BorderThickness="1" CornerRadius="8" Padding="14" Margin="0,0,0,14" Visibility="Collapsed">
            <StackPanel>
                <TextBlock x:Name="TxtBannerTitle" Text="Kıyaslama Durumu" FontSize="15" FontWeight="Bold" Foreground="#38BDF8"/>
                <TextBlock x:Name="TxtBannerDesc" Text="Sonuç açıklaması..." FontSize="13" Foreground="#E2E8F0" Margin="0,4,0,0" TextWrapping="Wrap"/>
            </StackPanel>
        </Border>

        <!-- Main Workspace (DevToys Cards) -->
        <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <!-- Hash Card -->
                <Border Background="#2B2B2B" BorderBrush="#383838" BorderThickness="1" CornerRadius="8" Padding="16" Margin="0,0,0,12">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*" />
                            <ColumnDefinition Width="Auto" />
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0">
                            <TextBlock Text="DONANIM BÜTÜNLÜK HASH (SHA-256)" FontSize="11" FontWeight="Bold" Foreground="#A6A6A6"/>
                            <TextBlock x:Name="TxtHash" Text="Taramak için 'Donanımı Tara' butonuna basın..." FontSize="14" FontWeight="SemiBold" Foreground="#38BDF8" FontFamily="Consolas" Margin="0,4,0,0" TextWrapping="Wrap"/>
                        </StackPanel>
                        <TextBlock x:Name="TxtTime" Grid.Column="1" Text="" FontSize="11" Foreground="#888888" VerticalAlignment="Center"/>
                    </Grid>
                </Border>

                <!-- Grid Details -->
                <Grid Margin="0,0,0,12">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*" />
                        <ColumnDefinition Width="12" />
                        <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>

                    <!-- Left: MB & CPU -->
                    <Border Grid.Column="0" Background="#2B2B2B" BorderBrush="#383838" BorderThickness="1" CornerRadius="8" Padding="16">
                        <StackPanel>
                            <TextBlock Text="💻 Anakart, BIOS &amp; İşlemci" FontSize="14" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,10"/>
                            <TextBlock Text="Anakart:" FontSize="11" Foreground="#888888"/>
                            <TextBlock x:Name="TxtMb" Text="-" FontSize="13" Foreground="#FFFFFF" Margin="0,0,0,6"/>

                            <TextBlock Text="Anakart Seri No:" FontSize="11" Foreground="#888888"/>
                            <TextBlock x:Name="TxtMbSn" Text="-" FontSize="13" Foreground="#38BDF8" FontFamily="Consolas" Margin="0,0,0,6"/>

                            <TextBlock Text="Sistem UUID:" FontSize="11" Foreground="#888888"/>
                            <TextBlock x:Name="TxtUuid" Text="-" FontSize="12" Foreground="#FFFFFF" FontFamily="Consolas" Margin="0,0,0,6"/>

                            <TextBlock Text="İşlemci (CPU):" FontSize="11" Foreground="#888888"/>
                            <TextBlock x:Name="TxtCpu" Text="-" FontSize="13" Foreground="#FFFFFF"/>
                        </StackPanel>
                    </Border>

                    <!-- Right: RAM & Disks -->
                    <Border Grid.Column="2" Background="#2B2B2B" BorderBrush="#383838" BorderThickness="1" CornerRadius="8" Padding="16">
                        <StackPanel>
                            <TextBlock Text="🧠 RAM &amp; Disk Envanteri" FontSize="14" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,10"/>
                            <TextBlock Text="Toplam RAM:" FontSize="11" Foreground="#888888"/>
                            <TextBlock x:Name="TxtRamSummary" Text="-" FontSize="13" Foreground="#107C41" FontWeight="Bold" Margin="0,0,0,6"/>

                            <TextBlock Text="Depolama (Diskler):" FontSize="11" Foreground="#888888"/>
                            <TextBlock x:Name="TxtDiskSummary" Text="-" FontSize="13" Foreground="#FFFFFF" Margin="0,0,0,6"/>

                            <TextBlock Text="Ekran Kartı (GPU):" FontSize="11" Foreground="#888888"/>
                            <TextBlock x:Name="TxtGpu" Text="-" FontSize="13" Foreground="#FFFFFF"/>
                        </StackPanel>
                    </Border>
                </Grid>

                <!-- Detailed Raw JSON / Info Box -->
                <Border Background="#2B2B2B" BorderBrush="#383838" BorderThickness="1" CornerRadius="8" Padding="16">
                    <StackPanel>
                        <TextBlock Text="📋 Donanım Detay Dökümü (JSON &amp; Parça Bilgisi)" FontSize="14" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,8"/>
                        <TextBox x:Name="TxtDetails" Height="180" Background="#181818" Foreground="#38BDF8" FontFamily="Consolas" FontSize="11.5" 
                                 IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" BorderThickness="0" Padding="10"/>
                    </StackPanel>
                </Border>
            </StackPanel>
        </ScrollViewer>

        <!-- Footer -->
        <TextBlock Grid.Row="4" Text="Ultimate Enterprise IT Suite - WPF XAML Native Edition" FontSize="11" Foreground="#666666" Margin="0,10,0,0" HorizontalAlignment="Center"/>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Map Elements
$btnScan = $window.FindName('BtnScan')
$btnSaveBaseline = $window.FindName('BtnSaveBaseline')
$btnCompare = $window.FindName('BtnCompare')
$btnHtmlReport = $window.FindName('BtnHtmlReport')
$btnOpenFolder = $window.FindName('BtnOpenFolder')
$bannerStatus = $window.FindName('BannerStatus')
$txtBannerTitle = $window.FindName('TxtBannerTitle')
$txtBannerDesc = $window.FindName('TxtBannerDesc')
$txtHash = $window.FindName('TxtHash')
$txtTime = $window.FindName('TxtTime')
$txtMb = $window.FindName('TxtMb')
$txtMbSn = $window.FindName('TxtMbSn')
$txtUuid = $window.FindName('TxtUuid')
$txtCpu = $window.FindName('TxtCpu')
$txtRamSummary = $window.FindName('TxtRamSummary')
$txtDiskSummary = $window.FindName('TxtDiskSummary')
$txtGpu = $window.FindName('TxtGpu')
$txtDetails = $window.FindName('TxtDetails')

$script:CurrentSnapshot = $null

# Action: Scan
$btnScan.Add_Click({
    $txtHash.Text = "Donanım taranıyor..."
    $snap = Get-HardwareSnapshotData
    $script:CurrentSnapshot = $snap

    $txtHash.Text = $snap.Hash
    $txtTime.Text = "Saat: $((Get-Date).ToString('HH:mm:ss'))"
    $txtMb.Text = "$($snap.Motherboard.Manufacturer) - $($snap.Motherboard.Product)"
    $txtMbSn.Text = $snap.Motherboard.SerialNumber
    $txtUuid.Text = $snap.Bios.UUID
    $txtCpu.Text = "$($snap.Processor.Name) ($($snap.Processor.Cores) Çekirdek)"

    $totalRam = 0
    foreach ($r in $snap.RAM) { $totalRam += [double]$r.CapacityGB }
    $txtRamSummary.Text = "$totalRam GB ($($snap.RAM.Count) Modül)"

    $diskSummary = ""
    foreach ($d in $snap.Disks) { $diskSummary += "$($d.Model) ($($d.SizeGB) GB) | " }
    $txtDiskSummary.Text = $diskSummary.TrimEnd(' ', '|')

    $gpuSummary = ""
    foreach ($g in $snap.GPU) { $gpuSummary += "$($g.Name), " }
    $txtGpu.Text = $gpuSummary.TrimEnd(' ', ',')

    $txtDetails.Text = ($snap | ConvertTo-Json -Depth 6)
})

# Action: Save Baseline
$btnSaveBaseline.Add_Click({
    if (-not $script:CurrentSnapshot) {
        $btnScan.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    }
    if ($script:CurrentSnapshot) {
        $json = $script:CurrentSnapshot | ConvertTo-Json -Depth 6
        [System.IO.File]::WriteAllText($script:BaselinePath, $json, [System.Text.Encoding]::UTF8)
        [System.Windows.MessageBox]::Show("Mevcut donanım konfigürasyonu ve SHA-256 hash değeri 'REFERANS BASELINE' olarak başarıyla kaydedildi!", "Başarılı", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# Action: Compare
$btnCompare.Add_Click({
    if (-not (Test-Path -LiteralPath $script:BaselinePath)) {
        [System.Windows.MessageBox]::Show("Henüz bir Referans Baseline kaydı bulunamadı! Lütfen önce 'Referans Kaydet' butonuna basın.", "Referans Yok", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    if (-not $script:CurrentSnapshot) {
        $btnScan.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    }

    $baselineJson = Get-Content -LiteralPath $script:BaselinePath -Raw -Encoding UTF8
    $baseline = $baselineJson | ConvertFrom-Json

    $bannerStatus.Visibility = [System.Windows.Visibility]::Visible

    if ($baseline.Hash -eq $script:CurrentSnapshot.Hash) {
        $bannerStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#14532D")
        $bannerStatus.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#22C55E")
        $txtBannerTitle.Text = "✓ DONANIM BÜTÜNLÜĞÜ TAM: HİÇBİR DEĞİŞİKLİK YOK"
        $txtBannerTitle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4ADE80")
        $txtBannerDesc.Text = "Cihazın anakart, RAM, disk, CPU ve ekran kartı kimlikleri referans kayıt ($($baseline.Timestamp)) ile %100 eşleşmektedir."
    } else {
        $bannerStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#7F1D1D")
        $bannerStatus.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444")
        $txtBannerTitle.Text = "⚠️ DİKKAT: DONANIM DEĞİŞİKLİĞİ TESPİT EDİLDİ!"
        $txtBannerTitle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F87171")
        $txtBannerDesc.Text = "Donanım parmak izi eşleşmiyor! Referans Hash: $($baseline.Hash) | Mevcut Hash: $($script:CurrentSnapshot.Hash)"
    }
})

# Action: Open Archive Folder
$btnOpenFolder.Add_Click({
    [System.Diagnostics.Process]::Start('explorer.exe', $script:BaseFolder)
})

# Action: HTML Report
$btnHtmlReport.Add_Click({
    if (-not $script:CurrentSnapshot) {
        $btnScan.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    }
    $reportPath = Join-Path $script:ReportFolder ("EkspertizRaporu_{0:yyyyMMdd_HHmmss}.html" -f (Get-Date))
    $html = @"
<!DOCTYPE html><html lang='tr'><head><meta charset='utf-8'/><title>Ekspertiz Raporu</title>
<style>
body { font-family: Segoe UI, sans-serif; background: #0f172a; color: #fff; padding: 24px; }
.card { background: #1e293b; padding: 24px; border-radius: 8px; max-width: 800px; margin: auto; }
h1 { color: #38bdf8; }
.hash { background: #000; padding: 12px; font-family: monospace; color: #38bdf8; word-break: break-all; }
</style></head><body>
<div class='card'>
<h1>🛠️ Donanım Ekspertiz Raporu</h1>
<p><strong>Cihaz:</strong> $($script:CurrentSnapshot.MachineName) | <strong>Tarih:</strong> $($script:CurrentSnapshot.Timestamp)</p>
<div class='hash'>SHA-256 Hash: $($script:CurrentSnapshot.Hash)</div>
<h2>Donanım Özeti</h2>
<p><strong>Anakart:</strong> $($script:CurrentSnapshot.Motherboard.Manufacturer) - $($script:CurrentSnapshot.Motherboard.Product) (SN: $($script:CurrentSnapshot.Motherboard.SerialNumber))</p>
<p><strong>İşlemci:</strong> $($script:CurrentSnapshot.Processor.Name)</p>
<p><strong>RAM:</strong> $($script:CurrentSnapshot.RAM.Count) Modül</p>
<p><strong>Diskler:</strong> $($script:CurrentSnapshot.Disks.Count) Adet</p>
</div></body></html>
"@
    [System.IO.File]::WriteAllText($reportPath, $html, [System.Text.Encoding]::UTF8)
    [System.Diagnostics.Process]::Start($reportPath)
})

# Auto scan on startup
$window.Add_Loaded({
    $btnScan.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
})

# Run Window
[void]$window.ShowDialog()
