#!/bin/bash

CONFIG="$(dirname "${BASH_SOURCE[0]}")/BackupRestore.conf"
. $CONFIG

# Create a log file to record command outputs
touch "$LogFile"
exec > >(tee -a "$LogFile")
exec 2>&1

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

## ---------------------------------- TESTS ------------------------------ #

# Check if the script is being executed by root or with sudo
if [[ $EUID -ne 0 ]]; then
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
BORG_OPTS="--verbose --filter AME --list --progress --stats --show-rc --compression lz4 --exclude-caches"

# Function to backup Nextcloud settings
nextcloud_settings() {
    echo "========== Backing up Nextcloud settings $( date )... =========="
    echo ""

    # Export the Settings and Database
   	sudo nextcloud.export -abc

    # Backup
    borg create $BORG_OPTS ::'NextcloudConfigs-{now:%Y%m%d-%H%M}' $NextcloudSnapConfig

    backup_exit=$?

    # Remove the database 
    rm -rf $NextcloudSnapConfig 
}

# Function to backup Nextcloud DATA folder
nextcloud_data() {
    echo "========== Backing up Nextcloud DATA folder $( date )...=========="
    echo ""

    sudo nextcloud.occ maintenance:mode --on

    borg create $BORG_OPTS ::'NextcloudData-{now:%Y%m%d-%H%M}' $NextcloudDataDir --exclude "$NextcloudDataDir/*/files_trashbin"

    backup_exit=$?

    sudo nextcloud.occ maintenance:mode --off
}

# Function to perform a complete Nextcloud backup
nextcloud_complete() {
    echo "========== Backing up Nextcloud $( date )... =========="
    echo ""

    # Export the Settings and Database
   	sudo nextcloud.export -abc

    # Enable maintenance mode
    sudo nextcloud.occ maintenance:mode --on

    borg create $BORG_OPTS ::'NextcloudData-{now:%Y%m%d-%H%M}' $NextcloudSnapConfig $NextcloudDataDir --exclude "$NextcloudDataDir/*/files_trashbin"

    backup_exit=$?

    # Disable the maintenance mode
    sudo nextcloud.occ maintenance:mode --off

    # Remove the database 
    rm -rf $NextcloudSnapConfig 
}

# Check if an option was passed as an argument
if [[ ! -z $1 ]]; then
    # Execute the corresponding Backup option
    case $1 in
        1)
            nextcloud_settings
            ;;
        2)
            nextcloud_data
            ;;
        3)
            nextcloud_complete
            ;;
        *)
            echo "Invalid option!"
            ;;
    esac
else
    # Display the menu to choose the Backup option
    echo "Choose a Backup option:"
    echo "1. Backup Nextcloud configurations and database."
    echo "2. Backup only the Nextcloud data folder. Useful if the folder is stored elsewhere."
    echo "3. Backup Nextcloud configurations, database, and data folder."
    echo "4. To go out."

    # Read the option entered by the user
    read option

    # Execute the corresponding Backup option
    case $option in
        1)
            nextcloud_settings
            ;;
        2)
            nextcloud_data
            ;;
        3)
            nextcloud_complete
            ;;
        4)
            echo "Leaving the script."
            exit 0
            ;;            
        *)
            echo "Invalid option!"
            ;;
    esac
fi

    info "Pruning repository"

    # Use the subcoming `prune` to keep 7 days, 4 per week and 6 per month
    # files of this machine.The prefix '{hostname}-' is very important for
    # limits PLA's operation to files in this machine and does not apply to
    # Files of other machines too:

    borg prune --list --progress --show-rc --keep-daily 7 --keep-weekly 4 --keep-monthly 6

    prune_exit=$? 

# Worked well? Unmount.
if [ "$?" = "0" ]; then
    echo ""
    echo "========== Backup completed. The removable drive has been unmounted and powered off. =========="
    umount "/dev/disk/by-uuid/$uuid"
    sudo udisksctl power-off -b "/dev/disk/by-uuid/$uuid"
fi

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune finished successfully" 2>&1 | tee -a
elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune finished with warnings" 2>&1 | tee -a
else
    info "Backup, Prune finished with errors" 2>&1 | tee -a
fi