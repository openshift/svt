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

      	# openshift-ansible
      	export OSEANSIBLE=${3:-'/root/openshift-ansible'}

        # tests
        export TESTDIR=$SCRIPTDIR/test
}

function check_required() {
	# TODO: check for oseansible and kubernetes repos
        if [[ -z $TESTNAME ]]; then
                usage
                exit $ERR
        fi
}

function parse_opts() {
        : '
        Accepted parameters::
        [*] are required

        -n <test name>  logSoak1 [*]
        -e <e2e test>   1
        -s <scale>      1
        -j <jctl>       1
        '

        while getopts ":m:n:e:s:j:h:" option; do
            case "${option}" in
                n)
                    TESTNAME=${OPTARG}
                    ;;
                m)
                    MOCK=${OPTARG}
                    RUN_TYPE="Mock testing... ${MOCK} seconds"
                    TESTBIN="sleep ${MOCK}"
                    CMD="$TESTBIN"
                    ;;

                e)
                    E2E=${OPTARG}
                    RUN_TYPE="E2E Logging Soak"
                    TESTBIN=$KUBEREPO/_output/local/bin/linux/amd64/e2e.test
                    CMD="$TESTBIN --repo-root=./ --ginkgo.focus=\"Logging\" --kubeconfig=$HOME/.kube/config --scale=$E2E"

                    ;;
                s)
                    SCALE=${OPTARG}
                    RUN_TYPE="Fluentd scale"
                    TESTBIN="EXPORT FD=$SCALE ; EXPORT ES=10 ; $TESTDIR/fluentd_autoscaler.sh"
                    CMD="$TESTBIN"
                    ;;
                j)
                    JOURNALD=${OPTARG}
                    RUN_TYPE="Journalctl spammer"
                    TESTBIN="$TESTDIR/jdspammer.sh"
                    CMD="$TESTBIN -r $JOURNALD -l 512"
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

function clean_pbench() {
        echo "[*] Stopping pbench tools..."
        pbench-stop-tools &> /dev/null
        pbench-kill-tools &> /dev/null
        pbench-clear-tools  &> /dev/null
        echo -e "[*] Done.\n"

}

function pbench_perftest() {
	echo -e "\n[*] Registering tool set locally"
        pbench-register-tool-set --interval=10

        NODES=("$@")
        for NODE in ${NODES[@]}
        do
                echo -e "\n[*] Registering tool set on $NODE"
                # sudo ssh $NODE 'hostname [podname]'
                pbench-register-tool-set --remote=$NODE --interval=10
        done

        echo -e "\n[*] Starting $RUN_TYPE test"
        pbench-start-tools -d $PB_RES/$TESTNAME

        eval ${CMD}

        echo -e "\n[*] Stopping $RUN_TYPE"
        pbench-stop-tools -d $PB_RES/$TESTNAME &> /dev/null
        pbench-postprocess-tools -d $PB_RES/$TESTNAME

        echo -e "\n[*] Copying pbench results"
	      pbench-copy-results
}

function cleanup() {
        : '
        Cleans up pbench temp files.
        '

        echo 'Removing tmp files...'
        rm -rf perf-percpu/
        rm perf-report.*
        echo -e "Done.\n"
        return $?
}

function sig_handler() {
        : '
        User signal handler
        '

        echo 'Received terminate signal. Exiting.'
        clean_pbench
        cleanup
        exit $ERR
}


function usage() {
        echo '
        Accepted parameters::
        [*] are required

        -n <test name> [*]
        -e <e2e scale>
        -s <scale>
        -j <journalctl>

        Examples:
        ./pbench_perftest.sh -n logging_e2e100_01012016 -e 100'
}
