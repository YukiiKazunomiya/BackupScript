# ╔════════════════════════════════════════════════════════════╗
# ║     BACKUP SYSTEM SETUP — Interactive Configuration        ║
# ║     Created By: YukiiKazunomiya  |  Version 2.0           ║
# ╚════════════════════════════════════════════════════════════╝
#
# Script ini membantu kamu:
#   1. Mengatur konfigurasi BackupSystem.ps1 (email, folder, dll)
#   2. Mendaftarkan backup otomatis ke Windows Task Scheduler
#
# Jalankan dengan: Right-click > Run with PowerShell (As Administrator)
#
#Requires -Version 5.1
#Requires -RunAsAdministrator

# ============================================================
# HELPER
# ============================================================
function Write-Title {
    param([string]$Text)
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Magenta
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Magenta
    Write-Host ""
}

function Prompt-Input {
    param([string]$Label, [string]$Default = "")
    $Hint = if ($Default) { " [Default: $Default]" } else { "" }
    Write-Host "  $Label$Hint" -ForegroundColor Yellow -NoNewline
    Write-Host " : " -NoNewline
    $Value = Read-Host
    if ([string]::IsNullOrWhiteSpace($Value) -and $Default) { return $Default }
    return $Value
}

function Prompt-YesNo {
    param([string]$Label, [bool]$Default = $true)
    $DefaultText = if ($Default) { "Y/n" } else { "y/N" }
    Write-Host "  $Label [$DefaultText]" -ForegroundColor Yellow -NoNewline
    Write-Host " : " -NoNewline
    $Value = Read-Host
    if ([string]::IsNullOrWhiteSpace($Value)) { return $Default }
    return $Value.ToLower() -eq 'y'
}

# ============================================================
# TAMPILKAN HEADER
# ============================================================
Clear-Host
Write-Host ""
Write-Host "  +==================================================+" -ForegroundColor Magenta
Write-Host "  |     Backup System - Interactive Setup            |" -ForegroundColor Cyan
Write-Host "  |     Version 2.0  -  (c) 2025 YukiiKazunomiya    |" -ForegroundColor Magenta
Write-Host "  +==================================================+" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Script ini akan membantu kamu mengatur backup otomatis." -ForegroundColor White
Write-Host "  Tekan ENTER untuk menggunakan nilai default yang ditampilkan." -ForegroundColor DarkGray
Write-Host ""

# ============================================================
# LANGKAH 1: CARI FILE BackupSystem.ps1
# ============================================================
Write-Title "LANGKAH 1: Lokasi Script"

$ScriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Path
$DefaultScript  = Join-Path $ScriptDir "BackupSystem.ps1"

