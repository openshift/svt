#!/bin/bash

echo "### START THE ROUTE TESTS  ##"

echo "Grafana route is: "
grafana_route=`oc get route --all-namespaces --no-headers | grep grafana | awk '{print $3}'` 
echo $grafana_route

echo "Creating the eap pods"
python /root/svt/openshift_scalability/cluster-loader.py -f route-test-app-config.yaml

echo "Waiting for the pods to be ready"
pods_up="no"
while [ "$pods_up" == "no" ]
do
  num_pods_up=`oc get pods --all-namespaces --no-headers | grep eap | grep -v build | grep -v sql-1- | grep -v database | grep -v db-1- | grep -v deploy | grep -v hook | grep Running | wc -l`
  echo $num_pods_up
  if [ $num_pods_up -eq 4 ]
  then
    pods_up="yes"
    echo "Pods are running, wait for build pods to go to complete"
    sleep 10
  else
  	sleep 5
  fi
done

echo "Done creating app pods"
echo "Creating wlg pod"
#find the wlg node
nodes=`oc get pods --all-namespaces -o wide | grep Running | grep eap-app-1 | awk -F ' '  '{arr[$8]++}END{for (a in arr) print a, arr[a]}' | awk '{print $1}' `
counts=`oc get pods --all-namespaces -o wide | grep Running | grep eap-app-1 | awk -F ' '  '{arr[$8]++}END{for (a in arr) print a, arr[a]}' | awk '{print $2}' `


i=0
for count in ${counts}
do
  echo "$count the i value is: $i"
  if [ $i -eq 0 ]
   then
     min_count=$count
     min_count_host=$i
     let i=i+1
  elif [ $count -lt $min_count ]
   then 
     min_count=$count
     min_count_host=$i
     let i=i+1
  else
     let i=i+1
  fi
done

echo "The min count pods: $min_count min count node pos: $min_count_host "

i=0
for host in ${nodes}
do
  echo $host
  if [ $min_count_host -eq $i ]
   then
   min_count_host_name=$host
   min_count_host_set="yes"
  fi
  let i=i+1
done
echo "The WLG host name is: $min_count_host_name "

echo "Labelling the WLG node"
oc label node $min_count_host_name placement=test --overwrite=true

echo "Building the WLG image"
ret_code=`ssh $min_count_host_name docker build -t svt/centos-stress   ~/svt/openshift_scalability/content/centos-stress`
echo "Return code is: $ret_code "
echo "Done preparing the wlg node"

echo "Update the stress json "
sed -i "s/Always/Never/g" /root/svt/openshift_scalability/content/quickstarts/stress/stress-pod.json

export benchmark_run_dir=/var/lib/pbench-agent
echo "Results directory set to $benchmark_run_dir "

initial_users=200

for users in $(seq $initial_users 50 800)
do
  echo "Running the route test for $users users "
  sed -i "s/users/$users/g" stress-route-test-template.yaml
  python /root/svt/openshift_scalability/cluster-loader.py -vaf stress-route-test-template.yaml
  sed -i "s/$users/users/g" stress-route-test-template.yaml
  sleep 60
done

echo "Analyzing results"
results_dir=$benchmark_run_dir

cd $results_dir
dirs=`ls -ltr | grep mb-centos | awk '{print $9}'`

for dir in ${dirs}
do
  #echo $dir
  users=`cat $dir/requests.json | grep clients | awk -F ":" '{print $2}' | awk -F "," '{print $1}' | awk '{print $1}' | sort -u`
  hits=`cat $dir/mb.log | grep Hits`
  total_hits=`echo $hits | awk -F ":" '{print $2}' | awk -F "," '{print $1}' | awk '{print $1}'`
  hits_per_sec=`echo $hits | awk -F ":" '{print $2}' | awk -F "," '{print $2}' | awk -F "/" '{print $1}' | awk '{print $1}'`
  echo "Users: $users Total-Hits: $total_hits Hits-per-sec: $hits_per_sec"
  line_total_hits="$users,$total_hits"
  line_hits_per_sec="$users,$hits_per_sec"
  echo $line_total_hits >> route-total-hits-temp
  echo $line_hits_per_sec >> route-hits-per-sec-temp
done
  
sort -t',' -k1 route-total-hits-temp >> route-total-hits
sort -t',' -k1 route-hits-per-sec-temp >> route-hits-per-sec

header="users,total-hits"
echo $header >> results-routerperf-total-hits.csv
while read line; do
  echo $line >> results-routerperf-total-hits.csv
done < route-total-hits

header="users,hits-per-sec"
echo $header > results-routerperf-hits-per-sec.csv
while read line; do
  echo $line >> results-routerperf-hits-per-sec.csv
done < route-hits-per-sec

echo "Copying the results to the analyzer input folder"
cp results-routerperf-total-hits.csv /root/svt/application_performance/osperf-analyzer/input/results-routerperf-total-hits.csv
cp results-routerperf-hits-per-sec.csv /root/svt/application_performance/osperf-analyzer/input/results-routerperf-hits-per-sec.csv

rm -rf route-*
mkdir tests-results
mv mb-* tests-results
mv results-* tests-results

echo "Running maven to generate the graphs for the results"
cd /root/svt/application_performance/osperf-analyzer
mvn clean compile
mvn test
sleep 10
cp -a results /var/lib/pbench-agent/tests-results

echo "Copying the results to the pbench server"
sleep 5
pbench-copy-results
echo "### END ROUTE TESTS  ##"