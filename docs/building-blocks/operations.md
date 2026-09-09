# Operations Deployment Guide

The **Operations** Building Block is the observability stack for an EOEPCA deployment. It gives operators a single place to see what the cluster is doing: metrics, logs, dashboards, and alerts, with optional Keycloak SSO in front of the UIs. This guide walks through deploying it on a Kubernetes cluster.

---

## Introduction

Operations deploys:

- **Prometheus** scrapes cluster metrics and workloads selected by scrape configuration
- **Loki** stores container logs, with **Alloy** collecting them from every node
- **Grafana** is the UI for both, with a set of cluster dashboards loaded out the box
- **Alertmanager** routes firing alerts to **Keep**, which is where operators triage and acknowledge them

Everything is declarative. Alert rules are `PrometheusRule` CRDs, dashboards are ConfigMaps, scrape targets are `ServiceMonitor` CRDs — so new components added to the cluster get picked up without touching Prometheus config.

---

## Components Overview

The Operations BB deploys the following:

1. **kube-prometheus-stack** — the core metrics platform:

- **Prometheus** — scrapes and stores metrics (30-day retention by default)
- **Alertmanager** — groups, deduplicates, and routes alerts
- **Grafana** — UI for metrics and logs, with Prometheus and Loki wired in as datasources
- **prometheus-operator** — manages the `ServiceMonitor`, `PodMonitor`, `PrometheusRule`, and `AlertmanagerConfig` CRDs that everything else in the stack uses
- **node-exporter** — per-node CPU, memory, disk, and network metrics
- **kube-state-metrics** — Kubernetes object state (pod phases, deployment replicas, etc)

2. **Loki**

Log database running in SingleBinary mode. Chunks live in S3-compatible object storage (MinIO in a typical EOEPCA deployment). The built-in compactor enforces retention.

3. **Grafana Alloy**

Log collector. Runs as a DaemonSet, reads pod logs through the Kubernetes API, adds pod and namespace labels, and sends them to Loki.

4. **Keep**

Alert management UI — triage, acknowledgement, grouping. Deployed as three services: backend, frontend, and websocket.

5. **oauth2-proxy**

Sits in front of Keep and handles the OIDC flow with Keycloak. Keep's OSS edition doesn't speak OIDC, so oauth2-proxy authenticates the user and forwards identity to Keep via `X-Forwarded-Email` and `X-Forwarded-Groups` headers.

6. **Alertmanager relay**

Small nginx proxy between Alertmanager and Keep. It forwards webhooks directly to the Keep backend, adding the service identity headers when IAM is enabled or an API-key header in unauthenticated mode.

7. **Alert rules and dashboards**

Baseline `PrometheusRule` resources covering pipeline health, node conditions, workloads, and storage. Five curated Grafana dashboards (cluster, node, pod, Prometheus overview, STAC SLO) shipped as labelled ConfigMaps — Grafana's sidecar picks them up automatically. The STAC SLO dashboard's panels stay empty until the STAC alert recording rules are enabled and Data Access is producing the underlying metrics.

8. **Optional components:**

- **STAC alerts** — EO-specific SLO rules and recording rules for STAC API latency, feeding the STAC SLO dashboard. Only useful if the Data Access BB is deployed with the APISIX prometheus plugin enabled.
- **IAM integration** — Keycloak clients and roles for Grafana and Keep SSO. Both Grafana and Keep validate the OIDC flow themselves (Grafana's built-in `auth.generic_oauth`, Keep via its own `oauth2-proxy` sidecar Service) rather than relying on an ingress-layer auth plugin, so IAM works the same way under APISIX or NGINX.

---

## Prerequisites

Before deploying the Operations Building Block, ensure you have the following:

| Component          | Requirement                                      | Documentation Link                                                |
| ------------------ | ------------------------------------------------ | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.32)                        | [Installation Guide](../prerequisites/kubernetes.md)              |
| Helm               | Version 3.5 or newer                             | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access                    | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| Ingress Controller | Properly installed (NGINX or APISIX)             | [Installation Guide](../prerequisites/ingress/overview.md)        |
| TLS Certificates   | Managed via `cert-manager` or manually           | [TLS Certificate Management Guide](../prerequisites/tls.md)       |
| Object Store       | S3-compatible store with a dedicated logs bucket | [MinIO Deployment Guide](../prerequisites/minio.md)               |

**Optional Prerequisites (for advanced features):**

