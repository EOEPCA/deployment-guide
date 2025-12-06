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

| Component          | Requirement                            | Documentation Link                                                |
| ------------------ | -------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.32)              | [Installation Guide](../prerequisites/kubernetes.md)             |
| Helm               | Version 3.7 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| TLS Certificates   | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md) |
| Ingress Controller | Properly installed (e.g., NGINX, APISIX) | [Installation Guide](../prerequisites/ingress/overview.md)      |


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

### 3. Deploy the Registration API Using Helm

The Registration API provides a RESTful interface through which resources can be directly registered, updated, or deleted.

Deploy the Registration API using the generated values file:
```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev
helm repo update eoepca-dev
helm upgrade -i registration-api eoepca-dev/registration-api \
  --version 2.0.0-dev11 \
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

#### Deploy Landsat Harvester Worker

Deploy the worker that executes Landsat harvesting tasks:

```bash
helm upgrade -i registration-harvester-worker-landsat eoepca-dev/registration-harvester \
  --version 2.0.0-rc2 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-harvester/harvester-values/values-landsat.yaml
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

---

## Validation and Usage

### Automated Validation

Run the validation script to verify the deployment:
```bash
bash validation.sh
```

### Access Points

**Registration API:**
```bash
source ~/.eoepca/state
# Open API endpoint
xdg-open "${HTTP_SCHEME}://registration-api.${INGRESS_HOST}/"

# API documentation
xdg-open "${HTTP_SCHEME}://registration-api.${INGRESS_HOST}/openapi?f=html"
```

**Flowable REST API:**
```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://registration-harvester-api.${INGRESS_HOST}/flowable-rest/docs/"
```

---

### Registering Resources

The Registration API provides OGC API Processes interfaces:

* Registration: `POST /processes/register/execution`
* De-registration: `POST /processes/deregister/execution`

#### Example - Registering a Collection

Register a STAC Collection for Landsat data:
```bash
source ~/.eoepca/state
curl -X POST "https://registration-api.${INGRESS_HOST}/processes/register/execution" \
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

#### Validate Registration

Check job status:
```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://registration-api.${INGRESS_HOST}/jobs"
```

If you have deployed the [Resource Discovery](./resource-discovery.md) Building Block, verify the collection:
```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/collections/landsat-ot-c2-l2"
```

---

### Using the Registration Harvester

#### Deploy Harvesting Workflows

Deploy the Landsat harvesting workflows to Flowable:

```bash
source ~/.eoepca/state
# Main workflow
curl -s https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/workflows/landsat.bpmn | \
curl -s -X POST "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/repository/deployments" \
  -u ${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD} \
  -F "landsat.bpmn=@-;filename=landsat.bpmn;type=text/xml" | jq

# Sub-workflow for scene ingestion
curl -s https://raw.githubusercontent.com/EOEPCA/registration-harvester/refs/heads/main/workflows/landsat-scene-ingestion.bpmn | \
curl -s -X POST "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/repository/deployments" \
  -u ${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD} \
  -F "landsat-scene-ingestion.bpmn=@-;filename=landsat-scene-ingestion.bpmn;type=text/xml" | jq
```

#### Example - Deploy Workflow for Landsat harvesting

Earlier in this page we deployed the Landsat harvester worker, which is implemented to respond to a specific set of workflow topics - as described by the values deployed with the helm chart:

* `landsat_discover_data` (LandsatDiscoverHandler)
* `landsat_continuous_data_discovery` (LandsatContinuousDiscoveryHandler)
* `landsat_get_download_urls` (LandsatGetDownloadUrlHandler)
* `landsat_download_data` (LandsatDownloadHandler)
* `landsat_untar` (LandsatUntarHandler)
* `landsat_extract_metadata` (LandsatExtractMetadataHandler)
* `landsat_register_metadata` (LandsatRegisterMetadataHandler)

To exploit this we deploy the Landsat workflow, comprising two BPMN processes. The main process (Landsat Registration) searches for new data at USGS. For each new scene found, the workflow executes another process (Landsat Scene Ingestion) which performs the individual steps for harvesting and registering the data.


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

#### Monitor Harvesting Progress

**Check worker logs:**
```bash
kubectl -n resource-registration logs -f deploy/registration-harvester-worker-landsat
```

Use `Ctrl-C` to exit the log stream.

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

---

#### Retain the `eodata` volume

Given the time/bandwidth required to retrieve the harvested data - you may want to ensure that the Persistent Volume is retained for future reuse. For example, to reconnect with the downloaded data in the case that the Resource Registration BB is re-deployed.

Depending on your `RWX` storage class, the `Retain` reclaim policy may already be set.

Check reclaim policy of the `eodata` persistent volume...

```bash
 EODATA_PV=$(kubectl get pvc "eodata" -n "resource-registration" -o jsonpath='{.spec.volumeName}')
 POLICY=$(kubectl get pv "$EODATA_PV" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')
 echo -e "\nVolume Reclaim Policy is: $POLICY\n"
```

Otherwise, you can patch the persistent volume as follows...

```bash
 EODATA_PV=$(kubectl get pvc "eodata" -n "resource-registration" -o jsonpath='{.spec.volumeName}')
 kubectl patch pv "$EODATA_PV" -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

---

### Delivery of data `assets`

The default harvesting approach illustrated above maintains the harvested assets into an `eodata` persistent volume. The metadata records registered with the catalogue assume delivery of these assets via the base URL `https://eodata.${INGRESS_HOST}/` - such that the registered _STAC Items_ include asset hrefs that are rooted under this base URL.

#### Example - Service for asset access

By way of an example, a simple NGINX service can be deployed to provide access to these assets - under the service URL `https://eodata.${INGRESS_HOST}/` - to correctly resolve the asset hrefs as registered in the STAC Items.

```bash
kubectl apply -f registration-harvester/generated-eodata-server.yaml
```

#### Visualise with STAC Browser

Use STAC Browser to navigate the harvested STAC Collection and the referenced assets.

```bash
source ~/.eoepca/state
xdg-open "https://radiantearth.github.io/stac-browser/#/external/resource-catalogue.${INGRESS_HOST}/stac/"
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
# Remove workers
helm uninstall registration-harvester-worker-landsat -n resource-registration

# Remove ingresses
kubectl delete -f registration-harvester/generated-ingress.yaml
kubectl delete -f registration-api/generated-ingress.yaml
kubectl delete -f registration-harvester/generated-eodata-server.yaml 2>/dev/null

# Remove core components
helm uninstall registration-harvester-api-engine -n resource-registration
helm uninstall registration-api -n resource-registration

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