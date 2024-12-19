
# Storage Requirements

Some EOEPCA Building Blocks, particularly those involved in processing (e.g. the CWL Processing Engine), require shared storage with `ReadWriteMany` access. This allows multiple pods to read and write to the same volume concurrently.

**Key Requirements:**

- **ReadWriteMany Persistent Volumes**: Essential for components like the CWL Processing Engine.
- **Appropriate StorageClass**: The cluster must have a StorageClass that can provision volumes suitable for EOEPCA’s workload.

**Storage Options for Production:**

- Consider robust, distributed filesystems or managed storage solutions. Examples include:
    - **GlusterFS** or IBM Spectrum Scale for large-scale distributed storage.
    - **OpenEBS** or **Longhorn** for simpler deployments that still support `ReadWriteMany`.
    - **NFS** with a proper HA setup can be a practical choice if carefully managed.

**Storage Options for Development or Testing:**

- **Longhorn** or **OpenEBS** set up on a single node, if you are seeking something quick and less complex.
- **HostPath** or a simple NFS server for a local environment—straightforward but not for production use.

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