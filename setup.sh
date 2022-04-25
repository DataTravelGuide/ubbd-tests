mount -t nfs 192.168.1.120:/nfs /nfs_images
cd /data/ubbd/
modprobe uio
make
sleep 1
insmod kmods/ubbd.ko
sleep 1
modprobe brd rd_nr=1 rd_size=$((21*1024*1024)) max_part=16

parted /dev/ram0 mklabel gpt
sgdisk  /dev/ram0 -n 1:1M:+1000M
sgdisk  /dev/ram0 -n 2:1001M:+10G
sgdisk  /dev/ram0 -n 3:11241M:+10G

partprobe /dev/ram0
ps -ef|grep start_ubbdd.sh|gawk '{print "kill "$2}'|bash
sleep 1
sh -x tests/function_test/utils/start_ubbdd.sh 0 0 30 &
sleep 2
./ubbdadm/ubbdadm --command map --type file --filepath /dev/ram0p2 --devsize $((10*1024*1024*1024))
sleep 1
./ubbdadm/ubbdadm --command map --type file --filepath /dev/ram0p3 --devsize $((10*1024*1024*1024))
sleep 1
./ubbdadm/ubbdadm --command map --type null --devsize $((10*1024*1024*1024))
sleep 1
mkfs.xfs -f /dev/ubbd0
