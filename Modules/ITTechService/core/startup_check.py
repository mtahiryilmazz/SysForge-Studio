import sys
import subprocess
import os

def check_and_install_requirements():
    # Eger uygulama EXE olarak derlenmisse (frozen), icindeki tum moduller zaten paketlenmistir!
    if getattr(sys, 'frozen', False):
        return True

    req_file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "requirements.txt")
    if not os.path.exists(req_file):
        print(f"Uyari: {req_file} bulunamadi.")
        return False
    
    try:
        from importlib.metadata import version, PackageNotFoundError
        
        with open(req_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            
        missing = False
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            # Paketin ismini al (>>, ==, vb. karakterlerden oncesi)
            pkg_name = line.replace('>=', '==').replace('<=', '==').split('==')[0]
            if pkg_name.lower() == 'pywin32':
                 pass # win32 metadata bazi sistemlerde farkli olabilir
                 
            try:
                version(pkg_name)
            except PackageNotFoundError:
                missing = True
                print(f"Eksik modul tespit edildi: {pkg_name}")
                break
                
        if missing:
            print("Eksik gereksinimler 'requirements.txt' uzerinden otomatik yukleniyor, lutfen bekleyin...")
            subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", req_file])
            print("Gereksinim indirme islemi tamamlandi!")
            return True
        return True
    
    except Exception as e:
        print(f"Modul kontrolunde bir hata olustu, yine de baslatilmaya calisiliyor... Hata: {e}")
        return False

# Modul import edildigi gibi calistirilir
check_and_install_requirements()
