#!/bin/bash

set -ex

ES_USERNAME=${ES_USERNAME}
ES_PASSWORD=${ES_PASSWORD}
export ES_SERVER="https://$ES_USERNAME:$ES_PASSWORD@search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com"

setup(){
    rm -rf e2e-benchmarking
    # Clone the e2e repo
    REPO_URL="https://github.com/cloud-bulldozer/e2e-benchmarking";
    LATEST_TAG=$(curl -s "https://api.github.com/repos/cloud-bulldozer/e2e-benchmarking/releases/latest" | jq -r '.tag_name');
    E2E_VERSION="v2.4.0"
    TAG_OPTION="--branch $(if [ "$E2E_VERSION" == "default" ]; then echo "$LATEST_TAG"; else echo "$E2E_VERSION"; fi)";
    git clone $REPO_URL $TAG_OPTION --depth 1
}

cleanup(){
    rm -rf e2e-benchmarking
}

run_workload(){
    if [[ ! -d e2e-benchmarking/workloads/kube-burner ]]; then
        setup
    fi
    pushd e2e-benchmarking/workloads/kube-burner
    ./run.sh 2>&1 | tee "kube-burner-$(date +%Y%m%d%H%M%S).out"
    popd
    cleanup
}

run_ingress_perf(){
    if [[ ! -d e2e-benchmarking/workloads/ingress-perf ]]; then
        setup
    fi
    pushd e2e-benchmarking/workloads/ingress-perf
    export ES_INDEX="ingress-performance"
    export CONFIG=${CONFIG:-"config/standard.yml"}
    echo "[INFO] Will run ingress-perf with config $CONFIG"
    ./run.sh 2>&1 | tee "/tmp/ingress-perf-$(date +%Y%m%d%H%M%S).out"
    popd
}

run_kube-burner-ocp-wrapper(){
    if [[ ! -d e2e-benchmarking/workloads/kube-burner-ocp-wrapper ]]; then
        setup
    fi
    pushd e2e-benchmarking/workloads/kube-burner-ocp-wrapper
    export GC=${GC:-"false"}
    export PPROF=${PPROF:-"false"}
    export CHURN=${CHURN:-"false"}
    ./run.sh 2>&1 | tee "/tmp/kube-burner-ocp-wrapper-$(date +%Y%m%d%H%M%S).out"
    popd
}

set +ex