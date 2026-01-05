# Workspace Deployment Guide

**Workspaces** enable individuals, teams, and organisations to provision isolated, self-service environments for data access, algorithm development, and collaborative exploration — all declaratively managed on Kubernetes and orchestrated through the **Workspace REST API** or via the **Workspace Web UI**.

---

## Introduction

The Workspace Building Block (BB) provides a unified environment that combines object storage, interactive runtimes, and collaborative tooling into a single Kubernetes-native platform.

The Workspace BB comprises the following key components:

* **Workspace API and UI**

    Orchestrate storage, runtime, and tooling resources via a unified REST API by managing the underlying Kubernetes Custom Resources (CRs).

* **Storage Controller (provider-storage)**

    A Kubernetes Custom Resource responsible for creating and managing S3-compatible buckets (e.g., MinIO, AWS S3, or OTC OBS).

* **Datalab Controller (provider-datalab)**

    A Kubernetes Custom Resource used to deploy persistent VSCode-based environments with direct object-storage access — either directly on Kubernetes or within a vCluster — preconfigured with essential services and tools.

* **Identity & Access (Keycloak)**

    Manages user and team identities, enabling role-based access control and granting permissions to specific Datalabs and storage resources.

The Workspace BB relies upon Crossplane to manage the creation and lifecycle of the resources that deliver these capabilities. This requires the deployment of:

* **Dependencies**, including CSI-RClone for storage mounting and the Educates framework for workspace environments.
* **Pipelines**, which manage the templating and provisioning of workspace resources, including storage, datalab configurations, and environment settings.
* **Provider Configurations**, that support the usage of specific Crossplane Providers such as MinIO, Kubernetes, Keycloak, and Helm.

---

## Prerequisites

Before deploying the Workspace Building Block, ensure you have the following:

