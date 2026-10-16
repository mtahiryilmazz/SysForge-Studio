import os
import subprocess
from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
                                QLabel, QTableWidget, QTableWidgetItem, QHeaderView, QFrame)
from PySide6.QtGui import QFont
from PySide6.QtCore import Qt

class ScreenshotsPage(QWidget):
    def __init__(self):
        super().__init__()
        self.setup_ui()
        self.refresh_list()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)

        header = QHBoxLayout()
        lbl_title = QLabel("📂 Ekran Kayıtları Arşivi")
        lbl_title.setFont(QFont("Segoe UI", 18, QFont.Bold))
        lbl_title.setStyleSheet("color: #89b4fa;")
        header.addWidget(lbl_title)

        self.btn_refresh = QPushButton("🔄 Listeyi Yenile")
        self.btn_refresh.setFixedWidth(150)
        self.btn_refresh.setCursor(Qt.PointingHandCursor)
        self.btn_refresh.clicked.connect(self.refresh_list)
        header.addWidget(self.btn_refresh)
        
        layout.addLayout(header)

        desc = QLabel("Cihazlara göre gruplandırılmış ekran görüntülerini buradan görebilirsiniz.")
        desc.setStyleSheet("color: #6c7086; margin-bottom: 10px;")
        layout.addWidget(desc)

        # Ana Tablo
        self.table = QTableWidget(0, 3)
        self.table.setHorizontalHeaderLabels(["Bilgisayar / IP Bilgisi", "Klasör Yolu", "İşlem"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeToContents)
        self.table.verticalHeader().hide()
        
        layout.addWidget(self.table)

    def showEvent(self, event):
        """Sayfa her gösterildiğinde listeyi yenile."""
        super().showEvent(event)
        self.refresh_list()

    def refresh_list(self):
        self.table.setRowCount(0)
        root_dir = "screenshots"
        
        if not os.path.exists(root_dir):
            os.makedirs(root_dir, exist_ok=True)
            return

        # Sadece klasörleri listele
        try:
            folders = [d for d in os.listdir(root_dir) if os.path.isdir(os.path.join(root_dir, d))]
            # Alfabetik sırala
            folders.sort()
        except Exception:
            folders = []
        
        for folder_name in folders:
            # Skip empty or hidden directories
            if folder_name.startswith('.'): continue
            
            row = self.table.rowCount()
            self.table.insertRow(row)
            
            # 1. Kolon: Bilgisayar / IP Bilgisi
            # Klasör adını daha okunaklı formatla (Hostname | IP)
            display_name = folder_name.replace("_", ".") # Geri çevir (Örn: DESKTOP-123_192.168.1.10)
            if "_" in folder_name:
                parts = folder_name.rsplit("_", 1)
                display_name = f"💻 {parts[0]} | 🌐 {parts[1].replace('_', '.')}"
            else:
                display_name = f"🖥️ {folder_name}"

            item_name = QTableWidgetItem(display_name)
            item_name.setFont(QFont("Segoe UI", 10, QFont.Bold))
            self.table.setItem(row, 0, item_name)
            
            # 2. Kolon: Path (Gizli veya Tooltip olarak kalsın, kullanıcıya temiz yol gösterelim)
            full_path = os.path.abspath(os.path.join(root_dir, folder_name))
            item_path = QTableWidgetItem(f"Archive: {folder_name}")
            item_path.setToolTip(full_path)
            item_path.setForeground(Qt.gray)
            self.table.setItem(row, 1, item_path)
            
            # 3. Kolon: Buton (Klasörü Aç)
            btn_open = QPushButton("📂 Klasörü Aç")
            btn_open.setCursor(Qt.PointingHandCursor)
            btn_open.setFixedWidth(140)
            btn_open.setStyleSheet("""
                QPushButton {
                    background-color: #3b82f6; 
                    color: white; 
                    font-weight: bold; 
                    border-radius: 4px; 
                    padding: 8px;
                }
                QPushButton:hover {
                    background-color: #2563eb;
                }
            """)
            btn_open.clicked.connect(lambda chk=False, p=full_path: os.startfile(p))
            
            self.table.setCellWidget(row, 2, btn_open)
            self.table.setRowHeight(row, 50)
