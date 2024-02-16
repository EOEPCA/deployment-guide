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

NAMESPACE="demo"

values() {
  cat - <<EOF
image:
  tag: "demo"
configmap:
  configuration: demo
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
  hosts:
    - host: eoepca-portal.${domain}
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: eoepca-portal-tls-certificate
      hosts:
        - eoepca-portal.${domain}
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall eoepca-portal
else
  # helm chart
  values | helm ${ACTION_HELM} eoepca-portal eoepca-portal -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace "${NAMESPACE}" --create-namespace \
    --version 1.0.10
fi
