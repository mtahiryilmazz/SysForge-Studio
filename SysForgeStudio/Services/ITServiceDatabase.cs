using System;
using System.Collections.Generic;
using System.IO;
using System.Management;
using System.Net;
using System.Net.Sockets;
using Microsoft.Data.Sqlite;
using SysForgeStudio.Models;

namespace SysForgeStudio.Services
{
    public class ITServiceDatabase
    {
        public static ITServiceDatabase Instance { get; } = new ITServiceDatabase();

        public string DbPath { get; }
        private readonly string _connectionString;

        public event Action? DataChanged;

        public void NotifyDataChanged()
        {
            try { DataChanged?.Invoke(); } catch { }
        }

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

            // Auto-migrate schema in case of existing/legacy Vanguard database
            EnsureColumnExists(conn, "tickets", "unit", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "tickets", "department", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "tickets", "department_id", "INTEGER DEFAULT 0");
            EnsureColumnExists(conn, "tickets", "unit_id", "INTEGER DEFAULT 0");
            EnsureColumnExists(conn, "tickets", "personnel_name", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "tickets", "internal_number", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "tickets", "issue_type", "TEXT DEFAULT 'Genel'");
            EnsureColumnExists(conn, "tickets", "priority", "TEXT DEFAULT 'Normal'");
            EnsureColumnExists(conn, "tickets", "description", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "tickets", "date", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "tickets", "status", "TEXT DEFAULT 'Açık'");
            EnsureColumnExists(conn, "tickets", "resolution_note", "TEXT DEFAULT ''");

            EnsureColumnExists(conn, "inventory", "department", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "unit", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "department_id", "INTEGER DEFAULT 0");
            EnsureColumnExists(conn, "inventory", "unit_id", "INTEGER DEFAULT 0");
            EnsureColumnExists(conn, "inventory", "brand", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "model", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "serial_no", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "ip_address", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "location", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "user_name", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "date", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "motherboard", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "processor", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "ram", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "disk", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "gpu", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "os_version", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "mac_address", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "windows_build", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "bios_version", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "domain_workgroup", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "network_details", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "security_software", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "installed_software", "TEXT DEFAULT ''");
            EnsureColumnExists(conn, "inventory", "uptime", "TEXT DEFAULT ''");

            // Seed default departments & units if empty
            using var countCmd = new SqliteCommand("SELECT COUNT(*) FROM departments;", conn);
            long count = Convert.ToInt64(countCmd.ExecuteScalar() ?? 0);
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

            // Sync/Migrate data from Vanguard database if available
            TryMigrateVanguardData(conn);

            // Auto-heal any existing records with Hyper-V virtual adapter IP (192.168.128.1)
            try
            {
                string realIp = GetPrimaryActiveIpAddress();
                if (realIp != "-" && realIp != "192.168.128.1")
                {
                    using var fixIpCmd = new SqliteCommand("UPDATE inventory SET ip_address=@newIp WHERE ip_address='192.168.128.1';", conn);
                    fixIpCmd.Parameters.AddWithValue("@newIp", realIp);
                    fixIpCmd.ExecuteNonQuery();
                }
            }
            catch { }

            // Auto-heal any existing records with invalid Serial Number ('Default string', etc.)
            try
            {
                string realHwid = GetMachineHardwareId();
                if (!string.IsNullOrWhiteSpace(realHwid))
                {
                    using var fixSnCmd = new SqliteCommand(@"
                        UPDATE inventory 
                        SET serial_no = @newHwid 
                        WHERE LOWER(serial_no) LIKE '%default string%' 
                           OR LOWER(serial_no) LIKE '%to be filled%' 
                           OR serial_no = '-' 
                           OR serial_no = '';
                    ", conn);
                    fixSnCmd.Parameters.AddWithValue("@newHwid", realHwid);
                    fixSnCmd.ExecuteNonQuery();
                }
            }
            catch { }
        }

        private void EnsureColumnExists(SqliteConnection conn, string table, string column, string typeDef)
        {
            try
            {
                using var checkCmd = new SqliteCommand($"PRAGMA table_info({table});", conn);
                using var reader = checkCmd.ExecuteReader();
                bool exists = false;
                while (reader.Read())
                {
                    string colName = reader.GetString(1);
                    if (colName.Equals(column, StringComparison.OrdinalIgnoreCase))
                    {
                        exists = true;
                        break;
                    }
                }
                if (!exists)
                {
                    using var alterCmd = new SqliteCommand($"ALTER TABLE {table} ADD COLUMN {column} {typeDef};", conn);
                    alterCmd.ExecuteNonQuery();
                }
            }
            catch { }
        }

