memleak=$1
downtime=$2

while true; do
	if [ $memleak -eq 1 ]; then
		memleak-bpfcc -c "./ubbdd/ubbdd" >> /var/log/memleak.log
	else
		./ubbdd/ubbdd
	fi
	sleep ${downtime}
done
