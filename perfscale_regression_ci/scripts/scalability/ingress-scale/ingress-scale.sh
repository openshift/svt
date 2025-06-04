#/!/bin/bash
################################################
## Auth=qili@redhat.com
## Desription: Script for ingress scale test case
## Polarion test case: OCP-43281
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-43281
## Cluster config: 3 master (m5.xlarge), 9 workers(m5.2xlarge), 3 infras(c5.4xlarge), do not move component to infra nodes before the test
## ingress-perf config: standard-3replicas.yml, standard-4replicas.yml, standard-3replicas-8threads.yml,standard-4replicas-8threads.yml
################################################ 
set -o errexit

source ../../common.sh
source ../../../utils/run_workload.sh

echo "[INFO] run ingress-perf with thread=4, replica=2"
run_ingress_perf
echo "[INFO] run ingress-perf with thread=4, replica=3"
export CONFIG=../../../standard-3replicas.yml
run_ingress_perf

echo "[INFO] scale infra replicas to 4"
scaleInfraMachineSets 4
waitForInfraNodesReady 4
labelNode "node-role.kubernetes.io/infra=" "node-role.kubernetes.io/worker-"

echo "[INFO] run ingress-perf with thread=4, replica=4"
export CONFIG=../../../standard-4replicas.yml
run_ingress_perf

echo "[INFO] run ingress-perf with thread=8, replica=4"
export CONFIG=../../../standard-4replicas-8threads.yml
run_ingress_perf

echo "[INFO] run ingress-perf with thread=8, replica=3"
export CONFIG=../../../standard-3replicas-8threads.yml
run_ingress_perf

echo "[INFO] run ingress-perf with thread=8, replica=2"
unset CONFIG
run_ingress_perf

echo "[INFO] Test is finished. Pleaset check results in the grafana dashboards."