#!/bin/bash
#awk 'BEGIN {FS="\t"} $4 != "" {y+=$2; next} {n+=$2} END {printf("%d%% complete, %d GB remaining\n",100.0*y/(n+y), n/10740563968);}' backup-index
source settings.sh
total=`echo "select sum(filesize) from backup_index;" | mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB | tail -n 1`
backed_up=`echo "select sum(filesize) from backup_index where discnum is not null;" | mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB | tail -n 1`
echo `echo "scale=1; 100*$backed_up/$total" | bc`"% complete, "`echo "scale=1; ($total-$backed_up)/1073741824" | bc `" GB remaining"
echo "(about "`echo "($total-$backed_up)/20020250624+1" | bc`" single-layer BD-R(s) with dvdisaster ECC)"