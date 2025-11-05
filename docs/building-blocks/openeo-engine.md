# Processing - OpenEO Engine Deployment Guide

OpenEO develops an API that allows users to connect to Earth observation cloud back-ends in a simple and unified way. The project maintains the API and process specifications, and an open-source ecosystem with clients and server implementations.

> **Note:** OIDC authentication is now optional for OpenEO deployments. If you choose to enable OIDC during configuration, you'll need a valid OIDC Provider. Refer to the [IAM Deployment Guide](./iam/main-iam.md) if you need to set one up.

---

## Prerequisites

Before deploying, ensure your environment meets the following requirements:

|Component|Requirement|Documentation Link|
|---|---|---|
|Kubernetes|Cluster (tested on v1.32)|[Installation Guide](../prerequisites/kubernetes.md)|
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
    --create-namespace \
    --values zookeeper/generated-values.yaml
```

For full configuration details, see the [values.yaml](https://github.com/bitnami/charts/blob/main/bitnami/zookeeper/values.yaml).

#### Step 3: Deploy openEO Geotrellis Using Helm

> You must wait for the ZooKeeper deployment to be fully running before deploying openEO Geotrellis. This is because it relies on the webhook.

Provides an API that simplifies connecting to EO cloud back-ends, running on Apache Spark in a Kubernetes environment.

```bash
helm upgrade -i openeo-geotrellis-openeo sparkapplication \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 0.16.3 \
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

### 4. Usage - openEO Web Editor

The deployment can be tested using the openEO Web Editor as a client.

```bash
xdg-open https://editor.openeo.org?server=https://openeo.${INGRESS_HOST}/openeo/1.2/
```

**Alternatively**

* Open the [openEO Web Editor](https://editor.openeo.org/)
* Enter the `URL` of the server - `https://openeo.${INGRESS_HOST}` - e.g. `https://openeo.myplatform.mydomain`
* Select `Connect`

**Login to service**

If OIDC authentication is enabled:
* Select `EOEPCA`
* Select `Log in with EOEPCA`  
  This should redirect to authenticate via the IAM BB Keycloak instance
* Authenticate as a user - such as `eoepcauser`

If basic authentication is configured
* Use the basic authentication credentials configured in your deployment
* The system will handle authentication without requiring external identity providers

**openEO Web Editor**

Successful login should redirect to the `Welcome` page of the openEO Web Editor.

The web editor can be used to explore the capabilities of the openEO instance.

For example, use the `Wizard` to download some data from the default collection.

---

### 5. Usage - openEO API calls

The authentication method depends on whether you enabled OIDC during configuration.

#### Get an Access Token (OIDC Authentication)

> **Note:** This section applies only if you enabled OIDC authentication. For basic authentication deployments, you can skip directly to submitting jobs using basic auth headers.

This assumes use of the previously created `KEYCLOAK_TEST_USER` (default `eoepcauser`).  
If needed, run the `create-user.sh` script to create a test user:
```
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

If the Access Token is empty, please make sure that the Keycloak client and user are correctly set up.

We need to format the token as `oidc/eoepca/${ACCESS_TOKEN}` to comply with the `oidc_providers` variable seen in the Helm values.

#### Get an Access Token (Basic Authentication)

```
export BASIC_AUTH=$(echo -n "testuser:testuser123" | base64)
AUTH_TOKEN="basic/openeo/${BASIC_AUTH}"
```


#### Submit a Job Using the "sum" Process

Submit a job that adds 5 and 6.5 by sending a process graph to the `/jobs` endpoint.

For OIDC authentication:
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
A simple numeric result:

```json
11.5
```

This confirms that the "sum" process is operational and returning the correct computed sum.

#### Experiment with Other Processes

To see more available processes you can run, navigate to:

```url
https://openeo.${INGRESS_HOST}/openeo/1.2/processes
```

You should see a JSON object with an array of processes. Each with example usage and descriptions. Follow the same process as above to submit a job using any of these processes.

Your Access Token will eventually expire (if using OIDC). If you receive a 401 error, you'll need to obtain a new token by running the `Get an Access Token` section again.

---

## Further Reading & Official Docs

- [openEO Documentation](https://open-eo.github.io/openeo-api/)
- [openEO Geotrellis GitHub Repository](https://github.com/Open-EO/openeo-geotrellis-kubernetes)
