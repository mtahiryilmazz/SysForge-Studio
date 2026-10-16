from PySide6.QtWidgets import (QDialog, QVBoxLayout, QLabel, QLineEdit, 
                             QPushButton, QHBoxLayout, QMessageBox)
from PySide6.QtCore import Qt

class LicenseDialog(QDialog):
    def __init__(self, license_manager, parent=None):
        super().__init__(parent)
        self.mgr = license_manager
        self.setWindowTitle("SENTINEL - Lisans Etkinleştirme")
        self.setFixedSize(400, 250)
        self.init_ui()
        self.setWindowFlags(self.windowFlags() & ~Qt.WindowContextHelpButtonHint)

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setSpacing(20)
        layout.setContentsMargins(30, 30, 30, 30)

        title = QLabel("LÜTFEN LİSANS ANAHTARINIZI GİRİN")
        title.setStyleSheet("font-weight: bold; font-size: 14px; color: #3b82f6;")
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)

        hwid_label = QLabel(f"Cihaz Kimliği (HWID):\n{self.mgr.hwid}")
        hwid_label.setStyleSheet("font-size: 10px; color: gray;")
        hwid_label.setAlignment(Qt.AlignCenter)
        hwid_label.setWordWrap(True)
        layout.addWidget(hwid_label)

        self.key_input = QLineEdit()
        self.key_input.setPlaceholderText("XXXX-XXXX-XXXX-XXXX")
        self.key_input.setStyleSheet("padding: 10px; font-size: 14px; border: 2px solid #3b82f6; border-radius: 5px;")
        layout.addWidget(self.key_input)

        btn_layout = QHBoxLayout()
        self.btn_activate = QPushButton("Etkinleştir")
        self.btn_activate.setStyleSheet("""
            QPushButton {
                background-color: #3b82f6; color: white; padding: 10px; font-weight: bold; border-radius: 5px;
            }
            QPushButton:hover { background-color: #2563eb; }
        """)
        self.btn_activate.clicked.connect(self.do_activate)
        
        self.btn_exit = QPushButton("Çıkış")
        self.btn_exit.setStyleSheet("padding: 10px;")
        self.btn_exit.clicked.connect(self.reject)
        
        btn_layout.addWidget(self.btn_exit)
        btn_layout.addWidget(self.btn_activate)
        layout.addLayout(btn_layout)

    def do_activate(self):
        key = self.key_input.text().strip()
        if not key:
            QMessageBox.warning(self, "Hata", "Lütfen bir anahtar girin.")
            return
            
        self.setDisabled(True)
        ok, msg = self.mgr.activate(key)
        self.setDisabled(False)
        
        if ok:
            QMessageBox.information(self, "Başarılı", msg)
            self.accept()
        else:
            QMessageBox.critical(self, "Hata", msg)
