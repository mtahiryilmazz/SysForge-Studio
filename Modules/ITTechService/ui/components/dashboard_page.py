import webbrowser
import datetime
import requests
import os
import socket
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QFrame,
    QGridLayout, QPushButton, QScrollArea, QSizePolicy
)
from PySide6.QtCore import Qt, QTimer, QThread, Signal
from PySide6.QtGui import QFont
import shiboken6 as shiboken # Validity guard

from database.connection import DatabaseConnection
from .ui_utils import GenericWorker


# ─────────────────────────────────────────────────────────────────────────────
#  RENKLİ KART — v4
# ─────────────────────────────────────────────────────────────────────────────
class DashboardCard(QFrame):
    def __init__(self, title, value, icon, bg_color):
        super().__init__()
        self.setObjectName("DashboardCard")
        self.setCursor(Qt.PointingHandCursor)
        self.bg_color = bg_color
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(15, 15, 15, 15)
        layout.setSpacing(5)

        header = QHBoxLayout()
        self.icon_lbl = QLabel(icon)
        self.icon_lbl.setStyleSheet("font-size: 24px; background: transparent; border: none;")
        header.addWidget(self.icon_lbl)
        
        self.title_lbl = QLabel(title)
        self.title_lbl.setStyleSheet("color: white; font-weight: 600; font-size: 14px; background: transparent; border: none;")
        header.addWidget(self.title_lbl)
        header.addStretch()
        layout.addLayout(header)

        self.value_lbl = QLabel(value)
        self.value_lbl.setStyleSheet("color: white; font-size: 32px; font-weight: 800; background: transparent; border: none;")
        layout.addWidget(self.value_lbl)

        trend = QLabel("▲ Güncel Veri")
        trend.setStyleSheet("color: rgba(255,255,255,0.7); font-size: 11px; background: transparent; border: none;")
        layout.addWidget(trend)

        self.apply_style()

    def apply_style(self):
        self.setStyleSheet(f"""
            QFrame#DashboardCard {{
                background-color: {self.bg_color};
                border-radius: 12px;
                border: 1px solid rgba(255,255,255,0.1);
            }}
            QFrame#DashboardCard:hover {{
                border: 1px solid white;
            }}
        """)

    def set_value(self, val):
        self.value_lbl.setText(val)

# ─────────────────────────────────────────────────────────────────────────────
#  STATUS CARD — Web Sunucusu Durumu
# ─────────────────────────────────────────────────────────────────────────────
class ServerStatusCard(QFrame):
    def __init__(self):
        super().__init__()
        self.setObjectName("ServerStatusCard")
        self.setStyleSheet("""
            QFrame#ServerStatusCard {
                background-color: #1e293b;
                border: 1px solid rgba(255,255,255,0.1);
                border-radius: 12px;
                padding: 15px;
            }
        """)
        
        layout = QHBoxLayout(self)
        info_lay = QVBoxLayout()
        title = QLabel("WEB PORTAL DURUMU")
        title.setStyleSheet("color: #94a3b8; font-size: 11px; font-weight: 800; border: none;")
        info_lay.addWidget(title)
        
        self.status_lbl = QLabel("KONTROL EDİLİYOR...")
        self.status_lbl.setStyleSheet("color: white; font-size: 16px; font-weight: 700; border: none;")
        info_lay.addWidget(self.status_lbl)
        layout.addLayout(info_lay)
        layout.addStretch()
        
        self.indicator = QFrame()
        self.indicator.setFixedSize(12, 12)
        self.indicator.setStyleSheet("background-color: #4b5563; border-radius: 6px;")
        layout.addWidget(self.indicator)
        
        layout.addSpacing(20)
        
        # IP Label & Button Container
        act_lay = QVBoxLayout()
        self.ip_lbl = QLabel("Erişim: http://localhost:5000")
        self.ip_lbl.setStyleSheet("color: #64748b; font-size: 11px; font-weight: 500; border: none;")
        self.ip_lbl.setVisible(False)
        act_lay.addWidget(self.ip_lbl)
        
        self.btn_open = QPushButton("🌐 Web Portalı Aç")
        self.btn_open.setCursor(Qt.PointingHandCursor)
        self.btn_open.setVisible(False)
        self.btn_open.setStyleSheet("""
            QPushButton {
                background-color: #3b82f6; color: white; border-radius: 6px; 
                padding: 6px 15px; font-weight: bold; font-size: 12px; border: none;
            }
            QPushButton:hover { background-color: #2563eb; }
        """)
        self.btn_open.clicked.connect(self._open_portal)
        act_lay.addWidget(self.btn_open)
        layout.addLayout(act_lay)

    def _open_portal(self):
        url = self.ip_lbl.text().replace("Erişim: ", "")
        __import__('PySide6.QtGui', fromlist=['QDesktopServices']).QDesktopServices.openUrl(
            __import__('PySide6.QtCore', fromlist=['QUrl']).QUrl(url)
        )

    def set_status(self, is_on, local_ip=None):
        if is_on:
            self.status_lbl.setText("🟢 ÇALIŞIYOR")
            self.indicator.setStyleSheet("background-color: #10b981; border-radius: 6px; border: 2px solid #064e3b;")
            self.btn_open.setVisible(True)
            if local_ip:
                self.ip_lbl.setText(f"Erişim: http://{local_ip}:5000")
                self.ip_lbl.setVisible(True)
        else:
            self.status_lbl.setText("🔴 KAPALI")
            self.indicator.setStyleSheet("background-color: #ef4444; border-radius: 6px; border: 2px solid #7f1d1d;")
            self.btn_open.setVisible(False)
            self.ip_lbl.setVisible(False)

