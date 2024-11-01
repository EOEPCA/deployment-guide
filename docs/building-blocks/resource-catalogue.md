# Resource Catalogue Deployment Guide

The **Resource Catalogue** is a standards-based Earth Observation (EO) metadata catalogue that supports OGC CSW, OGC API Records, STAC, and OpenSearch. It leverages **pycsw**, an open-source OGC-compliant metadata catalog server, to manage and serve EO data. This guide provides step-by-step instructions to deploy the Resource Catalogue within your Kubernetes cluster.


## Table of Contents

- [Resource Catalogue Deployment Guide](#resource-catalogue-deployment-guide)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
    - [Key Features](#key-features)
    - [Interfaces](#interfaces)
  - [Prerequisites](#prerequisites)
  - [Deployment Steps](#deployment-steps)
  - [Validation and Operation](#validation-and-operation)
  - [Uninstallation](#uninstallation)
  - [Further Reading](#further-reading)

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
| Cert Manager     | Properly installed            | [Installation Guide](../infra/tls/overview.mdkubernetes/) |

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

***
## Validation and Operation

**Automated Validation:**

```bash
bash validation.sh
```

**Further Validation:**

1. **Check Kubernetes Resources:**

```bash
kubectl get all -n resource-catalogue
```

2. **Access the Resource Catalogue**:

   Open a web browser and navigate to: `https://resource-catalogue.<your-domain>/`

3. **Test API Endpoints**:

  You can test the API using `curl`:
 
```bash
curl -X GET 'https://resource-catalogue.<your-domain>/collections' \
-H 'Accept: application/json'
```

***
## Uninstallation

To uninstall the Resource Catalogue and clean up associated resources:

```
helm -n resource-catalogue uninstall resource-catalogue
```

**Additional Cleanup**:

- Delete any Persistent Volume Claims (PVCs) if used:

  ```
  kubectl delete pvc -n resource-catalogue db-data-resource-catalogue-db-0
  ```

***
## Further Reading

- [Resource Catalogue BB](https://eoepca.readthedocs.io/projects/resource-discovery)
- [pycsw Documentation](https://docs.pycsw.org/en/latest/)
- [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-resource-catalogue)
