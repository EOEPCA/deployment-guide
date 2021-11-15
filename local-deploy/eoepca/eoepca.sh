#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source ../cluster/functions

ACTION="${1:-apply}"
cluster_name="${2:-eoepca}"

# Create the cluster
../cluster/cluster.sh "${ACTION}" "${cluster_name}" $3 $4

# deduce ip address from minikube
initIpDefaults
public_ip="${3:-${default_public_ip}}"
domain="${4:-${default_domain}}"

# storage
echo -e "\nstorage..."
./storage.sh apply

# dummy-service
echo -e "\nDeploy dummy-service..."
./dummy-service.sh apply "${domain}"

# login-service
echo -e "\nDeploy login-service..."
./login-service.sh apply "${public_ip}" "${domain}"

# pdp
echo -e "\nDeploy pdp..."
./pdp.sh apply "${public_ip}" "${domain}"

# ades
echo -e "\nDeploy ades..."
./ades.sh apply "${domain}"

# # portal
# echo -e "\nDeploy portal..."
# ./portal.sh apply "${domain}"
