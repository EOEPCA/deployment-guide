# Resource Registration Deployment Guide

The **Resource Registration** Building Block enables data and metadata ingestion into platform services. It handles:

- Metadata registration into Resource Discovery
- Data registration into Data Access services
- Resource visualisation configuration

---

## Introduction

The **Resource Registration Building Block** manages resource ingestion into the platform for discovery, access and collaboration. It supports:

- Datasets (EO data, auxiliary data)
- Processing workflows 
- Jupyter Notebooks
- Web services and applications
- Documentation and metadata

The BB integrates with other platform services to enable:

- Automated metadata extraction
- Resource discovery indexing
- Access control configuration
- Usage tracking

---

## Components Overview

The Resource Registration BB comprises three main components:

1. **Registration API**  
An OGC API Processes interface for registering, updating, or deleting resources on the local platform.
    
2. **Harvester**  
Automates workflows (via Flowable BPMN) to harvest data from external sources and register them in the platform.
    
3. **Common Registration Library**  
A Python library consolidating upstream packages (e.g. STAC tools, eometa tools) for business logic in workflows and resource handling.

---

## Prerequisites

Before deploying the Resource Registration Building Block, ensure you have the following:

| Component          | Requirement                            | Documentation Link                                                |
| ------------------ | -------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.28)              | [Installation Guide](../prerequisites/kubernetes.md)             |
| Helm               | Version 3.7 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| TLS Certificates   | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md) |
| Ingress Controller | Properly installed (e.g., NGINX)       | [Installation Guide](../prerequisites/ingress/overview.md)      |


**Clone the Deployment Guide Repository:**

```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/resource-registration
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script

Generate configuration files and prepare deployment:

```bash
bash configure-resource-registration.sh
```

**Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
    - *Example*: `example.com`
- **`CLUSTER_ISSUER`**: Cert-Manager ClusterIssuer for TLS certificates.
    - *Example*: `letsencrypt-http01-apisix`
- **`FLOWABLE_ADMIN_USER`**: Admin username for Flowable.
    - *Default*: `eoepca`
- **`FLOWABLE_ADMIN_PASSWORD`**: Admin password for Flowable.
    - *Default*: `eoepca`


### 2. Apply Kubernetes Secrets

Create required secrets:

```bash
bash apply-secrets.sh
```

**Secrets Created:**

- `flowable-admin-credentials` / `registration-harvester-secret`:<br>
  _Contains Flowable admin username and password_

### 3. Deploy the Registration API Using Helm

Deploy the Registration API using the generated values file.

```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev
helm repo update eoepca-dev
helm upgrade -i registration-api eoepca-dev/registration-api \
  --version 2.0.0-rc1 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-api/generated-values.yaml
```

Deploy the ingress for the Registration API:

```bash
kubectl apply -f registration-api/generated-ingress.yaml
```

### 4. Deploy the Registration Harvester Using Helm

**Deploy Flowable Engine:**

```bash
helm repo add flowable https://flowable.github.io/helm/
helm repo update flowable
helm upgrade -i registration-harvester-api-engine flowable/flowable \
  --version 7.0.0 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-harvester/generated-values.yaml
```

Deploy the ingress for the Flowable Engine:

```bash
kubectl apply -f registration-harvester/generated-ingress.yaml
```

**Deploy Registration Harvester Worker:**

By way of example, a `worker` is deployed that harvests `Landast` data from [USGS](https://landsatlook.usgs.gov/stac-server).

```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev
helm repo update eoepca-dev
helm upgrade -i registration-harvester-worker eoepca-dev/registration-harvester \
  --version 2.0.0-rc1 \
  --namespace resource-registration \
  --create-namespace \
  --values registration-harvester/generated-values.yaml
