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
NAMESPACE="rm"

if [ "${OPEN_INGRESS}" = "true" ]; then
  name="data-access-open"
else
  name="data-access"
fi

main() {
  # establish persistence
  deployPersistence
  # deploy the service
  deployService
  # protect the service (optional)
  if [ "${REQUIRE_DATA_ACCESS_PROTECTION}" = "true" ]; then
    echo -e "\nProtect Data Access..."
    createClient
    deployProtection
  fi
}

deployPersistence() {
  databasePVC | kubectl ${ACTION_KUBECTL} -f -
  redisPVC | kubectl ${ACTION_KUBECTL} -f -
}

deployService() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace ${NAMESPACE} uninstall data-access
  else
    serviceValues | helm ${ACTION_HELM} data-access data-access -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace ${NAMESPACE} --create-namespace \
      --version 1.4.0
  fi
}

serviceValues() {
  cat - <<EOF
global:
  env:
    REGISTRAR_REPLACE: "true"
    CPL_VSIL_CURL_ALLOWED_EXTENSIONS: .TIF,.TIFF,.tif,.tiff,.xml,.jp2,.jpg,.jpeg,.png,.nc
    AWS_ENDPOINT_URL_S3: $(httpScheme)://minio.${domain}
    AWS_HTTPS: "FALSE"
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
      endpoint_url: "$(httpScheme)://minio.${domain}/cache-bucket"
      host: "minio.${domain}"
      access_key_id: ${MINIO_ROOT_USER}
      secret_access_key: ${MINIO_ROOT_PASSWORD}
      region: us-east-1
      region_name: us-east-1

  metadata:
    title: EOEPCA Data Access Service developed by EOX
    abstract: EOEPCA Data Access Service developed by EOX
    header: "EOEPCA Data Access View Server (VS) Client powered by <a href=\"//eox.at\"><img src=\"//eox.at/wp-content/uploads/2017/09/EOX_Logo.svg\" alt=\"EOX\" style=\"height:25px;margin-left:10px\"/></a>"
    url: $(httpScheme)://${name}.${domain}/ows

$(dataSpecification)

vs:

  renderer:
    replicaCount: 4
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
      requests:
        cpu: 100m
        memory: 300Mi
      limits:
        cpu: 1.5
        memory: 3Gi

  registrar:
    replicaCount: 1
    resources:
      requests:
        cpu: 100m
        memory: 100Mi
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
            ows_url: $(httpScheme)://${name}.${domain}/ows
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

$(harvesterSpecification)

  client:
    replicaCount: 1
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

  redis:
    master:
      persistence:
        storageClass: ${DATA_ACCESS_STORAGE}

  ingestor:
    ingress:
      enabled: false

  # seeder:
  #   image:
  #     repository: registry.gitlab.eox.at/vs/vs/seeder
  #     tag: release-4.1.3

  cache:
    ingress:
      enabled: false

  scheduler:
    resources:
      requests:
        cpu: 100m
        memory: 100Mi
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
    - id: L8L1TP
      title: Landsat-8 Level 1TP True Color
      abstract: Landsat-8 Level 1TP True Color
      displayColor: '#eb3700'
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: L8L1TP
      search:
        histogramBinCount: 15
        histogramThreshold: 80
    - id: L8L1TP__TRUE_COLOR
      title: Landsat-8 Level 1TP True Color
      abstract: Landsat-8 Level 1TP True Color
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: L8L1TP
    - id: L8L1GT
      title: Landsat-8 Level 1GT True Color
      abstract: Landsat-8 Level 1GT True Color
      displayColor: '#eb3700'
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: L8L1GT
      search:
        histogramBinCount: 15
        histogramThreshold: 80
    - id: L8L1GT__TRUE_COLOR
      title: Landsat-8 Level 1GT True Color
      abstract: Landsat-8 Level 1GT True Color
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: L8L1GT
    - id: S3A_OL_2_LFR
      title: Sentinel-3 OL_2_LFR
      abstract: Sentinel-3 Quicklooks
      displayColor: '#eb3700'
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S3A_OL_2_LFR
      search:
        histogramBinCount: 15
        histogramThreshold: 80
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
    L8L1TP:
      product_types:
        - L8MSI1TP
      product_levels:
        - Level-1TP
      coverage_types:
        - L8L1TP_B01
        - L8L1TP_B02
        - L8L1TP_B03
        - L8L1TP_B04
        - L8L1TP_B05
        - L8L1TP_B06
        - L8L1TP_B07
    L8L1GT:
      product_types:
        - L8MSI1GT
      product_levels:
        - Level-1GT
      coverage_types:
        - L8L1GT_B01
        - L8L1GT_B02
        - L8L1GT_B03
        - L8L1GT_B04
        - L8L1GT_B05
        - L8L1GT_B06
        - L8L1GT_B07
    S1IWGRD1C:
      product_types:
        - S1IWGRD1C_VVVH
      coverage_types: []
    S1SLC:
      product_types:
        - S1SLC
      coverage_types: []
    S3A_OL_2_LFR:
      product_types:
        - S3A_OL_2_LFR
      coverage_types: []
  coverageTypes:
    # Landsat-8 L1TP
    - name: "L8L1TP_B01"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B1"
          name: "coastal"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B1"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 0.44
    - name: "L8L1TP_B02"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B2"
          name: "blue"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B2"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 0.48
    - name: "L8L1TP_B03"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B3"
          name: "green"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B3"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 0.56
    - name: "L8L1TP_B04"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B4"
          name: "red"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B4"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 0.65
    - name: "L8L1TP_B05"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B5"
          name: "nir08"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B5"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 0.86
    - name: "L8L1TP_B06"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B6"
          name: "swir16"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B6"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 1.6
    - name: "L8L1TP_B07"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B7"
          name: "swir22"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B7"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 2.2
    # Landsat-8 L1GT
    - name: "L8L1GT_B01"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B1"
          name: "coastal"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B1"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 0.44
    - name: "L8L1GT_B02"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B2"
          name: "blue"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B2"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 0.48
    - name: "L8L1GT_B03"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B3"
          name: "green"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B3"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 0.56
    - name: "L8L1GT_B04"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B4"
          name: "red"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B4"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 0.65
    - name: "L8L1GT_B05"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B5"
          name: "nir08"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B5"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 0.86
    - name: "L8L1GT_B06"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B6"
          name: "swir16"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B6"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 1.6
    - name: "L8L1GT_B07"
      data_type: "Uint16"
      bands:
        - identifier: "SR_B7"
          name: "swir22"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "SR_B7"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          uom: "W/m2/um"
          wavelength: 2.2
    - name: S1IWGRD1C_VV
      data_type: "Uint16"
      bands:
        - identifier: "VV"
          name: "VV"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "VV"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          # uom: "W/m2/um"
          wavelength: 5.5465763
    - name: S1IWGRD1C_VH
      data_type: "Uint16"
      bands:
        - identifier: "VH"
          name: "VH"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "VH"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          # uom: "W/m2/um"
          wavelength: 5.5465763
    - name: S1IWGRD1C_HH
      data_type: "Uint16"
      bands:
        - identifier: "HH"
          name: "HH"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "HH"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          # uom: "W/m2/um"
          wavelength: 5.5465763
    - name: S1IWGRD1C_HV
      data_type: "Uint16"
      bands:
        - identifier: "HV"
          name: "HV"
          definition: "http://www.opengis.net/def/property/OGC/0/Radiance"
          description: "HV"
          nil_values:
            - reason: "http://www.opengis.net/def/nil/OGC/0/unknown"
              value: 0
          # uom: "W/m2/um"
          wavelength: 5.5465763
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
    - name: L8MSI1TP
      filter:
        platform: landsat-8
        landsat:correction: L1TP
      collections:
        - L8L1TP
      metadata_assets: []
      coverages:
        L8L1TP_B01:
          assets:
            - SR_B1
        L8L1TP_B02:
          assets:
            - SR_B2
        L8L1TP_B03:
          assets:
            - SR_B3
        L8L1TP_B04:
          assets:
            - SR_B4
        L8L1TP_B05:
          assets:
            - SR_B5
        L8L1TP_B06:
          assets:
            - SR_B6
        L8L1TP_B07:
          assets:
            - SR_B7
      defaultBrowse: TRUE_COLOR
      browses:
        TRUE_COLOR:
          red:
            expression: SR_B4
            range: [5000, 12000]
            nodata: 0
          green:
            expression: SR_B3
            range: [5000, 12000]
            nodata: 0
          blue:
            expression: SR_B2
            range: [5000, 12000]
            nodata: 0
      masks:
        clouds:
          validity: false
    - name: L8MSI1GT
      filter:
        platform: landsat-8
        landsat:correction: L1GT
      collections:
        - L8L1GT
      metadata_assets: []
      coverages:
        L8L1GT_B01:
          assets:
            - SR_B1
        L8L1GT_B02:
          assets:
            - SR_B2
        L8L1GT_B03:
          assets:
            - SR_B3
        L8L1GT_B04:
          assets:
            - SR_B4
        L8L1GT_B05:
          assets:
            - SR_B5
        L8L1GT_B06:
          assets:
            - SR_B6
        L8L1GT_B07:
          assets:
            - SR_B7
      defaultBrowse: TRUE_COLOR
      browses:
        TRUE_COLOR:
          red:
            expression: SR_B4
            range: [5000, 12000]
            nodata: 0
          green:
            expression: SR_B3
            range: [5000, 12000]
            nodata: 0
          blue:
            expression: SR_B2
            range: [5000, 12000]
            nodata: 0
      masks:
        clouds:
          validity: false
    - name: S1IWGRD1C_VVVH
      filter:
        constellation: sentinel-1
        sar:instrument_mode: IW
        sar:product_type: GRD
        sar:polarizations: ["VV", "VH"]
      collections:
        - S1IWGRD1C
      metadata_assets: []
      coverages:
        S1IWGRD1C_VV:
          assets:
            - vv
        S1IWGRD1C_VH:
          assets:
            - vh
      # defaultBrowse: QUICKLOOK
      defaultBrowse: COMPOSITE
      browses:
        # QUICKLOOK:
        #   asset: thumbnail
        COMPOSITE:
          red:
            expression: VV
            range: [8, 1200]
            nodata: 0
          green:
            expression: VH
            range: [5000, 12000]
            nodata: 0
          blue:
            expression: VV/VH
            range: [5000, 12000]
            nodata: 0
    - name: S1SLC
      filter:
        constellation: sentinel-1
        sar:product_type: SLC
      collections:
        - S1SLC
      metadata_assets: []
      coverages: {}
        # S1IWGRD1C_VV:
        #   assets:
        #     - vv
        # S1IWGRD1C_VH:
        #   assets:
        #     - vh
      defaultBrowse: QUICKLOOK
      browses:
        QUICKLOOK:
          asset: thumbnail
    - name: S3A_OL_2_LFR
      filter:
        constellation: Sentinel-3
        s3:productType: OL_2_LFR___
      collections:
        - S3A_OL_2_LFR
      metadata_assets: []
      coverages: {}
        # OGVI:
        #   assets:
        #     - ogvi
        # RCOGVI:
        #   assets:
        #     - rcOgvi
        # OTCI:
        #   assets:
        #     - otci
        # IWV:
        #   assets:
        #     - iwv
        # LQSF:
        #   assets:
        #     - lqsf
        # TIMECOORDINATES:
        #   assets:
        #     - timeCoordinates
        # GEOCOORDINATES:
        #   assets:
        #     - geoCoordinates
        # TIEGEOCOORDINATES:
        #   assets:
        #     - tieGeoCoordinates
        # TIEGEOMETRIES:
        #   assets:
        #     - tieGeometries
        # TIEMETEO:
        #   assets:
        #     - tieMeteo
        # INSTRUMENTDATA:
        #   assets:
        #     - instrumentData
      defaultBrowse: THUMBNAIL
      browses:
        THUMBNAIL:
          asset: thumbnail
EOF
}

