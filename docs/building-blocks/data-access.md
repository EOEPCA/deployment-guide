
# Data Access Deployment Guide

The **Data Access** Building Block provides feature-rich and reliable interfaces to geospatial data assets stored in the platform, addressing both human and machine users. This guide provides step-by-step instructions to deploy the Data Access BB in your Kubernetes cluster.

---

## Introduction

The Data Access Building Block combines capabilities from two complementary libraries:

- **eoAPI**: Provides STAC data discovery, OGC API Features and OGC API Tiles for vector and raster data access.
- **EOX View Server (Stacture and Terravis)**: Adds support for OGC API Coverages, OGC WCS, and advanced rendering mechanisms.

The building block offers:

- STAC API for data discovery
- Support for retrieval and visualisation of features and coverages via standard OGC APIs
- Dynamic specification of which datasets should be delivered with which data access services
- Integration with other building blocks through shared databases (e.g., pgSTAC)

---

## Components Overview

The Data Access BB consists of the following main components:

1. **eoAPI**: A set of microservices for geospatial data access, including:

    - **stac**: STAC API for accessing geospatial metadata.
    - **raster**: Access to raster data via OGC APIs.
    - **vector**: Access to vector data via OGC APIs.
2. **PostgreSQL with PostGIS and pgSTAC**: Database for storing geospatial metadata and data managed by the [Crunchy Data Postgres Operator (pgo)](https://access.crunchydata.com/documentation/postgres-operator).
    
3. **Stacture and Terravis**: Components from EOX View Server providing:
    
    - **Stacture**: Bridges STAC API with OGC API Coverages and OGC WCS.
    - **Terravis**: Provides advanced rendering and processing capabilities.
4. **Tyk Gateway**: API Gateway for authentication, authorization, rate-limiting, and caching, integrated with the Identity Management BB.
    
5. **Redis**: In-memory data structure store used by Tyk.
    
6. **eoapi-support**: Optional but recommended monitoring stack (Grafana, Prometheus, metrics server) to observe and manage the Data Access services.
    

---

## Prerequisites

Before deploying the Data Access Building Block, ensure you have the following:

| Component          | Requirement                            | Documentation Link                                                |
| ------------------ | -------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.28)              | [Installation Guide](../prerequisites/kubernetes.md)             |
| Helm               | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| Ingress Controller   | Properly installed                     | [Installation Guide](../prerequisites/ingress-controller.md)  |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md) |
| Object Store                 | Accessible object store (i.e. MinIO)   | [MinIO Deployment Guide](../prerequisites/minio.md)                                          |


**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
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
    - _Example_: `example.com`
- **`CLUSTER_ISSUER`** (optional): Cert-manager Cluster Issuer for TLS certificates.
    - _Example_: `letsencrypt-prod`
- **`STORAGE_CLASS`**: Storage class for persistent volumes.
    - _Example_: `standard`
- **`S3_HOST`**: Host URL for MinIO or S3-compatible storage.
    - _Example_: `minio.example.com`
- **`S3_ACCESS_KEY`**: Access key for your S3 storage.
- **`S3_SECRET_KEY`**: Secret key for S3 storage.


### 2. Deploy PostgreSQL Operator and eoAPI

1. **Install the PostgreSQL Operator (pgo) from the Crunchy Data OCI registry:**
    
```bash
helm upgrade -i pgo oci://registry.developers.crunchydata.com/crunchydata/pgo \
  --version 5.6.0 \
  --namespace data-access \
  --create-namespace \
  --values postgres/generated-values.yaml
```
    
2. **Install `eoAPI`:**
    
```bash
helm repo add eoapi https://devseed.com/eoapi-k8s/
helm repo update eoapi

helm upgrade -i eoapi eoapi/eoapi \
  --version 0.5.2 \
  --namespace data-access \
  --values eoapi/generated-values.yaml
```

3. **(Optional) Install `eoapi-support`** for Grafana, Prometheus, and the metrics server:
    
```bash
helm upgrade -i eoapi-support eoapi/eoapi-support \
  --version 0.1.7 \
  --namespace data-access \
  --values eoapi-support/generated-values.yaml
```

> **Note**: If you prefer to monitor Data Access with your own monitoring solution, you can skip this step.


---

### 3. Deploy Stacture

Stacture bridges the STAC API with OGC API Coverages and WCS. It also handles advanced rendering through Terravis.

```bash
helm repo add eox https://charts-public.hub.eox.at/
helm repo update eox

helm upgrade -i stacture eox/stacture \
  --version 0.0.0 \
  --namespace data-access \
  --values stacture/generated-values.yaml
```

> This deploys **Stacture** and **Terravis** with images tagged at `v0.0.8` (configured in your `stacture/generated-values.yaml`).

