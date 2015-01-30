#!/bin/bash
source settings.sh

mysqldump -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD -dR $MYSQL_DB >backup_index-schema.sql
echo "insert into backup_index (discnum) values (0);" >>backup_index-schema.sql
