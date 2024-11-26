#!/bin/bash

if ! command -v oc &>/dev/null; then
    echo "Error: 'oc' command not found. Please install OpenShift CLI."
    exit 1
fi

timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
output_dir="./resource_logs"
mkdir -p "$output_dir"

api_resources=$(oc api-resources --namespaced=true --verbs=list -o name)

fetch_resources() {
    local resource=$1
    local log_file="$output_dir/${resource}_${timestamp}.log"

    echo "Fetching resource: $resource"
    oc get "$resource" --all-namespaces -o wide > "$log_file" 2>&1 || echo "No resources found for $resource" > "$log_file"
    echo "Results for $resource saved to: $log_file"
}

fetch_api_resources() {
    local resource=$1
    local log_file="$output_dir/${resource}_${timestamp}.log"
    
    echo "Fetching API resources..."
    oc get "$resource" --all-namespaces -o wide > "$log_file" 2>&1 || echo "No resources found for $resource" > "$log_file"
    echo "API resources saved to: $log_file"
}

resource_types=("pods" "services" "deployments" "replicasets" "statefulsets" "daemonsets" "configmaps" "secrets" "jobs" "cronjobs" "persistentvolumes" "persistentvolumeclaims" "routes" "replicationcontrollers" "namespaces" "serviceaccounts" "endpoints" "networkpolicies" "ingresses" "deployments.apps" "statefulsets.apps" "replicasets.apps" "pods.apps" "replicationcontrollers.apps" "replicationcontrollers.extensions")

for resource in "${resource_types[@]}"; do
    fetch_resources "$resource"
done

for resource in $api_resources; do
    fetch_api_resources "$resource"
done

echo "Resource listing completed. Results saved to $output_dir."
