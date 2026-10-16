using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using SysForgeStudio.Models;

namespace SysForgeStudio.Services
{
    public class ModuleCatalogService
    {
        public static ModuleCatalogService Instance { get; } = new ModuleCatalogService();

        public async Task<string> ExecuteActionAsync(ModuleAction action, Action<string>? onOutputLine = null)
        {
            var sbOutput = new StringBuilder();
            action.Status = "Çalışıyor...";

            void AppendLine(string line)
            {
                sbOutput.AppendLine(line);
                onOutputLine?.Invoke(line);
            }

            AppendLine($"[BAŞLADI] {action.Title} ({DateTime.Now:HH:mm:ss})");
            AppendLine($"Komut Türü: {action.Type} | Hedef: {action.Command}");
            AppendLine(new string('-', 60));

            try
            {
                if (action.Type == ActionType.Process)
                {
                    await Task.Run(() =>
                    {
                        var psi = new ProcessStartInfo
                        {
                            FileName = action.Command,
                            UseShellExecute = true
                        };
                        Process.Start(psi);
                    });

                    AppendLine($"[BİLGİ] '{action.Title}' Windows arayüzünde başarıyla başlatıldı.");
                    action.Status = "Başlatıldı";
                    ToolkitEngine.Instance.Log($"Arayüz aracı açıldı: {action.Title}", LogLevel.Success);
                }
                else if (action.Type == ActionType.PowerShell)
                {
                    await Task.Run(() =>
                    {
                        var psi = new ProcessStartInfo
                        {
                            FileName = "powershell.exe",
                            Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"{action.Command}\"",
                            RedirectStandardOutput = true,
                            RedirectStandardError = true,
                            UseShellExecute = false,
                            CreateNoWindow = true
                        };

                        using var proc = new Process { StartInfo = psi };
                        proc.OutputDataReceived += (s, e) =>
                        {
                            if (e.Data != null) AppendLine(e.Data);
                        };
                        proc.ErrorDataReceived += (s, e) =>
                        {
                            if (e.Data != null) AppendLine($"[HATA] {e.Data}");
                        };

                        proc.Start();
                        proc.BeginOutputReadLine();
                        proc.BeginErrorReadLine();
                        proc.WaitForExit();

                        AppendLine(new string('-', 60));
                        AppendLine($"[TAMAMLANDI] Çıkış Kodu: {proc.ExitCode}");
                    });

                    action.Status = "Tamamlandı";
                    ToolkitEngine.Instance.Log($"PowerShell işlemi tamamlandı: {action.Title}", LogLevel.Success);
                }
                else if (action.Type == ActionType.Cmd)
                {
                    await Task.Run(() =>
                    {
                        var psi = new ProcessStartInfo
                        {
                            FileName = "cmd.exe",
                            Arguments = $"/c {action.Command}",
                            RedirectStandardOutput = true,
                            RedirectStandardError = true,
                            UseShellExecute = false,
                            CreateNoWindow = true
                        };

                        using var proc = new Process { StartInfo = psi };
                        proc.OutputDataReceived += (s, e) =>
                        {
                            if (e.Data != null) AppendLine(e.Data);
                        };
                        proc.ErrorDataReceived += (s, e) =>
                        {
                            if (e.Data != null) AppendLine($"[HATA] {e.Data}");
                        };

                        proc.Start();
                        proc.BeginOutputReadLine();
                        proc.BeginErrorReadLine();
                        proc.WaitForExit();

                        AppendLine(new string('-', 60));
                        AppendLine($"[TAMAMLANDI] Çıkış Kodu: {proc.ExitCode}");
                    });

                    action.Status = "Tamamlandı";
                    ToolkitEngine.Instance.Log($"Komut işlemi tamamlandı: {action.Title}", LogLevel.Success);
                }
            }
            catch (Exception ex)
            {
                AppendLine($"[KRİTİK HATA] {ex.Message}");
                action.Status = "Hata";
                ToolkitEngine.Instance.Log($"Hata ({action.Title}): {ex.Message}", LogLevel.Error);
            }

            return sbOutput.ToString();
        }

