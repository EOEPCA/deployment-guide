# Processing - OpenEO Engine Deployment Guide (Early Access)

The **OpenEO Engine** building block provides early access to a unified processing platform for Earth observation data. It brings together two key components: **openEO Geotrellis** and **openEO Aggregator**. These components work together to offer a standards-based API for connecting to diverse EO cloud back-ends and to federate multiple openEO services into a cohesive processing platform.

> **Note:** You must have a valid OIDC Provider to submit jobs to the OpenEO Engine. If you do not have one, refer to the [IAM Deployment Guide](./iam/main-iam.md) to set up an OIDC Provider.

---

## Components

- **openEO Geotrellis:** Provides an API that simplifies connecting to EO cloud back-ends, running on Apache Spark.
- **openEO Aggregator:** Groups multiple openEO back-ends into a unified processing platform.

---

## Prerequisites

Before deploying, ensure your environment meets the following requirements:

|Component|Requirement|Documentation Link|
|---|---|---|
|Kubernetes|Cluster (tested on v1.28)|[Installation Guide](../prerequisites/kubernetes.md)|
|Helm|Version 3.5 or newer|[Installation Guide](https://helm.sh/docs/intro/install/)|
|kubectl|Configured for cluster access|[Installation Guide](https://kubernetes.io/docs/tasks/tools/)|
|Ingress|Properly installed|[Installation Guide](../prerequisites/ingress-controller.md)|
|Cert Manager|Properly installed|[Installation Guide](../prerequisites/tls.md)|
|OIDC Provider|Required to submit jobs|[Installation Guide](./iam/main-iam.md)|


**Clone the Deployment Guide Repository:**

```
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
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

During this process, you will be prompted for:

- **`INGRESS_HOST`**: Base domain for ingress hosts (e.g., `example.com`).
- **`STORAGE_CLASS`**: Kubernetes storage class for persistent volumes.
- **`CLUSTER_ISSUER`**: Cert-manager Cluster Issuer for TLS certificates.


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

Provides an API that simplifies connecting to EO cloud back-ends, running on Apache Spark in a Kubernetes environment.

```bash
helm upgrade -i openeo-geotrellis-openeo sparkapplication \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 0.16.3 \
    --namespace openeo-geotrellis \
    --create-namespace \
    --values openeo-geotrellis/generated-values.yaml
```

Deploy ingress

```
kubectl apply -f openeo-geotrellis/generated-ingress.yaml
```

---

## Validation

After deploying the OpenEO Engine components, perform the following checks to verify that the system is working as expected.

### 1. Automated Validation (Optional)

```bash
bash validation.sh
```

This script verifies that:

- All required pods in the `openeo-geotrellis` (and optionally `openeofed`) namespace are running.
- Ingress endpoints return an HTTP 200 status code.
- Key API endpoints provide well-formed JSON responses.



### 2. Manual Validation

To easily run these commands, we recommend first setting `${INGRESS_HOST}` in your environment.

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

_Expected output:_ A JSON object with an array of processes. Use your terminal’s scroll or `jq` to inspect the output.

### 3. Usage

Before running any jobs, you must obtain an access token from your OIDC Provider. Use the following command to get an access token if you followed our [IAM Deployment Guide](./iam/main-iam.md).

#### Create a Keycloak Client

Use the `create-client.sh` script in the `/scripts/utils/` directory. This script prompts you for basic details and automatically creates a Keycloak client in your chosen realm:

```bash
bash ../../utils/create-client.sh
```

When prompted:

- **Keycloak Admin Username and Password**: Enter the credentials of your Keycloak admin user (these are also in `~/.eoepca/state` if you have them set).
- **Keycloak base domain**: e.g. `auth.example.com`
- **Realm**: Typically `eoepca`.

- **Client ID**: Use `demo-openeo-eoepca`.
- **Client name** and **description**: Provide any helpful text (e.g., "OpenEO Client").
- **Client secret**: Leave blank and let Keycloak generate one.
- **Subdomain**: Use `openeo`.
- **Additional Subdomains**: Leave blank.

After it completes, you should see a JSON snippet confirming the newly created client.


#### Create a Keycloak User

If you have not already created a user, you can do so using the helper scripts or through the Keycloak UI. To create a user using the helper script, run

```bash
bash ../../utils/create-user.sh
```


#### Get an Accces Token

```bash
source ~/.eoepca/state

ACCESS_TOKEN=$(
    curl --silent --show-error \
         -X POST \
         -d "username=<YOUR-USERNAME>" \
         --data-urlencode "password=<YOUR-PASSWORD>" \
         -d "grant_type=password" \
         -d "client_id=demo-openeo-eoepca" \
         -d "client_secret=<CLIENT-SECRET>" \
         -d "scope=openid profile email" \
         "https://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/token" |
         jq -r '.access_token'
)

AUTH_TOKEN="oidc/eoepca/${ACCESS_TOKEN}"
```

Make sure that you replace the following values:
- <YOUR-USERNAME> with your username
- <YOUR-PASSWORD> with your password
- <CLIENT-SECRET> with your client secret

We need to format the token as `oidc/eoepca/${ACCESS_TOKEN}` to comply with the `oidc_providers` variable seen in the Helm values.


#### Submit a Job Using the "add" Process

Submit a job that adds 5 and 6.5 by sending a process graph to the `/jobs` endpoint:

```bash
curl -X POST "https://openeo.${INGRESS_HOST}/openeo/1.2/result" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -d '{
        "process": {
          "process_graph": {
            "arccos_node": {
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

This confirms that the "add" process is operational and returning the correct computed sum.

---

## Further Reading & Official Docs

- [openEO Documentation](https://open-eo.github.io/openeo-api/)
- [openEO Geotrellis GitHub Repository](https://github.com/Open-EO/openeo-geotrellis-kubernetes)
- [openEO Aggregator Documentation](https://open-eo.github.io/openeo-aggregator/)
