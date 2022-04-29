import random
import os
import time

from avocado import Test
from avocado.utils import process, genio

class Ubbdadmtest(Test):


    def setUp(self):
        self.dev_path = self.params.get("dev_path")
        self.runtime = self.params.get("runtime")
        self.ioengine = self.params.get("ioengine")
        self.rw_type = self.params.get("rw_type")
        self.block_size = self.params.get("block_size")
        self.iodepth = self.params.get("iodepth")
        self.numjobs = self.params.get("numjobs")
        self.output_file = self.params.get("output_file")

        self.log_file = os.path.join(self.logdir, 'fiolog.out')

    def test(self):
        cmd = str("fio --name=test --rw=%s --bs=%s --runtime=%s --ioengine=%s --iodepth=%s --numjobs=%s --filename=%s --direct=1 --group_reporting --time_based=1 --output=%s" % (self.rw_type, self.block_size, self.runtime, self.ioengine, self.iodepth, self.numjobs, self.dev_path, self.log_file))
        process.run(cmd)


    def tearDown(self):
        collect_cmd = str("./utils/fio_result_collect.sh %s" % (self.log_file))
        result = process.run(collect_cmd)
        self.whiteboard = result.stdout_text.strip()
