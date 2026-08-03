# Application Quality Deployment Guide

The **Application Quality Building Block (BB)** supports the transition of scientific algorithms from research prototypes to production-grade workflows. It provides tools for verifying code quality, security best practices, vulnerability scanning, performance testing and orchestrating these checks via pipelines integrated into a CI/CD process.

---

## Introduction

The **Application Quality Building Block** provides tools and processes designed to:

- **Ensure Best Practices:** Including static code analysis, security scanning, and adherence to open science standards.
- **Streamline Quality Checks:** Containerised tooling such as SonarQube, Bandit, and Sphinx, integrated into automated pipelines.
- **Measure Performance:** Tools and methods to test and optimise workflow execution performance.

!!! warning "Important"
    Application Quality's web portal and API validate OIDC tokens themselves against the Keycloak realm's discovery endpoint, so IAM/OIDC works under either **APISIX** or **NGINX** ingress. The optional **SonarQube** add-on is the exception: its `/sonarqube` routing in this guide uses an APISIX `ApisixRoute`, so SonarQube requires APISIX regardless of whether IAM is enabled. The configuration script fails early if SonarQube is enabled under NGINX.

---

## Architecture Overview

- **Database:** Stores definitions for analysis tools, pipelines, and execution metadata.
- **Web Portal:** User interface for creating pipelines, executing them, and reviewing results.
- **Backend API:** Provides backend services for the web portal, interacting with the database.
- **Pipeline Engine:** Manages and orchestrates pipeline execution, submitting CWL workflows to runners like Calrissian.
- **CWL Runner (Calrissian):** Executes workflow steps in Kubernetes containers.
- **Grafana Dashboards (Optional):** Provides dashboard visualisation where enabled by the deployment values.
- **SonarQube (Optional):** Provides code quality analysis using a separate SonarQube deployment and PostgreSQL database.

---

## Prerequisites

Before deploying the Application Quality Building Block, ensure you have the following:

