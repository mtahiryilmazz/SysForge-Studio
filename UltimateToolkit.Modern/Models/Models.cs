using System;
using System.Collections.Generic;

namespace UltimateToolkit.Modern.Models
{
    public class PrinterItem
    {
        public string Name { get; set; } = string.Empty;
        public string ShareName { get; set; } = string.Empty;
        public string DriverName { get; set; } = string.Empty;
        public string PortName { get; set; } = string.Empty;
        public string Status { get; set; } = "Bilinmiyor";
        public bool IsDefault { get; set; }
        public bool IsNetwork { get; set; }
        public bool IsShared { get; set; }
        public string Location { get; set; } = string.Empty;
    }

    public class DiagItem
    {
        public string Category { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Status { get; set; } = "OK"; // OK, WARN, ERR
        public string Details { get; set; } = string.Empty;
        public string Recommendation { get; set; } = string.Empty;
    }

    public class DriverItem
    {
        public string Name { get; set; } = string.Empty;
        public string Manufacturer { get; set; } = string.Empty;
        public string Architecture { get; set; } = "x64";
        public string Version { get; set; } = string.Empty;
        public string DriverPath { get; set; } = string.Empty;
    }

    public enum LogLevel
    {
        Info,
        Success,
        Warning,
        Error
    }

    public class LogEntry
    {
        public DateTime Timestamp { get; set; } = DateTime.Now;
        public LogLevel Level { get; set; } = LogLevel.Info;
        public string Message { get; set; } = string.Empty;
        public string FormattedTime => Timestamp.ToString("HH:mm:ss");
    }

    public class BackupItem
    {
        public string FileName { get; set; } = string.Empty;
        public string FullPath { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public string SizeDisplay { get; set; } = string.Empty;
    }

    // ============================================================
    // NEW MODELS: Network, Remote Desktop, System, Services
    // ============================================================

    public class NetworkAdapterInfo
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string IPAddress { get; set; } = string.Empty;
        public string SubnetMask { get; set; } = string.Empty;
        public string Gateway { get; set; } = string.Empty;
        public string DnsServers { get; set; } = string.Empty;
        public string MacAddress { get; set; } = string.Empty;
        public string Speed { get; set; } = string.Empty;
        public string Status { get; set; } = "Bilinmiyor";
        public string NetworkPrefix { get; set; } = string.Empty;
        public bool IsDhcp { get; set; }
    }

    public class NetworkHostInfo : System.ComponentModel.INotifyPropertyChanged
    {
        private string _macAddress = "-";
        private string _vendor = "Bilinmiyor";
        private string _deviceType = "Diğer Cihaz";
        private string _deviceIcon = "❓";

        public string IPAddress { get; set; } = string.Empty;
        public string Hostname { get; set; } = string.Empty;
        public int PingMs { get; set; } = -1;
        public string Status { get; set; } = "Bilinmiyor";

        public string MacAddress
        {
            get => _macAddress;
            set { _macAddress = value; OnPropertyChanged(nameof(MacAddress)); }
        }

        public string Vendor
        {
            get => _vendor;
            set { _vendor = value; OnPropertyChanged(nameof(Vendor)); }
        }

        public string DeviceType
        {
            get => _deviceType;
            set
            {
                if (_deviceType != value)
                {
                    _deviceType = value ?? "Diğer Cihaz";
                    UpdateIcon();
                    OnPropertyChanged(nameof(DeviceType));
                    OnPropertyChanged(nameof(DeviceIcon));
                }
            }
        }

        public string DeviceIcon
        {
            get => _deviceIcon;
            set { _deviceIcon = value; OnPropertyChanged(nameof(DeviceIcon)); }
        }

        public string OpenPorts { get; set; } = string.Empty;
        public string OsGuess { get; set; } = "-";
        public int Ttl { get; set; } = -1;
        public bool HasRDP { get; set; }
        public bool HasSMB { get; set; }
        public bool HasHTTP { get; set; }
        public bool HasPrinter { get; set; }
        public bool HasSip { get; set; }
        public bool HasSsh { get; set; }
        public bool HasMacAfp { get; set; }

