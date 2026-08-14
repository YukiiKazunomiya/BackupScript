# ╔════════════════════════════════════════════════════════════╗
# ║        BACKUP & MAINTENANCE AUTOMATION SYSTEM v2.0         ║
# ║        Created & Modified By: YukiiKazunomiya              ║
# ║        Date: November 2025                                 ║
# ╚════════════════════════════════════════════════════════════╝

#Requires -Version 5.1

# ============================================================
# MAIN CONFIGURATION — EDIT AS NEEDED
# ============================================================

$Config = @{

    # ── Backup Folders ───────────────────────────────────────
    # List of sub-folder names from the user profile to be backed up.
    # Add or remove as needed. Example addition: "Videos", "Music"
    BackupFolders     = @(
        "Documents",
        "Desktop",
        "Pictures",
        "Downloads",
        "Videos"
    )

    # Destination location for backup results on the PC
    BackupDestination = "C:\BackupData"

    # How many days old backups are kept before automatic deletion
    MaxBackupAge      = 30

    # ── Email Notifications ──────────────────────────────────
    EmailEnabled      = $true
    SmtpServer        = "smtp.gmail.com"
    SmtpPort          = 587
    EmailFrom         = "yukiidesu@gmail.com"   # Sender address (Your Gmail)
    EmailTo           = "yukiidesu@gmail.com"   # Destination address
    # Use Google App Password, NOT regular Gmail password!
    # How to create: myaccount.google.com > Security > App Passwords
    EmailPassword     = ""

    # Maximum ZIP attachment size sent via email (MB)
    # If backup is larger than this, ZIP is not attached (only log)
    MaxEmailAttachmentMB = 20

    # ── Auto Update Software (via Chocolatey) ────────────────
    AutoUpdateEnabled = $false
    SoftwareList      = @("googlechrome", "adobereader", "7zip")

    # ── Logging ──────────────────────────────────────────────
    LogFolder         = "C:\BackupLogs"
    LogRetentionDays  = 90
}

# ============================================================
# INTERNAL — DO NOT CHANGE
# ============================================================
$Script:LogFile = $null
$Script:Stats   = @{ FileCount = 0; TotalSizeMB = 0; Duration = 0; Errors = 0 }

# ============================================================
# WATERMARK
# ============================================================
function Show-Watermark {
    Clear-Host
    Write-Host ""
    Write-Host "  +==================================================+" -ForegroundColor Magenta
    Write-Host "  |    Backup & Maintenance Automation System        |" -ForegroundColor Cyan
    Write-Host "  |    Version 2.0  -  (c) 2025 YukiiKazunomiya     |" -ForegroundColor Magenta
    Write-Host "  +==================================================+" -ForegroundColor Magenta
    Write-Host ""
}

# ============================================================
# LOGGING
# ============================================================
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $Timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"

    # Ensure log folder exists
    if (!(Test-Path $Config.LogFolder)) {
        New-Item -ItemType Directory -Path $Config.LogFolder -Force | Out-Null
    }

    # Initialize log file path if not already set
    if ($null -eq $Script:LogFile) {
        $Script:LogFile = Join-Path $Config.LogFolder "Backup_$(Get-Date -Format 'yyyyMMdd').log"
    }

    Add-Content -Path $Script:LogFile -Value $LogMessage -Encoding UTF8

    $Color = switch ($Level) {
        'INFO'    { 'Cyan' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
        'SUCCESS' { 'Green' }
    }

    Write-Host $LogMessage -ForegroundColor $Color

    if ($Level -eq 'ERROR') { $Script:Stats.Errors++ }
}

