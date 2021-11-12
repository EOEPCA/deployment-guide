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
domain="${3:-${default_domain}.nip.io}"
NAMESPACE="um"

values() {
  cat - <<EOF
global:
  namespace: ${NAMESPACE}
volumeClaim:
  name: eoepca-userman-pvc
  create: false
config:
  domain: auth.${domain}
  volumeClaim:
    name: eoepca-userman-pvc
opendj:
  # This can be useful to workaround helm 'failed to upgrade' errors due to
  # immutable fields in the 'um-login-service-persistence-init-ss' job
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
    #   kubernetes.io/ingress.class: nginx
    #   kubernetes.io/tls-acme: "true"
      cert-manager.io/cluster-issuer: letsencrypt-staging
    path: /
    hosts:
      - auth.${domain}
    tls: 
    - secretName: login-service-tls
      hosts:
        - auth.${domain}
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall um-login-service
else
  values | helm ${ACTION_HELM} um-login-service login-service -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace "${NAMESPACE}" --create-namespace \
    --version 0.9.45
fi
