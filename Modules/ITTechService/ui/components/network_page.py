from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
                                QLabel, QTableWidget, QTableWidgetItem, QHeaderView, 
                                QComboBox, QProgressBar, QCheckBox, QFrame, QLineEdit)
from PySide6.QtGui import QFont, QColor, QIcon, QPixmap
from PySide6.QtCore import Qt, QThread, Signal
from pathlib import Path
from modules.network import NetworkModule

from .ui_utils import IPTableWidgetItem

class ScanThread(QThread):


    progress = Signal(int, dict)
    finished_scan = Signal(list)
    
    def __init__(self, module, ip, netmask):
        super().__init__()
        self.module = module
        self.ip = ip
        self.netmask = netmask
        
    def run(self):
        results = self.module.scan_subnet(self.ip, self.netmask, lambda p, r: self.progress.emit(p, r))
        self.finished_scan.emit(results)

class NetworkPage(QWidget):
    jump_to_remote = Signal(str) # MainWindow'a geçiş yapmak için IP gönderir

    def __init__(self, remote_server=None):
        super().__init__()
        self.module = NetworkModule()
        self.remote_server = remote_server
        self.interfaces = []
        self.all_scan_results = [] # Tüm tarama verisini tutar
        self.setup_ui()
        self.load_interfaces()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)

        lbl_title = QLabel("📡  Gelişmiş Ağ Tarayıcı")
        lbl_title.setFont(QFont("Segoe UI", 20, QFont.Bold))
        lbl_title.setObjectName("PageTitle")
        layout.addWidget(lbl_title)


        # Kontrol Paneli
        ctrl_frame = QFrame()
        ctrl_frame.setObjectName("ControlFrame")
        ctrl_layout = QVBoxLayout(ctrl_frame)
        ctrl_layout.setContentsMargins(15, 15, 15, 15)

        form_layout = QHBoxLayout()
        self.combo_iface = QComboBox()
        self.combo_iface.setMinimumWidth(300)
        
        self.btn_scan = QPushButton("Tüm Alt Ağı Tara")
        self.btn_scan.setCursor(Qt.PointingHandCursor)
        self.btn_scan.setStyleSheet("""
            QPushButton { background-color: #f38ba8; color: #11111b; padding: 10px 20px; font-weight: bold; border-radius: 6px; }
            QPushButton:hover { background-color: #f7a8b8; }
            QPushButton:disabled { background-color: #585b70; color: #a6adc8; }
        """)
        self.btn_scan.clicked.connect(self.start_scan)

        lbl_iface = QLabel("Ağ Kartı:")
        lbl_iface.setObjectName("SecondaryLabel")

        form_layout.addWidget(lbl_iface)
        form_layout.addWidget(self.combo_iface, stretch=1)
        form_layout.addWidget(self.btn_scan)
        ctrl_layout.addLayout(form_layout)

        # Filtreleme Seçenekleri
        filter_layout = QHBoxLayout()
        filter_layout.setSpacing(15)
        
        filter_layout.addWidget(QLabel("Görünüm:"))
        self.chk_open = QCheckBox("🟢 Açık")
        self.chk_closed = QCheckBox("⚪ Kapalı")
        self.chk_open.setChecked(True)
        self.chk_closed.setChecked(False)
        
        filter_layout.addWidget(self.chk_open)
        filter_layout.addWidget(self.chk_closed)
        
        filter_layout.addWidget(QLabel(" |  🔍 Ara:"))
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText("IP, Host, OS veya Profil ara...")
        self.inp_search.setMinimumWidth(200)
        filter_layout.addWidget(self.inp_search)

        for chk in [self.chk_open, self.chk_closed]:
            chk.stateChanged.connect(self.refresh_table)
        self.inp_search.textChanged.connect(self.refresh_table)

        
        filter_layout.addStretch()
        ctrl_layout.addLayout(filter_layout)
        layout.addWidget(ctrl_frame)
        
        self.progress_bar = QProgressBar()
        self.progress_bar.setStyleSheet("""
            QProgressBar { border: 1px solid #313244; border-radius: 5px; text-align: center; height: 18px; }
            QProgressBar::chunk { background-color: #89b4fa; border-radius: 4px; }
        """)
        self.progress_bar.setValue(0)
        self.progress_bar.setVisible(False)
        layout.addWidget(self.progress_bar)

        self.table = QTableWidget(0, 8)
        self.table.setSortingEnabled(True) # Sıralamayı aktif et
        self.table.setHorizontalHeaderLabels(["Tip", "IP Adresi", "Durum", "Ping", "Host Adı", "OS / Sınıf", "Profil", "İşlem"])

        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Interactive)
        self.table.horizontalHeader().setStretchLastSection(True)
        self.table.verticalHeader().setVisible(False)
        self.table.setStyleSheet("""
            QTableWidget { font-size: 13px; border: 1px solid #313244; border-radius: 8px; }
            QTableWidget::item { padding: 8px; border-bottom: 1px solid #313244; }
        """)
        # Sütun genişliklerini ayarla
        self.table.setColumnWidth(0, 45)  # İkon
        self.table.setColumnWidth(1, 120) # IP
        self.table.setColumnWidth(2, 80)  # Durum
        self.table.setColumnWidth(3, 60)  # Ping
        self.table.setColumnWidth(4, 140) # Host
        self.table.setColumnWidth(5, 110) # OS
        self.table.setColumnWidth(6, 100) # Profil
        self.table.setColumnWidth(7, 90)  # İşlem
        
        layout.addWidget(self.table)

    def load_interfaces(self):
        self.combo_iface.clear()
        self.interfaces = self.module.get_interfaces()
        for idx, iface in enumerate(self.interfaces):
            self.combo_iface.addItem(f"{iface['name']} ({iface['ip']})", userData=idx)
            
        if not self.interfaces:
            self.combo_iface.addItem("Ağ kartı bulunamadı.")

    def start_scan(self):
        idx = self.combo_iface.currentData()
        if idx is None or idx >= len(self.interfaces): return
        
        iface = self.interfaces[idx]
        self.all_scan_results = [] # Eski sonuçları temizle
        self.table.setRowCount(0)
        self.btn_scan.setEnabled(False)
        self.btn_scan.setText("🛠️ Taranıyor...")
        self.progress_bar.setVisible(True)
        self.progress_bar.setValue(0)
        
        self.thread = ScanThread(self.module, iface['ip'], iface['netmask'])
        self.thread.progress.connect(self.on_progress)
        self.thread.finished_scan.connect(self.on_scan_finished)
        self.thread.start()

    def on_progress(self, p, r):
        self.progress_bar.setValue(p)
        self.all_scan_results.append(r)
        self.add_single_row(r) # Sadece yeni gelen satırı ekle (Performans fix)

    def add_single_row(self, r):
        """Yeni gelen bir cihazı filtreye uygunsa tabloya ekler (Performans odaklı)."""
        if not self._check_filters(r):
            return

        icon_base = Path(__file__).resolve().parent.parent.parent / "static" / "icons"
        
        # Tarama sırasında sıralamayı ASLA açma (Donma sebebi)
        self.table.setSortingEnabled(False)
        row = self.table.rowCount()
        self.table.insertRow(row)
        self._fill_row_data(row, r, icon_base)


    def _fill_row_data(self, row, r, icon_base):
        status = r.get('status', '')
        is_open = (status == 'Açık')
        
        # İkon Yükleme
        icon_key = r.get('icon', 'unknown')
        icon_path = icon_base / f"{icon_key}.png"
        item_icon = IPTableWidgetItem(icon_key) # Sıralama için text veriyoruz
        if icon_path.exists():
            px = QPixmap(str(icon_path)).scaled(24, 24, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            item_icon.setIcon(QIcon(px))
        else:
            fallback = {"mac":"🍎", "win11":"💻", "win10":"💻", "router":"🌐", "printer":"🖨️", "nas":"📦", "linux":"🐧", "mobile":"📱"}
            item_icon.setText(fallback.get(icon_key, "⚪"))
            item_icon.setTextAlignment(Qt.AlignCenter)
        self.table.setItem(row, 0, item_icon)

        
        self.table.setItem(row, 1, IPTableWidgetItem(r['ip']))
        i_status = IPTableWidgetItem(status)
        if is_open: i_status.setForeground(QColor("#a6e3a1"))
        else: i_status.setForeground(QColor("#6c7086"))
        self.table.setItem(row, 2, i_status)
        
        self.table.setItem(row, 3, IPTableWidgetItem(r.get('ping', '-')))
        self.table.setItem(row, 4, IPTableWidgetItem(r.get('hostname', '-')))
        self.table.setItem(row, 5, IPTableWidgetItem(r.get('os', '-')))
        
        item_prof = IPTableWidgetItem(r.get('profile', '-'))
        item_prof.setFont(QFont("Segoe UI", 9, QFont.Bold))
        self.table.setItem(row, 6, item_prof)

        # ── AGENT TESPİTİ VE HIZLI KONTROL ──
        if self.remote_server:
            try:
                # Aktif istemcilerin IP'lerini anahtar (key) üzerinden al (Key formatı: "IP:PORT")
                active_ips = [addr.split(":")[0] for addr in self.remote_server.clients.keys()]
                if r['ip'] in active_ips:
                    # İkonu güncelle (Agent olduğunu belirt)
                    if isinstance(self.table.item(row, 0), IPTableWidgetItem):
                        item_icon = self.table.item(row, 0)
                        item_icon.setBackground(QColor("rgba(59, 130, 246, 0.1)"))
                    
                    # "Kontrol Et" Butonunu 8. sütuna (Eylem) ekle
                    btn_control = QPushButton("⚡ Kontrol")
                    btn_control.setToolTip("Bu cihazda ajan yüklü, uzaktan kontrole geç.")
                    btn_control.setFixedSize(80, 24)
                    btn_control.setCursor(Qt.PointingHandCursor)
                    btn_control.setStyleSheet("""
                        QPushButton { 
                            background-color: #3b82f6; color: white; border-radius: 4px; 
                            font-weight: bold; font-size: 10px;
                        }
                        QPushButton:hover { background-color: #2563eb; }
                    """)
                    btn_control.clicked.connect(lambda chk=False, ip=r['ip']: self.jump_to_remote.emit(ip))
                    
                    self.table.setCellWidget(row, 7, btn_control)
            except Exception as e:
                # Bir cihazdaki hata tüm taramayı bozmasın
                import logging
                logging.error(f"NetworkPage ajan eslestirme hatasi ({r.get('ip')}): {e}")

    def _check_filters(self, r):
        """Bir cihazın mevcut filtrelere (Açık/Kapalı ve Arama) uyup uymadığını kontrol eder."""
        status = r.get('status', '')
        is_open = (status == 'Açık')
        
        if is_open and not self.chk_open.isChecked(): return False
        if not is_open and not self.chk_closed.isChecked(): return False
        
        search_text = self.inp_search.text().lower().strip()
        if search_text:
            searchable = f"{r['ip']} {r.get('hostname','')} {r.get('os','')} {r.get('profile','')}".lower()
            if search_text not in searchable:
                return False
        return True

    def refresh_table(self):
        """Tüm sonuçları yeniden filtreleyip tabloyu doldurur."""
        self.table.setSortingEnabled(False)
        self.table.setRowCount(0)
        
        icon_base = Path(__file__).resolve().parent.parent.parent / "static" / "icons"

        for r in self.all_scan_results:
            if not self._check_filters(r):
                continue
            row = self.table.rowCount()
            self.table.insertRow(row)
            self._fill_row_data(row, r, icon_base)
        
        self.table.setSortingEnabled(True)





    def on_scan_finished(self, results):
        self.btn_scan.setEnabled(True)
        self.btn_scan.setText("Tüm Alt Ağı Tara")
        self.progress_bar.setVisible(False)
        self.progress_bar.setValue(100)
        self.refresh_table() # Final sıralama ve filtreleme
