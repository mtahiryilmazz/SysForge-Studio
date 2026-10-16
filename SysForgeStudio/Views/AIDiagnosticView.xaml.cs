using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using SysForgeStudio.Models;
using SysForgeStudio.Services;

namespace SysForgeStudio.Views
{
    public partial class AIDiagnosticView : UserControl
    {
        private AISolutionResult? _currentSolution;
        private string? _lastBackupPath;

        public AIDiagnosticView()
        {
            InitializeComponent();
            Loaded += AIDiagnosticView_Loaded;
        }

        private void AIDiagnosticView_Loaded(object sender, RoutedEventArgs e)
        {
            TxtApiKey.Text = AIDiagnosticEngine.Instance.ApiKey;
            CheckRecentBackupsAvailability();
        }

        private void CheckRecentBackupsAvailability()
        {
            var backups = SystemBackupService.Instance.GetRecentBackups();
            BtnRestoreLastBackup.IsEnabled = backups.Count > 0;
            if (backups.Count > 0)
            {
                BtnRestoreLastBackup.ToolTip = $"Son Yedek: {backups.First().Name} ({backups.First().CreationTime:yyyy-MM-dd HH:mm})";
            }
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
                MessageBox.Show("Lütfen analiz edilecek bir arıza veya hata açıklaması yazın.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            BtnAnalyze.IsEnabled = false;
            BtnAnalyze.Content = "⏳ Analiz Ediliyor...";

            try
            {
                AppendLog($"[AI ANALİZ BAŞLATILDI] Sorgu: '{query}'");
                _currentSolution = await AIDiagnosticEngine.Instance.AnalyzeIssueAsync(query);

                CardSolution.Visibility = Visibility.Visible;
                TxtSolutionTitle.Text = _currentSolution.Title;
                TxtCategoryBadge.Text = $"Alan: {_currentSolution.Category}";
                TxtRootCause.Text = _currentSolution.RootCause;
                ListSteps.ItemsSource = _currentSolution.Steps;
                TxtAutoScript.Text = _currentSolution.AutoFixScript;

                // Web Insights
                if (_currentSolution.HasWebInsights)
                {
                    CardWebInsights.Visibility = Visibility.Visible;
                    TxtWebInsights.Text = _currentSolution.WebInsights;
                    AppendLog("[WEB ARAŞTIRMASI] Canlı topluluk ve web çözümü başarıyla entegre edildi.");
                }
                else
                {
                    CardWebInsights.Visibility = Visibility.Collapsed;
                }

                // Alternatives
                if (_currentSolution.HasAlternatives)
                {
                    CardAlternatives.Visibility = Visibility.Visible;
                    ListAlternatives.ItemsSource = _currentSolution.Alternatives;
                }
                else
                {
                    CardAlternatives.Visibility = Visibility.Collapsed;
                }

                // Severity Badge
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

                AppendLog($"[AI TEŞHİS TAMAMLANDI] Kategori: {_currentSolution.Category} | Başlık: {_currentSolution.Title}");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Analiz hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
                AppendLog($"[HATA] {ex.Message}");
            }
            finally
            {
                BtnAnalyze.IsEnabled = true;
                BtnAnalyze.Content = "⚡ Yapay Zeka Analizi";
            }
        }

        private void BtnSelectAlternative_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is AISolutionAlternative alt)
            {
                TxtAutoScript.Text = alt.Script;
                AppendLog($"[ALTERNATİF SEÇİLDİ] '{alt.Title}' ({alt.Category}) komut alanına yüklendi.");
                MessageBox.Show($"'{alt.Title}' çözümü seçildi ve onarım komutuna yüklendi.\n\nİnceleyip 'Bu Çözümü Uygula' butonuna basabilirsiniz.", "Alternatif Seçildi", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private async void BtnExecuteFix_Click(object sender, RoutedEventArgs e)
        {
            if (_currentSolution == null || string.IsNullOrWhiteSpace(TxtAutoScript.Text))
            {
                MessageBox.Show("Çalıştırılacak onarım komutu bulunamadı.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            string script = TxtAutoScript.Text.Trim();

            if (MessageBox.Show($"Bu otomatik onarım çözümünü şimdi uygulamak istiyor musunuz?\n\nKomut:\n{script}", "Onarım Onayı", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
            {
                return;
            }

            BtnExecuteFix.IsEnabled = false;
            BtnExecuteFix.Content = "⏳ Onarım Uygulanıyor...";

            // 1. Safety Backup Handling
            if (ChkAutoBackup.IsChecked == true)
            {
                AppendLog("--- GÜVENLİK YEDEKLEMESİ BAŞLATILIYOR ---");
                
                // Registry Backup
                string regToBackup = _currentSolution.TargetRegistryBackupPath;
                if (string.IsNullOrWhiteSpace(regToBackup) && script.Contains("HKCU:"))
                {
                    regToBackup = @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer";
                }
                else if (string.IsNullOrWhiteSpace(regToBackup) && script.Contains("HKLM:"))
                {
                    regToBackup = @"HKEY_LOCAL_MACHINE\Software\Policies\Microsoft";
                }

                if (!string.IsNullOrWhiteSpace(regToBackup))
                {
                    AppendLog($"[YEDEK] Kayıt Defteri yedeği alınıyor: '{regToBackup}'...");
                    var regRes = await SystemBackupService.Instance.BackupRegistryKeyAsync(regToBackup, _currentSolution.Category);
                    if (regRes.Success)
                    {
                        _lastBackupPath = regRes.FilePath;
                        BtnUndoLastFix.Visibility = Visibility.Visible;
                        CheckRecentBackupsAvailability();
                        AppendLog($"[YEDEK BAŞARILI] {regRes.Message}");
                    }
                    else
                    {
                        AppendLog($"[YEDEK UYARISI] {regRes.Message}");
                    }
                }

                // System Restore Point
                AppendLog("[YEDEK] Windows Sistem Geri Yükleme Noktası (Restore Point) oluşturuluyor...");
                var rpRes = await SystemBackupService.Instance.CreateSystemRestorePointAsync(_currentSolution.Category);
                if (rpRes.Success)
                {
                    AppendLog($"[YEDEK BAŞARILI] {rpRes.Message}");
                }
                else
                {
                    AppendLog($"[YEDEK UYARISI] {rpRes.Message}");
                }
            }

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
                            MessageBox.Show("Otomatik onarım komutu tamamlandı!\nEğer bir sorun olursa 'Yapılan Değişikliği Geri Al' veya 'Sistem Geri Yükleme' ile önceki duruma dönebilirsiniz.", "İşlem Tamamlandı", MessageBoxButton.OK, MessageBoxImage.Information);
                        });
                    }
                }
                catch (Exception ex)
                {
                    Dispatcher.Invoke(() => AppendLog($"[KRİTİK HATA] {ex.Message}"));
                }
            });

            BtnExecuteFix.IsEnabled = true;
            BtnExecuteFix.Content = "🚀 Bu Çözümü Uygula (Otomatik Güvenli Onarım)";
        }

