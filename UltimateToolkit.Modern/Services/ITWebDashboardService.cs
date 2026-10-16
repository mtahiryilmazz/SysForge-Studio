using System;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace UltimateToolkit.Modern.Services
{
    public class ITWebDashboardService
    {
        public static ITWebDashboardService Instance { get; } = new ITWebDashboardService();

        private HttpListener? _listener;
        private CancellationTokenSource? _cts;
        public bool IsRunning => _listener != null && _listener.IsListening;
        public int Port { get; private set; } = 5000;

        public event Action<bool>? StateChanged;
        public event Action<string>? LogReceived;

        public void Start(int port = 5000)
        {
            if (IsRunning) return;
            Port = port;

            try
            {
                _listener = new HttpListener();
                _listener.Prefixes.Add($"http://localhost:{Port}/");
                _listener.Prefixes.Add($"http://127.0.0.1:{Port}/");
                _listener.Start();

                _cts = new CancellationTokenSource();
                Task.Run(() => ListenLoop(_cts.Token));

                StateChanged?.Invoke(true);
                LogReceived?.Invoke($"Web Dashboard başlatıldı: http://localhost:{Port}/");
            }
            catch (Exception ex)
            {
                LogReceived?.Invoke($"Web sunucusu başlatılamadı: {ex.Message}");
                Stop();
            }
        }

        public void Stop()
        {
            try
            {
                _cts?.Cancel();
                _listener?.Stop();
                _listener?.Close();
            }
            catch { }
            finally
            {
                _listener = null;
                StateChanged?.Invoke(false);
                LogReceived?.Invoke("Web Dashboard durduruldu.");
            }
        }

        private async Task ListenLoop(CancellationToken ct)
        {
            while (!ct.IsCancellationRequested && _listener != null && _listener.IsListening)
            {
                try
                {
                    var ctx = await _listener.GetContextAsync();
                    _ = ProcessRequestAsync(ctx);
                }
                catch when (ct.IsCancellationRequested)
                {
                    break;
                }
                catch { }
            }
        }

        private async Task ProcessRequestAsync(HttpListenerContext ctx)
        {
            var req = ctx.Request;
            var res = ctx.Response;

            try
            {
                if (req.HttpMethod == "POST" && req.Url?.AbsolutePath == "/api/tickets/create")
                {
                    using var reader = new StreamReader(req.InputStream, req.ContentEncoding);
                    string body = await reader.ReadToEndAsync();
                    // parse form-urlencoded
                    var nvc = System.Web.HttpUtility.ParseQueryString(body);
                    string person = nvc["personnel"] ?? "-";
                    string dep = nvc["department"] ?? "-";
                    string unit = nvc["unit"] ?? "-";
                    string desc = nvc["desc"] ?? "-";

                    ITServiceDatabase.Instance.AddTicket(new Models.TicketItem
                    {
                        PersonnelName = person,
                        Department = dep,
                        Unit = unit,
                        Description = desc,
                        IssueType = "Web Bildirimi",
                        Priority = "Normal",
                        Status = "Açık"
                    });

                    res.Redirect("/?success=1");
                    res.Close();
                    return;
                }

                // Render Modern Dark Web Dashboard HTML
                var tickets = ITServiceDatabase.Instance.GetTickets();
                var inventory = ITServiceDatabase.Instance.GetInventory();
                var departments = ITServiceDatabase.Instance.GetDepartments();

                var sb = new StringBuilder();
                sb.AppendLine("<!DOCTYPE html><html lang='tr'><head><meta charset='utf-8'/><meta name='viewport' content='width=device-width,initial-scale=1'/>");
                sb.AppendLine("<title>SysForge Studio - BT Web Portali</title>");
                sb.AppendLine("<style>");
                sb.AppendLine("body { font-family: 'Segoe UI', Tahoma, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 20px; }");
                sb.AppendLine(".container { max-width: 1000px; margin: auto; }");
                sb.AppendLine(".header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #334155; padding-bottom: 14px; margin-bottom: 20px; }");
                sb.AppendLine("h1 { color: #38bdf8; margin: 0; font-size: 24px; }");
                sb.AppendLine(".card { background: #1e293b; border-radius: 10px; padding: 20px; margin-bottom: 20px; box-shadow: 0 4px 12px rgba(0,0,0,0.3); }");
                sb.AppendLine("table { width: 100%; border-collapse: collapse; margin-top: 10px; }");
                sb.AppendLine("th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid #334155; font-size: 13px; }");
                sb.AppendLine("th { background: #0f172a; color: #94a3b8; }");
                sb.AppendLine("input, select, textarea, button { background: #0f172a; color: #fff; border: 1px solid #334155; padding: 8px 12px; border-radius: 6px; font-size: 13px; width: 100%; box-sizing: border-box; }");
                sb.AppendLine("button { background: #0284c7; font-weight: bold; cursor: pointer; border: none; margin-top: 10px; padding: 10px; }");
                sb.AppendLine("button:hover { background: #0369a1; }");
                sb.AppendLine(".badge { padding: 3px 8px; border-radius: 4px; font-size: 11px; font-weight: bold; }");
                sb.AppendLine(".badge-open { background: #b45309; color: #fff; }");
                sb.AppendLine(".badge-done { background: #15803d; color: #fff; }");
                sb.AppendLine("</style></head><body><div class='container'>");

                sb.AppendLine("<div class='header'><div><h1>🛠️ SysForge Studio - BT Servis Masası</h1><p style='color:#94a3b8;margin:4px 0 0;'>Kurumsal Arıza Bildirim ve Envanter Portali</p></div>");
                sb.AppendLine("<div style='text-align:right;'><span class='badge badge-done'>Canlı Sistem</span></div></div>");

                // New Ticket Card
                sb.AppendLine("<div class='card'><h2>➕ Yeni Arıza / Destek Talebi Oluştur</h2>");
                sb.AppendLine("<form method='POST' action='/api/tickets/create'>");
                sb.AppendLine("<div style='display:grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; margin-bottom: 10px;'>");
                sb.AppendLine("<input type='text' name='personnel' placeholder='Adınız Soyadınız' required/>");
                sb.AppendLine("<select name='department'>");
                foreach (var d in departments)
                {
                    sb.AppendLine($"<option value='{d.Name}'>{d.Name}</option>");
                }
                sb.AppendLine("</select>");
                sb.AppendLine("<input type='text' name='unit' placeholder='Alt Birim / Oda No'/>");
                sb.AppendLine("</div>");
                sb.AppendLine("<textarea name='desc' rows='3' placeholder='Arızayı veya talebinizi detaylı açıklayın...' required></textarea>");
                sb.AppendLine("<button type='submit'>🚀 Arıza Bildirimi Gönder</button>");
                sb.AppendLine("</form></div>");

                // Open Tickets Card
                sb.AppendLine("<div class='card'><h2>📋 Aktif Destek Talepleri</h2><table><tr><th>ID</th><th>Personel</th><th>Müdürlük</th><th>Açıklama</th><th>Tarih</th><th>Durum</th></tr>");
                foreach (var t in tickets)
                {
                    string badge = t.Status == "Çözüldü" ? "badge-done" : "badge-open";
                    sb.AppendLine($"<tr><td><strong>#{t.Id}</strong></td><td>{t.PersonnelName}</td><td>{t.Department} / {t.Unit}</td><td>{t.Description}</td><td>{t.Date}</td><td><span class='badge {badge}'>{t.Status}</span></td></tr>");
                }
                sb.AppendLine("</table></div>");

                // Inventory Card
                sb.AppendLine("<div class='card'><h2>🖥️ Cihaz & Donanım Envanteri</h2><table><tr><th>Marka / Model</th><th>Seri No</th><th>IP Adresi</th><th>Müdürlük</th><th>Kullanıcı</th></tr>");
                foreach (var inv in inventory)
                {
                    sb.AppendLine($"<tr><td><strong>{inv.Brand}</strong> {inv.Model}</td><td><code>{inv.SerialNo}</code></td><td>{inv.IpAddress}</td><td>{inv.Department} / {inv.Unit}</td><td>{inv.UserName}</td></tr>");
                }
                sb.AppendLine("</table></div>");

                sb.AppendLine("<p style='text-align:center;color:#64748b;font-size:12px;'>SysForge Studio Embedded Web Engine - Saf Yerel .NET 8 Motoru</p>");
                sb.AppendLine("</div></body></html>");

                byte[] bytes = Encoding.UTF8.GetBytes(sb.ToString());
                res.ContentType = "text/html; charset=utf-8";
                res.ContentLength64 = bytes.Length;
                await res.OutputStream.WriteAsync(bytes, 0, bytes.Length);
            }
            catch { }
            finally
            {
                try { res.Close(); } catch { }
            }
        }
    }
}