using System;
using System.Collections.Generic;
using System.IO;
using System.Management;
using System.Net;
using System.Net.Sockets;
using Microsoft.Data.Sqlite;
using UltimateToolkit.Modern.Models;

namespace UltimateToolkit.Modern.Services
{
    public class ITServiceDatabase
    {
        public static ITServiceDatabase Instance { get; } = new ITServiceDatabase();

        public string DbPath { get; }
        private readonly string _connectionString;

        public ITServiceDatabase()
        {
            string appData = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "SysForgeStudio");
            try { Directory.CreateDirectory(appData); } catch { }

            DbPath = Path.Combine(appData, "sysforge_it.db");
            _connectionString = $"Data Source={DbPath};";

            InitializeDatabase();
        }

        private void InitializeDatabase()
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            string schema = @"
                CREATE TABLE IF NOT EXISTS tickets (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    department TEXT,
                    personnel_name TEXT,
                    internal_number TEXT,
                    issue_type TEXT,
                    priority TEXT,
                    description TEXT,
                    date TEXT,
                    status TEXT DEFAULT 'Açık'
                );

                CREATE TABLE IF NOT EXISTS inventory (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    brand TEXT,
                    model TEXT,
                    serial_no TEXT UNIQUE,
                    ip_address TEXT,
                    location TEXT,
                    user_name TEXT,
                    date TEXT
                );

