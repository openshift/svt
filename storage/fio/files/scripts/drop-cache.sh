#!/bin/bash


oc get nodes --no-headers | cut -f1 -d" " | while read i; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -n "$i" 'sync ; echo 3 > /proc/sys/vm/drop_caches'; done
