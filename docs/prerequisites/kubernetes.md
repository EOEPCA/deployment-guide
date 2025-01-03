# Kubernetes Requirements

EOEPCA places a few special demands on your Kubernetes cluster. EOEPCA does **not** detail how to install Kubernetes—there are many official and third-party guides. Instead, we focus on specific **EOEPCA demands** you should verify in an existing cluster.

## Requirements

1. **Run Containers as Root (Mandatory)**  

   Some EOEPCA components require root privileges (e.g., certain processing containers). Attempting to run them under a non-root UID can fail. Ensure your cluster’s security policies (PodSecurityPolicies, PodSecurity Standards, or Admission Controllers) allow `root` containers.

2. **Ingress Controller + Wildcard DNS (Mandatory)**  

   - A cluster-level wildcard DNS record: `*.example.com → <Load Balancer IP>`.
   - An ingress controller that supports host-based routing (NGINX, APISIX, etc.).
   - This ensures that each EOEPCA Building Block can expose `service1.example.com`, `service2.example.com`, etc.

3. **Load Balancer with 80/443 (Recommended)**  

   - If your environment is on-prem or in a cloud, you should have a load balancer or external IP that listens on HTTP/HTTPS. 
   - In a development scenario (e.g., Minikube or a single-node Rancher), you can rely on NodePort or port forwarding, but this is **not** recommended for production.

4. **Cert-Manager or Equivalent (Recommended)**  

   - We strongly recommend [cert-manager](https://cert-manager.io/) for TLS automation. 
   - If you prefer manual certificates for dev or air-gapped setups, be prepared to manage rotation.

## Production vs. Development

- **Production**  

    - Leverage a managed Kubernetes cluster (e.g., an enterprise Rancher deployment or a cloud provider’s managed K8S).  
    - Use cert-manager with Let’s Encrypt or your CA for auto-renewed certificates.  
    - Keep your images in a Docker Hub authenticated registry or a private repository to avoid pull-rate issues.

- **Development / Testing**

    - A single-node cluster (Rancher, K3s, Minikube, Docker Desktop) can suffice.  
    - You can manually manage TLS or skip it if everything is internal.  
    - For DNS, you can use a local DNS trick like `nip.io` or edit your `/etc/hosts` as needed (less flexible, though).


## Additional Guidance

- Ensure your container runtime (containerd, Docker, etc.) is up to date and fully compatible with your K8S version.
- Check [Kubernetes official docs](https://kubernetes.io/docs/setup/) or [Rancher docs](https://rancher.com/docs/rke/latest/en/) for installation references.
- If you expect to run many EOEPCA components pulling images from Docker Hub, set up credentials or a proxy to avoid rate limits.