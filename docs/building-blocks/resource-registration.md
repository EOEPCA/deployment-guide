# Resource Registration Deployment Guide

The **Resource Registration** Building Block enables data and metadata ingestion into platform services. It handles:

- Metadata registration into Resource Discovery
- Data registration into Data Access services
- Resource visualisation configuration

---

## Introduction

The **Resource Registration Building Block** manages resource ingestion into the platform for discovery, access and collaboration. It supports:

- Datasets (EO data, auxiliary data)
- Processing workflows 
- Jupyter Notebooks
- Web services and applications
- Documentation and metadata

The BB integrates with other platform services to enable:

- Automated metadata extraction
- Resource discovery indexing
- Access control configuration
- Usage tracking

---

## Components Overview

The Resource Registration BB comprises three main components:

1. **Registration API**  
An OGC API Processes interface for registering, updating, or deleting resources on the local platform.
    
2. **Harvester**  
Automates workflows (via Flowable BPMN) to harvest data from external sources. This guide demonstrates harvesting Landsat data from USGS.
    
3. **Common Registration Library**  
A Python library consolidating upstream packages (e.g. STAC tools, eometa tools) for business logic in workflows and resource handling.

---

## Prerequisites

Before deploying the Resource Registration Building Block, ensure you have the following:

| Component          | Requirement                              | Documentation Link                                                |
| ------------------ | ---------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.32)                | [Installation Guide](../prerequisites/kubernetes.md)             |
| Helm               | Version 3.7 or newer                     | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access            | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| TLS Certificates   | Managed via `cert-manager` or manually   | [TLS Certificate Management Guide](../prerequisites/tls.md) |
| Ingress Controller | Properly installed (e.g., NGINX, APISIX) | [Installation Guide](../prerequisites/ingress/overview.md)      |
| Crossplane         | Properly installed (if OIDC protected)   | [Installation Guide](../prerequisites/crossplane.md) |

**Clone the Deployment Guide Repository:**
```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/resource-registration
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:
```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script

Generate configuration files and prepare deployment:
```bash
bash configure-resource-registration.sh
```

**Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
    - *Example*: `example.com`
- **`CLUSTER_ISSUER`**: Cert-Manager ClusterIssuer for TLS certificates.
    - *Example*: `letsencrypt-http01-apisix`
- **`FLOWABLE_ADMIN_USER`**: Admin username for Flowable.
    - *Default*: `eoepca`
- **`FLOWABLE_ADMIN_PASSWORD`**: Admin password for Flowable.
    - *Default*: `eoepca`
- **`PERSISTENT_STORAGECLASS`**: Storage Class for persistent volumes (ReadWriteOnce) - e.g. for `Flowable` database.
    - *Default*: `local-path`
- **`SHARED_STORAGECLASS`**: Storage Class for shared volumes (ReadWriteMany) - e.g. harvested `eodata`.
    - *Default*: `standard`
    > Note that `RWX` is specified for the `eodata` volume to which the harvester downloads harvested assets. A `RWX` volume is assumed here, in anticipation that other services (pods) will require to exploit the data assets.
- **`RESOURCE_REGISTRATION_ENABLE_OIDC`**: Whether the Resource Registration endpoints should be protected via OIDC authentication.
    - *Default*: `yes`
- **`RESOURCE_REGISTRATION_PROTECTED_TARGETS`**: Whether the Resource Registration target services for resource registration are protected via OIDC authentication. In this case the Resource Registration (API and harvester) must act as OIDC clients to authenticate against these services.
    - *Default*: `yes`
- **`RESOURCE_REGISTRATION_IAM_CLIENT_ID`**: The Client ID used both for ingress protection of Resource Registration services, and for Resource Registration to authenticate against protected target services. The associated `CLIENT_SECRET` will be generated.
    - *Default*: `resource-registration`
- **`EODATA_ASSET_BASE_URL`**: The base URL through which harvested 'eodata' assets will be accessed
    - *Default*: `"${HTTP_SCHEME}://eodata.${INGRESS_HOST}/"`

