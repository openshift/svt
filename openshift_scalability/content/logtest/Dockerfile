FROM centos:latest

RUN mkdir /var/lib/svt && mkdir /opt/svt
WORKDIR /opt/svt
COPY root ./
RUN yum -y install epel-release && yum -y install python2-pip && yum clean all
RUN python -m pip install --no-cache-dir -U pip
RUN python -m pip install --no-cache-dir json-logging

CMD ./ocp_logtest_wrapper.sh
