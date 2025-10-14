#!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Script to test leader-workerset api in perfscale team.
## export REPLICAS and SIZE to specify the scale.
## export IMAGE to specify what container image you want to run.
## export NAESPACE to specify what namespace you want the pods to deploy in.
################################################

function _usage {
    cat <<END
Usage: $(basename "${0}") [-r <replicas to run> ] [-s <size to run> ] [-i <image to runfolder_name> ] [-t <time_to_run>] -u
  -n <namespace to run>        : The namespace to deploy in. Default is lws-test.
  -r <replicas to run>         : The number of replicas to deploy. Default is 2.
  -s <size to run>             : The numner of pods to deploy on each replica.  Default is 2.
  -w <workload>                : The workload to run. Default is custom.
  -i <image or custom workload>: The container image to run. Default is quay.io/cloud-bulldozer/nginx:latest.
  -d                           : Delete one of the pod and let all pods in the replica to be recreated.
  -h                           : Help
END
}

while getopts ":n:r:s:idh" opt; do
    case ${opt} in
    n)
        LWSTEST_NAMESPACE=${OPTARG}
        ;;
    r)
        REPLICAS=${OPTARG}
        ;;
    s)
        SIZE=${OPTARG}
        ;;
    w)
        WORKLOAD=${OPTARG}
        ;;
    i)
        IMAGE=${OPTARG}
        ;;
    d)  
        DELETE=true
        ;;
    h)
        _usage
        exit 0
        ;;
    esac
done
if [[ "$1" = "" ]];then
    _usage
    exit 1
fi

function wait_for_running_pod {
  echo "Waiting for all pods in namespace '$LWSTEST_NAMESPACE' to be Running"
  RETRY=0
  max_retry=600
  START_TIME=$(date +%s)
  while true; do
    NOT_READY=$(oc get pods -n "$LWSTEST_NAMESPACE" --no-headers | \
      awk '{print $3}' | grep -v 'Running' | wc -l)
    if [ "$NOT_READY" -eq 0 ]; then
      break
    fi
    echo "Waiting on $NOT_READY pods..."
    sleep 2
    RETRY=$(($RETRY + 1))
    if [ $RETRY -gt $max_retry ]; then
      break
    fi
  done
  if [ "$RETRY" -gt $max_retry ]; then
      echo "Timed out waiting for all pods in namespace '$LWSTEST_NAMESPACE' to be Running."
  else
      echo "All pods in namespace '$LWSTEST_NAMESPACE' are Running"
  fi

  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))

  TOTAL_RUNNING_PODS=$(oc get pods -n "$LWSTEST_NAMESPACE" --no-headers | grep Running | wc -l)

  if [ $TOTAL_RUNNING_PODS -eq $(($REPLICAS * $SIZE)) ]; then
      echo "[PASS]" "Expected number of pods $TOTAL_RUNNING_PODS are running. Replicas: $REPLICAS, Size: $SIZE. Total pods running time: $ELAPSED seconds."
  else
      echo "[FAIL]" "Found $TOTAL_RUNNING_PODS, but expected $((REPLICAS * SIZE)) total running pods"
      exit 1
  fi

  echo "START_TIME: $START_TIME, END_TIME: $END_TIME"
  echo "Statefulsets:"
  oc get statefulsets -n "$LWSTEST_NAMESPACE"
}

LWSTEST_NAMESPACE=${LWSTEST_NAMESPACE:-"lws-test"}
REPLICAS=${REPLICAS:-2}
SIZE=${SIZE:-3}
WORKLOAD=${WORKLOAD:-custom}
IMAGE=${IMAGE:-quay.io/cloud-bulldozer/nginx:latest}

echo "=====================" 
echo "Replicas: $REPLICAS, Size: $SIZE, Image: $IMAGE"
echo "Running in project $LWSTEST_NAMESPACE"
echo "====================="
oc delete project "$LWSTEST_NAMESPACE" || true
oc new-project "$LWSTEST_NAMESPACE" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Failed to create project $LWSTEST_NAMESPACE!"
    exit 1
fi

if [ $WORKLOAD = "custom" ]; then
  oc apply -f - <<EOF
apiVersion: leaderworkerset.x-k8s.io/v1
kind: LeaderWorkerSet
metadata:
  name: leaderworkerset-sample
spec:
  replicas: $REPLICAS
  leaderWorkerTemplate:
    size: $SIZE
    workerTemplate:
      spec:
        containers:
        - name: nginx
          image: $IMAGE
          imagePullPolicy: IfNotPresent
          resources:
            limits:
              cpu: "100m"
            requests:
              cpu: "50m"
          ports:
          - containerPort: 8080
EOF
fi

if [ $WORKLOAD = "llamacpp" ]; then
  oc apply -f - <<EOF
apiVersion: leaderworkerset.x-k8s.io/v1
kind: LeaderWorkerSet
metadata:
  name: llamacpp-llama3-8b-instruct-bartowski-q5km
spec:
  replicas: $REPLICAS
  leaderWorkerTemplate:
    size: $SIZE
    restartPolicy: RecreateGroupOnPodRestart
    leaderTemplate:
      metadata:
        labels:
          app: llamacpp-llama3-8b-instruct-bartowski-q5km
      spec:
        containers:
        - name: llamacpp-leader
          image: quay.io/rhn_support_qili/llamacpp-llama3-8b-instruct-bartowski-q5km:latest
          imagePullPolicy: IfNotPresent
          command: [ "/llamacpp-leader", "--", "--n-gpu-layers", "99", "--verbose" ]
        securityContext:
          runAsUser: 0
        serviceAccountName: llama-sa
    workerTemplate:
      spec:
        containers:
        - name: llamacpp-worker
          image: quay.io/rhn_support_qili/llamacpp-worker:latest
          imagePullPolicy: IfNotPresent
          args: ["--host", "0.0.0.0", "--mem", "4192"]
        securityContext:
          runAsUser: 0
        serviceAccountName: llama-sa
---
apiVersion: v1
kind: Service
metadata:
  name: llamacpp
spec:
  clusterIP: None   #use headless service
  selector:
    app: llamacpp-llama3-8b-instruct-bartowski-q5km
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
EOF
fi

wait_for_running_pod

if [[ $DELETE ]]; then
    echo "=====================" 
    echo "Sleep 5 minutes before deleting a pod"
    sleep 300
    echo "Start to delete a pod"
    oc get po -n lws-test --no-headers | awk '{print $1}' | head -n 1 | xargs oc -n "$LWSTEST_NAMESPACE" delete pod
    wait_for_running_pod
fi