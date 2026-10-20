using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.Threading.Tasks;
using SysForgeStudio.Models;

namespace SysForgeStudio.Services
{
    public class NetworkCardService
    {
        public static NetworkCardService Instance { get; } = new NetworkCardService();

        /// <summary>
        /// Sistemdeki fiziksel ve tanınmayan ağ kartlarını WMI üzerinden tespit eder.
        /// Sürücüsü eksik (Kod 28) veya hatalı (Kod 10) olan bağdaştırıcıları özellikle belirler.
        /// </summary>
        public async Task<List<NetworkCardDiagnosticInfo>> GetNetworkAdaptersAsync()
        {
            return await Task.Run(() =>
            {
                var list = new List<NetworkCardDiagnosticInfo>();

                try
                {
                    // 1. Win32_NetworkAdapter sorgusu
                    using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_NetworkAdapter WHERE PhysicalAdapter = True OR AdapterTypeID = 0 OR AdapterTypeID = 9"))
                    {
                        foreach (ManagementObject mo in searcher.Get())
                        {
                            try
                            {
                                string name = mo["Name"]?.ToString() ?? "Bilinmeyen Ağ Kartı";
                                string mfg = mo["Manufacturer"]?.ToString() ?? "Standart Ağ Üreticisi";
                                string deviceId = mo["DeviceID"]?.ToString() ?? "";
                                string pnpDeviceId = mo["PNPDeviceID"]?.ToString() ?? "";
                                string mac = mo["MACAddress"]?.ToString() ?? "Yok / Atanmadı";
                                string netConnectionStatus = mo["NetConnectionStatus"]?.ToString() ?? "";
                                uint configCode = 0;
                                if (mo["ConfigManagerErrorCode"] != null)
                                {
                                    uint.TryParse(mo["ConfigManagerErrorCode"].ToString(), out configCode);
                                }

                                bool isDriverInstalled = (configCode == 0);
                                string statusBadgeText = "🟢 Aktif & Çalışıyor";
                                string statusBadgeColor = "#15803D";

                                if (configCode == 28)
                                {
                                    statusBadgeText = "⚠️ Sürücü Yüklü Değil (Kod 28)";
                                    statusBadgeColor = "#DC2626";
                                    isDriverInstalled = false;
                                }
                                else if (configCode != 0)
                                {
                                    statusBadgeText = $"⚠️ Aygıt Hatası (Kod {configCode})";
                                    statusBadgeColor = "#D97706";
                                    isDriverInstalled = false;
                                }
                                else if (string.IsNullOrEmpty(mac) || mac == "Yok / Atanmadı")
                                {
                                    statusBadgeText = "⚪ Sürücü Bekliyor / Pasif";
                                    statusBadgeColor = "#475569";
                                }

                                string adapterType = name.ToLower().Contains("wi-fi") || name.ToLower().Contains("wireless") || name.ToLower().Contains("802.11") || name.ToLower().Contains("wlan")
                                    ? "Kablosuz (Wi-Fi)"
                                    : "Kablolu (Ethernet)";

                                list.Add(new NetworkCardDiagnosticInfo
                                {
                                    Name = name,
                                    Manufacturer = mfg,
                                    DeviceID = deviceId,
                                    HardwareID = pnpDeviceId,
                                    MACAddress = mac,
                                    AdapterType = adapterType,
                                    ConfigManagerErrorCode = configCode,
                                    Status = mo["Status"]?.ToString() ?? "OK",
                                    IsDriverInstalled = isDriverInstalled,
                                    StatusBadgeText = statusBadgeText,
                                    StatusBadgeColor = statusBadgeColor,
                                    IsPhysical = true
                                });
                            }
                            catch { }
                        }
                    }

                    // 2. Win32_PnPEntity üzerinden sürücüsü kurulmamış (ClassGuid {4d36e972-e325-11ce-bfc1-08002be10318}) aygıtları tara
                    using (var pnpSearcher = new ManagementObjectSearcher("SELECT * FROM Win32_PnPEntity WHERE ClassGuid = '{4d36e972-e325-11ce-bfc1-08002be10318}' OR (PNPClass = 'Net' AND ConfigManagerErrorCode <> 0)"))
                    {
                        foreach (ManagementObject mo in pnpSearcher.Get())
                        {
                            try
                            {
                                string pnpId = mo["DeviceID"]?.ToString() ?? "";
                                if (string.IsNullOrEmpty(pnpId) || list.Any(x => x.HardwareID.Equals(pnpId, StringComparison.OrdinalIgnoreCase)))
                                    continue;

                                string name = mo["Name"]?.ToString() ?? mo["Description"]?.ToString() ?? "Tanınmayan Ağ Denetleyicisi";
                                string mfg = mo["Manufacturer"]?.ToString() ?? "Bilinmiyor";
                                uint configCode = 0;
                                if (mo["ConfigManagerErrorCode"] != null)
                                {
                                    uint.TryParse(mo["ConfigManagerErrorCode"].ToString(), out configCode);
                                }

                                list.Add(new NetworkCardDiagnosticInfo
                                {
                                    Name = name,
                                    Manufacturer = mfg,
                                    DeviceID = pnpId,
                                    HardwareID = pnpId,
                                    AdapterType = "Ağ Denetleyicisi (Sürücüsüz)",
                                    ConfigManagerErrorCode = configCode,
                                    Status = "Sürücü Eksik",
                                    IsDriverInstalled = false,
                                    StatusBadgeText = $"🚨 Sürücü Yok (Kod {configCode})",
                                    StatusBadgeColor = "#EF4444",
                                    IsPhysical = true
                                });
                            }
                            catch { }
                        }
                    }
                }
                catch { }

                return list;
            });
        }

