using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SysForgeStudio.Services
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
                string path = req.Url?.AbsolutePath ?? "/";

                // 1. POST: Create Ticket
                if (req.HttpMethod == "POST" && path == "/api/tickets/create")
                {
                    using var reader = new StreamReader(req.InputStream, req.ContentEncoding);
                    string body = await reader.ReadToEndAsync();
                    var nvc = System.Web.HttpUtility.ParseQueryString(body);

                    string person = (nvc["personnel"] ?? "").Trim();
                    string dep = (nvc["department"] ?? "").Trim();
                    string unit = (nvc["unit"] ?? "").Trim();
                    string issueType = (nvc["issue_type"] ?? "Genel Arıza").Trim();
                    string priority = (nvc["priority"] ?? "Normal").Trim();
                    string desc = (nvc["desc"] ?? "").Trim();

                    if (!string.IsNullOrWhiteSpace(person) && !string.IsNullOrWhiteSpace(desc))
                    {
                        ITServiceDatabase.Instance.AddTicket(new Models.TicketItem
                        {
                            PersonnelName = person,
                            Department = string.IsNullOrWhiteSpace(dep) ? "Belirtilmedi" : dep,
                            Unit = string.IsNullOrWhiteSpace(unit) ? "-" : unit,
                            IssueType = issueType,
                            Priority = priority,
                            Description = desc,
                            Status = "Açık"
                        });
                    }

                    res.Redirect("/?msg=created");
                    res.Close();
                    return;
                }

                // 2. POST: Create Department
                if (req.HttpMethod == "POST" && path == "/api/departments/create")
                {
                    using var reader = new StreamReader(req.InputStream, req.ContentEncoding);
                    string body = await reader.ReadToEndAsync();
                    var nvc = System.Web.HttpUtility.ParseQueryString(body);
                    string name = (nvc["name"] ?? "").Trim();
                    if (!string.IsNullOrWhiteSpace(name))
                    {
                        ITServiceDatabase.Instance.AddDepartment(name);
                    }
                    res.Redirect("/?msg=dept_created");
                    res.Close();
                    return;
                }

                // 3. GET: Delete Department
                if (path == "/api/departments/delete")
                {
                    string idStr = req.QueryString["id"] ?? "";
                    if (int.TryParse(idStr, out int deptId))
                    {
                        ITServiceDatabase.Instance.DeleteDepartment(deptId);
                    }
                    res.Redirect("/?msg=dept_deleted");
                    res.Close();
                    return;
                }

                // 4. POST: Create Unit
                if (req.HttpMethod == "POST" && path == "/api/units/create")
                {
                    using var reader = new StreamReader(req.InputStream, req.ContentEncoding);
                    string body = await reader.ReadToEndAsync();
                    var nvc = System.Web.HttpUtility.ParseQueryString(body);
                    string deptIdStr = (nvc["dept_id"] ?? "").Trim();
                    string name = (nvc["name"] ?? "").Trim();
                    if (int.TryParse(deptIdStr, out int deptId) && !string.IsNullOrWhiteSpace(name))
                    {
                        ITServiceDatabase.Instance.AddUnit(deptId, name);
                    }
                    res.Redirect("/?msg=unit_created");
                    res.Close();
                    return;
                }

                // 5. GET: Delete Unit
                if (path == "/api/units/delete")
                {
                    string idStr = req.QueryString["id"] ?? "";
                    if (int.TryParse(idStr, out int unitId))
                    {
                        ITServiceDatabase.Instance.DeleteUnit(unitId);
                    }
                    res.Redirect("/?msg=unit_deleted");
                    res.Close();
                    return;
                }

                // 6. GET: Resolve Ticket
                if (path == "/api/tickets/resolve")
                {
                    string idStr = req.QueryString["id"] ?? "";
                    string note = req.QueryString["note"] ?? "";
                    if (int.TryParse(idStr, out int ticketId))
                    {
                        ITServiceDatabase.Instance.ResolveTicket(ticketId, note);
                    }
                    res.Redirect("/?msg=resolved");
                    res.Close();
                    return;
                }

                // 7. GET: Delete Ticket
                if (path == "/api/tickets/delete")
                {
                    string idStr = req.QueryString["id"] ?? "";
                    if (int.TryParse(idStr, out int ticketId))
                    {
                        ITServiceDatabase.Instance.DeleteTicket(ticketId);
                    }
                    res.Redirect("/?msg=deleted");
                    res.Close();
                    return;
                }

                // 8. GET: Live Sync State Check
                if (path == "/api/sync/state")
                {
                    var allTickets = ITServiceDatabase.Instance.GetTickets();
                    var allInventory = ITServiceDatabase.Instance.GetInventory();
                    var allDepts = ITServiceDatabase.Instance.GetDepartments();
                    int opCount = allTickets.Count(t => t.Status != "Çözüldü");
                    int resCount = allTickets.Count(t => t.Status == "Çözüldü");
                    string json = $"{{\"total\":{allTickets.Count},\"open\":{opCount},\"resolved\":{resCount},\"inventory\":{allInventory.Count},\"depts\":{allDepts.Count}}}";
                    byte[] jsonBytes = Encoding.UTF8.GetBytes(json);
                    res.ContentType = "application/json; charset=utf-8";
                    res.ContentLength64 = jsonBytes.Length;
                    await res.OutputStream.WriteAsync(jsonBytes, 0, jsonBytes.Length);
                    res.Close();
                    return;
                }

                // 9. Render Windows 11 Fluent Dark Web Portal
                var tickets = ITServiceDatabase.Instance.GetTickets();
                var inventory = ITServiceDatabase.Instance.GetInventory();
                var departments = ITServiceDatabase.Instance.GetDepartments();

                int totalTickets = tickets.Count;
                int openTickets = tickets.Count(t => t.Status != "Çözüldü");
                int resolvedTickets = tickets.Count(t => t.Status == "Çözüldü");
                int inventoryCount = inventory.Count;

                string msg = req.QueryString["msg"] ?? "";
                string toastHtml = "";
                if (msg == "created")
                {
                    toastHtml = "<div class='toast toast-success'>✅ Arıza talebiniz başarıyla kaydedildi ve servis kuyruğuna alındı.</div>";
                }
                else if (msg == "resolved")
                {
                    toastHtml = "<div class='toast toast-info'>✓ Talep çözüldü olarak işaretlendi.</div>";
                }
                else if (msg == "deleted")
                {
                    toastHtml = "<div class='toast toast-warning'>🗑️ Kayıt başarıyla silindi.</div>";
                }
                else if (msg == "dept_created")
                {
                    toastHtml = "<div class='toast toast-success'>🏢 Yeni müdürlük başarıyla eklendi.</div>";
                }
                else if (msg == "dept_deleted")
                {
                    toastHtml = "<div class='toast toast-warning'>🗑️ Müdürlük ve bağlı alt birimleri başarıyla silindi.</div>";
                }
                else if (msg == "unit_created")
                {
                    toastHtml = "<div class='toast toast-success'>🏢 Yeni alt birim başarıyla eklendi.</div>";
                }
                else if (msg == "unit_deleted")
                {
                    toastHtml = "<div class='toast toast-warning'>🗑️ Alt birim silindi.</div>";
                }

                var sb = new StringBuilder();
                sb.AppendLine("<!DOCTYPE html><html lang='tr'><head><meta charset='utf-8'/><meta name='viewport' content='width=device-width,initial-scale=1'/>");
                sb.AppendLine("<title>SysForge Studio - BT Teknik Servis Masası</title>");
                sb.AppendLine("<style>");
                sb.AppendLine(":root {");
                sb.AppendLine("  --bg-main: #141414; --bg-card: #202020; --bg-subtle: #2B2B2B; --bg-hover: #323232;");
                sb.AppendLine("  --border: #383838; --border-focus: #0078D4; --text-main: #FFFFFF; --text-muted: #A6A6A6;");
                sb.AppendLine("  --accent: #0078D4; --accent-hover: #1A86D9; --success: #107C41; --warning: #F59E0B; --danger: #C42B1C;");
                sb.AppendLine("  --font: 'Segoe UI Variable Display', 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;");
                sb.AppendLine("}");
                sb.AppendLine("* { box-sizing: border-box; margin: 0; padding: 0; }");
                sb.AppendLine("body { font-family: var(--font); background: var(--bg-main); color: var(--text-main); line-height: 1.5; padding: 24px; min-height: 100vh; }");
                sb.AppendLine(".container { max-width: 1200px; margin: 0 auto; }");
                sb.AppendLine(".header-bar { display: flex; justify-content: space-between; align-items: center; padding: 18px 24px; background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px; margin-bottom: 24px; box-shadow: 0 4px 16px rgba(0,0,0,0.4); }");
                sb.AppendLine(".brand-title { font-size: 22px; font-weight: 700; color: #38BDF8; display: flex; align-items: center; gap: 10px; }");
                sb.AppendLine(".brand-sub { font-size: 13px; color: var(--text-muted); margin-top: 2px; }");
                sb.AppendLine(".sys-status { display: flex; align-items: center; gap: 8px; font-size: 12px; font-weight: 600; background: rgba(16,124,65,0.2); color: #4ADE80; border: 1px solid rgba(16,124,65,0.4); padding: 6px 14px; border-radius: 20px; }");
                sb.AppendLine(".pulse-dot { width: 8px; height: 8px; background: #4ADE80; border-radius: 50%; box-shadow: 0 0 8px #4ADE80; }");
                sb.AppendLine(".toast { padding: 12px 18px; border-radius: 8px; margin-bottom: 20px; font-size: 14px; font-weight: 500; display: flex; align-items: center; }");
                sb.AppendLine(".toast-success { background: rgba(16,124,65,0.25); border: 1px solid var(--success); color: #86EFAC; }");
                sb.AppendLine(".toast-info { background: rgba(0,120,212,0.25); border: 1px solid var(--accent); color: #93C5FD; }");
                sb.AppendLine(".toast-warning { background: rgba(196,43,28,0.25); border: 1px solid var(--danger); color: #FCA5A5; }");
                sb.AppendLine(".kpi-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; margin-bottom: 24px; }");
                sb.AppendLine(".kpi-card { background: var(--bg-card); border: 1px solid var(--border); border-radius: 10px; padding: 18px 20px; transition: transform 0.15s, border-color 0.15s; }");
                sb.AppendLine(".kpi-card:hover { transform: translateY(-2px); border-color: var(--accent); }");
                sb.AppendLine(".kpi-title { font-size: 11.5px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; }");
                sb.AppendLine(".kpi-num { font-size: 32px; font-weight: 800; margin-top: 6px; }");
                sb.AppendLine(".card { background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px; padding: 22px; margin-bottom: 24px; box-shadow: 0 4px 12px rgba(0,0,0,0.25); }");
                sb.AppendLine(".card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; border-bottom: 1px solid var(--border); padding-bottom: 12px; }");
                sb.AppendLine(".card-title { font-size: 17px; font-weight: 700; color: var(--text-main); }");
                sb.AppendLine(".form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px; margin-bottom: 14px; }");
                sb.AppendLine("label { display: block; font-size: 12px; font-weight: 600; color: var(--text-muted); margin-bottom: 6px; }");
                sb.AppendLine("input, select, textarea { width: 100%; background: var(--bg-subtle); color: var(--text-main); border: 1px solid var(--border); border-radius: 6px; padding: 10px 14px; font-size: 13.5px; font-family: inherit; transition: border-color 0.15s; outline: none; }");
                sb.AppendLine("input:focus, select:focus, textarea:focus { border-color: var(--border-focus); box-shadow: 0 0 0 2px rgba(0,120,212,0.3); }");
                sb.AppendLine("button.btn-primary { background: var(--accent); color: #fff; font-size: 13.5px; font-weight: 600; border: none; border-radius: 6px; padding: 12px 24px; cursor: pointer; transition: background 0.15s; display: inline-flex; align-items: center; gap: 8px; }");
                sb.AppendLine("button.btn-primary:hover { background: var(--accent-hover); }");
                sb.AppendLine(".search-box { display: flex; gap: 10px; margin-bottom: 16px; }");
                sb.AppendLine(".search-input { flex: 1; padding: 10px 16px; border-radius: 8px; font-size: 13px; }");
                sb.AppendLine("table { width: 100%; border-collapse: separate; border-spacing: 0; margin-top: 8px; }");
                sb.AppendLine("th { background: #181818; color: var(--text-muted); font-size: 12px; font-weight: 600; text-transform: uppercase; padding: 12px 14px; text-align: left; border-bottom: 1px solid var(--border); }");
                sb.AppendLine("td { padding: 12px 14px; font-size: 13px; border-bottom: 1px solid var(--border); vertical-align: middle; }");
                sb.AppendLine("tr:hover td { background: rgba(255,255,255,0.02); }");
                sb.AppendLine(".chip { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 700; }");
                sb.AppendLine(".chip-open { background: rgba(245,158,11,0.2); color: #FBBF24; border: 1px solid rgba(245,158,11,0.4); }");
                sb.AppendLine(".chip-done { background: rgba(16,124,65,0.2); color: #4ADE80; border: 1px solid rgba(16,124,65,0.4); }");
                sb.AppendLine(".chip-priority { background: #2A2A2A; border: 1px solid var(--border); color: #CBD5E1; }");
                sb.AppendLine(".action-link { text-decoration: none; font-size: 12px; font-weight: 600; padding: 5px 10px; border-radius: 5px; margin-right: 6px; transition: opacity 0.15s; cursor: pointer; display: inline-block; }");
                sb.AppendLine(".action-resolve { background: #107C41; color: #fff; }");
                sb.AppendLine(".action-delete { background: #383838; color: #EF4444; }");
                sb.AppendLine(".action-link:hover { opacity: 0.85; }");
                sb.AppendLine(".dept-card { background: #181818; border: 1px solid #333; border-radius: 8px; padding: 12px 14px; margin-bottom: 10px; }");
                sb.AppendLine(".dept-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }");
                sb.AppendLine(".unit-pill { display: inline-flex; align-items: center; gap: 6px; background: #262626; border: 1px solid #3A3A3A; border-radius: 4px; padding: 3px 8px; font-size: 12px; color: #E2E8F0; margin-right: 6px; margin-bottom: 6px; }");
                sb.AppendLine(".unit-del { color: #F87171; text-decoration: none; font-size: 11px; font-weight: bold; cursor: pointer; }");
                sb.AppendLine(".modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.75); backdrop-filter: blur(5px); display: none; align-items: center; justify-content: center; z-index: 10000; }");
                sb.AppendLine(".modal-card { background: #202020; border: 1px solid #383838; border-radius: 12px; width: 90%; max-width: 520px; padding: 24px; box-shadow: 0 16px 40px rgba(0,0,0,0.7); animation: fadeIn 0.15s ease-out; }");
                sb.AppendLine(".modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; }");
                sb.AppendLine(".modal-title { font-size: 17px; font-weight: 700; color: #4ADE80; display: flex; align-items: center; gap: 8px; }");
                sb.AppendLine(".modal-close { background: none; border: none; font-size: 18px; color: #888; cursor: pointer; padding: 4px; }");
                sb.AppendLine(".modal-close:hover { color: #fff; }");
                sb.AppendLine("@keyframes fadeIn { from { opacity: 0; transform: scale(0.96); } to { opacity: 1; transform: scale(1); } }");
                sb.AppendLine(".footer { text-align: center; color: #64748B; font-size: 12px; margin-top: 36px; padding-top: 18px; border-top: 1px solid #262626; }");
                sb.AppendLine("</style>");
                sb.AppendLine("<script>");
                sb.AppendLine("function filterTickets() {");
                sb.AppendLine("  var filter = document.getElementById('ticketSearch').value.toLowerCase();");
                sb.AppendLine("  var rows = document.querySelectorAll('#ticketTable tbody tr');");
                sb.AppendLine("  rows.forEach(function(row) {");
                sb.AppendLine("    var text = row.textContent.toLowerCase();");
                sb.AppendLine("    row.style.display = text.indexOf(filter) > -1 ? '' : 'none';");
                sb.AppendLine("  });");
                sb.AppendLine("}");
                sb.AppendLine("function filterInventory() {");
                sb.AppendLine("  var filter = document.getElementById('invSearch').value.toLowerCase();");
                sb.AppendLine("  var rows = document.querySelectorAll('#invTable tbody tr');");
                sb.AppendLine("  rows.forEach(function(row) {");
                sb.AppendLine("    var text = row.textContent.toLowerCase();");
                sb.AppendLine("    row.style.display = text.indexOf(filter) > -1 ? '' : 'none';");
                sb.AppendLine("  });");
                sb.AppendLine("}");
                sb.AppendLine("var activeResolveId = null;");
                sb.AppendLine("function resolveTicket(id) {");
                sb.AppendLine("  activeResolveId = id;");
                sb.AppendLine("  document.getElementById('resolveNoteText').value = '';");
                sb.AppendLine("  document.getElementById('resolveModal').style.display = 'flex';");
                sb.AppendLine("  setTimeout(function() { document.getElementById('resolveNoteText').focus(); }, 100);");
                sb.AppendLine("}");
                sb.AppendLine("function closeResolveModal() {");
                sb.AppendLine("  document.getElementById('resolveModal').style.display = 'none';");
                sb.AppendLine("  activeResolveId = null;");
                sb.AppendLine("}");
                sb.AppendLine("function confirmResolveModal() {");
                sb.AppendLine("  if (!activeResolveId) return;");
                sb.AppendLine("  var note = document.getElementById('resolveNoteText').value.trim();");
                sb.AppendLine("  window.location.href = '/api/tickets/resolve?id=' + activeResolveId + '&note=' + encodeURIComponent(note);");
                sb.AppendLine("}");
                sb.AppendLine("function showInvDetail(btn) {");
                sb.AppendLine("  var d = btn.dataset;");
                sb.AppendLine("  document.getElementById('invDetailTitle').innerText = '🖥️ ' + (d.loc || 'Cihaz') + ' - Donanım Detayı';");
                sb.AppendLine("  document.getElementById('invDetailBrandModel').innerText = (d.brand || '') + ' ' + (d.model || '');");
                sb.AppendLine("  document.getElementById('invDetailSerial').innerText = d.serial || '-';");
                sb.AppendLine("  document.getElementById('invDetailIp').innerText = d.ip || '-';");
                sb.AppendLine("  document.getElementById('invDetailMac').innerText = d.mac || '-';");
                sb.AppendLine("  document.getElementById('invDetailMb').innerText = d.mb || 'Belirtilmedi';");
                sb.AppendLine("  document.getElementById('invDetailCpu').innerText = d.cpu || 'Belirtilmedi';");
                sb.AppendLine("  document.getElementById('invDetailRam').innerText = d.ram || 'Belirtilmedi';");
                sb.AppendLine("  document.getElementById('invDetailDisk').innerText = d.disk || 'Belirtilmedi';");
                sb.AppendLine("  document.getElementById('invDetailGpu').innerText = d.gpu || 'Belirtilmedi';");
                sb.AppendLine("  document.getElementById('invDetailOs').innerText = d.os || 'Belirtilmedi';");
                sb.AppendLine("  document.getElementById('invDetailUser').innerText = d.user || '-';");
                sb.AppendLine("  document.getElementById('invDetailDept').innerText = (d.dept || '') + ' / ' + (d.unit || '');");
                sb.AppendLine("  document.getElementById('invDetailLoc').innerText = d.loc || '-';");
                sb.AppendLine("  document.getElementById('invDetailDate').innerText = d.date || '-';");
                sb.AppendLine("  document.getElementById('invCopyStatus').innerText = '';");
                sb.AppendLine("  document.getElementById('invDetailModal').style.display = 'flex';");
                sb.AppendLine("}");
                sb.AppendLine("function closeInvDetailModal() {");
                sb.AppendLine("  document.getElementById('invDetailModal').style.display = 'none';");
                sb.AppendLine("}");
                sb.AppendLine("function copyInvSerial() {");
                sb.AppendLine("  var sn = document.getElementById('invDetailSerial').innerText;");
                sb.AppendLine("  if (navigator.clipboard) {");
                sb.AppendLine("    navigator.clipboard.writeText(sn).then(function() {");
                sb.AppendLine("      document.getElementById('invCopyStatus').innerText = '✓ Seri No kopyalandı!';");
                sb.AppendLine("    });");
                sb.AppendLine("  }");
                sb.AppendLine("}");
                sb.AppendLine($"var currentSyncState = 'T:{totalTickets}|O:{openTickets}|R:{resolvedTickets}|I:{inventoryCount}|D:{departments.Count}';");
                sb.AppendLine("setInterval(function() {");
                sb.AppendLine("  var isModalVisible = (document.getElementById('resolveModal') && document.getElementById('resolveModal').style.display === 'flex') || (document.getElementById('invDetailModal') && document.getElementById('invDetailModal').style.display === 'flex');");
                sb.AppendLine("  var isFieldFocused = document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA');");
                sb.AppendLine("  if (isModalVisible || isFieldFocused) return;");
                sb.AppendLine("  fetch('/api/sync/state')");
                sb.AppendLine("    .then(function(res) { return res.json(); })");
                sb.AppendLine("    .then(function(data) {");
                sb.AppendLine("      var newState = 'T:' + data.total + '|O:' + data.open + '|R:' + data.resolved + '|I:' + data.inventory + '|D:' + data.depts;");
                sb.AppendLine("      if (newState !== currentSyncState) {");
                sb.AppendLine("        window.location.reload();");
                sb.AppendLine("      }");
                sb.AppendLine("    })");
                sb.AppendLine("    .catch(function(err) {});");
                sb.AppendLine("}, 2500);");
                sb.AppendLine("</script>");
                sb.AppendLine("</head><body><div class='container'>");

                // Modal Popup for Ticket Resolution
                sb.AppendLine("<div id='resolveModal' class='modal-overlay'>");
                sb.AppendLine("  <div class='modal-card'>");
                sb.AppendLine("    <div class='modal-header'>");
                sb.AppendLine("      <div class='modal-title'>✓ Arıza Kaydını Çöz ve Kapat</div>");
                sb.AppendLine("      <button type='button' class='modal-close' onclick='closeResolveModal()'>✕</button>");
                sb.AppendLine("    </div>");
                sb.AppendLine("    <div style='font-size:13px;color:var(--text-muted);margin-bottom:12px;'>Yapılan işlem ve arıza çözüm açıklamasını giriniz (İsteğe bağlı):</div>");
                sb.AppendLine("    <textarea id='resolveNoteText' rows='4' placeholder='Örn: Yapılan teknik müdahale, parça değişimi veya uygulanan çözüm detayı...' style='margin-bottom:16px;'></textarea>");
                sb.AppendLine("    <div style='display:flex;justify-content:flex-end;gap:10px;'>");
                sb.AppendLine("      <button type='button' onclick='closeResolveModal()' style='background:#333;color:#fff;border:none;padding:10px 18px;border-radius:6px;cursor:pointer;font-weight:600;'>Vazgeç</button>");
                sb.AppendLine("      <button type='button' onclick='confirmResolveModal()' class='btn-primary' style='background:#107C41;'>✓ Arızayı Çözüldü Olarak Kapat</button>");
                sb.AppendLine("    </div>");
                sb.AppendLine("  </div>");
                sb.AppendLine("</div>");
                sb.AppendLine("");
                sb.AppendLine("<!-- Modal Popup for Computer Hardware & Inventory Detail -->");
                sb.AppendLine("<div id='invDetailModal' class='modal-overlay'>");
                sb.AppendLine("  <div class='modal-card' style='max-width:620px;'>");
                sb.AppendLine("    <div class='modal-header'>");
                sb.AppendLine("      <div class='modal-title' id='invDetailTitle' style='color:#38BDF8;'>🖥️ Donanım &amp; Zimmet Detayı</div>");
                sb.AppendLine("      <button type='button' class='modal-close' onclick='closeInvDetailModal()'>✕</button>");
                sb.AppendLine("    </div>");
                sb.AppendLine("    <div style='background:#181818;border:1px solid #333;border-radius:8px;padding:12px;margin-bottom:12px;'>");
                sb.AppendLine("      <div style='font-size:11px;font-weight:700;color:#38BDF8;margin-bottom:6px;'>🏷️ CİHAZ VE KİMLİK</div>");
                sb.AppendLine("      <div style='display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;'>");
                sb.AppendLine("        <div style='font-size:12px;color:var(--text-muted);'>Marka / Model:</div>");
                sb.AppendLine("        <div id='invDetailBrandModel' style='font-weight:700;color:#fff;font-size:13px;'>-</div>");
                sb.AppendLine("      </div>");
                sb.AppendLine("      <div style='display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;'>");
                sb.AppendLine("        <div style='font-size:12px;color:var(--text-muted);'>Seri No / HWID:</div>");
                sb.AppendLine("        <div style='display:flex;align-items:center;gap:8px;'>");
                sb.AppendLine("          <code id='invDetailSerial' style='color:#38BDF8;background:#111;padding:3px 8px;border-radius:4px;font-family:Consolas,monospace;'>-</code>");
                sb.AppendLine("          <button type='button' onclick='copyInvSerial()' style='background:#2B2B2B;color:#E2E8F0;border:1px solid #444;border-radius:4px;padding:3px 8px;font-size:11px;cursor:pointer;'>📋 Kopyala</button>");
                sb.AppendLine("        </div>");
                sb.AppendLine("      </div>");
                sb.AppendLine("      <div style='display:flex;justify-content:space-between;align-items:center;font-size:12px;'>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>IP:</span> <code id='invDetailIp' style='color:#A78BFA;font-family:Consolas,monospace;'>-</code></div>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>MAC:</span> <code id='invDetailMac' style='color:#94A3B8;font-family:Consolas,monospace;'>-</code></div>");
                sb.AppendLine("      </div>");
                sb.AppendLine("    </div>");
                sb.AppendLine("    <div style='background:#181818;border:1px solid #333;border-radius:8px;padding:12px;margin-bottom:12px;'>");
                sb.AppendLine("      <div style='font-size:11px;font-weight:700;color:#4ADE80;margin-bottom:8px;'>⚙️ DONANIM BİLEŞEN DETAYLARI</div>");
                sb.AppendLine("      <div style='display:grid;grid-template-columns:1fr 1fr;gap:8px;font-size:12px;'>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>🧩 Anakart:</span> <span id='invDetailMb' style='color:#fff;'>-</span></div>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>⚡ İşlemci:</span> <span id='invDetailCpu' style='color:#4ADE80;font-weight:600;'>-</span></div>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>💾 Bellek (RAM):</span> <span id='invDetailRam' style='color:#fff;'>-</span></div>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>💽 Depolama:</span> <span id='invDetailDisk' style='color:#fff;'>-</span></div>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>🎮 Ekran Kartı:</span> <span id='invDetailGpu' style='color:#fff;'>-</span></div>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>🪟 İşletim Sistemi:</span> <span id='invDetailOs' style='color:#fff;'>-</span></div>");
                sb.AppendLine("      </div>");
                sb.AppendLine("    </div>");
                sb.AppendLine("    <div style='background:#181818;border:1px solid #333;border-radius:8px;padding:12px;margin-bottom:14px;'>");
                sb.AppendLine("      <div style='font-size:11px;font-weight:700;color:#F59E0B;margin-bottom:6px;'>👤 ZİMMET VE KULLANICI BİLGİSİ</div>");
                sb.AppendLine("      <div style='display:flex;justify-content:space-between;align-items:center;margin-bottom:4px;font-size:12px;'>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>Zimmetli Personel:</span> <strong id='invDetailUser' style='color:#fff;'>-</strong></div>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>Kayıt Tarihi:</span> <span id='invDetailDate' style='color:#94A3B8;'>-</span></div>");
                sb.AppendLine("      </div>");
                sb.AppendLine("      <div style='display:flex;justify-content:space-between;align-items:center;font-size:12px;'>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>Müdürlük &amp; Birim:</span> <span id='invDetailDept' style='color:#fff;'>-</span></div>");
                sb.AppendLine("        <div><span style='color:var(--text-muted);'>Cihaz / Konum:</span> <span id='invDetailLoc' style='color:#fff;'>-</span></div>");
                sb.AppendLine("      </div>");
                sb.AppendLine("    </div>");
                sb.AppendLine("    <div style='display:flex;justify-content:space-between;align-items:center;'>");
                sb.AppendLine("      <span id='invCopyStatus' style='font-size:12px;color:#4ADE80;'></span>");
                sb.AppendLine("      <button type='button' onclick='closeInvDetailModal()' style='background:#0078D4;color:#fff;border:none;padding:9px 20px;border-radius:6px;cursor:pointer;font-weight:600;'>Kapat</button>");
                sb.AppendLine("    </div>");
                sb.AppendLine("  </div>");
                sb.AppendLine("</div>");

                // Header
                sb.AppendLine("<div class='header-bar'>");
                sb.AppendLine("  <div>");
                sb.AppendLine("    <div class='brand-title'>💼 SysForge Studio &bull; BT Teknik Servis Masası</div>");
                sb.AppendLine("    <div class='brand-sub'>Müdürlük &amp; Birim Çağrı Yönetimi, Canlı Arıza Bildirimi ve Donanım Envanter Konsolu</div>");
                sb.AppendLine("  </div>");
                sb.AppendLine("  <div class='sys-status'><span class='pulse-dot'></span> Sunucu Çevrimiçi</div>");
                sb.AppendLine("</div>");

                if (!string.IsNullOrEmpty(toastHtml))
                {
                    sb.AppendLine(toastHtml);
                }

                // KPI Metric Summary Cards
                sb.AppendLine("<div class='kpi-grid'>");
                sb.AppendLine($"  <div class='kpi-card'><div class='kpi-title' style='color:#F59E0B;'>Açık Arıza Talepleri</div><div class='kpi-num' style='color:#FBBF24;'>{openTickets}</div></div>");
                sb.AppendLine($"  <div class='kpi-card'><div class='kpi-title' style='color:#107C41;'>Çözülen Çağrılar</div><div class='kpi-num' style='color:#4ADE80;'>{resolvedTickets}</div></div>");
                sb.AppendLine($"  <div class='kpi-card'><div class='kpi-title' style='color:#0078D4;'>Toplam Talep</div><div class='kpi-num' style='color:#38BDF8;'>{totalTickets}</div></div>");
                sb.AppendLine($"  <div class='kpi-card'><div class='kpi-title' style='color:#8B5CF6;'>Kayıtlı Cihaz Envanteri</div><div class='kpi-num' style='color:#A78BFA;'>{inventoryCount}</div></div>");
                sb.AppendLine("</div>");

                // 1. Department & Unit Management Card
                sb.AppendLine("<div class='card'>");
                sb.AppendLine("  <div class='card-header'><div class='card-title'>🏢 Müdürlük &amp; Alt Birim Yönetimi</div><span style='font-size:12px;color:var(--text-muted);'>Müdürlük ekleme, birim bağlama ve silme işlemleri</span></div>");
                sb.AppendLine("  <div style='display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px;margin-bottom:20px;'>");
                
                // Add Dept form
                sb.AppendLine("    <form method='POST' action='/api/departments/create' style='display:flex;gap:8px;align-items:flex-end;'>");
                sb.AppendLine("      <div style='flex:1;'><label>Yeni Müdürlük Adı</label><input type='text' name='name' placeholder='Örn: İnsan Kaynakları Müdürlüğü' required/></div>");
                sb.AppendLine("      <button type='submit' class='btn-primary' style='height:42px;padding:0 16px;white-space:nowrap;'>➕ Müdürlük Ekle</button>");
                sb.AppendLine("    </form>");

                // Add Unit form with target department select
                sb.AppendLine("    <form method='POST' action='/api/units/create' style='display:flex;gap:8px;align-items:flex-end;'>");
                sb.AppendLine("      <div style='flex:1;'><label>Hedef Müdürlük</label><select name='dept_id' required>");
                foreach (var d in departments)
                {
                    sb.AppendLine($"        <option value='{d.Id}'>{d.Name}</option>");
                }
                sb.AppendLine("      </select></div>");
                sb.AppendLine("      <div style='flex:1;'><label>Yeni Alt Birim Adı</label><input type='text' name='name' placeholder='Örn: Özlük İşleri' required/></div>");
                sb.AppendLine("      <button type='submit' class='btn-primary' style='height:42px;padding:0 16px;background:#383838;white-space:nowrap;'>➕ Birim Ekle</button>");
                sb.AppendLine("    </form>");
                sb.AppendLine("  </div>");

                // Existing Departments List with Delete buttons
                if (departments.Count == 0)
                {
                    sb.AppendLine("  <div style='color:var(--text-muted);font-size:13px;'>Henüz kayıtlı müdürlük bulunmuyor.</div>");
                }
                else
                {
                    foreach (var d in departments)
                    {
                        sb.AppendLine("  <div class='dept-card'>");
                        sb.AppendLine("    <div class='dept-header'>");
                        sb.AppendLine($"      <div><strong style='color:#38BDF8;'>🏢 {d.Name}</strong> <span style='font-size:11.5px;color:var(--text-muted);margin-left:6px;'>({d.Units.Count} Alt Birim)</span></div>");
                        sb.AppendLine($"      <a href='/api/departments/delete?id={d.Id}' class='action-link action-delete' onclick='return confirm(\"{d.Name} müdürlüğünü ve tüm alt birimlerini silmek istediğinize emin misiniz?\")'>🗑️ Müdürlüğü Sil</a>");
                        sb.AppendLine("    </div>");

                        if (d.Units.Count > 0)
                        {
                            sb.AppendLine("    <div style='display:flex;flex-wrap:wrap;'>");
                            foreach (var u in d.Units)
                            {
                                sb.AppendLine($"      <span class='unit-pill'>{u.Name} <a href='/api/units/delete?id={u.Id}' class='unit-del' onclick='return confirm(\"{u.Name} birimini silmek istediğinize emin misiniz?\")'>✕</a></span>");
                            }
                            sb.AppendLine("    </div>");
                        }
                        sb.AppendLine("  </div>");
                    }
                }
                sb.AppendLine("</div>");

                // 2. New Ticket Form Card
                sb.AppendLine("<div class='card'>");
                sb.AppendLine("  <div class='card-header'><div class='card-title'>➕ Yeni Arıza / Teknik Destek Talebi Oluştur</div><span style='font-size:12px;color:var(--text-muted);'>Ağdaki tüm personeller buradan kayıt bırakabilir</span></div>");
                sb.AppendLine("  <form method='POST' action='/api/tickets/create'>");
                sb.AppendLine("    <div class='form-grid'>");
                sb.AppendLine("      <div><label>Personel Adı Soyadı *</label><input type='text' name='personnel' placeholder='Örn: Ahmet Yılmaz' required/></div>");
                sb.AppendLine("      <div><label>Müdürlük *</label><select name='department' required>");
                foreach (var d in departments)
                {
                    sb.AppendLine($"        <option value='{d.Name}'>{d.Name}</option>");
                }
                sb.AppendLine("      </select></div>");
                sb.AppendLine("      <div><label>Alt Birim / Oda No / Dahili</label><input type='text' name='unit' placeholder='Örn: Muhasebe / Oda 204 / Dahili: 1402'/></div>");
                sb.AppendLine("      <div><label>Arıza Kategorisi</label><select name='issue_type'>");
                sb.AppendLine("        <option value='Yazıcı Sorunu'>🖨️ Yazıcı Sorunu</option>");
                sb.AppendLine("        <option value='Ağ / İnternet'>🌐 Ağ / İnternet Kesintisi</option>");
                sb.AppendLine("        <option value='Donanım Arızası'>🖥️ Bilgisayar / Donanım Arızası</option>");
                sb.AppendLine("        <option value='Yazılım / İşletim Sistemi'>💾 Yazılım / Windows Hatası</option>");
                sb.AppendLine("        <option value='E-Posta / Hesap'>✉️ E-Posta / Şifre Talebi</option>");
                sb.AppendLine("      </select></div>");
                sb.AppendLine("      <div><label>Öncelik Derecesi</label><select name='priority'>");
                sb.AppendLine("        <option value='Normal'>Normal</option>");
                sb.AppendLine("        <option value='Düşük'>Düşük</option>");
                sb.AppendLine("        <option value='Yüksek'>Yüksek</option>");
                sb.AppendLine("        <option value='Acil'>🔥 Acil (Kritik İş Engeli)</option>");
                sb.AppendLine("      </select></div>");
                sb.AppendLine("    </div>");
                sb.AppendLine("    <div style='margin-bottom:16px;'><label>Arıza veya Talep Detayı *</label><textarea name='desc' rows='3' placeholder='Lütfen karşılaştığınız sorunu, hata mesajını veya talebinizi detaylı olarak açıklayın...' required></textarea></div>");
                sb.AppendLine("    <button type='submit' class='btn-primary'>🚀 Arıza Bildirimini Servise Gönder</button>");
                sb.AppendLine("  </form>");
                sb.AppendLine("</div>");

                // 3. Tickets List Card
                sb.AppendLine("<div class='card'>");
                sb.AppendLine("  <div class='card-header'><div class='card-title'>🎫 Arıza &amp; Destek Talepleri Listesi</div><span style='font-size:12px;color:var(--text-muted);'>Toplam " + totalTickets + " kayıt listeleniyor</span></div>");
                sb.AppendLine("  <div class='search-box'><input type='text' id='ticketSearch' class='search-input' onkeyup='filterTickets()' placeholder='🔍 Personel, müdürlük, kategori veya açıklama ara...'/></div>");
                sb.AppendLine("  <div style='overflow-x:auto;'><table id='ticketTable'>");
                sb.AppendLine("    <thead><tr><th>ID</th><th>Personel</th><th>Müdürlük &amp; Birim</th><th>Kategori</th><th>Öncelik</th><th>Açıklama</th><th>Tarih</th><th>Durum</th><th>İşlem</th></tr></thead>");
                sb.AppendLine("    <tbody>");
                if (tickets.Count == 0)
                {
                    sb.AppendLine("      <tr><td colspan='9' style='text-align:center;color:var(--text-muted);padding:24px;'>Henüz kayıtlı arıza talebi bulunmuyor.</td></tr>");
                }
                else
                {
                    foreach (var t in tickets)
                    {
                        string chipClass = t.Status == "Çözüldü" ? "chip-done" : "chip-open";
                        string resolutionHtml = string.IsNullOrWhiteSpace(t.ResolutionNote) 
                            ? "" 
                            : $"<div style='margin-top:6px;padding:4px 8px;background:rgba(16,124,65,0.15);border-left:3px solid #107C41;border-radius:3px;font-size:11.5px;color:#86EFAC;'><strong>💡 Çözüm:</strong> {t.ResolutionNote}</div>";

                        sb.AppendLine($"      <tr>");
                        sb.AppendLine($"        <td><strong>#{t.Id}</strong></td>");
                        sb.AppendLine($"        <td><strong>{t.PersonnelName}</strong></td>");
                        sb.AppendLine($"        <td>{t.Department}<br/><span style='font-size:11px;color:var(--text-muted);'>{t.Unit}</span></td>");
                        sb.AppendLine($"        <td>{t.IssueType}</td>");
                        sb.AppendLine($"        <td><span class='chip chip-priority'>{t.Priority}</span></td>");
                        sb.AppendLine($"        <td style='max-width:320px;'>{t.Description}{resolutionHtml}</td>");
                        sb.AppendLine($"        <td style='font-size:12px;color:var(--text-muted);'>{t.Date}</td>");
                        sb.AppendLine($"        <td><span class='chip {chipClass}'>{t.Status}</span></td>");
                        sb.AppendLine($"        <td>");
                        if (t.Status != "Çözüldü")
                        {
                            sb.AppendLine($"          <a href='javascript:void(0)' onclick='resolveTicket({t.Id})' class='action-link action-resolve'>✓ Çözüldü</a>");
                        }
                        sb.AppendLine($"          <a href='/api/tickets/delete?id={t.Id}' class='action-link action-delete' onclick='return confirm(\"Bu kaydı silmek istediğinize emin misiniz?\")'>🗑️</a>");
                        sb.AppendLine($"        </td>");
                        sb.AppendLine($"      </tr>");
                    }
                }
                sb.AppendLine("    </tbody></table></div>");
                sb.AppendLine("</div>");

                // 3. Hardware Inventory Card
                sb.AppendLine("<div class='card'>");
                sb.AppendLine("  <div class='card-header'><div class='card-title'>🖥️ Cihaz &amp; Donanım Zimmet Envanteri</div><span style='font-size:12px;color:var(--text-muted);'>Kayıtlı " + inventoryCount + " donanım</span></div>");
                sb.AppendLine("  <div class='search-box'><input type='text' id='invSearch' class='search-input' onkeyup='filterInventory()' placeholder='🔍 Marka, model, seri no, IP veya zimmetli personel ara...'/></div>");
                sb.AppendLine("  <div style='overflow-x:auto;'><table id='invTable'>");
                sb.AppendLine("    <thead><tr><th>Marka / Model</th><th>Seri Numarası / HWID</th><th>IP Adresi</th><th>Müdürlük &amp; Konum</th><th>Zimmetli Kullanıcı</th><th style='text-align:right;'>İşlem</th></tr></thead>");
                sb.AppendLine("    <tbody>");
                if (inventory.Count == 0)
                {
                    sb.AppendLine("      <tr><td colspan='6' style='text-align:center;color:var(--text-muted);padding:24px;'>Henüz zimmet envanteri eklenmedi. Masaüstü uygulamasından otomatik eklenebilir.</td></tr>");
                }
                else
                {
                    foreach (var inv in inventory)
                    {
                        sb.AppendLine($"      <tr>");
                        sb.AppendLine($"        <td><strong style='color:#fff;'>{System.Net.WebUtility.HtmlEncode(inv.Brand)}</strong><div style='font-size:11px;color:var(--text-muted);'>{System.Net.WebUtility.HtmlEncode(inv.Model)}</div></td>");
                        sb.AppendLine($"        <td><code style='color:#38BDF8;font-family:Consolas,monospace;max-width:180px;display:inline-block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;' title='{System.Net.WebUtility.HtmlEncode(inv.SerialNo)}'>{System.Net.WebUtility.HtmlEncode(inv.SerialNo)}</code></td>");
                        sb.AppendLine($"        <td><code style='color:#A78BFA;font-family:Consolas,monospace;'>{System.Net.WebUtility.HtmlEncode(inv.IpAddress)}</code></td>");
                        sb.AppendLine($"        <td>{System.Net.WebUtility.HtmlEncode(inv.Department)} / {System.Net.WebUtility.HtmlEncode(inv.Unit)}<br/><span style='font-size:11px;color:var(--text-muted);'>{System.Net.WebUtility.HtmlEncode(inv.Location)}</span></td>");
                        sb.AppendLine($"        <td><strong>{System.Net.WebUtility.HtmlEncode(inv.UserName)}</strong><div style='font-size:11px;color:var(--text-muted);'>{System.Net.WebUtility.HtmlEncode(inv.Date)}</div></td>");
                        sb.AppendLine($"        <td style='text-align:right;'>");
                        sb.AppendLine($"          <button type='button' class='btn' style='background:#1E3A8A;color:#93C5FD;border:1px solid #2563EB;padding:5px 12px;border-radius:5px;font-size:12px;cursor:pointer;font-weight:600;' ");
                        sb.AppendLine($"            data-brand='{System.Net.WebUtility.HtmlEncode(inv.Brand)}' ");
                        sb.AppendLine($"            data-model='{System.Net.WebUtility.HtmlEncode(inv.Model)}' ");
                        sb.AppendLine($"            data-serial='{System.Net.WebUtility.HtmlEncode(inv.SerialNo)}' ");
                        sb.AppendLine($"            data-ip='{System.Net.WebUtility.HtmlEncode(inv.IpAddress)}' ");
                        sb.AppendLine($"            data-mac='{System.Net.WebUtility.HtmlEncode(inv.DisplayMacAddress)}' ");
                        sb.AppendLine($"            data-mb='{System.Net.WebUtility.HtmlEncode(inv.DisplayMotherboard)}' ");
                        sb.AppendLine($"            data-cpu='{System.Net.WebUtility.HtmlEncode(inv.DisplayProcessor)}' ");
                        sb.AppendLine($"            data-ram='{System.Net.WebUtility.HtmlEncode(inv.DisplayRam)}' ");
                        sb.AppendLine($"            data-disk='{System.Net.WebUtility.HtmlEncode(inv.DisplayDisk)}' ");
                        sb.AppendLine($"            data-gpu='{System.Net.WebUtility.HtmlEncode(inv.DisplayGpu)}' ");
                        sb.AppendLine($"            data-os='{System.Net.WebUtility.HtmlEncode(inv.DisplayOsVersion)}' ");
                        sb.AppendLine($"            data-user='{System.Net.WebUtility.HtmlEncode(inv.UserName)}' ");
                        sb.AppendLine($"            data-dept='{System.Net.WebUtility.HtmlEncode(inv.Department)}' ");
                        sb.AppendLine($"            data-unit='{System.Net.WebUtility.HtmlEncode(inv.Unit)}' ");
                        sb.AppendLine($"            data-loc='{System.Net.WebUtility.HtmlEncode(inv.Location)}' ");
                        sb.AppendLine($"            data-date='{System.Net.WebUtility.HtmlEncode(inv.Date)}' ");
                        sb.AppendLine($"            onclick='showInvDetail(this)'>🔍 Detay</button>");
                        sb.AppendLine($"        </td>");
                        sb.AppendLine($"      </tr>");
                    }
                }
                sb.AppendLine("    </tbody></table></div>");
                sb.AppendLine("</div>");

                // Footer
                sb.AppendLine("<div class='footer'>SysForge Studio Enterprise IT Suite &bull; Yerel Dahili C# Web Konsolu &bull; Windows 11 Fluent Tasarım</div>");
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