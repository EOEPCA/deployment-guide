#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

ACTION="${@:-template}"

# dummy-service
helm -n test ${ACTION} --create-namespace --version 0.9.2 --values dummy-service-values.yaml dummy-service eoepca/dummy

# protection
#
# client secret
if [ "${ACTION}" != "template" ]; then
  kubectl -n test create secret generic dummy-service-agent \
    --from-file=../client.yaml \
    --dry-run=client -o yaml \
    | kubectl apply -f -
fi
#
# resource-guard
helm -n test ${ACTION} --create-namespace --version 0.0.52 --values dummy-service-guard-values.yaml dummy-service-guard eoepca/resource-guard
