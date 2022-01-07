# Resource Catalogue

The _Resource Catalogue_ provides a standards-based EO metadata catalogue that includes support for OGC CSW / API Records, STAC and OpenSearch.

## Helm Chart

The _Resource Catalogue_ is deployed via the `rm-resource-catalogue` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `rm-resource-catalogue` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-resource-catalogue#readme).

```bash
helm install --values resource-catalogue-values.yaml ades eoepca/rm-resource-catalogue
```

## Values

The Resource Catalogue supports many values to configure the service - as described in the [Values section of the chart README](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-resource-catalogue#values).

Typically, values for the following attributes may be specified:

* The fully-qualified public URL for the service
* Dynamic provisioning _StorageClass_ for database persistence
* (optional) Specification of Ingress for reverse-proxy access to the service<br>
  _Note that this is only required in the case that the Resource Catalogue will **not** be protected by the `resource-guard` component - ref. [Resource Protection](../resource-protection). Otherwise the ingress will be handled by the `resource-guard` - use `ingress.enabled: false`._
* Metadata describing the Catalogue instance

**Example `resource-catalogue-values.yaml`...**

```yaml
global:
  namespace: rm
ingress:
  enabled: true
  name: resource-catalogue
  host: resource-catalogue.192.168.49.123.nip.io
  tls_host: resource-catalogue.192.168.49.123.nip.io
  tls_secret_name: resource-catalogue-tls
db:
  volume_storage_type: standard
pycsw:
  # image:
  #   pullPolicy: Always
  #   tag: "eoepca-0.9.0"
  config:
    server:
      url: https://resource-catalogue.192.168.49.123.nip.io/
```

## Protection

As described in [section Resource Protection](../resource-protection), the `resource-guard` component can be inserted into the request path of the Resource Catalogue service to provide access authorization decisions

```bash
helm install --values resource-catalogue-guard-values.yaml resource-catalogue-guard eoepca/resource-guard
```

The `resource-guard` must be configured with the values applicable to the Resource Catalogue for the _Policy Enforcement Point_ (`pep-engine`) and the _UMA User Agent_ (`uma-user-agent`)...

**Example `resource-catalogue-guard-values.yaml`...**

```yaml
#---------------------------------------------------------------------------
# Global values
#---------------------------------------------------------------------------
global:
  context: resource-catalogue
  pep: resource-catalogue-pep
  domain: 192.168.49.123.nip.io
  nginxIp: 192.168.49.123
  certManager:
    clusterIssuer: letsencrypt-staging
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
  fullnameOverride: resource-catalogue-agent
  nginxIntegration:
    enabled: true
    hosts:
      - host: resource-catalogue
        paths:
          - path: /(.*)
            service:
              name: resource-catalogue-service
              port: 80
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      nginx.ingress.kubernetes.io/rewrite-target: /$1
  client:
    credentialsSecretName: "resman-client"
  logging:
    level: "info"
  unauthorizedResponse: 'Bearer realm="https://auth.192.168.49.123.nip.io/oxauth/auth/passport/passportlogin.htm"'
  openAccess: false
  insecureTlsSkipVerify: true
```

**NOTES:**

* TLS is enabled by the specification of `certManager.clusterIssuer`
* The `letsencrypt` Cluster Issuer relies upon the deployment being accessible from the public internet via the `global.domain` DNS name. If this is not the case, e.g. for a local minikube deployment in which this is unlikely to be so. In this case the TLS will fall-back to the self-signed certificate built-in to the nginx ingress controller
* `insecureTlsSkipVerify` may be required in the case that good TLS certificates cannot be established, e.g. if letsencrypt cannot be used for a local deployment. Otherwise the certificates offered by login-service _Authorization Server_ will fail validation in the _Resource Guard_.
* `customDefaultResources` can be specified to apply initial protection to the endpoint

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

The client credentials are obtained by registration of a client at the login service web interface - e.g. [https://auth.192.168.49.123.nip.io](https://auth.192.168.49.123.nip.io). In addition there is a helper script that can be used to create a basic client and obtain the credentials, as described in [section Resource Protection](../resource-protection/#client-registration)...
```bash
./local-deploy/bin/register-client auth.192.168.49.123.nip.io "Resource Guard" | tee client.yaml
```

## Resource Catalogue Usage

The Resource Catalogue is initially populated during the initialisation of the Data Access service.<br>
See section [Data-layer Configuration](data-access.md#data-layer-configuration).

The Resource Catalogue is accessed at the endpoint `https://resource-catalogue.<domain>/`, configured by your domain - e.g. [https://resource-catalogue.192.168.49.123.nip.io/](https://resource-catalogue.192.168.49.123.nip.io/).

## Additional Information

Additional information regarding the _Resource Catalogue_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-resource-catalogue)
* [Docs](TBD)
* [GitHub Repository](https://github.com/EOEPCA/rm-resource-catalogue)
