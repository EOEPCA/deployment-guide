
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
helm install cert-manager cert-manager \
  --repo https://charts.jetstack.io \
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

3. **Check Certificate Creation**:

   After a short time (approx. 1 minute) the `Certificate` should have been created and stored into the secret `test-app-tls`.

   Check that the associated Kubernetes resources are ready and valid...
   ```bash
   kubectl get orders,certificates,secrets,ingress
   ```

4. **Test Access**:

   - Ensure that `app.your-domain` resolves to your load balancer's public IP.
   - Access `https://app.your-domain` in your browser and verify that you can reach the `httpbin` application, and that the TLS certificate is reported as valid in the browser.

5. **Undeploy Test Resources**:

```bash
kubectl delete ingress/test-app svc/test-app deploy/test-app
```

Note that the secret `test-app-tls` is retained. This can be useful in the case that the ingress is reinstated and so the existing `Certificate` can be used.
