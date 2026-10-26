<#
.SYNOPSIS
    Bugün kurulan tüm AI Skill ve Eklentilerini (Claude Code & Antigravity/Gemini) otomatik kuran PowerShell betiği.

.DESCRIPTION
    Bu script şu bileşenleri hem global olarak hem de çalışma alanına kurar:
    1. Claude Code Marketplaces & Eklentileri:
       - karpathy-skills (andrej-karpathy-skills)
       - ponytail (ponytail, ponytail-audit, ponytail-debt, ponytail-gain, ponytail-help, ponytail-review)
       - ui-ux-pro-max-skill (ui-ux-pro-max)
       - ecc (Everything Claude Code)
    2. Antigravity / Gemini Skills (Global: ~/.gemini/config/skills & Workspace: .agents/skills):
       - karpathy-guidelines
       - ponytail & tüm alt modülleri
       - ui-ux-pro-max
       - replica-* (11 adet reverse-engineering & clone geliştirme skill'i)
       - impeccable (UI/UX Director skill'i)
    3. Global NPM Paketleri:
       - ui-ux-pro-max-cli
#>

[CmdletBinding()]
param (
    [switch]$SkipClaude,
    [switch]$SkipNpm,
    [string]$WorkspaceRoot = $PSScriptRoot
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   🚀 AI Skills & Plugins Otomatik Kurulum Betiği        " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Ön Gereksinim Kontrolleri
$hasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
$hasClaude = [bool](Get-Command claude -ErrorAction SilentlyContinue)
$hasNpm = [bool](Get-Command npm -ErrorAction SilentlyContinue)

if (-not $hasGit) {
    Write-Error "[HATA] 'git' komutu bulunamadı. Lütfen önce Git kurun: https://git-scm.com"
    exit 1
}

# Hedef Dizinler (Antigravity Customization Roots)
$globalGeminiConfigSkills = Join-Path $HOME ".gemini\config\skills"
$globalGeminiSkills = Join-Path $HOME ".gemini\skills"
$workspaceSkills = Join-Path $WorkspaceRoot ".agents\skills"

$destinations = @($globalGeminiConfigSkills, $globalGeminiSkills)
if (Test-Path (Join-Path $WorkspaceRoot ".agents")) {
    $destinations += $workspaceSkills
} else {
    # Eğer .agents yoksa yine de oluşturup workspace içine kuralım
    New-Item -ItemType Directory -Path $workspaceSkills -Force | Out-Null
    $destinations += $workspaceSkills
}

foreach ($dest in $destinations) {
    if (-not (Test-Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
}

# Geçici indirme alanı
$tempDir = Join-Path $env:TEMP ("ai-skills-install-" + [Guid]::NewGuid().ToString().Substring(0, 8))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    Write-Host "[1/5] Git depoları klonlanıyor..." -ForegroundColor Yellow

    $repos = @(
        @{ Name = "karpathy"; Url = "https://github.com/forrestchang/andrej-karpathy-skills.git" },
        @{ Name = "ponytail"; Url = "https://github.com/DietrichGebert/ponytail.git" },
        @{ Name = "ui-ux"; Url = "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git" },
        @{ Name = "replica"; Url = "https://github.com/Jakeschincariol/replica-skill.git" },
        @{ Name = "impeccable"; Url = "https://github.com/pbakaus/impeccable.git" }
    )

    foreach ($repo in $repos) {
        $target = Join-Path $tempDir $repo.Name
        Write-Host "  -> Klonlanıyor: $($repo.Name) ($($repo.Url))..." -ForegroundColor Gray
        git clone --depth 1 $repo.Url $target 2>$null
        if (-not (Test-Path $target)) {
            Write-Warning "  [!] $($repo.Name) klonlanamadı!"
        }
    }

    Write-Host ""
    Write-Host "[2/5] Skiller Antigravity ve Çalışma Alanı Dizinlerine Dağıtılıyor..." -ForegroundColor Yellow

    function Deploy-SkillFolder([string]$srcDir, [string]$skillName) {
        if (-not (Test-Path $srcDir)) { return }
        Write-Host "  [+] Kuruluyor: $skillName" -ForegroundColor Green
        foreach ($dest in $destinations) {
            $destPath = Join-Path $dest $skillName
            Copy-Item -Path $srcDir -Destination $destPath -Recurse -Force
        }
    }

    # A) Karpathy Guidelines
    $karpathySrc = Join-Path $tempDir "karpathy\skills\karpathy-guidelines"
    Deploy-SkillFolder -srcDir $karpathySrc -skillName "karpathy-guidelines"

    # B) Ponytail Pack (ponytail, ponytail-audit, ponytail-debt, ponytail-gain, ponytail-help, ponytail-review)
    $ponytailSrc = Join-Path $tempDir "ponytail\skills"
    if (Test-Path $ponytailSrc) {
        Get-ChildItem -Path $ponytailSrc -Directory | ForEach-Object {
            Deploy-SkillFolder -srcDir $_.FullName -skillName $_.Name
        }
    }

    # C) UI/UX Pro Max
    $uiuxSrc = Join-Path $tempDir "ui-ux"
    if (Test-Path $uiuxSrc) {
        Deploy-SkillFolder -srcDir $uiuxSrc -skillName "ui-ux-pro-max"
    }

    # D) Replica Pack (11 skill: replica-architect, replica-recon, replica-build, vb.)
    $replicaSrc = Join-Path $tempDir "replica"
    if (Test-Path $replicaSrc) {
        Get-ChildItem -Path $replicaSrc -Directory -Filter "replica-*" | ForEach-Object {
            Deploy-SkillFolder -srcDir $_.FullName -skillName $_.Name
        }
    }

    # E) Impeccable (UI/UX Craft)
    $impeccableSrc = Join-Path $tempDir "impeccable"
    if (Test-Path $impeccableSrc) {
        Deploy-SkillFolder -srcDir $impeccableSrc -skillName "impeccable"
    }

    Write-Host ""
    Write-Host "[3/5] Claude Code CLI Eklentileri Kuruluyor..." -ForegroundColor Yellow

    if ($hasClaude -and -not $SkipClaude) {
        Write-Host "  -> Claude CLI tespit edildi, marketplace ve eklentiler yapılandırılıyor..." -ForegroundColor Cyan

        # Marketplaces
        $marketplaces = @(
            @{ Name = "karpathy-skills"; Source = "forrestchang/andrej-karpathy-skills" },
            @{ Name = "ponytail"; Source = "DietrichGebert/ponytail" },
            @{ Name = "ui-ux-pro-max-skill"; Source = "nextlevelbuilder/ui-ux-pro-max-skill" },
            @{ Name = "ecc"; Source = "https://github.com/affaan-m/ECC.git" }
        )

        foreach ($mp in $marketplaces) {
            Write-Host "  -> Marketplace ekleniyor: $($mp.Name)..." -ForegroundColor Gray
            claude plugin marketplace add $mp.Source 2>$null
        }

        # Plugins
        $plugins = @(
            "andrej-karpathy-skills@karpathy-skills",
            "ponytail@ponytail",
            "ui-ux-pro-max@ui-ux-pro-max-skill",
            "ecc@ecc"
        )

        foreach ($p in $plugins) {
            Write-Host "  -> Eklenti kuruluyor ve etkinleştiriliyor: $p..." -ForegroundColor Green
            claude plugin install $p 2>$null
            claude plugin enable $p 2>$null
        }
    } else {
        if (-not $hasClaude) {
            Write-Host "  [i] 'claude' CLI bulunamadı (Claude Code kurulu değilse bu adım atlandı)." -ForegroundColor DarkGray
        } else {
            Write-Host "  [i] Claude adımı -SkipClaude ile atlandı." -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "[4/5] Global NPM Paketleri Kontrol Ediliyor..." -ForegroundColor Yellow

    if ($hasNpm -and -not $SkipNpm) {
        Write-Host "  -> 'ui-ux-pro-max-cli' global kuruluyor/güncelleniyor..." -ForegroundColor Cyan
        npm install -g ui-ux-pro-max-cli
    } else {
        Write-Host "  [i] npm bulunamadı veya -SkipNpm seçildi, npm adımı atlandı." -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "[5/5] Kurulum Tamamlandı ve Doğrulanıyor!" -ForegroundColor Green

    Write-Host "`n=== Kurulan Antigravity Global Skilleri (~/.gemini/config/skills) ===" -ForegroundColor Magenta
    Get-ChildItem -Path $globalGeminiConfigSkills -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object

    if ($hasClaude -and -not $SkipClaude) {
        Write-Host "`n=== Claude Code Aktif Eklentileri ===" -ForegroundColor Magenta
        claude plugin list 2>$null
    }

} finally {
    # Geçici dosyaları temizle
    if (Test-Path $tempDir) {
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  ✨ Tüm skill ve eklentiler başarıyla hazırlandı!         " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
