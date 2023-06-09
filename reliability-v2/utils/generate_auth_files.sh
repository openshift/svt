#/!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Script to generate authentication files to run reliability-v2 test
## For rosa cluster installed by Prow: Export TOKEN, SERVER, and PROJECT(optional)
## For Flexy-install cluster: Export AUTH_PATH which includes kubeconfig, users.spec and kubeadmin-password files that
## downloaded from the Build Artifacts of the Flexy-install job.
## For cluster installed by other ways: export KUBECONFIG_PATH.
################################################

function _usage {
    cat <<END
Usage: $(basename "${0}")
If this is a rosa cluster provisioned in Prow CI, export TOKEN and SERVER get from the Prow CI's job. If there are multiple projects after login, also export PROJECT.
If this is a cluster provisioned by Jenkins Flexy-install job, export AUTH_PATH as the path includes kubeconfig, users.spec and kubeadmin-password files downloaded from the Flexy-install job.
If this is a cluster provisioned by other ways, export KUBECONFIG_PATH as the file path of the kubeconfig file.
END
}

if [[ "$1" = "-h" ]];then
    _usage
    exit 1
fi

if [[ ! -z $TOKEN && ! -z $SERVER ]]; then
    echo "TOKEN and SERVER are provided for Prow provisioned rosa cluster."
    type="rosa"
elif [[ ! -z $AUTH_PATH ]]; then
    echo "AUTH_PATH is provided for Flexy-install cluster."
    type="flexy"
elif [[ ! -z $KUBECONFIG_PATH ]]; then
    echo "KUBECONFIG_PATH is provided."
    type="other"
else
    _usage
    exit 1
fi

rm -rf path_to_auth_files
mkdir path_to_auth_files && cd path_to_auth_files

if [[ $type == "rosa" ]]; then
    # For rosa cluster installed by Prow
    oc login --token=$TOKEN --server=$SERVER
    if [[ ! -z $PROJECT ]]; then
        oc project $PROJECT
    fi
    pod=$(oc get pods --no-headers | grep 'perfscale-wait' | awk '{print $1}')
    oc rsh $pod cat /tmp/secret/kubeconfig > kubeconfig && echo "kubeconfig file is created"
    oc rsh $pod cat /tmp/secret/api.login > admin.out
    # SHARED_DIR=$(oc rsh $pod env | grep SHARED_DIR | cut -d '=' -f 2)
    SHARED_DIR='/var/run/secrets/ci.openshift.io/multi-stage'
    oc rsh $pod cat ${SHARED_DIR}/runtime_env > users.out

    cat admin.out| awk '{print $5":"$7}' > admin && rm admin.out && echo "admin file is created"
    cat users.out | cut -d "=" -f 2 > users && rm users.out && echo "users file is created"
elif [[ $type == "flexy" ]]; then
    cp $AUTH_PATH/kubeconfig kubeconfig
    echo "kubeadmin":$(cat $AUTH_PATH/kubeadmin-password) > admin
    cp $AUTH_PATH/users.spec users
elif [[ $type == "other" ]]; then
    cp $KUBECONFIG_PATH kubeconfig
    # code to generate users file to be added later
fi

echo "Find the credential files for reliability test in path_to_auth_files"
