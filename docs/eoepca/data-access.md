# Data Access

The _Data Access_ provides standards-based services for access to platform hosted data - including OGC WMS/WMTS for visualisation, and OGC WCS for data retrieval. This component also includes _Harvester_ and _Registrar_ services to discover/watch the existing data holding of the infrastructure data layer and populate/maintain the _data access_ and _resource catalogue_ services accordingly.

## Helm Chart

The _Data Access_ is deployed via the `vs` (View Server) helm chart from the [EOX Helm Chart Repository](https://charts-public.hub.eox.at/).

The chart is configured via values that are supplied with the instantiation of the helm release. The documentation for the View Server can be found here:

* User Guide: [https://vs.pages.eox.at/documentation/user/main/](https://vs.pages.eox.at/documentation/user/main/)
* Operator Guide: [https://vs.pages.eox.at/documentation/operator/main/](https://vs.pages.eox.at/documentation/operator/main/)

```bash
helm install --values data-access-values.yaml --repo https://charts-public.hub.eox.at/ data-access vs
```

## Values

The Data Access supports many values to configure the service. These are documented in full in the [View Server - Operator Guide Configuration page](https://vs.pages.eox.at/documentation/operator/main/configuration.html#helm-configuration-variables).

### Core Configuration

Typically, values for the following attributes may be specified to override the chart defaults:

* The fully-qualified public URL for the service, ref. (`global.ingress.hosts.host[0]`)
* Metadata describing the service instance
* Dynamic provisioning _StorageClass_ for persistence
* Persistent Volume Claims for `database` and `redis` components
* Object storage details for `data` and `cache`
* Container images for `renderer` and `registrar`
* (optional) Specification of Ingress for reverse-proxy access to the service<br>
  _Note that this is only required in the case that the Data Access will **not** be protected by the `resource-guard` component - ref. [Resource Protection](../resource-protection). Otherwise the ingress will be handled by the `resource-guard` - use `ingress.enabled: false`._

```yaml
global:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: "true"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      cert-manager.io/cluster-issuer: letsencrypt-production
    hosts:
      - host: data-access.192.168.49.123.nip.io
    tls:
      - hosts:
          - data-access.192.168.49.123.nip.io
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
      endpoint_url: "http://minio.192.168.49.123.nip.io"
      host: "minio.192.168.49.123.nip.io"
      access_key_id: xxx
      secret_access_key: xxx
      region: us-east-1
      bucket: cache-bucket
  metadata:
    title: EOEPCA Data Access Service developed by EOX
    abstract: EOEPCA Data Access Service developed by EOX
    header: "EOEPCA Data Access View Server (VS) Client powered by <a href=\"//eox.at\"><img src=\"//eox.at/wp-content/uploads/2017/09/EOX_Logo.svg\" alt=\"EOX\" style=\"height:25px;margin-left:10px\"/></a>"
    url: https://data-access.192.168.49.123.nip.io/ows
  layers:
    # see section 'Data-layer Configuration'
  collections:
    # see section 'Data-layer Configuration'
  productTypes:
    # see section 'Data-layer Configuration'
renderer:
  image:
    repository: eoepca/rm-data-access-core
    tag: "1.0.2"
  ingress:
    enabled: false
registrar:
  image:
    repository: eoepca/rm-data-access-core
    tag: "1.0.2"
harvester:
  # see section 'Harvester Configuration'
client:
  image:
    tag: release-2.0.2
  ingress:
    enabled: false
database:
  persistence:
    enabled: true
    existingClaim: data-access-db
redis:
  usePassword: false
  persistence:
    existingClaim: data-access-redis
  master:
    persistence:
      enabled: true
      storageClass: standard
  cluster:
    enabled: false
ingestor:
  replicaCount: 0
  ingress:
    enabled: false
preprocessor:
  replicaCount: 0
cache:
  ingress:
    enabled: false
```

### Data-layer Configuration

Configuration of the service data-layer - as described in the [View Server Operator Guide](https://vs.pages.eox.at/documentation/operator/main/configuration.html#helm-configuration-variables). See below for a populated sample based upon a CREODIAS infrastructure data provision. The sample helps to illustrate the values by way of a worked example, in which the following are defined:

* `layers` - [Layers](https://vs.pages.eox.at/documentation/operator/main/configuration.html#layers-layers)
* `collections` - [Data Collections](https://vs.pages.eox.at/documentation/operator/main/configuration.html#data-collections-collections)
* `productTypes` - [Product Types](https://vs.pages.eox.at/documentation/operator/main/configuration.html#product-types-producttypes)

```yaml
global:
  layers:
    - id: S2L1C
      title: Sentinel-2 Level 1C True Color
      abstract: Sentinel-2 Level 2A True Color
      displayColor: '#eb3700'
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L1C
    - id: S2L1C__TRUE_COLOR
      title: Sentinel-2 Level 1C True Color
      abstract: Sentinel-2 Level 2A True Color
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L1C
    - id: S2L1C__masked_clouds
      title: Sentinel-2 Level 1C True Color with cloud masks
      abstract: Sentinel-2 Level 1C True Color with cloud masks
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L1C
    - id: S2L1C__FALSE_COLOR
      title: Sentinel-2 Level 1C False Color
      abstract: Sentinel-2 Level 1C False Color
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L1C
    - id: S2L1C__NDVI
      title: Sentinel-2 Level 21CNDVI
      abstract: Sentinel-2 Level 1C NDVI
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L1C
    - id: S2L2A
      title: Sentinel-2 Level 2A True Color
      abstract: Sentinel-2 Level 2A True Color
      displayColor: '#eb3700'
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L2A
    - id: S2L2A__TRUE_COLOR
      title: Sentinel-2 Level 2A True Color
      abstract: Sentinel-2 Level 2A True Color
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L2A
    - id: S2L2A__masked_clouds
      title: Sentinel-2 Level 2A True Color with cloud masks
      abstract: Sentinel-2 Level 2A True Color with cloud masks
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L2A
    - id: S2L2A__FALSE_COLOR
      title: Sentinel-2 Level 2A False Color
      abstract: Sentinel-2 Level 2A False Color
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L2A
    - id: S2L2A__NDVI
      title: Sentinel-2 Level 2A NDVI
      abstract: Sentinel-2 Level 2A NDVI
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L2A
  collections:
    S2L1C:
      product_types:
        - S2MSI1C
      coverage_types:
        - S2L1C_B01
        - S2L1C_B02
        - S2L1C_B03
        - S2L1C_B04
        - S2L1C_B05
        - S2L1C_B06
        - S2L1C_B07
        - S2L1C_B08
        - S2L1C_B8A
        - S2L1C_B09
        - S2L1C_B10
        - S2L1C_B11
        - S2L1C_B12
    S2L2A:
      product_types:
        - S2MSI2A
      product_levels:
        - Level-2A
      coverage_types:
        - S2L2A_B01
        - S2L2A_B02
        - S2L2A_B03
        - S2L2A_B04
        - S2L2A_B05
        - S2L2A_B06
        - S2L2A_B07
        - S2L2A_B08
        - S2L2A_B8A
        - S2L2A_B09
        - S2L2A_B11
        - S2L2A_B12
  productTypes:
    - name: S2MSI1C
      filter:
        s2:product_type: S2MSI1C
      metadata_assets: []
      coverages:
        S2L1C_B01:
          assets:
            - B01
        S2L1C_B02:
          assets:
            - B02
        S2L1C_B03:
          assets:
            - B03
        S2L1C_B04:
          assets:
            - B04
        S2L1C_B05:
          assets:
            - B05
        S2L1C_B06:
          assets:
            - B06
        S2L1C_B07:
          assets:
            - B07
        S2L1C_B08:
          assets:
            - B08
        S2L1C_B8A:
          assets:
            - B8A
        S2L1C_B09:
          assets:
            - B09
        S2L1C_B10:
          assets:
            - B10
        S2L1C_B11:
          assets:
            - B11
        S2L1C_B12:
          assets:
            - B12
      defaultBrowse: TRUE_COLOR
      browses:
        TRUE_COLOR:
          asset: visual
          red:
            expression: B04
            range: [0, 4000]
            nodata: 0
          green:
            expression: B03
            range: [0, 4000]
            nodata: 0
          blue:
            expression: B02
            range: [0, 4000]
            nodata: 0
        FALSE_COLOR:
          red:
            expression: B08
            range: [0, 4000]
            nodata: 0
          green:
            expression: B04
            range: [0, 4000]
            nodata: 0
          blue:
            expression: B03
            range: [0, 4000]
            nodata: 0
        NDVI:
          grey:
            expression: (B08-B04)/(B08+B04)
            range: [-1, 1]
      masks:
        clouds:
          validity: false
    - name: S2MSI2A
      filter:
        s2:product_type: S2MSI2A
      metadata_assets: []
      coverages:
        S2L2A_B01:
          assets:
            - B01
        S2L2A_B02:
          assets:
            - B02
        S2L2A_B03:
          assets:
            - B03
        S2L2A_B04:
          assets:
            - B04
        S2L2A_B05:
          assets:
            - B05
        S2L2A_B06:
          assets:
            - B06
        S2L2A_B07:
          assets:
            - B07
        S2L2A_B08:
          assets:
            - B08
        S2L2A_B8A:
          assets:
            - B8A
        S2L2A_B09:
          assets:
            - B09
        S2L2A_B11:
          assets:
            - B11
        S2L2A_B12:
          assets:
            - B12
      default_browse_locator: TCI_10m
      browses:
        TRUE_COLOR:
          asset: visual-10m
          red:
            expression: B04
            range: [0, 4000]
            nodata: 0
          green:
            expression: B03
            range: [0, 4000]
            nodata: 0
          blue:
            expression: B02
            range: [0, 4000]
            nodata: 0
        FALSE_COLOR:
          red:
            expression: B08
            range: [0, 4000]
            nodata: 0
          green:
            expression: B04
            range: [0, 4000]
            nodata: 0
          blue:
            expression: B03
            range: [0, 4000]
            nodata: 0
        NDVI:
          grey:
            expression: (B08-B04)/(B08+B04)
            range: [-1, 1]
      masks:
        clouds:
          validity: false
```

### Harvester

The Data Access service includes a Harvester component. The following subsections describe its configuration and usage.

#### Harvester Helm Configuration

The Harvester can be configured through the helm chart values...

```yaml
harvester:
  image:
    repository: eoepca/rm-harvester
    tag: 1.0.0
  config:
    redis:
      host: data-access-redis-master
      port: 6379
    harvesters:
      - name: Creodias-Opensearch
        resource:
          url: https://finder.creodias.eu/resto/api/collections/Sentinel2/describe.xml
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
          type: harvester_eoepca.postprocess.CREODIASOpenSearchSentinel2Postprocessor
        queue: register_queue
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

As described in [section Resource Protection](../resource-protection), the `resource-guard` component can be inserted into the request path of the Data Access service to provide access authorization decisions.

```bash
helm install --values data-access-guard-values.yaml data-access-guard eoepca/resource-guard
```

The `resource-guard` must be configured with the values applicable to the Data Access for the _Policy Enforcement Point_ (`pep-engine`) and the _UMA User Agent_ (`uma-user-agent`)...

**Example `data-access-guard-values.yaml`...**

```yaml
#---------------------------------------------------------------------------
# Global values
#---------------------------------------------------------------------------
global:
  context: data-access
  pep: data-access-pep
  domain: 192.168.49.123.nip.io
  nginxIp: 192.168.49.123
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
  fullnameOverride: data-access-agent
  nginxIntegration:
    enabled: true
    hosts:
      - host: data-access
        paths:
          - path: /(ows.*)
            service:
              name: data-access-renderer
              port: 80
          - path: /(opensearch.*)
            service:
              name: data-access-renderer
              port: 80
          - path: /(admin.*)
            service:
              name: data-access-renderer
              port: 80
          - path: /cache/(.*)
            service:
              name: data-access-cache
              port: 80
          - path: /(.*)
            service:
              name: data-access-client
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

The client credentials are obtained by registration of a client at the login service web interface - e.g. https://auth.192.168.49.123.nip.io. In addition there is a helper script that can be used to create a basic client and obtain the credentials, as described in [section Resource Protection](../resource-protection/#client-registration)...
```bash
./local-deploy/bin/register-client auth.192.168.49.123.nip.io "Resource Guard" | tee client.yaml
```

## Data Access Usage

### Harvesting

The Data Access and Resource Catalogue services are configured to properly interpret harvested data via the values specified in the instantiation of the helm release. See section [Data-layer Configuration](#data-layer-configuration).

The harvesting of data can be triggered (post deployment) by connecting to the `rm/harvester` service and executing the command...
```
python3 -m harvester harvest --config-file /config-run.yaml --host data-access-redis-master --port 6379 Creodias-Opensearch
```

## Additional Information

Additional information regarding the _Data Access_ can be found at:

* [Helm Chart](https://charts-public.hub.eox.at/charts/vs-x.y.z.tgz)
* _Documentation:_
    * [User Guide](https://vs.pages.eox.at/documentation/user/main/)
    * [Operator Guide](https://vs.pages.eox.at/documentation/operator/main/)
* [Git Repository](TBD)
