# rsync-server-backup

This script allows for the automatic dumping of mysql/mariadb databases inside docker containers as well as transferring them to a remote machine via rsync/ssh.

The database backup part of this application is based on the [database container backup scripts](https://github.com/ChristianLempa/scripts/tree/main/db-container-backup) by Christian Lempa.