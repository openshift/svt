#!/bin/bash
###########################################################################################################
## Auth=skordas@redhat.com
## Desription: Script to toggle between encryption and decryption of cluster.
## Polarion test case: OCP-26194 - Compare project loading time with etcd-encryption enabled and disabled
## https://polarion.engineering.redhat.com/polarion/#/project/OSE/workitem?id=OCP-26194
## Cluster config: default
## Usage: ./toggle_encryption.sh <enable/disable> <timeout_in_minutes>
## To enable: ./toggle_encryption.sh enable 50
## To disable: ./toggle_encryption.sh disable 50
###########################################################################################################

function log {
    echo -e "$*"
}

# Setting variables and names of new created secrets.
mode=""
timeout=$(($2 * 60))
## Temporary files to store secrets
OC_SECRET="/tmp/openshift-apiserver-secret.yaml"
KB_SECRET="/tmp/openshift-kube-apiserver-secret.yaml"
OAUTH_SECRET="/tmp/openshift-oauth-apiserver-secret.yaml"
OC_MIGRATED_RESOURCES="'{\"resources\":[{\"Group\":\"route.openshift.io\",\"Resource\":\"routes\"}]}'"
## Resources A and B are the the same json objects, but look different as a strings (in check_secret I'm comparing string from yaml)
KB_MIGRATED_RESOURCES_A="'{\"resources\":[{\"Group\":\"\",\"Resource\":\"configmaps\"},{\"Group\":\"\",\"Resource\":\"secrets\"}]}'"
KB_MIGRATED_RESOURCES_B="'{\"resources\":[{\"Group\":\"\",\"Resource\":\"secrets\"},{\"Group\":\"\",\"Resource\":\"configmaps\"}]}'"
OAUTH_MIGRATED_RESOURCES_A="'{\"resources\":[{\"Group\":\"oauth.openshift.io\",\"Resource\":\"oauthaccesstokens\"},{\"Group\":\"oauth.openshift.io\",\"Resource\":\"oauthauthorizetokens\"}]}'"
OAUTH_MIGRATED_RESOURCES_B="'{\"resources\":[{\"Group\":\"oauth.openshift.io\",\"Resource\":\"oauthauthorizetokens\"},{\"Group\":\"oauth.openshift.io\",\"Resource\":\"oauthaccesstokens\"}]}'"
## Getting number of existing secrets.
oc_secrets_num=$(oc get secrets -n openshift-config-managed | grep -c encryption-key-openshift-apiserver)
kb_secrets_num=$(oc get secrets -n openshift-config-managed | grep -c encryption-key-openshift-kube-apiserver)
oauth_secrets_num=$(oc get secrets -n openshift-config-managed | grep -c encryption-key-openshift-oauth-apiserver)
## Setting names for secrets created during encryption/decryption.
((oc_secrets_num = oc_secrets_num + 1))
((kb_secrets_num = kb_secrets_num + 1))
((oauth_secrets_num = oauth_secrets_num + 1))
oc_secrets_name=$(echo -e "encryption-key-openshift-apiserver-${oc_secrets_num}")
kb_secrets_name=$(echo -e "encryption-key-openshift-kube-apiserver-${kb_secrets_num}")
oauth_secrets_name=$(echo -e "encryption-key-openshift-oauth-apiserver-${oauth_secrets_num}")
log "Secrets to check:"
log "${oc_secrets_name}"
log "${kb_secrets_name}"
log "${oauth_secrets_name}"

function enable_encryption {
    mode="aescbc"
    oc patch apiserver/cluster -p '{"spec":{"encryption": {"type":"aescbc"}}}' --type merge
    log "Encryption enabled"
}

function disable_encryption {
    mode="identity"
    oc patch apiserver/cluster -p '{"spec":{"encryption": {"type":"identity"}}}' --type merge
    log "Encryption disabled"
}

