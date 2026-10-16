import datetime
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QTableWidget,
    QTableWidgetItem, QPushButton, QLineEdit, QComboBox, QTextEdit,
    QHeaderView, QMessageBox, QTabWidget, QInputDialog, QFrame
)
from PySide6.QtCore import Qt, Signal, QTimer
from PySide6.QtGui import QFont
from database.connection import DatabaseConnection
from database.logger import write_log
from ui.premium_styles import PremiumStyles
from .ui_utils import IPTableWidgetItem



class TicketsPage(QWidget):
    data_changed = Signal()
    def __init__(self, db_conn: DatabaseConnection, current_user: str = "sistem"):
        super().__init__()
        self.setObjectName("TicketsPage")
        self.db = db_conn
        self.current_user = current_user
        self.editing_id = None
        self._setup_ui()
        self.refresh_dropdowns()
        self.load_tickets()

        # Arkaplan yenileme (Dışardan gelen değişiklikler için)
        self._auto_timer = QTimer(self)
        self._auto_timer.timeout.connect(self.load_tickets)
        self._auto_timer.start(10000)

    # ── Yardımcı ────────────────────────────────────────────────────────
    @staticmethod
    def _lbl(text: str) -> QLabel:
        l = QLabel(text)
        l.setObjectName("SecondaryLabel")
        return l


    # ── UI Kurulumu ──────────────────────────────────────────────────────
    def _setup_ui(self):
        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(20, 20, 20, 20)
        main_layout.setSpacing(20)

        # ── SOL: Form paneli ─────────────────────────────────────────────
        form_frame = QFrame()
        form_frame.setObjectName("TicketFormFrame")
        form_frame.setFixedWidth(300)
        # Arka plan rengi QSS temasından alınır
        form_frame.setStyleSheet("QFrame#TicketFormFrame { border-radius: 12px; }")
        form_layout = QVBoxLayout(form_frame)
        form_layout.setContentsMargins(16, 16, 16, 16)
        form_layout.setSpacing(6)
        form_layout.setAlignment(Qt.AlignTop)

        lbl_title = QLabel("Yeni Arıza Kaydı")
        lbl_title.setFont(QFont("Segoe UI", 12, QFont.Bold))
        lbl_title.setStyleSheet("color: #6c7086; margin-bottom: 5px;")
        form_layout.addWidget(lbl_title)

        # Müdürlük dropdown
        form_layout.addWidget(self._lbl("Müdürlük"))
        self.cmb_dept = QComboBox()
        self.cmb_dept.setObjectName("TicketDeptCombo")
        self.cmb_dept.currentIndexChanged.connect(self._on_dept_changed)
        form_layout.addWidget(self.cmb_dept)

        # Birim dropdown
        form_layout.addWidget(self._lbl("Birim"))
        self.cmb_unit = QComboBox()
        self.cmb_unit.setObjectName("TicketUnitCombo")
        form_layout.addWidget(self.cmb_unit)

        # Personel
        form_layout.addWidget(self._lbl("Personel Adı *"))
        self.inp_person = QLineEdit()
        self.inp_person.setObjectName("TicketPersonInput")
        self.inp_person.setPlaceholderText("Ad Soyad")
        form_layout.addWidget(self.inp_person)

        # Dahili numara
        form_layout.addWidget(self._lbl("Dahili Numara"))
        self.inp_intern = QLineEdit()
        self.inp_intern.setObjectName("TicketInternInput")
        self.inp_intern.setPlaceholderText("Opsiyonel")
        form_layout.addWidget(self.inp_intern)

        # Arıza Türü
        form_layout.addWidget(self._lbl("Arıza Türü"))
        self.issue_type = QComboBox()
        self.issue_type.addItems(["Donanım", "Yazılım", "Ağ", "Yazıcı", "Diğer"])
        form_layout.addWidget(self.issue_type)

        # Öncelik
        form_layout.addWidget(self._lbl("Öncelik"))
        self.priority = QComboBox()
        self.priority.addItems(["Düşük", "Normal", "Yüksek", "Acil"])
        form_layout.addWidget(self.priority)

        # Açıklama
        form_layout.addWidget(self._lbl("Açıklama"))
        self.description = QTextEdit()
        self.description.setObjectName("TicketDescInput")
        self.description.setMinimumHeight(80)
        self.description.setMaximumHeight(120)
        form_layout.addWidget(self.description)

        form_layout.addSpacing(8)

        self.btn_save = QPushButton("💾  Kaydı Oluştur")
        self.btn_save.setObjectName("TicketSaveBtn")
        self.btn_save.setCursor(Qt.PointingHandCursor)
        self.btn_save.setStyleSheet(
            "background-color: #89b4fa; color: #1e1e2e; font-weight: bold; "
            "border: none; border-radius: 7px; padding: 9px;"
        )
        self.btn_save.clicked.connect(self.save_ticket)
        form_layout.addWidget(self.btn_save)

        self.btn_cancel = QPushButton("İptal")
        self.btn_cancel.setObjectName("TicketCancelBtn")
        self.btn_cancel.setCursor(Qt.PointingHandCursor)
        self.btn_cancel.setStyleSheet(
            "background-color: transparent; color: #6c7086; "
            "border: 1px solid #45475a; border-radius: 7px; padding: 7px;"
        )
        self.btn_cancel.setVisible(False)
        self.btn_cancel.clicked.connect(self.cancel_edit)
        form_layout.addWidget(self.btn_cancel)

        form_layout.addStretch()

        # ── SAĞ: Sekmeli tablo ───────────────────────────────────────────
        right_layout = QVBoxLayout()
        self.tabs = QTabWidget()
        self.tabs.setObjectName("TicketTabs")

        self.tab_active = QWidget()
        l_active = QVBoxLayout(self.tab_active)
        l_active.setContentsMargins(0, 8, 0, 0)
        self.table_active = self._create_table()
        l_active.addWidget(self.table_active)
        self.tabs.addTab(self.tab_active, "🔴  Açık Arızalar")

        self.tab_archive = QWidget()
        l_archive = QVBoxLayout(self.tab_archive)
        l_archive.setContentsMargins(0, 8, 0, 0)
        self.table_archive = self._create_table()
        l_archive.addWidget(self.table_archive)
        self.tabs.addTab(self.tab_archive, "✅  Geçmiş (Arşiv)")

        # ── Filtre satırı (tablo üstü) ───────────────────────────────────────────
        filter_row = QHBoxLayout()
        filter_row.setSpacing(8)

        lbl_f = QLabel("Filtre:")
        lbl_f.setStyleSheet("color: #9399b2; font-size: 11px;")

        self.cmb_filter_dept = QComboBox()
        self.cmb_filter_dept.setObjectName("TktFilterDept")
        self.cmb_filter_dept.addItem("Tüm Müdürlükler", userData=None)
        self.cmb_filter_dept.currentIndexChanged.connect(self._on_filter_dept_changed)

        self.cmb_filter_unit = QComboBox()
        self.cmb_filter_unit.setObjectName("TktFilterUnit")
        self.cmb_filter_unit.addItem("Tüm Birimler", userData=None)
        self.cmb_filter_unit.currentIndexChanged.connect(self.load_tickets)

        self.inp_search = QLineEdit()
        self.inp_search.setObjectName("TktSearchInput")
        self.inp_search.setPlaceholderText("Personel / Ariza türü ara…")
        self.inp_search.textChanged.connect(self.load_tickets)

        self.btn_manual_refresh = QPushButton("🔄")
        self.btn_manual_refresh.setFixedWidth(30)
        self.btn_manual_refresh.setFixedHeight(30)
        self.btn_manual_refresh.setCursor(Qt.PointingHandCursor)
        self.btn_manual_refresh.setToolTip("Yenile")
        self.btn_manual_refresh.setStyleSheet("""
            QPushButton { background-color: #313244; color: #89b4fa; border: 1px solid #45475a; border-radius: 4px; }
            QPushButton:hover { background-color: #45475a; }
        """)
        self.btn_manual_refresh.clicked.connect(self.load_tickets)

        filter_row.addWidget(lbl_f)
        filter_row.addWidget(self.cmb_filter_dept)
        filter_row.addWidget(self.cmb_filter_unit)
        filter_row.addWidget(self.inp_search)
        filter_row.addWidget(self.btn_manual_refresh)
        filter_row.addStretch()
        right_layout.addLayout(filter_row)

        right_layout.addWidget(self.tabs)

        main_layout.addWidget(form_frame)
        main_layout.addLayout(right_layout, 1)

    def _create_table(self) -> QTableWidget:
        table = QTableWidget()
        table.setSortingEnabled(True) # Sıralamayı aktif et
        table.setObjectName("TicketTable")

        cols = ["ID", "Müdürlük", "Birim", "Personel", "Tür", "Öncelik", "Tarih", "Açıklama/Çözüm", "İşlemler"]
        table.setColumnCount(len(cols))
        table.setHorizontalHeaderLabels(cols)
        table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeToContents) # ID
        table.setColumnHidden(0, True) # ID'yi Gizle
        table.setColumnWidth(8, 70) # İşlemler
        table.setSelectionBehavior(QTableWidget.SelectRows)
        table.setEditTriggers(QTableWidget.NoEditTriggers)
        table.verticalHeader().setDefaultSectionSize(45) # Yüksekliği artır
        return table

    # ── Filtre dropdown'ları ────────────────────────────────────────────────
    def refresh_dropdowns(self):
        """Form + filtre combo'larını DB'den yeniler."""
        # Form combo (kayıt eklemek için)
        self.cmb_dept.blockSignals(True)
        self.cmb_dept.clear()
        self.cmb_dept.addItem("— Müdürlük Seçin —", userData=None)
        rows = self.db.fetch_data("SELECT id, name FROM departments ORDER BY name")
        for row in rows:
            d = dict(row)
            self.cmb_dept.addItem(d['name'], userData=d['id'])
        self.cmb_dept.blockSignals(False)
        self._on_dept_changed()

        # Filtre combo'ları
        cur_dept = self.cmb_filter_dept.currentData()
        self.cmb_filter_dept.blockSignals(True)
        self.cmb_filter_dept.clear()
        self.cmb_filter_dept.addItem("Tüm Müdürlükler", userData=None)
        for row in rows:
            d = dict(row)
            self.cmb_filter_dept.addItem(d['name'], userData=d['id'])
        # Önceki seçimi koru
        if cur_dept:
            idx = self.cmb_filter_dept.findData(cur_dept)
            if idx >= 0:
                self.cmb_filter_dept.setCurrentIndex(idx)
        self.cmb_filter_dept.blockSignals(False)
        self._on_filter_dept_changed()

    def _on_filter_dept_changed(self):
        dept_id = self.cmb_filter_dept.currentData()
        self.cmb_filter_unit.blockSignals(True)
        self.cmb_filter_unit.clear()
        self.cmb_filter_unit.addItem("Tüm Birimler", userData=None)
        if dept_id:
            rows = self.db.fetch_data(
                "SELECT id, name FROM units WHERE department_id=? ORDER BY name", (dept_id,)
            )
            for row in rows:
                d = dict(row)
                self.cmb_filter_unit.addItem(d['name'], userData=d['id'])
        self.cmb_filter_unit.blockSignals(False)
        self.load_tickets()

    def _on_dept_changed(self):
        dept_id = self.cmb_dept.currentData()
        self.cmb_unit.clear()
        self.cmb_unit.addItem("— Birim Seçin —", userData=None)
        if dept_id is None:
            return
        rows = self.db.fetch_data(
            "SELECT id, name FROM units WHERE department_id=? ORDER BY name", (dept_id,)
        )
        for row in rows:
            d = dict(row)
            self.cmb_unit.addItem(d['name'], userData=d['id'])

    # ── Tablo yükleme ────────────────────────────────────────────────────
    def load_tickets(self):
        self.table_active.setSortingEnabled(False)
        self.table_archive.setSortingEnabled(False)
        self.table_active.setRowCount(0)
        self.table_archive.setRowCount(0)



        # Filtre değerlerini oku
        dept_id  = getattr(self, 'cmb_filter_dept', None)
        dept_id  = dept_id.currentData()  if dept_id  else None
        unit_id  = getattr(self, 'cmb_filter_unit', None)
        unit_id  = unit_id.currentData()  if unit_id  else None
        search   = getattr(self, 'inp_search', None)
        search   = search.text().strip().lower() if search else ''

        where_parts, params = [], []
        if dept_id:
            where_parts.append("t.department_id = ?"); params.append(dept_id)
        if unit_id:
            where_parts.append("t.unit_id = ?");       params.append(unit_id)
        where = ("WHERE " + " AND ".join(where_parts)) if where_parts else ""

        rows = self.db.fetch_data(f"""
            SELECT t.*, COALESCE(d.name, t.department, '—') AS dept_name,
                   COALESCE(u.name, '—') AS unit_name
            FROM tickets t
            LEFT JOIN departments d ON d.id = t.department_id
            LEFT JOIN units u ON u.id = t.unit_id
            {where} ORDER BY t.id DESC
        """, tuple(params))


        PRIORITY_COLORS = {"Acil": "#f38ba8", "Yüksek": "#fab387",
                           "Normal": "#a6e3a1", "Düşük": "#89b4fa"}

        for row_data in rows:
            data = dict(row_data)
            is_closed = data.get("status") == "Kapalı"
            target = self.table_archive if is_closed else self.table_active
            r = target.rowCount()
            target.insertRow(r)

            i_id = IPTableWidgetItem(str(data.get('id', '')))
            i_dept = IPTableWidgetItem(data.get('dept_name', '—'))
            i_unit = IPTableWidgetItem(data.get('unit_name', '—'))
            i_person = IPTableWidgetItem(data.get('personnel_name', ''))
            i_type = IPTableWidgetItem(data.get('issue_type', ''))
            i_prio = IPTableWidgetItem(data.get('priority', ''))
            i_date = IPTableWidgetItem(data.get('date', '')[:10] if data.get('date') else "")
            i_desc = IPTableWidgetItem((data.get('description', '') or "")[:60])

            items = [i_id, i_dept, i_unit, i_person, i_type, i_prio, i_date, i_desc]
            for ci, item in enumerate(items):
                item.setFlags(item.flags() ^ Qt.ItemIsEditable)
                if ci == 5:
                    # 'item.text()' kullanarak renk tespiti yapıyoruz
                    item.setForeground(
                        __import__('PySide6.QtGui', fromlist=['QColor']).QColor(
                            PRIORITY_COLORS.get(item.text(), "#cdd6f4")
                        )
                    )
                target.setItem(r, ci, item)


            # Aksiyon butonları — ikon tabanlı, sığması için sabit boyut
            act = QWidget()
            act_lay = QHBoxLayout(act)
            act_lay.setContentsMargins(2, 1, 2, 1)
            act_lay.setSpacing(3)

            _btn_style = PremiumStyles.TABLE_ACTION_STYLE

            if not is_closed:
                btn_close = QPushButton("✅")
                btn_close.setToolTip("Arızayı Kapat")
                btn_close.setStyleSheet(_btn_style.format(bg="#a6e3a1", hover="#94d3a2"))
                btn_close.setCursor(Qt.PointingHandCursor)
                btn_close.clicked.connect(
                    lambda _, tid=data['id'], desc=data.get('description', ''):
                    self.close_ticket(tid, desc)
                )
                act_lay.addWidget(btn_close)

            btn_edit = QPushButton("✏️")
            btn_edit.setToolTip("Kaydı Düzenle")
            btn_edit.setStyleSheet(_btn_style.format(bg="#89b4fa", hover="#7aa2e8"))
            btn_edit.setCursor(Qt.PointingHandCursor)
            btn_edit.clicked.connect(lambda _, d=data: self.start_edit(d))
            act_lay.addWidget(btn_edit)

            btn_del = QPushButton("🗑")
            btn_del.setToolTip("Kaydı Sil")
            btn_del.setStyleSheet(_btn_style.format(bg="#f38ba8", hover="#e07090"))
            btn_del.setCursor(Qt.PointingHandCursor)
            btn_del.clicked.connect(lambda _, tid=data['id']: self.delete_ticket(tid))
            act_lay.addWidget(btn_del)

            act_lay.addStretch()
            target.setCellWidget(r, 8, act)

            target.setCellWidget(r, 8, act)

        self.table_active.setSortingEnabled(True)
        self.table_archive.setSortingEnabled(True)




    # ── Düzenleme ────────────────────────────────────────────────────────
    def start_edit(self, data):
        self.editing_id = data['id']

        # Müdürlük set
        dept_id = data.get('department_id')
        if dept_id:
            idx = self.cmb_dept.findData(dept_id)
            if idx >= 0:
                self.cmb_dept.setCurrentIndex(idx)
        self._on_dept_changed()

        # Birim set
        unit_id = data.get('unit_id')
        if unit_id:
            idx = self.cmb_unit.findData(unit_id)
            if idx >= 0:
                self.cmb_unit.setCurrentIndex(idx)

        self.inp_person.setText(data.get('personnel_name', ''))
        self.inp_intern.setText(str(data.get('internal_number', '')))

        idx_type = self.issue_type.findText(data.get('issue_type', ''))
        if idx_type >= 0:
            self.issue_type.setCurrentIndex(idx_type)

        idx_prio = self.priority.findText(data.get('priority', ''))
        if idx_prio >= 0:
            self.priority.setCurrentIndex(idx_prio)

        self.description.setPlainText(data.get('description', ''))

        self.btn_save.setText("✏️  Kaydı Güncelle")
        self.btn_save.setStyleSheet(
            "background-color: #fab387; color: #1e1e2e; font-weight: bold; "
            "border: none; border-radius: 7px; padding: 9px;"
        )
        self.btn_cancel.setVisible(True)

    def cancel_edit(self):
        self.editing_id = None
        self.cmb_dept.setCurrentIndex(0)
        self.cmb_unit.setCurrentIndex(0)
        self.inp_person.clear()
        self.inp_intern.clear()
        self.description.clear()
        self.btn_save.setText("💾  Kaydı Oluştur")
        self.btn_save.setStyleSheet(
            "background-color: #89b4fa; color: #1e1e2e; font-weight: bold; "
            "border: none; border-radius: 7px; padding: 9px;"
        )
        self.btn_cancel.setVisible(False)

    def delete_ticket(self, t_id):
        reply = QMessageBox.question(
            self, 'Silme Onayı',
            'Bu arıza kaydını kalıcı olarak silmek istediğinize emin misiniz?',
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
        if reply == QMessageBox.Yes:
            rec = self.db.fetch_data("SELECT personnel_name, issue_type FROM tickets WHERE id=?", (t_id,))
            if rec:
                r = dict(rec[0])
                write_log(self.db, self.current_user, "SİL",
                          f"Arıza silindi: #{t_id} {r['issue_type']} — {r['personnel_name']}")
            self.db.execute_query("DELETE FROM tickets WHERE id=?", (t_id,))
            self.load_tickets()
            self.data_changed.emit()

    def close_ticket(self, ticket_id, old_desc):
        reply_text, ok = QInputDialog.getText(self, "Arıza Kapat", "Çözüm Açıklaması:")
        if ok and reply_text:
            date_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
            new_desc = f"{old_desc}\n\n[Çözüm - {date_str}]: {reply_text}"
            if self.db.execute_query(
                "UPDATE tickets SET description=?, status='Kapalı' WHERE id=?",
                (new_desc, ticket_id)
            ):
                self.load_tickets()
                self.data_changed.emit()

    # ── Kaydet ───────────────────────────────────────────────────────────
    def save_ticket(self):
        dept_id = self.cmb_dept.currentData()
        unit_id = self.cmb_unit.currentData()
        # Metin fallback (eski kayıtlar + dept tablosu boşken)
        dept_text = self.cmb_dept.currentText() if dept_id else ""
        pers  = self.inp_person.text().strip()
        intern = self.inp_intern.text().strip()
        itype = self.issue_type.currentText()
        prio  = self.priority.currentText()
        desc  = self.description.toPlainText()

        if not pers:
            QMessageBox.warning(self, "Hata", "Personel Adı zorunludur!")
            return

        if self.editing_id:
            query = """UPDATE tickets
                       SET department=?, department_id=?, unit_id=?,
                           personnel_name=?, internal_number=?,
                           issue_type=?, priority=?, description=?
                       WHERE id=?"""
            success = self.db.execute_query(
                query, (dept_text, dept_id, unit_id,
                        pers, intern, itype, prio, desc, self.editing_id)
            )
        else:
            now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            query = """INSERT INTO tickets
                       (department, department_id, unit_id, personnel_name,
                        internal_number, issue_type, priority, description, date, status)
                       VALUES (?,?,?,?,?,?,?,?,?,'Açık')"""
            success = self.db.execute_query(
                query, (dept_text, dept_id, unit_id,
                        pers, intern, itype, prio, desc, now)
            )

        if success:
            write_log(self.db, self.current_user,
                      "GÜNCELLE" if self.editing_id else "EKLE",
                      f"Arıza {'güncellendi' if self.editing_id else 'eklendi'}: {itype} — {pers}")
            self.refresh_dropdowns()
            self.load_tickets()
            self.cancel_edit()
            self.data_changed.emit()
        else:
            QMessageBox.critical(self, "Hata", "Kayıt sırasında hata oluştu.")
