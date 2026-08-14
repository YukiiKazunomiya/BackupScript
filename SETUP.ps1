# ╔════════════════════════════════════════════════════════════╗
# ║     BACKUP SYSTEM SETUP — Interactive Configuration        ║
# ║     Created By: YukiiKazunomiya  |  Version 2.0           ║
# ╚════════════════════════════════════════════════════════════╝
#
# This script helps you to:
#   1. Configure BackupSystem.ps1 (email, folders, etc.)
#   2. Register automated backup to Windows Task Scheduler
#
# Run by: Right-click > Run with PowerShell (As Administrator)
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
# DISPLAY HEADER
# ============================================================
Clear-Host
Write-Host ""
Write-Host "  +==================================================+" -ForegroundColor Magenta
Write-Host "  |     Backup System - Interactive Setup            |" -ForegroundColor Cyan
Write-Host "  |     Version 2.0  -  (c) 2025 YukiiKazunomiya    |" -ForegroundColor Magenta
Write-Host "  +==================================================+" -ForegroundColor Magenta
Write-Host ""
Write-Host "  This script will help you configure automated backups." -ForegroundColor White
Write-Host "  Press ENTER to use the default values displayed." -ForegroundColor DarkGray
Write-Host ""

# ============================================================
# STEP 1: LOCATE BackupSystem.ps1
# ============================================================
Write-Title "STEP 1: Script Location"

$ScriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Path
$DefaultScript  = Join-Path $ScriptDir "BackupSystem.ps1"

