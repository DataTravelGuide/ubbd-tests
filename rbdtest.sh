#!/usr/bin/env bash
set -ex

. utils/ceph-helpers.sh

POOL=rbd
ANOTHER_POOL=new_default_pool$$
NS=ns
IMAGE=testrbdubbd$$
SIZE=64
DATA=
DEV=

_sudo()
{
    local cmd

    if [ `id -u` -eq 0 ]
    then
	"$@"
	return $?
    fi

    # Look for the command in the user path. If it fails run it as is,
    # supposing it is in sudo path.
    cmd=`which $1 2>/dev/null` || cmd=$1
    shift
    sudo -nE "${cmd}" "$@"
}

setup()
{
    local ns x

    if [ -e CMakeCache.txt ]; then
	# running under cmake build dir

	CEPH_SRC=$(readlink -f $(dirname $0)/../../../src)
	CEPH_ROOT=${PWD}
	CEPH_BIN=${CEPH_ROOT}/bin

	export LD_LIBRARY_PATH=${CEPH_ROOT}/lib:${LD_LIBRARY_PATH}
	export PYTHONPATH=${PYTHONPATH}:${CEPH_SRC}/pybind:${CEPH_ROOT}/lib/cython_modules/lib.3
	PATH=${CEPH_BIN}:${PATH}
    fi

    _sudo echo test sudo

    trap cleanup INT TERM EXIT
    TEMPDIR=`mktemp -d`
    DATA=${TEMPDIR}/data
    dd if=/dev/urandom of=${DATA} bs=1M count=${SIZE}

    rbd namespace create ${POOL}/${NS}

    for ns in '' ${NS}; do
        rbd --dest-pool ${POOL} --dest-namespace "${ns}" --no-progress import \
            ${DATA} ${IMAGE}
    done

    # create another pool
    ceph osd pool create ${ANOTHER_POOL} 8
    rbd pool init ${ANOTHER_POOL}
}

function cleanup()
{
    local ns s

    set +e

    mount | fgrep ${TEMPDIR}/mnt && _sudo umount -f ${TEMPDIR}/mnt

    rm -Rf ${TEMPDIR}
    if [ -n "${DEV}" ]
    then
	_sudo rbd device --device-type ubbd unmap ${DEV}
    fi

    if [ -n "${DEV1}" ]
    then
	_sudo rbd device --device-type ubbd unmap ${DEV1}
    fi

    for ns in '' ${NS}; do
        if rbd -p ${POOL} --namespace "${ns}" status ${IMAGE} 2>/dev/null; then
	    for s in 0.5 1 2 4 8 16 32; do
	        sleep $s
	        rbd -p ${POOL} --namespace "${ns}" status ${IMAGE} |
                    grep 'Watchers: none' && break
	    done
	    rbd -p ${POOL} --namespace "${ns}" snap purge ${IMAGE}
	    rbd -p ${POOL} --namespace "${ns}" remove ${IMAGE}
        fi
    done
    rbd namespace remove ${POOL}/${NS}

    # cleanup/reset default pool
    rbd config global rm global rbd_default_pool
    ceph osd pool delete ${ANOTHER_POOL} ${ANOTHER_POOL} --yes-i-really-really-mean-it
}

function expect_false()
{
  if "$@"; then return 1; else return 0; fi
}


unmap_device()
{
    local dev=$1

    _sudo rbd device --device-type ubbd unmap ${dev}
    rbd device --device-type ubbd list | expect_false grep "^${dev}" || return 1
}

#
# main
#

setup

# exit status test
expect_false _sudo rbd device --device-type ubbd map INVALIDIMAGE
expect_false _sudo ubbdadm map --type rbd --rbd-image INVALIDIMAGE


# map test
DEV=`_sudo rbd device --device-type ubbd map ${POOL}/${IMAGE}`

# read test
[ "`dd if=${DATA} bs=1M | md5sum`" = "`_sudo dd if=${DEV} bs=1M | md5sum`" ]

# write test
dd if=/dev/urandom of=${DATA} bs=1M count=${SIZE}
_sudo dd if=${DATA} of=${DEV} bs=1M oflag=direct
[ "`dd if=${DATA} bs=1M | md5sum`" = "`rbd -p ${POOL} --no-progress export ${IMAGE} - | md5sum`" ]
unmap_device ${DEV}

# trim test
DEV=`_sudo rbd device --device-type ubbd map ${POOL}/${IMAGE}`
provisioned=`rbd -p ${POOL} --format xml du ${IMAGE} |
  $XMLSTARLET sel -t -m "//stats/images/image/provisioned_size" -v .`
used=`rbd -p ${POOL} --format xml du ${IMAGE} |
  $XMLSTARLET sel -t -m "//stats/images/image/used_size" -v .`
[ "${used}" -eq "${provisioned}" ]
# should honor discard as at time of mapping trim was considered by default
_sudo blkdiscard ${DEV}
sync
provisioned=`rbd -p ${POOL} --format xml du ${IMAGE} |
  $XMLSTARLET sel -t -m "//stats/images/image/provisioned_size" -v .`
