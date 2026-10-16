using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace UltimateToolkit.Modern.Services
{
    public class SystemBackupService
    {
        public static SystemBackupService Instance { get; } = new SystemBackupService();

        public string BackupDirectory { get; }

        public SystemBackupService()
        {
            string appData = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "SysForgeStudio");
            BackupDirectory = Path.Combine(appData, "Backups");
            try
            {
                if (!Directory.Exists(BackupDirectory))
                {
                    Directory.CreateDirectory(BackupDirectory);
                }
            }
            catch { }
        }

        /// <summary>
        /// Windows Sistem Geri Yükleme Noktası (Restore Point) oluşturur.
        /// </summary>
        public async Task<(bool Success, string Message)> CreateSystemRestorePointAsync(string description)
        {
            return await Task.Run(() =>
            {
                try
                {
                    string safeDesc = string.IsNullOrWhiteSpace(description) 
                        ? $"SysForge_Backup_{DateTime.Now:yyyyMMdd_HHmmss}" 
                        : $"SysForge_{description.Replace(" ", "_")}_{DateTime.Now:HHmmss}";

                    if (safeDesc.Length > 60) safeDesc = safeDesc.Substring(0, 60);

                    // PowerShell komutu: Korumayı aktif et, frekans kısıtlamasını kaldır ve Checkpoint oluştur
                    string psCommand = $@"
                        try {{
                            Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue;
                            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue;
                            Checkpoint-Computer -Description '{safeDesc}' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop;
                            Write-Output 'RESTORE_POINT_SUCCESS';
                        }} catch {{
                            $wmi = [wmiclass]'\\localhost\root\default:SystemRestore';
                            if ($wmi) {{
                                $res = $wmi.CreateRestorePoint('{safeDesc}', 100, 7);
                                if ($res.ReturnValue -eq 0) {{
                                    Write-Output 'RESTORE_POINT_SUCCESS';
                                }} else {{
                                    Write-Output ('WMI_ERROR_' + $res.ReturnValue);
                                }}
                            }} else {{
                                Write-Output ('PS_ERROR: ' + $_.Exception.Message);
                            }}
                        }}
                    ";

                    var psi = new ProcessStartInfo
                    {
                        FileName = "powershell.exe",
                        Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"{psCommand}\"",
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };

                    using var proc = Process.Start(psi);
                    if (proc != null)
                    {
                        string output = proc.StandardOutput.ReadToEnd();
                        string error = proc.StandardError.ReadToEnd();
                        proc.WaitForExit();

                        if (output.Contains("RESTORE_POINT_SUCCESS"))
                        {
                            return (true, $"Sistem Geri Yükleme Noktası başarıyla oluşturuldu: '{safeDesc}'");
                        }
                        else
                        {
                            return (false, $"Geri yükleme noktası oluşturulamadı: {output} {error}".Trim());
                        }
                    }

                    return (false, "PowerShell işlemi başlatılamadı.");
                }
                catch (Exception ex)
                {
                    return (false, $"Geri yükleme hatası: {ex.Message}");
                }
            });
        }

        /// <summary>
        /// Belirtilen Kayıt Defteri yolunu .reg dosyası olarak dışa aktarır (Backup).
        /// </summary>
        public async Task<(bool Success, string FilePath, string Message)> BackupRegistryKeyAsync(string regPath, string label)
        {
            return await Task.Run(() =>
            {
                try
                {
                    if (string.IsNullOrWhiteSpace(regPath))
                        return (false, "", "Geçersiz kayıt defteri yolu.");

                    Directory.CreateDirectory(BackupDirectory);

                    string sanitizedLabel = string.Concat(label.Split(Path.GetInvalidFileNameChars())).Replace(" ", "_");
                    if (sanitizedLabel.Length > 30) sanitizedLabel = sanitizedLabel.Substring(0, 30);

                    string fileName = $"Reg_{DateTime.Now:yyyyMMdd_HHmmss}_{sanitizedLabel}.reg";
                    string destPath = Path.Combine(BackupDirectory, fileName);

                    // reg.exe export ile anahtarı dışa aktar
                    var psi = new ProcessStartInfo
                    {
                        FileName = "reg.exe",
                        Arguments = $"export \"{regPath}\" \"{destPath}\" /y",
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };

                    using var proc = Process.Start(psi);
                    if (proc != null)
                    {
                        proc.WaitForExit();
                        if (File.Exists(destPath) && new FileInfo(destPath).Length > 0)
                        {
                            return (true, destPath, $"Kayıt defteri yedeği alındı: {Path.GetFileName(destPath)}");
                        }
                    }

                    return (false, "", $"'{regPath}' anahtarı dışa aktarılamadı (anahtar mevcut olmayabilir).");
                }
                catch (Exception ex)
                {
                    return (false, "", $"Kayıt defteri yedekleme hatası: {ex.Message}");
                }
            });
        }

        /// <summary>
        /// .reg yedeğini sisteme geri yükler (import).
        /// </summary>
        public async Task<(bool Success, string Message)> RestoreRegistryBackupAsync(string regFilePath)
        {
            return await Task.Run(() =>
            {
                try
                {
                    if (!File.Exists(regFilePath))
                    {
                        return (false, "Yedek dosyası bulunamadı.");
                    }

                    var psi = new ProcessStartInfo
                    {
                        FileName = "reg.exe",
                        Arguments = $"import \"{regFilePath}\"",
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };

                    using var proc = Process.Start(psi);
                    if (proc != null)
                    {
                        proc.WaitForExit();
                        if (proc.ExitCode == 0)
                        {
                            return (true, $"Kayıt defteri yedeği başarıyla geri yüklendi: {Path.GetFileName(regFilePath)}");
                        }
                    }

                    return (false, "Kayıt defteri aktarımı başarısız oldu.");
                }
                catch (Exception ex)
                {
                    return (false, $"Geri yükleme hatası: {ex.Message}");
                }
            });
        }

        /// <summary>
        /// SysForge tarafından alınan son .reg yedek dosyalarını listeler.
        /// </summary>
        public List<FileInfo> GetRecentBackups()
        {
            try
            {
                if (!Directory.Exists(BackupDirectory)) return new List<FileInfo>();
                return new DirectoryInfo(BackupDirectory)
                    .GetFiles("*.reg")
                    .OrderByDescending(f => f.CreationTime)
                    .Take(20)
                    .ToList();
            }
            catch
            {
                return new List<FileInfo>();
            }
        }

        /// <summary>
        /// Windows Sistem Geri Yükleme Sihirbazı'nı (rstrui.exe) başlatır.
        /// </summary>
        public void LaunchSystemRestoreGui()
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "rstrui.exe",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Sistem geri yükleme sihirbazı başlatılamadı: {ex.Message}");
            }
        }

        /// <summary>
        /// Yedeklerin bulunduğu klasörü Windows Gezgini'nde açar.
        /// </summary>
        public void OpenBackupsFolder()
        {
            try
            {
                Directory.CreateDirectory(BackupDirectory);
                Process.Start(new ProcessStartInfo
                {
                    FileName = "explorer.exe",
                    Arguments = $"\"{BackupDirectory}\"",
                    UseShellExecute = true
                });
            }
            catch { }
        }
    }
}
