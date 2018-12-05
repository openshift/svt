#!/bin/bash

/usr/bin/ssh-keygen -A
/usr/sbin/sshd -D &
. /etc/profile.d/pbench-agent.sh
mkdir -p /var/lib/pbench-agent/tools-default
cp /root/.ssh/id_rsa /opt/pbench-agent/id_rsa
source /opt/pbench-agent/profile

# Config options
sed -i "/^pbench_results_redirector/c pbench_results_redirector = ${PBENCH_SERVER}" /opt/pbench-agent/config/pbench-agent.cfg
sed -i "/^pbench_web_server/c pbench_web_server = ${PBENCH_SERVER}"  /opt/pbench-agent/config/pbench-agent.cfg
sed -i "/^github_token/c github_token=${SCALE_CI_RESULTS_TOKEN}" /root/svt/utils/pbwedge/hosts

#sed -i "/^ssh_opts/c ssh_opts = -o StrictHostKeyChecking=no -p 2022" /opt/pbench-agent/config/pbench-agent.cfg
#sed -i "/^scp_opts/c scp_opts = -o StrictHostKeyChecking=no -P 2022" /opt/pbench-agent/config/pbench-agent.cfg

# Set ansible ssh port
sed -i "/^#remote_port/c remote_port = 2022" /etc/ansible/ansible.cfg

# Clone svt private repo
if [[ -n "$SVT_PRIVATE_GITHUB_TOKEN" ]]; then
	git clone https://$SVT_PRIVATE_GITHUB_TOKEN@github.com/openshift/svt-private /root/svt-private
fi

# Setup tooling
if [[ $JOB == "tooling" ]]; then
	cd /root/scale-cd-jobs/build-scripts
	source /opt/pbench-agent/profile; ./setup_tooling.sh ${TOOLING_INVENTORY} "${OPENSHIFT_INVENTORY}" ${CONTAINERIZED} ${REGISTER_ALL_NODES}
elif [[ $JOB == "nodevertical" ]]; then
	cd /root/scale-cd-jobs/build-scripts
	source /opt/pbench-agent/profile; ./nodevertical.sh $SETUP_PBENCH $CONTAINERIZED $CLEAR_RESULTS $MOVE_RESULTS $TOOLING_INVENTORY $ENVIRONMENT
elif [[ $JOB == "mastervertical" ]]; then
	cd /root/scale-cd-jobs/build-scripts
	source /opt/pbench-agent/profile; ./mastervert.sh.python $SETUP_PBENCH $CONTAINERIZED $CLEAR_RESULTS $MOVE_RESULTS $TOOLING_INVENTORY $FIRST_RUN_PROJECTS $SECOND_RUN_PROJECTS $THIRD_RUN_PROJECTS $MODE
elif [[ $JOB == "podvertical" ]]; then
	cd /root/scale-cd-jobs/build-scripts
	source /opt/pbench-agent/profile; ./podvertical.sh $SETUP_PBENCH $CONTAINERIZED $CLEAR_RESULTS $MOVE_RESULTS $TOOLING_INVENTORY $PODS $ITERATIONS
elif [[ $JOB == "ns_per_cluster" ]]; then
	cd /root/scale-cd-jobs/build-scripts
	source /opt/pbench-agent/profile; ./cluster_limits_ns.sh.python $SETUP_PBENCH $CONTAINERIZED $CLEAR_RESULTS $MOVE_RESULTS $TOOLING_INVENTORY $FIRST_RUN_PROJECTS $SECOND_RUN_PROJECTS $THIRD_RUN_PROJECTS $MODE
elif [[ $JOB == "deployments_per_ns" ]]; then
        cd /root/scale-cd-jobs/build-scripts
	source /opt/pbench-agent/profile; ./cluster_limits_deployments_per_ns.sh $SETUP_PBENCH $CONTAINERIZED $CLEAR_RESULTS $MOVE_RESULTS $TOOLING_INVENTORY $DEPLOYMENTS
elif [[ $JOB == "networking" ]]; then
	cd /root/svt/networking/synthetic
	source /opt/pbench-agent/profile; ./start-network-test.sh $MODE $SKIP_REGISTER_PBENCH
elif [[ $JOB == "pgbench" ]]; then
	# create template with storage class support
	oc create -f https://raw.githubusercontent.com/ekuric/openshift/master/postgresql/postgresql-persistent-cns.json || true
	if [[ -d "/root/openshift-elko" ]]; then
    		rm -rf /root/openshift-elko
    	fi
	git clone https://github.com/ekuric/openshift.git /root/openshift-elko
    	cd /root/openshift-elko/postgresql
    	chmod +x pgbench_test.sh
    	chmod +x runpgbench.sh
	source /opt/pbench-agent/profile; ./runpgbench.sh $NAMESPACE $TRANSACTIONS $TEMPLATE $VOLUME_CAPACITY $MEMORY_LIMIT $ITERATIONS $MODE $CLIENTS $THREADS $SCALING $STORAGECLASS $PBENCHCONFIG
elif [[ $JOB == "http" ]]; then
	if [[ -d "/root/http-ci-tests" ]]; then
		rm -rf /root/http-ci-tests
	fi	
	git clone https://github.com/jmencak/http-ci-tests.git /root/http-ci-tests
	cd /root/http-ci-tests
	source /opt/pbench-agent/profile; . ./http-test.sh all
elif [[ $JOB == "mongo" ]]; then
	source /opt/pbench-agent/profile; 
elif [[ $JOB == "test" ]]; then
	echo "sleeping forever"
	source /opt/pbench-agent/profile; sleep infinity
elif [[ $JOB == "byo" ]]; then
	echo "Running the script located at $BYO_SCRIPT_PATH"
	if [[ ! -f "$BYO_SCRIPT_PATH" ]]; then
		echo "Looks like $BYO_SCRIPT_PATH doesn't exist, please check"
		exit 1
	fi
	source /opt/pbench-agent/profile; chmod +x $BYO_SCRIPT_PATH; $BYO_SCRIPT_PATH
else
	echo "$JOB does not match any of the supported options, please check"
	exit 1
fi
