#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

CLUSTER_NAME="${1:-mykube}"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

# minikube
./install-minikube.sh

# kubernetes cluster
./setup-cluster.sh "${CLUSTER_NAME}"

# Certificate manager
./certificate-manager.sh

# Cluster Issuer
./letsencrypt/letsencrypt.sh

# Sealed Secrets
./sealed-secrets.sh "${CLUSTER_NAME}"

# Minio
./minio/minio.sh
