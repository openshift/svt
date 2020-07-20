#!/usr/bin/bash

params=`cat /var/lib/svt/ocp_logtest.cfg`
python2 -u ./ocp_logtest.py ${params}
sleep 1d
