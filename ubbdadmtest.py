import random
import os
import time
import errno

from avocado import Test
from avocado.utils import process, genio


class Ubbdadmtest(Test):

    proc = None
    ubbd_dev_list = []

    def setUp(self):
        self.ubbdd_timeout = self.params.get("ubbdd_timeout")
        self.ubbd_backend_file = self.params.get("ubbd_backend_file")
        self.ubbd_backend_file_size = self.params.get("ubbd_backend_file_size")
        self.ubbdadm_action_num = self.params.get("ubbdadm_action_num")
        self.ubbd_dev_timeout = self.params.get("ubbd_dev_timeout")
        self.ubbd_page_reserve = self.params.get("ubbd_page_reserve")
        self.fio_block_size = self.params.get("block_size")
        self.fio_iops_limit = self.params.get("iops_limit")
        self.fio_direct = self.params.get("fio_direct")
        self.ubbd_dir = self.params.get("UBBD_DIR")
        self.ubbd_tests_dir = self.params.get("UBBD_TESTS_DIR")
        self.fail_directly = self.params.get("fail_directly")
        self.always_retry = self.params.get("always_retry")
        self.ignore_exit_status = [(256 - errno.ECONNABORTED), -errno.EACCES, 255]
        self.s3_accessid = self.params.get("s3_accessid")
        self.s3_accesskey = self.params.get("s3_accesskey")
        self.s3_hostname = self.params.get("s3_hostname")
        self.s3_port = self.params.get("s3_port")
        self.s3_volume_name = self.params.get("s3_volume_name")
        self.s3_bucket_name = self.params.get("s3_bucket_name")
        self.map_type = self.params.get("ubbd_map_type")
        self.fio_iodepth = self.params.get("fio_iodepth")
        self.fio_numjobs = self.params.get("fio_numjobs")
        self.start_fio = self.params.get("start_fio")

        self.rbd_pool = self.params.get("rbd_pool")
        self.rbd_ns = self.params.get("rbd_ns")
        self.rbd_image = self.params.get("rbd_image")
        self.rbd_snap = self.params.get("rbd_snap")
        self.rbd_ceph_conf = self.params.get("rbd_ceph_conf")
        self.rbd_user_name = self.params.get("rbd_user_name")
        self.rbd_cluster_name = self.params.get("rbd_cluster_name")

        self.mem_devsize = self.params.get("mem_devsize")

        self.wait_for_ubbdd()

        os.chdir(self.ubbd_dir)
        if self.ubbdd_timeout:
            self.start_ubbdd_killer()

    def ubbd_list(self):
        cmd = str("ubbdadm list")
        result = process.run(cmd, ignore_status=True)
        if result.exit_status:
            return False

        return True

    def wait_for_ubbdd(self):
        while (True):
            if (self.ubbd_list()):
                return

            time.sleep(1)

    def start_ubbdd_killer(self):
        cmd = str("bash %s/utils/start_ubbdd_killer.sh %s" % (self.ubbd_tests_dir, self.ubbdd_timeout))
        self.proc = process.get_sub_process_klass(cmd)(cmd)
        pid = self.proc.start()
        self.log.info("ubbdd killer started: pid: %s, %s", pid, self.proc)

    def stop_ubbdd_killer(self):
        if not self.proc:
            return

        self.proc.stop(1)
        self.log.info("ubbdd killer stopped")

    def start_fio_process(self, ubbd_dev):
        if not self.start_fio:
            return
        cmd = str("fio --name test --rw randrw --bs %s --ioengine libaio --filename %s --numjobs %s --iodepth %s --eta-newline 1 " % (self.fio_block_size, ubbd_dev, self.fio_numjobs, self.fio_iodepth))
        if (self.fio_iops_limit != 0):
            cmd = str("%s --rate_iops %s" % (cmd, self.fio_iops_limit))
        if (self.fio_direct):
            cmd = str("%s --direct 1" % (cmd))
        else:
            cmd = str("%s --direct 0" % (cmd))

        proc = process.get_sub_process_klass(cmd)(cmd)
        proc.start()
        time.sleep(1)

    def set_dev_timeout(self, ubbd_dev):
        cmd = str("echo %s > /sys/block/%s/queue/io_timeout" % (self.ubbd_dev_timeout, ubbd_dev.replace("/dev/", "")))
        process.run(cmd)

    def get_dev_id(self, ubbd_dev):
        return str(ubbd_dev.replace("/dev/ubbd", "")).strip()

    def __list_and_check(self, ubbd_dev):
        cmd = str("ubbdadm list")
        result = process.run(cmd, ignore_status=True)
        if result.exit_status:
            if self.always_retry:
                return False
            if self.fail_directly or (result.exit_status not in self.ignore_exit_status):
                self.fail("list and check failed")
            return False

        dev_list = result.stdout_text.strip().split()
        for dev in dev_list:
            if dev.strip() == ubbd_dev.strip():
                return True

        return False

    def list_and_check(self, ubbd_dev):
        while (True):
            if (self.__list_and_check(ubbd_dev)):
                return

            time.sleep(1)

    def do_map(self):
        if (self.map_type == "file"):
            cmd = str("ubbdadm map --type file --file-filepath %s --devsize %s" % (self.ubbd_backend_file, self.ubbd_backend_file_size))
        elif (self.map_type == "s3"):
            cmd = str("ubbdadm map --type s3 --s3-accessid \"%s\" --s3-accesskey \"%s\" --s3-hostname \"%s\" --s3-port %s --s3-volume-name \"%s\" --devsize $((1024*1024*1024)) --s3-block-size $((4*1024)) --s3-bucket-name \"%s\"" % (self.s3_accessid, self.s3_accesskey, self.s3_hostname, self.s3_port, self.s3_volume_name, self.s3_bucket_name))
        elif (self.map_type == "rbd"):
            cmd = str("ubbdadm map --type rbd --rbd-pool %s --rbd-ns \"%s\" --rbd-image %s --rbd-snap \"%s\" --rbd-ceph-conf %s --rbd-user-name %s --rbd-cluster-name %s" % (self.rbd_pool, self.rbd_ns, self.rbd_image, self.rbd_snap, self.rbd_ceph_conf, self.rbd_user_name, self.rbd_cluster_name))
        elif (self.map_type == "mem"):
            cmd = str("ubbdadm map --type mem --devsize %s" % (self.mem_devsize))

        result = process.run(cmd, ignore_status=True, shell=True)
        if result.exit_status:
            self.log.error("map error: %s" % (result))
            if self.always_retry:
                return False
            if self.fail_directly or (result.exit_status not in self.ignore_exit_status):
                self.fail("start device failed, result: %s" % result)
            return False

        self.log.info("map result: %s" % (result))
        ubbd_dev = result.stdout_text.strip()
        if (len(ubbd_dev) == 0):
            self.log.error("stdout of map is none")
            return False

        self.list_and_check(ubbd_dev)
        self.set_dev_timeout(ubbd_dev)
        self.start_fio_process(ubbd_dev)
        self.ubbd_dev_list.append(ubbd_dev)
        self.log.info(self.ubbd_dev_list)
        return True

    def do_unmap(self, dev, force):
        cmd = str("ubbdadm unmap --ubbdid %s" % (self.get_dev_id(dev)))
        if force:
            cmd = str("%s --force" % cmd)
        result = process.run(cmd, ignore_status=True)
        self.log.info("unmap result: %s" % (result))
        if (result.exit_status):
            if self.always_retry:
                return False
            if self.fail_directly or (result.exit_status not in self.ignore_exit_status):
                self.fail("unmap dev failed.")
            return False
        return True

    def start_dev(self):
        while (True):
            if (self.do_map()):
                return

            time.sleep(1)

    def stop_dev(self, dev):
        while (os.path.exists(dev)):
            self.do_unmap(dev, True)
            time.sleep(1)

        self.ubbd_dev_list.remove(dev)
        self.log.info(self.ubbd_dev_list)

    def stop_devs(self):
        self.log.info(self.ubbd_dev_list)
        while (len(self.ubbd_dev_list) != 0):
            self.stop_dev(self.ubbd_dev_list[0])


    def do_config(self, dev):
        cmd = str("ubbdadm config --ubbdid %s --data-pages-reserve-percnt %s" % (self.get_dev_id(dev), self.ubbd_page_reserve))
        result = process.run(cmd, ignore_status=True)
        self.log.info("config result: %s" % (result))
        if (result.exit_status):
            if self.always_retry:
                return False
            if self.fail_directly or (result.exit_status not in self.ignore_exit_status):
                self.fail("config device failed")
            return False
        return True

    def config_dev(self, dev):
        while (True):
            if (self.do_config(dev)):
                return

            time.sleep(1)

    def do_req_stats(self, dev):
        cmd = str("ubbdadm req-stats --ubbdid %s" % (self.get_dev_id(dev)))
        result = process.run(cmd, ignore_status=True)
        self.log.info("req-stats result: %s" % (result))
        if (result.exit_status):
            if self.always_retry:
                return False
            if self.fail_directly or (result.exit_status not in self.ignore_exit_status):
                self.fail("req-stats failed")
            return False
        return True

    def dev_req_stats(self, dev):
        while (True):
            if (self.do_req_stats(dev)):
                return

            time.sleep(1)

    def do_dev_restart(self, dev):
        cmd = str("ubbdadm dev-restart --ubbdid %s --restart-mode queue" % (self.get_dev_id(dev)))
        result = process.run(cmd, ignore_status=True)
        self.log.info("dev-restart result: %s" % (result))
        if (result.exit_status):
            if self.always_retry:
                return False
            if self.fail_directly or (result.exit_status not in self.ignore_exit_status):
                self.fail("dev-restart failed")
            return False
        return True

    def dev_restart(self, dev):
        while (True):
            if (self.do_dev_restart(dev)):
                return

            time.sleep(1)

    def do_ubbd_action(self):
        action = random.randint(1, 5)
        if action == 1:
            self.log.info("map")
            self.start_dev()
        elif action == 2:
            self.log.info("unmap")
            if (len(self.ubbd_dev_list) > 0):
                self.stop_dev(self.ubbd_dev_list[0])
        elif action == 3:
            self.log.info("config")
            if (len(self.ubbd_dev_list) > 0):
                self.config_dev(self.ubbd_dev_list[0])
        elif action == 4:
            self.log.info("req-stats")
            if (len(self.ubbd_dev_list) > 0):
                self.dev_req_stats(self.ubbd_dev_list[0])
        elif action == 5:
            self.log.info("dev-restart")
            if (len(self.ubbd_dev_list) > 0):
                self.dev_restart(self.ubbd_dev_list[0])

    def test(self):
        if (self.map_type == "mem" and self.ubbdd_timeout):
            return

        for i in range(0, self.ubbdadm_action_num):
            self.do_ubbd_action()

    def tearDown(self):
        self.stop_devs()
        self.stop_ubbdd_killer()
