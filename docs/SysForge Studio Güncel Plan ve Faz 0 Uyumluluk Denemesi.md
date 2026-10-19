# SysForge Studio: Güncel Plan ve Faz 0 Uyumluluk Denemesi

*Hazırlayan: Claude · 19 Ekim 2026 · Kapsam: onaylanan kararlar, WPF-UI düzeltmesi, Faz 0 deneme planı ve güncel yol haritası*

## Onaylanan kararlar

- **Platform:** Windows 7 SP1'den Windows 11'e, x86 ve x64, tek EXE.
- **Altyapı:** C# + WPF, **.NET Framework 4.8**, "AnyCPU" derleme. Python, PowerShell ve BAT parçaları aşamalı olarak C#'a taşınır ve silinir.
- **Tasarım:** Önce WPF-UI denenir. Eski Windows'ta çalışmazsa mevcut `Pt*` stilleri WPF-UI görünümüne yaklaştırılır.
- **Test:** GitHub Actions ile otomatik derleme, Win7 SP1, Win8.1, Win10 ve Win11 sanal makinelerinde elle doğrulama.
- **Ek kurulum:** Win10 1903+ ve Win11'de gerekmez. Eski Win10, Win8.1 ve Win7 SP1'de .NET 4.8 bir kez kurulur.

## WPF-UI hakkında düzeltme

Önceki belgede "WPF-UI'dan vazgeçiyoruz" yazıyordu. Bu doğrulanmadan yazılmış bir sonuçtu ve geçersiz.

- Kütüphanenin belgeleri .NET 10/9/8'in yanında **.NET Framework 4.6.2 / 4.7.2 / 4.8.1** hedeflerini listeliyor. NuGet sayfası da `net462` uyumluluğunu gösteriyor. Yani .NET Framework 4.8 projesinde kullanılabilir.
- **Doğrulanmamış olan:** Windows 7 ve 8'de gerçekten düzgün çalışıp çalışmadığı. Belgeler işletim sistemi desteğini açıkça yazmıyor. Mica ve Acrylic zaten Win11'e özgü, eski sistemlerde düz arka plana düşmesi beklenir. Özel başlık çubuğunun (`FluentWindow`) Win7'deki davranışı bilinmiyor.
- Paylaşılan Store bağlantısı (WPF Gallery, `9ndlx60wx4kq`) Microsoft'un .NET 9 ve sonrasındaki yerleşik Fluent temasını gösteriyor. O tema .NET 9 gerektirdiği için Win7/8'de kullanılamaz. WPF-UI ayrı bir kütüphanedir.

Bu yüzden karar tahmine değil, Faz 0'daki denemeye bırakıldı.

## Faz 0: Hazırlık ve 1 günlük uyumluluk denemesi

### A. Depo hazırlığı

1. Mevcut durumu `legacy-modules-final` etiketiyle yedekle.
2. `gh` ile milestone ve issue'ları aç (Faz 1-6).
3. `Modules/ITTechService/license.json` ve `backups/Sentinel_Yedek_*.db` dosyalarını izlemeden çıkar. Git geçmişinde de durduklarından geçmiş temizliği (`git filter-repo`) ayrıca kararlaştırılır.
4. `SysForgeStudio.wsb` dosyasındaki eski yolu (`C:\Users\BT\...`) ve olmayan `Run_Modern_Toolkit.bat` hedefini düzelt.
5. `Archive/` zaten `.gitignore`'da ama dosyaları izleniyor, izlemeden çıkar.

### B. Uyumluluk denemesi (`spike/net48-wpfui` branch'i)

**Hazırlık (Claude):**

- `SysForgeStudio.csproj`'u `net48` hedefine çevir: `Nullable` ve `ImplicitUsings` ayarlarını kaldır, `LangVersion` ayarla, gereken uyumluluk (polyfill) paketlerini ekle.
- `System.Management` ve `ServiceController` zaten Framework'te yerleşik, paket referansları kalkar.
- `Microsoft.Data.Sqlite` paketinin net48'de x86 ve x64'te çalışıp çalışmadığını doğrula. Çalışmazsa alternatif (`System.Data.SQLite`) denenir.
- WPF-UI'ı ekle, bir deneme penceresi hazırla: `FluentWindow`, `NavigationView`, kart, buton, `DataGrid`, ikonlar, açık/koyu tema geçişi.
- GitHub Actions iş akışı: Windows sunucusunda derle, EXE'yi çıktı olarak yayınla.

