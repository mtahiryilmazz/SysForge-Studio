from PySide6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QTabWidget,
                               QTableWidget, QTableWidgetItem, QHeaderView, QLineEdit, QLabel, 
                               QComboBox, QMessageBox, QInputDialog, QCheckBox, QDialog,
                               QGridLayout, QFrame)
from PySide6.QtGui import QFont
from PySide6.QtCore import Qt
from ui.premium_styles import PremiumStyles
from database.connection import DatabaseConnection
from modules.auth import AuthModule
import time

class PermissionEditDialog(QDialog):
    def __init__(self, parent, user_id, username, current_perms_str):
        super().__init__(parent)
        self.user_id = user_id
        self.setWindowTitle(f"'{username}' Yetkilerini Düzenle")
        self.setMinimumWidth(300)
        
        layout = QVBoxLayout(self)
        
        self.chk_dashboard = QCheckBox("Dashboard")
        self.chk_tickets = QCheckBox("Arızalar")
        self.chk_inventory = QCheckBox("Envanter")
        self.chk_network = QCheckBox("Ağ Yönetimi")
        self.chk_printers = QCheckBox("Yazıcı Merkezi")
        self.chk_reports = QCheckBox("Raporlar")
        self.chk_remote_screen = QCheckBox("Uzak: Ekran İzleme")
        self.chk_remote_msg = QCheckBox("Uzak: Mesaj Atma")
        self.chk_remote_cmd = QCheckBox("Uzak: CMD Konsol")
        
        # Load existing checks
        current_perms = [p.strip() for p in current_perms_str.split(",")]
        is_all = current_perms_str == "*"
        
        self.chk_dashboard.setChecked(is_all or 'dashboard' in current_perms)
        self.chk_tickets.setChecked(is_all or 'tickets' in current_perms)
        self.chk_inventory.setChecked(is_all or 'inventory' in current_perms)
        self.chk_network.setChecked(is_all or 'network' in current_perms)
        self.chk_printers.setChecked(is_all or 'printers' in current_perms)
        self.chk_reports.setChecked(is_all or 'reports' in current_perms)
        self.chk_remote_screen.setChecked(is_all or 'remote_screen' in current_perms or 'remote' in current_perms)
        self.chk_remote_msg.setChecked(is_all or 'remote_msg' in current_perms or 'remote' in current_perms)
        self.chk_remote_cmd.setChecked(is_all or 'remote_cmd' in current_perms or 'remote' in current_perms)
        
        for chk in [self.chk_dashboard, self.chk_tickets, self.chk_inventory, 
                    self.chk_network, self.chk_printers, self.chk_reports,
                    self.chk_remote_screen, self.chk_remote_msg, self.chk_remote_cmd]:
            layout.addWidget(chk)
            
        btn_save = QPushButton("Kaydet")
        btn_save.clicked.connect(self.accept)
        layout.addWidget(btn_save)

    def get_selected_permissions(self):
        perms = []
        if self.chk_dashboard.isChecked(): perms.append('dashboard')
        if self.chk_tickets.isChecked(): perms.append('tickets')
        if self.chk_inventory.isChecked(): perms.append('inventory')
        if self.chk_network.isChecked(): perms.append('network')
        if self.chk_printers.isChecked(): perms.append('printers')
        if self.chk_reports.isChecked(): perms.append('reports')
        if self.chk_remote_screen.isChecked(): perms.append('remote_screen')
        if self.chk_remote_msg.isChecked(): perms.append('remote_msg')
        if self.chk_remote_cmd.isChecked(): perms.append('remote_cmd')
        return ",".join(perms)

