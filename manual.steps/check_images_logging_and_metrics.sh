#!/bin/bash

### check if the desired version of logging/metrics is ready for test
### require jq command: 'yum install jq' if command not found

function print_usage {
  echo "usage: $0 <version>"
  echo "eg, $0 v3.6.144"
}

if [ "$#" -ne 1 ]; then
  print_usage
  exit 1
fi

readonly DATE="$(date +%Y-%m-%dT%H:%M:%S)"
echo ${DATE}

readonly IMAGE_VERSION=$1

function check_brew_one(){
  local image
  image=$1
  local version
  version=$2
  while read version_on_server;
  do
    if [[ "${IMAGE_VERSION}" == "${version_on_server}" ]]; then
      echo "VVV:image $image version $version found in brew."
      return
    fi
  done << EOF
$(curl -s -k brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888/v1/repositories/openshift3/${image}/tags | jq 'keys' | jq -r .[] | grep ${version})
EOF
  echo "XXX:image $image version $version not found in brew!"
}


function check_brew() {
  for image in "${logging_image_array[@]}"
  do
    check_brew_one "${image}" "${IMAGE_VERSION}"
  done
}

function check_registry_one(){
  local image
  image=$1
  local version
  version=$2
  local http_response_code
  http_response_code="$(curl -L --write-out %{http_code} --silent --output /dev/null https://registry.ops.openshift.com/v2/openshift3/${image}/manifests/${version})"
  if [[ "${http_response_code}" == "2"* ]]; then
    echo "VVV:image $image version $version found in registry."
  else
    echo "XXX:image $image version $version not found in registry!"
  fi
}

function check_registry() {
  for image in "${logging_image_array[@]}"
  do
    check_registry_one "${image}" "${IMAGE_VERSION}"
  done
}

# logging-mux uses "logging-fluentd" image
declare -a logging_image_array=("logging-kibana" "logging-curator" "logging-elasticsearch" "logging-fluentd")

ping -q -c 1 brew-pulp-docker01.web.prod.ext.phx2.redhat.com > /dev/null

if [[ $? -eq 0 ]]; then
  check_brew
else
  echo "skip check_brew"
fi

check_registry

# TODO metrics