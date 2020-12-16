#!/bin/bash

vars_file='external_vars.yaml'
output_file="mongodb.out"
rm $output_file
mongodb_version=$(cat $vars_file | grep MONGODB_VERSION | cut -d ' ' -f 2)

if [[ $mongodb_version == "latest" ]]; then
  mongo_image=$(oc get imagestreams -A | grep mongo)
  version=""
  for image in $mongo_image; do
    echo "$image"
    #strip out number
    if [[ $image == *"latest"* ]]; then
      echo "lateset here"
      version=$(echo "$image" | cut -d',' -f 1)
      echo "$version"
    fi
  done
  python -c "import rewrite_external_vars; rewrite_external_vars.replace_value_in_file('$vars_file','MONGODB_VERSION',${version})"
fi

project_array=(5 8 10)
iteration_array=(40 25 20)
for i in "${!project_array[@]}"; do
  python -c "import rewrite_external_vars; rewrite_external_vars.replace_value_in_file('$vars_file','test_project_number',${project_array[$i]})"
  python -c "import rewrite_external_vars; rewrite_external_vars.replace_value_in_file('$vars_file','iteration',${iteration_array[$i]})"
  mongo_output=$(./runmongo.sh)
  echo "Project num: ${project_array[$i]}; iteration num: ${iteration_array[$i]}" >> $output_file
  echo -e $mongo_output | grep "Total[[:space:]]load" >> $output_file
  echo -e $mongo_output | grep "Total[[:space:]]run" >> $output_file
done

cat $output_file