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
| Kubernetes                  | Cluster (tested on v1.28)               | [Installation Guide](../prerequisites/kubernetes.md) |
| Git                         | Properly installed                      | [Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) |
| Helm                        | Version 3.5 or newer                    | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| Helm plugins                | `helm-git`: Version 1.3.0 tested        | [Installation Guide](https://github.com/aslafy-z/helm-git?tab=readme-ov-file#install) |
| kubectl                     | Configured for cluster access           | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| Ingress Controller          | Properly installed (e.g., NGINX)        | [Installation Guide](../prerequisites/ingress-controller.md)      |
| Internal TLS Certificates   | ClusterIssuer for internal certificates | [Internal TLS Setup](../prerequisites/tls.md#internal-tls) |

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

**Important Note:** Ensure that you have internal TLS setup. Please refer to the [Internal TLS Deployment Guide](../prerequisites/tls.md#internal-tls) for more information. 

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

4. **Check creation of Certificates for Internal TLS:**

      ```bash
      kubectl -n resource-health get certificate
      ```

      Confirm that all `Certificates` are marked `Ready`.

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


## Usage

The Resource Health Building Block (BB) is designed to be flexible and can operate without publicly exposed endpoints by default. This ensures that, initially, only cluster operators with `kubectl` access can view and test resource health checks. Later, you can integrate authentication and external access as needed.

### 1. Accessing the Resource Health Web Interface

By default, the Resource Health web interface is internal-only, so you must use `kubectl port-forward` to access it locally:

```bash
kubectl -n resource-health port-forward service/resource-health-web 8080:80
```

Once port-forwarding is active, open your browser at:

- [http://127.0.0.1:8080/](http://127.0.0.1:8080/) to see a list of recent health check outcomes.
- [http://127.0.0.1:8080/checks](http://127.0.0.1:8080/checks) to see a list of defined health checks.

If the pages load and you see the default or sample checks, your deployment is running correctly.

### 2. Defining and Scheduling Health Checks

Health checks are defined via Helm values. When you deployed the Resource Health BB, a `generated-values.yaml` file was created. You can add or modify health checks in that file under `healthchecks.checks`. For example:

```yaml
healthchecks:
  checks:
  - name: daily-trivial-check
    image:
      repository: docker.io/eoepca/healthcheck_runner
      pullPolicy: IfNotPresent
      tag: "v0.1.0-demo"
    # Runs every day at 08:00
    schedule: "0 8 * * *"
    requirements: "https://example.com/requirements.txt"
    script: "https://example.com/trivial_check.py"
    userid: bob
    env:
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: https://opentelemetry-collector:4317
```

**Key Fields**:

- **`name`**: Unique identifier for the health check.
- **`schedule`**: Cron expression for when to run the check.
- **`requirements`** & **`script`**: URLs from which to fetch additional Python dependencies and the test script.
- **`userid`**: Logical identifier of who owns the check (if applicable).

After updating `generated-values.yaml`, apply changes with:

```bash
helm upgrade resource-health resource-health/resource-health-reference-deployment \
  --namespace resource-health \
  --values generated-values.yaml
```

Check the `/checks` page again (via port-forward) to confirm that your new health check appears.

### 3. Verifying Health Check Execution

Once defined and scheduled, the health checks run at the configured times. You can verify this by:

- Visiting the main page ([http://127.0.0.1:8080/](http://127.0.0.1:8080/) after port-forwarding) to see recent outcomes.
- Confirming that a scheduled check appears in the outcomes list after its run time.

If the check fails or finds issues, it will report that within the outcome details. Successes and failures are both recorded as OpenTelemetry traces.

### 4. Exploring Data in OpenSearch Dashboards

The Resource Health BB uses OpenSearch to store health check telemetry. To access it directly:

1. Forward OpenSearch Dashboards:

```bash
kubectl -n resource-health port-forward service/resource-health-opensearch-dashboards 5601:5601
```

2. Open [http://127.0.0.1:5601](http://127.0.0.1:5601) in your browser.

**Note**: On some clusters, OpenSearch Dashboards may use HTTPS with a self-signed certificate. Be prepared to bypass browser warnings for self-signed certs.

In the Dashboards interface, you can:

- Search for indices containing health check data.
- Visualise traces, errors, and performance metrics.
- Explore root causes of failing checks by viewing logs and traces in detail.

### 5. Running Ad-Hoc Checks (Optional)

If you need to run a health check manually (ad-hoc):

- Adjust the health check’s schedule to a known upcoming minute or run a one-off job by temporarily setting a schedule for a near-future time.
- Reapply the Helm upgrade command.
- Wait for the check to run and then refresh the web interface or OpenSearch Dashboards to see the results.

### 6. Removing or Updating Health Checks

To remove or change a health check:

- Edit the corresponding entry in `generated-values.yaml`.
- Remove it or adjust its `schedule`, `script`, and other parameters.
- Run the Helm upgrade command again. Removed checks will no longer run, and updated checks will take on new schedules or scripts.

### 7. Authentication and Integration

Currently, the Resource Health BB may be running without public ingress or authentication. In a production environment, you would:

- Integrate with your IAM Building Block to secure access via OIDC/OAuth2.
- Provide ingress configurations to allow authorized external access.
- Set up alerts or notifications in OpenSearch for critical failures.

(Refer to the [Advanced Configuration and IAM docs](../iam/advanced-configuration.md) for guidance on authenticating and authorizing users or integrating into a broader EOEPCA ecosystem.)

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



