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
if [ "${REQUIRE_STORAGE}" = "true" ]; then
  echo -e "\nstorage..."
  ./storage.sh "${ACTION}"
fi

# dummy-service
if [ "${REQUIRE_DUMMY_SERVICE}" = "true" ]; then
  echo -e "\nDeploy dummy-service..."
  ./dummy-service.sh "${ACTION}" "${domain}"
fi

# login-service
if [ "${REQUIRE_LOGIN_SERVICE}" = "true" ]; then
  echo -e "\nDeploy login-service (Gluu)..."
  ./login-service.sh "${ACTION}" "${public_ip}" "${domain}"
  echo -e "\nDeploy identity-service (Keycloak)..."
  ./identity-service.sh "${ACTION}" "${public_ip}" "${domain}"
fi

# pdp
if [ "${REQUIRE_PDP}" = "true" ]; then
  echo -e "\nDeploy pdp..."
  ./pdp.sh "${ACTION}" "${public_ip}" "${domain}"
fi

# user-profile
if [ "${REQUIRE_USER_PROFILE}" = "true" ]; then
  echo -e "\nDeploy user-profile..."
  ./user-profile.sh "${ACTION}" "${public_ip}" "${domain}"
fi

# ades
if [ "${REQUIRE_ADES}" = "true" ]; then
  echo -e "\nDeploy ades..."
  ./ades.sh "${ACTION}" "${domain}"
  echo -e "\nDeploy ADES (zoo-project-dru)..."
  ./zoo.sh "${ACTION}" "${domain}"
fi

# resource catalogue
if [ "${REQUIRE_RESOURCE_CATALOGUE}" = "true" ]; then
  echo -e "\nDeploy resource-catalogue..."
  ./resource-catalogue.sh "${ACTION}" "${domain}"
fi

# data access
if [ "${REQUIRE_DATA_ACCESS}" = "true" ]; then
  echo -e "\nDeploy data-access..."
  ./data-access.sh "${ACTION}" "${domain}"
fi

# registration api
if [ "${REQUIRE_REGISTRATION_API}" = "true" ]; then
  echo -e "\nDeploy registration-api..."
  ./registration-api.sh "${ACTION}" "${domain}"
fi

# workspace api
if [ "${REQUIRE_WORKSPACE_API}" = "true" ]; then
  echo -e "\nDeploy workspace-api..."
  ./workspace-api.sh "${ACTION}" "${public_ip}" "${domain}"
fi

# harbor artefact registry
if [ "${REQUIRE_HARBOR}" = "true" ]; then
  echo -e "\nDeploy harbor..."
  ./harbor.sh "${ACTION}" "${domain}"
fi
