
# Ingress and DNS Requirements

EOEPCA requires that services be accessible via a wildcard DNS. The ingress controller should support host-based routing and be compatible with running containers as root. While there’s no strict requirement on which ingress controller to use, common choices include NGINX for development and APISIX or similar for production.

**Requirements:**

- **Wildcard DNS**: You must have a wildcard DNS entry pointing to your cluster’s load balancer or external IP. For example: `*.your-domain.com`.
- **Ingress Controller**: NGINX is easy to install for testing; APISIX or another high-performance controller may be used in production.

**Production vs Development:**

- **Production**:  
    - Ensure a stable and supported ingress controller (e.g. APISIX).  
    - A fully functional wildcard DNS record.
  
- **Development / Testing**:  
    - NGINX Ingress Controller installed via Helm.  
    - Local or makeshift DNS solutions (e.g. nip.io) might be acceptable for internal demos.

## Additional Notes

- **Wildcard DNS**: Ensure a wildcard DNS record is configured for your domain.
- **Ingress Class**: Specify the ingress class in your ingress resources for example `nginx` for NGINX, `apisix` for APISIX.

## Further Reading

- **Kubernetes Ingress Concepts**: [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- **APISIX Documentation**: [APISIX Ingress Controller](https://apisix.apache.org/docs/ingress-controller/)
- **NGINX Documentation**: [Ingress-NGINX Controller](https://kubernetes.github.io/ingress-nginx/)