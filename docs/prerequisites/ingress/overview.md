# Ingress Overview

EOEPCA+ requires an Ingress Controller to route external traffic into the platform's services. This setup typically depends on **Wildcard DNS** so that multiple services (hostnames) can be exposed under a single domain (e.g. `*.example.com`).

## Two Ingress Options

1. [APISIX Ingress](apisix.md)  
   - Recommended for deeper integration with IAM / Keycloak (supports OIDC and UMA flows).

2. [Nginx Ingress](nginx.md)  
   - A simpler, widely-used option if you don't require IAM-based request authorization.

You can install **either** one for a basic deployment. If your deployment demands multiple ingress controllers simultaneously, see [Multiple Ingress Controllers](ingress-multi.md).

**Before proceeding**:  
- You must have a wildcard DNS entry pointing to your cluster’s load balancer or external IP. For example: `*.myplatform.com`.<br>
- Ensure your cluster is reachable on the required ports (80/443) or has NodePort alternatives set up.  

>  _For testing, wildcard DNS can be simulated using IP-address-based `nip.io` hostnames - using the entrypoint IP-address of your cluster that routes to your ingress controller._

Continue with whichever approach best suits your environment:

- **[Install APISIX →](apisix.md)**  
- **[Install NGINX →](nginx.md)**
