#!/bin/bash
###############################################################
## Auth=vlaad@redhat.com
## Desription: Test readiness of cluster for reliability tests.
###############################################################

# An error exit function
function error_exit
{
  echo "$1" 1>&2
  exit 1
}


echo "create ruby app"
oc new-project p1
oc new-app -f https://raw.githubusercontent.com/openshift/svt/master/reliability/ruby-helloworld-sample.json

counter=0
while true;
do
  STATUS=$(oc status -n p1)
  if [[ ! $STATUS =~ .*deployment.*waiting.*on.*image.*or.*update.* && ! $STATUS =~ .*deployment.*running.*for.* && ! $STATUS =~ .*deployment.*pending.*ago.* ]]
  then
    echo "ruby app deployment complete"
    break
  fi

  if [[ $counter == 16 ]]
  then
    error_exit "Ruby app took more then 4 mins to deploy"
  fi
  ((counter++))

  sleep 15
done
content=$(curl -k https://$(oc get routes -n p1 --no-headers | awk '{print$2}'))

echo $content | grep "Welcome to an OpenShift v3 Demo App!"
if [[ $? -ne 0 ]]
then
  error_exit "Error accessing Ruby app"
else
  echo "Success ==================Ruby app deployed and accessed==================="
fi
oc delete project p1

echo "create dancer-mysql app"
oc new-project p2
oc new-app --template=dancer-mysql-example

counter=0
while true;
do
  STATUS=$(oc status -n p2)
  if [[ ! $STATUS =~ .*deployment.*waiting.*on.*image.*or.*update.* && ! $STATUS =~ .*deployment.*running.*for.* && ! $STATUS =~ .*deployment.*pending.*ago.* ]]
  then
    echo "dancer app deployment complete"
    break
  fi

  if [[ $counter == 20 ]]
  then
    error_exit "Dancer app took more then 4 mins to deploy"
  fi
  ((counter++))

  sleep 15
done

content=$(curl -k http://$(oc get routes -n p2 --no-headers | awk '{print$2}'))

echo $content | grep "Page view count"
if [[ $? -ne 0 ]]
then
  echo "Error accessing dancer app"
else
  echo "Success ==================Dancer app deployed and accessed==================="
fi
oc delete project p2

echo "create cakephp-mysql app"
oc new-project p3
oc new-app --template=cakephp-mysql-example

counter=0
while true;
do
  STATUS=$(oc status -n p3)
  if [[ ! $STATUS =~ .*deployment.*waiting.*on.*image.*or.*update.* && ! $STATUS =~ .*deployment.*running.*for.* && ! $STATUS =~ .*deployment.*pending.*ago.* ]]
  then
    echo "cakephp app deployment complete"
    break
  fi

  if [[ $counter == 16 ]]
  then
    error_exit "cakephp app took more then 4 mins to deploy"
  fi
  ((counter++))

  sleep 15
done

content=$(curl -k http://$(oc get routes -n p3 --no-headers | awk '{print$2}'))

echo $content | grep "Page view count"
if [[ $? -ne 0 ]]
then
  error_exit "Error accessing cakephp app"
else
  echo "Success ==================cakephp app deployed and accessed==================="
fi
oc delete project p3

echo "create eap-mysql app"
oc new-project p4
oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/master/secrets/eap-app-secret.json
oc new-app --template=eap64-mysql-s2i

counter=0
while true;
do
  STATUS=$(oc status -n p4)
  if [[ ! $STATUS =~ .*deployment.*waiting.*on.*image.*or.*update.* && ! $STATUS =~ .*deployment.*running.*for.* && ! $STATUS =~ .*deployment.*pending.*ago.* ]]
  then
    echo "eap app deployment complete"
    break
  fi

  if [[ $counter == 30 ]]
  then
    error_exit "eap app took more then 6 mins to deploy"
  fi
  ((counter++))

  sleep 15
done

content=$(curl -k http://$(oc get routes -n p4 --no-headers | grep -v secure | awk '{print$2}'))

echo $content | grep "TODO list"
if [[ $? -ne 0 ]]
then
  error_exit "Error accessing eap app"
else
  echo "Success ==================eap app deployed and accessed==================="
fi

oc delete project p4

echo "######################### SUCCESS : COMPLETE ##########################"
