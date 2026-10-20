# -*- coding: utf-8 -*-
import json, re

# Comprehensive Turkish dictionary for SysForge Studio UI
translations = {
    # Long descriptive cards & actions
    "Automatically run a complete background system repair sequence: SFC file scans, DISM component store recovery, CHKDSK disk integrity scan, active driver validation check, network stack rebuild (Winsock, IP, DNS flush), temp junk clearance, and full health report creation.":
        "Tam arka plan sistem onarım dizisini otomatik olarak çalıştırın: SFC dosya taraması, DISM bileşen deposu kurtarma, CHKDSK disk bütünlüğü taraması, sürücü doğrulama, ağ yığını yenileme (Winsock, IP, DNS temizliği), geçici çöp temizliği ve tam durum raporu.",
    
    "Click the \"Retrieve License Keys\" button above to decrypt system product keys from the Windows Registry, SLMGR license records, and Microsoft Office software protection logs.":
        "Windows Kayıt Defteri, SLMGR lisans kayıtları ve Microsoft Office koruma günlüklerindeki ürün lisans anahtarlarını çözmek için yukarıdaki \"Lisans Anahtarlarını Al\" düğmesine tıklayın.",
    
    "Hello! I'm your AI Diagnostics Assistant. I can help you analyze your system, find issues, and suggest solutions. Ask me anything about your system...":
        "Merhaba! Ben SysForge Yapay Zekâ Tanılama Asistanınızım. Sisteminizi analiz etmenize, sorunları bulmanıza ve çözümler üretmenize yardımcı olabilirim. Sisteminizle ilgili her şeyi sorabilirsiniz...",
    
    "Select a core topic from the left side panel to view detailed diagnostic pathways, root cause explanations, and run automated recovery scripts.":
        "Ayrıntılı tanılama adımlarını ve kök neden açıklamalarını görmek, otomatik kurtarma betiklerini çalıştırmak için sol menüden bir konu seçin.",
    
    "Select a mock system error image or drag-and-drop a crash screen (BSOD, application error, updates) for cognitive AI analysis.":
        "Yapay zekâ incelemesi için örnek hata görseli seçin veya çökme ekranını (mavi ekran, uygulama hatası ya da güncelleme) sürükleyip bırakın.",
    
    "Click \"Load Apps\" to scan the Windows Registry and list all installed programs with their version and publisher info.":
        "Windows Kayıt Defterini tarayıp tüm yüklü programları sürüm ve yayıncı bilgileriyle listelemek için \"Uygulamaları Yükle\" düğmesine tıklayın.",
    
    "Deep clean junk files, temp folders, old logs, recycle bin, and browser caches to free up disk space":
        "Disk alanı açmak için gereksiz dosyaları, geçici klasörleri, eski günlükleri, Geri Dönüşüm Kutusu'nu ve tarayıcı önbelleklerini temizleyin.",
    
    "Create an offline configuration snapshot of local drivers, registry variables, active services, startup items, and security policies.":
        "Yerel sürücülerin, Kayıt Defteri değişkenlerinin, etkin hizmetlerin, başlangıç öğelerinin ve güvenlik ilkelerinin çevrimdışı anlık görüntüsünü oluşturun.",
    
    "Click \"Load Disk Info\" to retrieve drive health, SMART data, and usage statistics for all connected drives.":
        "Bağlı tüm sürücülerin sağlık durumunu, SMART verilerini ve kullanım istatistiklerini almak için \"Disk Bilgilerini Yükle\" düğmesine tıklayın.",
    
    "Click \"Load Full Info\" to scan and display your complete hardware & software profile in real time.":
        "Tam donanım ve yazılım profilinizi anlık olarak tarayıp görüntülemek için \"Tüm Bilgileri Yükle\" düğmesine tıklayın.",
    
    "Click \"Load Full Info\" to scan and display your complete hardware &amp; software profile in real time.":
        "Tam donanım ve yazılım profilinizi anlık olarak tarayıp görüntülemek için \"Tüm Bilgileri Yükle\" düğmesine tıklayın.",
    
    "We recommend running the optimizations on the right to improve system performance and prevent future issues.":
        "Sistem performansını artırmak ve olası sorunları önlemek için sağdaki iyileştirmeleri çalıştırmanızı öneririz.",
    
    "Run SFC, DISM, Windows Update health check, Store verification, and app crash analysis in one click.":
        "SFC, DISM, Windows Update durum denetimi, Mağaza doğrulaması ve uygulama çökme analizini tek tıkla çalıştırın.",
    
    "Click \"Load Tasks\" to view all active Windows scheduled tasks, including OEM and maintenance jobs.":
        "OEM ve bakım görevleri dahil tüm aktif Windows zamanlanmış görevlerini görüntülemek için \"Görevleri Yükle\" düğmesine tıklayın.",
    
    "AI has scanned 1,248 system components and found 3 potential issues that may require attention.":
        "Yapay zekâ 1.248 sistem bileşenini taradı ve dikkat gerektirebilecek 3 olası durum belirledi.",
    
    "Scan Windows Integrity - PC Health - Store Health - Update Agent - App archives.":
        "Windows Bütünlüğü - PC Durumu - Mağaza Durumu - Güncelleme Aracısı - Uygulama Arşivlerini Tarayın.",
    
    "Over 1,500 enterprise nodes reported printer driver crash incidents immediately following Windows Update package":
        "Windows güncelleme paketinin ardından 1.500'den fazla kurumsal bilgisayarda yazıcı sürücüsü çökmesi bildirildi.",
    
    "Comprehensive interactive database of Windows repair protocols, error codes, WMI commands & AI-driven fixes":
        "Windows onarım yöntemleri, hata kodları, WMI komutları ve yapay zekâ çözümleri için kapsamlı etkileşimli kaynak.",
    
    "Launch offline diagnostic suites, backup tools, and partition managers directly from the toolkit catalog":
        "Çevrimdışı tanılama paketlerini, yedekleme araçlarını ve bölüm yöneticilerini araç kataloğundan doğrudan başlatın.",
    
    "Describe the repair script you need (e.g. 'Reset firewall to default', 'Clear update downloads')...":
        "İhtiyacınız olan onarım betiğini açıklayın (ör. 'Güvenlik duvarını varsayılana döndür', 'İndirilen güncellemeleri temizle')...",
    
    "Click \"Load Startup Items\" to view and manage all startup entries from Windows Registry.":
        "Windows Kayıt Defterindeki tüm başlangıç öğelerini görüntülemek ve yönetmek için \"Başlangıç Öğelerini Yükle\" düğmesine tıklayın.",
    
    "Analyze Windows minidump files to identify Blue Screen of Death causes and stop codes":
        "Mavi Ekran (BSOD) nedenlerini ve durdurma kodlarını belirlemek için Windows bellek dökümü (minidump) dosyalarını inceleyin.",
    
    "Open common registry paths, Windows 11 HUD customizer, NTFS cache optimizer and more":
        "Sık kullanılan Kayıt Defteri yollarını, Windows 11 HUD özelleştiricisini, NTFS önbellek iyileştiricisini ve fazlasını açın.",
    
    "Choose an error template from the dropdown to run cognitive OCR diagnostic scans.":
        "OCR tanılama taraması çalıştırmak için açılır listeden bir hata şablonu seçin.",
    
    "Scan Windows Event Logs - Detect Critical Errors - Auto-repair & Apply fixes.":
        "Windows Olay Günlüklerini tarayın - Kritik Hataları Belirleyin - Otomatik Onarın ve Çözümleri Uygulayın.",
    
    "Scan Windows Event Logs - Detect Critical Errors - Auto-repair &amp; Apply fixes.":
        "Windows Olay Günlüklerini tarayın - Kritik Hataları Belirleyin - Otomatik Onarın ve Çözümleri Uygulayın.",
    
    "Toggle system-level Windows customizations instantly with real-time registry tweaks and explorer auto-restart":
        "Windows ayarlarını ve kayıt defteri değişikliklerini anında uygulayın ve Dosya Gezginini otomatik yeniden başlatın.",
    
    "Real-time deep analysis of active network sockets, protocol distributions, and socket owners":
        "Etkin ağ yuvalarını, protokol dağılımlarını ve sahiplerini anlık ve ayrıntılı inceleyin.",
    
    "Enable TRIM to maintain optimal performance. Consider firmware update for better stability.":
        "En iyi performansı korumak için TRIM'i etkinleştirin. Daha fazla kararlılık için ürün yazılımı (firmware) güncellemesini değerlendirin.",
    
    "Repair & reset Windows Update services. Fix update errors and restore functionality.":
        "Windows Update hizmetlerini onarın ve sıfırlayın. Güncelleme hatalarını giderip işlevselliği geri getirin.",
    
    "Repair &amp; reset Windows Update services. Fix update errors and restore functionality.":
        "Windows Update hizmetlerini onarın ve sıfırlayın. Güncelleme hatalarını giderip işlevselliği geri getirin.",
    
    "Scan and update Windows software (Winget) and hardware drivers (Windows Update agent)":
        "Windows yazılımlarını (Winget) ve donanım sürücülerini (Windows Update) tarayıp güncelleyin.",
    
    "The start type of the Background Intelligent Transfer Service service was changed.":
        "Arka Plan Akıllı Aktarım Hizmetinin (BITS) başlangıç türü değiştirildi.",
    
    "Click \"Analyze BSOD Dumps\" to scan Windows minidump folder for crash reports...":
        "Çökme raporları için Windows minidump klasörünü taramak üzere \"Mavi Ekran Dökümlerini Analiz Et\" düğmesine tıklayın...",
    
    "Create, view, and manage Windows System Restore Points for safe system rollback":
        "Güvenli sistem geri dönüşü için Windows Sistem Geri Yükleme Noktaları oluşturun ve yönetin.",
    
    "Click scan to check OS restore points, UAC state, and Store health.":
        "Sistem geri yükleme noktalarını, UAC durumunu ve Mağaza sağlığını denetlemek için taramaya tıklayın.",
    
    "Paste custom winget IDs here (comma-separated or newline-separated, e.g. Google.Chrome, 7zip.7zip)...":
        "Özel winget paket kimliklerini buraya yapıştırın (virgülle veya satırla ayrılmış, ör. Google.Chrome, 7zip.7zip)...",
    
    "Windows product keys, Office activation status, and digital license information retrieval":
        "Windows ürün anahtarları, Office etkinleştirme durumu ve dijital lisans bilgilerini görüntüleme.",
    
    "AI Correlation Engine linked Spooler failure to active driver regression automatically.":
        "Yapay zekâ ilişkilendirme motoru, Yazdırma Biriktiricisi arızasını aktif sürücü sorunuyla otomatik olarak ilişkilendirdi.",
    
    "Your PC is running perfectly optimized with zero detected system issues!":
        "Bilgisayarınız mükemmel şekilde optimize edilmiş durumda; sıfır sistem sorunu tespit edildi!",
    
    "For best performance, use an external SSD or high-speed storage device.":
        "En iyi performans için harici bir SSD veya yüksek hızlı depolama aygıtı kullanın.",
    
    "Click Refresh to load all running processes sorted by RAM usage.":
        "Bellek kullanımına göre sıralanmış çalışan tüm işlemleri yüklemek için Yenile'ye tıklayın.",
    
    "Avoid charging above 80% for daily use to extend cell lifespan":
        "Hücre ömrünü uzatmak için günlük kullanımda %80'in üzerinde şarj etmekten kaçının.",
    
    "Set DNS to Google Public DNS for faster & secure browsing.":
        "Daha hızlı ve güvenli gezinme için DNS'i Google Genel DNS olarak ayarlayın.",
    
    "Set DNS to Google Public DNS for faster &amp; secure browsing.":
        "Daha hızlı ve güvenli gezinme için DNS'i Google Genel DNS olarak ayarlayın.",
    
    "Enter app name to search in Winget (e.g. VLC, WinRAR, Python)":
        "Winget'te aramak için uygulama adını girin (ör. VLC, WinRAR, Python)",
    
    "Real-time thermal telemetry, visual insights and processor core temperature diagnostics.":
        "Gerçek zamanlı sıcaklık telemetrisi, görsel grafikler ve işlemci çekirdek sıcaklığı tanılaması.",
    
    "Remove unnecessary Windows pre-installed apps, bloatware, and telemetry services safely":
        "Gereksiz Windows ön yüklü uygulamalarını, bloatware'leri ve telemetri servislerini güvenle kaldırın.",
    
    "The application-specific permission settings do not grant Local Activation permission.":
        "Uygulamaya özgü izin ayarları Yerel Etkinleştirme izni vermiyor.",
    
    "Comprehensive real-time hardware health profiles and Windows software integrity checks":
        "Kapsamlı gerçek zamanlı donanım sağlık profilleri ve Windows yazılım bütünlüğü denetimleri.",
    
    "View and manage Windows Firewall rules, inbound/outbound policies and configurations":
        "Windows Güvenlik Duvarı kurallarını, gelen/giden bağlantı ilkelerini görüntüleyin ve yönetin.",
    
    "Select any connection row to inspect details and run actions.":
        "Ayrıntıları incelemek ve işlem yapmak için herhangi bir bağlantı satırını seçin.",
    
    "Stop, clear and restart spooler service and fix print queue.":
        "Yazdırma biriktiricisini durdurun, temizleyin, yeniden başlatın ve yazdırma kuyruğunu onarın.",

    # Menu sections and headers
    "Module 1: AI Diagnostic Engine": "Modül 1: Yapay Zekâ Tanılama Motoru",
    "Module 2: Hardware Diagnostics": "Modül 2: Donanım Tanılaması",
    "Module 3: Windows Repair": "Modül 3: Windows Onarımı",
    "Module 4: Network Operations": "Modül 4: Ağ İşlemleri",
    "Module 5: Security": "Modül 5: Güvenlik",
    "Module 6: Backup/Recovery": "Modül 6: Yedekleme ve Kurtarma",
    "Module 7: Performance": "Modül 7: Performans",
    "Module 8: Emergency Recovery": "Modül 8: Acil Kurtarma",
    "Module 9: IT Admin": "Modül 9: BT Yönetimi",
    "Module 10: AI Knowledge Base": "Modül 10: Yapay Zekâ Bilgi Bankası",

    # Buttons and Action Labels
    "Run System File Checker (SFC /scannow)": "Sistem Dosyası Denetleyicisini Çalıştır (SFC /scannow)",
    "Repair Component Store (DISM /RestoreHealth)": "Bileşen Deposunu Onar (DISM /RestoreHealth)",
    "Check Disk for Errors (chkdsk /f)": "Diski Hatalara Karşı Denetle (chkdsk /f)",
    "Reset Windows Update Services": "Windows Güncelleme Hizmetlerini Sıfırla",
    "Repair Windows Store & Packages": "Windows Mağaza ve Paketlerini Onar",
    "Clear Spooler & Restart Service": "Yazdırma Biriktiricisini Temizle ve Başlat",
    "Reset Winsock & IP Configuration": "Winsock ve IP Yapılandırmasını Sıfırla",
    "Flush DNS Cache & Register DNS": "DNS Önbelleğini Temizle ve Yeniden Kaydet",
    "Reset Windows Firewall to Defaults": "Windows Güvenlik Duvarını Varsayılana Sıfırla",
    "Clear Windows Event Logs": "Windows Olay Günlüklerini Temizle",
    "Clean Temporary Files": "Geçici Dosyaları Temizle",
    "Clean Browser Cache & Temp": "Tarayıcı Önbelleğini ve Geçici Verileri Temizle",
    "Optimize Windows Performance": "Windows Performansını İyileştir",
    "Enable Ultimate Performance Mode": "Nihai Performans Modunu Etkinleştir",
    "Disable Windows Telemetry & Diagnostic Data": "Windows Telemetri ve Tanılama Verilerini Kapat",
    "Disable Cortana & Web Search": "Cortana ve Web Aramasını Kapat",
    "Create System Restore Point": "Sistem Geri Yükleme Noktası Oluştur",
    "Manage System Restore Points": "Sistem Geri Yükleme Noktalarını Yönet",
    "Backup User Profile (RoboCopy)": "Kullanıcı Profilini Yedekle (RoboCopy)",
    "View System Information": "Sistem Bilgilerini Görüntüle",
    "Analyze BSOD Crash Dumps": "Mavi Ekran (BSOD) Dökümlerini Analiz Et",
    "Open Windows Tools": "Windows Araçlarını Aç",
    "Open Device Manager": "Aygıt Yöneticisini Aç",
    "Open Disk Management": "Disk Yönetimini Aç",
    "Open Task Scheduler": "Görev Zamanlayıcıyı Aç",
    "Open Services Management": "Hizmetler Yönetimini Aç",
    "Open Registry Editor": "Kayıt Defteri Düzenleyicisini Aç",
    "Open Group Policy Editor": "Grup İlkesi Düzenleyicisini Aç",
    "Open Event Viewer": "Olay Görüntüleyicisini Aç",
    "Open Network Connections": "Ağ Bağlantılarını Aç",
    "Scan for Corrupted Files": "Bozuk Dosyaları Tara",
    "Scan for Malware & Viruses": "Kötü Amaçlı Yazılımları Tara",
    "One-Click Super Repair": "Tek Tıkla Süper Onarım",
    "Run Super Repair Sequence": "Süper Onarım Dizisini Çalıştır",
    "Super Repair Running...": "Süper Onarım Çalışıyor...",
    "Super Repair Completed": "Süper Onarım Tamamlandı",
    "Run Full Diagnostics Scan": "Tam Tanılama Taramasını Çalıştır",
    "Export Diagnostic Report": "Tanılama Raporunu Dışa Aktar",
    "Download Report (HTML)": "Raporu İndir (HTML)",
    "Download Report (PDF)": "Raporu İndir (PDF)",
    "Apply All Recommended Fixes": "Önerilen Tüm Düzeltmeleri Uygula",
    "Apply Fix": "Düzeltmeyi Uygula",
    "Fix Issue": "Sorunu Gider",
    "Ignore": "Yoksay",
    "Resolved": "Çözüldü",
    "Unresolved": "Çözülmedi",
    "Pending": "Bekliyor",
    "In Progress": "Devam Ediyor",
    "High Severity": "Yüksek Öncelik",
    "Medium Severity": "Orta Öncelik",
    "Low Severity": "Düşük Öncelik",
    "Critical Error": "Kritik Hata",
    "System Warning": "Sistem Uyarısı",
    "Healthy": "Sağlıklı",
    "Optimal": "İdeal",
    "Degraded": "Performans Düşük",
    "Corrupted": "Bozuk",
    "Attention Required": "Dikkat Gerekiyor",
    
    # Navigation and Badges
    "Predictive Radar": "Öngörülü Radar",
    "AI Engine": "Yapay Zekâ Motoru",
    "Twin Snapshot": "Sistem İkizi Anlık Görüntüsü",
    "Self-Healing Platform": "Otomatik Onarım Platformu",
    "Live Diagnostics": "Canlı Tanılama",
    "Smart Suggestions": "Akıllı Öneriler",
    "System Telemetry": "Sistem Telemetrisi",
    "Hardware Probes": "Donanım Algılayıcıları",
    "Network Topology": "Ağ Topolojisi",
    "Storage Analysis": "Depolama Analizi",
    "Memory Allocations": "Bellek Dağılımı",
    "Running Services": "Çalışan Hizmetler",
    "Startup Entries": "Başlangıç Girdileri",
    "Event Log Monitor": "Olay Günlüğü İzleyicisi",
    "Crash Dumps": "Çökme Dökümleri",
    "Security Policies": "Güvenlik İlkeleri",
    "System Restore": "Sistem Geri Yükleme",
    "RoboCopy Backup": "RoboCopy Yedekleme",
    "Performance Boost": "Performans Artışı",
    "Junk Cleanup": "Gereksiz Dosya Temizliği",
    "Bloatware Removal": "Gereksiz Uygulama Temizliği",
    "Power Plans": "Güç Planları",
    "Game Optimizations": "Oyun İyileştirmeleri",
    "Terminal Console": "Terminal Konsolu",
    "Command Palette": "Komut Paleti",
    "Application Catalog": "Uygulama Kataloğu",
    "Custom Bundler": "Özel Paket Oluşturucu",
    "Software Updates": "Yazılım Güncellemeleri",
    "Driver Center": "Sürücü Merkezi",
    "Emergency WinRE": "Acil Kurtarma (WinRE)",
    "Repair Catalog": "Onarım Kataloğu",
    "Knowledge Base": "Bilgi Bankası",
    "Color Themes": "Renk Temaları",
    "Light Mode": "Açık Tema",
    "Dark Mode": "Koyu Tema",
    "Cyberpunk Theme": "Siberpunk Tema",
    "Midnight Theme": "Gece Yarısı Teması",
    "Matrix Theme": "Matrix Teması",
    "Synthwave Theme": "Synthwave Teması",
    "Nord Theme": "Nord Teması",
    "Dracula Theme": "Dracula Teması"
}

# Update dashboard.html and Modules/dashboard.html
for file_path in ['dashboard.html', 'Modules/dashboard.html']:
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Find applyTurkishDashboardLabels
    marker = "Object.assign(labels, {"
    idx = content.find(marker)
    if idx != -1:
        # Build JS dictionary entries
        entries = []
        for k, v in translations.items():
            # escape single quotes
            escaped_k = k.replace("'", "\\'")
            escaped_v = v.replace("'", "\\'")
            entries.append(f"    '{escaped_k}':'{escaped_v}'")
        
        insert_code = marker + "\n" + ",\n".join(entries) + ",\n"
        content = content[:idx] + insert_code + content[idx + len(marker):]
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Successfully updated {file_path} with {len(translations)} new Turkish phrases!")
    else:
        print(f"Marker not found in {file_path}")
