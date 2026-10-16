from PySide6.QtWidgets import QTableWidgetItem, QAbstractButton
from PySide6.QtCore import Qt, QPropertyAnimation, QEasingCurve, QRect, Signal, Property
from PySide6.QtGui import QPainter, QColor, QFont

class IPTableWidgetItem(QTableWidgetItem):
    """IP adreslerini, sayısal değerleri ve metni doğru sıralamak için özel sınıf."""
    def __lt__(self, other):
        try:
            # Önce UserRole içindeki ham veriye bak (Gizli sıralama için), yoksa görünen metni kullan
            t_data = self.data(Qt.UserRole)
            o_data = other.data(Qt.UserRole)
            
            t_text = str(t_data).strip() if t_data is not None else self.text().strip()
            o_text = str(o_data).strip() if o_data is not None else other.text().strip()
            
            # Boş değerleri veya '-' karakterini her zaman en sona at
            if t_text in ['', '-']: return False
            if o_text in ['', '-']: return True

            # 1. IP ADRESI KONTROLÜ
            if (t_text.count('.') == 3 and all(p.isdigit() for p in t_text.split('.') if p)) and \
               (o_text.count('.') == 3 and all(p.isdigit() for p in o_text.split('.') if p)):
                t_parts = [int(p) for p in t_text.split('.')]
                o_parts = [int(p) for p in o_text.split('.')]
                return t_parts < o_parts
            
            # 2. SAYISAL KONTROL (Metin içinde sayı varsa örn: "15 ms")
            import re
            t_nums = re.findall(r'[-+]?\d*\.?\d+', t_text)
            o_nums = re.findall(r'[-+]?\d*\.?\d+', o_text)
            
            if t_nums and o_nums:
                # Sadece ilk sayıları karşılaştır
                return float(t_nums[0]) < float(o_nums[0])
            
            # 3. STANDART METİN (Büyük-küçük harf duyarsız)
            return t_text.lower() < o_text.lower()
        except:
            return super().__lt__(other)


class ModernToggle(QAbstractButton):
    def __init__(self, parent=None, 
                 active_color="#3b82f6", 
                 bg_color="#4b5563", 
                 circle_color="#ffffff",
                 width=38):
        super().__init__(parent)
        self.setCheckable(True)
        self.setCursor(Qt.PointingHandCursor)
        self.setFixedSize(width, 20)
        
        # Colors
        self._active_color = active_color
        self._bg_color = bg_color
        self._circle_color = circle_color
        
        # Animation
        self._circle_position = 2
        self._anim = QPropertyAnimation(self, b"circle_position")
        self._anim.setDuration(200)
        self._anim.setEasingCurve(QEasingCurve.OutCubic)
        
        self.toggled.connect(self.start_transition)

    @Property(float)
    def circle_position(self):
        return self._circle_position

    @circle_position.setter
    def circle_position(self, pos):
        self._circle_position = pos
        self.update()

    def start_transition(self, checked):
        self._anim.stop()
        if checked:
            self._anim.setEndValue(self.width() - self.height() + 2)
        else:
            self._anim.setEndValue(2)
        self._anim.start()

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        p.setPen(Qt.NoPen)
        
        # Draw track
        bg = QColor(self._active_color) if self.isChecked() else QColor(self._bg_color)
        p.setBrush(bg)
        # Professional rounded rect
        p.drawRoundedRect(0, 0, self.width(), self.height(), self.height() / 2, self.height() / 2)
            
        # Draw thumb (smaller and more centered)
        p.setBrush(QColor(self._circle_color))
        margin = 3
        thumb_size = self.height() - (margin * 2)
        p.drawEllipse(self._circle_position, margin, thumb_size, thumb_size)
        p.end()

    def hitButton(self, pos):
        return self.contentsRect().contains(pos)



from PySide6.QtCore import QObject, Signal as QSignal


class GenericWorker(QObject):
    finished = QSignal(object)  # İşlem bittiğinde sonucu gönderir
    error = QSignal(str)       # Hata oluşursa hata mesajını gönderir

    def __init__(self, fn, *args, **kwargs):
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs

    def run(self, *slot_args):
        try:
            # Sinyalden gelen argümanlar (slot_args) ile init sırasında verilen argümanları birleştir
            final_args = self.args + slot_args
            result = self.fn(*final_args, **self.kwargs)
            self.finished.emit(result)
        except Exception as e:
            self.error.emit(str(e))
