
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

Make sure to check which Building Blocks you plan to deploy and ensure the cluster’s StorageClass and volume provisioning match these requirements.

## Setting Up Storage Classes

- **NFS Provisioner**: [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- **OpenEBS**: [OpenEBS Documentation](https://openebs.io/)
- **Longhorn**: [Longhorn Documentation](https://longhorn.io/)
- **GlusterFS**: [GlusterFS Documentation](https://docs.gluster.org/en/latest/)

## Additional Resources

- [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)