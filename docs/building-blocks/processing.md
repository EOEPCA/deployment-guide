# Processing Building Block Deployment Guide

The **Processing Building Block** provides deployment and execution of user-defined processing workflows within the EOEPCA+ platform - with support for OGC API Processes, OGC Application Packages and openEO. The Processing BB is deployed in the form of a number of _Processing Engine_ variants that implement the different workflow approaches...

* **OGC API Processes Engine**<br>
  The **OGC API Processes Engine** provides an OGC API Processes execution engine through which users can deploy, manage, and execute OGC Application Packages. The OAPIP engine is provided by the [ZOO-Project](https://zoo-project.github.io/docs/intro.html#what-is-zoo-project) `zoo-project-dru` implementation - supporting OGC WPS 1.0.0/2.0.0 and OGC API Processes Parts 1 & 2.
* **openEO Engine**<br>
  _Coming soon_

***
## OGC API Processes Engine

### Introduction

The OGC API Processes Engine provides...

- **Standardised Interfaces**: Implements OGC API Processes standards for interoperability.
- **Application Deployment**: Supports deployment, replacement, and undeployment of applications.
- **Execution Engine**: Executes applications using Kubernetes and Calrissian for CWL workflows.
- **Integration**: Works seamlessly with other EOEPCA+building blocks like Identity Management.

***
### Prerequisites

Before deploying the **OGC API Processes Engine**, ensure you have the following:

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
cd deployment-guide/scripts/processing/oapip
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```
bash check-prerequisites.sh
```

***
### Deployment Steps


1. **Run the Configuration Script**

```bash
bash configure-oapip.sh
```

**Configuration Parameters**

- **`INGRESS_HOST`**: Base domain for ingress hosts.
    - *Example*: `example.com`
- **`CLUSTER_ISSUER`** (if using `cert-manager`): Name of the ClusterIssuer.
    - *Example*: `letsencrypt-prod`
- **`STORAGE_CLASS`**: Storage class for persistent volumes.
    - *Example*: `default`

**Stage-Out S3 Configuration**:
Before proceeding, ensure you have an existing S3 object store. If you need to set one up, refer to the [MinIO Deployment Guide](../infra/minio.md). These values get automatically set in the EOEPCA+ state if you followed the Deployment Steps.

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
    - `zoo-tls`
  - For instructions on creating TLS secrets manually, please refer to the [Manual TLS Certificate Management](../infra/tls/manual-tls.md) section in the TLS Certificate Management Guide.

1. **Deploy the Processing BB Using Helm**

```bash
helm repo add zoo-project https://zoo-project.github.io/charts/ && \
helm repo update zoo-project && \
helm upgrade -i zoo-project-dru zoo-project/zoo-project-dru \
  --version 0.3.6 \
  --values generated-values.yaml \
  --namespace processing \
  --create-namespace
```

---
### Validation and Operation

**Automated Validation:**

```bash
bash validation.sh
```


**Manual Validation:**

1. **Check Kubernetes Resources:**

```bash
kubectl get all -l app.kubernetes.io/name=zoo-project-dru-kubeproxy --all-namespaces ; \
kubectl get all -l app.kubernetes.io/instance=zoo-project-dru --all-namespaces
```

2. **Access Web Interface:**

Use the ZOO-Project Swagger UI to test the endpoints.

```
https://zoo.<your-domain>/swagger-ui/oapip/
```

3. **Test the OGC API Processes Endpoint:**

```bash
curl -X GET 'https://zoo.<your-domain>/ogc-api/processes' \
  -H 'Accept: application/json'
```


---
### Uninstallation

To remove the Processing Building Block from your cluster:

```bash
helm -n processing uninstall zoo-project-dru
```

#### Additional Cleanup

- **Delete Persistent Volume Claims (PVCs):**

  ```bash
  kubectl -n processing delete pvc -l app.kubernetes.io/instance=zoo-project-dru
  ```


---
### Further Reading

- [ZOO-Project DRU Helm Chart](https://github.com/ZOO-Project/ZOO-Project/tree/master/docker/kubernetes/helm/zoo-project-dru)
- [EOEPCA+Cookiecutter Template](https://github.com/EOEPCA/eoepca-proc-service-template)
- [EOEPCA+Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide)
- [OGC API Processes Standards](https://www.ogc.org/standards/ogcapi-processes)
- [Common Workflow Language (CWL)](https://www.commonwl.org/)
- [Calrissian Documentation](https://github.com/Duke-GCB/calrissian)

---
## Feedback

If you have any issues or suggestions, please open an issue on the [EOEPCA+Deployment Guide GitHub Repository](https://github.com/EOEPCA/deployment-guide/issues).

