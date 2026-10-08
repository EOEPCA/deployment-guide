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

First time running a script? [EOEPCA+ State](../prerequisites/state.md) covers the shared setup questions asked before this one.

**Configuration Parameters**

During the script execution, you will be prompted to provide:

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
    The Educates chart bundles Kyverno `ClusterPolicy` resources, so Kyverno must be installed before it - otherwise the `helm upgrade -i` below fails with `no matches for kind "ClusterPolicy"`.

```bash
# Kyverno is required by Educates, and by the policies in sections 8.2 and 9.3.
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update kyverno
helm upgrade -i kyverno kyverno/kyverno \
  --version 3.7.2 \
  --namespace kyverno \
  --create-namespace \
  --set backgroundController.enabled=true \
  --wait --timeout=5m

# Deploy CSI-RClone
helm upgrade -i workspace-dependencies-csi-rclone \
  oci://ghcr.io/eoepca/workspace/workspace-dependencies-csi-rclone \
  --version 2.2.1 \
  --namespace workspace

# Deploy Educates
helm upgrade -i workspace-dependencies-educates \
  oci://ghcr.io/eoepca/workspace/workspace-dependencies-educates \
  --version 2.2.1 \
  --namespace workspace \
  --values workspace-dependencies/educates-values.yaml
```

Educates does not set an `ingressClassName` on the per-session registry `Ingress`, so APISIX never routes it. Apply a Kyverno policy that sets it on every session:

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
  --version 2.2.1 \
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

Render and apply the `workspace-pipeline` client and grant it the roles it needs on Keycloak's built-in `realm-management` client: `manage-users`, `manage-authorization`, `manage-clients`, `create-client` and `realm-admin`. The built-in client is adopted read-only, by its client ID.

```bash
source ~/.eoepca/state
gomplate -f workspace-dependencies/pipeline-iam-template.yaml -o workspace-dependencies/generated-pipeline-iam.yaml
kubectl apply -f workspace-dependencies/generated-pipeline-iam.yaml
```

---

### 8. Configure TLS Certificates for Workspace Datalab

Each created Workspace includes a Datalab component that expects a `workspace-tls` secret in the `workspace` namespace, providing the TLS certificate for its ingress - this secret is automatically copied into each `ws-XXX` namespace created per workspace.

!!! warning
    Create this secret before the first workspace. APISIX drops an `Ingress` whose TLS secret is missing, so a Datalab session without `workspace-tls` returns `404 Route Not Found`.

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

#### 8.3. Manually-Provided Certificate

Without `cert-manager`, create the secret from a certificate and key you already hold. It must cover the Datalab session hostnames under `*.${INGRESS_HOST}`:

```bash
kubectl -n workspace create secret tls workspace-tls \
  --cert=/path/to/tls.crt \
  --key=/path/to/tls.key
```

---

### 9. Configure IAM for the Workspace API

The Workspace API always validates a Bearer token audienced for the `workspace-api` client.

#### 9.1 Create Keycloak Client

Render and apply the `workspace-api` Keycloak client. Its protocol mappers add the `aud` and `groups` claims that the Workspace API requires in a token.

This also creates an `admin` client role, and a `workspace-admin` group holding it with `KEYCLOAK_TEST_ADMIN` as a member. Members of that group can manage every workspace, not only their own.

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
    Any authenticated realm user can call the API, including creating and deleting workspaces. To restrict this further, add an OPA policy to the `workspace-api-auth` route in `workspace-api/ingress-template.yaml`.

#### 9.3. Optional: Protect Datalab Sessions with Keycloak SSO

Only applies when `OIDC_WORKSPACE_ENABLED=true`. A Kyverno policy adds Keycloak login and the IAM OPA policy `eoepca/workspace/wsui` to each Datalab session ingress. The public `workspace-api` client uses PKCE for browser login.

Grant Kyverno permission to manage `ApisixPluginConfig` resources, then apply the session-protection policy:

```bash
kubectl apply -f workspace-dependencies/kyverno-rbac-apisixpluginconfig.yaml
kubectl apply -f workspace-dependencies/generated-workspace-session-iam-policy.yaml
```

