#/!/bin/bash
################################################
## qili@redhat.com
## Desription: Script for OCP-41535 - NetworkPolicy scalability - 2000 pods per namespace using customer network policy
## https://polarion.engineering.redhat.com/polarion/redirect/project/OSE/workitem?id=OCP-41535
## AWS OVN 10 worker nodes
################################################

duration=0
namespace=network-policy-scalability

verifyReplicas(){
    echo "[INFO] Verify $1 replicas are reached, will timeout in 20 minutes."
    pod_number=0
    retry=0
    for i in {1..120};
        do
            replica=$(oc get deployment -n $namespace --no-headers| awk '{print $3}')
            pod_not_running=$(oc get pods -n $namespace --no-headers| egrep -v "Completed|Running" -c)
            if [[ $replica -eq $1 && $pod_not_running -eq 0 ]]; then
                break
            fi
            sleep 10
            echo "[INFO] replica=$replica pod_not_running=$pod_not_running retry=$retry sleep 10s"
            retry=$(expr $retry + 1)
        done

    if [[ $replica -lt $1 || $pod_not_running -ne 0 ]]; then
        echo "[ERROR] Time out. Exit."
        exit 1
    fi
}

scale(){
    echo "[INFO] Scale to $1 replicas."
    oc scale --replicas $1 deployment network-policy-scalability -n $namespace
    verifyReplicas $1
}

scaleDuration(){
    echo "[INFO] Scale to $1 replicas and count the time."
    # Scale deployment to 2000 pods and count the time
    date
    SECONDS=0
    oc scale --replicas $1 deployment network-policy-scalability -n $namespace
    duration=$SECONDS
    echo "***Time taken to trigger the scale command: ${duration}s"
    date

    # Monitor the deployment until it reaches 2000 pods. Record the time 2000 pods are reached.
    date
    SECONDS=0
    duration=0
    verifyReplicas $1
    date
    duration=$SECONDS
}

delete_networkpolicy(){
    oc get networkpolicy -n $namespace --no-headers | awk {'print $1'} | xargs oc delete networkpolicy -n $namespace
}

check_http_code(){
    SECONDS=0
    for i in {1..120};
        do
            date
            http_code=$(oc exec $apiserver_pod  -n openshift-oauth-apiserver -c oauth-apiserver -- curl -s http://${pod_ip}:8080 --connect-timeout 1 -w "%{http_code}" -o /dev/null)
            if [[ $http_code -eq $1 ]]; then
                break
            fi
            sleep 1
        done
    duration=$SECONDS
}

# Create test namespace
oc create namespace $namespace

# Apply deployment with 500 pods
echo "[INFO]Apply a deployment with 500 replicas."
oc apply -f ../content/deployment-network-policy-scalability.yaml -n $namespace
verifyReplicas 500

duration=0
scaleDuration 2000
echo "[INFO]***Time taken to scale deployment from 500 to 2000 WITHOUT network policies: ${duration}s"

scale 500

# Apply network policy to the namespace
oc apply -f ../content/networkpolicy-scalability.yaml -n $namespace

duration=0
scaleDuration 2000
echo "[INFO]***Time taken to scale deployment from 500 to 2000 WITH network policies: ${duration}s"

# Delete network policy
delete_networkpolicy

# Apply deny policy to the namespace

pod_name=$(oc get po -n $namespace --no-headers | head -n 1 | awk '{print $1}')
pod_ip=$(oc get po $pod_name -n  network-policy-scalability --output jsonpath='{.status.podIP}')
apiserver_pod=$(oc get po -n openshift-oauth-apiserver --no-headers | head -n 1 | awk '{print $1}')

# Appy deny network policy and check the time taken for network policy to be active
date
oc apply -f ../content/networkpolicy-deny.yaml -n $namespace
duration=0
check_http_code 000
echo "[INFO]***Time taken for network policy to be active: ${duration}s"
date

# Delete deny network policy and check the time taken for network policy to be inactive
date
delete_networkpolicy
duration=0
check_http_code 200
echo "[INFO]***Time taken for network policy to be inactive: ${duration}s"
date

# Delete test namespace
oc delete ns $namespace && echo "[INFO] test project is deleted"