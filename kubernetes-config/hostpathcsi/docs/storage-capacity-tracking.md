# Distributed provisioning with and without storage capacity tracking

csi-driver-host-path can be deployed locally on nodes with simulated storage
capacity limits. The experiment below shows how Kubernetes [storage capacity
tracking](https://kubernetes.io/docs/concepts/storage/storage-capacity/) helps
scheduling Pods that use volumes with "wait for first consumer" provisioning.

## Setup

Clusterloader from k8s.io/perf-test master (1a46c4c54dd348) is used to
generate the load.

The cluster was created in the Azure cloud, initially with 10 nodes:

```
az aks create -g cloud-native --name pmem --generate-ssh-keys --node-count 10 --kubernetes-version 1.21.1
```

csi-driver-hostpath master (76efcbf8658291e) and external-provisioner canary
(2022-03-06) were used to test with the latest code in preparation for
Kubernetes 1.24.

### Baseline without volumes

```
go run cmd/clusterloader.go -v=3 --report-dir=/tmp/clusterloader2-no-volumes --kubeconfig=/home/pohly/.kube/config --provider=local --nodes=10 --testconfig=testing/experimental/storage/pod-startup/config.yaml --testoverrides=testing/experimental/storage/pod-startup/volume-types/genericephemeralinline/override.yaml --testoverrides=no-volumes.yaml
```

The relevant local configuration is `no-volumes.yaml`:

```
PODS_PER_NODE: 100
NODES_PER_NAMESPACE: 10
VOLUMES_PER_POD: 0
VOL_SIZE: 1Gi
STORAGE_CLASS: csi-hostpath-fast
GATHER_METRICS: false
```

This creates 1 namespace, 1000 pods, and all pods could run on a single
node. This led to a moderate load for the cluster. Pods got spread out evenly:

```
$ kubectl top nodes
NAME                                CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
aks-nodepool1-15818640-vmss000000   546m         28%    2244Mi          49%       
aks-nodepool1-15818640-vmss000001   1382m        72%    1776Mi          38%       
aks-nodepool1-15818640-vmss000002   445m         23%    1816Mi          39%       
aks-nodepool1-15818640-vmss000003   861m         45%    1852Mi          40%       
aks-nodepool1-15818640-vmss000004   490m         25%    1798Mi          39%       
aks-nodepool1-15818640-vmss000005   945m         49%    1896Mi          41%       
aks-nodepool1-15818640-vmss000006   1355m        71%    1956Mi          42%       
aks-nodepool1-15818640-vmss000007   543m         28%    1788Mi          39%       
aks-nodepool1-15818640-vmss000008   426m         22%    1829Mi          40%       
aks-nodepool1-15818640-vmss000009   721m         37%    1890Mi          41%       
```

Test results were:
```
<?xml version="1.0" encoding="UTF-8"?>
  <testsuite name="ClusterLoaderV2" tests="0" failures="0" errors="0" time="446.487">
      <testcase name="storage overall (testing/experimental/storage/pod-startup/config.yaml)" classname="ClusterLoaderV2" time="446.483938942"></testcase>
      <testcase name="storage: [step: 01] Starting measurement for waiting for deployments" classname="ClusterLoaderV2" time="0.101351119"></testcase>
      <testcase name="storage: [step: 02] Creating deployments" classname="ClusterLoaderV2" time="100.609226598"></testcase>
      <testcase name="storage: [step: 03] Waiting for deployments to be running" classname="ClusterLoaderV2" time="114.905364201"></testcase>
      <testcase name="storage: [step: 04] Deleting deployments" classname="ClusterLoaderV2" time="100.616139236"></testcase>
```

### Without storage capacity tracking

For this csi-driver-hostpath was deployed with `deploy/kubernetes-distributed/deploy.sh` after patching the code:

```
diff --git a/deploy/kubernetes-distributed/hostpath/csi-hostpath-driverinfo.yaml b/deploy/kubernetes-distributed/hostpath/csi-hostpath-driverinfo.yaml
index 54d455c6..c61efec4 100644
--- a/deploy/kubernetes-distributed/hostpath/csi-hostpath-driverinfo.yaml
+++ b/deploy/kubernetes-distributed/hostpath/csi-hostpath-driverinfo.yaml
@@ -17,5 +17,4 @@ spec:
   podInfoOnMount: true
   # No attacher needed.
   attachRequired: false
-  # alpha: opt into capacity-aware scheduling
-  storageCapacity: true
+  storageCapacity: false
diff --git a/deploy/kubernetes-distributed/hostpath/csi-hostpath-plugin.yaml b/deploy/kubernetes-distributed/hostpath/csi-hostpath-plugin.yaml
index ce9abc40..e212feb6 100644
--- a/deploy/kubernetes-distributed/hostpath/csi-hostpath-plugin.yaml
+++ b/deploy/kubernetes-distributed/hostpath/csi-hostpath-plugin.yaml
@@ -25,12 +25,12 @@ spec:
       serviceAccountName: csi-provisioner
       containers:
         - name: csi-provisioner
-          image: k8s.gcr.io/sig-storage/csi-provisioner:v3.0.0
+          image: gcr.io/k8s-staging-sig-storage/csi-provisioner:canary
           args:
-            - -v=5
+            - -v=3
             - --csi-address=/csi/csi.sock
             - --feature-gates=Topology=true
-            - --enable-capacity
+            - --enable-capacity=false
             - --capacity-ownerref-level=0 # pod is owner
             - --node-deployment=true
             - --strict-topology=true
@@ -88,7 +88,7 @@ spec:
           image: k8s.gcr.io/sig-storage/hostpathplugin:v1.7.3
           args:
             - --drivername=hostpath.csi.k8s.io
-            - --v=5
+            - --v=3
             - --endpoint=$(CSI_ENDPOINT)
             - --nodeid=$(KUBE_NODE_NAME)
             - --capacity=slow=10Gi
             - --capacity=fast=100Gi
```

In this case, the local config was:

```
PODS_PER_NODE: 100
NODES_PER_NAMESPACE: 10
VOLUMES_PER_POD: 1
VOL_SIZE: 1Gi
STORAGE_CLASS: csi-hostpath-fast
GATHER_METRICS: false
POD_STARTUP_TIMEOUT: 45m
```

The number of namespaces and pods is the same, but now they have to be
distributed among all nodes because each node has storage for exactly 100
volumes (`--capacity=fast=100Gi`).

```
<?xml version="1.0" encoding="UTF-8"?>
  <testsuite name="ClusterLoaderV2" tests="0" failures="0" errors="0" time="806.468">
      <testcase name="storage overall (testing/experimental/storage/pod-startup/config.yaml)" classname="ClusterLoaderV2" time="806.464585136"></testcase>
      <testcase name="storage: [step: 01] Starting measurement for waiting for deployments" classname="ClusterLoaderV2" time="0.100971403"></testcase>
      <testcase name="storage: [step: 02] Creating deployments" classname="ClusterLoaderV2" time="100.584344658"></testcase>
      <testcase name="storage: [step: 03] Waiting for deployments to be running" classname="ClusterLoaderV2" time="414.865956542"></testcase>
      <testcase name="storage: [step: 04] Deleting deployments" classname="ClusterLoaderV2" time="100.614270188"></testcase>
```

Despite the for this particular scenario favorable even spreading, several
scheduling retries are needed, with kube-scheduler often picking nodes as
candidates that are already full:

```
$ for i in `kubectl get pods | grep csi-hostpathplugin- | sed -e 's/ .*//'`; do echo "$i: $(kubectl logs $i hostpath | grep '^E.*code = ResourceExhausted desc = requested capacity .*exceeds remaining capacity for "fast"' | wc -l)"; done
csi-hostpathplugin-5c74t: 24
csi-hostpathplugin-8q9kf: 0
csi-hostpathplugin-g4gqp: 15
csi-hostpathplugin-hqxpv: 14
csi-hostpathplugin-jpvj8: 10
csi-hostpathplugin-l4bzm: 17
csi-hostpathplugin-m54cc: 16
csi-hostpathplugin-r26b4: 0
csi-hostpathplugin-rnkjn: 7
csi-hostpathplugin-xmvwf: 26
```

These failed volume creation attempts are handled without deleting the affected
pod. Instead, kube-scheduler tries again with a different node.

The situation could have been a lot worse. If kube-scheduler had preferred to
pack as many pods as possible onto a single node, it would have always picked
the same node because it seems to fit the pod and then the test wouldn't have
completed at all.

### With capacity tracking

This is almost the default deployment, just with some tweaks to reduce logging
and the newer external-provisioner. A small fix in the deploy script was needed,
too.

```
diff --git a/deploy/kubernetes-distributed/deploy.sh b/deploy/kubernetes-distributed/deploy.sh
index 985e7f7a..b163aefc 100755
--- a/deploy/kubernetes-distributed/deploy.sh
+++ b/deploy/kubernetes-distributed/deploy.sh
@@ -174,8 +174,7 @@ done
 # changed via CSI_PROVISIONER_TAG, so we cannot just check for the version currently
 # listed in the YAML file.
 case "$CSI_PROVISIONER_TAG" in
-    "") csistoragecapacities_api=v1alpha1;; # unchanged, assume version from YAML
-    *) csistoragecapacities_api=v1beta1;; # set, assume that it is more recent *and* a version that uses v1beta1 (https://github.com/kubernetes-csi/external-provisioner/pull/584)
+    *) csistoragecapacities_api=v1beta1;; # we currently always use that version
 esac
 get_csistoragecapacities=$(kubectl get csistoragecapacities.${csistoragecapacities_api}.storage.k8s.io 2>&1 || true)
 if  echo "$get_csistoragecapacities" | grep -q "the server doesn't have a resource type"; then
diff --git a/deploy/kubernetes-distributed/hostpath/csi-hostpath-plugin.yaml b/deploy/kubernetes-distributed/hostpath/csi-hostpath-plugin.yaml
index ce9abc40..88983120 100644
--- a/deploy/kubernetes-distributed/hostpath/csi-hostpath-plugin.yaml
+++ b/deploy/kubernetes-distributed/hostpath/csi-hostpath-plugin.yaml
@@ -25,9 +25,9 @@ spec:
       serviceAccountName: csi-provisioner
       containers:
         - name: csi-provisioner
-          image: k8s.gcr.io/sig-storage/csi-provisioner:v3.0.0
+          image: gcr.io/k8s-staging-sig-storage/csi-provisioner:canary
           args:
-            - -v=5
+            - -v=3
             - --csi-address=/csi/csi.sock
             - --feature-gates=Topology=true
             - --enable-capacity
@@ -88,7 +88,7 @@ spec:
           image: k8s.gcr.io/sig-storage/hostpathplugin:v1.7.3
           args:
             - --drivername=hostpath.csi.k8s.io
-            - --v=5
+            - --v=3
             - --endpoint=$(CSI_ENDPOINT)
             - --nodeid=$(KUBE_NODE_NAME)
             - --capacity=slow=10Gi
```

Starting pods was more than twice as fast as without storage capacity tracking
(193 seconds instead of 414 seconds):

```
<?xml version="1.0" encoding="UTF-8"?>
  <testsuite name="ClusterLoaderV2" tests="0" failures="0" errors="0" time="544.772">
      <testcase name="storage overall (testing/experimental/storage/pod-startup/config.yaml)" classname="ClusterLoaderV2" time="544.769501842"></testcase>
      <testcase name="storage: [step: 01] Starting measurement for waiting for deployments" classname="ClusterLoaderV2" time="0.100321716"></testcase>
      <testcase name="storage: [step: 02] Creating deployments" classname="ClusterLoaderV2" time="100.602021053"></testcase>
      <testcase name="storage: [step: 03] Waiting for deployments to be running" classname="ClusterLoaderV2" time="193.207935027"></testcase>
      <testcase name="storage: [step: 04] Deleting deployments" classname="ClusterLoaderV2" time="100.607824368"></testcase>
```

There were still a few failed provisioning attempts (total shown here):

```
for i in `kubectl get pods | grep csi-hostpathplugin- | sed -e 's/ .*//'`; do kubectl logs $i hostpath ; done | grep '^E.*code = ResourceExhausted desc = requested capacity .*exceeds remaining capacity for "fast"' | wc -l
27
```

This is normal because CSIStorageCapacity might not get updated quickly enough
in some cases. The key point is that this doesn't happen repeatedly for the
same node.


### 100 nodes

For some reason, 1.22.1 was not accepted anymore when trying to create a
cluster with 100 nodes, so 1.22.6 was used instead:

```
az aks create -g cloud-native --name pmem --generate-ssh-keys --node-count 100 --kubernetes-version 1.22.6
```

When using the same clusterloader invocation as above with `--nodes=100`, the
number of pods gets scaled up to 10000 automatically.

The baseline without volumes turned out to be this:

```
<?xml version="1.0" encoding="UTF-8"?>
  <testsuite name="ClusterLoaderV2" tests="0" failures="0" errors="0" time="3208.062">
      <testcase name="storage overall (testing/experimental/storage/pod-startup/config.yaml)" classname="ClusterLoaderV2" time="3208.059435154"></testcase>
      <testcase name="storage: [step: 01] Starting measurement for waiting for deployments" classname="ClusterLoaderV2" time="0.100575248"></testcase>
      <testcase name="storage: [step: 02] Creating deployments" classname="ClusterLoaderV2" time="1005.908420547"></testcase>
      <testcase name="storage: [step: 03] Waiting for deployments to be running" classname="ClusterLoaderV2" time="1125.187490211"></testcase>
      <testcase name="storage: [step: 04] Deleting deployments" classname="ClusterLoaderV2" time="1005.74259478"></testcase>
```

Without storage capacity tracking, the test failed because pods didn't start
within the 45 minute timeout:

```
E0307 00:38:02.164402  175511 clusterloader.go:231] --------------------------------------------------------------------------------
E0307 00:38:02.164418  175511 clusterloader.go:232] Test Finished
E0307 00:38:02.164426  175511 clusterloader.go:233]   Test: testing/experimental/storage/pod-startup/config.yaml
E0307 00:38:02.164436  175511 clusterloader.go:234]   Status: Fail
E0307 00:38:02.164444  175511 clusterloader.go:236]   Errors: [measurement call WaitForControlledPodsRunning - WaitForRunningDeployments error: 7684 objects timed out: Deployments: test-t6vzr2-3/deployment-337, test-t6vzr2-3/deployment-971,
```

The total number of failed volume allocations was:

```
$ for i in `kubectl get pods | grep csi-hostpathplugin- | sed -e 's/ .*//'`; do kubectl logs $i hostpath ; done | grep '^E.*code = ResourceExhausted desc = requested capacity .*exceeds remaining capacity for "fast"' | wc -l
181508
```

*Pure chance alone is not good enough anymore when the number of nodes is high.*

With storage capacity tracking it initially also failed:
```
I0307 08:36:55.412124    6877 simple_test_executor.go:145] Step "[step: 03] Waiting for deployments to be running" started
W0307 08:45:52.536411    6877 reflector.go:436] *v1.PodStore: namespace(test-pu6g95-10), labelSelector(name=deployment-652): watch of *v1.Pod ended with: very short watch: *
v1.PodStore: namespace(test-pu6g95-10), labelSelector(name=deployment-652): Unexpected watch close - watch lasted less than a second and no items received
...
```

There were other intermittent problems accessing the apiserver. Doing the
[CSIStorageCapacity updates in a separate Kubernetes client with smaller rate
limits](https://github.com/kubernetes-csi/external-provisioner/pull/711) solved
this problem and the same test passed all three times that it was run:

```
<?xml version="1.0" encoding="UTF-8"?>
  <testsuite name="ClusterLoaderV2" tests="0" failures="0" errors="0" time="3989.135">
      <testcase name="storage overall (testing/experimental/storage/pod-startup/config.yaml)" classname="ClusterLoaderV2" time="3989.131860537"></testcase>
      <testcase name="storage: [step: 01] Starting measurement for waiting for deployments" classname="ClusterLoaderV2" time="0.100946346"></testcase>
      <testcase name="storage: [step: 02] Creating deployments" classname="ClusterLoaderV2" time="1005.808055111"></testcase>
      <testcase name="storage: [step: 03] Waiting for deployments to be running" classname="ClusterLoaderV2" time="1775.679433562"></testcase>
      <testcase name="storage: [step: 04] Deleting deployments" classname="ClusterLoaderV2" time="1005.768258827"></testcase>
```

In this run there were 573 failed provisioning attempts.

The ratio between "with volumes" and "no volumes" is 1.58. That is even better
than for 10 nodes where that ratio was 1.68.
