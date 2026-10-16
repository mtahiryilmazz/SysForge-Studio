import uuid
import datetime
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QTableWidget,
    QTableWidgetItem, QPushButton, QLineEdit, QHeaderView,
    QMessageBox, QComboBox, QFrame, QInputDialog
)
from PySide6.QtCore import Qt, Signal, QTimer
from PySide6.QtGui import QFont, QColor
from ui.premium_styles import PremiumStyles
from database.connection import DatabaseConnection
from database.logger import write_log
from .ui_utils import IPTableWidgetItem



# ─── Tek bir cihaz satırı (dinamik) ──────────────────────────────────────────
class DeviceRow(QWidget):
    """Bir cihaz için Marka / Model / Seri No / IP satırı."""

    def __init__(self, on_remove, parent=None):
        super().__init__(parent)
        self.setObjectName("DeviceRow")
        lay = QHBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(8)

        self.inp_brand  = QLineEdit(); self.inp_brand.setPlaceholderText("Marka")
        self.inp_model  = QLineEdit(); self.inp_model.setPlaceholderText("Model")
        self.inp_serial = QLineEdit(); self.inp_serial.setPlaceholderText("Seri No (boş bırakılabilir)")
        self.inp_ip     = QLineEdit(); self.inp_ip.setPlaceholderText("IP Adresi")

        btn_del = QPushButton("✕")
        btn_del.setCursor(Qt.PointingHandCursor)
        btn_del.setFixedWidth(32)
        btn_del.setStyleSheet(
            "background-color: #f38ba8; color: #1e1e2e; font-weight: bold; "
            "border: none; border-radius: 5px; padding: 6px;"
        )
        btn_del.clicked.connect(lambda: on_remove(self))

        for w in [self.inp_brand, self.inp_model, self.inp_serial, self.inp_ip]:
            lay.addWidget(w)
        lay.addWidget(btn_del)

    def get_data(self):
        return {
            "brand":  self.inp_brand.text().strip(),
            "model":  self.inp_model.text().strip(),
            "serial": self.inp_serial.text().strip(),
            "ip":     self.inp_ip.text().strip(),
        }

    def is_valid(self):
        return bool(self.get_data()["brand"])


