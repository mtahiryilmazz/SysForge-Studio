using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using UltimateToolkit.Modern.Models;

namespace UltimateToolkit.Modern.Services
{
    public class HardwareExpertiseService
    {
        public static HardwareExpertiseService Instance { get; } = new HardwareExpertiseService();

        public string BaseDirectory { get; }
        public string SnapshotsDirectory { get; }
        public string ReportsDirectory { get; }
        public string BaselineFilePath { get; }

        public HardwareExpertiseService()
        {
            string desktop = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
            BaseDirectory = Path.Combine(desktop, "EkspertizArsivi");
            SnapshotsDirectory = Path.Combine(BaseDirectory, "Snapshots");
            ReportsDirectory = Path.Combine(BaseDirectory, "Raporlar");
            BaselineFilePath = Path.Combine(SnapshotsDirectory, "baseline_hardware.json");

            try
            {
                Directory.CreateDirectory(BaseDirectory);
                Directory.CreateDirectory(SnapshotsDirectory);
                Directory.CreateDirectory(ReportsDirectory);
            }
            catch { }
        }

        public async Task<HardwareSnapshot> CaptureSnapshotAsync()
        {
            return await Task.Run(() =>
            {
                var snapshot = new HardwareSnapshot
                {
                    Timestamp = DateTime.Now,
                    MachineName = Environment.MachineName
                };

                // 1. Motherboard
                try
                {
                    using var searcher = new ManagementObjectSearcher("SELECT Manufacturer, Product, SerialNumber FROM Win32_BaseBoard");
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        snapshot.Motherboard.Manufacturer = obj["Manufacturer"]?.ToString()?.Trim() ?? "-";
                        snapshot.Motherboard.Product = obj["Product"]?.ToString()?.Trim() ?? "-";
                        snapshot.Motherboard.SerialNumber = obj["SerialNumber"]?.ToString()?.Trim() ?? "-";
                        break;
                    }
                }
                catch { }

                // 2. BIOS & System UUID
                try
                {
                    using var searcher = new ManagementObjectSearcher("SELECT Manufacturer, Version, SerialNumber FROM Win32_BIOS");
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        snapshot.Bios.Manufacturer = obj["Manufacturer"]?.ToString()?.Trim() ?? "-";
                        snapshot.Bios.Version = obj["Version"]?.ToString()?.Trim() ?? "-";
                        snapshot.Bios.SerialNumber = obj["SerialNumber"]?.ToString()?.Trim() ?? "-";
                        break;
                    }

                    using var cspSearcher = new ManagementObjectSearcher("SELECT UUID FROM Win32_ComputerSystemProduct");
                    foreach (ManagementObject obj in cspSearcher.Get())
                    {
                        snapshot.Bios.Uuid = obj["UUID"]?.ToString()?.Trim() ?? "-";
                        break;
                    }
                }
                catch { }

                // 3. CPU
                try
                {
                    using var searcher = new ManagementObjectSearcher("SELECT Name, ProcessorId, NumberOfCores, NumberOfLogicalProcessors FROM Win32_Processor");
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        snapshot.Processor.Name = obj["Name"]?.ToString()?.Trim() ?? "-";
                        snapshot.Processor.ProcessorId = obj["ProcessorId"]?.ToString()?.Trim() ?? "-";
                        snapshot.Processor.NumberOfCores = Convert.ToInt32(obj["NumberOfCores"] ?? 0);
                        snapshot.Processor.NumberOfLogicalProcessors = Convert.ToInt32(obj["NumberOfLogicalProcessors"] ?? 0);
                        break;
                    }
                }
                catch { }

                // 4. RAM Modules
                try
                {
                    using var searcher = new ManagementObjectSearcher("SELECT BankLabel, Capacity, Speed, Manufacturer, SerialNumber, PartNumber FROM Win32_PhysicalMemory");
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        double capacityGb = Math.Round(Convert.ToDouble(obj["Capacity"] ?? 0) / (1024 * 1024 * 1024), 2);
                        snapshot.RamModules.Add(new RamModuleInfo
                        {
                            BankLabel = obj["BankLabel"]?.ToString()?.Trim() ?? "-",
                            CapacityGB = capacityGb,
                            SpeedMHz = Convert.ToInt32(obj["Speed"] ?? 0),
                            Manufacturer = obj["Manufacturer"]?.ToString()?.Trim() ?? "-",
                            SerialNumber = obj["SerialNumber"]?.ToString()?.Trim() ?? "-",
                            PartNumber = obj["PartNumber"]?.ToString()?.Trim() ?? "-"
                        });
                    }
                }
                catch { }

