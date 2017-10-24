FROM rhel7-cuda9
MAINTAINER jeder@redhat.com

# The rhel7.4 base image included a 0day errata for systemd which was not in our 7.4 GA RHEL channel.  Thus we have to provide those RPMs here manually.
# If a system is properly registered to the customer portal or satellite, this issue does not exist.

COPY ./systemd-219-42_4.1 /root/systemd-219-42_4.1
COPY ./systemd.repo /etc/yum.repos.d/
RUN yum update -y systemd

# For STAC-A2
RUN yum install -y R sudo time openssh-clients python34 dos2unix && yum clean all

# This takes a very long time.
RUN echo "r <- getOption('repos'); r['CRAN'] <- 'http://cran.us.r-project.org'; options(repos = r);" > ~/.Rprofile
RUN Rscript -e "install.packages('knitr', dependencies = TRUE)"
