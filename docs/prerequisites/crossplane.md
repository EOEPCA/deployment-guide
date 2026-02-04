# Crossplane

Crossplane is a Kubernetes add-on that enables the management of cloud infrastructure and services using Kubernetes-native APIs.

The Crossplane deployment comprises a core system deployment, which is then extended via the installation of Providers. Each Provider enables the management of a specific type of infrastructure or service, such as Kubernetes clusters, cloud storage, databases, etc.

Crossplane is currently relied upon by several Building Blocks in this Deployment Guide, including:

* **IAM Building Block**<br>
  _Declarative provisioning of Clients, Users, Groups, and Roles in Keycloak._
* **Workspace Building Block**<br>
  _Declarative provisioning of workspaces and associated IAM resources._

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
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: provider-kubernetes
  namespace: crossplane-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: provider-kubernetes
rules:
- apiGroups:
  - "*"
  resources:
  - "*"
  verbs:
  - "*"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: provider-kubernetes
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: provider-kubernetes
subjects:
- kind: ServiceAccount
  name: provider-kubernetes
  namespace: crossplane-system
EOF
```

#### Activate and Configure

For the Kubernetes Provider, select which Managed Resource Definitions (MRDs) are activated, and configure the runtime for the Kubernetes Provider - e.g. to use the ServiceAccount created earlier.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apiextensions.crossplane.io/v1alpha1
kind: ManagedResourceActivationPolicy
metadata:
  name: provider-kubernetes
spec:
  activate:
    - objects.kubernetes.m.crossplane.io
---
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: provider-kubernetes
spec:
  deploymentTemplate:
    metadata:
      labels:
        runtime: provider-kubernetes
    spec:
      replicas: 1
      selector:
        matchLabels:
          runtime: provider-kubernetes
      template:
        metadata:
          labels:
            runtime: provider-kubernetes
        spec:
          serviceAccountName: provider-kubernetes
          containers:
          - name: package-runtime
            # args:
            # - --debug
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 500m
                memory: 512Mi
EOF
```

#### Deploy Provider

Deploy the Kubernetes Provider itself, referencing the runtime configuration created earlier.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v1.0.0
  runtimeConfigRef:
    name: provider-kubernetes
EOF
```

---

### Provider Minio

The Minio Provider allows Crossplane to manage Minio object storage resources.

#### Activate and Configure

For the Minio Provider, select which Managed Resource Definitions (MRDs) are activated, and configure the runtime for the Minio Provider.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apiextensions.crossplane.io/v1alpha1
kind: ManagedResourceActivationPolicy
metadata:
  name: provider-minio
spec:
  activate:
    - buckets.minio.crossplane.io
    - policies.minio.crossplane.io
    - users.minio.crossplane.io
---
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: provider-minio
spec:
  deploymentTemplate:
    metadata:
      labels:
        runtime: provider-minio
    spec:
      replicas: 1
      selector:
        matchLabels:
          runtime: provider-minio
      template:
        metadata:
          labels:
            runtime: provider-minio
        spec:
          containers:
          - name: package-runtime
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 500m
                memory: 512Mi
EOF
```

#### Deploy Provider

Deploy the Minio Provider itself, referencing the runtime configuration created earlier.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-minio
spec:
  package: xpkg.upbound.io/vshn/provider-minio:v0.4.4
EOF
```

---

### Provider Keycloak

The Keycloak Provider allows Crossplane to manage Keycloak resources - such as Clients, Users, and Groups.

#### Activate and Configure

For the Keycloak Provider, select which Managed Resource Definitions (MRDs) are activated, and configure the runtime for the Keycloak Provider.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apiextensions.crossplane.io/v1alpha1
kind: ManagedResourceActivationPolicy
metadata:
  name: provider-keycloak
spec:
  activate:
    - groups.group.keycloak.m.crossplane.io
    - memberships.group.keycloak.m.crossplane.io
    - roles.group.keycloak.m.crossplane.io
    - clients.openidclient.keycloak.m.crossplane.io
    - groupmembershipprotocolmappers.openidgroup.keycloak.m.crossplane.io
    - roles.role.keycloak.m.crossplane.io
---
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: provider-keycloak
spec:
  deploymentTemplate:
    metadata:
      labels:
        runtime: provider-keycloak
    spec:
      replicas: 1
      selector:
        matchLabels:
          runtime: provider-keycloak
      template:
        metadata:
          labels:
            runtime: provider-keycloak
        spec:
          containers:
          - name: package-runtime
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 500m
                memory: 512Mi
EOF
```

#### Deploy Provider

Deploy the Keycloak Provider itself, referencing the runtime configuration created earlier.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-keycloak
spec:
  package: ghcr.io/crossplane-contrib/provider-keycloak:v2.7.2
  runtimeConfigRef:
    name: provider-keycloak
EOF
```

---

### Provider Helm

The Helm Provider allows Crossplane to manage Helm charts and releases.

#### Activate and Configure

For the Helm Provider, select which Managed Resource Definitions (MRDs) are activated, and configure the runtime for the Helm Provider.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apiextensions.crossplane.io/v1alpha1
kind: ManagedResourceActivationPolicy
metadata:
  name: provider-helm
spec:
  activate:
    - releases.helm.m.crossplane.io
---
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: provider-helm
spec:
  deploymentTemplate:
    metadata:
      labels:
        runtime: provider-helm
    spec:
      replicas: 1
      selector:
        matchLabels:
          runtime: provider-helm
      template:
        metadata:
          labels:
            runtime: provider-helm
        spec:
          containers:
          - name: package-runtime
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 500m
                memory: 512Mi
EOF
```

#### Deploy Provider

Deploy the Helm Provider itself, referencing the runtime configuration created earlier.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-helm:v1.0.0
  runtimeConfigRef:
    name: provider-helm
EOF
```

---

## Provider Configurations

Crossplane Providers expect to find their configuration in `ProviderConfig` resources. Typically these are namespace-scoped and thus are configured by the BBs that rely upon those specific providers - although some providers (like MinIO) require cluster-wide configuration.

### Minio Provider

> For convenience we reuse the `minio-secret` that is provisioned as part of the [Workspace BB](../building-blocks/workspace.md) deployment. This secret supplies the credentals for the MinIO API.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: minio.crossplane.io/v1
kind: ProviderConfig
metadata:
  name: provider-minio
spec:
  credentials:
    apiSecretRef:
      name: minio-secret
      namespace: workspace
    source: InjectedIdentity
  minioURL: http://minio-svc.minio:9000
EOF
```

## Functions

Functions are lightweight pieces of code that can be executed within Crossplane to extend its capabilities. They can be used to perform custom logic, transformations, or integrations with other systems.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: crossplane-contrib-function-environment-configs
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-environment-configs:v0.4.0
---
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: crossplane-contrib-function-python
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-python:v0.2.0
---
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: crossplane-contrib-function-auto-ready
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-auto-ready:v0.5.0
EOF
```
