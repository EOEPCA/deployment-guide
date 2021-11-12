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
cluster_name="${2:-mykube}"

# Sealed Secrets
echo -e "\nSealed secrets controller..."
if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace infra uninstall "${cluster_name}"-sealed-secrets
else
  helm ${ACTION_HELM} "${cluster_name}"-sealed-secrets sealed-secrets \
    --repo https://bitnami-labs.github.io/sealed-secrets \
    --namespace infra --create-namespace \
    --version 1.13.2
fi