        public List<ModuleCategory> GetAllCategories()
        {
            return new List<ModuleCategory>
            {
                new ModuleCategory
                {
                    Id = "cat_sys_admin",
                    Code = "01",
                    Name = "Sistem & Yönetim",
                    Description = "Windows yönetim konsolları, süreçler, servisler ve sistem denetimi",
                    Icon = "⚙️",
                    Group = "Sistem",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "sa_compmgmt", Title = "Bilgisayar Yönetimi", Description = "Diskler, aygıtlar ve paylaşımlar dahil ana konsol", Icon = "🖥️", Type = ActionType.Process, Command = "compmgmt.msc", Badge = "MSC" },
                        new ModuleAction { Id = "sa_msconfig", Title = "Sistem Yapılandırması", Description = "Önyükleme, servisler ve genel başlatma seçenekleri", Icon = "⚙️", Type = ActionType.Process, Command = "msconfig", Badge = "EXE" },
                        new ModuleAction { Id = "sa_devmgmt", Title = "Aygıt Yöneticisi", Description = "Donanım aygıtları, sürücüler ve PnP cihazlar", Icon = "🔌", Type = ActionType.Process, Command = "devmgmt.msc", Badge = "MSC" },
                        new ModuleAction { Id = "sa_services", Title = "Hizmetler / Servisler", Description = "Arka plan Windows servislerinin durum ve kontrolü", Icon = "🛠️", Type = ActionType.Process, Command = "services.msc", Badge = "MSC" },
                        new ModuleAction { Id = "sa_taskmgr", Title = "Görev Yöneticisi", Description = "Canlı süreç, bellek ve performans yöneticisi", Icon = "📊", Type = ActionType.Process, Command = "taskmgr", Badge = "EXE" },
                        new ModuleAction { Id = "sa_control", Title = "Klasik Denetim Masası", Description = "Geleneksel Windows sistem ayarları", Icon = "🎛️", Type = ActionType.Process, Command = "control", Badge = "CPL" },
                        new ModuleAction { Id = "sa_sysdm", Title = "Gelişmiş Sistem Özellikleri", Description = "Performans ayarları, ortam değişkenleri ve sanal bellek", Icon = "⚙️", Type = ActionType.Process, Command = "sysdm.cpl", Badge = "CPL" },
                        new ModuleAction { Id = "sa_eventvwr", Title = "Olay Görüntüleyici", Description = "Sistem, güvenlik ve uygulama hata kayıtları", Icon = "📋", Type = ActionType.Process, Command = "eventvwr.msc", Badge = "MSC" },
                        new ModuleAction { Id = "sa_envvars", Title = "Ortam Değişkenleri", Description = "Kullanıcı ve Sistem ortam değişkenlerini listeler", Icon = "📜", Type = ActionType.PowerShell, Command = "Get-ChildItem env: | Format-Table -AutoSize", Badge = "PS" },
                        new ModuleAction { Id = "sa_schedtasks", Title = "Zamanlanmış Görevler", Description = "Windows Görev Zamanlayıcı konsolunu açar", Icon = "⏱️", Type = ActionType.Process, Command = "taskschd.msc", Badge = "MSC" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_network",
                    Code = "02",
                    Name = "Ağ & İnternet",
                    Description = "IP yapılandırması, WiFi şifreleri, DNS önbelleği, güvenlik duvarı ve portlar",
                    Icon = "🌐",
                    Group = "Ağ",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "net_ipconfig", Title = "IP ve Bağdaştırıcı Bilgisi", Description = "Tüm ağ kartlarının IP, Alt Ağ ve Ağ Geçidi detayları", Icon = "🌐", Type = ActionType.Cmd, Command = "ipconfig /all", Badge = "CMD" },
                        new ModuleAction { Id = "net_flushdns", Title = "DNS Önbelleğini Temizle", Description = "Bozulmuş DNS kayıtlarını temizler ve yeniler", Icon = "⚡", Type = ActionType.Cmd, Command = "ipconfig /flushdns", Badge = "CMD" },
                        new ModuleAction { Id = "net_wifipass", Title = "Kayıtlı WiFi Şifrelerini Çöz", Description = "Bilgisayarda kayıtlı tüm WiFi ağlarının şifrelerini listeler", Icon = "🔑", Type = ActionType.PowerShell, Command = "$profiles=(netsh wlan show profiles) | Select-String 'All User Profile' | ForEach-Object {($_.ToString() -split ':',2)[1].Trim()}; foreach($p in $profiles){$detail=netsh wlan show profile name=$p key=clear; $key=($detail | Select-String 'Key Content' | Select-Object -First 1); $pass=if($key){($key.ToString() -split ':',2)[1].Trim()}else{'<Sifresiz>'}; Write-Host ('[WiFi] ' + $p + ' -> Sifre: ' + $pass) -ForegroundColor Cyan}", Badge = "PS" },
                        new ModuleAction { Id = "net_ncpa", Title = "Ağ Bağlantıları Penceresi", Description = "Ağ adaptörlerini etkinleştirme/devre dışı bırakma penceresi", Icon = "🔌", Type = ActionType.Process, Command = "ncpa.cpl", Badge = "CPL" },
                        new ModuleAction { Id = "net_pingtest", Title = "İnternet Hızlı Ping Testi", Description = "Google DNS (8.8.8.8) üzerinden 4 paketlik gecikme testi", Icon = "📡", Type = ActionType.Cmd, Command = "ping -n 4 8.8.8.8", Badge = "CMD" },
                        new ModuleAction { Id = "net_tracert", Title = "Yol İzleme (Traceroute)", Description = "İnternet çıkış güzergahını ve atlama noktalarını izler", Icon = "🗺️", Type = ActionType.Cmd, Command = "tracert -d -h 12 8.8.8.8", Badge = "CMD" },
                        new ModuleAction { Id = "net_netstat", Title = "Aktif Portlar & Dinleyiciler", Description = "Sistemdeki tüm açık TCP/UDP dinleme bağlantıları", Icon = "🚪", Type = ActionType.PowerShell, Command = "netstat -ano | Select-String 'LISTENING' | Select-Object -First 40", Badge = "PS" },
                        new ModuleAction { Id = "net_firewall_gui", Title = "Gelişmiş Güvenlik Duvarı", Description = "Windows Defender Güvenlik Duvarı kural konsolu", Icon = "🧱", Type = ActionType.Process, Command = "wf.msc", Badge = "MSC" },
                        new ModuleAction { Id = "net_reset_stack", Title = "Ağ Yığınını Sıfırla (Winsock)", Description = "Winsock ve TCP/IP protokollerini tamamen sıfırlar", Icon = "🔄", Type = ActionType.Cmd, Command = "netsh winsock reset & netsh int ip reset", Badge = "CMD" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_repair",
                    Code = "03",
                    Name = "Windows Onarım & Kurtarma",
                    Description = "Sistem dosyası denetimi, bileşen deposu, kurtarma ve disk kontrolleri",
                    Icon = "🛠️",
                    Group = "Onarım",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "rep_sfc", Title = "SFC Sistem Dosyası Doğrulama", Description = "Bozuk sistem dosyalarını tarar ve otomatik onarır", Icon = "🛡️", Type = ActionType.Cmd, Command = "sfc /scannow", Badge = "CMD" },
                        new ModuleAction { Id = "rep_dism", Title = "DISM İmaj Sağlık Onarımı", Description = "Windows bileşen deposunu çevrimiçi kaynaktan onarır", Icon = "🔧", Type = ActionType.Cmd, Command = "dism /online /cleanup-image /restorehealth", Badge = "CMD" },
                        new ModuleAction { Id = "rep_dism_clean", Title = "DISM Bileşen Deposu Temizliği", Description = "Eski güncelleme kalıntılarını temizler ve alan açar", Icon = "🧹", Type = ActionType.Cmd, Command = "dism /online /cleanup-image /startcomponentcleanup", Badge = "CMD" },
                        new ModuleAction { Id = "rep_chkdsk", Title = "C: Sürücüsü Hata Taraması", Description = "Disk dosya sistemi hatalarını kontrol eder", Icon = "💾", Type = ActionType.Cmd, Command = "chkdsk C: /scan", Badge = "CMD" },
                        new ModuleAction { Id = "rep_recovery_ui", Title = "Windows Kurtarma Ayarları", Description = "Gelişmiş başlangıç ve sıfırlama ayarları menüsü", Icon = "🔄", Type = ActionType.Process, Command = "ms-settings:recovery", Badge = "URI" },
                        new ModuleAction { Id = "rep_restore_ui", Title = "Sistem Geri Yükleme", Description = "Sistem geri yükleme sihirbazını açar", Icon = "⏪", Type = ActionType.Process, Command = "rstrui.exe", Badge = "EXE" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_security",
                    Code = "04",
                    Name = "Güvenlik & Defender",
                    Description = "Antivirüs taramaları, güvenlik ilkeleri, BitLocker ve koruma durumu",
                    Icon = "🛡️",
                    Group = "Güvenlik",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "sec_quickscan", Title = "Defender Hızlı Tarama", Description = "Kritik sistem klasörlerinde hızlı zararlı taraması yapar", Icon = "⚡", Type = ActionType.PowerShell, Command = "Start-MpScan -ScanType QuickScan; Write-Host 'Hizli tarama tamamlandi.'", Badge = "PS" },
                        new ModuleAction { Id = "sec_updatesig", Title = "İmza ve Tanımları Güncelle", Description = "En son virüs ve casus yazılım tanımlarını indirir", Icon = "📥", Type = ActionType.PowerShell, Command = "Update-MpSignature; Write-Host 'Tanimlar guncellendi.'", Badge = "PS" },
                        new ModuleAction { Id = "sec_status", Title = "Defender Koruma Durumu", Description = "Gerçek zamanlı koruma ve modül durumlarını listeler", Icon = "🔍", Type = ActionType.PowerShell, Command = "Get-MpComputerStatus | Select-Object AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureVersion,NISSignatureVersion | Format-List", Badge = "PS" },
                        new ModuleAction { Id = "sec_defender_app", Title = "Windows Güvenlik Merkezi", Description = "Resmi Windows Güvenlik kontrol panelini açar", Icon = "🛡️", Type = ActionType.Process, Command = "windowsdefender:", Badge = "URI" },
                        new ModuleAction { Id = "sec_secpol", Title = "Yerel Güvenlik İlkesi", Description = "Hesap kilitlenmesi, parola ve denetim ilkeleri konsolu", Icon = "🔒", Type = ActionType.Process, Command = "secpol.msc", Badge = "MSC" },
                        new ModuleAction { Id = "sec_bitlocker", Title = "BitLocker Sürücü Şifreleme", Description = "Sürücü şifreleme yönetim paneli", Icon = "🔐", Type = ActionType.Process, Command = "control.exe /name Microsoft.BitLockerDriveEncryption", Badge = "CPL" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_performance",
                    Code = "05",
                    Name = "Performans & Optimizasyon",
                    Description = "Önbellek temizliği, RAM rahatlatma, CPU süreçleri ve geçici dosyalar",
                    Icon = "⚡",
                    Group = "Performans",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "perf_cleantemp", Title = "Kullanıcı Temp Temizliği", Description = "%TEMP% klasöründeki artık ve geçici dosyaları temizler", Icon = "🧹", Type = ActionType.PowerShell, Command = "Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Write-Host 'Kullanici Temp klasoru temizlendi.' -ForegroundColor Green", Badge = "PS" },
                        new ModuleAction { Id = "perf_cleanwintemp", Title = "Windows Temp Temizliği", Description = "C:\\Windows\\Temp klasörünü temizler", Icon = "🧹", Type = ActionType.PowerShell, Command = "Get-ChildItem C:\\Windows\\Temp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Write-Host 'Windows Temp temizlendi.' -ForegroundColor Green", Badge = "PS" },
                        new ModuleAction { Id = "perf_prefetch", Title = "Prefetch Önbellek Temizliği", Description = "C:\\Windows\\Prefetch uygulama önbelleğini temizler", Icon = "🚀", Type = ActionType.PowerShell, Command = "Get-ChildItem C:\\Windows\\Prefetch -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Write-Host 'Prefetch temizlendi.' -ForegroundColor Green", Badge = "PS" },
                        new ModuleAction { Id = "perf_cleanmgr", Title = "Disk Temizleme Sihirbazı", Description = "Gereksiz sistem dosyalarını seçerek temizleyin", Icon = "🗑️", Type = ActionType.Process, Command = "cleanmgr.exe", Badge = "EXE" },
                        new ModuleAction { Id = "perf_topcpu", Title = "En Çok CPU Tüketen İşlemler", Description = "Sistemi en çok yoran ilk 10 işlemi listeler", Icon = "📊", Type = ActionType.PowerShell, Command = "Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 ProcessName,CPU,WorkingSet64 | Format-Table -AutoSize", Badge = "PS" },
                        new ModuleAction { Id = "perf_topram", Title = "En Çok RAM Tüketen İşlemler", Description = "En yüksek bellek kullanan ilk 10 işlemi listeler", Icon = "🧠", Type = ActionType.PowerShell, Command = "Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 ProcessName,@{Name='RAM(MB)';Expression={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize", Badge = "PS" },
                        new ModuleAction { Id = "perf_perfmon", Title = "Performans İzleyicisi", Description = "Gelişmiş donanım performans sayaçları konsolu", Icon = "📈", Type = ActionType.Process, Command = "perfmon.msc", Badge = "MSC" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_storage",
                    Code = "06",
                    Name = "Depolama & Disk Yönetimi",
                    Description = "Bölümleme, birleştirme, SSD TRIM ve depolama alanları",
                    Icon = "💾",
                    Group = "Depolama",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "disk_mgmt", Title = "Disk Yönetimi Konsolu", Description = "Disk bölümlerini, harfleri ve formatları yönetin", Icon = "💾", Type = ActionType.Process, Command = "diskmgmt.msc", Badge = "MSC" },
                        new ModuleAction { Id = "disk_defrag_c", Title = "C: Sürücüsünü Optimize Et / Defrag", Description = "C: sürücüsü için disk birleştirme veya SSD TRIM optimizasyonu", Icon = "⚡", Type = ActionType.Cmd, Command = "defrag C: /O /U /V", Badge = "CMD" },
                        new ModuleAction { Id = "disk_trim_all", Title = "Tüm SSD'lere TRIM Gönder", Description = "SSD sürücülerinin performansını yeniler", Icon = "🚀", Type = ActionType.Cmd, Command = "defrag /C /L", Badge = "CMD" },
                        new ModuleAction { Id = "disk_volumes", Title = "Sürücü Doluluk Listesi", Description = "Tüm mantıksal sürücülerin boş/dolu alan durumları", Icon = "📊", Type = ActionType.PowerShell, Command = "Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,VolumeName,@{Name='Bos(GB)';Expression={[math]::Round($_.FreeSpace/1GB,1)}},@{Name='Toplam(GB)';Expression={[math]::Round($_.Size/1GB,1)}} | Format-Table -AutoSize", Badge = "PS" },
                        new ModuleAction { Id = "disk_storagesense", Title = "Akıllı Depolama Ayarları", Description = "Windows Storage Sense otomatik temizleme ayarları", Icon = "⚙️", Type = ActionType.Process, Command = "ms-settings:storagesense", Badge = "URI" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_users",
                    Code = "07",
                    Name = "Kullanıcı & Hesap Yönetimi",
                    Description = "Yerel kullanıcılar, parola ilkeleri ve oturum kontrolleri",
                    Icon = "👤",
                    Group = "Sistem",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "usr_lusrmgr", Title = "Yerel Kullanıcılar & Gruplar", Description = "Kullanıcı hesapları ve grup üyelikleri konsolu", Icon = "👥", Type = ActionType.Process, Command = "lusrmgr.msc", Badge = "MSC" },
                        new ModuleAction { Id = "usr_netplwiz", Title = "Gelişmiş Kullanıcı Hesapları", Description = "Otomatik oturum açma ve kullanıcı şifre ayarları", Icon = "👤", Type = ActionType.Process, Command = "netplwiz", Badge = "EXE" },
                        new ModuleAction { Id = "usr_list", Title = "Mevcut Kullanıcıları Listele", Description = "Sistemdeki tüm yerel hesapları listeler", Icon = "📋", Type = ActionType.Cmd, Command = "net user", Badge = "CMD" },
                        new ModuleAction { Id = "usr_lock", Title = "Oturumu Kilitle", Description = "Mevcut Windows oturumunu anında kilitler", Icon = "🔒", Type = ActionType.Process, Command = "rundll32.exe user32.dll,LockWorkStation", Badge = "DLL" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_update",
                    Code = "10",
                    Name = "Windows Update & Etkinleştirme",
                    Description = "Güncelleme önbellek sıfırlama, lisans doğrulama ve taramalar",
                    Icon = "🔄",
                    Group = "Sistem",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "upd_reset_services", Title = "Update Servisleri & Önbellek Sıfırla", Description = "Bozuk SoftwareDistribution ve Catroot klasörlerini temizler", Icon = "⚡", Type = ActionType.Cmd, Command = "net stop wuauserv & net stop bits & net stop cryptsvc & ren C:\\Windows\\SoftwareDistribution SoftwareDistribution.bak & net start bits & net start cryptsvc & net start wuauserv & echo Sifirlandi.", Badge = "CMD" },
                        new ModuleAction { Id = "upd_start_scan", Title = "Güncelleme Taramasını Tetikle", Description = "USO Client üzerinden yeni güncelleme aramasını başlatır", Icon = "🔍", Type = ActionType.Cmd, Command = "usoclient StartScan & echo Tarama baslatildi.", Badge = "CMD" },
                        new ModuleAction { Id = "upd_settings", Title = "Windows Update Ayarları", Description = "Windows Ayarlar güncelleme sayfasını açar", Icon = "⚙️", Type = ActionType.Process, Command = "ms-settings:windowsupdate", Badge = "URI" },
                        new ModuleAction { Id = "upd_license_status", Title = "Lisans Durumunu Sorgula", Description = "Windows aktivasyon ve lisans kanal durumunu gösterir", Icon = "🔑", Type = ActionType.Cmd, Command = "cscript //nologo %windir%\\system32\\slmgr.vbs /dli", Badge = "VBS" },
                        new ModuleAction { Id = "upd_oem_key", Title = "Anakart OEM Ürün Anahtarını Çek", Description = "BIOS içine gömülü orijinal Windows anahtarını okur", Icon = "💻", Type = ActionType.PowerShell, Command = "$key=(Get-CimInstance -Query 'SELECT OA3xOriginalProductKey FROM SoftwareLicensingService').OA3xOriginalProductKey; if($key){Write-Host ('OEM Lisans Anahtari: ' + $key) -ForegroundColor Green}else{Write-Host 'Gomulu OEM anahtar bulunamadi.' -ForegroundColor Yellow}", Badge = "PS" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_office",
                    Code = "11",
                    Name = "Office & Outlook Araçları",
                    Description = "Outlook güvenli mod, profil yöneticisi ve onarım araçları",
                    Icon = "✉️",
                    Group = "Office",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "off_safe", Title = "Outlook Güvenli Mod", Description = "Eklentileri devre dışı bırakarak Outlook'u açar", Icon = "🛡️", Type = ActionType.Process, Command = "outlook.exe /safe", Badge = "EXE" },
                        new ModuleAction { Id = "off_profiles", Title = "Outlook Profil Yöneticisi", Description = "E-posta profillerini düzenleme penceresini açar", Icon = "👤", Type = ActionType.Process, Command = "outlook.exe /manageprofiles", Badge = "EXE" },
                        new ModuleAction { Id = "off_resetnav", Title = "Gezinti Bölmesini Sıfırla", Description = "Açılmayan veya kilitlenen Outlook gezinti görünümünü düzeltir", Icon = "🔄", Type = ActionType.Process, Command = "outlook.exe /resetnavpane", Badge = "EXE" },
                        new ModuleAction { Id = "off_appwiz", Title = "Office Onarım Paneli", Description = "Program Ekle/Kaldır onarım penceresi", Icon = "🛠️", Type = ActionType.Process, Command = "appwiz.cpl", Badge = "CPL" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_printer_spool",
                    Code = "12",
                    Name = "Yazıcı & Spooler Merkezi",
                    Description = "Yazdırma biriktiricisi, RPC 0x0000011b, 709 ve paylaşım izinleri",
                    Icon = "🖨️",
                    Group = "Yazıcı",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "prn_resetspooler", Title = "Biriktiriciyi (Spooler) Sıfırla", Description = "Tüm bekleyen işleri temizler ve servisi yeniden başlatır", Icon = "🔄", Type = ActionType.Cmd, Command = "net stop spooler & del /Q /F /S \"%systemroot%\\System32\\Spool\\Printers\\*.*\" & net start spooler & echo Spooler sifirlandi.", Badge = "CMD" },
                        new ModuleAction { Id = "prn_rpcfix", Title = "RPC 0x0000011b & 709 Onarımı", Description = "Kayıt defteri RPC kimlik doğrulama ayarlarını düzeltir", Icon = "⚡", Type = ActionType.Cmd, Command = "reg add \"HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Print\" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f & echo 0x0000011b Duzeltildi.", Badge = "REG" },
                        new ModuleAction { Id = "prn_printui", Title = "Yazıcı Sunucusu Özellikleri", Description = "Sürücüler, bağlantı noktaları ve formlar konsolu", Icon = "🖨️", Type = ActionType.Process, Command = "printui.exe /s", Badge = "EXE" },
                        new ModuleAction { Id = "prn_printmgmt", Title = "Yazdırma Yönetimi Konsolu", Description = "Gelişmiş ağ ve sunucu yazdırma konsolu", Icon = "📋", Type = ActionType.Process, Command = "printmanagement.msc", Badge = "MSC" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_gpo_reg",
                    Code = "15",
                    Name = "Kayıt Defteri & Grup İlkesi",
                    Description = "Grup politikaları, zorla güncelleme ve kayıt defteri araçları",
                    Icon = "📑",
                    Group = "Sistem",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "gpo_edit", Title = "Grup İlkesi Düzenleyicisi", Description = "Yerel politika ayarları (gpedit.msc)", Icon = "📑", Type = ActionType.Process, Command = "gpedit.msc", Badge = "MSC" },
                        new ModuleAction { Id = "gpo_force", Title = "İlkeleri Zorla Güncelle", Description = "gpupdate /force ile tüm ilkeleri hemen uygular", Icon = "⚡", Type = ActionType.Cmd, Command = "gpupdate /force", Badge = "CMD" },
                        new ModuleAction { Id = "gpo_regedit", Title = "Kayıt Defteri Düzenleyicisi", Description = "Windows Kayıt Defteri (regedit.exe)", Icon = "📝", Type = ActionType.Process, Command = "regedit.exe", Badge = "EXE" },
                        new ModuleAction { Id = "gpo_rsop", Title = "İlke Sonuç Kümesi (RSoP)", Description = "Uygulanan tüm ilkelerin geçerlilik raporu", Icon = "🔍", Type = ActionType.Process, Command = "rsop.msc", Badge = "MSC" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_power_dev",
                    Code = "20",
                    Name = "Geliştirici & Güçlü Araçlar",
                    Description = "PowerShell, ortam yolları, paket yöneticisi ve tanılama",
                    Icon = "💡",
                    Group = "Araçlar",
                    Actions = new List<ModuleAction>
                    {
                        new ModuleAction { Id = "dev_wingetinfo", Title = "Winget Durumu ve Kaynaklar", Description = "Windows Paket Yöneticisi sürüm ve kaynak bilgisi", Icon = "📦", Type = ActionType.Cmd, Command = "winget --info", Badge = "CMD" },
                        new ModuleAction { Id = "dev_pathlist", Title = "Sistem PATH Yollarını Ayrıştır", Description = "Ortam değişkenindeki tüm arama yollarını satır satır gösterir", Icon = "🛣️", Type = ActionType.PowerShell, Command = "$env:PATH -split ';' | Where-Object { $_ } | ForEach-Object { Write-Host $_ }", Badge = "PS" },
                        new ModuleAction { Id = "dev_dotnetver", Title = "Kurulu .NET SDK/Runtime Sürümleri", Description = "Sistemdeki .NET çalışma zamanı sürümlerini listeler", Icon = "⚙️", Type = ActionType.Cmd, Command = "dotnet --info", Badge = "CMD" },
                        new ModuleAction { Id = "dev_godmode", Title = "Windows 'GodMode' Klasörü", Description = "Tüm Windows yönetim ayarlarına tek pencereden erişin", Icon = "👑", Type = ActionType.Process, Command = "explorer.exe shell:::{ED7BA470-8E54-465E-825C-99712043E01C}", Badge = "SHELL" }
                    }
                },

                new ModuleCategory
                {
                    Id = "cat_portable",
                    Code = "36",
                    Name = "Taşınabilir Araçlar Menüsü",
                    Description = "En popüler ve kritik bağımsız sistem araçları",
                    Icon = "🧰",
                    Group = "Araçlar",
                    Actions = GetPortableCatalogActions()
                }
            };
        }

