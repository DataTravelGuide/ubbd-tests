#!/bin/bash

result_file=$1

if [ -z ${result_file} ]; then
	echo "Please input result file."
	exit -1
fi

. ./utils/utils.sh

LATENCY_UNIT="us"
get_performance $1
