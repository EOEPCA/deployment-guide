#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

ACTION="${@:-template}"

# portal
helm -n demo ${ACTION} --create-namespace --version 0.1.10 --values portal-values.yaml django-portal eoepca/django-portal
