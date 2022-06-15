#!/bin/bash

# Usage: ./enable_encryption.sh <enable/disable> <timeout_in_minutes>
# To enable: ./enable_encryption.sh enable 50
# to disable: ./enable_encryption.sh disable 50

red="\e[31m"
green="\e[32m"
reset="\e[0m"

timeout=$(($2*60))

# Mode on encription
mode=""

function log {
    echo -e "[$(date "+%F %T")]: $*"
}

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

function wait_until_encryption_is_ready {
    start_time=$(date +%s)
    while (( ($(date +%s) - ${start_time}) < ${timeout} ));
    do
        continue=false

        echo -e "Not ready yet. Time from beginning: $(( $(date +%s) - ${start_time} )) seconds"
        echo -e "Retrying in 30 seconds"
        sleep 30

        log "Getting ${oc_secrets_name} secret"
        oc_secret=$(oc get secret ${oc_secrets_name} -o json -n openshift-config-managed)
        log "$(echo $oc_secret | jq -r)"
        echo ""

        log "Getting ${kb_secrets_name} secret"
        kb_secret=$(oc get secret ${kb_secrets_name} -o json -n openshift-config-managed)
        log "$(echo $kb_secret | jq -r)"
        echo ""

        log "Getting ${oauth_secrets_name} secret"
        oauth_secret=$(oc get secret ${oauth_secrets_name} -o json -n openshift-config-managed)
        log "$(echo $oauth_secret | jq -r)"
        echo ""

        log "Checking ${oc_secrets_name} secret"
        oc_mr=$(echo $oc_secret | jq -r '.metadata.annotations."encryption.apiserver.operator.openshift.io/migrated-resources"')
        oc_ts=$(echo $oc_secret | jq -r '.metadata.annotations."encryption.apiserver.operator.openshift.io/migrated-timestamp"')
        oc_m=$(echo $oc_secret | jq -r '.metadata.annotations."encryption.apiserver.operator.openshift.io/mode"')

        if [ "$oc_mr" == "{\"resources\":[{\"Group\":\"route.openshift.io\",\"Resource\":\"routes\"}]}" ]; then
            log "${green}Founded: encryption.apiserver.operator.openshift.io/migrated-resources in ${oc_secrets_name} secret.${reset}"
        else
            log "${red}Missing: encryption.apiserver.operator.openshift.io/migrated-resources in ${oc_secrets_name} secret.${reset}"
            continue=true
        fi

        if [ "$oc_ts" != "null" ]; then
            log "${green}Founded: encryption.apiserver.operator.openshift.io/migrated-timestamp in ${oc_secrets_name} secret.${reset}"
        else
            log "${red}Missing: encryption.apiserver.operator.openshift.io/migrated-timestamp in ${oc_secrets_name} secret.${reset}"
            continue=true
        fi

        if [ "$oc_m" == "$mode" ]; then
            log "${green}Founded: encryption.apiserver.operator.openshift.io/mode in ${oc_secrets_name} secret.${reset}"
        else
            log "${red}Missing: encryption.apiserver.operator.openshift.io/mode in ${oc_secrets_name} secret.${reset}"
            continue=true
        fi

        log "Checking ${kb_secrets_name} secret"
        kb_mr=$(echo $kb_secret | jq -r '.metadata.annotations."encryption.apiserver.operator.openshift.io/migrated-resources"')
        kb_ts=$(echo $kb_secret | jq -r '.metadata.annotations."encryption.apiserver.operator.openshift.io/migrated-timestamp"')
        kb_m=$(echo $kb_secret | jq -r '.metadata.annotations."encryption.apiserver.operator.openshift.io/mode"')

        if [ "$kb_mr" == "{\"resources\":[{\"Group\":\"\",\"Resource\":\"configmaps\"},{\"Group\":\"\",\"Resource\":\"secrets\"}]}" ]; then
            log "${green}Founded: encryption.apiserver.operator.openshift.io/migrated-resources in ${kb_secrets_name} secret.${reset}"
        else
            log "${red}Missing: encryption.apiserver.operator.openshift.io/migrated-resources in ${kb_secrets_name} secret.${reset}"
            continue=true
        fi

        if [ "$kb_ts" != "null" ]; then
            log "${green}Founded: encryption.apiserver.operator.openshift.io/migrated-timestamp in ${kb_secrets_name} secret.${reset}"
        else
            log "${red}Missing: encryption.apiserver.operator.openshift.io/migrated-timestamp in ${kb_secrets_name} secret.${reset}"
            continue=true
        fi

        if [ "$kb_m" == "$mode" ]; then
            log "${green}Founded: encryption.apiserver.operator.openshift.io/mode in ${kb_secrets_name} secret.${reset}"
        else
            log "${red}Missing: encryption.apiserver.operator.openshift.io/mode in ${kb_secrets_name} secret.${reset}"
            continue=true
        fi

        log "Checking ${oauth_secrets_name} secret"
        oauth_mr=$(echo $oauth_secret | jq -r '.metadata.annotations."encryption.apiserver.operator.openshift.io/migrated-resources"')
        oauth_ts=$(echo $oauth_secret | jq -r '.metadata.annotations."encryption.apiserver.operator.openshift.io/migrated-timestamp"')
        oauth_m=$(echo $oauth_secret | jq -r '.metadata.annotations."encryption.apiserver.operator.openshift.io/mode"')

        if [ "$oauth_mr" == "{\"resources\":[{\"Group\":\"oauth.openshift.io\",\"Resource\":\"oauthaccesstokens\"},{\"Group\":\"oauth.openshift.io\",\"Resource\":\"oauthauthorizetokens\"}]}" ]; then
            log "${green}Founded: encryption.apiserver.operator.openshift.io/migrated-resources in ${oauth_secrets_name} secret.${reset}"
        else
            log "${red}Missing: encryption.apiserver.operator.openshift.io/migrated-resources in ${oauth_secrets_name} secret.${reset}"
            continue=true
        fi

        if [ "$oauth_ts" != "null" ]; then
            log "${green}Founded: encryption.apiserver.operator.openshift.io/migrated-timestamp in ${oauth_secrets_name} secret.${reset}"
        else
            log "${red}Missing: encryption.apiserver.operator.openshift.io/migrated-timestamp in ${oauth_secrets_name} secret.${reset}"
            continue=true
        fi

        if [ "$oauth_m" == "$mode" ]; then
            log "${green}Founded: encryption.apiserver.operator.openshift.io/mode in ${oauth_secrets_name} secret.${reset}"
        else
            log "${red}Missing: encryption.apiserver.operator.openshift.io/mode in ${oauth_secrets_name} secret.${reset}"
            continue=true
        fi

        if [ "$continue"  == "true" ]; then
            continue
        fi

        log "${green}DONE${reset}"
        echo -e "Time from beginning: $(( $(date +%s) - ${start_time} )) seconds"
        exit 0
    done

    log "${red}Timeout!${reset}"
    exit 1
}

