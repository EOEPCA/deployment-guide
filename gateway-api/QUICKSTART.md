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
    - name: https
      protocol: TLS
      port: 443
      tls:
        mode: Passthrough
      allowedRoutes:
        namespaces:
          from: All
EOF
```

### HTTP Test Service

#### HTTP - Deployment and Service

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

#### HTTP - Routing via HTTPRoute

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

### HTTPS Test Service

#### HTTPS - Self-signed TLS Cert

```bash
clear
kubectl create namespace tls-echo 2>/dev/null
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout tls.key -out tls.crt -days 365 \
  -subj "/CN=tls-echo.verify.eoepca.org"
kubectl delete secret tls-echo-tls --namespace tls-echo 2>/dev/null
kubectl create secret tls tls-echo-tls \
  --cert=tls.crt --key=tls.key \
  --namespace tls-echo
rm tls.key tls.crt
```

#### HTTPS - Echo Pod and Service

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tls-echo
  namespace: tls-echo
  labels:
    app: tls-echo
spec:
  containers:
  - name: echo
    image: alpine:latest
    command: ["/bin/sh", "-c"]
    args:
      - |
        apk add openssl socat && \
        echo "This is service TLS ECHO (https/443)" >index.html && \
        (openssl s_server -accept 443 -cert /tls/tls.crt -key /tls/tls.key -WWW &) && \
        socat TCP-LISTEN:80,reuseaddr,fork EXEC:'echo -e "HTTP/1.1 200 OK\r\nContent-Length: 35\r\n\r\nThis is service TLS ECHO (http/80)"'
    volumeMounts:
    - name: tls
      mountPath: /tls
      readOnly: true
  volumes:
  - name: tls
    secret:
      secretName: tls-echo-tls
---
apiVersion: v1
kind: Service
metadata:
  name: tls-echo
  namespace: tls-echo
spec:
  selector:
    app: tls-echo
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: https
    port: 443
    targetPort: 443
EOF
```

#### HTTPS - http/80 routing via HTTPRoute

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: tls-echo
  namespace: tls-echo
spec:
  parentRefs:
    - name: eg
      namespace: default
  rules:
    - backendRefs:
        - name: tls-echo
          port: 80
EOF
```

#### HTTPS - https/443 routing via TLSRoute

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: tls-echo
  namespace: tls-echo
spec:
  parentRefs:
  - name: eg
    namespace: default
  rules:
  - backendRefs:
    - name: tls-echo
      port: 443
EOF
```

### DUMMY Test Service

#### DUMMY - Self-signed TLS Cert

```bash
clear
kubectl create namespace dummy 2>/dev/null
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout tls.key -out tls.crt -days 365 \
  -subj "/CN=dummy.verify.eoepca.org"
kubectl delete secret dummy-tls --namespace dummy 2>/dev/null
kubectl create secret tls dummy-tls \
  --cert=tls.crt --key=tls.key \
  --namespace dummy
rm tls.key tls.crt
```

#### DUMMY - Echo Pod and Service

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dummy
  namespace: dummy
  labels:
    app: dummy
spec:
  containers:
  - name: echo
    image: alpine:latest
    command: ["/bin/sh", "-c"]
    args:
      - apk add openssl && \
        echo "This is service DUMMY" >index.html && \
        openssl s_server -accept 443 -cert /tls/tls.crt -key /tls/tls.key -WWW
    volumeMounts:
    - name: tls
      mountPath: /tls
      readOnly: true
  volumes:
  - name: tls
    secret:
      secretName: dummy-tls
---
apiVersion: v1
kind: Service
metadata:
  name: dummy
  namespace: dummy
spec:
  selector:
    app: dummy
  ports:
  - port: 443
    targetPort: 443
EOF
```

#### DUMMY - Routing via TLSRoute

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: dummy
  namespace: dummy
spec:
  parentRefs:
  - name: eg
    namespace: default
  hostnames:
  - dummy.verify.eoepca.org
  rules:
  - backendRefs:
    - name: dummy
      port: 443
EOF
```
