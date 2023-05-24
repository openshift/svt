#!/bin/bash
. common.sh
. ./utils/common.sh
.  ./utils/compare.sh
run_storage_perf_workload()
{
  WORKLOAD=$1
  TOTAL_WORKLOAD=$2
  WORKLOAD_CHECKING_RETRY_TIMES=$3

  create_project perfscale-storage
  
  echo "Checking if the default storage class exist in the clusters"
  echo "#############################################################"
  oc get sc | grep -i default
  if [[ $? -eq 0 ]];then
	 echo "Default storage class has been found, change original default storage $ORIGINAL_DEFAULT_SC to false"
	 ORIGINAL_DEFAULT_SC=`oc get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'`
	 export ORIGINAL_DEFAULT_SC=${ORIGINAL_DEFAULT_SC}

	 oc patch storageclass ${ORIGINAL_DEFAULT_SC} -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}'

         echo "create storage class ${PROVISIONER}-in-tree ..."
	 create_intree_storageclass ${PROJECT_NAME}
         echo "Change default storage class to ${PROVISIONER}-in-tree ..."
	 oc patch storageclass ${PROVISIONER}-in-tree -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
	      
  else
         echo "create storage class ${PROVISIONER}-in-tree ..."
	 create_intree_storageclass ${PROJECT_NAME}
         echo "Change default storage class to ${PROVISIONER}-in-tree ..."
	 oc patch storageclass ${PROVISIONER}-in-tree -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
  fi


  if [[ $WORKLOAD == "mixed-workload" ]];then

	RESPECTIVE_PEPLICAS=$(( $TOTAL_WORKLOAD / 2 ))
	if [[ $(( $TOTAL_WORKLOAD % 2)) -eq 0 ]];then
             STATEFULSET_RELICAS=$RESPECTIVE_PEPLICAS
             DEPLOYMENT_NUM=$RESPECTIVE_PEPLICAS
        else
	     STATEFULSET_RELICAS=$(( $RESPECTIVE_PEPLICAS + 1 ))
	     DEPLOYMENT_NUM=$RESPECTIVE_PEPLICAS 
	fi

	#Deploy statefulset with replicas=1 by default
	echo "Deploy statefulset workload pod for mixed-workload"
	deploy_workload perfscale-storage statefulset perf-app pvc-appdata 1
        echo "Waitting for statefulset workload pod is ready ..."
        wait_workload_ready perfscale-storage statefulset perf-app ${WORKLOAD_CHECKING_RETRY_TIMES}
        echo
        echo "Scaling up statefulset to replicas ${STATEFULSET_RELICAS}"
	oc scale statefulset perf-app --replicas=${STATEFULSET_RELICAS} -n perfscale-storage

	echo "Wating workload for 10s to update status"
	sleep 10
        wait_workload_ready perfscale-storage statefulset perf-app ${WORKLOAD_CHECKING_RETRY_TIMES}


	#Deploy deployment with replicas=1 by default
	if [[ -z $DEPLOYMENT_REPLICAS ]];then
            DEPLOYMENT_REPLICAS=1
        fi

        echo "Deploy and scaleup deployment workload to replicas ${RESPECTIVE_PEPLICAS}"
	scaleup_deployment_withpvc $DEPLOYMENT_NUM $DEPLOYMENT_REPLICAS
	echo "Wating workload for 10s to update status"
	sleep 10
        wait_deployment_ready $DEPLOYMENT_NUM ${WORKLOAD_CHECKING_RETRY_TIMES}

elif [[ $WORKLOAD == "statefulset" ]];then

	echo "Deploy statefulset for storage-perf testing"
	deploy_workload perfscale-storage statefulset perf-app pvc-appdata 1

        echo "Waitting for statefulset  workload pod is ready ..."
        wait_workload_ready perfscale-storage statefulset perf-app ${WORKLOAD_CHECKING_RETRY_TIMES}

        echo "Scaling up statefulset to replicas ${TOTAL_WORKLOAD} to replicas ${DEPLOYMENT_NUM}"
	oc scale statefulset perf-app --replicas=${TOTAL_WORKLOAD} -n perfscale-storage

	echo "Wating workload for 10s to update status"
	sleep 10
        echo "Waitting for statefulset workload pod is ready after scale up..."
        wait_workload_ready perfscale-storage statefulset perf-app ${WORKLOAD_CHECKING_RETRY_TIMES}

