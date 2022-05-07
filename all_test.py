#!/usr/bin/env python3

import sys

from avocado.core.job import Job
from avocado.core.suite import TestSuite

ubbdadmtest_config = {'resolver.references': ['ubbdadmtest.py:Ubbdadmtest.test'],
          'yaml_to_mux.files': ['ubbdadmtest.py.data/ubbdadmtest.yaml'],
          'nrunner.max_parallel_tasks': 1,
          'run.dry_run.enabled': False}

xfstests_config = {'resolver.references': ['xfstests.py:Xfstests.test'],
          'yaml_to_mux.files': ['xfstests.py.data/xfstests.yaml'],
          'nrunner.max_parallel_tasks': 1,
          'run.dry_run.enabled': False}

fio_config = {'resolver.references': ['fio.py:Fiotest.test'],
          'yaml_to_mux.files': ['fio.py.data/fio.yaml'],
          'nrunner.max_parallel_tasks': 1,
          'run.dry_run.enabled': False}

upgradeonline_config = {'resolver.references': ['upgradeonline.py:Upgradeonlinetest.test'],
          'yaml_to_mux.files': ['upgradeonline.py.data/upgradeonline.yaml'],
          'nrunner.max_parallel_tasks': 1,
          'run.dry_run.enabled': False}

with Job(test_suites=[TestSuite.from_config(upgradeonline_config, name='upgradeonline'),
                      TestSuite.from_config(ubbdadmtest_config, name='ubbdadmtest'),
                      TestSuite.from_config(xfstests_config, name='xfstests'),
                      TestSuite.from_config(fio_config, name='fio')]) as j:
    sys.exit(j.run())
