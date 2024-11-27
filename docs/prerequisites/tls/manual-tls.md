
# Option 2: Manual TLS Certificate Management

> Please note that this is just one suggested way to manage TLS certificates. Depending on your environment and requirements, you might choose a different approach.

**When to Use This Option**:

- If you manage certificates via an internal Certificate Authority (CA) or external services.
- Ideal for development, testing, or internal setups where you prefer a simplified TLS configuration.

**Simplify TLS with a Wildcard Certificate**:

By using a single wildcard TLS certificate at the ingress controller level, you can cover all subdomains of your ingress host domain (e.g., `*.example.com`). This eliminates the need for individual certificates for each service.

**Suggested Steps**:

1. **Obtain a Wildcard TLS Certificate**:
    
- Get a wildcard TLS certificate for your domain (e.g., `*.example.com`) from your internal CA or a trusted provider.
- Ensure the certificate's **Common Name (CN)** is set to `*.your-domain`.

2. **Create a Kubernetes TLS Secret in the Ingress Namespace**:
    
- Find the namespace of your ingress controller (commonly `ingress-nginx`).
    
- Create a TLS secret:
    
```bash
kubectl create secret tls wildcard-tls \
  --cert=path/to/wildcard.crt \
  --key=path/to/wildcard.key \
  -n <ingress-namespace>
```

Replace `<ingress-namespace>` with your actual namespace.
        
3. **Configure the Ingress Controller to Use the Wildcard Certificate**:
    
**For NGINX Ingress Controller**:
    
Add to your ingress controller configuration (e.g., in `values.yaml` if using Helm):

```yaml
controller:
  extraArgs:
    default-ssl-certificate: "<ingress-namespace>/wildcard-tls"
```
    
4. **Verify the TLS Configuration**:
    
- Restart the ingress controller to apply changes:
    
```bash
kubectl rollout restart deployment <ingress-controller-deployment-name> -n <ingress-namespace>
```

Replace `<ingress-controller-deployment-name>` with your deployment name.
    
- Test accessing your services via HTTPS to ensure the wildcard certificate is being used.
        

**Proceed with Deployments**:

With the wildcard TLS certificate set up, you can deploy your Building Blocks without creating individual TLS secrets.

