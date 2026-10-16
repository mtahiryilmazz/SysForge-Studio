# 🛠️ SysForge Studio / Ultimate Enterprise IT Suite

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D4?logo=windows)](https://microsoft.com/windows)
[![Architecture](https://img.shields.io/badge/Arch-x86%20%7C%20x64-107C41)]()
[![Framework](https://img.shields.io/badge/.NET-8.0%20WPF%20Fluent-512BD4?logo=dotnet)]()
[![Design](https://img.shields.io/badge/Design-PowerToys%20%2F%20DevToys%20Dark-202020)]()

SysForge Studio (Ultimate Enterprise IT Suite), sistem yöneticileri, bilgi işlem personeli ve teknik servis teknisyenleri için tasarlanmış modern, hepsi bir arada Windows bakım, donanım kimlik doğrulama ve BT operasyon yönetim merkezidir.

---

## ✨ Temel Özellikler ve Modüller

### 🛡️ 1. Donanım Ekspertizi & Bütünlük Kıyaslama (Hardware Expertise)
* **Derin Donanım Keşfi:** Anakart, BIOS UUID, İşlemci ID, RAM modülleri (Bank, Seri No, Hız), Disk sürücüleri (Seri No, Model, Kapasite), GPU ve Ağ adaptörlerini listeler.
* **Kriptografik Donanım Parmak İzi (SHA-256):** Cihazın tüm benzersiz seri numaralarından deterministik donanım hash'i üretir.
* **Baseline (Referans) & Değişiklik Tespiti:** Cihaz ilk teslim alındığında referans kayıt alır; servis sonrasında veya periyodik kontrollerde donanım kıyaslaması yaparak sökülen, eklenen veya değiştirilen parçaları (örn. RAM modülü, SSD değişimi) anında raporlar.
* **HTML Ekspertiz Raporu:** Tek tıkla görselleştirilmiş teknik servis ekspertiz raporu üretir.

### 🖨️ 2. Kurumsal Yazıcı & Spooler Onarım Paketi
* **0x0000011b, 709 ve Point & Print Onarımları:** Windows Update sonrası bozulan ağ yazıcı bağlantılarını tek tıkla çözer.
* **Spooler & Kuyruk Temizliği:** Takılı kalmış yazdırma işlerini ve bozuk sürücü paketlerini izole eder.
* **Gelişmiş Yazıcı Keşfi:** Ağdaki paylaşılan yazıcıları ve UNC yollarını otomatik bulur.

### 💼 3. BT Servis & Vanguard Portali (IT Tech Service)
* **Arıza & Destek Talepleri (Tickets):** Kullanıcı bildirimlerini takip etme ve durum güncelleme.
* **Donanım Zimmet Envanteri:** Şirket içi cihazların zimmet kaydı.
* **Entegre Yerel Web Konsolu:** Flask tabanlı BT servis portalini arayüzden başlatma ve tarayıcıda yönetme.

### 🌐 4. Ağ Keşfi & Uzak Masaüstü
* 254 cihazlık yerel IP subnet taraması.
* Açık port analizi ve tek tıkla RDP bağlantı profilleri.

### 🔧 5. Windows Çekirdek Onarım & Performans
* SFC, DISM çevrimiçi imaj onarımı, TCP/IP & Winsock sıfırlama, Windows Update bileşen temizliği.

---

## 🏗️ Mimari & Çoklu Platform Desteği

* **Arayüz Çatısı:** Windows 11 / DevToys / PowerToys tasarım kılavuzlarına sadık kalınmış koyu Fluent XAML arayüzü.
* **x86 & x64 Desteği:** Hem eski 32-bit (x86) Windows sistemlerde hem de modern 64-bit (x64) sistemlerde sıfır harici bağımlılıkla çalışır.
* **WPF PowerShell Desteği:** Bağımsız PowerShell araçları (`EkspertizRaporu_WPF_Fluent.ps1`), eski Windows Forms yerine doğrudan yerel WPF XAML motoruyla açılır.

---

## 🚀 Derleme & Paketleme

Projeyi tek tıkla hem x86 hem x64 taşınabilir (`Self-Contained SingleFile .exe`) olarak derlemek için:

```cmd
Publish_All_Architectures.bat
```

Çıktılar `publish_output/win-x86/` ve `publish_output/win-x64/` klasörlerinde hazır olacaktır.

### Visual Studio ile Geliştirme:
1. `SysForgeStudio.sln` dosyasını Visual Studio 2022+ ile açın.
2. `Release | Any CPU` veya `Release | x64` seçeneğiyle derleyin.

---

## 📄 Lisans
Bu proje kurumsal IT altyapıları ve teknik servis operasyonları için geliştirilmiştir.