        private List<ModuleAction> GetPortableCatalogActions()
        {
            var list = new List<ModuleAction>();
            string baseDir = ToolkitEngine.Instance.LegacyToolkitRoot;

            var toolDefinitions = new (string Name, string Path, string Desc, string Icon)[]
            {
                ("BlueScreenView", @"Tools\bluescreenview-x64\BlueScreenView.exe", "Mavi ekran (BSOD) minidump dökümlerini analiz eder", "💻"),
                ("Hard Disk Sentinel Pro", @"Tools\Hard Disk Sentinel Pro\Hard Disk Sentinel.exe", "Disk sağlığı, sıcaklık ve SMART ömür izleyici", "💾"),
                ("Glary Utilities Pro", @"Tools\Glary Utilities Pro\GlaryUtilitiesPortable.exe", "Sistem bakım ve derin temizlik yardımcıları", "🧹"),
                ("WirelessKeyView", @"Tools\Feel Like Hacker\wirelesskeyview.exe", "Kayıtlı tüm WiFi şifrelerini anında gösterir", "🔑"),
                ("ProduKey License Scanner", @"Tools\Feel Like Hacker\produkey.exe", "Windows ve Office lisans ürün anahtarlarını bulur", "🏷️"),
                ("DevManView", @"Tools\Feel Like Hacker\devmanview.exe", "Gelişmiş aygıt yöneticisi ve donanım inceleyici", "🔌"),
                ("CurrPorts", @"Tools\Feel Like Hacker\cports.exe", "Anlık TCP/UDP bağlantıları ve ait olduğu süreçleri izler", "🚪"),
                ("USBDriveLog", @"Tools\Feel Like Hacker\usbdrivelog.exe", "Bu bilgisayara bağlanmış tüm USB belleklerin geçmişi", "💾"),
                ("WhatInStartup", @"Tools\Feel Like Hacker\whatinstartup.exe", "Başlangıçta otomatik çalışan programları denetler", "🚀")
            };

            foreach (var t in toolDefinitions)
            {
                string fullPath = Path.Combine(baseDir, t.Path);
                list.Add(new ModuleAction
                {
                    Id = "tool_" + t.Name.ToLower().Replace(" ", "_"),
                    Title = t.Name,
                    Description = t.Desc,
                    Icon = t.Icon,
                    Type = ActionType.Process,
                    Command = File.Exists(fullPath) ? fullPath : t.Name,
                    Badge = "PORTABLE",
                    Status = File.Exists(fullPath) ? "Hazır" : "Klasörde Ara"
                });
            }

            return list;
        }
    }
}
