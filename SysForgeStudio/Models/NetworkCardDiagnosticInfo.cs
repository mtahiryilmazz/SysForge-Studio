using System;

namespace SysForgeStudio.Models
{
    public class NetworkCardDiagnosticInfo
    {
        public string Name { get; set; } = "";
        public string Manufacturer { get; set; } = "Bilinmiyor";
        public string DeviceID { get; set; } = "";
        public string HardwareID { get; set; } = "";
        public string AdapterType { get; set; } = "Ethernet / Wi-Fi";
        public string MACAddress { get; set; } = "";
        public uint ConfigManagerErrorCode { get; set; } = 0;
        public string Status { get; set; } = "Bilinmiyor";
        public bool IsDriverInstalled { get; set; } = true;
        public bool IsPhysical { get; set; } = true;
        public string StatusBadgeText { get; set; } = "🟢 Aktif";
        public string StatusBadgeColor { get; set; } = "#15803D"; // Green
        public string IPAddress { get; set; } = "Bağlı Değil";

        public bool NeedsDriverFix => !IsDriverInstalled || ConfigManagerErrorCode != 0 || Status.Equals("Error", StringComparison.OrdinalIgnoreCase);
    }
}
