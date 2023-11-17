#!/bin/bash

# Make sure the script exits when any command fails
set -Eeuo pipefail

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
CONFIG="$SCRIPT_DIR/BackupRestore.conf"

# Check if config file exists
if [ ! -f "$CONFIG" ]; then
    echo "ERROR: Configuration file $CONFIG cannot be found!"
    echo "Please make sure that a configuration file '$CONFIG' is present in the main directory of the scripts."
    echo "This file can be created automatically using the setup.sh script."
    exit 1
fi

source "$CONFIG"

ARCHIVE_DATE=${2:-""}

# Create a log file to record command outputs
touch "$LogFile"
exec > >(tee -a "$LogFile")
exec 2>&1

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; } 

## ---------------------------------- TESTS ------------------------------ #
# Check if the script is being executed by root or with sudo
if [ $EUID -ne 0 ]; then
   echo "========== This script needs to be executed as root or with sudo. ==========" 
   exit 1
fi

# Change to the root directory, and exit with an error message if it fails
if cd /; then
    echo "Changed to the root directory ($(pwd))"
    echo "Location of the database backup file is /"
else
    echo "Failed to change to the root directory. Restoration failed."
    exit 1
fi

device=$(blkid -U "$uuid")

if [ -z "$device" ]; then
  echo "========== The unit with UUID $uuid Is not connected. Leaving the script.=========="
  exit 1
fi

echo "========== The unit with UUID $uuid is connected and corresponds to the device $device. =========="

# Check that the unit is assembled
if grep -qs "$BackupDisk" /proc/mounts; then
  echo "========== The unit is assembled ==========."
else
  echo "========== The unit is not assembled. Trying to assemble...=========="

  # Try to assemble the unit
  if mount "$device" "$BackupDisk"; then
    echo "========== The unit was successfully assembled.=========="
  else
    echo "========== Failure when setting up the unit. Leaving the script.=========="
    exit 1
  fi
fi

# Are there write and read permissions?
if [ ! -w "$BackupDisk" ]; then
    echo "========== No write permissions =========="
    exit 1
fi

# -------------------------------FUNCTIONS----------------------------------------- #
# Obtaining file information and dates to be restored
check_restore() {
    # Check if the restoration date is specified
    if [ -z "$ARCHIVE_DATE" ]
    then        
        read -p "Enter the restoration date (YYYY-MM-DD): " ARCHIVE_DATE
    if [ -z "$ARCHIVE_DATE" ]
    then
        echo "No date provided. Going off script."
        exit 1
    fi
 fi

    # Find the backup file name corresponding to the specified date
    ARCHIVE_NAME=$(borg list $BORG_REPO | grep $ARCHIVE_DATE | awk '{print $1}')

    # Check if the backup file is found
    if [ -z "$ARCHIVE_NAME" ]
    then
        echo "Could not find a backup file for the specified date: $ARCHIVE_DATE"
        exit 1
    fi

}

# Function to Restore 
Restore() {
    check_restore

    # Stop Media Server
    sudo systemctl stop $MediaserverService

    # Remove the current directory from Media Derver
    mv "$MediaserverConf" "$MediaserverConf.bk"

    echo "========== Restoring Media Server settings $( date )... =========="
    echo ""

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME "$MediaserverConf"

    # Restore permissions
    chmod -R 755 $MediaserverConf
    chown -R $MediaserverUser:$MediaserverUser $MediaserverConf

    # Add the Media Server User to the www-data group to access Nextcloud folders
    sudo adduser $MediaserverUser www-data

    # Start Media Server
    sudo systemctl start $MediaserverService

    # Removing unnecessary files
    rm -rf "$MediaserverConf.bk"
}

    # Worked well? Unmount.
    if [ $? -eq 0 ]; then
        echo ""
        echo "Restore completed. The removable drive has been unmounted and powered off."
        umount "/dev/disk/by-uuid/$uuid"
        sudo udisksctl power-off -b "/dev/disk/by-uuid/$uuid"
        exit 0
    fi

# Call the restore function
Restore $2