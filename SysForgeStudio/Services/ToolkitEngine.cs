using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Security.Principal;
using System.ServiceProcess;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Microsoft.Win32;
using SysForgeStudio.Models;

namespace SysForgeStudio.Services
{
    public class ToolkitEngine
    {
        public static ToolkitEngine Instance { get; } = new ToolkitEngine();

        public event Action<LogEntry>? LogReceived;
        public event Action<bool>? BusyChanged;
        public event Action<int, int>? ScanProgressChanged;

        private bool _isBusy;
        public bool IsBusy
        {
            get => _isBusy;
            set
            {
                _isBusy = value;
                BusyChanged?.Invoke(_isBusy);
            }
        }

        public string BackupDirectory { get; }
        public string LogsDirectory { get; }
        public string AppDataDirectory { get; }
        public string RdpConnectionsFile { get; }
        public string LegacyToolkitRoot { get; }

        public ToolkitEngine()
        {
            string appData = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "SysForgeStudio");
            AppDataDirectory = appData;
            BackupDirectory = Path.Combine(appData, "Backups");
            LogsDirectory = Path.Combine(appData, "Logs");
            RdpConnectionsFile = Path.Combine(appData, "rdp_connections.json");

            // Detect legacy toolkit root relative to this exe
            string exeDir = AppDomain.CurrentDomain.BaseDirectory;
            string possibleLegacy = Path.Combine(exeDir, "..", "SysForgeStudio", "Modules");
            if (Directory.Exists(possibleLegacy))
                LegacyToolkitRoot = Path.GetFullPath(possibleLegacy);
            else
            {
                possibleLegacy = Path.Combine(exeDir, "Modules");
                if (Directory.Exists(possibleLegacy))
                    LegacyToolkitRoot = Path.GetFullPath(possibleLegacy);
                else
                    LegacyToolkitRoot = exeDir;
            }

            try
            {
                Directory.CreateDirectory(BackupDirectory);
                Directory.CreateDirectory(LogsDirectory);
            }
            catch { }
        }

        #region Logging

        public void Log(string message, LogLevel level = LogLevel.Info)
        {
            var entry = new LogEntry
            {
                Message = message,
                Level = level,
                Timestamp = DateTime.Now
            };

            LogReceived?.Invoke(entry);

            try
            {
                string logFile = Path.Combine(LogsDirectory, $"UPT_Session_{DateTime.Now:yyyyMMdd}.log");
                string prefix = level switch
                {
                    LogLevel.Success => "[ OK ]",
                    LogLevel.Warning => "[WARN]",
                    LogLevel.Error => "[ERR ]",
                    _ => "[INFO]"
                };
                File.AppendAllText(logFile, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} {prefix} {message}{Environment.NewLine}");

                if (level == LogLevel.Error)
                {
                    App.LogRawError(message);
                }
            }
            catch { }
        }

        #endregion

        #region System & Role

