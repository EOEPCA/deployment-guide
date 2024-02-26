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
provided_domain="${3}"

# Create the cluster
../cluster/cluster.sh "${ACTION}" "${cluster_name}" "${provided_domain}" "${public_ip}"

# deduce ip address from minikube
initIpDefaults
domain="${provided_domain:-${default_domain}}"
public_ip="${4:-${default_public_ip}}"

# storage
if [ "${REQUIRE_STORAGE}" = "true" ]; then
  echo -e "\nstorage..."
  ./storage.sh "${ACTION}"
fi

# identity-service (Keycloak)
if [ "${REQUIRE_IDENTITY_SERVICE}" = "true" ]; then
  echo -e "\nDeploy identity-service (Keycloak)..."
  ./identity-service.sh "${ACTION}" "${domain}"
fi

# dummy-service
if [ "${REQUIRE_DUMMY_SERVICE}" = "true" ]; then
  echo -e "\nDeploy dummy-service..."
  ./dummy-service.sh "${ACTION}" "${domain}"
fi

# ades
if [ "${REQUIRE_ADES}" = "true" ]; then
  echo -e "\nDeploy ADES (zoo-project-dru)..."
  ./zoo.sh "${ACTION}" "${domain}"
fi

# Application Hub
if [ "${REQUIRE_APPLICATION_HUB}" = "true" ]; then
  echo -e "\nDeploy Application Hub..."
  ./application-hub.sh "${ACTION}" "${domain}"
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
  ./workspace-api.sh "${ACTION}" "${domain}"
fi

# harbor artefact registry
if [ "${REQUIRE_HARBOR}" = "true" ]; then
  echo -e "\nDeploy harbor..."
  ./harbor.sh "${ACTION}" "${domain}"
fi

# eoepca portal (useful as a test tool)
if [ "${REQUIRE_PORTAL}" = "true" ]; then
  echo -e "\nDeploy eoepca portal..."
  ./eoepca-portal.sh "${ACTION}" "${domain}"
fi
