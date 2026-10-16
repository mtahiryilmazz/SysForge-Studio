using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using UltimateToolkit.Modern.Models;

namespace UltimateToolkit.Modern.Services
{
    public class AIDiagnosticEngine
    {
        public static AIDiagnosticEngine Instance { get; } = new AIDiagnosticEngine();

        public string ApiKey { get; set; } = "";
        private readonly HttpClient _http = new();

        public AIDiagnosticEngine()
        {
            LoadSavedApiKey();
        }

        private void LoadSavedApiKey()
        {
            string appData = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "SysForgeStudio");
            string keyFile = Path.Combine(appData, "gemini_api.key");
            if (File.Exists(keyFile))
            {
                try { ApiKey = File.ReadAllText(keyFile).Trim(); } catch { }
            }
        }

        public void SaveApiKey(string key)
        {
            ApiKey = key.Trim();
            string appData = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "SysForgeStudio");
            try
            {
                Directory.CreateDirectory(appData);
                File.WriteAllText(Path.Combine(appData, "gemini_api.key"), ApiKey, Encoding.UTF8);
            }
            catch { }
        }

        public async Task<AISolutionResult> AnalyzeIssueAsync(string query)
        {
            query = query.Trim();

            // 1. If Gemini API key is available, attempt real cloud AI generation
            if (!string.IsNullOrWhiteSpace(ApiKey))
            {
                try
                {
                    var cloudResult = await QueryGeminiApiAsync(query);
                    if (cloudResult != null) return cloudResult;
                }
                catch { }
            }

            // 2. Fallback to Local Built-in Offline Expert Rule Engine
            return GetLocalExpertSolution(query);
        }

        private AISolutionResult GetLocalExpertSolution(string q)
        {
            string qLower = q.ToLowerInvariant();

            // 0x0000011b Print RPC Error
            if (qLower.Contains("11b") || (qLower.Contains("yazıcı") && qLower.Contains("rpc")))
            {
                return new AISolutionResult
                {
                    Title = "Ağ Yazıcısı RPC Kimlik Doğrulama Hatası (0x0000011b)",
                    RootCause = "Windows Update (CVE-2021-36958) sonrası Point&Print RPC kimlik doğrulama zorunluluğundan kaynaklanan ağ yazıcı erişim engeli.",
                    Severity = "Yüksek",
                    Steps = new List<string>
                    {
                        "Kayıt defterinde RpcAuthnLevelPrivacyEnabled değeri 0 olarak ayarlanmalı.",
                        "Yazdırma Biriktiricisi (Spooler) servisi yeniden başlatılmalı.",
                        "İstemci bilgisayar yeniden başlatılmadan yazıcı bağlantısı test edilmeli."
                    },
                    AutoFixScript = @"reg add ""HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Print"" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f; net stop spooler; net start spooler"
                };
            }

            // 0x00000709
            if (qLower.Contains("709") || (qLower.Contains("varsayılan") && qLower.Contains("yazıcı")))
            {
                return new AISolutionResult
                {
                    Title = "Yazıcı Bağlantı / Varsayılan Aygıt Hatası (0x00000709)",
                    RootCause = "Windows kayıt defterindeki yazıcı aygıt eşlemesi izinlerinin bozulması veya DNS CNAME isim çözümleme kısıtlaması.",
                    Severity = "Orta",
                    Steps = new List<string>
                    {
                        "Print Spooler kayıt defteri CNAME eşleme izni eklenmeli.",
                        "Windows'un varsayılan yazıcıyı yönetme özelliği devre dışı bırakılmalı."
                    },
                    AutoFixScript = @"reg add ""HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers"" /v ForceKerberosForRpc /t REG_DWORD /d 0 /f; reg add ""HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers"" /v RestrictDriverInstallationToAdministrators /t REG_DWORD /d 0 /f; net stop spooler; net start spooler"
                };
            }

            // Spooler Crash / Kuyruk Takılması
            if (qLower.Contains("spooler") || qLower.Contains("kuyruk") || qLower.Contains("yazdırmıyor"))
            {
                return new AISolutionResult
                {
                    Title = "Yazdırma Biriktiricisi (Print Spooler) Kilitlenmesi",
                    RootCause = "C:\\Windows\\System32\\spool\\PRINTERS klasöründe bozuk veya takılı kalmış .SHD/.SPL yazdırma işi dosyaları birikmiş.",
                    Severity = "Normal",
                    Steps = new List<string>
                    {
                        "Spooler servisini durdur.",
                        "PRINTERS klasöründeki tüm geçici dosyaları zorla temizle.",
                        "Spooler servisini tekrar başlat."
                    },
                    AutoFixScript = @"net stop spooler; Stop-Process -Name spoolsv -Force -ErrorAction SilentlyContinue; Remove-Item ""C:\Windows\System32\spool\PRINTERS\*"" -Force -Recurse; net start spooler"
                };
            }

            // DNS / Ağ Bağlantı Hatası
            if (qLower.Contains("dns") || qLower.Contains("internet") || qLower.Contains("ip"))
            {
                return new AISolutionResult
                {
                    Title = "Ağ Yığını & DNS Çözümleme Hatası",
                    RootCause = "Winsock protokol yığını veya bozulmuş DNS yerel önbellek kayıtları.",
                    Severity = "Orta",
                    Steps = new List<string>
                    {
                        "DNS önbelleğini temizle.",
                        "Winsock kataloğunu sıfırla.",
                        "TCP/IP arayüzünü yenile."
                    },
                    AutoFixScript = @"ipconfig /flushdns; ipconfig /release; ipconfig /renew; netsh winsock reset; netsh int ip reset"
                };
            }

            // SFC / DISM / Sistem Bozulması
            if (qLower.Contains("bozuk") || qLower.Contains("sistem") || qLower.Contains("mavi") || qLower.Contains("bsod") || qLower.Contains("yavaş"))
            {
                return new AISolutionResult
                {
                    Title = "Windows Sistem Dosyası & İmaj Bütünlük Onarımı",
                    RootCause = "Sistem DLL dosyaları veya bileşen deposunda (WinSxS) eksik ya da hasarlı paketler.",
                    Severity = "Yüksek",
                    Steps = new List<string>
                    {
                        "DISM ile çevrimiçi bileşen deposunu onar.",
                        "SFC ile sistem dosyalarını tara ve düzelt."
                    },
                    AutoFixScript = @"dism /online /cleanup-image /restorehealth; sfc /scannow"
                };
            }

            // Default Generic Expert Solution
            return new AISolutionResult
            {
                Title = $"BT Teşhis Raporu: {q}",
                RootCause = "Belirtilen arıza için otomatik akıllı analiz tamamlandı. Sistem kaynakları, servisler ve kayıt defteri denetimi önerilmektedir.",
                Severity = "Normal",
                Steps = new List<string>
                {
                    "Windows Olay Görüntüleyicisi (Event Viewer) uygulama ve sistem loglarını kontrol edin.",
                    "İlgili servisin çalışma durumunu doğrulayın.",
                    "Gerekiyorsa servisleri ve önbellekleri sıfırlayın."
                },
                AutoFixScript = @"ipconfig /flushdns; Get-Service -Name Spooler, LanmanWorkstation | Restart-Service -Force"
            };
        }

        private async Task<AISolutionResult?> QueryGeminiApiAsync(string query)
        {
            string url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={ApiKey}";
            string prompt = $@"Sen üst düzey bir Kurumsal Windows ve Ağ BT Sistem Mühendisisin.
Aşağıdaki kullanıcı/teknisyen arızasını incele ve sadece geçerli JSON döndür (markdown kod blokları olmadan):
Arıza: {query}

JSON Formatı:
{{
  ""title"": ""Arıza Kısa Başlığı"",
  ""rootCause"": ""Teknik kök neden açıklaması"",
  ""severity"": ""Normal/Orta/Yüksek"",
  ""steps"": [""Adım 1"", ""Adım 2"", ""Adım 3""],
  ""autoFixScript"": ""Tek satırda veya noktalı virgüllü çalıştırılabilir PowerShell onarım komutu""
}}";

            var payload = new
            {
                contents = new[]
                {
                    new { parts = new[] { new { text = prompt } } }
                }
            };

            string jsonBody = JsonSerializer.Serialize(payload);
            using var content = new StringContent(jsonBody, Encoding.UTF8, "application/json");
            var response = await _http.PostAsync(url, content);

            if (response.IsSuccessStatusCode)
            {
                string resJson = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(resJson);
                string text = doc.RootElement
                    .GetProperty("candidates")[0]
                    .GetProperty("content")
                    .GetProperty("parts")[0]
                    .GetProperty("text").GetString() ?? "";

                text = text.Replace("```json", "").Replace("```", "").Trim();
                return JsonSerializer.Deserialize<AISolutionResult>(text, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            }

            return null;
        }
    }
}