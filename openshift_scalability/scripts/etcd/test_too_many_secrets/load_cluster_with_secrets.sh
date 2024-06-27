#!/bin/bash

#################################################
# Author: skordas@redhat.com
# Related Test Case: OCP-69213
#
# Description:
# Script to create large number of secrets
# per project.
#################################################

START=$(date)

for i in {1..300}
  do oc new-project project-$i
  oc label ns project-$i purpose=test
  for j in {1..400}
    do sh load_secret.sh $j &
  done
  while [ $(oc get secrets -n project-$i | grep -c my-secret) -lt 400 ]
    do oc get secrets -n project-$i | grep -c my-secret
    sleep 5
  done
done

END=$(date)
echo "Start: $START"
echo "End  : $END" 
