# Datacube Access Deployment Guide

> **Note**: This Building Block is under active development. Some features may still be evolving, so we recommend using it with consideration as updates are rolled out.

The **Datacube Access** building block allows users to access and explore multi-dimensional Earth Observation (EO) data using standard APIs. It is built on open standards from OGC (Open Geospatial Consortium). 

---

## Introduction

Datacube Access gives users simple ways to discover, access, and process large Earth Observation datasets, known as "datacubes." These datacubes are structured, multi-dimensional sets of data, useful for various analytics and visualisation tasks.


---

## Prerequisites

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

---

## Deployment Steps

1. **Run the Configuration Script**

```bash
bash configure-datacube-access.sh
```

**Configuration Parameters**
During script execution, provide:

- **`INGRESS_HOST`**: Domain for ingress hosts.
  - *Example*: `example.com`
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


---

## Validation and Operation

### 1. Automated Validation

```bash
bash validation.sh
```

### 2. Manual Validation via Web Browser

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

- [EOEPCA Datacube Access Documentation](https://eoepca.readthedocs.io/projects/datacube-access/en/latest/)
- [OGC GeoDataCube API](https://m-mohr.github.io/geodatacube-api/)
- [STAC Datacube Extension](https://github.com/stac-extensions/datacube)
- [openEO Documentation](https://openeo.org/documentation/1.0/)

