#!/bin/sh

wait_for_ubbdd ()
{
	while true ; do
		./ubbdadm/ubbdadm --command list
		if [ $? -eq 0 ]; then
			return
		fi
		sleep 1
	done
}

setup ()
{
	# build and insmod ubbd
	cd $UBBD_KERNEL_DIR
	make mod
	make install
	sleep 1
	cd $UBBD_DIR
	make
	make install
	sleep 1

	# prepare ramdisk for testing.
	modprobe brd rd_nr=1 rd_size=$((21*1024*1024)) max_part=16

	parted /dev/ram0 mklabel gpt
	sgdisk  /dev/ram0 -n 1:1M:+1000M
	sgdisk  /dev/ram0 -n 2:1001M:+10G
	sgdisk  /dev/ram0 -n 3:11241M:+10G

	partprobe /dev/ram0
}

kill_ubbdd ()
{
	ps -ef |grep ubbdd_killer|gawk '{print "kill "$2}'|bash
	ps -ef|grep start_ubbdd.sh|gawk '{print "kill "$2}'|bash
	ps -ef|grep memleak|grep ubbdd|gawk '{print "kill "$2}'|bash
	pkill -9 ubbd-backend
	pkill -9 ubbdd
}

prepare_ubbdd ()
{
	memleak=$1

	cd $UBBD_DIR
	# kill ubbdd and restart it background
	kill_ubbdd
	modprobe ubbd

	sh -x $UBBD_TESTS_DIR/utils/start_ubbdd.sh $memleak 1 &
	wait_for_ubbdd
}

map_dev ()
{
	type=$1
	devsize=$2
	opts=$3

	while true; do
		${UBBD_DIR}/ubbdadm/ubbdadm --command map --type $type --devsize $devsize $opts
		if [ $? -eq 0 ]; then
			break
		fi
		sleep 1
	done
}

unmap_dev ()
{
	ubbdid=$1

	while true; do
		${UBBD_DIR}/ubbdadm/ubbdadm --command unmap --force --ubbdid $ubbdid
		if [ $? -eq 0 ]; then
			break
		fi
		sleep 1
	done
}

prepare_ubbd_devs ()
{
	prepare_ubbdd 0

	# map ubbd0 and ubbd1 for xfstests
	cd $UBBD_DIR
	map_dev file $((10*1024*1024*1024)) "--file-filepath /dev/ram0p2"
	map_dev file $((10*1024*1024*1024)) "--file-filepath /dev/ram0p3"
	map_dev null $((10*1024*1024*1024))
	mkfs.xfs -f /dev/ubbd0
}

unmap_ubbd_devs ()
{
	cd $UBBD_DIR
	for i in `ls /dev/ubbd*`; do
		id=$(echo "${i}" | sed "s/\/dev\/ubbd//g")
		unmap_dev $id
	done
}

cleanup ()
{
	cd $UBBD_TESTS_DIR
	umount /mnt
	umount /media

	if [ -z "$UBBD_DIR" ]; then
		echo "UBBD_DIR must be set in local_conf: UBBD_DIR=/xxx/xxxx"
		exit 1
	fi

	kill_ubbdd
	sleep 1
	prepare_ubbdd 0

	unmap_ubbd_devs

	sleep 3
	kill_ubbdd

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
