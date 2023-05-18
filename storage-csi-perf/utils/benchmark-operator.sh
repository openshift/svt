#!/usr/bin/env bash

OPERATOR_BRANCH=${OPERATOR_BRANCH:=v1.0.1}
OPERATOR_REPO=${OPERATOR_REPO:-https://github.com/cloud-bulldozer/benchmark-operator.git}

install_cli() {
  run_dir=/tmp/${UUID}
  ripsaw_tmp=${run_dir}/ripsaw-cli
  log "creating python virtual environment at path: ${ripsaw_tmp}"
  mkdir -p ${ripsaw_tmp}
  if [[ ! -f ${ripsaw_tmp}/bin/activate ]]; then
      if [[ "${isBareMetal}" == "true" ]]; then
        python3.8 -m venv ${ripsaw_tmp}
      else
        python -m venv ${ripsaw_tmp}
      fi
  fi
  source ${ripsaw_tmp}/bin/activate
  pip3 install -qq -U "git+${OPERATOR_REPO}@${OPERATOR_BRANCH}#egg=ripsaw-cli&subdirectory=cli"
}

remove_cli() {
  log "deactivating python virtual environment at path: ${ripsaw_tmp}"
  deactivate
  log "cleaning up unique run directory at path: ${run_dir}"
  rm -rf ${run_dir}
}

############################################################################
# Deploys benchmark-operator using ripsaw CLI
# GLOBALS:
#   OPERATOR_REPO
#   OPERATOR_BRANCH
############################################################################
deploy_benchmark_operator() {
  install_cli
  if ! ripsaw operator install --repo=${OPERATOR_REPO} --branch=${OPERATOR_BRANCH}; then
    exit 1
  fi
  deactivate
}

############################################################################
# Removes benchmark-operator using ripsaw CLI
# GLOBALS:
#   OPERATOR_REPO
#   OPERATOR_BRANCH
############################################################################
remove_benchmark_operator() {
  source ${ripsaw_tmp}/bin/activate
  ripsaw operator delete --repo=${OPERATOR_REPO} --branch=${OPERATOR_BRANCH}
  remove_cli
}

############################################################################
# Triggers workload using benchmark CR.
# Arguments:
#   Benchmark CR
############################################################################
run_workload() {
  log "Deploying benchmark"
  local TMPCR=$(mktemp)
  envsubst < $1 > ${TMPCR}
  run_benchmark ${TMPCR} ${TEST_TIMEOUT}
  local rc=$?
  if [[ ${TEST_CLEANUP} == "true" ]]; then
    log "Cleaning up benchmark"
    kubectl delete -f ${TMPCR}
  fi
  return ${rc}
}

############################################################################
# Creates a benchmark, waits for it to complete and index benchmark metadata
# Arguments:
#   Benchmark CR
#   Timeout in seconds
############################################################################
run_benchmark() {
  source ${ripsaw_tmp}/bin/activate
  local start_date=$(date +%s%3N)
  local rc=0
  if ! ripsaw benchmark run -f ${1} -t ${2}; then
    rc=1
    log "Benchmark failed, dumping workload more recent logs"
    local tmp_dir=$(mktemp -d)
    kubectl -n benchmark-operator get pod -l benchmark-uuid=${UUID}
    for pod in $(kubectl -n benchmark-operator get pod -l benchmark-uuid=${UUID} -o custom-columns="name:.metadata.name" --no-headers); do
      pod_log=${tmp_dir}/${pod}.log
      log "Writing pod logs in ${pod_log}"
      kubectl logs -n benchmark-operator --prefix --tail=30 ${pod}
      kubectl logs -n benchmark-operator --prefix --tail=-1 ${pod} >> ${pod_log}
    done
  fi
  local benchmark_name=$(cat ${1} | python -c 'import yaml; import sys; print(yaml.safe_load(sys.stdin.read())["metadata"]["name"])')
  gen_metadata ${benchmark_name} ${start_date} $(date +%s%3N)
  return ${rc}
}
