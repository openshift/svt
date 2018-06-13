#!/bin/bash
###############################################################
## Auth=vlaad@redhat.com
## Desription: Test readiness of cluster for reliability tests.
###############################################################

projects=("cakephp" "eap" "dancer" "ruby" "django" "nodejs")
page_text=("count-value" "TODO list" "count-value" "Welcome to your Rails application on OpenShift" "Page views" "count-value")

# An error exit function
function error_exit
{
  echo "$1" 1>&2
  exit 1
}

function wait_for_deployment
{
  counter=0
  while true;
  do
    all_deployed=1

    for var in {0..5}
    do
      proj=${projects[$var]}
      STATUS=$(oc status -n $proj)
      if [[ ! $STATUS =~ .*deployment.*waiting.*on.*image.*or.*update.* && ! $STATUS =~ .*deployment.*running.*for.* && ! $STATUS =~ .*deployment.*pending.*ago.* ]]
      then
        echo "$proj app deployment complete"
        echo "$proj app deployment complete" >> test_cluster.out
      else
	all_deployed=0
	echo "$proj deployment not complete, waiting..."
        echo "$proj deployment not complete, waiting..." >> test_cluster.out
      fi
    done

    if [ $all_deployed -eq 1 ]
    then
      break
    fi

    if [[ $counter == 30 ]]
    then
      echo "Apps took more then expected to deploy" >> test_cluster.out 
      error_exit "Apps took more then expected to deploy"
    fi
    ((counter++))
    sleep 15

  done
}

function access_applications
{
  all_accessed=1
  for var in {0..5}
  do
    proj=${projects[$var]}
    text=${page_text[$var]}
    content=$(curl -k http://$(oc get routes -n $proj --no-headers | awk '{print$2}'))
    echo $content | grep "$text"
    if [[ $? -ne 0 ]]
    then
      echo "error accessing $proj app"
      echo "error accessing $proj app" >> test_cluster.out
      all_accessed=0
    else
      echo "$proj app accessed"
      echo "$proj app accessed" >> test_cluster.out
    fi
  done

  if [ $all_accessed -eq 0 ]
  then
    error_exit "App access failed"
  fi
}

if [ "${1}" == "access" ]; then
  access_applications
  echo "######################### SUCCESS : COMPLETE ##########################"
  exit
fi

oc new-project cakephp
oc label namespace cakephp --overwrite purpose=rel 
oc new-app --template=cakephp-mysql-example    
oc new-project eap
oc label namespace eap --overwrite purpose=rel
oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/master/secrets/eap-app-secret.json
oc create -f /root/svt/reliability/eap-secret.json
oc new-app --template=eap64-mysql-s2i
oc new-project dancer
oc label namespace dancer --overwrite purpose=rel
oc new-app --template=dancer-mysql-example
oc new-project ruby
oc label namespace ruby --overwrite purpose=rel
oc new-app --template=rails-postgresql-example
oc new-project django
oc label namespace django --overwrite purpose=rel
oc new-app --template=django-psql-example
oc new-project nodejs
oc label namespace nodejs --overwrite purpose=rel
oc new-app --template=nodejs-mongodb-example

wait_for_deployment
access_applications

oc project default
echo "######################### SUCCESS : COMPLETE ##########################"
