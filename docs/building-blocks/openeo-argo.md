# Processing - OpenEO ArgoWorkflows with Dask

OpenEO ArgoWorkflows provides a Kubernetes-native implementation of the OpenEO API specification using Dask for distributed processing. This deployment offers an alternative to the GeoTrellis backend, leveraging Dask's parallel computing capabilities for Earth observation data processing.

> **Note:** OIDC authentication is configured by default for OpenEO ArgoWorkflows. The deployment integrates with external OIDC providers (e.g., EGI AAI) for authentication. Refer to the [IAM Deployment Guide](./iam/main-iam.md) if you need to set up your own OIDC Provider.

---

## Prerequisites

Before deploying, ensure your environment meets these requirements:

|Component|Requirement|Documentation Link|
|---|---|---|
|Kubernetes|Cluster (tested on v1.28)|[Installation Guide](../prerequisites/kubernetes.md)|
|Helm|Version 3.5 or newer|[Installation Guide](https://helm.sh/docs/intro/install/)|
|kubectl|Configured for cluster access|[Installation Guide](https://kubernetes.io/docs/tasks/tools/)|
|Ingress|Properly installed|[Installation Guide](../prerequisites/ingress/overview.md)|
|Cert Manager|Properly installed|[Installation Guide](../prerequisites/tls.md)|
|OIDC Provider|Required for authentication|[Installation Guide](./iam/main-iam.md)|

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

- **`INGRESS_HOST`**: Base domain for ingress hosts (e.g. `example.com`)
- **`PERSISTENT_STORAGECLASS`**: Kubernetes storage class for persistent volumes
- **`CLUSTER_ISSUER`**: Cert-manager Cluster Issuer for TLS certificates
- **`STAC_CATALOG_URL`**: STAC catalog endpoint (e.g. `${HTTP_SCHEME}://eoapi.${INGRESS_HOST}/stac`)
- **`OIDC_ISSUER_URL`**: OIDC provider URL (e.g. `https://aai.egi.eu/auth/realms/egi`)
- **`OIDC_ORGANISATION`**: OIDC organisation identifier (e.g. `egi`)

### 2. Deploy OpenEO ArgoWorkflows

The deployment consists of the core API service with PostgreSQL and Redis as supporting services.

```bash
# Add the required Helm repositories
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add dask https://helm.dask.org
helm repo update

# Add the git-based Helm repository
git clone https://github.com/jzvolensky/charts

# Deploy OpenEO ArgoWorkflows
helm dependency update charts/eodc/openeo-argo
helm dependency build charts/eodc/openeo-argo


helm upgrade -i openeo charts/eodc/openeo-argo \
    --namespace openeo \
    --create-namespace \
    --values generated-values.yaml \
    --wait --timeout 10m


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

#### Step 3: Deploy Ingress

Apply the ingress configuration:
```bash
kubectl apply -f generated-ingress.yaml
```

#### Step 4: Configure OIDC Client (if using custom OIDC)

If you're using your own OIDC provider rather than EGI AAI, create the client:
```bash
bash ../../utils/create-client.sh
```

When prompted:
- **Client ID**: Use `openeo-argo` 
- **Redirect URLs**: Include `https://openeo.${INGRESS_HOST}` and `https://editor.openeo.org`

---

## Validation

### 1. Automated Validation
```bash
bash validation.sh
```

This verifies:
- All pods in the `openeo` namespace are running
- PostgreSQL and Redis are operational
- API endpoints return valid responses
- Dask executor image is accessible

### 2. API Health Check
```bash
source ~/.eoepca/state
curl -L https://openeo.${INGRESS_HOST}/ | jq .
```

Expected output: API metadata including version, endpoints, and backend capabilities.

### 3. Service Discovery
```bash
# List available collections
curl -L https://openeo.${INGRESS_HOST}/collections | jq .

# List available processes
curl -L https://openeo.${INGRESS_HOST}/processes | jq .
```

---

## Usage

### OpenEO Web Editor

Test the deployment using the OpenEO Web Editor:
```bash
xdg-open https://editor.openeo.org?server=https://openeo.${INGRESS_HOST}
```

**Login Process:**
1. Select your OIDC provider (e.g., `EGI` or `EOEPCA`)
2. Authenticate with your credentials
3. Upon successful login, explore collections and build processing graphs

### Python Client Usage

#### Setup
```bash
python3 -m venv venv
source venv/bin/activate
pip install openeo
```

#### Connect and Authenticate
```python
import openeo
import os

# Connect to the service
connection = openeo.connect("https://openeo.${INGRESS_HOST}")

# Authenticate via OIDC
connection.authenticate_oidc()
```

#### Submit a Dask-Powered Job
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
job = ndvi.create_job(title="NDVI Calculation with Dask")
job.start_and_wait()

# Download results
job.download_results("ndvi_results/")
```

#### Monitor Dask Cluster

The Dask cluster automatically scales based on workload. Monitor active workers:
```python
# Get job details including Dask cluster information
job_info = job.describe()
print(f"Job status: {job_info['status']}")
print(f"Dask workers: {job_info.get('usage', {}).get('dask_workers', 'N/A')}")
```

### Direct API Usage

#### Submit a Synchronous Processing Request
```bash
# Get access token (adjust for your OIDC provider)
ACCESS_TOKEN=$(curl -s -X POST \
    "${OIDC_ISSUER_URL}/protocol/openid-connect/token" \
    -d "grant_type=password" \
    -d "username=${OIDC_USERNAME}" \
    -d "password=${OIDC_PASSWORD}" \
    -d "client_id=${OIDC_CLIENT_ID}" \
    -d "scope=openid" | jq -r '.access_token')

# Submit processing request
curl -X POST "https://openeo.${INGRESS_HOST}/result" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "process": {
      "process_graph": {
        "load": {
          "process_id": "load_collection",
          "arguments": {
            "id": "SENTINEL2_L2A",
            "spatial_extent": {
              "west": 11.4, "south": 46.5,
              "east": 11.5, "north": 46.6
            },
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
    }
  }'
```

---

## Architecture Overview

OpenEO ArgoWorkflows uses a different architecture compared to GeoTrellis:

**Core Components:**
- **API Service**: Handles OpenEO requests and orchestrates processing
- **PostgreSQL**: Stores job metadata, user data, and process graphs
- **Redis**: Manages job queues and caching
- **Dask**: Executes distributed processing tasks

**Processing Flow:**
1. User submits process graph via API
2. API validates and stores job in PostgreSQL
3. Job queued in Redis for execution
4. Dask cluster spawns workers as needed
5. Workers process data from STAC catalog
6. Results stored and made available to user

**Key Advantages:**
- Dynamic scaling with Dask
- Python-native processing environment
- Direct STAC catalog integration
- Simplified dependency management

---

## Troubleshooting

### Common Issues

**PostgreSQL Connection Errors:**
```bash
# Check PostgreSQL pod
kubectl logs -n openeo deployment/openeo-argoworkflows-postgresql

# Verify credentials
kubectl get secret -n openeo openeo-argoworkflows-postgresql \
  -o jsonpath='{.data.postgres-password}' | base64 -d
```

**Dask Worker Failures:**
```bash
# Check executor logs
kubectl logs -n openeo -l component=dask-worker

# Verify resource limits
kubectl describe pod -n openeo -l component=dask-worker
```

**STAC Catalog Connectivity:**
```bash
# Test from within cluster
kubectl run test-curl --rm -it --image=curlimages/curl -- \
  curl -L ${STAC_CATALOG_URL}
```

### Performance Tuning

Adjust Dask worker configuration in `generated-values.yaml`:
```yaml
global:
  env:
    daskWorkerCores: "8"     # Increase for CPU-intensive tasks
    daskWorkerMemory: "16"   # Increase for memory-intensive operations
    daskWorkerLimit: "10"    # Increase for larger parallel workloads
```

Apply changes:
```bash
helm upgrade openeo-argoworkflows eodc/openeo-argo \
  --namespace openeo \
  --values generated-values.yaml
```

---

## Further Reading

- [OpenEO API Specification](https://openeo.org/documentation/1.0/)
- [Dask Documentation](https://docs.dask.org/)
- [STAC Specification](https://stacspec.org/)
- [OpenEO Python Client](https://open-eo.github.io/openeo-python-client/)