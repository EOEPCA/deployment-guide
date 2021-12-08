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

values() {
  cat - <<EOF
global:
  env:
    REGISTRAR_REPLACE: "true"
    CPL_VSIL_CURL_ALLOWED_EXTENSIONS: .TIF,.tif,.xml,.jp2
    startup_scripts:
      - /registrar_pycsw/registrar_pycsw/initialize-collections.sh

  ingress:
    enabled: false
    # annotations:
    #   kubernetes.io/ingress.class: nginx
    #   kubernetes.io/tls-acme: "true"
    #   nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    #   nginx.ingress.kubernetes.io/enable-cors: "true"
    #   cert-manager.io/cluster-issuer: letsencrypt-staging
    # hosts:
    #   - host: data-access.${domain}
    # tls:
    #   - hosts:
    #       - data-access.${domain}
    #     secretName: data-access-tls

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
      endpoint_url: "https://cf2.cloudferro.com:8080/cache-bucket"
      host: "cf2.cloudferro.com:8080"
      access_key_id: xxx
      secret_access_key: xxx
      region: RegionOne
      bucket: cache-bucket

  metadata:
    title: EOEPCA Data Access Service developed by EOX
    abstract: EOEPCA Data Access Service developed by EOX
    header: "EOEPCA Data Access View Server (VS) Client powered by <a href=\"//eox.at\"><img src=\"//eox.at/wp-content/uploads/2017/09/EOX_Logo.svg\" alt=\"EOX\" style=\"height:25px;margin-left:10px\"/></a>"
    url: https://data-access.${domain}/ows

  layers: []
  collections: {}
  productTypes: []

renderer:
  image:
    repository: eoepca/rm-data-access-core
    tag: "0.9.10"

registrar:
  image:
    repository: eoepca/rm-data-access-core
    tag: "0.9.10"
  config:
    backends:
      - path: registrar_pycsw.backend.PycswBackend
        kwargs:
          repository_database_uri: postgresql://postgres:mypass@resource-catalogue-db/pycsw
          ows_url: https://data-access.${domain}/ows

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
      storageClass: managed-nfs-storage
  cluster:
    enabled: false

ingestor:
  replicaCount: 0

preprocessor:
  replicaCount: 0
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace rm uninstall data-access
else
  values | helm ${ACTION_HELM} data-access vs -f - \
    --repo https://charts-public.hub.eox.at/ \
    --namespace rm --create-namespace \
    --version 2.0.1
fi
