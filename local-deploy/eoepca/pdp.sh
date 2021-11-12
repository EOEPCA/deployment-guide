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

values() {
  cat - <<EOF
image:
  tag: task464_1
global:
  nginxIp: ${public_ip}
  domain: auth.${domain}
volumeClaim:
  name: eoepca-userman-pvc
  create: false
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace um uninstall pdp
else
  values | helm ${ACTION_HELM} pdp pdp-engine -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace um --create-namespace \
    --version 0.9.5
fi
