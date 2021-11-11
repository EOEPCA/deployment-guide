#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

domain="${1:-192.168.49.123.nip.io}"

values() {
  cat - <<EOF
image:
  # pullPolicy: Always
  # Overrides the image tag whose default is the chart appVersion.
  tag: "0.9.8"
workflowExecutor:
  inputs:
    STAGEOUT_AWS_SERVICEURL: http://minio.${domain}
    STAGEOUT_AWS_ACCESS_KEY_ID: eoepca
    STAGEOUT_AWS_SECRET_ACCESS_KEY: changeme
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
  hosts:
    - host: ades-open.${domain}
      paths: ["/"]
  tls:
    - hosts:
        - ades-open.${domain}
      secretName: ades-open-tls
EOF
}

values | helm upgrade --install ades ades -f - \
  --repo https://eoepca.github.io/helm-charts \
  --namespace proc --create-namespace \
  --version 0.9.10
