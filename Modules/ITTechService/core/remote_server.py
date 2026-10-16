import socket
import threading
import json
import logging

class RemoteServer:
    def __init__(self, host='0.0.0.0', port=7777):
        self.host = host
        self.port = port
        self.clients = {} 
        self.server_socket = None
        self.running = False
        self.callbacks = []

    def start(self):
        try:
            print(f"[*] Admin Sunucusu başlatılıyor: {self.host}:{self.port}...")
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(50)
            self.running = True
            
            # Arka plan iş parçacıklarını başlat
            threading.Thread(target=self.accept_clients, daemon=True).start()
            threading.Thread(target=self.start_udp_beacon, daemon=True).start()
            threading.Thread(target=self._heartbeat_loop, daemon=True).start()
            
            msg = f"[+] Admin Sunucusu {self.host}:{self.port} üzerinde dinlemeye basladi."
            print(msg)
            logging.info(msg)
        except Exception as e:
            err = f"[-] Admin Sunucusu baslatilamadi (Port {self.port} kullanimda olabilir): {e}"
            print(err)
            logging.error(err)

    def _heartbeat_loop(self):
        """Bağlantıların kopmaması için 30 saniyede bir ping atar (WinError 10054 koruması)."""
        import time
        while self.running:
            time.sleep(30)
            try:
                # Sözlük değişebileceği için liste üzerinden güvenli döngü
                for addr in list(self.clients.keys()):
                    self.send_command(addr, {"action": "ping"})
            except: pass

    def start_udp_beacon(self):
        """Istemcilerin sunucuyu bulmasi için tüm aktif ağ arayüzleri üzerinden UDP yayini yapar."""
        import socket
        import time
        import psutil
        
        beacon_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        try:
            beacon_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            beacon_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        except: pass
        
        while self.running:
            self._send_beacon(beacon_sock)
            time.sleep(5)

    def trigger_discovery(self):
        """Manuel olarak hemen bir UDP keşif yayını tetikler."""
        try:
            temp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
            temp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            self._send_beacon(temp_sock)
            temp_sock.close()
            return True
        except:
            return False

    def _send_beacon(self, sock):
        """Aktif ağ arayüzlerinden beacon paketlerini gönderir."""
        import psutil
        interfaces_to_broadcast = []
        try:
            for interface, addrs in psutil.net_if_addrs().items():
                lower_if = interface.lower()
                if any(x in lower_if for x in ["virtualbox", "vmware", "veth", "loopback", "isatap", "pseudo"]):
                    continue
                    
                for addr in addrs:
                    if addr.family == socket.AF_INET:
                        ip = addr.address
                        if not ip.startswith("127."):
                            broadcast_addr = getattr(addr, 'broadcast', None) or "255.255.255.255"
                            interfaces_to_broadcast.append((ip, broadcast_addr))
        except: pass

        if not interfaces_to_broadcast:
            interfaces_to_broadcast.append(("0.0.0.0", "255.255.255.255"))

        for local_ip, b_addr in interfaces_to_broadcast:
            try:
                beacon_msg = f"VANGUARD_SERVER|{local_ip}|AUTH_KEY_123".encode('utf-8')
                sock.sendto(beacon_msg, (b_addr, 7778))
                sock.sendto(beacon_msg, ("255.255.255.255", 7778))
            except: pass



    def add_callback(self, cb):
        self.callbacks.append(cb)

    def trigger_callbacks(self, event_type, data):
        for cb in self.callbacks:
            try:
                cb(event_type, data)
            except:
                pass

    def accept_clients(self):
        while self.running:
            try:
                conn, addr = self.server_socket.accept()
                threading.Thread(target=self.handle_client, args=(conn, addr), daemon=True).start()
            except Exception as e:
                if self.running: logging.error(f"Baglanti kabul hatasi: {e}")

    def handle_client(self, conn, addr):
        addr_str = f"{addr[0]}:{addr[1]}"
        byte_buffer = b""
        client_registered = False
        
        try:
            while self.running:
                chunk = conn.recv(1024 * 1024)
                if not chunk:
                    logging.info(f"Bağlantı kapandı: {addr_str}")
                    break
                
                byte_buffer += chunk
                
                # Mesajları satır satır ayır (b"\n" üzerinden)
                while b"\n" in byte_buffer:
                    line_bytes, byte_buffer = byte_buffer.split(b"\n", 1)
                    if not line_bytes.strip():
                        continue
                    
                    try:
                        line_text = line_bytes.decode('utf-8', errors='ignore')
                        msg_obj = json.loads(line_text)
                        
                        if not client_registered:
                            # İlk mesaj her zaman istemci bilgisidir
                            self.clients[addr_str] = {"conn": conn, "info": msg_obj}
                            self.trigger_callbacks("client_connected", {"addr": addr_str, "info": msg_obj})
                            logging.info(f"Yeni ajan başarıyla kaydedildi: {addr_str} ({msg_obj.get('hostname')})")
                            client_registered = True
                        else:
                            # Sonraki mesajlar normal komut verileridir
                            self.trigger_callbacks("message_received", {"addr": addr_str, "msg": line_text})
                    except json.JSONDecodeError as je:
                        logging.error(f"JSON Çözümleme Hatası ({addr_str}): {je}. Veri boyutu: {len(line_bytes)}")
                    except Exception as e:
                        logging.error(f"Mesaj İşleme Hatası ({addr_str}): {e}")
                    
        except Exception as e:
            logging.error(f"Client haberlesme hatasi ({addr_str}): {e}")
        finally:
            if addr_str in self.clients:
                del self.clients[addr_str]
                self.trigger_callbacks("client_disconnected", {"addr": addr_str})
            try:
                conn.close()
            except:
                pass


    def send_command(self, addr_str, cmd_dict):
        if addr_str in self.clients:
            try:
                conn = self.clients[addr_str]["conn"]
                payload = json.dumps(cmd_dict) + "\n"
                conn.sendall(payload.encode('utf-8'))
                return True
            except Exception as e:
                logging.error(f"Komut gonderme basarisiz {addr_str}: {e}")
                return False
        return False

    def stop(self):
        self.running = False
        if self.server_socket:
            self.server_socket.close()
