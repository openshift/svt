function delete_projects()
{
  echo "deleting projects"
  oc delete project -l purpose=test
}

function wait_for_project_termination()
{
  terminating=`oc get projects | grep Terminating | wc -l`
  while [ $terminating -ne 0 ]; do
  sleep 5
  terminating=`oc get projects | grep Terminating | wc -l`
  echo "$terminating projects are still terminating"
  done
}

start_time=`date +%s`

delete_projects
wait_for_project_termination

stop_time=`date +%s`
total_time=`echo $stop_time - $start_time | bc`
echo "Deletion Time - $total_time"