# ============================================================
# DISPLAY CONFIGURATION
# ============================================================
function Show-Configuration {
    Write-Log "====== SYSTEM CONFIGURATION ======" -Level INFO
    Write-Log "Active User       : $env:USERNAME" -Level INFO
    Write-Log "Backup destination: $($Config.BackupDestination)" -Level INFO
    Write-Log "Max backup age    : $($Config.MaxBackupAge) days" -Level INFO
    Write-Log "Email notification: $(if ($Config.EmailEnabled) {'ENABLED'} else {'DISABLED'})" -Level INFO
    Write-Log "Auto update SW    : $(if ($Config.AutoUpdateEnabled) {'ENABLED'} else {'DISABLED'})" -Level INFO
    Write-Log "Log retention     : $($Config.LogRetentionDays) days" -Level INFO
    Write-Log "Folders to be backed up:" -Level INFO
    foreach ($Folder in $Config.BackupFolders) {
        $FullPath = Join-Path $env:USERPROFILE $Folder
        $Exists   = if (Test-Path $FullPath) { "Found" } else { "NOT FOUND" }
        Write-Log "  - $FullPath  [$Exists]" -Level INFO
    }
    Write-Log "==================================" -Level INFO
    Write-Host ""
}

# ============================================================
# BACKUP PROCESS
# ============================================================
function Start-BackupProcess {
    Write-Log "====== STARTING BACKUP ======" -Level INFO

    try {
        # Create backup destination folder
        if (!(Test-Path $Config.BackupDestination)) {
            New-Item -ItemType Directory -Path $Config.BackupDestination -Force | Out-Null
        }

        $BackupTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupPath      = Join-Path $Config.BackupDestination "Backup_$BackupTimestamp"
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null

        $StartTime       = Get-Date
        $TotalFiles      = 0
        $TotalBytes      = 0
        $FoldersBackedup = 0

        # Loop through each configured folder
        foreach ($FolderName in $Config.BackupFolders) {
            $SourcePath = Join-Path $env:USERPROFILE $FolderName

            if (!(Test-Path $SourcePath)) {
                Write-Log "Folder not found, skipping: $SourcePath" -Level WARNING
                continue
            }

            $DestPath = Join-Path $BackupPath $FolderName
            New-Item -ItemType Directory -Path $DestPath -Force | Out-Null

            # Calculate folder size
            $FolderFiles  = Get-ChildItem -Path $SourcePath -Recurse -File -ErrorAction SilentlyContinue
            $FolderSize   = ($FolderFiles | Measure-Object -Property Length -Sum).Sum
            $FolderSizeMB = [math]::Round(($FolderSize / 1MB), 2)

            Write-Log "Backing up $FolderName ($($FolderFiles.Count) files, $FolderSizeMB MB)..." -Level INFO

            # Copy files with progress bar
            $FileIndex = 0
            foreach ($File in $FolderFiles) {
                $FileIndex++
                $RelativePath = $File.FullName.Substring($SourcePath.Length)
                $DestFile     = Join-Path $DestPath $RelativePath
                $DestDir      = Split-Path $DestFile -Parent

                if (!(Test-Path $DestDir)) {
                    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
                }

                try {
                    Copy-Item -Path $File.FullName -Destination $DestFile -Force
                }
                catch {
                    Write-Log "Copy failed: $($File.Name) - $($_.Exception.Message)" -Level WARNING
                }

                # Update progress bar every 10 files
                if ($FileIndex % 10 -eq 0 -or $FileIndex -eq $FolderFiles.Count) {
                    $Pct = [math]::Round(($FileIndex / [math]::Max($FolderFiles.Count, 1)) * 100)
                    Write-Progress -Activity "Backup $FolderName" `
                                   -Status "$FileIndex / $($FolderFiles.Count) files ($Pct%)" `
                                   -PercentComplete $Pct
                }
            }
            Write-Progress -Activity "Backup $FolderName" -Completed

            $TotalFiles  += $FolderFiles.Count
            $TotalBytes  += $FolderSize
            $FoldersBackedup++
            Write-Log "$FolderName backup completed." -Level SUCCESS
        }

        $Duration = [math]::Round(((Get-Date) - $StartTime).TotalSeconds, 2)

        if ($FoldersBackedup -eq 0) {
            Write-Log "No folders were successfully backed up. Check BackupFolders configuration." -Level ERROR
            Remove-Item -Path $BackupPath -Recurse -Force -ErrorAction SilentlyContinue
            return $null
        }

        # Save statistics
        $Script:Stats.FileCount   = $TotalFiles
        $Script:Stats.TotalSizeMB = [math]::Round($TotalBytes / 1MB, 2)
        $Script:Stats.Duration    = $Duration

        Write-Log "All folders completed: $TotalFiles files, $($Script:Stats.TotalSizeMB) MB, in $Duration seconds" -Level SUCCESS

        # Compress to ZIP
        Write-Log "Compressing backup to ZIP..." -Level INFO
        $ZipPath = "$BackupPath.zip"
        Compress-Archive -Path "$BackupPath\*" -DestinationPath $ZipPath -Force
        Remove-Item -Path $BackupPath -Recurse -Force

        $ZipSizeMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
        Write-Log "ZIP successfully created: $ZipPath ($ZipSizeMB MB)" -Level SUCCESS

        return $ZipPath
    }
    catch {
        Write-Log "Critical error during backup: $($_.Exception.Message)" -Level ERROR
        return $null
    }
}

