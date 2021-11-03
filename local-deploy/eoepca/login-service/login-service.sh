#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

ACTION="${@:-template}"

helm ${ACTION} --create-namespace --version 0.9.45 --values login-service-values.yaml um-login-service eoepca/login-service
