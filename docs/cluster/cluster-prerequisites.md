# Cluster Prerequisites

The following prerequisite components are assumed to be deployed in the cluster.

## Nginx Ingress Controller

```bash
# Add the helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install the Nginx Ingress Controller helm chart
helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx --wait
```

To target the _Nginx Ingress Controller_ the `kubernetes.io/ingress.class: nginx` annotation must be applied to the Ingress resource...
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
    ...
```

## Cert Manager

```bash
# Add the helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install the Cert Manager helm chart
helm upgrade -i cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

## Letsencrypt Certificates

Once the _Certificate Manager_ is deployed, then we can establish `ClusterIssuer` operators in the cluster to support use of TLS with service `Ingress` endpoints.

For _Letsencrypt_ we can define two `ClusterIssuer` - for `production` and for `staging`.

_NOTE that these require the cluster to be publicly accessible, in order for the `http01` acme flow to verify the domain ownership. Local development deployments will typically not have public IP/DNS - in which case the system deployment can proceed, but without TLS support for the service endpoints._

### Production

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: eoepca.systemteam@telespazio.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: letsencrypt-production-account-key
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
      - http01:
          ingress:
            class: nginx
```

### Staging

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: eoepca.systemteam@telespazio.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: letsencrypt-staging-account-key
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
      - http01:
          ingress:
            class: nginx
```

To exploit the specified ClusterIssuer the `cert-manager.io/cluster-issuer` annotation must be applied to the Ingress resource. For example...
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-production
    ...
```

## Sealed Secrets

The EOEPCA development team maintain their deployment configurations in GitHub - for declarative, reproducible cluster deployments.

Various `Secret` are relied upon by the system services. Secrets should not be exposed by commit to GitHub.

Instead [`SealedSecret`](https://github.com/bitnami-labs/sealed-secrets) are committed to GitHub, which are encrypted, and can only be decrypted by the `sealed-secret-controller` that runs within the cluster. The `sealed-secret-controller` decrypts the `SealedSecret` to a regular `Secret` (of the same name) that can then be consumed by the cluster components.

The `sealed-secret-controller` is deployed to the cluster using the helm chart...

```bash
helm repo add bitnami-sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm install --version 2.1.8 --create-namespace --namespace infra \
  eoepca-sealed-secrets bitnami-sealed-secrets/sealed-secrets
```

Once the controller is deployed within the cluster, then the [`kubeseal`](https://github.com/bitnami-labs/sealed-secrets/releases/tag/v0.15.0) command can be used to create a `SealedSecret` from a regular `Secret`, as follows...

Create example Secret...
```bash
kubectl -n test create secret generic mysecret \
  --from-literal=password=changeme \
  --dry-run=client -o yaml \
  > mysecret.yaml
```

Create SealedSecret from Secret using kubeseal...
```bash
kubeseal -o yaml \
  --controller-name eoepca-sealed-secrets \
  --controller-namespace infra \
  < mysecret.yaml \
  > mysecret-sealed.yaml
```

### References

* [Sealed Secrets on GitHub](https://github.com/bitnami-labs/sealed-secrets)
* [`kubeseal` Release](https://github.com/bitnami-labs/sealed-secrets/releases/tag/v0.15.0)

## MinIO Object Storage

Various building blocks require access to an S3-compatible object storage service. In particular the ADES processing service expects to stage-out its processing results to S3 object storage. Ideally the cloud provider for your deployment will make available a suitable object storage service.

As a workaround, in the absence of an existing object storage, it is possible to use [MinIO](https://min.io/) to establish an object storage service within the Kubernetes cluster. We use the [minio helm chart provided by bitnami](https://bitnami.com/stack/minio/helm).

```bash
# Add the bitnami helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install the minio helm chart
helm upgrade -i minio -f minio-values.yaml bitnami/minio
```

The minio deployment is customised via the values file `minio-values.yaml`, for example...

```yaml
auth:
  rootUser: eoepca
  rootPassword: changeme

ingress:
  enabled: true
  ingressClassName: nginx
  hostname: minio-console.192.168.49.123.nip.io

apiIngress:
  enabled: true
  ingressClassName: nginx
  hostname: minio.192.168.49.123.nip.io

persistence:
  storageClass: standard
```

### s3cmd Configuration

The `s3cmd` can be configured for access to the MinIO deployment. The `--configure` option can be used to prepare a suitable configuration file for `s3cmd`...

```bash
s3cmd -c mys3cfg --configure
```

In response to the prompts, the following configuration selections are applicable to the above settings...

```
Access Key: eoepca
Secret Key: changeme
Default Region: us-east-1
S3 Endpoint: minio.192.168.49.123.nip.io
DNS-style bucket+hostname:port template for accessing a bucket: minio.192.168.49.123.nip.io
Encryption password: 
Path to GPG program: /usr/bin/gpg
Use HTTPS protocol: False
HTTP Proxy server name: 
HTTP Proxy server port: 0
```

Save the configuration file, and check access to the S3 object store with...

```bash
# Create a bucket
s3cmd -c mys3cfg mb s3://eoepca

# List buckets
s3cmd -c mys3cfg ls
```

For example, using our sample deployment, the following can be used to interface with the MinIO service deployed in minikube...
```bash
s3cmd -c deploy/cluster/minio/s3cfg ls
```

### References

* [MinIO Helm Chart](https://bitnami.com/stack/minio/helm)
* [MinIO Helm Chart on GitHub](https://github.com/bitnami/charts/tree/master/bitnami/minio)
