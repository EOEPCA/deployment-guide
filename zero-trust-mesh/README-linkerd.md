# mTLS with `linkerd`

## Create Kubernestes Cluster

```bash
k3d cluster create linkerd \
  --k3s-arg="--disable=traefik@server:0" \
  --k3s-arg="--tls-san=$(hostname -f)@server:0" \
  --servers 1 --agents 0 \
  --port 31080:31080@loadbalancer \
  --port 31443:31443@loadbalancer \
  --registry-config "registries.yaml"
```

## Install Linkerd

Two approaches:
* [Install with `linkrd` CLI](#install-with-linkerd-cli)
* [Install with helm chart](#install-with-helm-chart)

### Install with `linkerd` CLI

Ref. [Linkerd `2.1.8` Getting Started](https://linkerd.io/2.18/getting-started/)

#### Install CLI

```bash
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install-edge | sh
export PATH=$HOME/.linkerd2/bin:$PATH
linkerd version
```

#### Install Gateway API

Only needed if the Gateway API (CRDs) are not already installed.

Check...

```bash
kubectl get crds/httproutes.gateway.networking.k8s.io \
  -o "jsonpath={.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}"
```

If the Gateway API (CRDs) is not already installed...

> Note the `linkerd` helm chart can do this as a dependency

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

#### Prerequisites Check

```bash
linkerd check --pre
```

#### Deploy Linkerd to the CLuster

Deploy...

```bash
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
```

Check...

```bash
linkerd check
```

### Install with helm chart

TBD

## Deploy Linkerd `viz` Dashboard

Deploy...

```bash
linkerd viz install | kubectl apply -f - # install the on-cluster metrics stack
```

Open the dashboard...

```bash
linkerd viz dashboard &
```

## Deploy the `Emojivoto` Demo App

### Deploy

```bash
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/emojivoto.yml \
  | kubectl apply -f -
```

### Open `Emojivoto` web app

Port-forward for web service access...

```bash
kubectl -n emojivoto port-forward svc/web-svc 8080:80
```

OPen web app...

```bash
xdg-open http://localhost:8080/
```

### Add `Emojivoto` to the Mesh

```bash
kubectl get -n emojivoto deploy -o yaml \
  | linkerd inject - \
  | kubectl apply -f -
```

## Deploy the Test pods

Test pods used for checking the mTLS allow/deny behaviour.

```bash
kubectl apply -f test.yaml
```

These pods have specific `ServiceAccounts` that will be used for mTLS access:
* Pod `curl-one` - service account `can-be-trusted`
* Pod `curl-two` - service account `dont-trust-me`

## Check access from test pods to `Emojivoto`

Since we have not yet specified any protection - both pods should have access to the `web-svc.emojivoto` service.

Pod `curl-one` - returns `200`...

```bash
kubectl -n test exec -it pod/curl-one -c curl -- curl -s -o /dev/null -D - web-svc.emojivoto | grep -i "^HTTP/"
```

Pod `curl-two` - returns `200`...

```bash
kubectl -n test exec -it pod/curl-two -c curl -- curl -s -o /dev/null -D - web-svc.emojivoto | grep -i "^HTTP/"
```

## Apply mTLS Protection to `Emojivoto`

Restrict access only to the service account of the `curl-one` pod - `can-be-trusted.test.serviceaccount.identity.linkerd.cluster.local`.

```bash
kubectl apply -f protect-emojivoto.yaml
```

## Re-check access from test pods to `Emojivoto`

Now the protection is applied - only pod `curl-one` should be allowed, whereas `curl-two` should be denied.

Pod `curl-one` - returns `200` (OK)...

```bash
kubectl -n test exec -it pod/curl-one -c curl -- curl -s -o /dev/null -D - web-svc.emojivoto | grep -i "^HTTP/"
```

Pod `curl-two` - returns `403` (Forbidden)...

```bash
kubectl -n test exec -it pod/curl-two -c curl -- curl -s -o /dev/null -D - web-svc.emojivoto | grep -i "^HTTP/"
```
