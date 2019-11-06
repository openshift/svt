#!/usr/bin/env python

import nto_test_core_functionality_is_working
import nto_test_custom_tuning
import nto_test_daemon_mode_label_pod
import nto_test_daemon_mode_remove_pod

########################################################################
# Node Tuning Operator Suite
# to run all test related to Node Tuning Operator just run this suite:
# python nto_suite.py
#
# You can also run specific test:
# python nto_test_<test_name>.py
########################################################################

test_results = [
    dict(name='Core functionality is working', result=nto_test_core_functionality_is_working.test()),
    dict(name='Custom tuning is working', result=nto_test_custom_tuning.test()),
    dict(name='Daemon mode - Label pod', result=nto_test_daemon_mode_label_pod.test()),
    dict(name='Daemon mode - Remove pod', result=nto_test_daemon_mode_remove_pod.test())
]

for result in test_results:
    if result['result']:
        print result['name'] + ' : PASSED'
    else:
        print result['name'] + ' : FAILED'
