#!/bin/bash

echo "001 $(date)"

if [ "$#" -ne 2 ]; then
    echo "need the path of tmp folder and STORAGE_CLASS_NAME"
    exit 1
fi

readonly TMP_FOLDER=$1
readonly STORAGE_CLASS_NAME=$2

### pbench-register runs before the test is started if necessary

echo "002 $(date)"

readonly CLIENT_HOSTS_COMMA=$(oc get pod --all-namespaces -o wide --no-headers | grep Running | grep fio | awk '{print $7}' | awk 'BEGIN { ORS = " " } { print }' |  tr " " ,)

readonly CLIENT_HOSTS="${CLIENT_HOSTS_COMMA::-1}"

echo "CLIENT_HOST ${CLIENT_HOSTS}"

#pbench-fio --test-types=read --clients="${CLIENT_HOSTS}" --config="SEQ_IO_${STORAGE_CLASS_NAME}" --samples=1 --max-stddev=20 --block-sizes=4 --job-file="${TMP_FOLDER}/config/sequential_io.job" --pre-iteration-script="${TMP_FOLDER}/scripts/drop-cache.sh"

pbench-fio --test-types=read,write,rw --clients="${CLIENT_HOSTS}" --config="SEQ_IO_${STORAGE_CLASS_NAME}" --samples=1 --max-stddev=20 --block-sizes=4,16,64 --job-file="${TMP_FOLDER}/config/sequential_io.job" --pre-iteration-script="${TMP_FOLDER}/scripts/drop-cache.sh"

echo "003 $(date)"

pbench-fio --test-types=randread,randwrite,randrw --clients="${CLIENT_HOSTS}" --config="RAND_IO_${STORAGE_CLASS_NAME}" --samples=1 --max-stddev=20 --block-sizes=4,16,64 --job-file="${TMP_FOLDER}/config/random_io.job" --pre-iteration-script="${TMP_FOLDER}/scripts/drop-cache.sh"

echo "pbench-copy-results: $(date)"

pbench-copy-results
