
# Storage Requirements

Certain EOEPCA Building Blocks (BBs) require persistent storage. This section outlines the storage needs and provides recommendations for both production and development environments.

## General Requirements

- **Persistent Volumes with `ReadWriteMany` Access Mode**: Needed for specific EOEPCA BBs, such as the **Processing BB** (e.g., CWL Processing Engine).
- **Storage Classes**: Should support dynamic provisioning of persistent volumes.

## Production Environment Recommendations

- **Recommended Storage Solutions**:
    - **NFS (Network File System)**: Reliable shared storage.
    - **OpenEBS**: Supports dynamic local PVs and `ReadWriteMany`.
    - **Longhorn**: Provides highly available persistent storage.
    - **GlusterFS**: Suitable for large-scale distributed storage.

## Development Environment Recommendations

- **HostPath Provisioner**:
    - Suitable for single-node clusters.
    - Not recommended for production or multi-node clusters.
    - [HostPath Provisioner Setup](./hostpath-provisioner.md)
- **Local NFS Server**:
    - Easy to set up for development.
    - Limited scalability.

## EOEPCA Building Blocks Requiring `ReadWriteMany` Storage

- **Processing BB**:
    - **CWL Processing Engine**: Requires shared storage for job execution.


## Setting Up Storage Classes

- **NFS Provisioner**: [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- **OpenEBS**: [OpenEBS Documentation](https://openebs.io/)
- **Longhorn**: [Longhorn Documentation](https://longhorn.io/)
- **GlusterFS**: [GlusterFS Documentation](https://docs.gluster.org/en/latest/)

## Additional Resources

  - [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
  - [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)