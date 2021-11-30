#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source functions
configureAction "$1"

values() {
  cat - <<EOF
controller:
  config:
    ssl-redirect: false
EOF
}

echo -e "\nIngress-nginx..."
if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace ingress-nginx uninstall ingress-nginx
else
  values | helm ${ACTION_HELM} ingress-nginx ingress-nginx -f - \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --version='<4'
fi
