FROM fedora
MAINTAINER Vikas Laad <vlaad@redhat.com>
LABEL Description="This image is used to start Reliability tests for Openshift 3.0 and later" Version="1.0"

#install packages required by reliability tests
RUN dnf install -y ruby wget hostname openssh-clients iproute procps-ng git
RUN gem install net-ssh net-scp

#install pbench
ADD https://copr.fedorainfracloud.org/coprs/ndokos/pbench/repo/fedora-23/ndokos-pbench-fedora-23.repo /etc/yum.repos.d/
RUN dnf install -y pbench-agent
ENV PATH "$PATH:/opt/pbench-agent/bench-scripts:/opt/pbench-agent/util-scripts"
ENV CONFIG "/opt/pbench-agent/config/pbench-agent.conf"

#installing oc client tool
RUN git ls-remote -t https://github.com/openshift/origin  | tail -1 >> /tmp/oc_url.txt
RUN echo $(cat /tmp/oc_url.txt) | gawk 'match($0, /(^\S{7}).*tags\/(.*)\^.*/, info) {print info[1]}' >> /tmp/oc_commit_id.txt
RUN echo $(cat /tmp/oc_url.txt) | gawk 'match($0, /(^\S{7}).*tags\/(.*)\^.*/, info) {print info[2]}' >> /tmp/oc_tag_name.txt
RUN echo https://github.com/openshift/origin/releases/download/$(cat /tmp/oc_tag_name.txt)/openshift-origin-client-tools-$(cat /tmp/oc_tag_name.txt)-$(cat /tmp/oc_commit_id.txt)-linux-64bit.tar.gz >> /tmp/oc_final_url.txt
RUN wget -q $(cat /tmp/oc_final_url.txt) -O /tmp/openshift-oc.tar.gz
RUN tar -zxvf /tmp/openshift-oc.tar.gz -C /tmp
RUN mv /tmp/openshift*/oc /bin

#setting up ssh config
RUN mkdir -p /root/.ssh
RUN echo -e "Host *.com\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config

WORKDIR /root/svt/reliability
#ENTRYPOINT /bin/bash
ENTRYPOINT ./startReliabilityContainer.sh >> setup.log
