using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using UltimateToolkit.Modern.Models;
using UltimateToolkit.Modern.Services;

namespace UltimateToolkit.Modern.Views
{
    public partial class NetworkScannerView : UserControl
    {
        private List<NetworkAdapterInfo> _adapters = new();
        private List<NetworkHostInfo> _scannedHosts = new();
        private List<RdpConnection> _savedRdp = new();
        private CancellationTokenSource? _scanCts;

        public NetworkScannerView()
        {
            InitializeComponent();
            Loaded += NetworkScannerView_Loaded;
            ToolkitEngine.Instance.ScanProgressChanged += OnScanProgress;
        }

        private void NetworkScannerView_Loaded(object sender, RoutedEventArgs e)
        {
            LoadAdapters();
            LoadSavedRdp();
        }

        private void LoadAdapters()
        {
            _adapters = ToolkitEngine.Instance.GetNetworkAdapters();
            CmbAdapters.Items.Clear();

            int selectedIndex = 0;
            for (int i = 0; i < _adapters.Count; i++)
            {
                var a = _adapters[i];
                string label = $"{a.Name} ({a.IPAddress}) - {a.Description}";
                CmbAdapters.Items.Add(label);

                // Auto-pick the adapter with a valid non-empty IPv4
                if (!string.IsNullOrEmpty(a.NetworkPrefix) && a.IPAddress != "-" && !a.IPAddress.StartsWith("169.254"))
                {
                    selectedIndex = i;
                }
            }

            if (CmbAdapters.Items.Count > 0)
            {
                CmbAdapters.SelectedIndex = selectedIndex;
            }
        }

        private void CmbAdapters_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            int idx = CmbAdapters.SelectedIndex;
            if (idx >= 0 && idx < _adapters.Count)
            {
                var a = _adapters[idx];
                TxtAdapterIP.Text = $"IP: {a.IPAddress}";
                TxtAdapterMask.Text = $"Mask: {a.SubnetMask}";
                TxtAdapterGateway.Text = $"Ağ Geçidi: {a.Gateway}";
                TxtAdapterDns.Text = $"DNS: {a.DnsServers}";
                TxtAdapterDhcp.Text = $"DHCP: {(a.IsDhcp ? "Aktif" : "Statik")}";

                if (!string.IsNullOrEmpty(a.NetworkPrefix))
                {
                    TxtSubnetPrefix.Text = a.NetworkPrefix;
                }
            }
        }

        private void BtnRefreshAdapters_Click(object sender, RoutedEventArgs e)
        {
            LoadAdapters();
        }

