# Workspace Deployment Guide

A **Workspace** is a self-service, isolated environment for data access and algorithm development, provisioned on Kubernetes via the **Workspace REST API** or **Workspace Web UI**.

---

## Introduction

The Workspace Building Block (BB) gives each user their own namespace with S3-compatible object storage and a persistent VSCode-based development environment (a "Datalab"), provisioned on request via a REST API and web UI.

The Workspace BB comprises the following components:

* **Workspace API and UI**

    A REST API and web UI for creating and deleting workspaces, backed by two Kubernetes Custom Resources it manages per workspace (below).

* **Storage Controller (provider-storage)**

    A Kubernetes Custom Resource responsible for creating and managing S3-compatible buckets (e.g., MinIO, AWS S3, or OTC OBS).

* **Datalab Controller (provider-datalab)**

    A Kubernetes Custom Resource used to deploy persistent VSCode-based environments with direct object-storage access, either directly on Kubernetes or within a vCluster.

* **Identity & Access (Keycloak)**

    Manages user and team identities, enabling role-based access control and granting permissions to specific Datalabs and storage resources.

The Workspace BB uses Crossplane to create and manage these resources, which requires deploying:

* **Dependencies** - CSI-RClone for storage mounting and the Educates framework for workspace environments.
* **Pipelines** - template and provision each workspace's storage, Datalab configuration, and environment settings.
* **Provider Configurations** - the Crossplane Providers this BB uses: MinIO, Kubernetes, Keycloak, and Helm.

---

## Prerequisites

Before deploying the Workspace Building Block, ensure you have the following:

| Component          | Requirement                                       | Documentation Link                                                |
| ------------------ | ------------------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.32)                         | [Installation Guide](../prerequisites/kubernetes.md)             |
| Helm               | Version 3.7 or newer                              | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access                     | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| TLS Certificates   | Managed via `cert-manager` or manually            | [TLS Certificate Management Guide](../prerequisites/tls.md) |
| APISIX Ingress Controller | Properly installed - the only ingress class this BB supports | [Installation Guide](../prerequisites/ingress/apisix.md)      |
| Crossplane         | Properly installed                                | [Installation Guide](../prerequisites/crossplane.md) |
| IAM Building Block | Deployed and running - the Workspace API always requires a Keycloak Bearer token, there is no auth-free mode | [IAM Deployment Guide](./iam/main-iam.md) |

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

* **S3 Credentials**: `S3_ENDPOINT`, `S3_REGION`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` for your S3-compatible storage.

* **`WORKSPACE_PIPELINE_CLIENT_ID`** and **`WORKSPACE_API_CLIENT_ID`**: Keycloak client IDs (defaults are fine) - see [step 9](#9-configure-iam-for-the-workspace-api) for what each of these controls. A client secret is generated automatically for the Workspace Pipeline client; the Workspace API client is public and has no secret.

* **`OIDC_WORKSPACE_ENABLED`**: whether to enable ingress-level login redirect and Datalab session SSO (default: `true`).

* **`KEYCLOAK_TEST_USER`**, **`KEYCLOAK_TEST_ADMIN`**, **`KEYCLOAK_TEST_PASSWORD`**: example user/admin usernames and shared password.


### 2. Apply Kubernetes Secrets

Run the script to create the necessary Kubernetes secrets.

```bash
bash apply-secrets.sh
```

### 3. Deploy Workspace Dependencies

The workspace dependencies include CSI-RClone for storage mounting and the Educates framework for workspace environments.

!!! warning
    The Educates chart bundles a set of Kyverno `ClusterPolicy` pod-security baseline/restricted policies (unconditionally, there is no values toggle to skip them) - Kyverno's CRDs must therefore already be installed before deploying Educates, or the `helm upgrade -i` below fails with `no matches for kind "ClusterPolicy"`.

```bash
# Deploy Kyverno (required by Educates' own bundled ClusterPolicies, and reused
# later for the optional TLS/IAM workarounds in sections 8.2 and 9.3)
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update kyverno
helm upgrade -i kyverno kyverno/kyverno \
  --version 3.6.2 \
  --namespace kyverno \
  --create-namespace

# Deploy CSI-RClone
helm upgrade -i workspace-dependencies-csi-rclone \
  oci://ghcr.io/eoepca/workspace/workspace-dependencies-csi-rclone \
  --version 2.2.0 \
  --namespace workspace

