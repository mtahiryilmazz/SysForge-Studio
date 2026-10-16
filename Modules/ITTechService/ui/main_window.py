# Dosya Adı: main_window.py
import sys
import os
import json
import ctypes
import subprocess
import time
from pathlib import Path
from PySide6.QtCore import QTimer, Qt
from PySide6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QStackedWidget, QFrame, QScrollArea, QMessageBox
)
from PySide6.QtGui import QFont, QIcon

from core.version import VERSION, CODENAME
from database.connection import DatabaseConnection
from ui.components.dashboard_page  import DashboardPage
from ui.components.tickets_page    import TicketsPage
from ui.components.inventory_page  import InventoryPage
from ui.components.network_page    import NetworkPage
from ui.components.printers_page   import PrintersPage
from ui.components.reports_page    import ReportsPage
from ui.components.remote_page     import RemotePage
from ui.components.settings_page   import SettingsPage
from ui.components.screenshots_page import ScreenshotsPage
from ui.components.ui_utils       import ModernToggle
from ui.license_dialog             import LicenseDialog
from core.remote_server            import RemoteServer



# settings.json — proje kökünde (main.py ile aynı dizin)
# Path.resolve() kullanılarak çalışma dizininden bağımsız mutlak yol elde edilir
_PROJECT_ROOT = Path(__file__).resolve().parent.parent
SETTINGS_FILE = str(_PROJECT_ROOT / "settings.json")

def _load_settings() -> dict:
    try:
        with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def _save_settings(data: dict):
    try:
        existing = _load_settings()
        existing.update(data)
        with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
            json.dump(existing, f, ensure_ascii=False, indent=2)
    except Exception as e:
        import logging
        logging.error(f"Ayarlar kaydedilemedi: {e}")

# Dahili Tema Tanımları
DARK_THEME = """
QMainWindow {
    background-color: #1e1e2e;
}
QWidget {
    background-color: transparent;
    color: #cdd6f4;
    font-family: 'Segoe UI';
    font-size: 13px;
}


/* Scrollable container'lar ve sayfa widget'ları için arka plan */
QScrollArea > QWidget > QWidget,
QStackedWidget > QWidget {
    background-color: #1e1e2e;
}
QFrame#Sidebar {
    background-color: #181825;
    border-right: 1px solid #313244;
}
QStackedWidget#ContentArea {
    background-color: #1e1e2e;
}


/* Form paneli — koyu temada daha aydınlık arka plan */
QFrame#InvFormPanel,
QFrame#TicketFormFrame,
QFrame#DashRecentFrame {
    background-color: #2a2a3d;
    border: 1px solid #3d3d5a;
}
QPushButton#MenuButton {
    border: none;
    padding: 10px 14px;
    text-align: left;
    font-size: 13px;
    background: transparent;
    color: #cdd6f4;
    border-radius: 6px;
}
QPushButton#MenuButton:hover {
    background-color: #313244;
}
QPushButton#ActiveNav {
    background-color: rgba(137, 180, 250, 0.1);
    color: #89b4fa;
    border: none;
    padding: 10px 14px;
    text-align: left;
    font-size: 13px;
    font-weight: bold;
    border-radius: 6px;
}
QLabel#AppTitle {
    color: #89b4fa;
    font-size: 16px;
    font-weight: bold;
    background: transparent;
}

/* Sidebar Alt Paneller (Pill) */
QFrame#LicensePill {
    background-color: rgba(59, 130, 246, 0.1);
    border: 1px solid rgba(59, 130, 246, 0.2);
    border-radius: 25px;
}
QFrame#WebPortalPill {
    background-color: rgba(255, 255, 255, 0.03);
    border: 1px solid #313244;
    border-radius: 12px;
}
QLabel#LicenseTimer {
    color: #fab387;
    font-family: 'Consolas', monospace;
    font-size: 14px;
}
QLabel#WebPortalTitle {
    color: #cdd6f4;
    font-weight: bold;
    font-size: 11px;
}
QLabel#WebStatusLabel {
    font-weight: bold;
    font-size: 10px;
    color: #f38ba8; /* Default: KAPALI (Kırmızımtırak) */
}
QLabel#SidebarHint {
    color: #6c7086;
    font-size: 10px;
}

QTableWidget {
    background-color: #181825;
    alternate-background-color: #1e1e2e;
    gridline-color: #313244;
    color: #cdd6f4;
    border: 1px solid #313244;
    border-radius: 4px;
}
QTableWidget::item:selected {
    background-color: #313244;
}
QHeaderView::section {
    background-color: #181825;
    color: #89b4fa;
    padding: 8px;
    border: 1px solid #313244;
    font-weight: bold;
}
QTableWidget QTableCornerButton::section {
    background-color: #181825;
    border: 1px solid #313244;
}

QLineEdit, QTextEdit, QComboBox {
    background-color: #313244;
    color: #cdd6f4;
    border: 1px solid #45475a;
    border-radius: 4px;
    padding: 6px;
}
QLineEdit:focus, QTextEdit:focus {
    border: 1px solid #89b4fa;
}
QComboBox QAbstractItemView {
    background-color: #313244;
    color: #cdd6f4;
    selection-background-color: #45475a;
    selection-color: #89b4fa;
    border: 1px solid #45475a;
    outline: none;
}
QPushButton {
    background-color: #313244;
    color: #cdd6f4;
    border: 1px solid #45475a;
    border-radius: 4px;
    padding: 6px 12px;
}
QPushButton:hover {
    background-color: #45475a;
}
QPushButton:pressed {
    background-color: #585b70;
}
QTabWidget::pane {
    border: 1px solid #313244;
    background-color: #1e1e2e;
}
QTabBar::tab {
    background-color: #181825;
    color: #cdd6f4;
    padding: 8px 16px;
    border: 1px solid #313244;
}


QTabBar::tab:selected {
    background-color: #313244;
    color: #89b4fa;
}
QScrollBar:vertical {
    background-color: #181825;
    width: 10px;
}
QScrollBar::handle:vertical {
    background-color: #45475a;
    border-radius: 5px;
}
QMessageBox {
    background-color: #1e1e2e;
    color: #cdd6f4;
}
QCheckBox {
    color: #cdd6f4;
    background: transparent;
}
QCheckBox::indicator {
    border: 1px solid #45475a;
    background-color: #313244;
    border-radius: 3px;
    width: 14px;
    height: 14px;
}
QCheckBox::indicator:checked {
    background-color: #89b4fa;
}
QMessageBox, QDialog {
    background-color: #1e1e2e;
    color: #cdd6f4;
}
QMessageBox QLabel, QDialog QLabel {
    color: #cdd6f4;
    background-color: transparent;
}
QMessageBox QPushButton, QDialog QPushButton {
    background-color: #313244;
    color: #cdd6f4;
    border: 1px solid #45475a;
    border-radius: 4px;
    padding: 6px 16px;
    min-width: 64px;
}
QMessageBox QPushButton:hover, QDialog QPushButton:hover {
    background-color: #45475a;
}



"""


