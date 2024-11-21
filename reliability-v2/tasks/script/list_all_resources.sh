#!/bin/bash

# Check if `oc` CLI is available
if ! command -v oc &> /dev/null; then
    echo "Error: 'oc' CLI not found. Install OpenShift CLI and login first."
    exit 1
fi

# Regular expression pattern for parsing namespace and value
ns_match='^\(\S+\)\s+(.*)$'

# Function to execute an `oc` command
run() {
    local cmd=$1
    local config=$2
    if [[ -n "$config" ]]; then
        cmd="KUBECONFIG=${config} ${cmd}"
    fi
    result=$(eval "$cmd" 2>&1)
    echo "$result"
}

# Function to get namespace parameter
get_namespace_param() {
    local namespace=$1
    if [[ -z "$namespace" ]]; then
        echo ""
    elif [[ "$namespace" == "all-namespaces" ]]; then
        echo " --all-namespaces"
    else
        echo " -n $namespace"
    fi
}

# Function to retrieve all items of a specific type within a namespace
get_all() {
    local type=$1
    local namespace=$2
    local namespace_param=$(get_namespace_param "$namespace")
    run "oc get --ignore-not-found --no-headers ${type}${namespace_param}"
}

# Function to get a list of all CRDs with specified scope
get_crd_list() {
    local scope=$1
    local scope_flag=""
    if [[ "$scope" != "all" ]]; then
        scope_flag=" | grep -i $scope"
    fi
    run "oc get crd --no-headers -o=custom-columns=NAME:.metadata.name,SCOPE:.spec.scope ${scope_flag}"
}

# Function to retrieve all API resources by scope
get_all_api_resources() {
    local scope=$1
    local scope_flag=""
    if [[ "$scope" == "namespaced" ]]; then
        scope_flag="--namespaced=true"
    elif [[ "$scope" == "cluster" ]]; then
        scope_flag="--namespaced=false"
    fi
    run "oc api-resources --verbs=list -o name ${scope_flag}"
}

# Function to retrieve and store all items of specified types
get_all_items() {
    local all_types=("$@")
    local namespace=${NAMESPACE:-""}
    type_items=()
    for this_type in "${all_types[@]}"; do
        result=()
        start_time=$(date +%s)
        # Exclude certain types, similar to a blacklist
        if [[ "$this_type" != "packagemanifests.packages.operators.coreos.com" ]]; then
            result=$(get_all "$this_type" "$namespace")
        fi
        elapsed_time=$(($(date +%s) - start_time))
        if [[ "$VERBOSE" == true ]]; then
            echo "$this_type: ${elapsed_time}s"
        fi
        if [[ -n "$result" ]]; then
            for this_result in $result; do
                if [[ "$this_result" =~ $ns_match ]]; then
                    type_items+=("${BASH_REMATCH[1]}: ${BASH_REMATCH[2]}")
                else
                    type_items+=("$namespace: $this_result")
                fi
            done
        fi
    done
    echo -e "${type_items[@]}"
}

# Function to print items based on the output format
print_items() {
    local all_items=("$@")
    local output=${OUTPUT:-"list"}
    for this_type in "${all_items[@]}"; do
        if [[ "$output" == "list" ]]; then
            echo -e "\n\n==============="
            echo "TYPE: $this_type"
            echo -e "${all_items[$this_type]}"
            echo -e "\n\n==============="
        elif [[ "$output" == "ns-count" ]]; then
            declare -A ns_count
            for item in ${all_items[$this_type]}; do
                ns="${item%%:*}"
                ((ns_count["$ns"]++))
            done
            echo -e "\n\n==============="
            echo "TYPE: $this_type"
            for ns in "${!ns_count[@]}"; do
                echo -e "\t$ns: ${ns_count[$ns]}"
                echo -e "\n\n==============="
            done
        else
            count=0
            echo -e "\n\n==============="
            echo "TYPE: $this_type"
            for item in ${all_items[$this_type]}; do
                echo "$item"
                ((count++))
            done
            echo "$this_type Count: $count"
            echo -e "\n\n==============="
        fi


    done
}

# Parsing command-line options
while getopts "n:t:cs:vo:" opt; do
    case $opt in
        n) NAMESPACE=$OPTARG ;;
        t) TYPE=$OPTARG ;;
        c) CRD=true ;;
        s) SCOPE=$OPTARG ;;
        v) VERBOSE=true ;;
        o) OUTPUT=$OPTARG ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    esac
done

# Determine types of resources to retrieve
declare -a type_list
if [[ "$CRD" == true ]]; then
    crd_type_result=$(get_crd_list "${SCOPE:-all}")
    for crd_type in $crd_type_result; do
        type_list+=("$(echo $crd_type | awk '{print $1}')")
    done
else
    if [[ "$TYPE" == "all" ]]; then
        type_list+=($(get_all_api_resources "${SCOPE:-all}"))
    else
        type_list+=("$TYPE")
    fi
fi

# Retrieve and print items based on selected options
items=$(get_all_items "${type_list[@]}")
print_items "$items"
