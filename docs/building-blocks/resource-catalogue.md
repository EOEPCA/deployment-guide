# Resource Catalogue Deployment Guide

The **Resource Catalogue** is a standards-based Earth Observation (EO) metadata catalogue that supports OGC CSW, OGC API Records, STAC, and OpenSearch. It leverages **pycsw**, an open-source OGC-compliant metadata catalog server, to manage and serve EO data. This guide provides step-by-step instructions to deploy the Resource Catalogue within your Kubernetes cluster.

***
## Introduction

The Resource Catalogue is a key component of the EOEPCA+ ecosystem, enabling users to aggregate, manage, and retrieve EO metadata from multiple sources. By adhering to open standards, it ensures discoverability and interoperability, facilitating integration with existing systems and enhancing scalability.

### Key Features

- **Metadata Management**: Aggregate and retrieve EO metadata efficiently.
- **Standards Compliance**: Supports OGC CSW, OGC API Records, STAC, and OpenSearch.
- **Discoverability**: Advanced search capabilities to locate EO data.
- **Scalability**: Built on **pycsw** for flexible and scalable deployments.

### Interfaces

The Resource Catalogue provides the following interfaces:

- **OGC CSW 2.0.2** (OGC Reference Implementation)
- **OGC CSW 3.0.0** (OGC Reference Implementation)
- **OGC API Records - Part 1: Core** (Early Implementation)
- **STAC API 1.0.0** (Listed in STAC API Servers)
- **OpenSearch** with OGC EO, Geo and Time extensions


***
## Prerequisites

Before deploying the Resource Catalogue, ensure you have the following:

