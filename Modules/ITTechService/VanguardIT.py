# Dosya Adı: VanguardIT.py
import sys
import os
import ctypes
import time
import subprocess
import requests
import traceback
import logging
import logging.handlers
import datetime
import socket
import multiprocessing
from database.logger import write_log
from core.path_helper import get_app_root, get_resource_path

# ── Globals / Shared State ───────────────────────────────────────────────────
_windows = {}
logger = logging.getLogger("VanguardIT")
lic_mgr = None
db_conn = None
trial_timer = None

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

# UAC kontrolü SADECE EXE olarak çalışırken devreye girer
if getattr(sys, 'frozen', False) and not is_admin() and "--server" not in sys.argv:
    if "--elevated" not in sys.argv:
        args = sys.argv[1:] + ["--elevated"]
        ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, " ".join(args), None, 1)
        sys.exit()

# ── Log Ayarları ─────────────────────────────────────────────────────────────
def setup_logging():
    app_base = get_app_root()
    log_dir = os.path.join(app_base, 'logs')
    os.makedirs(log_dir, exist_ok=True)
    log_file = os.path.join(log_dir, f"app_{datetime.date.today().isoformat()}.log")

    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
        handlers=[
            logging.handlers.RotatingFileHandler(
                log_file, maxBytes=5*1024*1024, backupCount=3, encoding='utf-8'
            ),
            logging.StreamHandler(sys.stdout),
        ]
    )
    return log_file

# ── Yakalanmamış istisnalar ────────────────────────────────────────────────────
def _handle_exception(exc_type, exc_value, exc_tb):
    if issubclass(exc_type, KeyboardInterrupt):
        sys.__excepthook__(exc_type, exc_value, exc_tb)
        return
    
    error_msg = "".join(traceback.format_exception(exc_type, exc_value, exc_tb))
    logger.critical("Yakalanmamış istisna:\n" + error_msg)
    
    # Veritabanına yazmayı dene
    if db_conn:
        try:
            write_log(db_conn, "SİSTEM", "KRİTİK_HATA", f"Uygulama çöktü: {str(exc_value)[:200]}")
        except: pass

    # Kullanıcıya görsel uyarı (Eğer QApplication varsa)
    if QApplication.instance():
        QMessageBox.critical(None, "Kritik Çalışma Hatası", 
                             f"Uygulama beklenmedik bir hata nedeniyle durduruldu.\n\n"
                             f"Hata: {exc_value}\n\n"
                             f"Detaylar için 'logs' klasöründeki güncel log dosyasına bakınız.")
    
    sys.__excepthook__(exc_type, exc_value, exc_tb)

sys.excepthook = _handle_exception

from PySide6.QtWidgets import QApplication, QMessageBox
from ui.login_window import LoginWindow
from ui.main_window import MainWindow
from database.connection import DatabaseConnection
from database.models import DatabaseManager
from core.license_manager import LicenseManager
from ui.license_dialog import LicenseDialog
from PySide6.QtCore import QTimer

# ── Helper Functions ─────────────────────────────────────────────────────────

