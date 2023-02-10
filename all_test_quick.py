#!/usr/bin/env python3

import sys

from avocado.core.job import Job
from avocado.core.suite import TestSuite

ubbdadmtest_config = {'run.references': ['ubbdadmtest.py:Ubbdadmtest.test'],
          'resolver.references': ['ubbdadmtest.py:Ubbdadmtest.test'],
          'yaml_to_mux.files': ['ubbdadmtest.py.data/ubbdadmtest_quick.yaml'],
          'nrunner.max_parallel_tasks': 1,
          'run.dry_run.enabled': False}

xfstests_config = {'run.references': ['xfstests.py:Xfstests.test'],
        'resolver.references': ['xfstests.py:Xfstests.test'],
          'yaml_to_mux.files': ['xfstests.py.data/xfstests_quick.yaml'],
          'nrunner.max_parallel_tasks': 1,
          'run.dry_run.enabled': False}

fio_config = {'run.references': ['fio.py:Fiotest.test'],
          'resolver.references': ['fio.py:Fiotest.test'],
          'yaml_to_mux.files': ['fio.py.data/fio_quick.yaml'],
          'nrunner.max_parallel_tasks': 1,
          'run.dry_run.enabled': False}

upgradeonline_config = {'run.references': ['upgradeonline.py:Upgradeonlinetest.test'],
          'resolver.references': ['upgradeonline.py:Upgradeonlinetest.test'],
          'yaml_to_mux.files': ['upgradeonline.py.data/upgradeonline_quick.yaml'],
          'nrunner.max_parallel_tasks': 1,
          'run.dry_run.enabled': False}

test_suites = []

test_suites.append(TestSuite.from_config(upgradeonline_config, name='upgradeonline'))
test_suites.append(TestSuite.from_config(ubbdadmtest_config, name='ubbdadmtest'))
test_suites.append(TestSuite.from_config(xfstests_config, name='xfstests'))
test_suites.append(TestSuite.from_config(fio_config, name='fio'))

with Job(test_suites=test_suites) as j:
    sys.exit(j.run())
