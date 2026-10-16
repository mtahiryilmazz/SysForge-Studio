import socket
import subprocess
import ipaddress
import concurrent.futures
import psutil

class NetworkModule:
    def __init__(self):
        pass

    def get_interfaces(self):
        """Sistemdeki ağ kartlarını ve IPv4 bilgilerini çeker."""
        interfaces = []
        try:
            for iface, addrs in psutil.net_if_addrs().items():
                for addr in addrs:
                    if addr.family == socket.AF_INET and not addr.address.startswith("127."):
                        interfaces.append({
                            "name": iface,
                            "ip": addr.address,
                            "netmask": addr.netmask
                        })
        except Exception as e:
            pass
        return interfaces

    def scan_ip(self, ip_str):
        """Tek bir IP adresini tarar, Ping atar, MAC ARP çeker ve OS cihaz profilini tahminsel bulur."""
        result = {
            "ip": ip_str,
            "status": "Kapalı / Boş",
            "ping": "-",
            "hostname": "-",
            "os": "-",
            "profile": "Bilinmiyor",
            "icon": "empty"
        }
        
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        
        try:
            proc = subprocess.run(['ping', '-n', '1', '-w', '400', ip_str], 
                                  capture_output=True, text=True, startupinfo=startupinfo)
            output = proc.stdout.lower()
            
            if "ttl=" in output:
                result["status"] = "Açık"
                result["icon"] = "online"
                
                try:
                    time_idx = output.find("time=")
                    if time_idx == -1: time_idx = output.find("süre=")
                    if time_idx != -1:
                        ms_part = output[time_idx:].split("ms")[0].split("=")[1].strip()
                        result["ping"] = f"{ms_part} ms"
                except: pass
                
                ttl = -1
                try:
                    ttl_part = output.split("ttl=")[1].split()[0]
                    ttl = int(ttl_part)
                    if ttl <= 64: result["os"] = "Linux / Router"
                    elif ttl <= 128: result["os"] = "Windows"
                    else: result["os"] = "Ağ Cihazı / Unix"
                except: pass
                
                try:
                    hostname, _, _ = socket.gethostbyaddr(ip_str)
                    result["hostname"] = hostname
                except:
                    result["hostname"] = "-"

                low_hostname = result["hostname"].lower()

                # Genişletilmiş Port Taraması
                # 80/443: Web, 135/445: Win, 548: Mac, 9100/631: Printer, 5060: SIP, 22: SSH, 5000/8000: NAS
                ports_to_check = [80, 443, 135, 445, 548, 9100, 5060, 22, 5000, 8000]
                open_ports = []
                for p in ports_to_check:
                    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                        s.settimeout(0.15)
                        if s.connect_ex((ip_str, p)) == 0:
                            open_ports.append(p)
                
                # Cihaz Tipleme Mantığı (Heuristic)
                if 548 in open_ports or "mac" in low_hostname or "apple" in low_hostname:
                    result["profile"] = "Apple Mac / MacBook"
                    result["icon"] = "mac"
                elif 135 in open_ports or 445 in open_ports or 139 in open_ports:
                    # Windows 10/11 Ayrımı denemesi
                    if "w11" in low_hostname or "win11" in low_hostname:
                        result["profile"] = "Windows 11 PC"
                        result["icon"] = "win11"
                    elif "w10" in low_hostname or "win10" in low_hostname:
                        result["profile"] = "Windows 10 PC"
                        result["icon"] = "win10"
                    else:
                        # Varsayılan (Genellikle yeni cihazlar W11, ama güvenli liman W10)
                        result["profile"] = "Windows PC / Sunucu"
                        result["icon"] = "win10" # Varsayılan Win10
                elif 9100 in open_ports or 631 in open_ports or "printer" in low_hostname:
                    result["profile"] = "Ağ Yazıcısı"
                    result["icon"] = "printer"
                elif 5060 in open_ports or "voip" in low_hostname or "phone" in low_hostname:
                    result["profile"] = "IP Telefon / VoIP"
                    result["icon"] = "phone"
                elif 5000 in open_ports or 5001 in open_ports or "nas" in low_hostname:
                    result["profile"] = "NAS Depolama Ünitesi"
                    result["icon"] = "nas"
                elif 22 in open_ports or 23 in open_ports or 80 in open_ports or 443 in open_ports:
                    if ttl <= 64 or "gateway" in low_hostname or "router" in low_hostname:
                        result["profile"] = "Modem / Router / Switch"
                        result["icon"] = "router"
                    else:
                        result["profile"] = "Linux / Sunucu"
                        result["icon"] = "linux"
                else:
                    if ttl <= 64: 
                        result["profile"] = "Android / Mobil / IoT"
                        result["icon"] = "mobile"
                    else: 
                        result["profile"] = "Bilinmeyen Cihaz"
                        result["icon"] = "unknown"
                    
        except Exception:
            pass
            
        return result

    def scan_subnet(self, ip, netmask, progress_callback=None):
        """Belirtilen alt ağdaki tüm IP'leri tarar (Thread havuzu kullanır)."""
        results = []
        try:
            network = ipaddress.IPv4Network(f"{ip}/{netmask}", strict=False)
            hosts = list(network.hosts()) # Sadece taranabilir hostlar
            if len(hosts) > 500:
                hosts = hosts[:500] # Güvenlik limiti
                
            total = len(hosts)
            completed = 0
            
            with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
                future_to_ip = {executor.submit(self.scan_ip, str(h)): h for h in hosts}
                for future in concurrent.futures.as_completed(future_to_ip):
                    r = future.result()
                    results.append(r)
                    completed += 1
                    if progress_callback:
                        progress_callback(int((completed / total) * 100), r)
        except Exception as e:
            print(e)
            pass
        
        # IP'ye göre sırala
        results.sort(key=lambda x: [int(p) for p in x["ip"].split(".")])
        return results
