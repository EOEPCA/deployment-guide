# Ingress Controller Setup Guide

This guide provides instructions to install and configure an ingress controller for your Kubernetes cluster. The ingress controller manages external access to the services in your cluster, typically via HTTP and HTTPS.

---

## Introduction

The canonical ingress controller is typically the Ingress-Nginx controller - for which we provide a deployment guide below.

The IAM BB (Identity & Access Management) advocates use of the alternative APISIX Ingress Controller, which offers more flexible policy enforcement configuration.

Recognising that it may be more or less convenient to accommodate the APISIX controller within your cluster, we present in this section various approaches to provision ingress within your cluster. Hopefully these options provide a suitable approach that can be adpated to your cluster offering.

---

## Provisioning Approaches

This section offers the following alternative approaches...

* [Use Ingress-Nginx](#use-ingress-nginx)
* [Use APISIX](#use-apisix)
* [Use both](#use-both)

> NOTE - for the purposes of this guide, we assume that the Kubernetes cluster exposes `NodePorts` `31080` (http) and `31443` (https) for external access to the cluster. This presumes that a (cloud) load balancer is configured to forward public `80/443` traffic to these exposed ports on the cluster nodes.
> 
> This can be adapted according to the network topology of your cluster environment.

### Use Ingress Nginx

Provision **Ingress-Nginx** as the sole ingress entrypoint to your cluster.

Follow the guide to [Setup Ingress-Nginx As Cluster Entrypoint](#ingress-nginx-as-cluster-entrypoint).

### Use APISIX

Provision **APISIX** as the sole ingress entrypoint to your cluster.

Follow the guide to [Setup APISIX As Cluster Entrypoint](#apisix-as-cluster-entrypoint).

### Use Both

In this approach both Ingress-Nginx and APISIX are provisioned - neither of which acts as the direct ingress entrypoint to the cluster.

Instead, an **Ingress Proxy** is provisioned as entrypoint - using hostname rules to passthru traffic to the relevant ingress controller.

Thus, the following guides should be followed...

* [Setup Ingress-Nginx Behind Ingress Proxy](#ingress-nginx-behind-ingress-proxy)
* [Setup APISIX Behind Ingress Proxy](#apisix-behind-ingress-proxy)
* [Setup Ingress Proxy](#ingress-proxy)

---

## Prerequisites

- A running Kubernetes cluster.
- `kubectl` and `helm` installed and configured to interact with your cluster.
- A domain name pointing to your cluster's external IP address.

The Ingress Controller typically relies upon a Load Balancer to listen on the public IP address and forward http/https traffic to the cluster nodes - as described in section [Deploy the Load Balancer](kubernetes-cluster-and-networking.md#3-deploy-the-load-balancer). 

A local single-node development cluster can be provisioned without the need for a Load Balancer - if the Ingress Controller can be configured to listen directly on the external IP address - or if external DNS routing is not required.

---

## Nginx Ingress Controller

### Ingress-Nginx As Cluster Entrypoint

The ingress controller runs as a NodePort service listening on the designated exposed ports `31080` (http) and `31443` (https).

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && \
helm repo update ingress-nginx && \
helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=31080 \
  --set controller.service.nodePorts.https=31443 \
  --set controller.ingressClassResource.default=true \
  --set controller.allowSnippetAnnotations=true
```

### Ingress-Nginx Behind Ingress Proxy

The ingress controller need not expose ports outside the cluster, so runs as a `ClusterIP` service that receives traffic via the Ingress Proxy.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && \
helm repo update ingress-nginx && \
helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=ClusterIP \
  --set controller.ingressClassResource.default=true \
  --set controller.allowSnippetAnnotations=true
```

### Uninstall Ingress-Nginx

```bash
helm -n ingress-nginx uninstall ingress-nginx; \
kubectl delete ns ingress-nginx
```

---

## APISIX Ingress Controller

### APISIX As Cluster Entrypoint

The ingress controller runs as a NodePort service listening on the designated exposed ports `31080` (http) and `31443` (https).

```bash
helm repo add apisix https://charts.apiseven.com && \
helm repo update apisix && \
helm upgrade -i apisix apisix/apisix \
  --version 2.9.0 \
  --namespace ingress-apisix --create-namespace \
  --set service.type=NodePort \
  --set service.http.nodePort=31080 \
  --set service.tls.nodePort=31443 \
  --set apisix.enableIPv6=false \
  --set apisix.enableServerTokens=false \
  --set apisix.ssl.enabled=true \
  --set ingress-controller.enabled=true
```

### APISIX Behind Ingress Proxy

The ingress controller need not expose ports outside the cluster, so it is not necessary to specify dedicated `NodePorts` for the service that receives traffic via the Ingress Proxy.

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

### Forced TLS Redirection

The following `ApisixGlobalRule` is used to configure Apisix to redirect all `http` traffic to `https`.

```bash
cat - <<'EOF' | kubectl -n ingress-apisix apply -f -
apiVersion: apisix.apache.org/v2
kind: ApisixGlobalRule
metadata:
  name: redirect-to-tls
spec:
  plugins:
    - name: redirect
      enable: true
      config:
        http_to_https: true
        _meta:
          filter:
            # With '!OR' all conditions must be false
            - "!OR"
            # Exclude paths used by letsencrypt http challenge
            - [ 'request_uri', '~*', '^/\.well-known/acme-challenge.*' ]
            # Use header X-No-Force-Tls to override
            - [ "http_x_no_force_tls", "==", "true" ]
EOF
```

For `filter` reference see:

* [Plugin Common Configuration](https://apisix.apache.org/docs/apisix/terminology/plugin/#plugin-common-configuration)
* [Expression Syntax](https://github.com/api7/lua-resty-expr?tab=readme-ov-file#comparison-operators)
* [Nginx Variable Reference](https://nginx.org/en/docs/varindex.html)

Note that, in principle, this `redirect` plugin with `http_to_https` can be used on individual `ApisixRoute` resources - rather than globally as above. However, it has been found that use of `http_to_https` on a specific route interferes with the `openid-connect` plugin that is also used for authentication. Hence the use of global `http_to_https` redirection.

### Uninstall APISIX

```bash
helm -n ingress-apisix uninstall apisix; \
kubectl delete ns ingress-apisix
```

---

## Ingress Proxy

The Ingress Proxy is provisioned as an nginx instance that is configured to pass through traffic to either `ingress-nginx` or to `apisix` depending on the requested hostname.<br>
See [nginx.conf (ConfigMap)](#configmap-nginxconf) for more details.

The Ingress Proxy deployment comprises the following elements...

* Namespace - using `ingress-proxy`
* ConfigMap - proxy configuration through the file `nginx.conf`
* Deployment - the proxy is implemented using `nginx`
* Service - as a `NodePort` service on the exposed ports `31080` / `31443`

### Namespace

```bash
kubectl create namespace ingress-proxy
```

### ConfigMap

Creates a `ConfigMap` containing the `nginx.conf` - to be mounted into the `Deployment`.

The `nginx.conf` configures the following rules to pass traffic through to the subordinate `ingress-nginx` and `apisix` controllers...

* `*-apx` prefixed hostname to `apisix` - e.g. `yourservice-apx.platform.domain`
* `*-ngx` prefixed hostname to `ingress-nginx` - e.g. `yourservice-ngx.platform.domain`

...with a catch-all default forwarding to `ingress-nginx`.

**_You can change the matching rules and the default upstream according to your needs._**

```bash
cat - <<'EOF' | kubectl -n ingress-proxy apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-proxy
data:
  nginx.conf: |
    events {}
    stream {
      resolver kube-dns.kube-system;
      map $ssl_preread_server_name $ssl_upstream {
        default "ingress-nginx-controller.ingress-nginx.svc.cluster.local:443";
        ~(?:^[^.]*)-ngx\..*$ "ingress-nginx-controller.ingress-nginx.svc.cluster.local:443";
        ~(?:^[^.]*)-apx\..*$ "apisix-gateway.ingress-apisix.svc.cluster.local:443";
      }
      server {
        listen 443 default_server;
        proxy_pass $ssl_upstream;
        ssl_preread on;
      }
    }
    http {
      resolver kube-dns.kube-system;
      map $host $upstream {
        default "ingress-nginx-controller.ingress-nginx.svc.cluster.local:80";
        ~(?:^[^.]*)-ngx\..*$ "ingress-nginx-controller.ingress-nginx.svc.cluster.local:80";
        ~(?:^[^.]*)-apx\..*$ "apisix-gateway.ingress-apisix.svc.cluster.local:80";
      }
      server {
        listen 80 default_server;
        location / {
          proxy_pass http://$upstream;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        }
      }
    }
EOF
```

### Deployment

Deploys `nginx` with the `nginx.conf` mounted via `ConfigMap`.

```bash
cat - <<'EOF' | kubectl -n ingress-proxy apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-proxy
  labels:
    app: ingress-proxy
spec:
  selector:
    matchLabels:
      app: ingress-proxy
  template:
    metadata:
      labels:
        app: ingress-proxy
    spec:
      containers:
        - name: nginx
          image: nginx
          volumeMounts:
            - name: ingress-proxy
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
      volumes:
        - name: ingress-proxy
          configMap:
            name: ingress-proxy
EOF
```

### Service

Creates a `Service` to expose the `nginx` instance as a `NodePort` service listening on the exposed ports `31080` (http) and `31443` (https).

This exposes the service for externally routed traffic - e.g. via cloud load balancer.

```bash
cat - <<'EOF' | kubectl -n ingress-proxy apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ingress-proxy
spec:
  selector:
    app: ingress-proxy
  type: NodePort
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 31080
    - name: https
      protocol: TCP
      port: 443
      targetPort: 443
      nodePort: 31443
EOF
```

### Uninstall Ingress Proxy

```bash
kubectl -n ingress-proxy delete svc ingress-proxy; \
kubectl -n ingress-proxy delete deploy ingress-proxy; \
kubectl -n ingress-proxy delete cm ingress-proxy; \
kubectl delete ns ingress-proxy
```

Then follow:

* [Uninstall Ingress-Nginx](#uninstall-ingress-nginx)
* [Uninstall APISIX](#uninstall-apisix)

---

## Validation

This section includes some simple steps to check the function of the ingress controller(s).

### Deploy a test service

```bash
kubectl run --image=kennethreitz/httpbin httpbin && \
kubectl expose pod httpbin --port 80
```

### Create ingress for test service

#### Via APISIX

```bash
echo -n "Enter your domain name: " && read your_domain && \
cat - <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: httpbin-apx
spec:
  ingressClassName: apisix
  rules:
    - host: httpbin-apx.$your_domain
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: httpbin
                port:
                  number: 80
EOF
```

**_Test by accessing the URL `http://httpbin-apx.<your-domain>` in your browser._**

#### Via Ingress-Nginx

```bash
echo -n "Enter your domain name: " && read your_domain && \
cat - <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: httpbin-ngx
spec:
  ingressClassName: nginx
  rules:
    - host: httpbin-ngx.$your_domain
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: httpbin
                port:
                  number: 80
EOF
```

**_Test by accessing the URL `http://httpbin-ngx.<your-domain>` in your browser._**

### Clean-up validation resources

```bash
kubectl delete ingress httpbin-apx 2>/dev/null; \
kubectl delete ingress httpbin-ngx 2>/dev/null; \
kubectl delete svc httpbin 2>/dev/null; \
kubectl delete pod httpbin 2>/dev/null
```

---

## Further Reading

- **Ingress-Nginx Controller**: [Documentation](https://kubernetes.github.io/ingress-nginx/)
- **APISIX Ingress Controller**: [Documentation](https://apisix.apache.org/docs/ingress-controller/getting-started/)
