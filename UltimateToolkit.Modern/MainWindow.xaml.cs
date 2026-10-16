using System;
using System.Windows;
using System.Windows.Controls;
using UltimateToolkit.Modern.Services;
using UltimateToolkit.Modern.Views;

namespace UltimateToolkit.Modern
{
    public partial class MainWindow : Window
    {
        private DashboardView? _dashboardView;
        private ConnectPrinterView? _printersView;
        private NetworkScannerView? _networkView;
        private FixesView? _fixesView;
        private DriverCleanupView? _driversView;
        private DiagnosticsView? _diagView;
        private ToolsView? _toolsView;
        private SystemRepairView? _sysRepairView;
        private LegacyModulesView? _legacyView;
        private HardwareExpertiseView? _expertiseView;
        private ITTechServiceView? _itServiceView;
        private LogsView? _logsView;
        private BackupView? _backupView;

        public MainWindow()
        {
            InitializeComponent();

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
            _expertiseView = new HardwareExpertiseView();
            _itServiceView = new ITTechServiceView();
            _logsView = new LogsView();
            _backupView = new BackupView();

            ToolkitEngine.Instance.BusyChanged += OnBusyChanged;

            // Set default view
            MainContent.Content = _dashboardView;
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
                    TxtHeaderTitle.Text = "Yazıcı Bağla & Keşif";
                    TxtHeaderSubtitle.Text = "Ağdaki paylaşılan yazıcıları tara, UNC adresi ile bağla ve yönet";
                    if (_printersView != null) MainContent.Content = _printersView;
                    break;

                case nameof(NavNetwork):
                    TxtHeaderTitle.Text = "IP Tarama, Ağ Keşfi & Uzak Masaüstü";
                    TxtHeaderSubtitle.Text = "Ağ kartından IP altyapısını tespit et, 254 cihazı tara, açık portları bul ve RDP ile bağlan";
                    if (_networkView != null) MainContent.Content = _networkView;
                    break;

                case nameof(NavDrivers):
                    TxtHeaderTitle.Text = "Sürücü Temizliği & Yönetimi";
                    TxtHeaderSubtitle.Text = "Yüklü yazıcı sürücülerini marka bazlı filtrele, bozuk paketleri temizle";
                    if (_driversView != null) MainContent.Content = _driversView;
                    break;

                case nameof(NavFixes):
                    TxtHeaderTitle.Text = "Yazıcı Hızlı Onarım & Tweaks";
                    TxtHeaderSubtitle.Text = "0x0000011b, 709, Point&Print, Spooler ve SMB paylaşımlarını tek tıkla onar";
                    if (_fixesView != null) MainContent.Content = _fixesView;
                    break;

                case nameof(NavSysRepair):
                    TxtHeaderTitle.Text = "Windows Çekirdek Onarım & Performans";
                    TxtHeaderSubtitle.Text = "SFC, DISM, TCP/IP ağ sıfırlama, Windows Update onarımı ve disk temizliği";
                    if (_sysRepairView != null) MainContent.Content = _sysRepairView;
                    break;

                case nameof(NavDiag):
                    TxtHeaderTitle.Text = "Sistem Teşhisi & Doğrulama";
                    TxtHeaderSubtitle.Text = "Kayıt defteri, güvenlik ilkeleri ve servis durumlarını tarayarak sorunları tespit et";
                    if (_diagView != null) MainContent.Content = _diagView;
                    break;

                case nameof(NavTools):
                    TxtHeaderTitle.Text = "Windows Yazıcı ve Sistem Araçları";
                    TxtHeaderSubtitle.Text = "Klasik yazıcı konsolları, servisler, kuyruk klasörü ve yönetim araçları";
                    if (_toolsView != null) MainContent.Content = _toolsView;
                    break;

                case nameof(NavModules):
                    TxtHeaderTitle.Text = "Entegre Gelişmiş Motorlar (v6, v5, Printer Pro)";
                    TxtHeaderSubtitle.Text = "v6 Web Dashboard (Port 9999), 37 modüllü v5 IT konsolu, Printer Analyzer ve sandbox temizliği";
                    if (_legacyView != null) MainContent.Content = _legacyView;
                    break;

                case nameof(NavExpertise):
                    TxtHeaderTitle.Text = "Donanım Ekspertizi & Kimlik Doğrulama";
                    TxtHeaderSubtitle.Text = "Anakart, BIOS, RAM, Disk ve GPU seri numaraları, SHA-256 hash ve donanım değişikliği tespiti";
                    if (_expertiseView != null) MainContent.Content = _expertiseView;
                    break;

                case nameof(NavITService):
                    TxtHeaderTitle.Text = "BT Teknik Servis & Vanguard Portali";
                    TxtHeaderSubtitle.Text = "Arıza çağrıları (Tickets), donanım zimmet takibi, teknisyen logları ve yerel web konsolu";
                    if (_itServiceView != null) MainContent.Content = _itServiceView;
                    break;

                case nameof(NavLogs):
                    TxtHeaderTitle.Text = "Canlı Çıktı & Terminal";
                    TxtHeaderSubtitle.Text = "Çalıştırılan onarımların ve komutların anlık terminal çıktısı";
                    if (_logsView != null) MainContent.Content = _logsView;
                    break;

                case nameof(NavBackup):
                    TxtHeaderTitle.Text = "Sistem & Yazıcı Yedeği";
                    TxtHeaderSubtitle.Text = "Kayıt defteri yazdırma yapılandırmalarını yedekleyin ve geri yükleyin";
                    if (_backupView != null) MainContent.Content = _backupView;
                    break;
            }
        }
    }
}