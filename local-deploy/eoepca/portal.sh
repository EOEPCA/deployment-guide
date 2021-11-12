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
domain: ${domain}
configmap:
  user_prefix: eoepca-user
image:
  tag: 2021.10.18.09.18
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall django-portal
else
  helm ${ACTION_HELM} django-portal django-portal -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace demo --create-namespace \
    --version 0.1.10
fi
