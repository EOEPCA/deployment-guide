#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

CLUSTER_NAME="${1:-eoepca}"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

# Create the cluster
../cluster/cluster.sh "${CLUSTER_NAME}"

# EOEPCA helm chart repository
echo -e "\neoepca helm repo..."
helm repo add eoepca https://eoepca.github.io/helm-charts

# storage
echo -e "\nstorage..."
./storage/storage.sh

# dummy-service
echo -e "\nDeploy dummy-service..."
./dummy-service/dummy-service.sh upgrade -i

# login-service
echo -e "\nDeploy login-service..."
./login-service/login-service.sh upgrade -i

# Register client
../bin/register-client auth.192.168.49.123.nip.io "Resource Guard" client.yaml

# ades
echo -e "\nDeploy ades..."
./ades/ades.sh upgrade -i
