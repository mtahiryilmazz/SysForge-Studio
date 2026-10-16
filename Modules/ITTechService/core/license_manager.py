import subprocess
import os
import json
import requests
import logging
import uuid
import sys

logger = logging.getLogger("license_manager")

class LicenseManager:
    def __init__(self, api_base_url="http://localhost:5000/api/license"):
        self.api_url = api_base_url
        self.license_file = self._get_license_path()
        self.hwid = self.generate_hwid()

    def _get_license_path(self):
        if getattr(sys, 'frozen', False):
            base_dir = os.path.dirname(sys.executable)
        else:
            base_dir = os.getcwd()
            
        path = os.path.join(base_dir, "license.json")
        
        if getattr(sys, 'frozen', False) and not os.path.exists(path):
            bundled = os.path.join(sys._MEIPASS, "license.json")
            if os.path.exists(bundled):
                try:
                    import shutil
                    shutil.copy2(bundled, path)
                except:
                    pass
                    
        return path

    def generate_hwid(self):
        """Generates a stable hardware ID using WMIC on Windows."""
        try:
            cmd = 'wmic csproduct get uuid'
            uuid_str = subprocess.check_output(cmd, shell=True).decode().split('\n')[1].strip()
            if not uuid_str or uuid_str.lower() == "ffffffff-ffff-ffff-ffff-ffffffffffff":
                # Fallback to mac address if wmic fails or returns dummy value
                return str(uuid.getnode())
            return uuid_str
        except Exception:
            return str(uuid.getnode())

    def get_local_license(self):
        if os.path.exists(self.license_file):
            try:
                with open(self.license_file, 'r') as f:
                    return json.load(f)
            except:
                return None
        return None

    def save_license(self, key):
        with open(self.license_file, 'w') as f:
            json.dump({"key": key}, f)

    def activate(self, key):
        """Attempts to activate the license on the remote server."""
        try:
            resp = requests.post(f"{self.api_url}/activate", json={
                "key": key,
                "hwid": self.hwid
            }, timeout=5)
            if resp.status_code == 200:
                self.save_license(key)
                return True, "Aktivasyon başarılı!"
            else:
                return False, resp.json().get('error', 'Aktivasyon hatası')
        except Exception as e:
            return False, f"Sunucuya bağlanılamadı: {e}"

    def check_license(self, db_conn=None):
        """Checks if the stored license is still valid, trying local DB first if available."""
        local = self.get_local_license()
        if not local:
            return False, "Lisans bulunamadı"

        # 1. Aşama: Eğer bir veritabanı bağlantısı varsa, doğrudan DB'den kontrol et (HIZLI)
        if db_conn:
            try:
                res = db_conn.fetch_data("SELECT status, hwid FROM licenses WHERE license_key=?", (local['key'],))
                if res:
                    lic = dict(res[0])
                    if lic['hwid'] and lic['hwid'] != self.hwid:
                        return False, "Cihaz eşleşmiyor (Yerel Kontrol)"
                    if lic['status'] == 'ACTIVE':
                        return True, "Lisans geçerli (Yerel Kontrol)"
                    return False, f"Lisans durumu: {lic['status']} (Yerel Kontrol)"
            except Exception as e:
                logger.debug(f"Yerel lisans kontrolü başarısız: {e}")

        # 2. Aşama: Fallback - Web API üzerinden kontrol et
        try:
            resp = requests.get(f"{self.api_url}/check", params={
                "key": local['key'],
                "hwid": self.hwid
            }, timeout=2) # Timeout'u düşürdük
            if resp.status_code == 200:
                data = resp.json()
                if data.get('status') == 'ACTIVE':
                    return True, "Lisans geçerli"
                return False, "Lisans iptal edilmiş!"
            else:
                return False, "Sunucu lisansı doğrulamadı"
        except requests.exceptions.RequestException:
            # Sunucuya ulaşılamıyor, ama daha önce DB'den kontrol etmiş olabiliriz veya 5 dk süre verebiliriz.
            return None, "Offline - Sunucuya ulaşılamıyor"
