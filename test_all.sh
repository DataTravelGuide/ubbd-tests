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
	${UBBD_TESTS_SETUP_CMD}
fi

# install requirements
apt install -y bpfcc-tools
pip install avocado-framework avocado-framework-plugin-varianter-yaml-to-mux avocado-framework-plugin-result-html

# build and insmod ubbd
setup

# 1. prepare memleak first
prepare_ubbdd 1

cd ${ubbd_test_dir}
replace_option ubbdadmtest.py.data/ubbdadmtest_no_killer.yaml UBBD_DIR_DEFAULT ${UBBD_DIR}
replace_option ubbdadmtest.py.data/ubbdadmtest_no_killer.yaml UBBD_TESTS_DIR_DEFAULT ${ubbd_test_dir}
replace_option ubbdadmtest.py.data/ubbdadmtest_no_killer.yaml UBBD_B_FILE_DEFAULT "/dev/ram0p1"
replace_option ubbdadmtest.py.data/ubbdadmtest_no_killer.yaml UBBD_B_FILE_SIZE_DEFAULT 1048576000

avocado run --nrunner-max-parallel-tasks 1  ubbdadmtest.py -m ubbdadmtest.py.data/ubbdadmtest_no_killer.yaml

# sleep for memleak to output
sleep 30
kill_ubbdd

# restart ubbdd to check memleak in reopen_devs
prepare_ubbdd 1
unmap_ubbd_devs
sleep 30
kill_ubbdd

# 2. start other tests without memleak
prepare_ubbd_devs

# replace default options with the real options
cd ${ubbd_test_dir}
replace_option ubbdadmtest.py.data/ubbdadmtest.yaml UBBD_DIR_DEFAULT ${UBBD_DIR}
replace_option ubbdadmtest.py.data/ubbdadmtest.yaml UBBD_TESTS_DIR_DEFAULT ${ubbd_test_dir}
replace_option ubbdadmtest.py.data/ubbdadmtest.yaml UBBD_B_FILE_DEFAULT "/dev/ram0p1"
replace_option ubbdadmtest.py.data/ubbdadmtest.yaml UBBD_B_FILE_SIZE_DEFAULT 1048576000

replace_option xfstests.py.data/xfstests.yaml XFSTESTS_DIR_DEFAULT ${UBBD_TESTS_XFSTESTS_DIR}
replace_option xfstests.py.data/xfstests.yaml UBBD_DIR_DEFAULT ${UBBD_DIR}
replace_option xfstests.py.data/xfstests.yaml UBBD_TESTS_DIR_DEFAULT ${ubbd_test_dir}
replace_option xfstests.py.data/xfstests.yaml SCRATCH_MNT_DEFAULT ${XFSTESTS_SCRATCH_MNT}
replace_option xfstests.py.data/xfstests.yaml TEST_MNT_DEFAULT ${XFSTESTS_TEST_MNT}


replace_option fio.py.data/fio.yaml UBBD_DEV_PATH /dev/ubbd2
replace_option fio.py.data/fio.yaml OUTPUT_FILE ${FIOTEST_OUTFILE}

replace_option upgradeonline.py.data/upgradeonline.yaml UBBD_TESTS_DIR_DEFAULT ${ubbd_test_dir}
replace_option upgradeonline.py.data/upgradeonline.yaml UBBD_DEV_DEFAULT /dev/ubbd0

./all_test.py

if [ ! -z "$UBBD_TESTS_POST_TEST_CMDS" ]; then
	${UBBD_TESTS_POST_TEST_CMDS}
fi

# cleanup 
cleanup