# Deploy Educates
helm upgrade -i workspace-dependencies-educates \
  oci://ghcr.io/eoepca/workspace/workspace-dependencies-educates \
  --version 2.2.0 \
  --namespace workspace \
  --values workspace-dependencies/educates-values.yaml
```

Educates gives every Datalab session's own registry component a per-session `Ingress`, but doesn't set an `ingressClassName` on it - so on an APISIX-only cluster it's created but never actually routable. Apply a Kyverno policy to fix this on every session:

```bash
kubectl apply -f workspace-dependencies/kyverno-registry-ingress-class.yaml
```

### 4. Deploy the Workspace API

```bash
helm repo add eoepca https://eoepca.github.io/helm-charts
helm repo update eoepca
helm upgrade -i workspace-api eoepca/rm-workspace-api \
  --version 2.2.2 \
  --namespace workspace \
  --values workspace-api/generated-values.yaml
```

!!! note
    The API isn't reachable yet - its route and Keycloak client are created in [step 9](#9-configure-iam-for-the-workspace-api).

### 5. Deploy the Workspace Pipeline

The Workspace Pipeline manages the templating and provisioning of resources within newly created workspaces.

```bash
helm upgrade -i workspace-pipeline \
  oci://ghcr.io/eoepca/workspace/workspace-pipeline \
  --version 2.2.0 \
  --namespace workspace \
  --values workspace-pipeline/generated-values.yaml
