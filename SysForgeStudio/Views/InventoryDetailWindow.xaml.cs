using System;
using System.Windows;
using SysForgeStudio.Models;

namespace SysForgeStudio.Views
{
    public partial class InventoryDetailWindow : Window
    {
        private readonly InventoryItem _item;

        public InventoryDetailWindow(InventoryItem item)
        {
            InitializeComponent();
            _item = item ?? throw new ArgumentNullException(nameof(item));
            PopulateData();
        }

        private void PopulateData()
        {
            TxtHeaderTitle.Text = $"💻 {_item.Location} - Donanım & Yazılım Detayı";
            TxtHeaderSub.Text = $"Kayıt Tarihi: {_item.Date} | Zimmetli Personel: {_item.UserName} ({_item.Department})";

            // 1. Identity
            TxtBrandModel.Text = $"{_item.Brand} {_item.Model}".Trim();
            TxtSerialNo.Text = string.IsNullOrWhiteSpace(_item.SerialNo) ? "-" : _item.SerialNo;
            TxtIpAddress.Text = string.IsNullOrWhiteSpace(_item.IpAddress) ? "-" : _item.IpAddress;
            TxtMacAddress.Text = _item.DisplayMacAddress;

            // 2. Hardware
            TxtMotherboard.Text = _item.DisplayMotherboard;
            TxtProcessor.Text = _item.DisplayProcessor;
            TxtRam.Text = _item.DisplayRam;
            TxtDisk.Text = _item.DisplayDisk;
            TxtGpu.Text = _item.DisplayGpu;

            // 3. Software & OS
            TxtOsVersion.Text = _item.DisplayOsVersion;
            TxtWindowsBuild.Text = _item.DisplayWindowsBuild;
            TxtBios.Text = _item.DisplayBios;
            TxtDomainWorkgroup.Text = _item.DisplayDomainWorkgroup;
            TxtNetworkDetails.Text = _item.DisplayNetworkDetails;
            TxtSecurity.Text = _item.DisplaySecurity;
            TxtInstalledSoftware.Text = _item.DisplayInstalledSoftware;
            TxtUptime.Text = _item.DisplayUptime;

            // 4. Assignment
            TxtUserName.Text = string.IsNullOrWhiteSpace(_item.UserName) ? "-" : _item.UserName;
            TxtDepartmentUnit.Text = $"{_item.Department} / {_item.Unit}".Trim(' ', '/');
            TxtLocation.Text = string.IsNullOrWhiteSpace(_item.Location) ? "-" : _item.Location;
            TxtDate.Text = string.IsNullOrWhiteSpace(_item.Date) ? "-" : _item.Date;
        }

        private void BtnCopySerial_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                Clipboard.SetText(_item.SerialNo);
                TxtCopyStatus.Text = "✓ Seri Numarası / HWID panoya kopyalandı!";
            }
            catch (Exception ex)
            {
                TxtCopyStatus.Text = $"Hata: {ex.Message}";
            }
        }

        private void BtnClose_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }
    }
}