| Component                | Requirement                    | Required For                          |
| ------------------------ | ------------------------------ | ------------------------------------- |
| Keycloak                 | For IAM integration            | Grafana and Keep single sign-on       |
| Data Access BB with STAC | For EO-specific alerts         | STAC latency SLO rules                |

**Clone the Deployment Guide Repository:**
```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/operations
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:
```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script

The configuration script prompts for necessary configuration values, generates configuration files, and prepares for deployment.
```bash
bash configure-operations.sh
```

First time running a script? [EOEPCA+ State](../prerequisites/state.md) covers the shared setup questions asked before this one.

**Core Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`PROMETHEUS_STORAGE_SIZE`**: Storage size for Prometheus TSDB
    - _Default_: `50Gi`
- **`PROMETHEUS_RETENTION`**: Metrics retention period
    - _Default_: `30d`
- **`S3_HOST`**: Host URL for MinIO or S3-compatible storage
    - _Example_: `minio.example.com`
- **`S3_BUCKET`**: Bucket name for Loki chunk storage
    - _Example_: `logging`
- **`S3_ACCESS_KEY`**: Access key for S3 storage
- **`S3_SECRET_KEY`**: Secret key for S3 storage
- **`LOKI_RETENTION_HOURS`**: Log retention period in hours
    - _Default_: `168` (7 days)

**Advanced Configuration Options**

- **`OPERATIONS_ENABLE_IAM`**: Enable Keycloak integration (yes/no)

