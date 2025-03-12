# Multiple Ingress Controllers

In some advanced scenarios, you may need multiple ingress controllers—for example, APISIX for IAM-related services, and NGINX for other external services.

Recognising that a platform may require use of an alternative ingress controller implementation, we offer an approach which may help to accommodate multiple controllers within the platform.

In this approach we introduce an _Ingress Proxy_ that acts as the cluster entrypoint - using hostname rules to passthrough to the relevant ingress controller. This provides an example that could be adapted to your needs.

The Ingress Proxy is configured as an nginx instance that is configured to pass through traffic according to hostname rules...

* By default forward to APISIX - ref. service `apisix-gateway`
* Hostname prefixed with `*-other` forwards to alternative ingress controller - for example service `ingress-nginx-controller`

### 1. Proxy ConfigMap

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

### 2. Proxy Deployment

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

### 3. Proxy Service (NodePorts)

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

### 4. Deploy APISIX Behind Proxy

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

### 5. Deploy NGINX Behind Proxy

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

### Uninstallation

- **Remove Ingress NGINX**:
    
```bash
helm -n ingress-nginx uninstall ingress-nginx
kubectl delete ns ingress-nginx
```

- **Remove Ingress Proxy**:
    
```bash
kubectl -n ingress-proxy delete svc ingress-proxy
kubectl -n ingress-proxy delete deploy ingress-proxy
kubectl -n ingress-proxy delete cm ingress-proxy
kubectl delete ns ingress-proxy
```
    
- **Remove APISIX** (if needed):
    
```bash
helm -n ingress-apisix uninstall apisix
kubectl delete ns ingress-apisix
```
