using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using SysForgeStudio.Models;
using SysForgeStudio.Services;

namespace SysForgeStudio.Views
{
    public partial class LogsView : UserControl
    {
        public LogsView()
        {
            InitializeComponent();
            ToolkitEngine.Instance.LogReceived += OnLogReceived;
            Loaded += LogsView_Loaded;
        }

        private void LogsView_Loaded(object sender, RoutedEventArgs e)
        {
            ToolkitEngine.Instance.Log("Canlı günlük paneli bağlandı ve hazır.", LogLevel.Info);
        }

        private void OnLogReceived(LogEntry entry)
        {
            Dispatcher.Invoke(() =>
            {
                var p = new Paragraph { Margin = new Thickness(0, 0, 0, 4) };

                // Zaman
                p.Inlines.Add(new Run($"[{entry.FormattedTime}] ") { Foreground = new SolidColorBrush(Color.FromRgb(100, 116, 139)) });

                // Düzey
                string prefix = entry.Level switch
                {
                    LogLevel.Success => "[ OK ] ",
                    LogLevel.Warning => "[WARN] ",
                    LogLevel.Error => "[ERR ] ",
                    _ => "[INFO] "
                };

                var levelBrush = entry.Level switch
                {
                    LogLevel.Success => new SolidColorBrush(Color.FromRgb(34, 197, 94)),
                    LogLevel.Warning => new SolidColorBrush(Color.FromRgb(245, 158, 11)),
                    LogLevel.Error => new SolidColorBrush(Color.FromRgb(239, 68, 68)),
                    _ => new SolidColorBrush(Color.FromRgb(56, 189, 248))
                };

                p.Inlines.Add(new Run(prefix) { Foreground = levelBrush, FontWeight = FontWeights.Bold });

                // Mesaj
                p.Inlines.Add(new Run(entry.Message) { Foreground = new SolidColorBrush(Color.FromRgb(241, 245, 249)) });

                RtbLogs.Document.Blocks.Add(p);
                RtbLogs.ScrollToEnd();

                TxtLogStatus.Text = $"Son işlem: {entry.FormattedTime} - {entry.Level}";
            });
        }

        private async void BtnHtmlReport_Click(object sender, RoutedEventArgs e)
        {
            var printers = await ToolkitEngine.Instance.GetPrintersAsync();
            var diags = await ToolkitEngine.Instance.RunFullDiagnosisAsync();
            string path = ToolkitEngine.Instance.GenerateHtmlReport(printers, diags);

            if (File.Exists(path))
            {
                Process.Start(new ProcessStartInfo { FileName = path, UseShellExecute = true });
            }
        }

        private void BtnOpenLogDir_Click(object sender, RoutedEventArgs e)
        {
            if (Directory.Exists(ToolkitEngine.Instance.LogsDirectory))
            {
                Process.Start(new ProcessStartInfo { FileName = ToolkitEngine.Instance.LogsDirectory, UseShellExecute = true });
            }
        }

        private void BtnClearLogs_Click(object sender, RoutedEventArgs e)
        {
            RtbLogs.Document.Blocks.Clear();
            TxtLogStatus.Text = "Kayıtlar temizlendi.";
        }

        private void BtnCopyClipboard_Click(object sender, RoutedEventArgs e)
        {
            var text = new TextRange(RtbLogs.Document.ContentStart, RtbLogs.Document.ContentEnd).Text;
            if (!string.IsNullOrWhiteSpace(text))
            {
                Clipboard.SetText(text);
                MessageBox.Show("Tüm loglar panoya kopyalandı.", "Kopyalandı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }
    }
}
