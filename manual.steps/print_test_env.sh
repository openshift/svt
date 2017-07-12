#!/bin/bash

set -x

date

oc version

openshift version

docker version

oc get nodes --show-labels
