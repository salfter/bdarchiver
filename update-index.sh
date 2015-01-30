#!/bin/bash

source settings.sh

echo -n | mysql --default-character-set=utf8 -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB >/dev/null
if [ $? -ne 0 ]
then
  echo "unable to connect to database"
  exit 1
fi

echo "select name from excluded_dirs;" | mysql --default-character-set=utf8 -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB | grep -v ^name\$ | sed "s/\//\\\\\//g;s/^/s\/^/;s/\$/\\\\\/.\*\/\//" >exclude.sed
TZ=UTC find $PATHS -type f -exec ls --full-time \{} \; | sed "s/.*$USER users //;s/\.0*//;s/ +0000//;s/ /\t/;s/ \\//\t\//;s/\(.*\)\t\(.*\)\t\(.*\)/\3\t\1\t\2/;s/$SEDROOTDIR\\///" | sed -f exclude.sed | grep -v ^\$ | sort | awk 'BEGIN {FS="\t"} {printf("%s\t%s\t%s\n",$1,$2,substr($3,1,19));}' >current-files
echo "select filename, filesize, filedate from backup_index;" | mysql --default-character-set=utf8 -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB | grep -Pv "filename\tfilesize\tfiledate" | sort >backup-index.tmp
sed 's/[ \t]*$//' backup-index.tmp >backup-index.tmp~ && mv backup-index.tmp~ backup-index.tmp
sed 's/[ \t]*$//' current-files >current-files~ && mv current-files~ current-files
diff -u backup-index.tmp current-files >changes
grep ^- changes | grep -v ^--- >removals
grep ^+ changes | grep -v ^+++ >additions
rm changes
sed "s/-\(.*\)\t\(.*\)\t\(.*\)/\1/;s/'/''/g;s/^/delete from backup_index where filename='/;s/\$/';/" removals >changes.sql
sed "s/^+//;s/'/''/g;s/\(.*\)\t\(.*\)\t\(.*\)/insert into backup_index (filename, filesize, filedate) values ('\1\', \2, '\3');/" additions >>changes.sql
mysql --default-character-set=utf8 -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB <changes.sql
rm backup-index.tmp changes.sql
echo `wc additions | awk '{print $1;}'` added, `wc removals | awk '{print $1;}'` removed
rm current-files additions removals exclude.sed
