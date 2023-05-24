#!/bin/bash
create_intree_storageclass()
{
  PROJECT_NAME=$1
  CLOUDPROVIDER=`oc get infrastructure cluster -ojsonpath={.status.platform}`
  CLOUDPROVIDER=`echo $CLOUDPROVIDER | tr -s [A-Z] [a-z]`
  case $CLOUDPROVIDER in
      aws) export PROVISIONER=aws-ebs ;;
      gcp) export PROVISIONER=gce-pd ;;
      vsphere) export PROVISIONER=vsphere-volume  ;;
      azure) export PROVISIONER=azure-disk   ;;
      openstack) export PROVISIONER=cinder ;;
      ibmcloud) export PROVISIONER=ibmc-block-bronze ;;
      #alibabacloud) PROVISIONER=kubernetes.io/aws-ebs;;
      *) echo "Unsupported cloud provider, please check"
	      exit 1
	      ;;
  esac
  oc -n $PROJECT_NAME process --ignore-unknown-parameters=true -f in-tree-storageclass.yaml -p PROVISIONER=${PROVISIONER} | oc -n $PROJECT_NAME apply -f -
}

rollback_origin_default_storageclass()
{

  ORIGINAL_DEFAULT_SC=$1
  CLOUDPROVIDER=`oc get infrastructure cluster -ojsonpath={.status.platform}`
  CLOUDPROVIDER=`echo $CLOUDPROVIDER | tr -s [A-Z] [a-z]`
  case $CLOUDPROVIDER in
      aws) export PROVISIONER=aws-ebs ;;
      gcp) export PROVISIONER=gce-pd ;;
      vsphere) export PROVISIONER=vsphere-volume  ;;
      azure) export PROVISIONER=azure-disk   ;;
      openstack) export PROVISIONER=cinder ;;
      ibmcloud) export PROVISIONER=ibmc-block-bronze ;;
      #alibabacloud) PROVISIONER=kubernetes.io/aws-ebs;;
      *) echo "Unsupported cloud provider, please check"
	      exit 1
	      ;;
  esac
  echo "Rollback storage class to original default storage class [$ORIGINAL_DEFAULT_SC] ..."
  oc patch storageclass ${PROVISIONER}-in-tree -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}'

  if [[ -z ${ORIGINAL_DEFAULT_SC} || ${ORIGINAL_DEFAULT_SC}==*in-tree ]];then
      ORIGINAL_DEFAULT_SC=`oc get sc -ojsonpath='{.items[*].metadata.name}' | sed "s/${PROVISIONER}-in-tree//"| awk '{print $NF}'`
  fi
  oc patch storageclass $ORIGINAL_DEFAULT_SC -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
}

pvc_verification()
{
   PROJECT_NAME=$1
   EXPECTED_PVC_NUM=$2
   CSI_NAME=$3

   #Only one type pvc and the pvc is specified type ${CSI_NAME}
   CSI_TYPE_NUM=`oc get pvc -n perfscale-storage --no-headers| awk '{print $6}'| sort|uniq|wc -l`
   CURRENT_PVC_NUM=`oc get pvc -n ${PROJECT_NAME} |grep -i Bound |grep ${CSI_NAME} |wc -l`
   TOTAL_RUNNING_POD_NUM=`oc get pods -n ${PROJECT_NAME} |grep -i Running|wc -l`
   CSI_DRIVER_NAME=`oc get pvc -n ${PROJECT_NAME} |grep -i Bound| awk '{print $6}'| uniq`
   if [[ $CURRENT_PVC_NUM -eq $EXPECTED_PVC_NUM && $TOTAL_RUNNING_POD_NUM -eq $EXPECTED_PVC_NUM && $CSI_TYPE_NUM -eq 1 ]];then
	   echo "All POD and PVC with correct ${CSI_NAME} created and bound in $PROJECT_NAME"
   else
           echo "[ERROR] POD PVC and CSI Driver type isn't as expected, please check ..."
	   echo -e "CURRENT_PVC_NUM is $CURRENT_PVC_NUM\nTOTAL_RUNNING_POD_NUM is $TOTAL_RUNNING_POD_NUM\nCSI_DRIVER_NAME is $CSI_DRIVER_NAME"
	   exit 1
   fi
}

create_project()
{
  PROJECT_NAME=$1
  #Check if the project perf-storage has been created
  oc get ns |grep ${PROJECT_NAME}
  if [ $? -eq 0 ];then
	echo "The project ${PROJECT_NAME} has been created"
  else
      echo "Creating new project ${PROJECT_NAME} for perfscale testing"
      echo "#############################################################"
      oc create ns ${PROJECT_NAME}
      echo
  fi

}