=== "Without IAM (default)"

    Grafana uses local admin auth and Keep runs unauthenticated - see [Authentication](#authentication) below.

=== "With IAM"

    You'll be prompted for:

    - **`KEYCLOAK_HOST`**: Keycloak service hostname
    - **`REALM`**: Keycloak realm name (default: `eoepca`)
    - **`GRAFANA_CLIENT_ID`**: OIDC client ID for Grafana (default: `monitoring`)
    - **`KEEP_CLIENT_ID`**: OIDC client ID for Keep (default: `alerting`)

- **`OPERATIONS_ENABLE_STAC_ALERTS`**: Deploy STAC-specific SLO alerts (yes/no)
    - Only applicable if Data Access BB is deployed with APISIX prometheus plugin enabled

**Example Prometheus Values Override:**

If you need to customise Prometheus resource limits or scrape intervals beyond the defaults, edit the generated `kube-prometheus-stack/generated-values.yaml` before deploying. See the [kube-prometheus-stack values reference](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) for the full schema.

### 2. Apply Secrets

Applies the Loki S3 credentials, the oauth2-proxy cookie secret, and (if IAM is enabled) the Keycloak client secrets generated during configuration.

```bash
bash apply-secrets.sh
```

### 3. Deployment

#### Deploy kube-prometheus-stack

The core monitoring stack is deployed first so that its CRDs (`ServiceMonitor`, `PodMonitor`, `PrometheusRule`, `AlertmanagerConfig`) are available for subsequent components. The values enable the recording rules used by the curated dashboards; baseline alert rules are applied separately.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
helm upgrade -i kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --version 83.1.0 \
  --namespace operations \
  --create-namespace \
  --values kube-prometheus-stack/generated-values.yaml \
  --wait
```

#### Deploy Loki

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update grafana
helm upgrade -i loki grafana/loki \
  --version 6.55.0 \
  --namespace operations \
  --values loki/generated-values.yaml \
  --wait
```

#### Deploy Alloy

Apply the Alloy manifests, which configure pod log collection through the Kubernetes API and delivery to Loki.

```bash
kubectl apply -k alloy/
```

#### Deploy Keep and oauth2-proxy

The generated values pin Keep's MySQL image to `26.7.0`, matching the upstream deployment.

=== "Without IAM (default)"

    ```bash
    source ~/.eoepca/state
    helm repo add keephq https://keephq.github.io/helm-charts
    helm repo update keephq

    helm upgrade -i keep keephq/keep \
      --version 0.1.95 \
      --namespace operations \
      --values keep/generated-values.yaml \
      --wait
    ```

=== "With IAM"

    ```bash
    source ~/.eoepca/state
    helm repo add keephq https://keephq.github.io/helm-charts
    helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
    helm repo update keephq oauth2-proxy

    helm upgrade -i keep keephq/keep \
      --version 0.1.95 \
      --namespace operations \
      --values keep/generated-values.yaml \
      --wait

    helm upgrade -i keep-oauth2-proxy oauth2-proxy/oauth2-proxy \
      --version 10.4.2 \
      --namespace operations \
      --values keep/generated-oauth2-proxy-values.yaml \
      --wait
    ```

#### Apply Alerting Configuration

Deploys the Alertmanager-to-Keep relay, the `AlertmanagerConfig` routing rules, and the baseline PrometheusRules.

```bash
kubectl apply -f alerting/generated-keep-alertmanager-relay.yaml
kubectl apply -f alerting/generated-alertmanagerconfig.yaml
kubectl apply -f rules/baseline-alerts.yaml

if [ "${OPERATIONS_ENABLE_STAC_ALERTS}" = "yes" ]; then
  kubectl apply -f rules/stac-alerts.yaml
fi
```

#### Apply Grafana Dashboards

Dashboards are delivered as labelled ConfigMaps which Grafana's sidecar discovers and loads automatically.

```bash
kubectl apply -k dashboards/
```

#### Configure Ingress/Routes

=== "Without IAM (default)"

    Apply the ingress resources (rendered for whichever `INGRESS_CLASS` was configured):

    ```bash
    source ~/.eoepca/state
    kubectl apply -f ingress/generated-monitoring-ingress.yaml
    kubectl apply -f ingress/generated-alerting-ingress.yaml
    ```

=== "With IAM"

    Keycloak needs to be configured with the `monitoring` and `alerting` clients and their associated roles, then apply the ingress resources (rendered for whichever `INGRESS_CLASS` was configured):

    ```bash
    source ~/.eoepca/state
    kubectl apply -f iam/generated-iam.yaml
    kubectl apply -f ingress/generated-monitoring-ingress.yaml
    kubectl apply -f ingress/generated-alerting-ingress.yaml
    ```

---

### 4. Monitoring the Deployment

After deploying, monitor the status:
```bash
kubectl get all -n operations
```

Run validation:
```bash
bash validation.sh
```

---

### 5. Accessing the Operations Services

Once deployment is complete:

**Core Services:**

- **Grafana:** `https://monitoring.${INGRESS_HOST}/`
- **Keep:** `https://alerting.${INGRESS_HOST}/`

Prometheus and Alertmanager are not exposed externally by default. They are reachable through Grafana as a datasource, or within the cluster via the `kube-prometheus-stack-prometheus` and `kube-prometheus-stack-alertmanager` services in the `operations` namespace.

#### Authentication

=== "Without IAM (default)"

    Grafana uses local admin auth. Retrieve the chart-generated credentials with:

    ```bash
    kubectl -n operations get secret kube-prometheus-stack-grafana \
      -o jsonpath='{.data.admin-user}' | base64 -d; echo

    kubectl -n operations get secret kube-prometheus-stack-grafana \
      -o jsonpath='{.data.admin-password}' | base64 -d; echo
    ```

    Keep runs with `AUTH_TYPE=NO_AUTH` and is unauthenticated. API requests still require an `X-API-KEY` header, but its value is not checked.

=== "With IAM"

    Both UIs are fronted by Keycloak. Users must be assigned one of `grafana_admin`, `grafana_editor`, or `grafana_viewer` on the `monitoring` client to access Grafana, and one of `keep_admin` or `keep_noc` on the `alerting` client to access Keep. `KEYCLOAK_TEST_ADMIN` gets admin on both automatically via `iam/generated-iam.yaml`; grant other users by adding them to the `monitoring-admin`/`alerting-admin` Keycloak groups (or assigning roles directly).

---

## Testing and Validation

These checks cover log collection into Loki, metrics in Grafana, and an alert passing from Prometheus through Alertmanager to Keep and resolving. The temporary alert tests delivery without interrupting an application.

### 1. Verify Grafana Datasources

Log in to Grafana and confirm both datasources are configured:

- **Prometheus** (default)
- **Loki**

Navigate to `Connections → Data sources` and test each one.

### 2. Explore Logs

Open **Explore** in Grafana, select the **Loki** datasource and **Code** mode, then run:

```logql
{namespace="operations"}
```

You should see log lines from the Operations BB components, collected by Alloy. Allow up to a minute for logs to arrive, then rerun the query if the result is empty.

### 3. Load a Curated Dashboard

Open **Dashboards → Kubernetes / Cluster View**. CPU and memory panels should show live cluster metrics. CPU rates need several scrapes before they appear; CPU limit panels can be empty when workloads have no limits.

### 4. Verify Alert Delivery

The baseline rules include a `Watchdog` alert which fires continuously as a pipeline health check. Verify it reaches Keep:

=== "Without IAM (default)"

    ```bash
    source ~/.eoepca/state
    curl -sS "${HTTP_SCHEME}://alerting.${INGRESS_HOST}/v2/alerts" \
      -H "Accept: application/json" -H "X-API-KEY: anything" | jq
    ```

=== "With IAM"

    `/v2/*` is behind oauth2-proxy, so an unauthenticated request to that URL returns `401`. Confirm delivery via the backend's logs instead:

    ```bash
    kubectl -n operations logs deploy/keep-backend --tail=50 | grep Watchdog
    ```

You can also log in to the Keep UI and confirm the `Watchdog` alert appears in the alerts view.

### 5. Verify Alertmanager Routing

Check Alertmanager's configuration has loaded the Keep receiver:

```bash
kubectl -n operations exec -it alertmanager-kube-prometheus-stack-alertmanager-0 -- \
  wget -qO- http://localhost:9093/api/v2/status | jq -r .config.original
```

### 6. Verify Firing and Resolution

Create a temporary rule to test alert delivery without interrupting a service:

```bash
cat > operations-test-alert.yaml <<'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: operations-test
  namespace: operations
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    - name: operations-test
      rules:
        - alert: OperationsTestAlert
          expr: vector(1)
          labels:
            severity: warning
          annotations:
            summary: Operations alert delivery test.
EOF
kubectl apply -f operations-test-alert.yaml
```

In Grafana **Explore**, select **Prometheus** and **Code** mode, set **Options → Type** to **Instant** and query:

```promql
ALERTS{alertname="OperationsTestAlert"}
```

Allow up to two minutes for rule discovery, evaluation and delivery. The `alertstate` label should be `firing`. Open Keep **Alerts → Feed** and find `OperationsTestAlert`. Inspect its summary and severity to confirm that the rule reached Keep through Alertmanager.

Leave the test alert unacknowledged so Keep displays the source status directly. A manual acknowledgement overrides that status even after the source resolves.

=== "Without IAM (default)"

    You can also inspect delivery through the API. Fetch the alerts and display the full response:

    ```bash
    source ~/.eoepca/state
    ALERTS_RESPONSE=$(curl -sS "${HTTP_SCHEME}://alerting.${INGRESS_HOST}/v2/alerts" \
      -H 'X-API-KEY: anything')
    printf '%s\n' "$ALERTS_RESPONSE" | jq
    ```

    Show just the names, statuses and recovery fields:

    ```bash
    printf '%s\n' "$ALERTS_RESPONSE" | jq '.[] | {name, status, endsAt, unresolvedCounter}'
    ```

    Find `OperationsTestAlert` with `status: firing` and `unresolvedCounter: 1`. If it has not arrived, wait about 30 seconds and rerun the request and short view. The short view reads the saved response; it does not fetch new data.

=== "With IAM"

    Use the authenticated Keep **Alerts -> Feed** view to inspect `OperationsTestAlert`. The API commands above are for unauthenticated deployments only.

Remove the test rule:

```bash
kubectl delete -f operations-test-alert.yaml
```

Repeat the Grafana query; it should return no series. Allow up to five minutes for Alertmanager to expire the removed alert, then refresh Keep and confirm the alert is `resolved`. In unauthenticated mode, rerun the API request and short view above: `OperationsTestAlert` should have `status: resolved`, a recovery time in `endsAt` and `unresolvedCounter: 0`.

Its history remains available for inspection. Leave `Watchdog` firing as the continuous pipeline check.

---

## Uninstallation

To uninstall the Operations Building Block:

```bash
source ~/.eoepca/state

if [ "${OPERATIONS_ENABLE_IAM:-no}" = "yes" ]; then
  kubectl delete -f iam/generated-iam.yaml --ignore-not-found
fi

helm uninstall keep-oauth2-proxy -n operations
helm uninstall keep -n operations
helm uninstall loki -n operations
helm uninstall kube-prometheus-stack -n operations

kubectl delete -k alloy/
kubectl delete -k dashboards/
kubectl delete -f rules/ --ignore-not-found
kubectl delete -f alerting/generated-keep-alertmanager-relay.yaml --ignore-not-found
kubectl delete -f alerting/generated-alertmanagerconfig.yaml --ignore-not-found

kubectl delete namespace operations
```

!!! note
    Deleting the namespace removes all remaining ConfigMaps, Secrets, and PVCs. If Prometheus was deployed with a persistent volume, the underlying PV may need to be deleted separately depending on the storage class's reclaim policy.

---

## Further Reading

- [kube-prometheus-stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Keep Documentation](https://docs.keephq.dev/)
- [oauth2-proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Prometheus Operator CRDs](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api-reference/api.md)