        private async void BtnUndoLastFix_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(_lastBackupPath) || !File.Exists(_lastBackupPath))
            {
                MessageBox.Show("Geri yüklenecek kayıt defteri yedeği bulunamadı.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (MessageBox.Show($"Son alınan kayıt defteri yedeğini geri yüklemek istiyor musunuz?\n\nDosya: {Path.GetFileName(_lastBackupPath)}", "Yedekten Geri Yükleme", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
            {
                return;
            }

            AppendLog($"[GERİ YÜKLEME] '{Path.GetFileName(_lastBackupPath)}' sisteme geri yükleniyor...");
            var res = await SystemBackupService.Instance.RestoreRegistryBackupAsync(_lastBackupPath);
            if (res.Success)
            {
                AppendLog($"[BAŞARILI] {res.Message}");
                MessageBox.Show("Kayıt defteri yedeği başarıyla geri yüklendi!", "Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                AppendLog($"[GERİ YÜKLEME HATASI] {res.Message}");
                MessageBox.Show($"Geri yükleme hatası: {res.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private async void BtnCreateRestorePoint_Click(object sender, RoutedEventArgs e)
        {
            BtnCreateRestorePoint.IsEnabled = false;
            AppendLog("[İŞLEM] Manuel Sistem Geri Yükleme Noktası oluşturuluyor...");
            var res = await SystemBackupService.Instance.CreateSystemRestorePointAsync("SysForge_Manual");
            if (res.Success)
            {
                AppendLog($"[BAŞARILI] {res.Message}");
                MessageBox.Show(res.Message, "Geri Yükleme Noktası", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                AppendLog($"[UYARI] {res.Message}");
                MessageBox.Show($"Geri yükleme noktası oluşturulurken bildirim: {res.Message}", "Bilgi", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
            BtnCreateRestorePoint.IsEnabled = true;
        }

        private void BtnLaunchSystemRestore_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                AppendLog("[BAŞLATILDI] Windows Sistem Geri Yükleme Sihirbazı (rstrui.exe) açılıyor...");
                SystemBackupService.Instance.LaunchSystemRestoreGui();
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnOpenBackupsFolder_Click(object sender, RoutedEventArgs e)
        {
            SystemBackupService.Instance.OpenBackupsFolder();
        }

        private async void BtnRestoreLastBackup_Click(object sender, RoutedEventArgs e)
        {
            var backups = SystemBackupService.Instance.GetRecentBackups();
            if (backups.Count == 0)
            {
                MessageBox.Show("Sistemde henüz kayıtlı bir SysForge .reg yedeği bulunamadı.", "Bilgi", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var latest = backups.First();
            if (MessageBox.Show($"En son alınan yedek dosyasını geri yüklemek istiyor musunuz?\n\nDosya: {latest.Name}\nTarih: {latest.CreationTime:yyyy-MM-dd HH:mm:ss}\nBoyut: {latest.Length} bayt", "Son Yedeği Yükle", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
            {
                return;
            }

            AppendLog($"[GERİ YÜKLEME] '{latest.Name}' aktarılıyor...");
            var res = await SystemBackupService.Instance.RestoreRegistryBackupAsync(latest.FullName);
            if (res.Success)
            {
                AppendLog($"[BAŞARILI] {res.Message}");
                MessageBox.Show(res.Message, "Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                AppendLog($"[HATA] {res.Message}");
                MessageBox.Show(res.Message, "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
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

        private void BtnClearLog_Click(object sender, RoutedEventArgs e)
        {
            TxtTerminalLog.Clear();
        }

        private void AppendLog(string line)
        {
            TxtTerminalLog.AppendText($"[{DateTime.Now:HH:mm:ss}] {line}\n");
            TxtTerminalLog.ScrollToEnd();
        }
    }
}