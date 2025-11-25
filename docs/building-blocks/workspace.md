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
  --values workspace-api/generated-values.yaml
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

### 7. Deploy the Workspace Admin Dashboard

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
> kubectl -n workspace port-forward svc/workspace-admin 8000
> ```

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

#### 8.2. Keycloak Client for Crossplane Provider

Create a Keycloak client for the Crossplane Keycloak provider to allow it to interface with Keycloak. We create the client `workspace-pipeline`, which is used by the workspace pipelines to perform administrative actions against the Keycloak API to properly protect newly created workspaces.

> The above `ProviderConfig` relies upon the secret `workspace-pipeline-client` that provides the credentials for this client.

Use the `create-client.sh` script in the `/scripts/utils/` directory. This script prompts you for basic details and automatically creates a Keycloak client in your chosen realm.

```bash
bash ../utils/create-client.sh
```

When prompted:

> In many cases the default values (indicated `'-'`) are acceptable.

| Prompt | Description | `workspace-pipeline` |
|--------|-------------|---------------------|
| Keycloak Admin Username and Password | Enter the credentials of your Keycloak admin user | - |
| Ingress Host | Platform base domain - e.g. `${INGRESS_HOST}` | - |
| Keycloak Host | e.g. `auth.${INGRESS_HOST}` | - |
| Realm | Typically `eoepca` | - |
| Confidential Client? | Specify `true` to create a CONFIDENTIAL client | `true` |
| Client ID | Identifier for the client in Keycloak | `workspace-pipeline` |
| Client Name | Display name for the client - for example... | `Workspace Pipelines` |
| Client Description | Descriptive text for the client - for example... | `Workspace Pipelines Admin` |
| Client secret | Enter the Client Secret that was generated during the configuration script (check `~/.eoepca/state`) | ref. env `WORKSPACE_PIPELINE_CLIENT_SECRET` |
| Subdomain | Redirect URL - Main service endpoint hostname as a prefix to `INGRESS_HOST` | `workspace-pipeline` |
| Additional Subdomains | Redirect URL - Additional `Subdomain` (prefix to `INGRESS_HOST`)<br>Comma-separated, or leave empty (e.g. `service-api`,`service-swagger`) | `<blank>` |
| Additional Hosts | Redirect URL - Additional full hostnames (i.e. outside of `INGRESS_HOST`)<br>Comma-separated, or leave empty (e.g. `service.some.platform`) | `<blank>` |

After it completes, you should see a JSON snippet confirming the newly created client.

The `workspace-pipeline` client requires specific `realm-management` roles to perform administrative actions against Keycloak.

Run the `crossplane-client-roles.sh` script in the `/scripts/utils/` directory, providing the `workspace-pipeline` client ID as an argument:

```bash
bash ../utils/crossplane-client-roles.sh workspace-pipeline
```

> The client is updated with the required roles.

---

### 9. Optional: Enable OIDC with Keycloak

If you **do not** wish to use OIDC/IAM right now, you can skip these steps and proceed directly to the [Validation](#validation) section.

If you **do** want to protect endpoints with IAM policies (i.e. require Keycloak tokens, limit access by groups/roles, etc.) **and** you enabled `OIDC` in the configuration script then follow these steps. You will create a new client in Keycloak and optionally define resource-protection rules (e.g. restricting who can list jobs).

> Before starting this please ensure that you have followed our [IAM Deployment Guide](./iam/main-iam.md) and have a Keycloak instance running.

#### 9.1 Create Keycloak Client

We create the client `workspace-api`, which is used by the Workspace API to interface with Keycloak and OPA for authentication and authorization.

Use the `create-client.sh` script in the `/scripts/utils/` directory. This script prompts you for basic details and automatically creates a Keycloak client in your chosen realm.

```bash
bash ../utils/create-client.sh
```

When prompted:

> In many cases the default values (indicated `'-'`) are acceptable.

| Prompt | Description | `workspace-api` |
|--------|-------------|-----------------|
| Keycloak Admin Username and Password | Enter the credentials of your Keycloak admin user | - |
| Ingress Host | Platform base domain - e.g. `${INGRESS_HOST}` | - |
| Keycloak Host | e.g. `auth.${INGRESS_HOST}` | - |
| Realm | Typically `eoepca` | - |
| Confidential Client? | Specify `true` to create a CONFIDENTIAL client | `true` |
| Client ID | Identifier for the client in Keycloak | `workspace-api` |
| Client Name | Display name for the client - for example... | `Workspace API` |
| Client Description | Descriptive text for the client - for example... | `Workspace API OIDC` |
| Client secret | Enter the Client Secret that was generated during the configuration script (check `~/.eoepca/state`) | ref. env `WORKSPACE_API_CLIENT_SECRET` |
| Subdomain | Redirect URL - Main service endpoint hostname as a prefix to `INGRESS_HOST` | `workspace-api` |
| Additional Subdomains | Redirect URL - Additional `Subdomain` (prefix to `INGRESS_HOST`)<br>Comma-separated, or leave empty (e.g. `service-api`,`service-swagger`) | `<blank>` |
| Additional Hosts | Redirect URL - Additional full hostnames (i.e. outside of `INGRESS_HOST`)<br>Comma-separated, or leave empty (e.g. `service.some.platform`) | `<blank>` |

After it completes, you should see a JSON snippet confirming the newly created client.

#### 9.2 Create APISIX Route Ingress

Apply the APISIX route ingress:

```bash
kubectl apply -f workspace-api/generated-ingress.yaml
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