| Component          | Requirement                                       | Documentation Link                                                |
| ------------------ | ------------------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.32)                         | [Installation Guide](../prerequisites/kubernetes.md)             |
| Helm               | Version 3.7 or newer                              | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access                     | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| TLS Certificates   | Managed via `cert-manager` or manually            | [TLS Certificate Management Guide](../prerequisites/tls.md) |
| APISIX Ingress Controller | Properly installed                         | [Installation Guide](../prerequisites/ingress/overview.md#apisix-ingress-controller)      |
| Crossplane         | Properly installed                                | [Installation Guide](../prerequisites/crossplane.md) |

**Clone the Deployment Guide Repository:**

```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/workspace
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script

```bash
bash configure-workspace.sh
```

**Configuration Parameters**

During the script execution, you will be prompted to provide:

* **`INGRESS_HOST`**: Base domain for ingress hosts.

    *Example*: `example.com`

* **`CLUSTER_ISSUER`**: Cert-Manager ClusterIssuer for TLS certificates.

    *Example*: `letsencrypt-http01-apisix`

* **S3 Credentials**
  
    Endpoint, region, access key, and secret key for your S3-compatible storage.

* **OIDC Configuration**

    You will be prompted to provide whether you wish to enable OIDC authentication. If you choose to enable OIDC, ensure that you follow the steps in the OIDC Configuration section after deployment.

    For instructions on how to set up IAM, you can follow the [IAM Building Block](./iam/main-iam.md) guide.


### 2. Apply Kubernetes Secrets

Run the script to create the necessary Kubernetes secrets.

```bash
bash apply-secrets.sh
```

### 3. Deploy Workspace Dependencies

The workspace dependencies include CSI-RClone for storage mounting and the Educates framework for workspace environments.

```bash
# Deploy CSI-RClone
helm upgrade -i workspace-dependencies-csi-rclone \
  oci://ghcr.io/eoepca/workspace/workspace-dependencies-csi-rclone \
  --version 2.0.0-rc.12 \
  --namespace workspace

# Deploy Educates
helm upgrade -i workspace-dependencies-educates \
  oci://ghcr.io/eoepca/workspace/workspace-dependencies-educates \
  --version 2.0.0-rc.12 \
  --namespace workspace \
  --values workspace-dependencies/educates-values.yaml
```

### 4. Deploy the Workspace API

```bash
helm repo add eoepca https://eoepca.github.io/helm-charts
helm repo update eoepca
helm upgrade -i workspace-api eoepca/rm-workspace-api \
  --version 2.0.0-rc.7 \
  --namespace workspace \
  --values workspace-api/generated-values.yaml \
  --set image.tag=2.0.0-rc.8
```

> Ingress is currently only available via APISIX routes, if you have not enabled OIDC, you will need to port-forward to access the API for now. 
> If you have enabled OIDC, we will set up the APISIX route/ingress in later steps.

### 5. Deploy the Workspace Pipeline

The Workspace Pipeline manages the templating and provisioning of resources within newly created workspaces.

```bash
helm upgrade -i workspace-pipeline \
  oci://ghcr.io/eoepca/workspace/workspace-pipeline \
  --version 2.0.0-rc.12 \
  --namespace workspace \
  --values workspace-pipeline/generated-values.yaml
```

### 6. Deploy the DataLab Session Cleaner

Deploy a CronJob that automatically cleans up inactive DataLab sessions:

```bash
kubectl apply -f workspace-cleanup/datalab-cleaner.yaml
```

This runs daily at 8 PM UTC and removes all sessions except the default ones.

### 9. Deploy the Workspace Admin Dashboard

The Kubernetes Dashboard provides a web-based interface for managing Kubernetes resources.

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update kubernetes-dashboard
helm upgrade -i workspace-admin kubernetes-dashboard/kubernetes-dashboard \
  --version 7.10.1 \
  --namespace workspace \
  --values workspace-admin/generated-values.yaml
```

> There is currently no ingress set up for the Workspace Admin Dashboard. To access it, you can use port-forwarding. For example:
> ```bash
> kubectl -n workspace port-forward svc/workspace-admin-web 8000
> ```
> Then access it at `http://localhost:8000/`.

---

### 8. Deploy Configurations for Crossplane Providers

#### 8.1. Provider Configurations

The Workspace BB uses several Crossplane providers to manage resources - each of which requires a corresponding ProviderConfig to be deployed in the `workspace` namespace. The exception is the MinIO provider, which requires a cluster-wide ProviderConfig.

* _**MinIO Provider**, for S3-compatible storage_<br>
  > Cluster-wide configuration already applied in the Crossplane prerequisites.
* **Kubernetes Provider**, for managing Kubernetes resources
* **Keycloak Provider**, for IAM integration
* **Helm Provider**, for deploying Helm charts within workspaces

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kubernetes.m.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: provider-kubernetes
  namespace: workspace
spec:
  credentials:
    source: InjectedIdentity
---
apiVersion: keycloak.m.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: provider-keycloak
  namespace: workspace
spec:
  credentialsSecretRef:
    name: workspace-pipeline-client
    key: credentials
---
apiVersion: helm.m.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: provider-helm
  namespace: workspace  
spec:
  credentials:
    source: InjectedIdentity
EOF
```

#### 8.2. Create the Keycloak Client for Crossplane Keycloak Provider

Create a Keycloak client for the Crossplane Keycloak provider to allow it to interface with Keycloak. We create the client `workspace-pipeline`, which is used by the workspace pipelines to perform administrative actions against the Keycloak API to properly protect newly created workspaces.

##### 8.2.1. Create the Keycloak Client

The client is created via the Crossplane `Client` CRD using the Keycloak Provider offered by the `iam-management` namespace. This bootstraps the ability of the Workspace to self-serve its own Keycloak resources for workspace isolation.

To this end we create:

* In namespace `iam-management`:
    * A Keycloak client `workspace-pipeline` with appropriate `realm-management` roles.
    * A Kubernetes secret `workspace-pipeline-keycloak-client` containing the client secret supporting client creation.
* In namespace `workspace`:
    * A Kubernetes secret `workspace-pipeline-client` containing the client credentials for the Crossplane Keycloak provider.

**Create the `workspace-pipeline` Keycloak client**

This relies upon the Keycloak Provider in the `iam-management` namespace.

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
# Secret providing client_secret for Client creation.
apiVersion: v1
kind: Secret
metadata:
  name: workspace-pipeline-keycloak-client
  namespace: iam-management
stringData:
  client_secret: "${WORKSPACE_PIPELINE_CLIENT_SECRET}"
---
# Create the Keycloak Client
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: "${WORKSPACE_PIPELINE_CLIENT_ID}"
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    clientId: ${WORKSPACE_PIPELINE_CLIENT_ID}
    name: Workspace Pipelines
    description: Workspace Pipelines Admin
    enabled: true
    accessType: CONFIDENTIAL
    rootUrl: ${HTTP_SCHEME}://workspace-pipeline.${INGRESS_HOST}
    baseUrl: ${HTTP_SCHEME}://workspace-pipeline.${INGRESS_HOST}
    adminUrl: ${HTTP_SCHEME}://workspace-pipeline.${INGRESS_HOST}
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
      name: workspace-pipeline-keycloak-client
      key: client_secret
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

**Client credentials for the Workspace-dedicated Keycloak Provider**

Create the secret with the client credentials for the _Crossplane Keycloak Provider_ in the `workspace` namespace.

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
# Secret providing credentials for Crossplane Keycloak Provider.
apiVersion: v1
kind: Secret
metadata:
  name: workspace-pipeline-client
  namespace: workspace
stringData:
  credentials: |
    {
      "client_id": "${WORKSPACE_PIPELINE_CLIENT_ID}",
      "client_secret": "${WORKSPACE_PIPELINE_CLIENT_SECRET}",
      "url": "http://iam-keycloak.iam",
      "base_path": "",
      "realm": "${REALM}"
    }
EOF
```

##### 8.2.2. Add the realm management roles to the Client

The `workspace-pipeline` client requires specific `realm-management` roles to perform administrative actions against Keycloak - namely: `manage-users`, `manage-authorization`, `manage-clients`, and `create-client`.

We can add the required roles to the `workspace-pipeline` client.

> Note this is actually modelled as a specific Custom Resource for each role assignment.

```bash
source ~/.eoepca/state
for role in manage-users manage-authorization manage-clients create-client; do
cat <<EOF | kubectl apply -f -
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: ClientServiceAccountRole
metadata:
  name: workspace-pipeline-client-${role}
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    serviceAccountUserClientIdRef:
      name: ${WORKSPACE_PIPELINE_CLIENT_ID}
      namespace: iam-management
    clientIdRef:
      name: realm-management
      namespace: iam-management
    role: ${role}
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
done
```

> Note that the above relies upon the `realm-management` client that was established [during IAM BB deployment](./iam/main-iam.md#53-create-realm-management-client).

---

### 9. Configure TLS Certificates for Workspace Datalab

The default Workspace pipelines include, within each created Workspace, a Datalab component. This is configured to expect the secret `workspace-tls` that is used to provide the TLS Certificate for each workspace ingress.

The deployment anticipates the use of a wildcard certificate that is reused for each created workspace. Thus, the `workspace-tls` secret is created in the `workspace` namespace, from where it is automatically copied to each `ws-XXX` namespace that is created for each instantiated workspace.

Section [`Wildcard Certificate Generation`](#91-wildcard-certificate-generation) below provides an illustration of wildcard certificate generation using _Cert Manager_. This can be adapted for your DNS provider.

Section [`Workspace Certificate Workaround`](#92-workspace-certificate-workaround) below provides a workaround, in the case that your are unable to obtain a wildcard certificate.

#### 9.1. Wildcard Certificate Generation

This approach relies upon a `Certificate` resource with the wildcard DNS name `*.${INGRESS_HOST}`. In order for this to be satisfied it is necessary to use a `ClusterIssuer` that uses the `DNS01` solver.

**Create `ClusterIssuer`**

The following illustrates an example that uses Cloudflare DNS provider.

> Set your email address in the resource definition.

```bash
cat - <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns01
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: <your-email-address>
    privateKeySecretRef:
      name: letsencrypt-dns01
    solvers:
      - dns01:
           cloudflare:
              apiTokenSecretRef:
                 key: api-token
                 name: cloudflare-api-token
EOF
```

For other supported DNS providers see the [Cert Manager DNS01 Documentation](https://cert-manager.io/docs/configuration/acme/dns01/).

**Cloudflare Credentials `Secret`**

Create the secret `cloudflare-api-token` (as per above) with your Cloudflare API token.

> Set your API token in the resource definition.

```bash
cat - <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
stringData:
  api-token: <your-api-token>
EOF
```

**Create Wildcard `Certificate`**

Now the `DNS01` cluster issuer is in place we can create the `Certificate` to generate the `workspace-tls` secret.

```bash
source ~/.eoepca/state
cat - <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: workspace-tls
  namespace: workspace
spec:
  secretName: workspace-tls
  issuerRef:
    name: letsencrypt-dns01
    kind: ClusterIssuer
  dnsNames:
    - "*.${INGRESS_HOST}"
EOF
```

In response, Cert Manager should trigger the certificate request via DNS01 - resulting in the `workspace-tls` secret. This secret is then available 

#### 9.2. Workspace Certificate Workaround

In case you are unable to provision a reusable wildcard certificate as described above then, as a workaround, we can modify the `Ingress` definition of each workspace to instead trigger its own dedicated certificate generation.

This approach involves using a _Mutating Admission Policy_ to patch the `Ingress` resource with appropriate annotations to integrate with Cert Manager.

**Deploy Kyverno**

The approach relies upon _Kyverno Policy Engine_ - which is also referenced in section [Suppress Resource Requests](../prerequisites/kubernetes.md#suppress-resource-requests).

If not already deployed, install _Kyverno_ using helm...

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update kyverno
helm upgrade -i kyverno kyverno/kyverno \
  --version 3.4.1 \
  --namespace kyverno \
  --create-namespace
```

**Workspace Ingress Policy**

Then we apply a policy that patches any `Ingress` resource in namespaces matching the `ws-` prefix used for workspaces. The patch adds annotations that are relevant to the Apisix Ingress Controller, and specifically adds the annotation `cert-manager.io/cluster-issuer` to trigger `Certificate` generation.

```bash
source ~/.eoepca/state
cat - <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: workspace-ingress
spec:
  rules:
    - name: workspace-ingress-annotations
      match:
        resources:
          kinds:
            - Ingress
          name: "ws-*"
      mutate:
        patchStrategicMerge:
          metadata:
            annotations:
              +(cert-manager.io/cluster-issuer): "${CLUSTER_ISSUER}"
              +(apisix.ingress.kubernetes.io/use-regex): "true"
              +(ingress.kubernetes.io/force-ssl-redirect): "true"
              +(k8s.apisix.apache.org/enable-cors): "true"
              +(k8s.apisix.apache.org/enable-websocket): "true"
              +(k8s.apisix.apache.org/http-to-https): "true"
              +(k8s.apisix.apache.org/upstream-read-timeout): 3600s
EOF
```

---

### 10. Optional: Enable OIDC with Keycloak

If you **do not** wish to use OIDC/IAM right now, you can skip these steps and proceed directly to the [Validation](#validation) section.

If you **do** want to protect endpoints with IAM policies (i.e. require Keycloak tokens, limit access by groups/roles, etc.) **and** you enabled `OIDC` in the configuration script then follow these steps. You will create a new client in Keycloak and optionally define resource-protection rules (e.g. restricting who can list jobs).

> Before starting this please ensure that you have followed our [IAM Deployment Guide](./iam/main-iam.md) and have a Keycloak instance running.

#### 10.1 Create Keycloak Client

A Keycloak client is required for the ingress protection of the Workspace API. The client can be created using the Crossplane Keycloak provider via the `Client` CRD.

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${WORKSPACE_API_CLIENT_ID}-keycloak-client
  namespace: iam-management
stringData:
  client_secret: ${WORKSPACE_API_CLIENT_SECRET}
---
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: ${WORKSPACE_API_CLIENT_ID}
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    clientId: ${WORKSPACE_API_CLIENT_ID}
    name: Workspace API
    description: Workspace API OIDC
    enabled: true
    accessType: CONFIDENTIAL
    rootUrl: ${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}
    baseUrl: ${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}
    adminUrl: ${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}
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
      name: ${WORKSPACE_API_CLIENT_ID}-keycloak-client
      key: client_secret
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

#### 10.2 Create APISIX Route Ingress

Apply the APISIX route ingress:

```bash
kubectl apply -f workspace-api/generated-ingress.yaml
```

#### 10.3. Assign `admin` role to the _Test Admin User_

The above `ApisixRoute` ingress enforces this [OPA policy](https://github.com/EOEPCA/iam-policies/blob/main/policies/eoepca/workspace/wsapi.rego) - which requires users to have the `admin` role in order to access certain endpoints (e.g. workspace creation).

First we create the `admin` role in the `workspace-api` Keycloak client...`

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: role.keycloak.m.crossplane.io/v1alpha1
kind: Role
metadata:
  name: ${WORKSPACE_API_CLIENT_ID}-admin
  namespace: iam-management
spec:
  forProvider:
    name: admin
    realmId: ${REALM}
    clientIdRef:
      name: ${WORKSPACE_API_CLIENT_ID}
    description: "Admin role for ${WORKSPACE_API_CLIENT_ID} client"
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

Then we assign the `admin` role to our test admin user (e.g. `eoepcaadmin`):

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: user.keycloak.m.crossplane.io/v1alpha1
kind: Roles
metadata:
  name: ${KEYCLOAK_TEST_ADMIN}-${WORKSPACE_API_CLIENT_ID}-admin
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    userIdRef:
      name: ${KEYCLOAK_TEST_ADMIN}
    roleIdsRefs:
      - name: ${WORKSPACE_API_CLIENT_ID}-admin
    exhaustive: false
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

---

## Validation and Usage

After deploying the Workspace Building Block, you can validate and interact with it through a series of checks and tests described below.

### Automated Validation

To run automated checks:

```bash
bash validation.sh
```

If all checks pass, your Workspace BB deployment is functioning as expected.

---

### Manual Validation Steps

#### 1. Check Kubernetes Resources

List all resources in the `workspace` namespace:

```bash
kubectl get all -n workspace
```

Confirm that all pods are `Running` and no errors are reported.

#### 2. Access the Workspace API Swagger Documentation

You can view the Workspace API's Swagger documentation at:

```bash
source ~/.eoepca/state
xdg-open "https://workspace-api.${INGRESS_HOST}/docs"
```

Replace `${INGRESS_HOST}` with your configured ingress host domain.

> NOTE that the ingress integrates with IAM via OIDC, and so expects an authenticated user - for example `eoepcaadmin` created earlier.

---

### Creating and Testing a Workspace

The Workspace API can be used to create a new workspace. In accordance with the `ApisixRoute` ingress and associated OPA policies, the user must have the `admin` role in order to create workspaces.

#### 1. Obtain an Access Token as `eoepcaadmin`

`eoepcaadmin` was registered earlier as a Workspace `admin` user. Obtain an access token for this user:

```bash
source ~/.eoepca/state
# Authenticate as test admin `eoepcaadmin`
ACCESS_TOKEN=$( \
  curl -X POST "${HTTP_SCHEME}://auth.${INGRESS_HOST}/realms/${REALM}/protocol/openid-connect/token" \
    --silent --show-error \
    -d "username=${KEYCLOAK_TEST_ADMIN}" \
    --data-urlencode "password=${KEYCLOAK_TEST_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=${WORKSPACE_API_CLIENT_ID}" \
    -d "client_secret=${WORKSPACE_API_CLIENT_SECRET}" \
    | jq -r '.access_token' \
)
echo "Access Token: ${ACCESS_TOKEN:0:20}..."
```

#### 2. Create a New Workspace via the Workspace API

Create a new workspace for the test user `eoepcauser`.

```bash
source ~/.eoepca/state
curl -X POST "${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}/workspaces" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
  "preferred_name": "${KEYCLOAK_TEST_USER}",
  "default_owner": "${KEYCLOAK_TEST_USER}"
}
EOF
```

#### 3. Check Workspace Creation

**Namespace**

Check creation of new namespace for the workspace.

```bash
source ~/.eoepca/state
kubectl get ns ws-${KEYCLOAK_TEST_USER}
```

**Custom Resources**

Check creation of the `Storage` Custom Resource for the workspace.

```bash
source ~/.eoepca/state
kubectl get storage/ws-${KEYCLOAK_TEST_USER} -n workspace
```

Check creation of the `Datalab` Custom Resource for the workspace.

```bash
source ~/.eoepca/state
kubectl get datalab/ws-${KEYCLOAK_TEST_USER} -n workspace
```

> Both resources should show a `True` status for `SYNCED` and `READY` conditions.<br>
> Note that state can take a little time to be reached as Crossplane provisions the underlying resources.

#### 4. Get New Workspace Details

**Authenticate as `eoepcauser` - the owner of the newly created workspace**

```bash
source ~/.eoepca/state
ACCESS_TOKEN=$( \
  curl -X POST "${HTTP_SCHEME}://auth.${INGRESS_HOST}/realms/${REALM}/protocol/openid-connect/token" \
    --silent --show-error \
    -d "username=${KEYCLOAK_TEST_USER}" \
    --data-urlencode "password=${KEYCLOAK_TEST_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=${WORKSPACE_API_CLIENT_ID}" \
    -d "client_secret=${WORKSPACE_API_CLIENT_SECRET}" \
    | jq -r '.access_token' \
)
echo "Access Token: ${ACCESS_TOKEN:0:20}..."
```

**Call the Workspace API to get details for the newly created workspace**

```bash
source ~/.eoepca/state
curl -X GET "${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}/workspaces/ws-${KEYCLOAK_TEST_USER}" \
  --silent --show-error \
  -H "Accept: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  | jq
```

> The details of the `storage` and the `datalab` associated with the workspace are returneed.

**Record the secret from the response for S3 access**

```bash
source ~/.eoepca/state
SECRET=$( \
  curl -X GET "${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}/workspaces/ws-${KEYCLOAK_TEST_USER}" \
    --silent --show-error \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    | jq -r '.storage.credentials.secret'
)
echo "S3 Secret: ${SECRET}"
```

#### 5. S3 Bucket Access

Use `s3cmd` (configured via `source ~/.eoepca/state`) to list and manipulate objects in the workspace's S3 buckets.

**List Buckets:**

```bash
source ~/.eoepca/state
s3cmd ls \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ${KEYCLOAK_TEST_USER} \
  --secret_key $SECRET
```

**Upload a Test File:**

> Ensure you are in the directory `scripts/workspace` for access to the test file `validation.sh`.

```bash
source ~/.eoepca/state
s3cmd put validation.sh s3://ws-eoepcauser \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ${KEYCLOAK_TEST_USER} \
  --secret_key $SECRET
```

**Check the Uploaded File:**

```bash
source ~/.eoepca/state
s3cmd ls s3://ws-eoepcauser \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ${KEYCLOAK_TEST_USER} \
  --secret_key $SECRET
```

**Delete the Test File:**

```bash
source ~/.eoepca/state
s3cmd del s3://ws-eoepcauser/validation.sh \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ${KEYCLOAK_TEST_USER} \
  --secret_key $SECRET
```

#### 6. Datalabs UI

Open the web UI for the created workspace.

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}/workspaces/ws-${KEYCLOAK_TEST_USER}"
```

The home page for `Workspace: ws-eoepcauser` opens.

Select `Datalab (default)` to open the default session. This opens a new window with the Datalabs session.

> First time this may take a little time whilst the session is created.

Navigate between each of the tabs:

* **Terminal**<br>
  _Provides a terminal within the session._
* **Editor**<br>
  _Provides a `vscode` style editor._
* **Data**<br>
  _Provides a file browser onto the object storage bucket(s) the user has access to._

#### 7. Workspace vCluster

If the workspace was created with a vCluster-enabled Datalab, you can access the vCluster from within the Datalab terminal and VS Code (`Editor`) environments. Kubernetes tooling such as `kubectl` and `helm` are pre-installed within the Datalab environment.

##### Explore vCluster Access via `Terminal`

In the `Terminal` tab, you can verify access to the vCluster by running:

```bash
kubectl get pods -A
```

You should see (at minimum) the `kube-system` pods of the vCluster.

##### Create a Custom Workload via `Editor`

Using the `Editor` tab we can use the web IDE to create and apply some Kubernetes yaml within the vCluster.

Open the terminal view with the key sequence <kbd>Ctrl-`</kbd> (backtick).

Create the new file `nginx-test.yaml` with the following content:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  labels:
    app: nginx-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
        - name: nginx-test
          image: nginx
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test
  labels:
    app: nginx-test
spec:
  selector:
    app: nginx-test
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
```

Deploy the test nginx deployment and service to the vCluster:

```bash
kubectl apply -f nginx-test.yaml
```

> deployment.apps/nginx-test created<br>
> service/nginx-test created

Check the deployment is running:

```bash
kubectl get svc,deploy,pods -l app=nginx-test
```

Once running, you can port-forward and use the VS Code Ports tab to connect with the nginx service:

```bash
kubectl port-forward svc/nginx-test 5000:80
```

VS Code automatically detects the forwarded port and adds it to the `Ports` tab - exposed via the URL `https://editor-ws-<username>-default.<ingress-host>/proxy/5000/`.

Open the forwarded port by following the link in the `Ports` tab or open directly.

Cleanup test resources...

Stop the port-forwarding (<kbd>Ctrl-C</kbd> in the terminal) and delete the test resources:

```bash
kubectl delete -f nginx-test.yaml
```

#### 8. (optional) Delete Workspace via the Workspace API

> The test workspace can be retained for additional testing, but if you wish to clean up the resources created during validation, you can delete the workspace.

The workspace for the `eoepcauser` test user can be deleted via the Workspace API.

This must be performed by a workspace `admin` user (e.g. `eoepcaadmin`).

**Authenticate as `eoepcaadmin`**

```bash
source ~/.eoepca/state
ACCESS_TOKEN=$( \
  curl -X POST "${HTTP_SCHEME}://auth.${INGRESS_HOST}/realms/${REALM}/protocol/openid-connect/token" \
    --silent --show-error \
    -d "username=${KEYCLOAK_TEST_ADMIN}" \
    --data-urlencode "password=${KEYCLOAK_TEST_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=${WORKSPACE_API_CLIENT_ID}" \
    -d "client_secret=${WORKSPACE_API_CLIENT_SECRET}" \
    | jq -r '.access_token' \
)
echo "Access Token: ${ACCESS_TOKEN:0:20}..."
```

**Delete the workspace**

```bash
source ~/.eoepca/state
curl -X DELETE "${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}/workspaces/ws-${KEYCLOAK_TEST_USER}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

---

## Uninstallation

To uninstall the Workspace Building Block and clean up associated resources:

```bash
source ~/.eoepca/state
kubectl delete roles.user.keycloak.m.crossplane.io/${KEYCLOAK_TEST_ADMIN}-${WORKSPACE_API_CLIENT_ID}-admin -n iam-management
kubectl delete role.role.keycloak.m.crossplane.io/${WORKSPACE_API_CLIENT_ID}-admin -n iam-management
kubectl delete -f workspace-api/generated-ingress.yaml
kubectl delete client.openidclient.keycloak.m.crossplane.io/${WORKSPACE_API_CLIENT_ID} -n iam-management
kubectl delete secret/${WORKSPACE_API_CLIENT_ID}-keycloak-client -n iam-management
kubectl delete ClusterPolicy/workspace-ingress
kubectl delete secret/workspace-tls -n workspace
for role in manage-users manage-authorization manage-clients create-client; do
  kubectl delete ClientServiceAccountRole.openidclient.keycloak.m.crossplane.io/workspace-pipeline-client-${role} -n iam-management
done
kubectl delete client.openidclient.keycloak.m.crossplane.io/${WORKSPACE_PIPELINE_CLIENT_ID} -n iam-management
kubectl delete secret/workspace-pipeline-client -n workspace
kubectl delete secret/workspace-pipeline-keycloak-client -n iam-management
kubectl delete providerconfig.kubernetes.m.crossplane.io/provider-kubernetes -n workspace
kubectl delete providerconfig.keycloak.m.crossplane.io/provider-keycloak -n workspace
kubectl delete providerconfig.helm.m.crossplane.io/provider-helm -n workspace
helm uninstall workspace-admin -n workspace
kubectl delete -f workspace-cleanup/datalab-cleaner.yaml
helm uninstall workspace-pipeline -n workspace
helm uninstall workspace-api -n workspace
helm uninstall workspace-dependencies-educates -n workspace
helm uninstall workspace-dependencies-csi-rclone -n workspace
kubectl delete namespace workspace
```

---

## Further Reading

- [EOEPCA+ Workspace GitHub Repository](https://github.com/EOEPCA/workspace)
- [Crossplane Documentation](https://crossplane.io/docs/)
- [Educates Documentation](https://docs.educates.dev/)
- [CSI-RClone Documentation](https://github.com/wunderio/csi-rclone)
- [Kubernetes Dashboard Documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)