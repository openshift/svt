# PVC Bound test

This test checks the latency of creating AWS-EBS-type PVCs.

The created PVCs are associated with project <code>project-test-pvc-bound</code>
which should existed before running the test.


> storage/scripts/pvc_bound_test.py -s 1 -c 1


To clean up the created PVCs, delete project <code>project-test-pvc-bound</code>.

