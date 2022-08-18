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

public_ip="${2:-${default_public_ip}}"
domain="${3:-${default_domain}}"
NAMESPACE="default"

values() {
  cat - <<EOF
global:
  namespace: ${NAMESPACE}
volumeClaim:
  name: eoepca-userman-pvc
  create: false
config:
  domain: auth.${domain}
  adminPass: ${LOGIN_SERVICE_ADMIN_PASSWORD}
  ldapPass: ${LOGIN_SERVICE_ADMIN_PASSWORD}
  volumeClaim:
    name: eoepca-userman-pvc
opendj:
  # This can be useful to workaround helm 'failed to upgrade' errors due to
  # immutable fields in the 'login-service-persistence-init-ss' job
  # persistence:
  #   enabled: false
  volumeClaim:
    name: eoepca-userman-pvc
oxauth:
  volumeClaim:
    name: eoepca-userman-pvc
oxtrust:
  volumeClaim:
    name: eoepca-userman-pvc
global:
  domain: auth.${domain}
  nginxIp: ${public_ip}
nginx:
  ingress:
    enabled: true
    annotations:
      # kubernetes.io/ingress.class: nginx
      # ingress.kubernetes.io/ssl-redirect: "false"
      # nginx.ingress.kubernetes.io/ssl-redirect: "false"
      cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
    path: /
    hosts:
      - auth.${domain}
    tls: 
    - secretName: tls-certificate
      hosts:
        - auth.${domain}
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall login-service
else
  values | helm ${ACTION_HELM} login-service login-service -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace "${NAMESPACE}" --create-namespace \
    --version 1.1.5
fi
