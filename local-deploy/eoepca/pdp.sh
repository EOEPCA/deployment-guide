#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

public_ip="${1:-192.168.49.123}"
domain="${2:-${public_ip}.nip.io}"

values() {
  cat - <<EOF
image:
  tag: task464_1
global:
  nginxIp: ${public_ip}
  domain: auth.${domain}
volumeClaim:
  name: eoepca-userman-pvc
  create: false
EOF
}

values | helm upgrade --install pdp pdp-engine -f - \
  --repo https://eoepca.github.io/helm-charts \
  --namespace default --create-namespace \
  --version 0.9.5
