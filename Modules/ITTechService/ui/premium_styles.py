from PySide6.QtWidgets import QFrame, QPushButton, QLabel, QTextEdit
from PySide6.QtGui import QColor, QFont, QPalette
from PySide6.QtCore import Qt

class PremiumStyles:
    THEMES = {
        "dark": {
            "bg": "#0f172a",
            "surface": "#1e293b",
            "primary": "#3b82f6",
            "hover": "#2563eb",
            "text": "#f8fafc",
            "muted": "#94a3b8",
            "sidebar": "#181825",
            "border": "#313244",
            "log_bg": "rgba(0, 0, 0, 0.2)"
        },
        "light": {
            "bg": "#f8fafc",
            "surface": "#ffffff",
            "primary": "#2563eb",
            "hover": "#1d4ed8",
            "text": "#0f172a",
            "muted": "#64748b",
            "sidebar": "#f1f5f9",
            "border": "#e2e8f0",
            "log_bg": "rgba(255, 255, 255, 0.8)"
        }
    }

    CURRENT_THEME = "dark"

    @classmethod
    def get_theme(cls):
        return cls.THEMES[cls.CURRENT_THEME]

    @classmethod
    def update_theme(cls, theme_name):
        if theme_name in cls.THEMES:
            cls.CURRENT_THEME = theme_name

    # ── Stylesheets (Dynamic) ──────────────────────────────────────────────────
    @classmethod
    def get_main_style(cls):
        t = cls.get_theme()
        return f"QMainWindow {{ background-color: {t['bg']}; }}"

    @classmethod
    def get_sidebar_style(cls):
        t = cls.get_theme()
        return f"""
            QFrame#Sidebar {{
                background-color: {t['sidebar']};
                border-right: 1px solid {t['border']};
            }}
            QPushButton {{
                background: transparent;
                color: {t['muted']};
                border: none;
                padding: 12px 20px;
                text-align: left;
                font-size: 13px;
                font-weight: 600;
                border-radius: 6px;
                margin: 2px 10px;
            }}
            QPushButton:hover {{
                background-color: {"rgba(0, 0, 0, 0.05)" if cls.CURRENT_THEME == "light" else "rgba(255, 255, 255, 0.05)"};
                color: {t['text']};
            }}
            QPushButton#ActiveNav, QPushButton:checked {{
                background-color: transparent;
                color: {t['primary']};
                font-weight: 700;
            }}
            QPushButton#ActiveNav:hover, QPushButton:checked:hover {{
                background-color: {"rgba(0, 0, 0, 0.05)" if cls.CURRENT_THEME == "light" else "rgba(255, 255, 255, 0.05)"};
            }}
        """

    @classmethod
    def get_card_style(cls):
        t = cls.get_theme()
        return f"""
            QFrame#Card {{
                background-color: {t['surface']};
                border: 1px solid {t['border']};
                border-radius: 12px;
            }}
            QFrame#StealthCard {{
                background-color: {t['bg']};
                border: 1px solid {t['border']};
                border-radius: 8px;
            }}
        """

    @classmethod
    def get_button_style(cls, dangerous=False):
        t = cls.get_theme()
        if dangerous:
            return f"""
                QPushButton {{
                    background-color: #ef44441A;
                    color: #ef4444;
                    border: 1px solid #ef4444;
                    padding: 8px 16px;
                    border-radius: 6px;
                    font-weight: bold;
                }}
                QPushButton:hover {{
                    background-color: #ef4444;
                    color: white;
                }}
            """
        return f"""
            QPushButton {{
                background-color: {t['primary']};
                color: white;
                border: none;
                padding: 8px 16px;
                border-radius: 6px;
                font-weight: bold;
            }}
            QPushButton:hover {{
                background-color: {t['hover']};
            }}
        """

    @classmethod
    def get_log_style(cls):
        t = cls.get_theme()
        return f"""
            QTextEdit {{
                background-color: {t['log_bg']};
                color: {"#94a3b8" if cls.CURRENT_THEME == "dark" else "#475569"};
                font-family: 'Consolas', 'Courier New';
                font-size: 12px;
                border: 1px solid {t['border']};
                border-radius: 8px;
                padding: 10px;
            }}
        """

    @classmethod
    def get_title_style(cls):
        t = cls.get_theme()
        return f"color: {t['text']}; font-size: 22px; font-weight: 800;"

    @classmethod
    def get_subtitle_style(cls):
        t = cls.get_theme()
        return f"color: {t['muted']}; font-size: 13px;"

    # Helper to get current style as a string for direct class access
    @classmethod
    def main_style(cls): return cls.get_main_style()
    @classmethod
    def sidebar_style(cls): return cls.get_sidebar_style()
    @classmethod
    def card_style(cls): return cls.get_card_style()
    @classmethod
    def button_style(cls, dangerous=False): return cls.get_button_style(dangerous)
    @classmethod
    def log_style(cls): return cls.get_log_style()
    @classmethod
    def title_style(cls): return cls.get_title_style()
    @classmethod
    def subtitle_style(cls): return cls.get_subtitle_style()

    # Legacy static access for backward compatibility (using a trick to make them look like class attributes)
    class _StyleProxy:
        def __getattribute__(self, name):
            if name == "MAIN_WINDOW_STYLE": return PremiumStyles.get_main_style()
            if name == "SIDEBAR_STYLE": return PremiumStyles.get_sidebar_style()
            if name == "CARD_STYLE": return PremiumStyles.get_card_style()
            if name == "BUTTON_STYLE": return PremiumStyles.get_button_style()
            if name == "LOG_STYLE": return PremiumStyles.get_log_style()
            if name == "TITLE_STYLE": return PremiumStyles.get_title_style()
            if name == "SUBTITLE_STYLE": return PremiumStyles.get_subtitle_style()
            return super().__getattribute__(name)

    TABLE_ACTION_STYLE = """
        QPushButton {{
            background-color: transparent;
            color: {bg}; 
            font-size: 15px;
            border: none;
            border-radius: 0px;
            min-width: 20px;
            max-width: 20px;
            min-height: 24px;
            max-height: 24px;
        }}
        QPushButton:hover {{
            background-color: rgba(255, 255, 255, 0.05);
        }}
    """

