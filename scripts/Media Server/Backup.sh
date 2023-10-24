#!/bin/bash

CONFIG="$(dirname "${BASH_SOURCE[0]}")/BackupRestore.conf"
. $CONFIG

# Create a log file to record command outputs
touch "$LogFile"
exec > >(tee -a "$LogFile")
exec 2>&1

## ---------------------------------- TESTS ------------------------------ #

# Check if the script is being executed by root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "========== This script needs to be executed as root or with sudo. ==========" 
   exit 1
fi

# Check if the removable drive is connected and mounted correctly
if [[ $(lsblk -no uuid /dev/sd*) == *"$uuid"* ]]; then
    echo "========== The drive is connected and mounted. =========="
    echo ""
else
    echo "========== The drive is not connected or mounted. =========="

    # Try to mount the drive
    sudo mount -U $uuid $BackupDir 2>/dev/null

    # Check if the drive is now mounted
    if [[ $(lsblk -no uuid /dev/sd*) == *"$uuid"* ]]; then
        echo "========== The drive has been successfully mounted. =========="
        echo ""
    else
        echo "========== Failed to mount the drive. Exiting script. =========="
        exit 1
    fi
fi

# Are there write and read permissions?
if [ ! -w "$BackupDir" ]; then
    echo "========== No write permissions =========="
    exit 1
fi

## -------------------------- MAIN SCRIPT -------------------------- #

echo "Starting Backup $(date)..."

# Function to backup
backup() {
    echo "=============== Backing up Media Server settings... ==============="
    echo ""

    # Stop Media Server
    systemctl stop "$MediaserverService"

    # Backup
    sudo rsync -avhP --delete --exclude={'*/Cache','*/cache','*/Crash Reports','*/Diagnostics','*/Logs','*/logs','*/transcoding-temp'} "$MediaserverConf" "$BackupDir/Mediaserver" 1>> $LogFile

    # Start Media Server
    systemctl start "$MediaserverService"
    
    # Worked well? Unmount.
    if [ $? -eq 0 ]; then
        echo ""
        echo "Backup completed. The removable drive has been unmounted and powered off."
        umount "/dev/disk/by-uuid/$uuid"
        sudo udisksctl power-off -b "/dev/disk/by-uuid/$uuid"
        exit 0
    fi
}

# Call the backup function
backup
