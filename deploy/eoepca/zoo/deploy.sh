#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

# Swagger UI: /ogc-api/api.html

ACTION="${1:-apply}"

# Read namespace from kustomization file
NAMESPACE="$(yq --raw-output .helmCharts[0].namespace kustomization.yaml 2>/dev/null)"
NAMESPACE="${NAMESPACE:-zp}"

# Create namespace
if [ "${ACTION}" = "apply" ]; then
  rm -rf charts
  kubectl create namespace "${NAMESPACE}" 2>/dev/null
fi

kubectl kustomize --enable-helm | kubectl -n "${NAMESPACE}" ${ACTION} -f -

if [ "${ACTION}" = "delete" ]; then kubectl delete namespace "${NAMESPACE}"; fi
