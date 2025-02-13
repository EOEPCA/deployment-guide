# Kubernetes Requirements

EOEPCA places a few special demands on your Kubernetes cluster. EOEPCA does **not** detail how to install Kubernetes—there are many official and third-party guides. Instead, we focus on specific **EOEPCA demands** you should verify in an existing cluster.

## Requirements

1. **Ingress Controller (Mandatory)**

    - An ingress controller that supports host-based routing (NGINX, APISIX, etc.).
    - For use with Cert Manager LetsEncrypt `HTTP01` challenge, then this must be routable from the public internet
    - Ideally combined with Wildcard DNS for public exposure of each EOEPCA Building Block.

2. **Wildcard DNS (Recommended)**

    - A cluster-level wildcard DNS record: `*.example.com → <Load Balancer IP>`.
    - This ensures that each EOEPCA Building Block can expose `service1.example.com`, `service2.example.com`, etc.
    - In the absence of dedicated DNS (e.g. for local development deployment), then host-based routing can be emulated with IP-address-based [`nip.io`](https://nip.io/) hostnames

3. **Run Containers as Root (Mandatory)**  

    Some EOEPCA components require root privileges (e.g., certain processing containers). Attempting to run them under a non-root UID can fail. Ensure your cluster’s security policies (PodSecurityPolicies, PodSecurity Standards, or Admission Controllers) allow `root` containers.

4. **Load Balancer with 80/443 (Recommended)**  

    - If your environment is on-prem or in a cloud, you should have a load balancer or external IP that listens on HTTP/HTTPS. 
    - In a development scenario (e.g., Minikube or a single-node Rancher), you can rely on NodePort or port forwarding, but this is **not** recommended for production.

5. **Cert-Manager or Equivalent (Recommended)**  

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

#### Creating an image pull secret for DockerHub

> We recommend this step if any `helm` deployment is returning `ImagePullBackOff` errors.

For example, docker credentials in the `processing` namespace...

```bash
kubectl create secret docker-registry regcred \
--docker-server="https://index.docker.io/v1/" \
--docker-username="YOUR_DOCKER_USERNAME" \
--docker-password="YOUR_DOCKER_PASSWORD_OR_TOKEN" \
--docker-email="YOUR_EMAIL" \
-n processing
```

> NOTE. Your Kubernetes distribution may provide other means for configuring cluster-wide container registry credentials - e.g. directly within the container runtime of each node within your cluster - as illustrated below with the `--registry-config` option of the `k3d` cluster creation.

## Quick Start

For evaluation and/or development purposes a non-production single node local cluster can be established.

This quick start provides some simple instructions to establish a local development cluster using [`k3d`](https://k3d.io/), which is part of the [Rancher](https://www.rancher.com/quick-start) Kubernetes offering.

**Install `k3d`**

Follow the [Installation Instructions](https://k3d.io/stable/#releases) to install the `k3d` binary.

**Create Kubernetes Cluster**

Cluster creation is initiated by the following command.

```bash
export KUBECONFIG="$PWD/kubeconfig.yaml"
k3d cluster create eoepca \
  --image rancher/k3s:v1.28.7-k3s1 \
  --k3s-arg="--disable=traefik@server:0" \
  --servers 1 --agents 0 \
  --port 31080:31080@loadbalancer \
  --port 31443:31443@loadbalancer
```

The characteristics of the created cluster are:

* KUBECONFIG file created in the file `kubeconfig.yaml` in the current directory
* Cluster name is `eoepca`. Change as desired
* Single node that provides all Kubernetes roles (control-place, master, worker, etc.)
* No ingress controller (which is established elsewhere is this guide)
* Cluster exposes ports 31080 (http) and 31443 (https) as entrypoint. Change as desired

The Kubernetes version of the cluster can be selected via the `--image` option - taking account of:

* **k3s images provided by rancher:** [https://hub.docker.com/r/rancher/k3s/tags](https://hub.docker.com/r/rancher/k3s/tags)
* **Kubernetes Release History:** [https://kubernetes.io/releases/](https://kubernetes.io/releases/)
* **Kubernetes API Deprecations:** [https://kubernetes.io/docs/reference/using-api/deprecation-guide/](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)

**Container registry credentials** can be introduced at cluster creation - e.g. for DockerHub.

* Registry credentials are defined in a dedicated config file (**_registries.yaml_**)...

    ```yaml
    mirrors:
      "docker.io":
        endpoint:
          - https://registry-1.docker.io
    configs:
      "docker.io":
        auth:
          username: mydockeruser
          password: mydockerpassword
    ```

* The file `registries.yaml` is introduced during the `k3d cluster create` command...

    ```bash
    export KUBECONFIG="$PWD/kubeconfig.yaml"
    k3d cluster create eoepca \
      --image rancher/k3s:v1.28.7-k3s1 \
      --k3s-arg="--disable=traefik@server:0" \
      --servers 1 --agents 0 \
      --port 31080:31080@loadbalancer \
      --port 31443:31443@loadbalancer \
      --registry-config "registries.yaml"
    ```

**Storage Provisioner**

As described in the [EOEPCA+ Prerequisites](storage.md), a persistence solution providing `ReadWriteMany` storage is required by some BBs. For this development deployment the single node HostPath Provisioner can be used as described in the [Storage Quick Start](storage.md#quick-start).
