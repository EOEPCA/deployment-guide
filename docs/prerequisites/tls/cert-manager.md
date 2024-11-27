
# Option 1: Using Cert-Manager with Let's Encrypt

**Prerequisites**:

- Your cluster must be accessible over the internet.
- A wildcard DNS record is configured for your cluster domain to support dynamic host-based routing via Ingress resources. For example:

```
*.your-domain.    300     IN      CNAME   your-domain.
your-domain.      300     IN      A       your-external-ip-addr
```

**Steps**:

1. **Install Cert-Manager**:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade -i cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.16.1 \
  --set crds.enabled=true
```

2. **Create a ClusterIssuer for Let's Encrypt**:

Update the email address (`your_email@your-domain`) with an administrator email.

```yaml
# letsencrypt-clusterissuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your_email@your-domain
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

Apply the configuration:

```bash
kubectl apply -f letsencrypt-clusterissuer.yaml
```

During the deployment of the Building Blocks, you will be asked for your `Cluster Issuer`. Use the name specified in `letsencrypt-clusterissuer.yaml`, which in this example is `letsencrypt-prod`.

Cert-Manager will automatically handle certificate issuance and renewal.

  
---

## Validation

1. **Deploy a Test Application**:

```bash
kubectl create deployment test-app --image=kennethreitz/httpbin
kubectl expose deployment test-app --port=80
```

2. **Create an Ingress Resource**:

Update the ingress host (`app.your-domain`) to match your domain.

```yaml
# test-app-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: app.your-domain
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: test-app
                port:
                  number: 80
  tls:
    - hosts:
        - app.your-domain
      secretName: test-app-tls
```

Apply the configuration:

```bash
kubectl apply -f test-app-ingress.yaml
```

3. **Check Certificate Creation**:

After a minute, the certificate should be created and stored in the secret `test-app-tls`. Verify the resources:

```bash
kubectl get certificates,secrets,ingress
```

4. **Test Access**:

- Ensure `app.your-domain` resolves to your load balancer's public IP.
- Access `https://app.your-domain` in a browser and verify the TLS certificate is valid.

5. **Clean Up**:

```bash
kubectl delete ingress/test-app service/test-app deployment/test-app
```

Note: The secret `test-app-tls` is retained, which can be useful if you redeploy the ingress.