# APISIX Ingress Controller

For full installation instructions for the APISIX Ingress Controller see the official [Installation Guide](https://apisix.apache.org/docs/apisix/installation-guide/).

!!! tip
    See also [Ingress Gateway](./gateway.md) for more advanced ingress scenarios.

## Quickstart Installation

!!! note "Disclaimer"
    We recommend following the official installation instructions for the APISIX Ingress Controller. However, this quick start guide should also work for most environments.

```bash
helm repo add apisix https://apache.github.io/apisix-helm-chart
helm repo update apisix
```

=== "NodePort Service"

    The deployment configuration below assumes that the Kubernetes cluster exposes NodePorts `31080` (http) and `31443` (https) for external access to the cluster. This presumes that a (cloud) load balancer or similar is configured to forward public `80/443` traffic to these exposed ports on the cluster nodes.

    ```bash
    cat - <<'EOF' | helm upgrade -i apisix apisix/apisix \
      --version 2.16.0 \
      --namespace ingress-apisix --create-namespace \
      -f -
    service:
      type: NodePort
      http:
        nodePort: 31080
      tls:
        nodePort: 31443
    apisix:
      enableIPv6: false
      enableServerTokens: false
      ssl:
        enabled: true
      pluginAttrs:
        redirect:
          https_port: 443
      deployment:
        role: traditional
        role_traditional:
          config_provider: yaml
      nginx:
        http:
          clientMaxBodySize: 10737418240
        configurationSnippet:
          httpStart: |
            # Large buffer sizes for handling large headers (e.g., auth tokens, OIDC flows etc.)
            proxy_buffer_size           32k;
            proxy_buffers               8 32k;
            proxy_busy_buffers_size     64k;
            large_client_header_buffers 4 32k;
    etcd:
      enabled: false
    ingress-controller:
      enabled: true
      config:
        provider:
          type: apisix-standalone
      gatewayProxy:
        createDefault: true
    EOF
    ```

    !!! note
        The value `apisix.nginx.http.clientMaxBodySize` is set to `10737418240` (10GB) to allow for large request bodies, which are required by some services such as minio, harbor, keycloak, others. Ordinarily the value would be set zero meaning unlimited. However testing has revealed that this 'zero' setting does not always have the expected 'unlimited' behaviour, so a large but finite value is used instead. Adjust this value if your environment requires a different limit.

    !!! warning
        The above configuration disables the `etcd` service (ref. `--set etcd.enabled=false`) and configures APISIX to use a standalone configuration provider (ref. `--set ingress-controller.config.provider.type=apisix-standalone`). If strongest low-latency config convergence under heavy churn is required, then etcd mode may prove more robust, with the tradeoff that you must run and operate Etcd (HA, backup, latency, etc.).

=== "LoadBalancer Service"

    ```bash
    cat - <<'EOF' | helm upgrade -i apisix apisix/apisix \
      --version 2.16.0 \
      --namespace ingress-apisix --create-namespace \
      -f -
    service:
      type: LoadBalancer
    apisix:
      enableIPv6: false
      enableServerTokens: false
      ssl:
        enabled: true
      pluginAttrs:
        redirect:
          https_port: 443
      deployment:
        role: traditional
        role_traditional:
          config_provider: yaml
      nginx:
        configurationSnippet:
          httpStart: |
            # Large buffer sizes for handling large headers (e.g., auth tokens, OIDC flows etc.)
            proxy_buffer_size           32k;
            proxy_buffers               8 32k;
            proxy_busy_buffers_size     64k;
            large_client_header_buffers 4 32k;
    etcd:
      enabled: false
    ingress-controller:
      enabled: true
      config:
        provider:
          type: apisix-standalone
      gatewayProxy:
        createDefault: true
    EOF
    ```

    !!! note
        This can be adapted according to the network topology of your cluster environment.

### Forced TLS Redirection (Optional)

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

!!! note
    The `filter` is used to suppress the redirection in the specific case of traffic used by the Letsencrypt HTTP01 challenge whilst establishing TLS certificates.

    Use of the header `X-No-Force-Tls` is included to provide an override that may prove useful in some circumstances or during development.

For `filter` reference see:

* [Plugin Common Configuration](https://apisix.apache.org/docs/apisix/terminology/plugin/#plugin-common-configuration)
* [Expression Syntax](https://github.com/api7/lua-resty-expr?tab=readme-ov-file#comparison-operators)

### Forwarded Port Correction (Optional)

By default, APISIX sets the `X-Forwarded-Port` header to its container port (`9443` by default) when forwarding requests. This may confuse upstream systems, because the externally facing https port is `443`.

Thus, we apply a global rule that replaces the value `9443` with the value `443`.<br>
_Actually the rule also replaces port `9080` with port `80` though this should be irrelevant due to prior HTTP-to-HTTPS redirection_

```bash
cat - <<'EOF' | kubectl -n ingress-apisix apply -f -
apiVersion: apisix.apache.org/v2
kind: ApisixGlobalRule
metadata:
  name: forwarded-port-correction
spec:
  plugins:
    - name: serverless-pre-function
      enable: true
      config:
        phase: "rewrite"
        functions:
          - "return function(conf, ctx) if tonumber(ngx.var.var_x_forwarded_port) > 9000 then ngx.var.var_x_forwarded_port = ngx.var.var_x_forwarded_port - 9000 end end"
EOF
```

## APISIX Uninstallation

```bash
helm -n ingress-apisix uninstall apisix
kubectl delete ns ingress-apisix
```
