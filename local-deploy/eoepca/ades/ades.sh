#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

ACTION="${@:-template}"

helm -n proc ${ACTION} --create-namespace --version 0.9.10 --values ades-values.yaml ades eoepca/ades
