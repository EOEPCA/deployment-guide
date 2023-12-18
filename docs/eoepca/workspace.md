# Workspace

The _Workspace_ provides protected user resource management that includes dedicated storage and services for resource discovery and access.

## Workspace API

The _Workspace API_ provides a REST service through which user workspaces can be created, interrogated, managed and deleted.

### Helm Chart

The _Workspace API_ is deployed via the `rm-workspace-api` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `um-workspace-api` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-workspace-api#readme).

```bash
helm install --version 1.3.5 --values workspace-api-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  workspace-api rm-workspace-api
```

### Values

At minimum, values for the following attributes should be specified:

* The fully-qualified public URL for the service
* (optional) Specification of Ingress for reverse-proxy access to the service<br>
  _Note that this is only required in the case that the Workspace API will **not** be protected by the `resource-guard` component - ref. [Resource Protection](resource-protection.md). Otherwise the ingress will be handled by the `resource-guard` - use `ingress.enabled: false`._
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
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
  hosts:
    - host: workspace-api-open.192-168-49-2.nip.io
      paths: ["/"]
  tls:
    - hosts:
        - workspace-api-open.192-168-49-2.nip.io
      secretName: workspace-api-open-tls
fluxHelmOperator:
  enabled: true
prefixForName: "ws"
workspaceSecretName: "bucket"
namespaceForBucketResource: "rm"
s3Endpoint: "https://minio.192-168-49-2.nip.io"
s3Region: "RegionOne"
harborUrl: "https://harbor.192-168-49-2.nip.io"
harborUsername: "admin"
harborPasswordSecretName: "harbor"
umaClientSecretName: "resman-client"
umaClientSecretNamespace: "rm"
workspaceChartsConfigMap: "workspace-charts"
bucketEndpointUrl: "http://minio-bucket-api:8080/bucket"
pepBaseUrl: "http://workspace-api-pep:5576/resources"
autoProtectionEnabled: True
```

!!! note
    * The Workspace API assumes a deployment of the Harbor Container Regsitry, as configured by the `harborXXX` values above.<br>See section [Container Registry](container-registry.md).
    * The password for the harbor `admin` user must be created as described in the section [Harbor `admin` Password](#harbor-admin-password).
    * If the workspace-api is access protected (ref. [section Protection](#protection)), then it is recommended to enable `autoProtectionEnabled` and to specifiy the `pepBaseUrl`.
    * The workspace-api initiates the creation of a storage 'bucket' for each workspace - the actual bucket creation being abstracted via a webhook - the URL of which is specified in the value `bucketEndpointUrl`.<br>
      _See section [Bucket Creation Webhook](#bucket-creation-webhook) for details._

### Harbor `admin` Password

The password for the harbor `admin` user is provided to the workspace-api via the specified secret - defined as `harbor` above.

This secret must be created - for example as follows...

```
kubectl -n rm create secret generic harbor \
  --from-literal=HARBOR_ADMIN_PASSWORD="changeme"
```

### Flux Dependency

Workspaces are created by instantiating the [`rm-user-workspace` helm chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-user-workspace) for each user/group. The Workspace API uses [Flux CD](https://fluxcd.io/) as a helper to manage these subordinate helm charts - via flux resources of type `HelmRelease`. Thus, it is necessary to deploy within the cluster the aspects of flux that support this helm chart management - namely the flux `helm-controller`, `source-controller` and the Kubernetes _Custom Resource Definitions (CRD)_ for `HelmRelease` and `HelmRepository`.

In case you are not already using flux within your clsuter, then the Workspace API helm chart can be configured to deploy the required flux components...
```
fluxHelmOperator:
  enabled: true  # true = install flux for me, false = I already have flux
