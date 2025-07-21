# Gateway API Proof-of-concept

## Motivation

The motivation for this proof-of-concept is to address the needs for multiple points of TLS termination:
* APISIX ingress controller, including IAM policy enforcement
* Workspace vClusters exposing Kubernetes API access with dedicated TLS certificates

The platform exposes a single public entrypoint - which must route the traffic to these internal endpoints. **Significantly, the traffic must be routed with SSL passthrough such that APISIX and the Workspace vClusters can perform their own SSL termination.**

Some investigations have been made to achieve this via `ingress-nginx` SSL passthrough. But it was found that this is somewhat limited - in particular for integration with APISIX - and it is also understood that use of `ssl-passtrhough` with nginx introduces inefficiencies.

A better alternative has been found in the Kubernetes [`Gateway API` ](https://gateway-api.sigs.k8s.io/) - which offers a more sophisticated and flexible approach to traffic routing.

This proof-of-concept introduces `Envoy Gateway` as the platform entrypoint implementing the `Gateway API` - with example `HTTPRoute` and `TLSRoute` resources for integration with APISIX and with self-terminating dummy endpoints (that emulate a Workspace vCluster).

The outcome of this approach, from the point if the building-blocks, is largely transparent:
* BBs create `Ingress` and `ApisixRoute` resources as per existing approach - to be satisfied by APISIX
* To expose Workspace vCluster Kubernetes API - the Workspace BB would have to use `TLSRoute` resources instead of the current `Ingress` resources used - which are directly routed (SSL passthrough) from the gateway to the vCLuster endpoint

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

## Envoy Gateway

### Envoy Gateway - Deploy via Helm

```bash
helm upgrade -i envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-gateway-system --create-namespace
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

### Envoy Gateway - Envoy Proxy

> **NOTE...**<br>
> We only need this as we want to expose http/80 / https/443 on NodePorts 31080/31443 - rather than the default LoadBalancer on port 80/443.<br>
> Each `Gateway` resource instantiates a set of resources (deployment, pods, service, etc.) that implement the `Gateway` - including a `Service` that exposes the listening ports of the `Gateway`.<br>
> These resources are defined by a template that can be patched via an `EnvoyProxy` resource.<br>
> Thus, we patch the `envoyService` ports defintion to include the required `NodePorts`.<br>
> The `EnvoyProxy/nodeport-proxy-config` is then used as a parameter in the `Gateway` below.

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: gateway
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: nodeport-proxy-config
  namespace: gateway
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

### Envoy Gateway - Gateway Class

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF
```

### Envoy Gateway - Gateway

> NOTE. The EnvoyProxy reference is only needed if the NodePort 31080/31443 patching is required

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: gateway
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eoepca-public
  namespace: gateway
spec:
  gatewayClassName: envoy
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

## HTTP Test Service

### HTTP - Deployment and Service

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

### HTTP - Routing via HTTPRoute

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: http-echo
  namespace: http-echo
spec:
  parentRefs:
    - name: eoepca-public
      namespace: gateway
  hostnames:
    - "http-echo.verify.eoepca.org"
  rules:
    - backendRefs:
        - name: http-echo
          port: 3000
EOF
```

Test the endpoint - should return a summary (echo) of the request...

```bash
curl http://http-echo.verify.eoepca.org
```

## HTTPS Test Service

### HTTPS - Self-signed TLS Cert

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

### HTTPS - Echo Pod and Service

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

### HTTPS - http/80 routing via HTTPRoute

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: tls-echo
  namespace: tls-echo
spec:
  parentRefs:
    - name: eoepca-public
      namespace: gateway
  hostnames:
    - tls-echo.verify.eoepca.org
  rules:
    - backendRefs:
        - name: tls-echo
          port: 80
EOF
```

Test the endpoint - should return `This is service TLS ECHO (http/80)`...

```bash
curl http://tls-echo.verify.eoepca.org/index.html
```

### HTTPS - https/443 routing via TLSRoute

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: tls-echo
  namespace: tls-echo
spec:
  parentRefs:
    - name: eoepca-public
      namespace: gateway
  hostnames:
    - tls-echo.verify.eoepca.org
  rules:
    - backendRefs:
      - name: tls-echo
        port: 443
EOF
```

Test the endpoint - should return `This is service TLS ECHO (https/443)`...

```bash
curl https://tls-echo.verify.eoepca.org/index.html -k
```

## DUMMY Test Service

### DUMMY - Self-signed TLS Cert

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

### DUMMY - Echo Pod and Service

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
        - |
          apk add openssl socat && \
          echo "This is service DUMMY (https/443)" >index.html && \
          (openssl s_server -accept 443 -cert /tls/tls.crt -key /tls/tls.key -WWW &) && \
          socat TCP-LISTEN:80,reuseaddr,fork EXEC:'echo -e "HTTP/1.1 200 OK\r\nContent-Length: 32\r\n\r\nThis is service DUMMY (http/80)"'
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
    - name: http
      port: 80
      targetPort: 80
    - name: https
      port: 443
      targetPort: 443
EOF
```

### DUMMY - http/80 routing via HTTPRoute

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: dummy
  namespace: dummy
spec:
  parentRefs:
    - name: eoepca-public
      namespace: gateway
  hostnames:
    - dummy.verify.eoepca.org
  rules:
    - backendRefs:
        - name: dummy
          port: 80
EOF
```

Test the endpoint - should return `This is service DUMMY (http/80)`...

```bash
curl http://dummy.verify.eoepca.org/index.html
```

### DUMMY - https/443 routing via TLSRoute

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: dummy
  namespace: dummy
spec:
  parentRefs:
    - name: eoepca-public
      namespace: gateway
  hostnames:
    - dummy.verify.eoepca.org
  rules:
    - backendRefs:
        - name: dummy
          port: 443
EOF
```

Test the endpoint - should return `This is service DUMMY (https/443)`...

```bash
curl https://dummy.verify.eoepca.org/index.html -k
```

## APISIX

### APISIX - Deploy via helm

```bash
helm repo add apisix https://charts.apiseven.com && \
helm repo update apisix && \
helm upgrade -i apisix apisix/apisix \
  --version 2.9.0 \
  --namespace ingress-apisix --create-namespace \
  --set apisix.enableIPv6=false \
  --set apisix.enableServerTokens=false \
  --set apisix.ssl.enabled=true \
  --set apisix.pluginAttrs.redirect.https_port=443 \
  --set ingress-controller.enabled=true \
  --set etcd.replicaCount=1
```

### APISIX - http/80 routing via HTTPRoute

> No hostname rules, so acts as Default Route

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: apisix
  namespace: ingress-apisix
spec:
  parentRefs:
    - name: eoepca-public
      namespace: gateway
  rules:
    - backendRefs:
        - name: apisix-gateway
          port: 80
EOF
```

Test the endpoint - should return `{"error_msg":"404 Route Not Found"}` - we recognise this as coming from APISIX...

```bash
curl http://fred.verify.eoepca.org/index.html
```

### APISIX - https/443 routing via TLSRoute

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: apisix
  namespace: ingress-apisix
spec:
  parentRefs:
    - name: eoepca-public
      namespace: gateway
  rules:
    - backendRefs:
        - name: apisix-gateway
          port: 443
EOF
```

> Will test this by creating an Ingress in next steps

## APISIX - Routing via Ingress

### APISIX - DUMMY Ingress - Self-signed TLS Cert

```bash
clear
kubectl create namespace dummy 2>/dev/null
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout tls.key -out tls.crt -days 365 \
  -subj "/CN=dummy-apisix.verify.eoepca.org"
kubectl delete secret dummy-apisix-tls --namespace dummy 2>/dev/null
kubectl create secret tls dummy-apisix-tls \
  --cert=tls.crt --key=tls.key \
  --namespace dummy
rm tls.key tls.crt
```

### APISIX - DUMMY Ingress

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dummy
  namespace: dummy
  annotations:
    kubernetes.io/ingress.class: apisix
spec:
  ingressClassName: apisix
  rules:
    - host: dummy-apisix.verify.eoepca.org
      http:
        paths:
          - path: "/"
            pathType: Prefix
            backend:
              service:
                name: dummy
                port:
                  number: 80
  tls:
    - hosts:
        - dummy-apisix.verify.eoepca.org
      secretName: dummy-apisix-tls
EOF
```

### APISIX - DUMMY Ingress - Test http/80

Test `http/80` endpoint - should return `This is service DUMMY (http/80)`...

```bash
curl http://dummy-apisix.verify.eoepca.org/index.html
```

### APISIX - DUMMY Ingress - Test https/443

Test `https/443` endpoint - should return `This is service DUMMY (http/80)`...

> NOTE APISIX terminates the TLS and forwards to the `http/80` service

```bash
curl https://dummy-apisix.verify.eoepca.org/index.html -k
```

## APISIX - Ingress with Letsencrypt

### APISIX - Ingress with Letsencrypt - Deploy Cert Manager

```bash
clear
helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack
helm upgrade -i cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.16.1 \
  --set crds.enabled=true
```

### APISIX - Ingress with Letsencrypt - Cluster Issuer

```bash
cat - <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-http01-apisix
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: richard.conway@telespazio.com
    privateKeySecretRef:
      name: letsencrypt-http01-apisix
    solvers:
      - http01:
          ingress:
            class: apisix
EOF
```

### APISIX - Ingress with Letsencrypt - Ingress Resource

```bash
clear ; cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dummy-letsencrypt
  namespace: dummy
  annotations:
    kubernetes.io/ingress.class: apisix
    cert-manager.io/cluster-issuer: "letsencrypt-http01-apisix"
spec:
  ingressClassName: apisix
  rules:
    - host: dummy-letsencrypt.verify.eoepca.org
      http:
        paths:
          - path: "/"
            pathType: Prefix
            backend:
              service:
                name: dummy
                port:
                  number: 80
  tls:
    - hosts:
        - dummy-letsencrypt.verify.eoepca.org
      secretName: dummy-letsencrypt-tls
EOF
```

### APISIX - Ingress with Letsencrypt - Test http/80

Test `http/80` endpoint - should return `This is service DUMMY (http/80)`...

```bash
curl http://dummy-letsencrypt.verify.eoepca.org/index.html
```

### APISIX - Ingress with Letsencrypt - Test https/443

Test `https/443` endpoint - should return `This is service DUMMY (http/80)`...

> NOTES:
> * APISIX terminates the TLS and forwards to the `http/80` service
> * The `-k` option is not needed as we have a fully signed TLS certificate

```bash
curl https://dummy-letsencrypt.verify.eoepca.org/index.html
```

Since the certificate is legitimate, we can open this endpoint in our browser...

```bash
xdg-open https://dummy-letsencrypt.verify.eoepca.org/index.html
```