class UsersPage(QWidget):
    def __init__(self, db_conn, user_data=None):
        super().__init__()
        self.db_conn = db_conn
        self.module = AuthModule(self.db_conn)
        self.current_user_id = user_data.get('id') if user_data else None
        self.setup_ui()
        self.load_data()

    def setup_ui(self):
        main_layout = QVBoxLayout(self)

        lbl_title = QLabel("Kullanıcı ve Yetki Yönetimi")
        lbl_title.setFont(QFont("Segoe UI", 12, QFont.Bold))
        lbl_title.setStyleSheet("color: #6c7086; margin-bottom: 5px;")
        main_layout.addWidget(lbl_title)
        
        self.tabs = QTabWidget()
        self.tab_users = QWidget()
        self.tab_active = QWidget()
        self.tabs.addTab(self.tab_users, "Kullanıcıları Yönet")
        self.tabs.addTab(self.tab_active, "🟢 Online Personeller")
        main_layout.addWidget(self.tabs)

        self._setup_users_tab()
        self._setup_active_tab()

    def _setup_users_tab(self):
        layout = QVBoxLayout(self.tab_users)
        layout.setSpacing(15)

        # Form ve Yetkiler için çerçeve
        form_frame = QFrame()
        form_frame.setStyleSheet("QFrame#FormFrame { border: 1px solid #555; border-radius: 8px; background-color: rgba(128, 128, 128, 0.05); }")
        form_frame.setObjectName("FormFrame")
        form_main_layout = QVBoxLayout(form_frame)
        form_main_layout.setContentsMargins(15, 15, 15, 15)
        form_main_layout.setSpacing(10)

        # KULLANICI BİLGİLERİ (ÜST SATIR)
        info_layout = QHBoxLayout()
        info_layout.setSpacing(10)
        self.inp_user = QLineEdit(); self.inp_user.setPlaceholderText("Kullanıcı Adı")
        self.inp_pass = QLineEdit(); self.inp_pass.setPlaceholderText("Şifre")
        self.inp_role = QComboBox()
        self.inp_role.addItems(["Teknik Personel", "İzleme Sorumlusu", "Admin"])

        for w in [self.inp_user, self.inp_pass, self.inp_role]:
            info_layout.addWidget(w)
            
        form_main_layout.addLayout(info_layout)

        # YETKİLER (GRID)
        lbl_perms = QLabel("Atanacak Yetkiler:")
        font_perms = QFont("Segoe UI", 11, QFont.Bold)
        lbl_perms.setFont(font_perms)
        form_main_layout.addWidget(lbl_perms)

        perm_grid = QGridLayout()
        perm_grid.setSpacing(10)
        
        self.chk_dashboard = QCheckBox("Dashboard"); self.chk_dashboard.setChecked(True)
        self.chk_tickets = QCheckBox("Arızalar"); self.chk_tickets.setChecked(True)
        self.chk_inventory = QCheckBox("Envanter"); self.chk_inventory.setChecked(True)
        self.chk_network = QCheckBox("Ağ Yönetimi"); self.chk_network.setChecked(False)
        self.chk_printers = QCheckBox("Yazıcı Merkezi"); self.chk_printers.setChecked(False)
        self.chk_reports = QCheckBox("Raporlar"); self.chk_reports.setChecked(True)
        self.chk_remote_screen = QCheckBox("Ekran İzleme"); self.chk_remote_screen.setChecked(False)
        self.chk_remote_msg = QCheckBox("Mesaj Atma"); self.chk_remote_msg.setChecked(False)
        self.chk_remote_cmd = QCheckBox("CMD / Konsol"); self.chk_remote_cmd.setChecked(False)
        
        checks = [
            self.chk_dashboard, self.chk_tickets, self.chk_inventory, 
            self.chk_network, self.chk_printers, self.chk_reports,
            self.chk_remote_screen, self.chk_remote_msg, self.chk_remote_cmd
        ]
        
        for i, chk in enumerate(checks):
            font = QFont("Segoe UI", 10)
            chk.setFont(font)
            perm_grid.addWidget(chk, i // 3, i % 3)
            
        form_main_layout.addLayout(perm_grid)

        # EKLE BUTONU
        btn_layout = QHBoxLayout()
        btn_layout.addStretch()
        btn_add = QPushButton("Kullanıcı Ekle")
        btn_add.setStyleSheet("background-color: #28a745; color: white; padding: 10px 30px; font-weight: bold; border-radius: 5px; font-size: 14px;")
        btn_add.clicked.connect(self.add_new_user)
        btn_layout.addWidget(btn_add)
        form_main_layout.addLayout(btn_layout)

        layout.addWidget(form_frame)

        # TABLO
        self.table = QTableWidget(0, 9)
        self.table.setHorizontalHeaderLabels(["ID", "Kullanıcı Adı", "Şifre (Açık)", "Rol", "Yetkiler", "Ad Gnc.", "Şifre Gnc.", "Yetki Gnc.", "İşlem"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeToContents) # ID
        self.table.setColumnHidden(0, True) # ID'yi Gizle
        self.table.setColumnWidth(5, 45)  # Ad Gnc.
        self.table.setColumnWidth(6, 45)  # Şifre Gnc.
        self.table.setColumnWidth(7, 45)  # Yetki Gnc.
        self.table.setColumnWidth(8, 45)  # İşlem
        self.table.setSelectionBehavior(QTableWidget.SelectRows)
        self.table.setStyleSheet("""
            QTableWidget { font-size: 14px; }
            QTableCornerButton::section { background-color: #181825; border: 1px solid #313244; }
        """)
        layout.addWidget(self.table)

    def _create_table_button(self, icon, color, tooltip, callback):
        container = QWidget()
        lay = QHBoxLayout(container)
        lay.setContentsMargins(2, 1, 2, 1)
        lay.setSpacing(3)
        
        btn = QPushButton(icon)
        btn.setToolTip(tooltip)
        btn.setCursor(Qt.PointingHandCursor)
        
        # Standart stil
        btn.setStyleSheet(PremiumStyles.TABLE_ACTION_STYLE.format(bg=color, hover=color+"bb"))
        
        btn.clicked.connect(callback)
        lay.addWidget(btn)
        lay.addStretch()
        return container

    def _setup_active_tab(self):
        layout = QVBoxLayout(self.tab_active)
        btn_refresh = QPushButton("Listeyi Yenile (F5)")
        btn_refresh.clicked.connect(self.load_data)
        btn_refresh.setStyleSheet("padding: 8px; font-weight:bold; width: 150px;")
        layout.addWidget(btn_refresh)

        self.table_active = QTableWidget(0, 4)
        self.table_active.setHorizontalHeaderLabels(["Kullanıcı ID", "Kullanıcı Adı", "Rolü", "Son Etkileşim"])
        self.table_active.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table_active.setStyleSheet("QTableWidget { font-size: 14px; }")
        layout.addWidget(self.table_active)


    def load_data(self):
        # 1. Kullanicilari Yukle
        self.table.setRowCount(0)
        try:
            data = self.module.get_all_users() or []
        except Exception:
            data = []
        for row, r_item in enumerate(data):
            try:
                item = dict(r_item) if not isinstance(r_item, dict) else r_item
            except Exception:
                item = {}
            self.table.insertRow(row)
            self.table.setItem(row, 0, QTableWidgetItem(str(item.get("id", ""))))
            self.table.setItem(row, 1, QTableWidgetItem(str(item.get("username", ""))))
            self.table.setItem(row, 2, QTableWidgetItem(str(item.get("password", ""))))
            self.table.setItem(row, 3, QTableWidgetItem(str(item.get("role", ""))))
            self.table.setItem(row, 4, QTableWidgetItem(str(item.get("permissions", ""))))

            u_id = item.get("id")
            uname = item.get("username", "")
            perms = str(item.get("permissions", ""))
            role = str(item.get("role", ""))

            c_uname = self._create_table_button("✏️", "#a6e3a1", "Adı Değiştir",
                lambda _, uid=u_id, un=uname: self.edit_username(uid, un))
            self.table.setCellWidget(row, 5, c_uname)

            c_edit = self._create_table_button("🔑", "#89b4fa", "Şifre Değiştir",
                lambda _, uid=u_id, un=uname: self.edit_password(uid, un))
            self.table.setCellWidget(row, 6, c_edit)

            c_perm = self._create_table_button("🛡️", "#fab387", "Yetkileri Düzenle",
                lambda _, uid=u_id, un=uname, p=perms, r=role: self.edit_permissions(uid, un, p, r))
            self.table.setCellWidget(row, 7, c_perm)

            c_del = self._create_table_button("🗑️", "#f38ba8", "Kullanıcıyı Sil",
                lambda _, uid=u_id, r=role: self.delete_user_confirm(uid, r))
            self.table.setCellWidget(row, 8, c_del)

        # 2. Aktif (Online) Kisileri Yukle
        self.table_active.setRowCount(0)
        try:
            actives = self.module.get_active_users() or []
        except Exception:
            actives = []
        for row, r_item in enumerate(actives):
            try:
                item = dict(r_item) if not isinstance(r_item, dict) else r_item
            except Exception:
                item = {}
            self.table_active.insertRow(row)
            self.table_active.setItem(row, 0, QTableWidgetItem(str(item.get("id", ""))))
            self.table_active.setItem(row, 1, QTableWidgetItem(str(item.get("username", ""))))
            self.table_active.setItem(row, 2, QTableWidgetItem(str(item.get("role", ""))))
            try:
                la = str(item.get("last_active") or "")
                if "|" in la:
                    ts, plat = la.split("|", 1)
                else:
                    ts, plat = la, "unknown"
                    
                diff = int(time.time()) - int(ts) if ts.isdigit() else 999
                time_str = "Şu an Aktif" if diff < 60 else f"{diff // 60} dakika önce"
                
                if plat == "desktop":
                    icon = "💻 "
                elif plat == "web":
                    icon = "🌐 "
                else:
                    icon = "❓ "
                    
                self.table_active.setItem(row, 3, QTableWidgetItem(f"{icon} {time_str}"))
            except Exception:
                self.table_active.setItem(row, 3, QTableWidgetItem("Bilinmiyor"))

    def add_new_user(self):
        u = self.inp_user.text().strip()
        p = self.inp_pass.text().strip()
        r = self.inp_role.currentText()
        
        perms = []
        if self.chk_dashboard.isChecked(): perms.append('dashboard')
        if self.chk_tickets.isChecked(): perms.append('tickets')
        if self.chk_inventory.isChecked(): perms.append('inventory')
        if self.chk_network.isChecked(): perms.append('network')
        if self.chk_printers.isChecked(): perms.append('printers')
        if self.chk_reports.isChecked(): perms.append('reports')
        if self.chk_remote_screen.isChecked(): perms.append('remote_screen')
        if self.chk_remote_msg.isChecked(): perms.append('remote_msg')
        if self.chk_remote_cmd.isChecked(): perms.append('remote_cmd')
        
        perm_str = ",".join(perms)
        if r == "Admin":
            perm_str = "*"
            
        if u and p:
            success = self.module.add_user(u, p, r, permissions=perm_str)
            if success:
                self.inp_user.clear()
                self.inp_pass.clear()
                self.load_data()
            else:
                QMessageBox.warning(self, "Hata", "Bu kullanıcı adı zaten mevcut olabilir!")

    def edit_username(self, user_id, username):
        new_uname, ok = QInputDialog.getText(self, "Adı Değiştir", f"'{username}' için yeni kullanıcı adı:", QLineEdit.Normal, username)
        if ok and new_uname.strip():
            success = self.module.update_username(user_id, new_uname.strip())
            if success:
                self.load_data()
                QMessageBox.information(self, "Başarılı", "Kullanıcı adı güncellendi.")
            else:
                QMessageBox.warning(self, "Hata", "Bu kullanıcı adı alınmış olabilir veya hata oluştu.")

    def edit_password(self, user_id, username):
        new_pass, ok = QInputDialog.getText(self, "Şifre Değiştir", f"'{username}' için yeni şifre belirleyin:")
        if ok and new_pass.strip():
            self.module.update_user_password(user_id, new_pass.strip())
            self.load_data()
            QMessageBox.information(self, "Başarılı", f"Kullanıcı parolası güncellendi.")

    def edit_permissions(self, user_id, username, current_perms, role):
        if role == "Admin":
            QMessageBox.information(self, "Bilgi", "Sen bir Admin'sin, Master Chief'sin! Yetkilerin zaten sınırsızdır ve değiştirilemez.")
            return
            
        dialog = PermissionEditDialog(self, user_id, username, current_perms)
        if dialog.exec():
            new_perms = dialog.get_selected_permissions()
            self.module.update_user_permissions(user_id, new_perms)
            self.load_data()
            QMessageBox.information(self, "Başarılı", f"'{username}' adlı personelin yetkileri güncellendi.")

    def delete_user_confirm(self, user_id, role):
        if str(user_id) == str(self.current_user_id):
            QMessageBox.warning(self, "İzin Reddedildi", "Kendi hesabınızı silemezsiniz!")
            return
            
        # Admin silinmek isteniyorsa, geriye en az 1 Admin kalacak mı kontrolü
        if role == "Admin":
            count_data = self.module.db.fetch_data("SELECT count(id) as c FROM users WHERE role='Admin'")
            if count_data and count_data[0]['c'] <= 1:
                QMessageBox.warning(self, "Kritik", "Sistemdeki son Yönetici (Admin) hesabı silinemez!")
                return
             
        reply = QMessageBox.question(self, 'Emin misiniz?', 
                                     'Bu personeli sistemden tamamen silmek istediğinize emin misiniz? (Geri alınamaz)',
                                     QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        
        if reply == QMessageBox.Yes:
            self.module.delete_user(user_id)
            self.load_data()
