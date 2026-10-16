import json
import base64
import logging
import os
import datetime
import subprocess

from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
                                QListWidget, QLabel, QInputDialog, QDialog, QTableWidget,
                                QTableWidgetItem, QHeaderView, QTabWidget, QMessageBox,
                                QMainWindow, QScrollArea, QToolBar, QStatusBar, QFrame, QCheckBox)

from PySide6.QtGui import QFont, QPixmap, QImage, QAction, QKeyEvent, QMouseEvent
from PySide6.QtCore import Qt, QTimer, QSize
from core.remote_server import RemoteServer

class RemotePage(QWidget):
    def __init__(self, user_data=None, server=None):
        super().__init__()
        self.user_data = user_data or {}
        
        if server:
            self.server = server
        else:
            self.server = RemoteServer(host='0.0.0.0', port=7777)
            self.server.start()

        self.server.add_callback(self.on_server_event)
        self.live_windows = {} # addr -> RemoteControlWindow
        
        self.setup_ui()
        self.refresh_list()

    def setup_ui(self):
        layout = QVBoxLayout(self)

        lbl_title = QLabel("Uzak Masaüstü ve Cihaz Kontrolü")
        lbl_title.setFont(QFont("Segoe UI", 20, QFont.Bold))
        layout.addWidget(lbl_title)

        h_layout = QHBoxLayout()

        # Sol taraf
        v_left = QVBoxLayout()
        v_left.addWidget(QLabel("Aktif Cihazlar:"))
        
        self.client_list = QListWidget()
        v_left.addWidget(self.client_list)

        self.btn_live = QPushButton("🎮  CANLI DESTEK / UZAKTAN KONTROL")
        self.btn_live.clicked.connect(self.open_live_control)
        self.btn_live.setStyleSheet("background-color: #a6e3a1; color: #11111b; padding: 12px; font-weight: bold; border-radius: 6px;")
        v_left.addWidget(self.btn_live)

        top_hlay = QHBoxLayout()
        self.btn_refresh = QPushButton("🔄 Yenile")
        self.btn_refresh.setFixedWidth(100)
        self.btn_refresh.setCursor(Qt.PointingHandCursor)
        self.btn_refresh.clicked.connect(self.refresh_list)
        
        self.btn_search = QPushButton("🔍 Cihazları Ara")
        self.btn_search.setFixedWidth(140)
        self.btn_search.setCursor(Qt.PointingHandCursor)
        self.btn_search.setStyleSheet("QPushButton { background-color: #3b82f6; color: white; font-weight: bold; }")
        self.btn_search.clicked.connect(self.search_devices)
        
        # Sinyal durumu etiketi
        self.lbl_server_info = QLabel("Sistem Hazır")
        self.lbl_server_info.setStyleSheet("color: #6c7086; font-size: 11px;")
        
        top_hlay.addWidget(self.btn_refresh)
        top_hlay.addWidget(self.btn_search)
        top_hlay.addStretch()
        top_hlay.addWidget(self.lbl_server_info)
        layout.addLayout(top_hlay)

        v_left.addWidget(self.btn_screen)
        
        self.btn_diag = QPushButton("🔍  Sistem Tanılama")
        self.btn_diag.clicked.connect(self.request_diag)
        v_left.addWidget(self.btn_diag)
        
        self.btn_open_shots = QPushButton("📂  Ekran Görüntülerini Aç")
        self.btn_open_shots.clicked.connect(self.open_screenshots_folder)
        self.btn_open_shots.setStyleSheet("background-color: #313244; color: #cdd6f4;")
        v_left.addWidget(self.btn_open_shots)

        
        h_layout.addLayout(v_left, 1)

        # Sağ taraf (Preview)
        v_right = QVBoxLayout()
        self.screen_viewer = QLabel("Önizleme Alanı")
        self.screen_viewer.setAlignment(Qt.AlignCenter)
        self.screen_viewer.setStyleSheet("background-color: #1e1e2e; border: 2px solid #313244; color: #cdd6f4;")
        self.screen_viewer.setMinimumSize(400, 300)
        v_right.addWidget(self.screen_viewer)
        h_layout.addLayout(v_right, 2)

        layout.addLayout(h_layout)

    def on_server_event(self, event_type, data):
        if event_type == "client_connected":
             QTimer.singleShot(0, lambda: self._add_client(data))
        elif event_type == "client_disconnected":
             QTimer.singleShot(0, lambda: self._remove_client(data['addr']))
        elif event_type == "message_received":
             QTimer.singleShot(0, lambda: self._handle_client_msg(data))

    def _add_client(self, data):
        self.refresh_list()

    def _remove_client(self, addr):
        if addr in self.live_windows:
            self.live_windows[addr].close()
            del self.live_windows[addr]
        self.refresh_list()

    def search_devices(self):
        """Manuel keşif yayını tetikler ve listeyi yeniler."""
        self.btn_search.setEnabled(False)
        self.btn_search.setText("Aranıyor...")
        
        if hasattr(self.server, 'trigger_discovery'):
            self.server.trigger_discovery()
            
        self.refresh_list()
        
        # 2 saniye sonra butonu eski haline getir
        QTimer.singleShot(2000, lambda: self.btn_search.setEnabled(True))
        QTimer.singleShot(2000, lambda: self.btn_search.setText("🔍 Cihazları Ara"))

    def refresh_list(self):
        self.client_list.clear()
        # Sunucudaki gerçek bağlantıları kullan (Single Source of Truth)
        clients = list(self.server.clients.items())
        for addr, client_data in clients:
            info = client_data.get("info", {})
            hostname = info.get("hostname", "Bilinmeyen")
            os_info = info.get("os", "N/A")
            item_text = f"{hostname} ({addr}) - {os_info}"
            self.client_list.addItem(item_text)
        
        self.lbl_server_info.setText(f"Aktif Cihaz: {len(clients)}")

    def _get_addr_from_text(self, text):
        # Format: "Hostname (IP:PORT) - OS" veya eski "Hostname | IP:PORT"
        if "(" in text and ")" in text:
            # "Hostname (192.168.1.5:7777) - Windows" -> "192.168.1.5:7777"
            return text.split("(")[1].split(")")[0]
        elif " | " in text:
            return text.split(" | ")[1]
        return None


    def send_message(self):
        sel = self.client_list.currentItem()
        if not sel: return
        addr = self._get_addr_from_text(sel.text())
        text, ok = QInputDialog.getText(self, "Mesaj", "İleti:")
        if ok and text:
            self.server.send_command(addr, {"action": "msg", "text": text})

    def request_screen(self):
        sel = self.client_list.currentItem()
        if not sel: return
        addr = self._get_addr_from_text(sel.text())
        self.server.send_command(addr, {"action": "screen"})

    def open_live_control(self):
        sel = self.client_list.currentItem()
        if not sel: return
        addr = self._get_addr_from_text(sel.text())
        if addr not in self.live_windows:
            win = RemoteControlWindow(self.server, addr, sel.text())
            self.live_windows[addr] = win
        self.live_windows[addr].show()
        self.live_windows[addr].start_stream()

    def open_screenshots_folder(self):
        folder = os.path.join(os.getcwd(), "screenshots")
        if not os.path.exists(folder): os.makedirs(folder)
        os.startfile(folder)

    def request_diag(self):
        sel = self.client_list.currentItem()
        if not sel: return
        addr = self._get_addr_from_text(sel.text())
        self.server.send_command(addr, {"action": "get_diag"})
        self.server.send_command(addr, {"action": "get_log"})

    def open_toolbox(self):
        """BT Araç Kutusu penceresini açar."""
        sel = self.client_list.currentItem()
        if not sel:
            QMessageBox.warning(self, "Uyarı", "Lütfen önce bir cihaz seçin.")
            return
            
        addr = self._get_addr_from_text(sel.text())
        if not addr: return
        
        # Eğer zaten açıksa öne getir
        if hasattr(self, 'current_toolbox') and self.current_toolbox.isVisible():
            self.current_toolbox.raise_()
            self.current_toolbox.activateWindow()
        else:
            self.current_toolbox = RemoteToolbox(self.server, addr, sel.text())
            self.current_toolbox.show()

    def _handle_client_msg(self, data):
        addr = data['addr']
        try:
            msg_obj = json.loads(data['msg'])
            m_type = msg_obj.get("type")
            if m_type != "screen_data":
                logging.info(f"🔎 [DEBUG] Mesaj Alındı: Tip={m_type}, Kaynak={addr}, Boyut={len(data['msg'])}")

            if msg_obj.get("type") == "error":

                logging.error(f"Ajan Hatası ({addr}): {msg_obj.get('message')}")
                QMessageBox.critical(self, "Ajan Hatası", f"İşlem sırasında hata oluştu:\n{msg_obj.get('message')}")
                return

            elif msg_obj.get("type") == "diag":
                diag_data = msg_obj.get("data", {})
                status = "\n".join([f"{k}: {v}" for k,v in diag_data.items()])
                QMessageBox.information(self, "Sistem Tanılama", f"Ajan Durumu:\n\n{status}")
                return
            
            elif msg_obj.get("type") == "log_data":
                log = msg_obj.get("log", "Boş")
                from PySide6.QtWidgets import QTextEdit
                diag = QDialog(self)
                diag.setWindowTitle("Ajan Log Kayıtları")
                diag.resize(600, 400)
                l = QVBoxLayout(diag)
                te = QTextEdit()
                te.setReadOnly(True)
                te.setPlainText(log)
                l.addWidget(te)
                diag.show()
                return

            elif msg_obj.get("type") == "screen_data":
                try:
                    img_data = base64.b64decode(msg_obj["image"])
                    image = QImage.fromData(img_data)
                    
                    if image.isNull():
                        logging.error(f"Gelen görüntü verisi çözülemedi (Null Image) - {addr}")
                        return

                    # Arşivle (Hiyerarşik Klasöre Kaydet)
                    root_folder = "screenshots"
                    hostname = self.server.clients.get(addr, {}).get("info", {}).get("hostname", "Cihaz")
                    clean_ip = addr.split(":")[0].replace(".", "_")
                    pc_folder = f"{hostname}_{clean_ip}"
                    date_folder = datetime.datetime.now().strftime("%Y-%m-%d")
                    
                    full_dir = os.path.join(root_folder, pc_folder, date_folder)
                    if not os.path.exists(full_dir): 
                        os.makedirs(full_dir, exist_ok=True)
                    
                    ts = datetime.datetime.now().strftime("%H%M%S")
                    filename = f"capture_{ts}.jpg"
                    filepath = os.path.join(full_dir, filename)
                    
                    image.save(filepath, "JPG", 90)
                    
                    # Eğer canlı pencere açıksa oraya gönder
                    if addr in self.live_windows:
                        self.live_windows[addr].update_image(image, msg_obj.get("resolution"))
                    
                    # Önizlemeyi güncelle
                    pix = QPixmap.fromImage(image)
                    self.screen_viewer.setPixmap(pix.scaled(self.screen_viewer.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation))
                except Exception as img_err:
                    logging.error(f"Ekran verisi işleme hatası: {img_err}")
                
            elif msg_obj.get("type") == "ps_list":
                ps_data = msg_obj.get("data", [])
                logging.info(f"Yenilenen görev listesi alındı: {len(ps_data)} adet - {addr}")
                # Ayrı toolbox penceresi açıksa oraya gönder
                if hasattr(self, 'current_toolbox') and self.current_toolbox.isVisible():
                    self.current_toolbox.update_ps_list(ps_data)
                # Canlı bağlantı penceresi açıksa ve sidebar aktifse oraya da gönder
                if addr in self.live_windows:
                    self.live_windows[addr].update_ps_list(ps_data)

        except json.JSONDecodeError:
            logging.error(f"Gelen mesaj JSON formatında değil: {data['msg'][:100]}...")
        except Exception as e:
            logging.error(f"Client Mesaj İşleme Hatası: {e}")
            import traceback
            logging.error(traceback.format_exc())


