#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

ACTION="${@:-template}"
NAMESPACE="proc"
SECRET_NAME="proc-client"

if [ -f ../client.yaml ]; then
  echo "Creating secret ${SECRET_NAME} in namespace ${NAMESPACE}..."
  kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
    --from-file=../client.yaml \
    --dry-run=client -o yaml \
    | kubectl apply -f -
  echo "  [done]"
fi

helm -n proc ${ACTION} --create-namespace --version 0.0.54 --values ades-guard-values.yaml ades-guard eoepca/resource-guard
