# Dockerfile for scale-ci-diagnosis

# Stage-1 to generate the rendered json files from jsonnet templates.
FROM registry.access.redhat.com/ubi8/ubi-minimal as jsonnet-builder

RUN microdnf install git make tar && git clone https://github.com/cloud-bulldozer/performance-dashboards.git --depth=1 dashboards && make -C dashboards build

# Stage-2 for provisioning data source and dashboards for generated json
FROM grafana/grafana:latest

USER root

MAINTAINER Red Hat OpenShift Performance and Scale

# Setup dashboard provider and prometheus as the default datasource
COPY datasource.yaml /etc/grafana/provisioning/datasources/datasource.yaml
COPY provider.yaml /etc/grafana/provisioning/dashboards/provider.yaml

# Setup dashboards - load openshift performance and scale default dashboards
COPY --from=jsonnet-builder dashboards/rendered/* /etc/grafana/provisioning/dashboards/
