#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source ../cluster/functions
configureAction "$1"
initIpDefaults

eric_id="${2:-c14974be-b32f-44f3-97be-b216676bb40e}"
bob_id="${3:-44f601ba-3fad-4d22-b2ae-ce8fafcdd763}"
public_ip="${4:-${default_public_ip}}"
domain="${5:-${default_domain}}"

# Register client
if [ "$ACTION" = "apply" ]; then
  if [ ! -f client.yaml ]; then
    echo "Registering client with Login Service..."
    ../bin/register-client "auth.${domain}" "Resource Guard" client.yaml
  fi
elif [ "$ACTION" = "delete" ]; then
  if [ -f client.yaml ]; then
    echo "Removing credentials for previously registered client..."
    rm -f client.yaml
  fi
fi

# dummy service
echo -e "\nProtect dummy-service..."
./dummy-service-guard.sh apply "${eric_id}" "${bob_id}" "${public_ip}" "${domain}"

# ades
echo -e "\nProtect ades..."
./ades/ades-guard.sh apply "${eric_id}" "${bob_id}" "${public_ip}" "${domain}"
