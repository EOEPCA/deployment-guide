# Resource Discovery Deployment Guide

The **Resource Discovery** building block provides a catalogue for Earth Observation (EO) metadata using open standards. It supports common standards such as OGC CSW, OGC API Records, STAC, and OpenSearch. Previously known as the "Resource Catalogue", it has now expanded to handle more types of resources and better integrates with tools like **eoAPI**. Internally, it uses **pycsw** to ensure OGC compatibility and can also work with **pgSTAC** via eoAPI to handle large amounts of STAC metadata.  

This guide shows you step-by-step how to set up Resource Discovery in your Kubernetes cluster.

---

## Introduction

Resource Discovery is an important component of the EOEPCA ecosystem. It helps users easily manage and search EO metadata from various sources. By using open standards, it makes data easier to find and integrate with other systems.

### Key Features

- **Easy Metadata Management**: Collect and search EO metadata efficiently.
- **Uses Open Standards**: Supports OGC CSW, OGC API Records, STAC, and OpenSearch.
- **Advanced Search**: Search by area (bounding boxes), time intervals, text, and more.
- **Federated / Distributed Search**: Fans a single search out to external OGC API - Records, STAC API, and CSW catalogues alongside local results.
- **Transactional Updates**: Allows creating, updating, and deleting records when enabled.

### Interfaces

Resource Discovery includes the following APIs:

- **OGC CSW (versions 2.0.2 and 3.0)**
- **OGC API - Records (Core)**
- **STAC API 1.0.0**
- **OpenSearch** (with support for EO, Geo, and Time queries)
- **Optional STAC Dataset Catalogue** via **eoAPI**

---

## Prerequisites

| Component        | Requirement                   | Documentation Link                                                      |
|------------------|-------------------------------|-------------------------------------------------------------------------|
| Kubernetes       | Cluster (tested on v1.32)     | [Installation Guide](../prerequisites/kubernetes.md)     |
| Helm             | Version 3.5 or newer          | [Installation Guide](https://helm.sh/docs/intro/install/)               |
| kubectl          | Configured for cluster access | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)           |
| Ingress          | Properly installed            | [Installation Guide](../prerequisites/ingress/overview.md)                    |
| Cert Manager     | Properly installed            | [Installation Guide](../prerequisites/tls.md)                          |

**Clone the Deployment Guide Repository:**

```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/resource-discovery
```

**Validate your environment:**

```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

1. **Run the Configuration Script**

```bash
bash configure-resource-discovery.sh
```

**Configuration Parameters**  
You'll be asked for, in order:

- **`INGRESS_HOST`**: Base domain for ingress hosts.  
    - Example: `example.com`
- **`PERSISTENT_STORAGECLASS`**: Storage class for the chart-managed PostgreSQL volume.  
    - Example: `local-path`
- **`RESOURCE_DISCOVERY_ENABLE_IAM`**: Whether to deploy the protected transactional catalogue - the EOEPCA IAM building block must already be deployed. Supported values: `yes`, `no`.
- **`CLUSTER_ISSUER`**: Cert-manager ClusterIssuer for TLS certificates. Only asked if cert-manager issuance was enabled during first-time setup.  
    - Example: `letsencrypt-http01-apisix`

!!! warning
    Decide on `RESOURCE_DISCOVERY_ENABLE_IAM` before the first Helm install. The public catalogue's database user/password are only set from `RESOURCE_DISCOVERY_DB_PASSWORD` at first start (Postgres only applies them on an empty data volume). Enabling IAM later, after the public catalogue already exists, leaves the running database on its old credentials while the protected catalogue expects the newly generated ones - the protected catalogue's pod will `CrashLoopBackOff` with a Postgres authentication error until the two are reconciled by hand.

=== "Without IAM (default)"

    Transactional writes stay disabled on the public catalogue - see [Bulk-loading records directly](#41-bulk-loading-records-directly-minimal-non-iam-deployments) for seeding sample data.

=== "With IAM"

    Resource Discovery deploys a second protected catalogue endpoint, `resource-catalogue-protected.${INGRESS_HOST}` - requires APISIX, since it uses the APISIX `openid-connect` and `opa` plugins.

    The configuration script also generates and stores two credentials in `~/.eoepca/state` at this point: `RESOURCE_CATALOGUE_SESSION_SECRET` (APISIX's OIDC session cookie signing key) and `RESOURCE_DISCOVERY_DB_PASSWORD` (the Postgres password the protected catalogue uses to reach the public catalogue's chart-managed database). You don't need to set these yourself.

2. **Deploy Resource Discovery Using Helm**

Add the EOEPCA development Helm chart repository and deploy the public Resource Discovery catalogue:

```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev
helm repo update eoepca-dev

