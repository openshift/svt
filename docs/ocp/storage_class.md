# Storage Class

More info on [Kubernetes site](https://kubernetes.io/docs/concepts/storage/storage-classes/)

## Creating storage class

Save file with content:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  creationTimestamp: null
  name: sk2
  ownerReferences:
  - apiVersion: v1
    kind: clusteroperator
    name: storage
    uid: 2b630aa6-816a-11e9-abbe-06954f63b386
  selfLink: /apis/storage.k8s.io/v1/storageclasses/sk2
parameters:
  encrypted: "true"
  type: gp2
provisioner: kubernetes.io/aws-ebs
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

Then create storage class object:

```bash
oc create -f <file_name>
# Verification:
oc get storageclasses
```