LIGHT_THEME = """
QMainWindow {
    background-color: #eff1f5;
}
QWidget {
    background-color: transparent;
    color: #4c4f69;
    font-family: 'Segoe UI';
    font-size: 13px;
}
QComboBox QAbstractItemView {
    background-color: #ffffff;
    color: #4c4f69;
    selection-background-color: #ccd0da;
    selection-color: #1e66f5;
    border: 1px solid #ccd0da;
    outline: none;
}



QScrollArea > QWidget > QWidget,
QStackedWidget > QWidget {
    background-color: #eff1f5;
}
QFrame#Sidebar {
    background-color: #dce0e8;
    border-right: 1px solid #ccd0da;
}
QStackedWidget#ContentArea {
    background-color: #eff1f5;
}
/* Form panelleri — açık temada beyaz arka plan */
QFrame#InvFormPanel,
QFrame#TicketFormFrame,
QFrame#DashReceıntFrame,
QFrame#DashRecentFrame {
    background-color: #ffffff;
    border: 1px solid #ccd0da;
}
QPushButton#MenuButton {
    border: none;
    padding: 10px 14px;
    text-align: left;
    font-size: 13px;
    background: transparent;
    color: #4c4f69;
    border-radius: 6px;
}
QPushButton#MenuButton:hover {
    background-color: #ccd0da;
}
QPushButton#ActiveNav {
    background-color: rgba(30, 102, 245, 0.1);
    color: #1e66f5;
    border: none;
    padding: 10px 14px;
    text-align: left;
    font-size: 13px;
    font-weight: bold;
    border-radius: 6px;
}
QLabel#AppTitle {
    color: #1e66f5;
    font-size: 16px;
    font-weight: bold;
    background: transparent;
}

/* Sidebar Alt Paneller (Pill) - Açık Tema */
QFrame#LicensePill {
    background-color: rgba(30, 102, 245, 0.05);
    border: 1px solid rgba(30, 102, 245, 0.2);
    border-radius: 25px;
}
QFrame#WebPortalPill {
    background-color: #e6e9ef;
    border: 1px solid #ccd0da;
    border-radius: 12px;
}
QLabel#LicenseTimer {
    color: #fe640b;
    font-family: 'Consolas', monospace;
    font-size: 14px;
}
QLabel#WebPortalTitle {
    color: #4c4f69;
    font-weight: bold;
    font-size: 11px;
}
QLabel#WebStatusLabel {
    font-weight: bold;
    font-size: 10px;
    color: #d20f39; /* Default: KAPALI (Kırmızı) */
}
QLabel#SidebarHint {
    color: #7c7f93;
    font-size: 10px;
}
QTableWidget {
    background-color: #ffffff;
    alternate-background-color: #eff1f5;
    gridline-color: #ccd0da;
    color: #4c4f69;
    border: 1px solid #ccd0da;
    border-radius: 4px;
}
QTableWidget::item:selected {
    background-color: #ccd0da;
}
QHeaderView::section {
    background-color: #e6e9ef;
    color: #1e66f5;
    padding: 8px;
    border: 1px solid #ccd0da;
    font-weight: bold;
}
QTableWidget QTableCornerButton::section {
    background-color: #e6e9ef;
    border: 1px solid #ccd0da;
}

QLineEdit, QTextEdit, QComboBox {
    background-color: #ffffff;
    color: #4c4f69;
    border: 1px solid #ccd0da;
    border-radius: 4px;
    padding: 6px;
}



QLineEdit:focus, QTextEdit:focus {
    border: 1px solid #1e66f5;
}
QPushButton {
    background-color: #e6e9ef;
    color: #4c4f69;
    border: 1px solid #ccd0da;
    border-radius: 4px;
    padding: 6px 12px;
}
QPushButton:hover {
    background-color: #ccd0da;
}
QTabWidget::pane {
    border: 1px solid #ccd0da;
    background-color: #eff1f5;
}
QTabBar::tab {
    background-color: #e6e9ef;
    color: #4c4f69;
    padding: 8px 16px;
    border: 1px solid #ccd0da;
}
QTabBar::tab:selected {
    background-color: #ffffff;
    color: #1e66f5;
}
QCheckBox {
    color: #4c4f69;
    background: transparent;
}
QScrollBar:vertical {
    background-color: #dce0e8;
    width: 10px;
}
QScrollBar::handle:vertical {
    background-color: #9ca0b0;
    border-radius: 5px;
}
QMessageBox, QDialog {
    background-color: #ffffff;
    color: #4c4f69;
}
QMessageBox QLabel, QDialog QLabel {
    color: #4c4f69;
    background-color: transparent;
}
QMessageBox QPushButton, QDialog QPushButton {
    background-color: #e6e9ef;
    color: #4c4f69;
    border: 1px solid #ccd0da;
    border-radius: 4px;
    padding: 6px 16px;
    min-width: 64px;
}
QMessageBox QPushButton:hover, QDialog QPushButton:hover {
    background-color: #ccd0da;
}



"""

