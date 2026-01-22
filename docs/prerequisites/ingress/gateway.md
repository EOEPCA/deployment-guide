# Ingress Gateway

## Introduction

If your ingress needs are more complex, for example you have an existing ingress controller or require use of multiple ingress controllers - then you might consider exposing the entrypoint to your cluster via an ingress gateway.

This document outlines an example of using an Envoy-based Gateway to route traffic into an EOEPCA+ deployment that uses the APISIX ingress controller. The approach illustrates SSL passthrough to the APISIX ingress controller which is able to perform TLS termination, establish SSL certificates via Letsencrypt, and enforce IAM policies.

The Kubernetes `Gateway` API provides a way to manage external L4/L7 access to services in a cluster, typically HTTP. The Gateway API is an evolution of the Ingress API, offering more flexibility and control over traffic routing. The Ingress API is no longer being actively developed, with the Gateway API intended to replace it over time.

The approach illustrates the following topology, which can be adapted to other ingress controllers or multiple ingress controllers as required:

> As for the [APISIX Ingress](../apisix-ingress.md) approach, we assume use of NodePorts `31080/31443` for the Gateway to expose its services externally.

```
Internet
 -> Public Entrypoint - e.g. Load-balancer
     -> Envoy Gateway - `NodePort 31080/31443`
         -> APISIX (default route) - `*.<platform-domain>` - full TLS passthrough
         -> Nginx (specific route) - `*.ngx.<platform-domain>` - full TLS passthrough
```

> The term **`<platform-domain>`** is used to represent the domain name assigned to your EOEPCA+ platform - e.g. `myplatform.example.com` - and should be substituted accordingly.

## Envoy Gateway

### Deploy Envoy Gateway

Envoy Gateway can be installed via Helm:

```bash
helm upgrade -i envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version 1.6.2 \
  --namespace envoy-gateway-system --create-namespace
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

### Patch for NodePorts

> This step is only needed as we want to expose `http/80`/`https/443` on NodePorts `31080/31443` - rather than the default LoadBalancer on port `80/443`.<br>
> **If this is not your configuration then you can skip this step.**

Each `Gateway` resource instantiates a set of resources (deployment, pods, service, etc.) that implement the `Gateway` - including a `Service` that exposes the listening ports of the `Gateway`.

These resources are defined by a template that can be patched via an `EnvoyProxy` resource. Thus, we patch the `envoyService` ports defintion to include the required `NodePorts`.

The `EnvoyProxy/nodeport-proxy-config` is then used as a parameter in the `Gateway` below.

```bash
cat <<EOF | kubectl apply -f -
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

### Gateway Class

Create a _GatewayClass_ resource to identify our Envoy Gateway controller.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF
```

### Create Gateway Instance

We create a `Gateway` instance for our EOEPCA traffic.

> * The `EnvoyProxy` reference is only needed if the NodePort `31080/31443` patching is required
> * TLS is configured for `Passthrough` mode so that SSL termination is handled by the backend ingress controller (such as APISIX)

```bash
cat <<EOF | kubectl apply -f -
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

## APISIX

We deploy APISIX and then configure the Gateway to route traffic to APISIX for all requests not otherwise matched - i.e. APISIX is the default backend for the Gateway.

See [APISIX Ingress](./apisix.md) for more details.

### Deploy APISIX

Similar to the deployment described in [APISIX Ingress](./apisix.md), APISIX is deployed via Helm:

> In this case we do not need the APISIX service to expose NodePorts as the Gateway handles this.

```bash
helm repo add apisix https://apache.github.io/apisix-helm-chart
helm repo update apisix
helm upgrade -i apisix apisix/apisix \
  --version 2.10.0 \
  --namespace ingress-apisix --create-namespace \
  --set etcd.image.repository=bitnamilegacy/etcd \
  --set etcd.replicaCount=1 \
  --set etcd.persistence.storageClass="${PERSISTENT_STORAGECLASS:-local-path}" \
  --set apisix.enableIPv6=false \
  --set apisix.enableServerTokens=false \
  --set apisix.ssl.enabled=true \
  --set apisix.pluginAttrs.redirect.https_port=443 \
  --set ingress-controller.enabled=true
```

