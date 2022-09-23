source ../custom_workload_env.sh

export WORKLOAD="cluster-density"
export INDEXING=true
export METADATA_COLLECTION=true
export METRICS_PROFILE="metrics-profiles/metrics-aggregated.yaml"
export COMPARISON_CONFIG="clusterVersion.json nodeMasters-max.json nodeAggWorkers.json"
export GEN_CSV=true
