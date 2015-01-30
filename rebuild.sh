#!/bin/bash

source settings.sh

mount /mnt/cdrom && cp /mnt/cdrom/contents . && umount /mnt/cdrom && chmod u+w contents && \
discnum=`tail -n 1 contents` && \
awk 'BEGIN {FS="\t"} {print $2}' contents | grep -v ^\$ >filelist.$discnum && \
sed "s/'/''/g;s/^/select filename,discnum from backup_index where filename='/;s/\$/';/" filelist.$discnum | mysql --default-character-set=utf8 -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB | grep NULL | sed "s/\tNULL\$//" >missing.$discnum && \
mount /mnt/cdrom && \
sed "s/\(.*\)/echo Summing \\\"\1\\\"...; md5sum \/mnt\/cdrom\/\\\"\1\\\" >>sums.$discnum/" missing.$discnum | bash && \
umount /mnt/cdrom && \
if [ -e sums.$discnum ]
then
  sed "s/'/''/g;s/\([0-9a-f]*\)  \/mnt\/cdrom\/\(.*\)/update backup_index set md5='\1', discnum=$discnum where filename='\2';/" sums.$discnum | mysql --default-character-set=utf8 -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB
  rm sums.$discnum
fi
rm contents filelist.$discnum missing.$discnum

