# Data Access Deployment Guide

The **Data Access** Building Block provides feature-rich and reliable interfaces to geospatial data assets stored in the platform, addressing both human and machine users. This guide provides step-by-step instructions to deploy the Data Access BB in your Kubernetes cluster.

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

The Data Access Building Block combines capabilities from two complementary libraries:

- **eoAPI**: Provides OGC API Features and OGC API Tiles for vector and raster data access.
- **EOX View Server (Stacture and Terravis)**: Adds support for OGC API Coverages, OGC WCS, and advanced rendering mechanisms.

The building block offers:

- Support for retrieval and visualisation of features and coverages via standard OGC APIs.
- Dynamic specification of which datasets should be delivered with which data access services.
- Integration with other building blocks through shared databases (e.g., pgSTAC).

---

## Components Overview

The Data Access BB consists of the following main components:

1. **eoAPI**: A set of microservices for geospatial data access, including:
   - **stac**: STAC API for accessing geospatial metadata.
   - **raster**: Access to raster data via OGC APIs.
   - **vector**: Access to vector data via OGC APIs.

2. **PostgreSQL with PostGIS and pgSTAC**: Database for storing geospatial metadata and data.

3. **Stacture and Terravis**: Components from EOX View Server providing:
   - **Stacture**: Bridges STAC API with OGC API Coverages and OGC WCS.
   - **Terravis**: Provides advanced rendering and processing capabilities.

4. **Tyk Gateway**: API Gateway for authentication, authorization, rate-limiting, and caching, integrated with the Identity Management BB.

5. **Redis**: In-memory data structure store used by Tyk.

---

## Prerequisites

Before deploying the Data Access Building Block, ensure you have the following:

| Component          | Requirement                            | Documentation Link                                                |
| ------------------ | -------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.28)              | [Installation Guide](../infra/kubernetes-cluster-and-networking.md)             |
| Helm               | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| Ingress Controller   | Properly installed                     | [Installation Guide](../infra/ingress-controller.md)  |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../infra/tls/overview.md/) |
| Object Store                 | Accessible object store (i.e. MinIO)   | [MinIO Deployment Guide](../infra/minio.md)                                          |


**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-alpha https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/data-access
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
bash configure-data-access.sh
```

**Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
  - *Example*: `example.com`
- **`CLUSTER_ISSUER`**: Cert-manager Cluster Issuer for TLS certificates.
  - *Example*: `letsencrypt-prod`
- **`STORAGE_CLASS`**: Storage class for persistent volumes.
 - *Example*: `managed-nfs-storage-retain`
- **`S3_HOST`**: Host URL for MinIO or S3-compatible storage.
  - *Example*: `minio.example.com`
- **`S3_ACCESS_KEY`**: Access key for your S3 storage.
- **`S3_SECRET_KEY`**: Secret key for S3 storage.

**Important Notes:**

- If you choose **not** to use `cert-manager`, you will need to create the TLS secrets manually before deploying.
  - The required TLS secret names are:
    - `eoapi-tls`
    - `data-access-stacture-tls`
  - For instructions on creating TLS secrets manually, please refer to the [Manual TLS Certificate Management](../infra/tls/manual-tls.md) section in the TLS Certificate Management Guide.


### 2. Deploy PostgreSQL Operator (pgo) and eoAPI

**Add the required Helm repositories:**

```bash
helm repo add eoapi-k8s https://devseed.com/eoapi-k8s/
helm repo update
```

**Install pgo (PostgreSQL Operator) from OCI registry:**

```bash
helm install pgo oci://registry.developers.crunchydata.com/crunchydata/pgo \
  --version 5.5.2 \
  --namespace data-access \
  --create-namespace \
  --values postgres/generated-values.yaml
```

**Install eoAPI:**

```bash
helm install eoapi eoapi-k8s/eoapi \
  --version 0.4.17 \
  --namespace data-access \
  --values eoapi/generated-values.yaml
```

### 3. Deploy Stacture

**Add the EOX Helm repository:**

```bash
helm repo add eox https://charts-public.hub.eox.at/
helm repo update
```

**Install Stacture:**

```bash
helm install stacture eox/stacture \
  --version 0.0.0 \
  --namespace data-access \
  --values stacture/generated-values.yaml
```

### 4. Deploy Tyk Gateway and Redis

**Add the Tyk and Bitnami Helm repositories:**

```bash
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

**Install Redis for Tyk Gateway:**

```bash
helm install tyk-redis bitnami/redis \
  --version 20.1.0 \
  --namespace data-access \
  --values tyk-gateway/redis-generated-values.yaml
```

**Install Tyk Gateway:**

```bash
helm install tyk-oss tyk-helm/tyk-oss \
  --version 1.6.0 \
  --namespace data-access \
  --values tyk-gateway/generated-values.yaml
```


---

### Monitoring the Deployment

After deploying, you can monitor the status of the deployments:

```bash
kubectl get all -n data-access
```

### Accessing the Data Access Services

Once the deployment is complete and all pods are running, you can access the services:

- **eoAPI STAC API:** `http://eoapi.${INGRESS_HOST}/stac/`
- **Stacture API:** `http://stacture.${INGRESS_HOST}/`

---

### Uninstallation

To uninstall all components and clean up resources:

```bash
helm uninstall tyk-oss -n data-access
helm uninstall tyk-redis -n data-access
helm uninstall stacture -n data-access
helm uninstall eoapi -n data-access
helm uninstall pgo -n data-access

kubectl delete namespace data-access
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
   kubectl get all -n data-access
   ```

2. **Access eoAPI STAC API:**

   Open a web browser and navigate to: `http://eoapi.<your-ingress-host>/stac/`

3. **Access Stacture API:**

   Open a web browser and navigate to: `http://stacture.<your-ingress-host>/`

4. **Test Data Access Functionality:**

   Verify that the Data Access services are operational by performing test actions through the APIs.

---

## Uninstallation

To uninstall the Data Access Building Block and clean up associated resources:

```bash
helm uninstall tyk-gateway -n data-access
helm uninstall tyk-redis -n data-access
helm uninstall stacture -n data-access
helm uninstall eoapi -n data-access
helm uninstall pgo -n data-access

kubectl delete namespace data-access
```

---

## Further Reading

- [EOEPCA+ Data Access GitHub Repository](https://github.com/EOEPCA/data-access)
- [eoAPI Documentation](https://github.com/developmentseed/eoAPI)
- [Stacture Documentation](https://stacture.readthedocs.io/)
- [Tyk Gateway Documentation](https://tyk.io/docs/)
- [Crunchy Data PostgreSQL Operator](https://github.com/CrunchyData/postgres-operator-examples)