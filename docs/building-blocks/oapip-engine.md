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
| Kubernetes       | Cluster (tested on v1.28)              | [Installation Guide](../prerequisites/kubernetes.md)                                         |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                     |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                 |
| Ingress          | Properly installed                     | [Installation Guide](../prerequisites/ingress-controller.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md)                             |
| Stage-In S3      | Accessible                             |             [MinIO Deployment Guide](../prerequisites/minio.md)                                                                                  |
| Stage-Out S3     | Accessible                             | [MinIO Deployment Guide](../prerequisites/minio.md)                                                                      |

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
    - *Example*: `letsencrypt-http01-apisix`
- **`STORAGE_CLASS`**: Storage class for persistent volumes.
    - *Example*: `standard`

**Stage-Out S3 Configuration:**

Before proceeding, ensure you have an S3-compatible object store set up. If not, refer to the [MinIO Deployment Guide](../prerequisites/minio.md). These values should already be in your EOEPCA+ state file if you followed the main deployment steps.

- **`S3_ENDPOINT`**, **`S3_ACCESS_KEY`**, **`S3_SECRET_KEY`**, **`S3_REGION`**: Credentials and location details for the S3 bucket used as Stage-Out storage.

**Stage-In S3 Configuration:**

If your Stage-In storage differs from Stage-Out (e.g., data hosted externally), specify these separately:

- **`STAGEIN_S3_ENDPOINT`**, **`STAGEIN_S3_ACCESS_KEY`**, **`STAGEIN_S3_SECRET_KEY`**, **`STAGEIN_S3_REGION`**

**OIDC Configuration:**