```

### User Workspace Templates

The Workspace API instantiates for each user a set of services, including a Resource Catalogue and Data Access services. These user services are instantiated via helm using templates. The templates are provided to the Workspace API in a `ConfigMap` that is, by default, named `workspace-charts`. Each file in the config-map is expected to be of `kind` `HelmRelease`. During creation of a new workspace, the Worksapce API applies each file to the cluster in the namespace of the newly created namespace.

The default ConfigMap that is included with this guide contains the following templates for instantiation of user-specific components:

* **Data Access**: `template-hr-data-access.yaml`
* **Resource Catalogue**: `template-hr-resource-catalogue.yaml`
* **Protection**: `template-hr-resource-guard.yaml`

Each of these templates is expressed as a flux `HelmRelease` object that describes the helm chart and values required to deploy the service.

In addition, ConfigMap templates are included that provide specific details required to access the user-scoped workspace resources, including access to S3 object storage and container registry:

* **S3 client configuration**: `template-cm-aws-config.yaml`
* **S3 client credentials**: `template-cm-aws-credentials.yaml`
* **Container registry configuration**: `template-cm-docker-config.yaml`

These ConfigMaps are designed to be mounted as files into the runtime environments of other components for user workspace integration. In particular the Application Hub makes use of this approach to provide a user experience that integrates with the user's workspace resources.

#### Templates ConfigMap

The templates are provided to the Workspace API as a `ConfigMap` in the namespace of the Workspace API deployment...

_(for full examples see [https://github.com/EOEPCA/deployment-guide/tree/eoepca-v1.3/deploy/eoepca/workspace-templates](https://github.com/EOEPCA/deployment-guide/tree/eoepca-v1.3/deploy/eoepca/workspace-templates))_

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
          version: 1.3.1
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
          version: 1.3.1
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
          version: 1.3.1
          sourceRef:
            kind: HelmRepository
            name: eoepca
            namespace: rm
      values:
        ...
  template-cm-aws-config.yaml: |
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: aws-config
    data:
      aws-config: |
        [default]
        region = {{ s3_region }}
        s3 =
          endpoint_url = {{ s3_endpoint_url }}
        s3api =
          endpoint_url = {{ s3_endpoint_url }}
        [plugins]
        endpoint = awscli_plugin_endpoint
  template-cm-aws-credentials.yaml: |
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: aws-credentials
    data:
      aws-credentials: |
        [default]
        aws_access_key_id = {{ access_key_id }}
        aws_secret_access_key = {{ secret_access_key }}
  template-cm-docker-config.yaml: |
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: docker-config
    data:
      docker-config: |
        {
          "auths": {
            "{{ container_registry_host }}": {
              "auth": "{{ container_registry_credentials }}"
            }
        }
```

