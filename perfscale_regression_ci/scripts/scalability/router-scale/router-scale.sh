#/!/bin/bash
################################################
## Auth=qili@redhat.com
## Desription: Script for router scale test
## Polarion test case: OCP-43281
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-43281
## Cluster config: 3 master (m5.xlarge), 9 workers(m5.2xlarge), 3 infras(c5.4xlarge), do not move component to infra nodes before the test
## ingress-perf config: standard-3replicas.yml, standard-4replicas.yml
## optional PARAMETERS: number of JOB_ITERATION
################################################ 
set -o errexit

source ../../common.sh
source ../../../utils/run_workload.sh

echo "[INFO] Patch threadCount as 4"
oc -n openshift-ingress-operator patch ingresscontroller/default --type=merge -p '{"spec":{"tuningOptions": {"threadCount": 4}}}'
oc -n openshift-ingress get deploy router-default -o yaml | grep " ROUTER_THREADS" -A 1

echo "[INFO] run ingress-perf with thread=4, replica=2"
run_ingress_perf
#run ingress-perf with thread=4, replica=3
export CONFIG=../../../standard-3replicas.yml
run_ingress_perf

echo "[INFO] scale infra replicas to 4"
machineset=$(oc get machinesets -n openshift-machine-api --no-headers | head -n 1 | awk {'print $1'})
oc scale machineset --replicas=2 ${machineset} -n openshift-machine-api
oc get machinesets -n openshift-machine-api

echo "[INFO] run ingress-perf with thread=4, replica=4"
export CONFIG=../../../standard-4replicas.yml
run_ingress_perf

echo "[INFO] Patch threadCount as 8"
oc -n openshift-ingress-operator patch ingresscontroller/default --type=merge -p '{"spec":{"tuningOptions": {"threadCount": 8}}}'
oc -n openshift-ingress get deploy router-default -o yaml | grep " ROUTER_THREADS" -A 1

echo "[INFO] run ingress-perf with thread=8, replica=4"
export CONFIG=../../../standard-4replicas.yml
run_ingress_perf

echo "[INFO] run ingress-perf with thread=8, replica=3"
export CONFIG=../../../standard-3replicas.yml
run_ingress_perf

echo "[INFO] run ingress-perf with thread=8, replica=2"
unset CONFIG
run_ingress_perf

echo "[INFO] Test is finished. Pleaset check results in the grafana and dittybopper dashboards."