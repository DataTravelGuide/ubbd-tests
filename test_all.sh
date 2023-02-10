#!/bin/sh

date_str=`date "+%Y_%m_%d_%H_%M_%S"`

SUFFIX=""
if [ "$1" = "quick" ]; then
	SUFFIX="_quick"
	echo "quick ubbd test."
else
	echo "full ubbd test."
fi

cat ./local_conf
. ./local_conf
. ./utils/utils.sh

if [ -z "$UBBD_DIR" ]; then
	echo "UBBD_DIR must be set in local_conf: UBBD_DIR=/xxx/xxxx"
	exit 1
fi

if [ ! -z "$UBBD_TESTS_SETUP_CMD" ]; then
	${UBBD_TESTS_SETUP_CMD}
fi

# install requirements
apt install -y bpfcc-tools fio
pip install avocado-framework==96.0 avocado-framework-plugin-varianter-yaml-to-mux==96.0 avocado-framework-plugin-result-html==96.0

# enable request stats
replace_option $UBBD_KERNEL_DIR/include/ubbd.h "\#undef UBBD_REQUEST_STATS" "\#define UBBD_REQUEST_STATS"
replace_option $UBBD_KERNEL_DIR/ubbd_internal.h "\#define UBBD_FAULT_INJECT" "\#undef UBBD_FAULT_INJECT"

# 1. cache backend test

# build and insmod ubbd
setup

prepare_ubbdd 0

cd ${UBBD_TESTS_DIR}
replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml UBBD_DIR_DEFAULT ${UBBD_DIR}
replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml UBBD_TESTS_DIR_DEFAULT ${UBBD_TESTS_DIR}
replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml UBBD_DEV_SIZE_DEFAULT 1048576000
replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml UBBD_CACHE_FILE_DEFAULT "/dev/ram0p1"
replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml UBBD_CACHE_FILE_SIZE_DEFAULT 1048576000

replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml UBBD_BACKING_FILE_DEFAULT "/dev/ram0p2"
replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml UBBD_BACKING_FILE_SIZE_DEFAULT 1048576000

replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml S3_ACCESS_ID ${UBBD_S3_ACCESSID}
replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml S3_ACCESS_KEY ${UBBD_S3_ACCESSKEY}
replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml S3_HOSTNAME ${UBBD_S3_HOSTNAME}
replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml S3_PORT ${UBBD_S3_PORT}
replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml S3_BUCKET_NAME ${UBBD_BUCKET_NAME}
replace_option cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml S3_DEV_SIZE_DEFAULT 31457280

avocado run --nrunner-max-parallel-tasks 1  cachebackendtest.py -m cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml

if [ ! -z "$UBBD_TESTS_POST_TEST_CMDS" ]; then
	${UBBD_TESTS_POST_TEST_CMDS}
fi

# sleep for memleak to output
sleep 30
kill_ubbdd

# restart ubbdd to check memleak in reopen_devs
prepare_ubbdd 0
unmap_ubbd_devs
sleep 30
kill_ubbdd

#cleanup
cleanup

# 2. prepare memleak first
# build and insmod ubbd
setup

prepare_ubbdd 0

cd ${UBBD_TESTS_DIR}
replace_option ubbdadmtest.py.data/ubbdadmtest${SUFFIX}.yaml UBBD_DIR_DEFAULT ${UBBD_DIR}
replace_option ubbdadmtest.py.data/ubbdadmtest${SUFFIX}.yaml UBBD_TESTS_DIR_DEFAULT ${UBBD_TESTS_DIR}
replace_option ubbdadmtest.py.data/ubbdadmtest${SUFFIX}.yaml UBBD_B_FILE_DEFAULT "/dev/ram0p1"
replace_option ubbdadmtest.py.data/ubbdadmtest${SUFFIX}.yaml UBBD_B_FILE_SIZE_DEFAULT 1048576000

replace_option ubbdadmtest.py.data/ubbdadmtest${SUFFIX}.yaml S3_ACCESS_ID ${UBBD_S3_ACCESSID}
replace_option ubbdadmtest.py.data/ubbdadmtest${SUFFIX}.yaml S3_ACCESS_KEY ${UBBD_S3_ACCESSKEY}
replace_option ubbdadmtest.py.data/ubbdadmtest${SUFFIX}.yaml S3_HOSTNAME ${UBBD_S3_HOSTNAME}
replace_option ubbdadmtest.py.data/ubbdadmtest${SUFFIX}.yaml S3_PORT ${UBBD_S3_PORT}
replace_option ubbdadmtest.py.data/ubbdadmtest${SUFFIX}.yaml S3_BUCKET_NAME ${UBBD_BUCKET_NAME}

