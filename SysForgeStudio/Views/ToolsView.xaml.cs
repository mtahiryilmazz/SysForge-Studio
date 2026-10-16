using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using SysForgeStudio.Services;

namespace SysForgeStudio.Views
{
    public partial class ToolsView : UserControl
    {
        public ToolsView()
        {
            InitializeComponent();
        }

        private void RunProcessSafe(string fileName, string args = "")
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = fileName,
                    Arguments = args,
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Araç başlatılamadı: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnControlPrinters_Click(object sender, RoutedEventArgs e) => RunProcessSafe("control.exe", "printers");
        private void BtnPrintManagement_Click(object sender, RoutedEventArgs e) => RunProcessSafe("mmc.exe", "printmanagement.msc");
        private void BtnPrintServerProps_Click(object sender, RoutedEventArgs e) => RunProcessSafe("rundll32.exe", "printui.dll,PrintUIEntry /s");
        private void BtnServices_Click(object sender, RoutedEventArgs e) => RunProcessSafe("services.msc");
        private void BtnEventVwr_Click(object sender, RoutedEventArgs e) => RunProcessSafe("eventvwr.msc");
        private void BtnNcpa_Click(object sender, RoutedEventArgs e) => RunProcessSafe("ncpa.cpl");

        private async void BtnGpUpdate_Click(object sender, RoutedEventArgs e)
        {
            ToolkitEngine.Instance.Log("gpupdate /force çalıştırılıyor...", Models.LogLevel.Info);
            await ToolkitEngine.Instance.RunCommandAsync("gpupdate /force", asPowerShell: false);
            MessageBox.Show("Grup ilkeleri başarıyla zorlanarak güncellendi.", "GPUpdate", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void BtnSpoolFolder_Click(object sender, RoutedEventArgs e)
        {
            string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "spool", "PRINTERS");
            RunProcessSafe("explorer.exe", path);
        }
    }
}
