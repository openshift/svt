#/!/bin/bash
################################################
## Auth=qili@redhat.com
## Desription: Script for ingress tunning options test case
## Polarion test case: OCP-43281
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-43281
## Cluster config: 3 master (m5.xlarge), 9 workers(m5.2xlarge), 3 infras(c5.4xlarge), do not move component to infra nodes before the test
## ingress-perf config: standard-tunning-options.yml
################################################ 
set -o errexit

source ../../common.sh
source ../../../utils/run_workload.sh

echo "[INFO] run ingress-perf with configured tunning options, thread=8, replica=3"
export CONFIG=../../../standard-tunning-options.yml
run_ingress_perf
oc get deployment router-default -n openshift-ingress -o yaml | egrep "ROUTER_BACKEND_CHECK_INTERVAL|ROUTER_DEFAULT_CLIENT_TIMEOUT|ROUTER_CLIENT_FIN_TIMEOUT|ROUTER_BUF_SIZE|ROUTER_MAX_REWRITE_SIZE|ROUTER_DEFAULT_SERVER_TIMEOUT|ROUTER_DEFAULT_SERVER_FIN_TIMEOUT|ROUTER_INSPECT_DELAY|ROUTER_DEFAULT_TUNNEL_TIMEOUT|ROUTER_MAX_CONNECTIONS" -A 1

echo "[INFO] Test is finished. Pleaset check results in the grafana dashboards."