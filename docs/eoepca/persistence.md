# Persistence

## Overview

The EOEPCA building-blocks rely upon Kubernetes `Persistent Volumes` for their component persistence. Components integrate with the storage provided in the cluster by means of configurable `Persistent Volume Claims` and/or dynamic `Storage Class` that are specfied as values at time of deployment. Some components require storage of type  `ReadWriteMany` - which, for a multi-node cluster, implies a network-based storage solution.

!!! note
    **Local CLuster Storage**<br>
    For the purposes of the [Scripted Deployment](../quickstart/scripted-deployment.md), the default Storage Class included with the local Kubernetes distribution can be used for all storage concerns - e.g. `standard` for `minikube` which provides the `ReadWriteMany` persistence that is required by the ADES.

## ReadWriteMany Storage

For the EOEPCA development deployment, an NFS server has been established to provide the persistence layer for `ReadWriteMany` storage.

### Pre-defined Persistent Volume Claims

The EOEPCA development deployment establishes the following pre-defined Persistent Volume Claims, to provide a simple storage architecture that is organised around the 'domain areas' into which the Reference Implementation is split.

* **Resource Managment** (`resman`) - **`persistentvolumeclaim/eoepca-resman-pvc`**
* **Processing & Chaining** (`proc`) - **`persistentvolumeclaim/eoepca-proc-pvc`**
* **User Management** (`userman`) - **`persistentvolumeclaim/eoepca-userman-pvc`**

_NOTE that this is offered only as an example thay suits the approach of the development team. Each building-block has configuration through which its persistence (PV/PVC) can be configured according the needs of the deployment._

The following Kubernetes yaml provides an example of provisioning such domain-specific PersistentVolumeClaims within the cluster - in this case using the minikube built-in storage-class `standard` for dynamic provisioning...

```
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: eoepca-proc-pvc
  namespace: proc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: standard
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: eoepca-resman-pvc
  namespace: rm
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: standard
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: eoepca-userman-pvc
  namespace: um
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: standard
  resources:
    requests:
      storage: 5Gi
```

Once established, these _PersistentVolumeClaims_ are then referenced within the deployment configurations of the building-blocks.

### Dynamic `ReadWriteMany` Storage Provisioning

In addition to the pre-defined PV/PVCs, the EOEPCA Reference Implementation also defines NFS-based storage classes for dynamic storage provisioning:

* `managed-nfs-storage`<br>
  *With a `Reclaim Policy` of `Delete`.*
* `managed-nfs-storage-retain`<br>
  *With a `Reclaim Policy` of `Retain`.*

The building-blocks simply reference the required `Storage Class` in their volume specifications, to receive a `Persistent Volume Claim` that is dynamically provisioned at deployment time.

This is acheived through the [`nfs-provisioner` helm chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/nfs-provisioner), with the following typical configurations...

Reclaim Policy `Delete`...
```yaml
provisionerName: nfs-storage
storageClass:
  name: managed-nfs-storage
  create: true
  reclaimPolicy: Delete
  archiveOnDelete: false
  allowVolumeExpansion: true
nfs:
  server: "<your-nfs-ip-address-here>"
  path: /data/dynamic  # your NFS server path here
```

Reclaim Policy `Retain`...
```yaml
provisionerName: nfs-storage-retain
storageClass:
  name: managed-nfs-storage-retain
  create: true
  reclaimPolicy: Retain
  allowVolumeExpansion: true
nfs:
  server: "<your-nfs-ip-address-here>"
  path: /data/dynamic  # your NFS server path here
```

## Clustered Storage Solutions

Clustered storage approaches offer an alternative to NFS. Clustered Storage provides a network-attached storage through a set of commodity hosts whose storage is aggregated to form a distributed file-system. Capacity is scaled by adding additional nodes or adding additional storage to the existing nodes. In the context of a multi-node Kubernetes cluster, then it is typical that the same commodity nodes provide both the cluster members and storage resources, i.e. the clustered storage is spread across the Kubernetes worker nodes.

Candidate clustered storage solutions include:

* **[GlusterFS](https://www.gluster.org/)**<br>
  GlusterFS is deployed as an operating system service across each node participating in the storage solution. Thus, with GlusterFS, the distributed storage nodes do not need to be one-and-the-same with the compute (cluster) nodes – although this may preferably be the case.
* **[Longhorn](https://longhorn.io/)**<br>
  Longhorn offers a solution that is similar to that of GlusterFS, except that Longhorn is ‘cloud-native’ in that its service layer deploys within the Kubernetes cluster itself. Thus, the storage nodes are also the cluster compute nodes by design.

**_All things being equal, Longhorn is recommended as the best approach for Kubernetes clusters._**
