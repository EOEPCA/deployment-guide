# Resource Discovery Deployment Guide

The **Resource Discovery** building block provides a catalogue for Earth Observation (EO) metadata using open standards. It supports common standards such as OGC CSW, OGC API Records, STAC, and OpenSearch. Previously known as the "Resource Catalogue", it has now expanded to handle more types of resources and better integrates with tools like **eoAPI**. Internally, it uses **pycsw** to ensure OGC compatibility and can also work with **pgSTAC** via eoAPI to handle large amounts of STAC metadata.  

This guide shows you step-by-step how to set up Resource Discovery in your Kubernetes cluster.

---

## Introduction

### Key Features

- **Advanced Search**: Search by area (bounding boxes), time intervals, and text.
- **Federated / Distributed Search**: Fans a single search out to external OGC API - Records, STAC API, and CSW catalogues alongside local results.
- **Transactional Updates**: Creates, updates, and deletes records when enabled.

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

First time running a script? [EOEPCA+ State](../prerequisites/state.md) covers the shared setup questions asked before this one.

**Configuration Parameters**  
You'll be asked for, in order:

- **`RESOURCE_DISCOVERY_ENABLE_IAM`**: Whether to deploy the protected transactional catalogue - the EOEPCA IAM building block must already be deployed. Supported values: `yes`, `no`.

!!! warning
    Decide on `RESOURCE_DISCOVERY_ENABLE_IAM` before the first Helm install. The public catalogue's database user/password are only set from `RESOURCE_DISCOVERY_DB_PASSWORD` at first start (Postgres only applies them on an empty data volume). Enabling IAM later, after the public catalogue already exists, leaves the running database on its old credentials while the protected catalogue expects the newly generated ones - the protected catalogue's pod will `CrashLoopBackOff` with a Postgres authentication error until the two are reconciled by hand.

=== "Without IAM (default)"

    Transactional writes stay disabled on the public catalogue - see [Ingesting Records](#4-ingesting-records) ("Without IAM" tab) for seeding sample data.

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

`KEYCLOAK_TEST_USER` is added to `resource-catalogue-admin` automatically. Any other user who needs to perform protected catalogue operations must be assigned to the group/role manually.

For minimal non-IAM deployments, use the public catalogue only:

`https://resource-catalogue.${INGRESS_HOST}`

---

## Validation and Operation

> **Prefer a notebook?** Run `../../notebooks/run.sh` and open the <a href="http://localhost:8888/lab/tree/resource-discovery/resource-discovery.ipynb" target="_blank">Resource Discovery notebook</a> at `http://localhost:8888`.

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

`values-template.yaml` configures one federated catalogue per protocol. Each is only listed or searched through its own protocol's endpoint - there is no combined list or search across types:

| type       | id               | list                        | search                                    |
|------------|------------------|------------------------------|---------------------------------------------|
| `OARec`    | `fedcat01`       | `federatedCatalogs`          | `items?distributedSearch=true`               |
| `STAC-API` | `fedcat02`       | *(none)*                     | `/stac/search?distributedSearch=true`        |
| `CSW`      | `arctic-sdi-csw` | `GetCapabilities` (CSW 3.0)  | `GetRecords` with `csw:DistributedSearch`    |

The following examples show how to performed a federated query for each of the three APIs.

!!! note
    In each example, you will see how the results are organised according to the federated catalogue source.

**OGC API Records - Distributed Search**

```bash
# OARec - fedcat01
curl -s "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/collections/metadata:main/items?distributedSearch=true&limit=1" | jq
```

**STAC API - Distributed Search**

```bash
# STAC-API - fedcat02
curl -s "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/stac/search?distributedSearch=true&limit=1" | jq
```

**OGC CSW - Distributed Search**

```bash
# CSW - arctic-sdi-csw
curl -s "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/csw?service=CSW&version=2.0.2&request=GetRecords&typeNames=csw:Record&resultType=results&elementSetName=brief&DistributedSearch=true"
```

---

### 4. Ingesting Records

How you add records depends on whether transactions are enabled.

=== "Without IAM (default)"

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

    Needs cluster access rather than going over the ingress.

    Verify:

    ```bash
    source ~/.eoepca/state
    curl -s "${HTTP_SCHEME}://resource-catalogue.${INGRESS_HOST}/collections/metadata:main/items" | jq '.features[].id'
    ```

=== "With IAM"

    When the protected catalogue is enabled, pycsw exposes the OGC API - Records **Transactions** extension directly: an authenticated `POST`/`PUT`/`DELETE` against `/collections/{collectionId}/items`, no separate ingestion tool or building block required.

    Unauthenticated requests are redirected to Keycloak rather than served:

    ```bash
    source ~/.eoepca/state
    curl -s -o /dev/null -w "%{http_code}\n" "${HTTP_SCHEME}://resource-catalogue-protected.${INGRESS_HOST}/"
    ```

    Expect `302`.

    The `resource-catalogue` Keycloak client has the OAuth2 **device authorization grant** enabled, which is the simplest way to get a token from a terminal without a client secret:

    ```bash
    DEVICE=$(curl -s -X POST "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/auth/device" \
      -d "client_id=resource-catalogue")

    echo "$DEVICE" | jq -r '"Open \(.verification_uri_complete) and log in as a user in the resource-catalogue-admin group"'
    ```

    Open the printed URL, log in as a user assigned to the `resource-catalogue-admin` group (for example the `eoepcauser` test user - see [Protected Transactional Catalogue](#protected-transactional-catalogue)), then exchange the device code for a token:

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

    Now verify that the record is present in the protected catalogue:

    ```bash
    curl -s "${HTTP_SCHEME}://resource-catalogue-protected.${INGRESS_HOST}/collections/metadata:main/items/urn:eoepca:sample:0001?f=json" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq
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
