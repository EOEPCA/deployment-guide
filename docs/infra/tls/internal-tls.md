# Internal TLS Setup Guide

This guide provides step-by-step instructions to set up internal TLS in your Kubernetes cluster using cert-manager. This setup is required for secure internal communication between services like OpenSearch and OpenSearch Dashboards.

---

## Table of Contents

- [Internal TLS Setup Guide](#internal-tls-setup-guide)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Prerequisites](#prerequisites)
  - [Setup Steps](#setup-steps)
    - [1. Install Cert-Manager](#1-install-cert-manager)
    - [2. Create the Self-Signed Issuer](#2-create-the-self-signed-issuer)
    - [3. Create the CA Certificate](#3-create-the-ca-certificate)
    - [4. Create the ClusterIssuer](#4-create-the-clusterissuer)
  - [Validation](#validation)

---

## Introduction

Internal TLS ensures secure communication between services within your Kubernetes cluster. By setting up an internal Certificate Authority (CA) and using cert-manager, you can automate the issuance and management of TLS certificates for internal services.

---

## Prerequisites

Before starting, ensure you have the following:

- **Kubernetes Cluster**: A running Kubernetes cluster (tested on v1.28).
- **kubectl**: Configured to access your cluster.
- **Cert-Manager**: Installed and configured in your cluster.

**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/internal-tls
```

---

## Setup Steps

These setup steps can be automated by running :
```bash
bash setup-internal-tls.sh
```

Alternatively you can set it up manually:
### 1. Install Cert-Manager

If you haven't installed cert-manager, install it using Helm:

```bash
helm repo add jetstack https://charts.jetstack.io && \
helm repo update jetstack && \
\
kubectl create namespace cert-manager && \
\
helm upgrade -i cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.12.2 \
  --set installCRDs=true
```

### 2. Create the Self-Signed Issuer

Create a self-signed Issuer to bootstrap your CA:

```bash
kubectl apply -f certificates/cert-manager-ss-issuer.yaml
```

**Manifest: `certificates/cert-manager-ss-issuer.yaml`**

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

Create a CA certificate signed by the self-signed Issuer:

```bash
kubectl apply -f certificates/cert-manager-ca-cert.yaml
```

**Manifest: `certificates/cert-manager-ca-cert.yaml`**

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

Create a ClusterIssuer that uses the CA certificate:

```bash
kubectl apply -f certificates/cert-manager-ca-issuer.yaml
```

**Manifest: `certificates/cert-manager-ca-issuer.yaml`**

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: eoepca-ca-clusterissuer
spec:
  ca:
    secretName: eoepca-ca-secret
```

---

## Validation

1. Check the status of the CA certificate and ClusterIssuer, ensure that the CA certificate is ready and the ClusterIssuer is available.

```bash
kubectl get certificates -n cert-manager
kubectl describe certificate eoepca-ca -n cert-manager
kubectl get clusterissuer
kubectl describe clusterissuer eoepca-ca-clusterissuer
```

2. Apply the test certificate to validate

```bash
kubectl apply -f certificates/test-server-cert.yaml 
```
