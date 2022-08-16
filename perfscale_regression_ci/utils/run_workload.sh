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
    setup
    cd e2e-benchmarking/workloads/kube-burner
    ./run.sh
    cleanup
}
