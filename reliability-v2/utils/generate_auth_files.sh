#/!/bin/bash
################################################
## Author: qili@redhat.com
## Description: Script to generate authentication files to run reliability-v2 test
## For rosa cluster installed by Prow: Export CLUSTER_ID, OCM_TOKEN and OCM_ENV
## For Flexy-install cluster: Export AUTH_PATH which includes kubeconfig, users.spec and kubeadmin-password files that
## downloaded from the Build Artifacts of the Flexy-install job.
## For rosa cluster installed by Prow: Export TOKEN, SERVER, and PROJECT(optional)
## For cluster installed by other ways: export KUBECONFIG_PATH.
################################################

function _usage {
    cat <<END
Usage: $(basename "${0}")
If this is a cluster provisioned by Flexy-install Jenkins job, export AUTH_PATH as the path includes kubeconfig, users.spec and kubeadmin-password files downloaded from the Flexy-install job.
If this is a rosa cluster provisioned by ocm-profile-ci Jenkins job, export the CLUSTER_ID get from the console output of the Jenkins job. 
And export the OCM_TOKEN of the ocm account, get it from "perfscale-rosa-token" in bitwarden.
And export OCM_ENV as staging or production.
If this is a rosa cluster provisioned in Prow CI, export TOKEN and SERVER get from the Prow CI's job. If there are multiple projects after login, also export PROJECT.
If this is a cluster provisioned by other ways, export KUBECONFIG_PATH as the file path of the kubeconfig file.
END
}

export IDP_USER_COUNT=${IDP_USER_COUNT:-50}

function create_idp_users_rosa {
    # create IDP users
    IDP_ID=$(ocm get "/api/clusters_mgmt/v1/clusters/${CLUSTER_ID}/identity_providers" --parameter search="type is 'HTPasswdIdentityProvider'" | jq -r '.items[].id' | head -n 1)
    user_count=$1
    # Generate IDP users 
    echo "Generating $user_count IDP users under the htpasswd idp ...."
    users=""
    for i in $(seq 1 ${user_count});
    do
        username="testuser-${i}"
        password="HTPasswd_$(echo $RANDOM | md5sum | cut -c 1-8)"
        users+="${username}:${password},"
        payload='{"username": "'${username}'","password": "'${password}'"}'
        echo "${payload}" | jq -c | ocm post "/api/clusters_mgmt/v1/clusters/${CLUSTER_ID}/identity_providers/${IDP_ID}/htpasswd_users" >> create_idp_users_rosa.log 2>&1
    done
    grep 'Error' create_idp_users_rosa.log > /dev/null
    if [[ $? -eq 0 ]]; then
        echo "Error happened during create_idp_users_rosa, please check path_to_auth_files/create_idp_users_rosa.log."
        exit 1
    fi
    echo "users file is created"
    echo "${users}" > "users"
}

if [[ "$1" = "-h" ]];then
    _usage
    exit 1
fi

if [[ ! -z $CLUSTER_ID && ! -z $OCM_TOKEN && ! -z $OCM_ENV ]]; then
    echo "CLUSTER_ID, OCM_TOKEN and OCM_ENV are provided for ocm-profile-ci Jenkins job provisioned rosa cluster."
    type="rosa"
elif [[ ! -z $TOKEN && ! -z $SERVER ]]; then
    echo "TOKEN and SERVER are provided for Prow provisioned rosa cluster."
    type="rosa-prow"
elif [[ ! -z $AUTH_PATH ]]; then
    echo "AUTH_PATH is provided for Flexy-install Jenkins job provisioned cluster."
    type="flexy"
elif [[ ! -z $KUBECONFIG_PATH ]]; then
    echo "KUBECONFIG_PATH is provided."
    type="other"
else
    _usage
    exit 1
fi

# checking ocm cli
echo "Checking ocm cli"
ocm version > /dev/null
if [[ $? != 0 ]]; then
    echo "ocm cli not found. Please install it from https://console.redhat.com/openshift/downloads"
    exit 1
fi

# checking roca cli
echo "Checking rosa cli"
rosa version > /dev/null
if [[ $? != 0 ]]; then
    echo "rosa cli not found. Installing rosa cli..."
    wget https://mirror.openshift.com/pub/openshift-v4/clients/rosa/latest/rosa-linux.tar.gz
    tar xvf rosa-linux.tar.gz
    sudo mv rosa /usr/bin/rosa
    sudo chmod u+x /usr/bin/rosa
    rosa completion bash | sudo tee /etc/bash_completion.d/rosa
    rosa version
    echo "Checking oc cli"
    oc version --client > /dev/null
    if [[ $? != 0 ]]; then
        echo "oc cli not found. Installing oc cli..."
        rosa download openshift-client
        tar xvf openshift-client-linux.tar.gz
        sudo mv oc /usr/local/bin/oc
        rosa verify openshift-client
    fi
fi

rm -rf path_to_auth_files
mkdir path_to_auth_files

utils_dir=$(cd $(dirname ${BASH_SOURCE[0]});pwd)

if [[ $type == "rosa" ]]; then
    cd path_to_auth_files
    # Log in
    rosa login --env $OCM_ENV --token $OCM_TOKEN
    if [[ $? -ne 0 ]]; then
        echo "rosa login failed"
        exit 1
    fi
    # Create admin user
    echo "Creating admin user ...."
    rosa create admin -c $CLUSTER_ID > admin.out
    # Generate the admin users files
    if [[ -s admin.out ]]; then
        login_cmd=$(cat admin.out| grep "oc login")
        if [[ x"$login_cmd" == x ]]; then
            echo "login_cmd failed."
            exit 1
        fi
        echo $login_cmd | awk '{print $5":"$7}' > admin && rm admin.out && echo "admin file is created"
    else
        echo "rosa create admin cmd failed."
        exit 1
    fi

    echo "Waiting for admin user login and generate kubeconfig ...."
    login_cmd=$login_cmd" --insecure-skip-tls-verify=true --kubeconfig=kubeconfig"
    start_time=$(date +"%s")
    while true; do
        sleep 60
        eval $login_cmd > admin_login_out || true
        if [[ $(cat admin_login_out) =~ "Login successful" ]]; then
            echo "admin user login successfully and kubeconfig file is created."
            rm admin_login_out
            break
        fi

        if (( $(date +"%s") - $start_time >= 600 )); then
            echo "error: Timed out while waiting for the htpasswd idp to be ready for login"
            exit 1
        fi
    done

    create_idp_users_rosa $IDP_USER_COUNT

elif [[ $type == "rosa-prow" ]]; then
    cd path_to_auth_files
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
    cd path_to_auth_files
    cp $AUTH_PATH/kubeconfig kubeconfig
    echo "kubeadmin":$(cat $AUTH_PATH/kubeadmin-password) > admin
    cp $AUTH_PATH/users.spec users
elif [[ $type == "other" ]]; then
    cd path_to_auth_files
    cp $KUBECONFIG_PATH kubeconfig
    # code to generate users file to be added later
fi

echo "The credential files for reliability test are created under folder path_to_auth_files."
