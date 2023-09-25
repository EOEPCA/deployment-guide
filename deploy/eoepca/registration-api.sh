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
  name="registration-api-open"
else
  name="registration-api"
fi

values() {
  cat - <<EOF
fullnameOverride: registration-api
# image: # {}
  # repository: eoepca/rm-registration-api
  # pullPolicy: Always
  # Overrides the image tag whose default is the chart appVersion.
  # tag: "1.3-dev1"

ingress:
  enabled: false
  hosts:
    - host: registration-api-open.${domain}
      paths: ["/"]
  tls:
    - hosts:
        - registration-api-open.${domain}
      secretName: registration-api-tls

# some values for the workspace API
workspaceK8sNamespace: "${NAMESPACE}"
redisServiceName: "data-access-redis-master"
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace ${NAMESPACE} uninstall registration-api
else
  values | helm ${ACTION_HELM} registration-api rm-registration-api -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace ${NAMESPACE} --create-namespace \
    --version 1.3.0
fi