### 2. Apply Kubernetes Secrets

Create required secrets for the Registration API and Harvester components:

```bash
bash apply-secrets.sh
```

During the script execution, you'll be prompted for optional external service credentials:

#### USGS M2M Credentials (for Landsat harvesting)

> For the purpose of this demonstration, we advise you to create this account so we can showcase the Landsat harvesting capabilities of the Registration Harvester.

If you want to harvest Landsat data, you'll need credentials from [USGS Machine-to-Machine (M2M) API](https://m2m.cr.usgs.gov/):

1. Register for a free account at USGS
2. Use the [Generate Application Token](https://ers.cr.usgs.gov/password/appgenerate) page 
3. Create a token with the `M2M API` scope
4. Enter these credentials when prompted by the script

#### CDSE Credentials (for Sentinel harvesting)

If you plan to harvest Sentinel data from the Copernicus Data Space Ecosystem (CDSE), you'll need to provide CDSE credentials:

1. Register for a free account at [CDSE](https://dataspace.copernicus.eu/)
2. Enter your email address (as your username) and your password when prompted

### 3. Deploy the Registration API Using Helm

The Registration API provides a RESTful interface through which resources can be directly registered, updated, or deleted.

Deploy the Registration API using the generated values file:
```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev
helm repo update eoepca-dev
helm upgrade -i registration-api eoepca-dev/registration-api \
  --version 2.0.0-rc5 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-api/generated-values.yaml
```

Deploy the ingress routes:
```bash
kubectl apply -f registration-api/generated-ingress.yaml
```

### 4. Deploy the Registration Harvester Components

The Registration Harvester consists of the Flowable engine and worker deployments.

#### Deploy Flowable Engine
```bash
helm repo add flowable https://flowable.github.io/helm/
helm repo update flowable
helm upgrade -i registration-harvester-api-engine flowable/flowable \
  --version 7.0.0 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-harvester/generated-values.yaml
```

Deploy the ingress for the Flowable Engine:
```bash
kubectl apply -f registration-harvester/generated-ingress.yaml
```

#### Shared `eodata` Volume

Each harvester worker stores their harvested data into a kubernetes persistent volume. We establish a single shared `eodata` volume to collate the outputs of all workers - and also to provide a single asset location to facilitate delivery of data through external services.

The volume must be created as `ReadWriteMany` - and thus should use the `SHARED_STORAGECLASS` specified at the earlier configuration step.

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: eodata
  namespace: resource-registration
  labels:
    app.kubernetes.io/name: registration-harvester
    app.kubernetes.io/component: eodata-storage
  annotations:
    helm.sh/resource-policy: keep
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ${SHARED_STORAGECLASS}
  resources:
    requests:
      storage: 100Gi
EOF
```

Each worker instance is then configured to use this persistent volume via helm values - for example, see helm values file `registration-harvester/harvester-values/values-landsat.yaml`...

```
harvester:
  eodata:
    enabled: true
    createPVC: false
    claimName: eodata
```

> Note that, alternative to directly creating the volume as above, the worker helm chart can be configured to create the volume itself...
>
> ```
> harvester:
>   eodata:
>     enabled: true
>     createPVC: true
>     claimName: eodata
>     storageClass: ${SHARED_STORAGECLASS}
> ```
>
> Subsequent worker instances should then be configured to use (rather than create) this existing volume...
> 
> ```
> harvester:
>   eodata:
>     enabled: true
>     createPVC: false
>     claimName: eodata
> ```

#### Deploy Landsat Harvester Worker

Deploy the worker that executes Landsat harvesting tasks:

```bash
helm upgrade -i registration-harvester-worker-landsat eoepca-dev/registration-harvester \
  --version 2.0.0-rc3 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-harvester/harvester-values/values-landsat.yaml
```

#### Deploy the Sentinel Harvester Worker

Deploy the worker that harvests Sentinel data from CDSE:

```bash
helm upgrade -i registration-harvester-worker-sentinel eoepca-dev/registration-harvester \
  --version 2.0.0-rc3 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-harvester/harvester-values/values-sentinel.yaml
```

### 5. Monitor the Deployment

Check the status of all deployments:
```bash
kubectl get all -n resource-registration
```

Verify all pods are running:
```bash
kubectl get pods -n resource-registration
```

### 6. Create the Keycloak Client for Resource Registration

A Keycloak client is required for Resource Registration for two purposes:

1. We want to protect the Resource Registration endpoints via OIDC<br>
   _Ref. `RESOURCE_REGISTRATION_ENABLE_OIDC`_
2. The Resource Registration needs to connect with other services that are protected via OIDC (e.g., resource-catalogue, eoapi)<br>
   _Ref. `RESOURCE_REGISTRATION_PROTECTED_TARGETS`_

> If neither of these apply, you can skip this step.

The client can be created using the Crossplane Keycloak provider via the `Client` CRD.

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${RESOURCE_REGISTRATION_IAM_CLIENT_ID}-keycloak-client
  namespace: iam-management
stringData:
  client_secret: ${RESOURCE_REGISTRATION_IAM_CLIENT_SECRET}
---
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: ${RESOURCE_REGISTRATION_IAM_CLIENT_ID}
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    clientId: ${RESOURCE_REGISTRATION_IAM_CLIENT_ID}
    name: Resource Registration
    description: Resource Registration OIDC
    enabled: true
    accessType: CONFIDENTIAL
    rootUrl: ${HTTP_SCHEME}://registration-api.${INGRESS_HOST}
    baseUrl: ${HTTP_SCHEME}://registration-api.${INGRESS_HOST}
    adminUrl: ${HTTP_SCHEME}://registration-api.${INGRESS_HOST}
    serviceAccountsEnabled: true
    directAccessGrantsEnabled: true
    standardFlowEnabled: true
    oauth2DeviceAuthorizationGrantEnabled: true
    useRefreshTokens: true
    authorization:
      - allowRemoteResourceManagement: false
        decisionStrategy: UNANIMOUS
        keepDefaults: true
        policyEnforcementMode: ENFORCING
    validRedirectUris:
      - "/*"
    webOrigins:
      - "/*"
    clientSecretSecretRef:
      name: ${RESOURCE_REGISTRATION_IAM_CLIENT_ID}-keycloak-client
      key: client_secret
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

---

## Validation and Usage

### Automated Validation

Run the validation script to verify the deployment:
```bash
bash validation.sh
```

### Access Points

**Registration API:**

> Authenticate as the configured _Test User_:
> 
> * Username: `eoepcauser` (ref. `KEYCLOAK_TEST_USER`)
> * Password: `eoepcapassword` (ref. `KEYCLOAK_TEST_PASSWORD`)

Service root:

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://registration-api.${INGRESS_HOST}/"
```

Swagger / OpenAPI documentation:

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://registration-api.${INGRESS_HOST}/openapi?f=html"
```

**Flowable REST API:**
```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://registration-harvester-api.${INGRESS_HOST}/flowable-rest/docs/"
```

---

### Registering Resources

The Registration API provides an OGC API Processes service, through which it exposes the _Registration API_ interfaces:

* Registration: `POST /processes/register/execution`
* De-registration: `POST /processes/deregister/execution`

#### (if needed) Obtain an Access Token as `eoepcauser`

If the Resource Registration endpoints are protected via OIDC, obtain an access token for the `eoepcauser`:

```bash
source ~/.eoepca/state
# Authenticate as test user `eoepcauser`
ACCESS_TOKEN=$( \
  curl --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_TEST_USER}" \
    --data-urlencode "password=${KEYCLOAK_TEST_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=${RESOURCE_REGISTRATION_IAM_CLIENT_ID}" \
    -d "client_secret=${RESOURCE_REGISTRATION_IAM_CLIENT_SECRET}" \
    "${HTTP_SCHEME}://auth.${INGRESS_HOST}/realms/${REALM}/protocol/openid-connect/token" | jq -r '.access_token' \
)
echo "Access Token: ${ACCESS_TOKEN:0:20}..."
```

#### Example - Registering a Landsat Collection

This example registers the STAC Collection `landsat-ot-c2-l2` resource into the EOEPCA Resource Catalogue instance - representing the `Landsat 8-9 OLI/TIRS Collection 2 Level-2`. This collection is used in later steps as a target for harvesting of some example Landsat data.

The `target` of this registration request is the STAC endpoint of the Resource Catalogue service deployed as part of the [Resource Discovery](resource-discovery.md) Building Block.

```bash
source ~/.eoepca/state
curl -X POST "https://registration-api.${INGRESS_HOST}/processes/register/execution" \
  ${ACCESS_TOKEN:+-H} ${ACCESS_TOKEN:+Authorization: Bearer ${ACCESS_TOKEN}} \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
    "inputs": {
        "source": {"rel": "collection", "href": "https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/etc/collections/landsat/landsat-ot-c2-l2.json"},
        "target": {"rel": "https://api.stacspec.org/v1.0.0/core", "href": "https://resource-catalogue.${INGRESS_HOST}/stac"}
    }
}
EOF
```

#### Example - Registering a Sentinel 2 Collection

This registers a STAC Collection for Sentinel 2 L2a Collection 1, which is also used later to demonstrate Sentinel harvesting.

```bash
source ~/.eoepca/state
curl -X POST "https://registration-api.${INGRESS_HOST}/processes/register/execution" \
  ${ACCESS_TOKEN:+-H} ${ACCESS_TOKEN:+Authorization: Bearer ${ACCESS_TOKEN}} \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
    "inputs": {
        "source": {"rel": "collection", "href": "https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/etc/collections/sentinel/sentinel-2-c1-l2a.json"},
        "target": {"rel": "https://api.stacspec.org/v1.0.0/core", "href": "https://resource-catalogue.${INGRESS_HOST}/stac"}
    }
}
EOF
```


#### Validate Registration

Check job status:

> If required, authenticate to the Registration API - e.g. as user `eoepcauser`.<br>
> You should see a new job with the status `COMPLETED`. 

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://registration-api.${INGRESS_HOST}/jobs"
```

