function create_demo() {
echo "$(date): Creating demo namespace..."
cat <<EOF | oc apply -f - 
apiVersion: v1
kind: Namespace
metadata:
  name: demo
EOF

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
  oc get namespaces
  echo "$(date): Deleting namespace..."
  oc delete namespace demo
  echo "$(date): Namespace deleted"

}

function create_flow_schemas() {
cat <<EOF | oc apply -f -
apiVersion: flowcontrol.apiserver.k8s.io/v1alpha1
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
apiVersion: flowcontrol.apiserver.k8s.io/v1alpha1
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
  oc get flowschema
  echo "$(date): Deleting flowshema..."
  oc delete flowschema restrict-pod-lister
  echo "$(date): Flowschema deleted"
}

function deploy_controller() {
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
  oc get deployments
  echo "$(date): Deleting deployments..."
  for i in {0..2}; do
  oc delete deployment podlister-$i
  echo "$(date): Deployments deleted"
  done
}

function scale_traffic() {
    echo "$(date): Scaling traffic..."
    for i in {0..2}; do oc -n demo scale deploy/podlister-$i --replicas=10; done
}

function check_logs() {
  oc -n demo set env deploy CONTEXT_TIMEOUT=1s --all                        

  echo ""

  oc -n demo logs deploy/podlister-0 | grep -i "context deadline"

  echo ""
}


create_demo

SERVICE_ACCOUNT="system:serviceaccount:openshift-apiserver-operator:openshift-apiserver-operator"

FLOW_SCHEMA_UID="$(oc get po -A --as "$SERVICE_ACCOUNT" -v8 2>&1 | grep -i X-Kubernetes-Pf-Flowschema-Uid | awk '{print $6}')"

PRIORITY_LEVEL_UID="$(oc get po -A --as "$SERVICE_ACCOUNT" -v8 2>&1 | grep -i X-Kubernetes-Pf-Prioritylevel-Uid | awk '{print $6}')"

CUSTOM_COLUMN=”uid:{metadata.uid},name:{metadata.name}”

create_flow_schemas

deploy_controller

echo "Logs before scaling traffic:"

check_logs

scale_traffic

echo "Logs after scaling traffic:"

check_logs

delete_flow_schema

delete_controller

delete_namespace


