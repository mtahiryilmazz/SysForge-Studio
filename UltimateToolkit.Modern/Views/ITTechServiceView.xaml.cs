using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace UltimateToolkit.Modern.Views
{
    public partial class ITTechServiceView : UserControl
    {
        private Process? _serverProcess;
        private string _moduleDirectory = string.Empty;

        public ITTechServiceView()
        {
            InitializeComponent();
            LocateModuleDirectory();
            Loaded += ITTechServiceView_Loaded;
        }

        private void LocateModuleDirectory()
        {
            string exeDir = AppDomain.CurrentDomain.BaseDirectory;
            string p1 = Path.GetFullPath(Path.Combine(exeDir, "..", "it_tech_service"));
            string p2 = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", "..", "it_tech_service"));
            string p3 = @"d:\YILMAZApp\it_tech_service";

            if (Directory.Exists(p1)) _moduleDirectory = p1;
            else if (Directory.Exists(p2)) _moduleDirectory = p2;
            else if (Directory.Exists(p3)) _moduleDirectory = p3;
            else _moduleDirectory = exeDir;
        }

        private void ITTechServiceView_Loaded(object sender, RoutedEventArgs e)
        {
            string dbPath = Path.Combine(_moduleDirectory, "it_tech_service.db");
            TxtDbPath.Text = File.Exists(dbPath) ? $"{dbPath} (Mevcut)" : $"{dbPath} (Henüz oluşturulmadı)";
            CheckPythonInstalled();
        }

        private void CheckPythonInstalled()
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "python",
                    Arguments = "--version",
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };
                using var p = Process.Start(psi);
                if (p != null)
                {
                    string output = p.StandardOutput.ReadToEnd().Trim();
                    if (string.IsNullOrWhiteSpace(output)) output = p.StandardError.ReadToEnd().Trim();
                    p.WaitForExit(3000);
                    TxtPythonInfo.Text = string.IsNullOrWhiteSpace(output) ? "Python Bulundu" : output;
                }
            }
            catch
            {
                TxtPythonInfo.Text = "Python PATH'te bulunamadı. Lütfen Python yükleyin.";
            }
        }

        private void BtnStartServer_Click(object sender, RoutedEventArgs e)
        {
            if (_serverProcess != null && !_serverProcess.HasExited)
            {
                MessageBox.Show("Sunucu zaten çalışıyor!", "Bilgi", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            string scriptPath = Path.Combine(_moduleDirectory, "web_server.py");
            if (!File.Exists(scriptPath))
            {
                MessageBox.Show($"web_server.py bulunamadı:\n{scriptPath}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "python",
                    Arguments = $"\"{scriptPath}\"",
                    WorkingDirectory = _moduleDirectory,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                _serverProcess = new Process { StartInfo = psi, EnableRaisingEvents = true };

                _serverProcess.OutputDataReceived += (s, args) =>
                {
                    if (!string.IsNullOrEmpty(args.Data))
                    {
                        Dispatcher.Invoke(() => AppendLog(args.Data));
                    }
                };

                _serverProcess.ErrorDataReceived += (s, args) =>
                {
                    if (!string.IsNullOrEmpty(args.Data))
                    {
                        Dispatcher.Invoke(() => AppendLog("[ERR] " + args.Data));
                    }
                };

                _serverProcess.Exited += (s, args) =>
                {
                    Dispatcher.Invoke(() =>
                    {
                        TxtServerStatus.Text = "⚪ Sunucu Kapalı (Durduruldu)";
                        TxtServerStatus.Foreground = new SolidColorBrush(Color.FromRgb(245, 158, 11));
                        BtnStartServer.IsEnabled = true;
                        BtnStopServer.IsEnabled = false;
                        AppendLog("--- Sunucu işlemi sonlandı ---");
                    });
                };

                _serverProcess.Start();
                _serverProcess.BeginOutputReadLine();
                _serverProcess.BeginErrorReadLine();

                TxtServerStatus.Text = "🟢 Sunucu Çalışıyor (Port 5000)";
                TxtServerStatus.Foreground = new SolidColorBrush(Color.FromRgb(34, 197, 94));
                BtnStartServer.IsEnabled = false;
                BtnStopServer.IsEnabled = true;

                AppendLog("Web servisi başlatıldı: http://localhost:5000");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Sunucu başlatılamadı: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnStopServer_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (_serverProcess != null && !_serverProcess.HasExited)
                {
                    _serverProcess.Kill(true);
                    _serverProcess.Dispose();
                    _serverProcess = null;
                }

                TxtServerStatus.Text = "⚪ Sunucu Kapalı (Durduruldu)";
                TxtServerStatus.Foreground = new SolidColorBrush(Color.FromRgb(245, 158, 11));
                BtnStartServer.IsEnabled = true;
                BtnStopServer.IsEnabled = false;
                AppendLog("Sunucu kullanıcı tarafından durduruldu.");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Durdurma hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnOpenBrowser_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "http://localhost:5000",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Tarayıcı açılamadı: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnCheckPython_Click(object sender, RoutedEventArgs e)
        {
            CheckPythonInstalled();
            MessageBox.Show($"Python Durumu: {TxtPythonInfo.Text}\nModül Konumu: {_moduleDirectory}", "Python Bilgisi", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void BtnOpenFolder_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (Directory.Exists(_moduleDirectory))
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = _moduleDirectory,
                        UseShellExecute = true
                    });
                }
            }
            catch { }
        }

        private void BtnClearLog_Click(object sender, RoutedEventArgs e)
        {
            TxtLogOutput.Text = string.Empty;
        }

        private void AppendLog(string text)
        {
            TxtLogOutput.AppendText($"[{DateTime.Now:HH:mm:ss}] {text}\n");
            TxtLogOutput.ScrollToEnd();
        }
    }
}
