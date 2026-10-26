# 🛡️ SysForge Studio — Depo, Güvenlik ve Mimari Analiz Raporu
> **Metodoloji:** `/ponytail-audit` · `/karpathy-guidelines` · `/ecc`  
> **Tarih:** 27 Ekim 2026  
> **Kapsam:** SysForge Studio Deposu — Güvenlik açıkları, hassas veri/anahtar/yol sızıntıları, gereksiz AI kalıntıları ve kod sadeleştirmesi.

---

## 📌 1. Depo Ne İşi Yapar? (What This Repo Does)

**SysForge Studio**, Windows BT yöneticileri ve teknik servis uzmanları için geliştirilmiş; C# WPF masaüstü uygulaması, bağımsız Node.js sanal sunucusu (`server.js`), çevrimdışı debloat/güvenlik çekirdeği ve tarayıcı tabanlı HUD kokpitinden oluşan hepsi bir arada bir sistem teşhis, onarım ve optimizasyon aracıdır. Teknisyenin yerel bilgisayarında veya yerel ağdaki (LAN) diğer cihazlarda doğrudan çalıştırılması (1 ila ~10 teknisyen eşzamanlı erişimi) varsayılmıştır.

---

## 🚨 2. Must Fix (Kritik Güvenlik, Veri ve Anahtar Sızıntıları)

### 1. `server.js` Dizin Geçişi (Directory Traversal) ve Hassas Dosya Erişimi (`server.js:L197-225`)
- **Tanım:** Node.js sanal sunucusu yerel ve LAN ağından gelen istemcilere statik dosyaları (`dashboard.html`, scriptler, resimler) sunar.
- **Problem:** Önceki regex kontrolü yalnızca istek başındaki `../` ifadelerini temizliyordu ve dosya uzantısı/noktalı dizin kısıtlaması yoktu. LAN'daki veya yerel bir istemci `/.env`, `/.git/config`, `Config/*.key`, kaynak kodları ve veritabanı dosyalarını indirebiliyordu.
- **Düzeltme:** `path.resolve` ile hedef dosyanın proje kök dizini sınırları içinde kaldığı teyit edildi. `.key`, `.token`, `.env`, `.pfx`, `.cer`, `.db`, `.log`, `.cs`, `.csproj`, `.sln`, `.suo` uzantılı ve gizli (`.`) dosyalara erişim `403 Forbidden` ile engellendi.

### 2. PowerShell Nesne Kalıntısı ve Kişisel Kullanıcı Yolu Sızıntısı (`Config/custom_bundle.txt`)
- **Tanım:** Paket yöneticisi için özel kurulacak yazılımların listesini tutan metin yapılandırması.
- **Problem:** Dosya içerisine `Get-Item` çıktısı doğrudan yazdırılmış ve `C:\Users\Ansh\Desktop\fresh\...` şeklinde kişisel bir Windows kullanıcı profili ve dosya yolu sızmıştı.
- **Düzeltme:** Dosya içeriği temizlenerek sadece tanımlı paket adı olan `java` bırakıldı.

### 3. `SystemTwin.json` İçindeki Kişisel Başlangıç Yolları (`Config/SystemTwin.json`)
- **Tanım:** Bilgisayarın başlangıç programları, sürücüleri ve servis durumunu saklayan sistem ikizi anlık görüntüsü.
- **Problem:** `OneDrive` ve `FilmoraTray` başlangıç kayıtlarında `C:\Users\Ansh\AppData\Local\...` hardcoded kullanıcı yolu bulunuyordu.
- **Düzeltme:** Yollar genel ve taşınabilir `%USERPROFILE%\AppData\Local\...` ortam değişkeniyle maskelendi.

### 4. Web Kokpitinde Sabit Kişisel Kullanıcı Yolları (`dashboard.html` & `Modules/dashboard.html`)
- **Tanım:** Web arayüzü içerisindeki teşhis raporu ve Discord engelleme örnek yolları.
- **Problem:** `C:\Users\Ansh\Desktop\fresh\Docs\HealthReport.html` ve `C:\Users\Ansh\AppData\Local\Discord\...` şeklinde geliştiriciye ait yerel dizinler yer alıyordu.
- **Düzeltme:** Teşhis raporu `C:\Users\Public\Documents\SysForge\Docs\HealthReport.html`, Discord yolu `C:\Program Files\Discord\Discord.exe` olarak güncellendi ve iki dosya senkronize edildi.

### 5. `SysForgeStudio.wsb` Windows Sandbox Sabit Kullanıcı Yolu
- **Tanım:** SysForge Studio'yu izole Windows Sandbox ortamında güvenle test etmek için kullanılan yapılandırma dosyası.
- **Problem:** `<HostFolder>C:\Users\BT\Documents\Github\SysForge-Studio</HostFolder>` şeklinde ofis kullanıcısının tam yolu yazılmıştı; başka bir bilgisayarda tıklandığında sandbox açılamıyordu.
- **Düzeltme:** WSB dosyası `C:\SysForgeStudio` şeklinde taşınabilir hale getirildi ve dinamik olarak o anki dizini sandbox'a bağlayıp açan tek tıkla çalışan [`Launch-Sandbox.cmd`](Launch-Sandbox.cmd) başlatıcısı eklendi.

