#!/usr/bin/env bash
#
# Handles benchmark-comparison execution

source common.sh

get_network_type() {
if [[ $NETWORK_TYPE == "OVNKubernetes" ]]; then
  network_ns=openshift-ovn-kubernetes
else
  network_ns=openshift-sdn
fi
echo $network_ns
}

check_metric_to_modify() {
  export div_by=1
  declare file_content=$( cat "${1}" )
  if [[ $file_content =~ "memory" ]]; then
   export div_by=1048576
  fi
  if [[ $file_content =~ "latency" ]]; then
    export div_by=1000
  fi
  if [[ $file_content =~ "byte" ]]; then
    export div_by=1000000
  fi
}

run_benchmark_comparison() {
  log "benchmark"
  compare_result=0
  if [[ -n ${ES_SERVER} ]] && [[ -n ${COMPARISON_CONFIG} ]]; then

    log "Installing touchstone"
    install_touchstone
    network_ns=openshift-ovn-kubernetes
    get_network_type
    export TOUCHSTONE_NAMESPACE=${TOUCHSTONE_NAMESPACE:-"$network_ns"}
    res_output_dir="/tmp/${WORKLOAD}-${UUID}"
    mkdir -p ${res_output_dir}
    export COMPARISON_OUTPUT=${PWD}/${WORKLOAD}-${UUID}.csv
    final_csv=${res_output_dir}/${UUID}.csv
    echo "final csv $final_csv"
    if [[ -z $CONFIG_LOC ]]; then
      #git clone https://github.com/cloud-bulldozer/benchmark-comparison.git
      git clone https://github.com/liqcui/benchmark-comparison.git
    fi
    for config in ${COMPARISON_CONFIG}
    do
      if [[ -z $CONFIG_LOC ]]; then
        config_loc=benchmark-comparison/config/${config}
      else
        config_loc=$CONFIG_LOC/${config}
      fi
      echo "config ${config_loc}"
      check_metric_to_modify $config_loc
      COMPARISON_FILE="${res_output_dir}/${config}"
      envsubst < $config_loc > $COMPARISON_FILE
      echo "comparison output"
      if [[ -n ${ES_SERVER_BASELINE} ]] && [[ -n ${BASELINE_UUID} ]]; then
        log "Comparing with baseline"
        if ! compare "${ES_SERVER_BASELINE} ${ES_SERVER}" "${BASELINE_UUID} ${UUID}" "${COMPARISON_FILE}" "${GEN_CSV}"; then
          compare_result=$((${compare_result} + 1))
          log "Comparing with baseline for config file $config failed"
        fi
      else
        log "Querying results"
        compare ${ES_SERVER} ${UUID} "${COMPARISON_FILE}" "${GEN_CSV}"
      fi
      log "python csv modifier"
      python $(dirname $(realpath ${BASH_SOURCE[0]}))/csv_modifier.py -c ${COMPARISON_OUTPUT} -o ${final_csv}
    done
    if [[ -n ${GSHEET_KEY_LOCATION} ]] && [[ ${GEN_CSV} == true ]] ; then
      gen_spreadsheet ${WORKLOAD} ${final_csv} ${EMAIL_ID_FOR_RESULTS_SHEET} ${GSHEET_KEY_LOCATION}
    fi
    log "Removing touchstone"
    remove_touchstone
  fi
  if [[ ${compare_result} -gt 0 ]]; then
    return 1
  fi
}

install_touchstone() {
  touchstone_tmp=$(mktemp -d)
  python3 -m venv ${touchstone_tmp}
  source ${touchstone_tmp}/bin/activate
  pip3 install -qq git+https://github.com/cloud-bulldozer/benchmark-comparison.git
}

remove_touchstone() {
  deactivate
  rm -rf "${touchstone_tmp}"
}

##############################################################################
# Run benchmark-comparison to compare two different datasets
# Arguments:
#   Dataset URL, in case of passing more than one, they must be quoted.
#   Dataset UUIDs, in case of passing more than one, they must be quoted.
#   Benchmark-comparison configuration file path.
#   Generate csv and write output to COMPARISON_OUTPUT, boolean.
# Globals
#   TOLERANCY_RULES Tolerancy config file path. Optional
#   COMPARISON_ALIASES Benchmark-comparison aliases. Optional
#   COMPARISON_OUTPUT Benchmark-comparison output file. Optional
##############################################################################
compare() { 
  cmd="touchstone_compare --database elasticsearch -url ${1} -u ${2} --config ${3}"
  if [[ ( -n ${TOLERANCY_RULES} ) && ( ${#2} > 40 ) ]]; then
    cmd+=" --tolerancy-rules ${TOLERANCY_RULES}"
  fi
  if [[ -n ${COMPARISON_ALIASES} ]]; then
    cmd+=" --alias ${COMPARISON_ALIASES}"
  fi
  if [[ ${4} == true ]] && [[ -n ${COMPARISON_OUTPUT} ]]; then
    cmd+=" -o csv --output-file ${COMPARISON_OUTPUT}"
  fi
  if [[ -n ${COMPARISON_RC} ]]; then
    cmd+=" --rc ${COMPARISON_RC}"
  fi
  log "Running: ${cmd}"
  ${cmd}
  result=$?
  log "comare result: ${result}"
  return ${result}
}

