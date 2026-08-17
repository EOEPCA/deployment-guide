# Datacube Access Deployment Guide

The **Datacube Access** Building Block defines a metadata convention for datacube-ready STAC collections, plus an optional API for filtering an existing STAC catalog down to the collections that follow it.

---

## Introduction

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
    | STAC Catalog     | Properly installed            | [Deployment Guide](./data-access.md)                  |

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

    Under `https://datacube-access.${INGRESS_HOST}`:

    | Endpoint | Purpose |
    |----------|---------|
    | `/` | Landing page - JSON with API information and links |
    | `/docs` | Interactive OpenAPI (Swagger) UI |
    | `/collections` | Datacube-ready collections exposed by the filter |
    | `/conformance` | OGC API conformance classes |

---

## Uninstallation

To remove the reference filtering service:

```bash
helm uninstall datacube-access -n datacube-access
kubectl delete namespace datacube-access
```

---

## Usage and Testing

> **Prefer a notebook?** Run `../../notebooks/run.sh` and open the <a href="http://localhost:8888/lab/tree/datacube-access/datacube-access.ipynb" target="_blank">Datacube Access notebook</a> at `http://localhost:8888`.

The Datacube Access BB filters your STAC catalog to expose only collections that include the [STAC Datacube Extension](https://github.com/stac-extensions/datacube) - specifically those with `cube:dimensions` or `cube:variables` defined. This ensures processing tools like openEO only see properly-structured, analysis-ready collections.

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

[openEO](https://openeo.org/) backends need exact band names, temporal resolution and dimension relationships to build a process graph - e.g. an NDVI time series workflow. Datacube Access's filtering ensures openEO only sees collections carrying that metadata, rather than heterogeneous STAC collections it can't reliably load as multi-dimensional arrays.


---

## Further Reading & Official Docs

- [STAC Best Practices for Data Cubes](https://github.com/EOEPCA/datacube-access/blob/main/best_practices/stac_best_practices.md) - the core metadata convention this BB defines
- [EOEPCA Datacube Access Documentation](https://eoepca.readthedocs.io/projects/datacube-access/en/latest/)
- [OGC GeoDataCube API](https://m-mohr.github.io/geodatacube-api/)
- [STAC Datacube Extension](https://github.com/stac-extensions/datacube)
- [openEO Documentation](https://openeo.org/documentation/1.0/)

