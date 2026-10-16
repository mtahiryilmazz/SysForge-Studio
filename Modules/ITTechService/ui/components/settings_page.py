"""
Ayarlar Sayfası — settings_page.py

Sekmeler:
  🎨 Tema        → tüm kullanıcılar
  🏢 Örgüt       → Admin (Müdürlük / Birim yönetimi)
  👥 Kullanıcılar → Admin
  📝 Sistem Logları → Admin
"""

from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QTabWidget,
    QPushButton, QFrame, QSizePolicy, QInputDialog, QLineEdit, QMessageBox, QDialog
)
import subprocess
import sys
import json
try:
    import pyotp
except ImportError:
    pyotp = None

import io
# qrcode ve PIL çalışma anında kontrol edilecek
from PySide6.QtCore import Qt, Signal, QUrl, QSize
from PySide6.QtGui import QFont, QIcon, QPixmap, QDesktopServices, QImage
from pathlib import Path

from core.version import VERSION, CODENAME
from database.connection import DatabaseConnection
from ui.components.departments_page import DepartmentsPage
from ui.components.users_page      import UsersPage
from ui.components.logs_page       import LogsPage






class SettingsPage(QWidget):
    """Ana ayarlar sayfası.

    Sinyal:
        data_changed — Müdürlük/Birim ekle-sil sonrası yayılır;
                       main_window bu sinyali dinleyerek diğer sayfaları yeniler.
    """
    data_changed = Signal()

    def __init__(self, db_conn: DatabaseConnection, user_data: dict, theme_callback, get_theme_fn=None):
        super().__init__()
        self.setObjectName("SettingsPage")
        self.db = db_conn
        self.user_data = user_data
        self.theme_callback = theme_callback   # main_window.toggle_theme
        self.get_theme_fn = get_theme_fn       # main_window.is_dark_theme getter (lambda)
        self.is_admin = user_data.get("role") == "Admin"

        self._setup_ui()

    # ── UI ───────────────────────────────────────────────────────────────
    def _setup_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(28, 24, 28, 24)
        root.setSpacing(16)

        hdr = QLabel("Ayarlar")
        hdr.setFont(QFont("Segoe UI", 12, QFont.Bold))
        hdr.setStyleSheet("color: #6c7086; margin-bottom: 5px;")
        root.addWidget(hdr)

        self.tabs = QTabWidget()
        self.tabs.setObjectName("SettingsTabs")
        root.addWidget(self.tabs)

        # (Tema sekmesi sidebar'a taşındı)

        if self.is_admin:
            # ── 2. Örgüt (Müdürlük/Birim) ───────────────────────────────
            self.dept_page = DepartmentsPage(self.db)
            self.dept_page.data_changed.connect(self.data_changed.emit)
            self.tabs.addTab(self.dept_page, "🏢  Müdürlük / Birim")

            # ── 3. Kullanıcı Yönetimi ────────────────────────────────────
            self.users_page = UsersPage(self.db, self.user_data)
            self.tabs.addTab(self.users_page, "👥  Kullanıcı Yönetimi")

            # ── 4. Sistem Logları ────────────────────────────────────────
            self.logs_page = LogsPage(self.db)
            self.tabs.addTab(self.logs_page, "📝  Sistem Logları")



        # ── 6. Hakkında Sekmesi ──────────────────────────────────────────
        self.tabs.addTab(self._build_about_tab(), "ℹ️  Hakkında")



    def _build_about_tab(self) -> QWidget:
        tab = QWidget()
        lay = QVBoxLayout(tab)
        lay.setContentsMargins(50, 50, 50, 50)
        lay.setSpacing(30)
        lay.setAlignment(Qt.AlignCenter)

        # Geliştirici Kartı
        card = QFrame()
        card.setObjectName("DevCard")
        card.setFixedWidth(400)
        card.setStyleSheet("""
            QFrame#DevCard {
                background-color: rgba(137, 180, 250, 0.05);
                border: 1px solid rgba(137, 180, 250, 0.2);
                border-radius: 20px;
            }
        """)
        card_lay = QVBoxLayout(card)
        card_lay.setContentsMargins(30, 40, 30, 40)
        card_lay.setSpacing(20)
        card_lay.setAlignment(Qt.AlignCenter)

        title = QLabel("Geliştirici Bilgileri")
        title.setFont(QFont("Segoe UI", 12, QFont.Bold))
        title.setStyleSheet("color: #9399b2;")
        card_lay.addWidget(title)

        name = QLabel("Muhammed Tahir YILMAZ")
        name.setFont(QFont("Segoe UI", 20, QFont.Bold))
        name.setStyleSheet("color: #cdd6f4;")
        card_lay.addWidget(name)

        role = QLabel("Full Stack Developer & System Architect")
        role.setStyleSheet("color: #89b4fa; font-size: 14px;")
        card_lay.addWidget(role)

        card_lay.addSpacing(20)

        # GitHub Butonu
        gh_btn = QPushButton("  GitHub Profilini Görüntüle")
        gh_btn.setCursor(Qt.PointingHandCursor)
        gh_btn.setFixedWidth(260)
        gh_btn.setFixedHeight(50)
        
        # İkon yükle
        icon_path = Path(__file__).resolve().parent.parent.parent / "static" / "icons" / "github.png"
        if icon_path.exists():
            gh_btn.setIcon(QIcon(str(icon_path)))
            gh_btn.setIconSize(QSize(24, 24))
        
        gh_btn.setStyleSheet("""
            QPushButton {
                background-color: #313244;
                color: #cdd6f4;
                border: 1px solid #45475a;
                border-radius: 12px;
                font-weight: bold;
                font-size: 13px;
                padding: 10px;
            }
            QPushButton:hover {
                background-color: #45475a;
                border: 1px solid #89b4fa;
            }
        """)
        card_lay.addWidget(gh_btn)

        lay.addWidget(card, alignment=Qt.AlignCenter)

        # Sürüm Bilgisi
        ver = QLabel(f"Project SENTINEL {CODENAME} v{VERSION}")
        ver.setStyleSheet("color: #585b70; font-size: 11px;")
        lay.addWidget(ver, alignment=Qt.AlignCenter)


        lay.addStretch()
        return tab




    # ── Public API ────────────────────────────────────────────────────────
    def refresh_logs(self):
        """Loglar sekmesini yeniler (ayarlara geçildiğinde)."""
        if self.is_admin and hasattr(self, 'logs_page'):
            self.logs_page.load_logs()

