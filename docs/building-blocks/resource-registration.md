# Resource Registration Deployment Guide

The **Resource Registration** Building Block enables data and metadata ingestion into platform services. It handles:

- Metadata registration into Resource Discovery
- Data registration into Data Access services
- Resource visualisation configuration



The BB integrates with other platform services to enable:

- Automated metadata extraction
- Resource discovery indexing
- Access control configuration

---

## Components Overview

The Resource Registration BB comprises two main components:

1. **Registration API**  
An OGC API Processes interface for registering, updating, or deleting resources on the local platform.
    
2. **Harvester**  
Automates workflows (via the Operaton BPM engine) to harvest data from external sources. This guide covers three harvester workers: Landsat (USGS), Sentinel (CDSE) and a generic STAC catalogue harvester.

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

First time running a script? [EOEPCA+ State](../prerequisites/state.md) covers the shared setup questions asked before this one.

**Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`SHARED_STORAGECLASS`**: Storage Class for shared volumes (ReadWriteMany) - e.g. harvested `eodata`.
    - *Default*: `standard`
    !!! note
        `eodata` must be `RWX` - multiple harvester workers share it, and other BBs may also read from it.
- **`OPERATON_ADMIN_USER`**: Admin username for the Operaton BPM engine.
    - *Default*: `eoepca`
- **`OPERATON_ADMIN_PASSWORD`**: Admin password for the Operaton BPM engine.
    - *Default*: `eoepca`
- **`EODATA_ASSET_BASE_URL`**: The base URL through which harvested 'eodata' assets will be accessed
    - *Default*: `"${HTTP_SCHEME}://eodata.${INGRESS_HOST}/"`

=== "With IAM (default)"

    - **`RESOURCE_REGISTRATION_ENABLE_OIDC`**: Whether the Resource Registration endpoints should be protected via OIDC authentication.
        - *Default*: `yes`
        - Uses the APISIX `openid-connect` and `authz-keycloak` plugins, so this is only supported when `INGRESS_CLASS=apisix` - for nginx deployments, set this `no`.
    - **`RESOURCE_REGISTRATION_PROTECTED_TARGETS`**: Whether the Resource Registration target services for resource registration (e.g. Resource Discovery, eoAPI) are themselves protected via OIDC authentication. In this case the Resource Registration (API and harvester) must act as OIDC clients to authenticate against these services.
        - *Default*: `yes`
        - Independent of `RESOURCE_REGISTRATION_ENABLE_OIDC` and works with `nginx` too - it only controls outbound authentication to target services, not the Resource Registration ingress itself.
    - **`RESOURCE_REGISTRATION_IAM_CLIENT_ID`**: The Client ID used both for ingress protection of Resource Registration services, and for Resource Registration to authenticate against protected target services. The associated `CLIENT_SECRET` will be generated.
        - *Default*: `resource-registration`

=== "Without IAM"

    Set both **`RESOURCE_REGISTRATION_ENABLE_OIDC`** and **`RESOURCE_REGISTRATION_PROTECTED_TARGETS`** to `no`. Resource Registration deploys with public, unauthenticated endpoints and calls target services (e.g. Resource Discovery) without a client credential. Works with both `apisix` and `nginx`.

### 2. Apply Kubernetes Secrets

Create required secrets for the Registration API and Harvester components:

```bash
bash apply-secrets.sh
```

During the script execution, you'll be prompted for optional external service credentials:

#### USGS M2M Credentials (for Landsat harvesting)

!!! warning
    These credentials are required when following below usage instructions for Landsat harvesting.

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
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev/
helm repo update eoepca-dev
helm upgrade -i registration-api eoepca-dev/registration-api \
  --version 2.1.0-dev2 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-api/generated-values.yaml
```

Deploy the ingress routes:
```bash
kubectl apply -f registration-api/generated-ingress.yaml
```

### 4. Deploy the Registration Harvester Components

The Registration Harvester consists of the Operaton BPM engine and worker deployments.

#### Deploy the Operaton BPM Engine
```bash
helm repo add operaton https://dlr-terrabyte.github.io/operaton-helm/
helm repo update operaton
helm upgrade -i registration-harvester-bpm-engine operaton/operaton \
  --version 1.0.6 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-harvester/generated-values.yaml
