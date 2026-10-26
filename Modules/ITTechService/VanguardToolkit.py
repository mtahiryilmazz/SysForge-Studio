import sys
import os
import random
import string
import datetime
import threading
import subprocess
import json
import shutil
from pathlib import Path

# ── STARTUP DEBUG LOG ────────────────────────────────────────────────────────
DEBUG_LOG = "toolkit_startup_debug.log"
with open(DEBUG_LOG, "w", encoding="utf-8") as f:
    f.write(f"VANGUARD Toolkit Startup Log - {datetime.datetime.now()}\n")
    f.write(f"CWD: {os.getcwd()}\n")
    f.write(f"Python: {sys.version}\n")

try:
    # Add project root to path
    sys.path.append(os.path.abspath(os.path.dirname(__file__)))

    from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                                 QHBoxLayout, QPushButton, QLabel, QStackedWidget, 
                                 QFrame, QTableWidget, QTableWidgetItem, QHeaderView,
                                 QMessageBox, QTextEdit, QProgressBar, 
                                 QLineEdit, QInputDialog, QGridLayout, QComboBox)
    from PySide6.QtCore import Qt, Signal, QObject, QTimer, QSize
    from PySide6.QtGui import QFont, QIcon, QColor, QKeySequence, QShortcut, QPixmap, QPainter
    from PySide6.QtSvg import QSvgRenderer
    import requests

    # Attempt to load pyotp for 2FA
    try:
        import pyotp
    except ImportError:
        pyotp = None

    from ui.premium_styles import PremiumStyles
    from ui.components.ui_utils import ModernToggle
    from database.connection import DatabaseConnection
    from ui.components.users_page import UsersPage

    with open(DEBUG_LOG, "a", encoding="utf-8") as f:
        f.write("Imports successful.\n")

except Exception as e:
    with open(DEBUG_LOG, "a", encoding="utf-8") as f:
        f.write(f"CRITICAL IMPORT ERROR: {e}\n")
    raise

# ── Signals for background workers ───────────────────────────────────────────
class WorkerSignals(QObject):
    log = Signal(str)
    progress = Signal(int)
    finished = Signal(int)

# ── Theme Toggle Widget (Swipe Style) ──────────────────────────────────────────
# ThemeToggle artik ModernToggle'dan turer veya onunla degistirilir
class ThemeToggle(ModernToggle):
    def __init__(self, parent=None):
        super().__init__(parent, width=34) # Ana menudekiyle ayni boyut

