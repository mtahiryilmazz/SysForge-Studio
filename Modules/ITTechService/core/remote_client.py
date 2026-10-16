import sys
import socket
import threading
import json
import time
import getpass
import platform
import subprocess
import logging
import os
import base64
import io
from pathlib import Path

try:
    import ctypes
except:
    pass

# Pynput: Fare ve Klavye Kontrolü İçin
try:
    from pynput.mouse import Button, Controller as MouseController
    from pynput.keyboard import Key, Controller as KeyboardController
except ImportError:
    # Ajan tarafında kütüphane eksikse hata vermemesi için fallback
    MouseController = None
    KeyboardController = None

# Yapılandırma ve Log Dizini Ayarı
CONFIG_DIR = Path(os.environ.get("ProgramData", "C:/ProgramData")) / "VanguardService"
CONFIG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = CONFIG_DIR / "agent_debug.log"
LAST_IP_FILE = CONFIG_DIR / "last_server.txt"

# Loglama Yapılandırması
logging.basicConfig(
    filename=str(LOG_FILE),
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class RemoteClient:
    def __init__(self, admin_ip='127.0.0.1', port=7777):
        self.admin_ip = admin_ip
        self.port = port
        self.conn = None
        self.running = True
        
        # Stream Ayarları
        self.is_streaming = False
        self.stream_quality = 50
        self.stream_scale = 1.0
        self.stream_thread = None
        
        # Kontrolcüler
        try:
            self.mouse = MouseController() if MouseController else None
            self.keyboard = KeyboardController() if KeyboardController else None
            logging.info(f"Pynput Kontrolcüler: Mouse={'OK' if self.mouse else 'Missing'}, Kbd={'OK' if self.keyboard else 'Missing'}")
        except Exception as e:
            self.mouse = None
            self.keyboard = None
            logging.error(f"Pynput başlatma hatası: {e}")
            
        logging.info(f"Ajan Başlatıldı. Varsayılan IP: {admin_ip}, Port: {port}")
        
    def send_error(self, message):
        """Hatayı sunucuya json olarak gönderir."""
        try:
            if self.conn:
                resp = json.dumps({"type": "error", "message": message}) + "\n"
                self.conn.sendall(resp.encode('utf-8'))
        except: pass

    def get_system_info(self):
        return {
            "hostname": platform.node(),
            "os": platform.system(),
            "user": getpass.getuser()
        }

    def _get_last_known_ip(self):
        if LAST_IP_FILE.exists():
            try:
                ip = LAST_IP_FILE.read_text().strip()
                if ip: return ip
            except: pass
        return None

    def _save_last_known_ip(self, ip):
        try:
            LAST_IP_FILE.write_text(ip)
        except: pass

    def start(self):
        logging.info("Bağlantı döngüsü başlatılıyor...")
        while self.running:
            try:
                server_ip = None
                
                # 1. ADIM: Sunucuyu Ağda Bul (UDP Discovery)
                logging.info("UDP Discovery başlatılıyor (Port 7778)...")
                server_ip = self.discover_server()
                
                if not server_ip:
                    last_ip = self._get_last_known_ip()
                    if last_ip:
                        logging.info(f"Discovery başarısız, hafızadaki IP deneniyor: {last_ip}")
                        server_ip = last_ip
                
                if not server_ip and self.admin_ip and self.admin_ip != '127.0.0.1':
                    logging.info(f"Manuel IP deneniyor: {self.admin_ip}")
                    server_ip = self.admin_ip

                if not server_ip:
                    time.sleep(5)
                    continue

                # 2. ADIM: Bulunan Sunucuya Bağlan (TCP)
                logging.info(f"Sunucuya bağlanılıyor: {server_ip}:{self.port}")
                self.conn = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                self.conn.settimeout(10)
                
                # TCP Keepalive: Bağlantının koptuğunu daha hızlı anlamak için
                try:
                    self.conn.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
                    # Windows özel: TCP Keepalive zamanlamasını ayarla (isteğe bağlı ama faydalı)
                    if platform.system() == "Windows":
                        self.conn.ioctl(socket.SIO_KEEPALIVE_VALS, (1, 30000, 3000)) # (active, time_ms, interval_ms)
                except: pass

                self.conn.connect((server_ip, self.port))
                self.conn.settimeout(45) # Komut gelmezse 45 saniyede bir timeout üret ki döngü kontrol edilebilsin

                
                self._save_last_known_ip(server_ip)
                logging.info(f"Bağlantı başarılı! Sunucu IP'si kaydedildi: {server_ip}")
                
                info = json.dumps(self.get_system_info()) + "\n"
                self.conn.sendall(info.encode('utf-8'))
                
                self.listen_for_commands()
            except Exception as e:
                logging.error(f"Bağlantı hatası: {e}. 5 saniye sonra tekrar denenecek.")
                self.is_streaming = False # Bağlantı koptuğunda yayını durdur
                if self.conn:
                    try: self.conn.close()
                    except: pass
                # Reconnection delay to prevent flapping
                time.sleep(5)

    def discover_server(self):
        """Ağdaki yetkili sunucu yayınını yakalar (UDP Discovery)."""
        disc_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            disc_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            # SO_BROADCAST yetkisi ekleyelim (bazi sistemlerde gerekebilir)
            try:
                disc_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            except: pass
            
            try:
                disc_sock.bind(('', 7778))
            except Exception as bind_err:
                logging.error(f"UDP Bind Hatası (Port 7778): {bind_err}. Güvenlik duvarı veya başka bir program engelliyor olabilir.")
                return None

            disc_sock.settimeout(2.0) # Faster timeout
            logging.info("UDP port 7778 dinleniyor...")
            
            start_time = time.time()
            while time.time() - start_time < 5.0: # Shorter but enough
                try:
                    data, addr = disc_sock.recvfrom(1024)
                    msg = data.decode('utf-8', errors='ignore')
                    
                    if msg.startswith("VANGUARD_SERVER"):
                        parts = msg.split("|")
                        if len(parts) >= 3 and parts[2] == "AUTH_KEY_123":
                            server_ip = addr[0]
                            logging.info(f"Sunucu yayını yakalandı: {server_ip} (Gerçek Kaynak)")
                            return server_ip
                except socket.timeout:
                    logging.debug("UDP Discovery zaman aşımı.")
                    continue # Do not break, try again until while loop ends
                except Exception as e:
                    logging.debug(f"UDP veri alma hatası: {e}")
        except Exception as e:
            logging.error(f"Discovery genel hata: {e}")
        finally:
            disc_sock.close()
        return None

    def listen_for_commands(self):
        logging.info("Komut dinleme moduna geçildi.")
        buffer = ""
        while self.running:
                try:
                    data = self.conn.recv(4096).decode('utf-8', errors='ignore')
                    if not data: 
                        logging.info("Sunucu bağlantıyı kesti (Boş veri).")
                        break
                    buffer += data
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        if line.strip():
                            threading.Thread(target=self.process_command, args=(line,), daemon=True).start()
                except socket.timeout:
                    # Normal timeout, bağlantı hala canlı olabilir ama sunucunun yaşadığından emin olmak için
                    # Bu noktada bir şey yapmaya gerek yok, döngü devam eder.
                    # Eğer çok uzun süre veri gelmezse TCP Keepalive zaten hata verecektir.
                    continue
                except Exception as e:
                    logging.error(f"Veri alımı sırasında hata: {e}")
                    break

                
    def process_command(self, line):
        try:
            cmd = json.loads(line)
            action = cmd.get("action")
            
            if action == "msg":
                message = cmd.get("text", "BT Servisinden bir mesajiniz var.")
                if platform.system() == "Windows":
                    # MB_OK(0) | MB_ICONINFORMATION(64) | MB_TOPMOST(262144) | MB_SETFOREGROUND(65536)
                    # Toplam: 327744 (0x50040)
                    ctypes.windll.user32.MessageBoxW(0, message, "Bilgi İşlem Merkezi - Uyarı", 0x50040)
                    
            elif action == "cmd":
                command = cmd.get("command", "echo nothing")
                subprocess.Popen(command, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                
            elif action == "get_ps":
                ps_list = []
                # psutil yüklü mü kontrol et
                psutil_available = False
                try:
                    import psutil
                    psutil_available = True
                except ImportError: pass
                
                if psutil_available:
                    try:
                        for proc in psutil.process_iter(['pid', 'name', 'username', 'memory_info']):
                            try:
                                info = proc.info
                                ps_list.append({
                                    "pid": info['pid'],
                                    "name": info.get('name', 'N/A'),
                                    "user": info.get('username', 'Sistem'),
                                    "mem": f"{info['memory_info'].rss / (1024*1024):.1f} MB" if info.get('memory_info') else "0 MB"
                                })
                            except: continue
                        logging.info(f"psutil ile {len(ps_list)} süreç listelendi.")
                    except Exception as e:
                        logging.error(f"psutil çalışma hatası: {e}")
                        psutil_available = False # Fallback'e zorla
                
                if not psutil_available:
                    if platform.system() == "Windows":
                        try:
                            logging.info("psutil yok veya hatalı, tasklist fallback kullanılıyor...")
                            output = subprocess.check_output("tasklist /FO CSV /NH", shell=True).decode('cp1254', errors='ignore')
                            import csv
                            import io
                            reader = csv.reader(io.StringIO(output))
                            for row in reader:
                                if len(row) >= 5:
                                    ps_list.append({"pid": row[1], "name": row[0], "user": "N/A", "mem": row[4]})
                            logging.info(f"tasklist ile {len(ps_list)} süreç listelendi.")
                        except Exception as ex:
                            self.send_error(f"Görev listesi alınamadı (psutil yok ve tasklist başarısız): {ex}")
                            return

                logging.info(f"Süreç listesi hazırlanıyor... (Mevcut sayı: {len(ps_list)})")
                resp_data = {"type": "ps_list", "data": ps_list}
                resp_json = json.dumps(resp_data) + "\n"
                self.conn.sendall(resp_json.encode('utf-8'))
                logging.info(f"Süreç listesi gönderildi: {len(ps_list)} adet.")


            elif action == "kill_ps":
                pid = cmd.get("pid")
                if pid:
                    logging.warning(f"Süreç sonlandırma isteği: PID {pid}")
                    if platform.system() == "Windows":
                        subprocess.run(f"taskkill /F /PID {pid}", shell=True)
                    else:
                        subprocess.run(f"kill -9 {pid}", shell=True)
            
            elif action == "ping":
                # Heartbeat: Baglantiyi canli tutmak icin boss gonderim
                pass

            elif action == "quick_action":
                mode = cmd.get("mode")
                logging.warning(f"Hızlı işlem tetiklendi: {mode}")
                if mode == "restart": subprocess.run("shutdown /r /t 5", shell=True)
                elif mode == "shutdown": subprocess.run("shutdown /s /t 5", shell=True)
                elif mode == "flush_dns": subprocess.run("ipconfig /flushdns", shell=True)
                elif mode == "empty_trash" and platform.system() == "Windows":
                    subprocess.run("powershell.exe -Command \"Clear-RecycleBin -Force -ErrorAction SilentlyContinue\"", shell=True)
                elif mode == "logoff" and platform.system() == "Windows":
                    subprocess.run("logoff", shell=True)

            elif action == "screen":
                try:
                    logging.info("Ekran görüntüsü talebi alındı.")
                    self.send_screenshot(quality=50, scale=1.5)
                except Exception as e:
                    self.send_error(f"Ekran yakalama hatası: {str(e)}")

            # === CANLI KONTROL KOMUTLARI ===
            elif action == "start_stream":
                # Eğer zaten yayındaysa, önce durdur ve temizle (Siyah ekranı önlemek için)
                if self.is_streaming:
                    logging.info("Aktif yayın sıfırlanıyor...")
                    self.is_streaming = False
                    time.sleep(0.5)

                self.stream_quality = cmd.get("quality", 50)
                self.stream_scale = cmd.get("scale", 1.5)
                self.is_streaming = True
                self.stream_thread = threading.Thread(target=self.stream_worker, daemon=True)
                self.stream_thread.start()
                # Handshake: Yayının başladığını onayla
                self.send_command({"type": "stream_info", "status": "started"})
                logging.info(f"Canlı yayın başlatıldı (Kalite: {self.stream_quality}, Ölçek: {self.stream_scale})")



            elif action == "stop_stream":
                self.is_streaming = False
                logging.info("Canlı yayın durduruldu.")

            elif action == "mouse":
                if not self.mouse: return
                x, y = cmd.get("x", 0), cmd.get("y", 0)
                m_action = cmd.get("m_action")
                btn = cmd.get("btn", "left")
                
                # Koordinatlara git
                self.mouse.position = (x, y)
                
                # Tıklama veya hareket
                if m_action == "click":
                    button = Button.left if btn == "left" else Button.right
                    self.mouse.click(button)
                elif m_action == "double_click":
                    self.mouse.click(Button.left, 2)
                    
            elif action == "keyboard":
                if not self.keyboard: return
                key_str = cmd.get("key")
                k_action = cmd.get("k_action", "press") # press, release, type
                
                logging.debug(f"Klavye komutu: {key_str} ({k_action})")
                
                # Özel tuşları ayrıştır (Key.enter -> keyboard.Key.enter)
                try:
                    if key_str == "cad":
                        # Ctrl+Alt+Del simülasyonu (Windows'ta kısıtlanmış olabilir ama ajan adminse çalışabilir)
                        with self.keyboard.pressed(Key.ctrl, Key.alt, Key.delete):
                            pass
                        return
                    elif key_str == "winr":
                        # Win+R (Çalıştır) kısayolu
                        with self.keyboard.pressed(Key.cmd, 'r'):
                            pass
                        return

                    target_key = key_str
                    if key_str.startswith("Key."):
                        attr = key_str.split(".")[1]
                        target_key = getattr(Key, attr)
                        
                    if k_action == "press":
                        self.keyboard.press(target_key)
                    elif k_action == "release":
                        self.keyboard.release(target_key)
                    elif k_action == "type":
                        self.keyboard.type(key_str)
                except Exception as e:
                    logging.error(f"Klavye simülasyon hatası: {e}")

            elif action == "get_diag":
                logging.info("Sistem tanılama talebi alındı.")
                diag = {
                    "psutil": "OK" if "psutil" in sys.modules else "Missing (Using Tasklist)",
                    "mss": "OK" if "mss" in sys.modules else "Missing (Using ImageGrab)",
                    "PIL": "OK" if "PIL" in sys.modules else "Missing",
                    "pynput": "OK" if "pynput" in sys.modules else "Missing",
                    "is_admin": ctypes.windll.shell32.IsUserAnAdmin() != 0 if platform.system() == "Windows" else "N/A",
                    "os": platform.platform(),
                    "resolution": "N/A"
                }
                try:
                    import mss
                    with mss.mss() as sct:
                        diag["monitors"] = len(sct.monitors)
                        if len(sct.monitors) > 0:
                            diag["resolution"] = f"{sct.monitors[0]['width']}x{sct.monitors[0]['height']}"
                except: 
                    diag["monitors"] = "Unknown"
                    try:
                        from PIL import ImageGrab
                        screen = ImageGrab.grab()
                        diag["resolution"] = f"{screen.size[0]}x{screen.size[1]} (Fallback)"
                    except: pass
                
                resp = json.dumps({"type": "diag", "data": diag}) + "\n"
                self.conn.sendall(resp.encode('utf-8'))

            elif action == "get_log":
                log_data = "Log dosyası bulunamadı."
                if LOG_FILE.exists():
                    with open(LOG_FILE, "r", encoding="utf-8", errors="ignore") as f:
                        log_data = f.read()[-5000:] # Son 5000 karakter
                resp = json.dumps({"type": "log_data", "log": log_data}) + "\n"
                self.conn.sendall(resp.encode('utf-8'))
                
        except Exception as e:
            logging.error(f"Komut işleme hatası: {e}")
            self.send_error(f"Komut işleme hatası: {e}")

    def stream_worker(self):
        """Canlı yayın thread'i."""
        while self.is_streaming and self.running:
            try:
                self.send_screenshot(quality=self.stream_quality, scale=self.stream_scale)
                # FPS Kontrolü: Kaliteye göre bekleme süresi
                time.sleep(0.3 if self.stream_quality > 50 else 0.1)
            except:
                break
        self.is_streaming = False

    def send_screenshot(self, quality=50, scale=1.5):
        """Ekran görüntüsünü yakalayıp gönderir (MSS veya ImageGrab fallback)."""
        try:
            import mss
            from PIL import Image
            with mss.mss() as sct:
                # Monitör kontrolü
                if not sct.monitors:
                    self.send_error("Monitör bulunamadı.")
                    return
                
                # Boyutları al (bazı sistemlerde monitor[1] yerine monitor[0] gerekebilir ama mss'de 0 tüm ekranı kapsar)
                main_mon = sct.monitors[1] if len(sct.monitors) > 1 else sct.monitors[0]
                sct_img = sct.grab(main_mon)
                
                img = Image.frombytes("RGB", sct_img.size, sct_img.bgra, "raw", "BGRX")
                
                # Boyutlandırma (Performans için küçültme)
                if scale > 1.0:
                    new_size = (int(img.width / scale), int(img.height / scale))
                    img = img.resize(new_size, Image.LANCZOS)
                
                buffer_img = io.BytesIO()
                img.save(buffer_img, format="JPEG", quality=quality)
                encoded = base64.b64encode(buffer_img.getvalue()).decode('utf-8')
                
                # JSON paketi oluştur
                resp_data = {
                    "type": "screen_data", 
                    "image": encoded,
                    "resolution": {"w": sct_img.width, "h": sct_img.height}
                }
                resp = json.dumps(resp_data) + "\n"
                
                if self.conn:
                    try:
                        self.conn.sendall(resp.encode('utf-8'))
                    except Exception as send_err:
                        logging.error(f"TCP üzerinden ekran gönderilemedi: {send_err}")
                        self.is_streaming = False
        except ImportError:
            # MSS yoksa PIL ImageGrab yedek mekanizması
            try:
                from PIL import Image, ImageGrab
                img = ImageGrab.grab()
                
                # Boyutlandırma
                if scale > 1.0:
                    new_size = (int(img.width / scale), int(img.height / scale))
                    img = img.resize(new_size, Image.LANCZOS)
                
                buffer_img = io.BytesIO()
                img.save(buffer_img, format="JPEG", quality=quality)
                encoded = base64.b64encode(buffer_img.getvalue()).decode('utf-8')
                
                resp_data = {
                    "type": "screen_data",
                    "image": encoded,
                    "resolution": {"w": img.width, "h": img.height}
                }
                
                resp = json.dumps(resp_data) + "\n"
                if self.conn:
                    self.conn.sendall(resp.encode('utf-8'))
            except Exception as e:
                self.send_error(f"Ekran yakalama yedeği (ImageGrab) hatası: {e}")
                self.is_streaming = False
        except Exception as e:
            err_msg = f"Ekran yakalama/gönderim hatası: {e}"
            logging.error(err_msg)
            self.send_error(err_msg)
            # Hata devam ederse yayını durdur ki döngü boşa dönmesin
            self.is_streaming = False 

    def stop(self):
        logging.info("Ajan durduruluyor...")
        self.running = False
        self.is_streaming = False
        if self.conn:
            try: self.conn.close()
            except: pass
