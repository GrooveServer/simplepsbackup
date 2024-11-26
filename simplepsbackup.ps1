<#
.SYNOPSIS
    Direct Compressed Backup Script

.DESCRIPTION
    This script performs a backup of a predefined list of folders to a specified network location, compressing the data using 7-Zip. Notifications are displayed using the BurntToast module.

.AUTHOR
    GrooveServer - November 23, 2024

.REQUIREMENTS
    - PowerShell 5.0 or higher
    - 7-Zip installed (ensure the executable path is correct, I wrote this with 7zip 23.01 installed)
    - BurntToast module installed for notifications (Script will install the module if its not present)

.PARAMETERS
    None

.NOTES
    - Set source folders ($sourceFolders) and destination path ($backupRootDestination)
    - The backup files are saved with a timestamp in the filename.
    - Only the latest 10 backups are retained; older backups are deleted automatically.
    - A log file ("BackupLog.txt") is maintained in the backup destination folder.

.EXAMPLE
    To execute the script, run it in PowerShell:
    ```powershell
    .\BackupScript.ps1
    ```

#>

# Import the BurntToast module for notifications (ensure it is installed)
if (!(Get-Module -ListAvailable -Name BurntToast)) {
    Install-Module -Name BurntToast -Force -Scope CurrentUser
}

# Define the source folders and backup root destination
$sourceFolders = @(
    "C:\Users\Example1",
    "C:\Users\Example2",
    "C:\Users\Example3",
    "C:\Users\Example4\Pictures"
)
$backupRootDestination = "\\192.168.x.x\example\Backup"  # Network path for backups
$dateSuffix = (Get-Date).ToString("yyyy-MM-dd")  # Current date for folder name
$compressedBackupFile = Join-Path -Path $backupRootDestination -ChildPath "Backup_$dateSuffix.zip"

# Define the path to 7-Zip (adjust if installed elsewhere)
$sevenZipPath = "C:\Program Files\7-Zip\7z.exe"

# Record the start time
$startTime = Get-Date

# Ensure the network backup destination is accessible
if (!(Test-Path -Path $backupRootDestination)) {
    Write-Host "Cannot access network path: $backupRootDestination" -ForegroundColor Red
    New-BurntToastNotification -Text "Backup Failed", "Cannot access the network path: $backupRootDestination."
    exit
}

# Compress using 7-Zip
Write-Host "Starting direct compression to $compressedBackupFile using 7-Zip..." -ForegroundColor Cyan
if (Test-Path -Path $compressedBackupFile) {
    Remove-Item -Path $compressedBackupFile -Force
}

try {
    # Quote each folder path individually
    $quotedFolders = $sourceFolders | ForEach-Object { "`"$_`"" }
    $foldersToCompress = $quotedFolders -join " "

    # Build the compression command
    $compressionCommand = "a -tzip `"$compressedBackupFile`" $foldersToCompress"

    # Execute the 7-Zip compression
    Start-Process -NoNewWindow -Wait -FilePath "$sevenZipPath" -ArgumentList $compressionCommand
    Write-Host "Compression completed successfully using 7-Zip: $compressedBackupFile" -ForegroundColor Green
    New-BurntToastNotification -Text "Backup Complete", "Backup compressed to $compressedBackupFile successfully."
} catch {
    Write-Host "An error occurred during compression: $_" -ForegroundColor Red
    New-BurntToastNotification -Text "Backup Failed", "An error occurred during compression using 7-Zip: $_."
    exit
}

# Rotate backups (keep only the latest 10 backups)
Write-Host "Rotating backups: Keeping the latest 10 backups..." -ForegroundColor Cyan
$backups = Get-ChildItem -Path $backupRootDestination -Filter "*.zip" | Sort-Object -Property LastWriteTime -Descending
if ($backups.Count -gt 10) {
    $backupsToDelete = $backups | Select-Object -Skip 10
    foreach ($backup in $backupsToDelete) {
        Write-Host "Deleting old backup: $($backup.FullName)" -ForegroundColor Yellow
        Remove-Item -Recurse -Force -Path $backup.FullName
    }
}

# Calculate duration
$endTime = Get-Date
$duration = $endTime - $startTime
$durationText = "{0:hh\:mm\:ss}" -f $duration

# Final notification with duration
New-BurntToastNotification -Text "Backup Complete", "Backup completed successfully in $durationText."

# Log duration to console and backup log
Write-Host "Backup completed in $durationText." -ForegroundColor Green
$logFile = Join-Path -Path $backupRootDestination -ChildPath "BackupLog.txt"
Add-Content -Path $logFile -Value "$(Get-Date): Backup completed successfully in $durationText."