# ── 1. License Manager Widget (RESTORED THEME) ────────────────────────────────
class LicenseTab(QFrame):
    def __init__(self, db_conn):
        super().__init__()
        self.db = db_conn
        self.setObjectName("Card")
        self.init_ui()
        self.refresh_data()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        header = QHBoxLayout()
        title = QLabel("🔑 Lisans Yönetim Paneli")
        title.setStyleSheet(PremiumStyles.title_style())
        header.addWidget(title)
        
        btn_gen = QPushButton("➕ Yeni Lisans Üret")
        btn_gen.setStyleSheet(PremiumStyles.button_style())
        btn_gen.setCursor(Qt.PointingHandCursor)
        btn_gen.clicked.connect(self.generate_new_key)
        header.addWidget(btn_gen, alignment=Qt.AlignRight)
        layout.addLayout(header)

        desc = QLabel("Sistemdeki lisans anahtarlarını, durumlarını ve HWID eşleşmelerini kontrol edin.")
        desc.setStyleSheet(PremiumStyles.subtitle_style())
        layout.addWidget(desc)

        self.table = QTableWidget(0, 7)
        self.table.setHorizontalHeaderLabels(["ID", "ANAHTAR", "ATANAN", "DURUM", "HWID", "TARİH", "İŞLEM"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeToContents) 
        self.table.horizontalHeader().setSectionResizeMode(6, QHeaderView.ResizeToContents)
        self.table.verticalHeader().hide() 
        # Table styles are set in apply_global_styles or here using dynamic properties
        self.update_table_style()
        layout.addWidget(self.table)

        btn_refresh = QPushButton("🔄 Listeyi Yenile")
        btn_refresh.setFixedWidth(150)
        btn_refresh.setStyleSheet(PremiumStyles.button_style() + "background-color: #313244;")
        btn_refresh.clicked.connect(self.refresh_data)
        layout.addWidget(btn_refresh)

    def update_table_style(self):
        t = PremiumStyles.get_theme()
        self.table.setStyleSheet(f"""
            QTableWidget {{ 
                background-color: {t['surface']}; 
                color: {t['text']}; 
                border: 1px solid {t['border']}; 
                gridline-color: {t['border']};
                border-radius: 8px;
                font-size: 13px;
            }}
            QHeaderView::section {{ 
                background-color: {t['bg']}; 
                color: {t['primary']}; 
                padding: 12px; 
                border: none; 
                font-weight: bold;
                font-size: 12px;
            }}
        """)

    def refresh_data(self):
        try:
            lics = self.db.fetch_data("SELECT * FROM licenses ORDER BY id DESC")
            self.table.setRowCount(0)
            for r in lics:
                row = self.table.rowCount()
                self.table.insertRow(row)
                d = dict(r)
                self.table.setItem(row, 0, QTableWidgetItem(str(d['id'])))
                self.table.setItem(row, 1, QTableWidgetItem(d['license_key']))
                self.table.setItem(row, 2, QTableWidgetItem(d['assigned_to'] or "Boş"))
                
                status_item = QTableWidgetItem(d['status'])
                if d['status'] == 'ACTIVE': status_item.setForeground(QColor("#3b82f6")) # Profesyonel Mavi
                elif d['status'] == 'REVOKED': status_item.setForeground(QColor("#f38ba8")) # Yumuak Kirmizi
                self.table.setItem(row, 3, status_item)
                
                self.table.setItem(row, 4, QTableWidgetItem(d['hwid'] or "—"))
                self.table.setItem(row, 5, QTableWidgetItem(d['created_at']))
                
                # SİMGELERİN GÖRÜNMESİ İÇİN YÜKSEK GÖRÜNÜRLÜKLÜ BUTONLAR
                act_w = QWidget()
                act_l = QHBoxLayout(act_w)
                act_l.setContentsMargins(4, 2, 4, 2)
                act_l.setSpacing(6)
                
                def make_btn(text, color, hint):
                    b = QPushButton(text)
                    b.setToolTip(hint)
                    b.setFixedSize(32, 26)
                    b.setStyleSheet(f"background-color: {color}; color: white; border-radius: 4px; font-weight: bold; font-size: 11px;")
                    b.setCursor(Qt.PointingHandCursor)
                    return b

                b_copy = make_btn("📋", "#3b82f6", "Kopyala")
                b_copy.clicked.connect(lambda chk=False, k=d['license_key']: QApplication.clipboard().setText(k))
                
                b_tog = make_btn("🔁", "#f59e0b", "Aktif/Pasif Yap")
                b_tog.clicked.connect(lambda chk=False, lid=d['id'], s=d['status']: self.toggle_status(lid, s))
                
                b_del = make_btn("🗑️", "#ef4444", "SİL")
                b_del.clicked.connect(lambda chk=False, lid=d['id']: self.delete_license(lid))
                
                act_l.addWidget(b_copy); act_l.addWidget(b_tog); act_l.addWidget(b_del)
                self.table.setCellWidget(row, 6, act_w)
        except Exception as e: print(f"Refresh error: {e}")

    def delete_license(self, lid):
        if QMessageBox.critical(self, "Onay", f"ID {lid} olan lisansı sileceksiniz. Devam?", QMessageBox.Yes|QMessageBox.No) == QMessageBox.Yes:
            self.db.execute_query("DELETE FROM licenses WHERE id=?", (lid,))
            self.refresh_data()

    def toggle_status(self, lid, s):
        new_s = 'REVOKED' if s != 'REVOKED' else 'ACTIVE'
        self.db.execute_query("UPDATE licenses SET status=? WHERE id=?", (new_s, lid))
        self.refresh_data()

    def generate_new_key(self):
        name, ok = QInputDialog.getText(self, "Lisans Üret", "Kime Atanacak?")
        if ok and name.strip():
            key = '-'.join([''.join(random.choices(string.ascii_uppercase + string.digits, k=4)) for _ in range(4)])
            self.db.execute_query("INSERT INTO licenses (license_key, assigned_to, status, created_at) VALUES (?,?,'PENDING',?)", 
                                (key, name.strip(), datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")))
            QMessageBox.information(self, "Başarılı", f"Anahtar: {key}")
            self.refresh_data()

# ── 2. EXE Builder Tab ────────────────────────────────────────────────────────
class BuilderTab(QFrame):
    def __init__(self):
        super().__init__()
        self.setObjectName("Card")
        self.signals = WorkerSignals()
        self.signals.log.connect(self.append_log)
        self.selected_color = "#0078D4"
        self.selected_preset_icon = "settings"
        self.selected_icon = "static/assets/builder/settings_default.ico"
        self.signals.finished.connect(lambda: self.progress.setVisible(False))
        self.init_ui()
        threading.Thread(target=self.init_icon_assets, daemon=True).start()

    def init_ui(self):
        layout = QVBoxLayout(self)
        title = QLabel("📦 Project Builder (EXE)")
        title.setStyleSheet(PremiumStyles.title_style())
        layout.addWidget(title)
        
        desc = QLabel("PyInstaller kullanarak tek parça taşınabilir dosyalar oluşturun.")
        desc.setStyleSheet(PremiumStyles.subtitle_style())
        layout.addWidget(desc)

        btn_box = QHBoxLayout()
        for name, file in [("Vanguard IT", "VanguardIT.py"), ("Vanguard Agent", "VanguardAgent.py"), ("Vanguard Agent\n(Legacy Win 7/8)", "VanguardAgent_Legacy"), ("Senkron Aracı", "github_sync.py"), ("Toolkit", "VanguardToolkit.py")]:
            btn = QPushButton(f"{name}\nPaketle")
            btn.setFixedHeight(60)
            btn.setStyleSheet(PremiumStyles.get_button_style())
            if "Legacy" in name:
                btn.clicked.connect(lambda chk=False: self.start_build("VanguardAgent.py", legacy=True))
                btn.setStyleSheet(PremiumStyles.get_button_style() + "border: 1px solid #f9e2af; color: #f9e2af;")
            else:
                btn.clicked.connect(lambda chk=False, f=file: self.start_build(f))
            btn_box.addWidget(btn)
        layout.addLayout(btn_box)

        # Open EXE Directory Button
        open_dir_row = QHBoxLayout()
        self.btn_open_dist = QPushButton("📂  EXE Dizinini (dist) Aç")
        self.btn_open_dist.setStyleSheet(PremiumStyles.get_button_style() + "background-color: #475569;")
        self.btn_open_dist.clicked.connect(self.open_dist_folder)
        open_dir_row.addWidget(self.btn_open_dist)
        layout.addLayout(open_dir_row)

        # --- Ajan Özelleştirme (Stealth) ---
        stealth_group = QFrame()
        stealth_group.setObjectName("StealthCard")
        stealth_layout = QVBoxLayout(stealth_group)
        
        stealth_title = QLabel("⚙️  Ajan Özelleştirme (Stealth Build)")
        stealth_title.setStyleSheet("font-weight: bold; color: #89b4fa; font-size: 14px;")
        stealth_layout.addWidget(stealth_title)
        
        row1 = QHBoxLayout()
        self.preset_combo = QComboBox()
        self.preset_combo.addItems([
            "🛡️ Güvenlik (SecurityHealthService)",
            "🔊 Ses Sistemi (WinAudioEndpoint)",
            "⚙️ Sistem Görevi (TaskHostW)",
            "💾 Depolama (StorageService)",
            "🖥️ Vanguard IT (Yönetim)",
            "💼 Vanguard Toolkit (Geliştirici)",
            "🔄 Senkron Aracı",
            "🛠️ Özel Tanımla..."
        ])
        self.preset_combo.currentIndexChanged.connect(self.on_preset_changed)
        row1.addWidget(QLabel("Hazır Şablon:"))
        row1.addWidget(self.preset_combo, 1)
        
        # --- Renk Paleti ---
        palette_layout = QHBoxLayout()
        palette_layout.addWidget(QLabel("Renk:"))
        self.color_buttons = []
        colors = [("#FFFFFF", "Beyaz"), ("#0078D4", "Mavi"), ("#45475a", "Gri"), ("#a6e3a1", "Yeşil"), ("#f38ba8", "Kırmızı")]
        for hex_code, name in colors:
            btn = QPushButton()
            btn.setFixedSize(24, 24)
            btn.setCursor(Qt.PointingHandCursor)
            btn.setToolTip(name)
            btn.setStyleSheet(f"background-color: {hex_code}; border-radius: 12px; border: 2px solid {PremiumStyles.get_theme()['primary'] if hex_code == '#0078D4' else 'transparent'};")
            btn.clicked.connect(lambda chk=False, h=hex_code: self.change_icon_color(h))
            palette_layout.addWidget(btn)
            self.color_buttons.append((btn, hex_code))
        row1.addLayout(palette_layout)

        self.btn_pick_icon = QPushButton("📁 Özel İkon...")
        self.btn_pick_icon.clicked.connect(self.pick_icon)
        self.btn_pick_icon.setStyleSheet("background-color: #45475a;")
        row1.addWidget(self.btn_pick_icon)
        stealth_layout.addLayout(row1)
        
        row2 = QHBoxLayout()
        self.inp_name = QLineEdit("SecurityHealthService")
        self.inp_name.setPlaceholderText("EXE Dosya Adı")
        self.inp_desc = QLineEdit("Windows Security Health Service")
        self.inp_desc.setPlaceholderText("Açıklama")
        self.inp_comp = QLineEdit("Microsoft Corporation")
        self.inp_comp.setPlaceholderText("Şirket")
        
        row2.addWidget(QLabel("Şirket:"))
        row2.addWidget(self.inp_comp)
        stealth_layout.addLayout(row2)

        # --- Legacy Ayarları ---
        legacy_frame = QFrame()
        legacy_frame.setStyleSheet("background-color: #313244; border-radius: 8px; margin-top: 10px; padding: 10px;")
        legacy_layout = QVBoxLayout(legacy_frame)
        
        leg_info = QLabel("🪟 Legacy (Windows 7/8) Paketleme Ayarları")
        leg_info.setStyleSheet("font-weight: bold; color: #f9e2af;")
        legacy_layout.addWidget(leg_info)
        
        default_py = os.path.expandvars(r"%LOCALAPPDATA%\Programs\Python\Python38\python.exe")
        self.inp_py38 = QLineEdit(default_py if os.path.exists(default_py) else "")
        self.inp_py38.setPlaceholderText("Python 3.8.x executable yolu (örn: C:\\Python38\\python.exe)")
        self.inp_py38.setStyleSheet("background: #1e1e2e; color: #cdd6f4; border: 1px solid #45475a; padding: 4px;")
        
        btn_browse_py = QPushButton("Gözat...")
        btn_browse_py.clicked.connect(self.browse_py38)
        btn_browse_py.setStyleSheet("max-width: 80px; padding: 4px;")
        
        py_row.addWidget(QLabel("Python 3.8 Yolu:"))
        py_row.addWidget(self.inp_py38)
        py_row.addWidget(btn_browse_py)
        legacy_layout.addLayout(py_row)
        
        leg_hint = QLabel("💡 Not: Win 7 desteği için sisteminizde Python 3.8.10 kurulu olmalı.\nÖnce şunu çalıştırın: python -m pip install --upgrade pip\nSonra: pip install pyinstaller mss psutil Pillow pynput")
        leg_hint.setStyleSheet("font-size: 10px; color: #f9e2af; font-style: italic;")
        leg_hint.setWordWrap(True)
        legacy_layout.addWidget(leg_hint)
        
        stealth_layout.addWidget(legacy_frame)
        
        layout.addWidget(stealth_group)

        self.progress = QProgressBar()
        self.progress.setRange(0, 0)
        self.progress.setVisible(False)
        layout.addWidget(self.progress)

        self.console = QTextEdit()
        self.console.setReadOnly(True)
        self.console.setStyleSheet(PremiumStyles.log_style())
        layout.addWidget(self.console)
        
    def open_dist_folder(self):
        dist_path = os.path.join(os.getcwd(), "dist")
        if not os.path.exists(dist_path): os.makedirs(dist_path)
        os.startfile(dist_path)

    def append_log(self, t): self.console.append(t)

    def on_preset_changed(self, index):
        presets = [
            ("SecurityHealthService", "Windows Security Health Service", "Microsoft Corporation", "shield"),
            ("WinAudioEndpoint", "Windows Audio Graph Engine", "Microsoft Corporation", "speaker"),
            ("TaskHostW", "Windows Task Host", "Microsoft Corporation", "settings"),
            ("StorageService", "Microsoft Storage Service", "Microsoft Corporation", "hard-drive"),
            ("VanguardIT", "Vanguard IT Management System", "Vanguard Security", "monitor"),
            ("VanguardToolkit", "Vanguard Developer Toolkit", "Vanguard Security", "briefcase"),
            ("VanguardSync", "Vanguard GitHub Sync Utility", "Vanguard Security", "refresh-ccw")
        ]
        if index < len(presets):
            name, desc, comp, icon = presets[index]
            self.inp_name.setText(name)
            self.inp_desc.setText(desc)
            self.inp_comp.setText(comp)
            self.selected_preset_icon = icon
            # İkonu senkron üret ki build eski ikonu kullanmasın
            self.generate_colored_icon()

    def change_icon_color(self, hex_code):
        self.selected_color = hex_code
        for btn, h in self.color_buttons:
            btn.setStyleSheet(f"background-color: {h}; border-radius: 12px; border: 2px solid {PremiumStyles.get_theme()['primary'] if h == hex_code else 'transparent'};")
        self.generate_colored_icon()

    def init_icon_assets(self):
        # Otomatik SVG indirme
        base_url = "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/"
        icons = ["shield", "settings", "speaker", "hard-drive", "monitor", "briefcase", "refresh-ccw"]
        os.makedirs("static/assets/builder/raw", exist_ok=True)
        
        for icon in icons:
            path = f"static/assets/builder/raw/{icon}.svg"
            if not os.path.exists(path):
                self.append_log(f"[*] {icon}.svg indiriliyor...")
                try:
                    r = requests.get(base_url + f"{icon}.svg", timeout=10)
                    if r.status_code == 200:
                        with open(path, "w", encoding="utf-8") as fs: fs.write(r.text)
                except Exception as e: self.append_log(f"[!] İndirme hatası ({icon}): {e}")
        
        self.generate_colored_icon()

    def generate_colored_icon(self):
        svg_path = f"static/assets/builder/raw/{self.selected_preset_icon}.svg"
        if not os.path.exists(svg_path): return
        
        try:
            with open(svg_path, "r", encoding="utf-8") as f:
                svg_data = f.read()
            
            # Renk değişimi: Lucide stroke tabanlıdır
            svg_data = svg_data.replace('stroke="currentColor"', f'stroke="{self.selected_color}"')
            
            # Render to ICO
            from PySide6.QtSvg import QSvgRenderer
            from PySide6.QtGui import QImage, QPainter
            from PySide6.QtCore import QBuffer, QIODevice
            from PIL import Image
            import io

            renderer = QSvgRenderer(svg_data.encode('utf-8'))
            img = QImage(256, 256, QImage.Format_ARGB32)
            img.fill(Qt.transparent)
            painter = QPainter(img)
            renderer.render(painter)
            painter.end()

            buffer = QBuffer()
            buffer.open(QIODevice.WriteOnly)
            img.save(buffer, "PNG")
            png_data = buffer.data().data()
            
            pil_img = Image.open(io.BytesIO(png_data))
            ico_path = f"static/assets/builder/{self.selected_preset_icon}_{self.selected_color.replace('#', '')}.ico"
            pil_img.save(ico_path, format="ICO", sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
            
            self.selected_icon = ico_path
            # Başarılı üretim logu
            self.signals.log.emit(f"[*] Özel ikon hazırlandı: {os.path.basename(ico_path)}")
        except Exception as e:
            self.signals.log.emit(f"[!] İkon üretim hatası: {e}")

    def browse_py38(self):
        from PySide6.QtWidgets import QFileDialog
        path, _ = QFileDialog.getOpenFileName(self, "Python 3.8 Executable Seç", "", "Executable (python.exe)")
        if path:
            self.inp_py38.setText(path)

    def pick_icon(self):
        from PySide6.QtWidgets import QFileDialog
        path, _ = QFileDialog.getOpenFileName(self, "İkon Seç", "", "Icon Files (*.ico)")
        if path:
            self.selected_icon = path
            self.append_log(f"[*] Yeni ikon seçildi: {os.path.basename(path)}")

    def start_build(self, f, legacy=False):
        self.console.clear()
        self.progress.setVisible(True)
        threading.Thread(target=self.run_pyinst, args=(f, legacy), daemon=True).start()

    def run_pyinst(self, f, legacy=False):
        import subprocess
        python_exe = sys.executable
        version_file_to_clean = None
        spec_file_to_clean = None
        
        if legacy:
            python_exe = self.inp_py38.text().strip()
            if not python_exe or not os.path.exists(python_exe):
                self.append_log("[!] HATA: Legacy build için geçerli bir Python 3.8 yolu seçilmedi!")
                return
            
            self.append_log(f"[*] Ortam doğrulanıyor: {python_exe}")
            try:
                # 1. PyInstaller Kontrolü
                check_pi = subprocess.run([python_exe, "-m", "PyInstaller", "--version"], 
                                         capture_output=True, text=True, timeout=10)
                if check_pi.returncode != 0:
                    self.append_log("[!] HATA: Seçilen Python ortamında PyInstaller yüklü değil!")
                    self.append_log(f"[*] Hata Çıktısı: {check_pi.stderr.strip() or check_pi.stdout.strip()}")
                    self.append_log(f"[*] Çözüm: CMD açın ve şu komutu çalıştırın:\n\"{python_exe}\" -m pip install pyinstaller")
                    return
                self.append_log(f"[*] PyInstaller Doğrulandı: {check_pi.stdout.strip()}")
                
                # 2. Kütüphane Kontrolü
                check_libs = subprocess.run([python_exe, "-c", "import mss, psutil, PIL, pynput"], 
                                           capture_output=True, text=True, timeout=10)
                if check_libs.returncode != 0:
                    self.append_log("[!] HATA: Gerekli kütüphaneler (mss, psutil, PIL, pynput) eksik!")
                    self.append_log(f"[*] Hata Çıktısı: {check_libs.stderr.strip()}")
                    self.append_log(f"[*] Çözüm: CMD açın ve şu komutu çalıştırın:\n\"{python_exe}\" -m pip install mss psutil Pillow pynput")
                    return
                self.append_log("[*] Tüm kütüphaneler doğrulandı.")
            except Exception as ve:
                self.append_log(f"[!] Doğrulama sırasında hata: {ve}")
                return
            
            self.append_log(f"[*] Legacy Build başlatılıyor. Kullanılan yorumlayıcı: {python_exe}")

        icon_path = self.selected_icon
        if icon_path:
            icon_path = os.path.abspath(icon_path)
            self.append_log(f"[*] Paketleme için seçilen ikon: {os.path.basename(icon_path)}")
            
        target_name = self.inp_name.text() if self.inp_name.text() else f.split('.')[0]
        
        version_file = self.create_version_info(target_name, self.inp_desc.text(), self.inp_comp.text())

        # Ajan için özel durum: Hazırladığımız .spec dosyasını temel alıp dinamik bir tane üretmeliyiz
        if f == "VanguardAgent.py":
            spec_base = "VanguardAgent.spec"
            if os.path.exists(spec_base):
                self.append_log(f"[*] Temel spec dosyası işleniyor: {spec_base}")
                try:
                    with open(spec_base, "r", encoding="utf-8") as fs:
                        spec_content = fs.read()
                    
                    # Dinamik alanları değiştir/ekle
                    # 1. EXE ismi
                    spec_content = spec_content.replace("name='VanguardAgent'", f"name='{target_name}'")
                    
                    # 2. İkon ve Versiyon (EXE() bloğunun içine eklenmeli)
                    icon_line = f"icon='{icon_path.replace('\\', '/')}'" if icon_path else "icon=None"
                    ver_line = f"version='{version_file}'" if version_file else "version=None"
                    
                    # EXE bloğunda name'den sonrasına ekleme yapalım (Basit string manipülasyonu)
                    insertion_point = f"name='{target_name}',"
                    spec_content = spec_content.replace(insertion_point, f"{insertion_point}\n    {icon_line},\n    {ver_line},")
                    
                    temp_spec = f"dist_{target_name}.spec"
                    with open(temp_spec, "w", encoding="utf-8") as fs:
                        fs.write(spec_content)
                    
                    cmd = [python_exe, "-m", "PyInstaller", "--noconfirm", "--clean", temp_spec]
                    version_file_to_clean = version_file
                    spec_file_to_clean = temp_spec
                except Exception as e:
                    self.append_log(f"[!] Spec hazırlama hatası: {e}")
                    return
            else:
                self.append_log("[!] UYARI: VanguardAgent.spec bulunamadı! Standart komutla devam ediliyor.")
                cmd = [python_exe, "-m", "PyInstaller", "--noconfirm", "--clean", "--onefile", "--windowed", "--name", target_name]
                if icon_path: cmd += ["--icon", icon_path]
                if version_file: cmd += ["--version-file", version_file]
                
                sep = os.pathsep
                for p in ["core", "modules"]:
                    if os.path.exists(p): cmd += ["--add-data", f"{p}{sep}{p}"]
                cmd.append(f)
                version_file_to_clean = version_file
                spec_file_to_clean = None
        else:
            cmd = [python_exe, "-m", "PyInstaller", "--noconfirm", "--clean", "--onefile", "--windowed", "--name", target_name]
            if icon_path: cmd += ["--icon", icon_path]
            if version_file: cmd += ["--version-file", version_file]
            
            if f == "VanguardIT.py" or f == "VanguardToolkit.py":
                if f == "VanguardToolkit.py": cmd += ["--collect-all", "PySide6"]
                sep = os.pathsep
                for p in ["ui", "modules", "core", "database", "static", "templates"]:
                    if os.path.exists(p): cmd += ["--add-data", f"{p}{sep}{p}"]
                for p in ["it_tech_service.db", "license.json", "settings.json"]:
                    if os.path.exists(p): cmd += ["--add-data", f"{p}{sep}."]
            cmd.append(f)
            version_file_to_clean = version_file
            spec_file_to_clean = None
        
        try:
            # Komutu tam olarak loglayalım (Debug için çok önemli)
            clean_cmd = " ".join([f'"{x}"' if " " in x else x for x in cmd])
            self.append_log(f"[*] Paketleme komutu:\n{clean_cmd}")
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            for line in iter(p.stdout.readline, ''): self.signals.log.emit(line.strip())
            p.wait()
            self.signals.finished.emit(0)
        except Exception as e:
            self.signals.log.emit(str(e))
        finally:
            # Temizlik (İşlem bittiğinde veya hata aldığında mutlaka çalışır)
            if version_file_to_clean and os.path.exists(version_file_to_clean):
                try: os.remove(version_file_to_clean)
                except: pass
            if spec_file_to_clean and os.path.exists(spec_file_to_clean):
                try: os.remove(spec_file_to_clean)
                except: pass

    def create_version_info(self, name, desc, comp):
        # PyInstaller version info file content
        content = f"""
VSVersionInfo(
  ffi=FixedFileInfo(
    filevers=(1, 0, 0, 0),
    prodvers=(1, 0, 0, 0),
    mask=0x3f,
    flags=0x0,
    OS=0x40004,
    fileType=0x1,
    subtype=0x0,
    date=(0, 0)
    ),
  kids=[
    StringTable(
      u'040904b0',
      [StringStruct(u'CompanyName', u'{comp}'),
       StringStruct(u'FileDescription', u'{desc}'),
       StringStruct(u'FileVersion', u'1.0.0.0'),
       StringStruct(u'InternalName', u'{name}'),
       StringStruct(u'LegalCopyright', u'© {comp}. All rights reserved.'),
       StringStruct(u'OriginalFilename', u'{name}.exe'),
       StringStruct(u'ProductName', u'{name}'),
       StringStruct(u'ProductVersion', u'1.0.0.0')])
  ]
)
"""
        try:
            # Benzersiz dosya ismi (Çakışmaları önlemek için)
            safe_name = name.replace(" ", "_")
            v_file = f"temp_version_{safe_name}.txt"
            with open(v_file, "w", encoding="utf-16") as f:
                f.write(content)
            return v_file
        except: return None

# ── 3. GitHub Sync Tab (EYE ICON ADDED) ──────────────────────────────────────
class SyncTab(QFrame):
    def __init__(self):
        super().__init__()
        self.setObjectName("Card")
        self.signals = WorkerSignals()
        self.signals.log.connect(self.log)
        self.config_file = ".github_settings.json" # JSON formatına geçtik
        self.init_ui()
        self.load_saved_settings()

    def init_ui(self):
        layout = QVBoxLayout(self)
        title = QLabel("🔄 GitHub Senkronizasyon")
        title.setStyleSheet(PremiumStyles.title_style())
        layout.addWidget(title)

        # REPO URL INPUT
        self.repo_url = QLineEdit()
        self.repo_url.setPlaceholderText("GitHub Repo URL (örn: https://github.com/.../...)")
        self.repo_url.setText("https://github.com/mtahiryilmazz/SENTINEL-IT-Service.git")
        layout.addWidget(self.repo_url)

        # TOKEN / AUTH INPUT WITH EYE ICON
        row2 = QHBoxLayout()
        self.otp = QLineEdit()
        self.otp.setPlaceholderText("GitHub Token (PAT - Personal Access Token)")
        self.otp.setEchoMode(QLineEdit.Password)
        self.update_input_styles()

        btn_eye_otp = QPushButton("👁️")
        btn_eye_otp.setFixedWidth(40)
        btn_eye_otp.setCheckable(True)
        btn_eye_otp.setCursor(Qt.PointingHandCursor)
        btn_eye_otp.setStyleSheet("background: transparent; font-size: 16px; border: 1px solid #3b82f6; border-radius: 4px;")
        btn_eye_otp.toggled.connect(lambda chk: self.otp.setEchoMode(QLineEdit.Normal if chk else QLineEdit.Password))

        row2.addWidget(self.otp); row2.addWidget(btn_eye_otp)
        layout.addLayout(row2)

        btn_row = QHBoxLayout()
        btn_sync = QPushButton("🚀 Şimdi Eşitle (GitHub Push)")
        btn_sync.setStyleSheet(PremiumStyles.get_button_style())
        btn_sync.clicked.connect(self.start_sync)
        
        btn_save = QPushButton("📥 Ayarları Kaydet")
        btn_save.setFixedWidth(150)
        btn_save.setStyleSheet(PremiumStyles.get_button_style() + "background-color: #313244;")
        btn_save.clicked.connect(self.save_settings)
        
        btn_row.addWidget(btn_sync, stretch=2)
        btn_row.addWidget(btn_save)
        layout.addLayout(btn_row)

        self.console = QTextEdit()
        self.console.setReadOnly(True)
        self.console.setStyleSheet(PremiumStyles.get_log_style())
        layout.addWidget(self.console)

    def update_input_styles(self):
        t = PremiumStyles.get_theme()
        inp_style = f"background: {t['bg']}; color: {t['text']}; padding: 10px; border-radius: 6px; border: 1px solid {t['border']};"
        self.repo_url.setStyleSheet(inp_style)
        self.otp.setStyleSheet(inp_style)

    def log(self, t): self.console.append(t)

    def load_saved_settings(self):
        if os.path.exists(self.config_file):
            try:
                import json
                with open(self.config_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if "token" in data: self.otp.setText(data["token"])
                    if "repo" in data: self.repo_url.setText(data["repo"])
            except: pass

    def save_settings(self):
        token = self.otp.text().strip()
        repo = self.repo_url.text().strip()
        if not token or not repo:
            QMessageBox.warning(self, "Hata", "Kaydetmek için hem Token hem de Repo URL girmelisiniz.")
            return
        try:
            import json
            with open(self.config_file, "w", encoding="utf-8") as f:
                json.dump({"token": token, "repo": repo}, f)
            QMessageBox.information(self, "Başarılı", "Ayarlar kaydedildi.\nArtık her açılışta otomatik yüklenecek.")
        except Exception as e:
            QMessageBox.critical(self, "Hata", f"Kaydedilemedi: {e}")

    def start_sync(self):
        token = self.otp.text().strip()
        url = self.repo_url.text().strip()
        if not token or not url:
             QMessageBox.warning(self, "Eksik Bilgi", "Lütfen hem Token hem de Hedef Repo URL'sini girin.")
             return
        self.console.clear()
        threading.Thread(target=self.run_sync, args=(token, url), daemon=True).start()

    def run_sync(self, t, repo_url):
        try:
            # Proje kök dizinini belirle (Toolkit'in bulunduğu yer)
            base_dir = os.path.dirname(os.path.abspath(__file__))
            
            # Kullanıcıdan gelen URL'i temizleyip kimlik bilgilerini yerleştiriyoruz.
            clean_host = repo_url.replace("https://", "").replace("http://", "")
            auth_url = f"https://mtahiryilmazz:{t}@{clean_host}"
            
            base_cmd = ["git", "-c", "credential.helper="]
            
            # 1. Hazırlık: init ve remote ayarları
            setup_cmds = [
                base_cmd + ["init"],
                base_cmd + ["remote", "remove", "origin"],
                base_cmd + ["remote", "add", "origin", auth_url]
            ]
            
            for c in setup_cmds:
                self.signals.log.emit(f"⏳ Hazırlanıyor: {' '.join(c)}")
                proc = subprocess.run(c, capture_output=True, text=True, errors='replace', cwd=base_dir)
                if proc.returncode != 0 and "remove" not in c:
                    self.signals.log.emit(f"⚠️ Uyarı: {' '.join(c)} başarısız oldu.")

            # 2. Değişiklikleri tara (git add -A tüm silinen ve yeni dosyaları kapsar)
            self.signals.log.emit("🔍 Değişiklikler taranıyor...")
            subprocess.run(base_cmd + ["add", "-A"], capture_output=True, text=True, cwd=base_dir)
            
            # Özel Kontrol: main.py değişti mi?
            status_proc = subprocess.run(base_cmd + ["status", "--porcelain"], capture_output=True, text=True, cwd=base_dir)
            changes = status_proc.stdout.strip()
            
            if not changes:
                self.signals.log.emit("ℹ️ Değişiklik bulunamadı, mevcut durum güncel.")
            else:
                if "main.py" in changes:
                    self.signals.log.emit("✨ main.py dosyasındaki değişiklikler tespit edildi.")
                self.signals.log.emit(f"📝 Değişiklik Özeti:\n{changes}")

            # 3. Commit ve Push
            commit_msg = f"Manual Sync {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}"
            
            # Commit (Eğer değişiklik yoksa hata vermemesi için check ekliyoruz)
            if changes:
                self.signals.log.emit(f"💾 Commit ediliyor: {commit_msg}")
                subprocess.run(base_cmd + ["commit", "-m", commit_msg], capture_output=True, text=True, cwd=base_dir)
            
            self.signals.log.emit("🚀 GitHub'a gönderiliyor (Push)...")
            push_proc = subprocess.run(base_cmd + ["push", "-u", "origin", "main", "--force"], 
                                     capture_output=True, text=True, errors='replace', cwd=base_dir)
            
            if push_proc.returncode == 0:
                self.signals.log.emit("✔ Başarıyla senkronize edildi.")
            else:
                err_text = push_proc.stderr.strip()
                self.signals.log.emit(f"<span style='color:#ef4444;'>❌ HATA: {err_text}</span>")
                self.signals.log.emit("❌ Senkronizasyon HATASI! Lütfen internet bağlantınızı veya Token yetkinizi kontrol edin.")

        except Exception as e: 
            self.signals.log.emit(f"<span style='color:#ef4444;'>💥 KRİTİK HATA: {str(e)}</span>")

# ── 4. Agent Manager Tab (INSTALL & UNINSTALL) ───────────────────────────────
class AgentTab(QFrame):
    def __init__(self):
        super().__init__()
        self.setObjectName("Card")
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        title = QLabel("⚡ VANGUARD Uzak Destek Ajanı")
        title.setStyleSheet(PremiumStyles.title_style())
        layout.addWidget(title)
        
        self.lbl_status = QLabel("Kontrol ediliyor...")
        self.lbl_status.setStyleSheet("color: white; font-weight: bold; margin-bottom: 20px;")
        layout.addWidget(self.lbl_status)

        # Real-time monitoring timer
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.check)
        self.timer.start(5000) # Check every 5 seconds

        box = QHBoxLayout()
        btn_in = QPushButton("🚀 Ajanı Kur")
        btn_in.setFixedHeight(50)
        btn_in.setStyleSheet(PremiumStyles.button_style() + "background-color: #64748b;")
        btn_in.clicked.connect(self.install)

        btn_start = QPushButton("🛠️ Ajanı Başlat / Yenile")
        btn_start.setFixedHeight(50)
        btn_start.setStyleSheet(PremiumStyles.button_style() + "background-color: #3b82f6;")
        btn_start.clicked.connect(self.start_agent_manual)
        
        btn_un = QPushButton("🗑️ Ajanı Kaldır")
        btn_un.setFixedHeight(50)
        btn_un.setStyleSheet(PremiumStyles.button_style() + "background-color: #ef4444;")
        btn_un.clicked.connect(self.uninstall)
        
        box.addWidget(btn_in); box.addWidget(btn_start); box.addWidget(btn_un)
        layout.addLayout(box)

        # Screenshot Management
        shot_box = QHBoxLayout()
        btn_open_shots = QPushButton("🖼️  Alınan Ekran Görüntülerini Aç")
        btn_open_shots.setFixedHeight(45)
        btn_open_shots.setStyleSheet(PremiumStyles.button_style() + "background-color: #45475a;")
        btn_open_shots.clicked.connect(self.open_screenshots_folder)
        shot_box.addWidget(btn_open_shots)
        layout.addLayout(shot_box)

        # Legacy Cleanup Button
        cleanup_box = QVBoxLayout()
        cleanup_box.setContentsMargins(0, 20, 0, 0)
        btn_cleanup = QPushButton("🧹 Eski Ajan Kalıntılarını Temizle (Legacy Cleanup)")
        btn_cleanup.setFixedHeight(50)
        btn_cleanup.setCursor(Qt.PointingHandCursor)
        btn_cleanup.setStyleSheet(PremiumStyles.button_style() + "background-color: #45475a; border: 1px dashed #f38ba8;")
        btn_cleanup.clicked.connect(self.cleanup_legacy_agents)
        cleanup_box.addWidget(btn_cleanup)
        
        cleanup_info = QLabel("Sisteminizde kalan eski isimli (Sentinel, IT-Tech) ajanları ve servisleri temizler.")
        cleanup_info.setStyleSheet("color: #6c7086; font-size: 11px;")
        cleanup_info.setAlignment(Qt.AlignCenter)
        cleanup_box.addWidget(cleanup_info)
        
        layout.addLayout(cleanup_box)
        layout.addStretch()
        self.check()

    def open_screenshots_folder(self):
        folder = os.path.join(os.getcwd(), "screenshots")
        if not os.path.exists(folder): os.makedirs(folder)
        os.startfile(folder)

    def check(self):
        p = os.path.join(os.environ.get("ProgramData", "C:"), "VanguardService")
        is_installed = os.path.exists(p)
        
        # Çalışan `agent` process'i var mı kontrol edelim
        is_running = False
        try:
            # Daha hassas kontrol: Sadece Image Name kısmına bakıyoruz
            active_names = {"vanguardagent.exe", "agent.exe", "agent_dist.exe"}
            output = subprocess.check_output('tasklist /NH /FO CSV', shell=True, text=True, errors='replace')
            import csv
            import io
            reader = csv.reader(io.StringIO(output))
            for row in reader:
                if row and row[0].lower() in active_names:
                    is_running = True
                    break
            
            if not is_running:
                # Python modu kontrolü (Geliştiriciler için daha geniş kapsamlı)
                output_v = subprocess.check_output('tasklist /V /NH', shell=True, text=True, errors='replace')
                if "agent.py" in output_v.lower():
                    is_running = True
        except Exception:
            pass

        if is_running:
            self.lbl_status.setText("Ajan Durumu: 🟢 AKTİF VE ÇALIŞIYOR")
            self.lbl_status.setStyleSheet("color: #94a3b8; font-weight: bold; font-size: 14px;")
        elif is_installed:
            self.lbl_status.setText("Ajan Durumu: 🟡 KURULU AMA ÇALIŞMIYOR\n(Dosyalar mevcut ama süreç bulunamadı)")
            self.lbl_status.setStyleSheet("color: #f9e2af; font-weight: bold; font-size: 14px;")
        else:
            self.lbl_status.setText("Ajan Durumu: 🔴 KURULU DEĞİL")
            self.lbl_status.setStyleSheet("color: #f38ba8; font-weight: bold; font-size: 14px;")

    def install(self):
        # Önce kullanıcıya sunucu IP'sini sor (Discovery başarısız olma ihtimaline karşı)
        ip, ok = QInputDialog.getText(self, "Ajan Kurulumu", 
                                     "Sunucu IP adresini girin (Boş bırakırsanız otomatik tarama yapar):",
                                     QLineEdit.Normal, "")
        if not ok: return
        
        try:
            import client_installer
            server_ip = ip.strip() if ip.strip() else None
            client_installer.install_agent(server_ip=server_ip)
            QMessageBox.information(self, "Başarılı", 
                                 f"Ajan başarıyla kuruldu.\n\n"
                                 f"Not: Eğer sunucuya bağlanamazsa C:\\ProgramData\\VanguardService\\agent_debug.log "
                                 f"dosyasını kontrol edin.")
            self.check()
        except Exception as e:
            QMessageBox.critical(self, "Hata", f"Kurulum hatası: {e}")

    def start_agent_manual(self):
        """Ajanı kurulu olduğu dizinden zorla başlatmaya çalışır."""
        p = os.path.join(os.environ.get("ProgramData", "C:"), "VanguardService")
        if not os.path.exists(p):
            QMessageBox.warning(self, "Hata", "Ajan kurulu değil.")
            return

        # Denenecek komutlar
        possible_targets = [
            os.path.join(p, "VanguardAgent.exe"),
            os.path.join(p, "agent_dist.exe"),
            os.path.join(p, "agent.exe")
        ]
        
        started = False
        for target in possible_targets:
            if os.path.exists(target):
                try:
                    subprocess.Popen(f'"{target}"', shell=True, creationflags=subprocess.CREATE_NO_WINDOW)
                    started = True
                    break
                except: pass
        
        if not started:
            # Python modu dene (Geliştirici için)
            script = os.path.join(p, "agent.py")
            if os.path.exists(script):
                try:
                    python_exe = sys.executable.replace("python.exe", "pythonw.exe")
                    subprocess.Popen([python_exe, script], creationflags=subprocess.CREATE_NO_WINDOW)
                    started = True
                except: pass

        if started:
            QMessageBox.information(self, "Bilgi", "Ajan başlatma komutu gönderildi. Lütfen durumu kontrol edin.")
            QTimer.singleShot(2000, self.check)
        else:
            QMessageBox.critical(self, "Hata", "Ajan dosyası bulunamadı veya başlatılamadı. Lütfen tekrar kurun.")

    def uninstall(self):
        if QMessageBox.warning(self, "Onay", "Ajan ve tüm kayıt defteri girişleri silinecek. Emin misiniz?", QMessageBox.Yes|QMessageBox.No) == QMessageBox.Yes:
            try:
                # 1. Servisleri Durdur (Eğer servis modundaysa)
                subprocess.run(["sc", "stop", "VanguardAgent"], capture_output=True)
                subprocess.run(["sc", "delete", "VanguardAgent"], capture_output=True)
                
                # 2. Çalışan Process'leri Sonlandır (Ağaç yapısında /T ile)
                subprocess.run(["taskkill", "/f", "/t", "/im", "VanguardAgent.exe"], capture_output=True)
                subprocess.run(["taskkill", "/f", "/t", "/im", "agent.exe"], capture_output=True)
                subprocess.run(["taskkill", "/f", "/t", "/im", "agent_dist.exe"], capture_output=True)
                
                # 3. Kayıt Defteri ve Zamanlanmış Görevleri Temizle
                try:
                    import winreg
                    key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Run", 0, winreg.KEY_SET_VALUE)
                    winreg.DeleteValue(key, "WindowsVanguardSvc")
                    winreg.CloseKey(key)
                except: pass
                
                try:
                    subprocess.run('schtasks /delete /tn "VanguardAgent_Boot" /f', shell=True, capture_output=True)
                    subprocess.run('schtasks /delete /tn "VanguardAgent_Watchdog" /f', shell=True, capture_output=True)
                except: pass

                # 4. Dosyaları Sil (Zorla)
                p = os.path.join(os.environ.get("ProgramData", "C:"), "VanguardService")
                if os.path.exists(p):
                    import time
                    time.sleep(0.5)
                    shutil.rmtree(p, ignore_errors=True)
                
                QMessageBox.information(self, "Tamam", "Ajan sistemden tamamen kaldırıldı.")
                self.check()
            except Exception as e: 
                QMessageBox.critical(self,"Hata", f"Kaldırma sırasında bir hata oluştu: {e}")

    def cleanup_legacy_agents(self):
        msg = ("Tam Otomatik Temizlik Başlatılsın mı?\n\n"
               "Bu işlem sistemdeki tum eski versiyonları (Sentinel, IT-Tech, eski Vanguard) "
               "otomatik tespit edip durduracaktır. Mevcut Toolkit kapatılmayacaktır.")
        
        if QMessageBox.question(self, "Otomatik Temizlik", msg, QMessageBox.Yes|QMessageBox.No) == QMessageBox.Yes:
            import csv
            import io
            
            # 1. DİNAMİK SÜREÇ TESPİTİ VE DURDURMA
            legacy_keywords = ["sentinel", "it_tech", "agent_dist", "vanguardsvc", "it-tech"]
            current_pid = str(os.getpid())
            killed_count = 0
            
            try:
                output = subprocess.check_output('tasklist /NH /FO CSV', shell=True, text=True, errors='replace')
                reader = csv.reader(io.StringIO(output))
                for row in reader:
                    if not row: continue
                    img_name = row[0].lower()
                    pid = row[1]
                    
                    # Mevcut toolkit'i koru
                    if pid == current_pid or "vanguardtoolkit" in img_name:
                        continue
                        
                    # Anahtar kelime kontrolü
                    is_legacy = any(kw in img_name for kw in legacy_keywords)
                    if is_legacy:
                        try:
                            subprocess.run(["taskkill", "/f", "/t", "/pid", pid], capture_output=True)
                            killed_count += 1
                        except: pass
            except: pass

            # 2. DİNAMİK SERVİS TESPİTİ VE SİLME
            try:
                # WMIC ile servisleri tara
                for kw in legacy_keywords:
                    wmic_cmd = f'wmic service where "name like \'%{kw}%\' or displayname like \'%{kw}%\'" get name'
                    svc_out = subprocess.check_output(wmic_cmd, shell=True, text=True, errors='replace')
                    for line in svc_out.splitlines():
                        svc_name = line.strip()
                        if svc_name and svc_name.lower() != "name":
                            subprocess.run(["sc", "stop", svc_name], capture_output=True)
                            subprocess.run(["sc", "delete", svc_name], capture_output=True)
            except: pass

            # 3. ESKİ DİZİN TEMİZLİĞİ (GENİŞLETİLMİŞ)
            try:
                prog_data = os.environ.get("ProgramData", "C:/ProgramData")
                legacy_folders = ["SentinelService", "ITTechService", "IT-Tech-Service", "SentinelVanguard"]
                for folder in legacy_folders:
                    p = os.path.join(prog_data, folder)
                    if os.path.exists(p):
                        shutil.rmtree(p, ignore_errors=True)
            except: pass

            QMessageBox.information(self, "Temizlik Başarılı", 
                                 f"Temizlik tamamlandı.\n\n"
                                 f"- Durdurulan süreç sayısı: {killed_count}\n"
                                 f"- Eski servisler ve dizinler taranıp temizlendi.")
            self.check()

# ── 4.5 Recovery Tab (BREAK-GLASS) ────────────────────────────────────────────
class RecoveryTab(QFrame):
    def __init__(self, db_conn):
        super().__init__()
        self.db = db_conn
        self.setObjectName("Card")
        self.init_ui()
        self.check_status()

    def init_ui(self):
        from PySide6.QtWidgets import QLineEdit, QHBoxLayout
        layout = QVBoxLayout(self)
        layout.setSpacing(16)
        
        title = QLabel("🛡️ Acil Durum Kalkanı")
        title.setStyleSheet(PremiumStyles.title_style())
        layout.addWidget(title)
        
        desc = QLabel("Sistemin ele geçirilmesi durumunda tam yetkiyi güvenle geri almak için Acil Durum modunu aktif edebilirsiniz.\n"
                      "Bu kalkan aktif edildiği an size özel geçici bir şifre tanımlanacak ve sisteme girişleriniz loglarda uyarı verecektir.")
        desc.setWordWrap(True)
        desc.setStyleSheet(PremiumStyles.subtitle_style() + "color:#f38ba8;")
        layout.addWidget(desc)

        self.lbl_status = QLabel("")
        self.lbl_status.setStyleSheet("font-weight: bold; font-size: 16px; padding: 20px; text-align: center;")
        self.lbl_status.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.lbl_status)

        # Kullanıcı adı satırı
        lbl_user = QLabel("👤  Kullanıcı Adı:")
        lbl_user.setStyleSheet("color: #cdd6f4; font-weight: bold; font-size: 13px;")
        layout.addWidget(lbl_user)

        user_row = QHBoxLayout()
        self.user_field = QLineEdit()
        self.user_field.setReadOnly(True)
        self.user_field.setText("Recovery")
        self.user_field.setStyleSheet(
            "font-family: monospace; font-size: 16px; font-weight: bold; "
            "background: #1e1e2e; color: #89b4fa; border: 2px solid #313244; "
            "border-radius: 8px; padding: 12px;"
        )
        self.user_field.setFixedHeight(50)
        self.user_field.setVisible(False)
        user_row.addWidget(self.user_field)

        self.btn_copy_user = QPushButton("📋 Kopyala")
        self.btn_copy_user.setFixedHeight(50)
        self.btn_copy_user.setFixedWidth(120)
        self.btn_copy_user.setCursor(Qt.PointingHandCursor)
        self.btn_copy_user.setStyleSheet(
            "background-color: #313244; color: #cdd6f4; font-weight: bold; "
            "border-radius: 8px; font-size: 14px;"
        )
        self.btn_copy_user.setVisible(False)
        self.btn_copy_user.clicked.connect(self.copy_username)
        user_row.addWidget(self.btn_copy_user)
        layout.addLayout(user_row)

        # Şifre gösterim satırı
        lbl_pass = QLabel("🔐  Geçici Şifre:")
        lbl_pass.setStyleSheet("color: #cdd6f4; font-weight: bold; font-size: 13px;")
        layout.addWidget(lbl_pass)

        # Şifre gösterim kutusu + kopyala butonu
        pass_row = QHBoxLayout()
        self.pass_field = QLineEdit()
        self.pass_field.setReadOnly(True)
        self.pass_field.setPlaceholderText("Kalkan aktif olduğunda şifre burada görünür...")
        self.pass_field.setStyleSheet(
            "font-family: monospace; font-size: 18px; font-weight: bold; "
            "background: #1e1e2e; color: #f38ba8; border: 2px solid #ef4444; "
            "border-radius: 8px; padding: 12px;"
        )
        self.pass_field.setFixedHeight(54)
        pass_row.addWidget(self.pass_field)

        self.btn_copy = QPushButton("📋 Kopyala")
        self.btn_copy.setFixedHeight(54)
        self.btn_copy.setFixedWidth(120)
        self.btn_copy.setCursor(Qt.PointingHandCursor)
        self.btn_copy.setStyleSheet(
            "background-color: #313244; color: #cdd6f4; font-weight: bold; "
            "border-radius: 8px; font-size: 14px;"
        )
        self.btn_copy.setVisible(False)
        self.btn_copy.clicked.connect(self.copy_password)
        pass_row.addWidget(self.btn_copy)
        layout.addLayout(pass_row)

        self.btn_action = QPushButton("")
        self.btn_action.setFixedHeight(50)
        self.btn_action.setCursor(Qt.PointingHandCursor)
        self.btn_action.clicked.connect(self.toggle_shield)
        layout.addWidget(self.btn_action)
        
        layout.addStretch()

    def copy_username(self):
        from PySide6.QtWidgets import QApplication
        QApplication.clipboard().setText("Recovery")
        self.btn_copy_user.setText("✅ Kopyalandı!")
        QTimer.singleShot(2000, lambda: self.btn_copy_user.setText("📋 Kopyala"))

    def copy_password(self):
        from PySide6.QtWidgets import QApplication
        txt = self.pass_field.text()
        if txt:
            QApplication.clipboard().setText(txt)
            self.btn_copy.setText("✅ Kopyalandı!")
            QTimer.singleShot(2000, lambda: self.btn_copy.setText("📋 Kopyala"))

    def check_status(self):
        r = self.db.fetch_data("SELECT password FROM users WHERE username='Recovery'")
        if r and not r[0]['password'].startswith('LOCKED_'):
            pw = r[0]['password']
            self.lbl_status.setText("🔴  KALKAN AKTİF — Sistem Kritik Modda")
            self.lbl_status.setStyleSheet(
                "color: white; background-color: #ef4444; border-radius: 8px; "
                "font-weight: bold; font-size: 18px; padding: 20px;"
            )
            self.pass_field.setText(pw)
            self.pass_field.setVisible(True)
            self.btn_copy.setVisible(True)
            self.user_field.setVisible(True)
            self.btn_copy_user.setVisible(True)
            self.btn_action.setText("🛡️ Kalkanı Kapat / Şifreyi İmha Et")
            self.btn_action.setStyleSheet(
                "background-color: #11111b; border: 2px solid #ef4444; "
                "color: #ef4444; font-weight:bold; font-size:16px;"
            )
        else:
            self.lbl_status.setText("🟢  Kalkan Şuan Kapalı — Hesap Güvenli Kilitli")
            self.lbl_status.setStyleSheet(
                "color: #94a3b8; font-weight: bold; font-size: 16px; padding: 20px;"
            )
            self.pass_field.clear()
            self.pass_field.setVisible(False)
            self.btn_copy.setVisible(False)
            self.user_field.setVisible(False)
            self.btn_copy_user.setVisible(False)
            self.btn_action.setText("⚡ Acil Durum Kalkanını Aktif Et")
            self.btn_action.setStyleSheet(
                "background-color: #64748b; color: white; font-weight:bold; font-size:16px;"
            )

    def toggle_shield(self):
        r = self.db.fetch_data("SELECT id, password FROM users WHERE username='Recovery'")
        
        is_active = False
        if r and not r[0]['password'].startswith('LOCKED_'):
            is_active = True
            
        if is_active:
            ans = QMessageBox.question(self, "Onay", "Şifreyi imha edip kurtarma hesabını kalıcı olarak kilitlemek istediğinize emin misiniz?", QMessageBox.Yes|QMessageBox.No)
            if ans == QMessageBox.Yes:
                self.db.execute_query("UPDATE users SET password=? WHERE username='Recovery'", ("LOCKED_" + "".join(random.choices(string.ascii_letters, k=32)),))
                QMessageBox.information(self, "Başarılı", "Kalkan kapatıldı ve hesap başarıyla kilitlendi.")
                self.check_status()
        else:
            ans = QMessageBox.question(self, "Yüksek Risk Uyarı", "Kurtarma mekanizmasını aktif etmek üzeresiniz. Yeni şifre ekranda sadece 1 kere açık gösterilecektir ve sisteme bu şifre ile girdiğiniz anda tüm paneller kırmızı alarm verecektir.\\n\\nEmin misiniz?", QMessageBox.Yes|QMessageBox.No)
            if ans == QMessageBox.Yes:
                raw_pass = "SV-" + "".join(random.choices(string.ascii_uppercase + string.digits, k=10))
                if not r:
                    self.db.execute_query("INSERT INTO users (username, password, role, permissions) VALUES (?, ?, 'Admin', '*')", ('Recovery', raw_pass))
                else:
                    self.db.execute_query("UPDATE users SET password=? WHERE username='Recovery'", (raw_pass,))
                self.check_status()

# UsersTab kaldirildi, yerine ana uygulamadan modüler olarak UsersPage eklendi.
# ── 5. Main Toolkit Window ────────────────────────────────────────────────────
class VanguardToolkit(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("VANGUARD Developer Toolkit v2")
        self.resize(1100, 750)
        self.setStyleSheet(PremiumStyles.main_style())
        
        self.db = DatabaseConnection()
        self.db.connect()
        
        self.setup_ui()
        self.setup_shortcuts()

    def setup_shortcuts(self):
        # Olası bir sonsuz döngü (UAC veya Process) durumunda tüm üretilmiş uygulamaları zorla kapatan kısayol
        shortcut = QShortcut(QKeySequence("Ctrl+Shift+K"), self)
        shortcut.activated.connect(self.emergency_kill_processes)

    def emergency_kill_processes(self):
        try:
            subprocess.run(["taskkill", "/f", "/im", "main_Dist.exe"], capture_output=True)
            subprocess.run(["taskkill", "/f", "/im", "VanguardAgent.exe"], capture_output=True)
            subprocess.run(["taskkill", "/f", "/im", "github_sync_Dist.exe"], capture_output=True)
            QMessageBox.warning(self, "Acil Durdurma", "Çalışan tüm derlenmiş uygulamalar (main, agent, sync) zorla durduruldu!", QMessageBox.Ok)
        except Exception as e:
            QMessageBox.critical(self, "Hata", f"Durdurma sırasında hata oluştu: {e}")

    def setup_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QHBoxLayout(central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # Sidebar
        sidebar = QFrame()
        sidebar.setObjectName("Sidebar")
        sidebar.setFixedWidth(240)
        sidebar.setStyleSheet(PremiumStyles.sidebar_style())
        side_lay = QVBoxLayout(sidebar)
        side_lay.setContentsMargins(0, 20, 0, 20)

        self.logo = QLabel("VANGUARD\nTOOLKIT")
        self.logo.setAlignment(Qt.AlignCenter)
        self.logo.setStyleSheet(f"color: {PremiumStyles.get_theme()['text']}; font-weight: 900; font-size: 24px; padding: 20px; border: none;")
        side_lay.addWidget(self.logo)

        # Global Panic Info
        panic_info = QLabel("Döngü/Hata Anında\nCTRL+SHIFT+K\nile tümünü durdur")
        panic_info.setAlignment(Qt.AlignCenter)
        panic_info.setStyleSheet("color: #ef4444; font-weight: bold; font-size: 11px; padding-bottom: 20px; border: none;")
        side_lay.addWidget(panic_info)

        self.stack = QStackedWidget()
        self.btns = []
        menus = [("Lisans Yönetimi", 0), ("Kullanıcı Yönetimi", 1), ("EXE Paketleyici", 2), 
                 ("Git Senkron", 3), ("Ajan Yönetimi", 4), ("Acil Durum Kalkanı", 5)]
        
        for name, idx in menus:
            btn = QPushButton(f"  {name}")
            btn.setCursor(Qt.PointingHandCursor)
            btn.clicked.connect(lambda chk, i=idx: self.switch_page(i))
            side_lay.addWidget(btn)
            self.btns.append(btn)
            
        # Sidebar Footer (Theme Switch Sync)
        side_lay.addStretch()
        
        footer_panel = QFrame()
        footer_panel.setObjectName("SidebarFooter")
        footer_panel.setFixedHeight(40)
        footer_panel.setStyleSheet("background: transparent; border: none;")
        
        foot_lay = QHBoxLayout(footer_panel)
        foot_lay.setContentsMargins(15, 0, 15, 0)
        
        lbl_theme = QLabel("🌓 Tema Değiştir")
        lbl_theme.setStyleSheet("color: #94a3b8; font-size: 11px; font-weight: bold; border: none;")
        
        self.theme_switch = ThemeToggle() # Bu artik ModernToggle'dan turuyor (width=34)
        self.theme_switch.setChecked(not PremiumStyles.CURRENT_THEME == "dark")
        self.theme_switch.toggled.connect(self.change_theme)
        
        foot_lay.addWidget(lbl_theme)
        foot_lay.addStretch()
        foot_lay.addWidget(self.theme_switch)
        
        side_lay.addWidget(footer_panel)
        
        main_layout.addWidget(sidebar)

        self.stack.addWidget(LicenseTab(self.db))
        # Ana uygulamadaki modüler UsersPage kullanılıyor (tam özellikli)
        self.stack.addWidget(UsersPage(self.db, {"role": "Admin", "id": -1}))
        self.stack.addWidget(BuilderTab())
        self.stack.addWidget(SyncTab())
        self.stack.addWidget(AgentTab())
        self.stack.addWidget(RecoveryTab(self.db))
        
        main_layout.addWidget(self.stack)
        self.switch_page(0)

    def switch_page(self, idx):
        self.stack.setCurrentIndex(idx)
        for i, b in enumerate(self.btns):
            b.setObjectName("ActiveNav" if i == idx else "")
            b.style().unpolish(b); b.style().polish(b)

    def change_theme(self, is_light):
        theme_name = "light" if is_light else "dark"
        PremiumStyles.update_theme(theme_name)
        
        # Apply theme to self (Main Window)
        self.setStyleSheet(PremiumStyles.get_main_style())
        
        # Find sidebar and update it
        sidebar = self.findChild(QFrame, "Sidebar")
        if sidebar:
            sidebar.setStyleSheet(PremiumStyles.get_sidebar_style())
        
        # Update all pages in stack
        # Note: Pages created with ClassName() once. We ideally want all widgets to refresh.
        # But applying at high level often works if variables used in stylesheet
        # For this implementation, we re-apply styling to known containers
        self.apply_global_styles()

    def apply_global_styles(self):
        # This forces a refresh of style calculations
        self.setStyleSheet(PremiumStyles.get_main_style())
        sb = self.findChild(QFrame, "Sidebar")
        if sb:
            sb.setStyleSheet(PremiumStyles.get_sidebar_style())
            if hasattr(self, "logo"):
                self.logo.setStyleSheet(f"color: {PremiumStyles.get_theme()['text']}; font-weight: 900; font-size: 24px; padding: 20px; border: none;")

        for i in range(self.stack.count()):
            page = self.stack.widget(i)
            page.setStyleSheet(PremiumStyles.get_card_style())
            
            # Tab specific refreshes
            if isinstance(page, LicenseTab): page.update_table_style()
            if isinstance(page, SyncTab): page.update_input_styles()
            if isinstance(page, BuilderTab):
                # Update stealth card and buttons if needed
                page.setStyleSheet(PremiumStyles.get_card_style())

    def showEvent(self, event):
        super().showEvent(event)
        self.apply_global_styles()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = VanguardToolkit()
    window.show()
    sys.exit(app.exec())
