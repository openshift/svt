FROM registry.access.redhat.com/rhel7/rhel-tools
MAINTAINER jeder <jeder@redhat.com>

# pbench is a distributed systems analysis framework:  http://distributed-system-analysis.github.io/pbench/
# Packages are available here:  https://copr-be.cloud.fedoraproject.org/results/ndokos/pbench-test/

# Install perf tools, benchmarks and sshd
RUN yum --enablerepo=copr-pbench-test install -y pbench* openssh-server && yum clean all

# Fix to allow running multiple privileged containers -- otherwise systemd agetty processes spin at 100%
# This does not affect non-privileged containers
RUN rm -f /lib/systemd/system/systemd*udev* && rm -f /lib/systemd/system/getty.target

# Example of enabling a systemd service
# cp /usr/local/share/uperf.service /etc/systemd/system/ ; systemctl enable uperf

# systemd init is the default process.  This allows systemd services to start.
# There are 2 ways to run this container.  If you want to use the systemd services:
# docker run -d -v /sys/fs/cgroup:/sys/fs/cgroup rtp
#
# If you want to run your own command, like bash:
# docker run -it r7perf bash

WORKDIR /root

# Set a default username to use inside the container.  If you set this, you probably also want to change WORKDIR.
# USER username
 
CMD ["/usr/sbin/init"]
