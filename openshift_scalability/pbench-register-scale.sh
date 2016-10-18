#!/bin/sh

pbench-stop-tools
pbench-kill-tools
pbench-clear-tools

# Intended to run on the master and list nodes here:
#NODES="ose3-master.example.com ose-node1.example.com ose-node2.example.com" passed as first parameter to script
NODES=$*

pbench-register-tool --name=sar -- --interval=10
pbench-register-tool --name=iostat -- --interval=10
pbench-register-tool --name=pidstat -- --interval=10
pbench-register-tool --name=oc
pbench-register-tool --name=pprof -- --osecomponent=master --interval=60

# setup pbench on nodes
for NODE in $NODES
  do
    pbench-register-tool --name=sar --remote=$NODE -- --interval=10
    pbench-register-tool --name=iostat --remote=$NODE -- --interval=10
    pbench-register-tool --name=pidstat --remote=$NODE -- --interval=10
    pbench-register-tool --name=pprof --remote=$NODE -- --osecomponent=node --interval=60
done

pbench-list-tools
