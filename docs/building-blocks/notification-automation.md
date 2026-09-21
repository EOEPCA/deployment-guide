# Notification and Automation Deployment Guide

Notification and Automation routes CloudEvents between event sources and subscribers using Knative Eventing. It includes a GitHub/GitLab webhook source, a Kubernetes API Server Source, a CloudEvents player and an optional emailer. Knative Serving runs custom event-driven functions.

The default broker uses an in-memory channel. Durable event storage requires a persistent broker or channel configuration; deploying Kafka alone does not change the broker.

## Components

- **Knative Operator**, installed separately with Helm, which manages the Knative Serving and Eventing instances
- **Knative Serving** for your own event-driven functions (see [Writing automations](#writing-automations))
- **Knative Eventing** for event routing and delivery
- **Kourier** as the cluster-internal ingress for Knative Services, enabled through the `KnativeServing` resource
- **Webhook source** that turns GitHub and GitLab webhooks into CloudEvents, with optional per-project secrets
- **API Server Source** that turns Kubernetes API events into CloudEvents
- **CloudEvents player** for inspecting events flowing through a broker
- **Emailer** that sends an email for each CloudEvent it receives
- **Kafka** (optional), deployed with Strimzi

The BB Helm chart (`notification-automation`) creates Deployments for the webhook source, CloudEvents player and optional emailer, plus an ApiServerSource, a Broker and their event-routing resources. It does not install Knative.

The webhook source and API Server Source send their events to the chart's `default` broker. The CloudEvents player subscribes to that broker without a filter, so events from both appear in the player.

## Prerequisites

| Component            | Requirement                                   | Documentation                                                 |
|----------------------|-----------------------------------------------|---------------------------------------------------------------|
| Kubernetes           | Cluster (tested on v1.34)                     | [Installation Guide](../prerequisites/kubernetes.md)          |
| Helm                 | Version 3.5 or newer                          | [Installation Guide](https://helm.sh/docs/intro/install/)     |
| kubectl              | Configured for cluster access                 | [Installation Guide](https://kubernetes.io/docs/tasks/tools/) |
| Ingress              | APISIX installed                              | [Installation Guide](../prerequisites/ingress/overview.md)    |
| Cert Manager         | Required when issuing TLS certificates        | [Installation Guide](../prerequisites/tls.md)                 |
| DNS-01 ClusterIssuer | Required for wildcard TLS on Knative services | —                                                             |

The supplied ingress templates require APISIX. The configure script rejects other values of `INGRESS_CLASS`.

Clone the deployment guide repo and switch to this BB's directory:

```bash
git clone --branch release-2.1 --depth 1 https://github.com/EOEPCA/deployment-guide.git
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
- `NA_ENABLE_OIDC`: whether to turn on Knative Eventing's own OIDC token authentication between eventing resources (defaults to no — this is unrelated to the IAM Building Block). Decide this before deploying; to change it later, uninstall and reinstall the BB
- `NA_ENABLE_EMAILER`: whether to deploy the emailer (defaults to no)
    - if yes: `NA_EMAIL_FROM`, `NA_EMAIL_TO`, `NA_SMTP_HOST`, `NA_SMTP_PORT`, `NA_SMTP_USER`, `NA_SMTP_PASSWORD`, `NA_SMTP_STARTTLS`, `NA_SMTP_SSL` (set implicit SSL to `true` for an SMTPS server, typically on port 465; leave it `false` for STARTTLS or plain SMTP)
- `NA_ENABLE_KAFKA`: whether to deploy a Kafka cluster (defaults to no)
    - if yes: `NA_KAFKA_REPLICAS`, `NA_KAFKA_VOLUME_SIZE`, `NA_KAFKA_VERSION`

The script generates random GitHub and GitLab webhook secrets and stores them in `~/.eoepca/state`. You need them when registering webhooks in a real repository.

### 2. Install the Knative Operator

Install the Knative Operator to manage the `KnativeServing` and `KnativeEventing` instances:

```bash
helm repo add knative-operator https://knative.github.io/operator
helm repo update knative-operator

helm upgrade -i knative-operator knative-operator/knative-operator \
  --namespace knative-operator \
  --create-namespace \
  --version v1.23.1 \
  --wait
```

### 3. Apply the Knative Serving and Eventing instances

```bash
kubectl apply -f generated-knative.yaml

kubectl wait --for=condition=Ready knativeserving/knative-serving -n knative-serving --timeout=300s
kubectl wait --for=condition=Ready knativeeventing/knative-eventing -n knative-eventing --timeout=300s
```

This creates the `knative-serving`/`knative-eventing`/`notifications` namespaces and the `KnativeServing`/`KnativeEventing` custom resources the operator reconciles. Give it a couple of minutes on a fresh cluster while it pulls the component images.

### 4. Optional: expose your own Knative Services

Apply this route if you want public URLs for Knative Services you deploy yourself. The webhook source and CloudEvents player use their own Ingresses, and broker-to-subscriber delivery uses internal service addresses.

For HTTPS, this step also creates a wildcard Certificate and an `ApisixTls` resource. Configure a DNS-01 `ClusterIssuer` before applying it; an HTTP-01 issuer cannot issue the wildcard certificate.

```bash
kubectl apply -f generated-apisix-route.yaml
```

When using HTTPS, wait for the certificate before opening a function's public URL:

```bash
kubectl wait --for=condition=Ready certificate/notifications-wildcard -n knative-serving --timeout=300s
```

### 5. Install the BB chart

The chart deploys the webhook source (GitHub and GitLab), the API Server Source, the CloudEvents player, the default broker and (if enabled) the emailer. The webhook source and CloudEvents player each get their own `Ingress`, using the TLS settings from the shared configuration.

```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev/
helm repo update eoepca-dev

helm upgrade -i notification-automation eoepca-dev/notification-automation \
  --namespace notifications \
  --create-namespace \
  --version 0.1.2 \
  -f generated-na-values.yaml \
  --wait
```

Once it's up - some quick checks:

```bash
source ~/.eoepca/state
curl ${HTTP_SCHEME}://cloudevents-player.notifications.${INGRESS_HOST}
curl ${HTTP_SCHEME}://webhooks.notifications.${INGRESS_HOST}/health
```

The CloudEvents player request should return `200` with associated response headers, and `/health` on the webhook source should return `200` with status `healthy`.

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

Then apply the cluster and wait for it:

```bash
kubectl apply -f generated-kafka-cluster.yaml
kubectl wait --for=condition=Ready kafka/kafka-cluster -n notifications --timeout=600s
```

The default broker does not use this Kafka cluster. Delivering events through Kafka requires the Knative Kafka extension, which this guide does not cover; see [Knative Kafka Broker](https://knative.dev/docs/eventing/brokers/broker-types/kafka-broker/).

### 7. Validate

```bash
bash validation.sh
```

## Usage

> **Prefer a notebook?** Run `../../notebooks/run.sh` and open the <a href="http://localhost:8888/lab/tree/notification-automation/notification-automation.ipynb" target="_blank">Notification and Automation notebook</a> at `http://localhost:8888`.

Follow **Send a GitHub webhook** and **Optional: email a CloudEvent** for an end-to-end notification workflow. The email step requires an SMTP server and a recipient inbox. The remaining examples show other sources, filters and subscribers.

```text
GitHub webhook → webhook source → default broker → CloudEvents player
                                                → emailer (push events only) → inbox
```

### Send a GitHub webhook

The payload below mimics a push to the deployment guide's `release-2.1` branch. GitHub signs requests with `X-Hub-Signature-256: sha256=<hmac-sha256 of the body>`, using the secret from `configure-notification-automation.sh`:

```bash
source ~/.eoepca/state
PAYLOAD='{"repository": {"html_url": "https://github.com/EOEPCA/deployment-guide"}, "ref": "refs/heads/release-2.1"}'
SIGNATURE="sha256=$(printf '%s' "$PAYLOAD" | openssl dgst -sha256 -hmac "$NA_GITHUB_WEBHOOK_SECRET" | awk '{print $NF}')"

curl -sS -w '\nHTTP %{http_code}\n' "${HTTP_SCHEME}://webhooks.notifications.${INGRESS_HOST}/github" \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -H "X-Hub-Signature-256: $SIGNATURE" \
  -d "$PAYLOAD"
```

Expect `HTTP 202`: the broker accepted the event. Check delivery to the player:

```bash
curl -s "${HTTP_SCHEME}://cloudevents-player.notifications.${INGRESS_HOST}/messages" | jq
```

Look for `eventType: org.eoepca.webhook.github.push`, the repository URL and branch in `data`, and the event `id`. If the event has not arrived yet, repeat the player request after a few seconds. You can also open `${HTTP_SCHEME}://cloudevents-player.notifications.${INGRESS_HOST}` in a browser.

The API returns the ten most recent events by default. Use `/messages?size=200` if cluster activity has pushed your event out of the list.

Use the same URL (`${HTTP_SCHEME}://webhooks.notifications.${INGRESS_HOST}/github`) and `NA_GITHUB_WEBHOOK_SECRET` when registering a real GitHub webhook.

### Optional: email a CloudEvent

This requires `NA_ENABLE_EMAILER=yes` and your SMTP settings. If you installed the chart without the emailer, rerun the configure script and the chart installation command.

The emailer starts without a subscription. Create a Trigger that sends only GitHub push events from the `default` broker to the emailer:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: eventing.knative.dev/v1
kind: Trigger
metadata:
  name: emailer-github
  namespace: notifications
spec:
  broker: default
  filter:
    attributes:
      type: org.eoepca.webhook.github.push
  subscriber:
    ref:
      apiVersion: v1
      kind: Service
      name: notification-automation-emailer
EOF

kubectl wait --for=condition=Ready trigger/emailer-github -n notifications --timeout=120s
```

Send the GitHub webhook again. Triggers do not replay events sent before they were created.

The email subject is `Notification [org.eoepca.webhook.github.push]`, and the body lists the event `id`, the repository URL and `refs/heads/release-2.1`.

If the email has not arrived, check the Trigger and emailer logs:

```bash
kubectl get trigger emailer-github -n notifications
kubectl logs -n notifications deployment/notification-automation-emailer --tail=20
```

The emailer logs `Email queued/sent` once the SMTP server accepts the message.

### Inspect Kubernetes events

The API Server Source watches Kubernetes `Event` objects in the `notifications` namespace. Create a sample event:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Event
metadata:
  name: notification-demo
  namespace: notifications
involvedObject:
  apiVersion: apps/v1
  kind: Deployment
  name: notification-automation-webhook-source
  namespace: notifications
reason: NotificationDemo
message: The webhook source is ready for events
type: Normal
EOF

curl -sS "${HTTP_SCHEME}://cloudevents-player.notifications.${INGRESS_HOST}/messages" | jq
```

Look for `eventType: dev.knative.apiserver.ref.add` with `notification-demo` in `data.name`. Repeat the player request after a few seconds if needed. The source sends an object reference; inspect the original Event to read its message:

```bash
kubectl get event notification-demo -n notifications -o yaml
```

The event does not match the emailer's GitHub push filter, so no email is sent. Delete the sample event:

```bash
kubectl delete event notification-demo -n notifications
```

The deletion appears in the player as `dev.knative.apiserver.ref.delete`. Events in other namespaces need their own source.

### Send a GitLab webhook

GitLab uses a plain secret token instead of a signature, sent as `X-Gitlab-Token`:

```bash
source ~/.eoepca/state
PAYLOAD='{"project": {"web_url": "https://gitlab.com/EOEPCA/deployment-guide"}}'

curl -sS -w '\nHTTP %{http_code}\n' "${HTTP_SCHEME}://webhooks.notifications.${INGRESS_HOST}/gitlab" \
  -H "Content-Type: application/json" \
  -H "X-Gitlab-Event: Push Hook" \
  -H "X-Gitlab-Token: $NA_GITLAB_WEBHOOK_SECRET" \
  -d "$PAYLOAD"
```

Expect `HTTP 202`, then look for `eventType: org.eoepca.webhook.gitlab.push_hook` in the player. This event does not match the emailer's GitHub push filter. Use `${HTTP_SCHEME}://webhooks.notifications.${INGRESS_HOST}/gitlab` and `NA_GITLAB_WEBHOOK_SECRET` when registering a real GitLab webhook.

### Route webhooks from multiple projects

The webhook source supports per-project secrets, so different repositories don't have to share one secret and can be told apart in the events they produce. Configure it via a `ConfigMap` the chart already knows how to read:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: notification-automation-webhook-source
  namespace: notifications
data:
  projects.json: |
    {
      "openeo-geotrellis": {
        "github_secret": "a-different-secret-for-this-repo"
      }
    }
EOF

kubectl rollout restart deployment/notification-automation-webhook-source -n notifications
kubectl rollout status deployment/notification-automation-webhook-source -n notifications --timeout=120s
```

The `ConfigMap` name must match `<helm release name>-webhook-source`; the webhook source only reads it on startup, hence the restart. Once it's picked up, `${HTTP_SCHEME}://webhooks.notifications.${INGRESS_HOST}/openeo-geotrellis/github` validates against that project's own secret instead of `NA_GITHUB_WEBHOOK_SECRET`, and the resulting CloudEvent's `subject` is set to the project name. The global `/github` and `/gitlab` endpoints keep working alongside project-specific ones.

Test the project-specific endpoint using the secret from `projects.json`:

```bash
PAYLOAD='{"repository":{"html_url":"https://github.com/EOEPCA/openeo-geotrellis"},"ref":"refs/heads/main"}'
SIGNATURE="sha256=$(printf '%s' "$PAYLOAD" | openssl dgst -sha256 -hmac 'a-different-secret-for-this-repo' | awk '{print $NF}')"

curl -sS -w '\nHTTP %{http_code}\n' \
  "${HTTP_SCHEME}://webhooks.notifications.${INGRESS_HOST}/openeo-geotrellis/github" \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -H "X-Hub-Signature-256: $SIGNATURE" \
  -d "$PAYLOAD"

curl -sS "${HTTP_SCHEME}://cloudevents-player.notifications.${INGRESS_HOST}/messages" | jq
```

Look for `subject: openeo-geotrellis`. The existing emailer Trigger also matches this push event. To subscribe only to this project, include both `type: org.eoepca.webhook.github.push` and `subject: openeo-geotrellis` under a Trigger's `filter.attributes`.

### Receive STAC item events from Data Access

[Data Access](./data-access.md) can publish a CloudEvent to this BB's `default` broker whenever a STAC item changes, using its `eoapi-notifier` component. Deploy (or redeploy) Data Access with `ENABLE_EOAPI_NOTIFIER=yes`, then create a collection and an item using Data Access's [STAC transactions example](./data-access.md#3-perform-basic-api-tests). Collection changes do not produce events.

!!! tip
    The following steps assume IAM is enabled on Data Access, such that all API requests require a valid access token and resource IDs are prefixed with the username.

Obtain an access token...

```bash
source ~/.eoepca/state
curl -X POST "${HTTP_SCHEME}://eoapi.${INGRESS_HOST}/stac/collections" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d @- <<EOF
{
  "id": "${KEYCLOAK_TEST_USER}.${collection}",
  "type": "Collection",
  "stac_version": "1.0.0",
  "description": "x",
  "license": "proprietary",
  "extent": {
    "spatial": {
      "bbox": [[-180,-90,180,90]]
    },
    "temporal": {
      "interval": [[null,null]]
    }
  },
  "links": []
}
EOF
```

Add an item to the collection...

curl -X POST "${HTTP_SCHEME}://eoapi.${INGRESS_HOST}/stac/collections/na-demo-collection/items" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d @- <<EOF
{
  "id": "na-demo-item-1",
  "type": "Feature",
  "stac_version": "1.0.0",
  "collection": "${KEYCLOAK_TEST_USER}.${collection}",
  "geometry": {
    "type": "Point",
    "coordinates": [0, 0]
  },
  "bbox": [0, 0, 0, 0],
  "properties": {
    "datetime": "2026-08-19T00:00:00Z"
  },
  "links": [],
  "assets": {}
}
EOF
```

Check the CloudEvents player again...

```bash
source ~/.eoepca/state
curl -s "https://cloudevents-player.notifications.${INGRESS_HOST}/messages" | jq '.[0]'
```

The player then shows an `org.ogc.api.collection.item.create` event with `source: /eoapi/pgstac` and `subject` set to the item's ID.

### Create a broker

`default` (created by the BB chart) already carries webhook, API Server Source and Data Access events. Create your own broker when you want a separate event space, for example so your Triggers don't match unrelated platform events.

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

Without `spec.config`, the broker uses the cluster default in-memory channel. A durable broker needs the Knative Kafka extension.

### Optional: notify Slack

[`send-notification-to-slack`](https://github.com/EOEPCA/send-notification-to-slack) is a Knative function that posts each CloudEvent it receives to a Slack channel. Set `SLACK_WEBHOOK_URL` to your [Slack Incoming Webhook](https://api.slack.com/apps) and deploy the prebuilt image:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: slack-notifier
  namespace: notifications
  labels:
    networking.knative.dev/visibility: cluster-local
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/min-scale: "1"
    spec:
      containers:
        - image: ghcr.io/eoepca/send-notification-to-slack:latest
          env:
            - name: SLACK_WEBHOOK_URL
              value: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: eventing.knative.dev/v1
kind: Trigger
metadata:
  name: slack-notifier-github
  namespace: notifications
spec:
  broker: default
  filter:
    attributes:
      type: org.eoepca.webhook.github.push
  subscriber:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: slack-notifier
EOF
```

Re-send the GitHub webhook and check the Slack channel. The function logs the response from Slack:

```bash
kubectl logs -n notifications -l serving.knative.dev/service=slack-notifier -c user-container --tail=20
```

## Writing automations

??? note "Writing your own automation"

    You have two routes for the actual automation code:

    - **`func` CLI** - the Knative Functions tool. It scaffolds a project with the CloudEvents handling in place and builds and pushes the image for you.
    - **Plain Knative Serving** - write a FastAPI (or any HTTP) service, build the container yourself, deploy as a `Service`.

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

    By default each function gets a public endpoint. To keep it cluster-local, add the label `networking.knative.dev/visibility=cluster-local` to the service; a function that only receives broker events does not need a public URL.

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

    The subscriber must reply with an empty body or a CloudEvent. The broker treats any other response body as a failed delivery and retries it, 10 times by default, so a FastAPI handler that returns JSON receives each event repeatedly.

    !!! warning "Avoid self-triggering loops"
        If your function emits a CloudEvent in response and the trigger has no filter, the response flows back through the broker, matches the trigger and fires the function again indefinitely. Either filter on `type` (as above) so the function's own response type doesn't match, or have the function return without sending a response.

    ### See it working

    Grab the broker's internal URL:

    ```bash
    BROKER_URL=$(kubectl get broker primary -n notifications -o jsonpath='{.status.address.url}')
    echo "$BROKER_URL"
    ```

    Post a CloudEvent. The `Ce-*` headers are how CloudEvents are encoded over HTTP in binary mode. The broker URL is cluster-internal, so run curl from a pod:

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
    kubectl logs -n notifications -l serving.knative.dev/service=demo-fn -c user-container --tail=50
    ```

    You should see one `Request Received` line per test event. If you see a flood of them, the function is looping on its own responses - delete the trigger, switch to a filtered one as above, or remove the response from `func.py`.

## Uninstallation

Tear down in the reverse order of installation, so nothing is left depending on a CRD or control plane that's already gone.

```bash
# Services, Brokers, Triggers and the projects ConfigMap created in Usage
kubectl delete ksvc,trigger,broker --all -n notifications 2>/dev/null || true
kubectl delete configmap notification-automation-webhook-source -n notifications 2>/dev/null || true

# If Kafka was deployed
kubectl delete -f generated-kafka-cluster.yaml 2>/dev/null || true
helm uninstall strimzi-cluster-operator -n strimzi-system 2>/dev/null || true

helm uninstall notification-automation -n notifications 2>/dev/null || true
kubectl delete -f generated-apisix-route.yaml 2>/dev/null || true

kubectl delete -f generated-knative.yaml 2>/dev/null || true
kubectl wait --for=delete knativeserving/knative-serving -n knative-serving --timeout=120s 2>/dev/null || true
kubectl wait --for=delete knativeeventing/knative-eventing -n knative-eventing --timeout=120s 2>/dev/null || true

helm uninstall knative-operator -n knative-operator 2>/dev/null || true

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
