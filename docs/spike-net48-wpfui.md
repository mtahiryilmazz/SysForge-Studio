# Faz 0: net48 + WPF-UI uyumluluk denemesi

## Çalıştırma
1. GitHub'da **Actions → Build net48 spike** sonucundan `SysForgeStudio-net48-spike` çıktısını indirin ve zip'ten çıkarın.
2. Test makinesinde `SysForgeStudio.exe --spike` komutuyla açın (yönetici izni ister).
3. **Testleri çalıştır** düğmesine basın, **Açık / Koyu tema** düğmesini deneyin.
4. **Raporu kopyala** ile raporu panoya alın (aynı klasörde `spike_report.txt` de oluşur).

## Test makineleri
Win7 SP1 x86 · Win8.1 x64 · Win10 x64 · Win11 x64 (.NET 4.8 yüklü olmalı).

## Bildirilecekler
- Her makinenin raporu (metin) ve pencerenin ekran görüntüsü.
- Açılmazsa: hata penceresi veya `logs\crash_log_*.log` içeriği.
- Görsel sorunlar: başlık çubuğu, ikonlar, düğme/kart/tablo, tema geçişi.

## Ayrıca normal uygulamayı da deneyin
Parametresiz `SysForgeStudio.exe` ana uygulamayı açar. Açılış ve temel ekranlar hâlâ çalışıyor mu kontrol edin.