### Gateway to APISIX Route (HTTP)

We create a `HTTPRoute` resource to route all HTTP traffic to the APISIX service.

> No hostname rules, so acts as Default Route

```bash
cat <<EOF | kubectl apply -f -
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

### Gateway to APISIX Route (HTTPS)

We create a `TLSRoute` resource to route all HTTPS traffic to the APISIX service - recalling that TLS Passthrough was specified for the `eoepca-public` Gateway listener.

> No hostname rules, so acts as Default Route

```bash
cat <<EOF | kubectl apply -f -
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

### Ingress to APISIX

The APISIX ingress controller can now be used to define ingresses as normal - using `Ingress` or `ApisixRoute` resources.

> Since TLS Passthhrough was specified for the Gateway, APISIX handles TLS termination and certificate management using Letsencrypt as per normal.
>
> The ingress assumes use of TLS via Let's Encrypt, as described in the [TLS Management](../tls.md) section - making use of the `letsencrypt-http01-apisix` [_ClusterIssuer_](../tls.md#create-a-clusterissuer-for-lets-encrypt).

For example:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-with-letsencrypt
  namespace: example
  annotations:
    kubernetes.io/ingress.class: apisix
    cert-manager.io/cluster-issuer: "letsencrypt-http01-apisix"
spec:
  ingressClassName: apisix
  rules:
    - host: example.<platform-domain>
      http:
        paths:
          - path: "/"
            pathType: Prefix
            backend:
              service:
                name: example
                port:
                  number: 80
  tls:
    - hosts:
        - example.<platform-domain>
      secretName: example-tls
```

## NGINX Ingress Controller

See [NGINX Ingress](./nginx.md) for more details.

### Deploy NGINX

Similar to the deployment described in [NGINX Ingress](./nginx.md), NGINX is deployed via Helm:

> In this case we do not need the NGINX service to expose NodePorts as the Gateway handles this.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.allowSnippetAnnotations=true \
  --set controller.config.ssl-redirect=true \
  --set controller.service.type=ClusterIP
```

### Gateway to NGINX Route (HTTP)

We create a `HTTPRoute` resource to route HTTP traffic for specific hostnames (anything under the sub-domain `.ngx.<platform-domain>`) to the NGINX service.

> Replace `<platform-domain>` with the domain for your deployment.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: nginx
  namespace: ingress-nginx
spec:
  parentRefs:
    - name: eoepca-public
      namespace: gateway
  hostnames:
    - "*.ngx.<platform-domain>"
  rules:
    - backendRefs:
        - name: ingress-nginx-controller
          port: 80
EOF
```

### Gateway to NGINX Route (HTTPS)

We create a `TLSRoute` resource to route HTTPS traffic for specific hostnames (anything under the sub-domain `.ngx.<platform-domain>`) to the NGINX service - recalling that TLS Passthrough was specified for the `eoepca-public` Gateway listener.

> Replace `<platform-domain>` with the domain for your deployment.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: nginx
  namespace: ingress-nginx
spec:
  parentRefs:
    - name: eoepca-public
      namespace: gateway
  hostnames:
    - "*.ngx.<platform-domain>"
  rules:
    - backendRefs:
        - name: ingress-nginx-controller
          port: 443
EOF
```

### Ingress to NGINX

The NGINX ingress controller can now be used to define ingresses as normal - using `Ingress` resources.

> Since TLS Passthhrough was specified for the Gateway, NGINX handles TLS termination and certificate management using Letsencrypt as per normal.
>
> The ingress assumes use of TLS via Let's Encrypt, as described in the [TLS Management](../tls.md) section - making use of the `letsencrypt-http01-nginx` [_ClusterIssuer_](../tls.md#create-a-clusterissuer-for-lets-encrypt).

For example:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-for-nginx
  namespace: example
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: "letsencrypt-http01-nginx"
spec:
  ingressClassName: nginx
  rules:
    - host: example.ngx.<platform-domain>
      http:
        paths:
          - path: "/"
            pathType: Prefix
            backend:
              service:
                name: example
                port:
                  number: 80
  tls:
    - hosts:
        - example.ngx.<platform-domain>
      secretName: example-ngx-tls
```
