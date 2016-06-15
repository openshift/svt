#!/bin/sh

pbench-stop-tools
pbench-kill-tools
pbench-clear-tools

# Intended to run on the master and list nodes here:
#NODES="ose3-master.example.com ose-node1.example.com ose-node2.example.com" passed as first parameter to script
NODES=$1

pbench-register-tool-set --interval=10
pbench-register-tool --name=oc
pbench-register-tool --name=pprof -- --profile=cpu --osecomponent=master

# setup pbench on nodes
for NODE in $NODES
  do
    pbench-register-tool-set --remote=$NODE --interval=10
    pbench-register-tool --name=pprof --remote=$NODE -- --profile=cpu --osecomponent=node
done

pbench-list-tools
