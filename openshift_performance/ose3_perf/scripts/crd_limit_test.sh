#!/usr/bin/bash

#
# create test CRDs
#

for i in {0..165}; do

cat <<EOF | oc create -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  generation: 1
  name: svtconfig${i}.svt${i}.io
spec:
  conversion:
    strategy: None
  group: svt${i}.io
  names:
    kind: SvtConfig${i}
    listKind: SvtConfig${i}List
    plural: svtconfig${i}
    singular: svtconfig${i}
  scope: Namespaced
  versions:
  - name: v1
    schema:
      openAPIV3Schema:
        description: 'Tuned is a collection of rules that allows cluster-wide deployment of node-level sysctls and more flexibility to add custom tuning specified by user needs. These rules are translated and passed to all containerized tuned daemons running in the cluster in the format that the daemons understand. The responsibility for applying the node-level tuning then lies with the containerized tuned daemons. More info: https://github.com/openshift/cluster-node-tuning-operator'
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info2: https://git.k8s.io/community/contributors/devel/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          spec:
            description: 'spec is the specification of the desired behavior of Tuned. More info: https://git.k8s.io/community/contributors/devel/api-conventions.md#spec-and-status'
            properties:
              flavor:
                description: flavor
                type: string
            type: object
          status:
            description: status holds observed values from the cluster. They may not
              be overridden.
            type: object
        type: object
    served: true
    storage: true
    subresources:
      status: {}
EOF

done


#
# Verify no throttling messages
#

oc get crd --no-headers -A | cut -f1 -d" " | while read crd; do
   echo "Retrieve ${crd}"
   this_crd=`oc get --no-headers $crd 2>&1`
   if [[ $this_crd == *"Throttling request"* ]]; then
     exit 99
   fi
done
retval=$?
if [[ $retval == 99 ]]; then
   status="FAIL:  Request was throttled"
else
   status="PASS: No requests throttled"
fi


oc get crds -A | cut -f1 -d" " | grep svt | while read crd; do
   oc delete --wait=false crd $crd
done


echo $status
exit $retval
