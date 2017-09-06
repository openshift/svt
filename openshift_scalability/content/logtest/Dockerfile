FROM centos:latest

RUN mkdir /var/lib/svt && mkdir /opt/svt
WORKDIR /opt/svt
COPY root ./

CMD ./ocp_logtest_wrapper.sh
