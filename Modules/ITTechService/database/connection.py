# Dosya Adı: connection.py
import sqlite3
import os
import logging
from core.path_helper import get_app_root
from typing import Optional, Any

# Loglama ayarı
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class DatabaseConnection:
    def __init__(self, db_type: str = "sqlite", db_string: str = "it_tech_service.db"):
        self.db_type = db_type
        self.db_string = db_string
        self.connection = None
        
    def connect(self):
        """Veritabanına bağlanır ve yoksa dosyayı oluşturur."""
        try:
            if self.db_type == "sqlite":
                # Veritabanı yolunu EXE'nin olduğu klasöre sabitle
                base_dir = get_app_root()
                if self.db_string == ":memory:":
                    db_path = ":memory:"
                else:
                    db_path = os.path.join(base_dir, self.db_string)
                    # REZALET ÖNLEYİCİ: Dizin yoksa oluştur
                    os.makedirs(os.path.dirname(db_path), exist_ok=True)
                
                import sys
                if getattr(sys, 'frozen', False) and not os.path.exists(db_path):
                    import shutil
                    bundled_db = os.path.join(sys._MEIPASS, self.db_string)
                    if os.path.exists(bundled_db):
                        try:
                            shutil.copy2(bundled_db, db_path)
                            logging.info(f"Paketlenmiş veritabanı başarıyla dışarı çıkarıldı: {db_path}")
                        except Exception as e:
                            logging.error(f"Veritabanı çıkarılamadı: {e}")
                            
                # Bağlan
                self.connection = sqlite3.connect(db_path, check_same_thread=False)
                self.connection.row_factory = sqlite3.Row
                
                # WAL MODU VE PERFORMANS AYARLARI
                self.connection.execute("PRAGMA journal_mode=WAL;")
                self.connection.execute("PRAGMA synchronous=NORMAL;")
                self._initialize_schema()
                
                logging.info(f"💾 Veritabanı hazır: {db_path}")
            else:
                logging.error("Sadece SQLite desteklenmektedir.")
        except Exception as e:
            logging.error(f"❌ Veritabanı hatası: {e}")
            self.connection = None
            
        return self.connection

    def _initialize_schema(self):
        """Tablolar yoksa oluşturur (Fallback)."""
        schema = [
            """CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT, 
                username TEXT UNIQUE NOT NULL, 
                password TEXT NOT NULL, 
                role TEXT NOT NULL, 
                permissions TEXT DEFAULT '*', 
                last_active TEXT, 
                ppolicy_version INTEGER DEFAULT 0
            )""",
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
            "CREATE TABLE IF NOT EXISTS departments (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)",
            "CREATE TABLE IF NOT EXISTS units (id INTEGER PRIMARY KEY AUTOINCREMENT, department_id INTEGER, name TEXT, FOREIGN KEY(department_id) REFERENCES departments(id))",
            "CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY AUTOINCREMENT, user_info TEXT, timestamp TEXT, action_type TEXT, result TEXT)",
            """CREATE TABLE IF NOT EXISTS licenses (
                id INTEGER PRIMARY KEY AUTOINCREMENT, 
                license_key TEXT UNIQUE NOT NULL, 
                assigned_to TEXT, 
                hwid TEXT, 
                status TEXT DEFAULT 'PENDING', 
                expiry_date TEXT, 
                created_at TEXT
            )"""
        ]
        for sql in schema:
            self.connection.execute(sql)
        
        # Varsayılan Admin kullanıcısı (yoksa)
        self.connection.execute("INSERT OR IGNORE INTO users (username, password, role) VALUES ('Admin', 'Admin', 'Admin')")
        self.connection.commit()

    def close(self):
        if self.connection:
            self.connection.close()
            self.connection = None

    def execute_query(self, query: str, parameters: tuple = ()) -> bool:
        try:
            if not self.connection: self.connect()
            cursor = self.connection.cursor()
            cursor.execute(query, parameters)
            self.connection.commit()
            return True
        except Exception as e:
            # duplicate column name gibi durumları logging.debug ile sessizce geçmek istersek burayı özelleştirebiliriz.
            # Ancak şu an şemamız temiz olduğu için normal bir ERROR kaydı faydalıdır.
            logging.error(f"Sorgu hatası: {e} | Sorgu: {query[:100]}")
            if self.connection: self.connection.rollback()
            return False

    def fetch_data(self, query: str, parameters: tuple = ()) -> list:
        try:
            if not self.connection: self.connect()
            cursor = self.connection.cursor()
            cursor.execute(query, parameters)
            return cursor.fetchall()
        except Exception as e:
            logging.error(f"Veri çekme hatası: {e}")
            return []
