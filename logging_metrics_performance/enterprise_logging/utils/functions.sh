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

	# tests
	export TESTDIR=$SCRIPTDIR/test

	# pbench
	export PB_RES=${2:-'/var/lib/pbench-agent'}
}

function check_required() {
	if [ ! -f $TESTBIN ]; then
		echo "Please build e2e test first:"
		echo "[1] cd /opt && git clone https://github.com/jayunit100/kubernetes"
		echo "[2] cd $KUBEREPO && sudo hack/build-go.sh test/e2e/e2e.test"
		exit $ERR
	fi

	if [[ -z $TESTNAME ]]; then
		usage
		exit $ERR
	fi
}



function parse_opts() {
	: '
	Accepted parameters::
	[*] are required

	-n <test name> 	logSoak1 [*]
	-e <e2e test>  	1
	-s <scale> 	1
	-j <jctl>	1
	'

	while getopts ":n:e:s:j:h:" option; do
	    case "${option}" in
		n)
		    TESTNAME=${OPTARG}
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
	echo "[*] Done."

}

function pbench_perftest() {
	pbench-register-tool-set --interval=10

	# register pbench on every node
	NODES=("$@")
	for NODE in ${NODES[@]}
	do
		echo "[*] Working on $NODE"
		# sudo ssh $NODE 'hostname [podname]'
		pbench-register-tool-set --remote=$NODE --label="x$NODE" --interval=10
		pbench-register-tool --name=pprof --remote=$NODE -- --osecomponent=node
	done

	echo -e "\n[*] Starting $RUN_TYPE test"
	pbench-start-tools -d $PB_RES/$TEST_NAME

	${CMD}

	echo -e "\n[*] Stopping $RUN_TYPE"
	pbench-stop-tools -d $PB_RES/$TEST_NAME &> /dev/null
	pbench-postprocess-tools -d $PB_RES/$TEST_NAME

	echo -e "\n[*] Copying pbench results"
	pbench-copy-results
}

function cleanup() {
	: '
	TODO
	'

        echo 'Removing tmp files...'
        return $?
}

function sig_handler() {
	: '
	User signal handler
	'

        echo 'Received terminate signal. Exiting.'
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