harvesterSpecification() {
  if [ "${CREODIAS_DATA_SPECIFICATION}" = "true" ]; then
    creodiasHarvester
  else
    cat - <<EOF
  harvester:
    replicaCount: 1
    resources:
      requests:
        cpu: 100m
        memory: 100Mi
EOF
  fi
}

creodiasHarvester() {
  cat - <<EOF
  harvester:
    replicaCount: 1
    resources:
      requests:
        cpu: 100m
        memory: 100Mi
    config:
      redis:
        host: data-access-redis-master
        port: 6379
      harvesters:
        Sentinel2:
          resource:
            type: OpenSearch
            opensearch:
              url: https://datahub.creodias.eu/resto/api/collections/Sentinel2/describe.xml
              format:
                type: 'application/json'
                json:
                  property_mapping:
                    start_datetime: 'startDate'
                    end_datetime: 'completionDate'
                    productIdentifier: 'productIdentifier'
              query:
                time:
                  begin: 2019-09-10T00:00:00Z
                  end: 2019-09-11T00:00:00Z
                collection: null
                bbox: 14.9,47.7,16.4,48.7
          filter: {}
          postprocessors:
            - type: external
              process: harvester_eoepca.postprocess.postprocess_sentinel2
              kwargs: {}
          queue: register
        Landsat8:
          filter: {}
          postprocessors:
          - kwargs: {}
            process: harvester_eoepca.postprocess.postprocess_landsat8
            type: external
          queue: register
          resource:
            opensearch:
              format:
                json:
                  property_mapping:
                    end_datetime: completionDate
                    productIdentifier: productIdentifier
                    start_datetime: startDate
                type: application/json
              query:
                bbox: 19.7,34.7,28.5,42.0
                collection: null
                time:
                  begin: 2020-09-01T00:00:00Z
                  end: 2020-09-05T00:00:00Z
              url: https://datahub.creodias.eu/resto/api/collections/Landsat8/describe.xml
            type: OpenSearch
        Sentinel1-GRD:
          resource:
            type: OpenSearch
            opensearch:
              url: https://datahub.creodias.eu/resto/api/collections/Sentinel1/describe.xml
              format:
                type: 'application/json'
                json:
                  property_mapping:
                    start_datetime: 'startDate'
                    end_datetime: 'completionDate'
                    productIdentifier: 'productIdentifier'
              query:
                time:
                  begin: 2019-09-10T00:00:00Z
                  end: 2019-09-11T00:00:00Z
                collection: null
                bbox: 14.9,47.7,16.4,48.7
                extra_params:
                  productType: GRD-COG
          filter: {}
          postprocessors:
            - type: external
              process: harvester_eoepca.postprocess.postprocess_sentinel1
              kwargs: {}
          queue: register
        Sentinel3:
          resource:
            type: OpenSearch
            opensearch:
              url: https://datahub.creodias.eu/resto/api/collections/Sentinel3/describe.xml
              format:
                type: 'application/json'
                json:
                  property_mapping:
                    start_datetime: 'startDate'
                    end_datetime: 'completionDate'
                    productIdentifier: 'productIdentifier'
              query:
                time:
                  begin: 2019-09-10T00:00:00Z
                  end: 2019-09-11T00:00:00Z
                collection: null
                bbox: 14.9,47.7,16.4,48.7
                extra_params:
                  productType: OL_2_LFR___
          filter: {}
          postprocessors:
            - type: external
              process: harvester_eoepca.postprocess.postprocess_sentinel3
              kwargs: {}
          queue: register
        Sentinel1-SLC:
          resource:
            type: OpenSearch
            opensearch:
              url: https://datahub.creodias.eu/resto/api/collections/Sentinel1/describe.xml
              format:
                type: 'application/json'
                json:
                  property_mapping:
                    start_datetime: 'startDate'
                    end_datetime: 'completionDate'
                    productIdentifier: 'productIdentifier'
              query:
                time:
                  begin: 2019-09-10T00:00:00Z
                  end: 2019-09-11T00:00:00Z
                collection: null
                bbox: 14.9,47.7,16.4,48.7
                extra_params:
                  productType: SLC
          filter: {}
          postprocessors:
            - type: external
              process: harvester_eoepca.postprocess.postprocess_sentinel1
              kwargs: {}
          queue: register
EOF
}