        public static readonly List<string> AvailableDeviceTypes = new()
        {
            "IP Telefon (Yealink)",
            "IP Telefon / VoIP",
            "Sunucu (Server)",
            "Windows PC",
            "Windows 11 PC",
            "Windows 10 PC",
            "Apple Mac / MacBook",
            "Linux / Sunucu",
            "Akıllı Telefon / Mobil",
            "Ağ Yazıcısı",
            "NAS Depolama",
            "Modem / Router / Switch",
            "Ağ Cihazı / Router",
            "Diğer Cihaz"
        };

        public void UpdateIcon()
        {
            if (string.IsNullOrEmpty(_deviceType))
            {
                _deviceIcon = "❓";
                return;
            }
            string lower = _deviceType.ToLowerInvariant();
            if (lower.Contains("yealink") || (lower.Contains("telefon") && lower.Contains("ip")) || lower.Contains("voip"))
                _deviceIcon = "☎️";
            else if (lower.Contains("nas"))
                _deviceIcon = "🗄️";
            else if (lower.Contains("mac") || lower.Contains("apple"))
                _deviceIcon = "🍎";
            else if (lower.Contains("linux"))
                _deviceIcon = "🐧";
            else if (lower.Contains("sunucu") || lower.Contains("server"))
                _deviceIcon = "🖧";
            else if (lower.Contains("windows"))
                _deviceIcon = "💻";
            else if (lower.Contains("mobil") || lower.Contains("akıllı telefon") || lower.Contains("android") || lower.Contains("iot"))
                _deviceIcon = "📱";
            else if (lower.Contains("yazıcı") || lower.Contains("printer"))
                _deviceIcon = "🖨️";
            else if (lower.Contains("router") || lower.Contains("modem") || lower.Contains("switch") || lower.Contains("ağ cihazı") || lower.Contains("firewall"))
                _deviceIcon = "🌐";
            else
                _deviceIcon = "❓";
        }

        public event System.ComponentModel.PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged(string propName) =>
            PropertyChanged?.Invoke(this, new System.ComponentModel.PropertyChangedEventArgs(propName));
    }

    public class RdpConnection
    {
        public string DisplayName { get; set; } = string.Empty;
        public string Hostname { get; set; } = string.Empty;
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public int Port { get; set; } = 3389;
        public bool FullScreen { get; set; } = true;
        public string Resolution { get; set; } = "Tam Ekran";
        public DateTime LastUsed { get; set; } = DateTime.Now;
        public string StatusIcon => "🖥️";
    }

    public class ServiceItem
    {
        public string ServiceName { get; set; } = string.Empty;
        public string DisplayName { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public string StartType { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Account { get; set; } = string.Empty;
    }

    public class SystemRepairAction
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Icon { get; set; } = "🔧";
        public string Category { get; set; } = string.Empty;
        public bool IsRecommended { get; set; }
        public bool IsSelected { get; set; }
        public string Command { get; set; } = string.Empty;
    }

    public class PerformanceMetric
    {
        public string Name { get; set; } = string.Empty;
        public string Value { get; set; } = string.Empty;
        public string Unit { get; set; } = string.Empty;
        public double Percentage { get; set; }
        public string Status { get; set; } = "Normal";
    }

    public class LegacyModule
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Icon { get; set; } = "📦";
        public string LaunchLabel { get; set; } = string.Empty;
        public string ScriptPath { get; set; } = string.Empty;
        public string Arguments { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
    }

    public enum ActionType
    {
        PowerShell,
        Cmd,
        Process,
        Internal
    }

    public class ModuleAction
    {
        public string Id { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Icon { get; set; } = "⚡";
        public string Command { get; set; } = string.Empty;
        public ActionType Type { get; set; } = ActionType.PowerShell;
        public string Badge { get; set; } = string.Empty;
        public string Status { get; set; } = "Hazır";
        public bool IsElevated { get; set; } = true;
    }

    public class ModuleCategory
    {
        public string Id { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Icon { get; set; } = "⚙️";
        public string Group { get; set; } = "Genel";
        public List<ModuleAction> Actions { get; set; } = new();
        public int ActionCount => Actions.Count;
    }
}