used=`rbd -p ${POOL} --format xml du ${IMAGE} |
  $XMLSTARLET sel -t -m "//stats/images/image/used_size" -v .`
[ "${used}" -lt "${provisioned}" ]

# resize test
devname=$(basename ${DEV})
blocks=$(awk -v dev=${devname} '$4 == dev {print $3}' /proc/partitions)
test -n "${blocks}"
rbd resize ${POOL}/${IMAGE} --size $((SIZE * 2))M
rbd info ${POOL}/${IMAGE}
blocks2=$(awk -v dev=${devname} '$4 == dev {print $3}' /proc/partitions)
test -n "${blocks2}"
test ${blocks2} -eq $((blocks * 2))
rbd resize ${POOL}/${IMAGE} --allow-shrink --size ${SIZE}M
blocks2=$(awk -v dev=${devname} '$4 == dev {print $3}' /proc/partitions)
test -n "${blocks2}"
test ${blocks2} -eq ${blocks}

# read-only option test
unmap_device ${DEV}
DEV=`_sudo rbd --device-type ubbd map --read-only ${POOL}/${IMAGE}`

_sudo dd if=${DEV} of=/dev/null bs=1M
expect_false _sudo dd if=${DATA} of=${DEV} bs=1M oflag=direct
unmap_device ${DEV}

# map/unmap snap test
rbd snap create ${POOL}/${IMAGE}@snap
DEV=`_sudo rbd device --device-type ubbd map ${POOL}/${IMAGE}@snap`
unmap_device ${DEV}
DEV=

# map snap test with --snap-id
SNAPID=`rbd snap ls ${POOL}/${IMAGE} | awk '$2 == "snap" {print $1}'`
DEV=`_sudo rbd device --device-type ubbd map --snap-id ${SNAPID} ${POOL}/${IMAGE}`
unmap_device ${DEV}
DEV=

# map/unmap namespace test
rbd snap create ${POOL}/${NS}/${IMAGE}@snap
DEV=`_sudo rbd device --device-type ubbd map ${POOL}/${NS}/${IMAGE}@snap`
unmap_device ${DEV}
DEV=

# map/unmap namespace test with --snap-id
SNAPID=`rbd snap ls ${POOL}/${NS}/${IMAGE} | awk '$2 == "snap" {print $1}'`
DEV=`_sudo rbd device --device-type ubbd map --snap-id ${SNAPID} ${POOL}/${NS}/${IMAGE}`
unmap_device ${DEV}
DEV=

# map namespace using options test
DEV=`_sudo rbd device --device-type ubbd map --pool ${POOL} --namespace ${NS} --image ${IMAGE}`
unmap_device ${DEV}
DEV=`_sudo rbd device --device-type ubbd map --pool ${POOL} --namespace ${NS} --image ${IMAGE} --snap snap`
unmap_device ${DEV}
DEV=

# map/unmap test with just image name and expect image to come from default pool
if [ "${POOL}" = "rbd" ];then
    DEV=`_sudo rbd device --device-type ubbd map ${IMAGE}`
    unmap_device ${DEV}
    DEV=
fi

# map/unmap test with just image name after changing default pool
rbd config global set global rbd_default_pool ${ANOTHER_POOL}
rbd create --size 10M ${IMAGE}
DEV=`_sudo rbd device --device-type ubbd map ${IMAGE}`
unmap_device ${DEV}
DEV=
# reset
rbd config global rm global rbd_default_pool

# map and check dev link
DEV=`_sudo rbd device --device-type ubbd map ${POOL}/${IMAGE}`
LINK_DEV=`readlink /dev/ubbd/rbd/${POOL}/${IMAGE}/*`
unmap_device ${DEV}
[ ${DEV} = ${LINK_DEV} ]

DEV=`_sudo rbd device --device-type ubbd map --pool ${POOL} --namespace ${NS} --image ${IMAGE}`
LINK_DEV=`readlink /dev/ubbd/rbd/${POOL}/${NS}/${IMAGE}/*`
unmap_device ${DEV}
[ ${DEV} = ${LINK_DEV} ]

DEV=`_sudo rbd device --device-type ubbd map ${POOL}/${IMAGE}@snap`
LINK_DEV=`readlink /dev/ubbd/rbd/${POOL}/${IMAGE}/snap/*`
unmap_device ${DEV}
[ ${DEV} = ${LINK_DEV} ]

DEV=`_sudo rbd device --device-type ubbd map ${POOL}/${IMAGE}`
DEV_ID=${DEV//\/dev\/ubbd/}
LINK_DEV=`readlink /dev/ubbd/rbd/${POOL}/${IMAGE}/${DEV_ID}`
[ ${DEV} = ${LINK_DEV} ]

DEV1=`_sudo rbd device --device-type ubbd map ${POOL}/${IMAGE}`
DEV_ID1=${DEV1//\/dev\/ubbd/}
LINK_DEV1=`readlink /dev/ubbd/rbd/${POOL}/${IMAGE}/${DEV_ID1}`
[ ${DEV1} = ${LINK_DEV1} ]

unmap_device ${DEV} 
unmap_device ${DEV1} 

echo OK
