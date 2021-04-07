#!/bin/bash
#number or projects (default 100)
basename=svt-overload
num_of_projects=100

# for multiple_objects is a number you want to multiple specific objects in template
# Default - for multiple_objects=1 will create for each project:
# 10 pods
# 5 routes
# 10 services
# 5 network policies
multiple_objects=1

# Loading pods
oc project default
python cluster-loader.py -f config/overload.yaml
oc label ns -l purpose=test purpose=stay --overwrite

# Loading routes
for i in $(seq 0 $((num_of_projects-1))); do
  for j in $(seq 0 $((multiple_objects-1))); do
    oc process -f content/routes-with-name-template.json -p NAME=$basename$i -p IDENTIFIER=$j | oc create -n $basename$i -f -
    sleep 0.1
  done
done

# Loading services
for i in $(seq 0 $((num_of_projects-1))); do
  for j in $(seq 0 $((multiple_objects-1))); do
    oc process -f content/service-with-name-template.json -p NAME=$basename$i -p IDENTIFIER=$j | oc create -n $basename$i -f -
    sleep 0.1
  done
done

# Loading Network Policies
for i in $(seq 0 $((num_of_projects-1))); do
  for j in $(seq 0 $((multiple_objects-1))); do
    oc process -f content/networkpolicy-with-name-template.json -p NAME=$basename$i -p IDENTIFIER=$j | oc create -n $basename$i -f -
    sleep 0.1
  done
done
