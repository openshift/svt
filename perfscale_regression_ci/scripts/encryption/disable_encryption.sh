#!/bin/bash
###########################################################################################################
## Auth=skordas@redhat.com
## Desription: Script to disable encryption of cluster.
## Polarion test case: OCP-26194 - Compare project loading time with etcd-encryption enabled and disabled
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-26194
## Cluster config: default
###########################################################################################################

bash toggle_encryption.sh disable 60