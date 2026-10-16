"""
Gelişmiş Rapor Merkezi — reports_page.py

Özellikler:
  • Rapor türü seçimi (Arıza / Envanter / Özet)
  • Müdürlük / Birim filtresi
  • Sürükle-bırak benzeri checkbox tabanlı sütun seçimi
  • Rapor türüne göre sütun listesi değişir
  • Önizleme tablosu
  • PDF / Excel dışa aktarım
"""

import os
import shutil
import datetime
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QFrame,
    QPushButton, QComboBox, QCheckBox, QTableWidget, QTableWidgetItem,
    QHeaderView, QMessageBox, QScrollArea, QGridLayout, QSizePolicy,
    QSpacerItem, QFileDialog
)
from PySide6.QtCore import Qt, QTimer, Signal
from PySide6.QtGui import QFont, QDesktopServices
from database.connection import DatabaseConnection
from .ui_utils import IPTableWidgetItem



# ── Sütun tanımları ──────────────────────────────────────────────────────────
REPORT_COLUMNS = {
    "Arıza Kayıtları": [
        ("id",             "ID"),
        ("dept_name",      "Müdürlük"),
        ("unit_name",      "Birim"),
        ("personnel_name", "Personel"),
        ("issue_type",     "Arıza Türü"),
        ("priority",       "Öncelik"),
        ("status",         "Durum"),
        ("date",           "Tarih"),
        ("description",    "Açıklama"),
    ],
    "Donanım Envanteri": [
        ("id",         "ID"),
        ("dept_name",  "Müdürlük"),
        ("unit_name",  "Birim"),
        ("user_name",  "Personel"),
        ("brand",      "Marka"),
        ("model",      "Model"),
        ("serial_no",  "Seri No"),
        ("ip_address", "IP Adresi"),
        ("date",       "Tarih"),
    ],
    "Özet İstatistikler": [
        ("dept_name",        "Müdürlük"),
        ("unit_name",        "Birim"),
        ("toplam_ariza",     "Toplam Arıza"),
        ("acik_ariza",       "Açık Arıza"),
        ("kapali_ariza",     "Kapalı Arıza"),
        ("toplam_envanter",  "Toplam Cihaz"),
    ],
}

DEFAULT_COLUMNS = {
    "Arıza Kayıtları":      {"dept_name", "unit_name", "personnel_name", "issue_type", "priority", "status", "date"},
    "Donanım Envanteri":    {"dept_name", "unit_name", "user_name", "brand", "model", "ip_address"},
    "Özet İstatistikler":   {"dept_name", "unit_name", "toplam_ariza", "acik_ariza", "toplam_envanter"},
}


