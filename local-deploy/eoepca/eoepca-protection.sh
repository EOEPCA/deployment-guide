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
configureAction "$ACTION"
initIpDefaults

eric_id="${2:-b8c8c62a-892c-4953-b44d-10a12eb762d8}"
bob_id="${3:-57e3e426-581e-4a01-b2b8-f731a928f2db}"
public_ip="${4:-${default_public_ip}}"
domain="${5:-${default_domain}}"

#-------------------------------------------------------------------------------
# Regsiter a client with the login service
#-------------------------------------------------------------------------------

if [ "$ACTION" = "apply" ]; then
  if [ ! -f client.yaml ]; then
    echo "Registering client with Login Service..."
    ../bin/register-client "auth.${domain}" "EoepcaClient" "https://portal.${domain}/oidc/callback/" "https://portal.${domain}" | tee client.yaml
  fi
elif [ "$ACTION" = "delete" ]; then
  if [ -f client.yaml ]; then
    echo "Removing credentials for previously registered client..."
    rm -f client.yaml
  fi
fi

#-------------------------------------------------------------------------------
# Components that need the client credentials before deployment
#-------------------------------------------------------------------------------

# portal
echo -e "\nDeploy portal..."
./portal.sh "${ACTION}" "${domain}"

# PDE
echo -e "\nDeploy PDE..."
./pde.sh "${ACTION}" "${domain}"

#-------------------------------------------------------------------------------
# Protection
#-------------------------------------------------------------------------------

# dummy service
echo -e "\nProtect dummy-service..."
./dummy-service-guard.sh "$ACTION" "${eric_id}" "${bob_id}" "${public_ip}" "${domain}"

# ades
echo -e "\nProtect ades..."
./ades-guard.sh "$ACTION" "${eric_id}" "${bob_id}" "${public_ip}" "${domain}"

# resource catalogue
echo -e "\nProtect resource-catalogue..."
./resource-catalogue-guard.sh "$ACTION" "${public_ip}" "${domain}"

# data access
echo -e "\nProtect data-access..."
./data-access-guard.sh "$ACTION" "${public_ip}" "${domain}"

# workspace api
echo -e "\nProtect workspace-api..."
./workspace-api-guard.sh "$ACTION" "${eric_id}" "${bob_id}" "${public_ip}" "${domain}"
