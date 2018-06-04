FROM docker.io/fedora:28

RUN dnf clean all; \
    rm -rf /var/cache/yum; \
    yum install -y git; \
    dnf clean all; \
    rm -rf /var/cache/yum

CMD ["/usr/sbin/init"]