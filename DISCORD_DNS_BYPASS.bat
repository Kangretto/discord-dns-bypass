<# :
@echo off
title Discord DNS Updater Pro - [Yonetici]
color 0B

:: 1. YONETICI IZNI KONTROLU (AUTO-ELEVATION)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Yonetici izinleri aliniyor... Lutfen onay verin.
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c %~f0' -Verb RunAs"
    exit /b
)

:: 2. POWERSHELL MOTORUNU TETIKLEME (POLYGLOT MIMARI)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ([System.IO.File]::ReadAllText('%~f0'))"
echo.
pause
exit /b
#>

# =====================================================================
# BURADAN ITIBAREN POWERSHELL KODLARI BASLAR
# =====================================================================
$ErrorActionPreference = "Stop"

# Hedef domainler
$domains = @(
    "discord.com", "gateway.discord.gg", "cdn.discordapp.com",
    "media.discordapp.net", "updates.discord.com", "discordapp.com",
    "discordapp.net", "discord.gg", "status.discord.com"
)

# Yedekli DNS Sunucuları (Cloudflare, Google, Quad9)
$dnsServers = @("1.1.1.1", "8.8.8.8", "9.9.9.9")
$hostsPath = "$env:windir\System32\drivers\etc\hosts"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       DISCORD DNS BYPASS - KANGRET       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# ADIM 1: HOSTS DOSYASI YEDEKLEME
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = "$hostsPath.$timestamp.bak"
try {
    Copy-Item -Path $hostsPath -Destination $backupPath -Force
    Write-Host "[+] Sistem hosts dosyasi yedeklendi: hosts.$timestamp.bak" -ForegroundColor DarkGreen
} catch {
    Write-Host "[-] KRITIK HATA: Hosts dosyasi yedeklenemedi. Islem iptal ediliyor." -ForegroundColor Red
    exit
}

# ADIM 2: IP ADRESLERINI SORGULAMA (FALLBACK ILE)
$newEntries = @()
Write-Host "[*] Guncel IP adresleri sorgulaniyor..." -ForegroundColor Yellow

foreach ($domain in $domains) {
    $resolved = $false
    foreach ($dns in $dnsServers) {
        try {
            # Dns sorgusu at, sadece IPv4 (A kaydı) al
            $record = Resolve-DnsName -Name $domain -Server $dns -Type A -ErrorAction Stop | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1
            if ($record.IPAddress) {
                $newEntries += "$($record.IPAddress)`t$domain"
                Write-Host "  -> $domain : $($record.IPAddress) ($dns uzerinden)" -ForegroundColor Green
                $resolved = $true
                break # Basarili olursa diger DNS'e gecme, donguden cik
            }
        } catch {
            # Hata verirse sessizce bir sonraki DNS'e geç
        }
    }
    if (-not $resolved) {
        Write-Host "  -> [!] $domain icin IP bulunamadi! (Baglantinizi kontrol edin)" -ForegroundColor Red
    }
}

# ADIM 3: GUVENLI YAZMA ISLEMI (FAIL-SAFE)
if ($newEntries.Count -eq 0) {
    Write-Host "`n[-] Hicbir IP adresi bulunamadi. Hosts dosyasi DEGISTIRILMEDI!" -ForegroundColor Red
    Write-Host "Lutfen internet baglantinizi kontrol edin." -ForegroundColor Red
} else {
    Write-Host "`n[*] Hosts dosyasi temizleniyor ve guncelleniyor..." -ForegroundColor Yellow
    
    # Eski hosts dosyasini oku, icinde "discord" gecenleri sil
    $currentHosts = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
    if ($null -ne $currentHosts) {
        $filteredHosts = $currentHosts | Where-Object { $_ -notmatch "(?i)discord" }
    } else {
        $filteredHosts = @()
    }

    # Yeni listeyi hazirla
    $finalHosts = $filteredHosts + "" + "# --- Discord DNS Bypass (Otomatik Guncellendi: $(Get-Date)) ---" + $newEntries + "# ---------------------------------------------------------"
    
    # Dosyaya yaz
    $finalHosts | Out-File -FilePath $hostsPath -Encoding utf8 -Force
    Write-Host "[+] Yeni ayarlar basariyla kaydedildi!" -ForegroundColor DarkGreen

    # DNS Onbellegini Temizle
    Clear-DnsClientCache
    Write-Host "[+] DNS Onbellegi (Cache) temizlendi." -ForegroundColor DarkGreen
    
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host " ISLEM KUSURSUZ TAMAMLANDI. DISCORD'U ACABILIRSINIZ." -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
}