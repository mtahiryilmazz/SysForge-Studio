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
                CREATE TABLE IF NOT EXISTS departments (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT UNIQUE NOT NULL
                );

                CREATE TABLE IF NOT EXISTS units (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    department_id INTEGER NOT NULL,
                    name TEXT NOT NULL,
                    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS tickets (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    department TEXT,
                    unit TEXT,
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
                    department TEXT,
                    unit TEXT,
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

            // Seed default departments & units if empty
            using var countCmd = new SqliteCommand("SELECT COUNT(*) FROM departments;", conn);
            long count = (long)(countCmd.ExecuteScalar() ?? 0);
            if (count == 0)
            {
                using var insertSeed = new SqliteCommand(@"
                    INSERT OR IGNORE INTO departments (name) VALUES ('Bilgi İşlem Müdürlüğü');
                    INSERT OR IGNORE INTO departments (name) VALUES ('İnsan Kaynakları');
                    INSERT OR IGNORE INTO departments (name) VALUES ('Mali Hizmetler');
                    INSERT OR IGNORE INTO departments (name) VALUES ('Yazı İşleri & Arşiv');
                    
                    INSERT OR IGNORE INTO units (department_id, name) VALUES (1, 'Sistem & Ağ Yönetimi');
                    INSERT OR IGNORE INTO units (department_id, name) VALUES (1, 'Kullanıcı Destek & Donanım');
                    INSERT OR IGNORE INTO units (department_id, name) VALUES (1, 'Yazılım & Veri');
                    INSERT OR IGNORE INTO units (department_id, name) VALUES (2, 'Özlük İşleri');
                    INSERT OR IGNORE INTO units (department_id, name) VALUES (3, 'Muhasebe & Gelir');
                ", conn);
                insertSeed.ExecuteNonQuery();
            }
        }

        #region Departments & Units

        public List<DepartmentItem> GetDepartments()
        {
            var list = new List<DepartmentItem>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand("SELECT id, name FROM departments ORDER BY name ASC;", conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new DepartmentItem
                {
                    Id = reader.GetInt32(0),
                    Name = reader.GetString(1)
                });
            }

            foreach (var dep in list)
            {
                dep.Units = GetUnits(dep.Id);
            }

            return list;
        }

        public void AddDepartment(string name)
        {
            if (string.IsNullOrWhiteSpace(name)) return;
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("INSERT OR IGNORE INTO departments (name) VALUES (@name);", conn);
            cmd.Parameters.AddWithValue("@name", name.Trim());
            cmd.ExecuteNonQuery();
        }

        public void DeleteDepartment(int id)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("DELETE FROM departments WHERE id=@id;", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.ExecuteNonQuery();
        }

        public List<UnitItem> GetUnits(int departmentId)
        {
            var list = new List<UnitItem>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand("SELECT id, department_id, name FROM units WHERE department_id=@depId ORDER BY name ASC;", conn);
            cmd.Parameters.AddWithValue("@depId", departmentId);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new UnitItem
                {
                    Id = reader.GetInt32(0),
                    DepartmentId = reader.GetInt32(1),
                    Name = reader.GetString(2)
                });
            }

            return list;
        }

        public void AddUnit(int departmentId, string name)
        {
            if (string.IsNullOrWhiteSpace(name)) return;
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("INSERT INTO units (department_id, name) VALUES (@depId, @name);", conn);
            cmd.Parameters.AddWithValue("@depId", departmentId);
            cmd.Parameters.AddWithValue("@name", name.Trim());
            cmd.ExecuteNonQuery();
        }

        public void DeleteUnit(int id)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("DELETE FROM units WHERE id=@id;", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.ExecuteNonQuery();
        }

        #endregion

        #region Tickets

        public List<TicketItem> GetTickets()
        {
            var list = new List<TicketItem>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand("SELECT id, department, unit, personnel_name, internal_number, issue_type, priority, description, date, status FROM tickets ORDER BY id DESC;", conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new TicketItem
                {
                    Id = reader.GetInt32(0),
                    Department = reader.IsDBNull(1) ? "-" : reader.GetString(1),
                    Unit = reader.IsDBNull(2) ? "-" : reader.GetString(2),
                    PersonnelName = reader.IsDBNull(3) ? "-" : reader.GetString(3),
                    InternalNumber = reader.IsDBNull(4) ? "-" : reader.GetString(4),
                    IssueType = reader.IsDBNull(5) ? "-" : reader.GetString(5),
                    Priority = reader.IsDBNull(6) ? "Normal" : reader.GetString(6),
                    Description = reader.IsDBNull(7) ? "" : reader.GetString(7),
                    Date = reader.IsDBNull(8) ? "-" : reader.GetString(8),
                    Status = reader.IsDBNull(9) ? "Açık" : reader.GetString(9)
                });
            }

            return list;
        }

        public void AddTicket(TicketItem ticket)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand(@"
                INSERT INTO tickets (department, unit, personnel_name, internal_number, issue_type, priority, description, date, status)
                VALUES (@dep, @unit, @pname, @inum, @itype, @prio, @desc, @date, @status);
            ", conn);

            cmd.Parameters.AddWithValue("@dep", ticket.Department);
            cmd.Parameters.AddWithValue("@unit", ticket.Unit);
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

        #endregion

        #region Inventory

        public List<InventoryItem> GetInventory()
        {
            var list = new List<InventoryItem>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand("SELECT id, brand, model, serial_no, ip_address, department, unit, location, user_name, date FROM inventory ORDER BY id DESC;", conn);
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
                    Department = reader.IsDBNull(5) ? "-" : reader.GetString(5),
                    Unit = reader.IsDBNull(6) ? "-" : reader.GetString(6),
                    Location = reader.IsDBNull(7) ? "-" : reader.GetString(7),
                    UserName = reader.IsDBNull(8) ? "-" : reader.GetString(8),
                    Date = reader.IsDBNull(9) ? "-" : reader.GetString(9)
                });
            }

            return list;
        }

        public void AddInventory(InventoryItem item)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand(@"
                INSERT OR REPLACE INTO inventory (brand, model, serial_no, ip_address, department, unit, location, user_name, date)
                VALUES (@brand, @model, @serial, @ip, @dep, @unit, @loc, @user, @date);
            ", conn);

            cmd.Parameters.AddWithValue("@brand", item.Brand);
            cmd.Parameters.AddWithValue("@model", item.Model);
            cmd.Parameters.AddWithValue("@serial", item.SerialNo);
            cmd.Parameters.AddWithValue("@ip", item.IpAddress);
            cmd.Parameters.AddWithValue("@dep", item.Department);
            cmd.Parameters.AddWithValue("@unit", item.Unit);
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

        public void AutoRegisterCurrentMachine(string department = "Bilgi İşlem", string unit = "Kullanıcı Destek")
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
                Department = department,
                Unit = unit,
                Location = Environment.MachineName,
                UserName = Environment.UserName,
                Date = DateTime.Now.ToString("yyyy-MM-dd")
            });
        }

        #endregion
    }
}