### 6. IT Servis Veritabanında Sabit Makine Dizini (`SysForgeStudio/Services/ITServiceDatabase.cs:L220`)
- **Tanım:** Yerel SQLite veritabanı yedek/geçiş aday kontrol mekanizması.
- **Problem:** `D:\YILMAZApp\it_tech_service\it_tech_service.db` şeklinde geliştiriciye ait fiziksel sürücü ve dizin hardcoded yer alıyordu.
- **Düzeltme:** `Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "it_tech_service", "it_tech_service.db")` dinamik yoluyla değiştirildi.

### 7. Vanguard Python 3.8 Sabit Dizin ve Flask Gizli Anahtarı (`Modules/ITTechService/`)
- **Tanım:** IT Tech Service bünyesindeki destek araçları ve web paneli.
- **Problem:** `VanguardToolkit.py` içinde `C:/Users/BT/AppData/.../python.exe` sabit yolu; `web_server.py` içinde ise hardcoded `app.secret_key = 'it_service_super_secret_key'` mevcuttu.
- **Düzeltme:** Python yolu `%LOCALAPPDATA%` dinamik kontrolüne bağlandı; Flask `secret_key` ise `os.environ.get('FLASK_SECRET_KEY') or os.urandom(24)` ile rastgele/çevresel güvenli hale getirildi.

---

## 🧹 3. Should Fix (Yapay Zekâ Kalıntıları & Şişkinlik / Bloat Temizliği)

### 8. 17 Farklı IDE Klasörüne Çoğaltılmış 2.924 Adet Mükerrer Yapay Zekâ Dosyası
- **Tanım:** Çeşitli AI araçları tarafından projenin kök dizinine otomatik kopyalanan AI IDE klasörleri (`.augment`, `.claude`, `.codebuddy`, `.codewhale`, `.continue`, `.cursor`, `.factory`, `.gemini`, `.github/prompts`, `.kilocode`, `.kiro`, `.opencode`, `.qoder`, `.roo`, `.trae`, `.warp`, `.windsurf`).
- **Problem:** Bu klasörlerin her birinde 172 adet tamamen aynı dosya (~4.14 MB x 17 = **~70 MB ve 2.924 dosya!**) yer alıyordu. Projenin gerçek kaynak kodları ~200 dosya iken, repo %90 oranında gereksiz kopyalarla şişmiş durumdaydı.
- **Düzeltme:** Antigravity IDE'nin standart çalışma alanı olan [`.agents/skills`](.agents/skills) (ve yeni eklenen `ponytail`, `karpathy-guidelines`, `ui-ux-pro-max`, `replica-*`) hariç, diğer 17 kopya dizin git takibinden ve diskten temizlendi. [`.gitignore`](.gitignore) dosyasına eklenerek gelecekte tekrar oluşmaları engellendi.

### 9. Kullanılmayan Eski Yedek Dosyası: `dashboard_origin.html`
- **Tanım:** Kök dizinde unutulmuş 2.41 MB boyutundaki eski kokpit kopyası.
- **Problem:** Hiçbir script veya servis tarafından çağrılmayan, çeviri ve debloat güncellemelerinden önceki ölü bir yedek dosyasıydı.
- **Düzeltme:** `dashboard_origin.html` git'ten ve diskten silindi; güncel [`dashboard.html`](dashboard.html) ile [`Modules/dashboard.html`](Modules/dashboard.html) senkronize edildi.

---

## 🛠️ 4. Nice to Have & Yeni Araçlar (İyileştirmeler)

### 10. Dinamik ve Taşınabilir Sandbox Başlatıcı (`Launch-Sandbox.cmd`)
- Hangi bilgisayarda veya hangi dizinde olursanız olun, çift tıklandığında anlık olarak `%TEMP%` altında geçerli repo dizinini haritalayan bir `.wsb` oluşturup Sandbox'ı başlatır.

### 11. Otomatik Skill & Eklenti Kurulum Betiği (`install-skills.ps1`)
- İşyerinde veya yeni bir geliştirme makinesinde hem Claude Code CLI hem de Antigravity ortamı için tüm becerileri, pazar yerlerini ve araçları tek tıkla kurar.

---

## 📊 5. Özet & Metrikler

- **Verdict:** **Depo temiz, güvenli ve sağlıklı.**
- **Lean Kazanımı:**
  - **-2.925 dosya silindi** (Takip edilen dosya sayısı **3.306'dan 381'e** düştü, **~%88 hafifleme**).
  - **-72.5 MB disk ve git yükü kaldırıldı.**
- **Derleme Doğrulaması:** `.NET Framework 4.8 Release` derlemesi 0 Hata / 0 Uyarı ile başarıyla test edildi.
