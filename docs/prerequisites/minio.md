# EOEPCA+ MinIO Deployment Guide

MinIO is a high-performance object storage system that's compatible with the Amazon S3 API. In the EOEPCA+ ecosystem, MinIO can serve as the object storage backend for various services, including user workspaces, MLOps and other data storage needs. This does not preclude the possibility to configure an alternaive S3-compatible object storage solution.

This guide provides instructions to deploy MinIO in your Kubernetes cluster.

---
## Introduction

MinIO provides a scalable and high-performance object storage solution that's compatible with AWS S3 APIs. It's used within the EOEPCA+ platform to store and manage data securely.

---
## Prerequisites

Before you begin, make sure you have the following:

| Component        | Requirement                            | Documentation Link                                                |
| ---------------- | -------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.28)              | [Installation Guide](kubernetes.md)             |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| Ingress          | Properly installed                     | [Ingress Controller Setup Guide](ingress-controller.md)     |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](tls.md) |

**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/minio
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

---
## Deployment Steps

### 1. Configure MinIO

Run the configuration script:

```bash
bash configure-minio.sh
```

**During the script execution, you will be prompted for:**

- **`INGRESS_HOST`**: Base domain for ingress hosts.
    - *Example*: `example.com`
- **`CLUSTER_ISSUER`** (if using `cert-manager`): Name of the ClusterIssuer.
    - *Example*: `letsencrypt-http01-apisix`
- **`STORAGE_CLASS`**: Storage class for persistent volumes.
    - *Example*: `standard`

**Important Notes:**

- If you choose **not** to use `cert-manager`, you will need to create the TLS secrets manually before deploying.
  - The required TLS secret names are:
    - `minio-tls`
    - `minio-console-tls`
  - For instructions on creating TLS secrets manually, please refer to section [Manual TLS](tls.md#manual-tls).

### 2. Deploy MinIO

Install MinIO using Helm:

```bash
helm repo add minio https://charts.min.io/ && \
helm repo update minio && \
helm upgrade -i minio minio/minio \
  --version 5.2.0 \
  --values server/generated-values.yaml \
  --namespace minio \
  --create-namespace
```

### 3. Create Access Keys

Access the MinIO Console to create access keys:

1. Navigate to `https://console-minio.<your-domain>/access-keys/new-account`
2. Log in using the **MinIO User** (`user`) and **MinIO Password** generated during the configuration step - see file `~/.eoepca/state`.
3. Under `Access Keys` select to `Create access key +`
4. Note down or download the **Access Key** and **Secret Key**.

Run the following script to save these keys to your EOEPCA+ state file:

```bash
bash ./apply-secrets.sh
```

> By saving these keys to the *EOEPCA+ state file*, the credentials will be automatically set during the deployment of S3-integrated Building Blocks.

---


## Validation

**Automated Validation:**

```bash
bash validation.sh
```

This script performs several checks to validate your MinIO deployment:

**Pod and Service Checks**: Verifies that all MinIO pods are running and services are available.

**Endpoint Checks**: Confirms that the MinIO endpoints are accessible and return the expected HTTP status codes.

**Functionality Tests**:
  - Creates a test bucket.
  - Uploads a test file to the bucket.
  - Deletes the test file.
  - Deletes the test bucket.

> **Note**: The script uses the AWS CLI to interact with MinIO. Ensure that the AWS CLI is installed and configured on your machine. Please refer to the [Official AWS Documentation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) for installation instructions.

---

**Manual Validation:**

1. **Check Kubernetes Resources:**

```bash
kubectl get all -n minio
```

2. **Access Dashboard:**

```
https://console-minio.<your-domain>
```

3. **Log In**:

   Use the credentials generated during the configuration step:

   - **Username**: `user`
   - **Password**: *(the password generated by the script)*

4. **Verify Buckets**:

   You should see the following buckets:

    - eoepca
    - cache-bucket
    - gitlab-backup-storage
    - gitlab-tmp-storage
    - gitlab-lfs-storage
    - mlopbb-mlflow-sharinghub
    - mlopbb-sharinghub
   
5. **Create a Test Bucket**:

   Use the dashboard to create a new bucket and upload a test file.

---
## Uninstallation

To remove MinIO and associated resources:

1. **Uninstall MinIO**:

```bash
helm -n minio uninstall minio
```

2. **Uninstall MinIO Bucket API**:

```bash
helm -n minio uninstall minio-bucket-api
```

3. **Delete Secrets and PVCs**:

```bash
kubectl delete secret minio-auth -n minio ; \
kubectl delete pvc -n minio --all
```

---
## Further Reading

- [MinIO Documentation](https://docs.min.io/)
- [MinIO Complete Helm Values](https://github.com/minio/minio/blob/master/helm/minio/values.yaml)

---
## Feedback

If you have any issues or suggestions, please open an issue on the [EOEPCA+ Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide/issues).