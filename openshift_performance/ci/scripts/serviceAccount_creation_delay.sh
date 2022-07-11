#!/bin/bash

# Test parameters
num_of_repeats=100
base_name=test-sa

# init state
sum_of_delays_build=0
sum_of_delays_defau=0
sum_of_delays_deplo=0
num_of_delays=0

# Create projects
for i in $(seq 1 $num_of_repeats)
do
  project_name=$base_name-$i
  oc new-project $project_name
  oc label namespace $project_name purpose=test
  oc create -f- <<EOF
{
  "kind": "PersistentVolumeClaim",
  "apiVersion": "v1",
  "metadata": {
    "name": "mypvc",
    "annotations": {},
    "labels": {
        "name": "dynamic-pvc"
    }
  },
  "spec": {
    "accessModes": [
      "ReadWriteOnce"
    ],
    "resources": {
      "requests": {
        "storage": "1Gi"
      }
    }
  }
}
EOF

  oc create -f- <<EOF
kind: Pod
apiVersion: v1
metadata:
  name: mypod
spec:
  containers:
    - name: dynamic
      image: quay.io/openshifttest/hello-openshift@sha256:b1aabe8c8272f750ce757b6c4263a2712796297511e0c6df79144ee188933623
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
      - mountPath: "/mnt/ocp_pv"
        name: dynamic
  volumes:
    - name: dynamic
      persistentVolumeClaim:
        claimName: mypvc

EOF

done

# Get delay times
for i in $(seq 1 $num_of_repeats)
do
  project_name=$base_name-$i
  echo "------ Project: $project_name -------"
  pr_time=$(date --date="$(oc get project $project_name -o jsonpath="{.metadata.creationTimestamp}")" -u +%s)
  echo "Project creationTimestamp: $pr_time"
  sa_build_time=$(date --date="$(oc get serviceaccount builder -n $project_name -o jsonpath="{.metadata.creationTimestamp}")" -u +%s)
  echo "ServiceAccount builder creationTimestamp:  $sa_build_time"
  sa_defau_time=$(date --date="$(oc get serviceaccount default -n $project_name -o jsonpath="{.metadata.creationTimestamp}")" -u +%s)
  echo "ServiceAccount default creationTimestamp:  $sa_defau_time"
  sa_deplo_time=$(date --date="$(oc get serviceaccount deployer -n $project_name -o jsonpath="{.metadata.creationTimestamp}")" -u +%s)
  echo "ServiceAccount deployer creationTimestamp: $sa_deplo_time"

  delay_time_build=$(($sa_build_time-$pr_time))
  echo "ServiceAccount build delay[s]:    $delay_time_build"
  delay_time_defau=$(($sa_defau_time-$pr_time))
  echo "ServiceAccount default delay[s]:  $delay_time_defau"
  delay_time_deplo=$(($sa_deplo_time-$pr_time))
  echo "ServiceAccount deployer delay[s]: $delay_time_deplo"

  sum_of_delays_build=$(($sum_of_delays_build+$delay_time_build))
  sum_of_delays_defau=$(($sum_of_delays_defau+$delay_time_defau))
  sum_of_delays_deplo=$(($sum_of_delays_deplo+$delay_time_deplo))
  if [[ "$delay_time_build" != "0" || "$delay_time_defau" != "0" || "$delay_time_deplo" != "0" ]]
  then
    num_of_delays=$(($num_of_delays+1))
    oc label namespace $project_name purpose-
    oc label namespace $project_name result=failed
  fi

done

# Delete projects
oc project default
oc delete project -l purpose=test
while [ $(oc get projects | grep -c Terminating) -gt 0 ]
do
  echo "Num projects still Terminating: $(oc get projects | grep -c Terminating)"
  sleep 10
done

# Summary
echo ""
echo "========================================================================================"
echo "Sum of delays of serviceAccount builder [s]:  $sum_of_delays_build"
echo "Sum of delays of serviceAccount default [s]:  $sum_of_delays_defau"
echo "Sum of delays of serviceAccount deployer [s]: $sum_of_delays_deplo"
average_time_build=$(echo "scale=3; $sum_of_delays_build/$num_of_repeats" | bc)
average_time_defau=$(echo "scale=3; $sum_of_delays_defau/$num_of_repeats" | bc)
average_time_deplo=$(echo "scale=3; $sum_of_delays_deplo/$num_of_repeats" | bc)
percentage_fails=$(echo "scale=3; $num_of_delays*100/$num_of_repeats" | bc)
echo "Average delay creation serviceAccount builder time per project [s]:  $average_time_build"
echo "Average delay creation serviceAccount default time per project [s]:  $average_time_defau"
echo "Average delay creation serviceAccount deployer time per project [s]: $average_time_deplo"
echo "Number of projects..........................................: $num_of_repeats"
echo "Number of projects where serviceAccount creation was delayed: $num_of_delays"
echo "Percentage of delayed.......................................: $percentage_fails"
echo "========================================================================================"
echo ""
echo "========================== Not deleted projects (with delays) =========================="
oc get projects | grep $base_name
echo "Please use 'oc delete projects -l result=failed' command to delete these."