---

### 4. Deploy Tyk Gateway and Redis

1. **Install Redis for Tyk Gateway:**
    
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update bitnami

helm upgrade -i tyk-redis bitnami/redis \
  --version 20.1.0 \
  --namespace data-access \
  --values tyk-gateway/redis-generated-values.yaml
```

2. **Install Tyk Gateway:**
    
```bash
helm repo add tyk-oss https://helm.tyk.io/public/helm/charts/
helm repo update tyk-oss

helm upgrade -i tyk-oss tyk-oss/tyk-oss \
  --version 1.6.0 \
  --namespace data-access \
  --values tyk-gateway/generated-values.yaml
```


Tyk integrates with Identity Management for secure access and additional capabilities such as rate limiting or caching.

---

### 5. Monitoring the Deployment

After deploying, you can monitor the status of the deployments:

```bash
kubectl get all -n data-access
```

Check that all pods are in the `Running` state and that services/ingresses are properly exposed.

---

### 6. Accessing the Data Access Services

Once the deployment is complete and all pods are running, you can access the services:

- **eoAPI STAC API:**  
    `https://eoapi.${INGRESS_HOST}/stac/`
    
- **Stacture API (coverages, WCS, etc.):**  
    `https://stacture.${INGRESS_HOST}/`
<!-- currently ingress issues -->
- **Tyk Gateway Dashboard** (if exposed via ingress):  
    `https://tyk-gateway.${INGRESS_HOST}/`
    
- **Grafana** (if `eoapi-support` is installed and ingress is enabled):  
    `https://eoapisupport.${INGRESS_HOST}/`
<!-- add default credentials -->

---

## Testing and Validation

Below are some quick ways to test and validate the Data Access services.

### 1. Access the Swagger UI

The Data Access Building Block provides Swagger UI documentation for its APIs, allowing you to interact with the APIs directly from your browser.

- **eoAPI STAC API Swagger UI**:  
    `https://eoapi.<INGRESS_HOST>/stac/api.html`
    
- **eoAPI Raster API Swagger UI**:  
    `https://eoapi.<INGRESS_HOST>/raster/api.html`
    
- **eoAPI Vector API Swagger UI**:  
    `https://eoapi.<INGRESS_HOST>/vector/api.html`
    
- **Stacture API Swagger UI**:  
    `https://stacture.<INGRESS_HOST>/`
    

Replace `<INGRESS_HOST>` with your actual ingress host domain.

### 2. Run Demo Jupyter Notebooks

The [EOEPCA/demo](https://github.com/EOEPCA/demo) Jupyter Notebooks showcase how to interact with the Data Access services programmatically, including examples for data discovery, visualization, and data download using the Data Access APIs. See the [04 Data Access Notebook](https://github.com/EOEPCA/demo/blob/main/demoroot/notebooks/04%20Data%20Access.ipynb) for usage examples.

- Before running the notebooks, ensure that sample data is registered into the Data Access component. Follow the [Resource Registration Guide](./resource-registration.md).

- In the notebooks, set the `base_domain` variable to reflect your endpoint:
    
```python
base_domain = "<INGRESS_HOST>"
```

For more information on how to run the demo Jupyter Notebooks, please visit the [EOEPCA/demo Readme](https://github.com/EOEPCA/demo/blob/main/README.md).

### 3. Perform Basic API Tests

You can perform basic tests using tools like `curl` or directly through the Swagger UI.

**Example: Retrieve STAC API Landing Page**

```bash
curl -X GET "https://eoapi.<INGRESS_HOST>/stac/" -H "accept: application/json"
```

**Example: Search STAC Items**

```bash
curl -X POST "https://eoapi.<INGRESS_HOST>/stac/search" \
  -H "Content-Type: application/json" \
  -d '{
    "bbox": [-10, 35, 0, 45],
    "datetime": "2021-01-01T00:00:00Z/2021-12-31T23:59:59Z",
    "limit": 10
  }'
```

---

## Uninstallation

To uninstall the Data Access Building Block and clean up associated resources:

```bash
helm uninstall tyk-oss -n data-access
helm uninstall tyk-redis -n data-access
helm uninstall stacture -n data-access
helm uninstall eoapi-support -n data-access
helm uninstall eoapi -n data-access
helm uninstall pgo -n data-access

kubectl delete namespace data-access
```

---

## Further Reading

- [EOEPCA+ Data Access GitHub Repository](https://github.com/EOEPCA/data-access)
- [eoAPI Documentation](https://github.com/developmentseed/eoAPI)
- [Tyk Gateway Documentation](https://tyk.io/docs/)
- [Crunchy Data Postgres Operator Documentation](https://access.crunchydata.com/documentation/postgres-operator/)
