using System;
using System.Windows;
using System.Windows.Controls;
using SysForgeStudio.Services;

namespace SysForgeStudio.Views
{
    public partial class DashboardView : UserControl
    {
        public event Action? NavigateToPrintersRequested;

        public DashboardView()
        {
            InitializeComponent();
            Loaded += DashboardView_Loaded;
        }

        private async void DashboardView_Loaded(object sender, RoutedEventArgs e)
        {
            var engine = ToolkitEngine.Instance;
            bool isAdmin = engine.IsAdministrator();
            TxtAdminStatus.Text = isAdmin ? "🛡️ Yönetici: Aktif (Tam Yetki)" : "⚠️ Yönetici: Yetkisiz (Yönetici Başlatın)";
            TxtAdminStatus.Foreground = isAdmin ? (System.Windows.Media.Brush)FindResource("SuccessBrush") : (System.Windows.Media.Brush)FindResource("DangerBrush");

            string spooler = engine.GetSpoolerStatus();
            TxtSpoolerStatus.Text = $"🖨️ Spooler: {spooler}";
            TxtSpoolerStatus.Foreground = spooler.Equals("Running", StringComparison.OrdinalIgnoreCase) 
                ? (System.Windows.Media.Brush)FindResource("SuccessBrush") 
                : (System.Windows.Media.Brush)FindResource("DangerBrush");

            string role = await engine.DetectRoleAsync();
            TxtRoleStatus.Text = $"🌐 Rol: {role}";

            var printers = await engine.GetPrintersAsync();
            TxtPrinterCount.Text = printers.Count.ToString();
        }

        private async void BtnSmartWorkflow_Click(object sender, RoutedEventArgs e)
        {
            var res = MessageBox.Show(
                "Akıllı Otomatik Onarım Akışı başlatılacak:\n\n- Kayıt defteri yedeği alınacak\n- Spooler ve kuyruk sıfırlanacak\n- 0x0000011b ve 709 RPC ayarları onarılacak\n- Point & Print kısıtlamaları açılacak\n- Güvenlik duvarı ve servisler yapılandırılacak\n\nDevam etmek istiyor musunuz?",
                "Akıllı Onarım Onayı",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (res == MessageBoxResult.Yes)
            {
                await ToolkitEngine.Instance.RunSmartAutoWorkflowAsync();
                MessageBox.Show("Akıllı onarım akışı tamamlandı! Canlı Kayıtlar (Logs) sekmesinden detayları görebilirsiniz.", "Tamamlandı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void BtnGoPrinters_Click(object sender, RoutedEventArgs e)
        {
            NavigateToPrintersRequested?.Invoke();
        }

        private async void BtnResetSpooler_Click(object sender, RoutedEventArgs e)
        {
            await ToolkitEngine.Instance.ResetSpoolerAsync();
            TxtSpoolerStatus.Text = $"🖨️ Spooler: {ToolkitEngine.Instance.GetSpoolerStatus()}";
            MessageBox.Show("Yazdırma Biriktiricisi başarıyla sıfırlandı ve başlatıldı.", "Bilgi", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private async void BtnQuickBackup_Click(object sender, RoutedEventArgs e)
        {
            string path = await ToolkitEngine.Instance.CreateBackupAsync();
            if (!string.IsNullOrEmpty(path))
            {
                MessageBox.Show($"Yedekleme oluşturuldu:\n{path}", "Yedek Alındı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private async void BtnFixRpc_Click(object sender, RoutedEventArgs e)
        {
            await ToolkitEngine.Instance.FixRpc11bAnd709Async();
            await ToolkitEngine.Instance.Fix709LsaAsync();
            MessageBox.Show("RPC 0x0000011b & 709 (LSA) kayıt defteri onarımı tamamlandı.", "Onarım Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private async void BtnFixPointPrint_Click(object sender, RoutedEventArgs e)
        {
            await ToolkitEngine.Instance.FixPointAndPrintAsync();
            MessageBox.Show("Point & Print sürücü indirme izinleri açıldı.", "Onarım Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private async void BtnFixFirewall_Click(object sender, RoutedEventArgs e)
        {
            await ToolkitEngine.Instance.FixFirewallAsync();
            MessageBox.Show("Yazıcı ve dosya paylaşım güvenlik duvarı izinleri uygulandı.", "Onarım Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }
}
