# EOEPCA Infrastructure Prerequisites

This section outlines the infrastructure requirements for deploying EOEPCA. Rather than explaining how to build a Kubernetes cluster from scratch, we focus on what EOEPCA specifically needs from your existing environment. We assume you have a working Kubernetes cluster, or know how to create one by referring to standard guides (e.g. Rancher, Kubernetes.io), and that you simply want to ensure it meets EOEPCA’s particular prerequisites.

**In essence, these prerequisites cover:**

- Specific Kubernetes configuration (including the need to run certain containers as root).
- A suitable storage solution offering `ReadWriteMany` capabilities for some EOEPCA Building Blocks.
- Proper ingress and TLS configuration, including wildcard DNS and a certificate manager.
- Object storage capabilities, such as S3 (though the details for these are covered elsewhere).

Where relevant, we outline what’s ideal for production versus what’s sufficient for development, testing or demonstrations.

**Before deploying the EOEPCA Building Blocks, we recommend running the `check-prerequisite` script (once provided). This script will:**

- Test if pods can run as root.
- Verify that ingress is properly set up with wildcard DNS.
- Check TLS certificate validity.
- Confirm that storage requirements (e.g. `ReadWriteMany`) are met.