                // 5. Disks
                try
                {
                    using var searcher = new ManagementObjectSearcher("SELECT Model, SerialNumber, Size, InterfaceType, MediaType FROM Win32_DiskDrive");
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        double sizeGb = Math.Round(Convert.ToDouble(obj["Size"] ?? 0) / (1024 * 1024 * 1024), 2);
                        snapshot.Disks.Add(new DiskDriveInfo
                        {
                            Model = obj["Model"]?.ToString()?.Trim() ?? "-",
                            SerialNumber = obj["SerialNumber"]?.ToString()?.Trim() ?? "-",
                            SizeGB = sizeGb,
                            InterfaceType = obj["InterfaceType"]?.ToString()?.Trim() ?? "-",
                            MediaType = obj["MediaType"]?.ToString()?.Trim() ?? "-"
                        });
                    }
                }
                catch { }

                // 6. GPU
                try
                {
                    using var searcher = new ManagementObjectSearcher("SELECT Name, DriverVersion, VideoProcessor, AdapterRAM FROM Win32_VideoController");
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        double ramGb = Math.Round(Convert.ToDouble(obj["AdapterRAM"] ?? 0) / (1024 * 1024 * 1024), 2);
                        snapshot.Gpus.Add(new GpuInfo
                        {
                            Name = obj["Name"]?.ToString()?.Trim() ?? "-",
                            DriverVersion = obj["DriverVersion"]?.ToString()?.Trim() ?? "-",
                            VideoProcessor = obj["VideoProcessor"]?.ToString()?.Trim() ?? "-",
                            AdapterRamGB = ramGb
                        });
                    }
                }
                catch { }

                // 7. Network Cards
                try
                {
                    using var searcher = new ManagementObjectSearcher("SELECT Name, MACAddress, Speed FROM Win32_NetworkAdapter WHERE MACAddress IS NOT NULL AND PhysicalAdapter = TRUE");
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        snapshot.NetworkCards.Add(new NetworkCardInfo
                        {
                            Name = obj["Name"]?.ToString()?.Trim() ?? "-",
                            MacAddress = obj["MACAddress"]?.ToString()?.Trim() ?? "-",
                            Speed = obj["Speed"]?.ToString()?.Trim() ?? "-"
                        });
                    }
                }
                catch { }

                // Compute Fingerprint Hash
                snapshot.GlobalHardwareHash = ComputeHardwareHash(snapshot);

                return snapshot;
            });
        }

        public string ComputeHardwareHash(HardwareSnapshot snapshot)
        {
            var sb = new StringBuilder();
            sb.Append(snapshot.Motherboard.SerialNumber);
            sb.Append('|').Append(snapshot.Bios.Uuid);
            sb.Append('|').Append(snapshot.Processor.ProcessorId);

            foreach (var ram in snapshot.RamModules.OrderBy(r => r.BankLabel).ThenBy(r => r.SerialNumber))
            {
                sb.Append('|').Append(ram.Manufacturer).Append(':').Append(ram.SerialNumber).Append(':').Append(ram.CapacityGB);
            }

            foreach (var disk in snapshot.Disks.OrderBy(d => d.SerialNumber))
            {
                sb.Append('|').Append(disk.Model).Append(':').Append(disk.SerialNumber);
            }

            foreach (var gpu in snapshot.Gpus.OrderBy(g => g.Name))
            {
                sb.Append('|').Append(gpu.Name);
            }

            foreach (var net in snapshot.NetworkCards.OrderBy(n => n.MacAddress))
            {
                sb.Append('|').Append(net.MacAddress);
            }

            using var sha = SHA256.Create();
            byte[] bytes = Encoding.UTF8.GetBytes(sb.ToString());
            byte[] hash = sha.ComputeHash(bytes);
            return BitConverter.ToString(hash).Replace("-", "").ToUpperInvariant();
        }

        public async Task SaveBaselineAsync(HardwareSnapshot snapshot)
        {
            string json = JsonSerializer.Serialize(snapshot, new JsonSerializerOptions { WriteIndented = true });
            await File.WriteAllTextAsync(BaselineFilePath, json, Encoding.UTF8);

            // Also save a timestamped archive copy
            string archiveFile = Path.Combine(SnapshotsDirectory, $"Snapshot_{DateTime.Now:yyyyMMdd_HHmmss}.json");
            await File.WriteAllTextAsync(archiveFile, json, Encoding.UTF8);
        }

        public async Task<HardwareSnapshot?> LoadBaselineAsync()
        {
            if (!File.Exists(BaselineFilePath)) return null;
            string json = await File.ReadAllTextAsync(BaselineFilePath, Encoding.UTF8);
            return JsonSerializer.Deserialize<HardwareSnapshot>(json);
        }

        public HardwareComparisonResult CompareSnapshots(HardwareSnapshot baseline, HardwareSnapshot current)
        {
            var result = new HardwareComparisonResult
            {
                BaselineDate = baseline.Timestamp,
                CurrentDate = current.Timestamp,
                BaselineHash = baseline.GlobalHardwareHash,
                CurrentHash = current.GlobalHardwareHash
            };

            // 1. Motherboard
            if (baseline.Motherboard.SerialNumber != current.Motherboard.SerialNumber)
            {
                result.Differences.Add(new HardwareDifference
                {
                    Component = "Anakart",
                    ChangeType = HardwareChangeType.Modified,
                    Description = "Anakart seri numarası değişti!",
                    OldValue = baseline.Motherboard.SerialNumber,
                    NewValue = current.Motherboard.SerialNumber
                });
            }

            // 2. BIOS / UUID
            if (baseline.Bios.Uuid != current.Bios.Uuid)
            {
                result.Differences.Add(new HardwareDifference
                {
                    Component = "BIOS / Kasa UUID",
                    ChangeType = HardwareChangeType.Modified,
                    Description = "Sistem UUID kimliği değişti!",
                    OldValue = baseline.Bios.Uuid,
                    NewValue = current.Bios.Uuid
                });
            }

            // 3. CPU
            if (baseline.Processor.ProcessorId != current.Processor.ProcessorId || baseline.Processor.Name != current.Processor.Name)
            {
                result.Differences.Add(new HardwareDifference
                {
                    Component = "İşlemci (CPU)",
                    ChangeType = HardwareChangeType.Modified,
                    Description = "İşlemci modeli veya donanım ID değişti!",
                    OldValue = $"{baseline.Processor.Name} (ID: {baseline.Processor.ProcessorId})",
                    NewValue = $"{current.Processor.Name} (ID: {current.Processor.ProcessorId})"
                });
            }

            // 4. RAM
            var oldRamSerials = baseline.RamModules.Select(r => r.SerialNumber).Where(s => s != "-" && !string.IsNullOrWhiteSpace(s)).ToHashSet();
            var newRamSerials = current.RamModules.Select(r => r.SerialNumber).Where(s => s != "-" && !string.IsNullOrWhiteSpace(s)).ToHashSet();

            foreach (var r in baseline.RamModules)
            {
                if (!string.IsNullOrWhiteSpace(r.SerialNumber) && r.SerialNumber != "-" && !newRamSerials.Contains(r.SerialNumber))
                {
                    result.Differences.Add(new HardwareDifference
                    {
                        Component = "Bellek (RAM)",
                        ChangeType = HardwareChangeType.Removed,
                        Description = $"RAM modülü söküldü veya eksildi: {r.BankLabel} ({r.CapacityGB} GB, {r.Manufacturer})",
                        OldValue = $"Seri No: {r.SerialNumber}",
                        NewValue = "[Söküldü / Bulunamadı]"
                    });
                }
            }

            foreach (var r in current.RamModules)
            {
                if (!string.IsNullOrWhiteSpace(r.SerialNumber) && r.SerialNumber != "-" && !oldRamSerials.Contains(r.SerialNumber))
                {
                    result.Differences.Add(new HardwareDifference
                    {
                        Component = "Bellek (RAM)",
                        ChangeType = HardwareChangeType.Added,
                        Description = $"Yeni RAM modülü takıldı: {r.BankLabel} ({r.CapacityGB} GB, {r.Manufacturer})",
                        OldValue = "[Yoktu]",
                        NewValue = $"Seri No: {r.SerialNumber}"
                    });
                }
            }

            // Total RAM check
            double oldTotalRam = baseline.RamModules.Sum(r => r.CapacityGB);
            double newTotalRam = current.RamModules.Sum(r => r.CapacityGB);
            if (Math.Abs(oldTotalRam - newTotalRam) > 0.5 && result.Differences.All(d => d.Component != "Bellek (RAM)"))
            {
                result.Differences.Add(new HardwareDifference
                {
                    Component = "Bellek (RAM)",
                    ChangeType = HardwareChangeType.Modified,
                    Description = $"Toplam RAM boyutu değişti!",
                    OldValue = $"{oldTotalRam} GB",
                    NewValue = $"{newTotalRam} GB"
                });
            }

            // 5. Disks
            var oldDisks = baseline.Disks.Select(d => d.SerialNumber).ToHashSet();
            var newDisks = current.Disks.Select(d => d.SerialNumber).ToHashSet();

            foreach (var d in baseline.Disks)
            {
                if (!newDisks.Contains(d.SerialNumber))
                {
                    result.Differences.Add(new HardwareDifference
                    {
                        Component = "Depolama (Disk)",
                        ChangeType = HardwareChangeType.Removed,
                        Description = $"Disk söküldü veya değiştirildi: {d.Model} ({d.SizeGB} GB)",
                        OldValue = $"Seri No: {d.SerialNumber}",
                        NewValue = "[Mevcut Değil]"
                    });
                }
            }

            foreach (var d in current.Disks)
            {
                if (!oldDisks.Contains(d.SerialNumber))
                {
                    result.Differences.Add(new HardwareDifference
                    {
                        Component = "Depolama (Disk)",
                        ChangeType = HardwareChangeType.Added,
                        Description = $"Yeni disk algılandı: {d.Model} ({d.SizeGB} GB)",
                        OldValue = "[Yoktu]",
                        NewValue = $"Seri No: {d.SerialNumber}"
                    });
                }
            }

            // 6. GPU
            var oldGpuNames = string.Join(", ", baseline.Gpus.Select(g => g.Name));
            var newGpuNames = string.Join(", ", current.Gpus.Select(g => g.Name));
            if (oldGpuNames != newGpuNames)
            {
                result.Differences.Add(new HardwareDifference
                {
                    Component = "Ekran Kartı (GPU)",
                    ChangeType = HardwareChangeType.Modified,
                    Description = "Ekran kartı konfigürasyonu değişti!",
                    OldValue = oldGpuNames,
                    NewValue = newGpuNames
                });
            }

            return result;
        }

        public async Task<string> GenerateHtmlReportAsync(HardwareSnapshot current, HardwareComparisonResult? compare = null)
        {
            string reportFile = Path.Combine(ReportsDirectory, $"EkspertizRaporu_{DateTime.Now:yyyyMMdd_HHmmss}.html");

            var sb = new StringBuilder();
            sb.AppendLine("<!DOCTYPE html><html lang='tr'><head><meta charset='utf-8'/><title>Donanım Ekspertiz Raporu</title>");
            sb.AppendLine("<style>");
            sb.AppendLine("body { font-family: 'Segoe UI', Tahoma, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 24px; }");
            sb.AppendLine(".container { max-width: 900px; margin: auto; background: #1e293b; border-radius: 12px; padding: 32px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }");
            sb.AppendLine("h1 { color: #38bdf8; margin-top: 0; border-bottom: 2px solid #334155; padding-bottom: 12px; }");
            sb.AppendLine(".badge { display: inline-block; padding: 4px 12px; border-radius: 6px; font-weight: bold; font-size: 14px; }");
            sb.AppendLine(".badge-success { background: #15803d; color: #fff; }");
            sb.AppendLine(".badge-danger { background: #b91c1c; color: #fff; }");
            sb.AppendLine("table { width: 100%; border-collapse: collapse; margin-top: 16px; margin-bottom: 24px; }");
            sb.AppendLine("th, td { padding: 10px 14px; text-align: left; border-bottom: 1px solid #334155; }");
            sb.AppendLine("th { background: #0f172a; color: #94a3b8; font-size: 13px; text-transform: uppercase; }");
            sb.AppendLine(".hash-box { background: #0f172a; border-left: 4px solid #38bdf8; padding: 12px 16px; font-family: monospace; font-size: 13px; word-break: break-all; margin: 16px 0; border-radius: 4px; }");
            sb.AppendLine("</style></head><body><div class='container'>");

            sb.AppendLine($"<h1>🛠️ Donanım Ekspertiz & Kimlik Doğrulama Raporu</h1>");
            sb.AppendLine($"<p><strong>Cihaz Adı:</strong> {current.MachineName} | <strong>Tarih:</strong> {current.Timestamp:yyyy-MM-dd HH:mm:ss}</p>");
            sb.AppendLine($"<div class='hash-box'><strong>Donanım Bütünlük Hash (SHA-256):</strong><br/>{current.GlobalHardwareHash}</div>");

            if (compare != null)
            {
                sb.AppendLine("<h2>🔍 Referans Kıyaslama Durumu</h2>");
                if (compare.IsIdentical)
                {
                    sb.AppendLine("<p><span class='badge badge-success'>✓ BÜTÜNLÜK TAM: Cihaz donanımlarında hiçbir değişiklik yok, orijinal referans ile birebir eşleşiyor.</span></p>");
                }
                else
                {
                    sb.AppendLine("<p><span class='badge badge-danger'>⚠️ DİKKAT: Cihaz üzerinde değişiklik tespit edildi!</span></p>");
                    sb.AppendLine("<table><tr><th>Bileşen</th><th>İşlem</th><th>Açıklama</th><th>Önceki Değer</th><th>Yeni Değer</th></tr>");
                    foreach (var diff in compare.Differences)
                    {
                        sb.AppendLine($"<tr><td><strong>{diff.Component}</strong></td><td>{diff.ChangeType}</td><td>{diff.Description}</td><td>{diff.OldValue}</td><td>{diff.NewValue}</td></tr>");
                    }
                    sb.AppendLine("</table>");
                }
            }

            sb.AppendLine("<h2>💻 Mevcut Donanım Envanteri</h2>");
            sb.AppendLine("<table><tr><th>Bileşen</th><th>Detaylar</th><th>Seri Numarası / Kimlik</th></tr>");
            sb.AppendLine($"<tr><td>Anakart</td><td>{current.Motherboard.Manufacturer} - {current.Motherboard.Product}</td><td><code>{current.Motherboard.SerialNumber}</code></td></tr>");
            sb.AppendLine($"<tr><td>BIOS / UUID</td><td>{current.Bios.Manufacturer} {current.Bios.Version}</td><td><code>{current.Bios.Uuid}</code></td></tr>");
            sb.AppendLine($"<tr><td>İşlemci</td><td>{current.Processor.Name} ({current.Processor.NumberOfCores} Çekirdek)</td><td><code>{current.Processor.ProcessorId}</code></td></tr>");

            foreach (var r in current.RamModules)
            {
                sb.AppendLine($"<tr><td>RAM ({r.BankLabel})</td><td>{r.CapacityGB} GB {r.Manufacturer} ({r.SpeedMHz} MHz)</td><td><code>{r.SerialNumber}</code> ({r.PartNumber})</td></tr>");
            }

            foreach (var d in current.Disks)
            {
                sb.AppendLine($"<tr><td>Disk</td><td>{d.Model} ({d.SizeGB} GB, {d.InterfaceType})</td><td><code>{d.SerialNumber}</code></td></tr>");
            }

            foreach (var g in current.Gpus)
            {
                sb.AppendLine($"<tr><td>Ekran Kartı</td><td>{g.Name} ({g.AdapterRamGB} GB)</td><td>Sürücü: {g.DriverVersion}</td></tr>");
            }

            foreach (var n in current.NetworkCards)
            {
                sb.AppendLine($"<tr><td>Ağ Kartı</td><td>{n.Name}</td><td>MAC: <code>{n.MacAddress}</code></td></tr>");
            }
            sb.AppendLine("</table>");

            sb.AppendLine("<p style='font-size:12px; color:#64748b; text-align:center; margin-top:30px;'>Bu rapor Ultimate Enterprise Toolkit Donanım Ekspertiz Motoru tarafından üretilmiştir.</p>");
            sb.AppendLine("</div></body></html>");

            await File.WriteAllTextAsync(reportFile, sb.ToString(), Encoding.UTF8);
            return reportFile;
        }
    }
}
