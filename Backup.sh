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

# Create a log file to record command outputs
touch "$LogFile"
exec > >(tee -a "$LogFile")
exec 2>&1

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

## ---------------------------------- TESTS ------------------------------ #

# Check if the script is being executed by root or with sudo
if [ $EUID -ne 0 ]; then
   echo "========== This script needs to be executed as root or with sudo. ==========" 
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
  if mount "$device" "$backupDisk"; then
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

## -------------------------- MAIN SCRIPT -------------------------- #
# Function to backup
backup() {
  BORG_OPTS="--verbose --filter AME --list --progress --stats --show-rc --compression lz4 --exclude-caches"

  # Filters for Inclusion Exclusion Borg
  BorgFilters="./patterns.lst"

  # Create a file with the delete standards Borg Inclusion
  tee -a "$BorgFilters" <<EOF
P sh
R /

# DO NOT LOOK IN THESE FOLDERS
! proc

# DIRECTORIES TO BE EXCLUDED FROM BACKUP  
- /dev
- /sys
- /tmp
- /run
- /mnt
- /media
- /lost+found

+ /home/*
+ /root/*

# DO NOT INCLUDE ANY MORE FILES
- **
EOF

    echo "========== Backing up $( date )... =========="
    echo ""

    # Backup
    borg create $BORG_OPTS --patterns-from $exclude ::'Full-{now:%Y%m%d-%H%M}'

    backup_exit=$?

    info "Pruning repository"

    # Use the subcoming `prune` to keep 7 days, 4 per week and 6 per month
    # files of this machine.The prefix '{hostname}-' is very important for
    # limits PLA's operation to files in this machine and does not apply to
    # Files of other machines too:

    borg prune --list --progress --show-rc --keep-daily 7 --keep-weekly 4 --keep-monthly 6

    prune_exit=$? 

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

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune finished successfully" 2>&1 | tee -a
elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune finished with warnings" 2>&1 | tee -a
else
    info "Backup, Prune finished with errors" 2>&1 | tee -a
fi