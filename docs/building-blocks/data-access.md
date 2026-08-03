# Data Access Deployment Guide

The **Data Access** Building Block provides standard OGC/STAC interfaces to geospatial data assets stored in the platform. This guide provides step-by-step instructions to deploy the Data Access BB in your Kubernetes cluster.

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

4. **titiler-openeo**<br>
   openEO API implementation backed by titiler, serving on-the-fly raster processing/visualisation services under `/openeo`

5. **Optional Components:**
   - **eoapi-support**: Monitoring stack (Grafana, Prometheus, metrics server)
   - **eoapi-notifier**: CloudEvents integration for event-driven workflows
   - **geoparquet-exporter**: Scheduled export of pgSTAC collections/items to GeoParquet on S3
   - **IAM Integration**: Keycloak authentication and OPA authorization

---

## Prerequisites

Before deploying the Data Access Building Block, ensure you have the following:

| Component          | Requirement                            | Documentation Link                                                |
| ------------------ | -------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.32)              | [Installation Guide](../prerequisites/kubernetes.md)             |
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
- **`CLUSTER_ISSUER`**: Cluster issuer for TLS certificates
    - _Example_: `letsencrypt-prod`
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

- **`DATA_ACCESS_ENABLE_IAM`**: Enable IAM/Keycloak integration (yes/no). IAM works under both `apisix` and `nginx` ingress classes.

