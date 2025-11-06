# Processing - OpenEO Engine Deployment Guide

OpenEO develops an API that allows users to connect to Earth observation cloud back-ends in a simple and unified way. The project maintains the API and process specifications, and an open-source ecosystem with clients and server implementations.

> **Note:** OIDC authentication is now optional for OpenEO deployments. If you choose to enable OIDC during configuration, you'll need a valid OIDC Provider. Refer to the [IAM Deployment Guide](./iam/main-iam.md) if you need to set one up.

---

## Prerequisites

Before deploying, ensure your environment meets the following requirements:

|Component|Requirement|Documentation Link|
|---|---|---|
|Kubernetes|Cluster (tested on v1.28)|[Installation Guide](../prerequisites/kubernetes.md)|
|Helm|Version 3.5 or newer|[Installation Guide](https://helm.sh/docs/intro/install/)|
|kubectl|Configured for cluster access|[Installation Guide](https://kubernetes.io/docs/tasks/tools/)|
|Ingress|Properly installed|[Installation Guide](../prerequisites/ingress/overview.md)|
|Cert Manager|Properly installed|[Installation Guide](../prerequisites/tls.md)|
|OIDC Provider|Optional (if enabling OIDC)|[Installation Guide](./iam/main-iam.md)|

**Clone the Deployment Guide Repository:**

```
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/processing/openeo
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script

```bash
bash configure-openeo.sh
```

During this process, you'll be prompted for:

- **`OPENEO_BACKEND`**: Which backend to deploy - currently only `geotrellis` is fully supported (Dask backend is still under development, so don't select it yet)
- **`INGRESS_HOST`**: Base domain for ingress hosts (e.g. `example.com`)
- **`PERSISTENT_STORAGECLASS`**: Kubernetes storage class for persistent volumes
- **`CLUSTER_ISSUER`**: Cert-manager Cluster Issuer for TLS certificates
- **`OPENEO_ENABLE_OIDC`**: Whether to enable OIDC authentication (yes/no)
- **`OPENEO_CLIENT_ID`**: Client ID for OpenEO clients (only if OIDC is enabled)

> **Note on Authentication:** The configuration script now offers a choice between OIDC authentication and basic authentication. If you choose not to enable OIDC, the deployment will use basic authentication instead.

### 2. Deploying openEO Geotrellis

openEO Geotrellis provides the API that connects users to EO cloud back-ends. It leverages Apache Spark and requires both the Spark Operator and ZooKeeper to function.

#### Step 1: Install Spark Operator

Deploy the Kubeflow Spark Operator to manage Spark jobs within your Kubernetes cluster:

```bash
helm upgrade -i openeo-geotrellis-sparkoperator spark-operator \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 2.0.2 \
    --namespace openeo-geotrellis \
    --create-namespace \
    --values sparkoperator/generated-values.yaml
```

Refer to the [values.yaml](https://github.com/kubeflow/spark-operator/blob/master/charts/spark-operator-chart/values.yaml) for additional configuration options.

#### Step 2: Install ZooKeeper

Deploy Apache ZooKeeper, which is required for internal coordination:

```bash
helm upgrade -i openeo-geotrellis-zookeeper \
    https://artifactory.vgt.vito.be/artifactory/helm-charts/zookeeper-11.1.6.tgz \
    --namespace openeo-geotrellis \
    --values zookeeper/generated-values.yaml \
    --set image.registry=docker.io \
    --set image.repository=bitnamilegacy/zookeeper \
    --set image.tag=3.8.1-debian-11-r18 \
    --wait --timeout 5m
```

For full configuration details, see the [values.yaml](https://github.com/bitnami/charts/blob/main/bitnami/zookeeper/values.yaml).

#### Step 3: Deploy openEO Geotrellis Using Helm

> You must wait for the ZooKeeper deployment to be fully running before deploying openEO Geotrellis. This is because it relies on the webhook.

Provides an API that simplifies connecting to EO cloud back-ends, running on Apache Spark in a Kubernetes environment.

```bash
helm upgrade -i openeo-geotrellis-openeo sparkapplication \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 1.0.2 \
    --namespace openeo-geotrellis \
    --create-namespace \
    --values openeo-geotrellis/generated-values.yaml
```

Deploy ingress:

```
kubectl apply -f openeo-geotrellis/generated-ingress.yaml
```

#### Step 4: Create a Keycloak Client (Only if OIDC is enabled)

> **Note:** This step is only required if you enabled OIDC authentication during the configuration step. If you chose basic authentication, skip to the Validation section.

The openEO API provides an endpoint for service discovery, which allows openEO clients to integrate with each openEO instance. This includes auth discovery that provides details of supported identity providers.

For OIDC identity providers, details of an OIDC client are provided through this discovery interface. This is assumed to be a public OIDC client for use with OIDC PKCE flows (Authorization/Device Code). This allows the openEO client to dynamically integrate with the authentication approach offered by the openEO instance - without the need to register their own OIDC client.

Thus, if OIDC is enabled, we configure in our openEO deployment integration with an `EOEPCA` identity provider.

Inside the `generated-values.yaml` (when OIDC is enabled) you'll find the following configuration:

```python
oidc_providers = [
  OidcProvider(
    id="eoepca",
    title="EOEPCA",
    issuer="${OIDC_ISSUER_URL}",
    scopes=["openid", "profile", "email"],
    default_clients=[
      {
        "id": "${OPENEO_CLIENT_ID}",
        "grant_types": [
          "authorization_code+pkce",
          "urn:ietf:params:oauth:grant-type:device_code+pkce",
          "refresh_token",
        ],
        "redirect_urls": ["https://openeo.$INGRESS_HOST","https://editor.openeo.org"],
      }
    ],
  ),
  #...
]
```

To support this configuration, create the `openeo-public` client in Keycloak using the `create-client.sh` script:

```bash
bash ../../utils/create-client.sh
```

When prompted:

- **Keycloak Admin Username and Password**: Enter the credentials of your Keycloak admin user (these are also in `~/.eoepca/state` if you have them set)
- **Keycloak base domain**: e.g. `auth.example.com`
- **Realm**: Typically `eoepca`
- **Confidential Client?**: specify `false` to create a PUBLIC client
- **Client ID**: Use `openeo-public` or what you named the client in the configuration script (check `~/.eoepca/state`)
- **Client name** and **description**: Provide any helpful text (e.g., "OpenEO Public Client")
- **Subdomain**: Use `openeo`
- **Additional Subdomains**: Leave blank
- **Additional Hosts**: Add `editor.openeo.org` to allow integration with the openEO Web Editor

After it completes, you should see a JSON snippet confirming the newly created client.

---

## Validation

After deploying the OpenEO Engine components, perform the following checks to verify that the system is working as expected.

### 1. Automated Validation

```bash
bash validation.sh
```

This script verifies that:

- All required pods in the `openeo-geotrellis` namespace are running
- Ingress endpoints return an HTTP 200 status code
- Key API endpoints provide well-formed JSON responses

### 2. Jupyter Notebook

Launch the notebook server:

> Note that this assumes `docker` and `docker-compose` are available.

```bash
../../../notebooks/run.sh
```

Open the openeo notebook:

```bash
xdg-open http://127.0.0.1:8888/lab/tree/openeo/openeo.ipynb
```

Clear the cell outputs and then execute the notebook - which should complete with similar outputs to the reference notebook.

> Once complete, the notebook server can be quit with Ctrl-C in the terminal.

### 3. Manual Validation

To easily run these commands, we recommend first setting `${INGRESS_HOST}` in your environment:

```bash
source ~/.eoepca/state
```

Use the following commands to interact directly with the APIs:

#### Check API Metadata

```bash
curl -L https://openeo.${INGRESS_HOST}/openeo/1.2/ | jq .
```

_Expected output:_ A JSON object containing `api_version`, `backend_version`, `endpoints`, etc.

#### List Collections

```bash
curl -L https://openeo.${INGRESS_HOST}/openeo/1.2/collections | jq .
```

_Expected output:_ A JSON array listing available collections, such as the sample collection `TestCollection-LonLat16x16`.

#### List Processes

```bash
curl -L https://openeo.${INGRESS_HOST}/openeo/1.2/processes | jq .
```

_Expected output:_ A JSON object with an array of processes. Use your terminal's scroll or `jq` to inspect the output.

---
## Usage

### openEO Web Editor

The deployment can be tested using the openEO Web Editor as a client.

```bash
xdg-open https://editor.openeo.org?server=https://openeo.${INGRESS_HOST}/openeo/1.2/
```

**Alternatively:**

* Open the [openEO Web Editor](https://editor.openeo.org/)
* Enter the `URL` of the server - `https://openeo.${INGRESS_HOST}` (e.g. `https://openeo.myplatform.mydomain`)
* Select `Connect`

**Login to service**

If OIDC authentication is enabled:
* Select `EOEPCA`
* Select `Log in with EOEPCA`  
  This redirects to authenticate via the IAM BB Keycloak instance
* Authenticate as a user - such as `eoepcauser`

**openEO Web Editor**

Successful login redirects to the `Welcome` page of the openEO Web Editor.

The web editor can be used to explore the capabilities of the openEO instance. For example, use the `Wizard` to download data from the default collection.

---

### openEO API Calls

The authentication method depends on whether you enabled OIDC during configuration.

#### Get an Access Token (OIDC Authentication)

> **Note:** This section applies only if you enabled OIDC authentication. For basic authentication deployments, skip directly to submitting jobs using basic auth headers.

This assumes use of the previously created `KEYCLOAK_TEST_USER` (default `eoepcauser`).  
If needed, run the `create-user.sh` script to create a test user:
```bash
bash ../../utils/create-user.sh
```

Request the access token:

```bash
source ~/.eoepca/state
ACCESS_TOKEN=$(
  curl --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_TEST_USER}" \
    --data-urlencode "password=${KEYCLOAK_TEST_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=${OPENEO_CLIENT_ID}" \
    -d "client_secret=${OPENEO_CLIENT_SECRET}" \
    -d "scope=openid profile email" \
    "https://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/token" |
    jq -r '.access_token'
)
echo "Access token: ${ACCESS_TOKEN}"

AUTH_TOKEN="oidc/eoepca/${ACCESS_TOKEN}"
```

If the Access Token is empty, ensure that the Keycloak client and user are correctly set up.

We format the token as `oidc/eoepca/${ACCESS_TOKEN}` to comply with the `oidc_providers` variable in the Helm values.

#### Get an Access Token (Basic Authentication)

> Skip this section if you enabled OIDC authentication.

```bash
export BASIC_AUTH=$(echo -n "testuser:testuser123" | base64)
AUTH_TOKEN="basic/openeo/${BASIC_AUTH}"
```

#### Submit a Job Using the "sum" Process

Submit a job that adds 5 and 6.5 by sending a process graph to the `/result` endpoint.

```bash
curl -X POST "https://openeo.${INGRESS_HOST}/openeo/1.2/result" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -d '{
        "process": {
          "process_graph": {
            "sum": {
              "process_id": "sum",
              "arguments": {
                "data": [5,6.5]
              },
              "result": true
            }
          }
        }
      }'
```

**Expected output:**  
```json
11.5
```

This confirms that the "sum" process is operational and returning the correct computed sum.

#### Explore Available Processes

To see available processes, navigate to:

```bash
curl -L https://openeo.${INGRESS_HOST}/openeo/1.2/processes | jq .
```

You'll see a JSON object with an array of processes, each with example usage and descriptions. Follow the same process as above to submit jobs using any of these processes.

Your Access Token will eventually expire (if using OIDC). If you receive a 401 error, obtain a new token by running the `Get an Access Token` section again.

---

### openEO Python Client

The Python client provides a more comprehensive interface for working with openEO services.

#### Install Dependencies

Create a virtual environment and install required packages:

```bash
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.12 python3.12-venv
python3.12 -m venv venv
source venv/bin/activate
pip install openeo xarray netCDF4 h5netcdf

export OPENEO_URL="https://openeo.${INGRESS_HOST}"
```

#### Connect and Authenticate

Start a Python session and establish connection:

```
python
```

And then run:

```python
import openeo
import json
import os
import xarray

# Connect to openEO service
openeo_url = os.environ.get('OPENEO_URL', 'https://openeo.${INGRESS_HOST}')
connection = openeo.connect(openeo_url)

connection.authenticate_oidc()

# Authenticate (basic auth example - adjust for OIDC if enabled)
# connection.authenticate_basic("testuser", "testuser123")

# Or for OIDC:

# Define parameters for data access
collection_id = "TestCollection-LonLat16x16"
temporal_extent = "2024-09"
spatial_extent = {"west": 3, "south": 51, "east": 5, "north": 53}
```

#### Service Discovery

Quickly explore available collections and processes:

```python
print(f"Collections: {connection.list_collection_ids()}")
print(f"Process count: {len(connection.list_processes())}")
```

#### Execute Simple Processes

Test basic arithmetic operations:

```python
result = connection.execute({
    "add": {
        "process_id": "add",
        "arguments": {"x": 3, "y": 5},
        "result": True,
    }
})
print(f"3 + 5 = {result}")
```

#### Load and Download Data

Retrieve data from collections and save locally:

```python
cube_original = connection.load_collection(
    collection_id=collection_id,
    temporal_extent=temporal_extent,
    spatial_extent=spatial_extent,
    bands=["Longitude", "Latitude", "Day"],
)
cube_original.download("original.nc")

# Inspect downloaded data
ds = xarray.load_dataset("original.nc")
print(ds)
```

#### Build Complex Processing Chains

Construct multi-step processing workflows:

```python
# Load collection with specific temporal range
cube_processed = connection.load_collection(
    collection_id=collection_id,
    temporal_extent=["2024-09-01", "2024-09-30"],
    spatial_extent=spatial_extent
)

# Apply processing steps
cube_processed = cube_processed.filter_temporal(["2024-09-10", "2024-09-20"])
cube_processed = cube_processed.reduce_dimension(dimension="t", reducer="max")
cube_processed = cube_processed.apply(lambda x: x * 100)

# Export process graph
graph = json.loads(cube_processed.to_json())
print(f"Processing chain: {' → '.join(graph['process_graph'].keys())}")

# Validate and save
connection.validate_process_graph(graph)
with open("workflow.json", "w") as f:
    json.dump(graph, f, indent=2)
print("✓ Graph validated and saved")
```

#### Band Mathematics and Normalisation

Perform calculations across multiple bands, such as computing a normalised index:

```python
# Load specific bands
cube_bands = connection.load_collection(
    collection_id=collection_id,
    temporal_extent="2024-09",
    spatial_extent=spatial_extent,
    bands=["Longitude", "Latitude"]
)

# Calculate normalised difference: (Longitude - Latitude) / (Longitude + Latitude)
lon = cube_bands.band("Longitude")
lat = cube_bands.band("Latitude")
normalised_diff = (lon - lat) / (lon + lat)

# Save results
cube_bands.download("bands.nc")
normalised_diff.download("normalised.nc")

# Export processing graph
nd_graph = json.loads(normalised_diff.to_json())
with open("normalised_workflow.json", "w") as f:
    json.dump(nd_graph, f, indent=2)
```

#### Verify Calculations

Validate that band mathematics produced expected results:

```python
ds_bands = xarray.load_dataset("bands.nc")
ds_norm = xarray.load_dataset("normalised.nc")

# Sample first pixel values
lon_val = ds_bands.Longitude.values[0, 0, 0]
lat_val = ds_bands.Latitude.values[0, 0, 0]
expected = (lon_val - lat_val) / (lon_val + lat_val)
actual = ds_norm['var'].values[0, 0, 0]

print(f"Longitude: {lon_val:.2f}, Latitude: {lat_val:.2f}")
print(f"Expected normalised value: {expected:.4f}, Actual: {actual:.4f}")
print(f"✓ Calculation correct" if abs(expected - actual) < 0.001 else "✗ Mismatch")
```

#### Clean Up

Exit Python and deactivate the virtual environment:

```python
exit()
```

```bash
ls -lh *.nc *.json
deactivate
```

The downloaded files contain the processed data cubes and workflow definitions that can be reused or shared with other openEO deployments.

## Further Reading & Official Docs

- [openEO Documentation](https://open-eo.github.io/openeo-api/)
- [openEO Geotrellis GitHub Repository](https://github.com/Open-EO/openeo-geotrellis-kubernetes)
