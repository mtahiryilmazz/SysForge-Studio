:: Dosya Adı: install_and_run.bat
@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo Bilgi Islem Teknik Servis Yazilimi - Kurulum ve Baslatma
echo ========================================================
echo.

:: 1. Internet Kontrolu (pythonping modulu oncesi veya genel olarak)
ping -n 1 google.com >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [UYARI] Internet baglantisi bulunamadi. Yukleme adimi sorun cikarabilir veya cevrimici araclari kullanamayabilirsiniz.
) else (
    echo [OK] Internet baglantisi mevcut.
)

:: 2. Python Kontrolu
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [HATA] Python yuklu degil veya PATH'e ekli degil.
    echo Lutfen Python 3.11 veya uzeri bir surum yukleyin.
    pause
    exit /b 1
)
echo [OK] Python bulundu.

:: 3. Pip Kontrolu
python -m pip --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [HATA] pip bulunamadi. Python kurulumunuzu kontrol edin.
    pause
    exit /b 1
)
echo [OK] pip bulundu.

:: 4. Bagimliliklari Yukleme
echo.
echo Moduller requirements.txt listesinden kontrol ediliyor ve yukleniyor...
echo Bu islem biraz zaman alip log uretilebilir.
python -m pip install -r requirements.txt > install_log.txt 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [HATA] Gereksinimler yuklenirken bir hata olustu. Detaylar icin install_log.txt dosyasini inceleyin.
    pause
    exit /b 1
)
echo [OK] Tum bagimliliklar yuklendi veya zaten mevcut.

:: 5. Uygulamayi Baslatma
echo.
echo Uygulama baslatiliyor...
python VanguardIT.py
if %ERRORLEVEL% NEQ 0 (
    echo [HATA] Uygulama calisirken bir hata olustu.
    pause
    exit /b 1
)

pause
:: Aciklama: Bu script kullanıcının sistemindeki Python'ı kontrol eder, eksik modülleri yükler, interneti sınar, log tutar ve ana projeyi ayağa kaldırır.
