
# Storage Requirements

---

## Overview

Most building blocks require the ability to persist data to maintain the state of the building block beyond the ephemeral life of a pod. This is typically achieved through the use of Persistent Volumes (PVs) in Kubernetes, which are backed by various storage solutions.

Each BB expresses their storage needs and requests storage resource from the cluster via Persistent Volume Claims (PVCs). The cluster's StorageClass is responsible for dynamically provisioning the appropriate type of storage based on these claims.

Kubernetes defines several access modes for volumes, which determine how the volume can be mounted by pods:

- **ReadWriteOnce (RWO)**: The volume can be mounted as read-write by a single node. This is the most common access mode and is suitable for many applications.
- **ReadWriteMany (RWX)**: The volume can be mounted as read-write by many nodes. This is required for applications that need to share data between multiple pods or nodes.
- **ReadOnlyMany (ROX)**: The volume can be mounted as read-only by many nodes. This is less common but can be useful for certain scenarios.
- **ReadWriteOncePod (RWOP)**: The volume can be mounted as read-write by a single pod. This is a more restrictive access mode introduced in Kubernetes 1.22.

---

## EOEPCA Storage Scenarios

For the purposes of the building blocks described in this guide there are two main scenarios to consider, which require either `ReadWriteOnce` or `ReadWriteMany` access.

**Scenario 1: Preservation (RWO)**

This represents important data that must be preserved beyond the life of a pod, but does not need to be shared between multiple pods. Examples include databases, configuration files, and application state.

This includes data that should be well managed and backed up as part of platform operations.

Typically this would be implemented using `ReadWriteOnce` volumes, which can be provided by a variety of storage solutions including local storage, cloud provider block storage (e.g., AWS EBS, GCP Persistent Disks), or network-attached storage (e.g., NFS, iSCSI).

***In this guide this type of volume is referred as `PERSISTENT_STORAGECLASS`.***

**Scenario 2: Sharing (RWX)**

This represents data that needs to be shared between multiple pods, such as input data for processing tasks, shared configuration files, or output data that needs to be accessed by multiple services.

This data may be transient and not require long-term preservation, but it must be accessible to multiple pods concurrently.

Typically this would be implemented using `ReadWriteMany` volumes, which can be provided by storage solutions such as NFS, GlusterFS, or cloud provider file storage services (e.g., AWS EFS, GCP Filestore).

**_In this guide this type of volume is referred as `SHARED_STORAGECLASS`._**

---

## `ReadWriteMany` Volumes

Special consideration is required for `ReadWriteMany` volumes, as not all Kubernetes clusters support this access mode by default.

The following EOEPCA building blocks require `ReadWriteMany` access:

