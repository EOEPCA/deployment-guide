# Notification and Automation Deployment Guide

The Notification and Automation Building Block gives the EOEPCA platform an event-driven workflow layer. It uses Knative Eventing for routing CloudEvents between sources and sinks, ships with a few ready-made components (a GitHub webhook source, a CloudEvents player for inspecting traffic, and an emailer sink), and lets you deploy your own event-driven functions on Knative Serving on top. Kafka can be added on top if you want a durable event backbone, but the default setup uses Knative's in-memory channel and works fine for most cases.

This guide walks through deploying the whole stack on a Kubernetes cluster.

## Components

- **Knative Operator** installed separately via Helm, ahead of the BB chart — reconciles the `KnativeServing`/`KnativeEventing` custom resources into an actual control plane
- **Knative Serving** for deploying your own serverless functions on top (see [Writing automations](#writing-automations))
- **Knative Eventing** for event routing and delivery
- **Kourier** as the cluster-internal ingress for Knative services (enabled via the Knative Serving CR, not installed separately)
- **GitHub webhook source** that turns inbound webhooks into CloudEvents
- **API Server Source** that turns Kubernetes API events into CloudEvents
- **CloudEvents player** for inspecting events flowing through a broker
- **Emailer sink** that sends an email when it receives a CloudEvent
- **Kafka** (optional) via Strimzi, for persistent event streaming

The BB Helm chart itself (`notification-automation`) only creates the webhook source, API server source, CloudEvents player, emailer, and default broker as plain Deployments — it does **not** install the Knative Operator or the `KnativeServing`/`KnativeEventing` instances. Those are separate, mandatory steps below.

The webhook source and API server source both send their CloudEvents into a chart-provisioned `default` broker, and the CloudEvents player is subscribed to that broker with no filter — so events from both are visible there with no extra wiring (see [Send a GitHub webhook](#send-a-github-webhook)).

## Prerequisites

| Component    | Requirement                   | Documentation                                                  |
|--------------|-------------------------------|----------------------------------------------------------------|
| Kubernetes   | Cluster (tested on v1.32)     | [Installation Guide](../prerequisites/kubernetes.md)           |
| Helm         | Version 3.5 or newer          | [Installation Guide](https://helm.sh/docs/intro/install/)      |
| kubectl      | Configured for cluster access | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)  |
| Ingress      | APISIX installed              | [Installation Guide](../prerequisites/ingress/overview.md)     |
| Cert Manager | Installed and working         | [Installation Guide](../prerequisites/tls.md)                  |
| DNS-01 ClusterIssuer | Required for wildcard TLS on Knative services | — |


A note on ingress: only APISIX is wired up by the templates in this BB. NGINX is on the roadmap but not supported yet. The configure script exits early if `INGRESS_CLASS` is set to anything other than `apisix`.

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

First time running a script? [EOEPCA+ State](../prerequisites/state.md) covers the shared setup questions asked before this one.

You'll be asked for, in order:

- `DNS_CLUSTER_ISSUER`: cert-manager ClusterIssuer supporting DNS-01, needed for wildcard TLS on Knative services (e.g. `letsencrypt-dns01`)
- `NA_ENABLE_OIDC`: whether to turn on Knative Eventing's own OIDC token authentication between eventing resources (defaults to no — this is unrelated to the IAM Building Block)
- `NA_ENABLE_EMAILER`: whether to deploy the emailer sink (defaults to no)
    - if yes: `NA_EMAIL_FROM`, `NA_EMAIL_TO`, `NA_SMTP_HOST`, `NA_SMTP_PORT`, `NA_SMTP_USER`, `NA_SMTP_PASSWORD`, `NA_SMTP_STARTTLS`
- `NA_ENABLE_KAFKA`: whether to deploy a Kafka cluster (defaults to no)
    - if yes: `NA_KAFKA_REPLICAS`, `NA_KAFKA_VOLUME_SIZE`, `NA_KAFKA_VERSION`

The script generates a random GitHub webhook secret and stores it in `~/.eoepca/state`. Keep that file safe, you will need the secret when registering webhooks against GitHub.

### 2. Install the Knative Operator

The BB chart does not install the Knative Operator or manage the `KnativeServing`/`KnativeEventing` custom resources — install it first, separately:

```bash
helm repo add knative-operator https://knative.github.io/operator
helm repo update knative-operator

helm upgrade -i knative-operator knative-operator/knative-operator \
  --namespace knative-operator \
  --create-namespace \
  --version v1.19.6 \
  --wait
```

### 3. Apply the Knative Serving and Eventing instances

```bash
kubectl apply -f generated-knative.yaml

kubectl wait --for=condition=Ready knativeserving/knative-serving -n knative-serving --timeout=300s
kubectl wait --for=condition=Ready knativeeventing/knative-eventing -n knative-eventing --timeout=300s
```

This creates the `knative-serving`/`knative-eventing`/`notifications` namespaces and the `KnativeServing`/`KnativeEventing` custom resources the operator reconciles. Give it a couple of minutes on a fresh cluster while it pulls the component images.

### 4. Apply the wildcard ingress route for Knative Functions

```bash
kubectl apply -f generated-apisix-route.yaml
```

This route is only for **Knative Services you deploy yourself** on top of the BB (see [Writing automations](#writing-automations) below). If you enabled HTTPS, it also creates the wildcard Certificate and ApisixTls resources; give cert-manager a minute or two to issue it.

### 5. Install the BB chart

The chart deploys the GitHub webhook source, the API server source, the CloudEvents player, the default broker and (if enabled) the emailer. The webhook source and CloudEvents player each get their own `Ingress` with a cert-manager-issued certificate.

```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev/
helm repo update eoepca-dev

helm upgrade -i notification-automation eoepca-dev/notification-automation \
  --namespace notifications \
  --create-namespace \
  -f generated-na-values.yaml \
  --wait
```

Once it's up:

```bash
source ~/.eoepca/state
curl https://cloudevents-player.notifications.${INGRESS_HOST}
curl https://webhooks.notifications.${INGRESS_HOST}/health
```

The CloudEvents player should return its web UI, and `/health` on the webhook source should return `200`.

### 6. Optional: Deploy Kafka

!!! note
    Skip this section unless you opted into Kafka during configuration.

Kafka requires the Strimzi operator, which the BB chart does not bundle:

```bash
helm repo add strimzi https://strimzi.io/charts/
helm repo update strimzi

helm upgrade -i strimzi-cluster-operator strimzi/strimzi-kafka-operator \
  --namespace strimzi-system \
  --create-namespace \
  --version 1.1.0 \
  --set watchAnyNamespace=true \
  --wait
```

Then apply the cluster:

```bash
kubectl apply -f generated-kafka-cluster.yaml
```

```bash
kubectl describe kafka kafka-cluster -n notifications
```

Wiring Kafka in as the channel layer for Knative Eventing needs the Knative Kafka extension configured against this cluster. That is out of scope here, see the Knative Kafka docs in further reading.

### 7. Validate

```bash
bash validation.sh
```

## Usage

> **Prefer a notebook?** Run `../../notebooks/run.sh` and open the <a href="http://localhost:8888/lab/tree/notification-automation/notification-automation.ipynb" target="_blank">Notification and Automation notebook</a> at `http://localhost:8888`.

A few worked examples to confirm things are working end to end, and to show the main patterns for building automations on top of the BB.

### Deploy a simple function

This deploys the standard Knative `helloworld-go` sample as a public function. Useful for confirming routing and TLS work before adding anything more complicated.

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

Check it came up and hit it:

```bash
kubectl get ksvc -n notifications

source ~/.eoepca/state
curl https://hello-function.notifications.notifications.${INGRESS_HOST}
```

### Send a GitHub webhook

GitHub signs requests with `X-Hub-Signature-256: sha256=<hmac-sha256 of the body>`, using the secret from `configure-notification-automation.sh`:

```bash
source ~/.eoepca/state
PAYLOAD='{"repository": {"html_url": "https://github.com/EOEPCA/deployment-guide"}, "ref": "refs/heads/main"}'
SIGNATURE="sha256=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$NA_GITHUB_WEBHOOK_SECRET" | awk '{print $NF}')"

curl -X POST "https://webhooks.notifications.${INGRESS_HOST}/github" \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -H "X-Hub-Signature-256: $SIGNATURE" \
  -d "$PAYLOAD"
```

A `202` means it was forwarded to the `default` broker. Check it arrived:

```bash
curl -s "https://cloudevents-player.notifications.${INGRESS_HOST}/messages" | jq
```

Use the same URL (`https://webhooks.notifications.${INGRESS_HOST}/github`) and `NA_GITHUB_WEBHOOK_SECRET` when registering a real GitHub webhook.

### Create a broker

`default` (created by the BB chart) already carries webhook/API-server events - create your own broker when you want an isolated event space instead, e.g. so your triggers aren't matching unrelated platform events.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: eventing.knative.dev/v1
kind: Broker
metadata:
  name: primary
  namespace: notifications
EOF

kubectl get brokers -n notifications
```

We deliberately omit `spec.config`. Knative will use the cluster default channel (in-memory by default), which is enough for testing. For a durable broker, point it at a Kafka channel once Kafka is set up.

## Writing automations

??? note "Writing your own automation"

    You have two routes for the actual automation code:

    - **`func` CLI** - the Knative Functions tool. Gives you a boilerplate project with CloudEvents wiring already done, and handles the build-and-push step for you. Good for getting going quickly without thinking about containers.
    - **Plain Knative Serving** - write a FastAPI (or any HTTP) service, build the container yourself, deploy as a `Service`. More control, no extra framework to learn.

    Both end up as Knative Services and both work with the same triggers, brokers and sources. The walkthrough below uses `func`. If you go the FastAPI route, skip to the trigger section once your service is deployed.

    ### Install the func CLI

    Download from the [Knative Functions releases page](https://github.com/knative/func/releases) and put the binary on your `PATH`. On Linux amd64:

    ```bash
    curl -L -o /tmp/func https://github.com/knative/func/releases/latest/download/func_linux_amd64
    chmod +x /tmp/func
    sudo mv /tmp/func /usr/local/bin/func
    func version
    ```

    !!! note "Apple Silicon"
        Building functions locally on an M-series Mac produces ARM64 container images that won't run on an x86_64 cluster. Either build remotely (`func deploy --remote`) or use a build host that matches your cluster architecture.

    ### Create a function

    `func create` scaffolds a project from a template. For an event-driven automation, use the `cloudevents` template:

    ```bash
    func create -l python -t cloudevents demo-fn
    cd demo-fn
    ```

    The handler lives in `function/func.py` - an async `handle(scope, receive, send)` method on a `Function` class, plus a module-level `new()` that returns an instance. The scaffold also includes optional `start`, `stop`, `alive` and `ready` hooks. Delete what you don't need.

    ### Deploy it

    ```bash
    func deploy --registry docker.io/YOUR-REGISTRY --build --namespace notifications
    ```

    First build is slow - Buildpacks downloads layers. Subsequent builds are quick. When it finishes you have a Knative Service:

    ```bash
    kubectl get ksvc -n notifications
    ```

    By default each function gets a public endpoint. To make it cluster-local only, add the label `networking.knative.dev/visibility=cluster-local` to the service. Safer default for automations that should only respond to internal events.

    ### Wire it to events with a Trigger

    Triggers route events from a broker to a subscriber. This one only fires for events of type `org.eoepca.demo.hello`:

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: eventing.knative.dev/v1
    kind: Trigger
    metadata:
      name: demo-fn-hello
      namespace: notifications
    spec:
      broker: primary
      filter:
        attributes:
          type: org.eoepca.demo.hello
      subscriber:
        ref:
          apiVersion: serving.knative.dev/v1
          kind: Service
          name: demo-fn
    EOF
    ```

    Events with other types pass through this trigger untouched (other triggers can still match them).

    !!! warning "Avoid self-triggering loops"
        If your function emits a CloudEvent in response and the trigger has no filter, the response flows back through the broker, matches the trigger, fires the function again, ad infinitum. Either filter on `type` (as above) so the function's own response type doesn't match, or have the function return without sending a response.

    ### See it working

    Grab the broker's internal URL:

    ```bash
    BROKER_URL=$(kubectl get broker primary -n notifications -o jsonpath='{.status.address.url}')
    echo "$BROKER_URL"
    ```

    Post a CloudEvent. The `Ce-*` headers are how CloudEvents are encoded over HTTP in binary mode. The broker URL is cluster-internal, so we run curl from inside a pod:

    ```bash
    kubectl run curl-test --rm -i --tty --restart=Never --namespace=notifications \
      --image=curlimages/curl:latest -- \
      curl -v "$BROKER_URL" \
        -H "Ce-Id: test-1" \
        -H "Ce-Specversion: 1.0" \
        -H "Ce-Type: org.eoepca.demo.hello" \
        -H "Ce-Source: manual-test" \
        -H "Content-Type: application/json" \
        -d '{"message": "hello from the test"}'
    ```

    A `202 Accepted` means the broker took the event. The trigger forwards it to `demo-fn`, which Knative scales up from zero if needed.

    Tail the function logs:

    ```bash
    kubectl logs -n notifications -l serving.knative.dev/service=demo-fn -c user-container --tail=50 -f
    ```

    You should see one `Request Received` line per test event. If you see a flood of them, the function is looping on its own responses - delete the trigger, switch to a filtered one as above, or remove the response from `func.py`.

## Uninstallation

Tear down in the reverse order of installation, so nothing is left depending on a CRD or control plane that's already gone.

```bash
# Any Knative Services/Brokers/Triggers you created
kubectl delete ksvc,trigger,broker --all -n notifications 2>/dev/null || true

# If Kafka was deployed
kubectl delete -f generated-kafka-cluster.yaml 2>/dev/null || true
helm uninstall strimzi-cluster-operator -n strimzi-system 2>/dev/null || true

# BB chart and ingress route
helm uninstall notification-automation -n notifications 2>/dev/null || true
kubectl delete -f generated-apisix-route.yaml 2>/dev/null || true

kubectl delete -f generated-knative.yaml 2>/dev/null || true
kubectl wait --for=delete knativeserving/knative-serving -n knative-serving --timeout=120s 2>/dev/null || true
kubectl wait --for=delete knativeeventing/knative-eventing -n knative-eventing --timeout=120s 2>/dev/null || true

# Now the operator that reconciled them
helm uninstall knative-operator -n knative-operator 2>/dev/null || true

# Namespaces
kubectl delete namespace notifications knative-serving knative-eventing knative-operator 2>/dev/null || true
kubectl delete namespace strimzi-system 2>/dev/null || true
```


## Further Reading

- [EOEPCA Notification and Automation Documentation](https://eoepca.readthedocs.io/projects/notification-automation)
- [Knative Serving Documentation](https://knative.dev/docs/serving/)
- [Knative Eventing Documentation](https://knative.dev/docs/eventing/)
- [Knative Kafka Broker](https://knative.dev/docs/eventing/brokers/broker-types/kafka-broker/)
- [CloudEvents Specification](https://cloudevents.io/)
- [Strimzi Documentation](https://strimzi.io/documentation/)
