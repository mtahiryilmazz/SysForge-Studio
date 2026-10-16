# Dosya Adı: models.py
import logging
from database.connection import DatabaseConnection

class DatabaseManager:
    def __init__(self, db_conn: DatabaseConnection):
        self.db = db_conn

    def initialize_database(self):
        """Veritabanı tablolarını yoksa oluşturur."""
        logging.info("Veritabani tablolari kontrol ediliyor...")

        schemas = [
            # 1. Kullanıcılar (Gelişmiş)
            """CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password TEXT NOT NULL,
                role TEXT NOT NULL,
                permissions TEXT DEFAULT '*',
                last_active TEXT,
                ppolicy_version INTEGER DEFAULT 0
            )""",
            # 2. Müdürlükler
            """CREATE TABLE IF NOT EXISTS departments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL
            )""",
            # 3. Birimler
            """CREATE TABLE IF NOT EXISTS units (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                department_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
            )""",
            # 4. Arıza Kayıtları
            """CREATE TABLE IF NOT EXISTS tickets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                department TEXT,
                department_id INTEGER,
                unit_id INTEGER,
                personnel_name TEXT,
                internal_number TEXT,
                issue_type TEXT,
                priority TEXT,
                description TEXT,
                date TEXT,
                status TEXT DEFAULT 'Açık'
            )""",
            # 5. Cihaz Envanteri
            """CREATE TABLE IF NOT EXISTS inventory (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                brand TEXT,
                model TEXT,
                serial_no TEXT UNIQUE,
                ip_address TEXT,
                location TEXT,
                user_name TEXT,
                department_id INTEGER,
                unit_id INTEGER,
                date TEXT
            )""",
            # 6. Log Sistemi
            """CREATE TABLE IF NOT EXISTS logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_info TEXT,
                timestamp TEXT,
                action_type TEXT,
                result TEXT
            )""",
            # 7. Lisanslama Sistemi
            """CREATE TABLE IF NOT EXISTS licenses (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                license_key TEXT UNIQUE NOT NULL,
                assigned_to TEXT,
                hwid TEXT,
                status TEXT DEFAULT 'PENDING',
                expiry_date TEXT,
                created_at TEXT
            )""",
        ]

        try:
            for sql in schemas:
                self.db.execute_query(sql)

            # Varsayılan Admin
            self.db.execute_query(
                "INSERT OR IGNORE INTO users (username, password, role) VALUES (?, ?, ?)",
                ("Admin", "admin123", "Admin")
            )
            self.db.execute_query("UPDATE users SET role='Admin' WHERE role='Master Admin'")
            self.db.execute_query("DELETE FROM users WHERE username='admin'")

            # ALTER TABLE işlemleri artık gereksiz çünkü kolonlar yukarıdaki CREATE TABLE içinde tanımlı.
            # Gelecekte yeni kolon eklenirse burada 'IF NOT EXISTS' kontrolü ile eklenmeli.

            # ID sayacı temizliği (test silmelerinden kalan yüksek ID'ler)
            for tbl in ("users", "tickets", "inventory"):
                try:
                    cnt = self.db.fetch_data(f"SELECT COUNT(*) as c FROM {tbl}")
                    mx  = self.db.fetch_data(f"SELECT MAX(id) as m FROM {tbl}")
                    c = cnt[0]['c'] if cnt else 0
                    m = mx[0]['m']  if (mx and mx[0]['m']) else 0
                    if c == 1 and m > 5:
                        self.db.execute_query(
                            "UPDATE sqlite_sequence SET seq=? WHERE name=?", (m, tbl)
                        )
                except Exception:
                    pass

            logging.info("Tablolar basariyla kontrol edildi ve olusturuldu.")
            return True
        except Exception as e:
            logging.error(f"Tablo olusturma hatasi: {e}")
            return False


def add_log(db_conn: DatabaseConnection, user_info: str, timestamp: str,
            action_type: str, result: str):
    return db_conn.execute_query(
        "INSERT INTO logs (user_info, timestamp, action_type, result) VALUES (?,?,?,?)",
        (user_info, timestamp, action_type, result)
    )
