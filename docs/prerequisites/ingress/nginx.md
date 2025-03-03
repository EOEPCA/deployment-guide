# Nginx Ingress

This document provides instructions to deploy [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) for EOEPCA+. This is a simpler alternative to APISIX if you don't require advanced features like IAM-based request authorization.

## Installation

Below is a minimal example using Helm:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.ingressClassResource.default=true \
  --set controller.allowSnippetAnnotations=true \
  --set controller.service.type=LoadBalancer
```

Adjust parameters as needed (e.g., `NodePort` vs. `LoadBalancer` service).

### Forced TLS Redirection

By default, if you want to force HTTP→HTTPS redirection, you can use an [ingress annotation or config snippet](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#force-ssl-redirect). For instance:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - "my-service.example.com"
      secretName: my-service-tls
  rules:
    - host: my-service.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

### Uninstallation

```bash
helm -n ingress-nginx uninstall ingress-nginx
kubectl delete ns ingress-nginx
```

**Next Steps**  
Once NGINX is installed, you can proceed with applying your EOEPCA+ ingress rules (or Helm chart values) referencing `ingressClassName: nginx`. 