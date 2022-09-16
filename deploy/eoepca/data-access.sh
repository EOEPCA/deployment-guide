#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source ../cluster/functions
configureAction "$1"
initIpDefaults

domain="${2:-${default_domain}}"

if [ "${OPEN_INGRESS}" = "true" ]; then
  name="data-access-open"
else
  name="data-access"
fi

main() {
  databasePVC | kubectl ${ACTION_KUBECTL} -f -
  redisPVC | kubectl ${ACTION_KUBECTL} -f -
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace rm uninstall data-access
  else
    values | helm ${ACTION_HELM} data-access vs -f - \
      --repo https://charts-public.hub.eox.at/ \
      --namespace rm --create-namespace \
      --version 2.2.4
  fi
}

values() {
  cat - <<EOF
global:
  env:
    REGISTRAR_REPLACE: "true"
    CPL_VSIL_CURL_ALLOWED_EXTENSIONS: .TIF,.tif,.xml,.jp2,.jpg
    startup_scripts:
      - /registrar_pycsw/registrar_pycsw/initialize-collections.sh

  # The data-access relies on the value 'ingress.tls.hosts[0]' to specify the service
  # hostname. So this must be supplied even if the ingress is disabled.
  ingress:
    enabled: ${OPEN_INGRESS}
    annotations:
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: "${USE_TLS}"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      cert-manager.io/cluster-issuer: "${TLS_CLUSTER_ISSUER}"
    hosts:
      - host: ${name}.${domain}
    tls:
      - hosts:
          - ${name}.${domain}
        secretName: ${name}-tls

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
      bucket: cache-bucket
      endpoint_url: "http://minio.${domain}/cache-bucket"
      host: "minio.${domain}"
      access_key_id: ${MINIO_ROOT_USER}
      secret_access_key: ${MINIO_ROOT_PASSWORD}
      region: us-east-1
      region_name: us-east-1

  metadata:
    title: EOEPCA Data Access Service developed by EOX
    abstract: EOEPCA Data Access Service developed by EOX
    header: "EOEPCA Data Access View Server (VS) Client powered by <a href=\"//eox.at\"><img src=\"//eox.at/wp-content/uploads/2017/09/EOX_Logo.svg\" alt=\"EOX\" style=\"height:25px;margin-left:10px\"/></a>"
    url: https://${name}.${domain}/ows

$(dataSpecification)

renderer:
  replicaCount: 4
  image:
    repository: eoepca/rm-data-access-core
    tag: 1.2-dev14
    pullPolicy: Always
  ingress:
    enabled: ${OPEN_INGRESS}
    annotations:
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: "${USE_TLS}"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      cert-manager.io/cluster-issuer: "${TLS_CLUSTER_ISSUER}"
    hosts:
      - host: ${name}.${domain}
    tls:
      - hosts:
          - ${name}.${domain}
        secretName: ${name}-tls
  resources:
    limits:
      cpu: 1.5
      memory: 3Gi
    requests:
      cpu: 0.5
      memory: 1Gi

registrar:
  image:
    repository: eoepca/rm-data-access-core
    # tag: 1.2-dev14
    tag: latest
    pullPolicy: Always
  config:
    defaultBackends:
      - path: registrar_pycsw.backend.ItemBackend
        kwargs:
          repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw
          ows_url: https://${name}.${domain}/ows
    defaultSuccessQueue: seed_queue
    # routes:
    #   collections:
    #     path: registrar.route.stac.Collection
    #     queue: register_collection_queue
    #     replace: true
    #     backends:
    #       - path: registrar_pycsw.backend.CollectionBackend
    #         kwargs:
    #           repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw

    #   ades:
    #     path: registrar.route.json.JSONRoute
    #     queue: register_ades_queue
    #     replace: true
    #     backends:
    #       - path: registrar_pycsw.backend.ADESBackend
    #         kwargs:
    #           repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw

    #   application:
    #     path: registrar.route.json.JSONRoute
    #     queue: register_application_queue
    #     replace: true
    #     backends:
    #       - path: registrar_pycsw.backend.CWLBackend
    #         kwargs:
    #           repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw

$(harvesterSpecification)

client:
  image:
    tag: release-2.0.29
  ingress:
    enabled: ${OPEN_INGRESS}
    annotations:
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: "${USE_TLS}"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      cert-manager.io/cluster-issuer: "${TLS_CLUSTER_ISSUER}"
    hosts:
      - host: ${name}.${domain}
    tls:
      - hosts:
          - ${name}.${domain}
        secretName: ${name}-tls
  config:
    eoxserverDownloadEnabled: true
    timeDomain:
      - "2002-01-01T00:00:00Z"
      - "customClientDateFuture1"
    displayTimeDomain:
      - "customClientDatePast1"
      - "customClientDateFuture1"
    selectedTimeDomain:
      - "customClientDatePast2"
      - "today"
    customClientDaysPast1: 90
    customClientDaysPast2: 1
    customClientDaysFuture1: 7

config:
  objectStorage:
    cache:
      access_key_id: ${MINIO_ROOT_USER}
      bucket: cache-bucket
      endpoint_url: minio.${domain}
      region: us-east-1
      secret_access_key: ${MINIO_ROOT_PASSWORD}
      type: S3

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
    enabled: ${OPEN_INGRESS}
    annotations:
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: "${USE_TLS}"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      cert-manager.io/cluster-issuer: "${TLS_CLUSTER_ISSUER}"
    hosts:
      - host: ${name}.${domain}
    tls:
      - hosts:
          - ${name}.${domain}
        secretName: ${name}-tls

preprocessor:
  replicaCount: 0

cache:
  ingress:
    enabled: ${OPEN_INGRESS}
    annotations:
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: "${USE_TLS}"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      cert-manager.io/cluster-issuer: "${TLS_CLUSTER_ISSUER}"
    hosts:
      - host: ${name}.${domain}
    tls:
      - hosts:
          - ${name}.${domain}
        secretName: ${name}-tls

seeder:
  config:
    minzoom: 0
    maxzoom: 6  # restrict to only 6 for testing for now
EOF
}

dataSpecification() {
  if [ "${CREODIAS_DATA_SPECIFICATION}" = "true" ]; then
    creodiasData
  else
    cat - <<EOF
  layers: []
  collections: {}
  productTypes: []
EOF
  fi
}

creodiasData() {
  cat - <<EOF
  layers:
    - id: S2L1C
      title: Sentinel-2 Level 1C True Color
      abstract: Sentinel-2 Level 2A True Color
      displayColor: '#eb3700'
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L1C
      search:
        histogramBinCount: 15
        histogramThreshold: 80
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
      search:
        histogramBinCount: 15
        histogramThreshold: 80
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
      collections:
        - S2L1C
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
      collections:
        - S2L2A
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
      defaultBrowse: TRUE_COLOR
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
EOF
}

harvesterSpecification() {
  if [ "${CREODIAS_DATA_SPECIFICATION}" = "true" ]; then
    creodiasHarvester
  else
    cat - <<EOF
harvester: {}
EOF
  fi
}

creodiasHarvester() {
  cat - <<EOF
harvester:
  image:
    repository: eoepca/rm-harvester
    tag: 1.2-dev1
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
          - type: harvester_eoepca.postprocess.CREODIASOpenSearchSentinel2Postprocessor
        queue: register
EOF
}

databasePVC() {
  cat - <<EOF
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
EOF
}

redisPVC() {
  cat - <<EOF
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
EOF
}

main