!!! note
    The policy is supplied by the IAM BB from [EOEPCA/iam-policies](https://github.com/EOEPCA/iam-policies). It grants access to users holding the workspace role `ws_access` or `ws_admin`, or the `workspace-api` role `admin`. If session URLs return `503`, the policy has not reached OPA - check `iam-opal-client`.

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
xdg-open "${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}/docs"
```

Replace `${INGRESS_HOST}` with your configured ingress host domain.

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
  --silent --show-error \
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

Creation is asynchronous. Wait for Crossplane to provision the workspace's storage,
membership and Datalab:

```bash
source ~/.eoepca/state
kubectl wait --for=condition=Ready \
  storage/ws-${KEYCLOAK_TEST_USER} datalab/ws-${KEYCLOAK_TEST_USER} \
  -n workspace --timeout=10m
```

**Namespace**

Check creation of new namespace for the workspace.

```bash
source ~/.eoepca/state
kubectl get ns ws-${KEYCLOAK_TEST_USER}
```

**Custom Resources**

Check the `Storage` and `Datalab` Custom Resources for the workspace.

```bash
source ~/.eoepca/state
kubectl get storage/ws-${KEYCLOAK_TEST_USER} datalab/ws-${KEYCLOAK_TEST_USER} -n workspace
```

Both should show `True` for `SYNCED` and `READY`.

**Resources provisioned for the workspace**

Crossplane creates the workspace's object storage and its Keycloak client, roles and
groups from those two custom resources:

```bash
kubectl get buckets,users -n workspace
kubectl get clients,roles.role.keycloak.m.crossplane.io,groups.group.keycloak.m.crossplane.io -n workspace
```

The `Bucket` and `User` are the workspace's object storage and its S3 credentials.
Access is shared through the Keycloak groups: members of `ws-<name>` hold the `ws_access`
role of the `ws-<name>` client, and members of `ws-<name>-admin` hold `ws_admin`.

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

**Record the access key and secret from the response for S3 access**

!!! warning
    The S3 access key is a generated MinIO principal, such as `ws-eoepcauser-1`. It is not the Keycloak username, so read it from the API response.

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

Use the MinIO client `mc` with the workspace credentials and the S3 endpoint configured
in [step 1](#1-run-the-configuration-script) to work with the workspace's bucket.

**Configure the client:**

```bash
source ~/.eoepca/state
mc alias set workspace "$S3_ENDPOINT" "$ACCESS_KEY" "$SECRET"
```

**List the bucket:**

```bash
mc ls workspace/ws-eoepcauser
```

The bucket is empty until the workspace owner puts something in it.

**Upload a test file:**

```bash
echo "workspace storage test" > test.txt
mc cp test.txt workspace/ws-eoepcauser/test.txt
mc ls workspace/ws-eoepcauser
```

**Read it back and delete it:**

```bash
mc cat workspace/ws-eoepcauser/test.txt
mc rm workspace/ws-eoepcauser/test.txt
```

#### 6. Workspace UI

Open the web UI for the created workspace.

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}/workspaces/ws-${KEYCLOAK_TEST_USER}"
```

The home page for `Workspace: ws-eoepcauser` opens.

#### 7. Datalabs UI

The default session is initially stopped. Using the owner's access token from the previous steps, start it through the Workspace API:

!!! note
    Alternatively the default session can be started via the Workspace Web UI - under `Management` -> `Sessions`.

```bash
curl --silent --show-error --fail -X PATCH \
  "${HTTP_SCHEME}://workspace-api.${INGRESS_HOST}/workspaces/ws-${KEYCLOAK_TEST_USER}/sessions/default" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"state": "started"}' | jq
kubectl -n ws-${KEYCLOAK_TEST_USER} wait --for=create \
  deployment/ws-${KEYCLOAK_TEST_USER}-default --timeout=2m
kubectl -n ws-${KEYCLOAK_TEST_USER} rollout status \
  deployment/ws-${KEYCLOAK_TEST_USER}-default --timeout=5m
```

!!! tip
    If the request returns `401` then the access token has expired - re-run the `ACCESS_TOKEN` request from [step 4](#4-get-new-workspace-details) to refresh it.

Once the session has been started (as per above, or via the UI) then select `Datalab (default)` to open the default session. This opens a new window with the Datalabs session.

Navigate between each of the tabs:

* **Terminal**<br>
  _Provides a terminal within the session._
* **Editor**<br>
  _Provides a `vscode` style editor._
* **Data**<br>
  _Provides a file browser onto the object storage bucket(s) the user has access to._

#### 8. Workspace vCluster

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

#### 9. (optional) Delete Workspace via the Workspace API

!!! tip
    The test workspace can be retained for additional testing, but if you wish to clean up the resources created during validation, you can delete the workspace.

The workspace for the `eoepcauser` test user can be deleted via the Workspace API, using any authenticated user (e.g. `eoepcaadmin`).

**Empty the workspace bucket**

A bucket that still holds objects is not deleted with the workspace - its `Bucket` resource stays in `Deleting` until it is empty. Using the `workspace` alias from [step 5](#5-s3-bucket-access):

```bash
source ~/.eoepca/state
mc rm --recursive --force workspace/ws-${KEYCLOAK_TEST_USER}
```

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
    Delete any workspaces first (see [step 9 of Validation](#9-optional-delete-workspace-via-the-workspace-api)). Removing the `workspace-pipeline` client below leaves a workspace's Keycloak resources orphaned, because Crossplane can no longer authenticate to delete them.

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
