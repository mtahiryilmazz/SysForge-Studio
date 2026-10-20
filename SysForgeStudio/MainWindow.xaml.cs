using System;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using SysForgeStudio.Services;
using SysForgeStudio.Views;

namespace SysForgeStudio
{
    public partial class MainWindow : Window
    {
        private bool _isLightTheme;
        private static string ThemePreferencePath => Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "SysForgeStudio", "theme.txt");

        private DashboardView? _dashboardView;
        private ConnectPrinterView? _printersView;
        private NetworkScannerView? _networkView;
        private FixesView? _fixesView;
        private DriverCleanupView? _driversView;
        private DiagnosticsView? _diagView;
        private ToolsView? _toolsView;
        private SystemRepairView? _sysRepairView;
        private LegacyModulesView? _legacyView;
        private AIDiagnosticView? _aiDiagView;
        private HardwareExpertiseView? _expertiseView;
        private ITTechServiceView? _itServiceView;
        private LogsView? _logsView;
        private BackupView? _backupView;

        public MainWindow()
        {
            InitializeComponent();
            ApplyTheme(LoadLightTheme(), persist: false);

            _dashboardView = new DashboardView();
            _dashboardView.NavigateToPrintersRequested += () => NavPrinters.IsChecked = true;

            _printersView = new ConnectPrinterView();
            _networkView = new NetworkScannerView();
            _fixesView = new FixesView();
            _driversView = new DriverCleanupView();
            _diagView = new DiagnosticsView();
            _toolsView = new ToolsView();
            _sysRepairView = new SystemRepairView();
            _legacyView = new LegacyModulesView();
            _legacyView.NavigateToPrintersRequested += () => NavPrinters.IsChecked = true;
            _aiDiagView = new AIDiagnosticView();
            _expertiseView = new HardwareExpertiseView();
            _itServiceView = new ITTechServiceView();
            _logsView = new LogsView();
            _backupView = new BackupView();

            ToolkitEngine.Instance.BusyChanged += OnBusyChanged;

            // Set default view
            MainContent.Content = _dashboardView;
        }

        private static bool LoadLightTheme()
        {
            try
            {
                return File.Exists(ThemePreferencePath) &&
                       string.Equals(File.ReadAllText(ThemePreferencePath).Trim(), "light", StringComparison.OrdinalIgnoreCase);
            }
            catch
            {
                return false;
            }
        }

