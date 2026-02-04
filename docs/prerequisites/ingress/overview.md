# Ingress Overview

EOEPCA+ requires an Ingress Controller to route external traffic into the platform's services. This setup typically depends on **Wildcard DNS** so that multiple services (hostnames) can be exposed under a single domain (e.g. `*.example.com`).

## Ingress Options

This guide supports two primary ingress controller options:

1. [APISIX Ingress](apisix.md)<br>
   **Required** if following the IAM aspects of this guide which relies upon APISIX plugins for IAM integration, with policy-based access control.

1. [Nginx Ingress](nginx.md)<br>
   **Suitable only** for open-access scenarios (in accordance with this guide), or where you are integrating your own IAM approach with the deployment.

You must choose one of these ingress controllers based on your security and access control requirements:

> You can install **either** one for a basic deployment.

- For deployments **requiring EOEPCA's IAM-based authorization**, you must use **APISIX**.
- For deployments that are **fully open or have their own authorization approach**, **NGINX** can be used.

## Advanced Scenarios

If your ingress needs are more complex, for example you have an existing ingress controller or require use of multiple ingress controllers - then you might consider exposing the entrypoint to your cluster via an ingress gateway - see section [Ingress Gateway](./gateway.md) for an example approach.

## Before proceeding

- Ensure a wildcard DNS entry is pointing to your cluster's load balancer or external IP, e.g., `*.myplatform.com`.  
- Confirm your cluster is reachable on the required ports (80/443) or has NodePort alternatives set up.  

> _For testing, wildcard DNS can be simulated using IP-address-based `nip.io` hostnames, using the entrypoint IP-address of your cluster that routes to your ingress controller._

## Next Steps

Continue with the approach best suited for your environment:

- **[Install APISIX →](apisix.md)**  
- **[Install NGINX →](nginx.md)**
