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
NAMESPACE="default"

if [ "${OPEN_INGRESS}" = "true" ]; then
  name="dummy-service-open"
else
  name="dummy-service"
fi

values() {
  cat - <<EOF
ingress:
  enabled: ${OPEN_INGRESS}
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
  hosts:
    - host: ${name}.${domain}
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - hosts:
        - ${name}.${domain}
      secretName: ${name}-tls
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall dummy-service
else
  values | helm ${ACTION_HELM} dummy-service dummy -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace "${NAMESPACE}" --create-namespace \
    --version 1.0.0
fi
