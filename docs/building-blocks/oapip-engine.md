# Processing - OGC API Processes Engine

## Introduction

The **OGC API Processes Engine** provides an OGC API Processes execution engine through which users can deploy, manage, and execute OGC Application Packages. The OAPIP engine is provided by the [ZOO-Project](https://zoo-project.github.io/docs/intro.html#what-is-zoo-project) `zoo-project-dru` implementation - supporting OGC WPS 1.0.0/2.0.0 and OGC API Processes Parts 1 & 2.

- **Standardised Interfaces**: Implements OGC API Processes standards for interoperability.
- **Application Deployment**: Supports deployment, replacement, and undeployment of applications.
- **Execution Engine**: Executes applications using Kubernetes and Calrissian for CWL workflows.

---

## Prerequisites

Before deploying the **OGC API Processes Engine**, ensure you have the following:

| Component        | Requirement                            | Documentation Link                                                                            |
| ---------------- | -------------------------------------- | --------------------------------------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.28)              | [Installation Guide](../infra/kubernetes-cluster-and-networking.md)                                         |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                     |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                 |
| Ingress          | Properly installed                     | [Installation Guide](../infra/ingress-controller.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../infra/tls/overview.md/)                             |
| Stage-In S3      | Accessible                             |             [MinIO Deployment Guide](../infra/minio.md)                                                                                  |
| Stage-Out S3     | Accessible                             | [MinIO Deployment Guide](../infra/minio.md)                                                                      |

**Clone the Deployment Guide Repository:**

```
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/processing/oapip
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```
bash check-prerequisites.sh
```

---

## Deployment

### Run the Configuration Script

```bash
bash configure-oapip.sh
```

**Configuration Parameters**

- **`INGRESS_HOST`**: Base domain for ingress hosts.
    - *Example*: `example.com`
- **`CLUSTER_ISSUER`** (if using `cert-manager`): Name of the ClusterIssuer.
    - *Example*: `letsencrypt-prod`
- **`STORAGE_CLASS`**: Storage class for persistent volumes.
    - *Example*: `default`

**Stage-Out S3 Configuration**:
Before proceeding, ensure you have an existing S3 object store. If you need to set one up, refer to the [MinIO Deployment Guide](../infra/minio.md). These values get automatically set in the EOEPCA+ state if you followed the Deployment Steps.

- **`S3_ENDPOINT`**: S3 Endpoint URL.
    - `minio.example.com`
- **`S3_ACCESS_KEY`**: S3 Access Key.
- **`S3_SECRET_KEY`**: S3 Secret Key.
- **`S3_REGION`**: S3 Region.
    - `us-west-1`
    
**Stage-In S3 Configuration**:
This is where you will get the incoming data. 
- This can be set to the same as the Stage-Out configuration if you are storing the data in the same S3. 
- Alternatively if your stage-in is in a different location, for example, you are using the data hosted by CloudFerro, then update these.

- **`STAGEIN_S3_ENDPOINT`**: Stage-In S3 Endpoint URL.
    - `stage-in-s3.example.com`
- **`STAGEIN_S3_ACCESS_KEY`**: Stage-In S3 Access Key.
- **`STAGEIN_S3_SECRET_KEY`**: Stage-In S3 Secret Key.
- **`STAGEIN_S3_REGION`**: Stage-In S3 Region.
    - `eu-west-2`

**Important Notes:**

- If you choose **not** to use `cert-manager`, you will need to create the TLS secrets manually before deploying.
  - The required TLS secret names are:
    - `zoo-tls`
  - For instructions on creating TLS secrets manually, please refer to the [Manual TLS Certificate Management](../infra/tls/manual-tls.md) section in the TLS Certificate Management Guide.

---

### Create Keycloak client for OAPIP Engine

Create the `oapip-engine` client in Keycloak for IAM integration.<br>
The client secret is required in the deployment steps.

**Get access token for administration**

```bash
source ~/.eoepca/state
ACCESS_TOKEN=$( \
  curl --silent --show-error \
    -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "https://auth-apx.${INGRESS_HOST}/realms/master/protocol/openid-connect/token" | jq -r '.access_token' \
)
```

**Create the `oapip-engine` client**

```bash
# curl --silent --show-error \
curl  \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" <<EOF
{
  "clientId": "oapip-engine",
  "name": "OGC API Processes Engine",
  "description": "OGC API Processes Engine",
  "enabled": true,
  "protocol": "openid-connect",
  "rootUrl": "https://zoo-apx.${INGRESS_HOST}",
  "baseUrl": "https://zoo-apx.${INGRESS_HOST}",
  "redirectUris": [
    "https://zoo-apx.${INGRESS_HOST}/*",
    "https://zoo-swagger-apx.${INGRESS_HOST}/*",
    "/*"
  ],
  "webOrigins": ["/*"],
  "publicClient": false,
  "clientAuthenticatorType": "client-secret",
  "secret": "${OAPIP_CLIENT_SECRET}",
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": true,
  "authorizationServicesEnabled": true,
  "frontchannelLogout": true
}
EOF
```

**Check details of new `oapip-engine` client**

```bash
curl --silent --show-error \
  -X GET \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" \
  | jq '.[] | select(.clientId == "oapip-engine")'
