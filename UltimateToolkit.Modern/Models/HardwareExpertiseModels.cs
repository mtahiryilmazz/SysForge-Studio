using System;
using System.Collections.Generic;

namespace UltimateToolkit.Modern.Models
{
    public class HardwareSnapshot
    {
        public DateTime Timestamp { get; set; } = DateTime.Now;
        public string MachineName { get; set; } = Environment.MachineName;
        public string GlobalHardwareHash { get; set; } = string.Empty;

        public MotherboardInfo Motherboard { get; set; } = new();
        public BiosInfo Bios { get; set; } = new();
        public ProcessorInfo Processor { get; set; } = new();
        public List<RamModuleInfo> RamModules { get; set; } = new();
        public List<DiskDriveInfo> Disks { get; set; } = new();
        public List<GpuInfo> Gpus { get; set; } = new();
        public List<NetworkCardInfo> NetworkCards { get; set; } = new();
    }

    public class MotherboardInfo
    {
        public string Manufacturer { get; set; } = "-";
        public string Product { get; set; } = "-";
        public string SerialNumber { get; set; } = "-";
    }

    public class BiosInfo
    {
        public string Manufacturer { get; set; } = "-";
        public string Version { get; set; } = "-";
        public string SerialNumber { get; set; } = "-";
        public string Uuid { get; set; } = "-";
    }

    public class ProcessorInfo
    {
        public string Name { get; set; } = "-";
        public string ProcessorId { get; set; } = "-";
        public int NumberOfCores { get; set; }
        public int NumberOfLogicalProcessors { get; set; }
    }

    public class RamModuleInfo
    {
        public string BankLabel { get; set; } = "-";
        public double CapacityGB { get; set; }
        public int SpeedMHz { get; set; }
        public string Manufacturer { get; set; } = "-";
        public string SerialNumber { get; set; } = "-";
        public string PartNumber { get; set; } = "-";
    }

    public class DiskDriveInfo
    {
        public string Model { get; set; } = "-";
        public string SerialNumber { get; set; } = "-";
        public double SizeGB { get; set; }
        public string InterfaceType { get; set; } = "-";
        public string MediaType { get; set; } = "-";
    }

    public class GpuInfo
    {
        public string Name { get; set; } = "-";
        public string DriverVersion { get; set; } = "-";
        public string VideoProcessor { get; set; } = "-";
        public double AdapterRamGB { get; set; }
    }

    public class NetworkCardInfo
    {
        public string Name { get; set; } = "-";
        public string MacAddress { get; set; } = "-";
        public string Speed { get; set; } = "-";
    }

    public enum HardwareChangeType
    {
        Added,
        Removed,
        Modified
    }

    public class HardwareDifference
    {
        public string Component { get; set; } = "";
        public HardwareChangeType ChangeType { get; set; }
        public string Description { get; set; } = "";
        public string OldValue { get; set; } = "";
        public string NewValue { get; set; } = "";
    }

    public class HardwareComparisonResult
    {
        public bool IsIdentical => Differences.Count == 0;
        public DateTime BaselineDate { get; set; }
        public DateTime CurrentDate { get; set; }
        public string BaselineHash { get; set; } = "";
        public string CurrentHash { get; set; } = "";
        public List<HardwareDifference> Differences { get; set; } = new();
    }
}
