# Application Quality Deployment Guide

The **Application Quality Building Block (BB)** supports the transition of scientific algorithms from research prototypes to production-grade workflows. It provides tools for verifying code quality, security best practices, vulnerability scanning, performance testing and orchestrating these checks via pipelines integrated into a CI/CD process.

---

## Introduction

The **Application Quality Building Block** provides tools and processes designed to:

- **Ensure Best Practices:** Including static code analysis, security scanning, and adherence to open science standards.
- **Streamline Quality Checks:** Containerised tooling such as SonarQube, Bandit, and Sphinx, integrated into automated pipelines.
- **Measure Performance:** Tools and methods to test and optimise workflow execution performance.

> **Important:** The Application Quality BB requires **APISIX** as an ingress controller to support OIDC authentication and API management. Deployments using NGINX ingress without additional OIDC plugins or proxies will not function correctly.

---

## Architecture Overview

- **Database:** Stores definitions for analysis tools, pipelines, and execution metadata.
- **Web Portal:** User interface for creating pipelines, executing them, and reviewing results.
- **Backend API:** Provides backend services for the web portal, interacting with the database.
- **Pipeline Engine:** Manages and orchestrates pipeline execution, submitting CWL workflows to runners like Calrissian.
- **CWL Runner (Calrissian):** Executes workflow steps in Kubernetes containers.
- **OpenSearch & Dashboards (Optional):** Stores, visualises, and analyses pipeline execution results.

---

## Prerequisites

Before deploying the Application Quality Building Block, ensure you have the following:

| Component        | Requirement                            | Documentation Link                                                                                  |
| ---------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.32)              | [Installation Guide](../prerequisites/kubernetes.md)                                               |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                           |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                       |
| OIDC Provider             | An OIDC Provider must be available              | [Deployment Guide](../building-blocks/iam/main-iam.md)                                                                                          |
| APISIX Ingress Controller | Installed and configured for OIDC | [APISIX Ingress Guide](../prerequisites/apisix-ingress.md)                                         |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md)                                   |
| Internal TLS Certificates   | ClusterIssuer for internal certificates | [Internal TLS Setup](../prerequisites/tls.md#internal-tls) |

**Clone the Deployment Guide Repository**:

```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/application-quality
```

**Validate your environment**:

```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script

```bash
bash configure-application-quality.sh
```

Provide values for:

- **`INGRESS_HOST`**: Your base domain (e.g. `example.org`).
- **`PERSISTENT_STORAGECLASS`**: Kubernetes storage class name.
- **`CLUSTER_ISSUER`**: Cert-manager issuer name.
- **`INTERNAL_CLUSTER_ISSUER`**: Internal TLS issuer (default: `eoepca-ca-clusterissuer`).

#### OIDC Authentication

OIDC authentication requires APISIX ingress. If using APISIX:

- **`APP_QUALITY_CLIENT_ID`**: Set the client ID (`application-quality`).



### 2. Apply Secrets

```
bash apply-secrets.sh
```


### 3. Deploy via Helm

> **Note:** Application Quality is not yet in the official Helm charts. Deploy directly from GitHub.

1. **Clone the reference repository**:
    
```bash
git clone https://github.com/EOEPCA/application-quality.git reference-repo \
  -b reference-deployment
```
    
2. **Install** with Helm:
    
```bash
helm dependency update reference-repo/application-quality-reference-deployment

helm upgrade -i application-quality reference-repo/application-quality-reference-deployment \
  --namespace application-quality \
  --create-namespace \
  --values generated-values.yaml
```


### 4 Create a Keycloak Client

Use the `create-client.sh` script in the `/scripts/utils/` directory. This script prompts you for basic details and automatically creates a Keycloak client in your chosen realm:

```bash
bash ../utils/create-client.sh
```

When prompted:

- **Keycloak Admin Username and Password**: Enter the credentials of your Keycloak admin user (these are also in `~/.eoepca/state` if you have them set).
- **Keycloak base domain**: e.g. `auth.example.com`
- **Realm**: Typically `eoepca`.

- **Confidential Client?**: specify `true` to create a CONFIDENTIAL client
- **Client ID**: You should use the client ID you inputted in the configuration script (`application-quality`).
- **Client name** and **description**: Provide any helpful text (e.g. Application Quality)
- **Client secret**: Enter the Client Secret that was generated during the configuration script (check `~/.eoepca/state`).
- **Subdomain**: Use `application-quality`.
- **Additional Subdomains**: Leave blank.
- **Additional Hosts**: Leave blank.

After it completes, you should see a JSON snippet confirming the newly created client.

---

## Validation

1. **Run the validation script** (`validation.sh`):
    
```bash
bash validation.sh
```

This checks that the required pods/services/ingress exist and that the main endpoint returns a 200 status code.

2. **Manual**:

To confirm everything is running...

```bash
kubectl get all -n application-quality
```

---

## Usage Instructions

### 1. Accessing the Web Portal

1. Ensure your ingress is configured to route `application-quality.${INGRESS_HOST}` (or whichever domain) to the Application Quality front-end.
2. Open a browser at `https://application-quality.${INGRESS_HOST}/`.
3. If OIDC is enabled, you'll see a **Login** link in the navigation bar. Unauthenticated users can only browse certain read-only features.

### 2. Authenticating via EOEPCA IAM

1. Click the **Login** link.
2. Choose your Identity Provider (local Keycloak account or GitHub, etc.).
3. Upon successful login, the top nav bar will show your username and a **Logout** link.

### 3. Defining & Executing Pipelines

A pipeline is a sequence of analysis tools (CWL definitions) that can run on your application's source code or container. Common examples include:

- **Static code analysis** (e.g. flake8, bandit, ruff, SonarQube)
- **Vulnerability scans** (e.g. Trivy, Docker image scanning)
- **Performance checks** (executing a workflow in a test environment and capturing resource usage)

**Manual Execution**:

1. **Navigate** to **Pipelines** in the side menu.
2. **Select** the pipeline you wish to run, or create a new one that references your analysis tools.
3. **Click** the (execute) icon.
4. **Enter** Git repository URL/branch.
5. Click **Execute**.

View the pipeline's progress under **Monitoring**, which shows each stage (tool) as it runs.

### 4. Inspection of Analysis Tools & Pipelines

1. **Analysis Tools** → Lists all available tools. Each tool can have a name, version, Docker container reference, etc.
2. **Pipelines** → Each pipeline references one or more tools, plus any triggers or environment variables.

### 5. Viewing Reports & Metrics

Once a pipeline finishes, you can see:

- **Reports**: Detailed findings from each tool (lint errors, vulnerabilities, performance metrics, coverage, etc.).
- **Monitoring**: The pipeline's timeline, success/failure, logs, etc.

---

## Uninstallation

To remove all Application Quality components:

```bash
helm uninstall application-quality -n application-quality
kubectl delete namespace application-quality
```

```bash
kubectl delete pvc --all -n application-quality
```

---

## Further Reading

- [Application Quality GitHub Repository](https://github.com/EOEPCA/application-quality)
- [Application Quality Documentation](https://eoepca.readthedocs.io/projects/application-quality/en/latest/)
