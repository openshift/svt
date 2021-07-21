#!/bin/bash

upgrade_pass=True

if [ "$#" -lt 1 ]; then
  echo "syntax: $0 <target_build_version> "
  echo "example:"
  echo "./upgrade.sh 4.8.1"
  exit 1
fi

taget_build_arr=(${1//,/ })  #target_build maybe a list "4.1.22,4.1.0-0.nightly-2019-11-04-224442,4.2.2"


enable_force=true
scale=false
maxUnavail=1
#optional parameters
while [[ $# -gt 1 ]]
do
key="$1"
echo "key $key"

case $key in
    -f|--force)
    enable_force=$2
    shift # past argument
    shift # past value
    ;;
    -s|--scale)
    scale=$2
    shift # past argument
    shift # past value
    ;;
    -u|--maxunavil)
    maxUnavail=$2
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    #need to get past file
    shift # past arg
    ;;
esac
done

echo "force $enable_force"
echo "scale $scale"
echo "target version $taget_build_arr"

# It will take about 15 mins If Kube-apiserver rolling out occurs after upgrade was fnished
kas_rollingout_wait(){
    timeout=60
    internal=5
    t=0
    PROGRESSING=$(oc get co/kube-apiserver --no-headers | awk '{print $4}')
    while [ $t -lt $timeout ] ;do
        if [ "X$PROGRESSING" == "XFalse" ];then
          echo "Kube-apiserver is done progressing"
          break
        fi
        [ "X$PROGRESSING" == "XTrue" ] && break
        sleep $internal
        t=$(( t + internal ))
        PROGRESSING=$(oc get co/kube-apiserver --no-headers | awk '{print $4}')
        echo "kube-apiserver still progressing $PROGRESSING"
    done
    if [ "X$PROGRESSING" == "XTrue" ];then
        echo -e "Kube-apiserver is rolling out ..."
        internal=20
        timeout=900
        while [ $t -lt $timeout ]; do
            [ "X$PROGRESSING" == "XFalse" ] && break
            sleep $internal
            t=$(( t + internal ))
            PROGRESSING=$(oc get co/kube-apiserver --no-headers | awk '{print $4}')
        done
        if [ "X$PROGRESSING" == "XFalse" ];then
            echo -e "#### Kube-apiserver rolling out was completed!"
        else
            echo -e "#### Warning: After waiting, co/kube-apiserver is still in Progressing!"
            echo -e "#### Warning: If this issue happened during 4.3->4.4 upgrade, then probably hit the bug 1931033, detailed in https://issues.redhat.com/browse/OCPQE-3342!"
            echo -e "#### Warning: otherwise, then probably hit the bug https://bugzilla.redhat.com/show_bug.cgi?id=1909600"
        fi
    fi
}


function abnormal_co() {
  echo -e "exit from upgrade loop\n"
  echo -e "**************Post Action after upgrade succ****************\n"

  post_check1=`oc get node -o wide`
  post_check2=`oc get co`
  echo -e "Post action: #oc get node: ${post_check1}\n\n"
  echo -e "Post action: #oc get co:${post_check2}\n\n"
  echo -e "print detail msg for node(SchedulingDisabled) if exist:\n"
  echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Abnormal node details~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n"
  if oc get node --no-headers | grep -E 'SchedulingDisabled|NotReady' ; then
                  oc get node --no-headers | grep -E 'SchedulingDisabled|NotReady'| awk '{print $1}'|while read line; do oc describe node $line;done
                  ret1="abnormal"
  fi
  echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n"
  echo -e "print detail msg for co(AVAILABLE != True or PROGRESSING!=False or DEGRADED!=False or version != target_version) if exist:\n"
  # Check if the kube-apiserver is rolling out after upgrade
  if [ -z "$ret1" ]; then # If master nodes are normal
      kas_rollingout_wait
  fi 

  echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Abnormal co details~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n"
  bnormalCO=""
  abnormalCO=$(oc get co |sed '1d'|grep -v "openshift-samples"|grep -v '.*True.*False.*False' | awk '{print $1}')
  if [ "X$abnormaalCO" != "X" ]; then
      upgrade_pass=False
      quick_diagnosis "$abnormalCO"
      for aco in $abnormalCO; do
          oc describe co $aco
          echo -e "\n~~~~~~~~~~~~~~~~~~~~~~~\n"
      done
  fi
  ret2=`oc get co |sed '1d'|grep -v "openshift-samples"|grep -v "service-catalog-apiserver"|grep -v "service-catalog-controller-manager"|grep -v "True        False         False"|awk '{print $1}'|while read line; do oc describe co $line;done`
  oc get co |sed '1d'|grep -v "openshift-samples"|grep -v ${target_version_prefix}|awk '{print $1}'|while read line; do oc describe co $line;echo -e "\n~~~~~~~~~~~~~~~~~~~~~~~\n";done
  ret3=`oc get co |sed '1d'|grep -v "openshift-samples"|grep -v "service-catalog-apiserver"|grep -v "service-catalog-controller-manager"|grep -v ${target_version_prefix}|awk '{print $1}'|while read line; do oc describe co $line;done`
  echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n"


  if [ -z "$ret1" ] && [ -z "$ret2" ] && [ -z "$ret3" ]; then
      echo -e "post check passed without err.\n"

  else
      echo -e "upgrade post check find err, collect must-gather....\n"
      schedulable_masters=(`oc get node | grep master |egrep -v 'Ready,SchedulingDisabled|NotReady'|awk '{print $1'}`)
      if [ -z "$schedulable_masters" ]; then
          echo "Skipping must-gather as there are no schedulable masters...\n"
      else
          oc adm must-gather --node-name=${schedulable_masters[0]}>/dev/null 2>&1
          ls must-gather.local*
          if [ $? -eq 0 ]; then
              filename=`ls |grep must-gather.local*`
              tar -czvf /tmp/${filename}.tar.gz $filename >/dev/null 2>&1
              rm -rf $filename
              echo -e "upload must_gather file to http://10.73.131.57:9000/minio/\n"
              pip3  install minio >/dev/null 2>&1
              upload_ret=$(python3 -c "import sys;sys.path.append('${upgrade_work_dir}');\
                                      import upload_must_gather_minio; \
                                      print (upload_must_gather_minio.upload_must_gather('/tmp/${filename}.tar.gz'))")
              rm -f /tmp/${filename}.tar.gz
              echo -e "+++[Debug]+++ upload_ret=${upload_ret}"
              echo -e "must_gather file upload:\n\n "
              echo -e "upload file: http://10.73.131.57:9000/minio/openshift-must-gather/${upload_ret}"
          else
             echo -e "must-gather file creation fails!!!"
          fi
      fi
      exit 127 # upgrade itself succ and post-check fail
  fi

}

# Quick diagnosis for abnormal cluster operators
function quick_diagnosis() {
    local abnormal_cos="$1"

    echo -e "~~~~~~~~\n $abnormal_cos \n~~~~~~~~\n"
    abnormal_co_logs=".abnormal_co_logs"
    all_co_logs=".all_co_logs" > "$abnormal_co_logs"
    oc get -o json clusteroperators > "$all_co_logs"
    for co in $abnormal_cos; do
        jq -r --arg co "$co" '.items[] | .metadata.name as $name | select($name == $co).status.conditions[] | .lastTransitionTime + " [" + $name + "] " + .type + " " + .status + " " + (.reason // "-") + " " + (.message // "-")' "$all_co_logs" >> "$abnormal_co_logs"
    done
    echo "#### Quick diagnosis: The first abnormal cluster operator is often the culprit! ####"
    echo "=> Below status and logs for the different conditions of all abnormal cos are sorted by 'lastTransitionTime':"
    # Error-tagging in one single line log
    reg1="Available False"
    reg2="Progressing True"
    reg3="Degraded True"
    reg4="not available"
    sed -i "s/$reg1/-->>$reg1<<--/g;s/$reg2/-->>$reg2<<--/g;s/$reg3/-->>$reg3<<--/g;s/$reg4/-->>$reg4<<--/g;" "$abnormal_co_logs"
    cat "$abnormal_co_logs" | sort
    echo -e "\n--------------------------\n"
    [ -f "$all_co_logs" ] && rm -f "$all_co_logs"
    [ -f "$abnormal_co_logs" ] && rm -f "$abnormal_co_logs"
}


function check_upgrade_version() {

  cur_version=$(oc get clusterversion -o jsonpath='{.items[0].status.desired.version}')
  cur_version_list=(${cur_version//./ })
  target_version_list=(${1//./ })
  index=1
  counter_cur=0
  for cur_version in "${cur_version_list[@]}"
  do
    counter_target=0
    for target_build_v in "${target_version_list[@]}"
    do
      if [[ $counter_cur -eq 1 ]]; then
        if [[ $counter_target -eq 1 ]]; then
          if [[ $cur_version -lt $((target_build_v - 1)) ]]; then
             echo "target build is more than 1 version ahead of current build"
             echo "Please update target version to be increased by 1"
             exit 1
            fi
        fi
      fi
      counter_target=$((counter_target+1))
  done
    counter_cur=$((counter_cur+1))
  done

}

python3 -c "import check_upgrade; check_upgrade.set_max_unavailable($maxUnavail)"

for target_build in "${taget_build_arr[@]}"
do
  check_upgrade_version $target_build
  echo ${target_build} |grep nightly >/dev/null 2>&1
  if [ $? -eq 0 ]
  then
      echo "target version nightly "
      target_version_prefix=${target_build}   #night build:4.2.0-0.nightly-2020-02-03-234322
      if [ "X$enable_force" == "Xtrue" ];then
        upgrade_line="oc adm upgrade --to-image registry.ci.openshift.org/ocp/release:$target_version_prefix --force --allow-explicit-upgrade"
      else
        upgrade_line="oc adm upgrade --to-image registry.ci.openshift.org/ocp/release:$target_version_prefix --allow-explicit-upgrade"
      fi
  else
    echo "target version quay "
    target_version_prefix=$(echo ${target_build}) #4.3.0-x86_64 ==> we got "Cluster version is 4.3.0"
    if [ "X$enable_force" == "Xtrue" ];then
      upgrade_line="oc adm upgrade --to-image quay.io/openshift-release-dev/ocp-release:$target_version_prefix-x86_64 --force --allow-explicit-upgrade"
    else
      upgrade_line="oc adm upgrade --to-image quay.io/openshift-release-dev/ocp-release:$target_version_prefix-x86_64 --allow-explicit-upgrade"
    fi
  fi

  echo "target version $target_version_prefix"
  echo "upgrade line $upgrade_line"
  echo $upgrade_line
  SECONDS=0
  CONSOLE_LAST_LINE="$($upgrade_line)"
  echo $CONSOLE_LAST_LINE
  export PYTHONUNBUFFERED=1
  python3 -c "import check_upgrade; check_upgrade.check_upgrade('$target_version_prefix')"
  duration=$SECONDS
  echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
  sleep 30
  abnormal_co
  sleep 1
done


if [ "X$scale" == "Xtrue" ]; then
  #add machinesets
  machine_name=$(oc get machineset -n openshift-machine-api -o name --no-headers | grep "^.*$" -m1)
  #get first machine replica count
  #add 1 to replica count
  machine_replicas=$(oc get $machine_name -n openshift-machine-api -o jsonpath={.status.replicas})
  machine_replicas=$((machine_replicas + 1))
  oc scale --replicas=$machine_replicas -n openshift-machine-api $machine_name
  python3 -c "import check_upgrade; check_upgrade.wait_for_replicas('$machine_replicas','$machine_name')"
fi

exit 0 #upgrade succ and post-check succ