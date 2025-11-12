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

# Usage

---

## Uninstallation

To uninstall the Notification and Automation Building Block:
```bash
TODO
```

---

## Further Reading & Official Docs

- [EOEPCA Notification and Automation Documentation](https://eoepca.readthedocs.io/projects/notification-automation)
- [Knative Serving Documentation](https://knative.dev/docs/serving/)
- [Knative Eventing Documentation](https://knative.dev/docs/eventing/)
- [Knative Functions Documentation](https://knative.dev/docs/functions/)
- [CloudEvents Specification](https://cloudevents.io/)