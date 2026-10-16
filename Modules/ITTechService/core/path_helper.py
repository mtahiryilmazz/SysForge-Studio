import os
import sys

def get_app_root():
    """
    Kalıcı verilerin (DB, Log) tutulacağı klasörü döner.
    Dondurulmuş (EXE) ise EXE'nin klasörü, değilse proje kök dizini.
    """
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    # core/path_helper.py olduğu için iki üst dizin kök dizindir
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def get_resource_path(relative_path):
    """
    Kaynak dosyaların (scriptler, static dosyalar) yolunu döner.
    Dondurulmuş (EXE) ise _MEIPASS klasörü, değilse proje kök dizini.
    """
    if getattr(sys, 'frozen', False):
        base_path = sys._MEIPASS
    else:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    return os.path.join(base_path, relative_path)
