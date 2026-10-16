using System;
using System.Windows;
using System.Windows.Controls;
using SysForgeStudio.Services;

namespace SysForgeStudio.Views
{
    public partial class SystemRepairView : UserControl
    {
        public SystemRepairView()
        {
            InitializeComponent();
            Loaded += SystemRepairView_Loaded;
        }

        private async void SystemRepairView_Loaded(object sender, RoutedEventArgs e)
        {
            await RefreshMetricsAsync();
        }

        private async void BtnRefreshMetrics_Click(object sender, RoutedEventArgs e)
        {
            await RefreshMetricsAsync();
        }

        private async System.Threading.Tasks.Task RefreshMetricsAsync()
        {
            try
            {
                var metrics = await ToolkitEngine.Instance.GetPerformanceMetricsAsync();
                IcMetrics.ItemsSource = metrics;
            }
            catch { }
        }

        private async void BtnSfc_Click(object sender, RoutedEventArgs e)
        {
            var res = MessageBox.Show(
                "SFC /scannow (Sistem Dosyası Doğrulama) işlemi başlatılacak. Bu işlem birkaç dakika sürebilir.\n\nBaşlatılsın mı?",
                "SFC Taraması",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (res == MessageBoxResult.Yes)
            {
                await ToolkitEngine.Instance.RunSfcScanAsync();
                MessageBox.Show("SFC taraması tamamlandı! Sonuçları Canlı Kayıtlar (Logs) sekmesinden inceleyebilirsiniz.", "Bilgi", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private async void BtnDism_Click(object sender, RoutedEventArgs e)
        {
            var res = MessageBox.Show(
                "DISM /RestoreHealth (Bileşen Deposu Onarımı) işlemi başlatılacak. İnternet bağlantısı gerektirebilir.\n\nBaşlatılsın mı?",
                "DISM Onarımı",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (res == MessageBoxResult.Yes)
            {
                await ToolkitEngine.Instance.RunDismRepairAsync();
                MessageBox.Show("DISM bileşen onarımı tamamlandı!", "Bilgi", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private async void BtnResetNetwork_Click(object sender, RoutedEventArgs e)
        {
            var res = MessageBox.Show(
                "TCP/IP ve Winsock sıfırlanacak. İşlem tamamlandıktan sonra bilgisayarı yeniden başlatmanız önerilir.\n\nOnaylıyor musunuz?",
                "Ağ Sıfırlama",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning);

            if (res == MessageBoxResult.Yes)
            {
                await ToolkitEngine.Instance.ResetNetworkStackAsync();
                MessageBox.Show("Ağ yığını başarıyla sıfırlandı. Değişikliklerin tam uygulanması için bilgisayarı yeniden başlatın.", "Ağ Sıfırlandı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private async void BtnResetUpdate_Click(object sender, RoutedEventArgs e)
        {
            var res = MessageBox.Show(
                "Windows Update servisleri durdurulup SoftwareDistribution önbelleği sıfırlanacak.\n\nDevam edilsin mi?",
                "Windows Update Sıfırlama",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (res == MessageBoxResult.Yes)
            {
                await ToolkitEngine.Instance.ResetWindowsUpdateAsync();
                MessageBox.Show("Windows Update servisleri ve önbellek klasörleri sıfırlandı.", "Bilgi", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private async void BtnCleanTemp_Click(object sender, RoutedEventArgs e)
        {
            await ToolkitEngine.Instance.CleanTempFilesAsync();
            await RefreshMetricsAsync();
            MessageBox.Show("Geçici ve gereksiz dosyalar temizlendi.", "Temizlik Tamamlandı", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }
}
