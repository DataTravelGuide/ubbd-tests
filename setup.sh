#!/bin/sh

date_str=`date "+%Y_%m_%d_%H_%M_%S"`

. ./local_conf
. ./utils/utils.sh

if [ -z "$UBBD_DIR" ]; then
	echo "UBBD_DIR must be set in local_conf: UBBD_DIR=/xxx/xxxx"
	exit 1
fi

if [ ! -z "$UBBD_TESTS_SETUP_CMD" ]; then
	$UBBD_TESTS_SETUP_CMD
fi

# enable request stats
replace_option $UBBD_DIR/include/ubbd.h "\#undef UBBD_REQUEST_STATS" "\#define UBBD_REQUEST_STATS"

# build and insmod ubbd
setup $1

prepare_ubbd_devs