```

Deploy the ingress for the Operaton BPM engine:
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

!!! tip "Alternative: let the worker chart create the volume"
    Rather than directly creating the volume as above, the worker helm chart can be configured to create the volume itself...

    ```
    harvester:
      eodata:
        enabled: true
        createPVC: true
        claimName: eodata
        storageClass: ${SHARED_STORAGECLASS}
    ```

    Subsequent worker instances should then be configured to use (rather than create) this existing volume...

    ```
    harvester:
      eodata:
        enabled: true
        createPVC: false
        claimName: eodata
    ```

#### Deploy Landsat Harvester Worker

Deploy the worker that executes Landsat harvesting tasks:

```bash
helm upgrade -i registration-harvester-worker-landsat eoepca-dev/registration-harvester \
  --version 2.0.0 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-harvester/harvester-values/values-landsat.yaml
```

#### Deploy the Sentinel Harvester Worker

Deploy the worker that harvests Sentinel data from CDSE:

```bash
helm upgrade -i registration-harvester-worker-sentinel eoepca-dev/registration-harvester \
  --version 2.0.0 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-harvester/harvester-values/values-sentinel.yaml
```

#### Deploy the STAC Harvester Worker

Deploy the worker that harvests generic STAC catalogues, registering into the [Data Access](./data-access.md) eoAPI STAC endpoint (rather than Resource Discovery):

```bash
helm upgrade -i registration-harvester-worker-stac eoepca-dev/registration-harvester \
  --version 2.0.0 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-harvester/harvester-values/values-stac.yaml
```

### 5. Monitor the Deployment

Check the status of all deployments:
```bash
kubectl get all -n resource-registration
```

### 6. Create the Keycloak Client for Resource Registration

A Keycloak client is required for Resource Registration for two purposes:

1. We want to protect the Resource Registration endpoints via OIDC<br>
   _Ref. `RESOURCE_REGISTRATION_ENABLE_OIDC`_
2. The Resource Registration needs to connect with other services that are protected via OIDC (e.g., resource-catalogue, eoapi)<br>
   _Ref. `RESOURCE_REGISTRATION_PROTECTED_TARGETS`_

!!! note
    If neither of these apply, you can skip this step.

The client can be created using the Crossplane Keycloak provider via the `Client` CRD. `configure-resource-registration.sh` already rendered `generated-iam.yaml` (the `Client` CRD plus its client-secret `Secret`) when either of the two cases above applied - this requires [Crossplane](../prerequisites/crossplane.md) with its Keycloak provider installed and configured.

```bash
kubectl apply -f generated-iam.yaml
kubectl wait --for=condition=Ready client.openidclient.keycloak.m.crossplane.io/${RESOURCE_REGISTRATION_IAM_CLIENT_ID} -n iam-management --timeout=60s
```

The `Client` CRD enables Authorization Services in `ENFORCING` mode (`spec.forProvider.authorization`) - thus we need to apply an Authorization Policy to protect the Resource Registration service.

As an example, the following applies protection that allows access for the configured _Test User_.

```bash
source ~/.eoepca/state
envsubst < protect-test-user.yaml | kubectl apply -f -
```

---

## Validation and Usage

> **Prefer a notebook?** Run `../../notebooks/run.sh` and open the <a href="http://localhost:8888/lab/tree/resource-registration/resource-registration.ipynb" target="_blank">Resource Registration notebook</a> at `http://localhost:8888`.

### Automated Validation

Run the validation script to verify the deployment:
```bash
bash validation.sh
```

### Access Points

**Registration API:**

!!! note
    If `RESOURCE_REGISTRATION_ENABLE_OIDC=yes`, authenticate as the configured _Test User_ when prompted:

    * Username: `eoepcauser` (ref. `KEYCLOAK_TEST_USER`)
    * Password: `eoepcapassword` (ref. `KEYCLOAK_TEST_PASSWORD`)

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

**Operaton BPM Engine (webapp):**
```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/operaton/"
```

!!! note
    Authenticate as the configured Operaton admin user - ref. `OPERATON_ADMIN_USER` / `OPERATON_ADMIN_PASSWORD`.

