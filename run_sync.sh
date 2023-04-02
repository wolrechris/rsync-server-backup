#!/bin/bash
# RSYNC SERVER BACKUP
# This script allows for automatic dumping of mysql/mariadb databases inside docker containers as well as transfering them to
# a remote machine via rsync/ssh. The script is primarily made for usage on a specific VPS and not developed for general
# usage. Usage on other servers is also possible (might need to change parts of the config / script below) but not officially
# supported.

# Config:
# Amount of days that database backups should be kept in the dump directory before being deleted
DAYS=2
# Hostname or IP address of the backup destination machine
REMOTE_HOST=remotehost.example.com
# Remote machine user
REMOTE_USER=username
# If applicable: Remote machine password. Leave empty if you are using SSH keys and are not prompted for a password at the login.
REMOTE_PASS=
# Set the directory to which the dumped database files will be synced here (give full path without short formats)
REMOTE_DB_DIR=/backup_directory_here/backup/db/
# Local directory to which database files are dumped
DBDUMPDIR=./db_backup



# Backup all mysql/mariadb containers
echo "Starting database dump..."
CONTAINER=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'mysql\|mariadb' | cut -d":" -f1)

echo "Containers found: $CONTAINER" 

if [ ! -d $DBDUMPDIR ]; then
    mkdir -p $DBDUMPDIR
fi

for i in $CONTAINER; do
    MYSQL_DATABASE=$(docker exec $i env | grep MYSQL_DATABASE |cut -d"=" -f2)
    MYSQL_PWD=$(docker exec $i env | grep MYSQL_ROOT_PASSWORD |cut -d"=" -f2)

    docker exec -e MYSQL_DATABASE=$MYSQL_DATABASE -e MYSQL_PWD=$MYSQL_PWD \
        $i /usr/bin/mysqldump -u root $MYSQL_DATABASE \
        | gzip > $DBDUMPDIR/$i-$MYSQL_DATABASE-$(date +"%Y%m%d%H%M").sql.gz

    OLD_BACKUPS=$(ls -1 $DBDUMPDIR/$i*.gz |wc -l)
    if [ $OLD_BACKUPS -gt $DAYS ]; then
        find $DBDUMPDIR -name "$i*.gz" -daystart -mtime +$DAYS -delete
    fi
done

echo "Starting rsync of dumped databases..."
rsync -av -r $DBDUMPDIR/* $REMOTE_USER@$REMOTE_HOST:$REMOTE_DB_DIR

# Sync files to remote server

SYNCPATHS="./paths.txt"
while IFS= read -r line
do
  echo "Running rsync for path-pair $line"
  SRC=$(echo $line | cut -d ">" -f 1)
  DST=$(echo $line | cut -d ">" -f 2)
  rsync -av -r $SRC/* $REMOTE_USER@$REMOTE_HOST:$DST
  echo "SRC=$SRC"
  echo "DST=$DST"
 
done < "$SYNCPATHS"


echo "End of script reached, exiting..."
exit
