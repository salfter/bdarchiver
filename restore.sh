#!/bin/bash
start=$1
if [ "$start" == "" ]
then
  start=0;
fi
discs=`echo select distinct discnum from backup_index where filename like \'video/%\' and discnum is not null order by discnum\; | mysql -h mythserver -u salfter --password=taifacs backup_index | grep -v discnum`
for i in $discs
do
  if [ $i -ge $start ]
  then
    eject /dev/sr0
    echo Insert disc $i
    for j in `seq 1 10`
    do
    	beep -f 800 -l 100
    	beep -f 750 -l 100
    done
    read
    eject -t /dev/sr0
    sleep 40
    sudo mount /mnt/cdrom 2>/dev/null
    while [ $? != 0 ]
    do
      sleep 2
      sudo mount /mnt/cdrom 2>/dev/null
    done  
    echo select filename from backup_index where discnum=$i and filename like \'video/%\'\; | mysql -h mythserver -u salfter --password=taifacs backup_index | grep -v discnum | grep -v filename | sed "s/\(.*\)/if [ \! -e \"\/mnt\/files\/\1\" ]; then cp -v \"\/mnt\/cdrom\/\1\" \"\/mnt\/files\/\1\"; fi/" | bash
  fi
done