**Operaton REST API:**
```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/engine"
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

The `target` of this registration request is the STAC endpoint of the Resource Catalogue service deployed as part of the [Resource Discovery](resource-discovery.md) Building Block - specifically its protected, transactional endpoint (`resource-catalogue-protected`), since the public endpoint has transactions disabled by chart default. This requires Resource Discovery to have been deployed with `RESOURCE_DISCOVERY_ENABLE_IAM=yes`; without it, there is no HTTP write path into the catalogue at all (see Resource Discovery's [Ingesting Records](resource-discovery.md#4-ingesting-records) instructions instead, "Without IAM" tab).

```bash
source ~/.eoepca/state
curl -X POST "https://registration-api.${INGRESS_HOST}/processes/register/execution" \
  ${ACCESS_TOKEN:+-H} ${ACCESS_TOKEN:+Authorization: Bearer ${ACCESS_TOKEN}} \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
    "inputs": {
        "source": {"rel": "collection", "href": "https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/etc/collections/landsat/landsat-ot-c2-l2.json"},
        "target": {"rel": "https://api.stacspec.org/v1.0.0/core", "href": "https://resource-catalogue-protected.${INGRESS_HOST}/stac"}
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
        "target": {"rel": "https://api.stacspec.org/v1.0.0/core", "href": "https://resource-catalogue-protected.${INGRESS_HOST}/stac"}
    }
}
EOF
```


#### Checking EOMP Conformance

The Registration API's `register`/`deregister` processes only validate the request envelope and any `stac_extensions` declared on the record - they do **not** check conformance against the [EOEPCA Metadata Profile (EOMP)](https://github.com/EOEPCA/eomp), so registration can succeed for a record that isn't a conformant EOMP record.

A separate `pyeomp-record-validate` process (from [pyeomp](https://github.com/EOEPCA/pyeomp), the EOMP reference implementation) is deployed alongside `register`/`deregister` for this purpose. It takes a `record` input - either an inline JSON object or a URL string - and returns an ETS (Executable Test Suite) report checking the record against the EOMP core schema:

```bash
source ~/.eoepca/state
curl -X POST "https://registration-api.${INGRESS_HOST}/processes/pyeomp-record-validate/execution" \
  ${ACCESS_TOKEN:+-H} ${ACCESS_TOKEN:+Authorization: Bearer ${ACCESS_TOKEN}} \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
    "inputs": {
        "record": "https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/etc/collections/landsat/landsat-ot-c2-l2.json"
    }
}
EOF
```

The Landsat collection record used above is a plain STAC Collection, not an EOMP record, so this reports a `FAILED` result - EOMP's core requirement class expects a GeoJSON `Feature` with top-level `geometry` and `properties`, which a STAC Collection doesn't have:

```json
{
    "summary": {"PASSED": 0, "FAILED": 1, "SKIPPED": 0, "WARNINGS": 0},
    "tests": [
        {
            "id": "http://eoepca.org/spec/eomp/1/conf/core/validation",
            "code": "FAILED",
            "message": "3 error(s)",
            "errors": [
                "$: 'geometry' is a required property",
                "$: 'properties' is a required property",
                "$.type: 'Collection' is not one of ['Feature']"
            ]
        }
    ]
}
```

#### Validate Registration

Check job status:

!!! note
    If required, authenticate to the Registration API - e.g. as user `eoepcauser`. You should see a new job with the status `COMPLETED`.

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

=== "Landsat"

    !!! warning
        Requires real [USGS M2M credentials](#usgs-m2m-credentials-for-landsat-harvesting)

    #### Deploy Workflow

    Earlier in this page we deployed the Landsat harvester worker, which is implemented to respond to a specific set of workflow topics - as described by the values deployed with the helm chart:

    * `landsat_ondemand_discovery` (LandsatDiscoverHandler)
    * `landsat_continuous_discovery` (LandsatContinuousDiscoveryHandler)
    * `landsat_download_scene` (LandsatDownloadHandler)
    * `landsat_unpack` (LandsatUntarHandler)
    * `landsat_extract_metadata` (LandsatExtractMetadataHandler)
    * `landsat_register_metadata` (LandsatRegisterMetadataHandler)

    To exploit this we deploy the Landsat workflow, comprising two BPMN processes. The main process (Landsat Registration) searches for new data at USGS. For each new scene found, the workflow executes another process (Landsat Scene Ingestion) which performs the individual steps for harvesting and registering the data.

    **Main workflow `landsat.bpmn`**

    ```bash
    source ~/.eoepca/state
    curl -s https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/workflows/landsat.bpmn | \
    curl -s -X POST "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/deployment/create" \
      -u "${OPERATON_ADMIN_USER}:${OPERATON_ADMIN_PASSWORD}" \
      -F "deployment-name=landsat" \
      -F "landsat.bpmn=@-;filename=landsat.bpmn;type=text/xml" | jq
    ```

    **Sub-workflow `landsat-scene-ingestion.bpmn` for individual scene ingestion**

    ```bash
    source ~/.eoepca/state
    curl -s https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/workflows/landsat-scene-ingestion.bpmn | \
    curl -s -X POST "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/deployment/create" \
      -u "${OPERATON_ADMIN_USER}:${OPERATON_ADMIN_PASSWORD}" \
      -F "deployment-name=landsat-scene-ingestion" \
      -F "landsat-scene-ingestion.bpmn=@-;filename=landsat-scene-ingestion.bpmn;type=text/xml" | jq
    ```

    !!! note
        The Operaton REST API deployment/process endpoints are not protected by HTTP basic auth by default - the `-u` flag above is only needed if you've explicitly enabled REST API authentication. Confirm against your deployment; drop `-u` if you get a 401 with credentials supplied.

    #### Execute Harvesting

    The main `landsat-data-ingestion` process (id `landsat-data-ingestion`) is triggered via its message start event (message name `landsat-start-order`), rather than started directly by process definition - use the `/message` endpoint to correlate it:

    ```bash
    source ~/.eoepca/state
    curl -s -X POST "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/message" \
      -H "Content-Type: application/json" \
      -d @- <<EOF | jq
    {
      "messageName": "landsat-start-order",
      "processVariables": {
        "datetime_interval": {"value": "2024-11-13T10:00:00Z/2024-11-13T11:00:00Z", "type": "String"},
        "collections": {"value": "landsat_ot_c2_l2", "type": "String"},
        "bbox": {"value": "-7,46,3,52", "type": "String"}
      }
    }
    EOF
    ```

    #### Monitor Harvesting Progress

    **Check worker logs:**

    ```bash
    kubectl -n resource-registration logs -f deploy/registration-harvester-worker-landsat
    ```

    Use `Ctrl-C` to exit the log stream.

    !!! note
        The harvesting may take some time, depending on download speeds and the number of scenes to be harvested. Therefore the following monitoring steps may be subject to delay.

    **Monitor process instances:**
    ```bash
    source ~/.eoepca/state
    curl -s "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/process-instance" \
      | jq -r '.[] | "\(.id) | \(.definitionId)"'
    ```

    **Check registered items:**

    Once harvesting completes (this may take time depending on download speeds), check the catalogue:
    ```bash
    source ~/.eoepca/state
    xdg-open "https://resource-catalogue.${INGRESS_HOST}/collections/landsat-ot-c2-l2/items"
    ```

=== "Sentinel"

    #### Deploy Workflow

    As for the Landsat harvester, two workflows must be deployed to Operaton for Sentinel harvesting:

    ```bash
    source ~/.eoepca/state
    curl -s https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/workflows/sentinel.bpmn | \
    curl -s -X POST "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/deployment/create" \
      -u "${OPERATON_ADMIN_USER}:${OPERATON_ADMIN_PASSWORD}" \
      -F "deployment-name=sentinel" \
      -F "sentinel.bpmn=@-;filename=sentinel.bpmn;type=text/xml" | jq
    ```

    and

    ```bash
    curl -s https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/workflows/sentinel-scene-ingestion.bpmn | \
    curl -s -X POST "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/deployment/create" \
      -u "${OPERATON_ADMIN_USER}:${OPERATON_ADMIN_PASSWORD}" \
      -F "deployment-name=sentinel-scene-ingestion" \
      -F "sentinel-scene-ingestion.bpmn=@-;filename=sentinel-scene-ingestion.bpmn;type=text/xml" | jq
    ```


    #### Execute Harvesting

    Start a Sentinel harvesting job for a small time window (this should match around 20 scenes). Like Landsat, the `sentinel-data-ingestion` process is triggered via its message start event (message name `sentinel-start-order`):

    ```bash
    source ~/.eoepca/state
    curl -s -X POST "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/message" \
      -H "Content-Type: application/json" \
      -d @- <<EOF | jq
    {
      "messageName": "sentinel-start-order",
      "processVariables": {
        "datetime_interval": {"value": "2025-11-13T10:00:00Z/2025-11-13T10:05:00Z", "type": "String"},
        "collections": {"value": "S2_MSI_L2A", "type": "String"}
      }
    }
    EOF
    ```

    #### Monitor Harvesting Progress

    **Check worker logs:**

    ```bash
    kubectl -n resource-registration logs -f deploy/registration-harvester-worker-sentinel
    ```

    Use `Ctrl-C` to exit the log stream.

    !!! note
        The harvesting may take some time, depending on download speeds and the number of scenes to be harvested. Therefore the following monitoring steps may be subject to delay.

    **Monitor process instances:**
    ```bash
    source ~/.eoepca/state
    curl -s "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/process-instance" \
      | jq -r '.[] | "\(.id) | \(.definitionId)"'
    ```

    **Check registered items:**

    Once harvesting completes (this may take time depending on download speeds), check the catalogue:
    ```bash
    source ~/.eoepca/state
    xdg-open "https://resource-catalogue.${INGRESS_HOST}/collections/sentinel-2-c1-l2a/items"
    ```

=== "STAC Catalog"

    Requires [Data Access](./data-access.md) to be deployed first - this harvester publishes into its eoAPI STAC endpoint.

    #### Deploy Workflow

    ```bash
    source ~/.eoepca/state
    curl -s https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/workflows/stac.bpmn | \
    curl -s -X POST "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/deployment/create" \
      -u "${OPERATON_ADMIN_USER}:${OPERATON_ADMIN_PASSWORD}" \
      -F "deployment-name=stac" \
      -F "stac.bpmn=@-;filename=stac.bpmn;type=text/xml" | jq
    ```

    #### Execute Harvesting

    This example harvests directly from a public STAC API ([Planetary Computer](https://planetarycomputer.microsoft.com/)), independent of the Landsat/Sentinel harvesters above:

    ```bash
    source ~/.eoepca/state
    curl -s -X POST "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/process-definition/key/stac-harvest-catalog/start" \
      -H "Content-Type: application/json" \
      -d @- <<EOF | jq
    {
      "variables": {
        "stac_catalog_source": {"value": "https://planetarycomputer.microsoft.com/api/stac/v1", "type": "String"},
        "stac_catalog_collections": {"value": "sentinel-2-l2a", "type": "String"},
        "stac_api_destination_url": {"value": "${HTTP_SCHEME}://eoapi.${INGRESS_HOST}/stac", "type": "String"},
        "datetime": {"value": "2025-11-13T00:00:00Z/2025-11-13T23:59:59Z", "type": "String"},
        "bbox": {"value": "-2,51,0,52.5", "type": "String"}
      }
    }
    EOF
    ```

    #### Monitor Harvesting Progress

    **Check worker logs:**

    ```bash
    kubectl -n resource-registration logs -f deploy/registration-harvester-worker-stac
    ```

    Use `Ctrl-C` to exit the log stream.

    **Monitor process instances:**
    ```bash
    source ~/.eoepca/state
    curl -s "${HTTP_SCHEME}://registration-harvester-bpm-engine.${INGRESS_HOST}/engine-rest/process-instance" \
      | jq -r '.[] | "\(.id) | \(.definitionId)"'
    ```

    **Check registered items:**

    ```bash
    source ~/.eoepca/state
    xdg-open "${HTTP_SCHEME}://eoapi.${INGRESS_HOST}/stac/collections/sentinel-2-l2a/items"
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

