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
   - **STAC Auth Proxy**: record-level access control for the STAC API

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
| STAC Auth Proxy          | For STAC access control        | Record-level read/write policies    |
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

- **`ENABLE_IAM`**: Enable IAM/Keycloak integration (yes/no)
    - If yes, you'll configure:
        - **`KEYCLOAK_HOST`**: Keycloak service hostname
        - **`REALM`**: Keycloak realm name
        - **`EOAPI_CLIENT_ID`**: Client ID for EOAPI
        - **`OPA_URL`**: OPA server URL for authorization

- **`ENABLE_TRANSACTIONS`**: Enable STAC transactions extension (yes/no)
- **`ENABLE_EOAPI_NOTIFIER`**: Enable CloudEvents notifier (yes/no)

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

> If using the external PostgreSQL option, skip this step.

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
  --version 0.7.12 \
  --namespace data-access \
  --values eoapi/generated-values.yaml
```

#### Deploy STAC Manager
```bash
helm repo add stac-manager https://stac-manager.ds.io/
helm repo update stac-manager
helm upgrade -i stac-manager stac-manager/stac-manager \
  --version 0.0.11 \
  --namespace data-access \
  --values stac-manager/generated-values.yaml
```

#### Deploy EOAPI Maps Plugin
```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev/
helm repo update eoepca-dev
helm upgrade -i eoapi-maps-plugin eoepca-dev/eoapi-maps-plugin \
  --version 0.0.21 \
  --namespace data-access \
  --values eoapi-maps-plugin/generated-values.yaml
```

#### Configure Ingress/Routes

If IAM is enabled then we need to configure Keycloak with a Client and associated Roles/Groups.

If APISIX is the configured ingress controller, then apply the dedicated `ApisixRoute`.

```bash
source ~/.eoepca/state
if [ "${DATA_ACCESS_ENABLE_IAM}" = "yes" ]; then
  kubectl apply -f iam/generated-iam.yaml
fi
if [ "${INGRESS_CLASS}" = "apisix" ]; then
  kubectl apply -f eoapi/generated-ingress.yaml
fi
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

## STAC API Access Control (STAC Auth Proxy)