```

---

### Apply Kubernetes Secrets

Run the script to create the necessary Kubernetes secrets.

```bash
bash apply-secrets.sh
```

---

### Deploy the OAPIP Engine Using Helm

```bash
helm repo add zoo-project https://zoo-project.github.io/charts/ && \
helm repo update zoo-project && \
helm upgrade -i zoo-project-dru zoo-project/zoo-project-dru \
  --version 0.3.6 \
  --values generated-values.yaml \
  --namespace processing \
  --create-namespace
```

---

### OAPIP Engine Ingress

Note the ingress for the OAPIP Engine is established using APISIX resources (ApisixRoute, ApisixTls). It is assumed that the `ClusterIssuer` dedicated to APISIX routes has been created (`letsencrypt-prod-apx`) - as described in section [Using Cert-Manager](../infra/tls/cert-manager.md).

```bash
kubectl -n processing apply -f generated-ingress.yaml
```

---

## Validation

### Automated Validation

This script performs a series of automated tests to validate the deployment.

```bash
bash validation.sh
```

---

### Web Endpoints

Check access to the service web endpoints:

* **ZOO-Project Swagger UI** - `https://zoo.<INGRESS_HOST>/swagger-ui/oapip/`
* **OGC API Processes Landing Page** - `https://zoo.<INGRESS_HOST>/ogc-api/processes/`

---

### Expected Kubernetes Resources

Ensure that all Kubernetes resources are running correctly.

```bash
kubectl get pods -n processing
```

**Expected Output:**

- All pods should be in the `Running` state.
- No pods should be in `CrashLoopBackOff` or `Error` states.

---

### Via OGC API Processes

Validate the operation of the `zoo` service via its OGC API Processes interfaces.

Depending on your validation needs we offer two sample applications that can be used to exercise the deployed service...

* `convert` - a very simple 'hello world' application that is quick to run, with low resource requirements, that can be used as a smoke test to validate the deployment
* `water-bodies` - a more real-world application that performs processing of EO input data

In the following sections select the path `convert` vs `water-bodies` that suits your needs.

NOTE that the following API requests assume use of the `eoepca` test user.

---

#### List Processes

Retrieve the list of available (currently deployed) processes.

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X GET "https://zoo.${INGRESS_HOST}/eoepca/ogc-api/processes" \
  -H "Accept: application/json" | jq
```

---

#### Deploy Process

Deploy the application that meets your validation needs.

---

##### Deploy - `convert`

Deploy the `convert` app...

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X POST "https://zoo.${INGRESS_HOST}/eoepca/ogc-api/processes" \
  -H "Content-Type: application/ogcapppkg+json" \
  -H "Accept: application/json" \
  -d @- <<EOF | jq
{
  "executionUnit": {
    "href": "https://raw.githubusercontent.com/EOEPCA/deployment-guide/2.0-beta/scripts/processing/oapip/examples/convert-url-app.cwl",
    "type": "application/cwl"
  }
}
EOF
```

Check the `convert` application is deployed...

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X GET "https://zoo.${INGRESS_HOST}/eoepca/ogc-api/processes/convert-url" \
  -H "Accept: application/json" | jq
```

---

##### Deploy - `water-bodies`

Deploy the `water-bodies` app...

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X POST "https://zoo.${INGRESS_HOST}/eoepca/ogc-api/processes" \
  -H "Content-Type: application/ogcapppkg+json" \
  -H "Accept: application/json" \
  -d @- <<EOF | jq
{
  "executionUnit": {
    "href": "https://raw.githubusercontent.com/EOEPCA/deployment-guide/2.0-beta/scripts/processing/oapip/examples/water-bodies.cwl",
    "type": "application/cwl"
  }
}
EOF
```

