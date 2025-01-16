# MLOps Deployment Guide

The **MLOps Building Block** provides support services for training machine learning models within the cloud platform. It orchestrates the training of ML models across popular frameworks, maintains a history of training runs with associated metrics, and manages the associated training data. This guide provides step-by-step instructions to deploy the MLOps Building Block within your Kubernetes cluster.

---

## Introduction

The **MLOps Building Block** provides integrated services for training and managing machine learning models within the EOEPCA+ environment. It leverages GitLab for code and data versioning, **SharingHub** for collaborative ML services, and **MLflow SharingHub** (a custom MLflow) for experiment tracking and model registry.

### Key Features

- **End-to-End** ML Workflow: Data versioning, model training, experiment logging, model deployment or registry.  
- **GitLab Integration**: Automatic linking of GitLab projects (public or private) into SharingHub for discoverability. Optional LFS or DVC for large files/datasets.  
- **OIDC Authentication**: Via Keycloak or compatible OIDC provider (optional but highly recommended).  
- **S3 / MinIO Storage**: Flexible object storage for large data and model artifacts.  
- **STAC-Based Discoverability**: SharingHub implements a STAC API over GitLab projects for dataset/ML model catalogs.


---
## Prerequisites

Before deploying the MLOps Building Block, ensure you have the following:

