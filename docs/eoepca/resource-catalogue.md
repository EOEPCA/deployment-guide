# Resource Catalogue

The _Resource Catalogue_ provides a standards-based EO metadata catalogue that includes support for OGC CSW / API Records, STAC and OpenSearch.

## Helm Chart

The _Resource Catalogue_ is deployed via the `rm-resource-catalogue` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `rm-resource-catalogue` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-resource-catalogue#readme).

```bash
helm install --version 1.3.1 --values resource-catalogue-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  resource-catalogue rm-resource-catalogue
```

## Values

The Resource Catalogue supports many values to configure the service - as described in the [Values section of the chart README](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-resource-catalogue#values).

Typically, values for the following attributes may be specified:

* The fully-qualified public URL for the service
* Dynamic provisioning _StorageClass_ for database persistence
* (optional) Specification of Ingress for reverse-proxy access to the service<br>
  _Note that this is only required in the case that the Resource Catalogue will **not** be protected by the `resource-guard` component - ref. [Resource Protection](../resource-protection). Otherwise the ingress will be handled by the `resource-guard` - use `ingress.enabled: false`._
* Metadata describing the Catalogue instance
* Tuning configuration for PostgreSQL - see values `db.config.XXX`.

**Example `resource-catalogue-values.yaml`...**

```yaml
global:
  namespace: rm
# For protected access disable this ingress, and rely upon the resource-guard
# for ingress with protection.
ingress:
  # Enabled for unprotected 'open' access to the resource-catalogue.
  enabled: true
  name: resource-catalogue
  host: resource-catalogue.192-168-49-2.nip.io
  tls_host: resource-catalogue.192-168-49-2.nip.io
  tls_secret_name: resource-catalogue-tls
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
db:
  volume_storage_type: standard
  # config:
  #   enabled: true
  #   shared_buffers: 2GB
  #   effective_cache_size: 6GB
  #   maintenance_work_mem: 512MB
  #   checkpoint_completion_target: 0.9
  #   wal_buffers: 16MB
  #   default_statistics_target: 100
  #   random_page_cost: 4
  #   work_mem: 4MB
  #   cpu_tuple_cost: 0.4
pycsw:
  config:
    server:
      url: https://resource-catalogue.192-168-49-2.nip.io/
    manager:
      transactions: "true"
      allowed_ips: "*"
```

!!! note
    The above example values enable transactions (write-access) to the catalogue from any IP address. This is convenient for testing/demonstration of the capability, but should be disbaled or restricted for operational deployments.

## Protection

As described in [section Resource Protection](../resource-protection), the `resource-guard` component can be inserted into the request path of the Resource Catalogue service to provide access authorization decisions

```bash
helm install --version 1.3.1 --values resource-catalogue-guard-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  resource-catalogue-guard resource-guard
```

The `resource-guard` must be configured with the values applicable to the Resource Catalogue for the _Policy Enforcement Point_ (`pep-engine`) and the _UMA User Agent_ (`uma-user-agent`)...

**Example `resource-catalogue-guard-values.yaml`...**

```yaml
#---------------------------------------------------------------------------
# Global values
#---------------------------------------------------------------------------
global:
  context: resource-catalogue
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
  unauthorizedResponse: 'Bearer realm="https://portal.192-168-49-2.nip.io/oidc/authenticate/"'
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

The client credentials are obtained by registration of a client at the login service web interface - e.g. [https://auth.192-168-49-2.nip.io](https://auth.192-168-49-2.nip.io). In addition there is a helper script that can be used to create a basic client and obtain the credentials, as described in [section Resource Protection](../resource-protection/#client-registration)...
```bash
./deploy/bin/register-client auth.192-168-49-2.nip.io "Resource Guard" | tee client.yaml
```

## Resource Catalogue Usage

The Resource Catalogue is initially populated during the initialisation of the Data Access service.<br>
See section [Data-layer Configuration](../data-access/#data-layer-configuration).

The Resource Catalogue is accessed at the endpoint `https://resource-catalogue.<domain>/`, configured by your domain - e.g. [https://resource-catalogue.192-168-49-2.nip.io/](https://resource-catalogue.192-168-49-2.nip.io/).

### Loading Records

As described in the [pycsw documentation](https://docs.pycsw.org/en/2.6.1/administration.html#loading-records), ISO XML records can be loaded into the resource-catalogue using the `pycsw-admin.py` admin utility...

```bash
pycsw-admin.py load_records -c /path/to/cfg -p /path/to/records
```

The `/path/to/records` can either be a single metadata file, or a directory containing multiple metadata files.

This is most easily achieved via connection to the pycsw pod, which includes the `pycsw-admin.py` utility and the pycsw configuration file at `/etc/pycsw/pycsw.cfg`...

```bash
kubectl -n rm cp "<metadata-file-or-directory>" "<pycsw-pod-name>":/tmp/metadata
kubectl -n rm exec -i "<pycsw-pod-name>" -- pycsw-admin.py load-records -c /etc/pycsw/pycsw.cfg -p /tmp/metadata
```

The name of the pycsw pod can be obtained using `kubectl`...

```bash
kubectl -n rm get pod --selector='io.kompose.service=pycsw' --output=jsonpath={.items[0].metadata.name}
```

To facilitate the loading of records via the pycsw pod, a helper script [`load-records`](https://raw.githubusercontent.com/EOEPCA/deployment-guide/main/deploy/bin/load-records) has been provided in the [git repository that hosts this document](https://github.com/EOEPCA/deployment-guide)...

```bash
git clone git@github.com:EOEPCA/deployment-guide
cd deployment-guide
./deploy/bin/load-records "<metadata-file-or-directory>"
```

The helper script identifies the pycsw pod, copies the metadata files to the pod, and runs `pycsw-admin.py load-records` within the pod to load the records.

## Additional Information

Additional information regarding the _Resource Catalogue_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-resource-catalogue)
* [pycsw Documentation](https://docs.pycsw.org/en/latest/)
* [GitHub Repository](https://github.com/EOEPCA/rm-resource-catalogue)
