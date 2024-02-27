# Data Access

The _Data Access_ provides standards-based services for access to platform hosted data - including OGC WMS/WMTS for visualisation, and OGC WCS for data retrieval. This component also includes _Harvester_ and _Registrar_ services to discover/watch the existing data holding of the infrastructure data layer and populate/maintain the _data access_ and _resource catalogue_ services accordingly.

## Helm Chart

The _Data Access_ is deployed via the `data-access` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are supplied with the instantiation of the helm release. The EOEPCA `data-access` chart provides a thin wrapper around the EOX View Server (`vs`) helm chart. The documentation for the View Server can be found here:

* User Guide: [https://vs.pages.eox.at/documentation/user/main/](https://vs.pages.eox.at/documentation/user/main/)
* Operator Guide: [https://vs.pages.eox.at/documentation/operator/main/](https://vs.pages.eox.at/documentation/operator/main/)

```bash
helm install --version 1.4.0 --values data-access-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  data-access data-access
```

## Values

The Data Access supports many values to configure the service. These are documented in full in the [View Server - Operator Guide Configuration page](https://vs.pages.eox.at/documentation/operator/main/k8s.html#helm-configuration-reference).

### Core Configuration

Typically, values for the following attributes may be specified to override the chart defaults:

* The fully-qualified public URL for the service, ref. (`global.ingress.hosts.host[0]`)
* Metadata describing the service instance
* Dynamic provisioning _StorageClass_ for persistence
* Persistent Volume Claims for `database` and `redis` components
* Object storage details for `data` and `cache`
* Container images for `renderer` and `registrar`
* (optional) Specification of Ingress for reverse-proxy access to the service<br>
  _Note that this is only required in the case that the Data Access will **not** be protected by the `identity-gatekeeper` component - ref. [Resource Protection](./resource-protection-keycloak.md). Otherwise the ingress will be handled by the `identity-gatekeeper` - use `ingress.enabled: false`._

```yaml
global:
  env:
    REGISTRAR_REPLACE: "true"
    CPL_VSIL_CURL_ALLOWED_EXTENSIONS: .TIF,.tif,.xml,.jp2,.jpg,.jpeg
    AWS_ENDPOINT_URL_S3: https://minio.192-168-49-2.nip.io
    AWS_HTTPS: "FALSE"
    startup_scripts:
      - /registrar_pycsw/registrar_pycsw/initialize-collections.sh
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: "true"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      cert-manager.io/cluster-issuer: letsencrypt-production
    hosts:
      - host: data-access.192-168-49-2.nip.io
    tls:
      - hosts:
          - data-access.192-168-49-2.nip.io
        secretName: data-access-tls
  storage:
    data:
      data:
        type: S3
        endpoint_url: http://data.cloudferro.com
        access_key_id: access
        secret_access_key: access
        region_name: RegionOne
        validate_bucket_name: false
    cache:
      type: S3
      endpoint_url: "https://minio.192-168-49-2.nip.io"
      host: "minio.192-168-49-2.nip.io"
      access_key_id: xxx
      secret_access_key: xxx
      region: us-east-1
      bucket: cache-bucket
  metadata:
    title: EOEPCA Data Access Service developed by EOX
    abstract: EOEPCA Data Access Service developed by EOX
    header: "EOEPCA Data Access View Server (VS) Client powered by <a href=\"//eox.at\"><img src=\"//eox.at/wp-content/uploads/2017/09/EOX_Logo.svg\" alt=\"EOX\" style=\"height:25px;margin-left:10px\"/></a>"
    url: https://data-access.192-168-49-2.nip.io/ows
  layers:
    # see section 'Data-layer Configuration'
  collections:
    # see section 'Data-layer Configuration'
  productTypes:
    # see section 'Data-layer Configuration'
vs:
  renderer:
    replicaCount: 4
    ingress:
      enabled: false
    resources:
      requests:
        cpu: 100m
        memory: 300Mi
      limits:
        cpu: 1.5
        memory: 3Gi
  registrar:
    replicaCount: 1
    config:
      # see section 'Registrar Routes Configuration'
    resources:
      requests:
        cpu: 100m
        memory: 100Mi
  harvester:
    # see section 'Harvester Configuration'
    replicaCount: 1
    resources:
      requests:
        cpu: 100m
        memory: 100Mi
  client:
    replicaCount: 1
    ingress:
      enabled: false
  redis:
    master:
      persistence:
        enabled: true
        storageClass: standard
  ingestor:
    replicaCount: 0
    ingress:
      enabled: false
  preprocessor:
    replicaCount: 0
  cache:
    ingress:
      enabled: false
  scheduler:
    resources:
      requests:
        cpu: 100m
        memory: 100Mi
```

!!! note
    The `resources:` above have been limited for the benefit of a minikube deployment. For a production deployment the values should be tuned (upwards) according to operational needs.

### Registrar Routes Configuration

The Data Access `registrar` component supports a number of different resource types. For each a dedicated 'backend' is configured to handle the specific registration of the resource type...

```
vs:
  registrar:
    config:
      #--------------
      # Default route
      #--------------
      disableDefaultRoute: false
      # Additional backends for the default route
      defaultBackends:
        - path: registrar_pycsw.backend.ItemBackend
          kwargs:
            repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw
            ows_url: https://data-access.192-168-49-2.nip.io/ows
      defaultSuccessQueue: seed_queue
      #----------------
      # Specific routes
      #----------------
      routes:
        collections:
          path: registrar.route.stac.CollectionRoute
          queue: register_collection_queue
          replace: true
          backends:
            - path: registrar_pycsw.backend.CollectionBackend
              kwargs:
                repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw
        ades:
          path: registrar.route.json.JSONRoute
          queue: register_ades_queue
          replace: true
          backends:
            - path: registrar_pycsw.backend.ADESBackend
              kwargs:
                repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw
        application:
          path: registrar.route.json.JSONRoute
          queue: register_application_queue
          replace: true
          backends:
            - path: registrar_pycsw.backend.CWLBackend
              kwargs:
                repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw
        catalogue:
          path: registrar.route.json.JSONRoute
          queue: register_catalogue_queue
          replace: true
          backends:
            - path: registrar_pycsw.backend.CatalogueBackend
              kwargs:
                repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw
        json:
          path: registrar.route.json.JSONRoute
          queue: register_json_queue
          replace: true
          backends:
            - path: registrar_pycsw.backend.JSONBackend
              kwargs:
                repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw
        xml:
          path: registrar.route.json.JSONRoute
          queue: register_xml_queue
          replace: true
          backends:
            - path: registrar_pycsw.backend.XMLBackend
              kwargs:
                repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw
```

### Data-layer Configuration

Configuration of the service data-layer - as described in the [View Server Operator Guide](https://vs.pages.eox.at/documentation/operator/main/configuration.html#helm-configuration-variables). 


The data-access service data handling is configured by definition of `productTypes`, `collections` and `layers`...

* `productTypes` - [Product Types](https://vs.pages.eox.at/documentation/operator/main/configuration.html#product-types-producttypes)<br>
  Identify the underlying file assets as WCS coverages and their visual representation
* `collections` - [Data Collections](https://vs.pages.eox.at/documentation/operator/main/configuration.html#data-collections-collections)<br>
  Provides groupings into which products are organised
* `layers` - [Layers](https://vs.pages.eox.at/documentation/operator/main/configuration.html#layers-layers)<br>
  Specifies the hoe the product visual representations are exposed through the WMS service

For more information, see the worked example in section [Data Specification](../quickstart/creodias-deployment.md#data-specification) for the [example CREODIAS deployment](../quickstart/creodias-deployment.md).

### Harvester

The Data Access service includes a Harvester component. The following subsections describe its configuration and usage.

#### Harvester Helm Configuration

The Harvester can be configured through the helm chart values...

```yaml
vs:
  harvester:
    replicaCount: 1
    config:
      redis:
        host: data-access-redis-master
        port: 6379
      harvesters:
        - name: Creodias-Opensearch
          resource:
            url: https://datahub.creodias.eu/resto/api/collections/Sentinel2/describe.xml
            type: OpenSearch
            format_config:
              type: 'application/json'
              property_mapping:
                start_datetime: 'startDate'
                end_datetime: 'completionDate'
                productIdentifier: 'productIdentifier'
            query:
              time:
                property: sensed
                begin: 2019-09-10T00:00:00Z
                end: 2019-09-11T00:00:00Z
              collection: null
              bbox: 14.9,47.7,16.4,48.7
          filter: {}
          postprocess:
            - type: harvester_eoepca.postprocess.CREODIASOpenSearchSentinel2Postprocessor
          queue: register
        - name: Creodias-Opensearch-Sentinel1
          resource:
            url: https://datahub.creodias.eu/resto/api/collections/Sentinel1/describe.xml
            type: OpenSearch
            format_config:
              type: 'application/json'
              property_mapping:
                start_datetime: 'startDate'
                end_datetime: 'completionDate'
                productIdentifier: 'productIdentifier'
            query:
              time:
                property: sensed
                begin: 2019-09-10T00:00:00Z
                end: 2019-09-11T00:00:00Z
              collection: null
              bbox: 14.9,47.7,16.4,48.7
              extra_params:
                productType: GRD-COG
          filter: {}
          postprocess:
            - type: harvester_eoepca.postprocess.CREODIASOpenSearchSentinel1Postprocessor
          queue: register
```

The `harvester.config.harvesters` list defines a set of pre-defined harvesters which can be invoked in a later stage. The name property must be unique for each harvester and must be unique among all harvesters in the list. Each harvester is associated with a `resource`, an optional `filter` or `postprocess` function, and a `queue`.

The `resource` defines where each item is harvested from. This can be a file system, a search service, catalog file or something similar. The example above defines a connection to an OpenSearch service on CREODIAS, with associated default query parameters and a format configuration.

The `filter` allows to filter elements within the harvester, when the resource does not provide a specific filter. This filter can be supplied using CQL2-JSON.

The `postprocess` can adjust the harvested results. In this example the harvested items are not complete, and additional metadata must be retrieved from an object storage.

The `queue` defines where harvested items will be pushed into. Usually this is a registration queue, where the registrar will pick up and start registration according to its configuration.

#### Starting the Harvester

The harvester can either do one-off harvests via the CLI or listen on a redis queue to run consecutive harvests whenever a harvesting request is received on that queue.

##### One-off harvests via the CLI

In order to start a harvest from the CLI, the operator first needs to connect to the kubernetes pod of the harvester. Within that pod, the harvest can be executed like this...
```bash
python3 -m harvester harvest --config-file /config-run.yaml --host data-access-redis-master --port 6379 Creodias-Opensearch
```

This will invoke the Creodias-Opensearch harvester with default arguments. When some values are to be overridden, the --values switch can be used to pass override values. These values must be a JSON string. The following example adjusts the begin and end times of the query parameters...
```bash
python3 -m harvester harvest --config-file /config-run.yaml --host data-access-redis-master --port 6379 Creodias-Opensearch --values '{"resource": {"query": {"time": {"begin": "2020-09-10T00:00:00Z", "end": "2020-09-11T00:00:00Z"}}}}'
```

##### Harvests via the harvest daemon

The harvester pod runs a service listening on a redis queue. When a message is read from the queue, it will be read as a JSON string, expecting an object with at least a `name` property. Optionally, it can also have a `values` property, working in the same way as with CLI `--values`.

To send a harvesting request via the redis queue, it is necessary to connect to the redis pod and execute the redis-cli there. Then the following command can be used to achieve the same result as above with CLI harvesting...
```bash
redis-cli LPUSH '{"name": "Creodias-Opensearch", "values": {"resource": {"query": {"time": {"begin": "2020-09-10T00:00:00Z", "end": "2020-09-11T00:00:00Z"}}}}}'
```

#### Results of the harvesting

The harvester produces a continous stream of STAC Items which are sent down via the configured queue. It is possible that the harvested metadata is not sufficient to create a fully functional STAC Item. In this case the postprocess must transform this intermediate item to a valid STAC Item. In our example, the postprocessor looks up the Sentinel-2 product file referenced by the product identifier which is then accessed on the object storage. From the stored metadata files, the STAC Items to be sent is created.

## Storage

Specification of PVCs and access to object storage.

### Persistent Volume Claims

The PVCs specified in the helm chart values must be created.

#### PVC for Database

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: data-access-db
  namespace: rm
  labels:
    k8s-app: data-access
    name: data-access
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
```

#### PVC for Redis

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: data-access-redis
  namespace: rm
  labels:
    k8s-app: data-access
    name: data-access
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
```

### Object Storage

The helm chart values expect specification of object storage details for:

* `data`: to access the EO data of the underlying infrastructure
* `cache`: a dedicated object storage bucket is used to support the cache function of the data access services

#### Platform EO Data

Specifies the details for the infrastructure object storage that provides direct access to the EO product files.

For example, the CREODIAS metadata catalogue provides references to product files in their `eodata` object storage - the access details for which are configured in the data access services:

```yaml
global:
  storage:
    data:
      data:
        type: S3
        endpoint_url: http://data.cloudferro.com
        access_key_id: access
        secret_access_key: access
        region_name: RegionOne
        validate_bucket_name: false
```

#### Data Access Cache

The Data Access services maintain a cache, which relies on the usage of a dedicate object storage bucket for data persistence. This bucket must be created (manual step) and its access details configured in the data access services. Example based upon CREODIAS:

```yaml
global:
  storage:
    cache:
      type: S3
      endpoint_url: "https://cf2.cloudferro.com:8080/cache-bucket"
      host: "cf2.cloudferro.com:8080"
      access_key_id: xxx
      secret_access_key: xxx
      region: RegionOne
      bucket: cache-bucket
```

...where `xxx` must be replaced with the bucket credentials.

## Protection

As described in [section Resource Protection (Keycloak)](resource-protection-keycloak.md), the `identity-gatekeeper` component can be inserted into the request path of the `data-access` service to provide access authorization decisions

### Gatekeeper

Gatekeeper is deployed using its helm chart...

```bash
helm install data-access-protection identity-gatekeeper -f data-access-protection-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  --namespace "rm" --create-namespace \
  --version 1.0.11
```

The `identity-gatekeeper` must be configured with the values applicable to the `data-access` - in particular the specific ingress requirements for the `data-access` backend services...

**Example `data-access-protection-values.yaml`...**

```yaml
fullnameOverride: data-access-protection
config:
  client-id: data-access
  discovery-url: https://identity.keycloak.192-168-49-2.nip.io/realms/master
  cookie-domain: 192-168-49-2.nip.io
targetService:
  host: data-access.192-168-49-2.nip.io
  name: data-access-renderer
  port:
    number: 80
secrets:
  # Values for secret 'data-access-protection'
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
    nginx.ingress.kubernetes.io/rewrite-target: /$1
  serverSnippets:
    custom: |-
      # Open access to renderer...
      location ~ ^/(ows.*|opensearch.*|coverages/metadata.*|admin.*) {
        proxy_pass http://data-access-renderer.rm.svc.cluster.local:80/$1;
      }
      # Open access to cache...
      location ~ ^/cache/(.*) {
        proxy_pass http://data-access-cache.rm.svc.cluster.local:80/$1;
      }
      # Open access to client...
      # Note that we use a negative lookahead to avoid matching '/.well-known/*' which
      # otherwise appears to interfere with the work of cert-manager/letsencrypt.
      location ~ ^/(?!\.well-known)(.*) {
        proxy_pass http://data-access-client.rm.svc.cluster.local:80/$1;
      }
```

### Keycloak Client

The Gatekeeper instance relies upon an associated client configured within Keycloak - ref. `client-id: data-access` above.

This can be created with the `create-client` helper script, as descirbed in section [Client Registration](./resource-protection-keycloak.md#client-registration).

For example...

```bash
../bin/create-client \
  -a https://identity.keycloak.192-168-49-2.nip.io \
  -i https://identity-api.192-168-49-2.nip.io \
  -r "master" \
  -u "admin" \
  -p "changeme" \
  -c "admin-cli" \
  --id=data-access \
  --name="Data Access Gatekeeper" \
  --secret="changeme" \
  --description="Client to be used by Data Access Gatekeeper"
```

## Data Access Usage

### Default Harvesting

At deployment time the `harvester` helm values include configuration that populates a default harvester configuration, that is prepared in the file `/config.yaml` in the `harvester` pod.

The Data Access and Resource Catalogue services are configured to properly interpret harvested data via these values specified in the instantiation of the helm release. See section [Data-layer Configuration](#data-layer-configuration).

The harvesting of data can be triggered (post deployment), in accordance with this default configuration, by connecting to the `rm/harvester` service and executing the command...
```
python3 -m harvester harvest --config-file /config-run.yaml --host data-access-redis-master --port 6379 Creodias-Opensearch
```

### Ad-hoc Harvesting

Ad-hoc harvesting can be invoked by provision of a suitable `config.yaml` into the harvester pod, which can then be invoked as shown above for the default harvester configuration established at deploy time.

The helper script `./deploy/bin/harvest` faciltates this...

```
./deploy/bin/harvest <path-to-config-file>
```

See directory `./deploy/samples/harvester/` that contains some sample harvesting configuration files.<br>
For example...

```
./deploy/bin/harvest ./deploy/samples/harvester/config-Sentinel2-2019.09.10.yaml
```

### Registration of Collections

The helper script `./deploy/bin/register-collection` is provided to faciltate the registration of collections that are specfied in _STAC Collection_ format.

```
./deploy/bin/register-collection <path-to-stac-collection-file>
```

See directory `./deploy/samples/collections/` that contains some same STAC Collection files.<br>
For example...

```
./deploy/bin/register-collection ./deploy/samples/collections/S2MSI2A.json
```

## Additional Information

Additional information regarding the _Data Access_ can be found at:

* [Helm Chart](https://charts-public.hub.eox.at/charts/vs-x.y.z.tgz)
* _Documentation:_
    * [User Guide](https://vs.pages.eox.at/documentation/user/main/)
    * [Operator Guide](https://vs.pages.eox.at/documentation/operator/main/)
* [Git Repository](https://gitlab.eox.at/vs/vs)
