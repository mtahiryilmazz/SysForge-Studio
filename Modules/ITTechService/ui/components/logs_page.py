# Dosya Adı: logs_page.py — Sadece Admin erişebilir
import datetime
import shiboken6 as shiboken
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QTableWidget,
    QTableWidgetItem, QPushButton, QHeaderView, QComboBox,
    QLineEdit, QFrame, QMessageBox
)
from PySide6.QtCore import Qt, QThread, Signal, Slot
from PySide6.QtGui import QFont
from database.connection import DatabaseConnection
from .ui_utils import GenericWorker
from ui.premium_styles import PremiumStyles
from .ui_utils import IPTableWidgetItem

class LogsPage(QWidget):
    """Sistem log görüntüleme sayfası — Yalnızca Admin."""
    # Sinyali argümanlı tanımlayarak filtreleri arka plana güvenli taşıyoruz
    refresh_needed = Signal(str, str)

    def __init__(self, db_conn: DatabaseConnection):
        super().__init__()
        self.setObjectName("LogsPage")
        self.db = db_conn
        self._setup_ui()
        
        # ── Persistent Threading Model ──
        self._worker_thread = QThread(self)
        self.worker = GenericWorker(self._fetch_logs_background)
        self.worker.moveToThread(self._worker_thread)
        
        # Sinyal bağlantısı: refresh_needed(filter1, filter2) -> worker.run(filter1, filter2)
        # Not: GenericWorker.run metodu *args destekleyecek şekilde güncellenmeli veya lambda kullanılmalı
        self.refresh_needed.connect(self.worker.run)
        self.worker.finished.connect(self._on_logs_loaded)
        self.worker.error.connect(lambda e: print(f"Log Yükleme Hatası: {e}"))
        
        self._worker_thread.start()
        self.load_logs()

    def _setup_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(28, 24, 28, 24)
        root.setSpacing(16)

        title = QLabel("📝  Sistem Log Kayıtları")
        title.setFont(QFont("Segoe UI", 18, QFont.Bold))
        title.setStyleSheet("color: #cdd6f4;")
        root.addWidget(title)

        self.lbl_loading = QLabel("")
        self.lbl_loading.setStyleSheet("color: #fab387; font-weight: bold; font-size: 12px;")
        root.addWidget(self.lbl_loading)

        filter_row = QHBoxLayout()
        self.cmb_type = QComboBox()
        self.cmb_type.addItems(["Tüm İşlemler", "EKLE", "SİL", "GÜNCELLE", "GİRİŞ", "GİRİŞ_HATA", "SİSTEM"])
        self.cmb_type.currentIndexChanged.connect(self.load_logs)

        self.inp_user = QLineEdit()
        self.inp_user.setPlaceholderText("Kullanıcı ara…")
        self.inp_user.textChanged.connect(self.load_logs)

        btn_clear = QPushButton("🗑️  Logları Temizle")
        btn_clear.clicked.connect(self._clear_logs)
        btn_clear.setStyleSheet("background-color: #f38ba8; color: #1e1e2e; font-weight: bold; border-radius: 7px; padding: 8px 16px;")

        btn_refresh = QPushButton("🔄  Yenile")
        btn_refresh.clicked.connect(self.load_logs)
        btn_refresh.setStyleSheet("background-color: #89b4fa; color: #1e1e2e; font-weight: bold; border-radius: 7px; padding: 8px 16px;")

        filter_row.addWidget(QLabel("Filtre:"))
        filter_row.addWidget(self.cmb_type)
        filter_row.addWidget(self.inp_user)
        filter_row.addStretch()
        filter_row.addWidget(btn_refresh)
        filter_row.addWidget(btn_clear)
        root.addLayout(filter_row)

        self.table = QTableWidget(0, 5)
        self.table.setSortingEnabled(True)
        self.table.setHorizontalHeaderLabels(["ID", "Kullanıcı", "Zaman", "İşlem", "Detay"])
        self.table.horizontalHeader().setSectionResizeMode(4, QHeaderView.Stretch)
        self.table.setColumnHidden(0, True) # ID'yi Gizle
        root.addWidget(self.table)

    def load_logs(self):
        """Thread tetikleyici. Parametreleri UI thread'inden yakalar."""
        if not shiboken.isValid(self): return
        
        # Filtreleri UI thread'inde oku
        action = self.cmb_type.currentText()
        user = self.inp_user.text().strip().lower()
        
        self.lbl_loading.setText("⏳ Loglar yükleniyor...")
        self.refresh_needed.emit(action, user)

    def _fetch_logs_background(self, action_filter, user_filter):
        """BU FONKSİYON ARKA PLANDA ÇALIŞIR. UI ERİŞİMİ YASAKTIR."""
        try:
            # Sadece DB erişimi yap
            query = "SELECT id, user_info, timestamp, action_type, result FROM logs ORDER BY id DESC LIMIT 500"
            rows = self.db.fetch_data(query)
            
            filtered_rows = []
            for row_data in rows:
                d = dict(row_data)
                # Filtreleme mantığı
                if action_filter != "Tüm İşlemler" and d.get("action_type") != action_filter:
                    continue
                if user_filter and user_filter not in str(d.get("user_info", "")).lower():
                    continue
                filtered_rows.append(d)
            return filtered_rows
        except Exception as e:
            import logging
            logging.error(f"Log çekme hatası: {e}")
            raise e # Hata Worker tarafından yakalanıp emit edilecek

    def _on_logs_loaded(self, rows):
        """UI Thread'inde çalışır."""
        if not shiboken.isValid(self): return
        self.lbl_loading.setText("")
        self.table.setSortingEnabled(False)
        self.table.setRowCount(0)

        ACTION_COLORS = {"EKLE": "#a6e3a1", "SİL": "#f38ba8", "GÜNCELLE": "#fab387", "GİRİŞ": "#89b4fa"}

        for d in rows:
            r = self.table.rowCount()
            self.table.insertRow(r)
            ts = d.get("timestamp", "")
            try: ts_fmt = datetime.datetime.fromisoformat(ts).strftime("%d.%m.%Y %H:%M:%S")
            except: ts_fmt = ts

            cells = [str(d.get("id", "")), d.get("user_info", ""), ts_fmt, d.get("action_type", ""), d.get("result", "")]
            for ci, val in enumerate(cells):
                item = IPTableWidgetItem(val)
                item.setFlags(item.flags() ^ Qt.ItemIsEditable)
                if ci == 3:
                    color = ACTION_COLORS.get(val, "#cdd6f4")
                    item.setForeground(__import__('PySide6.QtGui', fromlist=['QColor']).QColor(color))
                self.table.setItem(r, ci, item)

        self.table.setSortingEnabled(True)

    def _clear_logs(self):
        if QMessageBox.question(self, "Onay", "Tüm loglar silinecek. Emin misiniz?", QMessageBox.Yes|QMessageBox.No) == QMessageBox.Yes:
            self.db.execute_query("DELETE FROM logs")
            self.load_logs()

    def closeEvent(self, event):
        if hasattr(self, "_worker_thread") and self._worker_thread.isRunning():
            self._worker_thread.quit()
            self._worker_thread.wait()
        super().closeEvent(event)
