#!/bin/sh

setup ()
{
	# build and insmod ubbd
	cd $UBBD_DIR
	make
	sleep 1
	modprobe uio
	insmod kmods/ubbd.ko
	sleep 1

	# prepare ramdisk for testing.
	modprobe brd rd_nr=1 rd_size=$((21*1024*1024)) max_part=16

	parted /dev/ram0 mklabel gpt
	sgdisk  /dev/ram0 -n 1:1M:+1000M
	sgdisk  /dev/ram0 -n 2:1001M:+10G
	sgdisk  /dev/ram0 -n 3:11241M:+10G

	partprobe /dev/ram0

	# kill ubbdd and restart it background
	ps -ef|grep start_ubbdd.sh|gawk '{print "kill "$2}'|bash
	sleep 1
	sh -x $ubbd_test_dir/utils/start_ubbdd.sh 0 0 1 &
	sleep 2

	# map ubbd0 and ubbd1 for xfstests
	cd $UBBD_DIR
	./ubbdadm/ubbdadm --command map --type file --filepath /dev/ram0p2 --devsize $((10*1024*1024*1024))
	sleep 1
	./ubbdadm/ubbdadm --command map --type file --filepath /dev/ram0p3 --devsize $((10*1024*1024*1024))
	sleep 1
	./ubbdadm/ubbdadm --command map --type null --devsize $((10*1024*1024*1024))
	sleep 1
	./ubbdadm/ubbdadm --command map --type file --filepath /dev/ram0p2 --devsize $((10*1024*1024*1024)) --num-queues 1
	sleep 1
	mkfs.xfs -f /dev/ubbd0
}

cleanup ()
{
	umount /mnt
	umount /media

	. ./local_conf

	if [ -z "$UBBD_DIR" ]; then
		echo "UBBD_DIR must be set in local_conf: UBBD_DIR=/xxx/xxxx"
		exit 1
	fi

	cd $UBBD_DIR
	for i in /dev/ubbd*; do
		id=$(echo "${i}" | sed "s/\/dev\/ubbd//g")
		./ubbdadm/ubbdadm --command unmap --ubbdid $id --force 
	done
	sleep 3
	ps -ef|grep start_ubbdd.sh|gawk '{print "kill "$2}'|bash
	pkill ubbdd

	rmmod ubbd
	rmmod brd
}


replace_option()
{
	file=$1
	old=$2
	new=$3
	sed -i "s#${old}#${new}#" ${file}
}
