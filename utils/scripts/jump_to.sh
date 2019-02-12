#!/bin/bash

if [ "$#" -ne 2 ]
then
  echo "Please provide path to ssh key and ip or url address of worker node"
  echo "Usage: ./jump_to_node.sh path/to/ssh/key address.to.worker.node"
  exit 1
fi

key=$1
internalDNS=$2
externalDNS=`oc get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' | cut -d ' ' -f 1`

cmd=(ssh -i "$key" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand='ssh -A -i '"$key"' -W %h:%p core@'"$externalDNS"'' core@"$internalDNS")
echo "Command:\n" "${cmd[@]}"
"${cmd[@]}"
