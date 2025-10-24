# Data Access Deployment Guide

The **Data Access** Building Block provides feature-rich and reliable interfaces to geospatial data assets stored in the platform, addressing both human and machine users. This guide provides step-by-step instructions to deploy the Data Access BB in your Kubernetes cluster.

---

## Introduction

The Data Access Building Block provides STAC data discovery, OGC API Features and OGC API Tiles for vector and raster data access.

The building block offers:

- STAC API for data discovery with optional transaction support
- Support for retrieval and visualisation of raster and vector data via standard OGC APIs
- Dynamic specification of which datasets should be delivered with which data access services
- Integration with other building blocks through shared databases (e.g. pgSTAC)
- Optional IAM integration for secure access control
- Event-driven architecture support via CloudEvents

---

## Components Overview

The Data Access BB consists of the following main components:

1. **eoAPI**: A set of microservices for geospatial data access, including:

    - **stac**: STAC API for accessing geospatial metadata with transaction extensions
    - **raster**: Access to raster data via OGC APIs
    - **vector**: Access to vector data via OGC APIs
    - **multidim**: Support for multidimensional data access

2. **PostgreSQL with PostGIS and pgSTAC**<br>
   Database for storing geospatial metadata and data. Can be deployed as:
   - Internal cluster managed by [Zalando Postgres Operator](https://github.com/zalando/postgres-operator)
   - External PostgreSQL accessed via External Secrets Operator
    
3. **STAC Manager UI**<br>
   Web interface for managing STAC collections and items with optional OAuth integration
   
4. **EOAPI Maps Plugin**<br>
   PyGeoAPI-based service for OGC API Maps implementation

5. **Optional Components:**
   - **eoapi-support**: Monitoring stack (Grafana, Prometheus, metrics server)
   - **eoapi-notifier**: CloudEvents integration for event-driven workflows
   - **IAM Integration**: Keycloak authentication and OPA authorization

---

## Prerequisites

Before deploying the Data Access Building Block, ensure you have the following:

| Component          | Requirement                            | Documentation Link                                                |
| ------------------ | -------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.28)              | [Installation Guide](../prerequisites/kubernetes.md)             |
| Helm               | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| Ingress Controller | Properly installed (NGINX or APISIX)   | [Installation Guide](../prerequisites/ingress/overview.md)       |
| TLS Certificates   | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md)      |
| Object Store       | Accessible object store (i.e. MinIO)   | [MinIO Deployment Guide](../prerequisites/minio.md)              |

**Optional Prerequisites (for advanced features):**

| Component                | Requirement                    | Required For                        |
| ------------------------ | ------------------------------ | ----------------------------------- |
| External Secrets Operator | If using external PostgreSQL   | Production deployments              |
| Keycloak                 | For IAM integration            | Secure access control               |
| OPA (Open Policy Agent)  | For authorization              | Fine-grained access policies        |
| Knative Eventing         | For CloudEvents                | Event-driven workflows              |

**Clone the Deployment Guide Repository:**
```bash
git clone https://github.com/EOEPCA/deployment-guide
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

**Core Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts
    - _Example_: `example.com`
- **`PERSISTENT_STORAGECLASS`**: Storage class for persistent volumes
    - _Example_: `standard`
- **`S3_HOST`**: Host URL for MinIO or S3-compatible storage
    - _Example_: `minio.example.com`
- **`S3_ACCESS_KEY`**: Access key for your S3 storage
- **`S3_SECRET_KEY`**: Secret key for S3 storage
- **`S3_ENDPOINT`**: S3 endpoint for EOAPI services
    - _Example_: `eodata.cloudferro.com` or `minio.example.com`

**Advanced Configuration Options**

- **`USE_EXTERNAL_POSTGRES`**: Use external PostgreSQL with External Secrets Operator (yes/no)
    - If yes, you'll be prompted for:
        - **`POSTGRES_EXTERNAL_SECRET_NAME`**: External secret name (default: `default-pguser-eoapi`)
    - If no, you'll configure:
        - **`POSTGRES_REPLICAS`**: Number of PostgreSQL replicas
        - **`POSTGRES_STORAGE_SIZE`**: Storage size for PostgreSQL

- **`ENABLE_IAM`**: Enable IAM/Keycloak integration (yes/no)
    - If yes, you'll configure:
        - **`KEYCLOAK_URL`**: Keycloak server URL
        - **`KEYCLOAK_REALM`**: Keycloak realm name
        - **`KEYCLOAK_CLIENT_ID`**: Client ID for EOAPI
        - **`OPA_URL`**: OPA server URL for authorization

- **`ENABLE_TRANSACTIONS`**: Enable STAC transactions extension (yes/no)
- **`ENABLE_EOAPI_NOTIFIER`**: Enable CloudEvents notifier (yes/no)


### 3. Deployment

#### Apply Secrets
```bash
bash apply-secrets.sh
```

#### Deploy PostgreSQL (if using internal)
```bash
helm repo add postgres-operator https://postgres-operator-examples.github.io/charts
helm repo update

