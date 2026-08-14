# 💾 Backup & Maintenance Automation System

<div align="center">

![Version](https://img.shields.io/badge/version-2.0-blueviolet?style=for-the-badge)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?style=for-the-badge&logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D4?style=for-the-badge&logo=windows)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

**Automated PowerShell-based backup system for Windows**  
Backup important data, compress to ZIP, send email notifications — all automatically!

*Created by [YukiiKazunomiya](https://github.com/YukiiKazunomiya) • November 2025*

</div>

---

## 📋 Table of Contents

- [Features](#-features)
- [How it Works](#-how-it-works)
- [Requirements](#-requirements)
- [Installation & Configuration](#-installation--configuration)
- [How to Run](#-how-to-run)
- [Automated Backup (Task Scheduler)](#-automated-backup-task-scheduler)
- [Advanced Configuration](#-advanced-configuration)
- [Folder Structure](#-folder-structure)
- [FAQ & Troubleshooting](#-faq--troubleshooting)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 📂 **Auto-detect folders** | Automatically backup Documents, Desktop, Pictures, Downloads, Videos |
| 🗜️ **ZIP Compression** | Compressed output to save disk space |
| 📧 **Email Notifications** | Send backup reports + ZIP/log attachments via Gmail |
| 🗑️ **Auto cleanup** | Automatically delete old backups & logs |
| ⚙️ **Software Updates** | Update applications via Chocolatey (optional) |
| 📊 **Detailed Summary** | Statistics report: file count, size, duration, errors |
| 📋 **Comprehensive Logging** | All activities are recorded to a daily log file |
| ⏰ **Task Scheduler** | Setup daily/weekly/monthly automated backups |
| 🛡️ **Error Handling** | Handles errors gracefully without crashing |
| 🖥️ **Multi-PC** | Suitable for office PCs, personal laptops, or servers |

---

## 🔄 How it Works

```text
┌─────────────────────────────────────────────────────────┐
│                   BackupSystem.ps1                      │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐    ┌──────────────────────────────────┐
│  Read Config    │───▶│ BackupFolders: Documents,        │
│                 │    │  Desktop, Pictures, Downloads,   │
└─────────────────┘    │  Videos (customizable)           │
         │             └──────────────────────────────────┘
         ▼
┌─────────────────────────────────────────────────────────┐
│  BACKUP PROCESS                                         │
│                                                         │
│  C:\Users\<user>\Documents  ──┐                         │
│  C:\Users\<user>\Desktop    ──┤                         │
│  C:\Users\<user>\Pictures   ──┼──▶  C:\BackupData\      │
│  C:\Users\<user>\Downloads  ──┤     Backup_20251101\    │
│  C:\Users\<user>\Videos     ──┘     ├── Documents\      │
│                                     ├── Desktop\        │
│                                     ├── Pictures\       │
│                                     ├── Downloads\      │
│                                     └── Videos\         │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  COMPRESS to ZIP                                        │
│  Backup_20251101_143000\  ──▶  Backup_20251101_143000.zip│
└─────────────────────────────────────────────────────────┘
         │
         ├──▶  Delete old backups (> 30 days)
         ├──▶  Delete old logs    (> 90 days)
         ├──▶  Update software    (optional)
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  SEND EMAIL (1x, no duplicates)                         │
│                                                         │
│  Subject: [Backup Success] MYPC - 01/11/2025 14:30      │
│  Body   : Detailed backup report                        │
│  Attach : Backup_20251101.zip + Backup_20251101.log     │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  DONE — Display summary in console                      │
└─────────────────────────────────────────────────────────┘
```

---

## 📦 Requirements

- **OS**: Windows 10 / Windows 11
- **PowerShell**: Version 5.1 or newer (pre-installed on Windows 10/11)
- **Gmail Account**: For email notifications (Requires App Password)
- **Chocolatey** *(optional)*: For the auto software update feature
- **Administrator Rights**: Required to run SETUP.ps1 and register the Task Scheduler

---

## 🚀 Installation & Configuration

### Method 1: Interactive Setup (Recommended) ⭐

1. **Download** or clone this repository
2. **Right-click** `SETUP.ps1` → **"Run with PowerShell"**  
   *(If prompted for admin privileges, click "Yes")*
3. Follow the setup guide that appears:
   - Select the folders you want to backup
   - Enter your email and Gmail App Password
   - Choose the automated backup schedule (daily/weekly/monthly)
4. Setup complete! Backups will run automatically according to the schedule.

### Method 2: Manual Configuration

Open `BackupSystem.ps1` with a text editor, then edit the `$Config` section:

```powershell
$Config = @{

    # Folders from C:\Users\<username>\ to be backed up
    BackupFolders     = @(
        "Documents",    # Remove this line if not needed
        "Desktop",
        "Pictures",
        "Downloads",
        "Videos"
    )

    # Destination for backups on the PC
    BackupDestination = "C:\BackupData"

    # Delete backups older than 30 days
    MaxBackupAge      = 30

    # Email configuration
    EmailEnabled      = $true
    SmtpServer        = "smtp.gmail.com"
    SmtpPort          = 587
    EmailFrom         = "youremail@gmail.com"
    EmailTo           = "targetemail@gmail.com"
    EmailPassword     = "xxxx xxxx xxxx xxxx"  # Gmail App Password

    # If the backup is > 20MB, the ZIP is not attached (only the log)
    MaxEmailAttachmentMB = 20

    # Auto update via Chocolatey (false = disabled)
    AutoUpdateEnabled = $false
    SoftwareList      = @("googlechrome", "adobereader", "7zip")

    # Log configuration
    LogFolder         = "C:\BackupLogs"
    LogRetentionDays  = 90
}
```

---

## ▶️ How to Run

### Run Manually

```powershell
# Open PowerShell as Administrator, then:
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
& "C:\path\to\BackupSystem.ps1"
```

Or **right-click** `BackupSystem.ps1` → **"Run with PowerShell"**

### Expected Output

```text
  +==================================================+
  |    Backup & Maintenance Automation System        |
  |    Version 2.0  -  (c) 2025 YukiiKazunomiya     |
  +==================================================+

[2025-11-01 14:30:00] [INFO] ====== SYSTEM CONFIGURATION ======
[2025-11-01 14:30:00] [INFO] Active User       : YukiiKazunomiya
[2025-11-01 14:30:00] [INFO] Backup destination: C:\BackupData
...
[2025-11-01 14:30:01] [INFO] ====== STARTING BACKUP ======
[2025-11-01 14:30:01] [INFO] Backing up Documents (1,234 files, 256.5 MB)...
[2025-11-01 14:31:45] [SUCCESS] Documents backup completed.
...
[2025-11-01 14:33:00] [SUCCESS] ZIP successfully created: C:\BackupData\Backup_20251101_143000.zip
...
  +--------------------------------------------------+
  |                 BACKUP SUMMARY                   |
  +--------------------------------------------------+
  | Status     : SUCCESS                             |
  | Total files: 3,456                               |
  | Total size : 892.3 MB                            |
  | Duration   : 178.5 seconds                       |
  | Errors     : 0                                   |
  | ZIP File   : Backup_20251101_143000.zip          |
  +--------------------------------------------------+
```

---

## ⏰ Automated Backup (Task Scheduler)

### Via SETUP.ps1 (Recommended)

When running `SETUP.ps1`, you will be asked if you want to register an automated schedule. Select "Y" and set the backup time.

### Manually via PowerShell

```powershell
# Example: Backup every day at 02:00 AM
$Action  = New-ScheduledTaskAction -Execute "powershell.exe" `
               -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File 'C:\path\to\BackupSystem.ps1'"
$Trigger = New-ScheduledTaskTrigger -Daily -At "02:00"
Register-ScheduledTask -TaskName "BackupSystem" -Action $Action -Trigger $Trigger -RunLevel Highest
```

### Check Task Status

1. Press `Win + R` → type `taskschd.msc` → Enter
2. Open **Task Scheduler Library**
3. Look for **BackupSystem_YukiiKazunomiya**

---

## ⚙️ Advanced Configuration

### Adding Custom Backup Folders

```powershell
BackupFolders = @(
    "Documents",
    "Desktop",
    "Pictures",
    "Downloads",
    "Videos",
    "AppData\Roaming\MyApp",  # Folder within the user profile
)
```

> **Note**: All paths in `BackupFolders` are **relative** to `C:\Users\<username>\`

### Backing Up Very Large Data

If the data exceeds 25MB (Gmail limit), set `MaxEmailAttachmentMB = 0` so the ZIP is not attached. You will still receive the email report + log, and the ZIP file will be safely stored on your PC.

```powershell
MaxEmailAttachmentMB = 0  # Never attach the ZIP
```

### Disabling Email

```powershell
EmailEnabled = $false
```

The script will still run and the backup will be created, but the email will simply not be sent.

---

## 📁 Folder Structure

```text
BackupSystem/
├── BackupSystem.ps1     ← Main script (run this for backup)
├── SETUP.ps1            ← Interactive setup + Task Scheduler
└── README.md            ← This documentation

C:\BackupData\           ← Backup destination (default config)
├── Backup_20251101_143000.zip
├── Backup_20251029_020000.zip
└── ...

C:\BackupLogs\           ← Daily log files (default config)
├── Backup_20251101.log
├── Backup_20251029.log
└── ...
```

---

## ❓ FAQ & Troubleshooting

### ❌ "Cannot be loaded because running scripts is disabled"

**Solution**: Run this command in PowerShell (Admin):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

### ❌ Email sending failed / "535 Authentication failed"

**Cause**: Using your regular Gmail password instead of an App Password.

**Solution**:
1. Go to [myaccount.google.com](https://myaccount.google.com)
2. Navigate to **Security** → **2-Step Verification** (enable it first if not already)
3. Scroll down to → **App Passwords**
4. Select app: **Mail**, device: **Windows Computer**
5. Copy the 16 characters generated (format: `xxxx xxxx xxxx xxxx`)
6. Paste it into `EmailPassword` in the script (without spaces)

---

### ❌ "Source folder not found"

**Cause**: The folder configured in `BackupFolders` does not exist in the user profile.

**Solution**: The script will automatically skip folders that are not found and continue backing up the rest. Check the output to see which folders were skipped.

---

### ❌ ZIP doesn't appear in the email

**Cause**: The ZIP size exceeds `MaxEmailAttachmentMB` (default: 20 MB).

**Solution**: 
- Increase the limit: `MaxEmailAttachmentMB = 25` (Gmail max ~25MB)
- Or simply retrieve the ZIP file directly from `C:\BackupData\` on your PC.

---

### ❌ Task Scheduler doesn't run when PC is asleep/off

**Solution**: In Task Scheduler, open the task properties → **Conditions** tab → uncheck "Start the task only if the computer is on AC power" and check "Wake the computer to run this task" if necessary.

---

### ❓ How do I restore a backup?

1. Open `C:\BackupData\`
2. Find the ZIP file with the desired date: `Backup_YYYYMMDD_HHmmss.zip`
3. Right-click → **Extract All**
4. Files are organized in sub-folders: `Documents\`, `Desktop\`, etc.
5. Copy the files you need back to their original locations.

---

## 📄 License

MIT License — Free to use, modify, and distribute.  
Please include credits if you use it.

---

<div align="center">

**Made with ❤️ by YukiiKazunomiya**  
*Automated backups = safe data = sound sleep* 💤

</div>
