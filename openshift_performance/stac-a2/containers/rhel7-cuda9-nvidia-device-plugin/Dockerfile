# based on https://gitlab.com/nvidia/cuda/blob/centos7/9.0/base/Dockerfile

FROM registry.access.redhat.com/rhel7:latest
LABEL maintainer "jeder@redhat.com"

RUN NVIDIA_GPGKEY_SUM=d1be581509378368edeec8c1eb2958702feedf3bc3d17011adbf24efacce4ab5 && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/7fa2af80.pub | sed '/^Version/d' > /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA && \
    echo "$NVIDIA_GPGKEY_SUM  /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA" | sha256sum -c --strict -

RUN yum install -y \
        gcc \
        ca-certificates \
        wget

# Configure necessary external repos.  EPEL for DKMS and CUDA for CUDA.
RUN yum install -y http://epel.mirror.net.in/epel/7/x86_64/e/epel-release-7-10.noarch.rpm \
    && yum clean all
COPY ./cuda.repo /etc/yum.repos.d/
RUN yum install -y dkms && yum clean all

ENV CUDA_VERSION 9.0.176
LABEL com.nvidia.cuda.version="${CUDA_VERSION}"
ENV NVIDIA_CUDA_VERSION $CUDA_VERSION
 
ENV CUDA_PKG_VERSION=$CUDA_VERSION-1
 
RUN yum install -y cuda cuda-core cuda-cudart-dev-9-0 cuda-cudart-9-0-$CUDA_PKG_VERSION cuda-misc-headers-9-0 cuda-nvml-dev-9-0 && yum clean all
RUN ln -s cuda-9.0 /usr/local/cuda
 
# nvidia-docker 1.0
LABEL com.nvidia.volumes.needed="nvidia_driver"
 
RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf
 
ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64
 
# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility

# We do not have golang 1.9.1 in RHEL or EPEL
ENV GOLANG_VERSION 1.9.1
RUN wget -nv -O - https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz \
    | tar -C /usr/local -xz
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

ENV CGO_CFLAGS "-I /usr/local/cuda-9.0/include -I /usr/include/nvidia/gdk"
ENV CGO_LDFLAGS "-L /usr/local/cuda-9.0/lib64"
ENV PATH=$PATH:/usr/local/nvidia/bin:/usr/local/cuda/bin
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/nvidia/lib:/usr/local/nvidia/lib64

WORKDIR /go/src/nvidia-device-plugin
COPY . .

RUN go install -v nvidia-device-plugin


RUN cp /go/bin/nvidia-device-plugin /usr/bin/nvidia-device-plugin

CMD ["nvidia-device-plugin"]