helm upgrade --install pgo oci://registry.developers.crunchydata.com/crunchydata/pgo \
  --version 5.6.0 \
  --namespace data-access \
  --create-namespace \
  --values postgres/generated-values.yaml \
  --wait
```

#### Deploy eoAPI
```bash
helm repo add eoapi https://devseed.com/eoapi-k8s/
helm repo update
helm upgrade -i eoapi eoapi/eoapi \
  --version 0.7.12 \
  --namespace data-access \
  --values eoapi/generated-values.yaml
```

#### Deploy STAC Manager
```bash
helm repo add stac-manager https://stac-manager.ds.io/
helm repo update
helm upgrade -i stac-manager stac-manager/stac-manager \
  --version 0.0.11 \
  --namespace data-access \
  --values stac-manager/generated-values.yaml
```

#### Deploy EOAPI Maps Plugin
```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev/
helm repo update
helm upgrade -i eoapi-maps-plugin eoepca-dev/eoapi-maps-plugin \
  --version 0.0.21 \
  --namespace data-access \
  --values eoapi-maps-plugin/generated-values.yaml
```

#### Configure Ingress/Routes

For APISIX with IAM:
```bash
kubectl apply -f iam/generated-iam.yaml  # If IAM enabled
kubectl apply -f routes/generated-apisix-route.yaml  # APISIX routes
```

For APISIX without IAM or NGINX:
```bash
kubectl apply -f eoapi/generated-ingress.yaml
```

#### (Optional) Deploy Monitoring
```bash
helm upgrade -i eoapi-support eoapi/eoapi-support \
  --version 0.1.7 \
  --namespace data-access \
  --values eoapi-support/generated-values.yaml
```

---

### 4. Monitoring the Deployment

After deploying, monitor the status:
```bash
kubectl get all -n data-access
```

Run validation:
```bash
bash validation.sh
```

---

### 5. Accessing the Data Access Services

Once deployment is complete:

**Core Services:**
- **STAC API:** `https://eoapi.${INGRESS_HOST}/stac/`
- **Raster API:** `https://eoapi.${INGRESS_HOST}/raster/`
- **Vector API:** `https://eoapi.${INGRESS_HOST}/vector/`
- **Multidim API:** `https://eoapi.${INGRESS_HOST}/multidim/`
- **STAC Manager UI:** `https://eoapi.${INGRESS_HOST}/manager/`
- **Maps API:** `https://eoapi.${INGRESS_HOST}/maps/`

**Optional Services:**
- **Grafana** (if monitoring enabled): `https://eoapisupport.${INGRESS_HOST}/`

---

## Load Sample Collection

Load the sample `Sentinel-2-L2A-Iceland` collection:
```bash
cd collections/sentinel-2-iceland
../ingest.sh
cd ../..
```

Check the loaded collection via STAC Browser:
```bash
source ~/.eoepca/state
xdg-open https://radiantearth.github.io/stac-browser/#/external/eoapi.${INGRESS_HOST}/stac/collections/sentinel-2-iceland
```

---

## Testing and Validation

### 1. Access the Swagger UI

- **STAC API:** `https://eoapi.${INGRESS_HOST}/stac/api.html`
- **Raster API:** `https://eoapi.${INGRESS_HOST}/raster/api.html`
- **Vector API:** `https://eoapi.${INGRESS_HOST}/vector/api.html`
- **Multidim API:** `https://eoapi.${INGRESS_HOST}/multidim/api.html`

### 2. Access the STAC Browser UI

> There is a sample collection loaded in the previous step.

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://eoapi.${INGRESS_HOST}/browser/"
```

### 3. Perform Basic API Tests

**Retrieve STAC API Landing Page:**
```bash
source ~/.eoepca/state
curl -X GET "https://eoapi.${INGRESS_HOST}/stac/" -H "accept: application/json"
```

**Search STAC Items:**

```bash
curl -X POST "https://eoapi.${INGRESS_HOST}/stac/search" \
  -H "Content-Type: application/json" \
  -d '{
    "bbox": [-130.0, 20.0, -60.0, 55.0],
    "datetime": "2001-01-01T00:00:00Z/2021-12-31T23:59:59Z",
    "limit": 10
  }'
```

---

## Uninstallation

To uninstall the Data Access Building Block:
```bash
helm uninstall eoapi -n data-access
helm uninstall eoapi-maps-plugin -n data-access
helm uninstall stac-manager -n data-access
helm uninstall postgres-operator -n data-access  # or pgo if using Crunchy
helm uninstall eoapi-support -n data-access  # if monitoring was installed

kubectl delete namespace data-access
```

## Further Reading

- [EOEPCA+ Data Access GitHub Repository](https://github.com/EOEPCA/data-access)
- [eoAPI Documentation](https://github.com/developmentseed/eoAPI)
- [Zalando Postgres Operator Documentation](https://github.com/zalando/postgres-operator)
- [External Secrets Operator](https://external-secrets.io/)
- [APISIX Ingress Controller](https://apisix.apache.org/docs/ingress-controller/getting-started/)