```


### 5. Monitor the Deployment

Check the status of the deployments:

```bash
kubectl get all -n resource-registration
```

---

## Validation and Usage

**Automated Validation:**

This script performs a series of automated tests to validate the deployment.

```bash
bash validation.sh
```

---

**Registration API Home:**

This page provides basic information about the Registration API.

```
https://registration-api.${INGRESS_HOST}/
```
 

**Swagger UI Documentation:**

Interactive API documentation allowing you to explore and test the Registration API endpoints.

```
https://registration-api.${INGRESS_HOST}/openapi?f=html
``` 

**Flowable REST API Swagger UI:**

Provides Swagger UI documentation for the Flowable REST API.

```
https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/docs/
```

**Note:**

- You can use `xdg-open` to open these URLs in your default browser after setting the `INGRESS_HOST` variable (`source ~/.eoepca/state`)

---

### Testing a Simple Hello-World Process

```bash
source ~/.eoepca/state
curl -X POST "https://registration-api.${INGRESS_HOST}/processes/hello-world/execution" \
-H "Content-Type: application/json" \
-d '{
   "inputs": {
      "name": "Resource Registration Validation Tester",
      "message": "This confirms that the Registration API is working correctly."
   }
}'
```

---

## Registering Resources

Resource Registration relies on an **OGC API Processes** interface. To register a resource, send a `POST` request with a JSON payload to:

```
/processes/register/execution
```

A typical JSON request body might look like:

```json5
{
  "inputs": {
    "type": "...",         // e.g. "dataset", "item" etc.
    "source": "...",       // URL to the resource's current location (e.g. Git repo, S3 bucket, etc.)
    "target": "..."        // Endpoint or final location to publish the resource
  }
}
```

### Registering a Dataset (Example)

> **Prerequisite**: You should have a running STAC server. For a quick setup, refer to the [Resource Discovery](resource-discovery.md) Building Block documentation.

Use the following command to register a STAC Item with the platform:

```bash
source ~/.eoepca/state
curl -X POST "https://registration-api.${INGRESS_HOST}/processes/register/execution" \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
  "inputs": {
    "type": "dataset",
    "source": "https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/scripts/resource-registration/data/simple-item.json",
    "target": "https://resource-catalogue.${INGRESS_HOST}/stac"
  }
}
EOF
```

- **type**: Use `"dataset"` for STAC EO data.
- **source**: A valid STAC Item URL (in this example, hosted on GitHub).
- **target**: Your STAC server endpoint where the resource is to be registered.

### Validating the Registration

```
https://registration-api.${INGRESS_HOST}/jobs
```

You should see a new job with the status `COMPLETED`. 

If you have deployed the [**Resource Discovery**](./resource-discovery.md) Building Block, then the registered STAC Item will also be available at:

```
https://resource-catalogue.${INGRESS_HOST}/stac/collections/metadata:main/items/20201211_223832_CS2
```

_(The item ID and collection path will vary based on your input.)_

#### Using the Registration Harvester

The Registration Harvester leverages Flowable to automate resource harvesting workflows.

**Access the Flowable REST API Swagger UI:**

```url
https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/docs/
```

**List Deployed Processes**

Retrieve a list of deployed processes:

```bash
source ~/.eoepca/state
curl -u ${FLOWABLE_ADMIN_USER}:${FLOWABLE_ADMIN_PASSWORD} \
     "https://registration-harvester-api.${INGRESS_HOST}/flowable-rest/service/repository/process-definitions"
```

---


### Validating Kubernetes Resources

Ensure that all Kubernetes resources are running correctly.

```bash
kubectl get pods -n resource-registration
```

**Expected Output:**

- All pods should be in the `Running` state.
- No pods should be in `CrashLoopBackOff` or `Error` states.

---

## Uninstallation

To uninstall the Resource Registration Building Block and clean up associated resources:

```bash
helm uninstall registration-api -n resource-registration
helm uninstall registration-harvester-api-engine -n resource-registration
helm uninstall registration-harvester-worker -n resource-registration

kubectl delete namespace resource-registration
```

---

## Further Reading

- [EOEPCA+ Resource Registration GitHub Repository](https://github.com/EOEPCA/resource-registration)
- [Flowable BPMN Platform](https://flowable.com/open-source/)
- [pygeoapi Documentation](https://pygeoapi.io/)
- [EOEPCA+ Helm Charts](https://eoepca.github.io/helm-charts-dev)
