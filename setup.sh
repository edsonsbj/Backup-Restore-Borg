#!/bin/bash

#############################################################################################
#################################### Pre defined variables ##################################
#############################################################################################

BackupDir='/mnt/nextcloud_backup'
BackupRestoreConf='BackupRestore.conf'
LogFile='/var/log/Rsync-$(date +%Y-%m-%d_%H-%M).txt'
SourceDir='/'
webserverServiceName='nginx'
NextcloudConfig='/var/www/nextcloud'
script_backup=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)/Scripts/Backup.sh
Plex_Conf='/var/lib/plexmediaserver/Library/Application Support/Plex Media Server' # Diretório de configuração do Plex
Emby_Conf='/var/lib/emby' # Diretório de configuração do Emby
Jellyfin_Conf='/var/lib/jellyfin' # Diretório de configuração do Jellyfin
Mediaserver_Conf=''
MediaserverService=''
MediaserverUser=''

#############################################################################################
#################################### TESTS ##################################################
#############################################################################################

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

# Check if the script is being executed by root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "========== This script needs to be executed as root or with sudo. ==========" 
   exit 1
fi

clear

#############################################################################################
#################################### FUNCTIONS ##############################################
#############################################################################################

# Function to disks Backup UUID
disk_backup() {
  lsblk -o NAME,SIZE,RO,FSTYPE,TYPE,MOUNTPOINT,UUID,PTUUID | grep 'sd'
 
  # List of available partitions
  partitions=($(lsblk -o NAME,TYPE | grep 'part' | awk '{print $1}'))
  num_partitions=${#partitions[@]}
 
  # Check if there is at least one partition
  if [ "$num_partitions" -eq 0 ]; then
    echo "No partitions found."
    exit 1
  fi
 
  # List available partitions with enumerated numbers
  echo "Available partitions:"
  for ((i = 0; i < num_partitions; i++)); do
    echo "$((i + 1)). ${partitions[i]}"
  done
 
  # Ask the user to choose a partition by number
  read -p "Enter the desired partition number (1-$num_partitions): " partition_number
 
  # Check if the partition number is valid
  if ! [[ "$partition_number" =~ ^[0-9]+$ ]]; then
    echo "Invalid partition number."
    exit 1
  fi
 
  # Check that the partition number is within the valid interval
  if [ "$partition_number" -lt 1 ] || [ "$partition_number" -gt "$num_partitions" ]; then
    echo "Partition number outside the valid interval."
    exit 1
  fi
 
  # Get the name of the selected partition
  selected_partition="${partitions[$((partition_number - 1))]}"
  #echo "$selected_partition"
  selected_partition_cleaned=$(echo "$selected_partition" | sed 's/[└─├]//g')
  #echo "$selected_partition_cleaned"
  # Use the 'blkid' command to get the UUID of the selected partition
  uuid="$(blkid -s UUID -o value /dev/"$selected_partition_cleaned")"
 
  # Check if the UUID was found
  if [ -n "$uuid" ]; then
    echo "$uuid"
  else
    echo "Partition not found or UUID not available."
  fi

  clear

  echo "Enter the backup drive mount point here."
  echo "Default: ${BackupDir}"
  echo ""
  read -p "Enter a directory or press ENTER if the backup directory is ${BackupDir}: " BACKUPDIR

  [ -z "$BACKUPDIR" ] ||  BackupDir=$BACKUPDIR

  clear
  }

# Function to backup
backup() {
  echo "Enter the folder you want to backup here."
  echo "Default: ${SourceDir}"
  echo ""
  read -p "Enter a directory or press ENTER if the backup directory is ${SourceDir}:" SOURCEDIR

  [ -z "$SOURCEDIR" ] || SourceDir=$SOURCEDIR

  clear

  mkdir -p $HOME/Scripts
  cd $HOME/Scripts

  tee -a ./"${BackupRestoreConf}" <<EOF
# Configuration for Backup-Restore scripts

# TODO: The uuid of the backup drive
uuid='$uuid'

# TODO: Directory to backup 
SourceDir='$SourceDir'

# TODO: The Backup Drive Mount Point
BackupDir='$BackupDir'

# Log File
LogFile="$LogFile"

EOF

  clear

  wget https://raw.githubusercontent.com/edsonsbj/Backup-Restore/main/Backup.sh
  wget https://raw.githubusercontent.com/edsonsbj/Backup-Restore/main/Restore.sh

  chmod 700 *.sh

  clear

}

# Function to backup Nextcloud settings
nextcloud() {
  echo "Enter the path to the Nextcloud file directory."
  echo "Usually: ${NextcloudConfig}"
  echo ""
  read -p "Enter a directory or press ENTER if the file directory is ${NextcloudConfig}: " NEXTCLOUDCONF

  [ -z "$NEXTCLOUDCONF" ] ||  NextcloudConfig=$NEXTCLOUDCONF
  clear

  echo "Enter the webserver service name."
  echo "Usually: nginx or apache2"
  echo ""
  read -p "Enter an new webserver service name or press ENTER if the webserver service name is ${webserverServiceName}: " WEBSERVERSERVICENAME

  [ -z "$WEBSERVERSERVICENAME" ] ||  webserverServiceName=$WEBSERVERSERVICENAME
  clear

  NextcloudDataDir=$(sudo -u www-data php $NextcloudConfig/occ config:system:get datadirectory)
  DatabaseSystem=$(sudo -u www-data php $NextcloudConfig/occ config:system:get dbtype)
  NextcloudDatabase=$(sudo -u www-data php $NextcloudConfig/occ config:system:get dbname)
  DBUser=$(sudo -u www-data php $NextcloudConfig/occ config:system:get dbuser)
  DBPassword=$(sudo -u www-data php $NextcloudConfig/occ config:system:get dbpassword)
    
  clear

  mkdir -p $HOME/Scripts
  cd $HOME/Scripts

  tee -a ./"${BackupRestoreConf}" <<EOF
# Configuration for Backup-Restore scripts

# TODO: The uuid of the backup drive
uuid='$uuid'

# TODO: The Backup Drive Mount Point
BackupDir='$BackupDir'

# TODO: The service name of the web server. Used to start/stop web server (e.g. 'systemctl start <webserverServiceName>')
webserverServiceName='$webserverServiceName'

# TODO: The directory of your Nextcloud installation (this is a directory under your web root)
NextcloudConfig='$NextcloudConfig'

# TODO: The directory of your Nextcloud data directory (outside the Nextcloud file directory)
# If your data directory is located in the Nextcloud files directory (somewhere in the web root),
# the data directory must not be a separate part of the backup
NextcloudDataDir='$NextcloudDataDir'

# TODO: The name of the database system (one of: mysql, mariadb, postgresql)
# 'mysql' and 'mariadb' are equivalent, so when using 'mariadb', you could also set this variable to 'mysql' and vice versa.
DatabaseSystem='$DatabaseSystem'

# TODO: Your Nextcloud database name
NextcloudDatabase='$NextcloudDatabase'

# TODO: Your Nextcloud database user
DBUser='$DBUser'

# TODO: The password of the Nextcloud database user
DBPassword='$DBPassword'

# Log File
LogFile="$LogFile"

EOF

  clear

  wget https://raw.githubusercontent.com/edsonsbj/Backup-Restore/main/scripts/Nextcloud/Backup.sh
  wget https://raw.githubusercontent.com/edsonsbj/Backup-Restore/main/scripts/Nextcloud/Restore.sh

  chmod 700 *.sh

  clear
}

# Função para configurar o cron
cron() {

# Ask user about backup time
echo "Please enter the backup time in 24h format (MM:HH)"
read time

clear

# Ask the user about the day of the week
echo "Do you want to run the backup on a specific day of the week? (y/n)"
read reply_day

if [ "$reply_day" == "s" ]; then
    echo "Please enter the day of the week (0-6 where 0 is Sunday and 6 is Saturday)"
    read day_week
else
    day_week="*"
fi

clear

# Add the task to cron
(crontab -l 2>/dev/null; echo "$time * * $day_week $script_backup") | crontab -
}

# Function to configure the media server
configure_mediaserver() {
  echo "Choose the media server for backup:"
  select media_server in "Emby" "Jellyfin" "Plex"; do
    case $media_server in
      "Emby")
        MediaserverService="emby"
        MediaserverUser="emby"

        echo "Enter the path to the Emby file directory."
        echo "Usually: ${Emby_Conf}"
        echo ""
        read -p "Enter a directory or press ENTER if the file directory is ${Emby_Conf}: " EMBY_CONF

        [ -z "$EMBY_CONF" ] ||  Emby_Conf=$EMBY_CONF
        clear

        MediaserverConf="$Emby_Conf"
        break
        ;;
      "Jellyfin")
        MediaserverService="jellyfin"
        MediaserverUser="jellyfin"

        echo "Enter the path to the Jellyfin file directory."
        echo "Usually: ${Jellyfin_Conf}"
        echo ""
        read -p "Enter a directory or press ENTER if the file directory is ${Jellyfin_Conf}: " JELLYFIN_CONF

        [ -z "$JELLYFIN_CONF" ] ||  Jellyfin_Conf=$JELLYFIN_CONF
        clear

        MediaserverConf="$Jellyfin_Conf"
        break
        ;;
      "Plex")
        MediaserverService="plexmediaserver"
        MediaserverUser="plex"

        echo "Enter the path to the Jellyfin file directory."
        echo "Usually: ${Plex_Conf}"
        echo ""
        read -p "Enter a directory or press ENTER if the file directory is ${Plex_Conf}: " PLEX_CONF

        [ -z "$PLEX_CONF" ] ||  Plex_Conf=$PLEX_CONF
        clear

        MediaserverConf="$Plex_Conf"
        break
        ;;
      *)
        echo "Invalid option, try again."
        ;;
    esac
  done

  clear 

  mkdir -p $HOME/Scripts
  cd $HOME/Scripts

  tee -a ./"${BackupRestoreConf}" <<EOF
