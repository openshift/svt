#/!/bin/bash

function wait_for_descheduler_to_run() {
  kube_desch_name=$(oc get KubeDescheduler -n openshift-kube-descheduler-operator -o name)
  sched_seconds=$(oc get $kube_desch_name -n openshift-kube-descheduler-operator -o jsonpath='{.spec.deschedulingIntervalSeconds}')
  echo "waiting for $sched_seconds seconds for descheduler to run"
  sleep $sched_seconds
}


function get_descheduler_evicted() {
  desched_pod=$(oc get pods -n openshift-kube-descheduler-operator --no-headers -o name | grep -v operator)
  logs=$(oc logs $desched_pod -n openshift-kube-descheduler-operator --tail=10 |  grep 'Number of evicted pods')
  echo "$logs"
}


function validate_descheduler_installation() {
  all_ns=$(oc get ns -o name)
  found=False
  for ns in $all_ns; do
    if [[ $ns == "namespace/openshift-kube-descheduler-operator" ]]; then
      found=True
      break
    fi 
  done
  if [[ $found == False ]]; then 
    echo "Make sure to install the descheduler operator in namespace 'openshift-kube-descheduler-operator'"
    exit 1
  fi

  validate_profiles $1
}

function validate_profiles() {
  all_profiles=$(oc get kubedescheduler cluster -o jsonpath='{.spec.profiles}' -n openshift-kube-descheduler-operator)

  wanted_profiles_var=$1
  wanted_profiles=($(echo $wanted_profiles_var | tr ',' ' ' ))
  echo "wanted profiles ${wanted_profiles[@]}"

  data=($(echo $all_profiles | tr -d '[]'|  tr ',' ' ' ))

  found=0
  for wanted_profile in ${wanted_profiles[@]}; do 
    for prof in ${data[@]}; do
      profile_no_quotes=$(echo $prof | tr -d '"' )
      if [[ $profile_no_quotes == $wanted_profile ]]; then
        (( ++found ))
      fi
      
    done
  done

  if [[ $found -eq ${#wanted_profiles[@]} ]]; then
    echo "All profiles were properly set for descheduler"
  else
    echo "Not all profiles were found on the cluster"
    echo "Be sure to set profiles to: $wanted_profiles_var"
    exit 1
  fi
}

