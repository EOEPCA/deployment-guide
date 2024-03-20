# Scripted Deployment

## Overview

The Scripted Deployment provides a demonstration of an example deployment, and can found in the subdirectory [`deployment-guide/deploy`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.4/deploy/eoepca/eoepca.sh) of the source repository for this guide...

```bash
git clone -b eoepca-v1.4 https://github.com/EOEPCA/deployment-guide \
&& cd deployment-guide \
&& ls deploy
```

The script [`deploy/eoepca/eoepca.sh`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.4/deploy/eoepca/eoepca.sh) acts as an entry-point to the full system deployment. In order to tailor the deployment for your target environment, the script is configured through environment variables and command-line arguments. By default the script assumes deployment to a local minikube.

!!! note
    The scripted deployment assumes that installation of the [Prerequisite Tooling](../cluster/prerequisite-tooling.md) has been performed.

The following subsections lead through the steps for a full local deployment. Whilst minikube is assumed, minimal adaptions are required to make the deployment to your existing Kubernetes cluster.

The deployment follows these broad steps:

* **Configuration**<br>
  Tailoring of deployment options.
* **Deployment**<br>
  Creation of cluster and deployment of eoepca services.
* **Manual Steps**<br>
  Manual steps to be performed post-deployment.

## Configuration

The script [`deploy/eoepca/eoepca.sh`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.4/deploy/eoepca/eoepca.sh) is configured by some environment variables and command-line arguments.

### Environment Variables

