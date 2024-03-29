#!/bin/bash
set -x

# setup env
echo 1024000 > /proc/sys/fs/aio-max-nr 

date_str=`date "+%Y_%m_%d_%H_%M_%S"`

DRY_RUN=0

SUFFIX=""
if [ "$1" = "quick" ]; then
	SUFFIX="_quick"
	echo "quick ubbd test."
else
	echo "full ubbd test."
fi

if [ "$2" = "dryrun" ]; then
	DRY_RUN=1
	echo "dryrun....."
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

source /etc/os-release
case "$ID" in
debian|ubuntu|devuan|elementary|softiron)
	echo "ubuntu"
	apt install -y  fio python3 python3-pip
        ;;
rocky|centos|fedora|rhel|ol|virtuozzo)
	echo "centos"
	yum install -y  fio python3 python3-pip
        ;;
*)
        echo "$ID is unknown, dependencies will have to be installed manually."
        exit 1
        ;;
esac

# install requirements
pip install avocado-framework==96.0 avocado-framework-plugin-varianter-yaml-to-mux==96.0 avocado-framework-plugin-result-html==96.0

# enable request stats
replace_option $UBBD_KERNEL_DIR/ubbd-headers/ubbd.h "\#undef UBBD_REQUEST_STATS" "\#define UBBD_REQUEST_STATS"
replace_option $UBBD_KERNEL_DIR/src/ubbd_internal.h "\#define UBBD_FAULT_INJECT" "\#undef UBBD_FAULT_INJECT"

# 1. cache backend test

# build and insmod ubbd
setup

prepare_ubbdd 0

cd ${UBBD_TESTS_DIR}
replace_option buildtest.py.data/buildtest.yaml  UBBD_DIR_DEFAULT ${UBBD_DIR}

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

avocado run --nrunner-max-parallel-tasks 1  buildtest.py -m buildtest.py.data/buildtest.yaml

if [ $? != 0 ]; then
	print_avocado_debug_log
	exit 1
fi

if [ ${DRY_RUN} -eq 0 ]; then
	avocado run --nrunner-max-parallel-tasks 1  cachebackendtest.py -m cachebackendtest.py.data/cachebackendtest${SUFFIX}.yaml
fi

if [ $? != 0 ]; then
	print_avocado_debug_log
	exit 1
fi

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

replace_option ubbdadmtest.py.data/ubbdadmtest${suffix}.yaml RBD_POOL_DEFAULT ${RBD_POOL}
replace_option ubbdadmtest.py.data/ubbdadmtest${suffix}.yaml RBD_NS_DEFAULT ${RBD_NS}
replace_option ubbdadmtest.py.data/ubbdadmtest${suffix}.yaml RBD_IMAGE_DEFAULT ${RBD_IMAGE}
replace_option ubbdadmtest.py.data/ubbdadmtest${suffix}.yaml RBD_SNAP_DEFAULT ${RBD_SNAP}
replace_option ubbdadmtest.py.data/ubbdadmtest${suffix}.yaml RBD_CEPH_CONF_DEFAULT ${RBD_CEPH_CONF}
replace_option ubbdadmtest.py.data/ubbdadmtest${suffix}.yaml RBD_USER_NAME_DEFAULT ${RBD_USER_NAME}
replace_option ubbdadmtest.py.data/ubbdadmtest${suffix}.yaml RBD_CLUSTER_NAME_DEFAULT ${RBD_CLUSTER_NAME}

if [ ${DRY_RUN} -eq 0 ]; then
	avocado run --nrunner-max-parallel-tasks 1  ubbdadmtest.py -m ubbdadmtest.py.data/ubbdadmtest${SUFFIX}.yaml
fi

if [ $? != 0 ]; then
	print_avocado_debug_log
	exit 1
fi

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
#if [ "$1" != "quick" ]; then
	#replace_option $UBBD_KERNEL_DIR/src/ubbd_internal.h "\#undef UBBD_FAULT_INJECT" "\#define UBBD_FAULT_INJECT"
#fi

setup

prepare_ubbd_devs

cache_dev_1=`ubbdadm map --type cache --cache-dev-type file --cache-dev-file-filepath ${UBBD_TESTS_CACHE_FILE_1} --backing-dev-type file --backing-dev-file-filepath ${UBBD_TESTS_BACKING_FILE_1}  --cache-mode writeback`
cache_dev_2=`ubbdadm map --type cache --cache-dev-type file --cache-dev-file-filepath ${UBBD_TESTS_CACHE_FILE_2} --backing-dev-type file --backing-dev-file-filepath ${UBBD_TESTS_BACKING_FILE_2}  --cache-mode writeback`

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
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml TEST_FILE_DEV_DEFAULT /dev/ubbd0
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml SCRATCH_FILE_DEV_DEFAULT /dev/ubbd1
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml TEST_MEM_DEV_DEFAULT /dev/ubbd3
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml SCRATCH_MEM_DEV_DEFAULT /dev/ubbd4
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml TEST_CACHE_DEV_DEFAULT	${cache_dev_1}
replace_option xfstests.py.data/xfstests${SUFFIX}.yaml SCRATCH_CACHE_DEV_DEFAULT ${cache_dev_2}


replace_option fio.py.data/fio${SUFFIX}.yaml UBBD_DEV_PATH /dev/ubbd2
replace_option fio.py.data/fio${SUFFIX}.yaml OUTPUT_FILE ${FIOTEST_OUTFILE}

replace_option upgradeonline.py.data/upgradeonline${SUFFIX}.yaml UBBD_TESTS_DIR_DEFAULT ${UBBD_TESTS_DIR}
replace_option upgradeonline.py.data/upgradeonline${SUFFIX}.yaml UBBD_DEV_DEFAULT /dev/ubbd0

if [ ${DRY_RUN} -eq 0 ]; then
	./all_test${SUFFIX}.py
fi

if [ $? != 0 ]; then
	print_avocado_debug_log
	exit 1
fi

if [ ! -z "$UBBD_TESTS_POST_TEST_CMDS" ]; then
	${UBBD_TESTS_POST_TEST_CMDS}
fi

# cleanup 
cleanup
