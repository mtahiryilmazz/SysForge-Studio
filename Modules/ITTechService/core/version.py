# Dosya Adı: version.py
VERSION = "1.1.0"
CODENAME = "Orion"
APP_NAME = "SENTINEL"

def get_full_version():
    return f"{APP_NAME} {CODENAME} (v{VERSION})"
