# Notification and Automation Deployment Guide

The Notification and Automation Building Block gives the EOEPCA platform an event-driven workflow layer. It uses Knative Serving for serverless functions, Knative Eventing for routing CloudEvents between sources and sinks, and ships with a few ready-made components (a GitHub webhook source, a CloudEvents player for inspecting traffic, and an emailer sink). Kafka can be added on top if you want a durable event backbone, but the default setup uses Knative's in-memory channel and works fine for most cases.

This guide walks through deploying the whole stack on a Kubernetes cluster.

## Components

The BB deploys the following:

- **Knative Serving** for serverless workload deployment and autoscaling
- **Knative Eventing** for event routing and delivery
- **Kourier** as the cluster-internal ingress for Knative services (enabled via the Knative Serving CR, not installed separately)
- **GitHub webhook source** that turns inbound webhooks into CloudEvents
- **CloudEvents player** for inspecting events flowing through a broker
- **Emailer sink** that sends an email when it receives a CloudEvent
- **Kafka** (optional) via Strimzi, for persistent event streaming

## Prerequisites

| Component    | Requirement                   | Documentation                                                  |
|--------------|-------------------------------|----------------------------------------------------------------|
| Kubernetes   | Cluster (tested on v1.32)     | [Installation Guide](../prerequisites/kubernetes.md)           |
| Helm         | Version 3.5 or newer          | [Installation Guide](https://helm.sh/docs/intro/install/)      |
| kubectl      | Configured for cluster access | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)  |
| Ingress      | APISIX installed              | [Installation Guide](../prerequisites/ingress/overview.md)     |
| Cert Manager | Installed and working         | [Installation Guide](../prerequisites/tls.md)                  |

A note on ingress: only APISIX is wired up by the templates in this BB. NGINX is on the roadmap but not supported yet. The configure script will warn you if `INGRESS_CLASS` is set to anything other than `apisix`.

Clone the deployment guide repo and switch to this BB's directory:

```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/notification-automation
```

Validate your environment:

```bash
bash check-prerequisites.sh
```

## Deployment

### 1. Configure

```bash
bash configure-notification-automation.sh
```

You will be prompted for:

- `INGRESS_HOST`: base domain for ingress hosts (e.g. `example.com`)
- `CLUSTER_ISSUER`: cert-manager ClusterIssuer used for TLS (e.g. `letsencrypt-http01-apisix`)
- `NA_ENABLE_OIDC`: whether to turn on OIDC authentication for eventing resources (defaults to no)
- `NA_ENABLE_EMAILER`: whether to deploy the emailer sink (defaults to no)
- SMTP settings if the emailer is enabled
- `NA_ENABLE_KAFKA`: whether to deploy a Kafka cluster (defaults to no)

The script generates a random GitHub webhook secret and stores it in `~/.eoepca/state`. Keep that file safe, you will need the secret when registering webhooks against GitHub.

### 2. Apply secrets

```bash
bash apply-secrets.sh
```

Creates the SMTP credentials secret in the `notifications` namespace if the emailer is enabled. The webhook secret is handled by the BB Helm chart itself, so nothing needs to happen here for that.

### 3. Apply the ingress route

```bash
kubectl apply -f generated-apisix-route.yaml
```

This sets up the APISIX route that exposes Knative services through your cluster ingress. If you enabled HTTPS, it also creates the wildcard Certificate and ApisixTls resources. Give cert-manager a minute or two to issue the certificate before testing.

### 4. Install the BB chart

The chart bundles the Knative Operator, the Knative Serving and Eventing CRs, the GitHub webhook source, the CloudEvents player and the emailer. One install brings up the lot.

```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev/
helm repo update eoepca-dev

helm upgrade -i notification-automation eoepca-dev/notification-automation \
  --namespace notifications \
  --create-namespace \
  -f generated-na-values.yaml \
  --wait
```

The generated values set `serving.install: true` and `eventing.install: true` so the chart manages the Knative CRs alongside everything else. Do not run a separate `knative-operator` Helm install, the chart owns those CRDs and a separate install will conflict on ownership.

