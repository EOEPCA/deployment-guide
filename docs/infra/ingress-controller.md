# Ingress Controller Setup Guide

This guide provides instructions to install and configure an ingress controller for your Kubernetes cluster. The ingress controller manages external access to the services in your cluster, typically via HTTP and HTTPS.

---

## Introduction

An ingress controller is a necessary component for managing external access to the services within your Kubernetes cluster. It listens for ingress resources and routes traffic accordingly.

---

## Prerequisites

- A running Kubernetes cluster.
- `kubectl` and `helm` installed and configured to interact with your cluster.
- A domain name pointing to your cluster's load balancer.

The Ingress Controller typically relies upon a Load Balancer to listen on the public IP address and forward http/https traffic to the cluster nodes - as described in section [Deploy the Load Balancer](kubernetes-cluster-and-networking.md#3-deploy-the-load-balancer). 

A local single-node development cluster can be provisioned without the need for a Load Balancer - if the Ingress Controller can be configured to listen directly on the external IP address - or if external DNS routing is not required.

---

## Installing the Ingress Controller

We'll use the NGINX Ingress Controller in this example.

1. **Install the Ingress NGINX Controller**:

    ```bash
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && \
    helm repo update ingress-nginx && \
    helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
      --namespace ingress-nginx --create-namespace \
      --set controller.service.type=NodePort \
      --set controller.service.nodePorts.http=31080 \
      --set controller.service.nodePorts.https=31443 \
      --set controller.ingressClassResource.default=true \
      --set controller.allowSnippetAnnotations=true
    ```

2. **Configure Load Balancer Backend**:

   - Update your load balancer to forward ports 80 and 443 to the ingress controller's NodePorts (`31080` and `31443`) on the worker nodes.

---

## Validation

1. **Deploy a Test Application**:

   Deploy a simple application and expose it via a service.

```bash
kubectl create deployment test-app --image=kennethreitz/httpbin && \
kubectl expose deploy/test-app --port 80
```

2. **Create an Ingress Resource**:

   Create an ingress resource that routes traffic to your test application.

  > Update the ingress host (app.your-domain) to use the correct domain for your deployment

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: test-app
     namespace: default
   spec:
     ingressClassName: nginx
     rules:
       - host: app.your-domain
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: test-app
                   port:
                     number: 80
   ```

3. **Test Access**:

   - Ensure that `app.your-domain` resolves to your load balancer's public IP.
   - Access `http://app.your-domain` in your browser and verify that you can reach the `httpbin` application.

4. **Undeploy Test Resources**:

```bash
kubectl delete ingress/test-app svc/test-app deploy/test-app
```

---

## Next Steps

Now that your Kubernetes cluster is up and running, you need to set up additional components that are essential for deploying EOEPCA+ building blocks. These components often vary between deployments, so we've provided separate guides for each:

1. **TLS Certificate Management**:

   - Configure TLS certificates for secure communication.
   - Options include using `cert-manager` with Let's Encrypt, self-signed certificates, or manual certificate management.
   - See the [TLS Certificate Management Guide](tls/overview.md) for detailed instructions.

2. **Storage Provisioning**:

   - Set up a storage provisioner, such as NFS, for dynamic volume provisioning.
   - See the [Storage Classes Setup Guide](storage/storage-classes.md) for detailed instructions.

---

## Further Reading

- **Ingress NGINX Documentation**: [Ingress NGINX Docs](https://kubernetes.github.io/ingress-nginx/)