using System;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using UltimateToolkit.Modern.Models;
using UltimateToolkit.Modern.Services;

namespace UltimateToolkit.Modern.Views
{
    public partial class AIDiagnosticView : UserControl
    {
        private AISolutionResult? _currentSolution;

        public AIDiagnosticView()
        {
            InitializeComponent();
            Loaded += AIDiagnosticView_Loaded;
        }

        private void AIDiagnosticView_Loaded(object sender, RoutedEventArgs e)
        {
            TxtApiKey.Text = AIDiagnosticEngine.Instance.ApiKey;
        }

        private async void BtnAnalyze_Click(object sender, RoutedEventArgs e)
        {
            await RunAnalysisAsync();
        }

        private async void TxtIssueQuery_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Enter)
            {
                await RunAnalysisAsync();
            }
        }

        private async void BtnPreset_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Content != null)
            {
                TxtIssueQuery.Text = btn.Content.ToString();
                await RunAnalysisAsync();
            }
        }

        private async Task RunAnalysisAsync()
        {
            string query = TxtIssueQuery.Text.Trim();
            if (string.IsNullOrWhiteSpace(query))
            {
                MessageBox.Show("Lütfen analiz edilecek bir arıza veya hata kodu yazın.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            BtnAnalyze.IsEnabled = false;
            BtnAnalyze.Content = "⏳ Analiz Ediliyor...";

            try
            {
                _currentSolution = await AIDiagnosticEngine.Instance.AnalyzeIssueAsync(query);

                CardSolution.Visibility = Visibility.Visible;
                TxtSolutionTitle.Text = _currentSolution.Title;
                TxtRootCause.Text = _currentSolution.RootCause;
                ListSteps.ItemsSource = _currentSolution.Steps;
                TxtAutoScript.Text = _currentSolution.AutoFixScript;

                TxtSeverity.Text = $"Risk: {_currentSolution.Severity}";
                if (_currentSolution.Severity == "Yüksek")
                {
                    BadgeSeverity.Background = new SolidColorBrush(Color.FromRgb(185, 28, 28));
                }
                else if (_currentSolution.Severity == "Orta")
                {
                    BadgeSeverity.Background = new SolidColorBrush(Color.FromRgb(180, 83, 9));
                }
                else
                {
                    BadgeSeverity.Background = new SolidColorBrush(Color.FromRgb(21, 128, 61));
                }

                AppendLog($"[AI ANALİZ TAMAMLANDI] {_currentSolution.Title}");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Analiz hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                BtnAnalyze.IsEnabled = true;
                BtnAnalyze.Content = "⚡ Yapay Zeka Analizi";
            }
        }

        private async void BtnExecuteFix_Click(object sender, RoutedEventArgs e)
        {
            if (_currentSolution == null || string.IsNullOrWhiteSpace(_currentSolution.AutoFixScript))
            {
                MessageBox.Show("Çalıştırılacak onarım komutu bulunamadı.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (MessageBox.Show($"Bu otomatik onarım çözümünü şimdi uygulamak istiyor musunuz?\n\nKomut: {_currentSolution.AutoFixScript}", "Onarım Onayı", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
            {
                return;
            }

            BtnExecuteFix.IsEnabled = false;
            BtnExecuteFix.Content = "⏳ Onarım Uygulanıyor...";

            string script = _currentSolution.AutoFixScript;
            AppendLog($"--- ONARIM BAŞLATILDI: {DateTime.Now:HH:mm:ss} ---");
            AppendLog($"Komut: {script}");

            await Task.Run(() =>
            {
                try
                {
                    var psi = new ProcessStartInfo
                    {
                        FileName = "powershell.exe",
                        Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"{script}\"",
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };

                    using var proc = Process.Start(psi);
                    if (proc != null)
                    {
                        proc.OutputDataReceived += (s, args) =>
                        {
                            if (!string.IsNullOrEmpty(args.Data)) Dispatcher.Invoke(() => AppendLog(args.Data));
                        };
                        proc.ErrorDataReceived += (s, args) =>
                        {
                            if (!string.IsNullOrEmpty(args.Data)) Dispatcher.Invoke(() => AppendLog("[HATA] " + args.Data));
                        };

                        proc.BeginOutputReadLine();
                        proc.BeginErrorReadLine();
                        proc.WaitForExit();

                        Dispatcher.Invoke(() =>
                        {
                            AppendLog($"--- ONARIM TAMAMLANDI (Çıkış Kodu: {proc.ExitCode}) ---");
                            MessageBox.Show("Otomatik onarım başarıyla uygulandı!", "Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
                        });
                    }
                }
                catch (Exception ex)
                {
                    Dispatcher.Invoke(() => AppendLog($"[KRİTİK HATA] {ex.Message}"));
                }
            });

            BtnExecuteFix.IsEnabled = true;
            BtnExecuteFix.Content = "🚀 Bu Çözümü Uygula (Otomatik Onar)";
        }

        private void BtnCopyScript_Click(object sender, RoutedEventArgs e)
        {
            if (!string.IsNullOrWhiteSpace(TxtAutoScript.Text))
            {
                Clipboard.SetText(TxtAutoScript.Text);
                MessageBox.Show("Onarım komutu panoya kopyalandı!", "Kopyalandı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void BtnSaveApiKey_Click(object sender, RoutedEventArgs e)
        {
            AIDiagnosticEngine.Instance.SaveApiKey(TxtApiKey.Text);
            MessageBox.Show("Google Gemini API anahtarı başarıyla kaydedildi!", "Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void AppendLog(string line)
        {
            TxtTerminalLog.AppendText($"[{DateTime.Now:HH:mm:ss}] {line}\n");
            TxtTerminalLog.ScrollToEnd();
        }
    }
}