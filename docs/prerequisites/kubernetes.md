
# Kubernetes Requirements

To deploy EOEPCA+, your Kubernetes cluster must meet specific requirements.

## General Requirements

- **Kubernetes Version**: Compatible with Kubernetes version 1.28 or later.
- **Run Containers as Root**: **Required**. Some EOEPCA components need to run as the root user.
- **Ingress Controller with Wildcard DNS**: **Required** for dynamic host-based routing to services.
- **Load Balancer with Ports 80/443 Open**: **Recommended** for external access to services.
- **Cert-Manager Setup**: **Recommended** for simplified TLS certificate management.

## Additional Notes

- **Kubernetes Installation**: For installing Kubernetes, refer to external guides:
    - [Kubernetes Setup](https://kubernetes.io/docs/setup/)
    - [Rancher Kubernetes Engine](https://rancher.com/docs/rke/latest/en/)
- **Container Runtime**: Ensure your cluster uses a compatible container runtime (e.g. containerd, Docker).