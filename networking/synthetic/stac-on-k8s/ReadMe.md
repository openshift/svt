Run STAC-N1 on k8s deployment
===========================

Scripts and automation to run containerized STAC-N1 inside k8s pods
leveraging [SFC device plugin](https://github.com/vikaschoudhary16/kubernetes/pull/7).

----------

**Pre-requisites:**
-----------------------
- K8s 1.8 or higher patched with the [PR for device plugin's extended support for smart-NICs](https://github.com/kubernetes/kubernetes/pull/51938)
- Onload 1.3+ installed and working on the hosts.

**Steps:**
------

 **Deploy SFC device plugin daemonset pods:**
>[root@dell-r730-01 ]# kubectl apply -f [device_plugins/sfc_nic/device_plugin.yml](https://github.com/vikaschoudhary16/kubernetes/blob/20d84bc490f4583bcb0c2c535d4cfb95358fe6ab/device_plugins/sfc_nic/device_plugin.yml)  
>[root@dell-r730-01 vikas]# kubectl get pods -o wide
NAME                        READY     STATUS    RESTARTS   AGE       IP             NODE
kube-dns-6df5bc5d85-4n7xl   3/3       Running   0          2d        172.17.0.2     10.12.20.134
sfc-device-plugin-cfscs     1/1       Running   0          2d        10.12.20.134   10.12.20.134
sfc-device-plugin-x4d7f     1/1       Running   0          2d        10.12.20.136   10.12.20.136

 **Deploy STAC-N1 producer and consumer pods:**
 > [root@dell-r730-01 vikas]# kubectl create -f /home/stac-producer.yml

 
 > [root@dell-r730-01 vikas]# kubectl create -f /home/stac-consumer.yml


 > [root@dell-r730-01 vikas]# kubectl get pods -o wide 

NAME                        READY     STATUS    RESTARTS   AGE       IP             NODE
kube-dns-6df5bc5d85-4n7xl   3/3       Running   0          2d        172.17.0.2     10.12.20.134
sfc-device-plugin-cfscs     1/1       Running   0          2d        10.12.20.134   10.12.20.134
sfc-device-plugin-x4d7f     1/1       Running   0          2d        10.12.20.136   10.12.20.136
stac-consumer               1/1       Running   0          4h        172.17.0.3     10.12.20.134
stac-producer               1/1       Running   0          4h        172.17.0.2     10.12.20.136

**NOTE:** Irrespective of what machine STAC pods get launched on, device plugin will configure 70.70.70.1 on Producer pod SFC NIC and 70.70.70.2 on the consumer pod sfc NIC. IP addresses are configurable in the pod yml files, stac-producer.yml and stac-consumer.yml

**Start the STAC-N1 test:**
>[root@dell-r730-01 vikas]# kubectl exec stac-consumer -c stac-consumer -it -- /bin/bash -c './prepare-consumer'
> [root@dell-r730-01 vikas]# kubectl exec stac-producer -c stac-producer -it -- /bin/bash -c './start-stac-test'

**NOTE:**

 - For any change in STAC-N1 test configuration, `exec` into the
   stac-producer pod and reconfigure as desired before executing
   `start-stac-test`. Or  Change the STAC-N1 tarball location in the
   dockerfile and rebuild docker images for stac pods using:

> [root@dell-r730-01 vikas]# docker build -t rhel74:latest -f
> Dockerfile-rhel74-onload .

 -  `/home/container-home` is mounted as volume into STAC pods at `/home`
