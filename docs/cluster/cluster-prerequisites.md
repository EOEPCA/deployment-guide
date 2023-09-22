# Cluster Prerequisites

The following prerequisite components are assumed to be deployed in the cluster.

## Nginx Ingress Controller

```bash
# Install the Nginx Ingress Controller helm chart
helm upgrade -i --version='<4.5.0' \
  --repo https://kubernetes.github.io/ingress-nginx \
  ingress-nginx ingress-nginx \
  --wait
```
!!! note
    For Kubernetes version 1.22 and earlier the version of the Nginx Ingress Controller must be before v4.5.0.

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
# Install the Cert Manager helm chart
helm upgrade -i --namespace cert-manager --create-namespace \
  --repo https://charts.jetstack.io \
  --set installCRDs=true \
  cert-manager cert-manager
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
helm install --version 2.1.8 --create-namespace --namespace infra \
  --repo https://bitnami-labs.github.io/sealed-secrets \
  eoepca-sealed-secrets sealed-secrets
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

As a workaround, in the absence of an existing object storage, it is possible to use [MinIO](https://min.io/) to establish an object storage service within the Kubernetes cluster. We use the [minio helm chart provided by the MinIO Project](https://charts.min.io/).

```bash
# Install the minio helm chart
helm upgrade -i -f minio-values.yaml --namespace rm --create-namespace \
  --repo https://charts.min.io/ \
  minio minio \
  --wait
```

!!! note
    The Kubernetes namespace `rm` is used above as an example, and can be changed according to your deployment preference.

The minio deployment is customised via the values file `minio-values.yaml`, for example...

```yaml
existingSecret: minio-auth
replicas: 2

ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-read-timeout: '600'
  path: /
  hosts:
    - minio.192-168-49-2.nip.io
  tls:
    - secretName: minio-tls
      hosts:
        - minio.192-168-49-2.nip.io

consoleIngress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-read-timeout: '600'
  path: /
  hosts:
    - console.minio.192-168-49-2.nip.io
  tls:
  - secretName: minio-console-tls
    hosts:
      - console.minio.192-168-49-2.nip.io

resources:
  requests:
    memory: 1Gi

persistence:
  storageClass: standard

buckets:
  - name: eoepca
  - name: cache-bucket
```

!!! note
    * The example values assuming a TLS configuration using `letsencrypt` certificate provider
    * The admin credentials are provided by the Kubernetes secret named `minio-auth` - see below
    * The annotation `nginx.ingress.kubernetes.io/proxy-body-size` was found to be required to allow transfer of large files (such as data products) through the nginx proxy

### Minio Credentials Secret

The Minio admin credentials are provided via a Kubernetes secret that is referenced from the Minio helm chart deployment values. For example...

```
kubectl -n rm create secret generic minio-auth \
  --from-literal=rootUser="eoepca" \
  --from-literal=rootPassword="changeme"
```

!!! note
    The secret must be created in the same Kubernetes namespace as the Minio service deployment - e.g. `rm` namespce in the example above.

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
S3 Endpoint: minio.192-168-49-2.nip.io
DNS-style bucket+hostname:port template for accessing a bucket: minio.192-168-49-2.nip.io
Encryption password: 
Path to GPG program: /usr/bin/gpg
Use HTTPS protocol: True
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
s3cmd -c deploy/cluster/s3cfg ls
```

### References

* [MinIO Website](https://min.io/)
* [MinIO Helm Chart](https://charts.min.io/)
* [MinIO on GitHub](https://github.com/minio/minio)
