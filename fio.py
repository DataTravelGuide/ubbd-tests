import random
import os
import time
import json

from avocado import Test
from avocado.utils import process, genio

class Fiotest(Test):


    def setUp(self):
        self.dev_path = self.params.get("dev_path")
        self.runtime = self.params.get("runtime")
        self.ioengine = self.params.get("ioengine")
        self.rw_type = self.params.get("rw_type")
        self.block_size = self.params.get("block_size")
        self.iodepth = self.params.get("iodepth")
        self.numjobs = self.params.get("numjobs")
        self.output_file = str("%s/%s" % (os.path.dirname(self.logdir), self.params.get("output_file")))
        self.rwmixread = self.params.get("rwmixread")
        self.result_type = self.params.get("result_type")

        self.log_file = os.path.join(self.logdir, 'fiolog.out')

    def get_output(self, json, t):
        iops = str(int(json.get("jobs")[0].get(t).get("iops")))
        bw = str(int(json.get("jobs")[0].get(t).get("bw_bytes") / 1024 / 1024))
        lat = str(int(json.get("jobs")[0].get(t).get("lat_ns").get('mean') / 1000))
        return str("%s, %s, %s" % (iops, bw, lat))

    def get_output_from_json(self, json):
        result = []
        for t in self.result_type.split():
            result.append(str(self.get_output(json, t)))
            self.log.info(result)
        return result

    def test(self):
        cmd = str("fio --name=test --rw=%s --bs=%s --runtime=%s --ioengine=%s --iodepth=%s --numjobs=%s --filename=%s --direct=1 --group_reporting --time_based=1 --output-format=json" % (self.rw_type, self.block_size, self.runtime, self.ioengine, self.iodepth, self.numjobs, self.dev_path))
        if (self.rwmixread):
            cmd = str("%s --rwmixread %s" % (cmd, self.rwmixread))

        result = process.run(cmd)
        result_json = json.loads(result.stdout_text.strip())
        output_list = self.get_output_from_json(result_json)
        
        add_header = False
        if not os.path.exists(self.output_file):
            add_header = True
            
        output_file = open(self.output_file, 'a')
        if add_header:
            output_file.write("RW TYPE, BS, IODEPTH, NUMJOBS, IOPS, BW(MiB/s), LATENCY(us)\n")

        for string in output_list:
            output_str = str("%s, %s, %s, %s, %s\n" % (self.rw_type, self.block_size, self.iodepth, self.numjobs, string))
            output_file.write(output_str)

        output_file.close()


    def tearDown(self):
        self.log.info("finished")
