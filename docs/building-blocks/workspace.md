# Workspace Deployment Guide

The **Workspace** Building Block provides a comprehensive solution for storing assets and offering services like cataloguing, data access, and visualisation to explore stored assets. Workspaces can cater to individual users or serve as collaborative spaces for groups or projects. This guide provides step-by-step instructions to deploy the Workspace BB in your Kubernetes cluster using Helm.

---

## Introduction

The **Workspace** Building Block provides a comprehensive environment where users can store, organise, and process data. It leverages Kubernetes and GitOps principles to create isolated and customisable workspaces for projects or individual users.

---

## Components Overview

The Workspace BB comprises the following key components:

1. **Workspace Controller**: Manages the provisioning and lifecycle of workspaces using Kubernetes Custom Resource Definitions (CRDs) and controllers.

2. **Storage Controller**: Provides an API for self-service management of storage buckets within the workspace.

3. **Workspace Services**: An extensible set of services that can be provisioned within the workspace, such as resource discovery, data access, and visualisation tools.

4. **Workspace User Interface**: A web-based interface for workspace lifecycle management and resource management.

---

## Prerequisites

Before deploying the Workspace Building Block, ensure you have the following:

| Component          | Requirement                                       | Documentation Link                                                |
| ------------------ | ------------------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.28)                         | [Installation Guide](../infra/kubernetes-cluster-and-networking.md)             |
| Helm               | Version 3.7 or newer                              | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access                     | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| TLS Certificates   | Managed via `cert-manager` or manually            | [TLS Certificate Management Guide](../infra/tls/overview.md/) |
| APISIX Ingress Controller | Properly installed                         | [Installation Guide](../infra/ingress-controller.md#apisix-ingress-controller)      |
| Git Repository     | Access to a Git repository (e.g., GitHub, GitLab) | N/A                                                               |
| Keycloak Client    | `workspace-bb` Keycloak client for IAM integration | [See Guide Below](#create-iam-client) |

**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/workspace
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

---

## Create IAM Client

**TODO** - describe how to create the `workspace-bb` client in Keycloak for IAM integration.<br>
The client secret is required in the deployment steps.

---

## Deployment Steps

### 1. Run the Configuration Script

The configuration script will prompt you for necessary configuration values, generate configuration files, and prepare for deployment.

```bash
bash configure-workspace.sh
```

**Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
  - *Example*: `example.com`
- **`CLUSTER_ISSUER`**: Cert-Manager ClusterIssuer for TLS certificates.
  - *Example*: `letsencrypt-prod`
- **`S3_ENDPOINT`**: Endpoint URL for MinIO or S3-compatible storage.
  - *Example*: `https://minio.example.com`
- **`S3_REGION`**: Region of your S3 storage.
  - *Example*: `us-east-1`
- **`S3_ACCESS_KEY`**: Access key for your MinIO or S3 storage.
- **`S3_SECRET_KEY`**: Secret key for your MinIO or S3 storage.

### 2. Apply Kubernetes Secrets

Run the script to create the necessary Kubernetes secrets.

```bash
bash apply-secrets.sh
```

**Secrets Created in the `Workspace` namespace:**

- `harbor-admin-password`
- `minio-secret`
- `workspace-api-client`

**Important Notes:**

- If you choose **not** to use `cert-manager`, you will need to create the TLS secrets manually before deploying.
  - The required TLS secret names are:
    - `workspace-admin-tls`
    - `workspace-api-tls`
    - `workspace-ui-tls`
  - For instructions on creating TLS secrets manually, please refer to the [Manual TLS Certificate Management](../infra/tls/manual-tls.md) section in the TLS Certificate Management Guide.

### 3. Deploy Crossplane

Crossplane is used for managing cloud resources within Kubernetes.

**Install Crossplane:**

```bash
helm repo add crossplane https://charts.crossplane.io/stable && \
helm repo update crossplane && \
helm upgrade -i workspace-crossplane crossplane/crossplane \
  --version v1.17.1 \
  --namespace workspace \
  --create-namespace
```

### 4. Deploy the Workspace API

**Install the Workspace API:**

```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev && \
helm repo update eoepca-dev && \
helm upgrade -i workspace-api eoepca-dev/rm-workspace-api \
  --version 2.0.0 \
  --namespace workspace \
  --values workspace-api/generated-values.yaml
```

**Workspace API Ingress**

Note the ingress for the Workspace API is established using APISIX resources (ApisixRoute, ApisixTls). It is assumed that the `ClusterIssuer` dedicated to APISIX routes has been created (`letsencrypt-prod-apx`) - as described in section [Using Cert-Manager](../infra/tls/cert-manager.md).

```bash
kubectl -n workspace apply -f workspace-api/generated-ingress.yaml
```

### 5. Deploy the Workspace Pipelines

The Workspace Pipelines define the template that specifies the services provisioned within newly created Workspaces.

Some example pipelines are provided in the [Workspace Git Repository](https://github.com/EOEPCA/workspace) under the path `setup/eoepca-demo`.

These example pipelines are deployed here using `kustomize` (`kubectl -k`) with inline patching to apply the values configured via the `configure-workspace.sh` script.

**Apply the Pipelines:**

_NOTE that due to a race condition regarding the deployment of the Crossplane CRDs, it is necessary to run the apply command twice._

```bash
kubectl -n workspace apply -k workspace-pipelines 2>/dev/null ; \
while ! kubectl get crd providerconfigs.kubernetes.crossplane.io >/dev/null 2>&1 || \
      ! kubectl get crd providerconfigs.minio.crossplane.io >/dev/null 2>&1; \
      do sleep 1; done ; \
kubectl -n workspace apply -k workspace-pipelines
```

### 6. Deploy the Workspace Admin Dashboard

**Install the Workspace Admin Dashboard:**

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/ && \
helm repo update kubernetes-dashboard && \
helm upgrade -i workspace-admin kubernetes-dashboard/kubernetes-dashboard \
  --version 7.6.1 \
  --namespace workspace \
  --values workspace-admin/generated-values.yaml
```

**NOTE**: The Workspace Admin Dashboard is currently experiencing SSL certificate issues and will most likely not work as expected.

### 7. Deploy the Workspace UI


**Install the Workspace UI:**

```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev && \
helm repo update eoepca-dev && \
helm upgrade -i workspace-ui eoepca-dev/workspace-ui \
  --version 0.0.2 \
  --namespace workspace \
  --values workspace-ui/generated-values.yaml
```

### 8. Monitor the Deployment

Check the status of the deployments:

```bash
kubectl get all -n workspace
```

---

## Validation

**Automated Validation:**

```bash
bash validation.sh
```

**Further Validation:**

### 1. **Check Kubernetes Resources**

```bash
kubectl get all -n workspace
```

### 2. **Access Workspace API**

View the Swagger documentation for the Workspace API:

```
https://workspace-api.${INGRESS_HOST}/docs
```

### 3. **Access Workspace UI**

To access the Workspace UI, you will need the password that was generated during the configuration script. 

If you do not have the password, you can find it in the `generated-values.yaml` file. 

```
https://workspace-ui.${INGRESS_HOST}/
```


### 4. **Access Workspace Admin Dashboard**

```
https://workspace-admin.${INGRESS_HOST}/
```

### 6. **Create and check a new workspace**

Apply a `Workspace` resource...

```bash
cat <<EOF | kubectl apply -f -
apiVersion: epca.eo/v1beta1
kind: Workspace
metadata:
  name: ws-deploytest
  namespace: workspace
spec:
  subscription: bronze
EOF
```

Check a new namespace is created for the workspace...

```bash
kubectl get ns ws-deploytest
```

Check storage buckets (`ws-deploytest` and `ws-deploytest-stage`) are created for the workspace...

```bash
kubectl -n ws-deploytest get bucket
```

Get details for the new workspace via the workspace API...

_For simplicity, using port forward to bypass authorization (leave running in terminal)_
```bash
kubectl -n workspace port-forward svc/workspace-api 8080:8080
```

Then call the API via localhost...

```bash
curl http://localhost:8080/workspaces/ws-deploytest -H 'accept: application/json'
```

Use the S3 credentials (response `storage.credentials.secret`) to access the buckets...

```bash
SECRET="$(curl -s http://localhost:8080/workspaces/ws-deploytest -H 'accept: application/json' | jq -r '.storage.credentials.secret')"
```

Set your deployment domain...

```bash
INGRESS_HOST=<your-platform>
```

List buckets...

```bash
s3cmd ls \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ws-deploytest \
  --secret_key $SECRET
```

Put a file...

```bash
s3cmd put validation.sh s3://ws-deploytest \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ws-deploytest \
  --secret_key $SECRET
```

Check the bucket...

```bash
s3cmd ls s3://ws-deploytest \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ws-deploytest \
  --secret_key $SECRET
```

Empty the bucket...

```bash
s3cmd del s3://ws-deploytest/validation.sh \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ws-deploytest \
  --secret_key $SECRET
```

Delete the workspace...

```bash
kubectl -n workspace delete workspaces ws-deploytest
```

---

## Uninstallation

To uninstall the Workspace Building Block and clean up associated resources:

```bash
helm uninstall workspace-ui -n workspace ; \
helm uninstall workspace-admin -n workspace ; \
kubectl -n workspace delete -f workspace-api/generated-ingress.yaml; \
helm uninstall workspace-api -n workspace ; \
helm uninstall workspace-crossplane -n workspace ; \
kubectl delete -k workspace-pipelines -n workspace ; \
kubectl delete namespace workspace
```

---

## Further Reading

- [EOEPCA+ Workspace GitHub Repository](https://github.com/EOEPCA/workspace)
- [Crossplane Documentation](https://crossplane.io/docs/)
- [Flux GitOps Documentation](https://fluxcd.io/docs/)
- [vCluster Documentation](https://www.vcluster.com/docs/what-is-vcluster)
- [Kubernetes Dashboard Documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
