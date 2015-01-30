#!/bin/sh

device=/dev/sr0

help()
{
cat <<EOF >&2
Usage: $0 [options] image.iso

options: -d|--dao: use DAO mode
         -s|--speed n: set burning speed
         -n|--no-spares: don't create BD-R/BD-RE spare block area
         -r|--device: set device to use (default: /dev/sr0)
EOF
}

OPTS=`getopt -o ds:nhr: --long dao,speed,no-spares,help,device -- "$@"`
eval set -- "$OPTS"
while true; do
  case "$1" in
    -d|--dao) burnopts="$burnopts -use-the-force-luke=dao"; shift;;
    -s|--speed) burnopts="$burnopts -speed=$2"; shift 2;;
    -n|--no-spares) burnopts="$burnopts -use-the-force-luke=spares:none"; shift;;
    -r|--device) device=$2; shift 2;;
    -h|--help) help; exit 1;;
    --) shift; break;;
    *) echo "Internal error" >&2; exit 1;;
  esac
done

if [ "$1" == "" ]
then
  help
  exit 1;
fi

growisofs $burnopts -Z $device="$1" 
eject $device
sleep 4
eject -t $device
#sleep 20

err=-1
while [ $err != 0 ]
do
  mount $device 2>&1 >/dev/null
  err=$?
  sleep 2
done
umount $device 2>&1 >/dev/null

sleep 3

dvdisaster -r -d $device -i "${1%.iso}_r.iso"
dvdisaster -t -i "${1%.iso}_r.iso"
rm "${1%.iso}_r.iso"
