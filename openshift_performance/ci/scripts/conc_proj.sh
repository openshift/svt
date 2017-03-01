#/!/bin/bash
#set -x
################################################
## Auth=vlaad@redhat.com
## Desription: Script for running concurrent 
## projects test.
################################################

function wait_for_project_termination()
{
  terminating=`oc get projects | grep Terminating | wc -l`
    while [ $terminating -ne 0 ]; do
    sleep 5
    terminating=`oc get projects | grep Terminating | wc -l`
    echo "$terminating projects are still terminating"
  done
}


old_i=1
sed -i "s/num: .*/num: 1/g" ../content/conc_proj.yaml
rm -rf ./conc_proj.out
echo "#of Projects,Time (Sec)" >> conc_proj.out

for i in 1 5 10 20 40 60 80 100 120 140
do
  sed -i "s/num: $old_i/num: $i/g" ../content/conc_proj.yaml

  echo "Creating $i projects"
  start_time=`date +%s`
  python ../../../openshift_scalability/cluster-loader.py -p $i -f ../content/conc_proj.yaml
  stop_time=`date +%s`

  total_time=`echo $stop_time - $start_time | bc`
  echo "Time taken for creating $i concurrent projects : $total_time"
  echo "$i,$total_time" >> conc_proj.out

  echo "Deleting $i projects"
  oc delete project -l purpose=test

  wait_for_project_termination
  old_i=$i
done

cat conc_proj.out