**Doğrulama (siz):**

Çıktı EXE'yi şu makinelerde çalıştırıp sonucu (ekran görüntüsüyle) bildirirsiniz:

| Makine | Beklenti |
| --- | --- |
| Win7 SP1 x86 | Açılır, ana pencere ve kontroller görünür |
| Win8.1 x64 | Açılır, ana pencere ve kontroller görünür |
| Win10 x64 | Tam özellikli çalışır |
| Win11 x64 | Mica gibi efektler de çalışır |

### Kontrol listesi (her makinede)

- Uygulama açılıyor mu, hata penceresi çıkıyor mu?
- Ana pencere, başlık çubuğu ve kenar boşlukları düzgün mü?
- Menü ikonları görünüyor mu?
- Açık/koyu tema geçişi çalışıyor mu?
- Basit bir WMI sorgusu (donanım bilgisi) çalışıyor mu?
- SQLite veritabanı okuma ve yazma çalışıyor mu?
- Yerel web paneli (`HttpListener`, localhost) açılıyor mu?
- Yüksek DPI ekranda bulanıklık veya taşma var mı?

### Karar kuralı

| Sonuç | Karar |
| --- | --- |
| Her makinede kontrol listesi geçti | WPF-UI ile devam |
| Sadece efektler (Mica vb.) eski sistemde düz renge düşüyor | Kabul edilebilir, WPF-UI ile devam |
| `FluentWindow` / özel başlık çubuğu Win7'de bozuk, kontroller sağlam | WPF-UI kontrolleri + standart pencere çerçevesi |
| Kontroller Win7/8'de bozuk veya açılmıyor | `Pt*` stilleri WPF-UI görünümüne yaklaştırılır |

İlk iki satırda sorun yoksa `net48` geçişi de onaylanmış olur. Üçüncü ve dördüncü satırlarda altyapı yine `net48` kalır, yalnızca arayüz yaklaşımı değişir. Uygulamanın kendisi hiç açılmıyorsa (SQLite veya başka bir bağımlılık yüzünden) önce o çözülür.

## Güncel yol haritası

| Faz | İçerik |
| --- | --- |
| **0. Hazırlık ve deneme** | Yukarıdaki A ve B bölümleri |
| **1. Envanter eşlemesi** | Her PS1/Python/CMD işlevi için "C#'ta var / eksik / gereksiz" tablosu, ek kolon: hangi Windows sürümlerinde çalışır |
| **2. Tasarım sistemi** | Faz 0 sonucuna göre WPF-UI veya `Pt*`, ortak `tokens.json`, vektör ikon seti |
| **3. Eksik özelliklerin entegrasyonu** | Rol/izin, rapor üretimi, ekran arşivi, agent, (sonra) uzaktan kontrol |
| **4. Web paneli birleştirme** | Aynı token/CSS, güvenli kimlik doğrulama (hash'li şifre, oturum anahtarı, varsayılan yerel erişim) |
| **5. Temizlik** | `Modules/`, `Archive/` ve `LegacyModulesView` kaldırma, isimlendirme, README, testler. Eşleme tablosu onaylanmadan hiçbir şey silinmez |
| **6. Yeni özellikler ve yayın** | Komut paleti, güncelleme, sağlık skoru, `gh release` ile yayın (v7.0) |

## Riskler

- **Win7 güncellemeleri:** Yamasız Win7'de .NET 4.8 kurulumu ve TLS 1.2 (GitHub güncellemesi) sorun çıkarabilir. Deneme makinesinde yama durumu not edilmeli.
- **Geri taşıma maliyeti:** .NET 8'den Framework 4.8'e geçişte bazı yeni dil ve kütüphane özellikleri uyumluluk paketi gerektirir.
- **Test ortamı:** Derleme ve çalıştırma Claude'un tarafında yapılamıyor (Windows yok). Bu nedenle sonuçlar sizin VM testlerinize ve CI çıktısına bağlı.

## Sıradaki adım

`spike/net48-wpfui` branch'inin hazırlanması. Hazır olunca CI çıktısı EXE'yi VM'lerde deneyip sonuçları paylaşırsınız.
