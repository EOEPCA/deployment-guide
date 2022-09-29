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
  name="resource-catalogue-open"
else
  name="resource-catalogue"
fi

values() {
  cat - <<EOF
global:
  namespace: rm
ingress:
  enabled: ${OPEN_INGRESS}
  name: ${name}
  host: ${name}.${domain}
  tls_host: ${name}.${domain}
  tls_secret_name: ${name}-tls
  annotations:
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
db:
  volume_storage_type: standard
pycsw:
  # image:
  #   repository: geopython/pycsw
  #   tag: "eoepca-staging"
  #   pullPolicy: Always
  config:
    server:
      url: https://${name}.${domain}/
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace rm uninstall resource-catalogue
else
  values | helm ${ACTION_HELM} resource-catalogue rm-resource-catalogue -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace rm --create-namespace \
    --version 1.2.0
fi
