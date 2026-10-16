using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using UltimateToolkit.Modern.Models;
using UltimateToolkit.Modern.Services;

namespace UltimateToolkit.Modern.Views
{
    public partial class ConnectPrinterView : UserControl
    {
        public ConnectPrinterView()
        {
            InitializeComponent();
            Loaded += ConnectPrinterView_Loaded;
        }

        private async void ConnectPrinterView_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadPrintersAsync();
        }

        private async System.Threading.Tasks.Task LoadPrintersAsync()
        {
            var printers = await ToolkitEngine.Instance.GetPrintersAsync();
            DgPrinters.ItemsSource = printers;
            TxtListCount.Text = $"({printers.Count} yazıcı)";
        }

        private async void BtnRefresh_Click(object sender, RoutedEventArgs e)
        {
            await LoadPrintersAsync();
        }

        private async void BtnTestConnection_Click(object sender, RoutedEventArgs e)
        {
            string unc = TxtPrinterUnc.Text.Trim();
            if (string.IsNullOrWhiteSpace(unc))
            {
                MessageBox.Show("Lütfen test edilecek bir IP veya UNC adresi giriniz.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            bool ok = await ToolkitEngine.Instance.TestPreConnectAsync(unc);
            if (ok)
            {
                MessageBox.Show($"Hedef adrese bağlantı başarılı!\nSMB / Port 445 ve 139 yanıt veriyor.", "Bağlantı Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                MessageBox.Show($"Hedef adrese ulaşılamadı!\nLütfen IP adresini, paylaşım adını ve karşı makinenin güvenlik duvarını kontrol ediniz.", "Bağlantı Başarısız", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private async void BtnConnectPrinter_Click(object sender, RoutedEventArgs e)
        {
            string unc = TxtPrinterUnc.Text.Trim();
            if (string.IsNullOrWhiteSpace(unc))
            {
                MessageBox.Show("Lütfen bağlanacak yazıcının UNC yolunu giriniz.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            bool connected = await ToolkitEngine.Instance.ConnectPrinterAsync(unc);
            if (connected)
            {
                MessageBox.Show($"Yazıcı başarıyla bağlandı!\n{unc}", "Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
                await LoadPrintersAsync();
            }
            else
            {
                MessageBox.Show($"Yazıcı bağlanamadı!\n{unc}\n\nİpucu: 'Onarım Merkezi' sekmesinden RPC 11b, Point&Print ve SMB onarımlarını çalıştırıp tekrar deneyiniz.", "Bağlantı Hatası", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private async void BtnScanNetwork_Click(object sender, RoutedEventArgs e)
        {
            MessageBox.Show("Ağdaki paylaşılan yazıcılar taranıyor...\nSonuçları Canlı Kayıtlar (Logs) sekmesinden takip edebilirsiniz.", "Tarama Başlatıldı", MessageBoxButton.OK, MessageBoxImage.Information);
            await ToolkitEngine.Instance.RunCommandAsync("net view");
        }

        private PrinterItem? GetSelectedItem()
        {
            return DgPrinters.SelectedItem as PrinterItem;
        }

        private async void BtnSetDefault_Click(object sender, RoutedEventArgs e)
        {
            var item = GetSelectedItem();
            if (item == null)
            {
                MessageBox.Show("Lütfen önce listeden bir yazıcı seçiniz.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            await ToolkitEngine.Instance.SetDefaultPrinterAsync(item.Name);
            await LoadPrintersAsync();
        }

        private async void BtnPrintTest_Click(object sender, RoutedEventArgs e)
        {
            var item = GetSelectedItem();
            if (item == null)
            {
                MessageBox.Show("Lütfen önce listeden bir yazıcı seçiniz.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            await ToolkitEngine.Instance.PrintTestPageAsync(item.Name);
            MessageBox.Show($"'{item.Name}' için sınama sayfası yazdırma komutu gönderildi.", "Bilgi", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void BtnOpenQueue_Click(object sender, RoutedEventArgs e)
        {
            var item = GetSelectedItem();
            if (item == null)
            {
                MessageBox.Show("Lütfen önce listeden bir yazıcı seçiniz.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            ToolkitEngine.Instance.OpenQueue(item.Name);
        }

        private void BtnOpenProps_Click(object sender, RoutedEventArgs e)
        {
            var item = GetSelectedItem();
            if (item == null)
            {
                MessageBox.Show("Lütfen önce listeden bir yazıcı seçiniz.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            ToolkitEngine.Instance.OpenPrinterProperties(item.Name);
        }

        private async void BtnRemovePrinter_Click(object sender, RoutedEventArgs e)
        {
            var item = GetSelectedItem();
            if (item == null)
            {
                MessageBox.Show("Lütfen önce kaldırılacak yazıcıyı seçiniz.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var confirm = MessageBox.Show($"'{item.Name}' yazıcısı sistemden kaldırılsın mı?", "Kaldırma Onayı", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (confirm == MessageBoxResult.Yes)
            {
                await ToolkitEngine.Instance.RemovePrinterAsync(item.Name);
                await LoadPrintersAsync();
            }
        }
    }
}