| Component        | Requirement                            | Documentation Link                                                                            |
| ---------------- | -------------------------------------- | --------------------------------------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.28)              | [Installation Guide](../prerequisites/kubernetes.md)                                         |
| Git              | Properly installed                     | [Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)                                     |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                     |
| Helm plugins     | `helm-git`: Version 1.3.0 tested       | [Installation Guide](https://github.com/aslafy-z/helm-git?tab=readme-ov-file#install)                                     |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                 |
| OIDC             | OIDC                                   | TODO (GitLab uses this)                                                                       |
| Ingress          | Properly installed                     | [Installation Guide](../prerequisites/ingress-controller.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md)                             |
| MinIO            | S3-compatible storage                  | [Installation Guide](../prerequisites/minio.md)                |
| OIDC             | OpenID Connect (OIDC) Provider (e.g., Keycloak) | Installation guide coming soon. |

Additionally, you must have:

- **Keycloak** (or another OIDC provider) set up *if* you want single sign-on through OIDC.  
  - If you do not integrate OIDC, GitLab will use its default authentication method (username/password). However, SharingHub can still use GitLab for sign-in via an access token or GitLab OAuth app.


**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/mlops
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

## Optional: Configure Keycloak for GitLab (OIDC)

If you'd like GitLab to authenticate via Keycloak, follow these steps in Keycloak **before** continuing:

1. **Create or use an existing Realm** (e.g., `eoepca`).
2. **Create a new Client** for GitLab:

   - **Client ID**: `gitlab` (or a name of your choosing)
   - **Client Protocol**: `openid-connect`
   - **Root URL**: `https://gitlab.<YOUR-DOMAIN>` (you'll confirm `<YOUR-DOMAIN>` shortly)
   - **Redirect URIs**: Add `https://gitlab.<YOUR-DOMAIN>/users/auth/openid_connect/callback`
   - **Web Origins**: `https://gitlab.<YOUR-DOMAIN>`  
   - Ensure the client scopes `openid`, `profile`, `email` are included or default.
3. **Obtain** the following from Keycloak:

   - **OIDC_ISSUER_URL** (e.g., `https://auth.<YOUR-DOMAIN>/realms/eoepca`)
   - **OIDC_CLIENT_ID** (e.g., `gitlab`)
   - **OIDC_CLIENT_SECRET** (Keycloak-generated)

This data will be used in the MLOps deployment scripts.

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
    - *Example*: `letsencrypt-http01-apisix`

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


### 2. Create Required Kubernetes Secrets

```bash
bash apply-secrets.sh
```

### 3. Deploy GitLab

Deploy GitLab using the generated configuration file. This deployment can take up to 10 minutes, please be patient.

```bash
helm repo add gitlab https://charts.gitlab.io/ && \
helm repo update gitlab && \
helm upgrade -i gitlab gitlab/gitlab \
  --version 8.1.8 \
  --namespace gitlab \
  --create-namespace \
  --values gitlab/generated-values.yaml
```

**Important Notice Regarding GitLab Deployment:**

> **Note**: The provided GitLab deployment uses built-in PostgreSQL, Redis, and Gitaly. These are **evaluation-only** components. For production setups, reference GitLab's official docs on external databases, Redis clusters, etc.


### 4. Set Up GitLab OAuth Application for SharingHub

If you wish to sign into SharingHub using GitLab accounts:

1. Retrieve the **GitLab Root Password**:

```bash
kubectl get secret gitlab-gitlab-initial-root-password --template={{.data.password}} -n gitlab | base64 -d
```

2. Open `https://gitlab.<YOUR-DOMAIN>`.
3. Log in as `root` with the above password.
4. **Admin Area** → **Applications** → **New Application**:

   - **Name**: e.g., `SharingHub`
   - **Redirect URI**: `https://sharinghub.<YOUR-DOMAIN>/api/auth/login/callback`
   - **Scopes**: `openid`, `read_user`, `read_api`

5. After creating the application, note the **Application ID** and **Secret**.


### 5 Store the GitLab OAuth App Credentials

```bash
bash utils/save-application-credentials-to-state.sh
```

This script prompts you for `GITLAB_APP_ID` and `GITLAB_APP_SECRET` from the step above, then creates a Kubernetes secret (`sharinghub-oidc`) in the `sharinghub` namespace. This allows SharingHub to use GitLab-based OIDC sign-in.

### 6. Deploy SharingHub Using Helm

```bash
helm repo add sharinghub "git+https://github.com/csgroup-oss/sharinghub@deploy/helm?ref=0.3.0" && \
helm repo update sharinghub && \
helm upgrade -i sharinghub sharinghub/sharinghub \
  --namespace sharinghub \
  --create-namespace \
  --values sharinghub/generated-values.yaml
```

### 7. Deploy MLflow SharingHub Using Helm

```bash
helm repo add mlflow-sharinghub "git+https://github.com/csgroup-oss/mlflow-sharinghub@deploy/helm?ref=0.2.0" && \
helm repo update mlflow-sharinghub && \
helm upgrade -i mlflow-sharinghub mlflow-sharinghub/mlflow-sharinghub \
  --namespace sharinghub \
  --create-namespace \
  --values mlflow/generated-values.yaml
```

> **Note**: This deployment uses a custom MLflow that integrates with SharingHub. By default, it stores metadata either in an embedded SQLite or a small Postgres. Artifacts can go into your S3 bucket. Check `mlflow/generated-values.yaml` for final config.

---


### 1. Validate the Deployment

After the initial installation (GitLab, SharingHub, MLflow, secrets, etc.), run a few checks:

1. **Check Pods**:
```bash
kubectl get pods -n gitlab
kubectl get pods -n sharinghub
```
All pods should be in `Running` (or `Completed`) state.

2. **Visit GitLab**:

- `https://gitlab.<YOUR-DOMAIN>/`
- Log in with `root` user or (if OIDC integrated) use the "Sign in with OpenID Connect" link.

3. **Visit SharingHub**:

- `https://sharinghub.<YOUR-DOMAIN>/`
- If you set up GitLab OAuth for SharingHub, you should see a sign-in flow redirecting to GitLab.

4. **Visit MLflow**:

- `https://sharinghub.<YOUR-DOMAIN>/mlflow`
- Confirm the MLflow UI loads. If you have an existing project or run, you'll see experiments or metrics.

5. **Confirm S3 Access**:

- If using MinIO, run a quick test from your local machine or from a pod:
  ```bash
  aws --endpoint-url https://minio.<YOUR-DOMAIN> s3 ls s3://mlops-bucket
  ```
- If credentials or bucket aren't set correctly, you'll see an error.


---

### 2. Basic Usage Walkthrough

This section walks you through a minimal scenario of creating a project in GitLab, tagging it for discovery in SharingHub, and running a simple MLflow training job.

#### 2.1 Create a New GitLab Project

1. **Log into GitLab** at `https://gitlab.<INGRESS_HOST>/`.  
2. Create a project named `mlops-test-project`.  
3. Go to **Settings → General → Topics** and add the topic `sharinghub:aimodel` (or your chosen category from the `categories` config).  
4. (Optional) Commit a small dataset to the project (`wine-quality.csv` or similar).

#### 2.2 Verify that the Project Appears in SharingHub

1. Go to `https://sharinghub.<INGRESS_HOST>/`.  
2. Click "AI Models" category (or whichever category you used).  
3. The new GitLab project (`mlops-test-project`) should appear in SharingHub's listing.

If you do not see it, check:

- That your GitLab project is **public** (or internal). If it's private, your user must be authenticated in SharingHub with a GitLab token or default token.  
- That you used the correct GitLab topic matching your category configuration in `sharinghub/generated-values.yaml`.


### 2.3 MLflow Setup & Training

1. **Obtain the MLflow Tracking URI**
    
- Typically, you can browse to your project details in SharingHub and click an "MLflow" link in the top-right corner. This link will look something like:

```
https://sharinghub.<INGRESS_HOST>/mlflow/root/mlops-test-project/tracking/
```


2. **Authenticate**
    
- If your MLflow is protected (likely), you must provide a token or other credentials.
- **GitLab Personal Access Token**:

    1. Create a token in GitLab with `api` scope.
    2. Set it as an environment variable, e.g., `MLFLOW_TRACKING_TOKEN=<YOUR-TOKEN>`.

- This token must correspond to a GitLab user who has Developer (or Maintainer) access in that project.

3. **Run a Simple MLflow Experiment**  

Below is an example training script that logs a model and its accuracy to MLflow. You can run this script locally or in a pod.

```bash
pip install mlflow scikit-learn

# Create a Python script named main.py
cat <<EOF > main.py
import mlflow
import mlflow.sklearn
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier

# Start MLflow run
with mlflow.start_run():
    X, y = load_iris(return_X_y=True)
    X_train, X_test, y_train, y_test = train_test_split(X, y)
    model = RandomForestClassifier(n_estimators=10)
    model.fit(X_train, y_train)
    acc = model.score(X_test, y_test)
    mlflow.log_metric("accuracy", acc)
    mlflow.sklearn.log_model(model, "model")
EOF

# Execute the training script with MLflow environment variables
MLFLOW_TRACKING_URI="https://sharinghub.<YOUR-INGRESS-HOST>/mlflow/root/mlops-test-project/tracking/" \
MLFLOW_TRACKING_TOKEN="<YOUR-TOKEN>" \
python main.py
```

**Expected**: MLflow logs the run and saves the model artifact. You should not encounter 401 (Unauthorized) if the token is valid and 403 (Forbidden) if your GitLab user has the correct role (`Developer` or `Maintainer`) in the `mlops-test-project`.
    
4. **Check the MLflow UI**
    
- Navigate to `https://sharinghub.<INGRESS_HOST>/mlflow`.
- Look for your `mlops-test-project` in the left panel or under "Experiments."
- You should see a new run listed, along with metrics (e.g., the `accuracy` you logged).

5. **Confirm the Model in SharingHub**
    
- Return to `https://sharinghub.<INGRESS_HOST>/` and open your project’s page.
- You may see a "Model" or "Assets" section referencing your newly-logged model. Depending on your SharingHub configuration, it might also appear as a STAC item under "AI Models."

---

## Uninstallation

To uninstall the MLOps Building Block and clean up associated resources:

```bash
helm uninstall gitlab -n gitlab ; \
helm uninstall sharinghub mlflow-sharinghub -n sharinghub ; \
bash utils/uninstallation-cleanup.sh ; \
kubectl delete ns gitlab sharinghub
```

**Additional Cleanup**:

```bash
kubectl delete pvc -n sharinghub ; \
kubectl delete pvc -n gitlab
```

---

## Further Reading

- [SharingHub Documentation](https://github.com/csgroup-oss/sharinghub)
- [MLflow SharingHub Documentation](https://github.com/csgroup-oss/mlflow-sharinghub)
- [EOEPCA+Helm Charts Repository](https://github.com/EOEPCA/helm-charts)

---

## Feedback

If you have any issues or suggestions, please open an issue on the [EOEPCA+Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide/issues).
