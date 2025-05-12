
# Ingress and DNS Requirements

Access to the EOEPCA BB services is provided via an ingress controller that acts as a reverse proxy. Proxy routes are configured using host-based routing that relies upon wildcard DNS to resolve traffic to the platform domain (e.g. `*.myplatform.com`). Thus, an ingress controller that supports these features is required.

The EOEPCA+ Identity and Access Management (IAM) solution advocates use of the APISIX Ingress Controller, which offers native integration of IAM request authorisation - which, for example, integrates with Keycloak via OIDC (authentication) and UMA (authorisation) flows. Thus, following description of the general requirements for cluster ingress, a guide is provided for [deployment of APISIX](#apisix-ingress-controller).

**Requirements:**

- **Wildcard DNS**: You must have a wildcard DNS entry pointing to your cluster's load balancer or external IP. For example: `*.myplatform.com`.<br>
  _For testing, wildcard DNS can be simulated using IP-address-based `nip.io` hostnames - using the entrypoint IP-address of your cluster that routes to your ingress controller._
- **Ingress Controller**: APISIX is recommended for use with the EOEPCA+ IAM soluiton; others such as NGINX can also be used if the IAM integration is not of interest

**Production vs Development:**

- **Production**:  
    - Ensure a stable and supported ingress controller (e.g. APISIX) exposed through a routable IP address
    - A fully functional wildcard DNS record
  
- **Development / Testing**:  
    - Can be exposed through a private IP address
    - Local or makeshift DNS solutions (e.g. nip.io) might be acceptable for internal development/test/demo

## Additional Notes

- **Wildcard DNS**: You must have a wildcard DNS entry pointing to your cluster's load balancer or external IP. For example: `*.myplatform.com`.<br>
  _For testing, wildcard DNS can be simulated using IP-address-based `nip.io` hostnames - using the entrypoint IP-address of your cluster that routes to your ingress controller._

- **Ingress Class**: Specify the ingress class in your ingress resources for example `apisix` for APISIX, `nginx` for NGINX.

## Further Reading

- **Kubernetes Ingress Concepts**: [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- **APISIX Documentation**: [APISIX Ingress Controller](https://apisix.apache.org/docs/ingress-controller/)
- **NGINX Documentation**: [Ingress-NGINX Controller](https://kubernetes.github.io/ingress-nginx/)

## APISIX Ingress Controller

For full installation instructions for the APISIX Ingress Controller see the official [Installation Guide](https://apisix.apache.org/docs/apisix/installation-guide/).

As a quick start, the steps included here can be followed to deploy the APISIX Ingress Controller via helm chart...

```bash
helm repo add apisix https://charts.apiseven.com
helm repo update apisix
helm upgrade -i apisix apisix/apisix \
  --version 2.9.0 \
  --namespace ingress-apisix --create-namespace \
  --set service.type=NodePort \
  --set service.http.nodePort=31080 \
  --set service.tls.nodePort=31443 \
  --set apisix.enableIPv6=false \
  --set apisix.enableServerTokens=false \
  --set apisix.ssl.enabled=true \
  --set apisix.pluginAttrs.redirect.https_port=443 \
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

**Forwarded Port Correction**

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

**APISIX Uninstallation**

APISIX can be uninstalled as follows...

```bash
helm -n ingress-apisix uninstall apisix
kubectl delete ns ingress-apisix
```
