
# TLS Management

TLS plays an essential role in securing both external and internal traffic for EOEPCA. In practice, EOEPCA’s Building Blocks often rely on certificates issued via a `ClusterIssuer`, enabling automatic certificate management for all namespaces in the cluster. We strongly recommend using cert-manager for this purpose.

## Exposed Service TLS

For services that are extrernally exposed via the ingress controller, there are several options to establish the TLS certificates for each service.

### Dynamic using Cert-Manager

   - The simplest, most robust way to handle certificates in production.
   - You can create a `ClusterIssuer` that automatically issues and renews certs from Let’s Encrypt or your own CA.
   - Using either DNS-based or HTTP-based Let's Encrypt challenge approaches
   - In multi-tenant or multi-namespace scenarios, this is especially useful.

### Manual TLS

   - Applicable to cases where use of Let's Encrypt is not possible
   - Kubernetes `Secrets` are created to represent the certificate data
   - Certificates (secrets) must be manually rotated before expiry
   - A single [Global Wildcard Certificate](#global-wildcard-certificate) (applicable to all routes) can be used

## Internal TLS

- Some internal components can also use TLS for pod-to-pod or service-to-service encryption (e.g. an internal OpenSearch cluster). 
- With cert-manager, you can easily issue internal certificates signed by a local CA (`ClusterIssuer`) so that pods trust each other automatically.

## Further Reading

- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [Kubernetes Ingress TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)

## Quick Start

### Using Cert Manager

As a quick start we include instructions to bootstrap _Cert Manager_ into your cluster.

**Wildcard DNS**

Use of Cert Manager presumes that your cluster is reachable over the internet via a publicly routable IP - with an associated wildcard DNS record that is needed for correct routing of dynamic host-based routes established via Ingress resources for cluster services. For example...

```
*.your-domain.    300     IN      CNAME   your-domain.
your-domain.      300     IN      A       your-external-ip-addr
```

**Deploy Cert Manager**

Cert Manager is deployed via helm chart...

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack
helm upgrade -i cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.16.1 \
  --set crds.enabled=true
```

**Create a ClusterIssuer for Let’s Encrypt**

1. Using **HTTP01 Challenge** via APISIX ingress [[ref]](https://letsencrypt.org/docs/challenge-types/#http-01-challenge)

    Set your details for email.

    ```bash
    cat - <<'EOF' | kubectl apply -f -
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-http01-apisix
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: your_email@your-domain
        privateKeySecretRef:
          name: letsencrypt-http01-apisix
        solvers:
          - http01:
              ingress:
                class: apisix
    EOF
    ```

2. Using **DNS01 Challenge** [[ref]](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)

    The following illustrates an example that uses Cloudflare DNS provider.

    Set your details for email and Cloudflare API credentials (via secret).

    ```bash
    cat - <<'EOF' | kubectl apply -f -
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-dns01
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: your_email@your-domain
        privateKeySecretRef:
          name: letsencrypt-dns01
        solvers:
          - dns01:
               cloudflare:
                  apiTokenSecretRef:
                     key: api-token
                     name: cloudflare-api-token
    EOF
    ```

    For other supported DNS providers see the [Cert Manager DNS01 Documentation](https://cert-manager.io/docs/configuration/acme/dns01/).

### Global Wildcard Certificate

Alternatively, if you have a wildcard certificate, then this can be configured into Apisix as a global TLS certificate for all routes.

Represent the wildcard certificate in a `Secret`...

```yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: global-tls-certificate
  namespace: ingress-apisix
data:
  cert: <base64-encoded-certificate>
  key: <base64-encoded-private-key>
```

Configure Apisix global TLS using the certificate.

```yaml
apiVersion: apisix.apache.org/v2
kind: ApisixTls
metadata:
  name: global-tls
  namespace: ingress-apisix
spec:
  hosts:
    - "*.your_domain"  # Replace with your domain
  secret:
    name: global-tls-certificate
    namespace: ingress-apisix
```

---

### Internal TLS

**Clone the Deployment Guide Repository:**

```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/internal-tls
```

**Run the Internal TLS Setup Script:**

```bash
bash setup-internal-tls.sh
```

> This may not work perfectly for all environments, please adjust the script as needed.