deploy_workload()
{
  PROJECT_NAME=$1
  WORKLOAD_TYPE=$2
  WORKLOAD_NAME=$3
  WORKLOAD_TYPE=`echo $WORKLOAD_TYPE | tr -s [A-Z] [a-z]`
  PVC_NAME=$4
  DEFAULT_REPLICAS=$5

  #Check if the perf-app statefulset has been created
  oc get ${WORKLOAD_TYPE} -n ${PROJECT_NAME} | grep ${WORKLOAD_NAME}
  if [ $? -eq 0 ];then
      echo "The ${WORKLOAD_TYPE} ${WORKLOAD_NAME} has been created in ${PROJECT_NAME}"
  else
      echo "Creating ${WORKLOAD_TYPE} ${WORKLOAD_NAME} in ${PROJECT_NAME}"
      echo "#############################################################"
      if [[ ${WORKLOAD_TYPE} == "deployment" ]];then

          oc -n ${PROJECT_NAME} process --ignore-unknown-parameters=true -f ${WORKLOAD_TYPE}-pvc.yaml -p WORKLOAD_NAME=${WORKLOAD_NAME} -p PVC_NAME=${PVC_NAME} | oc -n ${PROJECT_NAME} apply -f -
          oc -n ${PROJECT_NAME} process --ignore-unknown-parameters=true -f ${WORKLOAD_TYPE}-pod-withpvc.yaml -p WORKLOAD_NAME=${WORKLOAD_NAME} -p PVC_NAME=${PVC_NAME} -p REPLICAS=${DEFAULT_REPLICAS} | oc -n ${PROJECT_NAME} apply -f -

      elif [[ ${WORKLOAD_TYPE} == "statefulset" ]];then

          oc -n ${PROJECT_NAME} process --ignore-unknown-parameters=true -f ${WORKLOAD_TYPE}-pod-withpvc.yaml -p WORKLOAD_NAME=${WORKLOAD_NAME}  -p PVC_NAME=${PVC_NAME} -p REPLICAS=${DEFAULT_REPLICAS} | oc -n ${PROJECT_NAME} apply -f -

      else
	      echo "${WORKLOAD_TYPE} is unsupported workload type, please check"
	      exit 1
      fi
      echo
  fi
}

wait_workload_ready()
{
  PROJECT_NAME=$1
  WORKLOAD_TYPE=$2
  WORKLOAD_NAME=$3
  WORKLOAD_TYPE=`echo $WORKLOAD_TYPE | tr -s [A-Z] [a-z]`
  MAX_RETRY=$4
  
  oc get ns |grep ${PROJECT_NAME}
  if [  $? -ne 0 ];then
	  echo "The project ${PROJECT_NAME} doesn't find ..."
	  exit 1
  fi
  DESIRED_REPLICAS=`oc get ${WORKLOAD_TYPE} ${WORKLOAD_NAME} -n ${PROJECT_NAME} "-o=jsonpath={.status.replicas}"`

  #The status.readyReplicas will show up in statefulset/deployment after 1 minutes later when the pod created
  READY_REPLICAS=`oc get ${WORKLOAD_TYPE} ${WORKLOAD_NAME} -n ${PROJECT_NAME} "-o=jsonpath={.status.readyReplicas}"`
  if [[ -z ${DESIRED_REPLICAS} ]];then
	  echo "No status was detected for ${WORKLOAD_TYPE} ${WORKLOAD_NAME}"
	  exit 1
  fi

 
  INIT_COUNT=1
  while [[ ${INIT_COUNT} -le ${MAX_RETRY} ]]
  do
     echo "Desired replicas for ${WORKLOAD_TYPE} ${WORKLOAD_NAME} is ${DESIRED_REPLICAS}, ready replicas is ${READY_REPLICAS}"
     echo 
     if [[ ${DESIRED_REPLICAS}x == ${READY_REPLICAS}x ]];then
	     echo "The workload ${WORKLOAD_TYPE} ${WORKLOAD_NAME} is ready"
	     break
     else
	 echo "The workload ${WORKLOAD_TYPE} ${WORKLOAD_NAME} isn't ready, re-checking again, retry #${INIT_COUNT}"
         DESIRED_REPLICAS=`oc get ${WORKLOAD_TYPE} ${WORKLOAD_NAME} -n ${PROJECT_NAME} "-o=jsonpath={.status.replicas}"`
         READY_REPLICAS=`oc get ${WORKLOAD_TYPE} ${WORKLOAD_NAME} -n ${PROJECT_NAME} "-o=jsonpath={.status.readyReplicas}"`
     fi
     sleep 10
     if [[ ${INIT_COUNT} -eq ${MAX_RETRY} ]];then
	     rollback_origin_default_storageclass ${ORIGINAL_DEFAULT_SC}
	     echo "Not all pod was created succesfully, max retry times reachout and will exit ..."
	     exit 1
     fi
     INIT_COUNT=$(( $INIT_COUNT + 1 ))
  done
}

scaleup_deployment_withpvc()
{
 DEPLOYMENT_NUM=$1
 DEFAULT_REPLICAS=$2
 if [[ -z $DEPLOYMENT_NUM ]];then
         echo "Please specify the correct replicas number for deployment"
         exit 1
 fi

 DEPLOYMENT_SN=1
 while [[ $DEPLOYMENT_SN -le $DEPLOYMENT_NUM  ]]
 do
    deploy_workload perfscale-storage deployment perf-web-${DEPLOYMENT_SN} pvc-webdata${DEPLOYMENT_SN} ${DEFAULT_REPLICAS}
    DEPLOYMENT_SN=$(( $DEPLOYMENT_SN + 1 ))
 done
}

wait_deployment_ready()
{
 DEPLOYMENT_NUM=$1
 WORKLOAD_CHECKING_RETRY_TIMES=$2
 if [[ -z $DEPLOYMENT_NUM ]];then
         echo "Please specify the correct replicas number for deployment"
         exit 1
 fi

 DEPLOYMENT_SN=1
 while [[ $DEPLOYMENT_SN -le $DEPLOYMENT_NUM  ]]
 do
    echo "Waitting for deployment workload pod is ready after scale up..."
    wait_workload_ready perfscale-storage deployment perf-web-${DEPLOYMENT_SN} ${WORKLOAD_CHECKING_RETRY_TIMES}

    DEPLOYMENT_SN=$(( $DEPLOYMENT_SN + 1 ))
 done
}

