using System.Windows;
using System.Windows.Controls;
using SysForgeStudio.Services;

namespace SysForgeStudio.Views
{
    public partial class FixesView : UserControl
    {
        public FixesView()
        {
            InitializeComponent();
        }

        private void BtnSelectAll_Click(object sender, RoutedEventArgs e)
        {
            SetAllChecks(true);
        }

        private void BtnSelectRecommended_Click(object sender, RoutedEventArgs e)
        {
            ChkRpcAuth.IsChecked = true;
            ChkRestrictAdmin.IsChecked = true;
            ChkNamedPipes.IsChecked = true;
            ChkFix709Lsa.IsChecked = true;
            ChkPointPrint.IsChecked = true;
            ChkUpdatePrompt.IsChecked = true;
            ChkSpoolerReset.IsChecked = true;
            ChkFirewall.IsChecked = true;
            ChkPrivateNetwork.IsChecked = true;
            ChkSmbGuest.IsChecked = true;
            ChkServices.IsChecked = true;
            ChkNtlm.IsChecked = false;
        }

        private void BtnClearSelection_Click(object sender, RoutedEventArgs e)
        {
            SetAllChecks(false);
        }

        private void SetAllChecks(bool val)
        {
            ChkRpcAuth.IsChecked = val;
            ChkRestrictAdmin.IsChecked = val;
            ChkNamedPipes.IsChecked = val;
            ChkFix709Lsa.IsChecked = val;
            ChkPointPrint.IsChecked = val;
            ChkUpdatePrompt.IsChecked = val;
            ChkSpoolerReset.IsChecked = val;
            ChkFirewall.IsChecked = val;
            ChkPrivateNetwork.IsChecked = val;
            ChkSmbGuest.IsChecked = val;
            ChkServices.IsChecked = val;
            ChkNtlm.IsChecked = val;
        }

        private async void BtnApplyFixes_Click(object sender, RoutedEventArgs e)
        {
            var engine = ToolkitEngine.Instance;

            // Önce yedek al
            await engine.CreateBackupAsync();

            if (ChkServices.IsChecked == true)
                await engine.FixServicesAsync();

            if (ChkSpoolerReset.IsChecked == true)
                await engine.ResetSpoolerAsync();

            if (ChkRpcAuth.IsChecked == true || ChkRestrictAdmin.IsChecked == true || ChkNamedPipes.IsChecked == true)
                await engine.FixRpc11bAnd709Async();

            if (ChkFix709Lsa.IsChecked == true)
                await engine.Fix709LsaAsync();

            if (ChkPointPrint.IsChecked == true || ChkUpdatePrompt.IsChecked == true)
                await engine.FixPointAndPrintAsync();

            if (ChkFirewall.IsChecked == true || ChkPrivateNetwork.IsChecked == true)
                await engine.FixFirewallAsync();

            if (ChkSmbGuest.IsChecked == true)
                await engine.FixSmbCompatibilityAsync();

            if (ChkNtlm.IsChecked == true)
                await engine.FixNtlmNetBiosAsync();

            MessageBox.Show("Seçilen onarımlar başarıyla uygulandı!\nDetayları Canlı Kayıtlar (Logs) sekmesinden inceleyebilirsiniz.", "Onarımlar Tamamlandı", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private async void BtnRestoreDefaults_Click(object sender, RoutedEventArgs e)
        {
            var res = MessageBox.Show("Sistemdeki yazıcı ve güvenlik politikaları varsayılan Windows fabrika ayarlarına döndürülecek. Onaylıyor musunuz?", "Varsayılanlara Sıfırlama", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (res == MessageBoxResult.Yes)
            {
                await ToolkitEngine.Instance.RestoreSecureDefaultsAsync();
                MessageBox.Show("Varsayılan güvenlik ilkeleri geri yüklendi.", "Sıfırlandı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }
    }
}
