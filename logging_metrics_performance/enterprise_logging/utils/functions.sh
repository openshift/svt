#!/usr/bin/env bash
#set -x


ERR=1
OK=0

function setup_globals() {
        : '
        Parameters:
        $1 KUBEREPO - kubernetes repo location
        $2 PBENCH_RES - pbench results directory
        '

        # e2es
        export KUBEREPO=${1:-'/opt/kubernetes'}

        # pbench
        export PB_RES=${2:-'/var/lib/pbench-agent'}
	PBENCH_COLLECTION_INTERVAL=60


	# pbench node file
	PBENCH_NODESFILE="pbench_nodes.lst"
	
      	# openshift-ansible
      	export OSEANSIBLE=${3:-'/root/openshift-ansible'}

        # tests
        export TESTDIR=$SCRIPTDIR/test

	# Elasticsearch
 	ES_ADMIN_CA=/etc/elasticsearch/secret/admin-ca
	ES_ADMIN_CERT=/etc/elasticsearch/secret/admin-cert
	ES_ADMIN_KEY=/etc/elasticsearch/secret/admin-key
	ES_URL=https://logging-es:9200

}

function check_required() {
        if [[ -z $TESTNAME ]]; then
                usage
                exit $ERR
        fi

	PB_DIR_LOG=${PB_RES}/$TESTNAME/log
 	export PB_DIR_LOG
	mkdir -p $PB_DIR_LOG
}

function parse_opts() {
        : '
        Accepted parameters::
        [*] are required

        -n <test name> [*]
	-d <test duration in seconds>
        -w <logger pods per node>
	-r <load rate>
	
	-i <pbench collection interval>
	-m <mock test>
        '

	while getopts ":m:n:w:h:d:i:r:" option; do
            case "${option}" in
                n)
                    TESTNAME=${OPTARG}
                    ;;
		r)
                    LOAD_RATE=${OPTARG}
                    ;;
		d)
                    TEST_DURATION=${OPTARG}
                    ;;
                m)
                    MOCK=${OPTARG}
                    RUN_TYPE="Mock testing... ${MOCK} seconds"
                    TESTBIN="sleep ${MOCK}"
                    CMD="$TESTBIN"
                    ;;
		i)
                    PBENCH_COLLECTION_INTERVAL=${OPTARG}
                    ;;
                w)
                    TIMES=${OPTARG}
                    RUN_TYPE="Journalctl logger pods"
                    TESTBIN="export TIMES=$TIMES; export MODE=1; $TESTDIR/manage_pods.sh -r $LOAD_RATE; sleep $TEST_DURATION"
                    CMD="$TESTBIN"
		     
                    ;;
		*)
                    echo -e "Invalid option / usage: ${option}\nExiting."
                    usage
                    exit $ERR
                    ;;

            esac
        done
        shift $((OPTIND-1))

}

function pbench_perftest() {
	PBTOOLS="iostat mpstat pidstat proc-vmstat sar turbostat"
	NODES=("$@")

	# Phase 1 - before
	pre_test_operations "pre_test"
	
	# Register pbench at target remotes 
        for NODE in ${NODES[@]}
        do
		disk_usage "${NODE}" "disk_usage_initial"

                echo -e "\n[*] Registering $PBTOOLS on $NODE"
                for TOOL in $PBTOOLS
                do
			pbench-register-tool --name=$TOOL --remote=$NODE -- --interval=${PBENCH_COLLECTION_INTERVAL}
                done
        done

        echo -e "\n[*] Starting $RUN_TYPE test"
	echo -e "Worker pod(s) per node: $TIMES\nLoad rate: $LOAD_RATE Byte/sec\nTest duration: $TEST_DURATION seconds.\n"
	echo -e "Pbench --interval: ${PBENCH_COLLECTION_INTERVAL}\n"
	sleep 5
        pbench-start-tools -d $PB_RES/$TESTNAME

	# Phase 2 - Run test
        eval ${CMD}

	# Phase 3 - after
	post_test_operations "post_test"
        for NODE in ${NODES[@]}
        do
                disk_usage ${NODE} "disk_usage_final"
        done

	echo -e "\n[*] Stopping $RUN_TYPE"
	export MODE=1; $TESTDIR/manage_pods.sh -k 1

	# Finish up pbench collection
        pbench-stop-tools -d $PB_RES/$TESTNAME &> /dev/null
        pbench-postprocess-tools -d $PB_RES/$TESTNAME

        echo -e "\n[*] Copying pbench results"
        pbench-copy-results --prefix $PB_RES/$TESTNAME
}

function pre_test_operations {
	system_logs ""
        oc_logs "oc/$1"
        es_logs "es/$1"
        es_delete_indices "es/${1}_delete_indices"
        es_get_stats "es/stats/$1"
}