        private void ApplyTheme(bool light, bool persist)
        {
            _isLightTheme = light;
            var palette = light
                ? new (string Key, string Value)[]
                {
                    // Pencereler, Paneller ve Kartlar
                    ("PtWindowBg", "#FFF4F7FB"),
                    ("PtSidebarBg", "#FFE9F0F8"),
                    ("PtCardBg", "#FFFFFFFF"),
                    ("PtCardHover", "#FFF0F4F9"),
                    ("PtCardBorder", "#FFD0DCE7"),
                    ("PtSubtleBg", "#FFF1F5F9"),

                    // Vurgu & Genel
                    ("PtAccent", "#FF0078D4"),
                    ("PtAccentHover", "#FF006CBE"),
                    ("PtSuccess", "#FF15803D"),
                    ("PtWarning", "#FFB45309"),
                    ("PtDanger", "#FFDC2626"),

                    // Tipografi
                    ("PtTextPrimary", "#FF0F172A"),
                    ("PtTextSecondary", "#FF475569"),
                    ("PtTextMuted", "#FF64748B"),

                    // İkincil Butonlar
                    ("PtButtonBg", "#FFFFFFFF"),
                    ("PtButtonBorder", "#FFCBD5E1"),
                    ("PtButtonHover", "#FFE2E8F0"),
                    ("PtButtonPressed", "#FFCBD5E1"),
                    ("PtButtonForeground", "#FF0F172A"),

                    // Navigasyon & Seçim
                    ("PtNavHover", "#FFE2E8F0"),
                    ("PtNavActive", "#FFD9E6F2"),

                    // Girdi & Rozetler
                    ("PtInputBg", "#FFFFFFFF"),
                    ("PtInputBorder", "#FFCBD5E1"),
                    ("PtBadgeBg", "#FFE2E8F0"),

                    // Veri Tablosu
                    ("PtGridRow", "#FFFFFFFF"),
                    ("PtGridRowAlt", "#FFF8FAFC"),
                    ("PtGridHeader", "#FFEAEFF6"),

                    // Durum Renkleri (Açık tema için yüksek kontrastlı)
                    ("PtStatusBlue", "#FF0284C7"),
                    ("PtStatusGreen", "#FF16A34A"),
                    ("PtStatusYellow", "#FFD97706"),
                    ("PtStatusAmber", "#FFD97706"),
                    ("PtStatusRed", "#FFDC2626"),
                    ("PtStatusPurple", "#FF7C3AED"),

                    // Kod & Terminal
                    ("PtCodeBackground", "#FFF1F5F9"),
                    ("PtCodeForeground", "#FF0369A1")
                }
                : new (string Key, string Value)[]
                {
                    // Pencereler, Paneller ve Kartlar
                    ("PtWindowBg", "#FF202020"),
                    ("PtSidebarBg", "#FF181818"),
                    ("PtCardBg", "#FF2B2B2B"),
                    ("PtCardHover", "#FF323232"),
                    ("PtCardBorder", "#FF383838"),
                    ("PtSubtleBg", "#FF262626"),

                    // Vurgu & Genel
                    ("PtAccent", "#FF0078D4"),
                    ("PtAccentHover", "#FF1A86D9"),
                    ("PtSuccess", "#FF107C41"),
                    ("PtWarning", "#FFD83B01"),
                    ("PtDanger", "#FFDC2626"),

                    // Tipografi
                    ("PtTextPrimary", "#FFFFFFFF"),
                    ("PtTextSecondary", "#FFA6A6A6"),
                    ("PtTextMuted", "#FF888888"),

                    // İkincil Butonlar
                    ("PtButtonBg", "#FF2E2E2E"),
                    ("PtButtonBorder", "#FF404040"),
                    ("PtButtonHover", "#FF3A3A3A"),
                    ("PtButtonPressed", "#FF222222"),
                    ("PtButtonForeground", "#FFFFFFFF"),

                    // Navigasyon & Seçim
                    ("PtNavHover", "#FF2D2D2D"),
                    ("PtNavActive", "#FF333333"),

                    // Girdi & Rozetler
                    ("PtInputBg", "#FF262626"),
                    ("PtInputBorder", "#FF383838"),
                    ("PtBadgeBg", "#FF333333"),

                    // Veri Tablosu
                    ("PtGridRow", "#FF2B2B2B"),
                    ("PtGridRowAlt", "#FF303030"),
                    ("PtGridHeader", "#FF333333"),

                    // Durum Renkleri (Koyu tema için canlı renkler)
                    ("PtStatusBlue", "#FF38BDF8"),
                    ("PtStatusGreen", "#FF4ADE80"),
                    ("PtStatusYellow", "#FFFDE047"),
                    ("PtStatusAmber", "#FFF59E0B"),
                    ("PtStatusRed", "#FFF87171"),
                    ("PtStatusPurple", "#FFA78BFA"),

                    // Kod & Terminal
                    ("PtCodeBackground", "#FF1E1E1E"),
                    ("PtCodeForeground", "#FF38BDF8")
                };

            foreach (var entry in palette)
            {
                var color = (Color)ColorConverter.ConvertFromString(entry.Value);
                Application.Current.Resources[entry.Key] = new SolidColorBrush(color);
            }

            BtnThemeToggle.Content = light ? "☀ Açık tema" : "🌙 Koyu tema";
            BtnThemeToggle.ToolTip = light ? "Şu an Açık Tema aktif. Koyu temaya geçmek için tıklayın." : "Şu an Koyu Tema aktif. Açık temaya geçmek için tıklayın.";

            if (persist)
            {
                try
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(ThemePreferencePath)!);
                    File.WriteAllText(ThemePreferencePath, light ? "light" : "dark");
                }
                catch
                {
                    // Theme changes still apply for this session if preference storage is unavailable.
                }
            }
        }

        private void BtnThemeToggle_Click(object sender, RoutedEventArgs e)
        {
            ApplyTheme(!_isLightTheme, persist: true);
        }

        private void OnBusyChanged(bool isBusy)
        {
            Dispatcher.Invoke(() =>
            {
                if (PbBusy != null)
                {
                    PbBusy.Visibility = isBusy ? Visibility.Visible : Visibility.Collapsed;
                }
            });
        }

        private void TxtSearch_TextChanged(object sender, TextChangedEventArgs e)
        {
            string query = TxtSearch.Text.Trim().ToLowerInvariant();
            if (string.IsNullOrEmpty(query)) return;

            if (query.Contains("ip") || query.Contains("ağ") || query.Contains("ping") || query.Contains("subnet") || query.Contains("rdp") || query.Contains("uzak masaüstü"))
            {
                NavNetwork.IsChecked = true;
            }
            else if (query.Contains("v6") || query.Contains("v5") || query.Contains("motor") || query.Contains("analyzer") || query.Contains("legacy") || query.Contains("bat") || query.Contains("modül"))
            {
                NavModules.IsChecked = true;
            }
            else if (query.Contains("sfc") || query.Contains("dism") || query.Contains("çekirdek") || query.Contains("winsock") || query.Contains("temp") || query.Contains("ram"))
            {
                NavSysRepair.IsChecked = true;
            }
            else if (query.Contains("yazıcı") || query.Contains("print") || query.Contains("bağla") || query.Contains("unc"))
            {
                NavPrinters.IsChecked = true;
            }
            else if (query.Contains("onarım") || query.Contains("fix") || query.Contains("11b") || query.Contains("709") || query.Contains("smb") || query.Contains("point"))
            {
                NavFixes.IsChecked = true;
            }
            else if (query.Contains("sürücü") || query.Contains("driver") || query.Contains("hp") || query.Contains("canon"))
            {
                NavDrivers.IsChecked = true;
            }
            else if (query.Contains("teşhis") || query.Contains("diag") || query.Contains("tara") || query.Contains("test"))
            {
                NavDiag.IsChecked = true;
            }
            else if (query.Contains("araç") || query.Contains("tool") || query.Contains("servis") || query.Contains("gpupdate"))
            {
                NavTools.IsChecked = true;
            }
            else if (query.Contains("log") || query.Contains("kayıt") || query.Contains("terminal") || query.Contains("rapor"))
            {
                NavLogs.IsChecked = true;
            }
            else if (query.Contains("yedek") || query.Contains("backup"))
            {
                NavBackup.IsChecked = true;
            }
            else if (query.Contains("ai") || query.Contains("yapay") || query.Contains("zeka") || query.Contains("hata") || query.Contains("çözüm"))
            {
                NavAIDiag.IsChecked = true;
            }
            else if (query.Contains("ekspertiz") || query.Contains("donanım") || query.Contains("hash") || query.Contains("md5") || query.Contains("sha") || query.Contains("ram") || query.Contains("seri"))
            {
                NavExpertise.IsChecked = true;
            }
            else if (query.Contains("vanguard") || query.Contains("it") || query.Contains("servis") || query.Contains("ticket") || query.Contains("envanter") || query.Contains("portal"))
            {
                NavITService.IsChecked = true;
            }
        }

        private void Nav_Checked(object sender, RoutedEventArgs e)
        {
            if (sender is not RadioButton rb) return;
            if (TxtHeaderTitle == null || TxtHeaderSubtitle == null || MainContent == null) return;

            switch (rb.Name)
            {
                case nameof(NavDashboard):
                    TxtHeaderTitle.Text = "Genel Bakış & Durum";
                    TxtHeaderSubtitle.Text = "Sistem yazdırma durumu, algılanan rol ve hızlı eylemler";
                    if (_dashboardView != null) MainContent.Content = _dashboardView;
                    break;

                case nameof(NavPrinters):
                    TxtHeaderTitle.Text = "Ağ Yazıcısı Bağlantısı & Keşif";
                    TxtHeaderSubtitle.Text = "Ağdaki paylaşılan yazıcıları tara, UNC adresi ile bağla ve yönet";
                    if (_printersView != null) MainContent.Content = _printersView;
                    break;

                case nameof(NavNetwork):
                    TxtHeaderTitle.Text = "IP Tarama & Ağ Keşfi (RDP)";
                    TxtHeaderSubtitle.Text = "Ağ kartından IP altyapısını tespit et, 254 cihazı tara, açık portları bul ve RDP ile bağlan";
                    if (_networkView != null) MainContent.Content = _networkView;
                    break;

                case nameof(NavDrivers):
                    TxtHeaderTitle.Text = "Sürücü Temizliği & Paket Yönetimi";
                    TxtHeaderSubtitle.Text = "Yüklü yazıcı sürücülerini marka bazlı filtrele, artık ve bozuk paketleri temizle";
                    if (_driversView != null) MainContent.Content = _driversView;
                    break;

                case nameof(NavFixes):
                    TxtHeaderTitle.Text = "Yazıcı & Spooler Hızlı Onarım";
                    TxtHeaderSubtitle.Text = "0x0000011b, 709, Point&Print, Spooler ve SMB paylaşımlarını tek tıkla onar";
                    if (_fixesView != null) MainContent.Content = _fixesView;
                    break;

                case nameof(NavSysRepair):
                    TxtHeaderTitle.Text = "Windows Çekirdek Onarımı";
                    TxtHeaderSubtitle.Text = "SFC, DISM, TCP/IP ağ sıfırlama, Windows Update onarımı ve disk temizliği";
                    if (_sysRepairView != null) MainContent.Content = _sysRepairView;
                    break;

                case nameof(NavDiag):
                    TxtHeaderTitle.Text = "Sistem Servis & İlke Teşhisi";
                    TxtHeaderSubtitle.Text = "Kayıt defteri, güvenlik ilkeleri ve servis durumlarını tarayarak sorunları tespit et";
                    if (_diagView != null) MainContent.Content = _diagView;
                    break;

                case nameof(NavTools):
                    TxtHeaderTitle.Text = "Windows BT Sistem Araçları";
                    TxtHeaderSubtitle.Text = "Klasik yazıcı konsolları, servisler, kuyruk klasörü ve IT yönetim araçları";
                    if (_toolsView != null) MainContent.Content = _toolsView;
                    break;

                case nameof(NavModules):
                    TxtHeaderTitle.Text = "SysForge Entegre Motor Merkezi";
                    TxtHeaderSubtitle.Text = "SysForge Web Paneli (Port 9999), 37 modüllü IT motoru, Yazıcı Analizörü ve sistem temizliği";
                    if (_legacyView != null) MainContent.Content = _legacyView;
                    break;

                case nameof(NavAIDiag):
                    TxtHeaderTitle.Text = "Yapay Zeka Arıza Teşhis & Onarım";
                    TxtHeaderSubtitle.Text = "Hata kodları ve donanım arızaları için kök neden analizi ve tek tıkla otomatik onarım komutları";
                    if (_aiDiagView != null) MainContent.Content = _aiDiagView;
                    break;

                case nameof(NavExpertise):
                    TxtHeaderTitle.Text = "Donanım Ekspertizi & HWID Hash";
                    TxtHeaderSubtitle.Text = "Anakart, BIOS, RAM, Disk ve GPU seri numaraları, SHA-256 hash ve donanım değişikliği tespiti";
                    if (_expertiseView != null) MainContent.Content = _expertiseView;
                    break;

                case nameof(NavITService):
                    TxtHeaderTitle.Text = "BT Servis Masası & Donanım Zimmet";
                    TxtHeaderSubtitle.Text = "Arıza çağrıları (Tickets), donanım zimmet takibi, teknisyen logları ve yerel web konsolu";
                    if (_itServiceView != null) MainContent.Content = _itServiceView;
                    break;

                case nameof(NavLogs):
                    TxtHeaderTitle.Text = "Canlı Terminal & Çıktı Günlüğü";
                    TxtHeaderSubtitle.Text = "Çalıştırılan onarımların ve komutların anlık terminal çıktısı";
                    if (_logsView != null) MainContent.Content = _logsView;
                    break;

                case nameof(NavBackup):
                    TxtHeaderTitle.Text = "Kayıt Defteri & Yapılandırma Yedeği";
                    TxtHeaderSubtitle.Text = "Kayıt defteri yazdırma yapılandırmalarını yedekleyin ve geri yükleyin";
                    if (_backupView != null) MainContent.Content = _backupView;
                    break;
            }
        }
    }
}
