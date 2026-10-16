using System;
using System.Collections.Generic;

namespace SysForgeStudio.Models
{
    public class DepartmentItem
    {
        public int Id { get; set; }
        public string Name { get; set; } = "";
        public List<UnitItem> Units { get; set; } = new();
    }

    public class UnitItem
    {
        public int Id { get; set; }
        public int DepartmentId { get; set; }
        public string Name { get; set; } = "";
    }

    public class TicketItem
    {
        public int Id { get; set; }
        public string Department { get; set; } = "-";
        public string Unit { get; set; } = "-";
        public string PersonnelName { get; set; } = "-";
        public string InternalNumber { get; set; } = "-";
        public string IssueType { get; set; } = "Genel Sorun";
        public string Priority { get; set; } = "Normal";
        public string Description { get; set; } = "";
        public string Date { get; set; } = DateTime.Now.ToString("yyyy-MM-dd HH:mm");
        public string Status { get; set; } = "Açık";
        public string ResolutionNote { get; set; } = "";
        public bool HasResolutionNote => !string.IsNullOrWhiteSpace(ResolutionNote);
    }

    public class InventoryItem
    {
        public int Id { get; set; }
        public string Brand { get; set; } = "-";
        public string Model { get; set; } = "-";
        public string SerialNo { get; set; } = "-";
        public string Motherboard { get; set; } = "-";
        public string Processor { get; set; } = "-";
        public string Ram { get; set; } = "-";
        public string Disk { get; set; } = "-";
        public string Gpu { get; set; } = "-";
        public string OsVersion { get; set; } = "-";
        public string MacAddress { get; set; } = "-";
        public string IpAddress { get; set; } = "-";
        public string Department { get; set; } = "-";
        public string Unit { get; set; } = "-";
        public string Location { get; set; } = "-";
        public string UserName { get; set; } = "-";
        public string Date { get; set; } = DateTime.Now.ToString("yyyy-MM-dd");

        // Helper getters for clean display
        public string DisplayMotherboard => string.IsNullOrWhiteSpace(Motherboard) || Motherboard == "-" ? "Belirtilmedi" : Motherboard;
        public string DisplayProcessor => string.IsNullOrWhiteSpace(Processor) || Processor == "-" ? "Belirtilmedi" : Processor;
        public string DisplayRam => string.IsNullOrWhiteSpace(Ram) || Ram == "-" ? "Belirtilmedi" : Ram;
        public string DisplayDisk => string.IsNullOrWhiteSpace(Disk) || Disk == "-" ? "Belirtilmedi" : Disk;
        public string DisplayGpu => string.IsNullOrWhiteSpace(Gpu) || Gpu == "-" ? "Belirtilmedi" : Gpu;
        public string DisplayOsVersion => string.IsNullOrWhiteSpace(OsVersion) || OsVersion == "-" ? "Belirtilmedi" : OsVersion;
        public string DisplayMacAddress => string.IsNullOrWhiteSpace(MacAddress) || MacAddress == "-" ? "Belirtilmedi" : MacAddress;
    }

    public class ITLogItem
    {
        public int Id { get; set; }
        public string UserInfo { get; set; } = Environment.UserName;
        public string Timestamp { get; set; } = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
        public string ActionType { get; set; } = "İŞLEM";
        public string Result { get; set; } = "";
    }

    public class AISolutionAlternative
    {
        public string Title { get; set; } = "";
        public string Description { get; set; } = "";
        public string Script { get; set; } = "";
        public string Category { get; set; } = "Genel";
    }

    public class AISolutionResult
    {
        public string Title { get; set; } = "";
        public string Category { get; set; } = "Genel Sistem";
        public string RootCause { get; set; } = "";
        public string Severity { get; set; } = "Orta";
        public List<string> Steps { get; set; } = new();
        public string AutoFixScript { get; set; } = "";
        public bool HasScript => !string.IsNullOrWhiteSpace(AutoFixScript);
        public string WebInsights { get; set; } = "";
        public bool HasWebInsights => !string.IsNullOrWhiteSpace(WebInsights);
        public List<AISolutionAlternative> Alternatives { get; set; } = new();
        public bool HasAlternatives => Alternatives != null && Alternatives.Count > 0;
        public string TargetRegistryBackupPath { get; set; } = "";
    }
}