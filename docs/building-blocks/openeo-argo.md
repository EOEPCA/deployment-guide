# Processing - OpenEO ArgoWorkflows with Dask

OpenEO ArgoWorkflows implements the OpenEO API specification using Argo Workflows to execute OpenEO process graphs and Dask for distributed processing. It's an alternative to the GeoTrellis backend, using Dask for the actual computation.

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
| OIDC Provider | Required (app-native OIDC) | [Installation Guide](./iam/main-iam.md) |
| STAC Catalogue | Optional - defaults to the public [Earth Search](https://earth-search.aws.element84.com/v1) catalogue; use your own for private/custom data | [eoAPI Deployment](./data-access.md) |

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

First time running a script? [EOEPCA+ State](../prerequisites/state.md) covers the shared setup questions asked before this one.

You'll be prompted for:

| Parameter | Description | Example |
|---|---|---|
| `SHARED_STORAGECLASS` | Kubernetes storage class for the shared job workspace (ReadWriteMany) | `standard` |
| `OIDC_ISSUER_URL` | OIDC provider URL | `https://auth.example.com/realms/eoepca` |
| `OIDC_ORGANISATION` | OIDC organisation identifier | `eoepca` |
| `OIDC_POLICIES` | OIDC policies (optional, leave empty for none) | |
| `STAC_CATALOG_ENDPOINT` | STAC catalog URL | `https://earth-search.aws.element84.com/v1` (default) or your own [eoAPI](./data-access.md) deployment |

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



The chart creates the API's Argo Workflows service-account token via a `post-upgrade` hook, which does **not** run on a first-ever install (Helm only fires `post-install` hooks then). If the `openeo-openeo-argo` pod is stuck in `CreateContainerConfigError` with `secret "openeo-argo-access-sa.service-account-token" not found`, re-run the exact same `helm upgrade` command above - the second run is a real upgrade, so the hook fires and the pod recovers.

### 5. Deploy Ingress
```bash
kubectl apply -f generated-ingress.yaml
```

### 6. Configure Authentication

A Keycloak client is required so the OpenEO API can validate tokens issued by your IAM deployment. `configure-openeo-argo.sh` already rendered `generated-iam.yaml` (a Crossplane `Client` CRD, a `ClientDefaultScopes` override, and two `ClientScope` resources) - this requires [Crossplane](./iam/main-iam.md) with its Keycloak provider installed and configured.

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

# The API redirects the bare version root to a trailing slash, so follow
# redirects with -L:
curl -s -L https://openeo-argo.${INGRESS_HOST}/openeo/1.1.0 | jq .
```

**List available processes:**
```bash
curl -s https://openeo-argo.${INGRESS_HOST}/openeo/1.1.0/processes | jq '[.processes[].id] | sort'
```

**Check Argo Workflows:**
```bash
kubectl get workflows -n openeo
```

---

### openEO Web Editor

The deployment can be tested using the openEO Web Editor as a client - either the publicly hosted instance, or your own self-hosted deployment.

=== "Public Instance"

    ```bash
    xdg-open "https://editor.openeo.org?server=https://openeo-argo.${INGRESS_HOST}/openeo/1.1.0/"
    ```

=== "Self-Hosted (Optional)"

    Deploy your own instance from `scripts/processing/openeo-web-editor`:

    ```bash
    cd ../openeo-web-editor
    bash configure-openeo-web-editor.sh

    helm repo add eoepca-dev-charts https://eoepca.github.io/helm-charts-dev/
    helm repo update eoepca-dev-charts
    helm upgrade -i openeo-web-editor eoepca-dev-charts/openeo-web-editor \
      --version 0.2.0 \
      --namespace openeo-web-editor \
      --create-namespace \
      --values generated-values.yaml
    ```

    Open it pre-connected to this deployment:

    ```bash
    source ~/.eoepca/state
    xdg-open "${HTTP_SCHEME}://${OPENEO_WEB_EDITOR_HOST}/?server=${HTTP_SCHEME}://openeo-argo.${INGRESS_HOST}/openeo/1.1.0/"
    ```

Select `EOEPCA` and log in via the IAM BB Keycloak instance.

---

### API Usage

> **Prefer a notebook?** Run `../../../notebooks/run.sh` and open the <a href="http://localhost:8888/lab/tree/openeo-argo/openeo-argo.ipynb" target="_blank">OpenEO ArgoWorkflows notebook</a> at `http://localhost:8888`.

**Submit and monitor a job:**
```bash
# Password grant against the openeo-argo client, using the test user from the IAM guide
ACCESS_TOKEN=$(curl -s -X POST \
    "${OIDC_ISSUER_URL}/protocol/openid-connect/token" \
    -d "grant_type=password" \
    -d "username=${KEYCLOAK_TEST_USER}" \
    -d "password=${KEYCLOAK_TEST_PASSWORD}" \
    -d "client_id=openeo-argo" \
    -d "scope=openid" | jq -r '.access_token')
AUTH_TOKEN="oidc/${OIDC_ORGANISATION}/${ACCESS_TOKEN}"

# Create a job - the ID isn't in the body, it comes back in the OpenEO-Identifier header
JOB_ID=$(curl -s -i -X POST "https://openeo-argo.${INGRESS_HOST}/openeo/1.1.0/jobs" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "process": {
      "process_graph": {
        "load": {
          "process_id": "load_collection",
          "arguments": {
            "id": "sentinel-2-l2a",
            "spatial_extent": {"west": 4.8, "south": 52.3, "east": 5.0, "north": 52.4},
            "temporal_extent": ["2023-06-01", "2023-06-30"],
            "bands": ["red", "nir"]
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

# A job sits in "created" status and does nothing until started
curl -s -X POST "https://openeo-argo.${INGRESS_HOST}/openeo/1.1.0/jobs/${JOB_ID}/results" \
  -H "Authorization: Bearer ${AUTH_TOKEN}"

# status moves through created -> running -> finished (or error)
curl -s "https://openeo-argo.${INGRESS_HOST}/openeo/1.1.0/jobs/${JOB_ID}" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" | jq '{id, status, title}'

curl -s "https://openeo-argo.${INGRESS_HOST}/openeo/1.1.0/jobs" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" | jq
```

!!! note
    This example works as-is against the default `STAC_CATALOG_ENDPOINT`. If you configured your own STAC catalogue instead, swap `id`, `spatial_extent` and `temporal_extent` for a collection and extent that catalogue actually has data for.

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