        private void TryMigrateVanguardData(SqliteConnection conn)
        {
            try
            {
                string[] candidates = {
                    @"D:\YILMAZApp\it_tech_service\it_tech_service.db",
                    @"C:\ProgramData\SysForgeStudio\it_tech_service.db",
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "it_tech_service.db")
                };

                string? sourcePath = candidates.FirstOrDefault(File.Exists);
                if (sourcePath == null || sourcePath.Equals(DbPath, StringComparison.OrdinalIgnoreCase))
                    return;

                using var sourceConn = new SqliteConnection($"Data Source={sourcePath};");
                sourceConn.Open();

                // 1. Migrate tickets if destination has 0 tickets
                using var tCountCmd = new SqliteCommand("SELECT COUNT(*) FROM tickets;", conn);
                long tCount = Convert.ToInt64(tCountCmd.ExecuteScalar() ?? 0);
                if (tCount == 0)
                {
                    using var sCmd = new SqliteCommand("SELECT id, department, personnel_name, internal_number, issue_type, priority, description, date, status FROM tickets;", sourceConn);
                    using var sReader = sCmd.ExecuteReader();
                    while (sReader.Read())
                    {
                        using var insCmd = new SqliteCommand(@"
                            INSERT OR IGNORE INTO tickets (department, unit, personnel_name, internal_number, issue_type, priority, description, date, status)
                            VALUES (@dep, '-', @pname, @inum, @itype, @prio, @desc, @date, @status);
                        ", conn);
                        insCmd.Parameters.AddWithValue("@dep", sReader.IsDBNull(1) ? "Genel" : sReader.GetString(1));
                        insCmd.Parameters.AddWithValue("@pname", sReader.IsDBNull(2) ? "Bilinmeyen" : sReader.GetString(2));
                        insCmd.Parameters.AddWithValue("@inum", sReader.IsDBNull(3) ? "-" : sReader.GetString(3));
                        insCmd.Parameters.AddWithValue("@itype", sReader.IsDBNull(4) ? "Genel" : sReader.GetString(4));
                        insCmd.Parameters.AddWithValue("@prio", sReader.IsDBNull(5) ? "Normal" : sReader.GetString(5));
                        insCmd.Parameters.AddWithValue("@desc", sReader.IsDBNull(6) ? "" : sReader.GetString(6));
                        insCmd.Parameters.AddWithValue("@date", sReader.IsDBNull(7) ? DateTime.Now.ToString("yyyy-MM-dd") : sReader.GetString(7));
                        insCmd.Parameters.AddWithValue("@status", sReader.IsDBNull(8) ? "Açık" : sReader.GetString(8));
                        insCmd.ExecuteNonQuery();
                    }
                }

                // 2. Migrate inventory if destination has 0 items
                using var iCountCmd = new SqliteCommand("SELECT COUNT(*) FROM inventory;", conn);
                long iCount = Convert.ToInt64(iCountCmd.ExecuteScalar() ?? 0);
                if (iCount == 0)
                {
                    using var sInvCmd = new SqliteCommand("SELECT brand, model, serial_no, ip_address, location, user_name FROM inventory;", sourceConn);
                    using var sInvReader = sInvCmd.ExecuteReader();
                    while (sInvReader.Read())
                    {
                        using var insInvCmd = new SqliteCommand(@"
                            INSERT OR IGNORE INTO inventory (brand, model, serial_no, ip_address, department, unit, location, user_name, date)
                            VALUES (@brand, @model, @serial, @ip, 'Bilgi İşlem', '-', @loc, @user, @date);
                        ", conn);
                        insInvCmd.Parameters.AddWithValue("@brand", sInvReader.IsDBNull(0) ? "-" : sInvReader.GetString(0));
                        insInvCmd.Parameters.AddWithValue("@model", sInvReader.IsDBNull(1) ? "-" : sInvReader.GetString(1));
                        insInvCmd.Parameters.AddWithValue("@serial", sInvReader.IsDBNull(2) ? "-" : sInvReader.GetString(2));
                        insInvCmd.Parameters.AddWithValue("@ip", sInvReader.IsDBNull(3) ? "-" : sInvReader.GetString(3));
                        insInvCmd.Parameters.AddWithValue("@loc", sInvReader.IsDBNull(4) ? "-" : sInvReader.GetString(4));
                        insInvCmd.Parameters.AddWithValue("@user", sInvReader.IsDBNull(5) ? "-" : sInvReader.GetString(5));
                        insInvCmd.Parameters.AddWithValue("@date", DateTime.Now.ToString("yyyy-MM-dd"));
                        insInvCmd.ExecuteNonQuery();
                    }
                }
            }
            catch { }
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
            NotifyDataChanged();
        }

        public void DeleteDepartment(int id)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmdUnits = new SqliteCommand("DELETE FROM units WHERE department_id=@id;", conn);
            cmdUnits.Parameters.AddWithValue("@id", id);
            cmdUnits.ExecuteNonQuery();

            using var cmd = new SqliteCommand("DELETE FROM departments WHERE id=@id;", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.ExecuteNonQuery();
            NotifyDataChanged();
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
            NotifyDataChanged();
        }

        public void DeleteUnit(int id)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("DELETE FROM units WHERE id=@id;", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.ExecuteNonQuery();
            NotifyDataChanged();
        }

        #endregion

        #region Tickets

        public List<TicketItem> GetTickets()
        {
            var list = new List<TicketItem>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand("SELECT id, department, unit, personnel_name, internal_number, issue_type, priority, description, date, status, resolution_note FROM tickets ORDER BY id DESC;", conn);
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
                    Status = reader.IsDBNull(9) ? "Açık" : reader.GetString(9),
                    ResolutionNote = reader.FieldCount > 10 && !reader.IsDBNull(10) ? reader.GetString(10) : ""
                });
            }

