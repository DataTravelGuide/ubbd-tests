#!/bin/sh

date_str=`date "+%Y_%m_%d_%H_%M_%S"`
ubbd_test_dir=`pwd`

cat ./local_conf
. ./local_conf
. ./utils/utils.sh

if [ -z "$UBBD_DIR" ]; then
	echo "UBBD_DIR must be set in local_conf: UBBD_DIR=/xxx/xxxx"
	exit 1
fi

if [ ! -z "$UBBD_TESTS_SETUP_CMD" ]; then
	$UBBD_TESTS_SETUP_CMD
fi

# build and insmod ubbd
setup

# start tests
cd $ubbd_test_dir

# replace default options with the real options
replace_option ubbdadmtest.py.data/ubbdadmtest.yaml UBBD_DIR_DEFAULT ${UBBD_DIR}
replace_option ubbdadmtest.py.data/ubbdadmtest.yaml UBBD_TESTS_DIR_DEFAULT ${ubbd_test_dir}
replace_option ubbdadmtest.py.data/ubbdadmtest.yaml UBBD_B_FILE_DEFAULT "/dev/ram0p1"
replace_option ubbdadmtest.py.data/ubbdadmtest.yaml UBBD_B_FILE_SIZE_DEFAULT 1048576000

replace_option xfstests.py.data/xfstests.yaml XFSTESTS_DIR_DEFAULT ${UBBD_TESTS_XFSTESTS_DIR}
replace_option xfstests.py.data/xfstests.yaml UBBD_DIR_DEFAULT ${UBBD_DIR}
replace_option xfstests.py.data/xfstests.yaml UBBD_TESTS_DIR_DEFAULT ${ubbd_test_dir}
replace_option xfstests.py.data/xfstests.yaml SCRATCH_MNT_DEFAULT ${XFSTESTS_SCRATCH_MNT}
replace_option xfstests.py.data/xfstests.yaml TEST_MNT_DEFAULT ${XFSTESTS_TEST_MNT}


echo "RW TYPE, BS, IODEPTH, NUMJOBS, IOPS, BW(MiB/s), LATENCY(us)" > ${FIOTEST_OUTFILE}
replace_option fio.py.data/fio.yaml UBBD_DEV_PATH /dev/ubbd0
replace_option fio.py.data/fio.yaml OUTPUT_FILE ${FIOTEST_OUTFILE}

./all_test.py

if [ ! -z "$UBBD_TESTS_POST_TEST_CMD" ]; then
	$UBBD_TESTS_POST_TEST_CMD
fi

# cleanup 
cleanup
