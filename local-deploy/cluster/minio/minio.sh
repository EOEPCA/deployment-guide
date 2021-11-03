#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

# Minio
echo -e "\nDeploy minio..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm upgrade -i -n minio --create-namespace minio -f minio-values.yaml bitnami/minio --wait