# Getting secrets names.
oc_secrets_num=$(oc get secrets -n openshift-config-managed | grep -c encryption-key-openshift-apiserver)
kb_secrets_num=$(oc get secrets -n openshift-config-managed | grep -c encryption-key-openshift-kube-apiserver)
oauth_secrets_num=$(oc get secrets -n openshift-config-managed | grep -c encryption-key-openshift-oauth-apiserver)
((oc_secrets_num=${oc_secrets_num}+1))
((kb_secrets_num=${kb_secrets_num}+1))
((oauth_secrets_num=${oauth_secrets_num}+1))
oc_secrets_name=$(echo -e "encryption-key-openshift-apiserver-${oc_secrets_num}")
kb_secrets_name=$(echo -e "encryption-key-openshift-kube-apiserver-${kb_secrets_num}")
oauth_secrets_name=$(echo -e "encryption-key-openshift-oauth-apiserver-${oauth_secrets_num}")
log "Secrets to check:"
log "${oc_secrets_name}"
log "${kb_secrets_name}"
log "${oauth_secrets_name}"

if [[ "$1" == "enable" ]]
then
    enable_encryption
elif [[ "$1" == "disable" ]]
then
    disable_encryption
else
    echo -e "${red}First argument should be 'enable' to enable encryption or 'disable' to disable encryption${reset}"
    exit 1
fi

wait_until_encryption_is_ready