### 5. Optional: Deploy Kafka

Skip this section unless you opted into Kafka during configuration.

Kafka requires the Strimzi operator. The BB chart does not bundle it, so install it separately:

```bash
helm repo add strimzi https://strimzi.io/charts/
helm repo update strimzi

helm upgrade -i strimzi-cluster-operator strimzi/strimzi-kafka-operator \
  --namespace strimzi-system \
  --create-namespace \
  --set watchAnyNamespace=true \
  --wait
```

Then apply the cluster:

```bash
kubectl apply -f generated-kafka-cluster.yaml
kubectl wait --for=condition=Ready kafka/kafka-cluster -n notifications --timeout=600s
```

Wiring Kafka in as the channel layer for Knative Eventing needs the Knative Kafka extension configured against this cluster. That is out of scope here, see the Knative Kafka docs in further reading.

### 6. Validate

```bash
bash validation.sh
```

This checks Knative Serving, Knative Eventing, Kourier and the BB Helm release are all in a good state.

## Usage

A few worked examples to confirm things are working end to end.

### Deploy a simple function

This deploys the standard Knative `helloworld-go` sample as a public function. It is useful for confirming routing and TLS work before you add anything more complicated. Note this image is publicly accessible from `gcr.io` and will not work on clusters with image pull restrictions.

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

Check it came up:

```bash
kubectl get ksvc -n notifications
```

Hit it (note the double `notifications` in the host, that is Knative's `service.namespace.domain` pattern):

```bash
source ~/.eoepca/state
curl https://hello-function.notifications.notifications.${INGRESS_HOST}
```

### Create a broker

A broker is the entry point for events. Once it is up, sources can send events into it and triggers can route events out to subscribers.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: eventing.knative.dev/v1
kind: Broker
metadata:
  name: primary
  namespace: notifications
EOF
```

```bash
kubectl get brokers -n notifications
```

We deliberately omit `spec.config` here. Knative will use the cluster default channel (in-memory by default), which is enough for testing. If you want a durable broker, point it at a Kafka channel once you have Kafka set up.

### Event-driven processing

This deploys a function that consumes events and a trigger that wires it to the broker. Replace the image with your own to actually process anything useful.

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
  namespace: notifications
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

The trigger only forwards events with `type: org.eoapi.stac.item`. Other event types pass through untouched.

### Inspect events with the CloudEvents player

The chart deploys a CloudEvents player that subscribes to the broker and shows incoming events in a web UI. If you enabled HTTPS during configuration it is exposed at:

```
https://cloudevents-player.na.notifications.${INGRESS_HOST}
```

Useful for sanity checking your event sources without writing a custom subscriber.

## Uninstall

```bash
helm uninstall notification-automation -n notifications

kubectl delete -f generated-apisix-route.yaml
kubectl delete -f generated-knative.yaml

helm uninstall knative-operator -n knative-operator

# If you deployed Kafka
kubectl delete -f generated-kafka-cluster.yaml 2>/dev/null || true
helm uninstall strimzi-cluster-operator -n strimzi-system 2>/dev/null || true

# Namespaces
kubectl delete namespace notifications
kubectl delete namespace knative-serving
kubectl delete namespace knative-eventing
kubectl delete namespace knative-operator
kubectl delete namespace kourier-system
kubectl delete namespace strimzi-system 2>/dev/null || true
```

The Knative namespaces sometimes hang on deletion because of finalizers on the operator CRs. If that happens, delete the `KnativeServing` and `KnativeEventing` resources before deleting the namespaces, or remove the stuck finalizers manually.

## Further Reading

- [EOEPCA Notification and Automation Documentation](https://eoepca.readthedocs.io/projects/notification-automation)
- [Knative Serving Documentation](https://knative.dev/docs/serving/)
- [Knative Eventing Documentation](https://knative.dev/docs/eventing/)
- [Knative Kafka Broker](https://knative.dev/docs/eventing/brokers/broker-types/kafka-broker/)
- [CloudEvents Specification](https://cloudevents.io/)
- [Strimzi Documentation](https://strimzi.io/documentation/)