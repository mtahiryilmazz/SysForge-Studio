# 🏠 SysForge Studio — Evde Devam Rehberi ve Geliştirme Özeti

Bu belge; ofiste gerçekleştirilen kapsamlı tersine mühendislik analizi, çeviri düzeltmeleri, Node.js sanal sunucu mimarisi, çevrimdışı debloat çekirdeği ve v6.1.0 derleme süreçlerini özetler. **Evdeki bilgisayarınızda projeyi açtığınızda kaldığınız yerden sorunsuz devam edebilmeniz için hazırlanmıştır.**

---

## 📌 1. Bugün Neler Yapıldı? (Yönetici Özeti)

1. **Tersine Mühendislik (Reverse-Engineering) ve Analiz:**
   - Projenin 4 katmanlı mimarisi (WPF C#, Web Kokpiti, PowerShell Çekirdeği, Yeni Node.js Sanal Sunucusu) incelendi ve pazar muadilleriyle (Chris Titus Tech WinUtil, Optimizer, BloatyNosy, Sophia Script) kıyaslandı.
2. **TR / EN Dil & Çeviri Anomalilerinin Onarımı:**
   - Önceki kontrolsüz regex değişimlerinden kaynaklanan JavaScript fonksiyon ve HTML etiket hataları (`loadBaşlatup`, `configureBaşlatupDelay`, `showBaşlatupImpact`, `runRecommendedEylems`, `Critical Hatas`, `Product Lisans Anahtarıs` vb.) temizlendi.
   - Geriye dönük uyumluluk takma adları (aliases) tanımlandı.
   - Kokpit üst barına `localStorage` kayıtlı dinamik **[🌐 TR / EN] Dil Değiştirici** butonu eklendi.
3. **Node.js Sanal Sunucu & LAN/Ağ Erişimi (`server.js`):**
   - Eski PowerShell `HttpListener`'ın `localhost` kısıtı ve thread kilitlenmesi sorunları aşıldı.
   - Harici npm paketi gerektirmeyen saf Node.js sunucusu **`0.0.0.0:9999`** dinleyecek şekilde yazıldı.
   - Yerel ağdaki Ethernet ve Wi-Fi IPv4 adreslerini otomatik algılar. Ağdaki cep telefonları, tabletler ve teknisyen laptopları web arayüzüne tam yetkiyle erişebilir.
   - Windows Güvenlik Duvarı'nda 9999 TCP kuralını açan [`Launch-NodeServer.cmd`](Launch-NodeServer.cmd) hazırlandı.
4. **Çevrimdışı Kurumsal Debloat & Gizlilik Çekirdeği (`Modules/SysForgeDebloatCore.ps1`):**
   - %100 çevrimdışı ve sıfır dış bağımlılıkla çalışan debloat motoru yazıldı:
     - Windows 11 Copilot & Recall AI kalkanı (`disable-ai`)
     - Telemetri & DiagTrack engelleyici (`disable-telemetry`)
     - Klasik Sağ Tık Menüsü, 'Görevi Sonlandır', Dosya Uzantıları (`optimize-ui`)
     - Düşük gecikmeli oyun, MMCSS önceliği ve Nihai Performans güç modu (`optimize-gaming`)
     - Hosts dosyası 0.0.0.0 telemetri kalkanı (`block-hosts`)
     - Windows Update 2 yıl büyük özellik erteleme (`wu-delay`)
     - Tek Tıkla Master Debloat (`apply-all-debloat`)
5. **Dashboard Entegrasyonu:**
   - Web kokpitine **"SysForge Enterprise Debloat & Privacy Suite"** yönetim kartı eklendi.
   - `dashboard.html` ve `Modules/dashboard.html` birebir senkronize edildi.
6. **Masaüstü WPF Entegrasyonu & v6.1.0 Derlemesi:**
   - [`ToolkitEngine.cs`](SysForgeStudio/Services/ToolkitEngine.cs) güncellenerek Node sunucusunu otomatik tespit edip başlatması ve durdurulduğunda süreçleri temizlemesi sağlandı.
   - Sürüm numarası `v6.1.0.0`'a yükseltildi.
   - `dotnet build -c Release` ve `-c Debug` 0 hata ile derlendi.
   - Kök dizine tek tıkla açan [`Launch-SysForgeStudio.cmd`](Launch-SysForgeStudio.cmd) yerleştirildi.
7. **WinoxIT Projesinin Ayrılması:**
   - Kullanıcı talimatı doğrultusunda WinoxIT bağımsız bir proje olarak `../WinoxIT` dizinine taşındı ve kendi yol haritası oluşturuldu. Bu depoda sadece SysForge Studio geliştirilmektedir.

---

## 🗂️ 2. Kritik Dosya Rehberi

| Dosya | Açıklama |
| :--- | :--- |
| [`ROADMAP.md`](ROADMAP.md) | Detaylı tersine mühendislik raporu, pazar matrisi ve tamamlanan/kalan yol haritası. |
| [`server.js`](server.js) | Node.js Sanal Sunucu & LAN Ağ Geçidi (0.0.0.0:9999). |
| [`Modules/SysForgeDebloatCore.ps1`](Modules/SysForgeDebloatCore.ps1) | 100% Çevrimdışı PowerShell Debloat ve Gizlilik Çekirdeği. |
| [`dashboard.html`](dashboard.html) | Ana Web Kokpiti (TR/EN dil seçici & Debloat Suite dahil). |
| [`Modules/dashboard.html`](Modules/dashboard.html) | Web Kokpitinin yedek/modül içi kopyası (sürekli ana kopya ile eşit tutulur). |
| [`Launch-SysForgeStudio.cmd`](Launch-SysForgeStudio.cmd) | WPF uygulamasını Yönetici olarak Release sürümünden açan başlatıcı. |
| [`Launch-NodeServer.cmd`](Launch-NodeServer.cmd) | Güvenlik duvarını yapılandırıp Node sunucusunu başlatan konsol. |
| [`Launch-WebDashboard.cmd`](Launch-WebDashboard.cmd) | Web konsolunu başlatan akıllı başlatıcı (Node varsa Node'u, yoksa PS köprüsünü açar). |
| [`SysForgeStudio/bin/Release/net48/SysForgeStudio.exe`](SysForgeStudio/bin/Release/net48/SysForgeStudio.exe) | Derlenmiş en güncel kararlı Release çalıştırılabilir dosyası. |

---

## 💻 3. Evde Projeyi Çalıştırma ve Test Etme

Evdeki bilgisayarınıza geçip depoyu `git pull` ile çektikten sonra:

### Adım 1: Masaüstü Uygulamasını Başlatma
Kök dizindeki **`Launch-SysForgeStudio.cmd`** dosyasına sağ tıklayıp Yönetici olarak çalıştırın (veya çift tıklayın, zaten UAC onayı isteyecektir).
- Açılan WPF arayüzünde tüm sistem ve donanım panellerini görebilirsiniz.
- Sol menüden *"Web Dashboard'u Başlat & Aç"* dediğinizde arka planda `server.js`'i ayağa kaldırıp varsayılan tarayıcınızda kokpiti açacaktır.

### Adım 2: Web Konsolu & LAN Erişimini Başlatma
Doğrudan web sunucusunu açmak isterseniz:
```powershell
.\Launch-NodeServer.cmd
```
Konsolda yerel ve ağ IP adresleriniz listelenecektir:
- Yerel: `http://localhost:9999/dashboard.html`
- Ağdaki Telefon/Tablet/PC: `http://<EV_AGI_IP>:9999/dashboard.html`

### Adım 3: Yeni Bir Değişiklik Sonrası Derleme (Build)
Eğer C# veya XAML tarafında bir değişiklik yaparsanız terminalden:
```powershell
dotnet build SysForgeStudio\SysForgeStudio.csproj -c Release
```
komutunu vermeniz yeterlidir. `dashboard.html`, `server.js` ve `Modules\` klasörleri otomatik olarak `bin\Release\net48\` içerisine kopyalanır.

---

## 🎯 4. Evde Tamamlanan Hedefler (Faz 3 & Faz 4 ✅)

1. **Hardware Drift (Donanım Değişiklik Dedektörü) Tamamlandı ✅:**
   - [`Modules/SysForgeHardwareDriftCore.ps1`](Modules/SysForgeHardwareDriftCore.ps1) geliştirildi.
   - Bilgisayarın anakart, BIOS UUID, CPU ID, RAM yuvaları ve seri numaraları, Disk seri numaraları, GPU ve MAC adreslerinden kriptografik SHA-256 donanım parmak izi üretilir.
   - İlk durum (`save-baseline`) kaydedilir, sonraki kontrollerde (`compare`) değişen veya sökülen parçalar saniyeler içinde tespit edilir ve kırmızı alarm verilir.
   - HTML ekspertiz raporu (`generate-report`) oluşturulur.
   - `server.js` ve `dashboard.html`'e canlı kart ve API uç noktaları entegre edildi.
2. **Push Agent & LAN Filo Keşfi Tamamlandı ✅:**
   - `/api/lan-agent/discover` ve `/api/lan-agent/dispatch` API'leri yazıldı.
   - Kokpitte Ağ Merkezi altına "Ağdaki Cihazları Keşfet (LAN Fleet)" paneli eklendi; yerel ağdaki IP'lere tek tıkla Ping testi veya uzaktan SysForge sağlık taraması yapılabilir.
3. **Edge & OneDrive İsteğe Bağlı Temizlik Tamamlandı ✅:**
   - [`Modules/SysForgeDebloatCore.ps1`](Modules/SysForgeDebloatCore.ps1) içerisine `remove-onedrive`, `restore-onedrive` ve `debloat-edge` işlevleri eklendi.
   - Web kokpitindeki Debloat Suite içerisine bu işlemler tek tık butonları olarak yerleştirildi.
4. **Katılımsız (Unattended) ISO / WIM İmaj Hazırlama Modülü Tamamlandı ✅:**
   - [`Modules/SysForgeIsoCore.ps1`](Modules/SysForgeIsoCore.ps1) yazıldı.
   - Windows 11 TPM 2.0, SecureBoot, RAM ve CPU kontrollerini bypass eden `autounattend.xml` yanıt dosyası üretici eklendi.
   - DISM WIM mount/unmount ve `SetupComplete.cmd` ilk açılış script enjeksiyon motoru entegre edildi.
   - `server.js` API uç noktaları (`/api/iso-builder/generate-xml`, `/mount`, `/unmount`, `/inject`) ve web kokpitine interaktif yönetim kartı yerleştirildi.
5. **Web Kokpiti Mobil HUD Teması & Portre İnce Ayarları Tamamlandı ✅:**
   - Küçük ekranlı akıllı telefonlar ve tabletler için responsive media query kuralları eklendi (`@media (max-width: 768px)` ve `480px`).
   - Kart akışları tek sütuna dengelendi, dokunmatik buton paddingleri ve başlık ölçeklemeleri optimize edildi.

---

## 🚀 5. Proje Durumu ve Genel Özet
*Tüm hedefler (Faz 1, Faz 2, Faz 3 ve Faz 4) başarıyla tamamlanmış, `SysForgeStudio.exe` Release sürümü 0 hata ile derlenmiş ve test edilmiştir.*
