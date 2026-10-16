using System;

namespace UltimateToolkit.Modern.Models
{
    public class TicketItem
    {
        public int Id { get; set; }
        public string Department { get; set; } = "-";
        public string PersonnelName { get; set; } = "-";
        public string InternalNumber { get; set; } = "-";
        public string IssueType { get; set; } = "Genel Sorun";
        public string Priority { get; set; } = "Normal";
        public string Description { get; set; } = "";
        public string Date { get; set; } = DateTime.Now.ToString("yyyy-MM-dd HH:mm");
        public string Status { get; set; } = "Açık";
    }

    public class InventoryItem
    {
        public int Id { get; set; }
        public string Brand { get; set; } = "-";
        public string Model { get; set; } = "-";
        public string SerialNo { get; set; } = "-";
        public string IpAddress { get; set; } = "-";
        public string Location { get; set; } = "-";
        public string UserName { get; set; } = "-";
        public string Date { get; set; } = DateTime.Now.ToString("yyyy-MM-dd");
    }

    public class ITLogItem
    {
        public int Id { get; set; }
        public string UserInfo { get; set; } = Environment.UserName;
        public string Timestamp { get; set; } = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
        public string ActionType { get; set; } = "İŞLEM";
        public string Result { get; set; } = "";
    }
}