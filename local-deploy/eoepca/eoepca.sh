#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source ./eoepca-options

source ../cluster/functions
ACTION="${1:-apply}"
configureAction "$ACTION"
cluster_name="${2:-eoepca}"

# Create the cluster
../cluster/cluster.sh "${ACTION}" "${cluster_name}" $3 $4

# deduce ip address from minikube
initIpDefaults
public_ip="${3:-${default_public_ip}}"
domain="${4:-${default_domain}}"

# storage
echo -e "\nstorage..."
./storage.sh "${ACTION}"

# dummy-service
echo -e "\nDeploy dummy-service..."
./dummy-service.sh "${ACTION}" "${domain}"

# login-service
echo -e "\nDeploy login-service..."
./login-service.sh "${ACTION}" "${public_ip}" "${domain}"

# pdp
echo -e "\nDeploy pdp..."
./pdp.sh "${ACTION}" "${public_ip}" "${domain}"

# user-profile
echo -e "\nDeploy user-profile..."
./user-profile.sh "${ACTION}" "${public_ip}" "${domain}"

# ades
echo -e "\nDeploy ades..."
./ades.sh "${ACTION}" "${domain}"

# resource catalogue
echo -e "\nDeploy resource-catalogue..."
./resource-catalogue.sh "${ACTION}" "${domain}"

# data access
echo -e "\nDeploy data-access..."
./data-access.sh "${ACTION}" "${domain}"

# workspace api
echo -e "\nDeploy workspace-api..."
./workspace-api.sh "${ACTION}" "${public_ip}" "${domain}"

# bucket operator
echo -e "\nDeploy bucket-operator..."
./bucket-operator.sh "${ACTION}" "${domain}"
# if [ "${OS_DOMAINNAME}" != "cloud_XXXXX" ]; then
#   echo -e "\nDeploy bucket-operator..."
#   ./bucket-operator.sh "${ACTION}" "${domain}"
# else
#   echo "SKIPPING bucket operator deployment - openstack credentials have not been configured"
# fi

# harbor artefact registry
echo -e "\nDeploy harbor..."
./harbor.sh "${ACTION}" "${domain}"
