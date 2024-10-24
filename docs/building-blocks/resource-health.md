# Resource Health Deployment Guide

The **Resource Health** Building Block (BB) offers a generalized capability that allows users to specify and schedule health checks relating to their resources of interest, visualize the outcomes, and receive notifications according to the outcomes. This guide provides step-by-step instructions to deploy the Resource Health BB in your Kubernetes cluster using the simplified Helm approach.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Components Overview](#components-overview)
3. [Prerequisites](#prerequisites)
4. [Deployment Steps](#deployment-steps)
5. [Validation](#validation)
6. [Uninstallation](#uninstallation)
7. [Further Reading](#further-reading)
8. [Scripts and Manifests](#scripts-and-manifests)

---

## Introduction

The **Resource Health Building Block** allows users to:

- Specify and schedule health checks for resources.
- Observe check outcomes and receive notifications.
- Use a REST API, dashboard, or Git repository to specify checks.
- Visualise status and performance statistics through a dashboard.
- Access health check status via API for integration into portals.

This deployment guide provides instructions to deploy the Resource Health BB using a simplified Helm chart approach, consolidating previous complexities into a single Helm deployment.

---

## Components Overview

The Resource Health BB comprises the following key components:

1. **Resource Health Core**: The main component responsible for orchestrating health checks and collecting results.

2. **OpenSearch and OpenSearch Dashboards**: Used for storing and visualizing health check results.

3. **OpenTelemetry Collector**: Collects telemetry data from health checks and forwards it to OpenSearch.

4. **Health Check Runner**: Executes the specified health checks according to the defined schedule.

---

## Prerequisites

Before deploying the Resource Health Building Block, ensure you have the following:

| Component                   | Requirement                             | Documentation Link                                                |
| --------------------------- | --------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes                  | Cluster (tested on v1.23 or newer)      | [Installation Guide](../infra/kubernetes-cluster-and-networking.md)             |
| Helm                        | Version 3.5 or newer                    | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl                     | Configured for cluster access           | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| Ingress Controller          | Properly installed (e.g., NGINX)        | [Installation Guide](../infra/ingress-controller.md)      |
| TLS Certificates (Internal) | ClusterIssuer for internal certificates | [Internal TLS Setup](../infra/tls/internal-tls.md) |

**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/resource-health
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

1. **Run the Configuration Script:**

```bash
bash configure-resource-health.sh
```

**Important Note:**
- Ensure that you have internal TLS setup. Please refer to the [Internal TLS Deployment Guide]() 


2. **Deploy the Resource Health BB Using Helm:**

```bash
git clone https://github.com/EOEPCA/resource-health reference-repo

helm dependency build reference-repo/resource-health-reference-deployment

helm install resource-health reference-repo/resource-health-reference-deployment \
  --namespace resource-health \
  --create-namespace \
  --values generated-values.yaml
```

3. **Monitor the Deployment:**

   ```bash
   kubectl get all -n resource-health
   ```

4. **Access the Resource Health Services:**

   Since we haven't defined any Ingress resources in the `values.yaml`, you might need to set up Ingress separately if required. However, if the Helm chart includes default Ingress configurations, you can access the services as per those configurations.


---

## Validation

**Automated Validation:**

```bash
bash validation.sh
```

**Further Validation:**

1. **Check Kubernetes Resources:**

   ```bash
   kubectl get all -n resource-health
   ```

2. **Access Resource Health API:**

   Open a web browser and navigate to: `https://resource-health.${INGRESS_HOST}/`

3. **Access OpenSearch Dashboards:**

   Open a web browser and navigate to: `https://resource-health-opensearch-dashboards.${INGRESS_HOST}/`

4. **Test Resource Health Functionality:**

   - Create sample health checks using the provided examples or your own scripts.
   - Verify that health checks are executed according to the schedule.
   - View health check results in OpenSearch Dashboards.

---

## Uninstallation

To uninstall the Resource Health Building Block and clean up associated resources:

```bash
helm uninstall resource-health -n resource-health

kubectl delete namespace resource-health
```

---

## Further Reading

- [EOEPCA+Resource Health GitHub Repository](https://github.com/EOEPCA/resource-health)
- [EOEPCA+Helm Charts](https://eoepca.github.io/helm-charts)
- [OpenSearch Documentation](https://opensearch.org/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/)
- [EOEPCA+Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide)



