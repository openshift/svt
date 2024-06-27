#!/bin/bash

i=$1
oc create secret generic my-secret-$i --from-literal=key1=supersecret --from-literal=key2=topsecret