# ============================================================
# SEND EMAIL NOTIFICATION (SUPPORT MULTI-ATTACHMENT)
# ============================================================
function Send-NotificationEmail {
    param(
        [string]$Subject,
        [string]$Body,
        [string[]]$AttachmentPaths = @()
    )

    if (-not $Config.EmailEnabled) {
        Write-Log "Email notification DISABLED, skipping." -Level WARNING
        return
    }

    if ([string]::IsNullOrWhiteSpace($Config.EmailPassword)) {
        Write-Log "EmailPassword is empty! Fill in Gmail App Password in configuration." -Level ERROR
        return
    }

    try {
        Write-Log "Sending email to $($Config.EmailTo)..." -Level INFO

        $smtp             = New-Object System.Net.Mail.SmtpClient($Config.SmtpServer, $Config.SmtpPort)
        $smtp.EnableSsl   = $true
        $smtp.Credentials = New-Object System.Net.NetworkCredential($Config.EmailFrom, $Config.EmailPassword)

        $mail            = New-Object System.Net.Mail.MailMessage
        $mail.From       = $Config.EmailFrom
        $mail.To.Add($Config.EmailTo)
        $mail.Subject    = $Subject
        $mail.Body       = $Body
        $mail.IsBodyHtml = $false

        # Add all valid attachments
        $AttachedCount = 0
        foreach ($Path in $AttachmentPaths) {
            if (![string]::IsNullOrWhiteSpace($Path) -and (Test-Path $Path)) {
                $mail.Attachments.Add((New-Object System.Net.Mail.Attachment($Path)))
                Write-Log "Attachment: $(Split-Path $Path -Leaf)" -Level INFO
                $AttachedCount++
            }
        }

        $smtp.Send($mail)
        $mail.Dispose()

        Write-Log "Email successfully sent with $AttachedCount attachments." -Level SUCCESS
    }
    catch {
        Write-Log "Error sending email: $($_.Exception.Message)" -Level ERROR
    }
}

