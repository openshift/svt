#!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Script to upgrade cluster
## Parameters: $1: Target build to upgrade to
## Config kubeconfig before running the script
################################################
set -e

# $1 info/debug, $2 log message
function log {
    green="\033[0;32m"
    end="\033[0m"
    current_date=$(date "+%Y%m%d %H:%M:%S")
    log_level=$(echo $1 | tr '[a-z]' '[A-Z]')
    echo "${green}[$current_date][$log_level] $2${end}"
}

log "info" "Getting current cluster version"
oc get clusterversion
current_version=$(oc get clusterversion --no-headers | awk '{print $2}')
release_y=$(echo $current_version | cut -d '.' -f 2)

log "info" "Fetching latest accepted nightly build for this release"
latest_accepted_nightly_build=$(curl -sSL https://amd64.ocp.releases.ci.openshift.org | \
grep -B1 'Accepted' | grep 4.$release_y.0-0.nightly | \
awk -F '/release/' '{print $2}' | awk -F '">' '{print $1}' | \
head -n 1)
log "info" "Latest nightly build: $latest_accepted_nightly_build"

if [[ $latest_accepted_nightly_build == $current_version ]]; then
    log "info" "The latest accepted nightly build is same as current build, skip upgrade."
else
    if [[ ! -d ocp-qe-perfscale-ci ]]; then
        log "info" "Cloning upgrade branch of ocp-qe-perfscale-ci repo"
        git clone -b upgrade git@github.com:openshift-eng/ocp-qe-perfscale-ci.git
    fi
    cd ocp-qe-perfscale-ci/upgrade_scripts
    log "info" "Preparing venv"
    python3 --version
    python3 -m venv upgrade_venv 
    source upgrade_venv/bin/activate
    pip --version
    pip install --upgrade pip
    pip install -U datetime pyyaml
    ./upgrade.sh $latest_accepted_nightly_build
fi


