import os
import sys
import shutil
import winreg
import subprocess
from pathlib import Path

def install_agent(server_ip=None):
    print("[*] VANGUARD Sessiz Ajan Kurulumu Başlatılıyor...")
    
    # 1. Hedef Dizin Hazırlığı
    target_dir = Path(os.environ.get("ProgramData", "C:/ProgramData")) / "VanguardService"
    target_dir.mkdir(parents=True, exist_ok=True)
    
    # 2. Sunucu IP Kaydı
    if server_ip:
        try:
            (target_dir / "last_server.txt").write_text(server_ip)
            print(f"[+] Sunucu IP adresi kaydedildi: {server_ip}")
        except: pass

    # 3. Güvenlik Duvarı İzinleri
    try:
        print("[*] Güvenlik duvarı kuralları ekleniyor...")
        subprocess.run('netsh advfirewall firewall add rule name="VanguardAgent_TCP" dir=in action=allow protocol=TCP localport=7777', shell=True, capture_output=True)
        subprocess.run('netsh advfirewall firewall add rule name="VanguardAgent_UDP" dir=in action=allow protocol=UDP localport=7778', shell=True, capture_output=True)
        subprocess.run('netsh advfirewall firewall add rule name="VanguardAgent_UDP_Out" dir=out action=allow protocol=UDP localport=7778', shell=True, capture_output=True)
        print("[+] Firewall izinleri başarıyla eklendi.")
    except Exception as e:
        print(f"[-] Firewall hatası: {e}")

    # 4. Dosyaları Hazırla ve Kopyala (Smarter Detection)
    current_dir = Path(os.path.abspath(os.path.dirname(__file__)))
    agent_exe_name = "VanguardAgent.exe"
    
    # Öncelik listesi: 
    # 1. Mevcut dizindeki dist/ içindeki paketlenmiş EXE
    # 2. Mevcut dizindeki paketlenmiş EXE
    # 3. Mevcut dizindeki agent.py (Geliştirici modu)
    
    source_exe = None
    potential_exes = [
        current_dir / "dist" / agent_exe_name,
        current_dir / agent_exe_name,
        Path(sys.executable).parent / agent_exe_name # Eğer toolkit içindense
    ]
    
    for p in potential_exes:
        if p.exists():
            source_exe = p
            break
            
    try:
        install_cmd = ""
        if source_exe:
            print(f"[*] Paketlenmiş EXE bulundu: {source_exe}")
            target_exe = target_dir / agent_exe_name
            shutil.copy2(source_exe, target_exe)
            install_cmd = f'"{target_exe}"'
            print("[+] EXE başarıyla kopyalandı.")
        else:
            print("[!] Paketlenmiş EXE bulunamadı. Geliştirici modu (Python) deneniyor.")
            # Core klasörünü kopyala
            if (current_dir / "core").exists():
                shutil.copytree(current_dir / "core", target_dir / "core", dirs_exist_ok=True)
            
            agent_script = target_dir / "agent.py"
            if (current_dir / "agent.py").exists():
                shutil.copy2(current_dir / "agent.py", agent_script)
                python_exe = sys.executable.replace("python.exe", "pythonw.exe")
                install_cmd = f'"{python_exe}" "{agent_script}"'
                print("[+] Python scripti ve core modülü kopyalandı.")
            else:
                raise FileNotFoundError("Hiçbir ajan dosyası (EXE veya .py) bulunamadı!")

        # 5. Zamanlanmış Görevler Oluştur (Persistence & Watchdog)
        # Görev 1: Kullanıcı giriş yaptığında başlar
        # Görev 2: Her 5 dakikada bir kontrol eder (Watchdog)
        try:
            print("[*] Zamanlanmış görevler oluşturuluyor...")
            
            # Eski görevleri temizle (varsa)
            subprocess.run('schtasks /delete /tn "VanguardAgent_Boot" /f', shell=True, capture_output=True)
            subprocess.run('schtasks /delete /tn "VanguardAgent_Watchdog" /f', shell=True, capture_output=True)
            
            # Logon Görevi
            boot_cmd = f'schtasks /create /tn "VanguardAgent_Boot" /tr "{install_cmd.replace(chr(34), chr(92)+chr(34))}" /sc onlogon /rl highest /f'
            subprocess.run(boot_cmd, shell=True, capture_output=True)
            
            # Watchdog Görevi (Her 5 dakikada bir)
            watchdog_cmd = f'schtasks /create /tn "VanguardAgent_Watchdog" /tr "{install_cmd.replace(chr(34), chr(92)+chr(34))}" /sc minute /mo 5 /rl highest /f'
            subprocess.run(watchdog_cmd, shell=True, capture_output=True)
            
            print("[+] Zamanlanmış görevler (Boot ve Watchdog) başarıyla oluşturuldu.")
            
            # Yedek olarak Kayıt Defterini de tutabiliriz ama temizlik için şimdilik kapalı tutalım
            # key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Run", 0, winreg.KEY_SET_VALUE)
            # winreg.SetValueEx(key, "WindowsVanguardSvc", 0, winreg.REG_SZ, install_cmd)
            # winreg.CloseKey(key)
        except Exception as st_err:
            print(f"[-] Görev oluşturma hatası: {st_err}")

        # 6. Ajanı Hemen Başlat
        print("[*] VANGUARD Ajanı başlatılıyor...")
        subprocess.Popen(install_cmd, shell=True, creationflags=subprocess.CREATE_NO_WINDOW)
        
    except Exception as e:
        print(f"[-] Kurulum hatası: {e}")
        return False

    print("\n[!] Kurulum Tamamlandı. İstemci artık sessizce çalışıyor.")
    return True

if __name__ == "__main__":
    sip = sys.argv[1] if len(sys.argv) > 1 else None
    install_agent(server_ip=sip)
