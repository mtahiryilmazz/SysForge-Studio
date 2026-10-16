import subprocess
import platform
import socket
from core.logger import get_logger

logger = get_logger(__name__)

def ping_host(host):
    param = '-n' if platform.system().lower() == 'windows' else '-c'
    command = ['ping', param, '1', host]
    try:
        response = subprocess.call(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return response == 0
    except Exception as e:
        logger.error(f"Ping hatası ({host}): {e}")
        return False

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception as e:
        logger.error(f"Yerel IP alınamadı: {e}")
        return "Bilinmiyor"
