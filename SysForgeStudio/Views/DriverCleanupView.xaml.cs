using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using SysForgeStudio.Models;
using SysForgeStudio.Services;

namespace SysForgeStudio.Views
{
    public partial class DriverCleanupView : UserControl
    {
        private List<DriverItem> _allDrivers = new List<DriverItem>();

        public DriverCleanupView()
        {
            InitializeComponent();
            Loaded += DriverCleanupView_Loaded;
        }

        private async void DriverCleanupView_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadDriversAsync();
        }

        private async System.Threading.Tasks.Task LoadDriversAsync()
        {
            _allDrivers = await ToolkitEngine.Instance.GetDriversAsync();
            DgDrivers.ItemsSource = _allDrivers;
        }

        private async void BtnRefreshDrivers_Click(object sender, RoutedEventArgs e)
        {
            await LoadDriversAsync();
        }

        private void BtnFilter_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn)
            {
                string tag = btn.Tag?.ToString() ?? string.Empty;
                if (string.IsNullOrEmpty(tag))
                {
                    DgDrivers.ItemsSource = _allDrivers;
                }
                else
                {
                    DgDrivers.ItemsSource = _allDrivers.Where(d => 
                        d.Manufacturer.Equals(tag, System.StringComparison.OrdinalIgnoreCase) ||
                        d.Name.Contains(tag, System.StringComparison.OrdinalIgnoreCase)).ToList();
                }
            }
        }

        private async void BtnDeleteDriver_Click(object sender, RoutedEventArgs e)
        {
            var selected = DgDrivers.SelectedItem as DriverItem;
            if (selected == null)
            {
                MessageBox.Show("Lütfen silmek istediğiniz sürücüyü listeden seçiniz.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var confirm = MessageBox.Show($"'{selected.Name}' sürücüsü ve ilişkili dosyaları kaldırılsın mı?", "Sürücü Kaldırma", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (confirm == MessageBoxResult.Yes)
            {
                await ToolkitEngine.Instance.RemoveDriverAsync(selected.Name);
                await LoadDriversAsync();
            }
        }

        private async void BtnCleanStore_Click(object sender, RoutedEventArgs e)
        {
            var confirm = MessageBox.Show("Sistemdeki kullanılmayan tüm OEM yazıcı sürücü paketleri temizlenecek. Devam edilsin mi?", "DriverStore Temizliği", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (confirm == MessageBoxResult.Yes)
            {
                await ToolkitEngine.Instance.CleanDriverStoreAsync();
                MessageBox.Show("Sürücü önbelleği ve paket temizliği tamamlandı.", "Tamamlandı", MessageBoxButton.OK, MessageBoxImage.Information);
                await LoadDriversAsync();
            }
        }
    }
}
