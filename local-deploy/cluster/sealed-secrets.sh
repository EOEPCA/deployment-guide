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
helm upgrade --install "${CLUSTER_NAME}"-sealed-secrets sealed-secrets \
  --repo https://bitnami-labs.github.io/sealed-secrets \
  --namespace infra --create-namespace \
  --version 1.13.2
