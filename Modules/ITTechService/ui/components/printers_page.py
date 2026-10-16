from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
                                QTableWidget, QTableWidgetItem, QHeaderView, QLabel, QGroupBox, QGridLayout, QFrame, QTextEdit)
from PySide6.QtGui import QFont
from PySide6.QtCore import Qt
from modules.printers import PrintersModule

from ui.premium_styles import PremiumStyles

class PrintersPage(QWidget):
    def __init__(self):
        super().__init__()
        self.module = PrintersModule()
        self.setup_ui()

    def setup_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(30, 30, 30, 30)
        main_layout.setSpacing(25)

        # ── Üst Başlık ──────────────────────────────────────────────────
        header_lay = QVBoxLayout()
        lbl_title = QLabel("🖨️ Yazıcı Merkezi")
        lbl_title.setStyleSheet(PremiumStyles.title_style())
        header_lay.addWidget(lbl_title)
        
        lbl_sub = QLabel("Sistemdeki yazıcıları yönetin, ağ ve bağlantı hatalarını saniyeler içinde onarın.")
        lbl_sub.setStyleSheet(PremiumStyles.subtitle_style())
        header_lay.addWidget(lbl_sub)
        main_layout.addLayout(header_lay)

        # ── İşlem Kartları ──────────────────────────────────────────────
        top_panels = QHBoxLayout()
        top_panels.setSpacing(20)

        # 🛒 HIZLI İŞLEMLER KARTI
        self.card_quick = QFrame()
        self.card_quick.setObjectName("DashRecentFrame") # Dinamik tema devredilir
        lay_quick = QVBoxLayout(self.card_quick)
        lay_quick.setContentsMargins(20, 20, 20, 20)
        
        lbl_q_title = QLabel("Hızlı İşlemler")
        lbl_q_title.setStyleSheet("color: #1e66f5; font-weight: bold; font-size: 15px; margin-bottom: 5px;")
        lay_quick.addWidget(lbl_q_title)

        btn_scan = QPushButton("🔍 Yazıcıları Tara")
        btn_scan.setCursor(Qt.PointingHandCursor)
        btn_scan.clicked.connect(self.load_data)
        
        btn_spooler = QPushButton("🧹 Kuyruğu Temizle")
        btn_spooler.setCursor(Qt.PointingHandCursor)
        btn_spooler.clicked.connect(self.fix_spooler)
        
        btn_autofix = QPushButton("⚡ Tam Onarım Yap")
        btn_autofix.setCursor(Qt.PointingHandCursor)
        btn_autofix.clicked.connect(self.run_auto_fix)
        
        lay_quick.addWidget(btn_scan)
        lay_quick.addWidget(btn_spooler)
        lay_quick.addWidget(btn_autofix)
        top_panels.addWidget(self.card_quick)

        # 🛠️ ÇÖZÜM ODASI KARTI
        self.card_tool = QFrame()
        self.card_tool.setObjectName("DashRecentFrame") # Dinamik tema devredilir
        lay_tool_grid = QGridLayout(self.card_tool)
        lay_tool_grid.setContentsMargins(20, 20, 20, 20)
        
        lbl_t_title = QLabel("Gelişmiş Onarım Araçları")
        lbl_t_title.setStyleSheet("color: #1e66f5; font-weight: bold; font-size: 15px; margin-bottom: 5px;")
        lay_tool_grid.addWidget(lbl_t_title, 0, 0, 1, 2)

        def create_tool_btn(text, callback):
            b = QPushButton(text)
            b.setCursor(Qt.PointingHandCursor)
            b.clicked.connect(callback)
            return b

        lay_tool_grid.addWidget(create_tool_btn("🔹 RPC / 11b Onarımı", self.do_fix_rpc), 1, 0)
        lay_tool_grid.addWidget(create_tool_btn("🔹 0x709 Ağ Hatası", self.do_fix_709), 1, 1)
        lay_tool_grid.addWidget(create_tool_btn("🔹 Servisleri Tetikle", self.do_fix_services), 2, 0)
        lay_tool_grid.addWidget(create_tool_btn("🔹 Ağ İzinlerini Ver", self.do_fix_network), 2, 1)
        lay_tool_grid.addWidget(create_tool_btn("🔹 Point & Print Fix", self.do_fix_pnp), 3, 0, 1, 2)

        top_panels.addWidget(self.card_tool)
        main_layout.addLayout(top_panels)

        # ── Tablo ──────────────────────────────────────────────────────
        self.table = QTableWidget(0, 4)
        self.table.setHorizontalHeaderLabels(["Yazıcı Adı", "Port", "Sürücü", "Durum"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table.verticalHeader().hide()
        self.table.setStyleSheet("""
            QTableWidget { font-size: 13px; }
            QHeaderView::section { font-weight: bold; }
        """)
        main_layout.addWidget(self.table)
        
        # ── Log / Konsol Paneli ─────────────────────────────────────────
        lbl_log = QLabel("⚡ İşlem Konsolu")
        lbl_log.setStyleSheet("color: #94a3b8; font-weight: bold; font-size: 13px; margin-top: 5px;")
        main_layout.addWidget(lbl_log)

        self.log_area = QTextEdit()
        self.log_area.setReadOnly(True)
        # Global temayı alabilmesi için doğrudan stili kaldırıldı
        self.log_area.setFixedHeight(120)
        main_layout.addWidget(self.log_area)

    def log(self, text):
        from datetime import datetime
        ts = datetime.now().strftime("%H:%M:%S")
        self.log_area.append(f"<b>[{ts}]</b> {text}")
        # Scroll to bottom
        self.log_area.verticalScrollBar().setValue(self.log_area.verticalScrollBar().maximum())

    def load_data(self):
        self.table.setRowCount(0)
        self.log("Sistem yazıcıları taranıyor...")
        data = self.module.get_installed_printers()
        if isinstance(data, list) and data:
            for row, item in enumerate(data):
                if isinstance(item, dict):
                    self.table.insertRow(row)
                    self.table.setItem(row, 0, QTableWidgetItem(str(item.get("Name", ""))))
                    self.table.setItem(row, 1, QTableWidgetItem(str(item.get("PortName", ""))))
                    self.table.setItem(row, 2, QTableWidgetItem(str(item.get("DriverName", ""))))
                    status = item.get("PrinterStatus", 0)
                    status_text = "Aktif" if status == 0 else f"Kod: {status}"
                    self.table.setItem(row, 3, QTableWidgetItem(status_text))
            self.log(f"<span style='color: #10b981;'>✔ {len(data)} yazıcı bulundu.</span>")
        else:
            self.log("<span style='color: #ef4444;'>⚠ Yazıcı listesi alınamadı veya sistemde yazıcı kayıtlı değil.</span>")

    def fix_spooler(self):
        self.log("Spooler (Biriktirici) temizleniyor...")
        success, out, err = self.module.fix_spooler()
        if success:
            self.log("<span style='color: #10b981;'>✔ Spooler başarıyla yenilendi.</span>")
        else: self.log(f"<span style='color: #ef4444;'>❌ Hata: {err}</span>")

    def do_fix_rpc(self):
        self.log("RPC & 11b Kayıt Defteri düzenleniyor...")
        success, out, err = self.module.fix_rpc()
        self.log("<span style='color: #10b981;'>✔ Politika uygulandı!</span>" if success else f"❌ {err}")

    def do_fix_709(self):
        self.log("0x00000709 ağ hatası çözülüyor...")
        success, out, err = self.module.fix_709()
        self.log("<span style='color: #10b981;'>✔ Lsa ağ izinleri düzenlendi!</span>" if success else f"❌ {err}")

    def do_fix_services(self):
        self.log("Kritik servisler tetikleniyor...")
        success, out, err = self.module.fix_services()
        self.log("<span style='color: #10b981;'>✔ Tüm servisler ayağa kalktı!</span>" if success else f"❌ {err}")

    def do_fix_network(self):
        self.log("Güvenlik Duvarı'nda paylaşım izinleri açılıyor...")
        success, out, err = self.module.fix_network()
        self.log("<span style='color: #10b981;'>✔ Ağ paylaşım izinleri verildi!</span>" if success else f"❌ {err}")

    def do_fix_pnp(self):
        self.log("Point & Print politikası gevşetiliyor...")
        success, out, err = self.module.fix_point_and_print()
        self.log("<span style='color: #10b981;'>✔ Manuel yükleme kısıtlamaları kaldırıldı!</span>" if success else f"❌ {err}")

    def run_auto_fix(self):
        self.log("<b>⚡ TOPLU ONARIM BAŞLATILDI...</b>")
        results = self.module.run_auto_fix()
        for action, status in results:
            stat_msg = "<span style='color: #10b981;'>TAMAM</span>" if status else "<span style='color: #ef4444;'>HATA</span>"
            self.log(f"{action} => {stat_msg}")
        self.log("<b>🎉 Tüm işlemler tamamlandı.</b>")


    def load_data(self):
        self.table.setRowCount(0)
        self.log("Sistem yazıcıları taranıyor...")
        data = self.module.get_installed_printers()
        if isinstance(data, list):
            for row, item in enumerate(data):
                if isinstance(item, dict):
                    self.table.insertRow(row)
                    self.table.setItem(row, 0, QTableWidgetItem(str(item.get("Name", ""))))
                    self.table.setItem(row, 1, QTableWidgetItem(str(item.get("PortName", ""))))
                    self.table.setItem(row, 2, QTableWidgetItem(str(item.get("DriverName", ""))))
                    status = item.get("PrinterStatus", 0)
                    self.table.setItem(row, 3, QTableWidgetItem(f"Durum Kodu: {status}"))
            self.log(f"Toplam {len(data)} yazıcı bulundu.")
        else:
            self.log("Yazıcı listesi alınamadı.")

    def fix_spooler(self):
        self.log("Yazdırma Biriktiricisi (Spooler) durduruluyor, kuyruklar siliniyor...")
        success, out, err = self.module.fix_spooler()
        if success:
            self.log("Spooler başarıyla temizlendi ve yeniden başlatıldı!")
        else:
            self.log(f"Spooler Hatası: {err}")

    def do_fix_rpc(self):
        self.log("RPC Güvenlik protokolleri ve 11b hatası için Registry düzenleniyor...")
        success, out, err = self.module.fix_rpc()
        self.log("İşlem Başarılı! (RpcAuthnLevelPrivacyEnabled & RpcUseNamedPipeProtocol)" if success else f"Hata: {err}")

    def do_fix_709(self):
        self.log("0x00000709 ağ hatası onarımı için Lsa izinleri deneniyor...")
        success, out, err = self.module.fix_709()
        self.log("İşlem Başarılı! (restrictanonymous & LmCompatibility Level)" if success else f"Hata: {err}")

    def do_fix_services(self):
        self.log("Spooler, Lanman, RPC ve FDP servisleri otomatik ayarlara çekiliyor...")
        success, out, err = self.module.fix_services()
        self.log("Tüm Hayati Servisler Başlatıldı!" if success else f"Hata: {err}")

    def do_fix_network(self):
        self.log("Güvenlik Duvarı'nda 'Dosya ve Yazıcı Paylaşım' izinleri aktif ediliyor...")
        success, out, err = self.module.fix_network()
        self.log("İzinler Verildi!" if success else f"Hata: {err}")

    def do_fix_pnp(self):
        self.log("Spooler UpdatePrompt ve PointAndPrint kısıtlamaları kaldırılıyor...")
        success, out, err = self.module.fix_point_and_print()
        self.log("Kısıtlamalar Devre Dışı Bırakıldı!" if success else f"Hata: {err}")

    def run_auto_fix(self):
        self.log("Otomatik Onarım Başlatıldı. Yönetici (Admin) izni gerektirir...")
        results = self.module.run_auto_fix()
        for action, status in results:
            stat_msg = "BAŞARILI" if status else "BAŞARISIZ"
            self.log(f"{action} => {stat_msg}")
        self.log("Tek toplu onarım tamamlandı! Yazıcıyı tekrar sınayınız.")
