#!/bin/bash

i=$1
echo "create testImage-$i"
oc process -f template_image.yaml -p NAME=testImage-$i | oc create -f -
