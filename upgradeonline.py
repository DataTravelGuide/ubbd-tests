import random
import os
import time

from avocado import Test
from avocado.utils import process, genio

class Upgradeonlinetest(Test):

    proc = None
    ubbd_dev_list = []

    def setUp(self):
        self.ubbdd_timeout = self.params.get("ubbdd_timeout")
        self.ubbd_dev = self.params.get('ubbd_dev', default=None)
        self.ubbd_tests_dir = self.params.get("UBBD_TESTS_DIR")

        os.chdir(self.ubbd_tests_dir)
        if self.ubbdd_timeout:
            self.start_ubbdd_killer()

    def start_ubbdd_killer(self):
        cmd = str("sh %s/utils/start_ubbdd_killer.sh %s" % (self.ubbd_tests_dir, self.ubbdd_timeout))
        self.proc = process.get_sub_process_klass(cmd)(cmd)
        pid = self.proc.start()
        self.log.info("ubbdd killer started: pid: %s, %s", pid, self.proc)

    def stop_ubbdd_killer(self):
        if not self.proc:
            return

        process.kill_process_tree(self.proc.get_pid())
        self.log.info("ubbdd killer stopped")

    def test(self):
        cmd = str("fio --name test --rw randwrite --bs 4K --ioengine libaio --filename %s  --direct 1 --numjobs 1 --iodepth 128  --verify md5 --group_reporting --eta-newline 1" % (self.ubbd_dev))

        result = process.run(cmd)
        if (result.exit_status):
            self.log.error("fio error")
            self.fail(result)

    def tearDown(self):
        self.stop_ubbdd_killer()