!!! note
    If your Resource Catalogue deployment uses `http` (rather than `https`) then this will not work. Instead use the [local STAC Browser deployment](#using-local-stac-browser).

```bash
source ~/.eoepca/state
xdg-open "https://radiantearth.github.io/stac-browser/#/external/resource-catalogue.${INGRESS_HOST}/stac/"
```

##### Using Local STAC Browser

**Deploy STAC Browser**

```bash
kubectl apply -f registration-harvester/generated-stac-browser.yaml
```

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://stac-browser.${INGRESS_HOST}"
```

---

## Uninstallation

Remove all Resource Registration components:

```bash
source ~/.eoepca/state

# Remove workers
helm uninstall registration-harvester-worker-landsat -n resource-registration
helm uninstall registration-harvester-worker-sentinel -n resource-registration
helm uninstall registration-harvester-worker-stac -n resource-registration

# Remove ingresses
kubectl delete -f registration-harvester/generated-ingress.yaml
kubectl delete -f registration-api/generated-ingress.yaml
kubectl delete -f registration-harvester/generated-eodata-server.yaml 2>/dev/null
kubectl delete -f registration-harvester/generated-stac-browser.yaml 2>/dev/null

# Remove core components
helm uninstall registration-harvester-bpm-engine -n resource-registration
helm uninstall registration-api -n resource-registration

# Remove IAM resources
envsubst < protect-test-user.yaml | kubectl delete -f -
kubectl delete -f generated-iam.yaml --ignore-not-found

# Remove namespace (optional - will delete all data)
kubectl delete namespace resource-registration
```

---

## Further Reading

- [EOEPCA+ Resource Registration GitHub Repository](https://github.com/EOEPCA/resource-registration)
- [Registration Harvester Documentation](https://github.com/EOEPCA/registration-harvester)
- [Operaton BPM Platform](https://operaton.org/)
- [pygeoapi Documentation](https://pygeoapi.io/)
- [EOEPCA+ Helm Charts](https://eoepca.github.io/helm-charts)
