# Resource Catalogue

The _Resource Catalogue_ provides a standards-based EO metadata catalogue that includes support for OGC CSW / API Records, STAC and OpenSearch.

## Helm Chart

The _Resource Catalogue_ is deployed via the `rm-resource-catalogue` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `rm-resource-catalogue` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-resource-catalogue#readme).

```bash
helm install --version 1.4.0 --values resource-catalogue-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  resource-catalogue rm-resource-catalogue
```

## Values

The Resource Catalogue supports many values to configure the service - as described in the [Values section of the chart README](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-resource-catalogue#values).

Typically, values for the following attributes may be specified:

* The fully-qualified public URL for the service
* Dynamic provisioning _StorageClass_ for database persistence
* (optional) Specification of Ingress for reverse-proxy access to the service<br>
  _Note that this is only required in the case that the Resource Catalogue will **not** be protected by the `identity-gatekeeper` component - ref. [Resource Protection](./resource-protection-keycloak.md). Otherwise the ingress will be handled by the `identity-gatekeeper` - use `ingress.enabled: false`._
* Metadata describing the Catalogue instance
* Tuning configuration for PostgreSQL - see values `db.config.XXX`.

**Example `resource-catalogue-values.yaml`...**

```yaml
global:
  namespace: rm
# For protected access disable this ingress, and rely upon the identity-gatekeeper
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

As described in [section Resource Protection (Keycloak)](resource-protection-keycloak.md), the `identity-gatekeeper` component can be inserted into the request path of the `resource-catalogue` service to provide access authorization decisions

### Gatekeeper

Gatekeeper is deployed using its helm chart...

```bash
helm install resource-catalogue-protection identity-gatekeeper -f resource-catalogue-protection-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  --namespace "rm" --create-namespace \
  --version 1.0.11
```

The `identity-gatekeeper` must be configured with the values applicable to the `resource-catalogue` - in particular the specific ingress requirements for the `resource-catalogue-service`...

**Example `resource-catalogue-protection-values.yaml`...**

```yaml
fullnameOverride: resource-catalogue-protection
config:
  client-id: resource-catalogue
  discovery-url: https://keycloak.192-168-49-2.nip.io/realms/master
  cookie-domain: 192-168-49-2.nip.io
targetService:
  host: resource-catalogue.192-168-49-2.nip.io
  name: resource-catalogue-service
  port:
    number: 80
secrets:
  # Values for secret 'resource-catalogue-protection'
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

The Gatekeeper instance relies upon an associated client configured within Keycloak - ref. `client-id: resource-catalogue` above.

This can be created with the `create-client` helper script, as descirbed in section [Client Registration](./resource-protection-keycloak.md#client-registration).

For example...

```bash
../bin/create-client \
  -a https://keycloak.192-168-49-2.nip.io \
  -i https://identity-api.192-168-49-2.nip.io \
  -r "master" \
  -u "admin" \
  -p "changeme" \
  -c "admin-cli" \
  --id=resource-catalogue \
  --name="Resource Catalogue Gatekeeper" \
  --secret="changeme" \
  --description="Client to be used by Resource Catalogue Gatekeeper"
```

## Resource Catalogue Usage

The Resource Catalogue is initially populated during the initialisation of the Data Access service.<br>
See section [Data-layer Configuration](data-access.md#data-layer-configuration).

The Resource Catalogue is accessed at the endpoint `https://resource-catalogue.192-168-49-2.nip.io/`, configured by your domain - e.g. [https://resource-catalogue.192-168-49-2.nip.io/](https://resource-catalogue.192-168-49-2.nip.io/).

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

To facilitate the loading of records via the pycsw pod, a helper script [`load-records`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.4/deploy/bin/load-records) has been provided in the [git repository that hosts this document](https://github.com/EOEPCA/deployment-guide/tree/eoepca-v1.4)...

```bash
git clone -b eoepca-v1.4 git@github.com:EOEPCA/deployment-guide
cd deployment-guide
./deploy/bin/load-records "<metadata-file-or-directory>"
```

The helper script identifies the pycsw pod, copies the metadata files to the pod, and runs `pycsw-admin.py load-records` within the pod to load the records.

## Additional Information

Additional information regarding the _Resource Catalogue_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/rm-resource-catalogue)
* [pycsw Documentation](https://docs.pycsw.org/en/latest/)
* [GitHub Repository](https://github.com/EOEPCA/rm-resource-catalogue)
