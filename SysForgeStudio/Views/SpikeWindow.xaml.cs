using System;
using System.IO;
using System.Linq;
using System.Management;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;
using Microsoft.Data.Sqlite;
using Wpf.Ui.Appearance;

namespace SysForgeStudio.Views
{
    /// <summary>
    /// Faz 0 uyumluluk denemesi: WPF-UI + .NET Framework 4.8 ana islevleri
    /// Win7 SP1 / Win8.1 / Win10 / Win11 uzerinde dener ve rapor uretir.
    /// Calistirma: SysForgeStudio.exe --spike
    /// </summary>
    public partial class SpikeWindow : Wpf.Ui.Controls.FluentWindow
    {
        private bool _dark = true;

        public SpikeWindow()
        {
            InitializeComponent();
            SampleGrid.ItemsSource = new[]
            {
                new { Cihaz = "PC-01", Bolum = "Muhasebe", Durum = "Hazır" },
                new { Cihaz = "PC-02", Bolum = "Bilgi İşlem", Durum = "Serviste" },
                new { Cihaz = "YZC-01", Bolum = "Arşiv", Durum = "Hazır" },
            };
        }

        private void BtnTheme_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                _dark = !_dark;
                ApplicationThemeManager.Apply(_dark ? ApplicationTheme.Dark : ApplicationTheme.Light);
            }
            catch (Exception ex)
            {
                TxtReport.AppendText(Environment.NewLine + "[HATA] Tema değişimi: " + ex.GetType().Name + ": " + ex.Message);
            }
        }

        private void BtnCopy_Click(object sender, RoutedEventArgs e)
        {
            try { Clipboard.SetText(TxtReport.Text); }
            catch (Exception ex) { TxtReport.AppendText(Environment.NewLine + "[HATA] Kopyalama: " + ex.Message); }
        }

        private async void BtnRun_Click(object sender, RoutedEventArgs e)
        {
            BtnRun.IsEnabled = false;
            var sb = new StringBuilder();
            sb.AppendLine("=== SysForge Studio net48 + WPF-UI uyumluluk raporu ===");
            sb.AppendLine("Tarih: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
            sb.AppendLine();

            Check(sb, "İşletim sistemi", () => Environment.OSVersion.VersionString);
            Check(sb, "64-bit OS / 64-bit işlem", () => Environment.Is64BitOperatingSystem + " / " + Environment.Is64BitProcess);
            Check(sb, ".NET çalışma zamanı", () => RuntimeInformation.FrameworkDescription);
            Check(sb, "WPF-UI sürümü", () => typeof(Wpf.Ui.Controls.FluentWindow).Assembly.GetName().Version.ToString());
            Check(sb, "WPF render katmanı (Tier)", () => (RenderCapability.Tier >> 16).ToString());
            Check(sb, "DPI ölçeği", () => VisualTreeHelper.GetDpi(this).DpiScaleX.ToString("0.00"));
            Check(sb, "Yazı tipleri", () =>
            {
                var names = Fonts.SystemFontFamilies.Select(f => f.Source).ToList();
                return string.Join(", ", new[] { "Segoe MDL2 Assets", "Segoe Fluent Icons", "Segoe UI Emoji" }
                    .Select(n => n + "=" + (names.Contains(n) ? "var" : "YOK")));
            });
            Check(sb, "TLS ayarı", () => ServicePointManager.SecurityProtocol.ToString());
            Check(sb, "WMI (Win32_OperatingSystem)", () =>
            {
                using (var s = new ManagementObjectSearcher("SELECT Caption, Version FROM Win32_OperatingSystem"))
                {
                    foreach (ManagementBaseObject o in s.Get())
                        return Convert.ToString(o["Caption"]) + " " + Convert.ToString(o["Version"]);
                }
                return "sonuç yok";
            });
            Check(sb, "SQLite (bellek içi yaz/oku)", () =>
            {
                using (var conn = new SqliteConnection("Data Source=:memory:"))
                {
                    conn.Open();
                    using (var c1 = conn.CreateCommand())
                    {
                        c1.CommandText = "CREATE TABLE t(a INTEGER)";
                        c1.ExecuteNonQuery();
                        c1.CommandText = "INSERT INTO t VALUES (42)";
                        c1.ExecuteNonQuery();
                    }
                    using (var c2 = conn.CreateCommand())
                    {
                        c2.CommandText = "SELECT a FROM t";
                        var v = c2.ExecuteScalar();
                        c2.CommandText = "SELECT sqlite_version()";
                        return "değer=" + v + ", sqlite " + c2.ExecuteScalar();
                    }
                }
            });

            try
            {
                string r = await Task.Run(() => TestHttpListener());
                sb.AppendLine("[OK ] HttpListener (localhost:5099): " + r);
            }
            catch (Exception ex)
            {
                sb.AppendLine("[HATA] HttpListener (localhost:5099): " + ex.GetType().Name + ": " + ex.Message);
            }

            sb.AppendLine();
            sb.AppendLine("Görsel kontrol (elle): başlık çubuğu, kenar boşlukları, düğme/kart/tablo görünümü, açık-koyu tema geçişi.");

            TxtReport.Text = sb.ToString();
            try { File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "spike_report.txt"), sb.ToString(), Encoding.UTF8); }
            catch { /* yazma izni yoksa yalnızca ekranda göster */ }
            BtnRun.IsEnabled = true;
        }

        private static void Check(StringBuilder sb, string name, Func<string> action)
        {
            try { sb.AppendLine("[OK ] " + name + ": " + action()); }
            catch (Exception ex) { sb.AppendLine("[HATA] " + name + ": " + ex.GetType().Name + ": " + ex.Message); }
        }

        private static async Task<string> TestHttpListener()
        {
            const string url = "http://localhost:5099/";
            var listener = new HttpListener();
            listener.Prefixes.Add(url);
            listener.Start();
            try
            {
                var ctxTask = listener.GetContextAsync();
                using (var client = new WebClient())
                {
                    client.Proxy = null;
                    var download = client.DownloadStringTaskAsync(url);
                    var ctx = await ctxTask;
                    byte[] buf = Encoding.UTF8.GetBytes("ok");
                    ctx.Response.OutputStream.Write(buf, 0, buf.Length);
                    ctx.Response.Close();
                    return "yanıt=" + await download;
                }
            }
            finally
            {
                listener.Stop();
                listener.Close();
            }
        }
    }
}