function check_secret {
    secret_file="$1"
    migrated_resources_value_a="$2"
    migrated_resources_value_b="$3"
    secret_migrated_resources=$(grep "encryption.apiserver.operator.openshift.io/migrated-resources" "${secret_file}" | awk '{print $2}')
    secret_timestamp=$(grep "encryption.apiserver.operator.openshift.io/migrated-timestamp" "${secret_file}" | awk '{print $2}')
    secret_mode=$(grep "encryption.apiserver.operator.openshift.io/mode" "${secret_file}" | awk '{print $2}')

    if [[ ${secret_migrated_resources} == "${migrated_resources_value_a}" ]] || [[ ${secret_migrated_resources} == "${migrated_resources_value_b}" ]]; then
        log "Founded: encryption.apiserver.operator.openshift.io/migrated-resources in ${secret_file} secret."
    else
        log "Still waiting for: encryption.apiserver.operator.openshift.io/migrated-resources in ${secret_file} secret."
        continue_wait=true
    fi

    if [[ ${secret_timestamp} != "" ]]; then
        log "Founded: encryption.apiserver.operator.openshift.io/migrated-timestamp in ${secret_file} secret."
    else
        log "Still waiting for: encryption.apiserver.operator.openshift.io/migrated-timestamp in ${secret_file} secret."
        continue_wait=true
    fi

    if [[ ${secret_mode} == "${mode}" ]]; then
        log "Founded: encryption.apiserver.operator.openshift.io/mode in ${kb_secrets_file} secret."
    else
        log "Still waiting for: encryption.apiserver.operator.openshift.io/mode in ${kb_secrets_file} secret."
        continue_wait=true
    fi
}

function wait_until_encryption_is_ready {
    start_time=$(date +%s)
    while ((($(date +%s) - start_time) < timeout)); do
        continue_wait=false

        echo -e "Not ready yet. Time from beginning: $(($(date +%s) - start_time)) seconds"
        echo -e "Retrying in one minute"
        sleep 60

        # Getting secrets
        log "Getting ${oc_secrets_name} secret"
        oc get secret "${oc_secrets_name}" -o yaml -n openshift-config-managed >"${OC_SECRET}"
        log "Getting ${kb_secrets_name} secret"
        oc get secret "${kb_secrets_name}" -o yaml -n openshift-config-managed >"${KB_SECRET}"
        log "Getting ${oauth_secrets_name} secret"
        oc get secret "${oauth_secrets_name}" -o yaml -n openshift-config-managed >"${OAUTH_SECRET}"

        # Checking encryption-key-openshift-apiserver secret
        log "------- Checking ${oc_secrets_name} secret"
        check_secret "${OC_SECRET}" "${OC_MIGRATED_RESOURCES}" "${OC_MIGRATED_RESOURCES}"

        # Checking encryption-key-openshift-kube-apiserver secret
        log "------- Checking ${kb_secrets_name} secret"
        check_secret "${KB_SECRET}" "${KB_MIGRATED_RESOURCES_A}" "${KB_MIGRATED_RESOURCES_B}"

        # Checking encryption-key-openshift-oauth-apiserver secret
        log "------- Checking ${oauth_secrets_name} secret"
        check_secret "${OAUTH_SECRET}" "${OAUTH_MIGRATED_RESOURCES_A}" "${OAUTH_MIGRATED_RESOURCES_B}"

        if [[ ${continue_wait} == "true" ]]; then
            continue
        fi

        log "DONE"
        echo -e "Time from beginning: $(($(date +%s) - start_time)) seconds"
        exit 0
    done

    log "!!!!!!!!!!! TIMEOUT !!!!!!!!!!!"
    log "${OC_SECRET}"
    cat "${OC_SECRET}"
    echo ""
    log "${KB_SECRET}"
    cat "${KB_SECRET}"
    echo ""
    log "${OAUTH_SECRET}"
    cat "${OAUTH_SECRET}"
    exit 1
}

# START!
if [[ $1 == "enable" ]]; then
    enable_encryption
elif [[ $1 == "disable" ]]; then
    disable_encryption
else
    echo -e "First argument should be 'enable' to enable encryption or 'disable' to disable encryption."
    exit 1
fi

wait_until_encryption_is_ready
