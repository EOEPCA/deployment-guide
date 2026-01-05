# Processing - OGC API Processes Engine

## Introduction

The **OGC API Processes Engine** provides an OGC API Processes execution engine through which users can deploy, manage, and execute OGC Application Packages. The OAPIP engine is provided by the [ZOO-Project](https://zoo-project.github.io/docs/intro.html#what-is-zoo-project) `zoo-project-dru` implementation - supporting OGC WPS 1.0.0/2.0.0 and OGC API Processes Parts 1 & 2.

- **Standardised Interfaces**: Implements OGC API Processes standards for interoperability.
- **Application Deployment**: Supports deployment, replacement, and undeployment of applications.
- **Execution Engine**: Applications execution backend. Can be Kubernetes/Calrissian, HPC/Toil and others.

---

## Prerequisites

Before deploying the **OGC API Processes Engine**, ensure you have the following:

| Component        | Requirement                            | Documentation Link                                                                            |
| ---------------- | -------------------------------------- | --------------------------------------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.32)              | [Installation Guide](../prerequisites/kubernetes.md)                                         |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                     |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                 |
| Ingress          | Properly installed                     | [Installation Guide](../prerequisites/ingress/overview.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md)                             |
| Stage-In S3      | Accessible                             |             [MinIO Deployment Guide](../prerequisites/minio.md)                                                                                  |
| Stage-Out S3     | Accessible                             | [MinIO Deployment Guide](../prerequisites/minio.md)                                                                      |

**Clone the Deployment Guide Repository:**

