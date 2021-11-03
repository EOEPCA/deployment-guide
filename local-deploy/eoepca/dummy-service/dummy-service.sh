#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

ACTION="${@:-template}"

helm -n test ${ACTION} --create-namespace --version 0.9.2 --values dummy-service-values.yaml dummy-service eoepca/dummy