function post_test_operations {
	system_logs ""
        es_get_stats "es/stats/$1"
        es_optimize "es/optimize"
        es_get_stats "es/stats/${1}_optimize"
        oc_logs "oc/$1"
        es_logs "es/$1"
}


#
# Openshift, cluster and Elasticsearch status and metrics gathering
function get_es_pods() {
  oc get pods -l component=es | grep ^logging-es | awk '{print $1}'
}

function disk_usage() {
        local nodename=$1
        local log_dir=${PB_DIR_LOG}/du/${nodename-du}
        local volume_dir=/var/lib/origin/openshift.local.volumes/pods/
        mkdir -p ${log_dir}
        local logfile=${log_dir}/${nodename}_${2}.log

        echo "Collecting $2 on $nodename ..." >&2
        echo $nodename >> $logfile
        echo "find $volume_dir -size +50M -exec ls -lrth" >> $logfile
        echo -e "--------------------------------------------------------\n" >> $logfile
        ssh $nodename "find $volume_dir -size +50M -exec ls -lrth '{}' \; | grep logging-es" >> $logfile
	echo -e "--------------------------------------------------------\n" >> $logfile
        echo "du -h $volume_dir | grep logging-es" >> $logfile
        ssh $nodename "du -h $volume_dir | grep logging-es" >> $logfile
        echo -e "--------------------------------------------------------\n" >> $logfile
}

function es_delete_indices() {
  local log_dir=${PB_DIR_LOG}/${1-es/delete_indices}
  local es_pods=$(get_es_pods)

  echo "Deleting ElasticSearch indices." >&2
  mkdir -p ${log_dir}

  for es_pod in $es_pods
  do
    oc exec $es_pod -- curl -s -k --cert $ES_ADMIN_CERT --key $ES_ADMIN_KEY --cacert $ES_ADMIN_CA \
      -XDELETE "$ES_URL/*" >> ${log_dir}/${es_pod}.log
  done
}

# https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-optimize.html
# The optimize process basically optimizes the index for faster search operations. Also, performs a "flush".
es_optimize() {
  local log_dir=${PB_DIR_LOG}/${1-es}
  local es_pods=$(get_es_pods)

  echo "Optimizing ElasticSearch index." >&2
  mkdir -p ${log_dir}

  for es_pod in $es_pods
  do
    oc exec $es_pod -- curl -s -k --cert $ES_ADMIN_CERT --key $ES_ADMIN_KEY --cacert $ES_ADMIN_CA \
      -XPOST "$ES_URL/_refresh" >> ${log_dir}/${es_pod}-refresh.log
    oc exec $es_pod -- curl -s -k --cert $ES_ADMIN_CERT --key $ES_ADMIN_KEY --cacert $ES_ADMIN_CA \
      -XPOST "$ES_URL/_optimize?only_expunge_deletes=true&flush=true" >> ${log_dir}/${es_pod}-optimize.log
  done
}

es_get_stats() {
  local log_dir=${PB_DIR_LOG}/${1-es}
  local es_pods=$(get_es_pods)

  echo "Saving ElasticSearch stats." >&2
  mkdir -p ${log_dir}

  for es_pod in $es_pods
  do
    oc exec $es_pod -- curl -s -k --cert $ES_ADMIN_CERT --key $ES_ADMIN_KEY --cacert $ES_ADMIN_CA \
      $ES_URL/_stats?pretty >> ${log_dir}/${es_pod}.log
  done
}

es_logs() {
  local log_dir=${PB_DIR_LOG}/${1-es}
  local es_pods=$(get_es_pods)

  echo "Saving ElasticSearch logs." >&2
  mkdir -p ${log_dir}

  test -t 9 && {
    echo "ProgramName: file descriptor 9 already opened, cannot save logs." >&1
    return $ERR
  }

  for es_pod in $es_pods
  do
    mkdir -p ${log_dir}/${es_pod}
    exec 9<<_EOF_
_cluster/health?pretty		_cluster_health
_cluster/state?pretty		_cluster_state
_cluster/pending_tasks?pretty	_cluster_pending_tasks
_nodes?pretty			_nodes
_nodes/stats?pretty		_nodes_stats
_stats?pretty			_stats
_cat/allocation?v		_cat_allocation
_cat/thread_pool?v		_cat_thread_pool
_cat/health?v			_cat_health
_cat/plugins?v			_cat_plugins
_cat/recovery?v			_cat_recovery
_cat/count?v			_cat_count
_cat/shards?v			_cat_shards
_cat/master?v			_cat_master
_cat/nodes?v			_cat_nodes
_cat/indices?v			_cat_indices
_cat/segments?v			_cat_segments
_cat/pending_tasks?v		_cat_pending_tasks
_cat/aliases?v			_cat_aliases
_cat/plugins?v			_cat_plugins
_cat/fielddata?v		_cat_fielddata
_EOF_

    while read -u9 -r api save rest
    do
      echo "# $ES_URL/$api:" >> ${log_dir}/${es_pod}/${save}.log
      oc exec $es_pod -- curl -s -k --cert $ES_ADMIN_CERT --key $ES_ADMIN_KEY --cacert $ES_ADMIN_CA \
        $ES_URL/$api >> ${log_dir}/${es_pod}/${save}.log
    done
  done
}