In addition to — or in place of — the ingress-level OPA authorization described above,
the STAC API can be protected with
[STAC Auth Proxy](https://github.com/developmentseed/stac-auth-proxy). The two operate
at different layers: OPA gates all APIs at the ingress, while STAC Auth Proxy enforces
record-level read/write policies for the STAC API only, by validating Keycloak OIDC
tokens and injecting CQL2 filters into every request. This is the approach used in the
EOEPCA+ demo cluster.

In brief, access is governed by a collection ID naming convention:

| Collection ID pattern | Read | Write |
| --- | --- | --- |
| No prefix (no `.` in the ID) | Everyone | `stac_editor` role only |
| `<username>.<collection>` | That user | That user |
| `<group>.<collection>` | Group members (incl. `-ro`) | Group members |

This is a simplified view — the full policy model, including the `-ro` (read-only) and
`-mgr` group-suffix rules and the default-deny behavior, is documented in the
[Resource Discovery BB — Access Control](https://eoepca.readthedocs.io/projects/resource-discovery/en/latest/design/data-catalogue/auth/)
page.

> **Note:** `configure-data-access.sh` does not yet template these values — the steps
> below are applied manually on top of the generated eoAPI values.

> **Important:** Once the proxy is active, anonymous writes are rejected. If you intend
> to load the [sample collection](#load-sample-collection), do so **before** enabling
> the proxy, or supply an authorized token to the ingest.

#### 1. Enable the proxy in the eoAPI Helm values

The `eoapi` Helm chart bundles STAC Auth Proxy as an optional subchart. Add to
`eoapi/generated-values.yaml`:

```yaml
stac-auth-proxy:
  enabled: true
  image:
    tag: "v1.1.0"
  env:
    UPSTREAM_URL: "http://eoapi-stac.data-access.svc.cluster.local:8080"
    OIDC_DISCOVERY_URL: "https://${KEYCLOAK_HOST}/realms/${REALM}/.well-known/openid-configuration"
    ALLOWED_JWT_AUDIENCES: "eoapi"
    ROOT_PATH: "/stac"
    COLLECTIONS_FILTER_CLS: stac_auth_proxy.eoepca_filters:CollectionsFilter
    ITEMS_FILTER_CLS: stac_auth_proxy.eoepca_filters:ItemsFilter
    STAC_EDITOR_CLIENT_IDS: "eoapi,registration-harvester"
    STAC_EDITOR_ROLE: "stac_editor"
```

#### 2. Mount the policy filter factories

The policies are implemented as
[filter factories](https://developmentseed.org/stac-auth-proxy/user-guide/record-level-auth/#filter-contract)
in a single Python file, delivered via ConfigMap — so policy changes need no image
rebuild, only a ConfigMap update and a proxy pod restart.

```bash
curl -LO https://raw.githubusercontent.com/EOEPCA/eoepca-plus/deploy-develop/argocd/eoepca/data-access/parts/stac-auth-proxy/eoepca_filters.py
kubectl create configmap stac-auth-proxy-filters \
  --from-file=eoepca_filters.py \
  --namespace data-access
```

And in the values, mount it into the proxy container:

```yaml
stac-auth-proxy:
  extraVolumes:
    - name: filters
      configMap:
        name: stac-auth-proxy-filters
  extraVolumeMounts:
    - name: filters
      mountPath: /app/src/stac_auth_proxy/eoepca_filters.py
      subPath: eoepca_filters.py
      readOnly: true
```

Re-run the `helm upgrade -i eoapi ...` command from the deployment steps to apply.

#### 3. Configure Keycloak

In the `${REALM}` realm:

1. Ensure the `eoapi` client exists and its audience appears in tokens
   (`ALLOWED_JWT_AUDIENCES` must match).
2. Create a `stac_editor` **client role** on each client listed in
   `STAC_EDITOR_CLIENT_IDS`, and assign it to the service accounts that need
   catalog-wide write access (e.g. the Registration Harvester). Only grant this on
   confidential clients — the role bypasses all collection-prefix checks.
3. For group-based access, ensure a `groups` claim mapper is configured so group
   memberships appear in access tokens. Group names must follow `/dss/<group-id>`,
   with `<group-id>` containing `-dss-` — see the Resource Discovery page above for
   the `-ro` and `-mgr` suffix semantics.

#### 4. Route ingress through the proxy

Point the STAC ingress path (`/stac`) at the `stac-auth-proxy` service instead of
`eoapi-stac`, so no request reaches the STAC API unfiltered. Raster/vector/multidim
routes are unaffected.

#### 5. Validate

```bash
source ~/.eoepca/state

# Anonymous: returns only public (unprefixed) collections
curl -s "https://eoapi.${INGRESS_HOST}/stac/collections" | jq -r '.collections[].id'

# Anonymous write: rejected
curl -s -o /dev/null -w "%{http_code}\n" \
  -X POST "https://eoapi.${INGRESS_HOST}/stac/collections" \
  -H "Content-Type: application/json" -d '{"id": "should-fail"}'

# Authenticated: additionally returns <username>.* and group-prefixed collections
TOKEN=$(curl -s "https://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/token" \
  -d "grant_type=password" -d "client_id=eoapi" \
  -d "username=<user>" -d "password=<password>" | jq -r .access_token)
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "https://eoapi.${INGRESS_HOST}/stac/collections" | jq -r '.collections[].id'
```

Because read responses depend on identity, clients should send their token on **all**
STAC requests, not only writes — current STAC Manager releases do this automatically.

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
- [STAC Auth Proxy Documentation](https://developmentseed.org/stac-auth-proxy/)
- [Resource Discovery BB — Access Control](https://eoepca.readthedocs.io/projects/resource-discovery/en/latest/design/data-catalogue/auth/)
- [Zalando Postgres Operator Documentation](https://github.com/zalando/postgres-operator)
- [External Secrets Operator](https://external-secrets.io/)