if (Test-Path $DefaultScript) {
    Write-Host "  Ditemukan: $DefaultScript" -ForegroundColor Green
    $ScriptPath = $DefaultScript
}
else {
    Write-Host "  BackupSystem.ps1 tidak ditemukan di folder ini." -ForegroundColor Yellow
    $ScriptPath = Prompt-Input "Path lengkap ke BackupSystem.ps1" $DefaultScript
    if (!(Test-Path $ScriptPath)) {
        Write-Host "  ERROR: File tidak ditemukan. Setup dibatalkan." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# ============================================================
# LANGKAH 2: KONFIGURASI FOLDER BACKUP
# ============================================================
Write-Title "LANGKAH 2: Folder yang Akan Dibackup"

Write-Host "  Folder default yang akan dibackup dari profil user kamu:" -ForegroundColor White
$DefaultFolders = @("Documents", "Desktop", "Pictures", "Downloads", "Videos")
foreach ($F in $DefaultFolders) {
    $Path   = Join-Path $env:USERPROFILE $F
    $Status = if (Test-Path $Path) { "[Ada]" } else { "[Tidak ada]" }
    Write-Host "    - $F  $Status" -ForegroundColor $(if (Test-Path $Path) { 'Cyan' } else { 'DarkGray' })
}
Write-Host ""

$UseCustomFolders = Prompt-YesNo "Gunakan daftar folder default di atas?" $true
$FolderList       = $DefaultFolders

if (-not $UseCustomFolders) {
    Write-Host "  Masukkan nama folder (pisahkan dengan koma, relatif dari C:\Users\$env:USERNAME\):" -ForegroundColor Yellow
    Write-Host "  Contoh: Documents,Desktop,Pictures,Downloads" -ForegroundColor DarkGray
    $Input     = Prompt-Input "Folder" "Documents,Desktop,Pictures,Downloads"
    $FolderList = $Input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}

$BackupDest = Prompt-Input "Lokasi penyimpanan backup di PC" "C:\BackupData"
$MaxAge     = Prompt-Input "Hapus backup lebih dari berapa hari?" "30"

# ============================================================
# LANGKAH 3: KONFIGURASI EMAIL
# ============================================================
Write-Title "LANGKAH 3: Email Notifikasi"

Write-Host "  PENTING: Gunakan App Password Gmail, bukan password biasa!" -ForegroundColor Yellow
Write-Host "  Cara buat App Password: myaccount.google.com > Security > App Passwords" -ForegroundColor DarkGray
Write-Host ""

$EmailEnabled = Prompt-YesNo "Aktifkan notifikasi email?" $true
$EmailFrom    = ""
$EmailTo      = ""
$EmailPass    = ""

if ($EmailEnabled) {
    $EmailFrom = Prompt-Input "Email pengirim (Gmail kamu)" "yukiidesu@gmail.com"
    $EmailTo   = Prompt-Input "Email penerima" $EmailFrom
    Write-Host "  App Password Gmail" -ForegroundColor Yellow -NoNewline
    Write-Host " : " -NoNewline
    $SecurePass = Read-Host -AsSecureString
    $Bstr       = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
    $EmailPass  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Bstr)
}

$MaxAttachMB = Prompt-Input "Batas ukuran attachment ZIP via email (MB)" "20"

# ============================================================
# LANGKAH 4: AUTO UPDATE (CHOCOLATEY)
# ============================================================
Write-Title "LANGKAH 4: Auto Update Software"

Write-Host "  Fitur ini membutuhkan Chocolatey (https://chocolatey.org/install)" -ForegroundColor DarkGray
$AutoUpdate = Prompt-YesNo "Aktifkan auto update software via Chocolatey?" $false

$SoftwareList = @("googlechrome", "adobereader", "7zip")
if ($AutoUpdate) {
    Write-Host "  Software default: googlechrome, adobereader, 7zip" -ForegroundColor White
    $CustomSW = Prompt-YesNo "Gunakan daftar software default?" $true
    if (-not $CustomSW) {
        $SWInput      = Prompt-Input "Nama package Chocolatey (pisah koma)" "googlechrome,adobereader,7zip"
        $SoftwareList = $SWInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    }
}

# ============================================================
# LANGKAH 5: LOGGING
# ============================================================
Write-Title "LANGKAH 5: Pengaturan Log"

$LogFolder   = Prompt-Input "Folder penyimpanan log" "C:\BackupLogs"
$LogRetention = Prompt-Input "Hapus log lebih dari berapa hari?" "90"

# ============================================================
# LANGKAH 6: JADWAL OTOMATIS (TASK SCHEDULER)
# ============================================================
Write-Title "LANGKAH 6: Jadwal Backup Otomatis"

Write-Host "  Daftarkan backup otomatis ke Windows Task Scheduler?" -ForegroundColor White
$UseSchedule = Prompt-YesNo "Aktifkan jadwal otomatis?" $true

$ScheduleType = "Daily"
$ScheduleTime = "02:00"

if ($UseSchedule) {
    Write-Host ""
    Write-Host "  Pilih jenis jadwal:" -ForegroundColor Yellow
    Write-Host "    1. Setiap hari (Daily)" -ForegroundColor White
    Write-Host "    2. Setiap minggu (Weekly - Senin)" -ForegroundColor White
    Write-Host "    3. Setiap bulan (Monthly - Tanggal 1)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Pilihan [1/2/3]" -ForegroundColor Yellow -NoNewline
    Write-Host " : " -NoNewline
    $ScheduleChoice = Read-Host
    switch ($ScheduleChoice) {
        "2" { $ScheduleType = "Weekly" }
        "3" { $ScheduleType = "Monthly" }
        default { $ScheduleType = "Daily" }
    }
    $ScheduleTime = Prompt-Input "Waktu backup (format 24 jam, contoh: 02:00)" "02:00"
}

# ============================================================
# KONFIRMASI & TULIS CONFIG
# ============================================================
Write-Title "KONFIRMASI KONFIGURASI"

Write-Host "  Folder backup     : $($FolderList -join ', ')" -ForegroundColor Cyan
Write-Host "  Tujuan backup     : $BackupDest" -ForegroundColor Cyan
Write-Host "  Max backup age    : $MaxAge hari" -ForegroundColor Cyan
Write-Host "  Email enabled     : $EmailEnabled" -ForegroundColor Cyan
if ($EmailEnabled) {
    Write-Host "  Email dari        : $EmailFrom" -ForegroundColor Cyan
    Write-Host "  Email ke          : $EmailTo" -ForegroundColor Cyan
}
Write-Host "  Auto update       : $AutoUpdate" -ForegroundColor Cyan
Write-Host "  Log folder        : $LogFolder" -ForegroundColor Cyan
Write-Host "  Log retention     : $LogRetention hari" -ForegroundColor Cyan
if ($UseSchedule) {
    Write-Host "  Jadwal backup     : $ScheduleType, pukul $ScheduleTime" -ForegroundColor Cyan
}
Write-Host ""

$Confirm = Prompt-YesNo "Simpan konfigurasi dan lanjutkan?" $true
if (-not $Confirm) {
    Write-Host "  Setup dibatalkan oleh user." -ForegroundColor Yellow
    exit 0
}

# ============================================================
# TULIS FILE KONFIGURASI
# ============================================================
Write-Host ""
Write-Host "  Menulis konfigurasi ke BackupSystem.ps1..." -ForegroundColor White

$Content = Get-Content $ScriptPath -Raw -Encoding UTF8

# Replace tiap nilai konfigurasi menggunakan regex
$FolderListStr = ($FolderList | ForEach-Object { "        `"$_`"" }) -join ",`n"

# Buat blok BackupFolders baru
$NewFolderBlock = "    BackupFolders     = @(`n$FolderListStr`n    )"
$Content = $Content -replace '(?s)BackupFolders\s*=\s*@\([^)]*\)', $NewFolderBlock

$Content = $Content -replace 'BackupDestination\s*=\s*"[^"]*"', "BackupDestination = `"$BackupDest`""
$Content = $Content -replace 'MaxBackupAge\s*=\s*\d+', "MaxBackupAge      = $MaxAge"
$Content = $Content -replace 'EmailEnabled\s*=\s*\$(true|false)', "EmailEnabled      = `$$($EmailEnabled.ToString().ToLower())"
$Content = $Content -replace 'EmailFrom\s*=\s*"[^"]*"', "EmailFrom         = `"$EmailFrom`""
$Content = $Content -replace 'EmailTo\s*=\s*"[^"]*"', "EmailTo           = `"$EmailTo`""
$Content = $Content -replace 'EmailPassword\s*=\s*"[^"]*"', "EmailPassword     = `"$EmailPass`""
$Content = $Content -replace 'MaxEmailAttachmentMB\s*=\s*\d+', "MaxEmailAttachmentMB = $MaxAttachMB"
$Content = $Content -replace 'AutoUpdateEnabled\s*=\s*\$(true|false)', "AutoUpdateEnabled = `$$($AutoUpdate.ToString().ToLower())"
$Content = $Content -replace 'LogFolder\s*=\s*"[^"]*"', "LogFolder         = `"$LogFolder`""
$Content = $Content -replace 'LogRetentionDays\s*=\s*\d+', "LogRetentionDays  = $LogRetention"

Set-Content -Path $ScriptPath -Value $Content -Encoding UTF8
Write-Host "  Konfigurasi berhasil disimpan." -ForegroundColor Green

# ============================================================
# DAFTARKAN TASK SCHEDULER
# ============================================================
if ($UseSchedule) {
    Write-Host ""
    Write-Host "  Mendaftarkan Windows Task Scheduler..." -ForegroundColor White

    try {
        $TaskName    = "BackupSystem_YukiiKazunomiya"
        $TaskAction  = New-ScheduledTaskAction -Execute "powershell.exe" `
                           -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

        $TimeSpan = [TimeSpan]::Parse($ScheduleTime + ":00")
        $TaskTrigger = switch ($ScheduleType) {
            "Daily"   { New-ScheduledTaskTrigger -Daily   -At $TimeSpan }
            "Weekly"  { New-ScheduledTaskTrigger -Weekly  -DaysOfWeek Monday -At $TimeSpan }
            "Monthly" { New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At $TimeSpan }
        }

        $TaskSettings = New-ScheduledTaskSettingsSet `
            -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
            -RestartCount 2 `
            -RestartInterval (New-TimeSpan -Minutes 10) `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable:$false

        $TaskPrincipal = New-ScheduledTaskPrincipal `
            -UserId "$env:USERDOMAIN\$env:USERNAME" `
            -LogonType Interactive `
            -RunLevel Highest

        # Hapus task lama jika ada
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

        Register-ScheduledTask `
            -TaskName   $TaskName `
            -Action     $TaskAction `
            -Trigger    $TaskTrigger `
            -Settings   $TaskSettings `
            -Principal  $TaskPrincipal `
            -Description "Backup otomatis oleh BackupSystem v2.0 - YukiiKazunomiya" | Out-Null

        Write-Host "  Task Scheduler berhasil didaftarkan!" -ForegroundColor Green
        Write-Host "  Nama task : $TaskName" -ForegroundColor Cyan
        Write-Host "  Jadwal    : $ScheduleType, pukul $ScheduleTime" -ForegroundColor Cyan
        Write-Host "  Cek di    : Task Scheduler > Task Scheduler Library > $TaskName" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "  ERROR mendaftarkan Task Scheduler: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Pastikan script dijalankan sebagai Administrator." -ForegroundColor Yellow
    }
}

# ============================================================
# SELESAI
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
Write-Host "  |  Setup selesai! Apa yang perlu dilakukan:        |" -ForegroundColor White
Write-Host "  |                                                  |" -ForegroundColor DarkGray
Write-Host "  |  1. Pastikan App Password Gmail sudah diisi      |" -ForegroundColor White
Write-Host "  |  2. Coba jalankan BackupSystem.ps1 manual dulu   |" -ForegroundColor White
if ($UseSchedule) {
    Write-Host "  |  3. Cek Task Scheduler untuk verifikasi jadwal   |" -ForegroundColor White
}
Write-Host "  |                                                  |" -ForegroundColor DarkGray
Write-Host "  |  (c) 2025 YukiiKazunomiya                        |" -ForegroundColor Magenta
Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
Write-Host ""

Pause
