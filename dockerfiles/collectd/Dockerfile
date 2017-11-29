FROM fedora:latest
MAINTAINER Naga Ravi Chaitanya Elluri <nelluri@redhat.com>

# Install collectd and dependencies
RUN dnf install -y git collectd collectd-disk procps && \
    dnf clean all && \
    mkdir -p /root/collectd

# setup collectd
COPY collectd.conf /etc/collectd.conf
COPY run.sh /root/collectd/run.sh
ENTRYPOINT  ["/root/collectd/run.sh"]
