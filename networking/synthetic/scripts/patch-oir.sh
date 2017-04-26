#!/bin/bash
function patch_node {
curl --cert /etc/origin/master/admin.crt --key /etc/origin/master/admin.key --cacert /etc/origin/master/ca.crt \
        --header "Content-Type:application/json-patch+json" \
        --request PATCH \
        --data '[{"op": "add", "path": "/status/capacity/pod.alpha.kubernetes.io~1opaque-int-resource-solarflare", "value": "1"}]' \
        $URL/api/v1/nodes/$NODE_NAME/status
}

if [ ! $# == 2 ] ; then
        echo " "
        echo "Usage: sh $0 <api-server-url> <node-name>"
        echo "Example: sh patch-oir.sh https://10.20.30.3:8443 node1"
        exit 1
fi
URL=$1
NODE_NAME=$2
patch_node
