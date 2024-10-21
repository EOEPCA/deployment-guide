
### Option 1: Using Cert-Manager with Let's Encrypt

**Prerequisites**:

- Your cluster must be accessible over the internet.

**Steps**:

1. **Install Cert-Manager**:

   ```bash
   helm repo add jetstack https://charts.jetstack.io
   helm repo update

   kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.11.0/cert-manager.crds.yaml

   helm install cert-manager jetstack/cert-manager \
     --namespace cert-manager --create-namespace \
     --version v1.11.0
   ```

2. **Create a ClusterIssuer for Let's Encrypt**:

   ```yaml
   # letsencrypt-clusterissuer.yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: your_email@example.com
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


Within the scripted deployment of the Building Block components, you will be asked for your `Cluster Issuer`. This should correspond to the name set intside of `letsencrypt-clusterissuer.yaml`, which in this example is: `letsencrypt-prod`. 

Cert-Manager will handle certificate issuance and renewal automatically.