def start_license_server():
    """Starts the web_server.py in the background and waits until it's ready."""
    try:
        # Check if already running
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(('localhost', 5000)) == 0:
                logger.info("Lisans sunucusu zaten çalışıyor (Port 5000).")
                return None
        
        if getattr(sys, 'frozen', False):
            # EXE modunda kendi kendimizi --server bayrağıyla çağırıyoruz
            proc = subprocess.Popen([sys.executable, "--server"], 
                                    stdout=subprocess.DEVNULL, 
                                    stderr=subprocess.DEVNULL,
                                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        else:
            # Geliştirme modunda python ile web_server.py'yi çağırıyoruz
            srv_path = get_resource_path("web_server.py")
            proc = subprocess.Popen([sys.executable, srv_path], 
                                    stdout=subprocess.DEVNULL, 
                                    stderr=subprocess.DEVNULL,
                                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        
        # Web sunucusunu başlattık, ama artık hazır olmasını BEKLEMİYORUZ (Non-blocking)
        # Bu sayede masaüstü uygulaması anında açılacak.
        logger.info("Lisans sunucusu arka planda başlatıldı (Port 5000).")
        return proc
    except Exception as e:
        logger.error(f"Lisans sunucusu başlatılırken hata: {e}")
        return None

def show_license_dialog():
    dialog = LicenseDialog(lic_mgr)
    if dialog.exec() == LicenseDialog.Accepted:
        if trial_timer: trial_timer.stop()
        logger.info("Lisans başarıyla etkinleştirildi.")
        if 'login' in _windows:
            _windows['login'].set_licensed(True)
        if 'main' in _windows:
            _windows['main'].refresh_sidebar()

def on_trial_expired():
    logger.warning("5 dakikalık deneme süresi doldu.")
    QMessageBox.critical(None, "Süre Doldu", "Program kapatılacaktır. Lütfen lisansınızı etkinleştirin.")
    sys.exit(0)

def on_login_success(user_data):
    logger.info(f"Giriş başarılı: {user_data.get('username')}")
    try:
        if 'login' in _windows:
            _windows['login'].close()
        
        _windows['main'] = MainWindow(db_conn, user_data, lic_mgr)
        _windows['main'].showMaximized()
        logger.info("Ana pencere açıldı.")
    except Exception as e:
        logger.critical(f"Ana pencere açılırken hata: {e}\n{traceback.format_exc()}")
        QMessageBox.critical(None, "Kritik Hata", f"Uygulama açılırken hata oluştu:\n{e}")

# ── Main Entry Point ──────────────────────────────────────────────────────────

def main():
    global lic_mgr, db_conn, trial_timer
    
    app = QApplication(sys.argv)
    app.setApplicationName("IT Teknik Servis")
    
    log_file = setup_logging()
    
    # ── Klasör Yapılandırması ────────────────────────────────────────────────
    app_base = get_app_root()
    for d in ["screenshots", "logs", "backups"]:
        os.makedirs(os.path.join(app_base, d), exist_ok=True)
    
    srv_proc = start_license_server()

    try:
        db_conn = DatabaseConnection()
        if not db_conn.connect():
            raise RuntimeError("Veritabanı bağlantısı kurulamadı!")
        DatabaseManager(db_conn).initialize_database()
    except Exception as e:
        logger.critical(f"Veritabanı hatası: {e}")
        sys.exit(1)

    lic_mgr = LicenseManager()
    # Veritabanı üzerinden doğrudan lisans kontrolü yap (Hızlı açılış için kritik)
    is_licensed, msg = lic_mgr.check_license(db_conn)
    
    trial_timer = QTimer()
    trial_timer.setSingleShot(True)
    trial_timer.timeout.connect(on_trial_expired)

    if not is_licensed:
        logger.info(f"Lisans kısıtlaması: {msg}.")
        write_log(db_conn, "SİSTEM", "LİSANS", f"Deneme sürümü aktif: {msg}")
        trial_timer.start(5 * 60 * 1000)
        if msg == "Lisans bulunamadı":
            QMessageBox.warning(None, "Lisans Gerekli", "Program 5 dakika içerisinde kapanacaktır.\nLütfen tam sürüm için lisans anahtarınızı etkinleştirin.")
    else:
        write_log(db_conn, "SİSTEM", "LİSANS", "Lisans doğrulandı, tam sürüm aktif.")

    try:
        _windows['login'] = LoginWindow(db_conn, on_login_success, is_licensed)
        _windows['login'].activate_requested = show_license_dialog
        _windows['login'].show()
        write_log(db_conn, "SİSTEM", "AÇILIŞ", "Giriş ekranı başarıyla yüklendi.")
    except Exception as e:
        logger.critical(f"Giriş ekranı hatası: {e}")
        write_log(db_conn, "SİSTEM", "HATA", f"Giriş ekranı yüklenemedi: {e}")
        sys.exit(1)

    exit_code = app.exec()
    
    # ── GÜVENLİ KAPANIŞ ───────────────────────────────────────────────────
    logger.info("Uygulama kapatılıyor...")
    
    # Uzaktan kontrol sunucusunu durdur
    if 'main' in _windows and hasattr(_windows['main'], 'remote_server'):
        try:
            logger.info("Uzak yönetim sunucusu durduruluyor...")
            _windows['main'].remote_server.stop()
        except: pass
        
    if srv_proc: 
        logger.info("Lisans sunucusu durduruluyor...")
        srv_proc.terminate()
        
    sys.exit(exit_code)

if __name__ == "__main__":
    try:
        multiprocessing.freeze_support()
        if "--server" in sys.argv:
            # Web sunucusu modunda başlat
            from web_server import app as flask_app
            import logging
            logging.basicConfig(level=logging.INFO)
            flask_app.run(host='0.0.0.0', port=5000, debug=False)
        else:
            main()
    except Exception as e:
        # Son çare hata yakalayıcı (Log dosyasına yazmak için)
        with open("critical_startup_error.log", "a") as f:
            f.write(f"\n{time.ctime()} - FATAL ERROR: {e}\n{traceback.format_exc()}\n")
        print(f"FATAL ERROR: {e}")
        sys.exit(1)

