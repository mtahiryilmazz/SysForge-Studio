import pandas as pd
from database.connection import DatabaseConnection

class ReportsModule:
    def __init__(self, db: DatabaseConnection):
        self.db = db

    def export_tickets_to_excel(self, file_path):
        query = "SELECT * FROM tickets ORDER BY id DESC"
        data = self.db.fetch_data(query)
        df = pd.DataFrame([dict(row) for row in data])
        df.to_excel(file_path, index=False)
        return True

    def export_inventory_to_excel(self, file_path):
        query = "SELECT * FROM inventory ORDER BY id DESC"
        data = self.db.fetch_data(query)
        df = pd.DataFrame([dict(row) for row in data])
        df.to_excel(file_path, index=False)
        return True

    def _generate_pdf(self, title, data_list, file_path):
        from reportlab.lib.pagesizes import A4, landscape
        from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
        from reportlab.lib.styles import getSampleStyleSheet
        from reportlab.lib import colors

        doc = SimpleDocTemplate(file_path, pagesize=landscape(A4))
        elements = []
        styles = getSampleStyleSheet()
        
        elements.append(Paragraph(title, styles['Title']))
        elements.append(Spacer(1, 12))
        
        if not data_list:
            elements.append(Paragraph("Veri bulunamadı.", styles['Normal']))
            doc.build(elements)
            return True

        # Extract headers from first item dict keys
        headers = list(data_list[0].keys())
        table_data = [headers]
        
        # Extract rows
        for row in data_list:
            table_data.append([str(row.get(h, "")) for h in headers])

        t = Table(table_data)
        t.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), colors.grey),
            ('TEXTCOLOR', (0,0), (-1,0), colors.whitesmoke),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
            ('BOTTOMPADDING', (0,0), (-1,0), 12),
            ('BACKGROUND', (0,1), (-1,-1), colors.beige),
            ('GRID', (0,0), (-1,-1), 1, colors.black),
            ('FONTSIZE', (0,0), (-1,-1), 8),
        ]))
        
        elements.append(t)
        doc.build(elements)
        return True

    def export_tickets_to_pdf(self, file_path):
        query = "SELECT id, title, status, priority, created_at, closed_at FROM tickets ORDER BY id DESC LIMIT 100"
        data = self.db.fetch_data(query)
        return self._generate_pdf("Ariza Kayitlari Raporu", [dict(row) for row in data], file_path)

    def export_inventory_to_pdf(self, file_path):
        query = "SELECT id, ip_adresi, cihaz_adi, tip, marka, model, eklendigi_tarih FROM inventory ORDER BY id DESC LIMIT 100"
        data = self.db.fetch_data(query)
        return self._generate_pdf("Donanim Envanteri Raporu", [dict(row) for row in data], file_path)
