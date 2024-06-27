#!/bin/bash

i=$1
SECRET_TEMPLATE=secret_template_run.yaml
SECRET_NAME="my-large-secret-$i"
TMP_FILE="/tmp/secret_$(date +%s)_$i.yaml"
sed "s/SECRET_NAME/$SECRET_NAME/g" $SECRET_TEMPLATE > $TMP_FILE

oc create -f $TMP_FILE