databasePVC() {
  cat - <<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: data-access-db
  namespace: ${NAMESPACE}
  labels:
    k8s-app: data-access
    name: data-access
spec:
  storageClassName: ${DATA_ACCESS_STORAGE}
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
  namespace: ${NAMESPACE}
  labels:
    k8s-app: data-access
    name: data-access
spec:
  storageClassName: ${DATA_ACCESS_STORAGE}
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
EOF
}

createClient() {
  # Create the client
  ../bin/create-client \
    -a $(httpScheme)://identity.keycloak.${domain} \
    -i $(httpScheme)://identity-api-protected.${domain} \
    -r "${IDENTITY_REALM}" \
    -u "${IDENTITY_SERVICE_ADMIN_USER}" \
    -p "${IDENTITY_SERVICE_ADMIN_PASSWORD}" \
    -c "${IDENTITY_SERVICE_ADMIN_CLIENT}" \
    --id=data-access \
    --name="Data Access Gatekeeper" \
    --secret="${IDENTITY_SERVICE_DEFAULT_SECRET}" \
    --description="Client to be used by Data Access Gatekeeper"
}

deployProtection() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall data-access-protection
  else
    serviceProtectionValues | helm ${ACTION_HELM} data-access-protection identity-gatekeeper -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.0.10
  fi
}