avocado run --nrunner-max-parallel-tasks 1  ubbdadmtest.py -m ubbdadmtest.py.data/ubbdadmtest${SUFFIX}.yaml

if [ ! -z "$UBBD_TESTS_POST_TEST_CMDS" ]; then
	${UBBD_TESTS_POST_TEST_CMDS}
fi

# sleep for memleak to output
sleep 30
kill_ubbdd

# restart ubbdd to check memleak in reopen_devs
prepare_ubbdd 0
unmap_ubbd_devs
sleep 30
kill_ubbdd

#cleanup
cleanup

# 3. start other tests without memleak

cd ${UBBD_DIR}
replace_option $UBBD_KERNEL_DIR/ubbd_internal.h "\#undef UBBD_FAULT_INJECT" "\#define UBBD_FAULT_INJECT"

setup

prepare_ubbd_devs

# replace default options with the real options
cd ${UBBD_TESTS_DIR}
replace_option ubbdadmtest.py.data/ubbdadmtest_fault_inject${SUFFIX}.yaml UBBD_DIR_DEFAULT ${UBBD_DIR}
replace_option ubbdadmtest.py.data/ubbdadmtest_fault_inject${SUFFIX}.yaml UBBD_TESTS_DIR_DEFAULT ${UBBD_TESTS_DIR}
replace_option ubbdadmtest.py.data/ubbdadmtest_fault_inject${SUFFIX}.yaml UBBD_B_FILE_DEFAULT "/dev/ram0p1"
replace_option ubbdadmtest.py.data/ubbdadmtest_fault_inject${SUFFIX}.yaml UBBD_B_FILE_SIZE_DEFAULT 1048576000

replace_option ubbdadmtest.py.data/ubbdadmtest_fault_inject${SUFFIX}.yaml S3_ACCESS_ID ${UBBD_S3_ACCESSID}
replace_option ubbdadmtest.py.data/ubbdadmtest_fault_inject${SUFFIX}.yaml S3_ACCESS_KEY ${UBBD_S3_ACCESSKEY}
replace_option ubbdadmtest.py.data/ubbdadmtest_fault_inject${SUFFIX}.yaml S3_HOSTNAME ${UBBD_S3_HOSTNAME}
replace_option ubbdadmtest.py.data/ubbdadmtest_fault_inject${SUFFIX}.yaml S3_PORT ${UBBD_S3_PORT}
replace_option ubbdadmtest.py.data/ubbdadmtest_fault_inject${SUFFIX}.yaml S3_BUCKET_NAME ${UBBD_BUCKET_NAME}

replace_option xfstests.py.data/xfstests${SUFFIX}.yaml XFSTESTS_DIR_DEFAULT ${UBBD_TESTS_XFSTESTS_DIR}
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml UBBD_DIR_DEFAULT ${UBBD_DIR}
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml UBBD_TESTS_DIR_DEFAULT ${UBBD_TESTS_DIR}
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml SCRATCH_MNT_DEFAULT ${XFSTESTS_SCRATCH_MNT}
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml TEST_MNT_DEFAULT ${XFSTESTS_TEST_MNT}
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml TEST_DEV_DEFAULT /dev/ubbd0
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml SCRATCH_DEV_DEFAULT /dev/ubbd1


replace_option fio.py.data/fio${SUFFIX}.yaml UBBD_DEV_PATH /dev/ubbd2
replace_option fio.py.data/fio${SUFFIX}.yaml OUTPUT_FILE ${FIOTEST_OUTFILE}

replace_option upgradeonline.py.data/upgradeonline${SUFFIX}.yaml UBBD_TESTS_DIR_DEFAULT ${UBBD_TESTS_DIR}
replace_option upgradeonline.py.data/upgradeonline${SUFFIX}.yaml UBBD_DEV_DEFAULT /dev/ubbd0

./all_test${SUFFIX}.py

if [ ! -z "$UBBD_TESTS_POST_TEST_CMDS" ]; then
	${UBBD_TESTS_POST_TEST_CMDS}
fi

# cleanup 
cleanup