* Processing BB (OGC API Processing via `zoo-project` and Calrissian CWL Engine

    Calrissian orchestrates the execution of the OGC Application Package that comprises a CWL workflow. Calrissian relies upon shared `RWX` storage to stage input data, intermediate files, and output data that is passed between workflow steps (pods) and amongst pods that may be executing concurrently, such as when using scatter-gather patterns.

* Resource Registration BB

    The harvester workflows can download data assets to an `eodata` volume. A `RWX` volume is assumed here, in anticipation that other services (pods) will require to exploit the data assets - e.g. to serve the data assets for retrieval via http URLs for access and visualisation.

### `RWX` Possible Implementations

* **Production**

    For use in production environments, consider the following options:

    * GlusterFS, IBM Spectrum Scale, Longhorn, OpenEBS, or fully managed cloud file systems that support `ReadWriteMany`
    * NFS can be used if carefully configured for high availability and reliability
    * [JuiceFS](https://juicefs.com/) is another cloud-native option that can be configured for high availability.<br>
      _See [Multi-node Quick Start](#quick-start-multi-node-with-juicefs) below_

* **Development / Testing**

    For development or testing environments, consider the following options:

    * HostPath provisioner for single-node clusters (e.g., k3d/k3s, Minikube, kind) - suitable for evaluation and demos<br>
        _See [Quick Start - Single-node with HostPath Provisioner](#quick-start-single-node-with-hostpath-provisioner) below_
    * A simple NFS server - e.g. running in a virtual machine
    * If you have access to object storage, then JuiceFS can offer a simple solution - see _See Multi-node Quick Start below_

---

## Reference Documentation

### Storage Classes

* **NFS Provisioner**: [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
* **OpenEBS**: [OpenEBS Documentation](https://openebs.io/)
* **Longhorn**: [Longhorn Documentation](https://longhorn.io/)
* **GlusterFS**: [GlusterFS Documentation](https://docs.gluster.org/en/latest/)
* **JuiceFS**: [JuiceFS CSI Driver](https://juicefs.com/docs/csi/introduction/)

### Kubernetes Storage

* [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
* [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

---

## Quick Start - Multi-node with JuiceFS

For a multi-node cluster then a distributed storage solution is required to provide `ReadWriteMany` access. If your cluster has access to an Object Storage solution (e.g. S3, MinIO, etc.), then JuiceFS can exploit this to offer a cloud-native storage solution that provides POSIX-compliant file system access with `ReadWriteMany` capabilities.

JuiceFS is an open-source, high-performance distributed file system that allows all kinds of object storage to be used as massive local disks and to be simulaneously mounted and accessed on different nodes.

JuiceFS achieves this by separation of 'data' and 'metadata' storage. The metadata is stored in a low-latency database (e.g. Redis, TiKV, MySQL, etc.) while the data is stored as chunks in an Object Storage system - and others such as local-disk, WebDAV, HDFS - see [Supported Storage](https://juicefs.com/docs/community/reference/how_to_set_up_object_storage/#supported-object-storage). This allows JuiceFS to provide high performance and scalability while leveraging convenient and cost-effective object storage for data persistence.

The resultant data volume can then be accessed/mounted through a variety of compatibility layers - including POSIX, HDFS, S3, and a Kubernetes CSI Driver for dynamic provisioning of PersistentVolumes.

### Basic Principles

To demonstrate the basic principles - the simplest case using SQLite for metadata storage and the local file-system for storage.

> This is only useful for demonstration purposes - for any real deployment a more robust network-accessible metadata engine (e.g. TiKV etc.) should be used, combined with a suitable object storage solution.

* Create a file-system (volume) `myjfs`...

    ```bash
    juicefs format sqlite3://myjfs.db myjfs
    ```

    > Storage defaults to the local path `~/.juicefs/local/myjfs`

* Mount the file-system to a local directory `./mnt`...

    ```bash
    mkdir mnt
    juicefs mount sqlite3://myjfs.db ./mnt
    ```

Building on this, a more relevant example using Redis for metadata storage and S3 Object Storage for the data backend.

* Create a file-system (volume)...

    ```bash
    juicefs format \
      --storage s3 \
        --bucket <S3-BUCKET-ENDPOINT> \
        --access-key <S3-ACCESS-KEY> \
        --secret-key <S3-SECRET-KEY> \
      redis://<REDIS-HOST>:6379 \
      myjfs
    ```

* Mount the file-system to a local directory `./mnt`...

    > As before the mount command references the metadata engine - in this case Redis - which in turn references the S3 Object Storage for the data blocks

    ```bash
    mkdir mnt
    juicefs mount redis://<REDIS-HOST>:6379 ./mnt

    cp somefile ./mnt
    ls ./mnt
    ```

### Deploying JuiceFS in Kubernetes

With those basic principles established, the next step is to deploy JuiceFS in a Kubernetes cluster, and create PersistentVolumes requiring `ReadWriteMany` access for use by EOEPCA+ Building Blocks.

Deploy the JuiceFS CSI Driver...

```bash
helm upgrade -i juicefs-csi-driver juicefs-csi-driver \
  --repo https://juicedata.github.io/charts/ \
  --namespace juicefs \
  --create-namespace
```

We will create a StorageClass that uses the [JuiceFS CSI Driver](https://juicefs.com/docs/csi/introduction/) to dynamically provision PersistentVolumes. But first we need a metadata engine accessible from all cluster nodes. There are many options, but for simplicity we will use Redis.

```bash
helm install redis redis \
  --repo https://charts.bitnami.com/bitnami \
  --set architecture=standalone \
  --set auth.enabled=false \
  --namespace juicefs \
  --create-namespace
```

Now we can create a StorageClass that uses the JuiceFS CSI Driver (provisioner), referencing the Redis metadata engine and an S3-compatible Object Storage solution.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: sc-eoepca-rw-many
  namespace: juicefs
type: Opaque
stringData:
  name: eoepca-rw-many                                     # The JuiceFS file system name
  access-key: <S3-ACCESS-KEY>                              # Object storage credentials
  secret-key: <S3-SECRET-KEY>                              # Object storage credentials
  metaurl: redis://redis-master.juicefs.svc.cluster.local  # Connection URL for metadata engine.
  storage: s3                                              # Object storage type, such as s3, gs, oss.
  bucket: <S3-BUCKET-ENDPOINT>                             # Bucket URL of object storage.
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: eoepca-rw-many
reclaimPolicy: Delete  # Specify "Retain" if you want to retain the data after PVC deletion
provisioner: csi.juicefs.com
parameters:
  csi.storage.k8s.io/provisioner-secret-name: sc-eoepca-rw-many
  csi.storage.k8s.io/provisioner-secret-namespace: juicefs
  csi.storage.k8s.io/node-publish-secret-name: sc-eoepca-rw-many
  csi.storage.k8s.io/node-publish-secret-namespace: juicefs
```

### Example using MinIO

To complete the demonstration, section [`S3 Storage (MinIO)`](./minio.md#readwritemany-storage-using-juicefs) includes an example that uses the above approach to establish an object storage backed JuiceFS StorageClass providing `ReadWriteMany` access for EOEPCA+ Building Blocks.

The JuiceFS approach described here is really designed to exploit the prevailing object storage solution that is provided by your cloud of choice. Hence, while it is possible to use MinIO as the object storage backend, this is not really the intended use case. Nevertheless, MinIO provides a convenient way to demonstrate the principles of JuiceFS in a self-contained manner.

> It should be acknowledged that using MinIO to back JuiceFS in this way has limitations. In particular, the storage is presented through two layers of persistent volume which will adversely affect performance. This should be taken into account. For any sort of real workload, then the 'native' S3 storage of the cloud provider should be used directly with JuiceFS.

---

## Quick Start - Single-node with HostPath Provisioner

For a development/testing environment such as the cluster established via the [Kubernetes Quick Start](kubernetes.md#quick-start), the HostPath provisioner can be used - noting that this can only be used for single node deployments. 

1. Deploy the provisioner and its associated `standard` storage class.

      ```bash
      kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/hostpath-provisioner.yaml
      ```

2. Monitor the deployment

      ```bash
      kubectl get -n kube-system sc/standard deploy/hostpath-storage-provisioner
      ```

This provides a storage class called `standard` that can be used for deployment of the EOEPCA+ Building Blocks that require persistent storage.

The `standard` StorageClass has a `Delete` reclaim policy, meaning that when the associated PersistentVolumeClaim is deleted, the underlying storage is also deleted.

If required, a `Retain` reclaim policy can also be used by configuration of a variant of the `standard` StorageClass, by applying the following manifest - which exploits the previously deployed HostPath provisioner:

```bash
cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: standard-retain
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF
```

This `standard-retain` StorageClass can then be used in place of `standard` when deploying EOEPCA+ Building Blocks that require persistent storage, where the underlying storage is to be retained after deletion of the associated PersistentVolumeClaim.