elif [[ $WORKLOAD == "deployment" ]];then

	#Deploy deployment with replicas=1 by default
	if [[ -z $DEPLOYMENT_REPLICAS ]];then
            DEPLOYMENT_REPLICAS=1
        fi

        echo "Deploy and scaleup deployment workload to replicas ${RESPECTIVE_PEPLICAS}"
	scaleup_deployment_withpvc ${TOTAL_WORKLOAD} $DEPLOYMENT_REPLICAS
	echo "Wating workload for 10s to update status"
	sleep 10
        wait_deployment_ready ${TOTAL_WORKLOAD} ${WORKLOAD_CHECKING_RETRY_TIMES}
	echo "Deploy deployment for storage-perf testing"
else
	rollback_origin_default_storageclass ${ORIGINAL_DEFAULT_SC}
	echo "Unsupported workload type : $WORKLOAD"
	exit 1
fi
	rollback_origin_default_storageclass ${ORIGINAL_DEFAULT_SC} 
}

# Cluster information
export CLUSTER_ID=$(oc get clusterversion -o jsonpath='{.items[].spec.clusterID}')
export CLUSTER_NAME=$(oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}')
export OPENSHIFT_VERSION=$(oc version -o json |  jq -r '.openshiftVersion')
KUBERNETES_MAJOR_VERSION=$(oc version -o json |  jq -r '.serverVersion.major')
KUBERNETES_MINOR_VERSION=$(oc version -o json |  jq -r '.serverVersion.minor')
export KUBERNETES_VERSION=${KUBERNETES_MAJOR_VERSION}.${KUBERNETES_MINOR_VERSION}
export CLUSTER_NETWORK_TYPE=$(oc get network.config/cluster -o jsonpath='{.spec.networkType}')
export NETWORK_TYPE=$CLUSTER_NETWORK_TYPE
export PLATFORM_STATUS=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus}')

#Storage CSI Workload Info
export WORKLOAD=${WORKLOAD:-"mixed-workload"}
export TOTAL_WORKLOAD=${TOTAL_WORKLOAD:-400}
export SPECIFY_TIME_DURATION=${SPECIFY_TIME_DURATION:-True}
export WORKLOAD_CHECKING_TIMEOUT=${WORKLOAD_CHECKING_TIMEOUT:-1200}
export WORKLOAD_CHECKING_RETRY_TIMES=$(( $WORKLOAD_CHECKING_TIMEOUT / 10 ))

STARTTIME=`date +%s`
sleep 30s
run_storage_perf_workload ${WORKLOAD} ${TOTAL_WORKLOAD} ${WORKLOAD_CHECKING_RETRY_TIMES}
if [[ $? -ne 0 ]];then
	exit 1
fi

#pvc_verification PROJECT_NAME  TOTAL_WORKLOAD SCI_NAME
pvc_verification perfscale-storage ${TOTAL_WORKLOAD} ${PROVISIONER}-in-tree
if [[ $? -ne 0 ]];then
	exit 1
fi
if [[ ${ORIGINAL_DEFAULT_SC} == *in-tree ]];then
   ORIGINAL_DEFAULT_SC=`oc get sc --no-headers|grep -v -i in-tree |awk '{print $1}'| tail -1`
fi
CSI_PROVIDER=`oc get sc ${ORIGINAL_DEFAULT_SC} -ojsonpath='{.provisioner}'`
echo "Waiting for 60s to make sure storage performance metrics update to database"
sleep 60s
ENDTIME=`date +%s`

export UUID=${UUID:-$(uuidgen)}

./storage-csi-metric.py -c $CSI_PROVIDER -s $STARTTIME -e $ENDTIME -t $SPECIFY_TIME_DURATION 

sleep 30s
run_benchmark_comparison

#exit ${rc}