helm upgrade -i resource-catalogue eoepca-dev/rm-resource-catalogue \
  --values generated-values.yaml \
  --version 2.1.0-dev1 \
  --namespace resource-discovery \
  --create-namespace
```

Deploy the public ingress:

```bash
kubectl apply -f generated-ingress.yaml
```

=== "Without IAM (default)"

    Nothing further needed here - only the public catalogue is deployed.

=== "With IAM"

    Deploy the IAM resources and the protected catalogue:

    ```bash
    source ~/.eoepca/state

    kubectl apply -f generated-iam.yaml

    # The protected catalogue reuses the public catalogue's chart-managed
    # database, so it needs the same DB credentials as a Secret.
    kubectl apply -f generated-db-secret.yaml

    helm upgrade -i resource-catalogue-protected eoepca-dev/rm-resource-catalogue \
      --values generated-protected-values.yaml \
      --version 2.1.0-dev1 \
      --namespace resource-discovery \
      --create-namespace

    kubectl apply -f generated-protected-ingress.yaml
    ```

    Note: applying `generated-iam.yaml` before the protected Helm install is fine. The protected route can exist before the Keycloak client is reconciled, but login may fail until IAM reconciliation completes.

Before proceeding, wait for Resource Discovery to be ready:

```bash
while ! kubectl wait --for=condition=Ready --all=true -n resource-discovery pod --timeout=1m &>/dev/null; do
  sleep 10
  echo "Waiting for Resource Discovery readiness"
done

echo -e "\nResource Discovery is READY"
```

### Protected Transactional Catalogue

The default public catalogue is intended for discovery. Transactional writes are disabled on the public endpoint.

When `RESOURCE_DISCOVERY_ENABLE_IAM=yes`, a second catalogue is deployed at:

`https://resource-catalogue-protected.${INGRESS_HOST}`

This protected catalogue enables pycsw transactions and is routed through APISIX using:

- OpenID Connect authentication against the EOEPCA IAM realm
- OPA policy checks using the Resource Registration policy
- a Keycloak client named `resource-catalogue`
- a Keycloak group named `resource-catalogue-admin`
- a client role named `records_editor`

Users who need to perform protected catalogue operations must be assigned to the appropriate IAM group/role.

For minimal non-IAM deployments, use the public catalogue only:

`https://resource-catalogue.${INGRESS_HOST}`

---

## Validation and Operation

### 1. Automated Validation (Optional Script)

```bash
bash validation.sh
```

### 2. Manual Validation via Web Browser

Most Resource Discovery endpoints can be accessed directly in a browser:

- **Landing/Home Page**  

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/"
```
You should see an HTML landing page or a minimal JSON response with links to the various endpoints.

- **Swagger UI (OpenAPI)**

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/openapi?f=html"
```  
Opens a human-friendly UI showing available endpoints and interactive documentation.  

- **OGC API - Records / STAC Collections**

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/collections"
```  

Should return a JSON or HTML response listing available collections.

- **Conformance**

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/conformance"
```  
Confirms which OGC API conformance classes and standards are supported by the server.

If these return meaningful responses (especially HTTP 200 with JSON or HTML data), it indicates that your Resource Discovery instance is operational.

### 3. Manual Validation via cURL / Command Line

Using the command line can be a quick way to check endpoints and see raw responses. Below are some example commands.

We recommend executing `source ~/.eoepca/state` to load the environment variables, or manually set the `INGRESS_HOST` variable.

#### 3.1. Basic Liveness Check

_Returns response headers only..._

```bash
curl -s -D - -o /dev/null "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/"
```

