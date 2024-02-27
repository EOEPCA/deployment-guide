# Workspace

The _Workspace_ provides protected user resource management that includes dedicated storage and services for resource discovery and access.

## Workspace API

The _Workspace API_ provides a REST service through which user workspaces can be created, interrogated, managed and deleted.

### Helm Chart

The _Workspace API_ is deployed via the `rm-workspace-api` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `um-workspace-api` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-workspace-api#readme).

```bash
helm install --version 1.4.2 --values workspace-api-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  workspace-api rm-workspace-api
```

### Values

At minimum, values for the following attributes should be specified:

* The fully-qualified public URL for the service
* (optional) Specification of Ingress for reverse-proxy access to the service<br>
  _Note that this is only required in the case that the Workspace API will **not** be protected by the `identity-gatekeeper` component - ref. [Resource Protection](./resource-protection-keycloak.md). Otherwise the ingress will be handled by the `identity-gatekeeper` - use `ingress.enabled: false`._
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
workspaceChartsConfigMap: "workspace-charts"
bucketEndpointUrl: "http://minio-bucket-api:8080/bucket"
keycloakIntegration:
  enabled: true
  keycloakUrl: "https://keycloak.192-168-49-2.nip.io"
  realm: "master"
  identityApiUrl: "https://identity-api.192-168-49-2.nip.io"
  workspaceApiIamClientId: "workspace-api"
  defaultIamClientSecret: "changeme"
```

!!! note
    * The Workspace API assumes a deployment of the Harbor Container Regsitry, as configured by the `harborXXX` values above.<br>See section [Container Registry](container-registry.md).
    * The password for the harbor `admin` user must be created as described in the section [Harbor `admin` Password](#harbor-admin-password).
    * The `keycloakIntegration` allows the Workspace API to apply protecion (for the specified workspace owner) to the services within newly created workspaces.
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
* **Protection**: `template-hr-resource-protection.yaml`

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
  template-hr-resource-protection.yaml: |
    apiVersion: helm.toolkit.fluxcd.io/v2beta1
    kind: HelmRelease
    metadata:
      name: resource-protection
    spec:
      interval: 5m
      chart:
        spec:
          chart: identity-gatekeeper
          version: 1.0.11
          sourceRef:
            kind: HelmRepository
            name: eoepca
            namespace: ${NAMESPACE}
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

As described in [section Resource Protection (Keycloak)](resource-protection-keycloak.md), the `identity-gatekeeper` component can be inserted into the request path of the `workspace-api` service to provide access authorization decisions

#### Gatekeeper

Gatekeeper is deployed using its helm chart...

```bash
helm install workspace-api-protection identity-gatekeeper -f workspace-api-protection-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  --namespace "rm" --create-namespace \
  --version 1.0.11
```

The `identity-gatekeeper` must be configured with the values applicable to the `workspace-api` - in particular the specific ingress requirements for the `workspace-api` backend service...

**Example `workspace-api-protection-values.yaml`...**

```yaml
fullnameOverride: workspace-api-protection
config:
  client-id: workspace-api
  discovery-url: https://keycloak.192-168-49-2.nip.io/realms/master
  cookie-domain: 192-168-49-2.nip.io
targetService:
  host: workspace-api.192-168-49-2.nip.io
  name: workspace-api
  port:
    number: 8080
secrets:
  # Values for secret 'workspace-api-protection'
  # Note - if ommitted, these can instead be set by creating the secret independently.
  clientSecret: "changeme"
  encryptionKey: "changemechangeme"
ingress:
  enabled: true
  className: nginx
  annotations:
    ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-production
  serverSnippets:
    custom: |-
      # Open access to some endpoints, including Swagger UI
      location ~ ^/(docs|openapi.json|probe) {
        proxy_pass {{ include "identity-gatekeeper.targetUrl" . }}$request_uri;
      }
```

#### Keycloak Client

The Gatekeeper instance relies upon an associated client configured within Keycloak - ref. `client-id: workspace-api` above.

This can be created with the `create-client` helper script, as descirbed in section [Client Registration](./resource-protection-keycloak.md#client-registration).

For example, with path protection for the `admin` user...

```bash
../bin/create-client \
  -a https://keycloak.192-168-49-2.nip.io \
  -i https://identity-api.192-168-49-2.nip.io \
  -r "master" \
  -u "admin" \
  -p "changeme" \
  -c "admin-cli" \
  --id="workspace-api" \
  --name="Workspace API Gatekeeper" \
  --secret="changeme" \
  --description="Client to be used by Workspace API Gatekeeper" \
  --resource="admin" --uris='/*' --scopes=view --users="admin"
```

### Workspace API Usage

The Workspace API provides a REST interface that is accessed at the endpoint https://workspace-api.192-168-49-2.nip.io/.<br>
See the [Swagger Docs - /docs](https://workspace-api.192-168-49-2.nip.io/docs).

!!! note
    If the Workspace API has been protected ([via Gatekeeper with Keycloak](./identity-service.md#protection-of-resources)), then requests must be supported by an `access_token` carried in the HTTP header `Authorozation: Bearer <token>`. This diminishes the utility of the swagger UI.

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
