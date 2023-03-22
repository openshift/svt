# Where to clone e2e-benchmarking from
export E2E_BENCHMARKING_REPOSITORY=${E2E_BENCHMARKING_REPOSITORY:-"https://github.com/cloud-bulldozer/e2e-benchmarking"}
export E2E_BENCHMARKING_BRANCH=${E2E_BENCHMARKING_BRANCH:-"master"}
# Common ENVs of custom workload for kube-burner
export WORKLOAD=${WORKLOAD:-"custom"}
export INDEXING=${INDEXING:-"false"}
export METRICS_PROFILE=${METRICS_PROFILE:-"metrics-profiles/metrics.yaml"}
export ALERTS_PROFILE=${ALERTS_PROFILE:-""}
export COMPARISON_CONFIG="clusterVersion.json"
export GEN_CSV=false
