#/!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Collect pprof perodically
################################################
 
function collect_pprof_kube_apiserver {
    kubectl proxy&
    sleep 5
    date_time=$(date +%Y%m%d%H%M%S)
    echo "${date_time} collect pprof from kube_apiserver"
    go tool pprof -raw -seconds=60 --output=${date_time}-heap.pprof http://127.0.0.1:8001/debug/pprof/heap
    kill -9 $(ps -ax | grep 'kubectl proxy' | grep -v grep | awk '{print $1}')
}


collect_pprof_kube_apiserver