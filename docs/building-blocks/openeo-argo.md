# Processing - OpenEO ArgoWorkflows with Dask

!!! warning "Active Development"
    This Building Block is under active development. Some features may still be evolving, so we recommend using it with consideration as updates are rolled out.

OpenEO ArgoWorkflows provides a Kubernetes-native implementation of the OpenEO API specification, using Argo Workflows to execute OpenEO process graphs and Dask for distributed processing. This deployment offers an alternative to the GeoTrellis backend, leveraging Dask's parallel computing capabilities for Earth observation data processing.

!!! note
    OIDC authentication is app-native - the API itself validates tokens against the configured identity provider's discovery endpoint, so it works the same way under either `apisix` or `nginx` ingress. Refer to the [IAM Deployment Guide](./iam/main-iam.md) if you need to set up your own OIDC Provider (e.g. Keycloak). If OIDC is disabled, a basic-auth proxy is deployed instead - for testing only.

---

## Prerequisites

Before deploying, ensure your environment meets these requirements:

| Component | Requirement | Documentation Link |
|---|---|---|
| Kubernetes | Cluster (tested on v1.28+) | [Installation Guide](../prerequisites/kubernetes.md) |
| Helm | Version 3.5 or newer | [Installation Guide](https://helm.sh/docs/intro/install/) |
| kubectl | Configured for cluster access | [Installation Guide](https://kubernetes.io/docs/tasks/tools/) |
| Ingress | Properly installed | [Installation Guide](../prerequisites/ingress/overview.md) |
| Cert Manager | Properly installed | [Installation Guide](../prerequisites/tls.md) |
| `ReadWriteMany` Storage Class | Required for the shared job workspace | [Storage Guide](../prerequisites/storage.md) |
| OIDC Provider | Optional (app-native OIDC, if enabling authentication) | [Installation Guide](./iam/main-iam.md) |
| STAC Catalogue | Required for data access | [eoAPI Deployment](./data-access.md) |

The API, executor, and Dask worker pods all mount the same job workspace volume concurrently, so the storage class used for it (`SHARED_STORAGECLASS` below) **must** support `ReadWriteMany`.

!!! warning
    This chart bundles Argo Workflows (CRDs + controller) as a dependency. If another Building Block on the cluster also installs the same cluster-scoped `*.argoproj.io` CRDs under a different Helm release (e.g. OGC API Processing's `zoo-project-dru`), `helm upgrade -i` below will fail with a CRD-ownership error - only one release can own them.

**Clone the Deployment Guide Repository:**
```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/processing/openeo-argo
```

**Validate your environment:**
```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script
```bash
bash configure-openeo-argo.sh
```

You'll be prompted for:

| Parameter | Description | Example |
|---|---|---|
| `INGRESS_HOST` | Base domain for ingress hosts | `example.com` |
| `PERSISTENT_STORAGECLASS` | Kubernetes storage class for PostgreSQL/Redis (ReadWriteOnce) | `standard` |
| `SHARED_STORAGECLASS` | Kubernetes storage class for the shared job workspace (ReadWriteMany) | `standard` |
| `CLUSTER_ISSUER` | Cert-manager Cluster Issuer for TLS certificates | `letsencrypt-prod` |
| `OPENEO_ARGO_ENABLE_OIDC` | Enable OIDC authentication (yes/no) | `yes` |
| `OIDC_ISSUER_URL` | OIDC provider URL (if OIDC enabled) | `https://auth.example.com/realms/eoepca` |
| `OIDC_ORGANISATION` | OIDC organisation identifier (if OIDC enabled) | `eoepca` |
| `OIDC_POLICIES` | OIDC policies (if OIDC enabled, optional, leave empty for none) | |
| `STAC_CATALOG_ENDPOINT` | STAC catalog URL | `https://eoapi.example.com/stac` |

### 2. Add Helm Repositories

The chart and its dependencies are all published to public Helm repositories:
```bash
helm repo add eodc https://eodcgmbh.github.io/charts/
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add dask https://helm.dask.org
helm repo update
```

### 3. Apply Secrets

The chart expects a pre-existing Secret holding the PostgreSQL admin password (it will not generate one itself):
```bash
bash apply-secrets.sh
```

### 4. Deploy OpenEO ArgoWorkflows

This installs the API/worker deployment along with its bundled PostgreSQL, Redis, Argo Workflows, and Dask Gateway dependencies into the `openeo` namespace:
```bash
helm upgrade -i openeo eodc/openeo-argo \
    --version 2026.7.1 \
    --namespace openeo \
    --create-namespace \
    --values generated-values.yaml \
    --dependency-update \
    --timeout 10m
```

!!! tip
    Check for a newer chart release with `helm search repo eodc/openeo-argo -l` - pin whichever version you've actually tested against.

The chart creates the API's Argo Workflows service-account token via a `post-upgrade` hook, which does **not** run on a first-ever install (Helm only fires `post-install` hooks then). If the `openeo-openeo-argo` pod is stuck in `CreateContainerConfigError` with `secret "openeo-argo-access-sa.service-account-token" not found`, re-run the exact same `helm upgrade` command above - the second run is a real upgrade, so the hook fires and the pod recovers.

### 5. Deploy Ingress
```bash
kubectl apply -f generated-ingress.yaml
```

### 6. Configure Authentication

=== "OIDC Disabled"

    Deploy the basic-auth proxy:

    ```bash
    kubectl apply -f generated-proxy-auth.yaml
    ```

=== "OIDC Enabled"

    A Keycloak client is required so the OpenEO API can validate tokens issued by your IAM deployment. `configure-openeo-argo.sh` already rendered `generated-iam.yaml` (a Crossplane `Client` CRD, plus a `ClientDefaultScopes` override) when OIDC was enabled - this requires [Crossplane](./iam/main-iam.md) with its Keycloak provider installed and configured.

    ```bash
    kubectl apply -f generated-iam.yaml
    kubectl wait --for=condition=Ready client.openidclient.keycloak.m.crossplane.io/openeo-argo -n iam-management --timeout=60s
    ```

---

## Validation

### Automated Validation
```bash
bash validation.sh
```

This verifies:
- All pods in the `openeo` namespace are running
- PostgreSQL and Redis are operational
- API endpoints return valid responses

### Manual Validation

**Check pod status:**
```bash
kubectl get pods -n openeo
```

**API Health Check:**
```bash
source ~/.eoepca/state

# If OIDC is enabled, the ingress routes straight to the API. The API redirects
# the bare version root to a trailing slash, so follow redirects with -L:
curl -s -L https://openeo.${INGRESS_HOST}/openeo/1.1.0 | jq .

# If OIDC is disabled, the ingress routes to the basic-auth proxy instead, which
# itself prepends /openeo/1.1.0 to whatever path you request - so call the bare root:
curl -s -u eoepcauser:eoepcapass https://openeo.${INGRESS_HOST}/ | jq .
```

**List available processes:**
```bash
curl -s https://openeo.${INGRESS_HOST}/openeo/1.1.0/processes | jq '[.processes[].id] | sort'
```

**Check Argo Workflows:**
```bash
kubectl get workflows -n openeo
```

---

### API Usage

!!! note
    The example below assumes OIDC is enabled. If you disabled OIDC, drop the `ACCESS_TOKEN`/`AUTH_TOKEN` lines and replace `-H "Authorization: Bearer ${AUTH_TOKEN}"` in each command with `-u eoepcauser:eoepcapass` (see the basic-auth example in [API Health Check](#manual-validation) above).

**Submit and monitor a job:**
```bash
# Get access token
ACCESS_TOKEN=$(curl -s -X POST \
    "${OIDC_ISSUER_URL}/protocol/openid-connect/token" \
    -d "grant_type=password" \
    -d "username=${KEYCLOAK_TEST_USER}" \
    -d "password=${KEYCLOAK_TEST_PASSWORD}" \
    -d "client_id=openeo-argo" \
    -d "scope=openid" | jq -r '.access_token')
AUTH_TOKEN="oidc/${OIDC_ORGANISATION}/${ACCESS_TOKEN}"

# Create a job
JOB_ID=$(curl -s -i -X POST "https://openeo.${INGRESS_HOST}/openeo/1.1.0/jobs" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "process": {
      "process_graph": {
        "load": {
          "process_id": "load_collection",
          "arguments": {
            "id": "your-collection-id",
            "spatial_extent": {"west": -34.0, "south": 38.8, "east": -33.0, "north": 39.5},
            "temporal_extent": ["2025-10-20", "2025-10-31"]
          }
        },
        "save": {
          "process_id": "save_result",
          "arguments": {
            "data": {"from_node": "load"},
            "format": "GTiff"
          },
          "result": true
        }
      }
    },
    "title": "Test Job"
  }' | grep -i "^openeo-identifier:" | cut -d' ' -f2 | tr -d '\r\n')

echo "Created job: ${JOB_ID}"

# Start the job
curl -s -X POST "https://openeo.${INGRESS_HOST}/openeo/1.1.0/jobs/${JOB_ID}/results" \
  -H "Authorization: Bearer ${AUTH_TOKEN}"

# Check status
curl -s "https://openeo.${INGRESS_HOST}/openeo/1.1.0/jobs/${JOB_ID}" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" | jq '{id, status, title}'

# List all jobs
curl -s "https://openeo.${INGRESS_HOST}/openeo/1.1.0/jobs" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" | jq
```

!!! note
    The STAC catalogue must contain collections with data formatted for OpenEO processing. Check the available collections at your STAC endpoint and ensure the spatial/temporal extent matches actual data.

---

## Advanced Configuration

The chart also supports (all optional, left unconfigured by this guide):

- **Basic-auth protected STAC catalogues** - `global.env.stacApiSecret` references an existing Secret with `username`/`secret` keys.
- **S3/Icechunk output storage and EODAG DESP access for the executor** - `global.env.executorSecret` references an existing Secret with AWS and EODAG credentials, and `global.env.awsEndpointUrl`/`eodagDedlPriority`/`icechunkS3*` control the connection. See the [chart README](https://github.com/eodcgmbh/charts/tree/main/eodc/openeo-argo) for the full parameter list.

---

## Uninstallation

To uninstall the OpenEO ArgoWorkflows deployment:

```bash
kubectl delete -f generated-ingress.yaml --ignore-not-found
kubectl delete -f generated-iam.yaml --ignore-not-found

helm uninstall openeo -n openeo

kubectl delete namespace openeo
```

---

## Further Reading

- [OpenEO API Specification](https://openeo.org/documentation/1.0/)
- [Dask Documentation](https://docs.dask.org/)
- [Argo Workflows Documentation](https://argoproj.github.io/workflows/)
- [STAC Specification](https://stacspec.org/)
- [OpenEO Python Client](https://open-eo.github.io/openeo-python-client/)
