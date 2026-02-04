# Processing - OpenEO ArgoWorkflows with Dask

> **Note**: This Building Block is under active development. Some features may still be evolving, so we recommend using it with consideration as updates are rolled out.

OpenEO ArgoWorkflows provides a Kubernetes-native implementation of the OpenEO API specification using Dask for distributed processing. This deployment offers an alternative to the GeoTrellis backend, leveraging Dask's parallel computing capabilities for Earth observation data processing.

> **Note:** OIDC authentication is configured by default for OpenEO ArgoWorkflows. The deployment integrates with external OIDC providers (e.g., EGI AAI) for authentication. Refer to the [IAM Deployment Guide](./iam/main-iam.md) if you need to set up your own OIDC Provider.

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
| OIDC Provider | Required for authentication | [Installation Guide](./iam/main-iam.md) |
| STAC Catalogue | Required for data access | [eoAPI Deployment](./data-access/eoapi.md) |

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
| `PERSISTENT_STORAGECLASS` | Kubernetes storage class for persistent volumes | `standard` |
| `CLUSTER_ISSUER` | Cert-manager Cluster Issuer for TLS certificates | `letsencrypt-prod` |
| `OPENEO_ARGO_ENABLE_OIDC` | Enable OIDC authentication (yes/no) | `yes` |
| `OIDC_ISSUER_URL` | OIDC provider URL (if OIDC enabled) | `https://auth.example.com/realms/eoepca` |
| `OIDC_ORGANISATION` | OIDC organisation identifier (if OIDC enabled) | `eoepca` |
| `STAC_CATALOG_ENDPOINT` | STAC catalog URL | `https://eoapi.example.com/stac` |

### 2. Add Helm Repositories
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add dask https://helm.dask.org
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### 3. Prepare the Helm Chart

Clone the charts repository and build dependencies:
```bash
git clone https://github.com/jzvolensky/charts
helm dependency update charts/eodc/openeo-argo
helm dependency build charts/eodc/openeo-argo
```

### 4. Deploy OpenEO ArgoWorkflows
```bash
helm upgrade -i openeo charts/eodc/openeo-argo \
    --namespace openeo \
    --create-namespace \
    --values generated-values.yaml \
    --timeout 10m
```

### 5. Deploy Ingress
```bash
kubectl apply -f generated-ingress.yaml
```

### 6. Deploy Basic Auth Proxy (if OIDC disabled)

If you disabled OIDC authentication during configuration:
```bash
kubectl apply -f generated-proxy-auth.yaml
```

### 7. Configure OIDC Client (if using custom OIDC)

A Keycloak client is required for the ingress protection of the Processing BB openEO Argo Engine. The client can be created using the Crossplane Keycloak provider via the `Client` CRD.

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: openeo-argo
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    clientId: openeo-argo
    name: openEO Argo Engine
    description: openEO Argo Engine OIDC
    enabled: true
    accessType: PUBLIC
    rootUrl: ${HTTP_SCHEME}://openeo.${INGRESS_HOST}
    baseUrl: ${HTTP_SCHEME}://openeo.${INGRESS_HOST}
    adminUrl: ${HTTP_SCHEME}://openeo.${INGRESS_HOST}
    directAccessGrantsEnabled: true
    standardFlowEnabled: true
    oauth2DeviceAuthorizationGrantEnabled: true
    useRefreshTokens: true
    validRedirectUris:
      - "/*"
      - "https://editor.openeo.org/*"
    webOrigins:
      - "+"
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

The `Client` should be created successfully.

Then remove the role
Clients → openeo-public → Client scopes tab
Remove roles or other scopes from "Assigned default client scopes" if they're adding the audience

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

# Without authentication (basic info only)
curl -s https://openeo.${INGRESS_HOST}/openeo/1.1.0 | jq .

# With basic auth (if OIDC disabled)
curl -s -u eoepcauser:eoepcapass https://openeo.${INGRESS_HOST}/openeo/1.1.0 | jq .
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
AUTH_TOKEN="oidc/eoepca/${ACCESS_TOKEN}"

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

> **Note:** The STAC catalogue must contain collections with data formatted for OpenEO processing. Check the available collections at your STAC endpoint and ensure the spatial/temporal extent matches actual data.


---

## Further Reading

- [OpenEO API Specification](https://openeo.org/documentation/1.0/)
- [Dask Documentation](https://docs.dask.org/)
- [Argo Workflows Documentation](https://argoproj.github.io/workflows/)
- [STAC Specification](https://stacspec.org/)
- [OpenEO Python Client](https://open-eo.github.io/openeo-python-client/)