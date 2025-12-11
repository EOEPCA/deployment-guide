# Notification and Automation Deployment Guide

The **Notification and Automation** building block provides event-driven automation and serverless function capabilities for the EOEPCA ecosystem. It enables automated workflows, notifications, and reactive processing using Knative's serving and eventing components. The system supports scalable function deployment, event routing, and can integrate with message brokers like Kafka for complex event processing workflows.

This guide shows you step-by-step how to set up Notification and Automation in your Kubernetes cluster.

---

### Components

Notification and Automation includes the following components:

- **Knative Serving** - Manages serverless workload deployment and scaling
- **Knative Eventing** - Provides event routing and delivery infrastructure
- **Kourier** - Lightweight ingress for Knative services
- **Optional Kafka Integration** - For persistent event streaming (when enabled)

---

## Prerequisites

| Component        | Requirement                   | Documentation Link                                                      |
|------------------|-------------------------------|-------------------------------------------------------------------------|
| Kubernetes       | Cluster (tested on v1.32)     | [Installation Guide](../prerequisites/kubernetes.md)                   |
| Helm             | Version 3.5 or newer          | [Installation Guide](https://helm.sh/docs/intro/install/)             |
| kubectl          | Configured for cluster access | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)         |
| Ingress          | Properly installed            | [Installation Guide](../prerequisites/ingress/overview.md)            |
| Cert Manager     | Properly installed            | [Installation Guide](../prerequisites/tls.md)                        |

**Clone the Deployment Guide Repository:**
```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/notification-automation
```

**Validate your environment:**
```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script
```bash
bash configure-notification-automation.sh
```

**Configuration Parameters**  
During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts  
    - *Example*: `example.com`
- **`CLUSTER_ISSUER`**: Cert-manager Cluster Issuer for TLS certificates  
    - *Example*: `letsencrypt-http01-apisix`

### 2. Install Knative Operator

The Knative Operator manages the lifecycle of Knative components:
```bash
helm repo add knative https://knative.github.io/operator
helm repo update knative

helm upgrade -i knative-operator knative/knative-operator \
  --version v1.19.5 \
  --namespace knative-operator \
  --create-namespace \
  --wait
```

### 3. Deploy Knative Components

Deploy the core Knative components using the generated configuration:
```bash
kubectl apply -f generated-knative.yaml
```

Wait for Knative components to be ready:
```bash
kubectl wait --for=condition=Ready knativeservings.operator.knative.dev knative-serving \
  --namespace knative-serving \
  --timeout=600s

kubectl wait --for=condition=Ready knativeeventings.operator.knative.dev knative-eventing \
  --namespace knative-eventing \
  --timeout=600s
```

### 4. Configure Ingress Routing

Deploy the APISIX route for Knative services:
```bash
kubectl apply -f generated-apisix-route.yaml
```

---

## Usage

Check that all Knative components are running:

```bash
kubectl get pods -n knative-serving
kubectl get pods -n knative-eventing
kubectl get pods -n kourier-system
```

Verify the Knative domain configuration:
```bash
kubectl get configmap config-domain -n knative-serving -o yaml
```

### Basic Usage Examples

#### 1. Deploy a Simple Function

Create a test Knative Service:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: hello-function
  namespace: notifications
spec:
  template:
    spec:
      containers:
      - image: gcr.io/knative-samples/helloworld-go
        env:
        - name: TARGET
          value: "EOEPCA Platform"
EOF
```

Apply and check the deployment:
```bash
kubectl get ksvc -n notifications
```

Access your function:
```bash
source ~/.eoepca/state
curl https://hello-function.notifications.notifications.${INGRESS_HOST}
```

> TODO: Below Not working.

#### 2. Create an Event Broker

Deploy a Knative Broker for event routing:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: eventing.knative.dev/v1
kind: Broker
metadata:
  name: primary
  namespace: default
spec:
  config:
    apiVersion: v1
    kind: ConfigMap
    name: default-broker-config
EOF
```

```bash
kubectl get brokers
```

#### 3. Event-Driven Processing Example

Create a function that processes CloudEvents:

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: event-processor
  namespace: notifications
spec:
  template:
    spec:
      containers:
      - image: your-registry/event-processor:latest
        env:
        - name: LOG_LEVEL
          value: "info"
---
apiVersion: eventing.knative.dev/v1
kind: Trigger
metadata:
  name: process-stac-events
  namespace: default
spec:
  broker: primary
  filter:
    attributes:
      type: org.eoapi.stac.item
  subscriber:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: event-processor
      namespace: notifications
```

---

## Uninstallation

To uninstall the Notification and Automation Building Block:

```bash
kubectl delete -f generated-apisix-route.yaml
kubectl delete -f generated-knative.yaml
helm uninstall knative-operator -n knative-operator

# Clean up namespaces
kubectl delete namespace knative-serving
kubectl delete namespace knative-eventing
kubectl delete namespace knative-operator
kubectl delete namespace notifications
kubectl delete namespace kourier-system
```

---

## Further Reading & Official Docs

- [EOEPCA Notification and Automation Documentation](https://eoepca.readthedocs.io/projects/notification-automation)
- [Knative Serving Documentation](https://knative.dev/docs/serving/)
- [Knative Eventing Documentation](https://knative.dev/docs/eventing/)
- [Knative Functions Documentation](https://knative.dev/docs/functions/)
- [CloudEvents Specification](https://cloudevents.io/)