#### 3.2. Testing OGC CSW

```bash
curl "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/csw?service=CSW&version=2.0.2&request=GetCapabilities"
```

- A successful response should be an XML Capabilities document containing service metadata.  

#### 3.3. Testing STAC API

```bash
curl -s "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/stac" | jq
```

- You should see a JSON object containing STAC-related metadata, including a list of links to collections and search endpoints.

#### 3.4. Searching STAC Items

```bash
curl -X POST "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/stac/search" \
   --silent --show-error \
  -H "Content-Type: application/json" \
  -d @- <<EOF | jq
{
  "bbox": [-180, -90, 180, 90],
  "datetime": "2010-01-01T00:00:00Z/2025-12-31T23:59:59Z",
  "limit": 5
}
EOF
```

You should receive a JSON response listing zero or more STAC items that match the query. If you have not yet ingested any items, you may get an empty result array (`"features": []`).  

#### 3.5. Federated / Distributed Search

Resource Discovery can fan a single search out to external catalogues alongside its own records. `values-template.yaml` pre-configures three examples under `pycsw.config.distributedsearch.catalogues`, one per protocol binding it understands:

| id               | type       | fanned out via                                          |
|------------------|------------|----------------------------------------------------------|
| `fedcat01`       | `OARec`    | OGC API - Records (`/collections/.../items`, `distributedSearch=true`) |
| `fedcat02`       | `STAC-API` | STAC API search (Copernicus Data Space Ecosystem)         |
| `arctic-sdi-csw` | `CSW`      | CSW `GetRecords` with `DistributedSearch`                  |

List the configured federated catalogues:

```bash
curl -s "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/collections/metadata:main/federatedCatalogs?f=json" | jq
```

Fan a search out to them:

```bash
curl -s "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/collections/metadata:main/items?distributedSearch=true&limit=1" \
  | jq '.federatedSearchResults'
```

A working response includes a `federatedSearchResults.fedcat01` key containing real features fetched live from the remote WIS2 catalogue. Each catalogue is only ever queried through the protocol binding matching its own `type` - a `STAC-API` entry is never queried via CSW `GetRecords`, for example.


---

### 4. Ingesting Records

How you add records depends on whether transactions are enabled.

#### 4.1. Bulk-loading records directly (minimal / non-IAM deployments)

With `RESOURCE_DISCOVERY_ENABLE_IAM=no`, transactions stay at the chart's secure default (disabled), so there is no HTTP write path on the public catalogue. To seed it with sample data, use pycsw's own admin CLI, `pycsw-admin.py`, which loads records straight into the configured database:

```bash
catalogue_pod="$(kubectl -n resource-discovery get pods --selector=io.kompose.service=pycsw --output=jsonpath='{.items[0].metadata.name}')"

kubectl cp sample_record.xml \
  "resource-discovery/${catalogue_pod}:/tmp/sample_record.xml"

kubectl -n resource-discovery exec -it "${catalogue_pod}" -- \
  /venv/bin/pycsw-admin.py load-records \
    --config /etc/pycsw/pycsw.yml \
    --path /tmp/sample_record.xml
```

!!! note
    A warning about the `geometry` field is expected and can be ignored for this sample.

This is the same tool pycsw's own harvest/bulk-load workflows use to pre-populate a catalogue - it's a legitimate way to seed data, it just always needs cluster access rather than going over the ingress.

Verify:

```bash
source ~/.eoepca/state
curl -s "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/collections/metadata:main/items" | jq '.features[].id'
```

#### 4.2. Creating records over HTTP (`RESOURCE_DISCOVERY_ENABLE_IAM=yes`)

When the protected catalogue is enabled, pycsw exposes the OGC API - Records **Transactions** extension directly: an authenticated `POST`/`PUT`/`DELETE` against `/collections/{collectionId}/items`, no separate ingestion tool or building block required.

The `resource-catalogue` Keycloak client has the OAuth2 **device authorization grant** enabled, which is the simplest way to get a token from a terminal without a client secret:

```bash
source ~/.eoepca/state

DEVICE=$(curl -s -X POST "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/auth/device" \
  -d "client_id=resource-catalogue")

echo "$DEVICE" | jq -r '"Open \(.verification_uri_complete) and log in as a user in the resource-catalogue-admin group"'
```

