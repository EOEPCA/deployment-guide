# Processing - OpenEO Engine Deployment Guide (Early Access)

The **OpenEO Engine** building block provides early access to a unified processing platform for Earth observation data. It brings together two key components: **openEO Geotrellis** and **openEO Aggregator**. These components work together to offer a standards-based API for connecting to diverse EO cloud back-ends and to federate multiple openEO services into a cohesive processing platform.

> **Note:** Integration of the openEO Engine is still in early access. The steps provided here are work-in-progress and may evolve in future releases.

---

## Introduction

- **openEO Geotrellis:** Provides an API that simplifies connecting to EO cloud back-ends, running on Apache Spark in a Kubernetes environment.
- **openEO Aggregator:** Groups multiple openEO back-ends into a unified, federated processing platform.

### Key Features

- **Unified API Access:** Standardized endpoints allow clients to connect easily with multiple EO data services.
- **Federated Processing:** Seamlessly aggregates back-ends, enabling flexible data processing.
- **Standards Compliance:** Follows openEO specifications to maintain broad interoperability.
- **Scalability:** Uses Kubernetes and Helm for robust, scalable deployments.
- **Early Access Deployment:** Offers raw steps to deploy and experiment with the openEO Engine components.

---

## Prerequisites

Before deploying, ensure your environment meets the following requirements:

|Component|Requirement|Documentation Link|
|---|---|---|
|Kubernetes|Cluster (tested on v1.28)|[Installation Guide](../prerequisites/kubernetes.md)|
|Helm|Version 3.5 or newer|[Installation Guide](https://helm.sh/docs/intro/install/)|
|kubectl|Configured for cluster access|[Installation Guide](https://kubernetes.io/docs/tasks/tools/)|
|Ingress|Properly installed|[Installation Guide](../prerequisites/ingress-controller.md)|
|Cert Manager|Properly installed|[Installation Guide](../prerequisites/tls.md)|

**Clone the Deployment Guide Repository:**

```
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/processing/openeo
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script

```bash
bash configure-openeo-geotrellis.sh
```

During this process, you will be prompted for:

- **`INGRESS_HOST`**: Base domain for ingress hosts (e.g., `example.com`).
- **`STORAGE_CLASS`**: Kubernetes storage class for persistent volumes.
- **`CLUSTER_ISSUER`**: Cert-manager Cluster Issuer for TLS certificates.


### 2. Deploying openEO Geotrellis

openEO Geotrellis provides the API that connects users to EO cloud back-ends. It leverages Apache Spark and requires both the Spark Operator and ZooKeeper to function.

#### Step 1: Install Spark Operator

Deploy the Kubeflow Spark Operator to manage Spark jobs within your Kubernetes cluster:

```bash
helm upgrade -i openeo-geotrellis-sparkoperator spark-operator \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 2.0.2 \
    --namespace openeo-geotrellis \
    --create-namespace \
    --values sparkoperator/generated-values.yaml
```

Refer to the [values.yaml](https://github.com/kubeflow/spark-operator/blob/master/charts/spark-operator-chart/values.yaml) for additional configuration options.

#### Step 2: Install ZooKeeper

Deploy Apache ZooKeeper, which is required for internal coordination:

```bash
helm upgrade -i openeo-geotrellis-zookeeper \
    https://artifactory.vgt.vito.be/artifactory/helm-charts/zookeeper-11.1.6.tgz \
    --namespace openeo-geotrellis \
    --create-namespace \
    --values zookeeper/generated-values.yaml
```

For full configuration details, see the [values.yaml](https://github.com/bitnami/charts/blob/main/bitnami/zookeeper/values.yaml).

#### Step 3: Deploy openEO Geotrellis Using Helm

Provides an API that simplifies connecting to EO cloud back-ends, running on Apache Spark in a Kubernetes environment.

```bash
helm upgrade -i openeo-geotrellis-openeo sparkapplication \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 0.16.3 \
    --namespace openeo-geotrellis \
    --create-namespace \
    --values openeo-geotrellis/generated-values.yaml
```

Deploy ingress

```
kubectl apply -f openeo-geotrellis/generated-ingress.yaml
```

#### Step 4: Deploy openEO Aggregator using Helm

The openEO Aggregator federates multiple openEO back-ends into a unified processing platform.


```bash
helm upgrade -i openeofed \
  https://artifactory.vgt.vito.be/artifactory/helm-charts/openeo-aggregator-2025.01.10-14.tgz \
  --namespace openeo-geotrellis \
  --create-namespace \
  --values openeo-aggregator/generated-values.yaml
```

---

## Validation

After deploying the OpenEO Engine components, perform the following checks to verify that the system is working as expected.

### 1. Automated Validation (Optional)

```bash
bash validation.sh
```

This script verifies that:

- All required pods in the `openeo-geotrellis` (and optionally `openeofed`) namespace are running.
- Ingress endpoints return an HTTP 200 status code.
- Key API endpoints provide well-formed JSON responses.



### 2. Manual Validation

To easily run these commands, we recommend first setting `${INGRESS_HOST}` in your environment.

```bash
source ~/.eoepca/state
```

Use the following commands to interact directly with the APIs:

#### Check API Metadata

```bash
curl -L https://openeo.${INGRESS_HOST}/openeo/1.2/ | jq .
```

_Expected output:_ A JSON object containing `api_version`, `backend_version`, `endpoints`, etc.

#### List Collections

```bash
curl -L https://openeo.${INGRESS_HOST}/openeo/1.2/collections | jq .
```

_Expected output:_ A JSON array listing available collections, such as the sample collection `TestCollection-LonLat16x16`.

#### List Processes

```bash
curl -L https://openeo.${INGRESS_HOST}/openeo/1.2/processes | jq .
```

_Expected output:_ A JSON object with an array of processes. Use your terminal’s scroll or `jq` to inspect the output.

#### Validate Aggregator Response

```bash
curl -L https://openeofed.${INGRESS_HOST}/openeo/ | jq .
```

_Expected output:_ A JSON response including federation details and links, confirming that the aggregator is aware of multiple back-ends.

### 3. Usage

If your deployment includes sample processes and supports job submissions, you can test job execution as follows:

#### 1. Submit a Job Using the "add" Process

Submit a job that adds 5 and 2.5 by sending a process graph to the `/jobs` endpoint:

```bash
curl -X POST "https://openeofed.${INGRESS_HOST}/openeo/1.2/jobs" \
  -H "Content-Type: application/json" \
  -d '{
        "process_graph": {
          "sum": {
            "process_id": "add",
            "arguments": {
              "x": 5,
              "y": 2.5
            },
            "result": true
          }
        }
      }' | jq .
```

The response should include a `job_id` (e.g., `"job_id": "12345"`) along with other job details.

#### 2. Monitor the Job Status

Replace `<JOB_ID>` with the actual job ID from the previous step and run:

```bash
curl -X GET "https://openeo.${INGRESS_HOST}/openeo/1.2/jobs/<JOB_ID>" | jq .
```

Check that the job’s status changes from `submitted` to `running` and eventually to `successful`.

#### 3. Retrieve the Job Result

Once the job has completed, retrieve the output:

```bash
curl -X GET "https://openeo.${INGRESS_HOST}/openeo/1.2/jobs/<JOB_ID>/results" | jq .
```

**Expected output:**  
A simple numeric result:

```json
7.5
```

This confirms that the "add" process is operational and returning the correct computed sum.

---

## Further Reading & Official Docs

- [openEO Documentation](https://open-eo.github.io/openeo-api/)
- [openEO Geotrellis GitHub Repository](https://github.com/Open-EO/openeo-geotrellis-kubernetes)
- [openEO Aggregator Documentation](https://open-eo.github.io/openeo-aggregator/)
- [EOEPCA+ Documentation](https://eoepca.readthedocs.io/)