            return list;
        }

        public void AddTicket(TicketItem ticket)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand(@"
                INSERT INTO tickets (department, unit, personnel_name, internal_number, issue_type, priority, description, date, status, resolution_note)
                VALUES (@dep, @unit, @pname, @inum, @itype, @prio, @desc, @date, @status, @note);
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
            cmd.Parameters.AddWithValue("@note", ticket.ResolutionNote ?? "");

            cmd.ExecuteNonQuery();
            NotifyDataChanged();
        }

        public void UpdateTicketStatus(int id, string newStatus)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("UPDATE tickets SET status=@status WHERE id=@id;", conn);
            cmd.Parameters.AddWithValue("@status", newStatus);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.ExecuteNonQuery();
            NotifyDataChanged();
        }

        public void ResolveTicket(int id, string? resolutionNote = null)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            if (!string.IsNullOrWhiteSpace(resolutionNote))
            {
                using var cmd = new SqliteCommand("UPDATE tickets SET status='Çözüldü', resolution_note=@note WHERE id=@id;", conn);
                cmd.Parameters.AddWithValue("@note", resolutionNote.Trim());
                cmd.Parameters.AddWithValue("@id", id);
                cmd.ExecuteNonQuery();
            }
            else
            {
                using var cmd = new SqliteCommand("UPDATE tickets SET status='Çözüldü' WHERE id=@id;", conn);
                cmd.Parameters.AddWithValue("@id", id);
                cmd.ExecuteNonQuery();
            }
            NotifyDataChanged();
        }

        public void DeleteTicket(int id)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("DELETE FROM tickets WHERE id=@id;", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.ExecuteNonQuery();
            NotifyDataChanged();
        }

        #endregion

        #region Inventory

        public List<InventoryItem> GetInventory()
        {
            var list = new List<InventoryItem>();
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand(@"
                SELECT id, brand, model, serial_no, ip_address, department, unit, location, user_name, date,
                       motherboard, processor, ram, disk, gpu, os_version, mac_address,
                       windows_build, bios_version, domain_workgroup, network_details, security_software, installed_software, uptime
                FROM inventory ORDER BY id DESC;
            ", conn);
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
                    Date = reader.IsDBNull(9) ? "-" : reader.GetString(9),
                    Motherboard = reader.FieldCount > 10 && !reader.IsDBNull(10) ? reader.GetString(10) : "-",
                    Processor = reader.FieldCount > 11 && !reader.IsDBNull(11) ? reader.GetString(11) : "-",
                    Ram = reader.FieldCount > 12 && !reader.IsDBNull(12) ? reader.GetString(12) : "-",
                    Disk = reader.FieldCount > 13 && !reader.IsDBNull(13) ? reader.GetString(13) : "-",
                    Gpu = reader.FieldCount > 14 && !reader.IsDBNull(14) ? reader.GetString(14) : "-",
                    OsVersion = reader.FieldCount > 15 && !reader.IsDBNull(15) ? reader.GetString(15) : "-",
                    MacAddress = reader.FieldCount > 16 && !reader.IsDBNull(16) ? reader.GetString(16) : "-",
                    WindowsBuild = reader.FieldCount > 17 && !reader.IsDBNull(17) ? reader.GetString(17) : "-",
                    BiosVersion = reader.FieldCount > 18 && !reader.IsDBNull(18) ? reader.GetString(18) : "-",
                    DomainWorkgroup = reader.FieldCount > 19 && !reader.IsDBNull(19) ? reader.GetString(19) : "-",
                    NetworkDetails = reader.FieldCount > 20 && !reader.IsDBNull(20) ? reader.GetString(20) : "-",
                    SecuritySoftware = reader.FieldCount > 21 && !reader.IsDBNull(21) ? reader.GetString(21) : "-",
                    InstalledSoftwareSummary = reader.FieldCount > 22 && !reader.IsDBNull(22) ? reader.GetString(22) : "-",
                    Uptime = reader.FieldCount > 23 && !reader.IsDBNull(23) ? reader.GetString(23) : "-"
                });
            }

            return list;
        }

        public void AddInventory(InventoryItem item)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            using var cmd = new SqliteCommand(@"
                INSERT OR REPLACE INTO inventory 
                (brand, model, serial_no, ip_address, department, unit, location, user_name, date,
                 motherboard, processor, ram, disk, gpu, os_version, mac_address,
                 windows_build, bios_version, domain_workgroup, network_details, security_software, installed_software, uptime)
                VALUES 
                (@brand, @model, @serial, @ip, @dep, @unit, @loc, @user, @date,
                 @mb, @cpu, @ram, @disk, @gpu, @os, @mac,
                 @wbuild, @bios, @dom, @net, @sec, @soft, @up);
            ", conn);

            cmd.Parameters.AddWithValue("@brand", item.Brand ?? "-");
            cmd.Parameters.AddWithValue("@model", item.Model ?? "-");
            cmd.Parameters.AddWithValue("@serial", item.SerialNo ?? "-");
            cmd.Parameters.AddWithValue("@ip", item.IpAddress ?? "-");
            cmd.Parameters.AddWithValue("@dep", item.Department ?? "-");
            cmd.Parameters.AddWithValue("@unit", item.Unit ?? "-");
            cmd.Parameters.AddWithValue("@loc", item.Location ?? "-");
            cmd.Parameters.AddWithValue("@user", item.UserName ?? "-");
            cmd.Parameters.AddWithValue("@date", string.IsNullOrWhiteSpace(item.Date) ? DateTime.Now.ToString("yyyy-MM-dd") : item.Date);
            cmd.Parameters.AddWithValue("@mb", item.Motherboard ?? "-");
            cmd.Parameters.AddWithValue("@cpu", item.Processor ?? "-");
            cmd.Parameters.AddWithValue("@ram", item.Ram ?? "-");
            cmd.Parameters.AddWithValue("@disk", item.Disk ?? "-");
            cmd.Parameters.AddWithValue("@gpu", item.Gpu ?? "-");
            cmd.Parameters.AddWithValue("@os", item.OsVersion ?? "-");
            cmd.Parameters.AddWithValue("@mac", item.MacAddress ?? "-");
            cmd.Parameters.AddWithValue("@wbuild", item.WindowsBuild ?? "-");
            cmd.Parameters.AddWithValue("@bios", item.BiosVersion ?? "-");
            cmd.Parameters.AddWithValue("@dom", item.DomainWorkgroup ?? "-");
            cmd.Parameters.AddWithValue("@net", item.NetworkDetails ?? "-");
            cmd.Parameters.AddWithValue("@sec", item.SecuritySoftware ?? "-");
            cmd.Parameters.AddWithValue("@soft", item.InstalledSoftwareSummary ?? "-");
            cmd.Parameters.AddWithValue("@up", item.Uptime ?? "-");

            cmd.ExecuteNonQuery();
            NotifyDataChanged();
        }

        public void DeleteInventory(int id)
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();
            using var cmd = new SqliteCommand("DELETE FROM inventory WHERE id=@id;", conn);
            cmd.Parameters.AddWithValue("@id", id);
            cmd.ExecuteNonQuery();
            NotifyDataChanged();
        }

        public static InventoryItem CollectLiveMachineSpecs(string department = "Bilgi İşlem", string unit = "Kullanıcı Destek")
        {
            string brand = "-";
            string model = "-";
            string serial = "-";
            string motherboard = "-";
            string processor = "-";
            string ram = "-";
            string disk = "-";
            string gpu = "-";
            string osVersion = "-";
            string macAddress = "-";
            string cpuShort = "";
            string ramShort = "";
            string ip = "-";

            // 1. Computer System & Memory
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT Manufacturer, Model, TotalPhysicalMemory FROM Win32_ComputerSystem");
                foreach (ManagementObject obj in searcher.Get())
                {
                    brand = obj["Manufacturer"]?.ToString()?.Trim() ?? "-";
                    model = obj["Model"]?.ToString()?.Trim() ?? "-";
                    if (obj["TotalPhysicalMemory"] != null && double.TryParse(obj["TotalPhysicalMemory"].ToString(), out double ramBytes))
                    {
                        double totalGb = Math.Round(ramBytes / (1024 * 1024 * 1024));
                        ramShort = $"{totalGb}GB RAM";
                        ram = $"{totalGb} GB";
                    }
                    break;
                }
            }
            catch { }

            // 2. BaseBoard (Motherboard)
            try
            {
                using var bbSearcher = new ManagementObjectSearcher("SELECT Manufacturer, Product, SerialNumber FROM Win32_BaseBoard");
                foreach (ManagementObject obj in bbSearcher.Get())
                {
                    string bbMfr = obj["Manufacturer"]?.ToString()?.Trim() ?? "";
                    string bbProd = obj["Product"]?.ToString()?.Trim() ?? "";
                    motherboard = $"{bbMfr} {bbProd}".Trim();
                    if (string.IsNullOrWhiteSpace(motherboard)) motherboard = "-";

                    if ((IsInvalidSerial(brand) || brand == "System manufacturer" || brand == "-") && !string.IsNullOrWhiteSpace(bbMfr))
                    {
                        brand = bbMfr;
                    }
                    if ((IsInvalidSerial(model) || model == "System Product Name" || model == "-") && !string.IsNullOrWhiteSpace(bbProd))
                    {
                        model = bbProd;
                    }
                    break;
                }
            }
            catch { }

            // 3. Processor (CPU)
            try
            {
                using var cpuSearcher = new ManagementObjectSearcher("SELECT Name, MaxClockSpeed, NumberOfCores, NumberOfLogicalProcessors FROM Win32_Processor");
                foreach (ManagementObject obj in cpuSearcher.Get())
                {
                    string rawCpu = obj["Name"]?.ToString()?.Trim() ?? "";
                    processor = rawCpu;
                    if (rawCpu.Contains("Core(TM) "))
                    {
                        var parts = rawCpu.Split(new[] { "Core(TM) " }, StringSplitOptions.None);
                        if (parts.Length > 1)
                        {
                            cpuShort = parts[1].Split('@')[0].Trim();
                        }
                    }
                    else if (!string.IsNullOrWhiteSpace(rawCpu))
                    {
                        cpuShort = rawCpu.Split('@')[0].Trim();
                    }
                    break;
                }
            }
            catch { }

            // 4. Memory Details (Slots & Speed)
            try
            {
                var memSlots = new List<string>();
                using var pmSearcher = new ManagementObjectSearcher("SELECT Capacity, Speed FROM Win32_PhysicalMemory");
                foreach (ManagementObject obj in pmSearcher.Get())
                {
                    if (obj["Capacity"] != null && double.TryParse(obj["Capacity"].ToString(), out double capBytes))
                    {
                        int slotGb = (int)Math.Round(capBytes / (1024 * 1024 * 1024));
                        string speed = obj["Speed"]?.ToString()?.Trim() ?? "";
                        memSlots.Add($"{slotGb}GB" + (!string.IsNullOrWhiteSpace(speed) ? $"@{speed}MHz" : ""));
                    }
                }
                if (memSlots.Count > 0)
                {
                    ram = $"{ram} ({string.Join(" + ", memSlots)})";
                }
            }
            catch { }

            // 5. Storage (Disk Drives)
            try
            {
                var diskList = new List<string>();
                using var ddSearcher = new ManagementObjectSearcher("SELECT Model, Size FROM Win32_DiskDrive");
                foreach (ManagementObject obj in ddSearcher.Get())
                {
                    string dModel = obj["Model"]?.ToString()?.Trim() ?? "";
                    string dSize = "";
                    if (obj["Size"] != null && double.TryParse(obj["Size"].ToString(), out double sizeBytes))
                    {
                        double gb = Math.Round(sizeBytes / (1024 * 1024 * 1024));
                        dSize = gb >= 1000 ? $"{Math.Round(gb / 1000, 1)} TB" : $"{gb} GB";
                    }
                    if (!string.IsNullOrWhiteSpace(dModel))
                    {
                        diskList.Add(string.IsNullOrWhiteSpace(dSize) ? dModel : $"{dModel} ({dSize})");
                    }
                }
                if (diskList.Count > 0)
                {
                    disk = string.Join(" | ", diskList);
                }
            }
            catch { }

            // 6. Graphics (GPU)
            try
            {
                var gpuList = new List<string>();
                using var vcSearcher = new ManagementObjectSearcher("SELECT Name FROM Win32_VideoController");
                foreach (ManagementObject obj in vcSearcher.Get())
                {
                    string gName = obj["Name"]?.ToString()?.Trim() ?? "";
                    if (!string.IsNullOrWhiteSpace(gName) && !gpuList.Contains(gName))
                    {
                        gpuList.Add(gName);
                    }
                }
                if (gpuList.Count > 0)
                {
                    gpu = string.Join(" / ", gpuList);
                }
            }
            catch { }

            // 7. Operating System & Windows Build
            string winBuild = "";
            try
            {
                using var osSearcher = new ManagementObjectSearcher("SELECT Caption, OSArchitecture, Version, BuildNumber FROM Win32_OperatingSystem");
                foreach (ManagementObject obj in osSearcher.Get())
                {
                    string cap = obj["Caption"]?.ToString()?.Trim() ?? "";
                    string arch = obj["OSArchitecture"]?.ToString()?.Trim() ?? "";
                    osVersion = $"{cap} ({arch})".Trim();
                    winBuild = $"Derleme {obj["BuildNumber"] ?? obj["Version"]}";
                    break;
                }
            }
            catch { }

            // 8. BIOS Version & Date
            string biosInfo = "-";
            try
            {
                using var bioSearcher = new ManagementObjectSearcher("SELECT Manufacturer, SMBIOSBIOSVersion, ReleaseDate FROM Win32_BIOS");
                foreach (ManagementObject obj in bioSearcher.Get())
                {
                    string bm = obj["Manufacturer"]?.ToString()?.Trim() ?? "";
                    string bv = obj["SMBIOSBIOSVersion"]?.ToString()?.Trim() ?? "";
                    string bd = obj["ReleaseDate"]?.ToString()?.Trim() ?? "";
                    if (bd.Length >= 8) bd = $"{bd.Substring(0, 4)}-{bd.Substring(4, 2)}-{bd.Substring(6, 2)}";
                    biosInfo = $"{bm} {bv} ({bd})".Trim();
                    break;
                }
            }
            catch { }

            // 9. Domain / Workgroup
            string domain = Environment.UserDomainName;
            try
            {
                using var cs = new ManagementObjectSearcher("SELECT Domain, PartOfDomain FROM Win32_ComputerSystem");
                foreach (ManagementObject obj in cs.Get())
                {
                    string d = obj["Domain"]?.ToString()?.Trim() ?? "";
                    bool pod = Convert.ToBoolean(obj["PartOfDomain"] ?? false);
                    domain = pod ? $"Domain: {d}" : $"İş Grubu: {d}";
                    break;
                }
            }
            catch { }

            // 10. Network Infrastructure & Primary MAC
            string netDetails = "-";
            try
            {
                using var netSearcher = new ManagementObjectSearcher("SELECT MACAddress, IPEnabled, DefaultIPGateway, IPSubnet, DNSServerSearchOrder FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = TRUE");
                foreach (ManagementObject obj in netSearcher.Get())
                {
                    string mac = obj["MACAddress"]?.ToString()?.Trim() ?? "";
                    if (!string.IsNullOrWhiteSpace(mac) && macAddress == "-")
                    {
                        macAddress = mac;
                    }
                    var gateways = obj["DefaultIPGateway"] as string[];
                    var subnets = obj["IPSubnet"] as string[];
                    var dns = obj["DNSServerSearchOrder"] as string[];
                    string gw = gateways != null && gateways.Length > 0 ? gateways[0] : "-";
                    string mask = subnets != null && subnets.Length > 0 ? subnets[0] : "-";
                    string dn = dns != null && dns.Length > 0 ? string.Join(", ", dns.Take(2)) : "-";
                    netDetails = $"Ağ Geçidi: {gw} | Alt Ağ: {mask} | DNS: {dn}";
                    break;
                }
            }
            catch { }

            // 11. Security Software / Defender Status
            string securityStatus = "Windows Defender (Aktif)";
            try
            {
                using var scSearcher = new ManagementObjectSearcher(@"root\SecurityCenter2", "SELECT displayName FROM AntiVirusProduct");
                var avs = new List<string>();
                foreach (ManagementObject obj in scSearcher.Get())
                {
                    string av = obj["displayName"]?.ToString()?.Trim() ?? "";
                    if (!string.IsNullOrWhiteSpace(av)) avs.Add(av);
                }
                if (avs.Count > 0) securityStatus = string.Join(", ", avs);
            }
            catch { }

            // 12. Installed Software Summary
            string softwareSummary = "-";
            try
            {
                int appCount = 0;
                var sampleApps = new List<string>();
                string[] regKeys = {
                    @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                    @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
                };
                foreach (var rk in regKeys)
                {
                    using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(rk);
                    if (key != null)
                    {
                        foreach (var subKeyName in key.GetSubKeyNames())
                        {
                            using var subKey = key.OpenSubKey(subKeyName);
                            string? name = subKey?.GetValue("DisplayName")?.ToString()?.Trim();
                            if (!string.IsNullOrWhiteSpace(name) && !name.StartsWith("KB") && !sampleApps.Contains(name))
                            {
                                appCount++;
                                if (sampleApps.Count < 4) sampleApps.Add(name);
                            }
                        }
                    }
                }
                softwareSummary = $"{appCount} Yüklü Uygulama ({string.Join(", ", sampleApps)}...)";
            }
            catch { }

            // 13. System Uptime
            string uptime = "-";
            try
            {
                var bootSpan = TimeSpan.FromMilliseconds(EnvironmentCompat.TickCount64);
                uptime = $"{bootSpan.Days} gün, {bootSpan.Hours} saat, {bootSpan.Minutes} dakika";
            }
            catch { }

            // Combine model with CPU and RAM context if not already present
            if (!string.IsNullOrWhiteSpace(cpuShort) || !string.IsNullOrWhiteSpace(ramShort))
            {
                var specs = string.Join(" / ", new[] { cpuShort, ramShort }.Where(x => !string.IsNullOrWhiteSpace(x)));
                if (!string.IsNullOrWhiteSpace(specs) && !model.Contains(specs, StringComparison.OrdinalIgnoreCase))
                {
                    model = $"{model} ({specs})";
                }
            }

            // 14. BIOS Serial Number & HWID Fallbacks
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

            if (IsInvalidSerial(serial))
            {
                try
                {
                    using var bbSearcher = new ManagementObjectSearcher("SELECT SerialNumber FROM Win32_BaseBoard");
                    foreach (ManagementObject obj in bbSearcher.Get())
                    {
                        string bbSerial = obj["SerialNumber"]?.ToString()?.Trim() ?? "-";
                        if (!IsInvalidSerial(bbSerial))
                        {
                            serial = bbSerial;
                            break;
                        }
                    }
                }
                catch { }
            }

            if (IsInvalidSerial(serial))
            {
                serial = GetMachineHardwareId();
            }

            ip = GetPrimaryActiveIpAddress();

            return new InventoryItem
            {
                Brand = brand,
                Model = model,
                SerialNo = serial,
                IpAddress = ip,
                Motherboard = motherboard,
                Processor = processor,
                Ram = ram,
                Disk = disk,
                Gpu = gpu,
                OsVersion = osVersion,
                WindowsBuild = winBuild,
                BiosVersion = biosInfo,
                DomainWorkgroup = domain,
                NetworkDetails = netDetails,
                SecuritySoftware = securityStatus,
                InstalledSoftwareSummary = softwareSummary,
                Uptime = uptime,
                MacAddress = macAddress,
                Department = department,
                Unit = unit,
                Location = Environment.MachineName,
                UserName = Environment.UserName,
                Date = DateTime.Now.ToString("yyyy-MM-dd")
            };
        }

        public void AutoRegisterCurrentMachine(string department = "Bilgi İşlem", string unit = "Kullanıcı Destek")
        {
            var item = CollectLiveMachineSpecs(department, unit);
            AddInventory(item);
        }

        public static bool IsInvalidSerial(string? s)
        {
            if (string.IsNullOrWhiteSpace(s)) return true;
            string clean = s.Trim().ToLowerInvariant();
            return clean == "-" ||
                   clean == "0" ||
                   clean == "none" ||
                   clean == "n/a" ||
                   clean == "null" ||
                   clean == "123456789" ||
                   clean.Contains("default string") ||
                   clean.Contains("to be filled") ||
                   clean.Contains("system serial") ||
                   clean.Contains("chassis serial") ||
                   clean.Contains("base board serial") ||
                   clean == "ffffffff-ffff-ffff-ffff-ffffffffffff" ||
                   clean == "00000000-0000-0000-0000-000000000000";
        }

        public static string GetMachineHardwareId()
        {
            string uuid = "";
            try
            {
                using var cspSearcher = new ManagementObjectSearcher("SELECT UUID FROM Win32_ComputerSystemProduct");
                foreach (ManagementObject obj in cspSearcher.Get())
                {
                    string val = obj["UUID"]?.ToString()?.Trim() ?? "";
                    if (!IsInvalidSerial(val))
                    {
                        uuid = val;
                        break;
                    }
                }
            }
            catch { }

            if (!string.IsNullOrWhiteSpace(uuid))
            {
                return $"HWID-{uuid}";
            }

            // Fallback: SHA256 hardware hash
            try
            {
                var parts = new List<string>();
                using var cpuSearcher = new ManagementObjectSearcher("SELECT ProcessorId, Name FROM Win32_Processor");
                foreach (ManagementObject obj in cpuSearcher.Get())
                {
                    parts.Add(obj["ProcessorId"]?.ToString()?.Trim() ?? "");
                    parts.Add(obj["Name"]?.ToString()?.Trim() ?? "");
                }

                using var bbSearcher = new ManagementObjectSearcher("SELECT Manufacturer, Product FROM Win32_BaseBoard");
                foreach (ManagementObject obj in bbSearcher.Get())
                {
                    parts.Add(obj["Manufacturer"]?.ToString()?.Trim() ?? "");
                    parts.Add(obj["Product"]?.ToString()?.Trim() ?? "");
                }

                using var diskSearcher = new ManagementObjectSearcher("SELECT SerialNumber FROM Win32_DiskDrive");
                foreach (ManagementObject obj in diskSearcher.Get())
                {
                    parts.Add(obj["SerialNumber"]?.ToString()?.Trim() ?? "");
                }

                parts.Add(Environment.MachineName);

                string raw = string.Join("|", parts.Where(p => !string.IsNullOrWhiteSpace(p)));
                using var sha = System.Security.Cryptography.SHA256.Create();
                byte[] hash = sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(raw));
                string hashStr = BitConverter.ToString(hash).Replace("-", "");
                return $"HWID-{hashStr.Substring(0, Math.Min(24, hashStr.Length))}";
            }
            catch
            {
                return $"HWID-{Environment.MachineName}";
            }
        }

        public static string GetPrimaryActiveIpAddress()
        {
            string ip = "-";

            // 1. Socket Routing Test (Active Default Gateway / Outgoing Interface)
            try
            {
                using var socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, 0);
                socket.Connect("8.8.8.8", 65530);
                if (socket.LocalEndPoint is IPEndPoint ep && !IPAddress.IsLoopback(ep.Address))
                {
                    string candidate = ep.Address.ToString();
                    if (!candidate.StartsWith("192.168.128.") && !candidate.StartsWith("169.254.") && !candidate.StartsWith("127."))
                    {
                        return candidate;
                    }
                }
            }
            catch { }

            // 2. IP Tarama panelindeki gerçek fiziksel ağ kartlarından çek
            try
            {
                var adapters = ToolkitEngine.Instance.GetNetworkAdapters();
                var physical = adapters.FirstOrDefault(a =>
                    !string.IsNullOrWhiteSpace(a.IPAddress) &&
                    a.IPAddress != "-" &&
                    !a.IPAddress.StartsWith("169.254") &&
                    !a.IPAddress.StartsWith("127.") &&
                    !a.IPAddress.StartsWith("192.168.128.") && // Hyper-V vEthernet
                    !a.Name.Contains("vEthernet", StringComparison.OrdinalIgnoreCase) &&
                    !a.Name.Contains("VMware", StringComparison.OrdinalIgnoreCase) &&
                    !a.Name.Contains("VirtualBox", StringComparison.OrdinalIgnoreCase) &&
                    !a.Name.Contains("Loopback", StringComparison.OrdinalIgnoreCase) &&
                    !a.Description.Contains("Virtual", StringComparison.OrdinalIgnoreCase) &&
                    !a.Description.Contains("Hyper-V", StringComparison.OrdinalIgnoreCase) &&
                    !a.Description.Contains("VMware", StringComparison.OrdinalIgnoreCase) &&
                    !a.Description.Contains("Filter", StringComparison.OrdinalIgnoreCase) &&
                    a.Gateway != "-" && a.Gateway != "0.0.0.0"
                ) ?? adapters.FirstOrDefault(a =>
                    !string.IsNullOrWhiteSpace(a.IPAddress) &&
                    a.IPAddress != "-" &&
                    !a.IPAddress.StartsWith("169.254") &&
                    !a.IPAddress.StartsWith("192.168.128.") &&
                    !a.Description.Contains("Virtual", StringComparison.OrdinalIgnoreCase) &&
                    !a.Description.Contains("Hyper-V", StringComparison.OrdinalIgnoreCase)
                );

                if (physical != null && !string.IsNullOrWhiteSpace(physical.IPAddress))
                {
                    return physical.IPAddress;
                }
            }
            catch { }

            // 3. Fallback DNS AddressList with virtual IP filtering
            try
            {
                foreach (var addr in Dns.GetHostEntry(Dns.GetHostName()).AddressList)
                {
                    if (addr.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(addr))
                    {
                        string s = addr.ToString();
                        if (!s.StartsWith("192.168.128.") && !s.StartsWith("169.254."))
                        {
                            return s;
                        }
                    }
                }
            }
            catch { }

            return ip;
        }

        #endregion
    }
}