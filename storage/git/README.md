# git-workload test

Tested with:

```
$ ansible --version
ansible 2.7.8
```

Run the test playbook:

```
$ ansible-playbook -i "<target_host>," storage/git/git-test.yaml" 

### if use private key to ssh the target host
$ ansible-playbook -i "<target_host>," storage/git/git-test.yaml --extra-vars "ansible_user=<fedora> ansible_ssh_private_key_file=<private_key>" 
```

Check results:

* check how many pods a worker node supports and the system load (CPU, Memory, Network) on worker nodes provided by `pbench` or `grafana`.
* check the stats (overall time and the time for each of the step).
* if the storage solution is provided by containers (glusterfs or rook-ceph), check the system load on the storage nodes.
  In this case, try to avoid running the test pods on those storage node. We can achieve that by cordoning the storage nodes or using node selectors in the test pods.
