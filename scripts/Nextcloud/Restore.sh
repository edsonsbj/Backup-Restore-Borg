#!/bin/bash

CONFIG="$(dirname "${BASH_SOURCE[0]}")/BackupRestore.conf"
. $CONFIG

ARCHIVE_DATE=$2

# Create a log file to record command outputs
touch "$LogFile"
exec > >(tee -a "$LogFile")
exec 2>&1

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; } 

## ---------------------------------- TESTS ------------------------------ #
# Check if the script is being executed by root or with sudo
if [[ $EUID -ne 0 ]]; then
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
check_restore() {
    # Check if the restoration date is specified
    if [ -z "$ARCHIVE_DATE" ]
    then
        echo "Enter the restoration date (YYYY-MM-DD):"
        read ARCHIVE_DATE
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

# Function to Nextcloud Maintenance Mode
nextcloud_enable() {
    # Enabling Maintenance Mode
    echo "============ Enabling Maintenance Mode... ============"
	sudo -u www-data php $NextcloudConfig/occ maintenance:mode --on
    echo ""
}

nextcloud_disable() {
    # Disabling Nextcloud Maintenance Mode
    echo "============ Disabling Maintenance Mode... ============"
	sudo -u www-data php $NextcloudConfig/occ maintenance:mode --off
    echo ""
}

# Function to WebServer Stop Start
stop_webserver() {
    # Stop Web Server
	systemctl stop $webserverServiceName
}

start_webserver() {
    # Stop Web Server
	systemctl start $webserverServiceName
}

# Function to restore Nextcloud settings
nextcloud_settings() {

    check_restore

    nextcloud_enable

    stop_webserver

    # Removing old versions 
    mv $NextcloudConfig "$NextcloudConfig.old/"
    
    echo "========== Restoring Nextcloud settings $( date )... =========="
    echo ""

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudConfig

    # Restore the database
    mysql --host=localhost --user=$DBUser --password=$DBPassword -e "DROP DATABASE $NextcloudDatabase"
    mysql --host=localhost --user=$DBUser --password=$DBPassword -e "CREATE DATABASE $NextcloudDatabase CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"    
    mysql --host=localhost --user=$DBUser --password=$DBPassword $NextcloudDatabase < "$NextcloudConfig/nextclouddb.sql"

    # Restore permissions
    chmod -R 755 $NextcloudConfig
    chown -R www-data:www-data $NextcloudConfig

    nextcloud_disable

    start_webserver    

    # Removing unnecessary files
    rm "$NextcloudConfig/nextclouddb.sql"
    rm -rf "$NextcloudConfig.old/"
}

# Function to restore Nextcloud DATA folder
nextcloud_data() {

    check_restore

    nextcloud_enable

    echo "========== Restoring Nextcloud DATA folder $( date )...=========="
    echo ""

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudDataDir

    # Restore permissions
    chmod -R 770 $NextcloudDataDir 
    chown -R www-data:www-data $NextcloudDataDir

    nextcloud_disable
}

# Function to restore Nextcloud
nextcloud_complete() {

    check_restore

    nextcloud_enable

    stop_webserver

    # Removing old versions 
    mv $NextcloudConfig '$NextcloudConfig.old/'

    echo "========== Restoring Nextcloud $( date )... =========="
    echo ""

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudConfig $NextcloudDataDir

    # Restore the database
    mysql --host=localhost --user=$DBUser --password=$DBPassword -e "DROP DATABASE $NextcloudDatabase"
    mysql --host=localhost --user=$DBUser --password=$DBPassword -e "CREATE DATABASE $NextcloudDatabase CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"    
    mysql --host=localhost --user=$DBUser --password=$DBPassword $NextcloudDatabase < "$NextcloudConfig/nextclouddb.sql"

    # Restore permissions
    chmod -R 755 $NextcloudConfig
    chown -R www-data:www-data $NextcloudConfig
    chmod -R 770 $NextcloudDataDir 
    chown -R www-data:www-data $NextcloudDataDir

    nextcloud_disable

    start_webserver

    # Removing unnecessary files
    rm "$NextcloudConfig/nextclouddb.sql"
    rm -rf "$NextcloudConfig.old/"
}

# Check if an option was passed as an argument
if [[ ! -z $1 ]]; then
    # Execute the corresponding Restore option
    case $1 in
        1)
            nextcloud_settings $2
            ;;
        2)
            nextcloud_data $2
            ;;
        3)
            nextcloud_complete $2
            ;;
        *)
            echo "Invalid option!"
            ;;
    esac
else
    # Display the menu to choose the Restore option
    echo "Choose a Restore option:"
    echo "1. Restore Nextcloud configurations and database."
    echo "2. Restore only the Nextcloud data folder. Useful if the folder is stored elsewhere."
    echo "3. Restore Nextcloud configurations, database, and data folder."
    echo "4. To go out."

    # Read the option entered by the user
    read option

    # Execute the corresponding Restore option
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

# Worked well? Unmount.
if [ "$?" = "0" ]; then
    echo ""
    echo "========== Restore     completed. The removable drive has been unmounted and powered off. =========="
    umount "/dev/disk/by-uuid/$uuid"
    sudo udisksctl power-off -b "/dev/disk/by-uuid/$uuid"
fi