        private async void BtnStartScan_Click(object sender, RoutedEventArgs e)
        {
            string prefix = TxtSubnetPrefix.Text.Trim();
            if (string.IsNullOrEmpty(prefix))
            {
                MessageBox.Show("Lütfen geçerli bir alt ağ öneki girin (Örn: 192.168.1)", "Geçersiz Ağ", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            BtnStartScan.IsEnabled = false;
            BrdScanProgress.Visibility = Visibility.Visible;
            PbScan.Value = 0;
            TxtScanStatus.Text = $"Ağ taranıyor: {prefix}.0/24...";
            TxtScanPercent.Text = "0%";

            _scanCts = new CancellationTokenSource();

            try
            {
                _scannedHosts = await ToolkitEngine.Instance.ScanSubnetAsync(prefix, _scanCts.Token);
                GridHosts.ItemsSource = null;
                GridHosts.ItemsSource = _scannedHosts;
                TxtHostCount.Text = $"{_scannedHosts.Count} Cihaz";
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Tarama sırasında hata oluştu: {ex.Message}", "Tarama Hatası", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                BtnStartScan.IsEnabled = true;
                BrdScanProgress.Visibility = Visibility.Collapsed;
            }
        }

        private void OnScanProgress(int completed, int total)
        {
            Dispatcher.Invoke(() =>
            {
                PbScan.Maximum = total;
                PbScan.Value = completed;
                int pct = (int)((completed / (double)total) * 100);
                TxtScanStatus.Text = $"Ağ taranıyor... ({completed} / {total})";
                TxtScanPercent.Text = $"{pct}%";
            });
        }

        private void TxtFilterHosts_TextChanged(object sender, TextChangedEventArgs e)
        {
            string query = TxtFilterHosts.Text.Trim().ToLowerInvariant();
            if (string.IsNullOrEmpty(query))
            {
                GridHosts.ItemsSource = _scannedHosts;
            }
            else
            {
                GridHosts.ItemsSource = _scannedHosts.Where(h =>
                    h.IPAddress.ToLowerInvariant().Contains(query) ||
                    h.Hostname.ToLowerInvariant().Contains(query) ||
                    h.OpenPorts.ToLowerInvariant().Contains(query) ||
                    h.DeviceType.ToLowerInvariant().Contains(query) ||
                    h.OsGuess.ToLowerInvariant().Contains(query) ||
                    h.MacAddress.ToLowerInvariant().Contains(query)).ToList();
            }
        }

        private void BtnExportCsv_Click(object sender, RoutedEventArgs e)
        {
            if (_scannedHosts.Count == 0)
            {
                MessageBox.Show("Önce bir ağ taraması çalıştırın.", "Dışa Aktarma", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            try
            {
                string path = ToolkitEngine.Instance.ExportNetworkScanCsv(_scannedHosts);
                Process.Start("explorer.exe", $"/select,\"{path}\"");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"CSV dışa aktarılamadı: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnExportHtml_Click(object sender, RoutedEventArgs e)
        {
            if (_scannedHosts.Count == 0)
            {
                MessageBox.Show("Önce bir ağ taraması çalıştırın.", "Dışa Aktarma", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            try
            {
                string path = ToolkitEngine.Instance.ExportNetworkScanHtml(_scannedHosts);
                Process.Start(new ProcessStartInfo { FileName = path, UseShellExecute = true });
            }
            catch (Exception ex)
            {
                MessageBox.Show($"HTML rapor açılamadı: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        #region Host Actions

        private void BtnHostRdp_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.DataContext is NetworkHostInfo host)
            {
                ToolkitEngine.Instance.LaunchRdp(host.IPAddress);
            }
        }

        private void BtnHostSmb_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.DataContext is NetworkHostInfo host)
            {
                try
                {
                    Process.Start("explorer.exe", $@"\\{host.IPAddress}");
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Paylaşım açılamadı: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void BtnHostWeb_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.DataContext is NetworkHostInfo host)
            {
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = $"http://{host.IPAddress}",
                        UseShellExecute = true
                    });
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Web sayfası açılamadı: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void BtnHostCopy_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.DataContext is NetworkHostInfo host)
            {
                Clipboard.SetText(host.IPAddress);
                MessageBox.Show($"IP adresi panoya kopyalandı: {host.IPAddress}", "Kopyalandı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        #endregion

        #region RDP Manager

        private void LoadSavedRdp()
        {
            _savedRdp = ToolkitEngine.Instance.LoadRdpConnections();
            LstSavedRdp.ItemsSource = null;
            LstSavedRdp.ItemsSource = _savedRdp;
        }

        private void BtnLaunchRdp_Click(object sender, RoutedEventArgs e)
        {
            string target = TxtRdpTarget.Text.Trim();
            if (string.IsNullOrEmpty(target))
            {
                MessageBox.Show("Lütfen hedef IP veya bilgisayar adı girin.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            int port = 3389;
            int.TryParse(TxtRdpPort.Text.Trim(), out port);
            bool fs = ChkRdpFullScreen.IsChecked ?? true;

            ToolkitEngine.Instance.LaunchRdp(target, TxtRdpUser.Text.Trim(), port, fs);
        }

        private void BtnSaveRdp_Click(object sender, RoutedEventArgs e)
        {
            string target = TxtRdpTarget.Text.Trim();
            if (string.IsNullOrEmpty(target))
            {
                MessageBox.Show("Lütfen kaydedilecek bir hedef IP veya bilgisayar adı girin.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            int port = 3389;
            int.TryParse(TxtRdpPort.Text.Trim(), out port);

            var existing = _savedRdp.FirstOrDefault(r => r.Hostname.Equals(target, StringComparison.OrdinalIgnoreCase));
            if (existing != null)
            {
                existing.Username = TxtRdpUser.Text.Trim();
                existing.Port = port;
                existing.LastUsed = DateTime.Now;
            }
            else
            {
                _savedRdp.Add(new RdpConnection
                {
                    DisplayName = target,
                    Hostname = target,
                    Username = TxtRdpUser.Text.Trim(),
                    Port = port,
                    FullScreen = ChkRdpFullScreen.IsChecked ?? true,
                    LastUsed = DateTime.Now
                });
            }

            ToolkitEngine.Instance.SaveRdpConnections(_savedRdp);
            LoadSavedRdp();
            MessageBox.Show("Uzak masaüstü bağlantısı kaydedildi.", "Kaydedildi", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void BtnQuickConnectRdp_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.DataContext is RdpConnection conn)
            {
                ToolkitEngine.Instance.LaunchRdp(conn.Hostname, conn.Username, conn.Port, conn.FullScreen);
            }
        }

        private void BtnDeleteSavedRdp_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.DataContext is RdpConnection conn)
            {
                _savedRdp.Remove(conn);
                ToolkitEngine.Instance.SaveRdpConnections(_savedRdp);
                LoadSavedRdp();
            }
        }

        #endregion
    }
}
