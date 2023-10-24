# Backup-Restore

Bash scripts for backup/restore of [Nextcloud](https://nextcloud.com/) and media servers as [Emby](https://emby.media/) [Jellyfin](https://jellyfin.org/) and [Plex](https://www.plex.tv/) that are installed in the same location.

## General information

For a full backup of any Nextcloud instance along with a multimedia server like Plex, you will have to back up these items:
- The Nextcloud **file directory** (usually */var/www/nextcloud*)
- The **data directory** of Nextcloud (it's recommended that this is *not* located in the web root, so e.g. */var/nextcloud_data*)
- The Nextcloud **database**
- The Media server  **file directory** (usually */var/lib or /var/snap*)

With these scripts, all these elements can be included in a backup.

## Important notes about using the scripts

- After cloning or downloading the scripts, these need to be set up by running the script `setup.sh` (see below).
- If you do not want to use the automated setup, you can also use the file `BackupRestore.conf.sample` as a starting point. Just make sure to rename the file when you are done (`cp BackupRestore.conf.sample BackupRestore.conf`)
- The configuration file `BackupRestore.conf` has to be located in the same directory as the scripts for backup/restore.
- If using for Backup or Restoration of `Nextcloud`, `Plex` or `Emby` servers, the scripts in this repository assume that the programs were installed via `apt-get` or `dpkg` (Media Server) and full installation (`Nextcloud`) with `nginx`, `php` and `redis`.

## Setup Automated

1. Run the following command at a terminal with administrator privileges 
```
wget https://raw.githubusercontent.com/edsonsbj/Backup-Restore/main/setup.sh && sudo chmod 700 *.sh && ./sudo setup.sh
```
2. After running the `setup.sh` interactive script, the `Backup.sh` and `Restore.sh` scripts will be generated based on your selection, along with the `BackupRestore.conf` for using the script, in addition to configuring cron.
3. **Important**: check that all files were created and must be in /root/Scripts. 
4. **Important**: Check this configuration file if everything was set up correctly (see *TODO* in the configuration file comments)
5. Start using the scripts: See sections *Backup* and *Restore* below

Keep in mind that the configuration file `BackupRestore.conf` hast to be located in the same directory as the scripts for backup/restore, otherwise the configuration will not be found.

## Setup Manual 

1. install Git if it is not installed.
2. Clone this Repository or download and unzip the zip file. git clone.
```
git clone https://github.com/edsonsbj/Backup-Restore.git
```
3. Choose the script you want to use for backup and restore and delete the others. Remember that the scripts in the root folder are intended to backup all the files on your system, useful if you are not interested in backing up and restoring Nextcloud, Emby, Jellyfin and Plex servers.
4. Copy the file BackupRestore.conf.sample to BackupRestore.conf, which must be in the same folder as the scripts
5. Make Scripts Executable.
```
chmod 700 *.sh
``` 

## Performing Backup or Restoration

### Backup ### 

If you choose option 1 >> Backup in the setup.sh automated script, or you have cloned the entire repository to use and want to use the scripts contained in the repository root, run the script like this:

```
sudo ./Backup.sh
```

### Media server ###

If you selected option 3 >> Backup in the automated setup.sh script, or downloaded the Media Server folder, run the script as follows:

```
sudo ./Backup.sh
```

Nextcloud & Nextcloud + Media Server

If you chose between options 2 or 4 >> Nextcloud and Nextcloud + Media Server in the automated setup.sh script, or downloaded one of the Nextcloud or Nextcloud + Media Server folders, invoke the script like this: 

### Nextcloud ###

```
sudo ./Backup.sh 1
```
Backup Nextcloud configurations, database, and data folder.

```
sudo ./Backup.sh 2
```
Backup Nextcloud configurations and database.

```
sudo ./Backup.sh 3
```
Backup Nextcloud configurations and database.

### Nextcloud + Media Server ###

Here the commands described above remain the same 

```
sudo ./Backup.sh 4
```
Backup Nextcloud and Media Server Settings

```
sudo ./Backup.sh 5
```
Backup Nextcloud settings, database and data folder, as well as Media Server settings.
