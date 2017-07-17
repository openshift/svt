#!/bin/bash

### check if the desired version of logging/metrics is ready for test

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

check_registry

# TODO metrics