# ============================================================
# DELETE OLD BACKUPS
# ============================================================
function Remove-OldBackups {
    Write-Log "====== DELETE OLD BACKUPS ======" -Level INFO
    try {
        if (!(Test-Path $Config.BackupDestination)) { return }

        $CutoffDate = (Get-Date).AddDays(-$Config.MaxBackupAge)
        Write-Log "Cutoff date: $($CutoffDate.ToString('yyyy-MM-dd'))" -Level INFO

        $OldBackups = Get-ChildItem -Path $Config.BackupDestination -Filter "Backup_*.zip" |
                      Where-Object { $_.LastWriteTime -lt $CutoffDate }

        if ($OldBackups.Count -eq 0) {
            Write-Log "No old backups found." -Level INFO
        }
        else {
            $TotalMB = [math]::Round(($OldBackups | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
            Write-Log "Found $($OldBackups.Count) old backups (Total: $TotalMB MB)" -Level WARNING
            foreach ($Backup in $OldBackups) {
                Remove-Item -Path $Backup.FullName -Force
                Write-Log "Deleted: $($Backup.Name)" -Level INFO
            }
            Write-Log "Successfully deleted $($OldBackups.Count) old backups." -Level SUCCESS
        }
    }
    catch {
        Write-Log "Error deleting old backups: $($_.Exception.Message)" -Level ERROR
    }
}

# ============================================================
# DELETE OLD LOGS
# ============================================================
function Remove-OldLogs {
    Write-Log "====== CLEAN UP OLD LOGS ======" -Level INFO
    try {
        $CutoffDate = (Get-Date).AddDays(-$Config.LogRetentionDays)
        $OldLogs    = Get-ChildItem -Path $Config.LogFolder -Filter "Backup_*.log" |
                      Where-Object { $_.LastWriteTime -lt $CutoffDate }

        if ($OldLogs.Count -eq 0) {
            Write-Log "No old logs found." -Level INFO
        }
        else {
            foreach ($Log in $OldLogs) {
                Remove-Item -Path $Log.FullName -Force
                Write-Log "Log deleted: $($Log.Name)" -Level INFO
            }
            Write-Log "Successfully deleted $($OldLogs.Count) old logs." -Level SUCCESS
        }
    }
    catch {
        Write-Log "Error deleting logs: $($_.Exception.Message)" -Level ERROR
    }
}

# ============================================================
# UPDATE SOFTWARE VIA CHOCOLATEY
# ============================================================
function Update-Software {
    Write-Log "====== UPDATE SOFTWARE ======" -Level INFO

    if (!$Config.AutoUpdateEnabled) {
        Write-Log "Auto update DISABLED, skipping." -Level WARNING
        return
    }

    $ChocoInstalled = Get-Command choco -ErrorAction SilentlyContinue
    if (!$ChocoInstalled) {
        Write-Log "Chocolatey is not installed. Visit: https://chocolatey.org/install" -Level WARNING
        return
    }

    foreach ($Software in $Config.SoftwareList) {
        Write-Log "Updating $Software..." -Level INFO
        try {
            choco upgrade $Software -y --no-progress 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "$Software successfully updated." -Level SUCCESS
            }
            else {
                Write-Log "$Software: might have errored or is already up to date" -Level WARNING
            }
        }
        catch {
            Write-Log "Error updating $Software: $($_.Exception.Message)" -Level ERROR
        }
    }
}

# ============================================================
# DISPLAY FINAL SUMMARY
# ============================================================
function Show-Summary {
    param(
        [string]$ZipPath,
        [bool]$Success
    )

    $StatusText = if ($Success) { "SUCCESS" } else { "FAILED" }
    $StatusColor = if ($Success) { 'Green' } else { 'Red' }

    Write-Host ""
    Write-Host "  +--------------------------------------------------+" -ForegroundColor $StatusColor
    Write-Host "  |                 BACKUP SUMMARY                   |" -ForegroundColor White
    Write-Host "  +--------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  | Status     : $($StatusText.PadRight(38))|" -ForegroundColor $StatusColor
    Write-Host "  | Total files: $($Script:Stats.FileCount.ToString().PadRight(38))|" -ForegroundColor Cyan
    Write-Host "  | Total size : $("$($Script:Stats.TotalSizeMB) MB".PadRight(38))|" -ForegroundColor Cyan
    Write-Host "  | Duration   : $("$($Script:Stats.Duration) seconds".PadRight(38))|" -ForegroundColor Cyan
    Write-Host "  | Errors     : $($Script:Stats.Errors.ToString().PadRight(38))|" -ForegroundColor $(if ($Script:Stats.Errors -gt 0) { 'Yellow' } else { 'Cyan' })
    if ($ZipPath) {
        $ZipName = Split-Path $ZipPath -Leaf
        Write-Host "  | ZIP File   : $($ZipName.PadRight(38))|" -ForegroundColor Cyan
    }
    Write-Host "  +--------------------------------------------------+" -ForegroundColor $StatusColor
    Write-Host ""
    Write-Host "  Backup location : $($Config.BackupDestination)" -ForegroundColor White
    Write-Host "  Log saved       : $($Script:LogFile)" -ForegroundColor White
    Write-Host ""
    Write-Host "  -------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Script completed! (c) By YukiiKazunomiya" -ForegroundColor Magenta
    Write-Host "  -------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================
# MAIN PROGRAM
# ============================================================

Show-Watermark
Show-Configuration

# 1. Run backup process
$ZipPath = Start-BackupProcess

# 2. Delete old backups & logs
Remove-OldBackups
Remove-OldLogs

# 3. Update software (optional, default DISABLED)
Update-Software

# 4. Send ONE email notification with all attachments at once
$EmailAttachments = @()
$LogCopyPath      = $null

# Create a log copy to prevent locking when attaching
if ($null -ne $Script:LogFile -and (Test-Path $Script:LogFile)) {
    $LogCopyPath = "$($Script:LogFile).tmp"
    Copy-Item $Script:LogFile $LogCopyPath -Force
    $EmailAttachments += $LogCopyPath
}

if ($null -ne $ZipPath) {
    # ── Backup SUCCESS ─────────────────────────────────────
    $EmailSubject = "[Backup Success] $env:COMPUTERNAME - $(Get-Date -Format 'yyyy/MM/dd HH:mm')"
    $EmailBody    = "Hello,

Automated backup has been SUCCESSFULLY executed on computer $env:COMPUTERNAME.

Backup Details:
  Computer  : $env:COMPUTERNAME
  User      : $env:USERNAME
  Time      : $(Get-Date -Format 'MMMM dd, yyyy, HH:mm:ss')
  Total file: $($Script:Stats.FileCount) files
  Size      : $($Script:Stats.TotalSizeMB) MB
  Duration  : $($Script:Stats.Duration) seconds
  Errors    : $($Script:Stats.Errors)

Backed up folders:
$(($Config.BackupFolders | ForEach-Object { "  - $_" }) -join "`n")

Backup file saved at: $($Config.BackupDestination)

---
Backup & Maintenance Automation System v2.0
(c) 2025 YukiiKazunomiya"

    # Attach ZIP if not too large
    $ZipSizeMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
    if ($ZipSizeMB -le $Config.MaxEmailAttachmentMB) {
        $EmailAttachments += $ZipPath
        Write-Log "ZIP will be attached to email ($ZipSizeMB MB)" -Level INFO
    }
    else {
        Write-Log "ZIP too large ($ZipSizeMB MB > $($Config.MaxEmailAttachmentMB) MB limit), not attached." -Level WARNING
        $EmailBody += "`n`nNOTE: ZIP file was not attached because its size ($ZipSizeMB MB) exceeds the limit ($($Config.MaxEmailAttachmentMB) MB). Retrieve backup directly from PC at: $($Config.BackupDestination)"
    }

    # Send 1 email only
    Send-NotificationEmail -Subject $EmailSubject -Body $EmailBody -AttachmentPaths $EmailAttachments
    Show-Summary -ZipPath $ZipPath -Success $true

}
else {
    # ── Backup FAILED ──────────────────────────────────────
    $EmailSubject = "[BACKUP FAILED] $env:COMPUTERNAME - $(Get-Date -Format 'yyyy/MM/dd HH:mm')"
    $EmailBody    = "ATTENTION: Backup FAILED on computer $env:COMPUTERNAME!

Details:
  Computer : $env:COMPUTERNAME
  User     : $env:USERNAME
  Time     : $(Get-Date -Format 'MMMM dd, yyyy, HH:mm:ss')

Please check the attached log to find the cause of failure.
Log saved at: $($Script:LogFile)

---
Backup & Maintenance Automation System v2.0
(c) 2025 YukiiKazunomiya"

    Send-NotificationEmail -Subject $EmailSubject -Body $EmailBody -AttachmentPaths $EmailAttachments
    Show-Summary -ZipPath $null -Success $false
}

# Delete temporary log file
if ($null -ne $LogCopyPath -and (Test-Path $LogCopyPath)) {
    Remove-Item $LogCopyPath -Force -ErrorAction SilentlyContinue
}

Write-Log "====== PROCESS COMPLETED ======" -Level SUCCESS
