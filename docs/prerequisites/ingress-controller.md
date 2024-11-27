
# Ingress Controller Setup Guide

An ingress controller is required to manage external access to services within the EOEPCA+ Kubernetes cluster.

## Requirements

- **Ingress Controller with Wildcard DNS Support**: **Required** for dynamic host-based routing.
- **Supports Running Containers as Root**: Necessary for certain EOEPCA components.

## Ingress Controller Options

### **APISIX Ingress Controller**

**Recommended for Production**.

For installation instructions follow the [APISIX Installation Guide](https://apisix.apache.org/docs/ingress-controller/getting-started/).

### **NGINX Ingress Controller**

**Suitable for Development and Testing**.

Install NGINX Ingress Controller using Helm:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx
```

## Additional Notes

- **Wildcard DNS**: Ensure a wildcard DNS record is configured for your domain.
- **Ingress Class**: Specify the ingress class in your ingress resources for example `nginx` for NGINX, `apisix` for APISIX.

## Further Reading

- **Kubernetes Ingress Concepts**: [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- **APISIX Documentation**: [APISIX Ingress Controller](https://apisix.apache.org/docs/ingress-controller/)
- **NGINX Documentation**: [Ingress-NGINX Controller](https://kubernetes.github.io/ingress-nginx/)