Check the `water-bodies` application is deployed...

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X GET "https://zoo.${INGRESS_HOST}/eoepca/ogc-api/processes/water-bodies" \
  -H "Accept: application/json" | jq
```

---

#### Execute Process

Initiate the execution of the deployed application.

Execute either `convert` or `water-bodies` - depending on your needs.

In either case the `JOB ID` of the execution is retained for use in subsequent API calls.

---

##### Execute - `convert`

```bash
source ~/.eoepca/state
JOB_ID=$(
  curl --silent --show-error \
    -X POST "https://zoo.${INGRESS_HOST}/eoepca/ogc-api/processes/convert-url/execution" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "Prefer: respond-async" \
    -d @- <<EOF | jq -r '.jobID'
  {
    "inputs": {
      "fn": "resize",
      "url":  "https://eoepca.org/media_portal/images/logo6_med.original.png",
      "size": "50%"
    }
  }
EOF
)
```

---

##### Execute - `water-bodies`

```bash
source ~/.eoepca/state
JOB_ID=$(
  curl --silent --show-error \
    -X POST "https://zoo.${INGRESS_HOST}/eoepca/ogc-api/processes/water-bodies/execution" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "Prefer: respond-async" \
    -d @- <<EOF | jq -r '.jobID'
  {
    "inputs": {
      "stac_items": [
        "raw.githubusercontent.com/EOEPCA/deployment-guide/2.0-beta/scripts/processing/oapip/examples/stac-item.json",
      ],
      "aoi": "-6.059593683367105,53.123645037009204,-4.727280797333244,54.133792015262706",
      "epsg": "EPSG:4326",
      "bands": [
        "green",
        "nir"
      ]
    }
  }
EOF
)
```

---

#### Check Execution Status

The `JOB ID` is used to monitor the progress of the job execution - most notably the status field that indicates whether the job is in-progress (`running`), or its completion status (`successful` / `failed`). Note that the full URL for job monitoring is also returned in the `Location` header of the http response to the execution request.

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X GET "https://zoo.${INGRESS_HOST}/ogc-api/jobs/${JOB_ID}" \
  -H "Accept: application/json" | jq
```

---

#### Check Execution Results

Similarly, once the job is completed successfully, then details of the results (outputs) can be retrieved.

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X GET "https://zoo.${INGRESS_HOST}/ogc-api/jobs/${JOB_ID}/results" \
  -H "Accept: application/json" | jq
```

The STAC files and assets comprising the results are referenced as links to object storage. Access the object storage console to inspect these outputs - see the [Object Storage description](../infra/minio.md) for more details.

---

#### Undeploy Process

The deployed application can be deleted (undeployed) once it is no longer needed.

---

##### Undeploy - `convert`

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X DELETE "https://zoo.${INGRESS_HOST}/eoepca/ogc-api/processes/convert-url" \
  -H "Accept: application/json" | jq
```

---

##### Undeploy - `water-bodies`

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X DELETE "https://zoo.${INGRESS_HOST}/eoepca/ogc-api/processes/water-bodies" \
  -H "Accept: application/json" | jq
```

---

## Uninstallation

To remove the Processing Building Block from your cluster:

```bash
helm -n processing uninstall zoo-project-dru
```

### Additional Cleanup

- **Delete Persistent Volume Claims (PVCs):**

  ```bash
  kubectl -n processing delete pvc -l app.kubernetes.io/instance=zoo-project-dru
  ```

---
## Further Reading

- [ZOO-Project DRU Helm Chart](https://github.com/ZOO-Project/ZOO-Project/tree/master/docker/kubernetes/helm/zoo-project-dru)
- [EOEPCA+Cookiecutter Template](https://github.com/EOEPCA/eoepca-proc-service-template)
- [EOEPCA+Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide)
- [OGC API Processes Standards](https://www.ogc.org/standards/ogcapi-processes)
- [Common Workflow Language (CWL)](https://www.commonwl.org/)
- [Calrissian Documentation](https://github.com/Duke-GCB/calrissian)

---
## Feedback

If you have any issues or suggestions, please open an issue on the [EOEPCA+Deployment Guide GitHub Repository](https://github.com/EOEPCA/deployment-guide/issues).

