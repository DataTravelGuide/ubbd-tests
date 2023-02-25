#!/bin/bash

wait_for_ubbdd ()
{
	while true ; do
		ubbdadm list
		if [ $? -eq 0 ]; then
			return
		fi
		sleep 1
	done
}

sleep_time=$1

while true; do
	pkill ubbd-backend
	pkill ubbdd
	ps -ef|grep ubbdd|grep memleak|gawk '{print "kill "$2}'|bash

	wait_for_ubbdd
	sleep $(($RANDOM % ${sleep_time}))
done
