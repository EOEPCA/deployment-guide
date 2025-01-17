
# Ingress and DNS Requirements

Access to the EOEPCA BB services is provided via an ingress controller that acts as a reverse proxy. Proxy routes are configured using host-based routing that relies upon wildcard DNS to resolve traffic to the platform domain (e.g. `*.myplatform.com`). Thus, an ingress controller that supports these features is required.

The EOEPCA+ Identity and Access Management (IAM) solution advocates use of the APISIX Ingress Controller, which offers native integration of IAM request authorisation - which, for example, integrates with Keycloak via OIDC (authentication) and UMA (authorisation) flows. Thus, following description of the general requirements for cluster ingress, a guide is provided for [deployment of APISIX](#apisix-ingress-controller).

**Requirements:**

- **Wildcard DNS**: You must have a wildcard DNS entry pointing to your cluster’s load balancer or external IP. For example: `*.myplatform.com`.
- **Ingress Controller**: APISIX is recommended for use with the EOEPCA+ IAM soluiton; others such as NGINX can also be used if the IAM integration is not of interest

**Production vs Development:**

- **Production**:  
    - Ensure a stable and supported ingress controller (e.g. APISIX) exposed through a routable IP address
    - A fully functional wildcard DNS record
  
- **Development / Testing**:  
    - Can be exposed through a private IP address
    - Local or makeshift DNS solutions (e.g. nip.io) might be acceptable for internal development/test/demo

## Additional Notes

- **Wildcard DNS**: Ensure a wildcard DNS record is configured for your domain.
- **Ingress Class**: Specify the ingress class in your ingress resources for example `apisix` for APISIX, `nginx` for NGINX.

## Further Reading

- **Kubernetes Ingress Concepts**: [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- **APISIX Documentation**: [APISIX Ingress Controller](https://apisix.apache.org/docs/ingress-controller/)
- **NGINX Documentation**: [Ingress-NGINX Controller](https://kubernetes.github.io/ingress-nginx/)

## APISIX Ingress Controller

For full installation instructions for the APISIX Ingress Controller see the official [Installation Guide](https://apisix.apache.org/docs/apisix/installation-guide/).

As a quick start, the steps included here can be followed to deploy the APISIX Ingress Controller via helm chart...

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

> The above configuration assumes that the Kubernetes cluster exposes NodePorts 31080 (http) and 31443 (https) for external access to the cluster. This presumes that a (cloud) load balancer or similar is configured to forward public 80/443 traffic to these exposed ports on the cluster nodes.

> This can be adapted according to the network topology of your cluster environment.

**Forced TLS Redirection**

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

> The `filter` is used to suppress the redirection in the specific case of traffic used by the Letsencrypt HTTP01 challenge whilst establishing TLS certificates.<br>
> Use of the header `X-No-Force-Tls` is included to provide an override that may prove useful in some circumstances or during development.

For `filter` reference see:

* [Plugin Common Configuration](https://apisix.apache.org/docs/apisix/terminology/plugin/#plugin-common-configuration)
* [Expression Syntax](https://github.com/api7/lua-resty-expr?tab=readme-ov-file#comparison-operators)

**APISIX Uninstallation**

APISIX can be uninstalled as follows...

```bash
helm -n ingress-apisix uninstall apisix
kubectl delete ns ingress-apisix
```

## Multiple Ingress Controllers

Recognising that a platform may require use of an alternative ingress controller implementation, we offer an approach which may help to accommodate multiple controllers within the platform.

In this approach we introduce an _Ingress Proxy_ that acts as the cluster entrypoint - using hostname rules to passthrough to the relevant ingress controller. This provides an example that could be adapted to your needs.

The Ingress Proxy is configured as an nginx instance that is configured to pass through traffic according to hostname rules...

* By default forward to APISIX - ref. service `apisix-gateway`
* Hostname prefixed with `*-other` forwards to alternative ingress controller - for example service `ingress-nginx-controller`

**Ingress Proxy - ConfigMap**

Ingress Proxy configuration, using `ingress-nginx-controller` as example of the `other` ingress controller.

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
        default "apisix-gateway.ingress-apisix.svc.cluster.local:443";
        ~(?:^[^.]*)-other\..*$ "ingress-nginx-controller.ingress-nginx.svc.cluster.local:443";
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
        default "apisix-gateway.ingress-apisix.svc.cluster.local:80";
        ~(?:^[^.]*)-other\..*$ "ingress-nginx-controller.ingress-nginx.svc.cluster.local:80";
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

**Ingress Proxy - Deployment**

Instantiates the _Ingress Proxy_ configured via the `ConfigMap`.

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

**Ingress Proxy - Service**

Creates a `Service` to expose the nginx instance as a `NodePort` service listening on the exposed ports `31080` (http) and `31443` (https) - i.e. using the previously assumed ports exposed by the cluster.

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

**APISIX Behind Proxy**

With the _Ingress Proxy_ providing the cluster entrypoint, the APISIX deployment is adjusted to no longer listen on the exposed ports.

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

**Ingress Nginx Behind Proxy**

To complete the example, `ingress-nginx` can be deployed to handle the `other` traffic.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && \
helm repo update ingress-nginx && \
helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=ClusterIP \
  --set controller.ingressClassResource.default=true \
  --set controller.allowSnippetAnnotations=true
```

The example `ingress-nginx` can be uninstalled with...

```bash
helm -n ingress-nginx uninstall ingress-nginx; \
kubectl delete ns ingress-nginx
```

**Ingress Proxy - Uninstallation**

The Ingress Proxy can be uninstalled as follows...

```bash
kubectl -n ingress-proxy delete svc ingress-proxy
kubectl -n ingress-proxy delete deploy ingress-proxy
kubectl -n ingress-proxy delete cm ingress-proxy
kubectl delete ns ingress-proxy
```
