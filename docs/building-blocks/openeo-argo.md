# Processing - OpenEO ArgoWorkflows with Dask

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

### 4. Fix the Executor Image (Required)

The upstream executor image is missing a required library (`libexpat`). You need to build a patched version.

```bash
cat > /tmp/Dockerfile.executor-fix << 'EOF'
FROM ghcr.io/eodcgmbh/openeo-argoworkflows:executor-2025.5.1
USER root
RUN apt-get update && apt-get install -y libexpat1 && rm -rf /var/lib/apt/lists/*
EOF

docker build -t ghcr.io/eodcgmbh/openeo-argoworkflows:executor-2025.5.1-fixed -f /tmp/Dockerfile.executor-fix /tmp

# If using a private registry, push the image:
# docker push your-registry.com/openeo-argoworkflows:executor-2025.5.1-fixed
```

**Update the configuration to use the fixed image:**
```bash
sed -i 's|executor-2025.5.1|executor-2025.5.1-fixed|g' generated-values.yaml
```

### 5. Deploy OpenEO ArgoWorkflows
```bash
helm upgrade -i openeo charts/eodc/openeo-argo \
    --namespace openeo \
    --create-namespace \
    --values generated-values.yaml \
    --timeout 10m
```

### 6. Create Service Account Token

The deployment requires a service account token for Argo Workflows. Create it after the initial deployment:
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: openeo-argo-access-sa.service-account-token
  namespace: openeo
  annotations:
    kubernetes.io/service-account.name: openeo-argo-access-sa
type: kubernetes.io/service-account-token
EOF
```

Wait for all pods to be ready:
```bash
kubectl get pods -n openeo -w
```

### 7. Deploy Ingress
```bash
kubectl apply -f generated-ingress.yaml
```

### 8. Deploy Basic Auth Proxy (if OIDC disabled)

If you disabled OIDC authentication during configuration:
```bash
kubectl apply -f generated-proxy-auth.yaml
```

### 9. Configure OIDC Client (if using custom OIDC)

If you're using your own OIDC provider, create the client:
```bash
bash ../../utils/create-client.sh
```

When prompted:
- **Client ID**: Use `openeo-argo`
- **Redirect URLs**: Include `https://openeo.${INGRESS_HOST}` and `https://editor.openeo.org`

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

## Usage

### OpenEO Web Editor

Test the deployment using the OpenEO Web Editor:

1. Navigate to [https://editor.openeo.org](https://editor.openeo.org)
2. Enter your server URL: `https://openeo.${INGRESS_HOST}/openeo/1.1.0`
3. Authenticate with your OIDC provider or basic credentials
4. Explore collections and build processing graphs

### Python Client

**Setup:**
```bash
python3 -m venv venv
source venv/bin/activate
pip install openeo
```

**Connect and authenticate:**
```python
import openeo
import os

INGRESS_HOST = os.getenv("INGRESS_HOST", "example.com")
connection = openeo.connect(f"https://openeo.{INGRESS_HOST}/openeo/1.1.0")

# For OIDC authentication
connection.authenticate_oidc()

# For basic auth (if OIDC disabled)
# connection.authenticate_basic("eoepcauser", "eoepcapass")
```

**Submit a job:**
```python
# Load a collection
datacube = connection.load_collection(
    "SENTINEL2_L2A",
    spatial_extent={"west": 11.4, "south": 46.5, "east": 11.5, "north": 46.6},
    temporal_extent=["2024-06-01", "2024-06-30"],
    bands=["B04", "B08"]
)

# Calculate NDVI
red = datacube.band("B04")
nir = datacube.band("B08")
ndvi = (nir - red) / (nir + red)

# Submit as batch job
job = ndvi.create_job(title="NDVI Calculation")
job.start_and_wait()

# Download results
job.download_results("ndvi_results/")
```

### Direct API Usage

**Submit a batch job:**
```bash
# Get access token (adjust for your OIDC provider)
ACCESS_TOKEN=$(curl -s -X POST \
    "${OIDC_ISSUER_URL}/protocol/openid-connect/token" \
    -d "grant_type=password" \
    -d "username=${KEYCLOAK_TEST_USER}" \
    -d "password=${KEYCLOAK_TEST_PASSWORD}" \
    -d "client_id=${OPENEO_CLIENT_ID}" \
    -d "scope=openid" | jq -r '.access_token')

AUTH_TOKEN="oidc/eoepca/${ACCESS_TOKEN}"

# Create a job
curl -i -X POST "https://openeo.${INGRESS_HOST}/openeo/1.1.0/jobs" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "process": {
      "process_graph": {
        "load": {
          "process_id": "load_collection",
          "arguments": {
            "id": "SENTINEL2_L2A",
            "spatial_extent": {"west": 11.4, "south": 46.5, "east": 11.5, "north": 46.6},
            "temporal_extent": ["2024-06-01", "2024-06-10"]
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
  }'

JOB_ID=4262cf4c-bf73-401e-9c86-58a7c0670936

# Start the job
curl -X POST "https://openeo.${INGRESS_HOST}/openeo/1.1.0/jobs/${JOB_ID}/results" \
  -H "Authorization: Bearer ${AUTH_TOKEN}"

# Check job status
curl -s "https://openeo.${INGRESS_HOST}/openeo/1.1.0/jobs/${JOB_ID}" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" | jq '{id, status, title}'

# View results
kubectl exec -n openeo deployment/openeo-openeo-argo -c openeo-argo -- ls -la /user_workspaces/
kubectl exec -n openeo deployment/openeo-openeo-argo -c openeo-argo -- find /user_workspaces -name "*.tif" -o -name "*.json" 2>/dev/null
```

---

## Monitoring

**View all resources:**
```bash
kubectl get all -n openeo
```

**Check Argo Workflows:**
```bash
kubectl get workflows -n openeo
```

**View executor logs:**
```bash
kubectl logs -n openeo -l workflows.argoproj.io/workflow --tail=50
```

**View OpenEO API logs:**
```bash
kubectl logs -n openeo deploy/openeo-openeo-argo -c openeo-argo --tail=50
```

---

## Further Reading

- [OpenEO API Specification](https://openeo.org/documentation/1.0/)
- [Dask Documentation](https://docs.dask.org/)
- [Argo Workflows Documentation](https://argoproj.github.io/workflows/)
- [STAC Specification](https://stacspec.org/)
- [OpenEO Python Client](https://open-eo.github.io/openeo-python-client/)