If you have deployed the [Resource Discovery](./resource-discovery.md) Building Block, verify the Landsat collection:
```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/collections/landsat-ot-c2-l2"
```

and the Sentinel collection:

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/collections/sentinel-2-c1-l2a"
```

---

### Using the Registration Harvester

#### Deploy Workflow for Landsat harvesting

Earlier in this page we deployed the Landsat harvester worker, which is implemented to respond to a specific set of workflow topics - as described by the values deployed with the helm chart:

* `landsat_discover_data` (LandsatDiscoverHandler)
* `landsat_continuous_data_discovery` (LandsatContinuousDiscoveryHandler)
* `landsat_get_download_urls` (LandsatGetDownloadUrlHandler)
* `landsat_download_data` (LandsatDownloadHandler)
* `landsat_untar` (LandsatUntarHandler)
* `landsat_extract_metadata` (LandsatExtractMetadataHandler)
* `landsat_register_metadata` (LandsatRegisterMetadataHandler)

To exploit this we deploy the Landsat workflow, comprising two BPMN processes. The main process (Landsat Registration) searches for new data at USGS. For each new scene found, the workflow executes another process (Landsat Scene Ingestion) which performs the individual steps for harvesting and registering the data.

**Main workflow `landsat.bpmn`**

```bash
source ~/.eoepca/state
curl -s https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/workflows/landsat.bpmn | \
curl -s -X POST "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/repository/deployments" \
  -u ${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD} \
  -F "landsat.bpmn=@-;filename=landsat.bpmn;type=text/xml" | jq