        public bool IsAdministrator()
        {
            try
            {
                using var id = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(id);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }

        public string GetSpoolerStatus()
        {
            try
            {
                using var sc = new ServiceController("Spooler");
                return sc.Status.ToString();
            }
            catch
            {
                return "Bilinmiyor";
            }
        }

        public async Task<string> DetectRoleAsync()
        {
            return await Task.Run(() =>
            {
                try
                {
                    using var searcher = new ManagementObjectSearcher("SELECT Shared FROM Win32_Printer WHERE Shared = True");
                    using var results = searcher.Get();
                    if (results.Count > 0)
                        return "Sunucu (Host) - Paylaşılan Yazıcı Var";
                    return "İstemci (Client)";
                }
                catch
                {
                    return "İstemci (Standart)";
                }
            });
        }

        #endregion

        #region PowerShell & Process Execution

        public async Task<string> RunCommandAsync(string command, bool asPowerShell = true)
        {
            return await Task.Run(() =>
            {
                try
                {
                    var psi = new ProcessStartInfo
                    {
                        FileName = asPowerShell ? "powershell.exe" : "cmd.exe",
                        Arguments = asPowerShell
                            ? $"-NoProfile -ExecutionPolicy Bypass -Command \"{command}\""
                            : $"/c {command}",
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true,
                        StandardOutputEncoding = Encoding.UTF8,
                        StandardErrorEncoding = Encoding.UTF8
                    };

                    using var proc = Process.Start(psi);
                    if (proc == null) return string.Empty;

                    string stdout = proc.StandardOutput.ReadToEnd();
                    string stderr = proc.StandardError.ReadToEnd();
                    proc.WaitForExit();

                    if (!string.IsNullOrWhiteSpace(stderr))
                    {
                        Log($"Komut uyarısı: {stderr.Trim()}", LogLevel.Warning);
                    }

                    return stdout.Trim();
                }
                catch (Exception ex)
                {
                    Log($"Komut çalıştırma hatası: {ex.Message}", LogLevel.Error);
                    return string.Empty;
                }
            });
        }

        public void LaunchProcess(string fileName, string arguments = "", bool asAdmin = false)
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = fileName,
                    Arguments = arguments,
                    UseShellExecute = true
                };
                if (asAdmin) psi.Verb = "runas";
                Process.Start(psi);
            }
            catch (Exception ex)
            {
                Log($"İşlem başlatılamadı: {ex.Message}", LogLevel.Error);
            }
        }

        #endregion

        #region Printer Discovery & Actions

        public async Task<List<PrinterItem>> GetPrintersAsync()
        {
            return await Task.Run(() =>
            {
                var list = new List<PrinterItem>();
                try
                {
                    using var searcher = new ManagementObjectSearcher("SELECT Name, ShareName, DriverName, PortName, Default, Network, Shared, Location FROM Win32_Printer");
                    foreach (ManagementObject mo in searcher.Get())
                    {
                        list.Add(new PrinterItem
                        {
                            Name = mo["Name"]?.ToString() ?? "Bilinmiyor",
                            ShareName = mo["ShareName"]?.ToString() ?? "-",
                            DriverName = mo["DriverName"]?.ToString() ?? "-",
                            PortName = mo["PortName"]?.ToString() ?? "-",
                            IsDefault = Convert.ToBoolean(mo["Default"] ?? false),
                            IsNetwork = Convert.ToBoolean(mo["Network"] ?? false),
                            IsShared = Convert.ToBoolean(mo["Shared"] ?? false),
                            Location = mo["Location"]?.ToString() ?? "-",
                            Status = "Hazır"
                        });
                    }
                }
                catch (Exception ex)
                {
                    Log($"Yazıcılar listelenirken hata: {ex.Message}", LogLevel.Error);
                }
                return list;
            });
        }

        public async Task<bool> TestPreConnectAsync(string target)
        {
            return await Task.Run(() =>
            {
                Log($"Ön bağlantı testi başlatılıyor: {target}...", LogLevel.Info);
                string host = target.Replace(@"\\", "").Split(new[] { '\\', '/' }, StringSplitOptions.RemoveEmptyEntries)[0];

                bool port445 = TestTcpPort(host, 445);
                bool port139 = TestTcpPort(host, 139);

                if (port445 || port139)
                {
                    Log($"Hedef makineye ({host}) SMB/RPC bağlantısı başarılı! (Port 445: {port445}, Port 139: {port139})", LogLevel.Success);
                    return true;
                }

                Log($"Hedef makineye ({host}) 445 ve 139 portlarından ulaşılamadı. Güvenlik duvarı veya IP kontrol edilmeli.", LogLevel.Warning);
                return false;
            });
        }

        private bool TestTcpPort(string host, int port, int timeoutMs = 2500)
        {
            Socket? socket = null;
            try
            {
                socket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp)
                {
                    Blocking = false
                };
                var result = socket.BeginConnect(host, port, null, null);
                bool success = result.AsyncWaitHandle.WaitOne(timeoutMs, false);
                if (success && socket.Connected)
                {
                    try { socket.EndConnect(result); } catch { }
                    return socket.Connected;
                }
                return false;
            }
            catch
            {
                return false;
            }
            finally
            {
                try { socket?.Close(); } catch { }
            }
        }

        public async Task<bool> ConnectPrinterAsync(string uncPath)
        {
            IsBusy = true;
            try
            {
                uncPath = uncPath.Trim();
                if (!uncPath.StartsWith(@"\\"))
                {
                    uncPath = @"\\" + uncPath;
                }

                Log($"Yazıcı bağlanıyor: {uncPath}...", LogLevel.Info);

                // Yöntem 1: WScript.Network AddWindowsPrinterConnection
                string scriptWScript = $"$net = New-Object -ComObject WScript.Network; $net.AddWindowsPrinterConnection('{uncPath}')";
                string res1 = await RunCommandAsync(scriptWScript);

                // Kontrol
                var check = await RunCommandAsync($"Get-Printer -Name '{uncPath}' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name");
                if (!string.IsNullOrWhiteSpace(check))
                {
                    Log($"Yazıcı başarıyla bağlandı (WScript): {uncPath}", LogLevel.Success);
                    return true;
                }

                // Yöntem 2: PrintUI /in
                Log("Alternatif yöntem 2 deneniyor (PrintUI /in)...", LogLevel.Info);
                await RunCommandAsync($"rundll32 printui.dll,PrintUIEntry /in /n \"{uncPath}\"", asPowerShell: false);
                await Task.Delay(2000);

                check = await RunCommandAsync($"Get-Printer -Name '{uncPath}' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name");
                if (!string.IsNullOrWhiteSpace(check))
                {
                    Log($"Yazıcı başarıyla bağlandı (PrintUI): {uncPath}", LogLevel.Success);
                    return true;
                }

                // Yöntem 3: Add-Printer
                Log("Alternatif yöntem 3 deneniyor (Add-Printer)...", LogLevel.Info);
                await RunCommandAsync($"Add-Printer -ConnectionName '{uncPath}' -ErrorAction SilentlyContinue");

                check = await RunCommandAsync($"Get-Printer -Name '{uncPath}' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name");
                if (!string.IsNullOrWhiteSpace(check))
                {
                    Log($"Yazıcı başarıyla bağlandı (Add-Printer): {uncPath}", LogLevel.Success);
                    return true;
                }

                Log($"Yazıcı doğrudan bağlanamadı: {uncPath}. Onarım Merkezi sekmesinden RPC/Point&Print düzeltmelerini uygulayınız.", LogLevel.Error);
                return false;
            }
            finally
            {
                IsBusy = false;
            }
        }

        public async Task SetDefaultPrinterAsync(string name)
        {
            Log($"Varsayılan yazıcı yapılıyor: {name}...", LogLevel.Info);
            await RunCommandAsync($"$net = New-Object -ComObject WScript.Network; $net.SetDefaultPrinter('{name}')");
            Log($"'{name}' varsayılan yazıcı olarak ayarlandı.", LogLevel.Success);
        }

        public async Task PrintTestPageAsync(string name)
        {
            Log($"'{name}' için sınama sayfası gönderiliyor...", LogLevel.Info);
            await RunCommandAsync($"rundll32 printui.dll,PrintUIEntry /k /n \"{name}\"", asPowerShell: false);
            Log("Sınama sayfası komutu gönderildi.", LogLevel.Success);
        }

        public void OpenQueue(string name)
        {
            try
            {
                Process.Start("rundll32.exe", $"printui.dll,PrintUIEntry /o /n \"{name}\"");
            }
            catch (Exception ex)
            {
                Log($"Kuyruk açılamadı: {ex.Message}", LogLevel.Error);
            }
        }

        public void OpenPrinterProperties(string name)
        {
            try
            {
                Process.Start("rundll32.exe", $"printui.dll,PrintUIEntry /p /n \"{name}\"");
            }
            catch (Exception ex)
            {
                Log($"Özellikler açılamadı: {ex.Message}", LogLevel.Error);
            }
        }

        public async Task RemovePrinterAsync(string name)
        {
            Log($"Yazıcı kaldırılıyor: {name}...", LogLevel.Info);
            await RunCommandAsync($"Remove-Printer -Name '{name}' -ErrorAction SilentlyContinue");
            Log($"'{name}' yazıcısı kaldırıldı.", LogLevel.Success);
        }

        #endregion

        #region Repairs & Fixes

        public async Task FixRpc11bAnd709Async()
        {
            IsBusy = true;
            try
            {
                Log("RPC 0x0000011b ve 0x00000709 kayıt defteri onarımı uygulanıyor...", LogLevel.Info);

                await Task.Run(() =>
                {
                    // RpcAuthnLevelPrivacyEnabled = 0
                    using (var key = Registry.LocalMachine.CreateSubKey(@"System\CurrentControlSet\Control\Print"))
                    {
                        key.SetValue("RpcAuthnLevelPrivacyEnabled", 0, RegistryValueKind.DWord);
                    }

                    // RestrictDriverInstallationToAdministrators = 0
                    using (var key = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint"))
                    {
                        key.SetValue("RestrictDriverInstallationToAdministrators", 0, RegistryValueKind.DWord);
                    }

                    // RPC Over Named Pipes
                    using (var key = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Policies\Microsoft\Windows NT\Printers"))
                    {
                        key.SetValue("RpcUseNamedPipeProtocol", 1, RegistryValueKind.DWord);
                        key.SetValue("RpcProtocols", 7, RegistryValueKind.DWord);
                    }
                });

                Log("0x0000011b / 709 RPC güvenlik kısıtlamaları ve Named Pipes başarıyla yapılandırıldı.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"RPC onarımı hatası: {ex.Message}", LogLevel.Error);
            }
            finally
            {
                IsBusy = false;
            }
        }

        public async Task FixPointAndPrintAsync()
        {
            IsBusy = true;
            try
            {
                Log("Point and Print kısıtlamaları kaldırılıyor...", LogLevel.Info);
                await Task.Run(() =>
                {
                    using var key = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint");
                    key.SetValue("NoWarningNoElevationOnInstall", 1, RegistryValueKind.DWord);
                    key.SetValue("UpdatePromptSettings", 2, RegistryValueKind.DWord);
                    key.SetValue("PackagePointAndPrintServerList", 0, RegistryValueKind.DWord);
                });
                Log("Point and Print sürücü yükleme izinleri başarıyla açıldı.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"Point & Print onarımı hatası: {ex.Message}", LogLevel.Error);
            }
            finally
            {
                IsBusy = false;
            }
        }

        public async Task ResetSpoolerAsync()
        {
            IsBusy = true;
            try
            {
                Log("Yazdırma Biriktiricisi (Spooler) durduruluyor...", LogLevel.Info);
                await RunCommandAsync("net stop spooler /y", asPowerShell: false);

                string spoolDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "spool", "PRINTERS");
                if (Directory.Exists(spoolDir))
                {
                    var files = Directory.GetFiles(spoolDir);
                    foreach (var f in files)
                    {
                        try { File.Delete(f); } catch { }
                    }
                    Log($"Spooler kuyruğu temizlendi ({files.Length} takılı dosya silindi).", LogLevel.Info);
                }

                await RunCommandAsync("net start spooler", asPowerShell: false);
                Log("Yazdırma Biriktiricisi başarıyla sıfırlandı ve yeniden başlatıldı.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"Spooler sıfırlama hatası: {ex.Message}", LogLevel.Error);
            }
            finally
            {
                IsBusy = false;
            }
        }

        public async Task FixFirewallAsync()
        {
            IsBusy = true;
            try
            {
                Log("Windows Güvenlik Duvarı Yazıcı ve Dosya Paylaşım kuralları etkinleştiriliyor...", LogLevel.Info);
                await RunCommandAsync("netsh advfirewall firewall set rule group=\"File and Printer Sharing\" new enable=Yes", asPowerShell: false);
                await RunCommandAsync("netsh advfirewall firewall set rule group=\"Dosya ve Yazıcı Paylaşımı\" new enable=Yes", asPowerShell: false);
                await RunCommandAsync("Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue");
                Log("Güvenlik Duvarı izinleri açıldı ve ağ profili 'Özel' (Private) yapıldı.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"Güvenlik duvarı hatası: {ex.Message}", LogLevel.Error);
            }
            finally
            {
                IsBusy = false;
            }
        }

        public async Task FixSmbCompatibilityAsync()
        {
            IsBusy = true;
            try
            {
                Log("SMB Konuk (Guest Auth) ve uyumluluk politikaları yapılandırılıyor...", LogLevel.Info);
                await Task.Run(() =>
                {
                    using (var key = Registry.LocalMachine.CreateSubKey(@"SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"))
                    {
                        key.SetValue("AllowInsecureGuestAuth", 1, RegistryValueKind.DWord);
                        key.SetValue("EnableSecuritySignature", 0, RegistryValueKind.DWord);
                        key.SetValue("RequireSecuritySignature", 0, RegistryValueKind.DWord);
                    }
                });
                Log("SMB güvenli olmayan konuk oturumu (Guest Login) ve imzalama ayarları etkinleştirildi.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"SMB onarımı hatası: {ex.Message}", LogLevel.Error);
            }
            finally
            {
                IsBusy = false;
            }
        }

        public async Task FixServicesAsync()
        {
            IsBusy = true;
            try
            {
                Log("Gerekli Windows ağ ve yazdırma servisleri başlatılıyor...", LogLevel.Info);
                // RpcSs / RpcEptMapper: Vanguard it_tech_service fix_services listesinden
                string ps = @"
                    $services = @('Spooler','LanmanServer','LanmanWorkstation','FDResPub','fdPHost','RpcSs','RpcEptMapper')
                    foreach ($s in $services) {
                        Set-Service -Name $s -StartupType Automatic -ErrorAction SilentlyContinue
                        Start-Service -Name $s -ErrorAction SilentlyContinue
                    }
                ";
                await RunCommandAsync(ps);
                Log("Spooler, RPC, LanmanServer/Workstation ve FDResPub servisleri otomatik başlatıldı.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"Servisler başlatılırken hata: {ex.Message}", LogLevel.Error);
            }
            finally
            {
                IsBusy = false;
            }
        }

        public async Task FixNtlmNetBiosAsync()
        {
            IsBusy = true;
            try
            {
                Log("NTLM ve NetBIOS uyumluluk modu ayarlanıyor...", LogLevel.Info);
                await Task.Run(() =>
                {
                    using var key = Registry.LocalMachine.CreateSubKey(@"SYSTEM\CurrentControlSet\Control\Lsa");
                    key.SetValue("LmCompatibilityLevel", 1, RegistryValueKind.DWord);
                });
                Log("NTLM seviyesi 1 (Geniş uyumluluk) olarak ayarlandı.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"NTLM hatası: {ex.Message}", LogLevel.Error);
            }
            finally
            {
                IsBusy = false;
            }
        }

        /// <summary>
        /// Vanguard it_tech_service fix_709: LSA anonymous kısıtlarını gevşeterek 0x00000709 ağ yazıcı hatasını giderir.
        /// </summary>
        public async Task Fix709LsaAsync()
        {
            IsBusy = true;
            try
            {
                Log("0x00000709 LSA ağ izinleri (restrictanonymous) düzenleniyor...", LogLevel.Info);
                await Task.Run(() =>
                {
                    using var key = Registry.LocalMachine.CreateSubKey(@"SYSTEM\CurrentControlSet\Control\Lsa");
                    key.SetValue("restrictanonymous", 0, RegistryValueKind.DWord);
                    key.SetValue("restrictanonymoussam", 0, RegistryValueKind.DWord);
                    // Mevcut NTLM politikasını bozmadan güvenli orta seviye bırak
                    if (key.GetValue("LmCompatibilityLevel") == null)
                        key.SetValue("LmCompatibilityLevel", 3, RegistryValueKind.DWord);
                    key.SetValue("NoLMHash", 1, RegistryValueKind.DWord);
                });
                Log("0x00000709 LSA ağ izinleri başarıyla uygulandı.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"0x00000709 LSA onarımı hatası: {ex.Message}", LogLevel.Error);
            }
            finally
            {
                IsBusy = false;
            }
        }

        public async Task RestoreSecureDefaultsAsync()
        {
            IsBusy = true;
            try
            {
                Log("Sistem varsayılan güvenli ayarlara sıfırlanıyor...", LogLevel.Info);
                await Task.Run(() =>
                {
                    using (var key = Registry.LocalMachine.OpenSubKey(@"System\CurrentControlSet\Control\Print", true))
                    {
                        key?.DeleteValue("RpcAuthnLevelPrivacyEnabled", false);
                    }
                    using (var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint", true))
                    {
                        key?.DeleteValue("RestrictDriverInstallationToAdministrators", false);
                        key?.DeleteValue("NoWarningNoElevationOnInstall", false);
                    }
                });
                Log("Varsayılan Windows güvenlik ilkeleri başarıyla geri yüklendi.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"Varsayılanlara dönülürken hata: {ex.Message}", LogLevel.Error);
            }
            finally
            {
                IsBusy = false;
            }
        }

        public async Task RunSmartAutoWorkflowAsync()
        {
            IsBusy = true;
            try
            {
                Log("==================================================", LogLevel.Info);
                Log("🚀 AKILLI OTOMATİK ONARIM AKIŞI BAŞLATILIYOR...", LogLevel.Info);
                Log("==================================================", LogLevel.Info);

                await CreateBackupAsync();
                await FixServicesAsync();
                await ResetSpoolerAsync();
                await FixRpc11bAnd709Async();
                await Fix709LsaAsync();
                await FixPointAndPrintAsync();
                await FixFirewallAsync();
                await FixSmbCompatibilityAsync();

                Log("==================================================", LogLevel.Success);
                Log("✅ TÜM AKILLI ONARIM ADIMLARI BAŞARIYLA TAMAMLANDI!", LogLevel.Success);
                Log("==================================================", LogLevel.Success);
            }
            finally
            {
                IsBusy = false;
            }
        }

        #endregion

        #region Drivers

        public async Task<List<DriverItem>> GetDriversAsync()
        {
            return await Task.Run(() =>
            {
                var list = new List<DriverItem>();
                try
                {
                    using var searcher = new ManagementObjectSearcher("SELECT Name, DriverPath FROM Win32_PrinterDriver");
                    foreach (ManagementObject mo in searcher.Get())
                    {
                        string name = mo["Name"]?.ToString() ?? "Bilinmiyor";
                        string path = mo["DriverPath"]?.ToString() ?? string.Empty;
                        string cleanName = name.Split(',')[0];

                        list.Add(new DriverItem
                        {
                            Name = cleanName,
                            DriverPath = path,
                            Architecture = name.Contains("x64") || name.Contains("Windows x64") ? "x64" : "x86",
                            Manufacturer = DetectManufacturer(cleanName),
                            Version = "Sistem"
                        });
                    }
                }
                catch (Exception ex)
                {
                    Log($"Sürücüler taranırken hata: {ex.Message}", LogLevel.Error);
                }
                return list;
            });
        }

        private string DetectManufacturer(string name)
        {
            string lower = name.ToLowerInvariant();
            if (lower.Contains("hp") || lower.Contains("hewlett")) return "HP";
            if (lower.Contains("canon")) return "Canon";
            if (lower.Contains("epson")) return "Epson";
            if (lower.Contains("brother")) return "Brother";
            if (lower.Contains("ricoh")) return "Ricoh";
            if (lower.Contains("konica") || lower.Contains("minolta")) return "Konica Minolta";
            if (lower.Contains("xerox")) return "Xerox";
            if (lower.Contains("kyocera")) return "Kyocera";
            if (lower.Contains("samsung")) return "Samsung";
            if (lower.Contains("lexmark")) return "Lexmark";
            if (lower.Contains("microsoft")) return "Microsoft";
            return "Diğer";
        }

        public async Task RemoveDriverAsync(string driverName)
        {
            IsBusy = true;
            try
            {
                Log($"Sürücü siliniyor: {driverName}...", LogLevel.Info);
                await RunCommandAsync($"Remove-PrinterDriver -Name '{driverName}' -RemoveDataFiles -ErrorAction SilentlyContinue");
                Log($"'{driverName}' başarıyla kaldırıldı.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"Sürücü silinemedi: {ex.Message}", LogLevel.Error);
            }
            finally
            {
                IsBusy = false;
            }
        }

        public async Task CleanDriverStoreAsync()
        {
            IsBusy = true;
            try
            {
                Log("Kullanılmayan yazıcı sürücü paketleri taranıyor ve temizleniyor...", LogLevel.Info);
                await RunCommandAsync("pnputil /delete-driver oem*.inf /uninstall", asPowerShell: false);
                Log("Sürücü önbelleği temizliği tamamlandı.", LogLevel.Success);
            }
            finally
            {
                IsBusy = false;
            }
        }

        #endregion

        #region Diagnostics

        public async Task<List<DiagItem>> RunFullDiagnosisAsync()
        {
            IsBusy = true;
            var list = new List<DiagItem>();
            try
            {
                Log("Sistem teşhis taraması başlatılıyor...", LogLevel.Info);

                await Task.Run(() =>
                {
                    // 1. Spooler
                    string spoolStatus = GetSpoolerStatus();
                    list.Add(new DiagItem
                    {
                        Category = "Servisler",
                        Name = "Yazdırma Biriktiricisi (Spooler)",
                        Status = spoolStatus.Equals("Running", StringComparison.OrdinalIgnoreCase) ? "OK" : "ERR",
                        Details = $"Mevcut Durum: {spoolStatus}",
                        Recommendation = spoolStatus.Equals("Running", StringComparison.OrdinalIgnoreCase) ? "Normal" : "Spooler servisini başlatın."
                    });

                    // 2. RPC 0x0000011b
                    int rpcAuth = -1;
                    try
                    {
                        using var key = Registry.LocalMachine.OpenSubKey(@"System\CurrentControlSet\Control\Print");
                        rpcAuth = (int)(key?.GetValue("RpcAuthnLevelPrivacyEnabled", -1) ?? -1);
                    }
                    catch { }

                    list.Add(new DiagItem
                    {
                        Category = "Kayıt Defteri",
                        Name = "0x0000011b RPC Gizlilik Koruması",
                        Status = rpcAuth == 0 ? "OK" : "WARN",
                        Details = rpcAuth == 0 ? "0 (Güvenli - Paylaşıma İzin Verildi)" : (rpcAuth == 1 ? "1 (Aktif - 11b hatası verebilir)" : "Varsayılan (Tanımsız)"),
                        Recommendation = rpcAuth == 0 ? "Normal" : "0x0000011b onarımını uygulayın."
                    });

                    // 3. Point and Print
                    int restrictAdmin = -1;
                    try
                    {
                        using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint");
                        restrictAdmin = (int)(key?.GetValue("RestrictDriverInstallationToAdministrators", -1) ?? -1);
                    }
                    catch { }

                    list.Add(new DiagItem
                    {
                        Category = "Grup İlkesi",
                        Name = "Point & Print Yönetici Kısıtlaması",
                        Status = restrictAdmin == 0 ? "OK" : "WARN",
                        Details = restrictAdmin == 0 ? "0 (Kullanıcılar sürücü indirebilir)" : "Aktif veya Tanımsız",
                        Recommendation = restrictAdmin == 0 ? "Normal" : "Point & Print kısıtlamasını kaldırın."
                    });

                    // 4. SMB Guest Auth
                    int guestAuth = -1;
                    try
                    {
                        using var key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters");
                        guestAuth = (int)(key?.GetValue("AllowInsecureGuestAuth", -1) ?? -1);
                    }
                    catch { }

                    list.Add(new DiagItem
                    {
                        Category = "Ağ / SMB",
                        Name = "SMB Konuk (Guest) Oturumu",
                        Status = guestAuth == 1 ? "OK" : "WARN",
                        Details = guestAuth == 1 ? "1 (Etkin - Şifresiz paylaşımlara açık)" : "Devre Dışı",
                        Recommendation = guestAuth == 1 ? "Normal" : "SMB uyumluluk onarımını uygulayın."
                    });
                });

                Log($"Teşhis tamamlandı. Toplam {list.Count} kontrol noktası değerlendirildi.", LogLevel.Success);
            }
            finally
            {
                IsBusy = false;
            }
            return list;
        }

        #endregion

        #region Backup & Restore

        public async Task<string> CreateBackupAsync()
        {
            return await Task.Run(() =>
            {
                try
                {
                    string fileName = $"UPT_Backup_{DateTime.Now:yyyyMMdd_HHmmss}.reg";
                    string fullPath = Path.Combine(BackupDirectory, fileName);

                    Log($"Sistem ve yazıcı ayarları yedekleniyor: {fileName}...", LogLevel.Info);
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "reg.exe",
                        Arguments = $"export \"HKLM\\System\\CurrentControlSet\\Control\\Print\" \"{fullPath}\" /y",
                        UseShellExecute = false,
                        CreateNoWindow = true
                    })?.WaitForExit();

                    Log($"Yedekleme başarıyla oluşturuldu: {fullPath}", LogLevel.Success);
                    return fullPath;
                }
                catch (Exception ex)
                {
                    Log($"Yedekleme hatası: {ex.Message}", LogLevel.Error);
                    return string.Empty;
                }
            });
        }

        public List<BackupItem> GetBackups()
        {
            var list = new List<BackupItem>();
            try
            {
                if (Directory.Exists(BackupDirectory))
                {
                    var di = new DirectoryInfo(BackupDirectory);
                    foreach (var fi in di.GetFiles("*.reg"))
                    {
                        list.Add(new BackupItem
                        {
                            FileName = fi.Name,
                            FullPath = fi.FullName,
                            CreatedAt = fi.CreationTime,
                            SizeDisplay = $"{fi.Length / 1024.0:F1} KB"
                        });
                    }
                }
            }
            catch { }
            return list;
        }

        public async Task RestoreBackupAsync(string regPath)
        {
            IsBusy = true;
            try
            {
                Log($"Yedek geri yükleniyor: {Path.GetFileName(regPath)}...", LogLevel.Info);
                await Task.Run(() =>
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "reg.exe",
                        Arguments = $"import \"{regPath}\"",
                        UseShellExecute = false,
                        CreateNoWindow = true
                    })?.WaitForExit();
                });
                await ResetSpoolerAsync();
                Log("Yedek başarıyla geri yüklendi ve Spooler yeniden başlatıldı.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"Geri yükleme hatası: {ex.Message}", LogLevel.Error);
            }
            finally
            {
                IsBusy = false;
            }
        }

        #endregion

        #region Network Scanning & Discovery

        public List<NetworkAdapterInfo> GetNetworkAdapters()
        {
            var adapters = new List<NetworkAdapterInfo>();
            try
            {
                foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
                {
                    if (nic.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
                    if (nic.OperationalStatus != OperationalStatus.Up && nic.OperationalStatus != OperationalStatus.Down) continue;

                    var props = nic.GetIPProperties();
                    var ipv4 = props.UnicastAddresses
                        .FirstOrDefault(a => a.Address.AddressFamily == AddressFamily.InterNetwork);

                    string ip = ipv4?.Address.ToString() ?? "-";
                    string mask = ipv4?.IPv4Mask?.ToString() ?? "-";
                    string gateway = props.GatewayAddresses.FirstOrDefault()?.Address.ToString() ?? "-";
                    string dns = string.Join(", ", props.DnsAddresses.Where(d => d.AddressFamily == AddressFamily.InterNetwork).Select(d => d.ToString()));
                    string speed = nic.Speed > 0 ? $"{nic.Speed / 1_000_000} Mbps" : "-";

                    string networkPrefix = "";
                    if (ipv4 != null && ip != "-")
                    {
                        var ipBytes = ipv4.Address.GetAddressBytes();
                        var maskBytes = ipv4.IPv4Mask?.GetAddressBytes();
                        if (maskBytes != null)
                        {
                            var netBytes = new byte[4];
                            for (int i = 0; i < 4; i++) netBytes[i] = (byte)(ipBytes[i] & maskBytes[i]);
                            networkPrefix = $"{netBytes[0]}.{netBytes[1]}.{netBytes[2]}";
                        }
                    }

                    bool isDhcp = false;
                    try { isDhcp = props.GetIPv4Properties()?.IsDhcpEnabled ?? false; } catch { }

                    adapters.Add(new NetworkAdapterInfo
                    {
                        Name = nic.Name,
                        Description = nic.Description,
                        IPAddress = ip,
                        SubnetMask = mask,
                        Gateway = gateway,
                        DnsServers = dns,
                        MacAddress = nic.GetPhysicalAddress().ToString(),
                        Speed = speed,
                        Status = nic.OperationalStatus.ToString(),
                        NetworkPrefix = networkPrefix,
                        IsDhcp = isDhcp
                    });
                }
            }
            catch (Exception ex)
            {
                Log($"Ağ adaptörleri alınırken hata: {ex.Message}", LogLevel.Error);
            }
            return adapters;
        }

        public async Task<List<NetworkHostInfo>> ScanSubnetAsync(string networkPrefix, CancellationToken ct = default)
        {
            var hosts = new List<NetworkHostInfo>();
            Log($"Ağ taraması başlatılıyor: {networkPrefix}.0/24 (Vanguard profilleme)...", LogLevel.Info);

            // ARP tablosu taramadan önce ısıtılsın diye boş bırakılır; ping sonrası yenilenir
            int completed = 0;
            var tasks = new List<Task>();
            var lockObj = new object();

            for (int i = 1; i <= 254; i++)
            {
                if (ct.IsCancellationRequested) break;

                string ip = $"{networkPrefix}.{i}";
                tasks.Add(Task.Run(async () =>
                {
                    try
                    {
                        using var ping = new Ping();
                        var reply = await ping.SendPingAsync(ip, 800);
                        if (reply.Status == IPStatus.Success)
                        {
                            string hostname = "";
                            try
                            {
                                var host = await Dns.GetHostEntryAsync(ip);
                                hostname = host.HostName;
                            }
                            catch { hostname = "-"; }

                            int ttl = reply.Options?.Ttl ?? -1;
                            string osGuess = GuessOsFromTtl(ttl);

                            // Vanguard it_tech_service port seti
                            bool hasHttp80 = TestTcpPort(ip, 80, 200);
                            bool hasHttp443 = TestTcpPort(ip, 443, 200);
                            bool hasRpc135 = TestTcpPort(ip, 135, 200);
                            bool hasSmb = TestTcpPort(ip, 445, 200) || TestTcpPort(ip, 139, 200);
                            bool hasMacAfp = TestTcpPort(ip, 548, 200);
                            bool hasPrinter = TestTcpPort(ip, 9100, 200) || TestTcpPort(ip, 631, 200) || TestTcpPort(ip, 515, 200);
                            bool hasSip = TestTcpPort(ip, 5060, 200);
                            bool hasSsh = TestTcpPort(ip, 22, 200);
                            bool hasNas = TestTcpPort(ip, 5000, 200) || TestTcpPort(ip, 5001, 200);
                            bool hasRdp = TestTcpPort(ip, 3389, 200);
                            bool hasHttp = hasHttp80 || hasHttp443;

                            var openPorts = new List<string>();
                            if (hasRdp) openPorts.Add("3389(RDP)");
                            if (hasSmb) openPorts.Add("445(SMB)");
                            if (hasRpc135) openPorts.Add("135(RPC)");
                            if (hasHttp) openPorts.Add("80/443(HTTP)");
                            if (hasPrinter) openPorts.Add("9100/631(PRN)");
                            if (hasSip) openPorts.Add("5060(SIP)");
                            if (hasSsh) openPorts.Add("22(SSH)");
                            if (hasMacAfp) openPorts.Add("548(AFP)");
                            if (hasNas) openPorts.Add("5000(NAS)");

                            string deviceType = ClassifyNetworkDevice(
                                hostname, ttl, hasRdp, hasSmb, hasRpc135, hasHttp,
                                hasPrinter, hasSip, hasSsh, hasMacAfp, hasNas);

                            var hostInfo = new NetworkHostInfo
                            {
                                IPAddress = ip,
                                Hostname = string.IsNullOrWhiteSpace(hostname) ? "-" : hostname,
                                PingMs = (int)reply.RoundtripTime,
                                Status = "Çevrimiçi",
                                OpenPorts = openPorts.Count > 0 ? string.Join(", ", openPorts) : "-",
                                OsGuess = osGuess,
                                Ttl = ttl,
                                HasRDP = hasRdp,
                                HasSMB = hasSmb,
                                HasHTTP = hasHttp,
                                HasPrinter = hasPrinter,
                                HasSip = hasSip,
                                HasSsh = hasSsh,
                                HasMacAfp = hasMacAfp,
                                DeviceType = deviceType
                            };

                            lock (lockObj)
                            {
                                hosts.Add(hostInfo);
                            }
                        }
                    }
                    catch { }
                    finally
                    {
                        int c = Interlocked.Increment(ref completed);
                        ScanProgressChanged?.Invoke(c, 254);
                    }
                }, ct));
            }

            await Task.WhenAll(tasks);

            // ARP tablosundan MAC adreslerini eşle (Vanguard network modülü gibi)
            try
            {
                var arpMap = GetArpMacMap();
                foreach (var h in hosts)
                {
                    if (arpMap.TryGetValue(h.IPAddress, out string? mac) && !string.IsNullOrEmpty(mac))
                        h.MacAddress = mac;
                }
            }
            catch { }

            hosts.Sort((a, b) =>
            {
                var partsA = a.IPAddress.Split('.').Select(int.Parse).ToArray();
                var partsB = b.IPAddress.Split('.').Select(int.Parse).ToArray();
                for (int j = 0; j < 4; j++)
                {
                    if (partsA[j] != partsB[j]) return partsA[j].CompareTo(partsB[j]);
                }
                return 0;
            });

            Log($"Ağ taraması tamamlandı. {hosts.Count} aktif cihaz bulundu (profil + MAC).", LogLevel.Success);
            return hosts;
        }

        private static string GuessOsFromTtl(int ttl)
        {
            if (ttl <= 0) return "-";
            if (ttl <= 64) return "Linux / Router / Mobil";
            if (ttl <= 128) return "Windows";
            return "Ağ Cihazı / Unix";
        }

        /// <summary>
        /// Vanguard it_tech_service NetworkModule cihaz tipleme sezgisel kuralları.
        /// </summary>
        private static string ClassifyNetworkDevice(
            string hostname, int ttl,
            bool hasRdp, bool hasSmb, bool hasRpc135, bool hasHttp,
            bool hasPrinter, bool hasSip, bool hasSsh, bool hasMacAfp, bool hasNas)
        {
            string low = (hostname ?? "").ToLowerInvariant();

            if (hasMacAfp || low.Contains("mac") || low.Contains("apple") || low.Contains("imac") || low.Contains("macbook"))
                return "Apple Mac / MacBook";

            if (hasSip || low.Contains("voip") || low.Contains("yealink") || low.Contains("phone") || low.Contains("sip"))
                return low.Contains("yealink") ? "IP Telefon (Yealink)" : "IP Telefon / VoIP";

            if (hasPrinter || low.Contains("printer") || low.Contains("yazici") || low.Contains("print") || low.Contains("laserjet") || low.Contains("deskjet"))
                return "Ağ Yazıcısı";

            if (hasNas || low.Contains("nas") || low.Contains("synology") || low.Contains("qnap"))
                return "NAS Depolama";

            if (hasRpc135 || hasSmb || hasRdp)
            {
                if (low.Contains("w11") || low.Contains("win11")) return "Windows 11 PC";
                if (low.Contains("w10") || low.Contains("win10")) return "Windows 10 PC";
                if (low.Contains("srv") || low.Contains("server") || low.Contains("dc-"))
                    return "Sunucu (Server)";
                return "Windows PC";
            }

            if (hasSsh || hasHttp)
            {
                if ((ttl > 0 && ttl <= 64) || low.Contains("gateway") || low.Contains("router") || low.Contains("modem") || low.Contains("ap-"))
                    return "Modem / Router / Switch";
                return "Linux / Sunucu";
            }

            if (ttl > 0 && ttl <= 64)
                return "Akıllı Telefon / Mobil";

            return "Diğer Cihaz";
        }

        private static Dictionary<string, string> GetArpMacMap()
        {
            var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "arp",
                    Arguments = "-a",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true
                };
                using var proc = Process.Start(psi);
                if (proc == null) return map;
                string output = proc.StandardOutput.ReadToEnd();
                proc.WaitForExit(5000);

                foreach (var rawLine in output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries))
                {
                    string line = rawLine.Trim();
                    // Örnek: 192.168.1.1    00-11-22-33-44-55    dynamic
                    var parts = line.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length >= 2 && parts[0].Contains('.') && parts[1].Contains('-'))
                    {
                        string ip = parts[0];
                        string mac = parts[1].Replace('-', ':').ToUpperInvariant();
                        if (!mac.StartsWith("00:00:00") && mac != "FF:FF:FF:FF:FF:FF")
                            map[ip] = mac;
                    }
                }
            }
            catch { }
            return map;
        }

        public string ExportNetworkScanCsv(List<NetworkHostInfo> hosts)
        {
            string file = Path.Combine(LogsDirectory, $"NetworkScan_{DateTime.Now:yyyyMMdd_HHmmss}.csv");
            static string Esc(string? s) => "\"" + (s ?? "").Replace("\"", "\"\"") + "\"";
            var sb = new StringBuilder();
            sb.AppendLine("Tip,IP,Hostname,OS,PingMs,MAC,Portlar,Durum");
            foreach (var h in hosts)
            {
                sb.AppendLine(string.Join(",",
                    Esc(h.DeviceType), Esc(h.IPAddress), Esc(h.Hostname), Esc(h.OsGuess),
                    h.PingMs.ToString(), Esc(h.MacAddress), Esc(h.OpenPorts), Esc(h.Status)));
            }
            File.WriteAllText(file, sb.ToString(), Encoding.UTF8);
            Log($"Ağ tarama CSV dışa aktarıldı: {file}", LogLevel.Success);
            return file;
        }

        public string ExportNetworkScanHtml(List<NetworkHostInfo> hosts)
        {
            string file = Path.Combine(LogsDirectory, $"NetworkScan_{DateTime.Now:yyyyMMdd_HHmmss}.html");
            var sb = new StringBuilder();
            sb.AppendLine("<!DOCTYPE html><html lang='tr'><head><meta charset='utf-8'/>");
            sb.AppendLine("<title>Ağ Tarama Raporu</title>");
            sb.AppendLine("<style>body{font-family:Segoe UI,sans-serif;background:#0f172a;color:#f8fafc;padding:24px}");
            sb.AppendLine("table{width:100%;border-collapse:collapse}th,td{padding:10px;border-bottom:1px solid #334155;text-align:left}");
            sb.AppendLine("th{background:#1e293b;color:#94a3b8}h1{color:#38bdf8}</style></head><body>");
            sb.AppendLine($"<h1>📡 Ağ Tarama Raporu</h1><p>{DateTime.Now:dd.MM.yyyy HH:mm:ss} — {hosts.Count} cihaz</p>");
            sb.AppendLine("<table><tr><th>Tip</th><th>IP</th><th>Hostname</th><th>OS</th><th>Ping</th><th>MAC</th><th>Portlar</th></tr>");
            foreach (var h in hosts)
            {
                sb.AppendLine($"<tr><td>{h.DeviceIcon} {System.Net.WebUtility.HtmlEncode(h.DeviceType)}</td>" +
                              $"<td>{System.Net.WebUtility.HtmlEncode(h.IPAddress)}</td>" +
                              $"<td>{System.Net.WebUtility.HtmlEncode(h.Hostname)}</td>" +
                              $"<td>{System.Net.WebUtility.HtmlEncode(h.OsGuess)}</td>" +
                              $"<td>{h.PingMs} ms</td>" +
                              $"<td>{System.Net.WebUtility.HtmlEncode(h.MacAddress)}</td>" +
                              $"<td>{System.Net.WebUtility.HtmlEncode(h.OpenPorts)}</td></tr>");
            }
            sb.AppendLine("</table></body></html>");
            File.WriteAllText(file, sb.ToString(), Encoding.UTF8);
            Log($"Ağ tarama HTML raporu oluşturuldu: {file}", LogLevel.Success);
            return file;
        }

        #endregion

        #region Remote Desktop

        public void LaunchRdp(string hostname, string username = "", int port = 3389, bool fullScreen = true, string resolution = "")
        {
            try
            {
                var args = new StringBuilder();
                args.Append($"/v:{hostname}");
                if (port != 3389) args.Append($":{port}");
                if (fullScreen) args.Append(" /f");
                else if (!string.IsNullOrEmpty(resolution))
                {
                    var parts = resolution.Split('x');
                    if (parts.Length == 2)
                    {
                        args.Append($" /w:{parts[0]} /h:{parts[1]}");
                    }
                }
                if (!string.IsNullOrEmpty(username)) args.Append($" /admin");

                Log($"Uzak Masaüstü başlatılıyor: {hostname}:{port}...", LogLevel.Info);
                Process.Start("mstsc.exe", args.ToString());
                Log($"RDP oturumu başlatıldı: {hostname}", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"RDP başlatılamadı: {ex.Message}", LogLevel.Error);
            }
        }

        public List<RdpConnection> LoadRdpConnections()
        {
            try
            {
                if (File.Exists(RdpConnectionsFile))
                {
                    string json = File.ReadAllText(RdpConnectionsFile);
                    return JsonSerializer.Deserialize<List<RdpConnection>>(json) ?? new List<RdpConnection>();
                }
            }
            catch { }
            return new List<RdpConnection>();
        }

        public void SaveRdpConnections(List<RdpConnection> connections)
        {
            try
            {
                string json = JsonSerializer.Serialize(connections, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(RdpConnectionsFile, json);
            }
            catch (Exception ex)
            {
                Log($"RDP bağlantıları kaydedilemedi: {ex.Message}", LogLevel.Error);
            }
        }

        #endregion

        #region System Repair

        public async Task RunSfcScanAsync()
        {
            IsBusy = true;
            try
            {
                Log("SFC /scannow başlatılıyor (Sistem dosyası bütünlük denetimi)...", LogLevel.Info);
                string result = await RunCommandAsync("sfc /scannow", asPowerShell: false);
                Log($"SFC tamamlandı:\n{result}", LogLevel.Success);
            }
            finally { IsBusy = false; }
        }

        public async Task RunDismRepairAsync()
        {
            IsBusy = true;
            try
            {
                Log("DISM /Online /Cleanup-Image /RestoreHealth başlatılıyor...", LogLevel.Info);
                string result = await RunCommandAsync("DISM /Online /Cleanup-Image /RestoreHealth", asPowerShell: false);
                Log($"DISM onarımı tamamlandı:\n{result}", LogLevel.Success);
            }
            finally { IsBusy = false; }
        }

        public async Task ResetNetworkStackAsync()
        {
            IsBusy = true;
            try
            {
                Log("Ağ yığını sıfırlanıyor (Winsock + IP + DNS)...", LogLevel.Info);
                await RunCommandAsync("netsh winsock reset", asPowerShell: false);
                await RunCommandAsync("netsh int ip reset", asPowerShell: false);
                await RunCommandAsync("ipconfig /flushdns", asPowerShell: false);
                await RunCommandAsync("ipconfig /release", asPowerShell: false);
                await RunCommandAsync("ipconfig /renew", asPowerShell: false);
                Log("Ağ yığını başarıyla sıfırlandı. Yeniden başlatma gerekebilir.", LogLevel.Success);
            }
            finally { IsBusy = false; }
        }

        public async Task ResetWindowsUpdateAsync()
        {
            IsBusy = true;
            try
            {
                Log("Windows Update bileşenleri sıfırlanıyor...", LogLevel.Info);
                await RunCommandAsync("net stop wuauserv /y", asPowerShell: false);
                await RunCommandAsync("net stop cryptSvc /y", asPowerShell: false);
                await RunCommandAsync("net stop bits /y", asPowerShell: false);
                await RunCommandAsync("net stop msiserver /y", asPowerShell: false);

                string winDir = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
                await RunCommandAsync($"ren \"{Path.Combine(winDir, "SoftwareDistribution")}\" SoftwareDistribution.old", asPowerShell: false);
                await RunCommandAsync($"ren \"{Path.Combine(winDir, "System32", "catroot2")}\" catroot2.old", asPowerShell: false);

                await RunCommandAsync("net start wuauserv", asPowerShell: false);
                await RunCommandAsync("net start cryptSvc", asPowerShell: false);
                await RunCommandAsync("net start bits", asPowerShell: false);
                await RunCommandAsync("net start msiserver", asPowerShell: false);

                Log("Windows Update bileşenleri başarıyla sıfırlandı.", LogLevel.Success);
            }
            finally { IsBusy = false; }
        }

        public async Task CleanTempFilesAsync()
        {
            IsBusy = true;
            try
            {
                Log("Geçici dosyalar temizleniyor...", LogLevel.Info);
                int count = 0;

                string[] tempDirs = {
                    Path.GetTempPath(),
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "Temp"),
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "Prefetch")
                };

                await Task.Run(() =>
                {
                    foreach (string dir in tempDirs)
                    {
                        if (!Directory.Exists(dir)) continue;
                        try
                        {
                            foreach (var f in Directory.GetFiles(dir, "*", SearchOption.AllDirectories))
                            {
                                try { File.Delete(f); count++; } catch { }
                            }
                        }
                        catch { }
                    }
                });

                Log($"Geçici dosya temizliği tamamlandı. {count} dosya silindi.", LogLevel.Success);
            }
            finally { IsBusy = false; }
        }

        #endregion

        #region Windows Services Management

        public async Task<List<ServiceItem>> GetServicesAsync(string filter = "")
        {
            return await Task.Run(() =>
            {
                var list = new List<ServiceItem>();
                try
                {
                    foreach (var sc in ServiceController.GetServices())
                    {
                        string displayName = sc.DisplayName;
                        string serviceName = sc.ServiceName;

                        if (!string.IsNullOrEmpty(filter))
                        {
                            if (!displayName.Contains(filter, StringComparison.OrdinalIgnoreCase) &&
                                !serviceName.Contains(filter, StringComparison.OrdinalIgnoreCase))
                                continue;
                        }

                        string startType = "Bilinmiyor";
                        try { startType = sc.StartType.ToString(); } catch { }

                        list.Add(new ServiceItem
                        {
                            ServiceName = serviceName,
                            DisplayName = displayName,
                            Status = sc.Status.ToString(),
                            StartType = startType
                        });

                        sc.Dispose();
                    }
                }
                catch (Exception ex)
                {
                    Log($"Servisler listelenirken hata: {ex.Message}", LogLevel.Error);
                }
                return list.OrderBy(s => s.DisplayName).ToList();
            });
        }

        public async Task ControlServiceAsync(string serviceName, string action)
        {
            IsBusy = true;
            try
            {
                string cmd = action.ToLower() switch
                {
                    "start" => $"Start-Service -Name '{serviceName}' -ErrorAction Stop",
                    "stop" => $"Stop-Service -Name '{serviceName}' -Force -ErrorAction Stop",
                    "restart" => $"Restart-Service -Name '{serviceName}' -Force -ErrorAction Stop",
                    _ => ""
                };

                if (!string.IsNullOrEmpty(cmd))
                {
                    Log($"Servis {action}: {serviceName}...", LogLevel.Info);
                    await RunCommandAsync(cmd);
                    Log($"Servis '{serviceName}' {action} işlemi tamamlandı.", LogLevel.Success);
                }
            }
            catch (Exception ex)
            {
                Log($"Servis kontrolü hatası: {ex.Message}", LogLevel.Error);
            }
            finally { IsBusy = false; }
        }

        #endregion

        #region Performance Info

        public async Task<List<PerformanceMetric>> GetPerformanceMetricsAsync()
        {
            return await Task.Run(() =>
            {
                var metrics = new List<PerformanceMetric>();

                // CPU
                try
                {
                    using var cpuCounter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
                    cpuCounter.NextValue();
                    Thread.Sleep(500);
                    float cpuUsage = cpuCounter.NextValue();
                    metrics.Add(new PerformanceMetric { Name = "CPU Kullanımı", Value = $"{cpuUsage:F1}", Unit = "%", Percentage = cpuUsage, Status = cpuUsage > 90 ? "Kritik" : cpuUsage > 70 ? "Yüksek" : "Normal" });
                }
                catch
                {
                    metrics.Add(new PerformanceMetric { Name = "CPU Kullanımı", Value = "-", Unit = "%", Status = "Bilinmiyor" });
                }

                // RAM
                try
                {
                    using var searcher = new ManagementObjectSearcher("SELECT TotalVisibleMemorySize, FreePhysicalMemory FROM Win32_OperatingSystem");
                    foreach (ManagementObject mo in searcher.Get())
                    {
                        double total = Convert.ToDouble(mo["TotalVisibleMemorySize"]) / 1024.0; // MB
                        double free = Convert.ToDouble(mo["FreePhysicalMemory"]) / 1024.0;
                        double used = total - free;
                        double pct = (used / total) * 100;
                        metrics.Add(new PerformanceMetric { Name = "RAM Kullanımı", Value = $"{used / 1024:F1} / {total / 1024:F1}", Unit = "GB", Percentage = pct, Status = pct > 90 ? "Kritik" : pct > 75 ? "Yüksek" : "Normal" });
                    }
                }
                catch { }

                // Disk
                try
                {
                    var sysDrive = DriveInfo.GetDrives().FirstOrDefault(d => d.IsReady && d.Name.StartsWith("C"));
                    if (sysDrive != null)
                    {
                        double totalGB = sysDrive.TotalSize / (1024.0 * 1024 * 1024);
                        double freeGB = sysDrive.AvailableFreeSpace / (1024.0 * 1024 * 1024);
                        double usedPct = ((totalGB - freeGB) / totalGB) * 100;
                        metrics.Add(new PerformanceMetric { Name = "Disk (C:)", Value = $"{freeGB:F1} boş / {totalGB:F1}", Unit = "GB", Percentage = usedPct, Status = freeGB < 10 ? "Kritik" : freeGB < 30 ? "Düşük" : "Normal" });
                    }
                }
                catch { }

                // Uptime
                try
                {
                    var uptime = TimeSpan.FromMilliseconds(EnvironmentCompat.TickCount64);
                    metrics.Add(new PerformanceMetric { Name = "Çalışma Süresi", Value = $"{(int)uptime.TotalDays}g {uptime.Hours}s {uptime.Minutes}d", Unit = "", Status = uptime.TotalDays > 30 ? "Uzun" : "Normal" });
                }
                catch { }

                return metrics;
            });
        }

        #endregion

        #region Legacy Toolkit Launcher

        public List<LegacyModule> GetLegacyModules()
        {
            string exeDir = AppDomain.CurrentDomain.BaseDirectory;
            // Search relative paths for legacy files
            string[] searchPaths = {
                Path.Combine(exeDir, ".."),
                Path.Combine(exeDir, "..", "Modules"),
                Path.Combine(exeDir, "..", "Archive"),
                exeDir,
            };

            var modules = new List<LegacyModule>();

            // Look for Toolkit.bat (v5 full)
            foreach (var basePath in searchPaths)
            {
                string toolkitBat = Path.Combine(basePath, "Toolkit.bat");
                if (File.Exists(toolkitBat))
                {
                    modules.Add(new LegacyModule
                    {
                        Name = "SysForge Konsolu v5 (Tam Yönetim)",
                        Description = "37 modüllü kurumsal IT admin konsolu - CMD tabanlı",
                        Icon = "🖥️",
                        LaunchLabel = "Konsolu Aç",
                        ScriptPath = Path.GetFullPath(toolkitBat),
                        Category = "Ana Araçlar"
                    });
                    break;
                }
            }

            // Look for Printer Toolkit (PowerShell GUI)
            foreach (var basePath in searchPaths)
            {
                string printerPs1 = Path.Combine(basePath, "Ultimate_Printer_Toolkit_v3.ps1");
                if (File.Exists(printerPs1))
                {
                    modules.Add(new LegacyModule
                    {
                        Name = "SysForge Yazıcı Teşhis & Onarım v3",
                        Description = "Yazıcı onarım, teşhis, host/client algılama - PowerShell GUI",
                        Icon = "🖨️",
                        LaunchLabel = "Başlat",
                        ScriptPath = Path.GetFullPath(printerPs1),
                        Category = "Yazıcı Araçları"
                    });
                    break;
                }
            }

            // Look for old CMD scripts in Old_Version
            foreach (var basePath in searchPaths)
            {
                string oldDir = Path.Combine(basePath, "Old_Version");
                if (!Directory.Exists(oldDir)) oldDir = basePath;

                string[] cmdFiles = { };
                try { cmdFiles = Directory.GetFiles(oldDir, "*.cmd"); } catch { }
                foreach (var cmd in cmdFiles)
                {
                    string name = Path.GetFileNameWithoutExtension(cmd);
                    modules.Add(new LegacyModule
                    {
                        Name = name.Replace("_", " "),
                        Description = $"Eski CMD aracı: {Path.GetFileName(cmd)}",
                        Icon = "📜",
                        LaunchLabel = "Çalıştır",
                        ScriptPath = cmd,
                        Category = "Eski Araçlar"
                    });
                }

                string[] ps1Files = { };
                try { ps1Files = Directory.GetFiles(oldDir, "*.ps1"); } catch { }
                foreach (var ps1 in ps1Files)
                {
                    string name = Path.GetFileNameWithoutExtension(ps1);
                    if (modules.Any(m => m.ScriptPath == ps1)) continue;
                    modules.Add(new LegacyModule
                    {
                        Name = name.Replace("_", " "),
                        Description = $"PowerShell aracı: {Path.GetFileName(ps1)}",
                        Icon = "⚙️",
                        LaunchLabel = "Çalıştır",
                        ScriptPath = ps1,
                        Category = "Eski Araçlar"
                    });
                }

                if (cmdFiles.Length > 0 || ps1Files.Length > 0) break;
            }

            // Look for V5.exe
            foreach (var basePath in searchPaths)
            {
                string v5Exe = Path.Combine(basePath, "V5.exe");
                if (File.Exists(v5Exe))
                {
                    modules.Add(new LegacyModule
                    {
                        Name = "SysForge Entegre Konsol (EXE)",
                        Description = "Derlenmiş V5 araç kutusu",
                        Icon = "📦",
                        LaunchLabel = "Başlat",
                        ScriptPath = v5Exe,
                        Category = "Ana Araçlar"
                    });
                    break;
                }
            }

            // Look for Printer Analyzer Pro
            foreach (var basePath in searchPaths)
            {
                string pap = Path.Combine(basePath, "Printer_Analyzer_Pro.exe");
                if (File.Exists(pap))
                {
                    modules.Add(new LegacyModule
                    {
                        Name = "Printer Analyzer Pro",
                        Description = "Gelişmiş yazıcı analiz aracı",
                        Icon = "🔬",
                        LaunchLabel = "Başlat",
                        ScriptPath = pap,
                        Category = "Yazıcı Araçları"
                    });
                    break;
                }
            }

            return modules;
        }

        public void LaunchLegacyModule(LegacyModule module)
        {
            try
            {
                string ext = Path.GetExtension(module.ScriptPath).ToLowerInvariant();
                switch (ext)
                {
                    case ".bat":
                    case ".cmd":
                        Process.Start(new ProcessStartInfo
                        {
                            FileName = "cmd.exe",
                            Arguments = $"/c \"{module.ScriptPath}\"",
                            WorkingDirectory = Path.GetDirectoryName(module.ScriptPath) ?? "",
                            UseShellExecute = true,
                            Verb = "runas"
                        });
                        break;
                    case ".ps1":
                        Process.Start(new ProcessStartInfo
                        {
                            FileName = "powershell.exe",
                            Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{module.ScriptPath}\"",
                            WorkingDirectory = Path.GetDirectoryName(module.ScriptPath) ?? "",
                            UseShellExecute = true,
                            Verb = "runas"
                        });
                        break;
                    case ".exe":
                        Process.Start(new ProcessStartInfo
                        {
                            FileName = module.ScriptPath,
                            UseShellExecute = true,
                            Verb = "runas"
                        });
                        break;
                }
                Log($"Legacy modül başlatıldı: {module.Name}", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"Legacy modül başlatılamadı: {ex.Message}", LogLevel.Error);
            }
        }

        public void LaunchToolkitModule(string label)
        {
            // Launch Toolkit.bat with --label argument to jump directly to a module
            var modules = GetLegacyModules();
            var toolkitBat = modules.FirstOrDefault(m => m.ScriptPath.EndsWith("Toolkit.bat", StringComparison.OrdinalIgnoreCase));
            if (toolkitBat != null)
            {
                try
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "cmd.exe",
                        Arguments = $"/c \"{toolkitBat.ScriptPath}\" --no-elevate --label {label}",
                        WorkingDirectory = Path.GetDirectoryName(toolkitBat.ScriptPath) ?? "",
                        UseShellExecute = true,
                        Verb = "runas"
                    });
                    Log($"Toolkit modülü başlatıldı: {label}", LogLevel.Success);
                }
                catch (Exception ex)
                {
                    Log($"Toolkit modülü başlatılamadı: {ex.Message}", LogLevel.Error);
                }
            }
            else
            {
                Log("Toolkit.bat bulunamadı. Legacy araçlar klasörünü kontrol edin.", LogLevel.Warning);
            }
        }

        public bool IsV6Running()
        {
            Socket? socket = null;
            try
            {
                socket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp)
                {
                    Blocking = false
                };
                var result = socket.BeginConnect("127.0.0.1", 9999, null, null);
                bool success = result.AsyncWaitHandle.WaitOne(400, false);
                if (success && socket.Connected)
                {
                    try { socket.EndConnect(result); } catch { }
                    return socket.Connected;
                }
                return false;
            }
            catch
            {
                return false;
            }
            finally
            {
                try { socket?.Close(); } catch { }
            }
        }

        public async Task StartV6WebDashboardAsync()
        {
            try
            {
                string scriptPath = "";
                string[] candidates = {
                    Path.Combine(LegacyToolkitRoot, "Modules", "WebBridgeServer.ps1"),
                    Path.Combine(LegacyToolkitRoot, "WebBridgeServer.ps1"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Modules", "WebBridgeServer.ps1"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "Modules", "WebBridgeServer.ps1"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "Modules", "WebBridgeServer.ps1"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "Modules", "WebBridgeServer.ps1"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "..", "Modules", "WebBridgeServer.ps1"),
                    @"C:\ProgramData\SysForgeStudio\Modules\WebBridgeServer.ps1"
                };

                foreach (var c in candidates)
                {
                    if (File.Exists(c))
                    {
                        scriptPath = Path.GetFullPath(c);
                        break;
                    }
                }

                if (string.IsNullOrEmpty(scriptPath))
                {
                    Log("WebBridgeServer.ps1 modülü bulunamadı!", LogLevel.Error);
                    return;
                }

                // Check if Node.js server.js exists for multi-device LAN access
                string rootDir = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(scriptPath) ?? "", ".."));
                string nodeServerPath = Path.Combine(rootDir, "server.js");
                bool hasNode = false;
                try
                {
                    using (var pCheck = Process.Start(new ProcessStartInfo { FileName = "node.exe", Arguments = "-v", CreateNoWindow = true, UseShellExecute = false }))
                    {
                        pCheck?.WaitForExit(1000);
                        if (pCheck?.ExitCode == 0) hasNode = true;
                    }
                }
                catch { }

                bool useNode = hasNode && File.Exists(nodeServerPath);

                if (useNode)
                {
                    Log("SysForge Node.js Sanal Sunucusu başlatılıyor (0.0.0.0:9999 - LAN/Ağ Erişimi Aktif)...", LogLevel.Info);
                }
                else
                {
                    Log("V6 Web Köprüsü başlatılıyor (Port 9999)...", LogLevel.Info);
                }

                // Ensure previous instance is stopped
                StopV6WebDashboard();

                await Task.Run(() =>
                {
                    // Add firewall rule
                    try
                    {
                        var psiFw = new ProcessStartInfo
                        {
                            FileName = "netsh.exe",
                            Arguments = "advfirewall firewall add rule name=\"SysForge Studio Web Server\" dir=in action=allow protocol=TCP localport=9999",
                            CreateNoWindow = true,
                            UseShellExecute = false
                        };
                        Process.Start(psiFw)?.WaitForExit(3000);
                    }
                    catch { }

                    ProcessStartInfo psi;
                    if (useNode)
                    {
                        psi = new ProcessStartInfo
                        {
                            FileName = "node.exe",
                            Arguments = $"\"{nodeServerPath}\"",
                            WorkingDirectory = rootDir,
                            CreateNoWindow = true,
                            UseShellExecute = false
                        };
                    }
                    else
                    {
                        psi = new ProcessStartInfo
                        {
                            FileName = "powershell.exe",
                            Arguments = $"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{scriptPath}\" -Port 9999",
                            WorkingDirectory = Path.GetDirectoryName(scriptPath) ?? "",
                            CreateNoWindow = true,
                            UseShellExecute = false
                        };
                    }
                    Process.Start(psi);
                });

                // Wait for port to open
                for (int i = 0; i < 10; i++)
                {
                    await Task.Delay(500);
                    if (IsV6Running()) break;
                }

                if (IsV6Running())
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "http://localhost:9999/dashboard.html",
                        UseShellExecute = true
                    });

                    Log("V6 Web Dashboard başarıyla açıldı (http://localhost:9999/dashboard.html).", LogLevel.Success);
                }
                else
                {
                    Log("V6 Web Köprüsü başlatılamadı: Port 9999 dinlemeye açılmadı.", LogLevel.Error);
                }
            }
            catch (Exception ex)
            {
                Log($"V6 başlatılırken hata: {ex.Message}", LogLevel.Error);
            }
        }

        public void StopV6WebDashboard()
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -Command \"Get-CimInstance Win32_Process | Where-Object { ($_.Name -like '*powershell*' -and $_.CommandLine -like '*WebBridgeServer.ps1*') -or ($_.Name -like '*node*' -and $_.CommandLine -like '*server.js*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }\"",
                    CreateNoWindow = true,
                    UseShellExecute = false
                };
                Process.Start(psi)?.WaitForExit(4000);
                Log("SysForge Sanal Sunucusu / Web Köprüsü durduruldu.", LogLevel.Info);
            }
            catch (Exception ex)
            {
                Log($"V6 durdurulurken hata: {ex.Message}", LogLevel.Error);
            }
        }

        public void LaunchPrinterAnalyzer()
        {
            try
            {
                string[] candidates = {
                    Path.Combine(LegacyToolkitRoot, "Printer_Analyzer_Pro.exe"),
                    Path.Combine(LegacyToolkitRoot, "PrinterEnterpriseFixTool", "Printer_Analyzer_Pro.exe"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Printer_Analyzer_Pro.exe"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Modules", "Printer_Analyzer_Pro.exe"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "Modules", "Printer_Analyzer_Pro.exe"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "Modules", "Printer_Analyzer_Pro.exe"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "Modules", "Printer_Analyzer_Pro.exe"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "..", "Modules", "Printer_Analyzer_Pro.exe"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "Modules", "PrinterEnterpriseFixTool", "Printer_Analyzer_Pro.exe"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "Modules", "PrinterEnterpriseFixTool", "Printer_Analyzer_Pro.exe"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "..", "Modules", "PrinterEnterpriseFixTool", "Printer_Analyzer_Pro.exe"),
                    @"C:\ProgramData\SysForgeStudio\Printer_Analyzer_Pro.exe"
                };

                string exePath = candidates.FirstOrDefault(File.Exists) ?? "";
                if (string.IsNullOrEmpty(exePath))
                {
                    Log("Printer_Analyzer_Pro.exe bulunamadı!", LogLevel.Error);
                    return;
                }

                Log($"Printer Analyzer Pro başlatılıyor: {exePath}...", LogLevel.Info);
                Process.Start(new ProcessStartInfo
                {
                    FileName = exePath,
                    WorkingDirectory = Path.GetDirectoryName(exePath) ?? "",
                    UseShellExecute = true,
                    Verb = "runas"
                });
                Log("Printer Analyzer Pro başarıyla başlatıldı.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"Printer Analyzer başlatılamadı: {ex.Message}", LogLevel.Error);
            }
        }

        public void LaunchPrinterEnterpriseFixTool()
        {
            try
            {
                string[] candidates = {
                    Path.Combine(LegacyToolkitRoot, "PrinterEnterpriseFixTool", "Printer_Enterprise_FixTool.ps1"),
                    Path.Combine(LegacyToolkitRoot, "PrinterEnterpriseFixTool", "Ultimate_Printer_Toolkit_v3.ps1"),
                    Path.Combine(LegacyToolkitRoot, "PrinterEnterpriseFixTool", "Run_PRN_UET_ENTERPRISE_V2_3_VISUAL_BACKUP.bat"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Modules", "PrinterEnterpriseFixTool", "Run_PRN_UET_ENTERPRISE_V2_3_VISUAL_BACKUP.bat"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "Modules", "PrinterEnterpriseFixTool", "Run_PRN_UET_ENTERPRISE_V2_3_VISUAL_BACKUP.bat"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "Modules", "PrinterEnterpriseFixTool", "Run_PRN_UET_ENTERPRISE_V2_3_VISUAL_BACKUP.bat"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "Modules", "PrinterEnterpriseFixTool", "Printer_Enterprise_FixTool.ps1"),
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "..", "Modules", "PrinterEnterpriseFixTool", "Printer_Enterprise_FixTool.ps1")
                };

                string toolPath = candidates.FirstOrDefault(File.Exists) ?? "";
                if (string.IsNullOrEmpty(toolPath))
                {
                    Log("Printer Enterprise Fix Tool dosyası bulunamadı!", LogLevel.Error);
                    return;
                }

                Log($"PRN Kurumsal Onarım Merkezi başlatılıyor: {toolPath}...", LogLevel.Info);
                var startInfo = new ProcessStartInfo
                {
                    FileName = toolPath,
                    WorkingDirectory = Path.GetDirectoryName(toolPath) ?? "",
                    UseShellExecute = true,
                    Verb = "runas"
                };

                if (Path.GetExtension(toolPath).Equals(".ps1", StringComparison.OrdinalIgnoreCase))
                {
                    startInfo.FileName = "powershell.exe";
                    startInfo.Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{toolPath}\"";
                }

                Process.Start(startInfo);
                Log("PRN Kurumsal Onarım Merkezi başarıyla başlatıldı.", LogLevel.Success);
            }
            catch (Exception ex)
            {
                Log($"PRN Kurumsal Onarım Merkezi başlatılamadı: {ex.Message}", LogLevel.Error);
            }
        }

        public List<string> DetectSandboxDirectories()
        {
            var list = new List<string>();
            string[] paths = {
                @"C:\ProgramData\SysForgeStudio",
                @"C:\Users\Public\SysForgeStudio_Run",
                @"C:\ProgramData\U",
                Path.Combine(Path.GetTempPath(), "SysForgeStudio"),
                Path.Combine(LegacyToolkitRoot, "scratch")
            };

            foreach (var p in paths)
            {
                if (Directory.Exists(p))
                {
                    try
                    {
                        var di = new DirectoryInfo(p);
                        long size = di.EnumerateFiles("*", SearchOption.AllDirectories).Sum(fi => fi.Length);
                        list.Add($"{p} ({size / (1024 * 1024.0):F2} MB)");
                    }
                    catch
                    {
                        list.Add($"{p} (Mevcut)");
                    }
                }
            }
            return list;
        }

        public void CleanSandboxDirectories()
        {
            string[] paths = {
                @"C:\Users\Public\SysForgeStudio_Run",
                @"C:\ProgramData\U",
                Path.Combine(Path.GetTempPath(), "SysForgeStudio"),
                Path.Combine(LegacyToolkitRoot, "scratch")
            };

            int cleaned = 0;
            foreach (var p in paths)
            {
                if (Directory.Exists(p))
                {
                    try
                    {
                        Directory.Delete(p, true);
                        cleaned++;
                        Log($"Sandbox geçici klasörü temizlendi: {p}", LogLevel.Success);
                    }
                    catch (Exception ex)
                    {
                        Log($"Temizlenemedi ({p}): {ex.Message}", LogLevel.Warning);
                    }
                }
            }

            if (cleaned == 0)
            {
                Log("Temizlenecek geçici kalıntı bulunamadı.", LogLevel.Info);
            }
        }

        #endregion

        #region HTML Report

        public string GenerateHtmlReport(List<PrinterItem> printers, List<DiagItem> diagItems)
        {
            string reportFile = Path.Combine(LogsDirectory, $"UPT_Report_{DateTime.Now:yyyyMMdd_HHmmss}.html");

            var sb = new StringBuilder();
            sb.AppendLine("<!DOCTYPE html>");
            sb.AppendLine("<html lang='tr'>");
            sb.AppendLine("<head>");
            sb.AppendLine("<meta charset='utf-8'/>");
            sb.AppendLine("<title>SysForge Studio - Sistem &amp; Donanım Raporu</title>");
            sb.AppendLine("<style>");
            sb.AppendLine("body { font-family: 'Segoe UI', Tahoma, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 24px; }");
            sb.AppendLine(".container { max-width: 1000px; margin: 0 auto; background: #1e293b; padding: 32px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }");
            sb.AppendLine("h1 { color: #38bdf8; margin-top: 0; }");
            sb.AppendLine("table { width: 100%; border-collapse: collapse; margin-top: 16px; margin-bottom: 32px; }");
            sb.AppendLine("th, td { padding: 12px; text-align: left; border-bottom: 1px solid #334155; }");
            sb.AppendLine("th { background: #0f172a; color: #94a3b8; }");
            sb.AppendLine(".badge-ok { background: #059669; color: white; padding: 4px 8px; border-radius: 4px; font-weight: bold; }");
            sb.AppendLine(".badge-warn { background: #d97706; color: white; padding: 4px 8px; border-radius: 4px; font-weight: bold; }");
            sb.AppendLine(".badge-err { background: #dc2626; color: white; padding: 4px 8px; border-radius: 4px; font-weight: bold; }");
            sb.AppendLine("</style>");
            sb.AppendLine("</head>");
            sb.AppendLine("<body>");
            sb.AppendLine("<div class='container'>");
            sb.AppendLine("<h1>🛠️ SysForge Studio - Sistem &amp; Donanım Raporu</h1>");
            sb.AppendLine($"<p>Oluşturulma Tarihi: <b>{DateTime.Now:dd.MM.yyyy HH:mm:ss}</b></p>");

            sb.AppendLine("<h2>1. Sistem Teşhis Özeti</h2>");
            sb.AppendLine("<table><tr><th>Bileşen</th><th>Kategori</th><th>Durum</th><th>Detay</th></tr>");
            foreach (var d in diagItems)
            {
                string badgeClass = d.Status == "OK" ? "badge-ok" : (d.Status == "WARN" ? "badge-warn" : "badge-err");
                sb.AppendLine($"<tr><td>{d.Name}</td><td>{d.Category}</td><td><span class='{badgeClass}'>{d.Status}</span></td><td>{d.Details}</td></tr>");
            }
            sb.AppendLine("</table>");

            sb.AppendLine("<h2>2. Yüklü Yazıcılar</h2>");
            sb.AppendLine("<table><tr><th>Yazıcı Adı</th><th>Bağlantı Noktası</th><th>Sürücü</th><th>Varsayılan</th></tr>");
            foreach (var p in printers)
            {
                sb.AppendLine($"<tr><td><b>{p.Name}</b></td><td>{p.PortName}</td><td>{p.DriverName}</td><td>{(p.IsDefault ? "Evet" : "Hayır")}</td></tr>");
            }
            sb.AppendLine("</table>");

            sb.AppendLine("</div>");
            sb.AppendLine("</body></html>");

            File.WriteAllText(reportFile, sb.ToString(), Encoding.UTF8);
            return reportFile;
        }

        #endregion
    }
}
