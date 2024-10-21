# Ingress Controller Setup Guide

This guide provides instructions to install and configure an ingress controller for your Kubernetes cluster. The ingress controller manages external access to the services in your cluster, typically via HTTP and HTTPS.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Installing the Ingress Controller](#installing-the-ingress-controller)
4. [Configuring the Ingress Controller](#configuring-the-ingress-controller)
5. [Validation](#validation)
6. [Further Reading](#further-reading)

---

## Introduction

An ingress controller is a necessary component for managing external access to the services within your Kubernetes cluster. It listens for ingress resources and routes traffic accordingly.

---

## Prerequisites

- A running Kubernetes cluster.
- `kubectl` and `helm` installed and configured to interact with your cluster.
- A domain name pointing to your cluster's load balancer.

---

## Installing the Ingress Controller

We'll use the NGINX Ingress Controller in this example.

1. **Add the Ingress NGINX Helm Repository**:

   ```bash
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update
   ```

2. **Install the Ingress NGINX Controller**:

   ```bash
   helm install ingress-nginx ingress-nginx/ingress-nginx \
     --namespace ingress-nginx --create-namespace \
     --set controller.service.type=NodePort \
     --set controller.service.nodePorts.http=31080 \
     --set controller.service.nodePorts.https=31443 \
     --set controller.ingressClassResource.default=true
   ```

3. **Configure Load Balancer Backend**:

   - Update your load balancer to forward ports 80 and 443 to the ingress controller's NodePorts (`31080` and `31443`) on the worker nodes.

---

## Validation

1. **Deploy a Test Application**:

   Deploy a simple application and expose it via a service.

2. **Create an Ingress Resource**:

   Create an ingress resource that routes traffic to your test application.

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: test-ingress
     namespace: default
   spec:
     ingressClassName: nginx
     rules:
       - host: app.example.com
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: test-service
                   port:
                     number: 80
   ```

3. **Test Access**:

   - Ensure that `app.example.com` resolves to your load balancer's public IP.
   - Access `http://app.example.com` in your browser and verify that you can reach your application.

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