```

**Sub-workflow `landsat-scene-ingestion.bpmn` for individual scene ingestion**

```bash
source ~/.eoepca/state
curl -s https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/workflows/landsat-scene-ingestion.bpmn | \
curl -s -X POST "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/repository/deployments" \
  -u ${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD} \
  -F "landsat-scene-ingestion.bpmn=@-;filename=landsat-scene-ingestion.bpmn;type=text/xml" | jq
```

#### Execute Landsat Harvesting

Start a Landsat harvesting job:

```bash
source ~/.eoepca/state
# Get process ID
processes="$( \
  curl -s "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/repository/process-definitions" \
    -u "${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD}" \
  )"
landsat_process_id="$(echo "$processes" | jq -r '[.data[] | select(.name == "Landsat Workflow")][0].id')"

# Start harvesting
curl -s -X POST "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/runtime/process-instances" \
  -u "${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d @- <<EOF | jq
{
  "processDefinitionId": "$landsat_process_id",
  "variables": [
    {
      "name": "datetime_interval",
      "type": "string",
      "value": "2024-11-13T10:00:00Z/2024-11-13T11:00:00Z"
    },
    {
      "name": "collections",
      "type": "string",
      "value": "landsat-c2l2-sr"
    },
    {
      "name": "bbox",
      "type": "string",
      "value": "-7,46,3,52"
    }
  ]
}
EOF
```

#### Monitor Landsat Harvesting Progress

**Check worker logs:**

```bash
kubectl -n resource-registration logs -f deploy/registration-harvester-worker-landsat
```

Use `Ctrl-C` to exit the log stream.

> Note that the harvesting may take some time, depending on download speeds and the number of scenes to be harvested. Therefore the following monitoring steps may be subject to delay.

**Monitor process instances:**
```bash
source ~/.eoepca/state
curl -s "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/runtime/process-instances" \
  -u ${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD} \
  | jq -r '.data[] | "\(.startTime) | \(.id) | \(.processDefinitionName)"'
