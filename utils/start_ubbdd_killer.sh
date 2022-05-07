#!/bin/bash

sleep_time=$1

while true; do
	pkill ubbdd
	sleep $(($RANDOM % ${sleep_time}))
done
