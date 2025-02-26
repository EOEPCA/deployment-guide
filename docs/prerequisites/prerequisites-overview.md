# EOEPCA+ Prerequisites

This section outlines the infrastructure requirements for deploying EOEPCA. Rather than explaining how to build a Kubernetes cluster from scratch, we focus on what EOEPCA specifically needs from your existing environment. We assume you have a working Kubernetes cluster, or know how to create one by referring to standard guides (e.g. Rancher, Kubernetes.io), and that you simply want to ensure it meets EOEPCA’s particular prerequisites.


## High-Level Requirements

- **Kubernetes**: Must allow containers to run as root, have an ingress + wildcard DNS, etc.
- **Storage**: Certain BBs need shared `ReadWriteMany` volumes.
- **TLS**: For production, cert-manager or a similar mechanism is strongly recommended.
- **(Optional) Object Storage**: E.g. MinIO or external S3.

For more in-depth information about each requirement (including recommended solutions for production vs. development), see the respective pages:

- [Kubernetes Requirements](kubernetes.md)
- [Storage Requirements](storage.md)
- [Ingress Controller Setup](ingress-controller.md)
- [TLS Management](tls.md)

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

> Before running the script ensure that `kubectl` is installed and configured to access your Kubernetes cluster.

```bash
bash check-prerequisites.sh
```

The **EOEPCA+ Prerequisites** should help guide you through any unmet requirements if your existing environment does not meet them.

