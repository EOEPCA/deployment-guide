# Datacube Access Deployment Guide

> **Note**: This Building Block is under active development. Some features may still be evolving, so we recommend using it with consideration as updates are rolled out.

The **Datacube Access** building block allows users to access and explore multi-dimensional Earth Observation (EO) data using standard APIs. It is built on open standards from OGC (Open Geospatial Consortium). 

---

## Introduction

Datacube Access gives users simple ways to discover, access, and process large Earth Observation datasets, known as "datacubes." These datacubes are structured, multi-dimensional sets of data, useful for various analytics and visualisation tasks.

### Key Features

- **Easy Data Access**: Quickly access and manage large EO datacubes.
- **Uses Open Standards**: STAC, openEO, OGC API Processes, OGC Application Packages
- **Data Discovery**: Easily discover data with STAC API integration.
- **Flexible Data Storage**: Works with common storage solutions like S3, HTTP or local file systems.
- **Data Processing**: Execute custom processing jobs using openEO and OGC API Processes.

### Interfaces

Datacube Access provides the following APIs:

- **OGC API Coverages**
- **OGC API Features**
- **STAC API**
- **openEO API for process discovery and execution**

---

## Prerequisites

| Component        | Requirement                   | Documentation Link                                                      |
|------------------|-------------------------------|-------------------------------------------------------------------------|
| Kubernetes       | Cluster (tested on v1.28)     | [Installation Guide](../prerequisites/kubernetes.md)                     |
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

### 3. Manual Validation via cURL

Quick command-line checks:

#### Basic API Check

_Returns response headers only..._

```bash
curl -s -D - -o /dev/null "https://datacube-access.${INGRESS_HOST}/"
```

#### Collection Access Test

```bash
curl "https://datacube-access.${INGRESS_HOST}/collections"
```

---

### Validating Kubernetes Resources

Check Kubernetes resource health:

```bash
kubectl get pods -n datacube-access
```

- Ensure all pods are `Running`.

---

## Further Reading & Official Docs

- [EOEPCA Datacube Access Documentation](https://eoepca.readthedocs.io/projects/datacube-access/en/latest/)
- [OGC GeoDataCube API](https://m-mohr.github.io/geodatacube-api/)
- [openEO Documentation](https://openeo.org/documentation/1.0/)

