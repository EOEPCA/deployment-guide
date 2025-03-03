# Resource Discovery Deployment Guide

The **Resource Discovery** building block provides a standards-based Earth Observation (EO) metadata catalogue, supporting OGC CSW, OGC API Records, STAC, and OpenSearch. It combines and extends the functionality previously known as the "Resource Catalogue," but has now evolved to handle additional resource types and deeper integration with data-catalogue components like **eoAPI**. Under the hood it still leverages **pycsw** for OGC compliance and can also integrate with **pgSTAC** (via eoAPI) for large-scale STAC metadata handling. This guide provides step-by-step instructions to deploy Resource Discovery in your Kubernetes cluster.

---

## Introduction

The Resource Discovery building block is a key component of the EOEPCA+ ecosystem. It enables users to aggregate, manage, and retrieve EO metadata from multiple sources. By adhering to open standards, it ensures discoverability and interoperability, facilitating integration with existing systems and enhancing scalability.

### Key Features

- **Metadata Management**: Aggregate and retrieve EO metadata efficiently across multiple resource types.  
- **Standards Compliance**: Supports OGC CSW, OGC API Records, STAC, and OpenSearch.  
- **Discoverability**: Advanced search capabilities—supporting bounding boxes, time intervals, free-text, and more.  
- **Scalability**: Built on **pycsw** and optionally on **pgSTAC**, enabling flexible, scalable deployments.  
- **Federation**: Supports platform federation by maintaining references to remote platforms.  
- **Transactional Support**: Endpoints for creating, updating, and deleting resources where permitted.

### Interfaces

The Resource Discovery building block includes:

- **OGC CSW (2.0.2 and 3.0)**  
- **OGC API - Records (Part 1: Core)**  
- **STAC API 1.0.0**  
- **OpenSearch** with OGC EO, Geo, and Time extensions  
- **Optional Dataset Catalogue** via **eoAPI** for STAC-based ingestion of granule-level data  

---

## Prerequisites

| Component        | Requirement                   | Documentation Link                                                      |
|------------------|-------------------------------|-------------------------------------------------------------------------|
| Kubernetes       | Cluster (tested on v1.28)     | [Installation Guide](../prerequisites/kubernetes.md)     |
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
During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts.  
    - *Example*: `example.com`
- **`CLUSTER_ISSUER`**: Cert-manager Cluster Issuer for TLS certificates.  
    - *Example*: `letsencrypt-http01-apisix`
- **`STORAGE_CLASS`**: Storage class for persistent volumes.  
    - *Example*: `standard`


2. **Deploy Resource Discovery Using Helm**

```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev
helm repo update eoepca-dev
helm upgrade -i resource-discovery eoepca-dev/rm-resource-catalogue \
  --values generated-values.yaml \
  --version 2.0.0-beta2 \
  --namespace resource-discovery \
  --create-namespace
```

Deploy the ingress for the Resource Discovery service:

```bash
kubectl apply -f generated-ingress.yaml
```

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
https://resource-catalogue.${INGRESS_HOST}/
```
You should see an HTML landing page or a minimal JSON response with links to the various endpoints.

- **Swagger UI (OpenAPI)**

```bash
https://resource-catalogue.${INGRESS_HOST}/openapi?f=html
```  
Opens a human-friendly UI showing available endpoints and interactive documentation.  

- **OGC API - Records / STAC Collections**

```bash
https://resource-catalogue.${INGRESS_HOST}/collections
```  
Should return a JSON or HTML response listing available collections.

- **Conformance**

```bash
https://resource-catalogue.${INGRESS_HOST}/conformance
```  
Confirms which OGC API conformance classes and standards are supported by the server.

If these return meaningful responses (especially HTTP 200 with JSON or HTML data), it indicates that your Resource Discovery instance is operational.

### 3. Manual Validation via cURL / Command Line

Using the command line can be a quick way to check endpoints and see raw responses. Below are some example commands.

#### 3.1. Basic Liveness Check

```bash
curl -I "https://resource-catalogue.${INGRESS_HOST}/"
```

#### 3.2. Testing OGC CSW

```bash
curl "https://resource-catalogue.${INGRESS_HOST}/csw?service=CSW&version=2.0.2&request=GetCapabilities"
```

- A successful response should be an XML Capabilities document containing service metadata.  

#### 3.3. Testing STAC API

```bash
curl "https://resource-catalogue.${INGRESS_HOST}/stac"
```

- You should see a JSON object containing STAC-related metadata, including a list of links to collections and search endpoints.

#### 3.4. Searching STAC Items

```bash
source ~/.eoepca/state
curl -X POST "https://resource-catalogue.${INGRESS_HOST}/stac/search" \
   --silent --show-error \
  -H "Content-Type: application/json" \
  -d '{
        "bbox": [-180, -90, 180, 90],
        "datetime": "2010-01-01T00:00:00Z/2025-12-31T23:59:59Z",
        "limit": 5
      }'
```

You should receive a JSON response listing zero or more STAC items that match the query. If you have not yet ingested any items, you may get an empty result array (`"features": []`).  


### 4. Ingesting Sample Records

    
**Find the Resource Catalogue Pod**:
        
```bash
kubectl get pods -n resource-discovery
```

Look for a pod name similar to `resource-catalogue-service-abcd1234-efgh5678`.
        
**Copy the Sample File** (`sample_record.xml`) to the pod.
> The sample record is provided in the `scripts/resource-discovery` directory of the deployment guide repository.
        
```bash
kubectl cp sample_record.xml \
  resource-discovery/<YOUR-RESOURCE-CATALOGUE-POD>:/tmp/sample_record.xml
```
        
3. **Access the Pod**:
        
```bash
kubectl exec -it <YOUR-RESOURCE-CATALOGUE-POD> -n resource-discovery -- /bin/bash
```
        
2. **Load the Sample Record using pycsw**

From within the container, run:

```bash
pycsw-admin.py load-records \
  --config /etc/pycsw/pycsw.yml \
  --path /tmp/sample_record.xml
```
    
3. **Verify the Ingested Record**
    
- **Via Web Browser / UI**  
    Navigate to:
    
    ```
    https://resource-catalogue.<INGRESS_HOST>/collections/metadata:main/items
    ```
    
    Confirm that the newly ingested record (titled `EOEPCA Sample Record`) appears in the search results.
    
- **Via Command Line**  
    You can also use `curl` or other OGC-compliant requests to verify that the sample record is now discoverable.

---

### Validating Kubernetes Resources

Ensure all Kubernetes resources are running correctly:

```bash
kubectl get pods -n resource-discovery
```

- All pods should be in `Running` state.
- No pods should be stuck in `CrashLoopBackOff` or `Error`.

---

## Further Reading & Official Docs

- [EOEPCA Resource Discovery Documentation](https://eoepca.readthedocs.io/projects/resource-discovery)  
- [pycsw Official Documentation](https://docs.pycsw.org/en/latest/)  
- [pycsw GitHub Repository](https://github.com/geopython/pycsw)  
- [eoAPI-k8s Documentation](https://github.com/developmentseed/eoapi-k8s/blob/main/docs) (if using eoAPI for dataset-level STAC ingestion)
