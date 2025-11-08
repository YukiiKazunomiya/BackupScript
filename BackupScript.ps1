# ╔════════════════════════════════════════════════════════════╗
# ║        BACKUP & MAINTENANCE AUTOMATION SYSTEM v1.0         ║
# ║        Created & Modified By: YukiiKazunomiya ♡            ║
# ║        Date: November 2025                                 ║
# ╚════════════════════════════════════════════════════════════╝

# ============================================
# KONFIGURASI UTAMA - EDIT SESUAI KEBUTUHAN
# ============================================

$Config = @{
    # Konfigurasi Folder Backup
    SourceFolder      = "C:\Data\Dokumen"
    BackupDestination = "C:\Users\Public\BackupTest"
    MaxBackupAge      = 30

    # Konfigurasi Email Notifikasi
    EmailEnabled      = $true
    SmtpServer        = "smtp.gmail.com"
    SmtpPort          = 587
    EmailFrom         = "YukiiKazunomiya@gmail.com"
    EmailTo           = "YukiiKazunomiya@gmail.com"
    EmailPassword     = ""

    # Konfigurasi Auto Update Software
    AutoUpdateEnabled = $true
    SoftwareList      = @("GoogleChrome", "AdobeReader", "7zip")

    # Konfigurasi Logging
    LogFolder         = "C:\BackupLogs"
    LogRetentionDays  = 90
}

# ============================================
# WATERMARK
# ============================================
function Show-Watermark {
    Write-Host "`n───────────────────────────────────────────────" -ForegroundColor Magenta
    Write-Host "💾  Backup & Maintenance System" -ForegroundColor Cyan
    Write-Host "📜  Version 1.0 - © 2025 By YukiiKazunomiya 💖" -ForegroundColor Magenta
    Write-Host "───────────────────────────────────────────────`n" -ForegroundColor Magenta
}

# ============================================
# FUNGSI-FUNGSI UTAMA
# ============================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR','SUCCESS')]
        [string]$Level = 'INFO'
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"

    if (!(Test-Path $Config.LogFolder)) {
        New-Item -ItemType Directory -Path $Config.LogFolder -Force | Out-Null
    }

    $LogFile = Join-Path $Config.LogFolder "Backup_$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $LogFile -Value $LogMessage

    switch ($Level) {
        'INFO'    { Write-Host $LogMessage -ForegroundColor Cyan }
        'WARNING' { Write-Host $LogMessage -ForegroundColor Yellow }
        'ERROR'   { Write-Host $LogMessage -ForegroundColor Red }
        'SUCCESS' { Write-Host $LogMessage -ForegroundColor Green }
    }
}

