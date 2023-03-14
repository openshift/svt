#/!/bin/bash
################################################
## Auth=qili@redhat.com
## Desription: Script to prepare OCP-9225 - add registry node and move registry component to registry node
## Polarion test case: OCP-9225 - Concurrent push to the registry
## https://polarion.engineering.redhat.com/polarion/redirect/project/OSE/workitem?id=OCP-9225
## Cluster config: 3 master/2 infra/2 registry/10 workers. Type AWS m5.4xlarge (16 vCPU, 64GB RAM). Registry configured to use AWS S3 bucket for persistence
## Registry machineset template: perfscale_regerssion_ci/content/registry-node-machineset-aws.yaml
################################################ 
source ../common.sh

# only work on aws now
create_registry_machinesets ../../content/registry-node-machineset-aws.yaml registry
move_registry_to_registry_nodes