class MainWindow(QMainWindow):
    def __init__(self, db_conn, user_data=None, lic_mgr=None):
        super().__init__()
        self.db_conn = db_conn
        self.user_data = user_data or {"role": "Admin", "username": "Admin"}
        self.lic_mgr = lic_mgr
        self.web_process = None
        # Kaydedilmiş temayı oku (yoksa koyu tema)
        saved_theme = _load_settings().get("theme", "dark")
        self.is_dark_theme = (saved_theme == "dark")

        # Uzaktan yönetim sunucusunu uygulama başladığında aktif et (Discovery için)
        self.remote_server = RemoteServer(host='0.0.0.0', port=7777)
        self.remote_server.start()

        self.content_area = QStackedWidget()
        self.content_area.setObjectName("ContentArea")
        
        self.pages = {}
        
        # Lisans kontrolü
        is_licensed = False
        if self.lic_mgr:
            is_licensed, _ = self.lic_mgr.check_license()
        
        page_classes = [
            ("dashboard", DashboardPage, (self.db_conn, self.user_data)),
            ("tickets",   TicketsPage,   (self.db_conn, self.user_data.get("username"))),
            ("inventory", InventoryPage, (self.db_conn, self.user_data.get("username"))),
            ("network",   NetworkPage,   (self.remote_server,)),
            ("printers",  PrintersPage,  ()),
            ("reports",   ReportsPage,   (self.db_conn,)),
            ("remote",    RemotePage,    (self.user_data, self.remote_server)),
            ("screenshots", ScreenshotsPage, ()),
            ("settings",  SettingsPage,  (
                self.db_conn, self.user_data,
                self.toggle_theme,
                lambda: self.is_dark_theme,
            )),
        ]

        for key, cls, args in page_classes:
            try:
                self.pages[key] = cls(*args)
                self.content_area.addWidget(self.pages[key])
                if key == "network":
                    self.pages[key].jump_to_remote.connect(self._handle_jump_to_remote)
            except Exception as e:
                import logging
                logging.error(f"Sayfa yüklenemedi ({key}): {e}")
                # Fallback widget if a page fails to load
                fallback = QWidget()
                flay = QVBoxLayout(fallback)
                flay.addWidget(QLabel(f"Hata: {key} sayfası yüklenemedi.\n{e}"))
                self.pages[key] = fallback
                self.content_area.addWidget(fallback)
                # Fallback widget if a page fails to load
                fallback = QWidget()
                flay = QVBoxLayout(fallback)
                flay.addWidget(QLabel(f"Hata: {key} sayfası yüklenemedi.\n{e}"))
                self.pages[key] = fallback


        self._setup_ui()
        self.apply_theme()  # Başlangıç temasını uygula

    def _handle_jump_to_remote(self, ip_addr):
        """Ağ sayfasından gelen 'Bu cihazı kontrol et' isteğini yönetir."""
        remote_page = self.pages.get("remote")
        if remote_page:
            # Önce listeyi zorla yenile (Yeni bağlantıları yakalamak için)
            remote_page.refresh_list()
            
            # IP adresine göre listedeki ismi bul ve seç
            for i in range(remote_page.client_list.count()):
                item_text = remote_page.client_list.item(i).text()
                if ip_addr in item_text:
                    remote_page.client_list.setCurrentRow(i)
                    self.switch_page("remote")
                    return
            QMessageBox.information(self, "Bilgi", f"{ip_addr} adresi aktif agent listesinde bulunamadı.\nLütfen agent'ın çalıştığından emin olun.")

    def refresh_sidebar(self):
        """Lisans aktivasyonu sonrası menüleri yeniden oluşturur."""
        # Mevcut butonları temizle
        import sip
        while self.nav_layout.count():
            item = self.nav_layout.takeAt(0)
            widget = item.widget()
            if widget:
                sip.delete(widget)
        
        self._menu_buttons = {}
        self._settings_hint = None
        
        # Sidebar layout'unu yeniden doldur
        self._setup_sidebar_content()

    def _on_data_changed(self):
        """Herhangi bir sayfada veri değiştiğinde Dashboard'u ve varsa diğer listeleri yeniler."""
        # Dashboard'u yenile
        dash = self.pages.get("dashboard")
        if dash and hasattr(dash, "refresh_data"):
            dash.refresh_data()
            
        # Raporlar sayfasındaysa orayı da yenile
        rep = self.pages.get("reports")
        if rep and hasattr(rep, '_refresh_filters'):
            rep._refresh_filters()

    def _on_departments_changed(self):
        """Müdürlük/Birim ekle-sil anında tüm dropdown'ları yeniler."""
        inv = self.pages.get("inventory")
        if inv and hasattr(inv, '_refresh_dropdowns'):
            inv._refresh_dropdowns()

        tck = self.pages.get("tickets")
        if tck and hasattr(tck, 'refresh_dropdowns'):
            tck.refresh_dropdowns()

        rep = self.pages.get("reports")
        if rep and hasattr(rep, '_refresh_filters'):
            rep._refresh_filters()

    def _setup_ui(self):
        # 1. Veritabanı Aktivite Güncelleme
        try:
            if self.user_data and "id" in self.user_data:
                self.db_conn.execute_query(
                    "UPDATE users SET last_active=? WHERE id=?", 
                    (str(int(time.time())) + "|desktop", self.user_data["id"])
                )
        except: pass

        # 2. Ana Layout Oluşturma
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QHBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # === SOL MENÜ (KAYDIRILABİLİR) ===
        self.sidebar = QFrame()
        self.sidebar.setObjectName("Sidebar")
        self.sidebar.setFixedWidth(230)
        
        sidebar_scroll = QScrollArea(self.sidebar)
        sidebar_scroll.setWidgetResizable(True)
        sidebar_scroll.setFrameShape(QFrame.NoFrame)
        sidebar_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        sidebar_scroll.setStyleSheet("background: transparent; border: none;")
        
        sidebar_container = QWidget()
        self.menu_layout = QVBoxLayout(sidebar_container)
        self.menu_layout.setObjectName("SidebarLayout")
        self.menu_layout.setContentsMargins(15, 20, 15, 20)
        self.menu_layout.setSpacing(10)
        sidebar_scroll.setWidget(sidebar_container)
        
        outer_sidebar_lay = QVBoxLayout(self.sidebar)
        outer_sidebar_lay.setContentsMargins(0,0,0,0)
        outer_sidebar_lay.addWidget(sidebar_scroll)

        app_title = QLabel("Bilgi İşlem Merkezi")
        app_title.setObjectName("AppTitle")
        app_title.setFont(QFont("Segoe UI", 15, QFont.Bold))
        app_title.setAlignment(Qt.AlignCenter)
        self.menu_layout.addWidget(app_title)
        self.menu_layout.addSpacing(20)

        self.menus_config = [
            ("🏠 Dashboard",        "dashboard"),
            ("🛠️ Arıza Kayıtları",   "tickets"),
            ("📦 Envanter",         "inventory"),
            ("🌐 Ağ Yönetimi",      "network"),
            ("🖨️ Yazıcı Merkezi",   "printers"),
            ("💻 Uzaktan Kontrol",  "remote"),
            ("📊 Raporlar",         "reports"),
            ("📂 Ekran Kayıtları",   "screenshots"),
            ("⚙️ Ayarlar",           "settings"),
        ]

        # Menü butonları için alt layout (Üst kısımda durması için)
        self.nav_layout = QVBoxLayout()
        self.nav_layout.setContentsMargins(0, 0, 0, 0)
        self.nav_layout.setSpacing(5)
        self.menu_layout.addLayout(self.nav_layout)

        self._menu_buttons = {}
        self._settings_hint = None

        # 3. Kenar Çubuğu İçeriklerini ve Sinyalleri Hazırla
        self._setup_sidebar_content() # Menüleri ekle

        # Alt Bölüm İçin Sabit Alanlar (Menülerden Sonra)
        self.menu_layout.addStretch()
        self._setup_license_pill()     
        self._setup_web_portal_pill()  
        self._setup_sidebar_footer()
        
        # ── İÇERİK ALANI HAZIRLIĞI ───────────────────────────────────────────
        content_wrapper = QWidget()
        content_vlay = QVBoxLayout(content_wrapper)
        content_vlay.setContentsMargins(0, 0, 0, 0)
        content_vlay.setSpacing(0)

        if self.user_data.get("username") == "Recovery":
            self.recovery_banner = QLabel(
                "🚨  SİSTEM KURTARMA MODUNDA ÇALIŞIYOR  —  "
                "Acil Durum Kurtarma Hesabı Aktif. "
                "İşiniz bittiğinde VANGUARD Toolkit'ten kalkanı kapatın."
            )
            self.recovery_banner.setAlignment(Qt.AlignCenter)
            self.recovery_banner.setStyleSheet(
                "background-color: #ef4444; color: white; font-weight: bold; "
                "font-size: 14px; padding: 12px; border: none;"
            )
            self.recovery_banner.setWordWrap(True)
            content_vlay.addWidget(self.recovery_banner)

            self._banner_timer = QTimer(self)
            self._banner_visible = True
            def _blink():
                self._banner_visible = not self._banner_visible
                op = "1" if self._banner_visible else "0.4"
                self.recovery_banner.setStyleSheet(
                    f"background-color: #ef4444; color: white; font-weight: bold; "
                    f"font-size: 14px; padding: 12px; border: none; opacity: {op};"
                )
            self._banner_timer.timeout.connect(_blink)
            self._banner_timer.start(800)

        content_vlay.addWidget(self.content_area)

        # ── ANA YERLEŞİM BİRLEŞTİRME ───────────────────────────────────────
        main_layout.addWidget(self.sidebar)
        main_layout.addWidget(content_wrapper)

        # Veri değişim sinyallerini bağla
        tpage = self.pages.get("tickets")
        if tpage and hasattr(tpage, 'data_changed'):
            tpage.data_changed.connect(self._on_data_changed)
        
        ipage = self.pages.get("inventory")
        if ipage and hasattr(ipage, 'data_changed'):
            ipage.data_changed.connect(self._on_data_changed)

        # Başlangıçta sunucu açıksa butonu güncelle (Pill yüklendikten sonra)
        if hasattr(self, 'web_toggle') and hasattr(self, '_is_server_listening'):
            if self._is_server_listening():
                self.web_toggle.blockSignals(True)
                self.web_toggle.setChecked(True)
                self.web_toggle.blockSignals(False)
                if hasattr(self, 'lbl_web_status'):
                    self.lbl_web_status.setText("AÇIK")
                    color = "#3b82f6" if not self.is_dark_theme else "#89b4fa"
                    self.lbl_web_status.setStyleSheet(f"color: {color}; font-weight: bold;")

    def _setup_sidebar_content(self):
        # Önceki butonları ve ipuçlarını temizle
        if hasattr(self, '_menu_buttons'):
            for btn in self._menu_buttons.values():
                btn.setParent(None)
                btn.deleteLater()
            self._menu_buttons = {}
        
        # Ayarlar ipucunu temizle (eğer varsa)
        if hasattr(self, '_settings_hint') and self._settings_hint:
            self._settings_hint.setParent(None)
            self._settings_hint.deleteLater()
            self._settings_hint = None

        # Lisans kontrolü
        is_licensed = False
        if self.lic_mgr:
            is_licensed, _ = self.lic_mgr.check_license()

        # Menüleri filtrele
        filtered_menus = []
        premium_keys = ["printers", "remote", "reports"]
        
        for text, key in self.menus_config:
            if not is_licensed and key in premium_keys:
                continue
            filtered_menus.append((text, key))

        # Yetkiye göre filtrele
        is_admin = self.user_data.get("role") == "Admin"
        if not is_admin:
            perms_str = str(self.user_data.get("permissions", ""))
            if perms_str != "*" and perms_str.strip() != "":
                allowed = [p.strip() for p in perms_str.split(",")]
                allowed += ["dashboard", "settings"]
                if any(p in allowed for p in ['remote_screen', 'remote_msg', 'remote_cmd', 'remote']):
                    allowed.append("remote")
                    allowed.append("screenshots")
                filtered_menus = [m for m in filtered_menus if m[1] in allowed]

        # Butonları oluştur ve ekle
        for text, key in filtered_menus:
            btn = QPushButton(text)
            btn.setObjectName("MenuButton")
            btn.setCursor(Qt.PointingHandCursor)
            btn.clicked.connect(lambda checked, k=key: self.switch_page(k))
            
            # Navigasyon layout'una ekle
            self.nav_layout.addWidget(btn)
            self._menu_buttons[key] = btn

            if key == "settings":
                self._settings_hint = QLabel("  Tema · Org · Kullanıcılar · Loglar")
                self._settings_hint.setObjectName("SidebarHint")
                self.nav_layout.addWidget(self._settings_hint)

    def _setup_license_pill(self):
        self.license_panel = QFrame()
        self.license_panel.setObjectName("LicensePill")
        self.license_panel.setFixedHeight(50)
        self.license_panel.setContentsMargins(0, 0, 0, 0)
        
        lic_layout = QHBoxLayout(self.license_panel)
        lic_layout.setContentsMargins(15, 0, 10, 0)
        lic_layout.setSpacing(10)

        self.lbl_timer = QLabel("05:00")
        self.lbl_timer.setObjectName("LicenseTimer")
        self.lbl_timer.setStyleSheet("font-weight: 800; font-family: 'Segoe UI', sans-serif; font-size: 14px;") # Sadece font kalsın, renk QSS'den gelir (veya label'a özel renk verelim)
        
        self.separator = QLabel("|")
        self.separator.setStyleSheet("color: rgba(128,128,128,0.3); font-size: 16px;")

        self.btn_license_icon = QPushButton("🔑 Etkinleştir")
        self.btn_license_icon.setCursor(Qt.PointingHandCursor)
        self.btn_license_icon.setObjectName("LicenseActionBtn")
        self.btn_license_icon.setStyleSheet("QPushButton { background: transparent; color: #3b82f6; border: none; font-weight: bold; font-size: 12px; padding: 5px; } QPushButton:hover { color: #60a5fa; }")
        self.btn_license_icon.clicked.connect(self.show_license_dialog)

        lic_layout.addWidget(self.lbl_timer)
        lic_layout.addWidget(self.separator)
        lic_layout.addWidget(self.btn_license_icon)
        lic_layout.addStretch()
        
        self.menu_layout.addWidget(self.license_panel)

        self.time_left = 300 
        self.lic_timer = QTimer(self)
        self.lic_timer.timeout.connect(self.update_license_timer)
        
        if self.lic_mgr:
            # Doğrudan DB üzerinden kontrol et (Web sunucusunu beklemeyi önler)
            is_ok, _ = self.lic_mgr.check_license(self.db_conn)
            if not is_ok: self.lic_timer.start(1000)
            else: self.license_panel.hide()

    def _setup_web_portal_pill(self):
        web_panel = QFrame()
        web_panel.setObjectName("WebPortalPill")
        web_panel.setFixedHeight(55)
        web_lay = QHBoxLayout(web_panel)
        web_lay.setContentsMargins(15, 8, 15, 8)
        
        lbl_web = QLabel("🌐 WEB PORTAL")
        lbl_web.setObjectName("WebPortalTitle")
        
        self.lbl_web_status = QLabel("KAPALI")
        self.lbl_web_status.setObjectName("WebStatusLabel")
        self.lbl_web_status.setFixedWidth(50)
        self.lbl_web_status.setAlignment(Qt.AlignCenter)
        
        self.web_toggle = ModernToggle(width=40)
        self.web_toggle.toggled.connect(self.toggle_web_server)
        
        web_lay.addWidget(lbl_web)
        web_lay.addStretch()
        web_lay.addWidget(self.lbl_web_status)
        web_lay.addWidget(self.web_toggle)
        
        self.menu_layout.addWidget(web_panel)

    def _setup_sidebar_footer(self):
        """Alt kısma minimalist tema değiştirici ekler."""
        footer_panel = QFrame()
        footer_panel.setObjectName("SidebarFooter")
        footer_panel.setFixedHeight(40)
        footer_panel.setStyleSheet("background: transparent; border: none;")
        
        foot_lay = QHBoxLayout(footer_panel)
        foot_lay.setContentsMargins(15, 0, 15, 0)
        
        lbl_theme = QLabel("🌓 Tema Değiştir")
        lbl_theme.setStyleSheet("color: #94a3b8; font-size: 11px; font-weight: bold; border: none;")
        
        self.theme_switch = ModernToggle(width=34)
        self.theme_switch.setChecked(not self.is_dark_theme)
        self.theme_switch.toggled.connect(self.toggle_theme)
        
        foot_lay.addWidget(lbl_theme)
        foot_lay.addStretch()
        foot_lay.addWidget(self.theme_switch)
        
        self.menu_layout.addWidget(footer_panel)


    def _is_server_listening(self) -> bool:
        """Port 5000'de bir servis olup olmadığını kontrol eder."""
        import socket
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(0.3)
                return s.connect_ex(('127.0.0.1', 5000)) == 0
        except Exception:
            return False

    def toggle_web_server(self, checked):
        # Hızlı tıklamaları önlemek için butonu geçici olarak devre dışı bırak
        self.web_toggle.setEnabled(False)
        QTimer.singleShot(1500, lambda: self.web_toggle.setEnabled(True))

        if checked:
            if self.web_process is None:
                try:
                    self.web_process = subprocess.Popen([sys.executable, "web_server.py"])
                    self.lbl_web_status.setText("AÇIK")
                    color = "#3b82f6" if not self.is_dark_theme else "#89b4fa"
                    self.lbl_web_status.setStyleSheet(f"color: {color}; font-weight: bold;")
                except Exception as e:
                    import logging
                    logging.error(f"Web sunucu baslatilamadi: {e}")
                    QMessageBox.critical(self, "Hata", f"Web portalı başlatılamadı:\n{e}")
                    self.web_process = None
                    self.web_toggle.setChecked(False)
        else:
            # Kapatma işlemi
            try:
                if self.web_process:
                    self.web_process.terminate()
                    self.web_process = None
                
                if os.name == 'nt':
                    import threading
                    def kill_zombie_servers():
                        try:
                            # Portu kullanan pilleri temizle
                            subprocess.call(['taskkill', '/F', '/IM', 'python.exe', '/FI', 'WINDOWTITLE eq web_server*'], 
                                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                            # Daha spesifik bir yöntem:
                            output = subprocess.check_output('netstat -ano | findstr :5000', shell=True).decode()
                            for line in output.strip().split('\n'):
                                parts = line.split()
                                if len(parts) > 4 and 'LISTENING' in line:
                                    pid = parts[-1]
                                    subprocess.call(['taskkill', '/F', '/PID', pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        except: pass
                    threading.Thread(target=kill_zombie_servers, daemon=True).start()
                
                self.lbl_web_status.setText("KAPALI")
                color = "#dc3545" if not self.is_dark_theme else "#f38ba8"
                self.lbl_web_status.setStyleSheet(f"color: {color}; font-weight: bold;")
            except Exception as e:
                import logging
                logging.error(f"Sunucu durdurma hatası: {e}")

        # Dashboard'u sadece bir kez, sunucu ayağa kalktığında/kapandığında yenile
        # Kullanım: singleShot(ms, context_object, callback) -> Context silinirse timer ölür
        QTimer.singleShot(2000, self, self._refresh_dashboard)

    def _refresh_dashboard(self):
        """Dashboard web sunucu kartını hemen günceller."""
        dash = self.pages.get("dashboard")
        if dash and hasattr(dash, 'refresh_data'):
            dash.refresh_data()

    def open_web_portal(self):
        import webbrowser
        import urllib.parse
        import time
        import hashlib
        
        u = self.user_data.get('username')
        p = self.user_data.get('password')
        
        if u and p:
            t = str(int(time.time()))
            token = hashlib.sha256(f"{u}:{p}:{t}:IT_TECH_SECRET".encode()).hexdigest()
            url = f"http://127.0.0.1:5000/auto_login?u={urllib.parse.quote(u)}&t={t}&token={token}"
        else:
            url = "http://127.0.0.1:5000/"
            
        webbrowser.open(url)

    def closeEvent(self, event):
        """Uygulama kapatılırken temizlik yapar."""
        # 1. Dashboard Thread'ini Güvenli Durdur
        dash = self.pages.get("dashboard")
        if dash and hasattr(dash, "_worker_thread") and dash._worker_thread.isRunning():
            dash._worker_thread.quit()
            dash._worker_thread.wait(1000) # Maksimum 1 saniye bekle
        
        # 2. Web Sunucusunu Kapat
        if self.web_process:
            try:
                if os.name == 'nt':
                    subprocess.call(['taskkill', '/F', '/T', '/PID', str(self.web_process.pid)], 
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                else:
                    self.web_process.terminate()
            except Exception:
                pass
        
        super().closeEvent(event)

    def switch_page(self, key, tab_index=None):
        if key == "screenshots":
            import os
            path = "screenshots"
            if not os.path.exists(path): os.makedirs(path)
            os.startfile(path)
            return

        if key not in self.pages:
            return
        page = self.pages[key]
        self.content_area.setCurrentWidget(page)

        # Sidebar buton vurgulamasını güncelle
        for k, btn in self._menu_buttons.items():
            btn.setObjectName("ActiveNav" if k == key else "MenuButton")
            btn.style().unpolish(btn)
            btn.style().polish(btn)


        # Eğer sayfa içinde sekmeler varsa ve tab_index belirtilmişse ilgili sekmeye geç
        if tab_index is not None and hasattr(page, "tabs"):
            page.tabs.setCurrentIndex(tab_index)

        # Dashboard: veri yenile
        if key == "dashboard" and hasattr(page, 'refresh_data'):
            page.refresh_data()
            return

        # Müdürlük/Birim dropdown kullanan sayfalar: geçişte yenile
        if key == "inventory":
            if hasattr(page, 'load_inventory'):
                page.load_inventory()          # _refresh_dropdowns + tablo
        elif key == "tickets":
            if hasattr(page, 'refresh_dropdowns'):
                page.refresh_dropdowns()       # cascade dropdown yenile
        elif key == "reports":
            if hasattr(page, '_refresh_filters'):
                page._refresh_filters()
        elif key == "settings":
            if hasattr(page, 'refresh_logs'):
                page.refresh_logs()   # Loglar sekmesini yenile


    def toggle_theme(self):
        self.is_dark_theme = not self.is_dark_theme
        self.apply_theme()
        # Tema seçimini kaydet
        _save_settings({"theme": "dark" if self.is_dark_theme else "light"})

    def update_license_timer(self):
        self.time_left -= 1
        if self.time_left <= 0:
            self.lic_timer.stop()
            QMessageBox.critical(self, "Süre Doldu", "5 dakikalık deneme süreniz doldu. Program kapatılacaktır.")
            sys.exit(0)
        
        mins, secs = divmod(self.time_left, 60)
        self.lbl_timer.setText(f"{mins:02d}:{secs:02d}")
        
        if self.time_left < 60:
            # Kritik süre rengi (Koyu temada açık kırmızı, Açık temada koyu kırmızı)
            crit_color = "#f38ba8" if self.is_dark_theme else "#d20f39"
            self.lbl_timer.setStyleSheet(f"color: {crit_color}; font-weight: bold; font-family: 'Consolas'; font-size: 15px;")

    def on_license_activated(self):
        """Lisans aktif edildikten sonra timer'ı durdurur ve UI'ı yeniler."""
        if hasattr(self, 'lic_timer'):
            self.lic_timer.stop()
        
        if hasattr(self, 'license_panel'):
            self.license_panel.hide()
            
        self.is_licensed = True
        self.refresh_sidebar() # Menüleri yeniden oluştur (Sınırsız modda)
        QMessageBox.information(self, "Başarılı", "Lisans etkinleştirildi! Tüm kısıtlamalar kaldırıldı.")

    def show_license_dialog(self):
        if not self.lic_mgr: return
        dialog = LicenseDialog(self.lic_mgr, self)
        if dialog.exec() == LicenseDialog.Accepted:
            self.on_license_activated()

    def apply_theme(self):
        if self.is_dark_theme:
            self.setStyleSheet(DARK_THEME)
        else:
            self.setStyleSheet(LIGHT_THEME)


# Açıklama: Yeni eklenen Cihaz Envanteri ve Arıza Kayıtları ekranlarını yükleyen,
# dahili QSS tabanlı açık/koyu temayı barındıran ana pencere.
# qdarktheme bağımlılığı kaldırıldı - tüm stiller dahili olarak tanımlanmıştır.
