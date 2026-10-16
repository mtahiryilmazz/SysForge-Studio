# Dosya Adı: logger.py — Log yazma yardımcısı
import datetime
from database.connection import DatabaseConnection


def write_log(db_conn: DatabaseConnection, user: str, action: str, detail: str) -> None:
    """Sisteme log kaydı yazar.
    
    Args:
        db_conn: Veritabanı bağlantısı
        user:    Kullanıcı adı veya bilgisi
        action:  İşlem tipi — "EKLE" | "SİL" | "GÜNCELLE" | "GİRİŞ"
        detail:  İşlem detayı (örn: "Envanter: Dell Latitude #42")
    """
    ts = datetime.datetime.now().isoformat(sep=" ", timespec="seconds")
    try:
        db_conn.execute_query(
            "INSERT INTO logs (user_info, timestamp, action_type, result) VALUES (?,?,?,?)",
            (user, ts, action, detail)
        )
    except Exception:
        pass  # Log hatası asla ana işlemi durdurmasın
