
# Storage Requirements

Some EOEPCA Building Blocks, particularly those involved in processing (e.g. the CWL Processing Engine), require shared storage with `ReadWriteMany` access. This allows multiple pods to read and write to the same volume concurrently.

**Key Requirements:**

- **ReadWriteMany Volumes**  
    - Mandatory for the CWL Processing Engine and potentially other BBs requiring concurrent file access.
- **Appropriate StorageClass**  
    - The cluster must have a default or specialized StorageClass that can dynamically provision `ReadWriteMany` volumes.

## Production vs. Development

- **Production**  

    - Use robust solutions like GlusterFS, IBM Spectrum Scale, or fully managed cloud file systems that support `ReadWriteMany`.
    - Tools like OpenEBS or Longhorn can provide distributed block storage, but ensure they truly support multi-node RWX if your usage demands it.
    - NFS can be used if carefully configured for high availability and reliability.

- **Development / Testing**  

    - A simple NFS server or an OpenEBS/Longhorn single-node install might suffice for demos.
    - HostPath or local volumes can be acceptable for quick tests, but not recommended for multi-node or production usage.

**Which EOEPCA Blocks Require `ReadWriteMany`?**

- **Processing Building Blocks**: For instance, the CWL Processing Engine needs shared file access.

Make sure to check which Building Blocks you plan to deploy and ensure the cluster's StorageClass and volume provisioning match these requirements.

## Setting Up Storage Classes

- **NFS Provisioner**: [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- **OpenEBS**: [OpenEBS Documentation](https://openebs.io/)
- **Longhorn**: [Longhorn Documentation](https://longhorn.io/)
- **GlusterFS**: [GlusterFS Documentation](https://docs.gluster.org/en/latest/)

## Additional Resources

- [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

## Quick Start

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
