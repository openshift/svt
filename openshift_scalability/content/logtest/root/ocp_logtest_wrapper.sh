#!/usr/bin/bash

params=`cat /var/lib/svt/ocp_logtest.cfg`
python -u ./ocp_logtest.py ${params}
