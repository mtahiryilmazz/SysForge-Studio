# Ultimate Printer Toolkit

Bu paket, klasordeki mevcut yazici onarim araclarinin GUI odakli birlesik surumudur.

## Baslatma

- `Run_Ultimate_Printer_Toolkit.bat` dosyasini yonetici olarak calistirin.
- Alternatif komut: `powershell -NoProfile -ExecutionPolicy Bypass -File .\Ultimate_Printer_Toolkit.ps1`

## Ana Ozellikler

- Yerel ve uzak yazici tanilama
- Uzak PC/IP uzerinden paylasilan yazici tarama
- UNC ile yazici baglama: `\\PCADI\PAYLASIM`
- Add-Printer, PrintUI ve WScript baglanti yontemleri
- 0x0000011b / 0x00000709 / PointAndPrint / RPC uyumluluk duzeltmeleri
- Print Spooler reset ve kuyruk temizligi
- Firewall, Network Discovery, File and Printer Sharing hazirligi
- Servis kontrolu: Spooler, RPC, LanmanServer, LanmanWorkstation, FDResPub, SSDP, UPnP
- Varsayilan yazici yapma, test sayfasi, kuyruk ve ozellik pencereleri
- Yerel yaziciyi paylasima acma
- Driver/port/printer izlerini filtreli temizleme
- Backup/restore snapshot ve HTML rapor
- Guvenli varsayilanlara donus
- LPD/LPR eski yazici ozelliklerini istege bagli acma
- SMB1 ve guest erisim gibi riskli secenekleri ayri onayli calistirma
- Klasordeki eski printer CMD/PS1 araclarini Araclar sekmesinden acma

## Guvenlik Notu

Guest access, SMB1 ve SMB signing gevsetme varsayilan olarak kapali tutulur. Sadece eski cihazlarla zorunlu uyumluluk gerekiyorsa ve etkisini bilerek etkinlestirin. Arac, onemli onarimlardan once otomatik yedek almaya calisir.

## Bilerek Eklenmeyenler

Printer disi veya sistem politikalarini genis olcekte silen yardimci CMD dosyalari ana GUI'ye alinmadi. Bunlar yazici onarim akisinda gereksiz risk olusturabilir.
