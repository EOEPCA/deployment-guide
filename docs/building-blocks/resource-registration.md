# Resource Registration Deployment Guide

The **Resource Registration** Building Block supports the ingestion of data and its associated metadata into the platform services, including metadata registration into the Resource Discovery service and data registration into Data Access services for data retrieval and visualisation. This guide provides step-by-step instructions to deploy the Resource Registration BB in your Kubernetes cluster.

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

The **Resource Registration Building Block** provides support for ingesting resources into the platform so that they can be discovered, accessed, and used collaboratively. These resources include, but are not limited to, datasets, workflows, Jupyter Notebooks, services, web applications, and documentation.

---

## Components Overview

The Resource Registration BB comprises the following key components:

1. **Registration API**: Provides core resource management services on the local platform, offering an OGC API Processes interface for resource creation, update, and deletion.

2. **Harvester**: Implements workflows for harvesting and registering resources from external data sources using the Flowable BPMN platform.

3. **Common Library**: A Python library that consolidates functionalities from various upstream packages, used to implement business logic in workflows and resource handling.

---

## Prerequisites

Before deploying the Resource Registration Building Block, ensure you have the following:

| Component          | Requirement                            | Documentation Link                                                |
| ------------------ | -------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.28)              | [Installation Guide](../infra/kubernetes-cluster-and-networking.md)             |
| Helm               | Version 3.7 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| TLS Certificates   | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../infra/tls/overview.md/) |
| Ingress Controller | Properly installed (e.g., NGINX)       | [Installation Guide](../infra/ingress-controller.md)      |


**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-alpha https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/resource-registration
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
bash configure-resource-registration.sh
```

**Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
  - *Example*: `example.com`
- **`CLUSTER_ISSUER`**: Cert-Manager ClusterIssuer for TLS certificates.
  - *Example*: `letsencrypt-prod`
- **`FLOWABLE_ADMIN_USER`**: Admin username for Flowable.
  - *Default*: `eoepca`
- **`FLOWABLE_ADMIN_PASSWORD`**: Admin password for Flowable.
  - *Default*: `eoepca`

**Important Notes:**

- If you choose **not** to use `cert-manager`, you will need to create the TLS secrets manually before deploying.
  - The required TLS secret names are:
    - `registration-api-tls-secret`
  - For instructions on creating TLS secrets manually, please refer to the [Manual TLS Certificate Management](../infra/tls/manual-tls.md) section in the TLS Certificate Management Guide.

### 2. Apply Kubernetes Secrets

Run the script to create the necessary Kubernetes secrets.

```bash
bash apply-secrets.sh
```

**Secrets Created:**

- `flowable-admin-credentials`: Contains Flowable admin username and password.

### 3. Deploy the Registration API Using Helm

Add the EOEPCA+Helm repository and deploy the Registration API using the generated values file.

```bash
helm repo add eoepca-helm https://eoepca.github.io/helm-charts-dev
helm repo update

helm install registration-api eoepca-helm/registration-api \
  --version 2.0.0-beta1 \
  --namespace rm \
  --create-namespace \
  --values registration-api/generated-values.yaml
```

### 4. Deploy the Registration Harvester Using Helm

**Deploy Flowable Engine:**

```bash
helm repo add flowable https://flowable.github.io/helm/

helm repo update

helm install registration-harvester-api-engine flowable/flowable \
  --version 7.0.0 \
  --namespace registration-harvester-api \
  --create-namespace \
  --values registration-harvester/generated-values.yaml
```

**Deploy Registration Harvester Worker:**

```bash
helm install registration-harvester-worker eoepca-helm/registration-harvester \
  --version 2.0.0-beta1 \
  --namespace registration-harvester-api \
  --values registration-harvester/generated-values.yaml
```


### 6. Monitor the Deployment

Check the status of the deployments:

```bash
kubectl get all -n rm
kubectl get all -n registration-harvester-api
```

### 7. Access the Registration Services

Once the deployment is complete, you can access the services:

- **Registration API**: `http://registration-api.<your-domain>/`
- **Registration Harvester API**: `http://registration-harvester-api.<your-domain>/`

---

## Validation

**Automated Validation:**

```bash
bash validation.sh
```

**Further Validation:**

1. **Check Kubernetes Resources:**

   ```bash
   kubectl get all -n rm
   kubectl get all -n registration-harvester-api
   ```

2. **Access Registration API:**

   Open a web browser and navigate to: `http://registration-api.${INGRESS_HOST}/`

3. **Access Flowable UI:**

   Open a web browser and navigate to: `http://registration-harvester-api.${INGRESS_HOST}/flowable-ui/`

4. **Test Resource Registration Functionality:**

   Verify that the Registration API services are operational by performing test actions through the APIs.

---

## Uninstallation

To uninstall the Resource Registration Building Block and clean up associated resources:

```bash
helm uninstall registration-api -n rm
helm uninstall registration-api-protection -n rm
helm uninstall registration-harvester-api-engine -n registration-harvester-api
helm uninstall registration-harvester-worker -n registration-harvester-api

kubectl delete namespace rm
kubectl delete namespace registration-harvester-api
```

---

## Further Reading

- [EOEPCA+Resource Registration GitHub Repository](https://github.com/EOEPCA/resource-registration)
- [Flowable BPMN Platform](https://flowable.com/open-source/)
- [pygeoapi Documentation](https://pygeoapi.io/)
- [EOEPCA+Helm Charts](https://eoepca.github.io/helm-charts-dev)