system_logs() {
  local log_dir=${PB_DIR_LOG}/${1-system}

  echo "Saving system logs." >&2
  mkdir -p ${log_dir}

  grep "journal: Suppressed" /var/log/messages >> ${log_dir}/rate-limiting.log
  grep "messages lost due to rate-limiting" /var/log/messages >> ${log_dir}/rate-limiting.log
}

oc_logs() {
  local log_dir=${PB_DIR_LOG}/${1-oc}

  echo "Saving OpenShift logs." >&2
  mkdir -p ${log_dir}

  oc get nodes -o wide > ${log_dir}/oc_get_nodes.log
  oc get pods -o wide > ${log_dir}/oc_get_pods.log

  for p in $(oc get pods | grep -v ^logging-kibana | tail -n+2 | awk '{print $1}')
  do
    local log_dir_pod=${log_dir}/pods
    mkdir -p ${log_dir_pod}
    oc logs $p > ${log_dir_pod}/oc_logs-${p}.log
    oc describe pod $p > ${log_dir_pod}/oc_describe-${p}.log
  done

  # Kibana needs special handling
  for p in $(oc get pods | grep ^logging-kibana | awk '{print $1}')
  do
    local log_dir_pod=${log_dir}/pods
    mkdir -p ${log_dir_pod}
    oc logs -c kibana $p > ${log_dir_pod}/oc_logs-${p}-kibana.log
    oc logs -c kibana-proxy $p > ${log_dir_pod}/oc_logs-${p}-kibana-proxy.log
    oc describe pod $p > ${log_dir_pod}/oc_describe-${p}.log
   done
}


#
# Logging installer specific
function show_help() {
cat << EOF
    Usage: scriptname.sh [depyer_helper_cfg_file]
    ./enterprise_logging_setup.sh deployer.conf
EOF
}

function _wait() {
        echo -e "\nSleeping for $1 secs..."
        sleep $1
        echo -e "Resuming...\n"
}

function add_roles() {
        oc policy add-role-to-user edit --serviceaccount logging-deployer
        oc policy add-role-to-user daemonset-admin --serviceaccount logging-deployer
        oadm policy add-cluster-role-to-user oauth-editor system:serviceaccount:logging:logging-deployer
        oadm policy add-scc-to-user privileged system:serviceaccount:logging:aggregated-logging-fluentd
        oadm policy add-cluster-role-to-user cluster-reader system:serviceaccount:logging:aggregated-logging-fluentd
}

function pre_clean() {
        # logging-deployer-template and logging-deployer-account-template should
        # already exist under the openshift namespace. Delete them first.
        oc delete project logging &> /dev/null
        for template in 'logging-deployer-template' 'logging-deployer-account-template'
        do
          oc delete template $template -n openshift &> /dev/null
        done
}


#
# Other / misc 
function cleanup() {
        : '
        Cleans up pbench temp files.
        '

        echo -e "\nRemoving tmp files..."
        rm -rf perf-percpu/ &> /dev/null
        rm perf-report.* &> /dev/null

        echo -e "\nKilling running pods..."
        export MODE=1; $TESTDIR/manage_pods.sh -k 1

        echo -e "Done.\n"
        return $?
}

function clean_pbench() {
        echo "[*] Stopping pbench tools..."
        pbench-stop-tools &> /dev/null
        pbench-kill-tools &> /dev/null
        pbench-clear-tools  &> /dev/null
        echo -e "[*] Done.\n"
}

function sig_handler() {
        : '
        User signal handler
        '
	
        echo -e "\nReceived terminate signal. Exiting."
        clean_pbench
        cleanup
        exit $ERR
}

function usage() {
        echo '
        Accepted parameters::
        [*] are required

        -n <test name> [*]
	-d <test duration in seconds>
        -w <logger pods per node>
	-r <load rate>
	
	-i <pbench collection interval>
	-m <mock test>

        Examples:
	 Mock test for 120 seconds
         ./pbench_perftest.sh -n logging_e2e100_01012016 -m 120
	
	 3600 seconds test, 5 worker pods per node logging at 256Bytes/sec
	 ./pbench_perftest.sh -n logging_3600sec_5wppn -d 3600 -r 256 -w 5'
}
