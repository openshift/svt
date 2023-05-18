#!/usr/bin/env bash
export LC_ALL=en_US.utf-8
export LANG=en_US.utf-8

python3 -m pip install --user pipx
export PATH="${PATH}:$(python3 -c 'import site; print(site.USER_BASE)')/bin"

export file_path=$1
export SNAPPY_FILE_DIR=$2

pipx install git+https://github.com/cloud-bulldozer/data-server-cli.git  --force
snappy install

if [[ $? -ne 0 ]] ; then
  echo "Unable to backup data... Failed to install snappy!"
  exit 1
fi

if [[ $SNAPPY_DATA_SERVER_URL == "" ]] ; then
  echo "... Exiting.... Snappy data server path not defined! "
  exit 1
fi

if [[ $SNAPPY_DATA_SERVER_USERNAME == "" ]] ; then
  echo "... Exiting.... Snappy data server username not defined! "
  exit 1
fi

if [[ $SNAPPY_DATA_SERVER_PASSWORD == "" ]] ; then
  echo "... Exiting.... Snappy data server password not defined! "
  exit 1
fi

export DATA_SERVER_URL=$SNAPPY_DATA_SERVER_URL
export DATA_SERVER_USERNAME=$SNAPPY_DATA_SERVER_USERNAME
export DATA_SERVER_PASSWORD=$SNAPPY_DATA_SERVER_PASSWORD

set -x
snappy script-login
echo "Trying to store data at ${SNAPPY_FILE_DIR}"
snappy post-file $file_path --filedir $SNAPPY_FILE_DIR
set +x

if [[ $? -ne 0 ]] ; then
  echo "Unable to backup data - Failed to run Snappy!"
  exit 1
fi

