#!/bin/bash

####################################################################################
#  This is script to run the scale testing  using cluster loader on OCP lab.       #
#                                                                                  #
#   - Set VMs quantity                                                             #
#   - Select scale test by name                                                    #
####################################################################################

SETUP_PBENCH=$1
CONTAINERIZED=$2
CLEAR_RESULTS=$3
MOVE_RESULTS=$4
TOOLING_INVENTORY=$5
TEST_NAME=$6
VMS_QUENTITY=$7
CURRENT_TEST=""
CURRENT_TEST_SCRIPT=""
CURRENT_TEST_NS=""

# TODO: Set namespace with loop according to number of vms
if [[ "${TEST_NAME}" == "cirros_test" ]]; then
    CURRENT_TEST='cnv_vm_cirros'
    declare -a CURRENT_TEST_NS=('cvn-vm-testing-cirros0' 'cvn-vm-testing-cirros1' 'cvn-vm-testing-cirros2' 'cvn-vm-testing-cirros3')
elif [[ "${TEST_NAME}" == "fedora_test" ]]; then
    CURRENT_TEST='cnv_vm_fedora'
    declare -a CURRENT_TEST_NS=('cvn-vm-testing-fedora0' 'cvn-vm-testing-fedora1' 'cvn-vm-testing-fedora2' 'cvn-vm-testing-fedora3')
else
   echo "Wrong test name"
   exit 1
fi

## Set script name
CURRENT_TEST_SCRIPT="${CURRENT_TEST}"'.sh'

echo " =========================================================================="
echo "     CNV test                                                              "
echo "     Test name: '${CURRENT_TEST}'                                          "
echo "     Test script: '${CURRENT_TEST_SCRIPT}'                                 "
echo "     VM namespace: '${CURRENT_TEST_NS}'                                    "
echo "     Test # of VMs: '${VMS_QUENTITY}'                                      "
echo " =========================================================================="


## Setup pbench
if [[ "${CONTAINERIZED}" != "true" ]] && [[ "${SETUP_PBENCH}" == "true" ]]; then
	set -e
	# register tools
	echo "Running pbench ansible"
    	echo "----------------------------------------------------------"
        if [[ -d "/root/pbench" ]]; then
        	rm -rf /root/pbench
        fi
    	git clone https://github.com/distributed-system-analysis/pbench.git /root/pbench
    	cd /root/pbench/contrib/ansible/openshift/
    	pbench-clear-tools
   	ansible-playbook -vv -i ${TOOLING_INVENTORY} pbench_register.yml
    	echo "Finshed registering tools, labeling nodes"
    	echo "----------------------------------------------------------"
    	echo "List of tools registered:"
    	echo "----------------------------------------------------------"
    	pbench-list-tools
    	echo "----------------------------------------------------------"
elif [[ "${CONTAINERIZED}" == "true" ]] && [[ "${SETUP_PBENCH}" == "true" ]]; then
	# check if the jump node has pbench-controller image
    	docker images | grep -w "pbench-controller"
    	if [[ $? != 0 ]]; then
    		docker pull ravielluri/image:controller
        	docker tag ravielluri/image:controller pbench-controller:latest
    	fi
else
    	echo "Not setting up pbench"
fi

# clear results
if [[ "${CLEAR_RESULTS}" == "true" ]]; then
	pbench-clear-results
fi

# Backup config
cp /root/svt/openshift_scalability/config/golang/"${CURRENT_TEST}".yaml /root/svt/openshift_scalability/config/golang/"${CURRENT_TEST}".bak

# Switch to default ns
oc project default

# Run
export KUBECONFIG
cd /root/svt/openshift_scalability
chmod +x /root/svt/openshift_scalability/"${CURRENT_TEST_SCRIPT}"

# update VM quantity
sed -i -e "s/NUMBER_OF_VMS/"${VMS_QUENTITY}"/g"  ~/git/svt/openshift_scalability/config/golang/"${CURRENT_TEST}".yaml

#pbench-user-benchmark --pbench-post='/usr/local/bin/pbscraper -i $benchmark_results_dir/tools-default -o $benchmark_results_dir; ansible-playbook -vvv -i /root/svt/utils/pbwedge/hosts /root/svt/utils/pbwedge/main.yml -e new_file=$benchmark_results_dir/out.json -e git_test_branch='"deployments_per_ns_$DEPLOYMENTS"'' -- /root/svt/openshift_scalability/deployments_per_ns.sh golang
pbench-user-benchmark  -- /root/svt/openshift_scalability/"${CURRENT_TEST_SCRIPT}" golang

# Move results
if [[ "${MOVE_RESULTS}" == "true" ]]; then
	pbench-move-results --prefix=CVN_Scale_test_"${VMS_QUENTITY}"_"${CURRENT_TEST}"
fi

# Restore config
cp /root/svt/openshift_scalability/config/golang/"${CURRENT_TEST}".bak /root/svt/openshift_scalability/config/golang/"${CURRENT_TEST}".yaml

# Cleanup namespaces
for ns in ${CURRENT_TEST_NS[@]}; do
   oc delete project --wait=true $ns
done