# Configuration for Backup-Restore scripts

# TODO: The uuid of the backup drive
uuid='$uuid'

# TODO: The Backup Drive Mount Point
BackupDir='$BackupDir'

# TODO: The service name of the media server. Used to start/stop web server (e.g. 'systemctl start <mediaserverServiceName>')
MediaserverService='$MediaserverService'

# TODO: The service name of the media server. Used to restore permissions media server settings)
MediaserverUser='$MediaserverUser'

# TODO: The directory where the Media Server settings are stored (this directory is stored within /var/lib)
MediaserverConf='$MediaserverConf'

# Log File
LogFile="$LogFile"

EOF

  clear

  wget https://raw.githubusercontent.com/edsonsbj/Backup-Restore/main/scripts/Media%20Server/Backup.sh
  wget https://raw.githubusercontent.com/edsonsbj/Backup-Restore/main/scripts/Media%20Server/Restore.sh

  chmod 700 *.sh

  clear

}

# Function to configure the media server with NextCloud
configure_nextcloud_mediaserver() {
  echo "Enter the path to the Nextcloud file directory."
  echo "Usually: ${NextcloudConfig}"
  echo ""
  read -p "Enter a directory or press ENTER if the file directory is ${NextcloudConfig}: " NEXTCLOUDCONF

  [ -z "$NEXTCLOUDCONF" ] ||  NextcloudConfig=$NEXTCLOUDCONF
  clear

  echo "Enter the webserver service name."
  echo "Usually: nginx or apache2"
  echo ""
  read -p "Enter an new webserver service name or press ENTER if the webserver service name is ${webserverServiceName}: " WEBSERVERSERVICENAME

  [ -z "$WEBSERVERSERVICENAME" ] ||  webserverServiceName=$WEBSERVERSERVICENAME
  clear

  NextcloudDataDir=$(sudo -u www-data php $NextcloudConfig/occ config:system:get datadirectory)
  DatabaseSystem=$(sudo -u www-data php $NextcloudConfig/occ config:system:get dbtype)
  NextcloudDatabase=$(sudo -u www-data php $NextcloudConfig/occ config:system:get dbname)
  DBUser=$(sudo -u www-data php $NextcloudConfig/occ config:system:get dbuser)
  DBPassword=$(sudo -u www-data php $NextcloudConfig/occ config:system:get dbpassword)

  echo "Choose the Backup Media Server: "
  select media_server in "Emby" "Jellyfin" "Plex"; do
    case $media_server in
      "Emby")
        MediaserverService="emby"
        MediaserverUser="emby"

        echo "Enter the path to the Emby file directory."
        echo "Usually: ${Emby_Conf}"
        echo ""
        read -p "Enter a directory or press ENTER if the file directory is ${Emby_Conf}: " EMBY_CONF

        [ -z "$EMBY_CONF" ] ||  Emby_Conf=$EMBY_CONF
        clear

        MediaserverConf="$Emby_Conf"
        break
        ;;
      "Jellyfin")
        MediaserverService="jellyfin"
        MediaserverUser="jellyfin"

        echo "Enter the path to the Jellyfin file directory."
        echo "Usually: ${Jellyfin_Conf}"
        echo ""
        read -p "Enter a directory or press ENTER if the file directory is ${Jellyfin_Conf}: " JELLYFIN_CONF

        [ -z "$JELLYFIN_CONF" ] ||  Jellyfin_Conf=$JELLYFIN_CONF
        clear

        MediaserverConf="$Jellyfin_Conf"
        break
        ;;
      "Plex")
        MediaserverService="plexmediaserver"
        MediaserverUser="plwx"

        echo "Enter the path to the Jellyfin file directory."
        echo "Usually: ${Plex_Conf}"
        echo ""
        read -p "Enter a directory or press ENTER if the file directory is ${Plex_Conf}: " PLEX_CONF

        [ -z "$PLEX_CONF" ] ||  Plex_Conf=$PLEX_CONF
        clear

        MediaserverConf="$Plex_Conf"
        break
        ;;
      *)
        echo "Invalid option, try again."
        ;;
    esac
  done

  clear 

  mkdir -p $HOME/Scripts
  cd $HOME/Scripts

  tee -a ./"${BackupRestoreConf}" <<EOF