```

**Check registered items:**

Once harvesting completes (this may take time depending on download speeds), check the catalogue:
```bash
source ~/.eoepca/state
xdg-open "https://resource-catalogue.${INGRESS_HOST}/collections/landsat-ot-c2-l2/items"
```

#### Deploy Workflow for Sentinel harvesting

As above for the Landsat harvester, for Sentinel harvesting two workflows must be deployed to Flowable using

```bash
source ~/.eoepca/state
curl -s https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/workflows/sentinel.bpmn | \
curl -s -X POST "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/repository/deployments" \
  -u ${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD} \
  -F "sentinel.bpmn=@-;filename=sentinel.bpmn;type=text/xml" | jq
```

and

```bash
curl -s https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/workflows/sentinel-scene-ingestion.bpmn | \
curl -s -X POST "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/repository/deployments" \
  -u ${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD} \
  -F "sentinel-scene-ingestion.bpmn=@-;filename=sentinel-scene-ingestion.bpmn;type=text/xml" | jq
```


#### Execute Sentinel Harvesting

Start a Sentinel harvesting job (for a small time period - this should match three records):

```bash
source ~/.eoepca/state
# Get process ID
processes="$( \
  curl -s "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/repository/process-definitions" \
    -u "${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD}" \
  )"
sentinel_process_id="$(echo "$processes" | jq -r '[.data[] | select(.name == "Sentinel Registration")][0].id')"

# Start harvesting
curl -s -X POST "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/runtime/process-instances" \
  -u "${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d @- <<EOF | jq
{
  "processDefinitionId": "$sentinel_process_id",
  "variables": [
    {
      "name": "filter",
      "type": "string",
      "value": "startswith(Name,'S2') and contains(Name,'L2A') and contains(Name,'_N05') and PublicationDate ge 2025-11-13T10:00:00Z and PublicationDate lt 2025-11-13T10:00:30Z and Online eq true"
    }
  ]
}
EOF
```

#### Monitor Sentinel Harvesting Progress

**Check worker logs:**

```bash
kubectl -n resource-registration logs -f deploy/registration-harvester-worker-sentinel
```

Use `Ctrl-C` to exit the log stream.

> Note that the harvesting may take some time, depending on download speeds and the number of scenes to be harvested. Therefore the following monitoring steps may be subject to delay.

**Monitor process instances:**
```bash
source ~/.eoepca/state
curl -s "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/runtime/process-instances" \
  -u ${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD} \
  | jq -r '.data[] | "\(.startTime) | \(.id) | \(.processDefinitionName)"'