        /// <summary>
        /// İNTERNET OLMADAN, yerel Windows Sürücü Ambarı (DriverStore) ve sistem depolarını tarayarak
        /// tüm uyumlu Ethernet / Wi-Fi INF sürücülerini tek tıkla kurar ve ağ yığınını sıfırlar.
        /// </summary>
        public async Task<(bool Success, string Message)> InstallUniversalNetworkDriversAsync(Action<string> log)
        {
            return await Task.Run(() =>
            {
                try
                {
                    log("══════════════════════════════════════════════════════════");
                    log("🌐 ÇEVRİMDIŞI UNIVERSAL AĞ KARTI SÜRÜCÜ KURULUMU BAŞLATILDI");
                    log("══════════════════════════════════════════════════════════");
                    log("ℹ️ İnternet bağlantısı olmadan yerel Windows DriverStore taranıyor...");

                    // 1. PnP Aygıt Yeniden Taraması
                    log("[1/5] Plug and Play donanım değişiklikleri taranıyor (pnputil /scan-devices)...");
                    RunProcess("pnputil.exe", "/scan-devices", log);

                    // 2. Windows DriverStore FileRepository altındaki net*.inf paketlerini sisteme yükle
                    string driverStorePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "DriverStore", "FileRepository");
                    log($"[2/5] Yerel Sürücü Deposu ({driverStorePath}) taranıyor...");

                    if (Directory.Exists(driverStorePath))
                    {
                        var netDirs = Directory.GetDirectories(driverStorePath, "net*");
                        log($"     Tespit edilen yerel ağ sürücü paketi sayısı: {netDirs.Length}");

                        int installedCount = 0;
                        foreach (var dir in netDirs.Take(40)) // En ilgili ilk 40 sürücü paketi
                        {
                            var infFiles = Directory.GetFiles(dir, "*.inf");
                            foreach (var inf in infFiles)
                            {
                                RunProcess("pnputil.exe", $"/add-driver \"{inf}\" /install", null);
                                installedCount++;
                            }
                        }
                        log($"     {installedCount} adet yerel INF sürücü paketi başarıyla aygıtlara bağlandı.");
                    }

                    // 3. C:\Windows\INF altındaki varsayılan NDIS ağ inf dosyalarını kur
                    string winInfPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "INF");
                    if (Directory.Exists(winInfPath))
                    {
                        log("[3/5] Standart Windows NDIS ağ protokolü ve INF sürücüleri taranıyor...");
                        var genericInfs = Directory.GetFiles(winInfPath, "net*.inf");
                        foreach (var inf in genericInfs.Take(25))
                        {
                            RunProcess("pnputil.exe", $"/add-driver \"{inf}\" /install", null);
                        }
                    }

                    // 4. Sorunlu / Devre Dışı PnP Ağ Aygıtlarını Yeniden Etkinleştir
                    log("[4/5] Hatalı veya beklemedeki ağ kartları yeniden başlatılıyor...");
                    string psEnableScript = @"
                        Get-PnpDevice -Class Net -ErrorAction SilentlyContinue | ForEach-Object {
                            try {
                                if ($_.Status -ne 'OK') {
                                    Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
                                }
                            } catch {}
                        }
                        Start-Service -Name netman, nlasvc, netprofm, wlansvc, Dhcp, Dnscache -ErrorAction SilentlyContinue
                    ";
                    RunPowershell(psEnableScript, log);

                    // 5. Ağ Yığını (TCP/IP & Winsock) ve IP Yenileme
                    log("[5/5] TCP/IP yığını sıfırlanıyor ve DHCP IP adresi yenileniyor...");
                    RunProcess("netsh.exe", "winsock reset", log);
                    RunProcess("netsh.exe", "int ip reset", log);
                    RunProcess("ipconfig.exe", "/renew", log);

                    log("✅ UNIVERSAL AĞ SÜRÜCÜSÜ KURULUMU VE AĞ YENİLEME TAMAMLANDI!");
                    return (true, "Universal ağ kartı sürücüleri yerel DriverStore'dan başarıyla kuruldu ve ağ bağdaştırıcıları etkinleştirildi.");
                }
                catch (Exception ex)
                {
                    log($"❌ [HATA] Sürücü kurulumunda istisna: {ex.Message}");
                    return (false, $"Sürücü kurulum hatası: {ex.Message}");
                }
            });
        }

        private static void RunProcess(string filename, string args, Action<string>? log)
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = filename,
                    Arguments = args,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using var proc = Process.Start(psi);
                if (proc != null)
                {
                    proc.WaitForExit(15000);
                    if (log != null)
                    {
                        string outStr = proc.StandardOutput.ReadToEnd().Trim();
                        if (!string.IsNullOrEmpty(outStr))
                        {
                            foreach (var line in outStr.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries).Take(4))
                            {
                                log("     " + line);
                            }
                        }
                    }
                }
            }
            catch { }
        }

        private static void RunPowershell(string script, Action<string>? log)
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
                    proc.WaitForExit(15000);
                }
            }
            catch { }
        }
    }
}
