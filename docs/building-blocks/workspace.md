# Workspace Deployment Guide

The **Workspace** Building Block provides a comprehensive solution for storing assets and offering services like cataloguing, data access, and visualisation to explore stored assets. Workspaces can cater to individual users or serve as collaborative spaces for groups or projects. This guide provides step-by-step instructions to deploy the Workspace BB in your Kubernetes cluster using Helm.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Components Overview](#components-overview)
3. [Prerequisites](#prerequisites)
4. [Deployment Steps](#deployment-steps)
5. [Validation](#validation)
6. [Uninstallation](#uninstallation)
7. [Further Reading](#further-reading)
8. [Scripts and Manifests](#scripts-and-manifests)

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
| Ingress Controller | Properly installed (e.g., NGINX)                  | [Installation Guide](../infra/ingress-controller.md)      |
| Git Repository     | Access to a Git repository (e.g., GitHub, GitLab) | N/A                                                               |

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
### 3. Apply Kubernetes Secrets

Run the script to create the necessary Kubernetes secrets.

```bash
bash apply-secrets.sh
```

**Secrets Created in the `Workspace` namespace:**

- `harbor-admin-password`
- `minio-secret`

**Important Notes:**

- If you choose **not** to use `cert-manager`, you will need to create the TLS secrets manually before deploying.
  - The required TLS secret names are:
    - `workspace-admin-tls`
    - `workspace-api-v2-tls
    - `workspace-ui-tls`
  - For instructions on creating TLS secrets manually, please refer to the [Manual TLS Certificate Management](../infra/tls/manual-tls.md) section in the TLS Certificate Management Guide.

### 4. Deploy Crossplane

Crossplane is used for managing cloud resources within Kubernetes.

**Install Crossplane:**

```bash
helm repo add crossplane-stable https://charts.crossplane.io/stable

helm repo update

helm install workspace-crossplane crossplane-stable/crossplane \
  --version v1.17.1 \
  --namespace workspace \
  --create-namespace
```

### 5. Deploy the Workspace API

**Install the Workspace API:**

```bash
helm install workspace-api-v2 rm-workspace-api \
  --version 1.4.2 \
  --namespace workspace \
  --values workspace-api/generated-values.yaml \
  --repo https://eoepca.github.io/helm-charts
```

### 6. Deploy the Workspace Pipelines

The Workspace Pipelines are Git repositories containing the desired state for the workspaces.

**Clone the Workspace Repository:**

```bash
git clone https://github.com/EOEPCA/workspace
cd workspace/setup/eoepca-demo
```

**Customize the Pipelines:**

Modify the pipeline manifests as needed for your environment.

**Apply the Pipelines:**

```bash
kubectl apply -f . -n workspace
```

### 7. Deploy the Workspace Admin Dashboard

**Install the Workspace Admin Dashboard:**

```bash
cd ../../../
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
helm install workspace-admin kubernetes-dashboard/kubernetes-dashboard \
  --version 7.6.1 \
  --namespace workspace \
  --values workspace-admin/generated-values.yaml
```

### 8. Deploy the Workspace UI


**Install the Workspace UI:**

```bash
helm repo add eoepca-helm-dev https://eoepca.github.io/helm-charts-dev
helm repo update
helm install workspace-ui eoepca-helm-dev/workspace-ui \
  --version 0.0.2 \
  --namespace workspace \
  --values workspace-ui/generated-values.yaml
```

### 9. Monitor the Deployment

Check the status of the deployments:

```bash
kubectl get all -n workspace
```

### 10. Access the Workspace Services

Once the deployment is complete, you can access the services:

- **Workspace API**: `https://workspace-api-v2.${INGRESS_HOST}/`
- **Workspace UI**: `https://workspace-ui.${INGRESS_HOST}/`
- **Workspace Admin Dashboard**: `https://workspace-admin.${INGRESS_HOST}/`

---

## Validation

**Automated Validation:**

```bash
bash validation.sh
```

**Further Validation:**

1. **Check Kubernetes Resources:**

```bash
kubectl get all -n workspace
```

2. **Access Workspace API:**

   Open a web browser and navigate to: `https://workspace-api-v2.${INGRESS_HOST}/`

3. **Access Workspace UI:**

   Open a web browser and navigate to: `https://workspace-ui.${INGRESS_HOST}/`

4. **Access Workspace Admin Dashboard:**

   Open a web browser and navigate to: `https://workspace-admin.${INGRESS_HOST}/`

5. **Test Workspace Functionality:**

   - Create a new workspace using the Workspace API or UI.
   - Verify that the workspace is created and resources are provisioned.
   - Check that you can access the services within the workspace.

---

## Uninstallation

To uninstall the Workspace Building Block and clean up associated resources:

```bash
helm uninstall workspace-ui -n workspace
helm uninstall workspace-admin -n workspace
helm uninstall workspace-api-v2 -n workspace
helm uninstall workspace-crossplane -n workspace

kubectl delete namespace workspace
```

---

## Further Reading

- [EOEPCA+Workspace GitHub Repository](https://github.com/EOEPCA/workspace)
- [Crossplane Documentation](https://crossplane.io/docs/)
- [Flux GitOps Documentation](https://fluxcd.io/docs/)
- [vCluster Documentation](https://www.vcluster.com/docs/what-is-vcluster)
- [Kubernetes Dashboard Documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