```
git clone https://github.com/EOEPCA/deployment-guide
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
- **`PERSISTENT_STORAGECLASS`**: Storage class for persistent volumes.
    - *Example*: `standard`
    
**Workspace Integration Configuration:**

The OAPIP engine supports two possible integrations with object storage for stage-out of processing results:

* With the EOEPCA+ Workspace BB - in which case results are written directly to the user's workspace bucket.
* With a dedicated S3 bucket - in which case results are written to a pre-configured (shared) S3 bucket.

Workspace integration is controlled via the following parameter:

- **`USE_WORKSPACE_API`**: Whether the processing stage-out should integrate with the user's Workspace object storage for persistence of processing results

Assumptions regarding integration with the Workspace BB:

* The Workspace BB has already been deployed in the cluster.
* The `username` of the user invoking the processing execution is used to select the appropriate workspace bucket - via the workspace following the naming convention `ws-<username>`. The processing engine determines the username from the JWT `Bearer` token presented in the `Authorization` header of the request. In the case that no token is presented (i.e. open service), then the username is taken from the path prefix of the request - e.g. `/<username>/ogc-api/processes/...`.

**Stage-Out S3 Configuration:**

Before proceeding, ensure you have an S3-compatible object store set up. If not, refer to the [MinIO Deployment Guide](../prerequisites/minio.md). These values should already be in your EOEPCA+ state file if you followed the main deployment steps.

- **`S3_ENDPOINT`**, **`S3_ACCESS_KEY`**, **`S3_SECRET_KEY`**, **`S3_REGION`**: Credentials and location details for the S3 bucket used as Stage-Out storage.

**Stage-In S3 Configuration:**

If your Stage-In storage differs from Stage-Out (e.g., data hosted externally), specify these separately:

- **`STAGEIN_S3_ENDPOINT`**, **`STAGEIN_S3_ACCESS_KEY`**, **`STAGEIN_S3_SECRET_KEY`**, **`STAGEIN_S3_REGION`**

**OIDC Configuration:**

If you are using the APISIX Ingress Controller, you will be prompted to provide whether you wish to enable OIDC authentication. If you choose to enable OIDC, ensure that you follow the steps in the [OIDC Configuration](#optional-oidc-configuration) section after deployment.

When prompted for the `Client ID` we recommend setting it to `oapip-engine`.

For instructions on how to set up IAM, you can follow the [IAM Building Block](./iam/main-iam.md) guide.

**Execution Engine Configuration:**

Different Execution Engines can be selected, according to the type of backend. The currently supported engines and their additional dependencies are the following:

| Execution Engine | Backend | Additional dependencies |
| --- | --- | --- |
| calrissian | Executes applications as Kubernetes jobs in dedicated namespaces, using [Calrissian](https://duke-gcb.github.io/calrissian/) | None |
| toil | Executes application as HPC jobs on a variety of HPC batch scedulers, using [Toil](https://toil.ucsc-cgl.org/) | A [Toil WES Service](https://toil.readthedocs.io/en/master/running/server/wes.html) |

The following Execution Engine specific configuration parameters needs to be setup:

For Calrissian:

- **`NODE_SELECTOR_KEY`**: Determine which nodes will run the processing workflows.
    - *Example*: `kubernetes.io/os`
    - *Read more*: [Node Selector Documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector)
- **`NODE_SELECTOR_VALUE`**: Value for the node selector key.
    - *Example*: `linux`

For Toil:

- **`OAPIP_TOIL_WES_URL`**: The Toil WES service endpoint, including the path. Must be ending with `/ga4gh/wes/v1/`
    - *Example*: `https://toil.hpc.host/ga4gh/wes/v1/`
    - *Read more*: [Zoo Wes Runner documentation](https://zoo-project.github.io/zoo-wes-runner/)
- **`OAPIP_TOIL_WES_USER`**: The Toil WES service user
    - *Example*: `test`
- **`OAPIP_TOIL_WES_PASSWORD`**: The Toil WES service password (must but be in htpasswd format)
    - *Example*: `$2y$12$ci.4U63YX83CwkyUrjqxAucnmi2xXOIlEF6T/KdP9824f1Rf1iyNG`


---

### Deploy the OAPIP Engine

#### Deploy the Helm Chart

```bash
helm repo add zoo-project https://zoo-project.github.io/charts/
helm repo update zoo-project
helm upgrade -i zoo-project-dru zoo-project/zoo-project-dru \
  --version 0.8.0 \
  --values generated-values.yaml \
  --namespace processing \
  --create-namespace
```

---

## Optional: Enable OIDC with Keycloak

> This option is only available when using the **APISIX** Ingress Controller as it relies upon APISIX to act as the policy enforcement point. If you are using a different Ingress Controller, skip to the [Validation](#validation) section.

If you **do not** wish to use OIDC IAM right now, you can skip these steps and proceed directly to the [Validation](#validation) section. You can still work with the OAPIP Engine but access will not be restricted.

If you **do** want to protect OAPIP endpoints with IAM policies (i.e. require Keycloak tokens, limit access by groups/roles, etc.) **and** you enabled `OIDC` in the configuration script then follow these steps. You will create a new client in Keycloak for the OAPIP engine and optionally define resource-protection rules (e.g. restricting who can list jobs).

> Before starting this please ensure that you have followed our [IAM Deployment Guide](./iam/main-iam.md) and have a Keycloak instance running.

### Create a Keycloak Client

A Keycloak client is required for the ingress protection of the Processing BB OAPIP Engine. The client can be created using the Crossplane Keycloak provider via the `Client` CRD.

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${OAPIP_CLIENT_ID}-keycloak-client
  namespace: iam-management
stringData:
  client_secret: ${OAPIP_CLIENT_SECRET}
---
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: ${OAPIP_CLIENT_ID}
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    clientId: ${OAPIP_CLIENT_ID}
    name: Processing OAPIP Engine
    description: Processing OAPIP Engine OIDC
    enabled: true
    accessType: CONFIDENTIAL
    rootUrl: ${HTTP_SCHEME}://zoo.${INGRESS_HOST}
    baseUrl: ${HTTP_SCHEME}://zoo.${INGRESS_HOST}
    adminUrl: ${HTTP_SCHEME}://zoo.${INGRESS_HOST}
    serviceAccountsEnabled: true
    directAccessGrantsEnabled: true
    standardFlowEnabled: true
    oauth2DeviceAuthorizationGrantEnabled: true
    useRefreshTokens: true
    authorization:
      - allowRemoteResourceManagement: false
        decisionStrategy: UNANIMOUS
        keepDefaults: true
        policyEnforcementMode: ENFORCING
    validRedirectUris:
      - "/*"
    webOrigins:
      - "/*"
    clientSecretSecretRef:
      name: ${OAPIP_CLIENT_ID}-keycloak-client
      key: client_secret
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

The `Client` should be created successfully.

### Protect the user's processing context

The OAPIP Engine is provided by the [ZOO-Project](https://zoo-project.org/) implementation, which uses a path prefix to establish a context within the processing service - such as `/<username>` or `/<project>`.

Protection can be applied so that the context is accessible only by the owning user(s).

To demonstrate, we will apply protection for the `KEYCLOAK_TEST_USER` used in this guide - nominal username `eoepcauser`. See `IAM` section [Create Test Users](./iam/main-iam.md#6-create-test-users) for creation of the test users assumed by this guide.

Similarly to the `Client` creation, we will use the Crossplane Keycloak provider to establish the protection using CRDs. The protection comprises:

* Create a Keycloak group `<username>-group`
* Add the user (`eoepcauser`) to the group
* Configure the `oapip-engine` Keycloak client `Authorization`, comprising:
    * A `Resource` representing the user's processing context - i.e. `/<username>/*`
    * A `Policy` requiring membership of the group `<username>-group`
    * A `Permission` attaching the `Policy` to the `Resource` - and so completing the protection

```bash
source ~/.eoepca/state
export OAPIP_USER="${KEYCLOAK_TEST_USER}"
envsubst < protect-oapip-user.yaml | kubectl apply -f -
```

This should indicate successful creation of the resources: `eoepcauser-group`, `eoepcauser-membership`, `eoepcauser-resource`, `eoepcauser-policy`, `eoepcauser-access`.

### Create APISIX Route Ingress

If you are using APISIX Ingress controller, apply the ingress:

```bash
kubectl apply -f generated-ingress.yaml
```

### Confirm Protection (APISIX Only)

> Resource protection is only available when using the APISIX Ingress Controller.

With the resource and permission created, attempts to access the protected endpoint (`/eoepcauser/*`) without a valid token or with insufficient privileges should be denied. You can test it by:

> Wait for the ingress and associated TLS to be established before running the following.

```
bash resource-protection-validation.sh
```

If this script shows `401 Authorization` errors when the request is made with a token, then there must be an issue with the token or the resource protection configuration.

For more detailed Keycloak testing (device flow, tokens, etc.), refer to [Resource Protection with Keycloak Policies](./iam/advanced-iam.md#resource-protection-with-keycloak-policies).

---

## Validation

### Automated Validation

This script performs a series of automated tests to validate the deployment.

```bash
bash validation.sh
```

### Web Endpoints

Check access to the service web endpoints:

* **ZOO-Project Swagger UI** - `https://zoo.${INGRESS_HOST}/swagger-ui/oapip/`
* **OGC API Processes Landing Page** - `https://zoo.${INGRESS_HOST}/ogc-api/processes/`


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

We offer a sample application that can be used to exercise the deployed service:

* `convert` - a very simple 'hello world' application that is quick to run, with low resource requirements, that can be used as a smoke test to validate the deployment

---

### Using the API

This section provides a walkthrough the OGC API Processes endpoints to deploy, execute, monitor, and retrieve results from a sample application.

> **Alternative Notebook Validation**
> 
> You can, instead, perform the walkthrough via a Jupyter Notebook - which can be invoked via the script:
> 
> ```bash
> ../../../notebooks/run.sh
> ```
> 
> This runs a local Jupyter server at `http://localhost:8888`. Open the <a href="http://localhost:8888/lab/tree/oapip/oapip.ipynb" target="_blank">OAPIP Engine Validation notebook</a> at path `/oapip/oapip.ipynb`.

#### Initialise Environment

The following example commands assume use of `bash` shell.

```bash
bash -l
```

Initialise environment variables used by the example commands.

```bash
source ~/.eoepca/state
echo ${OAPIP_HOST}
```

If you have OIDC enabled, run the `oapip-utils.sh` to generate a valid OIDC token that will be temporarily stored in your environment variables.

This will ask you for the username and password for the user you added to the group to generate an access token.

```bash
source oapip-utils.sh
```

> **_NOTE that the token is short-lived - so it may be necessary to repeat this step to refresh the token - in the case that the following commands fail unexpectedly_**

---

#### List Processes

Retrieve the list of available (currently deployed) processes.

```bash
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/processes" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Accept: application/json" | jq
```

> This command will omit the `Authorization` header if OIDC is not enabled. If you have OIDC enabled, and it is failing, please ensure you have run the `source oapip-utils.sh` script to generate the `OAPIP_AUTH_HEADER` variable.

---

#### Deploy Process `convert`

Deploy the `convert` app...

```bash
curl --silent --show-error \
  -X POST "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/processes" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d @- <<EOF | jq
{
  "executionUnit": {
    "href": "https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/scripts/processing/oapip/examples/convert-url-app.cwl",
    "type": "application/cwl"
  }
}
EOF
```

Check the `convert` application is deployed...

```bash
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/processes/convert-url" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Accept: application/json" | jq
```

---

#### Execute Process `convert`

```bash
JOB_ID=$(
  curl --silent --show-error \
    -X POST "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/processes/convert-url/execution" \
    ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
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

echo "JOB ID: ${JOB_ID}"
```

---

#### Check Execution Status

The `JOB ID` is used to monitor the progress of the job execution - most notably the status field that indicates whether the job is in-progress (`running`), or its completion status (`successful` / `failed`). Note that the full URL for job monitoring is also returned in the `Location` header of the http response to the execution request.

```bash
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/jobs/${JOB_ID}" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Accept: application/json" | jq
```

---

#### Check Execution Results

Similarly, once the job is completed successfully, then details of the results (outputs) can be retrieved.

```bash
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/jobs/${JOB_ID}/results" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Accept: application/json" | jq
```

---

#### Undeploy Process `convert`

```bash

curl --silent --show-error \
  -X DELETE "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/processes/convert-url" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Accept: application/json" | jq
```

---

## Uninstallation

To remove the Processing BB OAPIP Engine from your cluster:

```bash
source ~/.eoepca/state
export OAPIP_USER="${KEYCLOAK_TEST_USER}"
kubectl delete -f generated-ingress.yaml
envsubst < protect-oapip-user.yaml | kubectl delete -f -
kubectl -n iam-management delete client.openidclient.keycloak.m.crossplane.io ${OAPIP_CLIENT_ID}
kubectl -n iam-management delete secret ${OAPIP_CLIENT_ID}-keycloak-client
helm -n processing uninstall zoo-project-dru
kubectl delete ns processing
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

