# Dosya Adı: departments_page.py
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QLineEdit, QTableWidget, QTableWidgetItem, QHeaderView,
    QComboBox, QTabWidget, QMessageBox, QFrame
)
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QFont
from ui.premium_styles import PremiumStyles
from database.connection import DatabaseConnection


class DepartmentsPage(QWidget):
    """Müdürlük ve Birim yönetim ekranı.
    Tab 1 → Müdürlükler
    Tab 2 → Birimler (müdürlüğe bağlı)
    """
    # Diğer sayfalara ekle/sil bildirimi için sinyal
    data_changed = Signal()

    def __init__(self, db_conn: DatabaseConnection):
        super().__init__()
        self.setObjectName("DepartmentsPage")
        self.db = db_conn
        self._setup_ui()
        self.load_all()

    # ──────────────────────────────────────────────────────────────────────
    def _setup_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(28, 24, 28, 24)
        root.setSpacing(16)

        title = QLabel("Müdürlük & Birim Yönetimi")
        title.setFont(QFont("Segoe UI", 12, QFont.Bold))
        title.setStyleSheet("color: #6c7086; margin-bottom: 5px;")
        root.addWidget(title)

        self.tabs = QTabWidget()
        self.tab_dept = QWidget()
        self.tab_unit = QWidget()
        self.tabs.addTab(self.tab_dept, "🏛️  Müdürlükler")
        self.tabs.addTab(self.tab_unit, "🗂️  Birimler")
        root.addWidget(self.tabs)

        self._build_dept_tab()
        self._build_unit_tab()

    # ── Müdürlük Sekmesi ──────────────────────────────────────────────────
    def _build_dept_tab(self):
        lay = QVBoxLayout(self.tab_dept)
        lay.setSpacing(12)

        # Form
        form = QHBoxLayout()
        self.inp_dept = QLineEdit()
        self.inp_dept.setPlaceholderText("Müdürlük adı girin…")
        self.inp_dept.setObjectName("DeptNameInput")
        self.inp_dept.returnPressed.connect(self._add_dept)

        btn_add = QPushButton("➕  Müdürlük Ekle")
        btn_add.setObjectName("DeptAddBtn")
        btn_add.setCursor(Qt.PointingHandCursor)
        btn_add.setStyleSheet(
            "background-color: #89b4fa; color: #1e1e2e; font-weight: bold; "
            "padding: 8px 20px; border-radius: 7px; border: none;"
        )
        btn_add.clicked.connect(self._add_dept)

        form.addWidget(self.inp_dept)
        form.addWidget(btn_add)
        lay.addLayout(form)

        # Tablo
        self.tbl_dept = QTableWidget(0, 3)
        self.tbl_dept.setObjectName("DeptTable")
        self.tbl_dept.setHorizontalHeaderLabels(["ID", "Müdürlük Adı", "İşlem"])
        self.tbl_dept.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.tbl_dept.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeToContents)
        self.tbl_dept.setColumnHidden(0, True) # ID'yi Gizle
        self.tbl_dept.setColumnWidth(2, 45)
        self.tbl_dept.setSelectionBehavior(QTableWidget.SelectRows)
        self.tbl_dept.setEditTriggers(QTableWidget.NoEditTriggers)
        self.tbl_dept.verticalHeader().setDefaultSectionSize(45)
        lay.addWidget(self.tbl_dept)

    # ── Birim Sekmesi ─────────────────────────────────────────────────────
    def _build_unit_tab(self):
        lay = QVBoxLayout(self.tab_unit)
        lay.setSpacing(12)

        # Form
        form = QHBoxLayout()

        lbl = QLabel("Müdürlük:")
        lbl.setStyleSheet("color: #6c7086; font-size: 12px;")

        self.cmb_dept_for_unit = QComboBox()
        self.cmb_dept_for_unit.setObjectName("UnitDeptCombo")
        self.cmb_dept_for_unit.setMinimumWidth(200)

        self.inp_unit = QLineEdit()
        self.inp_unit.setPlaceholderText("Birim adı girin…")
        self.inp_unit.setObjectName("UnitNameInput")
        self.inp_unit.returnPressed.connect(self._add_unit)

        btn_add = QPushButton("➕  Birim Ekle")
        btn_add.setObjectName("UnitAddBtn")
        btn_add.setCursor(Qt.PointingHandCursor)
        btn_add.setStyleSheet(
            "background-color: #a6e3a1; color: #1e1e2e; font-weight: bold; "
            "padding: 8px 20px; border-radius: 7px; border: none;"
        )
        btn_add.clicked.connect(self._add_unit)

        form.addWidget(lbl)
        form.addWidget(self.cmb_dept_for_unit)
        form.addWidget(self.inp_unit)
        form.addWidget(btn_add)
        lay.addLayout(form)

        # Tablo
        self.tbl_unit = QTableWidget(0, 4)
        self.tbl_unit.setObjectName("UnitTable")
        self.tbl_unit.setHorizontalHeaderLabels(["ID", "Müdürlük", "Birim Adı", "İşlem"])
        self.tbl_unit.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.tbl_unit.horizontalHeader().setSectionResizeMode(2, QHeaderView.Stretch)
        self.tbl_unit.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeToContents)
        self.tbl_unit.setColumnHidden(0, True) # ID'yi Gizle
        self.tbl_unit.setColumnWidth(3, 45)
        self.tbl_unit.setSelectionBehavior(QTableWidget.SelectRows)
        self.tbl_unit.setEditTriggers(QTableWidget.NoEditTriggers)
        self.tbl_unit.verticalHeader().setDefaultSectionSize(45)
        lay.addWidget(self.tbl_unit)

    # ──────────────────────────────────────────────────────────────────────
    #  Veri işlemleri
    # ──────────────────────────────────────────────────────────────────────
    def load_all(self):
        self._load_depts()
        self._load_units()
        self._refresh_dept_combo()

    def _load_depts(self):
        self.tbl_dept.setRowCount(0)
        rows = self.db.fetch_data("SELECT id, name FROM departments ORDER BY name")
        for i, row in enumerate(rows):
            d = dict(row)
            self.tbl_dept.insertRow(i)
            self.tbl_dept.setItem(i, 0, QTableWidgetItem(str(d['id'])))
            self.tbl_dept.setItem(i, 1, QTableWidgetItem(d['name']))
            self.tbl_dept.setCellWidget(i, 2, self._del_btn(
                lambda _, rid=d['id']: self._del_dept(rid)
            ))

    def _load_units(self):
        self.tbl_unit.setRowCount(0)
        rows = self.db.fetch_data(
            "SELECT u.id, d.name as dept_name, u.name "
            "FROM units u JOIN departments d ON d.id=u.department_id ORDER BY d.name, u.name"
        )
        for i, row in enumerate(rows):
            d = dict(row)
            self.tbl_unit.insertRow(i)
            self.tbl_unit.setItem(i, 0, QTableWidgetItem(str(d['id'])))
            self.tbl_unit.setItem(i, 1, QTableWidgetItem(d['dept_name']))
            self.tbl_unit.setItem(i, 2, QTableWidgetItem(d['name']))
            self.tbl_unit.setCellWidget(i, 3, self._del_btn(
                lambda _, rid=d['id']: self._del_unit(rid)
            ))

    def _refresh_dept_combo(self):
        self.cmb_dept_for_unit.clear()
        rows = self.db.fetch_data("SELECT id, name FROM departments ORDER BY name")
        for row in rows:
            d = dict(row)
            self.cmb_dept_for_unit.addItem(d['name'], userData=d['id'])

    def _del_btn(self, callback) -> QWidget:
        w = QWidget()
        lay = QHBoxLayout(w)
        lay.setContentsMargins(2, 1, 2, 1)
        lay.setSpacing(3)
        
        btn = QPushButton("🗑️")
        btn.setToolTip("Kaydı Sil")
        btn.setCursor(Qt.PointingHandCursor)
        
        # Premium Stil
        btn.setStyleSheet(PremiumStyles.TABLE_ACTION_STYLE.format(
            bg="#f38ba8", hover="#e07090"
        ))
        
        btn.clicked.connect(callback)
        lay.addWidget(btn)
        lay.addStretch()
        return w

    # ── Ekle / Sil ────────────────────────────────────────────────────────
    def _add_dept(self):
        name = self.inp_dept.text().strip()
        if not name:
            return
        ok = self.db.execute_query(
            "INSERT OR IGNORE INTO departments (name) VALUES (?)", (name,)
        )
        if ok:
            self.inp_dept.clear()
            self.load_all()
            self.data_changed.emit()   # Diğer sayfalara bildir
        else:
            QMessageBox.warning(self, "Hata", "Bu müdürlük zaten mevcut!")

    def _add_unit(self):
        name = self.inp_unit.text().strip()
        dept_id = self.cmb_dept_for_unit.currentData()
        if not name or dept_id is None:
            QMessageBox.warning(self, "Uyarı", "Müdürlük seçin ve birim adı girin.")
            return
        ok = self.db.execute_query(
            "INSERT INTO units (department_id, name) VALUES (?, ?)", (dept_id, name)
        )
        if ok:
            self.inp_unit.clear()
            self._load_units()
            self.data_changed.emit()   # Diğer sayfalara bildir
        else:
            QMessageBox.warning(self, "Hata", "Birim eklenemedi.")

    def _del_dept(self, dept_id: int):
        reply = QMessageBox.question(
            self, "Emin misiniz?",
            "Bu müdürlük ve bağlı tüm birimler silinecek. Devam edilsin mi?",
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
        if reply == QMessageBox.Yes:
            self.db.execute_query("DELETE FROM units WHERE department_id=?", (dept_id,))
            self.db.execute_query("DELETE FROM departments WHERE id=?", (dept_id,))
            self.load_all()
            self.data_changed.emit()   # Diğer sayfalara bildir

    def _del_unit(self, unit_id: int):
        reply = QMessageBox.question(
            self, "Emin misiniz?", "Bu birim silinecek. Devam edilsin mi?",
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
        if reply == QMessageBox.Yes:
            self.db.execute_query("DELETE FROM units WHERE id=?", (unit_id,))
            self._load_units()
            self.data_changed.emit()   # Diğer sayfalara bildir
