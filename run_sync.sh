#!/bin/bash

# DB Container Backup Script Template
# ---
# This backup script can be used to automatically backup databases in docker containers.
# It currently supports mariadb, mysql and bitwardenrs containers.
# 

DAYS=2
REMOTE_HOST=testhost
REMOTE_USER=user
REMOTE_PASS=password
DBDUMPDIR=./db_backup


# backup all mysql/mariadb containers

CONTAINER=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'mysql\|mariadb' | cut -d":" -f1)

echo $CONTAINER

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

# Sync files to remote server
SYNCPATHS="./paths.txt"
while IFS= read -r line
do
  echo "Running rsync for path-pair $line"
  SRC=cut -d ">" -f 1 $line
  DST= cut -d ">" -f 2 $line
  rsync -a -r $SRC/* $REMOTE_USER@$REMOTE_HOST:$DST

done < "$SYNCPATHS"
