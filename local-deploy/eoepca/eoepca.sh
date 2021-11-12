#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

# deduce defaults from minikube ip
minikube_ip="$(minikube ip)"
base_ip="$(echo -n $minikube_ip | cut -d. -f-3)"
default_public_ip="${base_ip}.123"
default_domain="${public_ip}.nip.io"

cluster_name="${1:-eoepca}"
public_ip="${2:-${default_public_ip}}"
domain="${3:-${default_domain}}"

# Create the cluster
../cluster/cluster.sh "${cluster_name}" "${public_ip}" "${domain}"

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
