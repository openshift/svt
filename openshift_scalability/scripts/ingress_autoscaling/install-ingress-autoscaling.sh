#/!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Script to install ingress autoscaling
## 4.12 Feature: https://issues.redhat.com/browse/NE-361
## $1 MAXREPLICACOUNT
## Before running this script 
## From web console
## 1. Operators -> OperatorHub
## 2. Input keda in the filter and select 'Custom Metrics Autoscaler'.
## 3. Click Install, in the opened page, click Install.
## 4. Operators ->'Installed Operators', find 'Custom Metrics Autoscaler'.
## 5. On 'All instances' tab, click "Create new" and select 'KedaController', click 'Create'.
################################################
set -e

if [[ $(uname -a) =~ "Darwin" ]]; then 
    os=mac
else
    os=linux
fi

if [[ -z $1 ]]; then
    echo "[ERROR] please provide MAXREPLICACOUNT as parameter, e.g. 1,2,omit"
    exit 1
fi
keda_pod=$(oc get po -n openshift-keda | grep Running -c)
if [[ $keda_pod -ne 3 ]]; then
    echo "[ERROR] please make sure KedaController is successfully installed."
    exit 1
fi
echo "[INFO ]====Installing Ingresss Autoscaling===="

echo "[INFO] Creating project openshift-ingress-operator"
oc project openshift-ingress-operator

echo "[INFO] Applying ConfigMap cluster-monitoring-config"
oc apply -f content/cluster-monitoring-config.yaml

echo "[INFO] Creating serviceaccount thanos"
oc create serviceaccount thanos && oc describe serviceaccount thanos

echo "[INFO ]Getting thanos-token secret"
secret=$(oc get secret | grep thanos-token | head -n 1 | awk '{ print $1 }')

echo "[INFO] Appling template keda-trigger-auth-prometheus"
cp content/keda-trigger-auth-prometheus.yaml content/keda-trigger-auth-prometheus-temp.yaml
if [[ $os == "linux" ]]; then
    sed -i s/'<token>'/$secret/g content/keda-trigger-auth-prometheus-temp.yaml
elif [[ $os == "mac" ]]; then
    sed -i "" s/'<token>'/$secret/g content/keda-trigger-auth-prometheus-temp.yaml
fi
oc process -f content/keda-trigger-auth-prometheus-temp.yaml | oc apply -f - && rm content/keda-trigger-auth-prometheus-temp.yaml

echo "[INFO] Applying thanos-metrics-reader role"
oc apply -f content/thanos-metrics-reader.yaml

echo "[INFO] Ading role thanos-metrics-reader to user thanos"
oc adm policy add-role-to-user thanos-metrics-reader -z thanos --role-namespace=openshift-ingress-operator

echo "[INFO] Ading cluster role cluster-monitoring-view to user thanos"
oc adm policy -n openshift-ingress-operator add-cluster-role-to-user cluster-monitoring-view -z thanos

echo "[INFO] Applying ScaledObject ingress-scaler"
cp content/ingress-scaler.yaml content/ingress-scaler-temp.yaml
if [[ $1 == "omit" ]]; then
    if [[ $os == "linux" ]]; then
        sed -i /maxReplicaCount/d content/ingress-scaler-temp.yaml
    elif [[ $os == "mac" ]]; then
        sed -i "" /maxReplicaCount/d content/ingress-scaler-temp.yaml
    fi
else
    if [[ $os == "linux" ]]; then
        sed -i s/'<max_replica_count>'/$1/ content/ingress-scaler-temp.yaml
    elif [[ $os == "mac" ]]; then
        sed -i "" s/'<max_replica_count>'/$1/ content/ingress-scaler-temp.yaml
    fi
fi
oc apply -f content/ingress-scaler-temp.yaml && rm content/ingress-scaler-temp.yaml

echo "[INFO] ====Post Install Check===="
echo "[INFO] Getting hpa"
oc get hpa
node=$(oc get nodes --no-headers -l node-role.kubernetes.io/worker= | wc -l| sed -e 's/\(^ *\)//')
echo "[INFO] Number of worker nodes: $node"
replicas=$(oc get ingresscontroller/default -n openshift-ingress-operator -o jsonpath="{.spec.replicas}")
echo "[INFO] Ingresscontroller replicas: $replicas"
if [[ $1 == "omit" && $node -le 100 ]]; then
  if [[ $replicas -eq $node ]]; then
    echo "[PASS] maxReplicaCount is $1. Replica number $replicas equals to node number $node."
    exit 0
  else 
    echo "[FAIL] maxReplicaCount is $1. Replica number $replicas should be equal to node number $node."
    exit 1
  fi
elif [[ $1 == "omit" && $node -gt 100 ]]; then
  if [[ $replicas -eq 100 ]]; then
    echo "[PASS] maxReplicaCount is $1. Replica number $replicas equals to maxReplicaCount $1."
    exit 0
  else 
    echo "[FAIL] maxReplicaCount is $1. Replica number $replicas does not equal to maxReplicaCount $1."
    exit 1
  fi
else
  if [[ $1 -ge $node ]]; then
    if [[ $replicas -eq $node ]]; then
      echo "[PASS] maxReplicaCount is $1. Replica number $replicas equals to node number $node."
      exit 0
    else 
      echo "[FAIL] maxReplicaCount is $1. Replica number $replicas does not equal to node number $node."
      exit 1
    fi
  elif [[ $1 -lt $node ]]; then
    if [[ $replicas -eq $1 ]]; then
      echo "[PASS] maxReplicaCount is $1. Replica number $replicas equals to maxReplicaCount $1."
      exit 0
    else 
      echo "[FAIL]vmaxReplicaCount is $1. Replica number $replicas does not equal to maxReplicaCount $1."
      exit 1
    fi  
  fi  
fi
