#!/bin/bash

source settings.sh

echo -n | mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB >/dev/null
if [ $? -ne 0 ]
then
  echo "unable to connect to database" >&2
  exit 1
fi

help()
{
cat <<EOF >&2
options: -b|--bdr: prepare for BD-R media
         -d|--dvdr: prepare for DVD-R media
         -c|--cdr: prepare for CD-R media
         -l|--dual-layer: prepare for dual-layer media (DVD-R/BD-R only)
         -r|--reserve: reserve space for dvdisaster (default: 20%)
	 -e|--reserve-percent: change reserved percentage for dvdisaster
         -p|--progress filename: write progress messages (default: /dev/null)
         -h|--help: this message
EOF
}

progress=/dev/null

OPTS=`getopt -o bcdlrhp:e: --long bdr,cdr,dvdr,dual-layer,reserve,help,progress,reserve-percent -- "$@"`
eval set -- "$OPTS"
while true; do
  case "$1" in
    -b|--bdr) media=bdr; shift;;
    -c|--cdr) media=cdr ; shift;;
    -d|--dvdr) media=dvdr; shift;;
    -l|--dual-layer) dual=1; shift;;
    -r|--reserve) reserve=1; shift;;
    -e|--reserve-percent) rsvpct="$2"; shift 2;;
    -h|--help) help; exit 1;;
    -p|--progress) progress="$2"; shift 2;;
    --) shift; break;;
    *) echo "Internal error" >&2; exit 1;;
  esac
done

if [ "$media" == "" ]
then
  help; exit 1
fi

case "$media" in
  "bdr")  if [ "$dual" == "1" ]; then cap=24438784; else cap=12219392; fi;;
  "dvdr") if [ "$dual" == "1" ]; then cap=4171712; else cap=2295104; fi;;
  "cdr")  cap=360000;;
esac

if [ "$rsvpct" == "" ]
then
  rsvpct=20
fi

if [ "$reserve" == "1" ]
then
  #cap=`echo $cap/5\*4 | bc`
  cap=`echo $cap $rsvpct | awk '{printf("%.0f\n", (1-$2/100)*$1)}'`
fi

# 29 Aug 14: estimate space needed for database backup, and deduct it

b1=`mysqldump -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD -R $MYSQL_DB | xz -z9  | wc -c`
b2=`tar cJf - *.sh | wc -c`
total=`echo \( $b1 / 2048 + 1 \) + \( $b2 / 2048 + 1 \) | bc`
cap=`echo $cap - $total | bc`

#echo === Selecting files to copy === && \
cat <<EOF | mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB | grep -Pv "^filesize\tfilename\tfiledate$" >contents
update backup_index set discnum=null where discnum=-1;
call pick_files($cap);
select filesize, filename, filedate from backup_index where discnum=-1;
EOF

discnum=`echo "select max(discnum)+1 from backup_index;" | mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB | tail -n 1`
echo $discnum >>contents

cat <<EOF | mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB | grep -v "^filename$" >filelist
select filename from backup_index where discnum=-1;
EOF
#echo "select filename from backup_index where discnum=-1;" | mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB | grep -v "^filename$" >filelist
(cat filelist; echo $discnum) >preplist


#echo === Linking files === && \
if [ -e tmp ]
then
  rm -r tmp
fi
mkdir tmp && \
ln -s "`readlink -f contents`" tmp/ && \
#sed "s/\(.*\)/d=\`dirname \"\1\"\`\nmkdir -p tmp\/\"\$d\"\nln -s $SEDROOTDIR\/\"\1\" tmp\/\"\1\"/" filelist | bash &&
sed "s/\`/\\\\\`/g;s/\(.*\)/d=\$\(dirname \"\1\"\)\nmkdir -p tmp\/\"\$d\"\nln -s $SEDROOTDIR\/\"\1\" tmp\/\"\1\"/" filelist | bash &&

# 29 Aug 14: include database and scripts in disc image

cat <<EOF | mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB
update backup_index set discnum=$discnum where discnum=-1;
EOF

mysqldump -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD -R $MYSQL_DB | xz -z9 >tmp/backup_index.sql.xz
tar cJf tmp/backup_index_scripts.tar.xz *.sh

cat <<EOF | mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB
update backup_index set discnum=-1 where discnum=$discnum;
EOF

#echo === Building backup_$discnum.iso ===
#mkisofs -iso-level 3 -f -JR -udf -V backup_$discnum -o backup_$discnum.iso tmp &>>"$progress" 
mkisofs -allow-limited-size -iso-level 3 -f -r -udf -V backup_$discnum -o backup_$discnum.iso tmp &>>"$progress" 
if [ $? -ne 0 ]
then
  echo "error in mkisofs"
  exit $?
fi
rm preplist filelist contents && \
rm -r tmp && mkdir tmp && \

#echo === Gathering MD5 sums === && \
sudo mount -o loop,ro backup_$discnum.iso tmp && \
(cd tmp; find . -type f | sed "s/^\.\///" | grep -v ^contents\$ | sed "s/^/\"/;s/\$/\"/" | xargs md5sum) >backup_$discnum.sums && \
sudo umount tmp && \
rmdir tmp && \

#echo === Updating index ===
sed "s/'/''/g;s/\([0-9a-f]*\)  \(.*\)/update backup_index set discnum=$discnum, md5='\1' where filename='\2';/" backup_$discnum.sums | mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWD $MYSQL_DB

if [ "$reserve" == "1" ]
then
#  echo === Augmenting image with recovery data ===
  dvdisaster -mRS02 -ci backup_$discnum.iso &>>"$progress"
fi

#echo === Done preparing backup_$discnum.iso. ===
echo "backup_$discnum.iso"
rm backup_$discnum.sums