Open the printed URL, log in as a user assigned to the `resource-catalogue-admin` group (see [Protected Transactional Catalogue](#protected-transactional-catalogue)), then exchange the device code for a token:

```bash
DEVICE_CODE=$(echo "$DEVICE" | jq -r '.device_code')

ACCESS_TOKEN=$(curl -s -X POST "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/token" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
  -d "device_code=${DEVICE_CODE}" \
  -d "client_id=resource-catalogue" | jq -r '.access_token')
```

Create a record:

```bash
curl -s -i -X POST "${HTTP_SCHEME}://resource-catalogue-protected.${INGRESS_HOST}/collections/metadata:main/items" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/geo+json" \
  -d @- <<EOF
{
  "type": "Feature",
  "id": "urn:eoepca:sample:0001",
  "conformsTo": ["http://www.opengis.net/spec/ogcapi-records-1/1.0/req/record-core"],
  "properties": {
    "type": "dataset",
    "title": "EOEPCA Sample Record",
    "description": "Sample record ingested via the OGC API Records transactional endpoint."
  },
  "geometry": {"type": "Point", "coordinates": [23.7, 37.9]}
}
EOF
```

A successful create returns `201 Created`. Update the same record with `PUT` against `/collections/metadata:main/items/urn:eoepca:sample:0001` (same headers/body shape, returns `204`), remove it with `DELETE`.

Verify:

```bash
curl -s "${HTTP_SCHEME}://resource-catalogue-protected.${INGRESS_HOST}/collections/metadata:main/items/urn:eoepca:sample:0001" | jq
```

---

### 5. Validating Kubernetes Resources

Ensure all Kubernetes resources are running correctly:

```bash
kubectl get pods -n resource-discovery
```

- All pods should be in `Running` state.
- No pods should be stuck in `CrashLoopBackOff` or `Error`.

---

### Protected Catalogue Validation

!!! note
    Skip this section if `RESOURCE_DISCOVERY_ENABLE_IAM=no` - there is no protected endpoint to validate.

Verify that the protected public metadata endpoint is reachable:

```bash
source ~/.eoepca/state

curl -s -D - -o /dev/null \
  "${HTTP_SCHEME}://resource-catalogue-protected.${INGRESS_HOST}/conformance"
```

This should return HTTP 200.

The protected catalogue root should redirect unauthenticated users to IAM:

```bash
curl -s -D - -o /dev/null \
  "${HTTP_SCHEME}://resource-catalogue-protected.${INGRESS_HOST}/"
```

This should return a redirect response, usually HTTP 302.

To use protected transactional operations, authenticate through IAM with a user assigned to the resource-catalogue-admin group / records_editor role.

---

## Uninstallation

To uninstall Resource Discovery and clean up associated resources:

```bash
source ~/.eoepca/state

kubectl delete -f generated-ingress.yaml --ignore-not-found

if [ "${RESOURCE_DISCOVERY_ENABLE_IAM:-no}" = "yes" ]; then
  kubectl delete -f generated-protected-ingress.yaml --ignore-not-found
  kubectl delete -f generated-iam.yaml --ignore-not-found
  kubectl delete -f generated-db-secret.yaml --ignore-not-found
  helm uninstall resource-catalogue-protected -n resource-discovery || true
fi

helm uninstall resource-catalogue -n resource-discovery || true

kubectl delete namespace resource-discovery
```

---

## Further Reading & Official Docs

- [EOEPCA Resource Discovery Documentation](https://eoepca.readthedocs.io/projects/resource-discovery)  
- [pycsw Official Documentation](https://docs.pycsw.org/en/latest/)  
- [pycsw GitHub Repository](https://github.com/geopython/pycsw)  
- [eoAPI-k8s Documentation](https://github.com/developmentseed/eoapi-k8s/blob/main/docs) (if using eoAPI for dataset-level STAC ingestion)
- [Resource Registration BB](./resource-registration.md), for automated harvesting pipelines that keep the catalogue in sync with an upstream data source, rather than one-off manual record creation