# ─── Envanter Sayfası ────────────────────────────────────────────────────────
class InventoryPage(QWidget):
    data_changed = Signal()
    def __init__(self, db_conn: DatabaseConnection, current_user: str = "sistem"):
        super().__init__()
        self.setObjectName("InventoryPage")
        self.db = db_conn
        self.current_user = current_user
        self.editing_id = None
        self._device_rows: list[DeviceRow] = []
        self._setup_ui()
        self._refresh_dropdowns()
        self.load_inventory()

        # Otomatik Yenileme (Web portal sync için)
        self._auto_timer = QTimer(self)
        self._auto_timer.timeout.connect(self.load_inventory)
        self._auto_timer.start(10000)

    # ── UI Kurulumu ──────────────────────────────────────────────────────
    def _setup_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(28, 24, 28, 24)
        root.setSpacing(12)

        # Başlık
        title = QLabel("Cihaz Envanter Yönetimi")
        title.setFont(QFont("Segoe UI", 12, QFont.Bold))
        title.setStyleSheet("color: #6c7086; margin-bottom: 5px;")
        root.addWidget(title)

        # ── FİLTRE SATIRI (başlığın hemen altında — her zaman görünür) ──
        flt = QHBoxLayout()
        flt.setSpacing(10)

        flt.addWidget(QLabel("Müdürlük:"))
        self.cmb_filter_dept = QComboBox()
        self.cmb_filter_dept.setObjectName("InvFilterDept")
        self.cmb_filter_dept.setMinimumWidth(160)
        self.cmb_filter_dept.addItem("Tüm Müdürlükler", userData=None)
        self.cmb_filter_dept.currentIndexChanged.connect(self._on_filter_dept_changed)
        flt.addWidget(self.cmb_filter_dept)

        flt.addWidget(QLabel("Birim:"))
        self.cmb_filter_unit = QComboBox()
        self.cmb_filter_unit.setObjectName("InvFilterUnit")
        self.cmb_filter_unit.setMinimumWidth(160)
        self.cmb_filter_unit.addItem("Tüm Birimler", userData=None)
        self.cmb_filter_unit.currentIndexChanged.connect(self.load_inventory)
        flt.addWidget(self.cmb_filter_unit)

        self.inp_search = QLineEdit()
        self.inp_search.setObjectName("InvSearchInput")
        self.inp_search.setPlaceholderText("🔍  Personel / Marka / Model ara…")
        self.inp_search.textChanged.connect(self.load_inventory)
        
        self.btn_manual_refresh = QPushButton("🔄")
        self.btn_manual_refresh.setFixedWidth(30)
        self.btn_manual_refresh.setFixedHeight(30)
        self.btn_manual_refresh.setCursor(Qt.PointingHandCursor)
        self.btn_manual_refresh.setToolTip("Yenile")
        self.btn_manual_refresh.setStyleSheet("""
            QPushButton { background-color: #313244; color: #89b4fa; border: 1px solid #45475a; border-radius: 4px; }
            QPushButton:hover { background-color: #45475a; }
        """)
        self.btn_manual_refresh.clicked.connect(self.load_inventory)

        flt.addWidget(self.inp_search)
        flt.addWidget(self.btn_manual_refresh)
        flt.addStretch()
        root.addLayout(flt)

        # ── FORM PANELİ (cihaz ekle / güncelle) ─────────────────────────
        self.form_panel = QFrame()
        self.form_panel.setObjectName("InvFormPanel")
        self.form_panel.setStyleSheet("QFrame#InvFormPanel { border-radius: 12px; }")
        form_root = QVBoxLayout(self.form_panel)
        form_root.setContentsMargins(20, 16, 20, 16)
        form_root.setSpacing(12)
        root.addWidget(self.form_panel)

        # Kişi + Müdürlük + Birim satırı
        person_row = QHBoxLayout()
        person_row.setSpacing(12)

        col_dept = QVBoxLayout()
        col_dept.addWidget(self._small_label("Müdürlük"))
        self.cmb_dept = QComboBox()
        self.cmb_dept.setObjectName("InvDeptCombo")
        self.cmb_dept.setMinimumWidth(180)
        self.cmb_dept.currentIndexChanged.connect(self._on_dept_changed)
        col_dept.addWidget(self.cmb_dept)

        col_unit = QVBoxLayout()
        col_unit.addWidget(self._small_label("Birim"))
        self.cmb_unit = QComboBox()
        self.cmb_unit.setObjectName("InvUnitCombo")
        self.cmb_unit.setMinimumWidth(180)
        col_unit.addWidget(self.cmb_unit)

        col_person = QVBoxLayout()
        col_person.addWidget(self._small_label("Personel Adı *"))
        self.inp_person = QLineEdit()
        self.inp_person.setObjectName("InvPersonInput")
        self.inp_person.setPlaceholderText("Ad Soyad")
        col_person.addWidget(self.inp_person)

        person_row.addLayout(col_dept)
        person_row.addLayout(col_unit)
        person_row.addLayout(col_person)
        person_row.addStretch()
        form_root.addLayout(person_row)

        # Cihaz satırları başlığı
        dev_header = QHBoxLayout()
        lbl_devices = QLabel("Cihazlar")
        lbl_devices.setStyleSheet("color: #6c7086; font-size: 11px; font-weight: bold; letter-spacing: 1px;")
        btn_add_row = QPushButton("➕  Cihaz Satırı Ekle")
        btn_add_row.setObjectName("InvAddRowBtn")
        btn_add_row.setCursor(Qt.PointingHandCursor)
        btn_add_row.setStyleSheet(
            "background-color: transparent; color: #89b4fa; "
            "border: 1px solid #89b4fa55; border-radius: 6px; "
            "padding: 4px 14px; font-size: 12px;"
        )
        btn_add_row.clicked.connect(self._add_device_row)

        dev_header.addWidget(lbl_devices)
        dev_header.addStretch()
        dev_header.addWidget(btn_add_row)
        form_root.addLayout(dev_header)

        self.device_container = QVBoxLayout()
        self.device_container.setSpacing(6)
        form_root.addLayout(self.device_container)
        self._add_device_row()

        # Kaydet / İptal
        btn_row = QHBoxLayout()
        btn_row.addStretch()

        self.btn_cancel = QPushButton("İptal")
        self.btn_cancel.setObjectName("InvCancelBtn")
        self.btn_cancel.setCursor(Qt.PointingHandCursor)
        self.btn_cancel.setStyleSheet(
            "background-color: transparent; color: #6c7086; "
            "border: 1px solid #45475a; border-radius: 7px; padding: 8px 20px;"
        )
        self.btn_cancel.setVisible(False)
        self.btn_cancel.clicked.connect(self._cancel_edit)

        self.btn_save = QPushButton("💾  Envantere Kaydet")
        self.btn_save.setObjectName("InvSaveBtn")
        self.btn_save.setCursor(Qt.PointingHandCursor)
        self.btn_save.setStyleSheet(
            "background-color: #89b4fa; color: #1e1e2e; font-weight: bold; "
            "border: none; border-radius: 7px; padding: 8px 24px;"
        )
        self.btn_save.clicked.connect(self._save)

        btn_row.addWidget(self.btn_cancel)
        btn_row.addWidget(self.btn_save)
        form_root.addLayout(btn_row)

        # ── TABLO ────────────────────────────────────────────────────────
        self.table = QTableWidget(0, 9)
        self.table.setSortingEnabled(True) # Sıralamayı aktif et
        self.table.setObjectName("InvTable")

        self.table.setHorizontalHeaderLabels([
            "ID", "Müdürlük", "Birim", "Personel",
            "Marka", "Model", "Seri No", "IP", "İşlemler"
        ])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeToContents) # ID
        self.table.setColumnHidden(0, True) # ID'yi Gizle
        self.table.setColumnWidth(8, 50) # İşlemler
        self.table.setSelectionBehavior(QTableWidget.SelectRows)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.table.verticalHeader().setDefaultSectionSize(45) # Yüksekliği artır
        root.addWidget(self.table)

    # ── Yardımcı ────────────────────────────────────────────────────────
    @staticmethod
    def _small_label(text: str) -> QLabel:
        lbl = QLabel(text)
        lbl.setObjectName("SecondaryLabel")
        return lbl


    # ── Dropdown yenileme ────────────────────────────────────────────────
    def _refresh_dropdowns(self):
        """Müdürlük/Birim combo'larını DB'den yeniler (sadece başlangıçta veya dept değişince)."""
        # Form combo'ı
        self._fill_dept_combo(self.cmb_dept)
        self._on_dept_changed()
        # Filtre combo'ları — mevcut seçimi koru
        cur = self.cmb_filter_dept.currentData()
        self._fill_dept_combo(self.cmb_filter_dept, all_item="Tüm Müdürlükler")
        if cur:
            idx = self.cmb_filter_dept.findData(cur)
            if idx >= 0:
                self.cmb_filter_dept.setCurrentIndex(idx)
        self._on_filter_dept_changed()

    def _fill_dept_combo(self, combo: QComboBox, all_item=None):
        combo.blockSignals(True)
        combo.clear()
        if all_item:
            combo.addItem(all_item, userData=None)
        rows = self.db.fetch_data("SELECT id, name FROM departments ORDER BY name")
        for row in rows:
            d = dict(row)
            combo.addItem(d['name'], userData=d['id'])
        combo.blockSignals(False)

    def _fill_unit_combo(self, combo: QComboBox, dept_id, all_item=None):
        combo.blockSignals(True)
        combo.clear()
        if all_item:
            combo.addItem(all_item, userData=None)
        if dept_id is not None:
            rows = self.db.fetch_data(
                "SELECT id, name FROM units WHERE department_id=? ORDER BY name", (dept_id,)
            )
            for row in rows:
                d = dict(row)
                combo.addItem(d['name'], userData=d['id'])
        combo.blockSignals(False)

    def _on_dept_changed(self):
        dept_id = self.cmb_dept.currentData()
        self._fill_unit_combo(self.cmb_unit, dept_id)

    def _on_filter_dept_changed(self):
        dept_id = self.cmb_filter_dept.currentData()
        self._fill_unit_combo(self.cmb_filter_unit, dept_id, all_item="Tüm Birimler")
        self.load_inventory()

    # ── Cihaz satırı yönetimi ────────────────────────────────────────────
    def _add_device_row(self):
        row = DeviceRow(on_remove=self._remove_device_row)
        self._device_rows.append(row)
        self.device_container.addWidget(row)

    def _remove_device_row(self, row: DeviceRow):
        if len(self._device_rows) <= 1:
            row.inp_brand.clear(); row.inp_model.clear()
            row.inp_serial.clear(); row.inp_ip.clear()
            return
        self._device_rows.remove(row)
        self.device_container.removeWidget(row)
        row.deleteLater()

    def _clear_form(self):
        self.cmb_dept.setCurrentIndex(0)
        self.cmb_unit.setCurrentIndex(0)
        self.inp_person.clear()
        while len(self._device_rows) > 1:
            r = self._device_rows.pop()
            self.device_container.removeWidget(r)
            r.deleteLater()
        if self._device_rows:
            r = self._device_rows[0]
            r.inp_brand.clear(); r.inp_model.clear()
            r.inp_serial.clear(); r.inp_ip.clear()

    # ── CRUD ─────────────────────────────────────────────────────────────
    def _save(self):
        if self.editing_id:
            self._update_single()
        else:
            self._insert_bulk()

    def _insert_bulk(self):
        person = self.inp_person.text().strip()
        dept_id = self.cmb_dept.currentData()
        unit_id = self.cmb_unit.currentData()
        today = datetime.date.today().isoformat()

        if not person:
            QMessageBox.warning(self, "Uyarı", "Personel adı zorunludur.")
            return

        if dept_id is None:
            QMessageBox.warning(self, "Uyarı", "Lütfen bir müdürlük seçin.")
            return

        valid_rows = [r for r in self._device_rows if r.is_valid()]
        if not valid_rows:
            QMessageBox.warning(self, "Uyarı", "En az bir cihazın Marka alanı dolu olmalıdır.")
            return

        errors = 0
        for row in valid_rows:
            d = row.get_data()
            sn = d['serial'] or f"TEMP-{uuid.uuid4().hex[:8]}"
            ok = self.db.execute_query(
                "INSERT INTO inventory (brand, model, serial_no, ip_address, location, user_name, "
                "department_id, unit_id, date) VALUES (?,?,?,?,?,?,?,?,?)",
                (d['brand'], d['model'], sn, d['ip'], '', person, dept_id, unit_id, today)
            )
            if ok:
                write_log(self.db, self.current_user, "EKLE",
                          f"Envanter: {d['brand']} {d['model']} — Personel: {person}")
            else:
                errors += 1

        total = len(valid_rows)
        added = total - errors
        if added > 0:
            self._clear_form()
            self.load_inventory()
            self.data_changed.emit()
            QMessageBox.information(self, "Başarılı",
                f"{added}/{total} cihaz envantere eklendi."
                + (f"\n{errors} kayıt seri no çakışması nedeniyle eklenemedi." if errors else ""))
        else:
            QMessageBox.critical(self, "Hata", "Hiçbir cihaz eklenemedi. Seri No çakışması olabilir.")

    def _update_single(self):
        """Tek kayıt güncelleme."""
        if not self._device_rows:
            return
        d = self._device_rows[0].get_data()
        person = self.inp_person.text().strip()
        dept_id = self.cmb_dept.currentData()
        unit_id = self.cmb_unit.currentData()
        sn = d['serial'] or f"TEMP-{uuid.uuid4().hex[:8]}"
        ok = self.db.execute_query(
            "UPDATE inventory SET brand=?, model=?, serial_no=?, ip_address=?, "
            "user_name=?, department_id=?, unit_id=? WHERE id=?",
            (d['brand'], d['model'], sn, d['ip'], person, dept_id, unit_id, self.editing_id)
        )
        if ok:
            write_log(self.db, self.current_user, "GÜNCELLE",
                      f"Envanter güncellendi: {d['brand']} {d['model']} — {person} (ID:{self.editing_id})")
            self._cancel_edit()
            self.load_inventory()
            self.data_changed.emit()
        else:
            QMessageBox.critical(self, "Hata", "Güncelleme sırasında hata oluştu.")

    def _cancel_edit(self):
        self.editing_id = None
        self._clear_form()
        self.btn_save.setText("💾  Envantere Kaydet")
        self.btn_save.setStyleSheet(
            "background-color: #89b4fa; color: #1e1e2e; font-weight: bold; "
            "border: none; border-radius: 7px; padding: 8px 24px;"
        )
        self.btn_cancel.setVisible(False)

    def _start_edit(self, data: dict):
        """Tablodaki 'Düzenle' butonuna basılınca formu doldurur."""
        self.editing_id = data['id']
        self._clear_form()
        row = self._device_rows[0]
        row.inp_brand.setText(data.get('brand', ''))
        row.inp_model.setText(data.get('model', ''))
        row.inp_serial.setText(data.get('serial_no', ''))
        row.inp_ip.setText(data.get('ip_address', ''))
        self.inp_person.setText(data.get('user_name', ''))

        dept_id = data.get('department_id')
        if dept_id:
            idx = self.cmb_dept.findData(dept_id)
            if idx >= 0:
                self.cmb_dept.setCurrentIndex(idx)
        self._on_dept_changed()

        unit_id = data.get('unit_id')
        if unit_id:
            idx = self.cmb_unit.findData(unit_id)
            if idx >= 0:
                self.cmb_unit.setCurrentIndex(idx)

        self.btn_save.setText("✏️  Güncelle")
        self.btn_save.setStyleSheet(
            "background-color: #fab387; color: #1e1e2e; font-weight: bold; "
            "border: none; border-radius: 7px; padding: 8px 24px;"
        )
        self.btn_cancel.setVisible(True)
        # Forma kaydır
        self.form_panel.setFocus()

    def _delete(self, dev_id: int):
        """Silme: açıklama zorunlu, log'a neden kaydedilir."""
        reason, ok = QInputDialog.getText(
            self, "Silme Nedeni",
            "Bu cihazı envanterden silmek için neden girin (zorunlu):"
        )
        if not ok:
            return
        reason = reason.strip()
        if not reason:
            QMessageBox.warning(self, "Uyarı", "Silme nedeni boş bırakılamaz!")
            return

        rec = self.db.fetch_data("SELECT brand, model, user_name FROM inventory WHERE id=?", (dev_id,))
        if rec:
            r = dict(rec[0])
            write_log(self.db, self.current_user, "SİL",
                      f"Envanter silindi: {r['brand']} {r['model']} "
                      f"— {r['user_name']} (ID:{dev_id}) | Neden: {reason}")
        self.db.execute_query("DELETE FROM inventory WHERE id=?", (dev_id,))
        self.load_inventory()
        self.data_changed.emit()

    # ── Tablo yükleme ────────────────────────────────────────────────────
    def load_inventory(self):
        """DB'den verileri çeker ve tabloyu doldurur."""
        self.table.setSortingEnabled(False)
        self.table.setRowCount(0)

        dept_id = self.cmb_filter_dept.currentData()
        unit_id = self.cmb_filter_unit.currentData()
        search  = self.inp_search.text().strip().lower() if hasattr(self, 'inp_search') else ''

        query = """
            SELECT i.id, COALESCE(d.name,'—') AS dept_name,
                   COALESCE(u.name,'—') AS unit_name,
                   i.user_name, i.brand, i.model, i.serial_no, i.ip_address,
                   i.department_id, i.unit_id
            FROM inventory i
            LEFT JOIN departments d ON d.id = i.department_id
            LEFT JOIN units u ON u.id = i.unit_id
        """
        params = []
        conditions = []

        if dept_id is not None:
            conditions.append("i.department_id = ?")
            params.append(dept_id)
        if unit_id is not None:
            conditions.append("i.unit_id = ?")
            params.append(unit_id)
        if conditions:
            query += " WHERE " + " AND ".join(conditions)
        query += " ORDER BY i.id DESC"

        rows = self.db.fetch_data(query, tuple(params))
        self.table.setSortingEnabled(False)
        self.table.setRowCount(0)


        for _, row_data in enumerate(rows):
            r = dict(row_data)
            if search and not any(search in str(r.get(k, '')).lower()
                                  for k in ('user_name', 'brand', 'model', 'serial_no')):
                continue

            ti = self.table.rowCount()
            self.table.insertRow(ti)

            cells = [
                str(r['id']), r['dept_name'], r['unit_name'], r['user_name'],
                r['brand'], r['model'], r['serial_no'], r['ip_address']
            ]
            for ci, val in enumerate(cells):
                item = IPTableWidgetItem(str(val) if val else '')
                item.setFlags(item.flags() ^ Qt.ItemIsEditable)
                self.table.setItem(ti, ci, item)

            # ... (Actions buttons part follows)


            act = QWidget()
            act_lay = QHBoxLayout(act)
            act_lay.setContentsMargins(2, 1, 2, 1)
            act_lay.setSpacing(3)

            _btn_style = PremiumStyles.TABLE_ACTION_STYLE

            btn_e = QPushButton("✏️")
            btn_e.setToolTip("Kaydı Düzenle")
            btn_e.setStyleSheet(_btn_style.format(bg="#89b4fa", hover="#7aa2e8"))
            btn_e.setCursor(Qt.PointingHandCursor)
            btn_e.clicked.connect(lambda _, d=r: self._start_edit(d))

            btn_d = QPushButton("🗑")
            btn_d.setToolTip("Kaydı Sil")
            btn_d.setStyleSheet(_btn_style.format(bg="#f38ba8", hover="#e07090"))
            btn_d.setCursor(Qt.PointingHandCursor)
            btn_d.clicked.connect(lambda _, did=r['id']: self._delete(did))

            act_lay.addWidget(btn_e)
            act_lay.addWidget(btn_d)
            act_lay.addStretch()
            self.table.setCellWidget(ti, 8, act)

        self.table.setSortingEnabled(True)

