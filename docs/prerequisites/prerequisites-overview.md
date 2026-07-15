# EOEPCA+ Prerequisites

This section outlines the infrastructure requirements for deploying EOEPCA. Rather than explaining how to build a Kubernetes cluster from scratch, we focus on what EOEPCA specifically needs from your existing environment. We assume you have a working Kubernetes cluster, or know how to create one by referring to standard guides (e.g. Rancher, Kubernetes.io), and that you simply want to ensure it meets EOEPCA's particular prerequisites.

## High-Level Requirements

<div class="grid cards" markdown>

-   :material-kubernetes:{ .lg .middle } **Kubernetes**

    ---

    Must allow containers to run as root, have an ingress + wildcard DNS, etc.

    [:octicons-arrow-right-24: Kubernetes Requirements](kubernetes.md)

-   :material-harddisk:{ .lg .middle } **Storage**

    ---

    Certain BBs need shared `ReadWriteMany` volumes.

    [:octicons-arrow-right-24: Storage Requirements](storage.md)

-   :material-router-network:{ .lg .middle } **Ingress**

    ---

    An ingress controller / gateway, correctly configured with wildcard DNS.

    [:octicons-arrow-right-24: Ingress Controller Setup](../prerequisites/ingress/overview.md)

-   :material-lock-check:{ .lg .middle } **TLS**

    ---

    For production, cert-manager or a similar mechanism is strongly recommended.

    [:octicons-arrow-right-24: TLS Management](tls.md)

</div>

(Optional) **Object Storage** - e.g. MinIO or external S3 - is also used by certain Building Blocks; see [S3 Storage (MinIO)](minio.md).

---

**Before deploying the EOEPCA Building Blocks, we recommend running or referencing the `check-prerequisite` script (once provided). This script will:**

- Test if pods can run as root.
- Verify that ingress is properly set up with wildcard DNS.
- Check TLS certificate validity.
- Confirm that storage requirements (e.g. `ReadWriteMany`) are met.

**Clone the Deployment Guide Repository:**

```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/infra-prereq
```

**Validate your environment:**

!!! note
    Before running the script ensure that `kubectl` is installed and configured to access your Kubernetes cluster.

```bash
bash check-prerequisites.sh
```

The **EOEPCA+ Prerequisites** should help guide you through any unmet requirements if your existing environment does not meet them.
