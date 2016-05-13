#!/usr/bin/env bash


# fio_smallfile_ose.sh will do a) get dockerfile, and b) build docker image and c) run smallfile and fio IO test inside pod
# on OSE
podname="r7perf"
testtype="fio"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        printf "you have to be root to run script\n"
        exit 0
    fi
}

usage() {
        printf "Usage: ./$(basename $0) -p podname -t testtype\n"
        printf "Supported tests are : fio or smallfile\n"
        printf "fio test example:  "$0" -p r7perf -t fio\n"
        printf "smallfile test example: "$0" -p r7perf -t smallfile\n"
        printf "defaults are podname $podname and testtype $testtype\n"
        exit 0
}

opts=$(getopt -q -o p:t:h --longoptions "podname:,testtype:,help" -n "getopt.sh" -- "$@");
eval set -- "$opts";
echo "processing options"
while true; do
    case "$1" in
        -p|--podname)
            shift;
            if [ -n "$1" ]; then
                podname="$1"
                shift;
            fi
        ;;
        -t|--testtype)
            shift;
            if [ -n "$1" ]; then
                testtype="$1"
                shift;
            fi
        ;;

        -h|--help)
            usage
        ;;
        --)
            shift
            break;
        ;;
        *)
            shift
            break;
        ;;
    esac
done
create_docker_image() {
cat <<EOF >/root/$podname.yml
apiVersion: v1
kind: Pod
metadata:
      name: $podname
spec:
  containers:
  - image: $podname
    name: $podname
    securityContext:
      privileged: False
      command:
      - /usr/bin/init
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - mountPath: "/perf1"
      name: perf1
  volumes:
    - name: perf1
      hostPath:
        path: /perf1
EOF
    # ensure docker has access to example.com

    if docker images | awk '{ print $1 }'  | grep -v REP | grep $podname; then
        printf "image $podname is present ... we will not build it again\n"
    else
        printf "image $podname is not present ... we will build it now\n"
        printf "docker build will pull rhel-tools images from example.com - ensure build machine can reach it\n"
        curl -o /root/Dockerfile http://example.com/git/perf-dept.git/plain/docker/Dockerfiles/Dockerfile_rtp
cat <<EOF >>/etc/sysconfig/docker
INSECURE_REGISTRY='--insecure-registry example.com'
EOF
        systemctl restart docker
        docker build -t $podname - < /root/Dockerfile
    fi
}

# we want to build pod after every test - so we delte it after test

smallfile() {
    oc create -f /root/$podname.yml
    printf "pod created ...waiting 20 sec\n"
    sleep 20
    printf "running smallfile test\n"
    oc exec $podname -- /root/perf-dept/etest/perf-guide-test/rhel_atomic_fio.sh -a ose -f smallfile_test_OSE -t smallfile --files 20000 --label smallfile_test_OSE --mprefix smallfile_test_OSE
    printf "smallfile finished...sleeping 60 sec\n" ; sleep 60
    oc delete pod $podname; sleep 30
}
fio () {
    oc create -f /root/$podname.yml
    printf "running FIO tests... \n"; sleep 30
    oc exec $podname -- /root/perf-dept/etest/perf-guide-test/rhel_atomic_fio.sh -a ose -f fio_test_OSE -t fio --label fio_test_OSE --mprefix fio_test_OSE
    printf "fio test finished... sleep 30s\n" ; sleep 30
    oc delete pod $podname; sleep 30
}
# main
case "$testtype" in
    fio)
        create_docker_image
        printf "running fio test...\n"
        fio
    ;;
    smallfile)
        create_docker_image
        printf "running smallfile test...\n"
        smallfile
    ;;
    all)
        printf "running both: fio and smallfile - it will take some time to finish\n"
        create_docker_image
        fio
        smallfile
    ;;
esac

