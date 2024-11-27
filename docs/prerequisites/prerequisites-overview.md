
# EOEPCA+ Prerequisites

This guide outlines the essential prerequisites for deploying the EOEPCA ecosystem. It focuses on the specific requirements unique to EOEPCA, ensuring that your infrastructure can support the deployment of EOEPCA Building Blocks (BBs) outlined in the [Application Deployment](../building-blocks/overview.md) section of the guide.

## Overview

EOEPCA+ requires certain infrastructure capabilities to function correctly. This guide details:

- **Kubernetes Cluster Requirements**: Specific configurations your Kubernetes cluster must have.
- **Storage Requirements**: Details on storage classes and persistent volumes needed by certain EOEPCA BBs.
- **Ingress Controller Setup**: Guidance on ingress controllers suitable for EOEPCA.
- **TLS Certificate Management**: Recommendations for securing your services.
- **Docker Hub Credentials**: Recommended to set up Docker Hub credentials or a proxy registry in the cluster to overcome image pull limits due to the number of containers involved. (TODO)

## Next Steps

Proceed to the following sections to ensure your infrastructure meets EOEPCA's prerequisites:

1. [Kubernetes Requirements](kubernetes.md)
2. [Storage Requirements](storage.md)
3. [Ingress Controller Setup](ingress-controller.md)
4. [TLS Certificate Management](tls/overview.md)