                CREATE TABLE IF NOT EXISTS logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_info TEXT,
                    timestamp TEXT,
                    action_type TEXT,
                    result TEXT
                );
            ";

            using var cmd = new SqliteCommand(schema, conn);
            cmd.ExecuteNonQuery();

            // Insert sample ticket if empty
            using var countCmd = new SqliteCommand("SELECT COUNT(*) FROM tickets;", conn);
            long count = (long)(countCmd.ExecuteScalar() ?? 0);
            if (count == 0)
            {
                using var insertSample = new SqliteCommand(@"
                    INSERT INTO tickets (department, personnel_name, internal_number, issue_type, priority, description, date, status)
                    VALUES ('Bilgi İşlem', 'Sistem Yöneticisi', '101', 'Sistem Kurulumu', 'Normal', 'SysForge Studio kurulumu tamamlandı ve aktif edildi.', datetime('now', 'localtime'), 'Çözüldü');
                ", conn);
                insertSample.ExecuteNonQuery();
            }
        }

        public List<TicketItem> GetTickets()
        {
            var list = new List<TicketItem>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand("SELECT id, department, personnel_name, internal_number, issue_type, priority, description, date, status FROM tickets ORDER BY id DESC;", conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new TicketItem
                {
                    Id = reader.GetInt32(0),
                    Department = reader.IsDBNull(1) ? "-" : reader.GetString(1),
                    PersonnelName = reader.IsDBNull(2) ? "-" : reader.GetString(2),
                    InternalNumber = reader.IsDBNull(3) ? "-" : reader.GetString(3),
                    IssueType = reader.IsDBNull(4) ? "-" : reader.GetString(4),
                    Priority = reader.IsDBNull(5) ? "Normal" : reader.GetString(5),
                    Description = reader.IsDBNull(6) ? "" : reader.GetString(6),
                    Date = reader.IsDBNull(7) ? "-" : reader.GetString(7),
                    Status = reader.IsDBNull(8) ? "Açık" : reader.GetString(8)
                });
            }

            return list;
        }

        public void AddTicket(TicketItem ticket)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand(@"
                INSERT INTO tickets (department, personnel_name, internal_number, issue_type, priority, description, date, status)
                VALUES (@dep, @pname, @inum, @itype, @prio, @desc, @date, @status);
            ", conn);

            cmd.Parameters.AddWithValue("@dep", ticket.Department);
            cmd.Parameters.AddWithValue("@pname", ticket.PersonnelName);
            cmd.Parameters.AddWithValue("@inum", ticket.InternalNumber);
            cmd.Parameters.AddWithValue("@itype", ticket.IssueType);
            cmd.Parameters.AddWithValue("@prio", ticket.Priority);
            cmd.Parameters.AddWithValue("@desc", ticket.Description);
            cmd.Parameters.AddWithValue("@date", DateTime.Now.ToString("yyyy-MM-dd HH:mm"));
            cmd.Parameters.AddWithValue("@status", ticket.Status);

            cmd.ExecuteNonQuery();
        }

        public void UpdateTicketStatus(int id, string newStatus)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand("UPDATE tickets SET status=@status WHERE id=@id;", conn);
            cmd.Parameters.AddWithValue("@status", newStatus);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.ExecuteNonQuery();
        }

        public void DeleteTicket(int id)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand("DELETE FROM tickets WHERE id=@id;", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.ExecuteNonQuery();
        }

        public List<InventoryItem> GetInventory()
        {
            var list = new List<InventoryItem>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand("SELECT id, brand, model, serial_no, ip_address, location, user_name, date FROM inventory ORDER BY id DESC;", conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new InventoryItem
                {
                    Id = reader.GetInt32(0),
                    Brand = reader.IsDBNull(1) ? "-" : reader.GetString(1),
                    Model = reader.IsDBNull(2) ? "-" : reader.GetString(2),
                    SerialNo = reader.IsDBNull(3) ? "-" : reader.GetString(3),
                    IpAddress = reader.IsDBNull(4) ? "-" : reader.GetString(4),
                    Location = reader.IsDBNull(5) ? "-" : reader.GetString(5),
                    UserName = reader.IsDBNull(6) ? "-" : reader.GetString(6),
                    Date = reader.IsDBNull(7) ? "-" : reader.GetString(7)
                });
            }

            return list;
        }

        public void AddInventory(InventoryItem item)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand(@"
                INSERT OR REPLACE INTO inventory (brand, model, serial_no, ip_address, location, user_name, date)
                VALUES (@brand, @model, @serial, @ip, @loc, @user, @date);
            ", conn);

            cmd.Parameters.AddWithValue("@brand", item.Brand);
            cmd.Parameters.AddWithValue("@model", item.Model);
            cmd.Parameters.AddWithValue("@serial", item.SerialNo);
            cmd.Parameters.AddWithValue("@ip", item.IpAddress);
            cmd.Parameters.AddWithValue("@loc", item.Location);
            cmd.Parameters.AddWithValue("@user", item.UserName);
            cmd.Parameters.AddWithValue("@date", DateTime.Now.ToString("yyyy-MM-dd"));

            cmd.ExecuteNonQuery();
        }

        public void DeleteInventory(int id)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand("DELETE FROM inventory WHERE id=@id;", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.ExecuteNonQuery();
        }

        public void AutoRegisterCurrentMachine()
        {
            string brand = "-";
            string model = "-";
            string serial = "-";
            string ip = "-";

            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT Manufacturer, Model FROM Win32_ComputerSystem");
                foreach (ManagementObject obj in searcher.Get())
                {
                    brand = obj["Manufacturer"]?.ToString()?.Trim() ?? "-";
                    model = obj["Model"]?.ToString()?.Trim() ?? "-";
                    break;
                }
            }
            catch { }

            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT SerialNumber FROM Win32_BIOS");
                foreach (ManagementObject obj in searcher.Get())
                {
                    serial = obj["SerialNumber"]?.ToString()?.Trim() ?? "-";
                    break;
                }
            }
            catch { }

            try
            {
                foreach (var addr in Dns.GetHostEntry(Dns.GetHostName()).AddressList)
                {
                    if (addr.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(addr))
                    {
                        ip = addr.ToString();
                        break;
                    }
                }
            }
            catch { }

            AddInventory(new InventoryItem
            {
                Brand = brand,
                Model = model,
                SerialNo = serial,
                IpAddress = ip,
                Location = Environment.MachineName,
                UserName = Environment.UserName,
                Date = DateTime.Now.ToString("yyyy-MM-dd")
            });
        }
    }
}