# ─────────────────────────────────────────────────────────────────────────────
#  DASHBOARD SAYFASI (Persistent Threading & Restored Features)
# ─────────────────────────────────────────────────────────────────────────────
class DashboardPage(QWidget):
    refresh_needed = Signal()

    def __init__(self, db_conn: DatabaseConnection, user_data=None):
        super().__init__()
        self.setObjectName("DashboardPage")
        self.db = db_conn
        self.user_data = user_data or {}
        
        self.cards = []
        self._last_ticket_data = []
        self._setup_ui()
        
        # ── Persistent Threading ──
        self._worker_thread = QThread(self)
        self.worker = GenericWorker(self._fetch_all_dashboard_data)
        self.worker.moveToThread(self._worker_thread)
        
        self.refresh_needed.connect(self.worker.run)
        self.worker.finished.connect(self._on_data_loaded)
        self.worker.error.connect(lambda e: print(f"Dashboard hatası: {e}"))
        
        self._worker_thread.start()
        self.refresh_data()

        # Otomatik yenileme (20 saniye)
        self._auto_timer = QTimer(self)
        self._auto_timer.timeout.connect(self.refresh_data)
        self._auto_timer.start(20000)

    def _setup_ui(self):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setStyleSheet("background: transparent; border: none;")
        
        content = QWidget()
        content.setStyleSheet("background: transparent;")
        main_lay = QVBoxLayout(content)
        main_lay.setContentsMargins(0, 0, 0, 0)
        main_lay.setSpacing(25)

        # Header
        header = QHBoxLayout()
        name = self.user_data.get('username', 'Kullanıcı')
        welcome = QLabel(f"Tekrar Hoş Geldiniz, {name} 👋")
        welcome.setStyleSheet("color: white; font-size: 28px; font-weight: 800; border: none;")
        header.addWidget(welcome)
        header.addStretch()
        
        self.btn_refresh = QPushButton("🔄 Yenile")
        self.btn_refresh.setCursor(Qt.PointingHandCursor)
        self.btn_refresh.setStyleSheet("""
            QPushButton {
                background: rgba(255, 255, 255, 0.05); color: white; padding: 10px 20px; 
                border-radius: 8px; border: 1px solid rgba(255,255,255,0.1); font-weight: bold;
            }
            QPushButton:hover { background: rgba(255, 255, 255, 0.1); border-color: white; }
        """)
        self.btn_refresh.clicked.connect(self.refresh_data)
        header.addWidget(self.btn_refresh)
        main_lay.addLayout(header)

        # Stats
        stats_grid = QGridLayout()
        stats_grid.setSpacing(20)
        self.card_open = DashboardCard("Açık Talepler", "0", "🔓", "#3b82f6")
        self.card_closed = DashboardCard("Bitiş", "0", "✅", "#10b981")
        self.card_inv = DashboardCard("Envanter", "0", "📦", "#f59e0b")
        self.card_users = DashboardCard("Personel", "0", "👥", "#8b5cf6")
        stats_grid.addWidget(self.card_open, 0, 0)
        stats_grid.addWidget(self.card_closed, 0, 1)
        stats_grid.addWidget(self.card_inv, 0, 2)
        stats_grid.addWidget(self.card_users, 0, 3)
        main_lay.addLayout(stats_grid)

        # Sunucu Kartı
        self.server_card = ServerStatusCard()
        main_lay.addWidget(self.server_card)

        # ── SON TALEPLER (BEKLEYEN ARIZALAR) RESTORASYONU ──
        lbl_recent = QLabel("⚡ BEKLEYEN ARIZALAR (SON 5)")
        lbl_recent.setStyleSheet("color: #94a3b8; font-size: 13px; font-weight: 800; letter-spacing: 1px; border: none; margin-top: 10px;")
        main_lay.addWidget(lbl_recent)

        self.tickets_container = QVBoxLayout()
        self.tickets_container.setSpacing(10)
        main_lay.addLayout(self.tickets_container)

        main_lay.addStretch()
        scroll.setWidget(content)
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.addWidget(scroll)

    def refresh_data(self):
        """Safe refresh trigger."""
        if not shiboken.isValid(self): return
        try:
            if not self._worker_thread.isRunning():
                self._worker_thread.start()
            
            # Parametreleri UI thread'inde yakala ve worker'a ilet
            # (Dashboard şu an parametresiz ama yapıyı bozmamak için emit ediyoruz)
            self.refresh_needed.emit()
            self.btn_refresh.setEnabled(False)
            self.btn_refresh.setText("⏳")
        except: pass

    def _fetch_all_dashboard_data(self):
        try:
            counts = {
                "open":   self._count("SELECT COUNT(*) FROM tickets WHERE status='Açık'"),
                "closed": self._count("SELECT COUNT(*) FROM tickets WHERE status='Kapalı'"),
                "inv":    self._count("SELECT COUNT(*) FROM inventory"),
                "users":  self._count("SELECT COUNT(*) FROM users")
            }
            recent = self.db.fetch_data(
                "SELECT personnel_name, department, issue_type, priority, status, description "
                "FROM tickets WHERE status='Açık' ORDER BY id DESC LIMIT 5"
            )
            
            # Port Check
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.3)
            res = sock.connect_ex(('127.0.0.1', 5000))
            sock.close()
            
            # Local IP
            local_ip = "127.0.0.1"
            if res == 0:
                try:
                    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    s.settimeout(0)
                    # Doesn't have to be reachable
                    s.connect(('8.8.8.8', 1))
                    local_ip = s.getsockname()[0]
                    s.close()
                except Exception:
                    local_ip = socket.gethostbyname(socket.gethostname())

            return {
                "counts": counts, 
                "recent": [dict(r) for r in recent], 
                "server_on": res == 0,
                "local_ip": local_ip
            }
        except: return None

    def _count(self, q):
        res = self.db.fetch_data(q)
        return res[0][0] if res else 0

    def _on_data_loaded(self, data):
        if not shiboken.isValid(self) or not data: 
            if shiboken.isValid(self): 
                self.btn_refresh.setEnabled(True)
                self.btn_refresh.setText("🔄 Yenile")
            return
        
        try:
            counts = data["counts"]
            self.card_open.set_value(str(counts["open"]))
            self.card_closed.set_value(str(counts["closed"]))
            self.card_inv.set_value(str(counts["inv"]))
            self.card_users.set_value(str(counts["users"]))
            
            # Sunucu Kartı GÜNCELLE (IP dahil)
            self.server_card.set_status(data["server_on"], data.get("local_ip"))
            
            # TALEPLERİ GÜNCELLE
            if data["recent"] != self._last_ticket_data:
                self._update_tickets_list(data["recent"])
                self._last_ticket_data = data["recent"]

            self.btn_refresh.setEnabled(True)
            self.btn_refresh.setText("🔄 Yenile")
        except: pass

    def _update_tickets_list(self, tickets):
        """Konteyneri temizler ve yeni biletleri ekler (Dar ve Satır İçi Detaylı)."""
        while self.tickets_container.count():
            item = self.tickets_container.takeAt(0)
            if item.widget(): item.widget().deleteLater()

        if not tickets:
            lbl = QLabel("Bekleyen bilet bulunamadı. Aktif arıza yok.")
            lbl.setStyleSheet("color: #6c7086; font-style: italic; padding: 10px; border: none;")
            self.tickets_container.addWidget(lbl)
            return

        for t in tickets:
            row = QFrame()
            row.setObjectName("TicketRow")
            row.setStyleSheet("""
                QFrame#TicketRow {
                    background-color: rgba(255, 255, 255, 0.02);
                    border: 1px solid rgba(255,255,255,0.05);
                    border-radius: 8px; padding: 10px 15px;
                }
                QFrame#TicketRow:hover { border-color: #3b82f6; background-color: rgba(255,255,255,0.04); }
            """)
            rlay = QVBoxLayout(row)
            rlay.setSpacing(2)
            
            # Üst Satır: İsim, Birim ve Öncelik
            top_row = QHBoxLayout()
            top_row.setContentsMargins(0, 0, 0, 0)
            
            name_unit = QLabel(f"<b>{t['personnel_name']}</b> <span style='color:#94a3b8;'>({t['unit_name'] if 'unit_name' in t else t['department']})</span>")
            name_unit.setStyleSheet("color: #cdd6f4; font-size: 13px; border: none;")
            top_row.addWidget(name_unit)
            
            top_row.addStretch()
            
            prio = QLabel(t['priority'].upper())
            col = "#f38ba8" if t['priority'] == 'Acil' else "#fab387"
            prio.setStyleSheet(f"color: {col}; font-weight: 900; font-size: 9px; border: 1px solid {col}44; border-radius: 3px; padding: 1px 6px; background: {col}11;")
            top_row.addWidget(prio)
            rlay.addLayout(top_row)
            
            # Alt Satır: Detay
            desc = QLabel(f"{t['issue_type']}: {t['description']}")
            desc.setWordWrap(True)
            desc.setStyleSheet("color: #6c7086; font-size: 11px; border: none; padding-top: 2px;")
            rlay.addWidget(desc)
            
            self.tickets_container.addWidget(row)

    def closeEvent(self, event):
        if hasattr(self, '_auto_timer'):
            self._auto_timer.stop()
        if self._worker_thread.isRunning():
            self._worker_thread.quit()
            self._worker_thread.wait()
        super().closeEvent(event)