# Configuration for Backup-Restore scripts

# TODO: The uuid of the backup drive
uuid='$uuid'

# TODO: The Backup Drive Mount Point
BackupDir='$BackupDir'

# TODO: The service name of the web server. Used to start/stop web server (e.g. 'systemctl start <webserverServiceName>')
webserverServiceName='$webserverServiceName'

# TODO: The directory of your Nextcloud installation (this is a directory under your web root)
NextcloudConfig='$NextcloudConfig'

# TODO: The directory of your Nextcloud data directory (outside the Nextcloud file directory)
# If your data directory is located in the Nextcloud files directory (somewhere in the web root),
# the data directory must not be a separate part of the backup
NextcloudDataDir='$NextcloudDataDir'

# TODO: The name of the database system (one of: mysql, mariadb, postgresql)
# 'mysql' and 'mariadb' are equivalent, so when using 'mariadb', you could also set this variable to 'mysql' and vice versa.
DatabaseSystem='$DatabaseSystem'

# TODO: Your Nextcloud database name
NextcloudDatabase='$NextcloudDatabase'

# TODO: Your Nextcloud database user
DBUser='$DBUser'

# TODO: The password of the Nextcloud database user
DBPassword='$DBPassword'

# TODO: The service name of the media server. Used to start/stop web server (e.g. 'systemctl start <mediaserverServiceName>')
MediaserverService='$MediaserverService'

