
### Option 1: Using Cert-Manager with Let's Encrypt

**Prerequisites**:

- Your cluster must be accessible over the internet.
- Assumes that a wilcard DNS record is configured for your cluster domain.<br>
  This is necessary for correct routing of dynamic host-based routes established via Ingress resources for cluster services.<br>
  For example,<br>
  ```
  *.your-domain.    300     IN      CNAME   your-domain.
  your-domain.      300     IN      A       your-external-ip-addr
  ```

**Steps**:

1. **Install Cert-Manager**:

```bash
helm repo add jetstack https://charts.jetstack.io && \
helm repo update jetstack && \
helm upgrade -i cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.16.1 \
  --set crds.enabled=true
```

2. **Create a ClusterIssuer for Let's Encrypt**:

   **_Update the email address (your_email@your-domain) to use an email address appropriate to the administrator of the cluster_**

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


Within the scripted deployment of the Building Block components, you will be asked for your `Cluster Issuer`. This should correspond to the name set in `letsencrypt-clusterissuer.yaml`, which in this example is: `letsencrypt-prod`. 

Cert-Manager will handle certificate issuance and renewal automatically.

3. **(Optional) Create a ClusterIssuer for APISIX Routes**:

If you are using the APISIX Ingress Controller - as described in section [Ingress Controller Setup](../ingress-controller.md#apisix-ingress-controller) - then configure a _ClusterIssuer_ utilising the `apisix` ingress class name...

   ```yaml
   # letsencrypt-clusterissuer-apisix.yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod-apx
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: your_email@your-domain
       privateKeySecretRef:
         name: letsencrypt-prod-apx
       solvers:
         - http01:
             ingress:
               class: apisix
   ```

   Apply the configuration:

   ```bash
   kubectl apply -f letsencrypt-clusterissuer-apisix.yaml
   ```

---

## Validation

1. **Deploy a Test Application**:

   Deploy a simple application and expose it via a service.

```bash
kubectl create deployment test-app --image=kennethreitz/httpbin && \
kubectl expose deploy/test-app --port 80
```

2. **Create an Ingress Resource**:

   Create an ingress resource that routes traffic to your test application - requesting TLS to be established via the `letsencrypt-prod` Cluster Issuer.

   **_Update the ingress host (app.your-domain) to use the correct domain for your deployment_**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app
  namespace: default
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

2b. **(Optional) Create ingress via APISIX**:

   Use APISIX to route traffic to your test application - requesting TLS to be established via the `letsencrypt-prod-apx` Cluster Issuer.

   **_Update the ingress host (app-apx.your-domain) to use the correct domain for your deployment - noting the use of the host postfix `-apx` depending on which [Ingress Controller Setup](../ingress-controller.md#provisioning-approaches) approach was followed_**

```yaml
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: test-app-apx
spec:
  http:
    - name: test-app-apx
      backends:
        - serviceName: test-app
          servicePort: 80
      match:
        hosts:
          - app-apx.your-domain
        paths:
          - /*
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-app-apx
spec:
  dnsNames:
    - app-apx.your-domain
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod-apx
  secretName: test-app-apx-tls
  usages:
    - digital signature
    - key encipherment
    - server auth
---
apiVersion: apisix.apache.org/v2
kind: ApisixTls
metadata:
  name: test-app-apx
spec:
  hosts:
    - app-apx.your-domain
  secret:
    name: test-app-apx-tls
    namespace: default
```

3. **Check Certificate Creation**:

   After a short time (approx. 1 minute) the `Certificate` should have been created and stored into the secret `test-app-tls` (and optionally `test-app-apx-tls`).

   Check that the associated Kubernetes resources are ready and valid...
   ```bash
   kubectl get orders,certificates,secrets,ingress
   ```

   For APISIX...
   ```bash
   kubectl get orders,certificates,secrets,apisixroute,apisixtls
   ```

4. **Test Access**:

   - Ensure that `app.your-domain` (and optionally `app-apx.your-domain`) resolves to your load balancer's public IP.
   - Access `https://app.your-domain` (and optionally `https://app-apx.your-domain`) in your browser and verify that you can reach the `httpbin` application, and that the TLS certificate is reported as valid in the browser.

5. **Undeploy Test Resources**:

```bash
kubectl delete ingress/test-app svc/test-app deploy/test-app
```

Note that the secret `test-app-tls` is retained. This can be useful in the case that the ingress is reinstated and so the existing `Certificate` can be used.
