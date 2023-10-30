function create_demo() {
# create the demo namespace
echo "$(date): Creating demo namespace... \n"
cat <<EOF | oc apply -f - 
apiVersion: v1
kind: Namespace
metadata:
  name: demo
EOF

# give the podlisters permissions to LIST and GET pods from the demo namespace
for i in {0..2}; do
cat <<EOF | oc auth reconcile -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: podlister
  namespace: demo  
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["list", "get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: podlister
  namespace: demo
subjects:
- apiGroup: ""
  kind: ServiceAccount
  name: podlister-$i
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: podlister
EOF
done

echo "\n$(date): Creating ServiceAccounts...\n"

# create the ServiceAccounts for the demo namespace
for i in {0..2}; do
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: podlister-$i
  namespace: demo
  labels:
    kubernetes.io/name: podlister-$i
EOF
done
}

function delete_namespace() {
  # clean up the demo namespace
  echo "\n$(date): Deleting namespace..."
  oc delete namespace demo
  echo "$(date): Namespace deleted"

}

function create_flow_control() {
# create the FlowSchema and PriorityLevelConfigurations to moderate requests going to the service accounts
cat <<EOF | oc apply -f -
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: FlowSchema
metadata:
  name: restrict-pod-lister
spec:
  priorityLevelConfiguration:
    name: restrict-pod-lister
  distinguisherMethod:
    type: ByUser
  rules:
  - resourceRules:
    - apiGroups: [""]
      namespaces: ["demo"]
      resources: ["pods"]
      verbs: ["list", "get"]
    subjects:
    - kind: ServiceAccount
      serviceAccount:
        name: podlister-0
        namespace: demo
    - kind: ServiceAccount
      serviceAccount:
        name: podlister-1
        namespace: demo 
    - kind: ServiceAccount
      serviceAccount:
        name: podlister-2
        namespace: demo            
---
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: PriorityLevelConfiguration
metadata:
  name: restrict-pod-lister
spec:
  type: Limited
  limited:
    assuredConcurrencyShares: 5
    limitResponse:
      queuing:   
        queues: 10
        queueLengthLimit: 20
        handSize: 4
      type: Queue
EOF
}

function delete_flow_schema() {
  # clean up the FlowSchema
  oc get flowschema
  echo "$(date): Deleting Flowschema..."
  oc delete flowschema restrict-pod-lister
  echo "$(date): Flowschema deleted"
}

function delete_priority_level_configuration() {
  # clean up the PriorityLevelConfiguration
  oc get prioritylevelconfiguration
  echo "$(date): Deleting PriorityLevelConfiguration..."
  oc delete prioritylevelconfiguration restrict-pod-lister
  echo "$(date): Flowschema deleted"
}

function deploy_controller() {
# create three deployments to send continuous traffic to the ServiceAccounts
for i in {0..2}; do
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podlister-$i
  namespace: demo
  labels:
    kubernetes.io/name: podlister-$i
spec:
  selector:
    matchLabels:
      kubernetes.io/name: podlister-$i
  template:
    metadata:
      labels:
        kubernetes.io/name: podlister-$i
    spec:
      serviceAccountName: podlister-$i
      containers:
      - name: podlister
        image: quay.io/isim/podlister
        imagePullPolicy: Always
        command:
        - /podlister
        env:
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: SHOW_ERRORS_ONLY
          value: "true"
        - name: TARGET_NAMESPACE
          value: demo
        - name: TICK_INTERVAL
          value: 100ms         
        resources:
          requests:
            cpu: 30m
            memory: 50Mi
          limits:
            cpu: 100m
            memory: 128Mi
EOF
done
}

function delete_controller() {
  # clean up deployments in the demo namespace
  oc get deployments -n demo
  printf "$(date): Deleting deployments... \n\n"
  for i in {0..2}; do
  oc delete deployment podlister-$i -n demo
  done
  printf "\n$(date): Deployments deleted \n"
}

function scale_traffic() {
  # scale up the deployments to send more traffic and overload the APF settings
  echo "$(date): Scaling traffic..."
  for i in {0..2}; do oc -n demo scale deploy/podlister-$i --replicas=20; done
}

function check_no_errors() {
  # validate that the logs show no errors before traffic has been scaled
  oc -n demo set env deploy CONTEXT_TIMEOUT=1s --all                        

  echo ""

  not_scaled_log_count=$(oc -n demo logs deploy/podlister-0 | grep -i "context deadline" | wc -l)
  echo "$not_scaled_log_count"
  if [ $not_scaled_log_count -le 0 ]; then
    echo "Expected: No error logs found"
  else
    echo "Errors found. Priority and Fairness settings did not properly catch the requests."
  fi
  
}

function check_errors() {
  # validate that there are errors after the 
  oc -n demo set env deploy CONTEXT_TIMEOUT=1s --all
  oc -n demo logs deploy/podlister-0 | grep -i "context deadline" | wc -l                        
  scaled_log_count=$(oc -n demo logs deploy/podlister-0 | grep -i "context deadline" | wc -l)
  echo "$scaled_log_count"
  if [[ ($not_scaled_log_count -le 0) && ($scaled_log_count > 0) ]]; then
    echo "API Priority and Fairness Test Result: PASS"
    echo "Expected: Errors appeared when traffic was scaled."
  else
    echo "API Priority and Fairness Test Result: FAIL"
    echo "No error logs found when traffic was scaled."
  fi
}



create_demo

SERVICE_ACCOUNT="system:serviceaccount:openshift-apiserver-operator:openshift-apiserver-operator"

FLOW_SCHEMA_UID="$(oc get po -A --as "$SERVICE_ACCOUNT" -v8 2>&1 | grep -i X-Kubernetes-Pf-Flowschema-Uid | awk '{print $6}')"

PRIORITY_LEVEL_UID="$(oc get po -A --as "$SERVICE_ACCOUNT" -v8 2>&1 | grep -i X-Kubernetes-Pf-Prioritylevel-Uid | awk '{print $6}')"

CUSTOM_COLUMN=”uid:{metadata.uid},name:{metadata.name}”

create_flow_control

deploy_controller

echo "Logs before scaling traffic:"

check_no_errors

scale_traffic

sleep 10

echo "Logs after scaling traffic:"

check_errors

delete_flow_schema

delete_controller

delete_namespace