from PySide6.QtWidgets import QComboBox, QToolButton, QMenu

class RemoteControlWindow(QMainWindow):
    def __init__(self, server, addr, name):
        super().__init__()
        self.server = server
        self.addr = addr
        self.setWindowTitle(f"VANGUARD REMOTE: {name}")
        self.resize(1250, 850)
        
        self.remote_res = {"w": 1920, "h": 1080}
        self.quality = 60
        self.scale = 1.5
        self.is_control_enabled = True
        
        self.setup_ui()
        # İlk açılışta hemen stream başlat ve görev listesini iste
        QTimer.singleShot(500, self.start_stream)
        QTimer.singleShot(1000, self.refresh_ps)

    def setup_ui(self):
        self.central = QWidget()
        self.setCentralWidget(self.central)
        self.main_layout = QHBoxLayout(self.central)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        self.main_layout.setSpacing(0)

        # === SOL TARAF: ANA KONTROL ALANI ===
        self.left_container = QWidget()
        self.left_vlay = QVBoxLayout(self.left_container)
        self.left_vlay.setContentsMargins(0,0,0,0)
        self.left_vlay.setSpacing(0)
        
        # --- Modern Üst Bar ---
        self.top_bar = QFrame()
        self.top_bar.setFixedHeight(50)
        self.top_bar.setStyleSheet("""
            QFrame { background-color: #181825; border-bottom: 2px solid #89b4fa; }
            QPushButton { background-color: #313244; color: #cdd6f4; border: 1px solid #45475a; 
                         border-radius: 4px; padding: 5px 10px; font-weight: bold; }
            QPushButton:hover { background-color: #45475a; }
            QLabel { color: #89b4fa; font-weight: bold; }
        """)
        top_layout = QHBoxLayout(self.top_bar)
        top_layout.setContentsMargins(15, 0, 15, 0)
        
        self.lbl_status = QLabel("● CANLI BAĞLANTI")
        top_layout.addWidget(self.lbl_status)
        top_layout.addSpacing(10)

        top_layout.addWidget(QLabel("Kalite:"))
        self.combo_quality = QComboBox()
        self.combo_quality.addItems(["🚀 Hızlı", "⚖️ Dengeli", "💎 Net", "🌟 Ultra"])
        self.combo_quality.setCurrentIndex(1)
        self.combo_quality.setFixedWidth(100)
        self.combo_quality.currentIndexChanged.connect(self.on_quality_changed)
        top_layout.addWidget(self.combo_quality)

        self.btn_force_refresh = QPushButton("🔄 Akışı Yenile")
        self.btn_force_refresh.setToolTip("Ekran siyah kalırsa bağlantıyı zorla yeniler.")
        self.btn_force_refresh.clicked.connect(self.force_reset_stream)
        top_layout.addWidget(self.btn_force_refresh)
        
        top_layout.addSpacing(10)

        
        btn_cad = QPushButton("Ctrl+Alt+Del")
        btn_cad.setStyleSheet("background-color: #f38ba8; color: #11111b;")
        btn_cad.clicked.connect(lambda: self.server.send_command(self.addr, {"action": "keyboard", "key": "cad"}))
        top_layout.addWidget(btn_cad)
        
        btn_winr = QPushButton("Win + R")
        btn_winr.clicked.connect(lambda: self.server.send_command(self.addr, {"action": "keyboard", "key": "winr"}))
        top_layout.addWidget(btn_winr)

        top_layout.addStretch()
        
        self.ch_mouse = QCheckBox("Fare")
        self.ch_mouse.setChecked(True)
        top_layout.addWidget(self.ch_mouse)
        
        self.ch_kbd = QCheckBox("Klavye")
        self.ch_kbd.setChecked(True)
        top_layout.addWidget(self.ch_kbd)
        
        self.btn_toggle_sidebar = QPushButton("⚙️ Araçlar")
        self.btn_toggle_sidebar.setCheckable(True)
        self.btn_toggle_sidebar.setChecked(True)
        self.btn_toggle_sidebar.clicked.connect(self.toggle_sidebar)
        top_layout.addWidget(self.btn_toggle_sidebar)
        
        self.left_vlay.addWidget(self.top_bar)
        
        # --- Ekran Alanı ---
        self.screen_label = QLabel("🔗 Bağlantı kuruluyor...")
        self.screen_label.setAlignment(Qt.AlignCenter)
        self.screen_label.setMouseTracking(True)
        self.screen_label.setStyleSheet("background-color: #000000;")
        
        self.scroll = QScrollArea()
        self.scroll.setWidget(self.screen_label)
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QFrame.NoFrame)
        self.left_vlay.addWidget(self.scroll)
        
        self.main_layout.addWidget(self.left_container, 7) # Sol taraf 7 oranında

        # === SAĞ TARAF: ENTEGRE ARAÇ KUTUSU (SIDEBAR) ===
        self.sidebar = QFrame()
        self.sidebar.setObjectName("RemoteSidebar")
        self.sidebar.setFixedWidth(320)
        self.sidebar.setStyleSheet("""
            QFrame#RemoteSidebar { background-color: #1e1e2e; border-left: 1px solid #313244; }
            QTableWidget { background-color: #181825; border: none; color: #cdd6f4; font-size: 11px; }
            QHeaderView::section { background-color: #313244; color: #89b4fa; padding: 4px; border: none; }
            QTabWidget::pane { border: none; }
            QTabBar::tab { background: #1e1e2e; color: #cdd6f4; padding: 8px; }
            QTabBar::tab:selected { background: #313244; color: #89b4fa; }
        """)
        
        side_layout = QVBoxLayout(self.sidebar)
        side_layout.setContentsMargins(5, 5, 5, 5)
        
        self.side_tabs = QTabWidget()
        
        # 1. Görev Yöneticisi Tab'ı
        self.tab_ps = QWidget()
        ps_lay = QVBoxLayout(self.tab_ps)
        ps_lay.setContentsMargins(0, 5, 0, 0)
        
        self.ps_table = QTableWidget(0, 2)
        self.ps_table.setHorizontalHeaderLabels(["Program", "Bellek"])
        self.ps_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.Stretch)
        self.ps_table.setSelectionBehavior(QTableWidget.SelectRows)
        ps_lay.addWidget(self.ps_table)
        
        ps_btns = QHBoxLayout()
        self.btn_ps_refresh = QPushButton("🔄")
        self.btn_ps_refresh.setToolTip("Listeyi Yenile")
        self.btn_ps_refresh.clicked.connect(self.refresh_ps)
        
        self.btn_ps_kill = QPushButton("🛑 Görevi Sonlandır")
        self.btn_ps_kill.setStyleSheet("background-color: #f38ba8; color: #11111b; font-size: 11px;")
        self.btn_ps_kill.clicked.connect(self.kill_ps)
        
        ps_btns.addWidget(self.btn_ps_refresh)
        ps_btns.addWidget(self.btn_ps_kill)
        ps_lay.addLayout(ps_btns)
        
        self.side_tabs.addTab(self.tab_ps, "📋 Görevler")
        
        # 2. İşlemler Tab'ı
        self.tab_actions = QWidget()
        act_lay = QVBoxLayout(self.tab_actions)
        
        cmds = [
            ("🌐 DNS Temizle", "flush_dns", "#89b4fa"),
            ("🧹 Çöpü Boşalt", "empty_trash", "#a6e3a1"),
            ("🔄 Sistemi Yeniden Başlat", "restart", "#f9e2af"),
            ("🛑 Sistemi Kapat", "shutdown", "#f38ba8")
        ]
        for title, mode, color in cmds:
            btn = QPushButton(title)
            btn.setStyleSheet(f"background-color: {color}; color: #11111b; text-align: left; padding: 12px;")
            btn.clicked.connect(lambda _, m=mode, t=title: self.run_quick_action(m, t))
            act_lay.addWidget(btn)
        act_lay.addStretch()
        
        self.side_tabs.addTab(self.tab_actions, "⚡ İşlemler")
        
        # 3. Mesaj Gönderme Tab'ı
        self.tab_msg = QWidget()
        msg_lay = QVBoxLayout(self.tab_msg)
        self.msg_input = QTableWidget(1, 1) # Basit bir text alanı için
        # Gerçekten basit olsun diye QInputDialog gibi bir şey yerine TextEdit koyalım
        from PySide6.QtWidgets import QTextEdit
        self.te_msg = QTextEdit()
        self.te_msg.setPlaceholderText("Uzak kullanıcıya iletilecek mesajı yazın...")
        self.te_msg.setStyleSheet("background-color: #181825; color: #cdd6f4; border: 1px solid #45475a;")
        msg_lay.addWidget(self.te_msg)
        
        self.btn_send_sidebar = QPushButton("📧 Mesajı Gönder")
        self.btn_send_sidebar.setStyleSheet("background-color: #89b4fa; color: #11111b; font-weight: bold;")
        self.btn_send_sidebar.clicked.connect(self.send_sidebar_msg)
        msg_lay.addWidget(self.btn_send_sidebar)
        msg_lay.addStretch()
        
        self.side_tabs.addTab(self.tab_msg, "💬 Mesaj")
        
        side_layout.addWidget(self.side_tabs)

        self.main_layout.addWidget(self.sidebar)

        self.status = QStatusBar()
        self.setStatusBar(self.status)
        self.status.showMessage("Bağlı: " + str(self.addr))

    def toggle_sidebar(self):
        self.sidebar.setVisible(self.btn_toggle_sidebar.isChecked())

    def update_ps_list(self, data):
        logging.info(f"Tabloya {len(data)} süreç verisi yazılıyor... (Örn: {data[0]['name'] if data else 'N/A'})")
        self.ps_table.setRowCount(0)
        for p in data:

            row = self.ps_table.rowCount()
            self.ps_table.insertRow(row)
            self.ps_table.setItem(row, 0, QTableWidgetItem(str(p.get("name", ""))))
            self.ps_table.setItem(row, 1, QTableWidgetItem(str(p.get("mem", ""))))
            # Tooltip'e PID ekle
            self.ps_table.item(row, 0).setToolTip(f"PID: {p.get('pid')}")
            # Gizli kolon: PID saklamak için (hücre verisi olarak değil de item datası olarak)
            self.ps_table.item(row, 0).setData(Qt.UserRole, p.get("pid"))

    def refresh_ps(self):
        self.server.send_command(self.addr, {"action": "get_ps"})

    def kill_ps(self):
        sel = self.ps_table.currentRow()
        if sel < 0: return
        pid = self.ps_table.item(sel, 0).data(Qt.UserRole)
        if pid:
            self.server.send_command(self.addr, {"action": "kill_ps", "pid": pid})
            QTimer.singleShot(1500, self.refresh_ps)

    def run_quick_action(self, mode, title):
        if QMessageBox.question(self, "Onay", f"'{title}' işlemini yapmak istiyor musunuz?", QMessageBox.Yes|QMessageBox.No) == QMessageBox.Yes:
            self.server.send_command(self.addr, {"action": "quick_action", "mode": mode})
            self.status.showMessage(f"Komut gönderildi: {title}", 3000)

    def on_quality_changed(self, index):
        presets = [(30, 2.0), (60, 1.5), (85, 1.0), (100, 1.0)]
        self.quality, self.scale = presets[index]
        self.status.showMessage(f"Kalite güncellendi: {self.combo_quality.currentText()}")
        self.start_stream()

    def send_sidebar_msg(self):
        text = self.te_msg.toPlainText().strip()
        if text:
            self.server.send_command(self.addr, {"action": "msg", "text": text})
            self.te_msg.clear()
            self.status.showMessage("Mesaj başarıyla gönderildi.", 3000)

    def force_reset_stream(self):
        self.status.showMessage("Bağlantı akışı zorla sıfırlanıyor...", 3000)
        self.server.send_command(self.addr, {"action": "stop_stream"})
        QTimer.singleShot(1000, self.start_stream)



    def start_stream(self):
        self.server.send_command(self.addr, {
            "action": "start_stream", 
            "quality": self.quality, 
            "scale": self.scale
        })

    def closeEvent(self, event):
        self.server.send_command(self.addr, {"action": "stop_stream"})
        event.accept()

    def update_image(self, qimage, res):
        if res: self.remote_res = res
        pix = QPixmap.fromImage(qimage)
        # Pencereye sığdır ama aspect ratio koru
        scaled_pix = pix.scaled(self.screen_label.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation)
        self.screen_label.setPixmap(scaled_pix)
        
    # --- FARE VE KLAVYE OLAYLARI ---
    def mousePressEvent(self, event: QMouseEvent):
        self._send_mouse(event, "click")

    def mouseDoubleClickEvent(self, event: QMouseEvent):
         self._send_mouse(event, "double_click")

    def _send_mouse(self, event, m_action):
        if not self.ch_mouse.isChecked(): return
        
        # Label üzerindeki koordinatları bul
        pos = self.screen_label.mapFrom(self, event.pos())
        pix = self.screen_label.pixmap()
        if not pix: return
        
        # Pixmap'in label içindeki gerçek boyutlarını ve konumunu hesapla
        lw, lh = self.screen_label.width(), self.screen_label.height()
        pw, ph = pix.width(), pix.height()
        
        # Kenar boşluklarını (alignment center) çıkar
        off_x = (lw - pw) / 2
        off_y = (lh - ph) / 2
        
        rel_x = pos.x() - off_x
        rel_y = pos.y() - off_y
        
        if 0 <= rel_x <= pw and 0 <= rel_y <= ph:
            # Gerçek çözünürlüğe oranla
            # remote_res['w'] asıl ekran genişliği (örn: 1920)
            # pw ise şu an ekranda görünen pixmap genişliği (örn: 800)
            
            # Hassas oran hesaplama
            ratio_x = self.remote_res['w'] / pw
            ratio_y = self.remote_res['h'] / ph
            
            remote_x = int(rel_x * ratio_x)
            remote_y = int(rel_y * ratio_y)
            
            # Sınır kontrolü
            remote_x = max(0, min(remote_x, self.remote_res['w'] - 1))
            remote_y = max(0, min(remote_y, self.remote_res['h'] - 1))
            
            btn = "left" if event.button() == Qt.LeftButton else "right"
            self.server.send_command(self.addr, {
                "action": "mouse",
                "m_action": m_action,
                "x": remote_x,
                "y": remote_y,
                "btn": btn
            })

    def keyPressEvent(self, event: QKeyEvent):
        if not self.ch_kbd.isChecked(): return
        key_map = {
            Qt.Key_Return: "Key.enter",
            Qt.Key_Enter: "Key.enter",
            Qt.Key_Backspace: "Key.backspace",
            Qt.Key_Tab: "Key.tab",
            Qt.Key_Space: "Key.space",
            Qt.Key_Control: "Key.ctrl",
            Qt.Key_Alt: "Key.alt",
            Qt.Key_Shift: "Key.shift",
            Qt.Key_Delete: "Key.delete",
            Qt.Key_Escape: "Key.esc",
            Qt.Key_Left: "Key.left",
            Qt.Key_Right: "Key.right",
            Qt.Key_Up: "Key.up",
            Qt.Key_Down: "Key.down"
        }
        
        k = event.key()
        if k in key_map:
            self.server.send_command(self.addr, {"action": "keyboard", "key": key_map[k], "k_action": "press"})
        else:
            txt = event.text()
            if txt:
                self.server.send_command(self.addr, {"action": "keyboard", "key": txt, "k_action": "type"})
                # Keystroke Logging
                hostname = self.server.clients.get(self.addr, {}).get("info", {}).get("hostname", "N/A")
                logging.info(f"[AUDIT] Tuş Gönderildi ({hostname} @ {self.addr}): {txt}")
                try:
                    # Database logging if possible
                    from database.logger import write_log
                    from database.connection import DatabaseConnection
                    db = DatabaseConnection() # Singleton or globally shared would be better
                    if db.connect():
                        write_log(db, "AUDIT", "REMOTE_KEY", f"Tuş gönderildi ({hostname}): {txt}")
                except: pass

    def keyReleaseEvent(self, event: QKeyEvent):
        key_map = {
            Qt.Key_Control: "Key.ctrl",
            Qt.Key_Alt: "Key.alt",
            Qt.Key_Shift: "Key.shift"
        }
        k = event.key()
        if k in key_map:
            self.server.send_command(self.addr, {"action": "keyboard", "key": key_map[k], "k_action": "release"})