serviceProtectionValues() {
  cat - <<EOF
nameOverride: data-access-protection
config:
  client-id: data-access
  discovery-url: $(httpScheme)://identity.keycloak.${domain}/realms/master
  cookie-domain: ${domain}
targetService:
  host: ${name}.${domain}
  name: data-access-renderer
  port:
    number: 80
# Values for secret 'data-access-protection'
secrets:
  # Note - if ommitted, these can instead be set by creating the secret independently.
  clientSecret: "${IDENTITY_GATEKEEPER_CLIENT_SECRET}"
  encryptionKey: "${IDENTITY_GATEKEEPER_ENCRYPTION_KEY}"
ingress:
  enabled: true
  className: nginx
  annotations:
    ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    nginx.ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /\$1
  
  # ROUTES...
  # Use 'hosts' to define protected routes.
  # Or use 'serverSnippets' to define 'custom' open routes.
  # hosts:
  #   - host: "{{ .Values.targetService.host }}"
  #     paths:
  #       - path: /(ows.*|opensearch.*|coverages/metadata.*|admin.*)
  #         pathType: Prefix
  #         backend:
  #           service:
  #             name: data-access-renderer
  #             port:
  #               number: 80
  #       - path: /cache/(.*)
  #         pathType: Prefix
  #         backend:
  #           service:
  #             name: data-access-cache
  #             port:
  #               number: 80
  #       - path: /(.*)
  #         pathType: Prefix
  #         backend:
  #           service:
  #             name: data-access-client
  #             port:
  #               number: 80
  serverSnippets:
    custom: |-
      # Open access to renderer...
      location ~ ^/(ows.*|opensearch.*|coverages/metadata.*|admin.*) {
        proxy_pass http://data-access-renderer.${NAMESPACE}.svc.cluster.local:80/\$1;
      }
      # Open access to cache...
      location ~ ^/cache/(.*) {
        proxy_pass http://data-access-cache.${NAMESPACE}.svc.cluster.local:80/\$1;
      }
      # Open access to client...
      # Note that we use a negative lookahead to avoid matching '/.well-known/*' which
      # otherwise appears to interfere with the work of cert-manager/letsencrypt.
      location ~ ^/(?!\.well-known)(.*) {
        proxy_pass http://data-access-client.${NAMESPACE}.svc.cluster.local:80/\$1;
      }
EOF
}

main "$@"
