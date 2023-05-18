# Dockerfile for conformance

FROM quay.io/openshift/origin-tests:latest as origintests

FROM centos:7

MAINTAINER Red Hat OpenShift Performance and Scale

ENV KUBECONFIG /root/.kube/config

# Copy OpenShift CLI, Kubernetes CLI and openshift-tests binaries from origin-tests image
COPY --from=origintests /usr/bin/oc /usr/bin/oc
COPY --from=origintests /usr/bin/kubectl /usr/bin/kubectl
COPY --from=origintests /usr/bin/openshift-tests /usr/bin/openshift-tests

ENTRYPOINT /usr/bin/openshift-tests run openshift/conformance/parallel 
