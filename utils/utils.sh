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

# fio result parse
get_iops()
{
	local file=$1

	grep -o "IOPS=.*," ${file} | sed 's/IOPS=//g' | sed 's/,//g'
}

get_bw()
{
	local file=$1

	grep -o "BW=.* " ${file} | sed 's/BW=//g' | sed 's/ //g'
}

get_lat()
{
	local file=$1

	grep -o " lat.*avg=.*," ${file} | sed 's/lat.*avg=//g' | sed 's/,//g'
}

get_unit()
{
	local file=$1

	grep " lat.*avg" ${file} | grep -o .sec
}

iops_converter()
{
	local iops=$1

	if echo ${iops} | grep -q "k$" ; then
		iops=$(echo ${iops} | sed 's/k//g')
		iops=$(awk -v x=${iops} 'BEGIN{printf "%.0f", x * 1000}')
	fi

	echo ${iops}
}

bw_converter_to_M()
{
	local bw=$1

	if echo ${bw} | grep -q "KiB.s$" ; then
		bw=$(echo ${bw} | sed 's/KiB.s//g')
		bw=$(awk -v x=${bw} 'BEGIN{printf "%.2f", x / 1024}')
	elif echo ${bw} | grep -q "MiB.s$" ; then
		bw=$(echo ${bw} | sed 's/MiB.s//g')
	elif echo ${bw} | grep -q "GiB.s$" ; then
		bw=$(echo ${bw} | sed 's/GiB.s//g')
		bw=$(awk -v x=${bw} 'BEGIN{printf "%.2f", x * 1024}')
	fi

	echo ${bw}
}

lat_converter_to_usec()
{
	local lat=$1

	if echo ${lat} | grep -q "usec$" ; then
		lat=$(echo ${lat} | sed 's/usec//g')
	elif echo ${lat} | grep -q "msec$" ; then
		lat=$(echo ${lat} | sed 's/msec//g')
		lat=$(awk -v x=${lat} 'BEGIN{printf "%.2f", x * 1000}')
	# I am not sure the 'else'.
	else
		lat=$(awk -v x=${lat} 'BEGIN{printf "%.2f", x / 1000}')
	fi

	echo ${lat}
}

lat_converter_to_msec()
{
	local lat=$1

	if echo ${lat} | grep -q "usec$" ; then
		lat=$(echo ${lat} | sed 's/usec//g')
		lat=$(awk -v x=${lat} 'BEGIN{printf "%.2f", x / 1000}')
	elif echo ${lat} | grep -q "msec$" ; then
		lat=$(echo ${lat} | sed 's/msec//g')
	# I am not sure the 'else'.
	else
		lat=$(awk -v x=${lat} 'BEGIN{printf "%.2f", x / 1000 / 1000}')
	fi

	echo ${lat}
}

get_performance()
{
	local file=$1

	# Return if the file is not exist.
	if [[ ! -e ${file} ]]; then
		return
	fi

	local case=$(echo ${file} | grep -o -E "(rand){0,1}(read|write|rw)_(4k|8k|16k|32k|64k|128k|256k|512k|1m|1M)_(1|2|4|8|16|32|64|128)iodepth_[[:digit:]]{1,}numjobs")
	if [ -z "${case}" ]; then
		case=$(sed -ne '1p' ${file} | sed 's/:.*//g')
	fi
	if [ -z "${case}" ]; then
		return
	fi

	local rw=$(echo ${case} | grep -o -E "(rand){0,1}(read|write|rw)")
	local bs=$(echo ${case} | grep -o -E "(4k|8k|16k|32k|64k|128k|256k|512k|1m)")
	local iodepth=$(echo ${case} | grep -o -E "(1|2|4|8|16|32|64|128)iodepth" | sed 's/iodepth//')
	local numjobs=$(echo ${case} | grep -o -E "[[:digit:]]{1,}numjobs" | sed 's/numjobs//')

	local iops=$(get_iops ${file})
	local bw=$(get_bw ${file})
	local lat=$(get_lat ${file})
	local unit=$(get_unit ${file})

	local i=1
	for _iops in ${iops}
	do
		_bw=$(echo ${bw} | cut -d ' ' -f${i})
		_lat=$(echo ${lat} | cut -d ' ' -f${i})
		_unit=$(echo ${unit} | cut -d ' ' -f${i})

		_iops=$(iops_converter ${_iops})
		_bw=$(bw_converter_to_M ${_bw})
		_lat=$(lat_converter_to_${LATENCY_UNIT}ec ${_lat}${_unit})
		i=$((i+1))

		echo -ne "${rw}, ${bs}, ${iodepth}, ${numjobs}, ${_iops}, ${_bw}, ${_lat}\n"
	done
}
