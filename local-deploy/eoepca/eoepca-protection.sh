#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

# Register client
if [ ! -f client.yaml ]; then
  echo "Registering client with Login Service..."
  ../bin/register-client auth.192.168.49.123.nip.io "Resource Guard" client.yaml
fi

# ades
echo -e "\nProtect ades..."
./ades/ades-guard.sh upgrade -i
