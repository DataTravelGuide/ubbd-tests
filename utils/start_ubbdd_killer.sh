#!/bin/bash

sleep_time=$1

while true; do
	pkill ubbd-backend
	pkill ubbdd
	ps -ef|grep ubbdd|grep memleak|gawk '{print "kill "$2}'|bash
	sleep $(($RANDOM % ${sleep_time}))
done