```

### 6. Deploy the DataLab Session Cleaner

Deploy a CronJob that automatically cleans up inactive DataLab sessions:

```bash
kubectl apply -f workspace-cleanup/datalab-cleaner.yaml
```

This runs daily at 8 PM UTC and stops every Datalab session (including `default`) - their configuration is preserved and each can be started again from the Datalabs UI.

---

### 7. Deploy Configurations for Crossplane Providers

#### 7.1. Provider Configurations

Each Crossplane provider used by the Workspace BB needs a `ProviderConfig` in the `workspace` namespace (the MinIO provider is the exception - already configured cluster-wide in the Crossplane prerequisites):

```bash
kubectl apply -f workspace-dependencies/provider-configs.yaml
```

#### 7.2. Keycloak Client for the Workspace Pipeline

The workspace pipeline needs its own Keycloak client, `workspace-pipeline`, so it can self-serve a Keycloak client/roles/groups for every workspace it provisions. This is required regardless of the ingress-level login redirect setting in [step 9](#9-configure-iam-for-the-workspace-api).

Look up the UUID of Keycloak's built-in `realm-management` client (adopted below, since role grants reference it and it isn't created by the IAM Building Block itself):

```bash
source ~/.eoepca/state
KEYCLOAK_ADMIN_TOKEN=$( \
  curl -X POST "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/master/protocol/openid-connect/token" \
    --silent --show-error \
    -d "client_id=admin-cli" -d "grant_type=password" \
    -d "username=${KEYCLOAK_ADMIN_USER}" --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    | jq -r '.access_token' \
)
export REALM_MANAGEMENT_CLIENT_UUID=$( \
  curl --silent --show-error -H "Authorization: Bearer ${KEYCLOAK_ADMIN_TOKEN}" \
    "${HTTP_SCHEME}://${KEYCLOAK_HOST}/admin/realms/${REALM}/clients?clientId=realm-management" \
    | jq -r '.[0].id' \
)
```

Render and apply the `workspace-pipeline` client, the adopted `realm-management` client, and the `realm-management` role grants it needs (`manage-users`, `manage-authorization`, `manage-clients`, `create-client`, and the composite `realm-admin` - required because the Keycloak Terraform provider Crossplane uses calls the realm's `serverinfo` admin endpoint on every connection, which only `realm-admin` can reach):

```bash
source ~/.eoepca/state
gomplate -f workspace-dependencies/pipeline-iam-template.yaml -o workspace-dependencies/generated-pipeline-iam.yaml
kubectl apply -f workspace-dependencies/generated-pipeline-iam.yaml
```

---

### 8. Configure TLS Certificates for Workspace Datalab

Each created Workspace includes a Datalab component that expects a `workspace-tls` secret in the `workspace` namespace, providing the TLS certificate for its ingress - this secret is automatically copied into each `ws-XXX` namespace created per workspace.

#### 8.1. Wildcard Certificate (recommended)

Follow [TLS Management](../prerequisites/tls.md#create-a-clusterissuer-for-lets-encrypt) (the DNS01 Challenge option) to create a `letsencrypt-dns01` `ClusterIssuer` for your DNS provider, then request the wildcard certificate that will back `workspace-tls`:

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
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

#### 8.2. Workaround: Per-Workspace Certificates

If a wildcard certificate isn't available, use a Kyverno policy (already deployed in [step 3](#3-deploy-workspace-dependencies)) to trigger a dedicated HTTP01 certificate for each Datalab session `Ingress` instead:

```bash
source ~/.eoepca/state
gomplate -f workspace-dependencies/workspace-ingress-policy-template.yaml -o workspace-dependencies/generated-workspace-ingress-policy.yaml
kubectl apply -f workspace-dependencies/generated-workspace-ingress-policy.yaml
```

!!! warning
    Matching is scoped to the `training.educates.dev/application: workshop` label (same selector as the IAM policy in [9.3](#93-optional-protect-datalab-sessions-with-keycloak-sso)), not an Ingress name pattern - each session also gets a separate registry `Ingress` (`training.educates.dev/application: registry`) that must not receive this annotation, or it races the real session Ingress for ownership of the shared `workspace-tls` Certificate and can leave it issued for the wrong host.

---

### 9. Configure IAM for the Workspace API

The Workspace API always validates a Bearer token audienced for the `workspace-api` client (`authMode: gateway` in the upstream chart has no auth-free option) - steps 9.1 and 9.2 are required regardless of `OIDC_WORKSPACE_ENABLED`. That setting only controls whether the ingress additionally redirects unauthenticated browser requests to Keycloak login (9.2), and whether Datalab sessions get Keycloak SSO (9.3).

!!! note
    Before starting, ensure you have followed the [IAM Deployment Guide](./iam/main-iam.md) and have a Keycloak instance running.

#### 9.1 Create Keycloak Client

Render and apply the `workspace-api` Keycloak client, with protocol mappers so its tokens carry an `aud` claim naming itself (the workspace-api app rejects tokens lacking this) and a `groups` claim (used to resolve workspace ownership/membership). This also creates an `admin` client role and a `workspace-admin` group granting it, with `KEYCLOAK_TEST_ADMIN` added as a member - the app itself checks this role (independent of any ingress-layer enforcement) to grant access across every workspace rather than just ones the caller owns:

```bash
source ~/.eoepca/state
gomplate -f workspace-api/iam-template.yaml -o workspace-api/generated-iam.yaml
kubectl apply -f workspace-api/generated-iam.yaml
```

#### 9.2 Create APISIX Route Ingress

```bash
kubectl apply -f workspace-api/generated-ingress.yaml
```

!!! note
    This route doesn't enforce an `admin` role at the ingress layer - any authenticated user can call the API, including creating and deleting workspaces (matches the current upstream baseline). The `admin` client role from [9.1](#91-create-keycloak-client) is still checked by the app itself: an admin can view/manage any workspace, not just ones they own. Further restricting who may create workspaces is left to you to add via an OPA policy on the `workspace-api-auth` route in `workspace-api/ingress-template.yaml`.

#### 9.3. Optional: Protect Datalab Sessions with Keycloak SSO

Only applies when `OIDC_WORKSPACE_ENABLED=true`. Session ingresses aren't otherwise IAM-protected - a Kyverno policy wraps every Datalab session `Ingress` with the same `workspace-api` OIDC client, so opening a session requires a valid Keycloak login.

Grant Kyverno permission to manage `ApisixPluginConfig` resources, then apply the session-protection policy:

```bash
kubectl apply -f workspace-dependencies/kyverno-rbac-apisixpluginconfig.yaml
kubectl apply -f workspace-dependencies/generated-workspace-session-iam-policy.yaml
```

!!! note
    Any authenticated user in the realm can then open a Datalab session. Restricting *which* users may do so is left as a further exercise (e.g. via an OPA policy), matching the `workspace-api-auth` route pattern above.

---

## Validation and Usage

> **Prefer a notebook?** Run `../../notebooks/run.sh` and open the <a href="http://localhost:8888/lab/tree/workspace/workspace.ipynb" target="_blank">Workspace notebook</a> at `http://localhost:8888`.

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

!!! note
    If `OIDC_WORKSPACE_ENABLED=true`, the ingress redirects to Keycloak login first - for example `eoepcaadmin` created earlier.

---

### Creating and Testing a Workspace

