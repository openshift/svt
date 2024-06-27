#!/bin/bash

#################################################
# Author: skordas@redhat.com
# Related Test Case: OCP-69214
#
# Description:
# Script to create large number of big secrets
# ###############################################


START=$(date)

# Configure the name of the secret and namespace
NAMESPACE="my-namespace"

# SSH key
ssh-keygen -t rsa -b 4096 -f sshkey -N ''
SSH_PRIVATE_KEY=$(cat sshkey | base64 | tr -d '\n')
SSH_PUBLIC_KEY=$(cat sshkey.pub | base64 | tr -d '\n')

# Token (example token here, replace with your actual token generation method)
TOKEN_VALUE=$(openssl rand -hex 32 | base64 | tr -d '\n')

# Self-signed Certificate
openssl req -x509 -newkey rsa:4096 -keyout tls.key -out tls.crt -days 365 -nodes -subj "/CN=mydomain.com"
CERTIFICATE=$(cat tls.crt | base64 | tr -d '\n')
PRIVATE_KEY=$(cat tls.key | base64 | tr -d '\n')

# Creating sectret template for this test run.
TEMPLATE=secret_template.yaml
SECRET_TEMPLATE=secret_template_run.yaml

cp $TEMPLATE $SECRET_TEMPLATE

sed -i "s/NAMESPACE/$NAMESPACE/g" $SECRET_TEMPLATE
sed -i "s/SSH_PRIVATE_KEY/$PRIVATE_KEY/g" $SECRET_TEMPLATE
sed -i "s/SSH_PUBLIC_KEY/$SSH_PUBLIC_KEY/g" $SECRET_TEMPLATE
sed -i "s/TOKEN_VALUE/$TOKEN_VALUE/g" $SECRET_TEMPLATE
sed -i "s/CERTIFICATE/$CERTIFICATE/g" $SECRET_TEMPLATE
sed -i "s/PRIVATE_KEY/$PRIVATE_KEY/g" $SECRET_TEMPLATE

# Create project and load with secrets
oc new-project $NAMESPACE
oc label ns $NAMESPACE purpose=test

for i in {1..50000};
do
  sh load_secret.sh $i &
done

END=$(date)
sleep 5 # Some time to finish all secrets to be created.
echo "Start: $START"
echo "End  : $END"