??? example "Environment Variables"
    Variable | Description | Default
    -------- | ----------- | -------
    **REQUIRE_<cluster-component\>** | A set of variables that can be used to control which **CLUSTER** components are deployed by the script, as follows (with defaults):<br>`REQUIRE_MINIKUBE=true`<br>`REQUIRE_INGRESS_NGINX=true`<br>`REQUIRE_CERT_MANAGER=true`<br>`REQUIRE_LETSENCRYPT=true`<br>`REQUIRE_SEALED_SECRETS=false`<br>`REQUIRE_MINIO=false` | see description
    **REQUIRE_<eoepca-component\>** | A set of variables that can be used to control which **EOEPCA** components are deployed by the script, as follows (with defaults):<br>`REQUIRE_STORAGE=true`<br>`REQUIRE_DUMMY_SERVICE=false`<br>`REQUIRE_IDENTITY_SERVICE=true`<br>`REQUIRE_ADES=true`<br>`REQUIRE_RESOURCE_CATALOGUE=true`<br>`REQUIRE_DATA_ACCESS=true`<br>`REQUIRE_REGISTRATION_API=true`<br>`REQUIRE_WORKSPACE_API=true`<br>`REQUIRE_HARBOR=true`<br>`REQUIRE_PORTAL=true`<br>`REQUIRE_APPLICATION_HUB=true` | see description
    **REQUIRE_<protection-component\>** | A set of variables that can be used to control which **PROTECTION** components are deployed by the script, as follows (with defaults):<br>`REQUIRE_DUMMY_SERVICE_PROTECTION=false`<br>`REQUIRE_ADES_PROTECTION=true`<br>`REQUIRE_RESOURCE_CATALOGUE_PROTECTION=true`<br>`REQUIRE_DATA_ACCESS_PROTECTION=true`<br>`REGISTRATION_API_PROTECTION=true`<br>`REQUIRE_WORKSPACE_API_PROTECTION=true` | see description
    **MINIKUBE_VERSION** | The Minikube version to be (optionally) installed<br>Note that the EOEPCA development has been conducted using the default stated here. | `v1.32.0`
    **MINIKUBE_KUBERNETES_VERSION** | The Kubernetes version to be used by minikube<br>Note that the EOEPCA development has been conducted primarily using version 1.22.5. | `v1.22.5`
    **MINIKUBE_MEMORY_AMOUNT** | Amount of memory to allocate to the docker containers used by minikube to implement the cluster. | `12g`
    **MINIKUBE_DISK_AMOUNT** | Amount of disk space to allocate to the docker containers used by minikube to implement the cluster. | `20g`
    **MINIKUBE_EXTRA_OPTIONS** | Additional options to pass to `minikube start` command-line | `--ports=80:80,443:443`
    **USE_METALLB** | Enable use of minikube's built-in load-balancer.<br>The load-balancer can be used to facilitate exposing services publicly. However, the same can be achieved using minikube's built-in ingress-controller. Therefore, this option is suppressed by default. | `false`
    **USE_INGRESS_NGINX_HELM** | Install the ingress-nginx controller using the published helm chart, rather than relying upon the version that is built-in to minikube. By default we prefer the version that is built in to minikube.  | `false`
    **USE_INGRESS_NGINX_LOADBALANCER** | Patch the built-in minikube nginx-ingress-controller to offer a service of type `LoadBalancer`, rather than the default `NodePort`. It was initially thought that this would be necessary to achieve public access to the ingress services - but was subsequently found that the default `NodePort` configuration of the ingress-controller was sufficient. This option is left in case it proves useful.<br>Only applicable for `USE_INGRESS_NGINX_HELM=false` (i.e. when using the minikube built-in ) | `false`
    **OPEN_INGRESS** | Create 'open' ingress endpoints that are not subject to authorization protection. For a secure system the open endpoints should be disabled (`false`) and access to resource should be protected via [ingress that apply protection](../eoepca/resource-protection-keycloak.md) | `false`
    **USE_TLS** | Indicates whether TLS will be configured for service `Ingress` rules.<br>If not (i.e. `USE_TLS=false`), then the ingress-controller is configured to disable `ssl-redirect`, and `TLS_CLUSTER_ISSUER=notls` is set. | `true`
    **TLS_CLUSTER_ISSUER** | The name of the ClusterIssuer to satisfy ingress tls certificates.<br>Out-of-the-box _ClusterIssuer_ instances are configured in the file `deploy/cluster/letsencrypt.sh`. | `letsencrypt-staging`
    **IDENTITY_SERVICE_DEFAULT_SECRET** | Default secret that is used by exception for other Identity Service credentials | `changeme`
    **IDENTITY_SERVICE_ADMIN_USER** | The admin user for Keycloak | `admin`
    **IDENTITY_SERVICE_ADMIN_PASSWORD** | The admin user password for Keycloak | `${IDENTITY_SERVICE_DEFAULT_SECRET}`
    **IDENTITY_SERVICE_ADMIN_CLIENT** | The Keycloak client to use for admin API tasks during scripted deployment | `admin-cli`
    **IDENTITY_POSTGRES_PASSWORD** | The password for the Keycloak Postgres service | `${IDENTITY_SERVICE_DEFAULT_SECRET}`
    **IDENTITY_GATEKEEPER_CLIENT_SECRET** | The secret used for each Keycloak client (one per resource service) created during scripted deployment | `${IDENTITY_SERVICE_DEFAULT_SECRET}`
    **IDENTITY_GATEKEEPER_ENCRYPTION_KEY** | The encryption key for each Keycloak client (one per resource service) created during scripted deployment<br>NOTE that this must be either 16 or 32 characters long | `changemechangeme`
    **IDENTITY_REALM** | Keycloak realm for Identity Service.<br>_This is not explicitly created by the scripted deployment, and so is assumed to exist within the Keycloak instance. Thus, will probably break the deployment if modified._ | `master`
    **MINIO_ROOT_USER** | Name of the 'root' user for the Minio object storage service. | `eoepca`
    **MINIO_ROOT_PASSWORD** | Password for the 'root' user for the Minio object storage service. | `changeme`
    **HARBOR_ADMIN_PASSWORD** | Password for the 'admin' user for the Harbor artefact registry service. | `changeme`
    **DEFAULT_STORAGE** | _Storage Class_ to be used by default for all components requiring dynamic storage provisioning.<br>See variables `<component>_STORAGE` for per-component overrides. | `standard`
    **<component\>_STORAGE** | A set of variables to control the dynamic provisioning _Storage Class_ for individual components, as follows:<br>MINIO_STORAGE<br>ADES_STORAGE<br>APPLICATION_HUB_STORAGE<br>DATA_ACCESS_STORAGE<br>HARBOR_STORAGE<br>RESOURCE_CATALOGUE_STORAGE | `<DEFAULT_STORAGE>`
    **PROCESSING_MAX_RAM** | Max RAM allocated to an individual processing job | `8Gi`
    **PROCESSING_MAX_CORES** | Max number of CPU cores allocated to an individual processing job | `4`
    **PROCESSING_ZOO_IMAGE** | Container image for `zoo-dru` deployment | `eoepca-092ea7a2c6823dba9c6d52c383a73f5ff92d0762`
    **STAGEOUT_TARGET** | Configures the ADES with the destination to which it should push processing results:<br>`workspace` - via the Workspace API<br>`minio` - to minio S3 object storage | `workspace`
    **INSTALL_FLUX** | The Workspace API relies upon [Flux CI/CD](https://fluxcd.io/), and has the capability to install the required flux components to the cluster. If your deployment already has flux installed then set this value `false` to suppress the Workspace API flux install | `true`
    **CREODIAS_DATA_SPECIFICATION** | Apply the data specification to harvest from the CREODIAS data offering into the resource-catalogue and data-access services.<br>_Can only be used when running in the CREODIAS (Cloudferro) cloud, with access to the `eodata` network._ | `false`
    **TEMP_FORWARDING_PORT** | Local port used during the scripted deployment for `kubectl port-forward` operations | `9876`

### Command-line Arguments

The eoepca.sh script is further configured via command-line arguments...

```bash
eoepca.sh <action> <cluster-name> <domain> <public-ip>
```

??? example "`eoepca.sh` Command-line Arguments"
    Argument | Description | Default
    -------- | ----------- | -------
    **action** | Action to perform: `apply` \| `delete` \| `template`.<br>`apply` makes the deployment<br>`delete` removes the deployment<br>`template` outputs generated kubernetes yaml to stdout | `apply`
    **cluster-name** | The name of the minikube 'profile' for the created minikube cluster | `eoepca`
    **domain** | The DNS domain name through which the deployment is accessed. Forms the stem for all service hostnames in the ingress rules - i.e. `<service-name>.<domain>`.<br>By default, the value is deduced from the assigned cluster minikube IP address, using `nip.io` to establish a DNS lookup - i.e. `<minikube ip>.nip.io`. | `<minikube ip>.nip.io`
    **public-ip** | The public IP address through which the deployment is exposed via the ingress-controller.<br>By default, the value is deduced from the assigned cluster minikube IP address - ref. command `minikube ip`. | `<minikube-ip>`

### Public Deployment

For simplicity, the out-of-the-box scripts assume a 'private' deployment - with no public IP / DNS and hence no use of TLS for service ingress endpoints.

In the case that an external-facing public deployment is desired, then the following configuration selections should be made:

* `domain` - set to the domain (as per DNS records) for your deployment<br>
  _Note that the EOEPCA components typically configure their ingress with hostname prefixes applied to this `domain`. Thus, it is necessary that the DNS record for the domain is established as a wildcard record - i.e. `*.<domain>`_
* `public_ip` - set to the public IP address through which the deployment is exposed via the ingress-controller<br>
  _i.e. the IP address that is assigned to the ingress controller service of type LoadBalancer_
* `USE_TLS=true` - to enable configuration of TLS endpoints in each component service ingress
* `TLS_CLUSTER_ISSUER=<issuer>` - should be configured ~ e.g. using the `letsencrypt-production` or `letsencrypt-staging` (testing only) _Cluster Issuer_ that are configured by the scripted deployment

## Deployment

The deployment is initiated by setting the appropriate [environment variables](#environment-variables) and invoking the `eoepca.sh` script with suitable [command-line arguments](#command-line-arguments). You may find it convenient to do so using a wrapper script that customises the environment varaibles according to your cluster, and then invokes the `eoepca.sh` script.

Customised examples are provided for Simple, CREODIAS and Processing deployments.

**_NOTE that if a prior deployment has been attempted then, before redeploying, a clean-up should be performed as described in the [Clean-up](#clean-up) section below. This is particularly important in the case that the minikube `none` driver is used, as the persistence is maintained on the host and so is not naturally removed when the minikube cluster is destroyed._**

Initiate the deployment...
```bash
./deploy/eoepca/eoepca.sh apply "<cluster-name>" "<public-ip>" "<domain>"
```

The deployment takes 10+ minutes - depending on the resources of your host/cluster. The progress can be monitored...
```bash
kubectl get pods -A
```

The deployment is ready once all pods are either `Running` or `Completed`.

## Post-deployment Manual Steps

The scripted deployment has been designed, as far as possible, to automate the configuration of the deployed components. However, there remain some steps that must be performed manually after the scripted deployment has completed.<br>
See the building block specific pages...

* **Identity Service:** [Token Lifespans](../eoepca/identity-service.md#token-lifespans)
* **Application Hub:** [Post-deployment Manual Steps](../eoepca/application-hub.md#post-deployment-manual-steps)

## Default Credentials

### Identity Service

By default, the Identity Service is accessed at the URL `https://keycloak.192-168-49-2.nip.io/` with the credentials...

```
username: `admin`
password: `changeme`
```

...unless the password is overridden via the variable `IDENTITY_SERVICE_ADMIN_PASSWORD`.

### Minio Object Storage

By default, Minio is accessed at the URL `https://console.minio.192-168-49-2.nip.io/` with the credentials...

```
username: `eoepca`
password: `changeme`
```

...unless the username/password are overridden via the variables `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD`.

### Harbor Container Registry

By default, Harbor is accessed at the URL `https://harbor.192-168-49-2.nip.io/` with the credentials...

```
username: `admin`
password: `changeme`
```

...unless the password is overridden via the variable `HARBOR_ADMIN_PASSWORD`.

## Protection

The protection of resource server endpoints is applied during the deployment of each service requiring protection. This comprises creating a dedicated Keycloak client for each resource server, and the creation of associated resources and policies that protect the service-specific URLs.

This protection can be disabled via the environment variables `REQUIRE_XXX_PROTECTION` - e.g. `REQUIRE_ADES_PROTECTION=false`.

!!! note
    By default, if `OPEN_INGRESS` is set `true` then `PROTECTION` will be disabled (`false`) unless overridden via the `REQUIRE_XXX_PROTECTION` variables.

## Test Users

The deployment creates (in the Keycloak Identity Service) the test users: `eric`, `bob`, `alice`.

!!! note
    This does NOT create the workspace for each of these users - which must be performed via the Workspace API.

## User Workspace Creation

The deployment created the test users `eric`, `bob` and `alice`. For completeness we use the Workspace API to create their user workspaces, which hold their personal resources (data, processing results, etc.) within the platform - see [Workspace](../eoepca/workspace.md).

### Using Workspace Swagger UI

The Workspace API provides a Swagger UI that facilitates interaction with the API - at the URL `https://workspace-api.192-168-49-2.nip.io/docs#`.

!!! note
    If the Workspace API has been protected ([via Gatekeeper with Keycloak](../eoepca/identity-service.md#protection-of-resources)), then requests must be supported by an `access_token` carried in the HTTP header `Authorozation: Bearer <token>`. This diminishes the utility of the swagger UI.

Access the Workspace Swagger UI at `https://workspace-api.192-168-49-2.nip.io/docs`. Workspaces are created using `POST  /workspaces` **(Create Workspace)**. Expand the node and select `Try it out`. Complete the request body, such as...
```json
{
  "preferred_name": "eric",
  "default_owner": "eric"
}
```
...where the `default_owner` is the ID for the user in Keycloak - thus protecting the created workspace for the identified user.

### Using `curl`

The same can be achieved with a straight http request, for example using `curl`...

```bash
curl -X 'POST' \
  'http://workspace-api.192-168-49-2.nip.io/workspaces' \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -H 'Authorization: Bearer <admin-access-token>' \
  -d '{
  "preferred_name": "<workspace-name>",
  "default_owner": "<user-id>"
}'
```

Values must be provided for:

* `admin-access-token` - Access Token for the admin user
* `workspace-name` - name of the workspace, typically the username
* `user-id` - the ID of the user for which the created workspace will be protected, typically the username

The Access Token for the `admin` user can be obtained with a call to the token endpoint of the Identity Service - supplying the credentials for the `admin` user and the pre-registered client...

```bash
curl -L -X POST 'https://keycloak.192-168-49-2.nip.io/realms/master/protocol/openid-connect/token' \
  -H 'Cache-Control: no-cache' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'scope=openid profile email' \
  --data-urlencode 'grant_type=password' \
  --data-urlencode 'username=admin' \
  --data-urlencode 'password=<admin-password>' \
  --data-urlencode 'client_id=admin-cli'
```

A json response is returned, in which the field `access_token` provides the Access Token for the `admin` user.

### Using `create-workspace` helper script

As an aide there is a helper script [`create-workspace`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.4/deploy/bin/create-workspace). The script is available in the [`deployment-guide` repository](https://github.com/EOEPCA/deployment-guide), and can be obtained as follows...

```bash
git clone -b eoepca-v1.4 git@github.com:EOEPCA/deployment-guide
cd deployment-guide
```

The `create-workspace` helper script requires some command-line arguments...

```
$ ./deploy/bin/create-workspace -h

Create a new User Workspace.
create-workspace -h | -w {workspace_api} -a {auth_server} -r {realm} -c {client} -u {admin-username} -p {admin-password} -O {owner} -W {workspace-name}

where:
    -h  show help message
    -w  workspace-api service url (default: http://workspace-api.192-168-49-2.nip.io)
    -a  authorization server url (default: http://keycloak.192-168-49-2.nip.io)
    -r  realm within Keycloak (default: master)
    -u  username used for authentication (default: admin)
    -p  password used for authentication (default: changeme)
    -c  client id of the bootstrap client used in the create request (default: admin-cli)
    -O  user ID of the 'owner' of the new workspace (default: workspace(-W))
    -W  name of the workspace to create (default: owner(-O))
```

Most of the arguments have default values that are aligned to the defaults of the scripted deployment.<br>
At minimum either `-O owner` or `-W workspace` must be specified.

For example (assuming defaults)...

```bash
./deploy/bin/create-workspace -O eric
```

For example (all arguments)...

```bash
./deploy/bin/create-workspace 
  -w http://workspace-api.192-168-49-2.nip.io \
  -a http://keycloak.192-168-49-2.nip.io \
  -r master \
  -u admin \
  -p changeme \
  -c admin-cli \
  -O bob \
  -W bob
```

## EOEPCA Portal

The `eoepca-portal` is a simple web application that is used as a test aid. It's main purpose is to provide the ability to login, and so establish a session with appropriate browser cookies - which then allow authenticated access to other EOEPCA services such as the Workspace API, Identity API, etc.

The portal is deployed via a helm chart...

```bash
helm install eoepca-portal eoepca-portal -f portal-values.yaml - \
  --repo https://eoepca.github.io/helm-charts \
  --namespace "demo" --create-namespace \
  --version 1.0.11
```

The helm values must be tailored for your deployment.<br>
For example...

```yaml
configMap:
  identity_url: "http://keycloak.192-168-49-2.nip.io"
  realm: "master"
  client_id: "eoepca-portal"
  identity_api_url: "http://identity-api.192-168-49-2.nip.io"
  ades_url: "http://zoo.192-168-49-2.nip.io/ogc-api/processes"
  resource_catalogue_url: "http://resource-catalogue.192-168-49-2.nip.io"
  data_access_url: "http://data-access.192-168-49-2.nip.io"
  workspace_url: "http://workspace-api.192-168-49-2.nip.io"
  workspace_docs_url: "http://workspace-api.192-168-49-2.nip.io/docs#"
  images_registry_url: "http://harbor.192-168-49-2.nip.io"
  dummy_service_url: "http://dummy-service.192-168-49-2.nip.io"
  access_token_name: "auth_user_id"
  access_token_domain: ".192-168-49-2.nip.io"
  refresh_token_name: "auth_refresh_token"
  refresh_token_domain: ".192-168-49-2.nip.io"
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-production
  hosts:
    - host: eoepca-portal.192-168-49-2.nip.io
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: eoepca-portal-tls
      hosts:
        - eoepca-portal.192-168-49-2.nip.io
```

The setting `client_id: eoepca-portal` identifies a client that must be created in Keycloak - as described in section [`create-client` Helper Script](../eoepca/identity-service.md#create-client-helper-script) - noting that the `eoepca-portal` requires a client that is configured as a `Public Client`...

```bash
../bin/create-client \
  -a https://keycloak.192-168-49-2.nip.io \
  -i https://identity-api.192-168-49-2.nip.io \
  -r "master" \
  -u "admin" \
  -p "changeme" \
  -c "admin-cli" \
  --id=eoepca-portal \
  --name="EOEPCA Portal" \
  --public \
  --description="Client to be used by the EOEPCA Portal"
```

## Clean-up

Before initiating a fresh deployment, if a prior deployment has been attempted, then it is necessary to remove any persistent artefacts of the prior deployment. This includes...

1. **Minikube cluster**<br>
  Delete the minikube cluster...<br>
  `minikube delete`<br>
  If necessary specify the cluster (profile)...<br>
  `minikube -p <profile> delete`<br>

1. **Persistent Data**<br>
  In the case that the minikube `none` driver is used, the persistence is maintained on the host and so is not naturally removed when the minikube cluster is destroyed. In this case, the minikube `standard` _StorageClass_ is fulfilled by the `hostpath` provisioner, whose persistence is removed as follows...<br>
  `sudo rm -rf /tmp/hostpath-provisioner`

There is a helper script [`clean`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.4/deploy/cluster/clean) that can be used for step 2 above, (the script does not delete the cluster).
```bash
./deploy/cluster/clean
```
