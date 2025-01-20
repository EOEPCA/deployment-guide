# Application Quality Deployment Guide

The **Application Quality** Building Block (BB) supports the evolution of scientific algorithms from research prototypes to production-grade processing workflows. It provides tooling to verify non-functional requirements—code quality, best practices, vulnerability scanning, performance testing—and to manage these checks via pipelines integrated into a typical CI/CD process.

---

## Introduction

The **Application Quality Building Block** provides tooling to encourage best practices in software development and to test (and optimize) the performance of processing workflows in a sandbox environment. It includes:

- **Development Best Practice**: Static code analysis, vulnerability scans, best practice checks for open reproducible science.
- **Application Quality Tooling**: Container-based tools that can be orchestrated in pipelines (e.g. SonarQube, Bandit, Sphinx, etc.).
- **Application Performance**: Tools supporting performance testing and optimisation of processing workflows.

---

## Architecture Overview

- **Application Quality Database**: Stores definitions of analysis tools, pipelines, and pipeline execution metadata.
- **Application Quality Web Portal**: Front-end for pipeline creation, management, and viewing results.
- **Application Quality API**: Backend service that provides data to the Web Portal and interacts with the database.
- **Application Quality Engine**: Orchestrates pipeline executions. Submits CWL documents to a CWL runner (e.g. Calrissian) for container-based tasks.
- **CWL Runner (Calrissian)**: Runs each step in containers on Kubernetes.
- **Optional**: OpenSearch & OpenSearch Dashboards to store, visualise, and analyze results.

---

## Prerequisites

Before deploying the Application Quality Building Block, ensure you have the following:

| Component        | Requirement                            | Documentation Link                                                                                  |
| ---------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.28)              | [Installation Guide](../prerequisites/kubernetes.md)                                               |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                           |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                       |
| Ingress          | Properly installed                     | [Ingress Controllers](../prerequisites/ingress-controller.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md)                                   |
| Internal TLS Certificates   | ClusterIssuer for internal certificates | [Internal TLS Setup](../prerequisites/tls.md#internal-tls) |

**Clone the Deployment Guide Repository**:

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
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

**Configuration Parameters** include:

- **`INGRESS_HOST`**: Base domain (e.g. `example.org`)
- **`STORAGE_CLASS`**: Name of your storage class (e.g. `standard`, `managed-nfs-storage-retain`)
- **`CLUSTER_ISSUER`**: Cert-manager issuer name (e.g. `letsencrypt-prod`)
- **`INTERNAL_CLUSTER_ISSUER`**: Name of the cert-manager ClusterIssuer for internal TLS. (Default: `eoepca-ca-clusterissuer`)

**OIDC Configuration**:

> OIDC authentication is currently a requirement of this Building Block. The application will still deploy, but it will not be fully operational.

If you choose to enable OIDC authentication, you will be asked to provide:

- **`OIDC_RP_CLIENT_ID`**: OIDC client ID for the Application Quality Building Block.
- **`OIDC_RP_CLIENT_SECRET`**: OIDC client secret for the Application Quality Building Block.

- **`OSD_CLIENT_ID`**: OpenSearch Dashboards client ID.
- **`OSD_CLIENT_SECRET`**: OpenSearch Dashboards client secret.

### 2. Apply Secrets

```
bash apply-secrets.sh
```


### 3. Deploy via Helm

> **Note**: While the Application Quality BB is not yet in the official EOEPCA Helm charts, you can install it directly from the GitHub repository.

1. **Clone the reference repository** (if not using a Helm repo):
    
```bash
git clone https://github.com/EOEPCA/application-quality.git reference-repo
```
    
2. **Install** with Helm:
    
```bash
helm dependency build reference-repo/application-quality-reference-deployment

helm upgrade -i application-quality \
  reference-repo/application-quality-reference-deployment \
  --namespace application-quality \
  --create-namespace \
  --values generated-values.yaml
```
    
---

## Validation

1. **Run the validation script** (`validation.sh`):
    
```bash
bash validation.sh
```

This checks that the required pods/services/ingress exist and that the main endpoint returns a 200 status code.

2. **Manual**:
    
- `kubectl get all -n application-quality` to confirm everything is running.

---

## Usage Instructions

### 1. Accessing the Web Portal

1. Ensure your ingress is configured to route `application-quality.<INGRESS_HOST>` (or whichever domain) to the Application Quality front-end.
2. Open a browser at `https://application-quality.<INGRESS_HOST>/`.
3. If OIDC is enabled, you’ll see a **Login** link in the navigation bar. Unauthenticated users can only browse certain read-only features.

### 2. Authenticating via EOEPCA IAM

1. Click the **Login** link.
2. Choose your Identity Provider (local Keycloak account or GitHub, etc.).
3. Upon successful login, the top nav bar will show your username and a **Logout** link.

### 3. Defining & Executing Pipelines

A pipeline is a sequence of analysis tools (CWL definitions) that can run on your application’s source code or container. Common examples include:

- **Static code analysis** (e.g. flake8, bandit, ruff, SonarQube)
- **Vulnerability scans** (e.g. Trivy, Docker image scanning)
- **Performance checks** (executing a workflow in a test environment and capturing resource usage)

**Manual Execution**:

1. **Navigate** to **Pipelines** in the side menu.
2. **Select** the pipeline you wish to run, or create a new one that references your analysis tools.
3. **Click** the (execute) icon.
4. **Enter** Git repository URL/branch.
5. Click **Execute**.

View the pipeline’s progress under **Monitoring**, which shows each stage (tool) as it runs.

### 4. Inspection of Analysis Tools & Pipelines

1. **Analysis Tools** → Lists all available tools. Each tool can have a name, version, Docker container reference, etc.
2. **Pipelines** → Each pipeline references one or more tools, plus any triggers or environment variables.

Click the icon to see more details, including integrated tools.

### 5. Viewing Reports & Metrics

Once a pipeline finishes, you can see:

- **Reports**: Detailed findings from each tool (lint errors, vulnerabilities, performance metrics, coverage, etc.).
- **Monitoring**: The pipeline’s timeline, success/failure, logs, etc.

From the side menu:

1. **Monitoring** → pick a pipeline → pick an execution
2. **Reports** → filter by pipeline & execution → see a list of tool-specific results
3. Click the icon on a specific tool’s result to see a detail page with logs or metrics.

### 6. REST API Usage (Optional)

The Application Quality service also exposes a REST API for programmatic access. For advanced users:

1. **Port-forward** or expose the service’s backend via ingress.
2. Check the [API usage docs] or the generated OpenAPI spec at `/docs` or `/openapi.json`.
3. Common endpoints include:
    - `POST /pipelines` to define pipelines
    - `POST /pipelines/{id}/execute` to run a pipeline
    - `GET /executions/{execId}` to retrieve results

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
