# Registration API

The _Registration API_ provides a REST API through which resources can be registered with both the Resource Catalogue and (as applicable) with the Data Access services.

## Helm Chart

The _Registration API_ is deployed via the `rm-registration-api` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `rm-registration-api` chart](https://github.com/EOEPCA/helm-charts/blob/main/charts/rm-registration-api/README.md).

```bash
helm install --version 1.3.0 --values registration-api-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  registration-api rm-registration-api
```

## Values

The Registration API supports many values to configure the service - as described in the [Values section of the chart README](https://github.com/EOEPCA/helm-charts/blob/main/charts/rm-registration-api/README.md#values).

Typically, values for the following attributes may be specified:

* The fully-qualified public URL for the service
* (optional) Specification of Ingress for reverse-proxy access to the service<br>
  _Note that this is only required in the case that the Registration API will **not** be protected by the `resource-guard` component - ref. [Resource Protection](resource-protection-gluu.md). Otherwise the ingress will be handled by the `resource-guard` - use `ingress.enabled: false`._
* Values for integration with the workspace-api and data-access services

**Example `registration-api-values.yaml`...**

```yaml
fullnameOverride: registration-api
# image: # {}
  # repository: eoepca/rm-registration-api
  # pullPolicy: Always
  # Overrides the image tag whose default is the chart appVersion.
  # tag: "1.3-dev1"

ingress:
  enabled: false
  hosts:
    - host: registration-api-open.192-168-49-2.nip.io
      paths: ["/"]
  tls:
    - hosts:
        - registration-api-open.192-168-49-2.nip.io
      secretName: registration-api-tls

# some values for the workspace API
workspaceK8sNamespace: rm
redisServiceName: "data-access-redis-master"
```

## Protection

As described in [section Resource Protection (Keycloak)](resource-protection-keycloak.md), the `identity-gatekeeper` component can be inserted into the request path of the `registration-api` service to provide access authorization decisions

### Gatekeeper

Gatekeeper is deployed using its helm chart...

```bash
helm install registration-api-protection identity-gatekeeper -f registration-api-protection-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  --namespace "rm" --create-namespace \
  --version 1.0.11
```

The `identity-gatekeeper` must be configured with the values applicable to the `registration-api` - in particular the specific ingress requirements for the `registration-api` backend service...

**Example `registration-api-protection-values.yaml`...**

```yaml
fullnameOverride: registration-api-protection
config:
  client-id: registration-api
  discovery-url: http://identity.keycloak.192-168-49-2.nip.io/realms/master
  cookie-domain: 192-168-49-2.nip.io
targetService:
  host: registration-api.192-168-49-2.nip.io
  name: registration-api
  port:
    number: 8080
secrets:
  # Values for secret 'registration-api-protection'
  # Note - if ommitted, these can instead be set by creating the secret independently.
  clientSecret: "changeme"
  encryptionKey: "changemechangeme"
ingress:
  enabled: true
  className: nginx
  annotations:
    ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-production
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/enable-cors: "true"
  serverSnippets:
    custom: |-
      # Open access...
      location ~ ^/ {
        proxy_pass {{ include "identity-gatekeeper.targetUrl" . }}$request_uri;
      }
```

### Keycloak Client

The Gatekeeper instance relies upon an associated client configured within Keycloak - ref. `client-id: registration-api` above.

This can be created with the `create-client` helper script, as descirbed in section [Client Registration](./resource-protection-keycloak.md#client-registration).

For example...

```bash
../bin/create-client \
  -a http://identity.keycloak.192-168-49-2.nip.io \
  -i http://identity-api-protected.192-168-49-2.nip.io \
  -r "master" \
  -u "admin" \
  -p "changeme" \
  -c "admin-cli" \
  --id=registration-api \
  --name="Registration API Gatekeeper" \
  --secret="changeme" \
  --description="Client to be used by Registration API Gatekeeper"
```

## Additional Information

Additional information regarding the _Registration API_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-registration-api)
* [GitHub Repository](https://github.com/EOEPCA/rm-registration-api)
