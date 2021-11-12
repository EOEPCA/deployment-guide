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

public_ip="${2:-${default_public_ip}}"
domain="${3:-${default_domain}}"

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
./dummy-service-guard.sh apply "${public_ip}" "${domain}"

# ades
echo -e "\nProtect ades..."
./ades/ades-guard.sh apply "${public_ip}" "${domain}"
