# OpenShift, Kubernetes and Docker: Performance, Scalability and Capacity Planning Research by Red Hat

[OpenShift v3 Scaling, Performance and Capacity Planning Whitepaper](https://access.redhat.com/articles/2191731 "OpenShift v3 Scaling, Performance and Capacity Planning Whitepaper")

This repository details the approach, process and procedures used by engineering teams at Red Hat to analyze and improve the performance and scalability of integrated platform and infrastructure stacks.  It shares results, best practices and reference architectures for the Kubernetes and docker-based OpenShift v3 Platform-as-a-Service, as well as the Red Hat Atomic technologies.

Unsurprisingly, performance analysis and tuning in the container and container-orchestration space has tremendous overlap with previous generation approaches to distributed computing.  Performance still boils down to identifying and resolving bottlenecks, data- and compute-locality, and applying best-practices to software scale-out design hard-won over decades of grid- and high-performance computing research.

Further tests quantify application performance when running in a container hosted by OpenShift, as well as measure reliability over time, searching for things like memory leaks.

# How this repository is organized:
The hierarchy of this repository is as follows:

```
.
├── application_performance:  JMeter-based performance testing of applications hosted on OpenShift.
├── applications_scalability:  Performance and scalability testing of the OpenShift web UI.
├── conformance: Wrappers to run a subset of e2e/conformance tests in an SVT environment (work in progress)
├── image_provisioner:  Ansible playbooks for building AMI and qcow2 images with OpenShift rpms and Docker images baked in.
├── networking: Performance tests for the OpenShift SDN and kube-proxy.
├── openshift_performance:  Performance tests for container build parallelism, projects and persistent storage (EBS, Ceph, Gluster and NFS)
├── openshift_scalability: Home of the infamous "cluster-loader", details in openshift_scalability/README.md
└── reliability: Run tests over long periods of time (weeks), cycle object quantity up and down.
```

Feedback, issues and pull requests happily accepted!
