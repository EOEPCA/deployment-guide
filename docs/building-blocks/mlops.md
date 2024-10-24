# MLOps Deployment Guide


> **Important Note**: While deployment will succeed, full operation is not available in this EOEPCA+ release due to the inability to configure Keycloak settings.

The **MLOps Building Block** provides support services for training machine learning models within the cloud platform. It orchestrates the training of ML models across popular frameworks, maintains a history of training runs with associated metrics, and manages the associated training data. This guide provides step-by-step instructions to deploy the MLOps Building Block within your Kubernetes cluster.

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Deployment Steps](#deployment-steps)
4. [Validation](#validation)
5. [Uninstallation](#uninstallation)
6. [Further Reading](#further-reading)
7. [Feedback](#feedback)

---

## Introduction

The MLOps Building Block enabling users to develop, train, and manage machine learning models efficiently. It leverages **SharingHub**, a web application offering collaborative services for ML development, and **MLflow SharingHub**, a custom version of MLflow integrated with SharingHub for experiment tracking and model management.

### Key Features

- **Model Training**: Supports initiation and management of training runs across popular ML frameworks.
- **Experiment Tracking**: Maintains a history of training runs, parameters, and performance metrics.
- **Model Management**: Version control and management of ML models using interoperable formats like ONNX.
- **Data Management**: Efficient storage, access, and versioning of training datasets.
- **Discoverability**: Integrates with Resource Discovery for sharing models and datasets.
- **Scalability**: Built on Kubernetes for flexible and scalable deployments.
- **Security**: Integrates with Keycloak for authentication and authorization.

### Components

The MLOps Building Block comprises the following components:

- **SharingHub**: A web application offering collaborative services for ML development.
- **MLflow SharingHub**: A custom version of MLflow integrated with SharingHub for tracking experiments and managing models.
- **GitLab**: Used for version control, issue tracking, and CI/CD (can be an existing instance).

---
## Prerequisites

Before deploying the MLOps Building Block, ensure you have the following:

| Component        | Requirement                            | Documentation Link                                                                            |
| ---------------- | -------------------------------------- | --------------------------------------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.28)              | [Installation Guide](../infra/kubernetes-cluster-and-networking.md)                                         |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                     |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                 |
| OIDC             | OIDC                                   | TODO (GitLab uses this)                                                                       |
| Ingress          | Properly installed                     | [Installation Guide](../infra/ingress-controller.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../infra/tls/overview.md/)                             |
| MinIO            | S3-compatible storage                  | [Installation Guide](https://min.io/docs/minio/kubernetes/upstream/index.html)                |

**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-beta1 https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/mlops
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script

The configuration script will prompt you for necessary configuration values, generate secret keys, and create configuration files for GitLab, SharingHub, and MLflow SharingHub.

```bash
bash configure-mlops.sh
```

**Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
  - *Example*: `example.com`
- **`CLUSTER_ISSUER`**: Cert-manager Cluster Issuer for TLS certificates.
  - *Example*: `letsencrypt-prod`

The S3 environment variables should be already set after successful deployment of the [Minio Building Block]():

- **`S3_ENDPOINT`**: Endpoint URL for MinIO or S3-compatible storage.
  - *Example*: `https://minio.example.com`
- **`S3_BUCKET`**: Name of the S3 bucket to be used.
  - *Example*: `mlops-bucket`
- **`S3_REGION`**: Region of your S3 storage.
  - *Example*: `us-east-1`
- **`S3_ACCESS_KEY`**: Access key for your MinIO or S3 storage.
- **`S3_SECRET_KEY`**: Secret key for your MinIO or S3 storage.


- **`OIDC_ISSUER_URL`**: The URL of your OpenID Connect provider (e.g., Keycloak).
  - *Example*: `https://keycloak.example.com/realms/master`
- **`OIDC_CLIENT_ID`**: The client ID registered with your OIDC provider for GitLab.
- **`OIDC_CLIENT_SECRET`**: The client secret associated with the client ID.

**Important Notes:**

- If you choose **not** to use `cert-manager`, you will need to create the TLS secrets manually before deploying.
  - The required TLS secret names are:
    - `sharinghub-tls`
    - `gitlab-tls`
  - For instructions on creating TLS secrets manually, please refer to the [Manual TLS Certificate Management](../infra/tls/manual-tls.md) section in the TLS Certificate Management Guide.

### 2. Create Required Kubernetes Secrets

**Note:** These secrets must be created before deploying GitLab, as they contain essential configurations.

Run the script to create all the necessary Kubernetes secrets:

```bash
bash apply-secrets.sh
```

**Secrets Created:**

- `gitlab-storage-config`: Contains S3 configuration for GitLab backups.
- `object-storage`: Contains S3 configuration for Git LFS and other storage needs.
- `openid-connect`: Contains OIDC configuration for GitLab authentication.
- `gitlab-secrets`: Contains the initial root password for GitLab.

### 3. Deploy GitLab

Deploy GitLab using the generated configuration file.

```bash
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --create-namespace \
  --values gitlab/generated-values.yaml
```

**Note:** Wait for all GitLab pods to be up and running before proceeding.

### 4. Set Up GitLab OAuth Application

Retrieve the generated **GitLab Root Password**:
```bash
kubectl get secret gitlab-gitlab-initial-root-password --template={{.data.password}} -n gitlab | base64 -d
```

- Open a web browser and navigate to `https://gitlab.<your-domain>`
- Log in using:
	- Username: `root`
	- Password: *The generated password.*
- Navigate to **Admin Area > Applications**.
- Create a new application with the following settings:
  - **Name**: `SharingHub`
  - **Redirect URI**: `https://sharinghub.${INGRESS_HOST}/api/auth/login/callback`
  - **Scopes**: `openid`, `read_user`, `read_api`
- After creating the application, note the **Application ID** and **Secret**.

### 5. Apply Remaining Kubernetes Secrets

Now that we have the GitLab OAuth credentials, we can apply the remaining secrets for SharingHub and MLflow SharingHub.

```bash
bash apply-secrets.sh
```

**Note:** The `apply-secrets.sh` script has been updated to apply the remaining secrets.

### 6. Deploy SharingHub Using Helm

```bash
git clone https://github.com/csgroup-oss/sharinghub.git reference-repo-sharing-hub

helm install sharinghub reference-repo-sharing-hub/deploy/helm/sharinghub/ \
  --namespace sharinghub \
  --create-namespace \
  --values sharinghub/generated-values.yaml \
  --version 0.3.0
```

### 7. Deploy MLflow SharingHub Using Helm

```bash
git clone https://github.com/csgroup-oss/mlflow-sharinghub.git reference-repo-mlflow-sharinghub

helm dependency update reference-repo-mlflow-sharinghub/deploy/helm/mlflow-sharinghub/

helm install mlflow-sharinghub reference-repo-mlflow-sharinghub/deploy/helm/mlflow-sharinghub/ \
  --namespace sharinghub \
  --values mlflow/generated-values.yaml \
  --version 0.2.0 
```

---

## Validation

**Automated Validation:**

```bash
bash validation.sh
```

**Further Validation:**

1. **Check Kubernetes Resources:**

   ```bash
   kubectl get all -n sharinghub
   ```

2. **Access SharingHub Web Interface**:

   Open a web browser and navigate to: `https://sharinghub.<your-domain>/` and `https://sharinghub.<your-domain>/mlflow`
   
3. **Test API Endpoints**:

   You can test the API using `curl`:

   - **Get STAC Collections**:

```bash
curl -X GET 'https://sharinghub.<your-domain>/api/stac/collections' \
	-H 'Accept: application/json'
```

---

## Uninstallation

To uninstall the MLOps Building Block and clean up associated resources:

```bash
helm uninstall sharinghub mlflow-sharinghub -n sharinghub
```

**Additional Cleanup**:

- Delete any Persistent Volume Claims (PVCs) if used:

  ```bash
  kubectl delete pvc --all -n sharinghub
  ```

---

## Further Reading

- [SharingHub Documentation](https://github.com/csgroup-oss/sharinghub)
- [MLflow SharingHub Documentation](https://github.com/csgroup-oss/mlflow-sharinghub)
- [EOEPCA+Helm Charts Repository](https://github.com/EOEPCA/helm-charts)

---

## Feedback

If you have any issues or suggestions, please open an issue on the [EOEPCA+Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide/issues).