# TODO: The service name of the media server. Used to restore permissions media server settings)
MediaserverUser='$MediaserverUser'

# TODO: The directory where the Media Server settings are stored (this directory is stored within /var/lib)
MediaserverConf='$MediaserverConf'

# Log File
LogFile="$LogFile"

EOF

  clear

  wget https://raw.githubusercontent.com/edsonsbj/Backup-Restore/main/scripts/Nextcloud%20%2B%20Media%20server%20/Backup.sh
  wget https://raw.githubusercontent.com/edsonsbj/Backup-Restore/main/scripts/Nextcloud%20%2B%20Media%20server%20/Restore.sh
  
  chmod 700 *.sh

  clear

}

# Main menu
while true; do
  echo "Choose an option:"
  echo "1. Backup"
  echo "2. Backup Nextcloud"
  echo "3. Backup Media Server"
  echo "4. Backup Nextcloud + Media Server"
  echo "5. To go out"

  read choice

  case $choice in
    1)
      disk_backup
      backup
      cron
      ;;
    2)
      disk_backup
      nextcloud
      cron
      ;;
    3)
      disk_backup
      configure_mediaserver
      cron
      ;;      
    4)
      disk_backup
      configure_nextcloud_mediaserver
      cron
      ;;
    5)
      echo "Leaving the script."
      exit 0
      ;;
    *)
      echo "Invalid option, try again."
      ;;
  esac
done

echo ""
echo "Done!"
echo ""
echo ""
echo "IMPORTANT: Please check $BackupRestoreConf if all variables were set correctly BEFORE running the backup/restore scripts!"