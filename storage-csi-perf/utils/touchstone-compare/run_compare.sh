#!/usr/bin/env bash
datasource="elasticsearch"
_es=${ES_SERVER:-https://search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com:443}
_es_baseline=${ES_SERVER_BASELINE:-https://search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com:443}
tool=${1}

python3 -m venv ./venv
source ./venv/bin/activate
set -x
git clone https://github.com/cloud-bulldozer/benchmark-comparison
ln -s benchmark-comparison/config config
ln -s benchmark-comparison/tolerancy-configs tolerancy-configs
set +x
pip3 install benchmark-comparison/.

if [[ $? -ne 0 ]] ; then
  echo "Unable to execute compare - Failed to install touchstone"
  exit 1
fi

set -x
if [[ ${COMPARE_WITH_GOLD} == "true" ]] || [[ ${COMPARE} == "true" ]]; then
  echo "Comparing"
  echo "baseline gold uuid: ${2} current run uuid: ${3}"
  touchstone_compare --database elasticsearch -url $_es_baseline $_es -u ${2} ${3} -o yaml --config config/${tool}.json | grep -v "ERROR"| tee compare_output_${!#}.yaml
else
  touchstone_compare --database elasticsearch -url $_es -u ${2} -o yaml --config config/${tool}.json | grep -v "ERROR"| tee compare_output_${!#}.yaml
fi
set +x

if [[ $? -ne 0 ]] ; then
  echo "Unable to execute compare - Failed to run touchstone"
  exit 1
fi

deactivate
rm -rf venv benchmark-comparison config tolerancy-configs
