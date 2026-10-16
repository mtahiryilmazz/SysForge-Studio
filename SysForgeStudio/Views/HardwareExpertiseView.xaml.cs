using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using SysForgeStudio.Models;
using SysForgeStudio.Services;

namespace SysForgeStudio.Views
{
    public partial class HardwareExpertiseView : UserControl
    {
        private HardwareSnapshot? _currentSnapshot;

        public HardwareExpertiseView()
        {
            InitializeComponent();
            Loaded += HardwareExpertiseView_Loaded;
        }

        private async void HardwareExpertiseView_Loaded(object sender, RoutedEventArgs e)
        {
            if (_currentSnapshot == null)
            {
                await PerformScanAsync();
            }
        }

        private async void BtnScan_Click(object sender, RoutedEventArgs e)
        {
            await PerformScanAsync();
        }

        private async System.Threading.Tasks.Task PerformScanAsync()
        {
            try
            {
                TxtHardwareHash.Text = "Donanım taranıyor ve parmak izi hesaplanıyor...";
                _currentSnapshot = await HardwareExpertiseService.Instance.CaptureSnapshotAsync();

                TxtHardwareHash.Text = _currentSnapshot.GlobalHardwareHash;
                TxtScanTimestamp.Text = $"Son Tarama: {_currentSnapshot.Timestamp:HH:mm:ss}";

                TxtMotherboard.Text = $"{_currentSnapshot.Motherboard.Manufacturer} - {_currentSnapshot.Motherboard.Product}";
                TxtMBSN.Text = _currentSnapshot.Motherboard.SerialNumber;
                TxtBiosUuid.Text = $"{_currentSnapshot.Bios.Version} | UUID: {_currentSnapshot.Bios.Uuid}";
                TxtCpu.Text = $"{_currentSnapshot.Processor.Name} ({_currentSnapshot.Processor.NumberOfCores} Core / {_currentSnapshot.Processor.NumberOfLogicalProcessors} Thread)";

                double totalRam = _currentSnapshot.RamModules.Sum(r => r.CapacityGB);
                TxtRamSummary.Text = $"{totalRam} GB ({_currentSnapshot.RamModules.Count} Modül)";

                double totalDisk = _currentSnapshot.Disks.Sum(d => d.SizeGB);
                TxtDiskSummary.Text = $"{totalDisk} GB ({_currentSnapshot.Disks.Count} Sürücü)";

                TxtGpuSummary.Text = string.Join(", ", _currentSnapshot.Gpus.Select(g => $"{g.Name} ({g.AdapterRamGB} GB)"));

                ListDisks.ItemsSource = _currentSnapshot.Disks;
                ListRam.ItemsSource = _currentSnapshot.RamModules;
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Donanım taraması sırasında hata oluştu: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private async void BtnSaveBaseline_Click(object sender, RoutedEventArgs e)
        {
            if (_currentSnapshot == null)
            {
                await PerformScanAsync();
            }

            if (_currentSnapshot != null)
            {
                try
                {
                    await HardwareExpertiseService.Instance.SaveBaselineAsync(_currentSnapshot);
                    MessageBox.Show("Mevcut donanım konfigürasyonu ve SHA-256 parmak izi 'REFERANS BASELINE' olarak başarıyla kaydedildi.\n\nİlerleyen tarihlerde yapılacak kıyaslamalarda bu kayıt temel alınacaktır.", "Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Referans kaydedilemedi: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private async void BtnCompare_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var baseline = await HardwareExpertiseService.Instance.LoadBaselineAsync();
                if (baseline == null)
                {
                    MessageBox.Show("Henüz kaydedilmiş bir 'Referans Baseline' bulunamadı!\nLütfen önce 'Referans (Baseline) Kaydet' butonuna basarak ilk kaydı oluşturun.", "Referans Bulunamadı", MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }

                if (_currentSnapshot == null)
                {
                    await PerformScanAsync();
                }

                if (_currentSnapshot == null) return;

                var result = HardwareExpertiseService.Instance.CompareSnapshots(baseline, _currentSnapshot);
                BannerComparison.Visibility = Visibility.Visible;

                if (result.IsIdentical)
                {
                    BannerComparison.Background = new SolidColorBrush(Color.FromRgb(16, 46, 25)); // Dark green
                    BannerComparison.BorderBrush = new SolidColorBrush(Color.FromRgb(34, 197, 94));
                    TxtComparisonTitle.Text = "✓ DONANIM BÜTÜNLÜĞÜ TAM: DEĞİŞİKLİK YOK";
                    TxtComparisonTitle.Foreground = new SolidColorBrush(Color.FromRgb(74, 222, 128));
                    TxtComparisonSummary.Text = $"Cihazın tüm parçaları (Anakart, RAM, Disk, CPU, GPU), {result.BaselineDate:dd.MM.yyyy HH:mm} tarihinde alınan referans kayıt ile %100 eşleşmektedir.";
                    ListDifferences.ItemsSource = null;
                }
                else
                {
                    BannerComparison.Background = new SolidColorBrush(Color.FromRgb(46, 16, 16)); // Dark red
                    BannerComparison.BorderBrush = new SolidColorBrush(Color.FromRgb(239, 68, 68));
                    TxtComparisonTitle.Text = "⚠️ DİKKAT: DONANIM DEĞİŞİKLİĞİ TESPİT EDİLDİ!";
                    TxtComparisonTitle.Foreground = new SolidColorBrush(Color.FromRgb(248, 113, 113));
                    TxtComparisonSummary.Text = $"Referans tarihten ({result.BaselineDate:dd.MM.yyyy HH:mm}) bugüne kadar {result.Differences.Count} adet donanım değişikliği saptandı:";
                    ListDifferences.ItemsSource = result.Differences;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Kıyaslama hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private async void BtnGenerateReport_Click(object sender, RoutedEventArgs e)
        {
            if (_currentSnapshot == null)
            {
                await PerformScanAsync();
            }

            if (_currentSnapshot != null)
            {
                try
                {
                    var baseline = await HardwareExpertiseService.Instance.LoadBaselineAsync();
                    HardwareComparisonResult? compare = null;
                    if (baseline != null)
                    {
                        compare = HardwareExpertiseService.Instance.CompareSnapshots(baseline, _currentSnapshot);
                    }

                    string reportPath = await HardwareExpertiseService.Instance.GenerateHtmlReportAsync(_currentSnapshot, compare);
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = reportPath,
                        UseShellExecute = true
                    });
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Rapor oluşturulamadı: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void BtnOpenArchive_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                string path = HardwareExpertiseService.Instance.BaseDirectory;
                if (!Directory.Exists(path)) Directory.CreateDirectory(path);
                Process.Start(new ProcessStartInfo
                {
                    FileName = path,
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Klasör açılamadı: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }
}
