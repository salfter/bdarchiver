#!/bin/bash
err=-1
while [ $err != 0 ]
do
  mount /mnt/cdrom 2>&1 >/dev/null
  err=$?
  sleep 2
done
umount /mnt/cdrom 2>&1 >/dev/null
