# ENVs to overwrite the kube-burner configuration file
export NAME=${NAME:-"bulk-delete"}
export NAMESPACE=${NAMESPACE:-"bulk-delete"}
export JOB_ITERATION=${JOB_ITERATION:=1}
export POD_REPLICAS=0
export IMAGES_STREAM_REPLICAS=20
export BUILDS_REPLICAS=10
export SECRETS_REPLICAS=200
export ROUTES_REPLICAS=10
export GEN_CSV=false