| Component        | Requirement                   | Documentation Link                                          |
|------------------|-------------------------------|-------------------------------------------------------------|
| Kubernetes       | Cluster (tested on v1.28)     | [Installation Guide](../infra/kubernetes-cluster-and-networking.md)       |
| Helm             | Version 3.5 or newer          | [Installation Guide](https://helm.sh/docs/intro/install/)   |
| kubectl          | Configured for cluster access | [Installation Guide](https://kubernetes.io/docs/tasks/tools/) |
| Ingress          | Properly installed            | [Installation Guide](../infra/ingress-controller.md) |
| Cert Manager     | Properly installed            | [Installation Guide](../infra/tls/overview.md) |

**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/resource-catalogue
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

***
## Deployment Steps

1. **Run the Configuration Script**

```bash
bash configure-resource-catalogue.sh
```

**Configuration Parameters**

During the script execution, you will be prompted to provide:

   - **`INGRESS_HOST`**: Base domain for ingress hosts.
     - *Example*: `example.com`
   - **`CLUSTER_ISSUER`**: Cert-manager Cluster Issuer for TLS certificates.
     - *Example*: `letsencrypt-prod`
   - **`STORAGE_CLASS`**: Storage class for persistent volumes.
     - *Example*: `managed-nfs-storage-retain`

**Important Notes:**

- If you choose **not** to use `cert-manager`, you will need to create the TLS secrets manually before deploying.
  - The required TLS secret names are:
    - `resource-catalogue-tls`
  - For instructions on creating TLS secrets manually, please refer to the [Manual TLS Certificate Management](../infra/tls/manual-tls.md) section in the TLS Certificate Management Guide.


2. **Deploy the Resource Catalogue Using Helm**

```bash
helm repo add eoepca https://eoepca.github.io/helm-charts && \
helm repo update eoepca && \
helm upgrade -i resource-catalogue eoepca/rm-resource-catalogue \
  --values generated-values.yaml \
  --version 2.0.0-beta1 \
  --namespace resource-catalogue \
  --create-namespace
```

---

## Validation and Operation

**Automated Validation:**

```bash
bash validation.sh
```


**Further Validation:**


After deployment, the Resource Catalogue exposes several interfaces compliant with open standards. Replace `<INGRESS_HOST>` with your actual ingress host domain in the URLs below.

**Resource Catalogue Home**:

  - URL: `https://resource-catalogue.<INGRESS_HOST>/`
  - This page provides links to all available services and tools.

**OGC CSW 2.0.2 Endpoint**:

  - URL: `https://resource-catalogue.<INGRESS_HOST>/csw?service=CSW&version=2.0.2&request=GetCapabilities`

**STAC API Endpoint**:

  - URL: `https://resource-catalogue.<INGRESS_HOST>/stac`

**OpenSearch Endpoint**:

  - URL: `https://resource-catalogue.<INGRESS_HOST>/opensearch`

**Additional Tools and Endpoints**:

  - **Collections**: `https://resource-catalogue.<INGRESS_HOST>/collections`
  - **Swagger UI**:
    - **OpenAPI Swagger**: `https://resource-catalogue.<INGRESS_HOST>/openapi?f=html`
    - **JSON OpenAPI Definition**: `https://resource-catalogue.<INGRESS_HOST>/openapi?f=json`
  - **Conformance**: `https://resource-catalogue.<INGRESS_HOST>/conformance`
  - **OAI-PMH Endpoint**: `https://resource-catalogue.<INGRESS_HOST>/oaipmh`
  - **SRU Endpoint**: `https://resource-catalogue.<INGRESS_HOST>/sru`

---

To interact with the Resource Catalogue and perform queries, you need to ingest records. 
It is recommended to use the [Resource Registration Building Block](../building-blocks/resource-registration.md) to register and ingest records into the catalogue.

Alternatively, you can use the `pycsw-admin.py` utility inside the pycsw container to load sample data.

**Note**: Ensure that you have sample records available or use the provided samples within the container. 

**Steps**:

1. **Identify the pycsw Pod**:

```bash
kubectl get pods -n resource-catalogue
```

Look for the pod named similar to `resource-catalogue-service-xxxxxxxxx-xxxxx`.

2. **Access the pycsw Pod**:

```bash
kubectl exec -it <resource-catalogue-pod-name> -n resource-catalogue -- /bin/bash
```

3. **Navigate to the pycsw Directory**:

```bash
cd /usr/local/bin
```

4. **Load Sample Data**:

You can see the full list of commands available by running
```bash
pycsw-admin.py --help
```

For example, to load sample records from the `samples/records` directory, run the following command:
```bash
pycsw-admin.py -c load_records -f etc/pycsw/default.cfg -p samples/records
```
---

#### Querying the Catalogue

Once you have records ingested, you can perform queries against the catalogue using various interfaces.

View all collections and records via the web interface:

```url
https://resource-catalogue.<INGRESS_HOST>/collections/
```

Alternatively, use `curl` to get a JSON response of all collections:

```bash
curl "https://resource-catalogue.<INGRESS_HOST>/collections"
```

---

**Using the STAC API**

```bash
curl "https://resource-catalogue.<INGRESS_HOST>/stac"
```

Perform a STAC Item Search:

```bash
curl -X POST "https://resource-catalogue.<INGRESS_HOST>/stac/search" \
-H "Content-Type: application/json" \
-d '{
      "bbox": [-180, -90, 180, 90],
      "datetime": "2010-01-01T00:00:00Z/2020-12-31T23:59:59Z",
      "limit": 10
    }'
```

---

#### Using OGC CSW

Access the `GetCapabilities` document to verify the CSW service:

```bash
curl "https://resource-catalogue.<INGRESS_HOST>/csw?service=CSW&version=2.0.2&request=GetCapabilities"
```

**Note**: For more advanced queries, refer to the [OGC CSW 2.0.2 Documentation](https://www.ogc.org/standards/cat).


---

### Validating Kubernetes Resources

Ensure that all Kubernetes resources are running correctly.

```bash
kubectl get pods -n resource-catalogue
```

**Expected Output**:

- All pods should be in the `Running` state.
- No pods should be in `CrashLoopBackOff` or `Error` states.

---

## Further Reading

For more detailed information, refer to the following resources:

- [EOEPCA Resource Catalogue Documentation](https://eoepca.readthedocs.io/projects/resource-discovery)
- [pycsw Official Documentation](https://docs.pycsw.org/en/latest/)
- [pycsw GitHub Repository](https://github.com/geopython/pycsw)
