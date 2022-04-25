umount /mnt
umount /media

cd /data/ubbd/
./ubbdadm/ubbdadm --command unmap --ubbdid 0
./ubbdadm/ubbdadm --command unmap --ubbdid 1
./ubbdadm/ubbdadm --command unmap --ubbdid 2
sleep 3
ps -ef|grep start_ubbdd.sh|gawk '{print "kill "$2}'|bash
pkill ubbdd

rmmod ubbd
rmmod brd