> NOTE that the ingress integrates with IAM via OIDC, and so expects an authenticated user - for example `eoepcauser` created earlier.

---

### Creating and Testing a Workspace

#### 1. Create a New Workspace

Apply a sample `Workspace` resource definition:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: epca.eo/v1beta1
kind: Workspace
metadata:
  name: ws-eoepcauser
  namespace: workspace
spec:
  subscription: bronze
  owner: eoepcauser
  extraBuckets:
    - ws-eoepcauser-shared
EOF
```

Check that a new namespace was created:

```bash
kubectl get ns ws-eoepcauser
```

#### 2. Verify Storage Buckets

Confirm that the workspace's storage buckets - `ws-eoepcauser` _(default)_ and `ws-eoepcauser-shared` _(additional)_ - were created:

```bash
kubectl -n ws-eoepcauser get bucket
```

#### 3. Query the Workspace API

Port-forward the Workspace API service:<br>
_Use of port forward allows to bypass the IAM to simplify the test_

```bash
kubectl -n workspace port-forward svc/workspace-api 8080:8080
```

From another terminal window, call the Workspace API to get details for the newly created workspace:

```bash
curl http://localhost:8080/workspaces/ws-eoepcauser -H 'accept: application/json'
```

Record the secret from the response for S3 access:

```bash
SECRET="$(curl -s http://localhost:8080/workspaces/ws-eoepcauser -H 'accept: application/json' | jq -r '.storage.credentials.secret')"
```

Now the `port-forward` to the Workspace API service can be stopped - `Ctrl-C` in original terminal window.

#### 4. Interacting with S3 Buckets

Use `s3cmd` (configured via `source ~/.eoepca/state`) to list and manipulate objects in the workspace's S3 buckets.

**List Buckets:**

```bash
source ~/.eoepca/state
s3cmd ls \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ws-eoepcauser \
  --secret_key $SECRET
```

**Upload a Test File:**

> Ensure you are in the directory `scripts/workspace` for access to the test file `validation.sh`.

```bash
source ~/.eoepca/state
s3cmd put validation.sh s3://ws-eoepcauser \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ws-eoepcauser \
  --secret_key $SECRET
```

**Check the Uploaded File:**

```bash
source ~/.eoepca/state
s3cmd ls s3://ws-eoepcauser \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ws-eoepcauser \
  --secret_key $SECRET
```

**Delete the Test File:**

```bash
source ~/.eoepca/state
s3cmd del s3://ws-eoepcauser/validation.sh \
  --host minio.${INGRESS_HOST} \
  --host-bucket minio.${INGRESS_HOST} \
  --access_key ws-eoepcauser \
  --secret_key $SECRET
```

#### 5. Delete the Test Workspace

To remove the test workspace:

```bash
kubectl -n workspace delete workspaces ws-eoepcauser
```

---

## Uninstallation

To uninstall the Workspace Building Block and clean up associated resources:

```bash
kubectl delete -f workspace-cleanup/datalab-cleaner.yaml ; \
helm uninstall workspace-admin -n workspace ; \
kubectl -n workspace delete -f workspace-api/generated-ingress.yaml; \
helm uninstall workspace-api -n workspace ; \
helm uninstall workspace-pipeline -n workspace ; \
helm uninstall workspace-dependencies-educates -n workspace ; \
helm uninstall workspace-dependencies-csi-rclone -n workspace ; \
helm uninstall workspace-crossplane -n workspace ; \
kubectl delete namespace workspace
```

---

## Further Reading

- [EOEPCA+ Workspace GitHub Repository](https://github.com/EOEPCA/workspace)
- [Crossplane Documentation](https://crossplane.io/docs/)
- [Educates Documentation](https://docs.educates.dev/)
- [CSI-RClone Documentation](https://github.com/wunderio/csi-rclone)
- [Kubernetes Dashboard Documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)