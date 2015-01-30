#!/bin/bash
export MYSQL_HOST="MYSQL_SERVER_HOSTNAME"
export MYSQL_USER="MYSQL_USERNAME"
export MYSQL_PASSWD="MYSQL_PASSWORD"
export MYSQL_DB="backup_index"
eval `echo "select name, value from settings;" | mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB | grep -Pv "name\tvalue" | sed "s/\t/=\"/;s/\$/\"/"`
PATHS=""
for i in $DIRS
do
  PATHS="$PATHS $ROOTDIR/$i"
done
SEDROOTDIR="`echo $ROOTDIR | sed "s/\//\\\\\\\\\//g"`"
