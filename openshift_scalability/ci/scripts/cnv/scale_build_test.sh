#!/bin/bash

########################################################################################################################################################
#  This is script to run the scale testing  using cluster loader on OCP.                                                                               #
#  It gets VMs quantity and test vm as parameters.                                                                                                     #
#                                                                                                                                                      #
#  Usage:                                                                                                                                              #
#   ./scale_build_test.sh ${SETUP_PBENCH} ${CONTAINERIZED} ${CLEAR_RESULTS} ${MOVE_RESULTS} ${TOOLING_INVENTORY} ${CNV_TEST_NAME} ${VMS_QUENTITY}      #
#                                                                                                                                                      #
########################################################################################################################################################

SETUP_PBENCH=$1
CONTAINERIZED=$2
CLEAR_RESULTS=$3
MOVE_RESULTS=$4
TOOLING_INVENTORY=$5
TEST_NAME=$6
VMS_QUENTITY=$7
CURRENT_TEST=""
CURRENT_TEST_NS=""

function get_ns_names {
  # returns array with name spaces name according to test name
  base_name="cvn-vm-testing-"$1
  for index in {0..20}
  do
    args+=$base_name"${index}"
    args+=" "
  done
  echo "${args[@]}"
}

if [[ "${TEST_NAME}" == "cirros_test" ]]; then
    CURRENT_TEST='cnv_vm_cirros'
    declare -a CURRENT_TEST_NS=$(get_ns_names "cirros")

elif [[ "${TEST_NAME}" == "fedora_test" ]]; then
    CURRENT_TEST='cnv_vm_fedora'
    declare -a CURRENT_TEST_NS=$(get_ns_names "fedora")
else
   echo "${TEST_NAME} is not a valid option, available options: cirros_test, fedora_test"
   exit 1
fi
echo $CURRENT_TEST_NS


echo " =========================================================================="
echo "     CNV test                                                              "
echo "     Test name: '${CURRENT_TEST}'                                          "
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
chmod +x /root/svt/openshift_scalability/cnv_vm_scale.sh

# update VM quantity
sed -i -e "s/NUMBER_OF_VMS/"${VMS_QUENTITY}"/g"  /root/svt/openshift_scalability/config/golang/"${CURRENT_TEST}".yaml

#pbench-user-benchmark --pbench-post='/usr/local/bin/pbscraper -i $benchmark_results_dir/tools-default -o $benchmark_results_dir; ansible-playbook -vvv -i /root/svt/utils/pbwedge/hosts /root/svt/utils/pbwedge/main.yml -e new_file=$benchmark_results_dir/out.json -e git_test_branch='"deployments_per_ns_$DEPLOYMENTS"'' -- /root/svt/openshift_scalability/deployments_per_ns.sh golang
pbench-user-benchmark  -- /root/svt/openshift_scalability/cnv_vm_scale.sh golang ${CURRENT_TEST}

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
