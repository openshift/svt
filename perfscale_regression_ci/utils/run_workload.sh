#!/bin/bash

set -ex

setup(){
    rm -rf e2e-benchmarking
    git clone --single-branch --branch ${E2E_BENCHMARKING_BRANCH} ${E2E_BENCHMARKING_REPOSITORY}
}

cleanup(){
    rm -rf e2e-benchmarking
}

run_workload(){
    if [[ ! -d e2e-benchmarking/workloads/kube-burner ]]; then
        setup
    fi
    cd e2e-benchmarking/workloads/kube-burner
    ./run.sh |& tee "kube-burner-$(date +%Y%m%d%H%M%S).out"
    cd ../../.. #prepare for cleanup
    cleanup
}

set +ex
