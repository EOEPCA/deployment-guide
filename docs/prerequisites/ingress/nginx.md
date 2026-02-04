# Nginx Ingress

> **Important:** The NGINX ingress should **only be used for open deployments** where EOEPCA's IAM-based request authorization is **not required** - or you are integrating your own IAM approach. If you are following the IAM integration and request authorization approach described in this guide, then select the **APISIX Ingress** instead.

This document provides instructions to deploy [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) for EOEPCA+. 

> See also [Ingress Gateway](./gateway.md) for more advanced ingress scenarios.

## Quickstart Installation

> **Disclaimer:** We recommend following the official installation instructions for the NGINX Ingress Controller. However, this quick start guide should also work for most environments.

The deployment configuration below assumes that the Kubernetes cluster exposes NodePorts `31080` (http) and `31443` (https) for external access to the cluster. This presumes that a (cloud) load balancer or similar is configured to forward public `80/443` traffic to these exposed ports on the cluster nodes.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.allowSnippetAnnotations=true \
  --set controller.config.ssl-redirect=true \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=31080 \
  --set controller.service.nodePorts.https=31443
```

Adjust parameters as needed (e.g. `NodePort` vs. `LoadBalancer` service).

### Forced TLS Redirection

The above configuration enables forced TLS redirection via the NGINX controller config (`ssl-redirect="true"`).

This global redirect can be disabled for specific Ingress resources with the `annotation`:

```yaml
nginx.ingress.kubernetes.io/ssl-redirect: "false"
```

## NGINX Uninstallation

```bash
helm -n ingress-nginx uninstall ingress-nginx
kubectl delete ns ingress-nginx
```
