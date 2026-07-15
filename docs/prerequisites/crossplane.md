# Crossplane

Crossplane is a Kubernetes add-on that enables the management of cloud infrastructure and services using Kubernetes-native APIs.

The Crossplane deployment comprises a core system deployment, which is then extended via the installation of Providers. Each Provider enables the management of a specific type of infrastructure or service, such as Kubernetes clusters, cloud storage, databases, etc.

Crossplane is currently relied upon by several Building Blocks in this Deployment Guide, including:

* **IAM Building Block**<br>
  _Declarative provisioning of Clients, Users, Groups, and Roles in Keycloak._
* **Workspace Building Block**<br>
  _Declarative provisioning of workspaces and associated IAM resources._

The manifests referenced below live in [`docs/prerequisites/crossplane/`](https://github.com/EOEPCA/deployment-guide/tree/main/docs/prerequisites/crossplane) - they're static (no per-deployment variables), so there's nothing to render, just apply them directly.

## Crossplane Core

The first step is to deploy the Crossplane core system using Helm:

```bash
helm upgrade --install crossplane crossplane \
  --repo https://charts.crossplane.io/stable \
  --version 2.0.2 \
  --namespace crossplane-system \
  --create-namespace \
  --set provider.defaultActivations={}
```

## Providers

Crossplane Providers are packages that extend Crossplane's capabilities to manage specific types of infrastructure or services. It does this by defining Managed Resource Definitions (MRDs) and the necessary controllers to reconcile those resources. The MRDs define new Kubernetes-style APIs (CRDs) that represent the external resources.

Below are the steps to deploy several providers that are used by some of the Building Blocks in this Deployment Guide.

### Kubernetes Provider

The Kubernetes Provider allows Crossplane to manage Kubernetes resources across multiple clusters.

#### Service Account

For the Kubernetes Provider, we need to create a ServiceAccount with elevated permissions to allow it to manage resources across the cluster.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/crossplane/provider-kubernetes-rbac.yaml
```

#### Activate and Configure

For the Kubernetes Provider, select which Managed Resource Definitions (MRDs) are activated, and configure the runtime for the Kubernetes Provider - e.g. to use the ServiceAccount created earlier.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/crossplane/provider-kubernetes-config.yaml
```

#### Deploy Provider

Deploy the Kubernetes Provider itself, referencing the runtime configuration created earlier.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/crossplane/provider-kubernetes.yaml
```

---

### Provider Minio

The Minio Provider allows Crossplane to manage Minio object storage resources.

#### Activate and Configure

For the Minio Provider, select which Managed Resource Definitions (MRDs) are activated, and configure the runtime for the Minio Provider.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/crossplane/provider-minio-config.yaml
```

#### Deploy Provider

Deploy the Minio Provider itself, referencing the runtime configuration created earlier.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/crossplane/provider-minio.yaml
```

---

### Provider Keycloak

The Keycloak Provider allows Crossplane to manage Keycloak resources - such as Clients, Users, and Groups.

#### Activate and Configure

For the Keycloak Provider, select which Managed Resource Definitions (MRDs) are activated, and configure the runtime for the Keycloak Provider.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/crossplane/provider-keycloak-config.yaml
```

#### Deploy Provider

Deploy the Keycloak Provider itself, referencing the runtime configuration created earlier.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/crossplane/provider-keycloak.yaml
```

---

### Provider Helm

The Helm Provider allows Crossplane to manage Helm charts and releases.

#### Activate and Configure

For the Helm Provider, select which Managed Resource Definitions (MRDs) are activated, and configure the runtime for the Helm Provider.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/crossplane/provider-helm-config.yaml
```

#### Deploy Provider

Deploy the Helm Provider itself, referencing the runtime configuration created earlier.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/crossplane/provider-helm.yaml
```

---

## Provider Configurations

Crossplane Providers expect to find their configuration in `ProviderConfig` resources. Typically these are namespace-scoped and thus are configured by the BBs that rely upon those specific providers - although some providers (like MinIO) require cluster-wide configuration.

### Minio Provider

!!! tip
    For convenience we reuse the `minio-secret` that is provisioned as part of the [Workspace BB](../building-blocks/workspace.md) deployment. This secret supplies the credentals for the MinIO API.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/crossplane/provider-config-minio.yaml
```

## Functions

Functions are lightweight pieces of code that can be executed within Crossplane to extend its capabilities. They can be used to perform custom logic, transformations, or integrations with other systems.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/docs/prerequisites/crossplane/functions.yaml
```
