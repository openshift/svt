!/bin/bash

########################################################################################################################################################
#  This is script to run the scale testing  using cluster loader on OCP.                                                                               #
#  It gets VMs quantity and test vm as parameters.                                                                                                     #
#                                                                                                                                                      #
#  Usage:                                                                                                                                              #
#   ./scale_build_test.sh ${SETUP_PBENCH} ${CONTAINERIZED} ${CLEAR_RESULTS} ${MOVE_RESULTS} ${TOOLING_INVENTORY} ${CNV_TEST_NAME} ${VMS_QUENTITY}      #
#                                                                                                                                                      #
########################################################################################################################################################

set -x

TEST_NAME=$1
VMS_QUENTITY=$2
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


# Backup config
cp /root/svt/openshift_scalability/config/golang/"${CURRENT_TEST}".yaml /root/svt/openshift_scalability/config/golang/"${CURRENT_TEST}".bak

# Switch to default ns
oc project default

# Run
export KUBECONFIG=~/.kube/config
cd /root/svt/openshift_scalability
chmod +x /root/svt/openshift_scalability/cnv_vm_scale.sh

# update VM quantity
sed -i -e "s/NUMBER_OF_VMS/"${VMS_QUENTITY}"/g"  /root/svt/openshift_scalability/config/golang/"${CURRENT_TEST}".yaml

/root/svt/openshift_scalability/cnv_vm_scale.sh golang ${CURRENT_TEST}


# Restore config
cp /root/svt/openshift_scalability/config/golang/"${CURRENT_TEST}".bak /root/svt/openshift_scalability/config/golang/"${CURRENT_TEST}".yaml

# Cleanup namespaces
for ns in ${CURRENT_TEST_NS[@]}; do
   oc delete project --wait=true $ns
done
