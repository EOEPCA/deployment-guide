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
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "false"
    # cert-manager.io/cluster-issuer: letsencrypt-production
  hosts:
    - host: dummy-service-open.${domain}
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - hosts:
        - dummy-service-open.${domain}
      secretName: dummy-service-tls
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace test uninstall dummy-service
else
  values | helm ${ACTION_HELM} dummy-service dummy -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace test --create-namespace \
    --version 0.9.2
fi
