#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

CLUSTER_NAME="${1:-eoepca}"

minikube_ip="$(minikube ip)"
base_ip="$(echo -n $minikube_ip | cut -d. -f-3)"
public_ip="${base_ip}.123"
domain="${public_ip}.nip.io"

# Create the cluster
../cluster/cluster.sh "${CLUSTER_NAME}" "${public_ip}" "${domain}"

# storage
echo -e "\nstorage..."
./storage.sh "${domain}"

# dummy-service
echo -e "\nDeploy dummy-service..."
./dummy-service.sh "${domain}"

# login-service
echo -e "\nDeploy login-service..."
./login-service.sh "${public_ip}" "${domain}"

# pdp
echo -e "\nDeploy pdp..."
./pdp/pdp.sh "${public_ip}" "${domain}"

# ades
echo -e "\nDeploy ades..."
./ades/ades.sh "${domain}"