if (Test-Path $DefaultScript) {
    Write-Host "  Found: $DefaultScript" -ForegroundColor Green
    $ScriptPath = $DefaultScript
}
else {
    Write-Host "  BackupSystem.ps1 was not found in this folder." -ForegroundColor Yellow
    $ScriptPath = Prompt-Input "Full path to BackupSystem.ps1" $DefaultScript
    if (!(Test-Path $ScriptPath)) {
        Write-Host "  ERROR: File not found. Setup aborted." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# ============================================================
# STEP 2: CONFIGURE BACKUP FOLDERS
# ============================================================
Write-Title "STEP 2: Folders to Backup"

Write-Host "  Default folders to be backed up from your user profile:" -ForegroundColor White
$DefaultFolders = @("Documents", "Desktop", "Pictures", "Downloads", "Videos")
foreach ($F in $DefaultFolders) {
    $Path   = Join-Path $env:USERPROFILE $F
    $Status = if (Test-Path $Path) { "[Found]" } else { "[Not found]" }
    Write-Host "    - $F  $Status" -ForegroundColor $(if (Test-Path $Path) { 'Cyan' } else { 'DarkGray' })
}
Write-Host ""

$UseCustomFolders = Prompt-YesNo "Use the default folder list above?" $true
$FolderList       = $DefaultFolders

if (-not $UseCustomFolders) {
    Write-Host "  Enter folder names (comma separated, relative to C:\Users\$env:USERNAME\):" -ForegroundColor Yellow
    Write-Host "  Example: Documents,Desktop,Pictures,Downloads" -ForegroundColor DarkGray
    $Input      = Prompt-Input "Folders" "Documents,Desktop,Pictures,Downloads"
    $FolderList = $Input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}

$BackupDest = Prompt-Input "Backup destination on PC" "C:\BackupData"
$MaxAge     = Prompt-Input "Delete backups older than how many days?" "30"

# ============================================================
# STEP 3: CONFIGURE EMAIL
# ============================================================
Write-Title "STEP 3: Email Notifications"

Write-Host "  IMPORTANT: Use a Gmail App Password, not your regular password!" -ForegroundColor Yellow
Write-Host "  How to create: myaccount.google.com > Security > App Passwords" -ForegroundColor DarkGray
Write-Host ""

$EmailEnabled = Prompt-YesNo "Enable email notifications?" $true
$EmailFrom    = ""
$EmailTo      = ""
$EmailPass    = ""

if ($EmailEnabled) {
    $EmailFrom = Prompt-Input "Sender email (Your Gmail)" "yukiidesu@gmail.com"
    $EmailTo   = Prompt-Input "Recipient email" $EmailFrom
    Write-Host "  Gmail App Password" -ForegroundColor Yellow -NoNewline
    Write-Host " : " -NoNewline
    $SecurePass = Read-Host -AsSecureString
    $Bstr       = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
    $EmailPass  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Bstr)
}

$MaxAttachMB = Prompt-Input "Max ZIP attachment size via email (MB)" "20"

# ============================================================
# STEP 4: AUTO UPDATE (CHOCOLATEY)
# ============================================================
Write-Title "STEP 4: Auto Update Software"

Write-Host "  This feature requires Chocolatey (https://chocolatey.org/install)" -ForegroundColor DarkGray
$AutoUpdate = Prompt-YesNo "Enable auto update via Chocolatey?" $false

$SoftwareList = @("googlechrome", "adobereader", "7zip")
if ($AutoUpdate) {
    Write-Host "  Default software: googlechrome, adobereader, 7zip" -ForegroundColor White
    $CustomSW = Prompt-YesNo "Use default software list?" $true
    if (-not $CustomSW) {
        $SWInput      = Prompt-Input "Chocolatey package names (comma separated)" "googlechrome,adobereader,7zip"
        $SoftwareList = $SWInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    }
}

# ============================================================
# STEP 5: LOGGING
# ============================================================
Write-Title "STEP 5: Log Settings"

$LogFolder    = Prompt-Input "Log storage folder" "C:\BackupLogs"
$LogRetention = Prompt-Input "Delete logs older than how many days?" "90"

# ============================================================
# STEP 6: AUTOMATED SCHEDULE (TASK SCHEDULER)
# ============================================================
Write-Title "STEP 6: Automated Backup Schedule"

Write-Host "  Register automated backup to Windows Task Scheduler?" -ForegroundColor White
$UseSchedule = Prompt-YesNo "Enable automated schedule?" $true

$ScheduleType = "Daily"
$ScheduleTime = "02:00"

if ($UseSchedule) {
    Write-Host ""
    Write-Host "  Select schedule type:" -ForegroundColor Yellow
    Write-Host "    1. Daily" -ForegroundColor White
    Write-Host "    2. Weekly (Monday)" -ForegroundColor White
    Write-Host "    3. Monthly (1st of the month)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Choice [1/2/3]" -ForegroundColor Yellow -NoNewline
    Write-Host " : " -NoNewline
    $ScheduleChoice = Read-Host
    switch ($ScheduleChoice) {
        "2" { $ScheduleType = "Weekly" }
        "3" { $ScheduleType = "Monthly" }
        default { $ScheduleType = "Daily" }
    }
    $ScheduleTime = Prompt-Input "Backup time (24-hour format, e.g., 02:00)" "02:00"
}

# ============================================================
# CONFIRM & WRITE CONFIG
# ============================================================
Write-Title "CONFIRM CONFIGURATION"

Write-Host "  Backup folders    : $($FolderList -join ', ')" -ForegroundColor Cyan
Write-Host "  Backup dest       : $BackupDest" -ForegroundColor Cyan
Write-Host "  Max backup age    : $MaxAge days" -ForegroundColor Cyan
Write-Host "  Email enabled     : $EmailEnabled" -ForegroundColor Cyan
if ($EmailEnabled) {
    Write-Host "  Email from        : $EmailFrom" -ForegroundColor Cyan
    Write-Host "  Email to          : $EmailTo" -ForegroundColor Cyan
}
Write-Host "  Auto update       : $AutoUpdate" -ForegroundColor Cyan
Write-Host "  Log folder        : $LogFolder" -ForegroundColor Cyan
Write-Host "  Log retention     : $LogRetention days" -ForegroundColor Cyan
if ($UseSchedule) {
    Write-Host "  Backup schedule   : $ScheduleType, at $ScheduleTime" -ForegroundColor Cyan
}
Write-Host ""

$Confirm = Prompt-YesNo "Save configuration and continue?" $true
if (-not $Confirm) {
    Write-Host "  Setup cancelled by user." -ForegroundColor Yellow
    exit 0
}

# ============================================================
# WRITE CONFIGURATION FILE
# ============================================================
Write-Host ""
Write-Host "  Writing configuration to BackupSystem.ps1..." -ForegroundColor White

$Content = Get-Content $ScriptPath -Raw -Encoding UTF8

# Replace each configuration value using regex
$FolderListStr = ($FolderList | ForEach-Object { "        `"$_`"" }) -join ",`n"

# Create new BackupFolders block
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
Write-Host "  Configuration saved successfully." -ForegroundColor Green

# ============================================================
# REGISTER TASK SCHEDULER
# ============================================================
if ($UseSchedule) {
    Write-Host ""
    Write-Host "  Registering Windows Task Scheduler..." -ForegroundColor White

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
            -RunOnlyIfNetworkAvailable:$false `
            -WakeToRun `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries

        $TaskPrincipal = New-ScheduledTaskPrincipal `
            -UserId "$env:USERDOMAIN\$env:USERNAME" `
            -LogonType Interactive `
            -RunLevel Highest

        # Delete old task if it exists
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

        Register-ScheduledTask `
            -TaskName   $TaskName `
            -Action     $TaskAction `
            -Trigger    $TaskTrigger `
            -Settings   $TaskSettings `
            -Principal  $TaskPrincipal `
            -Description "Automated backup by BackupSystem v2.0 - YukiiKazunomiya" | Out-Null

        Write-Host "  Task Scheduler registered successfully!" -ForegroundColor Green
        Write-Host "  Task Name : $TaskName" -ForegroundColor Cyan
        Write-Host "  Schedule  : $ScheduleType, at $ScheduleTime" -ForegroundColor Cyan
        Write-Host "  Check in  : Task Scheduler > Task Scheduler Library > $TaskName" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "  ERROR registering Task Scheduler: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Ensure the script is running as Administrator." -ForegroundColor Yellow
    }
}

# ============================================================
# DONE
# ============================================================
Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
Write-Host "  |  Setup complete! Next steps:                     |" -ForegroundColor White
Write-Host "  |                                                  |" -ForegroundColor DarkGray
Write-Host "  |  1. Ensure Gmail App Password is filled          |" -ForegroundColor White
Write-Host "  |  2. Try running BackupSystem.ps1 manually first  |" -ForegroundColor White
if ($UseSchedule) {
    Write-Host "  |  3. Check Task Scheduler to verify the schedule  |" -ForegroundColor White
}
Write-Host "  |                                                  |" -ForegroundColor DarkGray
Write-Host "  |  (c) 2025 YukiiKazunomiya                        |" -ForegroundColor Magenta
Write-Host "  +--------------------------------------------------+" -ForegroundColor Green
Write-Host ""

Pause
