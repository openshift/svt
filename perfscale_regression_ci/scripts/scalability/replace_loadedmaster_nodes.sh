#/!/bin/bash
##################################################################################################
## Auth=mbhalodi@redhat.com
## Desription: Script for resizing master nodes with larger master nodes
## Polarion test case: OCP-40556 - Replace loaded control plane nodes with larger instances
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-40556
## Customer related: https://access.redhat.com/support/cases/#/case/02864921
## Pre-requisites: 
### Cluster with 3 m5.4xlarge master nodes and 30 m5.xlarge worker cluster on AWS, or equivalent size of these profiles:
#### AWS: IPI-on-AWS-OVN
#### GCP: IPI-on-GCP-OVN
#### Azure: IPI-on-Azure-OVN
#### Alicloud: IPI-on-AlibabacloudOVN
## kube-burner config: 
### e2e-benchmarking/workloads/kube-burner/workloads/cluster-density/cluster-density.yml
## Parameters: Cloud provider, number of replicas and number of JOB_ITERATIONS
###################################################################################################

source ./replace_loadedmaster_nodes_env.sh
source ../common.sh
source ../../utils/run_workload.sh

# If parameters is set from upstream ci, overwrite params
echo "Upstream PARAMETERS set to $PARAMETERS"
export params=(${PARAMETERS:-aws 3 120})
echo "params is $params"

export CLOUD=${params[0]:-"aws"}
export REPLICAS=${params[1]:-"3"}
export JOB_ITERATIONS=${params[2]:-"120"}

echo "Testing with $CLOUD $REPLICAS $JOB_ITERATIONS"

# Install dittybopper to check resource usage
install_dittybopper

if [ $? -eq 0 ]; 
then
    # Cluster health check prior to testing
    python -c "import utils.ocp_utils as ocp_utils; ocp_utils.cluster_health_check()"
    echo "Run workload on current master nodes machineset."
    run_kube-burner-ocp-wrapper
    sleep 180
    echo "Deploy new machineset and scale down one machine at a time from existing machinesets." 
    cd ./replace_nodes/clouds
    . ./${CLOUD}.sh
    cd ../..
    python ./replace_master_nodes.py ${CLOUD} ${REPLICAS} ${OPENSHIFT_MASTER_NODE_INSTANCE_TYPE}
    echo "Existing machines scaled down and new nodes are up."
    sleep 180 
    python -c "import utils.ocp_utils as ocp_utils; ocp_utils.cluster_health_check()"
    echo "Cleanup existing workload namespaces."
    delete_project_by_label kube-burner-job=$WORKLOAD
    sleep 180
    python -c "import utils.ocp_utils as ocp_utils; ocp_utils.cluster_health_check()"
    echo "Rerun workload on new machineset."
    run_kube-burner-ocp-wrapper
    sleep 180
    python -c "import utils.ocp_utils as ocp_utils; ocp_utils.cluster_health_check()"
    echo "Test complete!"
    echo "Verify test results as defined in Polarion test case."
    exit 0
else
    echo "Failed to install dittybopper."
    exit 1
fi
