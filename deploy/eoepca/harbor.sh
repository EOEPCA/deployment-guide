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

# Force use of 'valid' certificates from Letsencrypt 'production'.
# The Workspace API, which calls the Harbor API, expects valid certificates.
TLS_CLUSTER_ISSUER="letsencrypt-production"

values() {
  cat - <<EOF
expose:
  ingress:
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: "${TLS_CLUSTER_ISSUER}"
      nginx.ingress.kubernetes.io/proxy-read-timeout: '600'

      # from chart:
      ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
      ingress.kubernetes.io/proxy-body-size: "0"
      nginx.ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
      nginx.ingress.kubernetes.io/proxy-body-size: "0"

    hosts:
      core: harbor.${domain}
    tls:
      enabled: "${USE_TLS}"
      certSource: secret
      secret:
        secretName: "harbor-tls"

persistence:
  persistentVolumeClaim:
    registry:
      storageClass: ${HARBOR_STORAGE}
    chartmuseum:
      storageClass: ${HARBOR_STORAGE}
    jobservice:
      storageClass: ${HARBOR_STORAGE}
    database:
      storageClass: ${HARBOR_STORAGE}
    redis:
      storageClass: ${HARBOR_STORAGE}
    trivy:
      storageClass: ${HARBOR_STORAGE}

externalURL: https://harbor.${domain}
# initial password for logging in with user "admin"
harborAdminPassword: "${HARBOR_ADMIN_PASSWORD}"

chartmuseum:
  enabled: false
trivy:
  enabled: false
notary:
  enabled: false
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace rm uninstall harbor
else
  values | helm ${ACTION_HELM} harbor harbor -f - \
    --repo https://helm.goharbor.io \
    --namespace rm --create-namespace \
    --version 1.7.3
fi
