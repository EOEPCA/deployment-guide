# Storage Provisioning Guide

## Introduction

Persistent storage is essential for many applications deployed in Kubernetes. Kubernetes uses **Storage Classes** to provision persistent volumes dynamically. This guide provides general guidance on storage provisioning and how to ensure your cluster is ready to support applications that require persistent storage.

- **Storage Classes** define how a unit of storage can be dynamically created.
- Different storage classes map to different storage providers and types (e.g., local disks, network storage, cloud storage).
- Each storage class has properties that define the provisioner, parameters, and reclaim policy.

---

If your cluster does not have a suitable storage class, you need to set one up. The method for doing this depends on your environment and the storage solution you wish to use.

### Common Storage Solutions

- **Cloud Provider Storage Classes**: Most cloud providers offer managed storage solutions that integrate with Kubernetes (e.g., AWS EBS, Azure Disk, Google Persistent Disk).
- **Network File Systems (NFS)**: Allows multiple nodes to share the same storage. 
- **Distributed Storage Systems**: Solutions like Ceph, GlusterFS, or Longhorn also provide storage.

### Resources for Setting Up Storage Classes

- **Kubernetes Documentation**: [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
- **NFS Provisioner**: [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- **Cloud Provider Guides**:
  - [AWS EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
  - [Azure Disk CSI Driver](https://github.com/kubernetes-sigs/azuredisk-csi-driver)
  - [Google Cloud PD CSI Driver](https://github.com/kubernetes-sigs/gcp-compute-persistent-disk-csi-driver)
