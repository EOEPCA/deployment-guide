
# Internal TLS Setup Guide

This guide provides step-by-step instructions to set up internal TLS in your Kubernetes cluster using cert-manager. This is required for secure internal communication between services like OpenSearch and OpenSearch Dashboards.

## Prerequisites

- **Kubernetes Cluster**: Running Kubernetes cluster (tested on v1.28).
- **kubectl**: Configured to access your cluster.
- **Cert-Manager**: Installed and configured.

**Clone the Deployment Guide Repository**:

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/internal-tls
```

## Setup Steps

To automate the setup, run:

```bash
bash setup-internal-tls.sh
```

Alternatively, follow the manual steps below.

### 1. Install Cert-Manager

If not already installed:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl create namespace cert-manager
helm upgrade -i cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.12.2 \
  --set installCRDs=true
```

### 2. Create a Self-Signed Issuer

```bash
kubectl apply -f certificates/cert-manager-ss-issuer.yaml
```

**cert-manager-ss-issuer.yaml**:

```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: eoepca-selfsigned-issuer
  namespace: cert-manager
spec:
  selfSigned: {}
```

### 3. Create the CA Certificate

```bash
kubectl apply -f certificates/cert-manager-ca-cert.yaml
```

**cert-manager-ca-cert.yaml**:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: eoepca-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: "EOEPCA Root CA"
  subject:
    organizations:
      - EOEPCA
    organizationalUnits:
      - Certificate Authority
  secretName: eoepca-ca-secret
  privateKey:
    algorithm: RSA
    size: 2048
  issuerRef:
    name: eoepca-selfsigned-issuer
    kind: Issuer
```

### 4. Create the ClusterIssuer

```bash
kubectl apply -f certificates/cert-manager-ca-issuer.yaml
```

**cert-manager-ca-issuer.yaml**:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: eoepca-ca-clusterissuer
spec:
  ca:
    secretName: eoepca-ca-secret
```

## Validation

1. **Check the Status**:

   ```bash
   kubectl get certificates -n cert-manager
   kubectl describe certificate eoepca-ca -n cert-manager
   kubectl get clusterissuer
   kubectl describe clusterissuer eoepca-ca-clusterissuer
   ```

2. **Apply a Test Certificate**:

   ```bash
   kubectl apply -f certificates/test-server-cert.yaml
   ```
