# Datacube Access Deployment Guide

The **Datacube Access** building block allows users to access and explore multi-dimensional Earth Observation (EO) data using standard APIs. It is built on open standards from OGC (Open Geospatial Consortium). 

---

## Introduction

Datacube Access gives users simple ways to discover, access, and process large Earth Observation datasets, known as "datacubes." These datacubes are structured, multi-dimensional sets of data, useful for various analytics and visualisation tasks.

This Building Block has two parts:

- **STAC Best Practices for datacube-ready collections** - the core deliverable. A metadata convention (built on the [STAC Datacube Extension](https://github.com/stac-extensions/datacube)) that other Building Blocks - Resource Registration, Data Access, Processing - rely on to interoperate, so that any datacube-ready collection in your STAC catalog can be reliably loaded and processed. This applies whether or not you deploy anything below.
- **A reference filtering API** (optional) - a small service that filters an existing STAC API down to only the collections that follow the convention above. Useful if you want a dedicated endpoint for datacube-ready data, but not required to benefit from the best practices themselves.

See the [STAC Best Practices for Data Cubes](https://github.com/EOEPCA/datacube-access/blob/main/best_practices/stac_best_practices.md) for the full convention, and the [Design Overview](https://eoepca.readthedocs.io/projects/datacube-access/en/latest/design/overview/) for how this BB relates to the others.

---

## Optional: Deploy the Reference Filtering Service

!!! note
    The steps below deploy the reference filtering API. This is only useful if you want a dedicated `datacube-access` endpoint on top of an existing STAC catalog - skip this section if you only need the STAC Best Practices to structure your own collections.

??? note "Deploy the Reference Filtering Service"

    ### Prerequisites

    | Component        | Requirement                   | Documentation Link                                                      |
    |------------------|-------------------------------|-------------------------------------------------------------------------|
    | Kubernetes       | Cluster (tested on v1.32)     | [Installation Guide](../prerequisites/kubernetes.md)                     |
    | Helm             | Version 3.5 or newer          | [Installation Guide](https://helm.sh/docs/intro/install/)               |
    | kubectl          | Configured for cluster access | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)           |
    | Ingress          | Properly installed            | [Installation Guide](../prerequisites/ingress/overview.md)              |
    | Cert Manager     | Properly installed            | [Installation Guide](../prerequisites/tls.md)                           |
    | STAC Catalog     | Properly installed            | [Deployment Guide](./resource-discovery.md)                  |

    **Clone the Deployment Guide Repository:**

    ```bash
    git clone https://github.com/EOEPCA/deployment-guide
    cd deployment-guide/scripts/datacube-access
    ```

    **Validate your environment:**

    ```bash
    bash check-prerequisites.sh
    ```

    ### Deployment Steps

    1. **Run the Configuration Script**

    ```bash
    bash configure-datacube-access.sh
    ```

    **Configuration Parameters**
    During script execution, provide:

    - **`INGRESS_HOST`**: Domain for ingress hosts.
      - *Example*: `example.com`
    - **`STAC_CATALOG_ENDPOINT`**: The STAC API to filter down to datacube-ready collections. Defaults to `https://eoapi.${INGRESS_HOST}/stac/`, matching the [Data Access](./data-access.md) BB's `eoapi` STAC endpoint.
      - The service does not follow HTTP redirects when calling this backend. If the STAC catalog issues one (e.g. `eoapi` redirects `/stac` to `/stac/`), every request - including the pod's own liveness/readiness probes - fails and the pod crash-loops. Use the exact URL that returns `200` directly, trailing slash included where required.
    - **`CLUSTER_ISSUER`**: Cert-manager issuer for TLS certificates.
      - *Example*: `letsencrypt-http01`


    2. **Deploy Datacube Access Using Helm**

    ```bash
    helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev
    helm repo update eoepca-dev
    helm upgrade -i datacube-access eoepca-dev/datacube-access \
      --values generated-values.yaml \
      --version 2.0.0-rc2 \
      --namespace datacube-access \
      --create-namespace
    ```


    ### Validation and Operation

    #### 1. Automated Validation

    ```bash
    bash validation.sh
    ```

    #### 2. Manual Validation via Web Browser

    Verify endpoints using a web browser:

    - **Landing/Home Page**

    ```bash
    https://datacube-access.${INGRESS_HOST}/
    ```
    Expect a JSON response with API information and links.

    - **OpenAPI Documentation**

    ```bash
    https://datacube-access.${INGRESS_HOST}/docs
    ```
    Interactive UI listing available API endpoints.

    - **Collections Access**

    ```bash
    https://datacube-access.${INGRESS_HOST}/collections
    ```
    Verify JSON or HTML response listing available datacube collections.

    - **Conformance Check**

    ```bash
    https://datacube-access.${INGRESS_HOST}/conformance
    ```
    Confirm OGC API conformance classes and supported standards.


    #### Collection Access Test

    ```bash
    curl "https://datacube-access.${INGRESS_HOST}/collections"
    ```

---

## Uninstallation

To remove the reference filtering service:

```bash
helm uninstall datacube-access -n datacube-access
kubectl delete namespace datacube-access
```

---

## Usage and Testing

The Datacube Access BB filters your STAC catalog to expose only collections that include the [STAC Datacube Extension](https://github.com/stac-extensions/datacube) - specifically those with `cube:dimensions` or `cube:variables` defined. This ensures processing tools like openEO only see properly-structured, analysis-ready collections.

### Understanding Datacube-Ready Collections

Standard STAC collections describe what data exists and where. Datacube-ready collections add structural metadata: dimensions (x, y, time, bands), coordinate reference systems, and dimension relationships. This metadata tells processing tools how to interpret and load the data as a multidimensional datacube.

### Loading a Test Collection

Add a sample datacube-ready collection to your STAC catalog. There is a provided script in the `deployment-guide/scripts/datacube-access/collections/datacube-ready-collection/` directory. This is setup to work automatically with the `eoapi` component of the `Data Access` BB, but this can be adapted to other STAC catalogs, i.e. A `POST` request using the `collections.json` and `items.json` provided.

```bash
cd collections/datacube-ready-collection
../ingest.sh
cd ../..
```

View the collection at
```
https://datacube-access.${INGRESS_HOST}/collections/sentinel-2-datacube
```

### Testing with Processing Tools
A test script is provided to demonstrate loading the datacube using Python libraries like `pystac-client` and `odc-stac`. This script connects to the Datacube Access STAC API, searches for the datacube-ready collection, and loads it into an `xarray` datacube.

```bash
cd tests
python -m venv venv
source ./venv/bin/activate
pip install -U -r requirements.txt
source ~/.eoepca/state
python processing-tools.py
deactivate
cd ..
```

### Relevance to OpenEO

Datacube Access acts as a filtered data layer for [openEO](https://openeo.org/) backends by exposing only collections with proper datacube metadata (`cube:dimensions`, `cube:variables`). This ensures openEO can reliably load data into multi-dimensional arrays and perform operations.

The dimensional metadata (spatial, temporal, spectral) enables openEO to validate process graphs and maintain dimension compatibility throughout processing chains. Without this filtering, openEO backends would encounter heterogeneous STAC collections lacking the structure needed for multi-dimensional processing.

For example, an openEO workflow calculating NDVI time series needs to know exact band names, temporal resolution, and dimension relationships - all provided by the datacube metadata.


---

## Further Reading & Official Docs

- [STAC Best Practices for Data Cubes](https://github.com/EOEPCA/datacube-access/blob/main/best_practices/stac_best_practices.md) - the core metadata convention this BB defines
- [EOEPCA Datacube Access Documentation](https://eoepca.readthedocs.io/projects/datacube-access/en/latest/)
- [OGC GeoDataCube API](https://m-mohr.github.io/geodatacube-api/)
- [STAC Datacube Extension](https://github.com/stac-extensions/datacube)
- [openEO Documentation](https://openeo.org/documentation/1.0/)

