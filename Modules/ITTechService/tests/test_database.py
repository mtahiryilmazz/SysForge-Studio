# Dosya Adı: test_database.py
import sys
import os
import unittest

# Proje ana dizinini Python path'ine ekle
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.connection import DatabaseConnection
from database.models import DatabaseManager

class TestDatabase(unittest.TestCase):
    def setUp(self):
        # Bellekte (InMemory) geçici bir veritabanı ile test
        self.db = DatabaseConnection(db_type="sqlite", db_string=":memory:")
        self.db.connect()
        self.manager = DatabaseManager(self.db)

    def test_connection_and_init(self):
        # Bağlantı başarılı mı?
        self.assertIsNotNone(self.db.connection)
        
        # Tablolar oluşturulabildi mi?
        result = self.manager.initialize_database()
        self.assertTrue(result)
        
        # Admin kullanıcısı eklenmiş mi?
        rows = self.db.fetch_data("SELECT * FROM users WHERE username='Admin'")
        self.assertEqual(len(rows), 1)

    def tearDown(self):
        self.db.close()

if __name__ == '__main__':
    unittest.main()

# Açıklama: Veritabanı bağlantı ve model katmanlarının in-memory (sanal bellek)
# üzerinde çalışabildiğini doğrulayan birim test dosyasıdır.
