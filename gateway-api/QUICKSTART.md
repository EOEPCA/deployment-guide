# Envoy Gateway Quickstart

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

## Quickstart Deploy

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v0.0.0-latest -n envoy-gateway-system --create-namespace
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/latest/quickstart.yaml -n default
```

### Envoy Proxy

> NOTE. We only need this as we want to expose http/80 on NodePort 31080 - rather than the default LoadBalancer on port 80.

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: nodeport-proxy-config
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyDeployment:
        replicas: 1
      envoyService:
        type: NodePort
        patch:
          type: StrategicMerge
          value:
            spec:
              ports:
              - name: http-80
                port: 80
                protocol: TCP
                targetPort: 10080
                nodePort: 31080
              - name: https-443
                port: 443
                protocol: TCP
                targetPort: 10443
                nodePort: 31443
EOF
```

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: nodeport-proxy-config
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        type: NodePort
        patch:
          type: StrategicMerge
          value:
            spec:
              ports:
              - name: http-80
                port: 80
                protocol: TCP
                targetPort: 10080
                nodePort: 31080
              - name: https-443
                port: 443
                protocol: TCP
                targetPort: 10443
                nodePort: 31443
EOF
```

### Gateway Class

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF
```

### Gateway

> NOTE. The EnvoyProxy reference is only needed if the NodePort 31080/31443 patching is required

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eg
spec:
  gatewayClassName: eg
  infrastructure:
    parametersRef:
      group: gateway.envoyproxy.io
      kind: EnvoyProxy
      name: nodeport-proxy-config
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
EOF
```

### Test Service

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: http-echo
---
apiVersion: v1
kind: Service
metadata:
  name: http-echo
  namespace: http-echo
  labels:
    app: http-echo
    service: http-echo
spec:
  ports:
    - name: http
      port: 3000
      targetPort: 3000
  selector:
    app: http-echo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-echo
  namespace: http-echo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: http-echo
      version: v1
  template:
    metadata:
      labels:
        app: http-echo
        version: v1
    spec:
      containers:
        - image: gcr.io/k8s-staging-gateway-api/echo-basic:v20231214-v1.0.0-140-gf544a46e
          imagePullPolicy: IfNotPresent
          name: http-echo
          ports:
            - containerPort: 3000
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
EOF
```

## HTTPRoute

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: http-echo
  namespace: http-echo
spec:
  parentRefs:
    - name: eg
      namespace: default
  hostnames:
    - "http-echo.verify.eoepca.org"
  rules:
    - backendRefs:
        - group: ""
          kind: Service
          name: http-echo
          port: 3000
          weight: 1
      # matches:
      #   - path:
      #       type: PathPrefix
      #       value: /
EOF
```