class ReportsPage(QWidget):
    def __init__(self, db_conn: DatabaseConnection):
        super().__init__()
        self.setObjectName("ReportsPage")
        self.db = db_conn
        self._preview_data: list[dict] = []
        self._preview_cols: list[tuple] = []
        self._setup_ui()
        self._refresh_filters()
        self._on_report_type_changed()

        self._on_report_type_changed()

    # ── UI Kurulumu ──────────────────────────────────────────────────────
    def _setup_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(28, 24, 28, 24)
        root.setSpacing(16)

        # Başlık
        title = QLabel("Rapor Merkezi")
        title.setFont(QFont("Segoe UI", 12, QFont.Bold))
        title.setStyleSheet("color: #6c7086; margin-bottom: 5px;")
        root.addWidget(title)

        # ── ÜST KONTROLLER ──────────────────────────────────────────────
        ctrl_frame = QFrame()
        ctrl_frame.setObjectName("ReportCtrlFrame")
        ctrl_frame.setStyleSheet("QFrame#ReportCtrlFrame { border-radius: 12px; }")
        ctrl_lay = QHBoxLayout(ctrl_frame)
        ctrl_lay.setContentsMargins(16, 14, 16, 14)
        ctrl_lay.setSpacing(16)
        root.addWidget(ctrl_frame)

        def _lbl(t):
            l = QLabel(t)
            l.setObjectName("SecondaryLabel")
            return l


        # Rapor Türü
        col_type = QVBoxLayout()
        col_type.addWidget(_lbl("RAPOR TÜRÜ"))
        self.cmb_type = QComboBox()
        self.cmb_type.setObjectName("ReportTypeCombo")
        self.cmb_type.addItems(list(REPORT_COLUMNS.keys()))
        self.cmb_type.currentTextChanged.connect(self._on_report_type_changed)
        col_type.addWidget(self.cmb_type)
        ctrl_lay.addLayout(col_type)

        # Müdürlük
        col_dept = QVBoxLayout()
        col_dept.addWidget(_lbl("MÜDÜRLÜK"))
        self.cmb_dept = QComboBox()
        self.cmb_dept.setObjectName("ReportDeptCombo")
        self.cmb_dept.currentIndexChanged.connect(self._on_dept_changed)
        col_dept.addWidget(self.cmb_dept)
        ctrl_lay.addLayout(col_dept)

        # Birim
        col_unit = QVBoxLayout()
        col_unit.addWidget(_lbl("BİRİM"))
        self.cmb_unit = QComboBox()
        self.cmb_unit.setObjectName("ReportUnitCombo")
        col_unit.addWidget(self.cmb_unit)
        ctrl_lay.addLayout(col_unit)

        ctrl_lay.addStretch()

        # Ön izle butonu
        btn_preview = QPushButton("🔍  Önizle")
        btn_preview.setObjectName("ReportPreviewBtn")
        btn_preview.setCursor(Qt.PointingHandCursor)
        btn_preview.setFixedHeight(38)
        btn_preview.setStyleSheet(
            "background-color: #89b4fa; color: #1e1e2e; font-weight: bold; "
            "border: none; border-radius: 7px; padding: 0 20px;"
        )
        btn_preview.clicked.connect(self._preview)
        ctrl_lay.addWidget(btn_preview)

        self.btn_manual_refresh = QPushButton("🔄")
        self.btn_manual_refresh.setFixedWidth(38)
        self.btn_manual_refresh.setFixedHeight(38)
        self.btn_manual_refresh.setCursor(Qt.PointingHandCursor)
        self.btn_manual_refresh.setToolTip("Dropdownları Yenile")
        self.btn_manual_refresh.setStyleSheet("""
            QPushButton { background-color: #313244; color: #89dceb; border: 1px solid #45475a; border-radius: 7px; font-size: 14px; }
            QPushButton:hover { background-color: #45475a; }
        """)
        self.btn_manual_refresh.clicked.connect(self._refresh_filters)
        ctrl_lay.addWidget(self.btn_manual_refresh)

        # ── SÜTUN SEÇİCİ ────────────────────────────────────────────────
        col_frame = QFrame()
        col_frame.setObjectName("ReportColFrame")
        col_frame.setStyleSheet("QFrame#ReportColFrame { border-radius: 10px; }")
        col_outer = QVBoxLayout(col_frame)
        col_outer.setContentsMargins(16, 12, 16, 12)
        col_outer.setSpacing(8)

        col_header_row = QHBoxLayout()
        lbl_col = QLabel("📋  Rapor Sütunları")
        lbl_col.setStyleSheet("color: #cdd6f4; font-size: 13px; font-weight: 600;")
        btn_all = QPushButton("Tümünü Seç")
        btn_none = QPushButton("Temizle")
        for b in [btn_all, btn_none]:
            b.setCursor(Qt.PointingHandCursor)
            b.setStyleSheet(
                "background-color: transparent; color: #89b4fa; border: 1px solid #89b4fa55; "
                "border-radius: 5px; padding: 3px 10px; font-size: 11px;"
            )
        btn_all.clicked.connect(lambda: self._check_all(True))
        btn_none.clicked.connect(lambda: self._check_all(False))
        col_header_row.addWidget(lbl_col)
        col_header_row.addStretch()
        col_header_row.addWidget(btn_all)
        col_header_row.addWidget(btn_none)
        col_outer.addLayout(col_header_row)

        # Checkbox alanı
        self.col_checkbox_area = QHBoxLayout()
        self.col_checkbox_area.setSpacing(6)
        col_outer.addLayout(self.col_checkbox_area)
        self._col_checkboxes: list[tuple[str, str, QCheckBox]] = []

        root.addWidget(col_frame)

        # ── DIŞA AKTARMA BUTONLARI ───────────────────────────────────────
        export_row = QHBoxLayout()
        export_row.setSpacing(10)

        for label, color, fmt in [
            ("📄  PDF Olarak İndir",   "#f38ba8", "pdf"),
            ("📊  Excel Olarak İndir", "#a6e3a1", "excel"),
        ]:
            btn = QPushButton(label)
            btn.setCursor(Qt.PointingHandCursor)
            btn.setFixedHeight(38)
            btn.setStyleSheet(
                f"background-color: {color}; color: #1e1e2e; font-weight: bold; "
                "border: none; border-radius: 7px; padding: 0 20px;"
            )
            btn.clicked.connect(lambda _, f=fmt: self._export(f))
            export_row.addWidget(btn)

        btn_clear = QPushButton("🗑️  Verileri Sıfırla")
        btn_clear.setCursor(Qt.PointingHandCursor)
        btn_clear.setFixedHeight(38)
        btn_clear.setToolTip("Tüm arıza ve envanter kayıtlarını siler (Yedek Alınır)")
        btn_clear.setStyleSheet("""
            QPushButton { 
                background-color: transparent; color: #f38ba8; border: 1px solid #f38ba866; 
                border-radius: 7px; padding: 0 16px; font-weight: bold;
            }
            QPushButton:hover { background-color: #f38ba811; border-color: #f38ba8; }
        """)
        btn_clear.clicked.connect(self._clear_all_with_backup)
        export_row.addWidget(btn_clear)

        export_row.addStretch()

        self.lbl_status = QLabel("")
        self.lbl_status.setStyleSheet("color: #a6e3a1; font-size: 12px;")
        export_row.addWidget(self.lbl_status)
        root.addLayout(export_row)

        # ── ÖNİZLEME TABLOSU ────────────────────────────────────────────
        self.table = QTableWidget(0, 1)
        self.table.setSortingEnabled(True) # Sıralamayı aktif et
        self.table.setObjectName("ReportTable")

        self.table.setHorizontalHeaderLabels(["—"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table.setSelectionBehavior(QTableWidget.SelectRows)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.table.verticalHeader().setDefaultSectionSize(36)
        root.addWidget(self.table)

    # ── Filtre yenileme ──────────────────────────────────────────────────
    def _refresh_filters(self):
        self.cmb_dept.blockSignals(True)
        self.cmb_dept.clear()
        self.cmb_dept.addItem("Tüm Müdürlükler", userData=None)
        for r in self.db.fetch_data("SELECT id, name FROM departments ORDER BY name"):
            d = dict(r)
            self.cmb_dept.addItem(d['name'], userData=d['id'])
        self.cmb_dept.blockSignals(False)
        self._on_dept_changed()

    def _on_dept_changed(self):
        dept_id = self.cmb_dept.currentData()
        self.cmb_unit.clear()
        self.cmb_unit.addItem("Tüm Birimler", userData=None)
        if dept_id:
            for r in self.db.fetch_data(
                "SELECT id, name FROM units WHERE department_id=? ORDER BY name", (dept_id,)
            ):
                d = dict(r)
                self.cmb_unit.addItem(d['name'], userData=d['id'])

    # ── Rapor türü değişince sütunları güncelle ──────────────────────────
    def _on_report_type_changed(self):
        rtype = self.cmb_type.currentText()
        # Eski checkbox'ları temizle
        self._col_checkboxes.clear()
        while self.col_checkbox_area.count():
            item = self.col_checkbox_area.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        cols = REPORT_COLUMNS.get(rtype, [])
        defaults = DEFAULT_COLUMNS.get(rtype, set())

        for key, label in cols:
            cb = QCheckBox(label)
            cb.setObjectName(f"ColCB_{key}")
            cb.setChecked(key in defaults)
            cb.setStyleSheet("spacing: 4px; font-size: 12px;")
            self.col_checkbox_area.addWidget(cb)
            self._col_checkboxes.append((key, label, cb))

        self.col_checkbox_area.addStretch()
        # Önizlemeyi sıfırla
        self.table.setRowCount(0)
        self.table.setColumnCount(1)
        self.table.setHorizontalHeaderLabels(["← Filtre seçip 'Önizle' butonuna basın"])

    def _check_all(self, state: bool):
        for _, _, cb in self._col_checkboxes:
            cb.setChecked(state)

    # ── Veri çekme ───────────────────────────────────────────────────────
    def _fetch_data(self, rtype: str, dept_id, unit_id) -> list[dict]:
        params = []
        where_parts = []

        if dept_id:
            where_parts.append("i.department_id = ?" if "Envanter" in rtype else "t.department_id = ?")
            params.append(dept_id)
        if unit_id:
            where_parts.append("i.unit_id = ?" if "Envanter" in rtype else "t.unit_id = ?")
            params.append(unit_id)

        where = ("WHERE " + " AND ".join(where_parts)) if where_parts else ""

        if rtype == "Arıza Kayıtları":
            q = f"""
                SELECT t.*, COALESCE(d.name,'—') AS dept_name, COALESCE(u.name,'—') AS unit_name
                FROM tickets t
                LEFT JOIN departments d ON d.id=t.department_id
                LEFT JOIN units u ON u.id=t.unit_id
                {where} ORDER BY t.id DESC
            """
        elif rtype == "Donanım Envanteri":
            q = f"""
                SELECT i.*, COALESCE(d.name,'—') AS dept_name, COALESCE(u.name,'—') AS unit_name
                FROM inventory i
                LEFT JOIN departments d ON d.id=i.department_id
                LEFT JOIN units u ON u.id=i.unit_id
                {where} ORDER BY i.id DESC
            """
        else:  # Özet
            if dept_id:
                group_q = f"""
                    SELECT COALESCE(d.name,'—') AS dept_name, COALESCE(u.name,'—') AS unit_name,
                           COUNT(DISTINCT CASE WHEN t.id IS NOT NULL THEN t.id END) AS toplam_ariza,
                           COUNT(DISTINCT CASE WHEN t.status='Açık' THEN t.id END) AS acik_ariza,
                           COUNT(DISTINCT CASE WHEN t.status='Kapalı' THEN t.id END) AS kapali_ariza,
                           COUNT(DISTINCT inv.id) AS toplam_envanter
                    FROM departments d
                    LEFT JOIN units u ON u.department_id=d.id
                    LEFT JOIN tickets t ON t.department_id=d.id AND (? IS NULL OR t.unit_id=?)
                    LEFT JOIN inventory inv ON inv.department_id=d.id AND (? IS NULL OR inv.unit_id=?)
                    WHERE d.id=?
                    GROUP BY d.id, u.id ORDER BY d.name, u.name
                """
                params_oz = [unit_id, unit_id, unit_id, unit_id, dept_id]
            else:
                group_q = """
                    SELECT COALESCE(d.name,'—') AS dept_name, '—' AS unit_name,
                           COUNT(DISTINCT t.id) AS toplam_ariza,
                           COUNT(DISTINCT CASE WHEN t.status='Açık' THEN t.id END) AS acik_ariza,
                           COUNT(DISTINCT CASE WHEN t.status='Kapalı' THEN t.id END) AS kapali_ariza,
                           COUNT(DISTINCT inv.id) AS toplam_envanter
                    FROM departments d
                    LEFT JOIN tickets t ON t.department_id=d.id
                    LEFT JOIN inventory inv ON inv.department_id=d.id
                    GROUP BY d.id ORDER BY d.name
                """
                params_oz = []
            return [dict(r) for r in self.db.fetch_data(group_q, tuple(params_oz))]

        return [dict(r) for r in self.db.fetch_data(q, tuple(params))]

    # ── Önizle ───────────────────────────────────────────────────────────
    def _preview(self):
        rtype   = self.cmb_type.currentText()
        dept_id = self.cmb_dept.currentData()
        unit_id = self.cmb_unit.currentData()

        selected_cols = [(k, l) for k, l, cb in self._col_checkboxes if cb.isChecked()]
        if not selected_cols:
            QMessageBox.warning(self, "Uyarı", "En az bir sütun seçin.")
            return

        try:
            data = self._fetch_data(rtype, dept_id, unit_id)
        except Exception as e:
            QMessageBox.critical(self, "Hata", f"Veri çekilemedi: {e}")
            return

        self._preview_data = data
        self._preview_cols = selected_cols

        self.table.setSortingEnabled(False)
        self.table.setRowCount(0)
        self.table.setColumnCount(len(selected_cols))
        self.table.setHorizontalHeaderLabels([l for _, l in selected_cols])


        for row in data:
            r = self.table.rowCount()
            self.table.insertRow(r)
            for ci, (key, _) in enumerate(selected_cols):
                val = str(row.get(key, "") or "")
                item = IPTableWidgetItem(val)
                item.setFlags(item.flags() ^ Qt.ItemIsEditable)
                self.table.setItem(r, ci, item)

        # ID sütununu gizle (eğer seçiliyse ve 0. sütunsa)
        if selected_cols and selected_cols[0][0] == "id":
             self.table.setColumnHidden(0, True)
        else:
             self.table.setColumnHidden(0, False) # Diğer durumlarda göster

        self.table.setSortingEnabled(True)


        self.lbl_status.setText(f"✅ {len(data)} kayıt listelendi.")

    # ── Dışa Aktarım ─────────────────────────────────────────────────────
    def _export(self, fmt: str):
        # Önizleme yapılmamışsa otomatik çalıştır
        if not self._preview_data:
            self._preview()
        if not self._preview_data:
            return

        rtype = self.cmb_type.currentText()
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M")
        safe = rtype.replace(" ", "_").replace("/", "-")
        default_name = f"Rapor_{safe}_{ts}.{'pdf' if fmt == 'pdf' else 'xlsx'}"
        default_dir = os.path.join(os.path.expanduser("~"), "Desktop")

        if fmt == "pdf":
            file_filter = "PDF Dosyası (*.pdf)"
        else:
            file_filter = "Excel Dosyası (*.xlsx)"

        out, _ = QFileDialog.getSaveFileName(
            self, "Raporu Kaydet",
            os.path.join(default_dir, default_name),
            file_filter
        )
        if not out:   # Kullanıcı iptal etti
            return

        try:
            if fmt == "pdf":
                self._export_pdf(out, rtype)
            else:
                self._export_excel(out, rtype)
            self.lbl_status.setText(f"✅ Kaydedildi: {os.path.basename(out)}")
            self.lbl_status.setStyleSheet("color: #a6e3a1; font-size: 12px;")
        except Exception as e:
            self.lbl_status.setText(f"⚠️ Hata: {e}")
            self.lbl_status.setStyleSheet("color: #f38ba8; font-size: 12px;")

    def _export_pdf(self, path: str, title: str):
        from reportlab.lib.pagesizes import A4, landscape
        from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
        from reportlab.lib import colors
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.pdfbase import pdfmetrics
        from reportlab.pdfbase.ttfonts import TTFont

        # Türkçe karakter desteği için DejaVuSans (veya Arial Unicode) dene
        BODY_FONT  = "Helvetica"
        BOLD_FONT  = "Helvetica-Bold"
        _font_registered = False

        # Windows sistem fontlarında Türkçe destekleyen fontları ara
        _candidates = [
            ("C:/Windows/Fonts/DejaVuSans.ttf",       "DejaVuSans"),
            ("C:/Windows/Fonts/DejaVuSans-Bold.ttf",  "DejaVuSans-Bold"),
            ("C:/Windows/Fonts/arial.ttf",            "ArialTR"),
            ("C:/Windows/Fonts/arialbd.ttf",          "ArialTR-Bold"),
            ("C:/Windows/Fonts/calibri.ttf",          "Calibri"),
            ("C:/Windows/Fonts/calibrib.ttf",         "Calibri-Bold"),
        ]
        import os as _os
        for fpath, fname in _candidates[:2]:          # önce DejaVu dene
            if _os.path.exists(fpath):
                try:
                    pdfmetrics.registerFont(TTFont(fname, fpath))
                    _font_registered = True
                except Exception:
                    pass
        if _font_registered:
            BODY_FONT = "DejaVuSans"
            BOLD_FONT = "DejaVuSans-Bold"
        else:
            # DejaVu yok, Arial dene
            for fpath, fname in _candidates[2:4]:
                if _os.path.exists(fpath):
                    try:
                        pdfmetrics.registerFont(TTFont(fname, fpath))
                        _font_registered = True
                    except Exception:
                        pass
            if _font_registered:
                BODY_FONT = "ArialTR"
                BOLD_FONT = "ArialTR-Bold"
            else:
                # Calibri dene
                for fpath, fname in _candidates[4:6]:
                    if _os.path.exists(fpath):
                        try:
                            pdfmetrics.registerFont(TTFont(fname, fpath))
                            _font_registered = True
                        except Exception:
                            pass
                if _font_registered:
                    BODY_FONT = "Calibri"
                    BOLD_FONT = "Calibri-Bold"

        # Türkçe karakterleri güvenle encode et
        def safe(text):
            if not isinstance(text, str):
                text = str(text) if text else ""
            return text

        doc = SimpleDocTemplate(path, pagesize=landscape(A4),
                                leftMargin=20, rightMargin=20,
                                topMargin=20, bottomMargin=20)
        styles = getSampleStyleSheet()
        title_style = ParagraphStyle(
            "TRTitle", parent=styles["Title"],
            fontName=BOLD_FONT, fontSize=14, spaceAfter=4
        )
        normal_style = ParagraphStyle(
            "TRNormal", parent=styles["Normal"],
            fontName=BODY_FONT, fontSize=9
        )
        elements = [
            Paragraph(safe(f"{title} Raporu"), title_style),
            Paragraph(safe(f"Oluşturma: {datetime.datetime.now().strftime('%d.%m.%Y %H:%M')}"), normal_style),
            Spacer(1, 10),
        ]

        headers = [safe(l) for _, l in self._preview_cols]
        table_data = [headers]
        for row in self._preview_data:
            table_data.append([safe(row.get(k, "") or "") for k, _ in self._preview_cols])

        t = Table(table_data, repeatRows=1)
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1e66f5')),
            ('TEXTCOLOR',  (0, 0), (-1, 0), colors.white),
            ('FONTNAME',   (0, 0), (-1, 0), BOLD_FONT),
            ('FONTSIZE',   (0, 0), (-1, 0), 9),
            ('FONTNAME',   (0, 1), (-1, -1), BODY_FONT),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f2f2f2')]),
            ('FONTSIZE',   (0, 1), (-1, -1), 8),
            ('GRID',       (0, 0), (-1, -1), 0.5, colors.lightgrey),
            ('ALIGN',      (0, 0), (-1, -1), 'LEFT'),
            ('VALIGN',     (0, 0), (-1, -1), 'MIDDLE'),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ]))
        elements.append(t)
        doc.build(elements)


    def _export_excel(self, path: str, title: str):
        import openpyxl
        from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = title[:31]

        # Başlık satırı
        headers = [l for _, l in self._preview_cols]
        ws.append(headers)
        hdr_fill = PatternFill("solid", fgColor="1e66f5")
        hdr_font = Font(bold=True, color="FFFFFF")
        for cell in ws[1]:
            cell.fill = hdr_fill
            cell.font = hdr_font
            cell.alignment = Alignment(horizontal='center')

        # Veri satırları
        fill_alt = PatternFill("solid", fgColor="EEF1F5")
        for i, row in enumerate(self._preview_data):
            vals = [str(row.get(k, "") or "") for k, _ in self._preview_cols]
            ws.append(vals)
            if i % 2 == 1:
                for cell in ws[i + 2]:
                    cell.fill = fill_alt

        # Sütun genişliği otomatik
        for col in ws.columns:
            max_len = max((len(str(c.value or "")) for c in col), default=8)
            ws.column_dimensions[col[0].column_letter].width = min(max_len + 4, 40)

        wb.save(path)

    # ── Veri Temizleme & Yedekleme ───────────────────────────────────────
    def _clear_all_with_backup(self):
        """Tüm kayıtları yedek alarak siler."""
        confirm = QMessageBox.question(
            self, "Verileri Sıfırla",
            "Sistemdeki TÜM arıza kayıtlarını ve envanter listesini silmek istediğinize emin misiniz?\n\n"
            "NOT: İşlemden önce gizli bir yedek alınacaktır.",
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
        if confirm != QMessageBox.Yes:
            return

        # İkinci onay
        confirm2 = QMessageBox.warning(
            self, "KRİTİK ONAY",
            "BU İŞLEM GERİ ALINAMAZ!\n\nDevam etmek istiyor musunuz?",
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
        if confirm2 != QMessageBox.Yes:
            return

        try:
            # 1. Yedekleme
            backup_dir = "backups"
            if not os.path.exists(backup_dir):
                os.makedirs(backup_dir)
            
            ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            db_name = self.db.db_string
            backup_path = os.path.join(backup_dir, f"Sentinel_Yedek_{ts}.db")
            
            # Veritabanı dosyasının mutlak yolunu bul (frozen/normal ayrımı)
            import sys
            base_dir = os.path.dirname(sys.executable) if getattr(sys, 'frozen', False) else os.getcwd()
            source_path = os.path.join(base_dir, db_name)
            
            shutil.copy2(source_path, backup_path)

            # 2. Temizleme
            self.db.execute_query("DELETE FROM tickets")
            self.db.execute_query("DELETE FROM inventory")
            self.db.execute_query("VACUUM")
            
            self._preview_data = []
            self.table.setRowCount(0)
            self.lbl_status.setText(f"✅ Başarılı! Veriler temizlendi. Yedek: {backup_path}")
            self.lbl_status.setStyleSheet("color: #a6e3a1; font-size: 11px;")
            
            QMessageBox.information(
                self, "İşlem Başarılı",
                f"Tüm veriler temizlendi.\n\nYedek oluşturuldu:\n{backup_path}"
            )
            
        except Exception as e:
            QMessageBox.critical(self, "Hata", f"Sıfırlama sırasında hata oluştu:\n{e}")

