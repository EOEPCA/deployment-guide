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

echo -e "\nCert manager..."
if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace cert-manager uninstall cert-manager
else
  helm ${ACTION_HELM} cert-manager cert-manager \
    --repo https://charts.jetstack.io \
    --namespace cert-manager --create-namespace \
    --set installCRDs=true
fi