=== "Without IAM (default)"

    You'll be prompted for a **`OPENEO_BASIC_AUTH_USER`** - a password is generated automatically and printed at the end of configuration (used to protect the openEO API, which has no other auth option without IAM).

    Every STAC collection/item is publicly readable and writable - see [Collection-Level Access Control](#4-collection-level-access-control-iam) below.

=== "With IAM"

    You'll be prompted for:

    - **`KEYCLOAK_HOST`**: Keycloak service hostname
    - **`REALM`**: Keycloak realm name
    - **`EOAPI_CLIENT_ID`**: Client ID for EOAPI
    - **`OPA_URL`**: OPA server URL for authorization

    This requires the [IAM Building Block](./iam/main-iam.md) already deployed.

- **`ENABLE_TRANSACTIONS`**: Enable STAC transactions extension (yes/no)
- **`ENABLE_EOAPI_NOTIFIER`**: Enable CloudEvents notifier (yes/no)
- **`ENABLE_GEOPARQUET_EXPORT`**: Enable scheduled pgSTAC-to-geoparquet export to S3 (yes/no)
    - If yes, you'll be prompted for **`GEOPARQUET_EXPORT_S3_BUCKET`** - the destination `s3://` path, reusing the same S3 credentials as raster/multidim

**PgSTAC Configuration Options**

Configure via `pgstacBootstrap.settings.pgstacSettings`:

| Values Key | Description | Default | Format |
|------------|-------------|---------|--------|
| `queue_timeout` | Timeout for queued queries | `"10 minutes"` | PostgreSQL interval |
| `use_queue` | Enable query queue mechanism | `"false"` | boolean string |
| `update_collection_extent` | Auto-update collection extents | `"true"` | boolean string |

**CronJobs Configuration**

CronJobs are conditionally created based on PgSTAC settings:

- **Queue Processor** (created when `use_queue: "true"`):
  - Schedule: `"0 * * * *"` (hourly)
  - Processes queries that exceeded timeout
  - Configurable via `queueProcessor.schedule`

- **Extent Updater** (created when `update_collection_extent: "false"`):
  - Schedule: `"0 2 * * *"` (daily at 2 AM)
  - Updates collection spatial/temporal boundaries
  - Configurable via `extentUpdater.schedule`

By default, no CronJobs are created (`use_queue=false`, `update_collection_extent=true`). Both schedules are customizable using standard cron format.

**Example PgSTAC Configuration:**

```yaml
pgstacBootstrap:
  settings:
    pgstacSettings:
      # Performance tuning for large datasets
      queue_timeout: "20 minutes"
      use_queue: "true"
      update_collection_extent: "false"
```

### 3. Deployment

#### Apply Secrets
```bash
bash apply-secrets.sh
```

#### Deploy PostgreSQL Operator (if using internal database)

!!! note
    If using the external PostgreSQL option, skip this step.

```bash
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
helm repo update eoapi
helm upgrade -i eoapi eoapi/eoapi \
  --version 0.13.1 \
  --namespace data-access \
  --create-namespace \
  --values eoapi/generated-values.yaml
```

#### Deploy STAC Manager
```bash
helm repo add stac-manager https://stac-manager.ds.io/
helm repo update stac-manager
helm upgrade -i stac-manager stac-manager/stac-manager \
  --version 1.0.3 \
  --namespace data-access \
  --values stac-manager/generated-values.yaml
```

#### Deploy titiler-openeo

`titiler-openeo` is only published as a git-sourced Helm chart (no packaged chart repo), so it's installed directly from a pinned tag:
```bash
git clone --depth 1 --branch titiler-openeo-v0.12.0 https://github.com/sentinel-hub/titiler-openeo /tmp/titiler-openeo
helm upgrade -i titiler-openeo /tmp/titiler-openeo/deployment/k8s/charts \
  --namespace data-access \
  --values titiler-openeo/generated-values.yaml
```

#### Configure Ingress/Routes

=== "Without IAM (default)"

    If APISIX is the configured ingress controller, apply the dedicated `ApisixRoute`:

    ```bash
    source ~/.eoepca/state
    if [ "${INGRESS_CLASS}" = "apisix" ]; then
      kubectl apply -f eoapi/generated-ingress.yaml
    fi
    ```

=== "With IAM"

    Configure Keycloak with a Client and associated Roles/Groups, then - if APISIX is the configured ingress controller - apply the dedicated `ApisixRoute`:

    ```bash
    source ~/.eoepca/state
    kubectl apply -f iam/generated-iam.yaml
    if [ "${INGRESS_CLASS}" = "apisix" ]; then
      kubectl apply -f eoapi/generated-ingress.yaml
    fi
    ```

#### (Optional) Deploy Geoparquet Exporter

!!! note
    Skip this step if `ENABLE_GEOPARQUET_EXPORT=no`.

Also only published as a git-sourced Helm chart:
```bash
git clone --depth 1 --branch v0.2.4 https://github.com/developmentseed/pgstac-geoparquet-exporter /tmp/pgstac-geoparquet-exporter
helm upgrade -i geoparquet-exporter /tmp/pgstac-geoparquet-exporter/charts/pgstac-geoparquet-exporter \
  --namespace data-access \
  --values geoparquet-exporter/generated-values.yaml
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
- **openEO API:** `https://eoapi.${INGRESS_HOST}/openeo/`

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

!!! note
    There is a sample collection loaded in the previous step.

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

### 4. Collection-Level Access Control (IAM)

=== "Without IAM (default)"

    `stac-auth-proxy` is disabled entirely, so every collection/item is readable and writable by anyone who can reach the STAC API. There's nothing further to configure - skip to [Uninstallation](#uninstallation) if you're done validating.

=== "With IAM"

    `stac-auth-proxy` sits in front of the STAC API and decides access per-request using the collection ID:

    - **Public collections** — any collection ID with no `.` in it (e.g. `sentinel-2-iceland`) is readable by everyone, including unauthenticated requests. Reads are always public; only writes need auth.
    - **Private/owned collections** — an ID prefixed `<prefix>.` (e.g. `eoepcauser.mycollection`) is only readable/writable by:
        - the Keycloak user whose `preferred_username` matches `<prefix>`, or
        - a member of the Keycloak group `/dss/<prefix>` (read-write), or `/dss/<prefix>-ro` (read-only).
    - **Catalog-wide editors** — a token whose `azp` is one of `STAC_EDITOR_CLIENT_IDS` (the `eoapi` client, by default) and whose `resource_access.<azp>.roles` includes `stac_editor` can write to *any* collection, regardless of prefix. `iam/generated-iam.yaml` creates this role and a `data-access-admin` Keycloak group that grants it — add a user to that group (via the Keycloak admin console, or a Crossplane `Roles`/group-membership CR) to give them ingestion/admin rights across the whole catalogue.
      - This only works if the `eoapi` client's token actually carries a `resource_access` claim, which requires the built-in `roles` client scope to be assigned (`iam/generated-iam.yaml`'s `ClientDefaultScopes` includes it) — without it, group membership is granted in Keycloak but silently has no effect (every write still 403s with `"Resource does not match access filter"`, indistinguishable from the user simply not being in the group).

    This applies uniformly to both collections and items (an item's `collection` field is checked the same way).

    **Get a token to test with** (any realm user, using the `eoapi` client created by `iam/generated-iam.yaml`):

    ```bash
    source ~/.eoepca/state
    ACCESS_TOKEN=$( \
      curl -sk -X POST \
        -d "username=${KEYCLOAK_TEST_USER}" \
        --data-urlencode "password=${KEYCLOAK_TEST_PASSWORD}" \
        -d "grant_type=password" \
        -d "client_id=${EOAPI_CLIENT_ID}" \
        -d "scope=openid" \
        "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/token" \
      | jq -r '.access_token' \
    )
    ```

    **Unauthenticated write is rejected:**

    ```bash
    curl -sk -o /dev/null -w "%{http_code}\n" -X POST "https://eoapi.${INGRESS_HOST}/stac/collections" \
      -H "Content-Type: application/json" \
      -d '{"id": "unauth-test", "type": "Collection", "stac_version": "1.0.0", "description": "x", "license": "proprietary", "extent": {"spatial": {"bbox": [[-180,-90,180,90]]}, "temporal": {"interval": [[null,null]]}}, "links": []}'
    # 401
    ```

    **A user can write to their own username-prefixed collection:**

    ```bash
    curl -sk -o /dev/null -w "%{http_code}\n" -X POST "https://eoapi.${INGRESS_HOST}/stac/collections" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -d "{\"id\": \"${KEYCLOAK_TEST_USER}.mycollection\", \"type\": \"Collection\", \"stac_version\": \"1.0.0\", \"description\": \"x\", \"license\": \"proprietary\", \"extent\": {\"spatial\": {\"bbox\": [[-180,-90,180,90]]}, \"temporal\": {\"interval\": [[null,null]]}}, \"links\": []}"
    # 201
    ```

    **...but not to an unrelated collection they don't own and have no editor role for:**

    ```bash
    curl -sk -o /dev/null -w "%{http_code}\n" -X POST "https://eoapi.${INGRESS_HOST}/stac/collections" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -d '{"id": "someone-elses-collection", "type": "Collection", "stac_version": "1.0.0", "description": "x", "license": "proprietary", "extent": {"spatial": {"bbox": [[-180,-90,180,90]]}, "temporal": {"interval": [[null,null]]}}, "links": []}'
    # 403 {"code": "ForbiddenError", "description": "Resource does not match access filter."}
    ```

    **A private collection is invisible to unauthenticated requests, but visible to its owner:**

    ```bash
    curl -sk -o /dev/null -w "%{http_code}\n" "https://eoapi.${INGRESS_HOST}/stac/collections/${KEYCLOAK_TEST_USER}.mycollection"
    # 404 (filtered out, not "403" - its existence isn't revealed either)

    curl -sk "https://eoapi.${INGRESS_HOST}/stac/collections/${KEYCLOAK_TEST_USER}.mycollection" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq '{id, type}'
    ```

    Login to the STAC Browser and see your private collection available at:

    ```bash
    source ~/.eoepca/state
    xdg-open "${HTTP_SCHEME}://eoapi.${INGRESS_HOST}/browser/"
    ```

---

## Uninstallation

To uninstall the Data Access Building Block:
```bash
source ~/.eoepca/state

# The Crossplane IAM resources live in iam-management, not data-access, so
# they aren't removed by deleting the data-access namespace below.
if [ "${DATA_ACCESS_ENABLE_IAM:-no}" = "yes" ]; then
  kubectl delete -f iam/generated-iam.yaml --ignore-not-found
fi

helm uninstall eoapi -n data-access
helm uninstall stac-manager -n data-access
helm uninstall titiler-openeo -n data-access
if [ "${USE_EXTERNAL_POSTGRES}" != "yes" ]; then
  helm uninstall pgo -n data-access
fi
if [ "${ENABLE_GEOPARQUET_EXPORT:-no}" = "yes" ]; then
  helm uninstall geoparquet-exporter -n data-access
fi
helm uninstall eoapi-support -n data-access  # if monitoring was installed

kubectl delete namespace data-access
```

## Further Reading

- [EOEPCA+ Data Access GitHub Repository](https://github.com/EOEPCA/data-access)
- [eoAPI Documentation](https://github.com/developmentseed/eoAPI)
- [Zalando Postgres Operator Documentation](https://github.com/zalando/postgres-operator)
- [External Secrets Operator](https://external-secrets.io/)