function Start-BackupProcess {
    Write-Log "======== MEMULAI PROSES BACKUP ========" -Level INFO
    try {
        if (!(Test-Path $Config.SourceFolder)) {
            Write-Log "ERROR: Source folder tidak ditemukan: $($Config.SourceFolder)" -Level ERROR
            return $false
        }

        $BackupTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupPath = Join-Path $Config.BackupDestination "Backup_$BackupTimestamp"

        Write-Log "Membuat folder backup: $BackupPath" -Level INFO
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null

        $SourceSize = (Get-ChildItem -Path $Config.SourceFolder -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Log "Ukuran data yang akan dibackup: $([math]::Round($SourceSize, 2)) MB" -Level INFO

        Write-Log "Memulai proses copy file..." -Level INFO
        $StartTime = Get-Date

        Copy-Item -Path "$($Config.SourceFolder)\*" -Destination $BackupPath -Recurse -Force

        $EndTime = Get-Date
        $Duration = ($EndTime - $StartTime).TotalSeconds
        $FileCount = (Get-ChildItem -Path $BackupPath -Recurse -File).Count

        Write-Log "Backup berhasil! Total $FileCount file dalam $([math]::Round($Duration, 2)) detik" -Level SUCCESS

        Write-Log "Mengkompress backup ke ZIP..." -Level INFO
        $ZipPath = "$BackupPath.zip"
        Compress-Archive -Path $BackupPath -DestinationPath $ZipPath -Force

        Remove-Item -Path $BackupPath -Recurse -Force
        $ZipSize = (Get-Item $ZipPath).Length / 1MB
        Write-Log "Backup ZIP dibuat: $([math]::Round($ZipSize, 2)) MB" -Level SUCCESS

        return $true
    }
    catch {
        Write-Log "ERROR saat backup: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Remove-OldBackups {
    Write-Log "======== MENGHAPUS BACKUP LAMA ========" -Level INFO
    try {
        $CutoffDate = (Get-Date).AddDays(-$Config.MaxBackupAge)
        Write-Log "Menghapus backup lebih lama dari: $($CutoffDate.ToString('yyyy-MM-dd'))" -Level INFO

        $OldBackups = Get-ChildItem -Path $Config.BackupDestination -Filter "Backup_*.zip" |
                      Where-Object { $_.LastWriteTime -lt $CutoffDate }

        if ($OldBackups.Count -eq 0) {
            Write-Log "Tidak ada backup lama yang perlu dihapus" -Level INFO
        } else {
            $TotalSize = ($OldBackups | Measure-Object -Property Length -Sum).Sum / 1MB
            Write-Log "Ditemukan $($OldBackups.Count) backup lama (Total: $([math]::Round($TotalSize, 2)) MB)" -Level WARNING

            foreach ($Backup in $OldBackups) {
                Remove-Item -Path $Backup.FullName -Force
                Write-Log "Dihapus: $($Backup.Name)" -Level INFO
            }
            Write-Log "Berhasil menghapus $($OldBackups.Count) backup lama" -Level SUCCESS
        }
    }
    catch {
        Write-Log "ERROR saat menghapus backup lama: $($_.Exception.Message)" -Level ERROR
    }
}

function Remove-OldLogs {
    Write-Log "======== MEMBERSIHKAN LOG LAMA ========" -Level INFO
    try {
        $CutoffDate = (Get-Date).AddDays(-$Config.LogRetentionDays)
        $OldLogs = Get-ChildItem -Path $Config.LogFolder -Filter "Backup_*.log" |
                   Where-Object { $_.LastWriteTime -lt $CutoffDate }

        if ($OldLogs.Count -eq 0) {
            Write-Log "Tidak ada log lama yang perlu dihapus" -Level INFO
        } else {
            foreach ($Log in $OldLogs) {
                Remove-Item -Path $Log.FullName -Force
                Write-Log "Log dihapus: $($Log.Name)" -Level INFO
            }
            Write-Log "Berhasil menghapus $($OldLogs.Count) log lama" -Level SUCCESS
        }
    }
    catch {
        Write-Log "ERROR saat menghapus log: $($_.Exception.Message)" -Level ERROR
    }
}

function Update-Software {
    Write-Log "======== UPDATE SOFTWARE ========" -Level INFO
    if (!$Config.AutoUpdateEnabled) {
        Write-Log "Auto update software DISABLED" -Level WARNING
        return
    }

    try {
        $ChocoInstalled = Get-Command choco -ErrorAction SilentlyContinue
        if (!$ChocoInstalled) {
            Write-Log "Chocolatey belum terinstall. Melewati update software." -Level WARNING
            Write-Log "Install Chocolatey di: https://chocolatey.org/install" -Level INFO
            return
        }

        foreach ($Software in $Config.SoftwareList) {
            Write-Log "Mengupdate $Software..." -Level INFO
            choco upgrade $Software -y 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "$Software berhasil diupdate" -Level SUCCESS
            } else {
                Write-Log "${Software}: Sudah versi terbaru atau error" -Level WARNING
            }
        }
    }
    catch {
        Write-Log "ERROR saat update software: $($_.Exception.Message)" -Level ERROR
    }
}

function Show-Configuration {
    Write-Log "======== KONFIGURASI SYSTEM ========" -Level INFO
    Write-Log "Source Folder     : $($Config.SourceFolder)" -Level INFO
    Write-Log "Backup Destination: $($Config.BackupDestination)" -Level INFO
    Write-Log "Max Backup Age    : $($Config.MaxBackupAge) hari" -Level INFO
    Write-Log "Email Notifikasi  : $(if ($Config.EmailEnabled) {'ENABLED ✅'} else {'DISABLED ❌'})" -Level INFO
    Write-Log "Auto Update       : $(if ($Config.AutoUpdateEnabled) {'ENABLED ✅'} else {'DISABLED ❌'})" -Level INFO
    Write-Log "Log Retention     : $($Config.LogRetentionDays) hari" -Level INFO
    Write-Log "=====================================" -Level INFO
}

# ============================================
# MAIN PROGRAM
# ============================================

Show-Watermark
Show-Configuration
$BackupSuccess = Start-BackupProcess
Remove-OldBackups
Remove-OldLogs
Update-Software

Write-Log "======== PROSES SELESAI ========" -Level 'SUCCESS'
Write-Host ""
Write-Host "[INFO] Backup process completed! Check log file untuk detail lengkap." -ForegroundColor Green
Write-Host "`n───────────────────────────────────────────────"
Write-Host "Script completed successfully!  © By YukiiKazunomiya 💫"
Write-Host "───────────────────────────────────────────────`n"
