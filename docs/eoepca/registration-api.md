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

As described in [section Resource Protection](resource-protection-gluu.md), the `resource-guard` component can be inserted into the request path of the Registration API service to provide access authorization decisions

```bash
helm install --version 1.3.1 --values registration-api-guard-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  registration-api-guard resource-guard
```

The `resource-guard` must be configured with the values applicable to the Registration API for the _Policy Enforcement Point_ (`pep-engine`) and the _UMA User Agent_ (`uma-user-agent`)...

**Example `registration-api-guard-values.yaml`...**

```yaml
#---------------------------------------------------------------------------
# Global values
#---------------------------------------------------------------------------
global:
  context: registration-api
  domain: 192-168-49-2.nip.io
  nginxIp: 192.168.49.2
  certManager:
    clusterIssuer: letsencrypt-production
#---------------------------------------------------------------------------
# PEP values
#---------------------------------------------------------------------------
pep-engine:
  configMap:
    asHostname: auth
    pdpHostname: auth
  volumeClaim:
    name: eoepca-resman-pvc
    create: false
#---------------------------------------------------------------------------
# UMA User Agent values
#---------------------------------------------------------------------------
uma-user-agent:
  nginxIntegration:
    enabled: true
    hosts:
      - host: registration-api
        paths:
          - path: /(.*)
            service:
              name: registration-api
              port: 8080
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      nginx.ingress.kubernetes.io/rewrite-target: /$1
  client:
    credentialsSecretName: "resman-client"
  logging:
    level: "info"
  unauthorizedResponse: 'Bearer realm="https://portal.192-168-49-2.nip.io/oidc/authenticate/"'
  openAccess: true
  insecureTlsSkipVerify: true
```

!!! note
    * TLS is enabled by the specification of `certManager.clusterIssuer`
    * The `letsencrypt` Cluster Issuer relies upon the deployment being accessible from the public internet via the `global.domain` DNS name. If this is not the case, e.g. for a local minikube deployment in which this is unlikely to be so. In this case the TLS will fall-back to the self-signed certificate built-in to the nginx ingress controller
    * `insecureTlsSkipVerify` may be required in the case that good TLS certificates cannot be established, e.g. if letsencrypt cannot be used for a local deployment. Otherwise the certificates offered by login-service _Authorization Server_ will fail validation in the _Resource Guard_.
    * `customDefaultResources` can be specified to apply initial protection to the endpoint
    * In the example above `openAccess: true` has been specified, meaning that policy envorcement is skipped and all access is allowed

### Client Secret

The Resource Guard requires confidential client credentials to be configured through the file `client.yaml`, delivered via a kubernetes secret..

**Example `client.yaml`...**

```yaml
client-id: a98ba66e-e876-46e1-8619-5e130a38d1a4
client-secret: 73914cfc-c7dd-4b54-8807-ce17c3645558
```

**Example `Secret`...**

```bash
kubectl -n rm create secret generic resman-client \
  --from-file=client.yaml \
  --dry-run=client -o yaml \
  > resman-client-secret.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: resman-client
  namespace: rm
data:
  client.yaml: Y2xpZW50LWlkOiBhOThiYTY2ZS1lODc2LTQ2ZTEtODYxOS01ZTEzMGEzOGQxYTQKY2xpZW50LXNlY3JldDogNzM5MTRjZmMtYzdkZC00YjU0LTg4MDctY2UxN2MzNjQ1NTU4
```

The client credentials are obtained by registration of a client at the login service web interface - e.g. [https://auth.192-168-49-2.nip.io](https://auth.192-168-49-2.nip.io). In addition there is a helper script that can be used to create a basic client and obtain the credentials, as described in [section Resource Protection](resource-protection-gluu.md#client-registration)...
```bash
./deploy/bin/register-client auth.192-168-49-2.nip.io "Resource Guard" | tee client.yaml
```

## Additional Information

Additional information regarding the _Registration API_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-registration-api)
* [GitHub Repository](https://github.com/EOEPCA/rm-registration-api)
