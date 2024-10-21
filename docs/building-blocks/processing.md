# Processing Building Block Deployment Guide

The **Processing Building Block** provides a platform-hosted execution engine through which users can deploy, manage, and execute Earth Observation applications using the OGC API Processes standards. The Processing Building Block aligns with the [Zoo Project](https://zoo-project.github.io/docs/intro.html#what-is-zoo-project) which is a WPS (Web Processing Service) implementation written in C, Python and JavaScript. It is an open source platform which implements the WPS 1.0.0 and WPS 2.0.0 standards edited by the Open Geospatial Consortium (OGC).

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Deployment](#deployment)
5. [Validation and Operation](#validation-and-operation)
6. [Uninstallation](#uninstallation)
7. [Further Reading](#further-reading)
8. [Feedback](#feedback)

***
## Introduction

The Processing Building Block is made up of the following components:

- [ZOO-Kernel](https://zoo-project.github.io/docs/kernel/index.html#kernel-index): A WPS compliant implementation written in C offering a powerful WPS server able to manage and chain WPS services. by loading dynamic libraries and code written in different languages.
- [ZOO-Services](https://zoo-project.github.io/docs/services/index.html#services-index): A growing collection of ready to use Web Processing Services built on top of reliable open source libraries such as GDAL, GRASS GIS, OrfeoToolbox, CGAL and SAGA GIS.
- [ZOO-API](https://zoo-project.github.io/docs/api/index.html#api-index): A server-side JavaScript API for creating, chaining and orchestrating the available WPS Services.
- [ZOO-Client](https://zoo-project.github.io/docs/client/index.html#client-index): A client side JavaScript API for interacting with WPS servers and executing standard requests from web applications.

### Architecture Overview

- **Standardised Interfaces**: Implements OGC API Processes standards for interoperability.
- **Application Deployment**: Supports deployment, replacement, and undeployment of applications.
- **Execution Engine**: Executes applications using Kubernetes and Calrissian for CWL workflows.
- **Integration**: Works seamlessly with other EOEPCA+building blocks like Identity Management.


![[processing-ADES-execute.png]]


***
## Prerequisites

Before deploying the **Processing Building Block**, ensure you have the following:

| Component        | Requirement                            | Documentation Link                                                                            |
| ---------------- | -------------------------------------- | --------------------------------------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.28)              | [Installation Guide](../infra/kubernetes-cluster-and-networking.md)                                         |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                     |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                 |
| Ingress          | Properly installed                     | [Installation Guide](../infra/ingress-controller.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../infra/tls/overview.md/)                             |
| Stage-In S3      | Accessible                             |             [MinIO Deployment Guide](../infra/minio.md)                                                                                  |
| Stage-Out S3     | Accessible                             | [MinIO Deployment Guide](../infra/minio.md)                                                                      |

**Clone the Deployment Guide Repository:**

```
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/processing
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```
bash check-prerequisites.sh
```

***
## Deployment Steps


1. **Run the Configuration Script**

```bash
bash configure-processing.sh
```

**Configuration Parameters**
- **`INGRESS_HOST`**: Base domain for ingress hosts.
  - *Example*: `example.com`
- **`CLUSTER_ISSUER`** (if using `cert-manager`): Name of the ClusterIssuer.
  - *Example*: `letsencrypt-prod`
- **`STORAGE_CLASS`**: Storage class for persistent volumes.
  - *Example*: `default`

**Stage-Out S3 Configuration**:
Before proceeding, ensure you have an existing S3 object store. If you need to set one up, refer to the [MinIO Deployment Guide](../infra/minio.md)(). These values get automatically set in the EOEPCA+state if you followed the Deployment Steps.

- `S3_ENDPOINT`: S3 Endpoint URL.
    - Example: `minio.example.com`
- `S3_ACCESS_KEY`: S3 Access Key.
- `S3_SECRET_KEY`: S3 Secret Key.
- `S3_REGION`: S3 Region.
    - Example: `us-west-1`
    
**Stage-In S3 Configuration**:
This is where you will get the incoming data. 
- This can be set to the same as the Stage-Out configuration if you are storing the data in the same S3. 
- Alternatively if your stage-in is in a different location, for example, you are using the data hosted by CloudFerro, then update these.

- `STAGEIN_S3_ENDPOINT`: Stage-In S3 Endpoint URL.
    - Example: `stage-in-s3.example.com`
- `STAGEIN_S3_ACCESS_KEY`: Stage-In S3 Access Key.
- `STAGEIN_S3_SECRET_KEY`: Stage-In S3 Secret Key.
- `STAGEIN_S3_REGION`: Stage-In S3 Region.
    - Example: `eu-west-2`

**Important Notes:**

- If you choose **not** to use `cert-manager`, you will need to create the TLS secrets manually before deploying.
  - The required TLS secret names are:
    - `zoo-open-tls`
  - For instructions on creating TLS secrets manually, please refer to the [Manual TLS Certificate Management](../infra/tls/manual-tls.md) section in the TLS Certificate Management Guide.

3. **Deploy the Processing BB Using Helm**

```bash
helm install zoo-project-dru zoo-project-dru \
  --version 0.2.6 \
  --values generated-values.yaml \
  --repo https://zoo-project.github.io/charts/ \
  --namespace processing \
  --create-namespace
```


---
## Validation and Operation

**Automated Validation:**

```bash
bash validation.sh
```


**Manual Validation:**

1. **Check Kubernetes Resources:**

```bash
kubectl get all -l app.kubernetes.io/name=zoo-project-dru-kubeproxy --all-namespaces
kubectl get all -l app.kubernetes.io/instance=zoo-project-dru --all-namespaces
```

2. **Access Domain:**

```
https://zoo-open.<your-domain>
```

3. **Test the OGC API Processes Endpoint:**

```bash
curl -X GET 'https://zoo-open.<your-domain>/ogc-api/processes' \
  -H 'Accept: application/json'
```

4. **Access the Swagger page and test the endpoints:**

```
https://zoo-open.<your-domain>/swagger-ui/oapip
```


---
## Uninstallation

To remove the Processing Building Block from your cluster:

```bash
helm uninstall zoo-project-dru
```

### Additional Cleanup

- **Delete Persistent Volume Claims (PVCs):**

  ```bash
  kubectl delete pvc -l app.kubernetes.io/instance=zoo-project-dru
  ```


---
## Further Reading

- [ZOO-Project DRU Helm Chart](https://github.com/ZOO-Project/ZOO-Project/tree/master/docker/kubernetes/helm/zoo-project-dru)
- [EOEPCA+Cookiecutter Template](https://github.com/EOEPCA/eoepca-proc-service-template)
- [EOEPCA+Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide)
- [OGC API Processes Standards](https://www.ogc.org/standards/ogcapi-processes)
- [Common Workflow Language (CWL)](https://www.commonwl.org/)
- [Calrissian Documentation](https://github.com/Duke-GCB/calrissian)

---
## Feedback

If you have any issues or suggestions, please open an issue on the [EOEPCA+Deployment Guide GitHub Repository](https://github.com/EOEPCA/deployment-guide/issues).

