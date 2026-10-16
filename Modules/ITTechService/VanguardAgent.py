import sys
import os
import time
import traceback
import logging
import ctypes

# Singleton Lock (Aynı anda sadece bir ajanın çalışmasını sağlar)
# Mutex ismi sistem genelinde benzersiz olmalıdır.
def is_already_running():
    mutex_name = "Global\\VanguardAgent_Singleton_Mutex"
    try:
        kernel32 = ctypes.windll.kernel32
        mutex = kernel32.CreateMutexW(None, False, mutex_name)
        if kernel32.GetLastError() == 183: # ERROR_ALREADY_EXISTS
            return True
        return False
    except:
        return False

if is_already_running():
    sys.exit(0)
# 1. KRİTİK HATA YAKALAYICI (DEBUG İÇİN)
def handle_exception(exc_type, exc_value, exc_tb):
    if issubclass(exc_type, KeyboardInterrupt):
        sys.__excepthook__(exc_type, exc_value, exc_tb)
        return
    
    # Hata dizinini hazırla
    log_dir = os.path.join(os.environ.get("ProgramData", "C:/ProgramData"), "VanguardService")
    if not os.path.exists(log_dir): os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, "agent_debug.log")
    
    error_msg = "".join(traceback.format_exception(exc_type, exc_value, exc_tb))
    try:
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"\n--- CRITICAL CRASH: {time.ctime()} ---\n")
            f.write(error_msg)
            f.write("-" * 50 + "\n")
    except:
        pass
    sys.__excepthook__(exc_type, exc_value, exc_tb)

sys.excepthook = handle_exception

# 2. BAĞIMLILIK KONTROLLERİ
if sys.platform == 'win32':
    try:
        import pynput.keyboard._win32
        import pynput.mouse._win32
    except ImportError:
        pass

# Konsol gizleme
try:
    import ctypes
    if sys.platform == 'win32' and not getattr(sys, 'frozen', False):
        hwnd = ctypes.windll.kernel32.GetConsoleWindow()
        if hwnd:
            ctypes.windll.user32.ShowWindow(hwnd, 0)
except:
    pass

from core.remote_client import RemoteClient

if __name__ == "__main__":
    manual_ip = '127.0.0.1'
    if len(sys.argv) > 1:
        manual_ip = sys.argv[1]
        
    client = RemoteClient(admin_ip=manual_ip)
    
    try:
        client.start()
    except Exception as e:
        # Bu kısım zaten sys.excepthook tarafından yakalanacaktır ama yine de tedbir amaçlı:
        error_info = traceback.format_exc()
        log_dir = os.path.join(os.environ.get("ProgramData", "C:/ProgramData"), "VanguardService")
        log_path = os.path.join(log_dir, "agent_debug.log")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"\n--- MAIN LOOP ERROR: {time.ctime()} ---\n{error_info}\n")
        
        # 5 saniye bekle ve kendini yeniden başlat
        time.sleep(5)
        try:
            if getattr(sys, 'frozen', False):
                os.execv(sys.executable, sys.argv)
            else:
                os.execv(sys.executable, ['python'] + sys.argv)
        except:
            sys.exit(1)
