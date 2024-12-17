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
    "/*"
  ],
  "webOrigins": ["/*"],
  "publicClient": false,
  "clientAuthenticatorType": "client-secret",
  "secret": "${OAPIP_CLIENT_SECRET}",
  "directAccessGrantsEnabled": false,
  "attributes": {
    "oauth2.device.authorization.grant.enabled": true
  },
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

## Apply Resource Protection

This section provides an example resource protection using Keycloak groups and policies.

The example assumes protection for the `/eoepca` context within `zoo` - protected via the group `team-eoepca` that represents a team/project with common access.

The user `eoepca` is added to the `team-eoepca` group - assuming that the user was created as described in section [Create `eoepca` user for testing](iam.md#6-create-eoepca-user-for-testing)

### Obtain an Access Token for Administration

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

### Create the `Group`

Create the group `team-eoepca`.

```bash
curl --silent --show-error \
  -X POST "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/groups" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json" \
  -d '
{
  "name": "team-eoepca"
}'
```

Retrieve the unique Group ID.

```bash
group_id=$( \
  curl --silent --show-error \
    -X GET "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/groups" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    | jq -r '.[] | select(.name == "team-eoepca") | .id' \
)
echo "Group ID: ${group_id}"
```

### Add user to group

Retrieve the unique User ID for user `eoepca`.

```bash
user_id=$(
  curl --silent --show-error \
    -X GET "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/users?username=eoepca" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    | jq -r '.[] | .id'
)
echo "User ID: ${user_id}"
```

Add user `eoepca` to group `team-eoepca`.

```bash
curl --silent --show-error \
  -X PUT "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/users/${user_id}/groups/${group_id}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json"
```

### Create policy

Create policy `eoepca-team-policy` that requires membership of the `team-eoepca` group. The policy is created in the `oapip-engine` client.

Retrieve the unique Client ID.

```bash
client_id=$( \
  curl --silent --show-error \
    -X GET "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    | jq -r '.[] | select (.clientId == "oapip-engine") | .id' \
)
echo "Client ID: ${client_id}"
```

Create the policy.

```bash
policy_id=$( \
  curl --silent --show-error \
    -X POST "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients/${client_id}/authz/resource-server/policy/group" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    -d @- <<EOF | jq -r '.id'
{
  "name": "eoepca-team-policy",
  "logic": "POSITIVE",
  "decisionStrategy": "UNANIMOUS",
  "groups": ["${group_id}"]
}
EOF
)
echo "Policy ID: ${policy_id}"
```

### Create resource

Create the resource `eoepca-context` for the `/eoepca` endpoint within `zoo`.

```bash
resource_id=$( \
  curl --silent --show-error \
    -X POST "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients/${client_id}/authz/resource-server/resource" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    -d @- <<EOF | jq -r '._id'
{
  "name": "eoepca-context",
  "uris": ["/eoepca/*"],
  "ownerManagedAccess": true
}
EOF
)
echo "Resource ID: ${resource_id}"
```

### Create permission

Associate the policy `eoepca-team-policy` with the `eoepca-context` resource by creating a permission.

The effect of this is to allow access to anyone in the `team-eoepca` group to access the path `/eoepca` within Zoo.

```bash
permission_id=$( \
  curl --silent --show-error \
    -X POST "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients/${client_id}/authz/resource-server/policy/resource" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    -d @- <<EOF | jq -r '.id'
{
  "name": "eoepca-context-access",
  "description": "Group team-eoepca access to /eoepca",
  "logic": "POSITIVE",
  "decisionStrategy": "UNANIMOUS",
  "resources": ["${resource_id}"],
  "policies": ["${policy_id}"]
}
EOF
)
echo "Permission ID: ${permission_id}"
```

### ALTERNATIVE - Role-based Permission

The previous steps protect the `/eoepca` zoo endpoint by directly referencing the `group` to which access is granted.

Alternatively, the permission could be expressed with an additional indirection via a `role`. In this case, access to the `/eoepca` resource references a `role` rather than the `group`. The `team-eoepca` group can then be added to the role, and hence receive access.

In Keycloak, a role can be created either at the level of a realm, or scoped to a specific client - using the API endpoints...

* **realm** - `/admin/realms/eoepca/roles`
* **client** - `/admin/realms/eoepca/clients/{client-id}/roles`

See the [Keycloak Admin REST API](https://www.keycloak.org/docs-api/latest/rest-api/) for more details.

## Validation

### Automated Validation

This script performs a series of automated tests to validate the deployment.

```bash
bash validation.sh
```

---

### Web Endpoints

Check access to the service web endpoints:

* **ZOO-Project Swagger UI** - `https://zoo-apx.<INGRESS_HOST>/swagger-ui/oapip/`
* **OGC API Processes Landing Page** - `https://zoo-apx.<INGRESS_HOST>/ogc-api/processes/`

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

#### Authenticate

Assuming that the zoo service has been protected as described in section [Apply Resource Protection](#apply-resource-protection), then it is necessary to authenticate as the `eoepca` user to obtain an `access-token` for API requests.

**Step 1 - Initiate the Device Auth Flow**

```bash
source ~/.eoepca/state

response=$( \
  curl --silent --show-error \
    -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=oapip-engine" \
    -d "client_secret=${OAPIP_CLIENT_SECRET}" \
    -d "scope=openid profile email" \
    "https://auth-apx.${INGRESS_HOST}/realms/eoepca/protocol/openid-connect/auth/device" \
)
device_code=$(echo $response | jq -r '.device_code')
verification_uri_complete=$(echo $response | jq -r '.verification_uri_complete')
echo -e "\nNavigate to the following URL in your browser: ${verification_uri_complete}"
```

**Step 2 - Authorize via the provided URL**

Login as the `eoepca` user, that is a member of the `team-eoepca` group, and hence should receive zoo API access.

```bash
xdg-open "${verification_uri_complete}"
```

**Step 3 - Poll for token following user authorization**

```bash
response=$( \
  curl --silent --show-error \
    -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=oapip-engine" \
    -d "client_secret=${OAPIP_CLIENT_SECRET}" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    -d "device_code=${device_code}" \
    "https://auth-apx.${INGRESS_HOST}/realms/eoepca/protocol/openid-connect/token" \
)
access_token=$(echo $response | jq -r '.access_token')
refresh_token=$(echo $response | jq -r '.refresh_token')
id_token=$(echo $response | jq -r '.id_token')
```

The access token can then be used as `Authorization: Bearer` in requests to the `zoo` service APIs.

**Step 4 - (as required) Refresh the access token**

```bash
response=$( \
  curl --silent --show-error \
    -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=oapip-engine" \
    -d "client_secret=${OAPIP_CLIENT_SECRET}" \
    -d "grant_type=refresh_token" \
    -d "refresh_token=${refresh_token}" \
    "https://auth-apx.${INGRESS_HOST}/realms/eoepca/protocol/openid-connect/token" \
)
access_token=$(echo $response | jq -r '.access_token')
refresh_token=$(echo $response | jq -r '.refresh_token')
id_token=$(echo $response | jq -r '.id_token')
```

---

#### List Processes

Retrieve the list of available (currently deployed) processes.

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X GET "https://zoo-apx.${INGRESS_HOST}/eoepca/ogc-api/processes" \
  -H "Authorization: Bearer ${access_token}" \
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
  -X POST "https://zoo-apx.${INGRESS_HOST}/eoepca/ogc-api/processes" \
  -H "Authorization: Bearer ${access_token}" \
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
  -X GET "https://zoo-apx.${INGRESS_HOST}/eoepca/ogc-api/processes/convert-url" \
  -H "Authorization: Bearer ${access_token}" \
  -H "Accept: application/json" | jq
```

---

##### Deploy - `water-bodies`

Deploy the `water-bodies` app...

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X POST "https://zoo-apx.${INGRESS_HOST}/eoepca/ogc-api/processes" \
  -H "Authorization: Bearer ${access_token}" \
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
  -X GET "https://zoo-apx.${INGRESS_HOST}/eoepca/ogc-api/processes/water-bodies" \
  -H "Authorization: Bearer ${access_token}" \
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
    -X POST "https://zoo-apx.${INGRESS_HOST}/eoepca/ogc-api/processes/convert-url/execution" \
    -H "Authorization: Bearer ${access_token}" \
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
    -X POST "https://zoo-apx.${INGRESS_HOST}/eoepca/ogc-api/processes/water-bodies/execution" \
    -H "Authorization: Bearer ${access_token}" \
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
  -X GET "https://zoo-apx.${INGRESS_HOST}/ogc-api/jobs/${JOB_ID}" \
  -H "Authorization: Bearer ${access_token}" \
  -H "Accept: application/json" | jq
```

---

#### Check Execution Results

Similarly, once the job is completed successfully, then details of the results (outputs) can be retrieved.

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X GET "https://zoo-apx.${INGRESS_HOST}/ogc-api/jobs/${JOB_ID}/results" \
  -H "Authorization: Bearer ${access_token}" \
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
  -X DELETE "https://zoo-apx.${INGRESS_HOST}/eoepca/ogc-api/processes/convert-url" \
  -H "Authorization: Bearer ${access_token}" \
  -H "Accept: application/json" | jq
```

---

##### Undeploy - `water-bodies`

```bash
source ~/.eoepca/state
curl --silent --show-error \
  -X DELETE "https://zoo-apx.${INGRESS_HOST}/eoepca/ogc-api/processes/water-bodies" \
  -H "Authorization: Bearer ${access_token}" \
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

