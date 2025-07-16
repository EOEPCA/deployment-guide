# Use of Gateway API

## Create fresh cluster

```bash
export KUBECONFIG="$PWD/kubeconfig.yaml"
k3d cluster create eoepca \
  --k3s-arg="--disable=traefik@server:0" \
  --k3s-arg="--tls-san=$(hostname -f)@server:0" \
  --servers 1 --agents 0 \
  --port 31080:31080@loadbalancer \
  --port 31443:31443@loadbalancer
```

## Install Envoy Gateway

```bash
helm upgrade -i envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-gateway-system --create-namespace
```

## Create GatewayClass

```bash
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway-class
spec:
  controllerName: gateway.envoyproxy.io/gateway-controller
EOF
```

## Create Gateway

```bash
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: tls-gateway
  namespace: default
spec:
  gatewayClassName: envoy-gateway-class
  listeners:
  - name: tls
    protocol: TLS
    port: 443
    tls:
      mode: Passthrough
    allowedRoutes:
      namespaces:
        from: All
EOF
```

## Dummy TLS service endpoint for testing

### Self-signed TLS Cert

```bash
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout tls.key -out tls.crt -days 365 \
  -subj "/CN=test-tls.local" && \
kubectl create secret tls test-tls \
  --cert=tls.crt --key=tls.key \
  --namespace default && \
rm tls.key tls.crt
```

### TLS Echo Pod

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tls-echo
  namespace: default
spec:
  containers:
  - name: echo
    image: alpine:latest
    command: ["/bin/sh", "-c"]
    args:
      - apk add openssl && \
        openssl s_server -accept 443 -cert /tls/tls.crt -key /tls/tls.key -www
    volumeMounts:
    - name: tls
      mountPath: /tls
      readOnly: true
  volumes:
  - name: tls
    secret:
      secretName: test-tls
---
apiVersion: v1
kind: Service
metadata:
  name: tls-echo-service
  namespace: default
spec:
  selector:
    app: tls-echo
  ports:
  - port: 443
    targetPort: 443
EOF
```

## Create TLSRoute

```bash
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: echo-tls-route
  namespace: default
spec:
  parentRefs:
  - name: tls-gateway
    namespace: default
  rules:
  - backendRefs:
    - name: tls-echo-service
      port: 443
EOF
```
