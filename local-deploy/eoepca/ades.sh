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
# image:
#   pullPolicy: Always
#   tag: "0.9.8"
workflowExecutor:
  inputs:
    STAGEOUT_AWS_SERVICEURL: http://minio.${domain}
    STAGEOUT_AWS_ACCESS_KEY_ID: ${MINIO_ROOT_USER}
    STAGEOUT_AWS_SECRET_ACCESS_KEY: ${MINIO_ROOT_PASSWORD}
    STAGEOUT_AWS_REGION: us-east-1
    STAGEOUT_OUTPUT: s3://eoepca
  processingStorageClass: standard
persistence:
  storageClass: standard
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
  hosts:
    - host: ades-open.${domain}
      paths: ["/"]
  tls:
    - hosts:
        - ades-open.${domain}
      secretName: ades-open-tls
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace proc uninstall ades
else
  values | helm ${ACTION_HELM} ades ades -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace proc --create-namespace \
    --version 0.9.11
fi