| Component        | Requirement                            | Documentation Link                                                                                  |
| ---------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.32)              | [Installation Guide](../prerequisites/kubernetes.md)                                               |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                           |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                       |
| gomplate         | Required to render Helm values         | [gomplate Installation](https://docs.gomplate.ca/installing/)                                      |
| OIDC Provider    | Required only when IAM is enabled      | [Deployment Guide](../building-blocks/iam/main-iam.md)                                             |
| APISIX Ingress Controller | Required only if deploying the optional SonarQube add-on | [APISIX Ingress Guide](../prerequisites/ingress/apisix.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md)                                        |
| Internal TLS Certificates | ClusterIssuer for internal certificates | [Internal TLS Setup](../prerequisites/tls.md#internal-tls)                                  |
| Persistent Storage | Storage class for Application Quality persistence | [Storage Guide](../prerequisites/storage.md) |
| Shared Storage | RWX-capable storage class for Calrissian workloads | [Storage Guide](../prerequisites/storage.md) |

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
- **`PERSISTENT_STORAGECLASS`**: Kubernetes storage class for persistent data.
- **`SHARED_STORAGECLASS`**: Kubernetes storage class for shared Calrissian volumes.
- **`CLUSTER_ISSUER`**: Cert-manager issuer name.
- **`INTERNAL_CLUSTER_ISSUER`**: Internal TLS issuer (default: `eoepca-ca-clusterissuer`).

`APP_QUALITY_PUBLIC_HOST` defaults to `application-quality.${INGRESS_HOST}` and isn't prompted for directly.

The script also asks whether to enable:

- **IAM/OIDC authentication**
- **Optional Grafana dashboards**
- **Optional SonarQube deployment**

#### OIDC Authentication

OIDC authentication is optional - the script asks a plain yes/no with no preset default.

=== "Without IAM"

    - **`APP_QUALITY_ENABLE_IAM`** is set to `false`.
    - Application Quality is deployed without authentication.

=== "With IAM"

    - **`APP_QUALITY_ENABLE_IAM`** is set to `true`.
    - **`APP_QUALITY_CLIENT_ID`** is requested.
    - **`APP_QUALITY_CLIENT_SECRET`** is generated if not already set.
    - Works under either APISIX or NGINX ingress, since the API validates tokens itself against Keycloak.

#### Grafana Dashboards

Grafana is optional.

When Grafana is enabled:

- **`APP_QUALITY_ENABLE_GRAFANA`** is set to `true`.
- A Grafana admin credentials secret is generated by `apply-secrets.sh` and Grafana is deployed as part of the main Helm release, exposed under `${APP_QUALITY_PUBLIC_HOST}/dashboards`.
- Log in with the generated admin credentials (see `apply-secrets.sh`). This guide does not configure Grafana's OIDC SSO against Keycloak; the chart's default OIDC login option is disabled to avoid generating a broken configuration pointed at a Keycloak host this guide does not know about. Configure Grafana OIDC manually afterwards if required.
- Dashboard routing under APISIX uses a path-rewrite annotation to strip the `/dashboards` prefix; NGINX ingress for Grafana is not validated by this guide.

#### SonarQube

SonarQube is optional.

When SonarQube is enabled:

- **`APP_QUALITY_ENABLE_SONARQUBE`** is set to `true`.
- Database and monitoring passcode secrets are generated.
- SonarQube is deployed separately into the `application-quality-sonarqube` namespace.
- APISIX ingress is required for the `/sonarqube` route.

!!! warning "Important"
    SonarQube routing in this guide uses an APISIX `ApisixRoute`. SonarQube with NGINX ingress is not currently supported by this guide.

---

### 2. Apply Secrets

```bash
bash apply-secrets.sh
```

This creates the required Kubernetes Secrets.

For the core Application Quality deployment, IAM secrets are created only when IAM is enabled.

For SonarQube, database and monitoring passcode secrets are created only when SonarQube is enabled.

---

### 3. Deploy Application Quality via Helm

Clone the Application Quality repository:

```bash
git clone https://github.com/EOEPCA/application-quality.git reference-repo
cd reference-repo
git checkout reference-deployment
cd ..
```

Update Helm dependencies:

```bash
helm dependency update reference-repo/application-quality-reference-deployment
```

Deploy using Helm with the generated values:

```bash
helm upgrade -i application-quality reference-repo/application-quality-reference-deployment \
  -f generated-values.yaml \
  -n application-quality \
  --create-namespace \
  --wait \
  --timeout 15m
```

Check the deployment:

```bash
kubectl get all -n application-quality
kubectl get ingress -n application-quality
```

If pods do not become ready, inspect the logs:

```bash
kubectl logs -n application-quality -l app.kubernetes.io/component=api --tail=200
kubectl logs -n application-quality -l app.kubernetes.io/component=web --tail=200
```

!!! note
    If you get a Knative-related error, ensure notifications are disabled or install Knative Eventing before enabling notifications. Notifications are disabled by default in this guide.

!!! danger "Security note"
    The chart's own bundled PostgreSQL database (used by the core Application Quality API, separate from the optional SonarQube database) is deployed with fixed, chart-default credentials (`admin`/`changeme`) that this guide does not override, matching upstream `reference-deployment` behaviour. Treat this database as internal-only; do not expose its service externally.

---

### 4. Create an IAM Client

Skip this step if IAM/OIDC was disabled.

A Keycloak client is required when IAM/OIDC is enabled. `configure-application-quality.sh` already rendered `generated-iam.yaml` (a Crossplane `Client` CR) when IAM was enabled, provided Crossplane and its Keycloak provider are installed:

```bash
kubectl apply -f generated-iam.yaml
```

If Crossplane Keycloak provider support isn't available, create the client manually in Keycloak instead, using the following settings:

| Setting | Value |
| ------- | ----- |
| Client ID | `${APP_QUALITY_CLIENT_ID}` |
| Client type | OpenID Connect |
| Access type | Confidential |
| Client secret | `${APP_QUALITY_CLIENT_SECRET}` |
| Root URL | `${HTTP_SCHEME}://${APP_QUALITY_PUBLIC_HOST}` |
| Base URL | `${HTTP_SCHEME}://${APP_QUALITY_PUBLIC_HOST}` |
| Valid redirect URIs | `${HTTP_SCHEME}://${APP_QUALITY_PUBLIC_HOST}/*` |
| Web origins | `${HTTP_SCHEME}://${APP_QUALITY_PUBLIC_HOST}` |
| Standard flow | Enabled |
| Direct access grants | Enabled |

Load the configured values before creating the client:

```bash
source ~/.eoepca/state
```

For production deployments, avoid broad wildcard redirects where possible. Use exact redirect URIs after confirming the paths used by the Application Quality UI and backend.

---

### 5. Deploy SonarQube (Optional)

Skip this step if SonarQube was disabled during configuration.

SonarQube is deployed as a separate stack because current SonarQube chart versions require PostgreSQL to be deployed separately.

Add the required Helm repositories:

```bash
helm repo add kubelauncher https://kubelauncher.github.io/charts
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update kubelauncher sonarqube
```

```bash
helm upgrade -i application-quality-sonarqube-db kubelauncher/postgresql \
  --version 0.3.4 \
  -n application-quality-sonarqube \
  --create-namespace \
  -f generated-sonarqube-db-values.yaml \
  --wait \
  --timeout 10m

helm upgrade -i application-quality-sonarqube sonarqube/sonarqube \
  --version 2026.2.1 \
  -n application-quality-sonarqube \
  -f generated-sonarqube-values.yaml \
  --wait \
  --timeout 20m
kubectl apply -f generated-sonarqube-apisix.yaml
```

SonarQube is exposed under:

```text
${HTTP_SCHEME}://${APP_QUALITY_PUBLIC_HOST}/sonarqube
```

!!! note
    The SonarQube chart installs the OIDC plugin, but this guide does not fully configure SonarQube SSO by default. Configure SonarQube authentication after deployment if required.

---

## Validation

1. **Run the validation script** (`validation.sh`):

```bash
bash validation.sh
```

This checks that the required pods, services, ingress resources and public endpoints exist.

If SonarQube is enabled, the validation also checks the SonarQube namespace, services and APISIX route.

2. **Manual checks**:

To confirm Application Quality is running:

```bash
kubectl get all -n application-quality
```

To check the public endpoint:

```bash
source ~/.eoepca/state
curl -k -I "${HTTP_SCHEME}://${APP_QUALITY_PUBLIC_HOST}"
```

If IAM is enabled, the endpoint may redirect to the identity provider. For redirect checks, do not use `curl -L`; inspect the initial response.

To confirm SonarQube is running:

```bash
kubectl get all -n application-quality-sonarqube
kubectl get apisixroute -n application-quality-sonarqube
```

---

## Usage Instructions

### 1. Accessing the Web Portal

1. Ensure your ingress is configured to route `application-quality.${INGRESS_HOST}` or the configured `APP_QUALITY_PUBLIC_HOST` to the Application Quality front-end.
2. Open a browser at `https://application-quality.${INGRESS_HOST}/`, or the configured public host.
3. If OIDC is enabled, authenticate using EOEPCA IAM.

### 2. Authenticating via EOEPCA IAM

1. Click the **Login** link.
2. Choose your Identity Provider.
3. Upon successful login, the top navigation bar should show the authenticated user and logout option.

### 3. Defining & Executing Pipelines

A pipeline is a sequence of analysis tools that can run on an application's source code, container image or workflow definition. Common examples include:

- **Static code analysis** (e.g. flake8, bandit, ruff, SonarQube)
- **Vulnerability scans** (e.g. Trivy, Docker image scanning)
- **Documentation checks** (e.g. Sphinx)
- **Performance checks** (executing a workflow in a test environment and capturing resource usage)

**Manual Execution**:

1. Navigate to **Pipelines** in the side menu.
2. Select the pipeline to run, or create a new one that references your analysis tools.
3. Click the execute icon.
4. Enter the Git repository URL and branch.
5. Click **Execute**.

View the pipeline's progress under **Monitoring**, which shows each stage as it runs.

### 4. Inspection of Analysis Tools & Pipelines

1. **Analysis Tools** → Lists available tools. Each tool can have a name, version, container reference and execution configuration.
2. **Pipelines** → Lists configured pipelines and the tools that they execute.

### 5. Viewing Reports & Metrics

Once a pipeline finishes, you can see:

- **Reports**: Detailed findings from each tool, such as lint errors, vulnerabilities, coverage or quality results.
- **Monitoring**: Pipeline timeline, status and execution logs.
- **SonarQube Results**: Available in SonarQube when SonarQube is enabled and the pipeline is configured to publish analysis results.

---

## Uninstallation

To remove the core Application Quality components:

```bash
helm uninstall application-quality -n application-quality
kubectl delete namespace application-quality
```

If SonarQube was enabled, remove it separately:

```bash
helm uninstall application-quality-sonarqube -n application-quality-sonarqube
helm uninstall application-quality-sonarqube-db -n application-quality-sonarqube
kubectl delete namespace application-quality-sonarqube
```


---

## Further Reading

- [Application Quality GitHub Repository](https://github.com/EOEPCA/application-quality)
- [Application Quality Documentation](https://eoepca.readthedocs.io/projects/application-quality/en/latest/)