#!/bin/bash

cd ${UBBD_DIR}
./configure ${CONFIG_RBD_ARGS} ${CONFIG_S3_ARGS} ${CONFIG_SSH_ARGS} ${CONFIG_CACHE_ARGS}
make