```

**Check registered items:**

Once harvesting completes (this may take time depending on download speeds), check the catalogue:
```bash
source ~/.eoepca/state
xdg-open "https://resource-catalogue.${INGRESS_HOST}/collections/sentinel-2-c1-l2a/items"
```

---

### Delivery of data `assets`

The default harvesting approach illustrated above maintains the harvested assets into a persistent `eodata` volume. The metadata records registered with the catalogue assume delivery of these assets via the base URL `https://eodata.${INGRESS_HOST}/` - such that the registered _STAC Items_ include asset hrefs that are rooted under this base URL.

#### Example - Service for asset access

By way of an example, a simple NGINX service can be deployed to provide access to these assets - under the service URL `https://eodata.${INGRESS_HOST}/` - to correctly resolve the asset hrefs as registered in the STAC Items.

```bash
kubectl apply -f registration-harvester/generated-eodata-server.yaml
```

Once started, the asset links in the STAC Items viewed earlier should work.

#### Visualise with STAC Browser

STAC Browser can be used to visualise the harvested STAC Collection and the referenced assets.

Use either the [On-line Radiant Earth instance](#using-on-line-radiant-earth-service), or a [dedicated local instance](#using-local-stac-browser).

##### Using On-line Radiant Earth service

[Radiant Earth](https://radiant.earth/) provide a [public STAC Browser client](https://radiantearth.github.io/stac-browser).

> If your Resource Catalogue deployment uses `http` (rather than `https`) then this will not work. Instead use the [local STAC Browser deployment](#using-local-stac-browser)

```bash
source ~/.eoepca/state
xdg-open "https://radiantearth.github.io/stac-browser/#/external/resource-catalogue.${INGRESS_HOST}/stac/"
```

##### Using Local STAC Browser

**Deploy STAC Browser**

Deploy...

```bash
kubectl apply -f registration-harvester/generated-stac-browser.yaml
```

Open...

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://stac-browser.${INGRESS_HOST}"
```

---

## Additional Harvester Types

The Registration Harvester supports additional data sources beyond Landsat:

- **Sentinel data** from Copernicus Data Space Ecosystem (CDSE)
- **Generic STAC catalogues**

Deployment of these additional harvesters follows a similar pattern but requires specific configuration and credentials. Refer to the [Registration Harvester Documentation](https://github.com/EOEPCA/registration-harvester) for details.

---

## Uninstallation

Remove all Resource Registration components:

```bash
source ~/.eoepca/state

# Remove workers
helm uninstall registration-harvester-worker-landsat -n resource-registration

# Remove ingresses
kubectl delete -f registration-harvester/generated-ingress.yaml
kubectl delete -f registration-api/generated-ingress.yaml
kubectl delete -f registration-harvester/generated-eodata-server.yaml 2>/dev/null

# Remove core components
helm uninstall registration-harvester-api-engine -n resource-registration
helm uninstall registration-api -n resource-registration

# Remove IAM resources
kubectl delete client.openidclient.keycloak.m.crossplane.io/${RESOURCE_REGISTRATION_IAM_CLIENT_ID} -n iam-management
kubectl delete secret/${RESOURCE_REGISTRATION_IAM_CLIENT_ID}-keycloak-client -n iam-management

# Remove namespace (optional - will delete all data)
kubectl delete namespace resource-registration
```

---

## Further Reading

- [EOEPCA+ Resource Registration GitHub Repository](https://github.com/EOEPCA/resource-registration)
- [Registration Harvester Documentation](https://github.com/EOEPCA/registration-harvester)
- [Flowable BPMN Platform](https://flowable.com/open-source/)
- [pygeoapi Documentation](https://pygeoapi.io/)
- [EOEPCA+ Helm Charts](https://eoepca.github.io/helm-charts-dev)
