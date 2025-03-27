# Ingress Overview

EOEPCA+ requires an Ingress Controller to route external traffic into the platform's services. This setup typically depends on **Wildcard DNS** so that multiple services (hostnames) can be exposed under a single domain (e.g. `*.example.com`).

## Two Ingress Options

1. [APISIX Ingress](apisix.md)  
   - **Recommended** if following the IAM spects of this guide which relies upon APISIX plugins for IAM integration, with policy-based access control.

2. [Nginx Ingress](nginx.md)  
   - **Suitable only** for open-access scenarios (in accordance with this guide), or where you are integrating your own IAM approach with the deployment.

You must choose one of these ingress controllers based on your security and access control requirements:

- For deployments **requiring EOEPCA's IAM-based authorization**, you must use **APISIX**.
- For deployments that are **fully open or have their own authorization approach**, **NGINX** can be used.

You can install **either** one for a basic deployment. If your deployment demands multiple ingress controllers simultaneously, see [Multiple Ingress Controllers](ingress-multi.md).

**Before proceeding:**  
- Ensure a wildcard DNS entry is pointing to your cluster’s load balancer or external IP, e.g., `*.myplatform.com`.  
- Confirm your cluster is reachable on the required ports (80/443) or has NodePort alternatives set up.  

> _For testing, wildcard DNS can be simulated using IP-address-based `nip.io` hostnames, using the entrypoint IP-address of your cluster that routes to your ingress controller._

Continue with the approach best suited for your environment:

- **[Install APISIX →](apisix.md)**  
- **[Install NGINX →](nginx.md)**