You will be prompted to provide whether you wish to enable OIDC authentication. If you choose to enable OIDC, ensure that you follow the steps in the [OIDC Configuration](#optional-oidc-configuration) section after deployment.

For instructions on how to set up IAM, you can follow the [IAM Building Block](./iam/main-iam.md) guide.

---

### Deploy the OAPIP Engine

#### Deploy the Helm Chart

```bash
helm repo add zoo-project https://zoo-project.github.io/charts/ && \
helm repo update zoo-project && \
helm upgrade -i zoo-project-dru zoo-project/zoo-project-dru \
  --version 0.2.6 \
  --values generated-values.yaml \
  --namespace processing \
  --create-namespace
```

---

## Optional: Enable OIDC with Keycloak

If you **do not** wish to use OIDC/IAM right now, you can skip these steps and proceed directly to the [Validation](#validation) section.

If you **do** want to protect OAPIP endpoints with IAM policies (i.e. require Keycloak tokens, limit access by groups/roles, etc.), follow these steps. You will create a new client in Keycloak for the OAPIP engine and optionally define resource-protection rules (e.g. restricting who can list jobs).

> Before starting this please ensure that you have followed our [IAM Deployment Guide](./iam/main-iam.md) and have a Keycloak instance running.

### 2.1 Create a Keycloak Client

Use the `create-client.sh` script in the `/scripts/utils/` directory. This script prompts you for basic details and automatically creates a Keycloak client in your chosen realm:

```bash
cd /scripts/utils
bash create-client.sh
```

When prompted:

- **Keycloak Admin Username and Password**: Enter the credentials of your Keycloak admin user (these are also in `~/.eoepca/state` if you have them set).
- **Keycloak base domain**: e.g. `auth.example.com` or `auth-apx.example.com`
- **Realm**: Typically `eoepca`.

- **Client ID**: For the OAPIP engine, you should use `oapip-engine`.
- **Client name** and **description**: Provide any helpful text (e.g., `OAPIP Engine Client`).
- **Client secret**: Enter the OAPIP Client Secret that was generated during the configuration script (check `~/.eoepca/state`).
- **Subdomain**: Use `zoo` for the OAPIP engine. 

After it completes, you should see a JSON snippet confirming the newly created client.

---

### 2.2 Define Resource Protection

By default, once the OAPIP engine is connected to Keycloak, it can accept OIDC tokens. If you want to **restrict** or **fine-tune** access to certain endpoints (like `/ogc-api/jobs/`).

#### Protect the `/ogc-api/jobs/*` Endpoint

1. **Use the `protect-resource.sh`**:
        
```bash
cd /scripts/utils
bash protect-resource.sh
```
        
When prompted:

- **Client ID**: `oapip-engine` (the client you created in the previous step)
- **Resource Type**: `urn:oapip-engine:resources:default`
- **Resource URI**: `/ogc-api/jobs/*`
- **Username**: e.g., `eoepca` (or any user you want to test with, if you don't have a user, then create one in Keycloak)

---

### 2.3 Create APISIX Route Ingress

Back in the `scripts/processing/oapip` directory, apply the APISIX route ingress:

```bash
kubectl apply -f generated-ingress.yaml
```

---


### 2.4 Confirm Protection

With the resource and permission created, attempts to access the protected endpoint (`/ogc-api/jobs/*`) without a valid token or with insufficient privileges should be denied. You can test it by:

```
bash resource-protection-validation.sh
```



For more detailed Keycloak testing (device flow, tokens, etc.), refer to [Resource Protection with Keycloak Policies](../iam/advanced-iam.md#resource-protection-with-keycloak-policies).

---

## Validation

### Automated Validation

This script performs a series of automated tests to validate the deployment.

```bash
bash validation.sh
```

### Web Endpoints

Check access to the service web endpoints:

* **ZOO-Project Swagger UI** - `https://zoo.<INGRESS_HOST>/swagger-ui/oapip/`
* **OGC API Processes Landing Page** - `https://zoo.<INGRESS_HOST>/ogc-api/processes/`


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

Depending on your validation needs we offer a sample application that can be used to exercise the deployed service...

* `convert` - a very simple 'hello world' application that is quick to run, with low resource requirements, that can be used as a smoke test to validate the deployment


#### Authenticate

Please refer to the [IAM User Authentication](../iam/client-management#obtaining-tokens-via-the-device-flow) section for details on how to authenticate as the `eoepca` user to obtain an `access_token`.

---

### Using the API

To follow the below sections easily we recommend setting the `OAPIP_HOST` and `OAPIP_AUTH_HEADER` environment variables.

Only set `OAPIP_AUTH_HEADER` if you have OIDC enabled.

```bash
source ~/.eoepca/state
echo ${OAPIP_HOST}
export OAPIP_AUTH_HEADER="-H \"Authorization: Bearer ${access_token}\"" # Only if OIDC is enabled
```

#### List Processes

Retrieve the list of available (currently deployed) processes.

```bash
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/eoepca/ogc-api/processes" \
  ${OAPIP_AUTH_HEADER}
  -H "Accept: application/json" | jq
```

---

#### Deploy Process

Deploy the application that meets your validation needs.

---

##### Deploy - `convert`

Deploy the `convert` app...

```bash
curl --show-error \
  -X POST "${OAPIP_HOST}/ogc-api/processes" \
  ${OAPIP_AUTH_HEADER} \
  -H "Content-Type: application/json" \
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
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/eoepca/ogc-api/processes/convert-url" \
  ${OAPIP_AUTH_HEADER}
  -H "Accept: application/json" | jq
```

---

#### Execute Process

Initiate the execution of the deployed application.

Execute  `convert` and retrieve the `JOB ID` of the execution.

---

##### Execute - `convert`

```bash

JOB_ID=$(
  curl --silent --show-error \
    -X POST "${OAPIP_HOST}/eoepca/ogc-api/processes/convert-url/execution" \
    ${OAPIP_AUTH_HEADER} \
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

#### Check Execution Status

The `JOB ID` is used to monitor the progress of the job execution - most notably the status field that indicates whether the job is in-progress (`running`), or its completion status (`successful` / `failed`). Note that the full URL for job monitoring is also returned in the `Location` header of the http response to the execution request.

```bash
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/ogc-api/jobs/${JOB_ID}" \
  ${OAPIP_AUTH_HEADER} \
  -H "Accept: application/json" | jq
```

---

#### Check Execution Results

Similarly, once the job is completed successfully, then details of the results (outputs) can be retrieved.

```bash
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/ogc-api/jobs/${JOB_ID}/results" \
  ${OAPIP_AUTH_HEADER} \
  -H "Accept: application/json" | jq
```

The STAC files and assets comprising the results are referenced as links to object storage. Access the object storage console to inspect these outputs - see the [Object Storage description](../prerequisites/minio.md) for more details.

---

#### Undeploy Process

The deployed application can be deleted (undeployed) once it is no longer needed.

---

##### Undeploy - `convert`

```bash

curl --silent --show-error \
  -X DELETE "${OAPIP_HOST}/eoepca/ogc-api/processes/convert-url" \
  ${OAPIP_AUTH_HEADER}
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
- [EOEPCA+ Cookiecutter Template](https://github.com/EOEPCA/eoepca-proc-service-template)
- [EOEPCA+ Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide)
- [OGC API Processes Standards](https://www.ogc.org/standards/ogcapi-processes)
- [Common Workflow Language (CWL)](https://www.commonwl.org/)
- [Calrissian Documentation](https://github.com/Duke-GCB/calrissian)

---
## Feedback

If you have any issues or suggestions, please open an issue on the [EOEPCA+Deployment Guide GitHub Repository](https://github.com/EOEPCA/deployment-guide/issues).