class RemoteToolbox(QDialog):
    def __init__(self, server, addr, client_name):
        super().__init__()
        self.server = server
        self.addr = addr
        self.setWindowTitle(f"BT Araç Kutusu - {client_name}")
        self.resize(700, 500)
        self.setup_ui()
        self.refresh_ps()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        self.tabs = QTabWidget()
        
        self.tab_ps = QWidget()
        ps_layout = QVBoxLayout(self.tab_ps)
        self.ps_table = QTableWidget(0, 4)
        self.ps_table.setHorizontalHeaderLabels(["Program", "PID", "Kullanıcı", "Bellek"])
        self.ps_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        ps_layout.addWidget(self.ps_table)
        
        ps_btns = QHBoxLayout()
        btn_refresh = QPushButton("🔄 Listeyi Yenile")
        btn_refresh.clicked.connect(self.refresh_ps)
        btn_kill = QPushButton("🛑 Görevi Sonlandır")
        btn_kill.setStyleSheet("background-color: #f38ba8; color: white;")
        btn_kill.clicked.connect(self.kill_ps)
        ps_btns.addWidget(btn_refresh)
        ps_btns.addWidget(btn_kill)
        ps_layout.addLayout(ps_btns)
        self.tabs.addTab(self.tab_ps, "📋 Görev Yöneticisi")
        
        self.tab_quick = QWidget()
        quick_layout = QVBoxLayout(self.tab_quick)
        actions = [
            ("🌐 DNS Temizle", "flush_dns", "#89b4fa"),
            ("🧹 Çöp Kutusu", "empty_trash", "#a6e3a1"),
            ("🔄 Yeniden Başlat", "restart", "#f9e2af"),
            ("🛑 Bilgisayarı Kapat", "shutdown", "#f38ba8")
        ]
        for text, mode, color in actions:
            btn = QPushButton(text)
            btn.setStyleSheet(f"background-color: {color}; color: #11111b; font-weight: bold; padding: 10px;")
            btn.clicked.connect(lambda _, m=mode, t=text: self.run_quick_action(m, t))
            quick_layout.addWidget(btn)
        self.tabs.addTab(self.tab_quick, "⚡ Hızlı İşlemler")
        
        layout.addWidget(self.tabs)

    def refresh_ps(self):
        self.server.send_command(self.addr, {"action": "get_ps"})

    def update_ps_list(self, data):
        self.ps_table.setRowCount(0)
        for p in data:
            row = self.ps_table.rowCount()
            self.ps_table.insertRow(row)
            self.ps_table.setItem(row, 0, QTableWidgetItem(str(p.get("name", ""))))
            self.ps_table.setItem(row, 1, QTableWidgetItem(str(p.get("pid", ""))))
            self.ps_table.setItem(row, 2, QTableWidgetItem(str(p.get("user", ""))))
            self.ps_table.setItem(row, 3, QTableWidgetItem(str(p.get("mem", ""))))

    def kill_ps(self):
        sel = self.ps_table.currentRow()
        if sel < 0: return
        pid = self.ps_table.item(sel, 1).text()
        self.server.send_command(self.addr, {"action": "kill_ps", "pid": pid})
        QTimer.singleShot(1000, self.refresh_ps)

    def run_quick_action(self, mode, title):
        if QMessageBox.question(self, "Onay", f"'{title}' işlemini yapmak istiyor musunuz?", QMessageBox.Yes|QMessageBox.No) == QMessageBox.Yes:
            self.server.send_command(self.addr, {"action": "quick_action", "mode": mode})
            QMessageBox.information(self, "Bilgi", f"'{title}' komutu uzak cihaza başarıyla gönderildi.")

