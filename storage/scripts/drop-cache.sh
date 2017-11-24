#!/bin/bash


oc get nodes --no-headers | cut -f1 -d" " | while read i; do ssh -n "$i" 'sync ; echo 3 > /proc/sys/vm/drop_caches'; done
