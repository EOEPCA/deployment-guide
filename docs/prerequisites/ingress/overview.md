# Ingress Overview

EOEPCA+ requires an Ingress Controller to route external traffic into the platform's services. This setup typically depends on **Wildcard DNS** so that multiple services (hostnames) can be exposed under a single domain (e.g. `*.example.com`).

## Ingress Options

This guide supports two primary ingress controller options. You must choose one of these based on your security and access control requirements.

!!! tip
    You can install **either** one for a basic deployment.

<div class="grid cards" markdown>

-   :material-shield-lock:{ .lg .middle } **APISIX Ingress**

    ---

    **Required** if following the IAM aspects of this guide, which rely upon APISIX plugins for IAM integration, with policy-based access control.

    [:octicons-arrow-right-24: Install APISIX](apisix.md)

-   :material-lock-open-variant:{ .lg .middle } **Nginx Ingress**

    ---

    **Suitable only** for open-access scenarios (in accordance with this guide), or where you are integrating your own IAM approach with the deployment.

    [:octicons-arrow-right-24: Install NGINX](nginx.md)

</div>

## Advanced Scenarios

If your ingress needs are more complex, for example you have an existing ingress controller or require use of multiple ingress controllers - then you might consider exposing the entrypoint to your cluster via an ingress gateway - see section [Ingress Gateway](./gateway.md) for an example approach.

## Before proceeding

- Ensure a wildcard DNS entry is pointing to your cluster's load balancer or external IP, e.g., `*.myplatform.com`.
- Confirm your cluster is reachable on the required ports (80/443) or has NodePort alternatives set up.

!!! tip
    For testing, wildcard DNS can be simulated using IP-address-based `nip.io` hostnames, using the entrypoint IP-address of your cluster that routes to your ingress controller.
