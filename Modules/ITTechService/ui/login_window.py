from PySide6.QtWidgets import QWidget, QVBoxLayout, QLineEdit, QPushButton, QLabel, QMessageBox, QCheckBox
from PySide6.QtGui import QFont
from PySide6.QtCore import Qt
from modules.auth import AuthModule
import json
import os
from pathlib import Path
from database.logger import write_log

import sys
import shutil
from core.path_helper import get_app_root

_APP_ROOT = Path(get_app_root())
SETTINGS_FILE = str(_APP_ROOT / "settings.json")

# Eğer EXE içerisindeysek ve ayar dosyası çalışma dizininde yoksa, şablonu kopyalayalım
if getattr(sys, 'frozen', False) and not os.path.exists(SETTINGS_FILE):
    bundled_settings = os.path.join(sys._MEIPASS, "settings.json")
    if os.path.exists(bundled_settings):
        try:
            shutil.copy2(bundled_settings, SETTINGS_FILE)
        except:
            pass

class LoginWindow(QWidget):
    def __init__(self, db_conn, on_success, is_licensed=False):
        super().__init__()
        self.db_conn = db_conn
        self.on_success = on_success
        self.is_licensed = is_licensed
        self.auth = AuthModule(db_conn)
        self.activate_requested = None # Callback for license dialog
        
        self.setWindowTitle("VANGUARD IT - Yetkili Girişi")
        self.setFixedSize(400, 420)
        
        # Başlangıç temasını ayarla
        saved_theme = self._get_saved_theme()
        is_dark = (saved_theme == "dark")
        self._apply_theme_to_login(is_dark)
        
        self.setup_ui()

    def _get_saved_theme(self):
        try:
            if os.path.exists(SETTINGS_FILE):
                with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                    return json.load(f).get("theme", "dark")
        except: pass
        return "dark"

    def _apply_theme_to_login(self, is_dark):
        if is_dark:
            self.setStyleSheet("""
                QWidget { background-color: #1e1e2e; color: #cdd6f4; font-family: 'Segoe UI'; }
                QLineEdit { padding: 12px; font-size: 14px; background-color: #313244; border: 1px solid #45475a; border-radius: 6px; color: #cdd6f4; }
                QLabel { color: #cdd6f4; background: transparent; }
                QCheckBox { color: #a6adc8; }
                QPushButton { background-color: #89b4fa; color: #11111b; padding: 12px; font-size: 14px; font-weight: bold; border-radius: 6px; }
                QPushButton:hover { background-color: #b4befe; }
            """)
        else:
            self.setStyleSheet("""
                QWidget { background-color: #eff1f5; color: #4c4f69; font-family: 'Segoe UI'; }
                QLineEdit { padding: 12px; font-size: 14px; background-color: #ffffff; border: 1px solid #ccd0da; border-radius: 6px; color: #4c4f69; }
                QLabel { color: #4c4f69; background: transparent; }
                QCheckBox { color: #6c6f85; }
                QPushButton { background-color: #1e66f5; color: #ffffff; padding: 12px; font-size: 14px; font-weight: bold; border-radius: 6px; }
                QPushButton:hover { background-color: #4079f8; }
            """)

    def setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setAlignment(Qt.AlignCenter)
        layout.setContentsMargins(40, 40, 40, 40)

        lbl = QLabel("Bilgi İşlem Merkezi")
        lbl.setFont(QFont("Segoe UI", 16, QFont.Bold))
        layout.addWidget(lbl, alignment=Qt.AlignCenter)
        
        layout.addSpacing(30)

        self.inp_user = QLineEdit()
        self.inp_user.setPlaceholderText("Kullanıcı Adı")
        self.inp_user.setStyleSheet("padding: 12px; font-size: 14px; background-color: #2d2d30; border: 1px solid #555; border-radius: 5px;")
        layout.addWidget(self.inp_user)

        layout.addSpacing(10)

        self.inp_pass = QLineEdit()
        self.inp_pass.setPlaceholderText("Şifre")
        self.inp_pass.setEchoMode(QLineEdit.Password)
        self.inp_pass.setStyleSheet("padding: 12px; font-size: 14px; background-color: #2d2d30; border: 1px solid #555; border-radius: 5px;")
        self.inp_pass.returnPressed.connect(self.do_login)
        layout.addWidget(self.inp_pass)
        
        self.chk_remember = QCheckBox("Beni Hatırla")
        self.chk_remember.setStyleSheet("font-size: 13px; margin-top: 5px;")
        layout.addWidget(self.chk_remember)
        
        layout.addSpacing(20)

        # Load saved credentials if any
        if os.path.exists(SETTINGS_FILE):
            try:
                with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if data.get("remember"):
                        self.inp_user.setText(data.get("u", ""))
                        self.inp_pass.setText(data.get("p", ""))
                        self.chk_remember.setChecked(True)
            except:
                pass

        btn = QPushButton("Uygulamaya Giriş Yap")
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet("background-color: #007acc; color: white; padding: 12px; font-size: 14px; font-weight:bold; border-radius: 5px; border: none;")
        btn.clicked.connect(self.do_login)
        layout.addWidget(btn)

        layout.addSpacing(15)
        
        self.btn_license = QPushButton("Lisansı Etkinleştir")
        self.btn_license.setCursor(Qt.PointingHandCursor)
        self.btn_license.setStyleSheet("background: transparent; color: #89b4fa; text-decoration: underline; border: none; font-size: 12px;")
        self.btn_license.clicked.connect(self.trigger_activation)
        layout.addWidget(self.btn_license, alignment=Qt.AlignCenter)
        
        # Lisanslı ise butonu gizle
        if self.is_licensed:
            self.btn_license.hide()

    def set_licensed(self, status):
        """Lisans durumunu dinamik olarak günceller."""
        self.is_licensed = status
        if status:
            self.btn_license.hide()
        else:
            self.btn_license.show()

    def trigger_activation(self):
        if self.activate_requested:
            self.activate_requested()

    def do_login(self):
        try:
            u = self.inp_user.text().strip()
            p = self.inp_pass.text().strip()
            
            if not u:
                QMessageBox.warning(self, "Hata", "Lütfen kullanıcı adınızı girin.")
                return

            user_data = self.auth.login(u, p)
            if user_data:
                # Beni Hatırla İşlemleri
                try:
                    existing = {}
                    if os.path.exists(SETTINGS_FILE):
                        with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                            existing = json.load(f)
                    
                    if self.chk_remember.isChecked():
                        existing.update({"remember": True, "u": u, "p": p})
                    else:
                        existing.update({"remember": False, "u": "", "p": ""})
                    
                    with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
                        json.dump(existing, f, ensure_ascii=False, indent=2)
                except Exception as e:
                    print(f"Beni hatırla ayarları kaydedilemedi: {e}")

                # Ana pencereye geçiş
                self.on_success(user_data)
            else:
                write_log(self.db_conn, u, "GİRİŞ_HATA", f"Hatalı giriş denemesi: {u}")
                QMessageBox.warning(self, "Hata", "Geçersiz kullanıcı adı veya şifre.")
        except Exception as e:
            import traceback
            err_details = traceback.format_exc()
            print(f"Login Crash:\n{err_details}")
            QMessageBox.critical(self, "Kritik Giriş Hatası", f"Giriş yapılırken bir hata oluştu:\n{e}")
