#!/bin/bash

set -eo pipefail

url=$1
dir=/tmp/prometheus
prometheus_url=https://github.com/prometheus/prometheus/releases/download/v2.7.1/prometheus-2.7.1.linux-amd64.tar.gz

if  [[ "$#" -ne 1 ]]; then
	echo "Syntax: $0 <db_tarball_url>"
	exit 1
fi

# create prometheus dir
rm -rf $dir || true
mkdir $dir

# download prometheus
wget -q $prometheus_url -O /tmp/prometheus_server.tar.gz 
tar xf /tmp/prometheus_server.tar.gz -C /tmp && mv /tmp/prometheus*/prometheus /usr/local/bin && mv /tmp/prometheus*/prometheus.yml $dir/prometheus.yml

# download the prometheus results tarball
curl $1 | tar xvJf - -C $dir
echo "open http://localhost:9090 to look at the captured metrics"
/usr/local/bin/prometheus --storage.tsdb.path=$dir --config.file $dir/prometheus.yml --storage.tsdb.retention=1y
