import random
import os
import time
import errno

from avocado import Test
from avocado.utils import process, genio


class Ubbdadmtest(Test):

    def setUp(self):
        self.ubbd_dir = self.params.get("UBBD_DIR")
        self.rbd_args = self.params.get("CONFIG_RBD_ARGS")
        self.s3_args = self.params.get("CONFIG_S3_ARGS")
        self.ssh_args = self.params.get("CONFIG_SSH_ARGS")
        self.cache_args = self.params.get("CONFIG_CACHE_ARGS")

        os.chdir(self.ubbd_dir)

    def test(self):
        cmd = str("./configure %s %s %s %s" % (self.rbd_args, self.s3_args, self.ssh_args, self.cache_args))
        process.run(cmd)
        process.run("make")

    def tearDown(self):
        pass
