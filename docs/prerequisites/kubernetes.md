# Kubernetes Requirements

EOEPCA places a few special demands on your Kubernetes cluster. We do not detail how to install Kubernetes here—there are many fine guides available (e.g. [Rancher’s non-production quickstart](https://rancher.com/docs/rke/latest/en/) or [Kubernetes official docs](https://kubernetes.io/docs/setup/)). Instead, we focus on what EOEPCA expects from an already-installed cluster.

**Requirements:**

- **Run Containers as Root (Mandatory)**: Some EOEPCA components cannot run under non-root users.
- **Wildcard DNS & Ingress Controller (Mandatory)**: The cluster must be accessible via a wildcard DNS entry, and you should have an ingress controller that can handle host-based routing.
- **Load Balancer with Port 80/443 Exposure (Recommended)**: This ensures external traffic can reach the EOEPCA services.
- **Cert-Manager or Equivalent (Recommended)**: Simplifies obtaining and managing TLS certificates.

**Production vs Development:**

- **Production**:  
    - Consider a fully managed or production-hardened Kubernetes environment (e.g. a production Rancher setup or a managed Kubernetes service from a cloud provider).
    - Use cert-manager with Let’s Encrypt for automatic certificate renewal.
    - Ensure you have a stable load balancer and wildcard DNS properly configured.
  
- **Development / Internal Testing**:  
    - A single-node Rancher or Minikube-like environment is often enough.  
    - Manual certificates or self-signed TLS might suffice.  
    - Simplified DNS settings can be used, such as a local DNS server or a host file override.

**Recommended Additional Steps:**

- **Avoiding Docker Hub Pull Rate Limits**:  
    Given the number of images pulled from Docker Hub during EOEPCA deployment, it’s recommended to authenticate to Docker Hub or configure a Docker Hub proxy registry. This reduces the chance of hitting the `Too Many Requests` rate limit and speeds up the overall deployment process. For detailed instructions, refer to Docker Hub’s [Rate Limit Documentation](https://docs.docker.com/docker-hub/download-rate-limit/).

## Additional Notes

- **Kubernetes Installation**: For installing Kubernetes, refer to external guides:
    - [Kubernetes Setup](https://kubernetes.io/docs/setup/)
    - [Rancher Kubernetes Engine](https://rancher.com/docs/rke/latest/en/)
- **Container Runtime**: Ensure your cluster uses a compatible container runtime (e.g. containerd, Docker).