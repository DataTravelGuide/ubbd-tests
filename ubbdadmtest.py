import random
import os
import time

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

        os.chdir(self.ubbd_dir)
        if self.ubbdd_timeout:
            self.start_ubbdd_killer()

    def start_ubbdd_killer(self):
        cmd = str("bash %s/utils/start_ubbdd_killer.sh %s" % (self.ubbd_tests_dir, self.ubbdd_timeout))
        self.proc = process.get_sub_process_klass(cmd)(cmd)
        pid = self.proc.start()
        self.log.info("ubbdd killer started: pid: %s, %s", pid, self.proc)

    def stop_ubbdd_killer(self):
        if not self.proc:
            return

        process.kill_process_tree(self.proc.get_pid())
        self.log.info("ubbdd killer stopped")

    def start_fio(self, ubbd_dev):
        cmd = str("fio --name test --rw randrw --bs %s --ioengine libaio --filename %s --numjobs 16 --iodepth 128 --eta-newline 1 " % (self.fio_block_size, ubbd_dev))
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
        cmd = str("%s/ubbdadm/ubbdadm --command list" % (self.ubbd_dir))
        result = process.run(cmd, ignore_status=True)
        if result.exit_status:
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

            if self.ubbdd_timeout is not 0:
                self.fail("list and check failed")
            time.sleep(1)

    def do_map(self):
        result = process.run("%s/ubbdadm/ubbdadm --command map --type file --filepath %s --devsize %s" % (self.ubbd_dir, self.ubbd_backend_file, self.ubbd_backend_file_size), ignore_status=True, shell=True)
        if result.exit_status:
            self.log.error("map error: %s" % (result))
            return False

        self.log.info("map result: %s" % (result))
        ubbd_dev = result.stdout_text.strip()
        if (len(ubbd_dev) == 0):
            self.log.error("stdout of map is none")
            return False
        self.list_and_check(ubbd_dev)
        self.set_dev_timeout(ubbd_dev)
        self.start_fio(ubbd_dev)
        self.ubbd_dev_list.append(ubbd_dev)
        self.log.info(self.ubbd_dev_list)
        return True

    def do_unmap(self, dev, force):
        cmd = str("%s/ubbdadm/ubbdadm --command unmap --ubbdid %s" % (self.ubbd_dir, self.get_dev_id(dev)))
        if force:
            cmd = str("%s --force" % cmd)
        result = process.run(cmd, ignore_status=True)
        self.log.info("unmap result: %s" % (result))
        return (result.exit_status == 0)

    def start_dev(self):
        while (True):
            if (self.do_map()):
                return

            if self.ubbdd_timeout is not 0:
                self.fail("start device failed")
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
        cmd = str("%s/ubbdadm/ubbdadm --command config --ubbdid %s --data-pages-reserve %s" % (self.ubbd_dir, self.get_dev_id(dev), self.ubbd_page_reserve))
        result = process.run(cmd, ignore_status=True)
        self.log.info("config result: %s" % (result))
        return (result.exit_status == 0)

    def config_dev(self, dev):
        while (True):
            if (self.do_config(dev)):
                return

            if self.ubbdd_timeout is not 0:
                self.fail("config device failed")
            time.sleep(1)

    def do_req_stats(self, dev):
        cmd = str("%s/ubbdadm/ubbdadm --command req-stats --ubbdid %s" % (self.ubbd_dir, self.get_dev_id(dev)))
        result = process.run(cmd, ignore_status=True)
        self.log.info("req-stats result: %s" % (result))
        return (result.exit_status == 0)

    def dev_req_stats(self, dev):
        while (True):
            if (self.do_req_stats(dev)):
                return

            if self.ubbdd_timeout is not 0:
                self.fail("req-stats failed")
            time.sleep(1)

    def do_dev_restart(self, dev):
        cmd = str("%s/ubbdadm/ubbdadm --command dev-restart --ubbdid %s --restart-mode queue" % (self.ubbd_dir, self.get_dev_id(dev)))
        result = process.run(cmd, ignore_status=True)
        self.log.info("dev-restart result: %s" % (result))
        return (result.exit_status == 0)

    def dev_restart(self, dev):
        while (True):
            if (self.do_dev_restart(dev)):
                return

            if self.ubbdd_timeout is not 0:
                self.fail("dev-restart failed")
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
        for i in range(0, self.ubbdadm_action_num):
            self.do_ubbd_action()

    def tearDown(self):
        self.stop_devs()
        self.stop_ubbdd_killer()
