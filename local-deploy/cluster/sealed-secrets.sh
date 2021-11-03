#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

CLUSTER_NAME="${1:-mykube}"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

# Sealed Secrets
echo -e "\nDeploy the sealed secrets controller..."
helm repo add bitnami-sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm upgrade -i --version 1.13.2 --create-namespace --namespace infra \
  "${CLUSTER_NAME}"-sealed-secrets bitnami-sealed-secrets/sealed-secrets \
   >/dev/null
