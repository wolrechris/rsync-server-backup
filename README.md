# rsync-server-backup

This script allows for the automatic dumping of mysql/mariadb databases inside docker containers as well as transferring them to a remote machine via rsync/ssh.

The database backup part of this application is based on the [database container backup scripts](https://github.com/ChristianLempa/scripts/tree/main/db-container-backup) by Christian Lempa.
=======
# Dockerbackup script

This script allows for automatic dumping of mysql/mariadb databases inside docker containers as well as transfering them to a remote machine via rsync/ssh. The script is primarily made for usage on a specific VPS and not developed for general usage. Usage on other servers is also possible (might need to change parts of the config / script below) but not officially supported. The database backup part of this application is based on the [database container backup scripts](https://github.com/ChristianLempa/scripts/tree/main/db-container-backup) by Christian Lempa.

## Configuration

The following configuration options are available within the script (edit `run_sync.sh`):

    # Amount of days that database backups should be kept in the dump directory before being deleted
    DAYS=2
    # Hostname or IP address of the backup destination machine
    REMOTE_HOST=remote-host.example.com
    # Remote machine user
    REMOTE_USER=user
    # If applicable: Remote machine password. Leave empty if you are using SSH keys and are not prompted for a password at the login. (currently unsupported)
    REMOTE_PASS=
    # Set the directory to which the dumped database files will be synced here
    REMOTE_DB_DIR=/remote/dir/here
    # Local directory to which database files are dumped
    DBDUMPDIR=/local/dir/here
    # Token for Gotify (if you do not want to use Gotify, uncomment the second-to-last line of this script.
    GOTIFY_TOKEN=

## Usage

To execute the script and generate logs (logs are only required if you want to use Gotify), simply use the following format:

    /home/user/dockerbackup/run_sync.sh | tee -a /home/user/dockerbackup/backup.log | tee /home/user/dockerbackup/latest.log

Similarly, the script can also be used to run rsync automatically via cronjobs:

    0 3 * * * /root/dockerbackup/run_sync.sh | tee -a /root/dockerbackup/backup.log | tee /root/dockerbackup/latest.log
