# Scripted Deployment

The Scripted Deployment provides a demonstration of an example deployment, and can found in the subdirectory [`deployment-guide/deploy`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/eoepca/eoepca.sh) of the source repository for this guide...

```bash
git clone https://github.com/EOEPCA/deployment-guide \
&& cd deployment-guide \
&& ls deploy
```

The script [`deploy/eoepca/eoepca.sh`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/eoepca/eoepca.sh) acts as an entry-point to the full system deployment. In order to tailor the deployment for your target environment, the script is configured through environment variables and command-line arguments. By default the script assumes deployment to a local minikube.

The following subsections lead through the steps for a full local deployment. Whilst minikube is assumed, minimal adaptions are required to make the deployment to your existing Kubernetes cluster.

The deployment follows these broad steps:

* **Configuration**<br>
  Tailoring of deployment options.
* **Deployment**<br>
  Creation of cluster and deployment of eoepca services.
* **Protection**<br>
  Application of protection for authorized access to services.

The Protection step is split from Deployment as there are some manual steps to be performed before the Protection can be applied.

## Configuration

The script [`deploy/eoepca/eoepca.sh`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/eoepca/eoepca.sh) is configured by some environment variables and command-line arguments.

### Environment Variables

Variable | Description | Default
-------- | ----------- | -------
**REQUIRE_<cluster-component\>** | A set of variables that can be used to control which **CLUSTER** components are deployed by the script, as follows (with defaults):<br>`REQUIRE_MINIKUBE=true`<br>`REQUIRE_INGRESS_NGINX=true`<br>`REQUIRE_CERT_MANAGER=true`<br>`REQUIRE_LETSENCRYPT=true`<br>`REQUIRE_SEALED_SECRETS=false`<br>`REQUIRE_MINIO=false` | see description
**REQUIRE_<eoepca-component\>** | A set of variables that can be used to control which **EOEPCA** components are deployed by the script, as follows (with defaults):<br>`REQUIRE_STORAGE=true`<br>`REQUIRE_DUMMY_SERVICE=false`<br>`REQUIRE_LOGIN_SERVICE=true`<br>`REQUIRE_PDP=true`<br>`REQUIRE_USER_PROFILE=true`<br>`REQUIRE_ADES=true`<br>`REQUIRE_RESOURCE_CATALOGUE=true`<br>`REQUIRE_DATA_ACCESS=true`<br>`REQUIRE_WORKSPACE_API=true`<br>`REQUIRE_BUCKET_OPERATOR=true`<br>`REQUIRE_HARBOR=true`<br>`REQUIRE_PORTAL=true`<br>`REQUIRE_PDE=true` | see description
**REQUIRE_<protection-component\>** | A set of variables that can be used to control which **PROTECTION** components are deployed by the script, as follows (with defaults):<br>`REQUIRE_DUMMY_SERVICE_PROTECTION=false`<br>`REQUIRE_ADES_PROTECTION=true`<br>`REQUIRE_RESOURCE_CATALOGUE_PROTECTION=true`<br>`REQUIRE_DATA_ACCESS_PROTECTION=true`<br>`REQUIRE_WORKSPACE_API_PROTECTION=true` | see description
**USE_MINIKUBE_NONE_DRIVER** | Force use of the minikube 'none' driver.<br>The 'none' driver has been found to be useful to more easily expose the kubernetes cluster for external access, e.g. via `ingress-controller`. This, in turn, facilitates the use of letsencrypt to establish TLS certificates. | `true`
**MINIKUBE_KUBERNETES_VERSION** | The Kubernetes version to be used by minikube<br>Note that the EOEPCA development has been conducted primarily using version 1.22.5. | `v1.22.5`
**MINIKUBE_MEMORY_AMOUNT** | Amount of memory to allocate to the docker containers used by minikube to implement the cluster. | `12g`
**USE_METALLB** | Enable use of minikube's built-in load-balancer.<br>The load-balancer can be used to facilitate exposing services publicly. However, the same can be achieved using minikube's built-in ingress-controller. Therefore, this option is suppressed by default. | `false`
**USE_INGRESS_NGINX_HELM** | Install the ingress-nginx controller using the published helm chart, rather than relying upon the version that is built-in to minikube. By default we prefer the version that is built in to minikube.  | `false`
**USE_INGRESS_NGINX_LOADBALANCER** | Patch the built-in minikube nginx-ingress-controller to offer a service of type `LoadBalancer`, rather than the default `NodePort`. It was initially thought that this would be necessary to achieve public access to the ingress services - but was subsequently found that the default `NodePort` configuration of the ingress-controller was sufficient. This option is left in case it proves useful.<br>Only applicable for `USE_INGRESS_NGINX_HELM=false` (i.e. when using the minikube built-in ) | `false`
**OPEN_INGRESS** | Create 'open' ingress endpoints that are not subject to authorization protection. For a secure system the open endpoints should be disabled (`false`) and access to resource should be protected via [ingress that apply protection](../eoepca/resource-protection.md) | `false`
**USE_TLS** | Indicates whether TLS will be configured for service `Ingress` rules.<br>If not (i.e. `USE_TLS=false`), then the ingress-controller is configured to disable `ssl-redirect`, and `TLS_CLUSTER_ISSUER=notls` is set. | `true`
**TLS_CLUSTER_ISSUER** | The name of the ClusterIssuer to satisfy ingress tls certificates.<br>Out-of-the-box _ClusterIssuer_ instances are configured in the file `deploy/cluster/letsencrypt.sh`. | `letsencrypt-staging`
**LOGIN_SERVICE_ADMIN_PASSWORD** | Initial password for the `admin` user in the login-service. | `changeme`
**MINIO_ROOT_USER** | Name of the 'root' user for the Minio object storage service. | `eoepca`
**MINIO_ROOT_PASSWORD** | Password for the 'root' user for the Minio object storage service. | `changeme`
**HARBOR_ADMIN_PASSWORD** | Password for the 'admin' user for the Harbor artefact registry service. | `changeme`
**STAGEOUT_TARGET** | Configures the ADES with the destination to which it should push processing results:<br>`workspace` - via the Workspace API<br>`minio` - to minio S3 object storage | `workspace`
**INSTALL_FLUX** | The Workspace API relies upon [Flux CI/CD](https://fluxcd.io/), and has the capability to install the required flux components to the cluster. If your deployment already has flux installed then set this value `false` to suppress the Workspace API flux install | `true`
**CREODIAS_DATA_SPECIFICATION** | Apply the data specification to harvest from the CREODIAS data offering into the resource-catalogue and data-access services.<br>_Can only be used when running in the CREODIAS (Cloudferro) cloud, with access to the `eodata` network._ | `false`

### Openstack Configuration

There are some additional environment variables that configure the `BucketOperator` with details of the infrastructure Openstack layer.

NOTE that this is only applicable for an Openstack deployment and has only been tested on the CREODIAS.

Variable | Description | Default
-------- | ----------- | -------
**OS_DOMAINNAME** | Openstack domain of the admin account in the cloud provider. | `cloud_XXXXX`
**OS_USERNAME** | Openstack username of the admin account in the cloud provider. | `user@cloud.com`
**OS_PASSWORD** | Openstack password of the admin account in the cloud provider. | `none`
**OS_MEMBERROLEID** | ID of a specific role (e.g. the '_member_' role) for operations users (to allow administration), e.g. `7fe2ff9ee5384b1894a90838d3e92bab`. | `none`
**OS_SERVICEPROJECTID** | ID of a project containing the user identity requiring write access to the created user buckets, e.g. `573916ef342a4bf1aea807d0c6058c1e`. | `none`
**USER_EMAIL_PATTERN** | Email associated to the created user within the created user project.<br>_Note: `<name>` is templated and will be replaced._ | `eoepca-<name>@platform.com`

### Command-line Arguments

The eoepca.sh script is further configured via command-line arguments...

**```
Usage: eoepca.sh <action> <cluster-name> <public-ip> <domain>
```**

Argument | Description | Default
-------- | ----------- | -------
**action** | Action to perform: `apply` \| `delete` \| `template`.<br>`apply` makes the deployment<br>`delete` removes the deployment<br>`template` outputs generated kubernetes yaml to stdout | `apply`
**cluster-name** | The name of the minikube 'profile' for the created minikube cluster.<br>Note that this option is ignored if `USE_MINIKUBE_NONE_DRIVER=true` as the 'none' driver does not support multiple profiles. | `eoepca`
**public-ip** | The public IP address through which the deployment is exposed via the ingress-controller.<br>By default, the value is deduced from the assigned cluster minikube IP address - ref. command `minikube ip`. | `<minikube-ip>`
**domain** | The DNS domain name through which the deployment is accessed. Forms the stem for all service hostnames in the ingress rules - i.e. `<service-name>.<domain>`.<br>By default, the value is deduced from the assigned cluster minikube IP address, using `nip.io` to establish a DNS lookup - i.e. `<minikube ip>.nip.io`. | `<minikube ip>.nip.io`

### Private Deployment

In the case that a 'private' deployment is required - i.e. with no public IP - then the following configuration selections should be made:

* `public_ip` - leave blank to fall-back to minikube ip default
* `domain` - leave blank to fall-back to minikube ip default
* `USE_MINIKUBE_NONE_DRIVER=false` - the `none` driver is mostly useful only with a public IP
* `USE_TLS=false` - difficult to configure letsencrypt without a public IP

## Deployment

The deployment is initiated by setting the appropriate [environment variables](#environment-variables) and invoking the `eoepca.sh` script with suitable [command-line arguments](#command-line-arguments). You may find it convenient to do so using a wrapper script that customises the environment varaibles according to your cluster, and then invokes the `eoepca.sh` script.

Customised examples are provided for Simple, CREODIAS and Processing deployments.

**_NOTE that if a prior deployment has been attempted then, before redeploying, a clean-up should be performed as described in the [Clean-up](#clean-up) section below. This is particularly important in the case that the minikube 'none' driver is used, as the persistence is maintained on the host and so is not naturally removed when the minikube cluster is destroyed._**

Initiate the deployment...
```bash
./deploy/eoepca/eoepca.sh apply "<cluster-name>" "<public-ip>" "<domain>"
```

The deployment takes 10+ minutes - depending on the resources of your host/cluster. The progress can be monitored...
```bash
kubectl get pods -A
```

The deployment is ready once all pods are either `Running` or `Completed`. This can be further confirmed by accessing the login-service web interface at `https://auth.<domain>/` and logging in as user `admin` using the credentials configured via `LOGIN_SERVICE_ADMIN_PASSWORD`.

## Default Credentials

### Login Service

By default, the Login Service is accessed at the URL `https://auth.<domain>/` with the credentials...

```
username: admin
password: Chang3me!
```

...unless the password is overridden via the variable `LOGIN_SERVICE_ADMIN_PASSWORD`.

### Minio Object Storage

By default, Minio is accessed at the URL `http://minio-console.<domain>/` with the credentials...

```
username: eoepca
password: changeme
```

...unless the username/password are overridden via the variables `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD`.

### Harbor Container Registry

By default, Harbor is accessed at the URL `https://harbor.<domain>/` with the credentials...

```
username: admin
password: changeme
```

...unless the password is overridden via the variable `HARBOR_ADMIN_PASSWORD`.

## Protection

The protection of resource server endpoints is applied with the script `deploy/eoepca/eoepca-protection.sh`. This script should be executed with environment variables and command-line options that are consistent with those of the main deployment (ref. script `eoepca.sh`).

The script `eoepca-protection.sh` introduces two users `eric` and `bob` to demonstrate the application of authorized access to various service endpoints: ADES, Workspace API and dummy-service (simple endpoint used for debugging).

Thus, the users must [first be created](#create-test-users) in the login-service and their unique IDs passed to the protection script.

```
Usage: eoepca-protection.sh <action> <eric-id> <bob-id> <public-ip> <domain>
```

### Create Test Users

Access the login-service web interface (`https://auth.<domain>/`) as user admin using the credentials configured via `LOGIN_SERVICE_ADMIN_PASSWORD`.

Select `Users -> Add person` to add users `eric` and `bob` (dummy details can be used). Note the `Inum` (unique user ID) for each user for use with the `eoepca-protection.sh` script.

### Apply Protection

Apply the protection...<br>
_Ensure that the script is executed with the environment variables and command-line options that are consistent with those of the main [deployment](#deployment)._

```bash
./deploy/eoepca/eoepca-protection.sh apply "<eric-id>" "<bob-id>" "<public-ip>" "<domain>"
```

## Create User Workspaces

The protection steps created the test users `eric` and `bob`. For completeness we use the Workspace API to create their user workspaces, which hold their personal resources (data, processing results, etc.) within the platform - see [Workspace](../workspace/).

### Using Workspace Swagger UI

The Workspace API provides a Swagger UI that facilitates interaction with the API - at the URL `https://workspace-api.<domain>/docs#`. Access to The Workspace API is protected, such that the necessary access tokens must be supplied in requests, which is most easily achieved by logging in via the 'portal'.

The portal is accessed at `https://portal.<domain>/`. It is a rudimentary web service that facilitates establishing the appropriate tokens in the user's browser context. Login to the portal as the `admin` user, using the configured credentials.

Access the Workspace Swagger UI at `https://workspace-api.<domain>/docs`. Workspaces are created using `POST  /workspaces` **(Create Workspace)**. Expand the node and select `Try it out`. Complete the request body, such as...
```json
{
  "preferred_name": "eric",
  "default_owner": "d95b0c2b-ea74-4b3f-9c6a-85198dec974d"
}
```
...where the `default_owner` is the user ID (`Inum`) for the user - thus protecting the created workspace for the identified user.

### Using `curl`

The same can be achieved with a straight http request, for example using `curl`...

```bash
curl -X 'POST' \
  'https://workspace-api.192.168.49.2.nip.io/workspaces' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -H 'X-User-Id: <admin-id-token>' \
  -d '{
  "preferred_name": "<workspace-name>",
  "default_owner": "<user-inum>"
}'
```

Values must be provided for:

* `admin-id-token` - User ID token for the admin user
* `workspace-name` - name of the workspace, typically the username
* `user-inum` - the ID of the user for which the created workspace will be protected

The ID token for the `admin` user can be obtained with a call to the token endpoint of the Login Service - supplying the credentials for the `admin` user and the pre-registered client...

```bash
curl -L -X POST 'https://auth.<domain>/oxauth/restv1/token' \
  -H 'Cache-Control: no-cache' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'scope=openid user_name is_operator' \
  --data-urlencode 'grant_type=password' \
  --data-urlencode 'username=admin' \
  --data-urlencode 'password=<admin-password>' \
  --data-urlencode 'client_id=<client-id>' \
  --data-urlencode 'client_secret=<client-secret>'
```

A json response is returned, in which the field `id_token` provides the user ID token for the `admin` user.

### Using `create-workspace` helper script

As an aide there is a helper script [`create-workspace`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/bin/create-workspace). The script is available in the [`deployment-guide` repository](https://github.com/EOEPCA/deployment-guide), and can be obtained as follows...

```bash
git clone git@github.com:EOEPCA/deployment-guide
cd deployment-guide
```

The `create-workspace` helper script requires some command-line arguments...

```
Usage:
  create-workspace <domain> <user> <user-inum> [<client-id> <client-secret>]
```

For example...

```bash
./deploy/bin/create-workspace 192.168.49.2.nip.io eric d95b0c2b-ea74-4b3f-9c6a-85198dec974d
```

The script prompts for the password of the `admin` user.

By default `<client-id>` and `<client-secret>` are read from the `client.yaml` file that is created by the deployment script, which auto-registers a Login Service client. Thus, these args can be ommited to use the default client credentials.

## Clean-up

Before initiating a fresh deployment, if a prior deployment has been attempted, then it is necessary to remove any persistent artefacts of the prior deployment. This includes...

1. **Minikube cluster**<br>
  Delete the minikube cluster...<br>
  `minikube delete`<br>
  If necessary specify the cluster (profile)...<br>
  `minikube -p <profile> delete`<br>

2. **Persistent Data**<br>
  In the case that the minikube `none` driver is used, the persistence is maintained on the host and so is not naturally removed when the minikube cluster is destroyed. In this case, the minikube `standard` _StorageClass_ is fulfilled by the `hostpath` provisioner, whose persistence is removed as follows...<br>
  `sudo rm -rf /tmp/hostpath-provisioner`

1. **Client Credentials**<br>
  During the deployment a client of the Authorisation Server is registered, and its credentials stored for reuse in the file `client.yaml`. Once the cluster has been destroyed, then these client credentials become stale and so should be removed to avoid polluting subsequent deployments...<br>
  `rm -rf ./deploy/eoepca/client.yaml`

There is a helper script [`clean`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/cluster/clean) that can be used for steps 2 and 3 above, (the script does not delete the cluster).
```bash
./deploy/cluster/clean
```
