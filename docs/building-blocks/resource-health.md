# Resource Health Deployment Guide

The **Resource Health** BB provides a flexible framework that allows platform users and operators to monitor the health and status of resources offered through the platform. This includes core platform services, as well as resources (datasets, workflows, etc.) offered through those platform services.

---

## Introduction

The **Resource Health Building Block** allows users to:

- Specify and schedule health checks for resources.
- Observe check outcomes and receive notifications.
- Use a REST API, dashboard, or Git repository to specify checks.
- Visualise status and performance statistics through a dashboard.
- Access health check status via API for integration into portals.

---

## Components Overview

The Resource Health BB comprises the following key components:

1. **Resource Health Core**<br>
   The main component responsible for orchestrating health checks and collecting results.

2. **OpenSearch and OpenSearch Dashboards**<br>
   Used for storing and visualizing health check results.

3. **OpenTelemetry Collector**<br>
   Collects telemetry data from health checks and forwards it to OpenSearch.

4. **Health Check Runner**<br>
   Executes the specified health checks according to the defined schedule.

---

## Prerequisites

Before deploying the Resource Health Building Block, ensure you have the following:

| Component                   | Requirement                             | Documentation Link                                                |
| --------------------------- | --------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes                  | Cluster (tested on v1.28)               | [Installation Guide](../infra/kubernetes-cluster-and-networking.md) |
| Git                         | Properly installed                      | [Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) |
| Helm                        | Version 3.5 or newer                    | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| Helm plugins                | `helm-git`: Version 1.3.0 tested        | [Installation Guide](https://github.com/aslafy-z/helm-git?tab=readme-ov-file#install) |
| kubectl                     | Configured for cluster access           | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| Ingress Controller          | Properly installed (e.g., NGINX)        | [Installation Guide](../infra/ingress-controller.md)      |
| Internal TLS Certificates   | ClusterIssuer for internal certificates | [Internal TLS Setup](../infra/tls/internal-tls.md) |

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

**Important Note:** Ensure that you have internal TLS setup. Please refer to the [Internal TLS Deployment Guide](../infra/tls/internal-tls.md) for more information. 

---

## Deployment Steps

1. **Run the Configuration Script:**

```bash
bash configure-resource-health.sh
```

2. **Deploy the Resource Health BB Using Helm:**

```bash
helm repo add resource-health "git+https://github.com/EOEPCA/resource-health?ref=2.0-beta" && \
helm repo update resource-health && \
helm upgrade -i resource-health resource-health/resource-health-reference-deployment \
  --namespace resource-health \
  --create-namespace \
  --values generated-values.yaml
```

3. **Monitor the Deployment:**

```bash
kubectl get all -n resource-health
```

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

2. **Test Resource Health Functionality:**

   - Create sample health checks using the provided examples or your own scripts.
   - Verify that health checks are executed according to the schedule.
   - View health check results in OpenSearch Dashboards.

---

## Uninstallation

To uninstall the Resource Health Building Block and clean up associated resources:

```bash
helm uninstall resource-health -n resource-health && \
kubectl delete namespace resource-health
```

---

## Further Reading

- [EOEPCA+ Resource Health GitHub Repository](https://github.com/EOEPCA/resource-health)
- [EOEPCA+ Helm Charts](https://eoepca.github.io/helm-charts)
- [OpenSearch Documentation](https://opensearch.org/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/)
- [EOEPCA+Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide)



