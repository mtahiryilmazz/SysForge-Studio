using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using UltimateToolkit.Modern.Models;
using UltimateToolkit.Modern.Services;

namespace UltimateToolkit.Modern.Views
{
    public partial class BackupView : UserControl
    {
        public BackupView()
        {
            InitializeComponent();
            Loaded += BackupView_Loaded;
        }

        private void BackupView_Loaded(object sender, RoutedEventArgs e)
        {
            LoadBackups();
        }

        private void LoadBackups()
        {
            var backups = ToolkitEngine.Instance.GetBackups();
            DgBackups.ItemsSource = backups;
        }

        private async void BtnCreateBackup_Click(object sender, RoutedEventArgs e)
        {
            string path = await ToolkitEngine.Instance.CreateBackupAsync();
            if (!string.IsNullOrEmpty(path))
            {
                MessageBox.Show($"Yeni yedek başarıyla oluşturuldu:\n{Path.GetFileName(path)}", "Yedek Alındı", MessageBoxButton.OK, MessageBoxImage.Information);
                LoadBackups();
            }
        }

        private async void BtnRestore_Click(object sender, RoutedEventArgs e)
        {
            var item = DgBackups.SelectedItem as BackupItem;
            if (item == null)
            {
                MessageBox.Show("Lütfen geri yüklenecek bir yedek dosyası seçiniz.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var confirm = MessageBox.Show($"'{item.FileName}' yedeği geri yüklenecek ve Spooler sıfırlanacak. Onaylıyor musunuz?", "Geri Yükleme Onayı", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (confirm == MessageBoxResult.Yes)
            {
                await ToolkitEngine.Instance.RestoreBackupAsync(item.FullPath);
                MessageBox.Show("Yedek başarıyla geri yüklendi.", "Tamamlandı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void BtnOpenFolder_Click(object sender, RoutedEventArgs e)
        {
            if (Directory.Exists(ToolkitEngine.Instance.BackupDirectory))
            {
                Process.Start(new ProcessStartInfo { FileName = ToolkitEngine.Instance.BackupDirectory, UseShellExecute = true });
            }
        }
    }
}
