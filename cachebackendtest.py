import random
import os
import time
import errno

from avocado import Test
from avocado.utils import process, genio


class CacheBackendtest(Test):


    def setUp(self):
        self.ubbd_dir = self.params.get("UBBD_DIR")
        self.ubbd_tests_dir = self.params.get("UBBD_TESTS_DIR")

        self.ubbd_cache_mode = self.params.get("ubbd_cache_mode")
        self.ubbd_dev_size = self.params.get("ubbd_dev_size")

        self.ubbd_cache_type = self.params.get("ubbd_cache_type")
        self.ubbd_cache_file = self.params.get("ubbd_cache_file")
        self.ubbd_cache_file_size = self.params.get("ubbd_cache_file_size")

        self.ubbd_backing_type = self.params.get("ubbd_backing_type")
        self.ubbd_backing_file = self.params.get("ubbd_backing_file")
        self.ubbd_backing_file_size = self.params.get("ubbd_backing_file_size")

        self.s3_accessid = self.params.get("s3_accessid")
        self.s3_accesskey = self.params.get("s3_accesskey")
        self.s3_hostname = self.params.get("s3_hostname")
        self.s3_port = self.params.get("s3_port")
        self.s3_volume_name = self.params.get("s3_volume_name")
        self.s3_bucket_name = self.params.get("s3_bucket_name")
        self.s3_dev_size = self.params.get("s3_dev_size")

        self.ubbd_data_size = self.params.get("ubbd_data_size")
        self.ubbd_data_size_extra = self.params.get("ubbd_data_size_extra")

        self.ubbd_data_size = self.ubbd_data_size + self.ubbd_data_size_extra

        self.mount_dir = str("%s/cache_test_mount" % (self.teststmpdir))
        self.data_dir = str("%s/data_dir" % (self.teststmpdir))
        try:
            os.mkdir(self.mount_dir)
            os.mkdir(self.data_dir)
        except Exception:
            pass

    def setup_dev(self, init):
        cmd = str("ubbdadm map --type cache --cache-mode %s --devsize %s " % (self.ubbd_cache_mode, self.ubbd_dev_size))

        if (self.ubbd_cache_type == "file"):
            cmd = str("%s --cache-dev-type file --cache-dev-file-filepath %s --cache-dev-devsize %s " % (cmd, self.ubbd_cache_file, self.ubbd_cache_file_size))
            if (init):
                init_cmd = str("dd if=/dev/zero of=%s bs=1M count=100" % self.ubbd_cache_file)
                process.run(init_cmd, shell=True)

        if (self.ubbd_backing_type == "file"):
            cmd = str("%s --backing-dev-type file --backing-dev-file-filepath %s --backing-dev-devsize %s " % (cmd, self.ubbd_backing_file, self.ubbd_backing_file_size))
        elif (self.ubbd_backing_type == "s3"):
            cmd = str("%s --backing-dev-type s3 --backing-dev-s3-accessid %s --backing-dev-s3-accesskey %s --backing-dev-s3-hostname %s --backing-dev-s3-port %s --backing-dev-s3-volume-name %s --backing-dev-devsize %s --backing-dev-s3-bucket-name %s --backing-dev-s3-block-size 4096" % (cmd, self.s3_accessid, self.s3_accesskey, self.s3_hostname, self.s3_port, self.s3_volume_name, self.s3_dev_size, self.s3_bucket_name))

        result = process.run(cmd, ignore_status=True, shell=True)
        if result.exit_status:
            self.fail("setup dev error.")

        self.ubbd_dev = result.stdout_text.strip()
        if (len(self.ubbd_dev) == 0):
            self.fail("ubbd_dev is none")

        if (init):
            cmd = str("mkfs.xfs -f %s" % (self.ubbd_dev))
            process.run(cmd, shell=True)

        cmd = str("mount %s %s" % (self.ubbd_dev, self.mount_dir))
        process.run(cmd, shell=True)

    def write_data(self):
        self.src_path = str("%s/%s" % (self.data_dir, self.ubbd_data_size))
        self.dst_path = str("%s/%s" % (self.mount_dir, self.ubbd_data_size))
        cmd = str("dd if=/dev/urandom of=%s bs=%s count=1; cp %s %s" % (self.src_path, self.ubbd_data_size, self.src_path, self.dst_path))
        process.run(cmd, shell=True)

    def get_dev_id(self, ubbd_dev):
        return str(ubbd_dev.replace("/dev/ubbd", "")).strip()

    def destroy_dev(self, detach):
        cmd = str("umount %s; ubbdadm unmap --ubbdid %s" % (self.ubbd_dev, self.get_dev_id(self.ubbd_dev)))

        if (detach):
            cmd = str("%s --detach" % cmd)

        process.run(cmd, shell=True)

    def check_data(self):
        cmd = str("md5sum %s %s; diff %s %s" % (self.src_path, self.dst_path, self.src_path, self.dst_path))
        process.run(cmd, shell=True)

    def setup_backing(self):
        if (self.ubbd_backing_type == "file"):
            cmd = str("ubbdadm map --type file --devsize %s --file-filepath %s " % (self.ubbd_backing_file_size, self.ubbd_backing_file))
        elif (self.ubbd_backing_type == "s3"):
            cmd = str("ubbdadm map --type s3 --s3-accessid %s --s3-accesskey %s --s3-hostname %s --s3-port %s --s3-volume-name %s --devsize %s --s3-bucket-name %s --s3-block-size 4096" % (self.s3_accessid, self.s3_accesskey, self.s3_hostname, self.s3_port, self.s3_volume_name, self.s3_dev_size, self.s3_bucket_name))

        result = process.run(cmd, shell=True)

        self.ubbd_dev = result.stdout_text.strip()
        if (len(self.ubbd_dev) == 0):
            self.fail("dev is none")

        cmd = str("mount %s %s" % (self.ubbd_dev, self.mount_dir))
        process.run(cmd, shell=True)

    def test(self):
        if (self.setup_dev(init=True)):
            self.fail("failed to map dev.")

        if (self.write_data()):
            self.fail("failed to write data.")

        if (self.destroy_dev(detach=False)):
            self.fail("failed to destroy dev.")

        if (self.setup_dev(init=False)):
            self.fail("failed to setup dev again.")

        if (self.check_data()):
            self.fail("check data failed.")

        if (self.destroy_dev(detach=True)):
            self.fail("failed to destroy dev with detach.")

        if (self.setup_backing()):
            self.fail("failed to setup backing dev.")

        if (self.check_data()):
            self.fail("failed to check data in backing dev.")

        if (self.destroy_dev(detach=False)):
            self.fail("failed to destroy backing dev.")

        if (self.setup_dev(init=False)):
            self.fail("failed to setup dev after detach")

        if (self.check_data()):
            self.fail("failed to check data after detach.")

        if (self.destroy_dev(detach=True)):
            self.fail("failed to destroy dev")

    def tearDown(self):
        self.log.info("into teardown")