Notice the use of workspace template parameters `{{ param_name }}` that are used at workspace creation time to contextualise the workspace for the owning user. See section [Workspace Template Parameters](#workspace-template-parameters) for more information.

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

#### Workspace Template Parameters

The Workspace API uses the [`jinja2` templating engine](https://palletsprojects.com/p/jinja/) when applying the _resources_ for a user workspace. The current parameters are currently supported:

* **`workspace_name`**<br>
  The name of the workspace - `{{ workspace_name }}` used to ensure unique naming of cluster resources, such as service ingress
* **`default_owner`**<br>
  The `uuid` of the owner of the workspace - `{{ default_owner }}` used to initialise the workspace protection
* **_S3 Object Storage details..._**
    * `{{ s3_endpoint_url }}`
    * `{{ s3_region }}`
    * `{{ access_key_id }}`
    * `{{ secret_access_key }}`
* **_Container Registry details..._**
    * `{{ container_registry_host }}`
    * `{{ container_registry_credentials }}`

### Protection

As described in [section Resource Protection](resource-protection.md), the `resource-guard` component can be inserted into the request path of the Workspace API service to provide access authorization decisions

```bash
helm install --version 1.3.1 --values workspace-api-guard-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  workspace-api-guard resource-guard
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
  defaultResources:
    - name: "Workspace API Base Path"
      description: "Protected root path for operators only"
      resource_uri: "/"
      scopes: []
      default_owner: "0000000000000"
  customDefaultResources:
    - name: "Workspace API Swagger Docs"
      description: "Public access to workspace API swagger docs"
      resource_uri: "/docs"
      scopes:
        - "public_access"
      default_owner: "0000000000000"
    - name: "Workspace API OpenAPI JSON"
      description: "Public access to workspace API openapi.json file"
      resource_uri: "/openapi.json"
      scopes:
        - "public_access"
      default_owner: "0000000000000"
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

!!! note
    * TLS is enabled by the specification of `certManager.clusterIssuer`
    * The `letsencrypt` Cluster Issuer relies upon the deployment being accessible from the public internet via the `global.domain` DNS name. If this is not the case, e.g. for a local minikube deployment in which this is unlikely to be so. In this case the TLS will fall-back to the self-signed certificate built-in to the nginx ingress controller
    * `insecureTlsSkipVerify` may be required in the case that good TLS certificates cannot be established, e.g. if letsencrypt cannot be used for a local deployment. Otherwise the certificates offered by login-service _Authorization Server_ will fail validation in the _Resource Guard_.
    * `customDefaultResources` can be specified to apply initial protection to the endpoint.<br>
      _In the example above we open up access to the OpenAPI (swagger) documentation that does not require protection._

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

The client credentials are obtained by registration of a client at the login service web interface - e.g. [https://auth.192-168-49-2.nip.io](https://auth.192-168-49-2.nip.io). In addition there is a helper script that can be used to create a basic client and obtain the credentials, as described in [section Resource Protection](resource-protection.md#client-registration)...
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

## Bucket Creation Webhook

With helm chart version `1.3.1` of the `workspace-api` the approach to bucket creation has been re-architected to use a webhook approach.

### Approach

During workspace creation the `workspace-api` needs to create an object storage bucket for the user. The method by which the bucket is created is a function of the hosting infrastructure object storage layer - i.e. there is no 'common' approach for the `workspace-api` to perform the bucket creation.

In order to allow this bucket creation step to be customised by the platform integrator, the workspace-api is configured with a webhook endpoint that is invoked to effect the bucket creation on behalf of the workspace-api.

The workspace-api is configured by the following value in its helm chart deployment, e.g...
```
bucketEndpointUrl: "http://my-bucket-webhook:8080/bucket"
```

The webhook service must implement the following REST interface...

method: `POST`<br>
content-type: `application/json`<br>
data:
```
{
  bucketName: str
  secretName: str
  secretNamespace: str
}
```

There are two possible approaches to implement this request, distinguished by the response code...

* `200`<br>
  The bucket is created and the credentials are included in the response body.<br>
  In this case only the supplied `bucketName` is relevant to fulfil the request.
* `201`<br>
  The bucket will be created (asychronously) and the outcome is provided by the webhook via a Kubernetes secret, as per the `secretName` and `secretNamespace` request parameters

**`200` Response**

In case `200` response, the response body should communicate the credentials with an `application/json` content-type in the form...
```
{
    "bucketname": "...",
    "access_key": "...",
    "access_secret": "....",
    "projectid": "...",
}
```

In this case the workspace-api will create the appropriate bucket secret using the returned credentials.

**`201` Response**

In case `201` response, the secret should be created in the form...
```
data:
  bucketname: "..."
  access: "..."
  secret: "..."
  projectid: "..."
```

In this case the workspace-api will wait for the (asynchronous) creation of the specified secret before continuing with the workspace creation.

**Overall Outcome**

In both cases the ultimate outcome is the creation of the bucket in the back-end object storage, and the creation of a Kubernetes secret that maintains the credentials for access to the bucket. The existence of the bucket secret is prerequisite to the continuation of the user workspace creation.

### Minio Bucket API (Webhook)

The _Minio Bucket API_ provides an implementation of a _Bucket Creation Webhook_ for a Minio S3 Object Storage backend. This is used as the default in this guide - but should be replaced for a production deployment with an appropriate webhook to integrate with the object storage solution of the deployment environment.

#### Helm Chart

The _Minio Bucket API_ is deployed via the `rm-minio-bucket-api` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts) - ref. [Helm Chart for the Minio Bucket API](https://github.com/EOEPCA/helm-charts/blob/main/charts/rm-minio-bucket-api).

```bash
helm install --version 0.0.4 --values minio-bucket-api-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  rm-minio-bucket-api rm-minio-bucket-api
```

#### Values

At minimum, values for the following attributes should be specified:

* The URL for the Minio endpoint - `minIOServerEndpoint`
* The credentials for admin access to Minio - via the specified secret `accessCredentials.secretName` (ref. [Minio Credentials Secret](../cluster/cluster-prerequisites.md#minio-credentials-secret))

Example `minio-bucket-api-values.yaml`...
```yaml
fullnameOverride: minio-bucket-api
minIOServerEndpoint: https://minio.192-168-49-2.nip.io
accessCredentials:
  secretName: minio-auth
```

### Additional Information

Additional information regarding the _Minio Bucket API_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-minio-bucket-api)
* [GitHub Repository](https://github.com/EOEPCA/rm-minio-bucket-api)