The Workspace API can be used to create a new workspace. Any authenticated user in the realm may do so (see the note in [9.2](#92-create-apisix-route-ingress)); we use the `eoepcaadmin` test user created during IAM setup.

#### 1. Obtain an Access Token as `eoepcaadmin`

Obtain an access token for the `eoepcaadmin` test user:

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

!!! note
    Both resources should show a `True` status for `SYNCED` and `READY` conditions. State can take a little time to be reached as Crossplane provisions the underlying resources.

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

!!! note
    The details of the `storage` and the `datalab` associated with the workspace are returned.

**Record the access key and secret from the response for S3 access**

!!! warning
    The bucket's S3 access key is a generated MinIO principal (e.g. `ws-eoepcauser-1`) - it is **not** the same as `KEYCLOAK_TEST_USER`, so it must be read from the API response rather than assumed.

```bash
source ~/.eoepca/state
WORKSPACE_DETAILS=$( \
  curl -X GET "${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}/workspaces/ws-${KEYCLOAK_TEST_USER}" \
    --silent --show-error \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
)
ACCESS_KEY=$(echo "$WORKSPACE_DETAILS" | jq -r '.storage.credentials.access')
SECRET=$(echo "$WORKSPACE_DETAILS" | jq -r '.storage.credentials.secret')
echo "S3 Access Key: ${ACCESS_KEY}"
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
  --access_key $ACCESS_KEY \
  --secret_key $SECRET
```

**Upload a Test File:**

!!! note
    Ensure you are in the directory `scripts/workspace` for access to the test file `validation.sh`.

```bash
source ~/.eoepca/state
s3cmd put validation.sh s3://ws-eoepcauser \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key $ACCESS_KEY \
  --secret_key $SECRET
```

**Check the Uploaded File:**

```bash
source ~/.eoepca/state
s3cmd ls s3://ws-eoepcauser \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key $ACCESS_KEY \
  --secret_key $SECRET
```

**Delete the Test File:**

```bash
source ~/.eoepca/state
s3cmd del s3://ws-eoepcauser/validation.sh \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key $ACCESS_KEY \
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

!!! note
    First time this may take a little time whilst the session is created.

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

Stop the port-forwarding (<kbd>Ctrl-C</kbd> in the terminal) and delete the test resources:

```bash
kubectl delete -f nginx-test.yaml
```

#### 8. (optional) Delete Workspace via the Workspace API

!!! tip
    The test workspace can be retained for additional testing, but if you wish to clean up the resources created during validation, you can delete the workspace.

The workspace for the `eoepcauser` test user can be deleted via the Workspace API, using any authenticated user (e.g. `eoepcaadmin`).

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

!!! warning
    Delete any workspaces created during validation first (see [step 8 of Validation](#8-optional-delete-workspace-via-the-workspace-api)). Removing the `workspace-pipeline` Keycloak client below before a workspace's own Keycloak resources have been cleaned up leaves them orphaned, since Crossplane can no longer authenticate to delete them from Keycloak.

To uninstall the Workspace Building Block and clean up associated resources:

```bash
source ~/.eoepca/state
kubectl delete ClusterPolicy/workspace-session-iam --ignore-not-found
kubectl delete -f workspace-dependencies/kyverno-rbac-apisixpluginconfig.yaml --ignore-not-found
kubectl delete -f workspace-dependencies/kyverno-registry-ingress-class.yaml
kubectl delete -f workspace-api/generated-ingress.yaml
kubectl delete -f workspace-api/generated-iam.yaml
kubectl delete -f workspace-dependencies/generated-workspace-ingress-policy.yaml --ignore-not-found
kubectl delete secret/workspace-tls -n workspace
kubectl delete -f workspace-dependencies/generated-pipeline-iam.yaml
kubectl delete secret/workspace-pipeline-client -n workspace
kubectl delete secret/workspace-pipeline-keycloak-client -n iam-management
kubectl delete -f workspace-dependencies/provider-configs.yaml
kubectl delete -f workspace-cleanup/datalab-cleaner.yaml
helm uninstall workspace-pipeline -n workspace
helm uninstall workspace-api -n workspace
helm uninstall workspace-dependencies-educates -n workspace
helm uninstall workspace-dependencies-csi-rclone -n workspace
kubectl delete namespace workspace
# Only remove Kyverno if no other Building Block on the cluster relies on it
helm uninstall kyverno -n kyverno
kubectl delete namespace kyverno
```

---

## Further Reading

- [EOEPCA+ Workspace GitHub Repository](https://github.com/EOEPCA/workspace)
- [Crossplane Documentation](https://crossplane.io/docs/)
- [Educates Documentation](https://docs.educates.dev/)
- [CSI-RClone Documentation](https://github.com/wunderio/csi-rclone)
