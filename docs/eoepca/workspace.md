# Workspace

The _Workspace_ provides protected user resource management that includes dedicated storage and services for resource discovery and access.

## Workspace API

The _Workspace API_ provides a REST service through which user workspaces can be created, interrogated, managed and deleted.

### Helm Chart

The _Workspace API_ is deployed via the `rm-workspace-api` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `um-workspace-api` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-workspace-api#readme).

```bash
helm install --version 1.2.0 --values workspace-api-values.yaml workspace-api eoepca/rm-workspace-api
```

### Values

At minimum, values for the following attributes should be specified:

* The fully-qualified public URL for the service
* (optional) Specification of Ingress for reverse-proxy access to the service<br>
  _Note that this is only required in the case that the Workspace API will **not** be protected by the `resource-guard` component - ref. [Resource Protection](../resource-protection). Otherwise the ingress will be handled by the `resource-guard` - use `ingress.enabled: false`._
* Prefix for user projects in OpenStack
* Details for underlying S3 object storage service
* Identification of secret that provides the client credentials for resource protection
* Whether flux components should be installed - otherwise they must already be present - [Flux Dependency](#flux-dependency)
* Name of the ConfigMap for user workspace templates - See [User Workspace Templates](#user-workspace-templates)

Example `workspace-api-values.yaml`...
```yaml
fullnameOverride: workspace-api
ingress:
  enabled: true
  hosts:
    - host: workspace-api-open.192-168-49-2.nip.io
      paths: ["/"]
  tls:
    - hosts:
        - workspace-api-open.192-168-49-2.nip.io
      secretName: workspace-api-open-tls
fluxHelmOperator:
  enabled: true
prefixForName: "guide-user"
workspaceSecretName: "bucket"
namespaceForBucketResource: "rm"
s3Endpoint: "https://cf2.cloudferro.com:8080"
s3Region: "RegionOne"
harborUrl: "https://harbor.192-168-49-2.nip.io"
harborUsername: "admin"
harborPassword: "changeme"
umaClientSecretName: "resman-client"
umaClientSecretNamespace: "rm"
workspaceChartsConfigMap: "workspace-charts"
```

**NOTES:**

* The Workspace API assumes a deployment of the Harbor Container Regsitry, as configured by the `harborXXX` values above.<br>See section [Container Registry](../container-registry/).

### Flux Dependency

Workspaces are created by instantiating the [`rm-user-workspace` helm chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-user-workspace) for each user/group. The Workspace API uses [Flux CD](https://fluxcd.io/) as a helper to manage these subordinate helm charts - via flux resources of type `HelmRelease`. Thus, it is necessary to deploy within the cluster the aspects of flux that support this helm chart management - namely the flux `helm-controller`, `source-controller` and the Kubernetes _Custom Resource Definitions (CRD)_ for `HelmRelease` and `HelmRepository`.

In case you are not already using flux within your clsuter, then the Workspace API helm chart can be configured to deploy the required flux components...
```
fluxHelmOperator:
  enabled: true  # true = install flux for me, false = I already have flux
```

### User Workspace Templates

The Workspace API instantiates for each user a set of services, including a Resource Catalogue and Data Access services. These user services are instantiated via helm using templates. The templates are provided to the Workspace API in a `ConfigMap` that is, by default, named `workspace-charts`. Each file in the config-map is expected to be of `kind` `HelmRelease`. During creation of a new workspace, the Worksapce API applies each file to the cluster in the namespace of the newly created namespace.

The default ConfigMap that is included with this guide contains the following templates:

* **Data Access**: `template-hr-data-access.yaml`
* **Resource Catalogue**: `template-hr-resource-catalogue.yaml`
* **Protection**: `template-hr-resource-guard.yaml`

Each of these templates is expressed as a flux `HelmRelease` object that describes the helm chart and values required to deploy the service.

#### Templates ConfigMap

The templates are provided to the Workspace API as a `ConfigMap` in the namespace of the Workspace API deployment...

_(for full examples see [https://github.com/EOEPCA/deployment-guide/tree/main/deploy/eoepca/workspace-templates](https://github.com/EOEPCA/deployment-guide/tree/main/deploy/eoepca/workspace-templates))_

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: workspace-charts
data:
  template-hr-resource-catalogue.yaml: |
    apiVersion: helm.toolkit.fluxcd.io/v2beta1
    kind: HelmRelease
    metadata:
      name: rm-resource-catalogue
    spec:
      interval: 5m
      chart:
        spec:
          chart: rm-resource-catalogue
          version: 1.2.0
          sourceRef:
            kind: HelmRepository
            name: eoepca
            namespace: rm
      values:
        ...
  template-hr-data-access.yaml: |
    apiVersion: helm.toolkit.fluxcd.io/v2beta1
    kind: HelmRelease
    metadata:
      name: vs
    spec:
      interval: 5m
      chart:
        spec:
          chart: data-access
          version: 1.2.5
          sourceRef:
            kind: HelmRepository
            name: eoepca
            namespace: rm
      values:
        ...
  template-hr-resource-guard.yaml: |
    apiVersion: helm.toolkit.fluxcd.io/v2beta1
    kind: HelmRelease
    metadata:
      name: resource-guard
    spec:
      interval: 5m
      chart:
        spec:
          chart: resource-guard
          version: 1.2.1
          sourceRef:
            kind: HelmRepository
            name: eoepca
            namespace: rm
      values:
        ...
```

#### HelmRepositories for Templates

As can be seen above, the HelmRelease templates rely upon objects of type HelmRepository that define the hosting helm chart repository. Thus, in support of the workspace templates, appropriate HelmRepository objects must be provisioned within the cluster. For example, in support of the above examples that rely upon the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts)...

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: eoepca
  namespace: rm
spec:
  interval: 2m
  url: https://eoepca.github.io/helm-charts/
```

#### Helm Template Parameters

The Workspace API uses the [`jinja2` templating engine](https://palletsprojects.com/p/jinja/) when applying the HelmReleases for a user workspace. The current parameters are currently supported:

* **`workspace_name`**<br>
  The name of the workspace - `{{ workspace_name }}` used to ensure unique naming of cluster resources, such as service ingress
* **`default_owner`**<br>
  The `uuid` of the owner of the workspace - `{{ default_owner }}` used to initialise the workspace protection

### Protection

As described in [section Resource Protection](../resource-protection), the `resource-guard` component can be inserted into the request path of the Workspace API service to provide access authorization decisions

```bash
helm install --version 1.2.1 --values workspace-api-guard-values.yaml workspace-api-guard eoepca/resource-guard
```

The `resource-guard` must be configured with the values applicable to the Workspace API for the _Policy Enforcement Point_ (`pep-engine`) and the _UMA User Agent_ (`uma-user-agent`)...

**Example `workspace-api-guard-values.yaml`...**

```yaml
#---------------------------------------------------------------------------
# Global values
#---------------------------------------------------------------------------
global:
  context: workspace-api
  domain: 192-168-49-2.nip.io
  nginxIp: 192.168.49.2
  certManager:
    clusterIssuer: letsencrypt-production
#---------------------------------------------------------------------------
# PEP values
#---------------------------------------------------------------------------
pep-engine:
  configMap:
    asHostname: auth
    pdpHostname: auth
  # customDefaultResources:
  # - name: "Eric's workspace"
  #   description: "Protected Access for eric to his user workspace"
  #   resource_uri: "/workspaces/guide-user-eric"
  #   scopes: []
  #   default_owner: "d3688daa-385d-45b0-8e04-2062e3e2cd86"
  # - name: "Bob's workspace"
  #   description: "Protected Access for bob to his user workspace"
  #   resource_uri: "/workspaces/guide-user-bob"
  #   scopes: []
  #   default_owner: "f12c2592-0332-49f4-a4fb-7063b3c2a889"
  volumeClaim:
    name: eoepca-resman-pvc
    create: false
#---------------------------------------------------------------------------
# UMA User Agent values
#---------------------------------------------------------------------------
uma-user-agent:
  nginxIntegration:
    enabled: true
    hosts:
      - host: workspace-api
        paths:
          - path: /(.*)
            service:
              name: workspace-api
              port: http
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      nginx.ingress.kubernetes.io/rewrite-target: /$1
  client:
    credentialsSecretName: "resman-client"
  logging:
    level: "info"
  unauthorizedResponse: 'Bearer realm="https://portal.192-168-49-2.nip.io/oidc/authenticate/"'
  openAccess: false
  insecureTlsSkipVerify: true
```

**NOTES:**

* TLS is enabled by the specification of `certManager.clusterIssuer`
* The `letsencrypt` Cluster Issuer relies upon the deployment being accessible from the public internet via the `global.domain` DNS name. If this is not the case, e.g. for a local minikube deployment in which this is unlikely to be so. In this case the TLS will fall-back to the self-signed certificate built-in to the nginx ingress controller
* `insecureTlsSkipVerify` may be required in the case that good TLS certificates cannot be established, e.g. if letsencrypt cannot be used for a local deployment. Otherwise the certificates offered by login-service _Authorization Server_ will fail validation in the _Resource Guard_.
* `customDefaultResources` can be specified to apply initial protection to the endpoint

### Client Secret

The Resource Guard requires confidential client credentials to be configured through the file `client.yaml`, delivered via a kubernetes secret..

**Example `client.yaml`...**

```yaml
client-id: a98ba66e-e876-46e1-8619-5e130a38d1a4
client-secret: 73914cfc-c7dd-4b54-8807-ce17c3645558
```

**Example `Secret`...**

```bash
kubectl -n rm create secret generic resman-client \
  --from-file=client.yaml \
  --dry-run=client -o yaml \
  > resman-client-secret.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: resman-client
  namespace: rm
data:
  client.yaml: Y2xpZW50LWlkOiBhOThiYTY2ZS1lODc2LTQ2ZTEtODYxOS01ZTEzMGEzOGQxYTQKY2xpZW50LXNlY3JldDogNzM5MTRjZmMtYzdkZC00YjU0LTg4MDctY2UxN2MzNjQ1NTU4
```

The client credentials are obtained by registration of a client at the login service web interface - e.g. [https://auth.192-168-49-2.nip.io](https://auth.192-168-49-2.nip.io). In addition there is a helper script that can be used to create a basic client and obtain the credentials, as described in [section Resource Protection](../resource-protection/#client-registration)...
```bash
./deploy/bin/register-client auth.192-168-49-2.nip.io "Resource Guard" | tee client.yaml
```

### Workspace API Usage

The Workspace API provides a REST interface that is accessed at the endpoint https://workspace-api.192-168-49-2.nip.io/.<br>
See the [Swagger Docs](https://workspace-api.192-168-49-2.nip.io/docs).

### Additional Information

Additional information regarding the _Workspace API_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-workspace-api)
* [Wiki](https://github.com/EOEPCA/rm-workspace-api/wiki)
* [GitHub Repository](https://github.com/EOEPCA/rm-workspace-api)


## Bucket Operator

The Workspace API creates workspaces for individual users. In doing so, dedicated object storage buckets are created associated to each user workspace - for self-contained storage of user owned resources (data, processing applications, etc.).

The bucket creation relies upon the object storage services of the underlying cloud infrastructure. We have created a `Bucket` abstraction as a Kubernetes `Custom Resource Definition`. This is served by a `Bucket Operator` service that deploys into the Kubernetes cluster to satisfy requests for resources of type `Bucket`.

We provide a `Bucket Operator` implementation that currently supports the creation of buckets in OpenStack object storage - currently tested only on the CREODIAS (Cloudferro).

The _Bucket Operator_ is deployed via the `rm-bucket-operator` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `um-bucket-operator` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-bucket-operator#readme).

```bash
helm install --version 0.9.9 --values bucket-operator-values.yaml bucket-operator eoepca/rm-bucket-operator
```

### Values

At minimum, values for the following attributes should be specified:

* The fully-qualified public URL for the service
* OpenStack access details
* Cluster Issuer for TLS

Example `bucket-operator-values.yaml`...
```yaml
domain: 192-168-49-2.nip.io
data:
  OS_MEMBERROLEID: "9ee2ff9ee4384b1894a90878d3e92bab"
  OS_SERVICEPROJECTID: "d21467d0a0414252a79e29d38f03ff98"
  USER_EMAIL_PATTERN: "eoepca+<name>@192-168-49-2.nip.io"
ingress:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
```

### OpenStack Secret

The `Bucket Operator` requires privileged access to the OpenStack API, for which credentials are required. These are provided via a Kubernetes secret named `openstack` created in the namespace of the Bucket Operator.<br>
For example...

```
kubectl -n rm create secret generic openstack \
  --from-literal=username="${OS_USERNAME}" \
  --from-literal=password="${OS_PASSWORD}" \
  --from-literal=domainname="${OS_DOMAINNAME}"
```

See the [README for the Bucket Operator](https://github.com/EOEPCA/rm-bucket-operator#readme), which describes the configuration required for integration with your OpenStack account.

For a worked example see our [Scripted Example Deployment](../../examples/scripted-example-deployment) - in particular:

* [Openstack Configuration](../../examples/scripted-example-deployment/#openstack-configuration)
* [Deployment Script](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/eoepca/bucket-operator.sh)
