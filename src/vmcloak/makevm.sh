#!/bin/bash
set -xe

if [[ -z "$5" ]]; then
	echo "Usage: $0 <name> <osversion> <iso> <serial> <ip-last-octet>"
	echo "Where osversion is one of: winxp win7x86 win7x64 win81x86 win81x64 win10x86 win10x64"
	exit
fi

ISODIR=/mnt/isos

NAME="$1"
VER="$2"
ISO=$ISODIR/"$3"
SERIAL="$4"
IP="$5"

ISO_MNT=`mktemp -d`

mount -o loop,ro $ISO $ISO_MNT
if [[ $? -ne 0 ]]; then
	echo "Unable to mount ISO!"
	exit
fi

vmcloak init --$VER --iso-mount $ISO_MNT --serial-key $SERIAL --ip 172.28.128.$IP --gateway 172.28.128.1 --resolution 1280x720 $NAME

umount $ISO_MNT
